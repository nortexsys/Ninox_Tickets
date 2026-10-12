/// What a file's first bytes say about it (`implement-photo-route`, design §1).
///
/// **Why it exists.** The photo route is handed a file and has to know what it
/// is: a PDF, whose pages are rendered, or an image, which is read as it is.
/// And an image's boxes come back from the engine in the image's own pixels,
/// which have to become Core's milli-points, so the image's size has to be
/// known before it is read — and reading the size out of the file's own header
/// is the only way to know it without decoding the image.
///
/// **What it does not do.** It decodes nothing: no pixel is read, no channel is
/// converted, and nothing is written. It looks at a prefix of the file and
/// returns numbers the format itself declares. The formats are the two image
/// types the MVP accepts (`IntakeResult.supportedMediaTypes`): **PNG** and
/// **JPEG**.
///
/// **Where it stops.** A file that is neither a PDF nor one of those two
/// images is not identified. A JPEG's frame header can sit behind a large
/// application segment; the caller hands this code a prefix, and a frame header
/// that is not inside it is not found.
library;

import 'dart:typed_data';

/// The size an image file declares for itself, in pixels.
class ImagePixelSize {
  /// Creates a size of [width] by [height] pixels.
  const ImagePixelSize(this.width, this.height);

  /// The image's width in pixels.
  final int width;

  /// The image's height in pixels.
  final int height;

  @override
  String toString() => 'ImagePixelSize(${width}x$height)';

  /// Value equality on both sides.
  @override
  bool operator ==(Object other) =>
      other is ImagePixelSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}

/// Whether [bytes] begin with a PDF's own marker, `%PDF-`.
///
/// The marker and not the file name: the intake keeps the name a document
/// arrived with, and the bytes are what is read.
bool looksLikePdf(Uint8List bytes) {
  const List<int> marker = <int>[0x25, 0x50, 0x44, 0x46, 0x2D];
  if (bytes.length < marker.length) {
    return false;
  }
  for (var i = 0; i < marker.length; i++) {
    if (bytes[i] != marker[i]) {
      return false;
    }
  }
  return true;
}

/// The size the PNG or JPEG in [bytes] declares for itself, or null when
/// [bytes] is neither or its header does not carry a usable size.
///
/// A size of no pixel in either direction is not a size and answers null: the
/// conversion to Core's units divides by the pixel count, and a zero there
/// would be a division this layer must not perform.
ImagePixelSize? imagePixelSize(Uint8List bytes) {
  if (_startsWithPng(bytes)) {
    return _pngSize(bytes);
  }
  if (_startsWithJpeg(bytes)) {
    return _jpegSize(bytes);
  }
  return null;
}

/// PNG's signature: eight bytes that no other common format starts with.
const List<int> _pngSignature = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
];

bool _startsWithPng(Uint8List bytes) {
  if (bytes.length < _pngSignature.length) {
    return false;
  }
  for (var i = 0; i < _pngSignature.length; i++) {
    if (bytes[i] != _pngSignature[i]) {
      return false;
    }
  }
  return true;
}

/// The width and height of a PNG, from the `IHDR` chunk that every PNG carries
/// first: eight bytes of signature, four of chunk length, four of chunk type,
/// then the two 32-bit big-endian sizes.
ImagePixelSize? _pngSize(Uint8List bytes) {
  const int ihdrWidth = 16;
  if (bytes.length < ihdrWidth + 8) {
    return null;
  }
  final int width = _bigEndianInt(bytes, ihdrWidth);
  final int height = _bigEndianInt(bytes, ihdrWidth + 4);
  if (width <= 0 || height <= 0) {
    return null;
  }
  return ImagePixelSize(width, height);
}

/// A JPEG starts with the start-of-image marker.
bool _startsWithJpeg(Uint8List bytes) =>
    bytes.length >= 3 &&
    bytes[0] == 0xFF &&
    bytes[1] == 0xD8 &&
    bytes[2] == 0xFF;

/// The width and height of a JPEG, from its first frame header.
///
/// The segments between the start-of-image marker and the frame are walked by
/// their own declared lengths, because that is the only way to reach the frame
/// header: a JPEG may carry any number of application and table segments first,
/// and their content means nothing here.
ImagePixelSize? _jpegSize(Uint8List bytes) {
  var i = 2;
  while (i + 3 < bytes.length) {
    if (bytes[i] != 0xFF) {
      // Not a marker where a marker must be: the stream cannot be walked.
      return null;
    }
    while (i < bytes.length && bytes[i] == 0xFF) {
      // A marker may be preceded by any number of fill bytes.
      i++;
    }
    if (i >= bytes.length) {
      return null;
    }
    final int marker = bytes[i];
    i++;
    if (marker == 0xD9) {
      // End of image, and no frame header was found before it.
      return null;
    }
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD8)) {
      // Standalone markers: no length field, nothing to skip.
      continue;
    }
    if (i + 1 >= bytes.length) {
      return null;
    }
    final int length = (bytes[i] << 8) | bytes[i + 1];
    if (length < 2) {
      return null;
    }
    if (_isFrameHeader(marker)) {
      // length, then one byte of sample precision, then the height and the
      // width, each 16 bits big-endian.
      if (i + 6 >= bytes.length) {
        return null;
      }
      final int height = (bytes[i + 3] << 8) | bytes[i + 4];
      final int width = (bytes[i + 5] << 8) | bytes[i + 6];
      if (width <= 0 || height <= 0) {
        return null;
      }
      return ImagePixelSize(width, height);
    }
    i += length;
  }
  return null;
}

/// The frame headers: the markers that carry the image's size.
///
/// They are the `SOF` markers, with three codes among them that are not frame
/// headers: `0xC4` is a table, `0xC8` is reserved and `0xCC` is an arithmetic
/// coding table.
bool _isFrameHeader(int marker) =>
    marker >= 0xC0 &&
    marker <= 0xCF &&
    marker != 0xC4 &&
    marker != 0xC8 &&
    marker != 0xCC;

/// A 32-bit big-endian integer, the order PNG writes its sizes in.
int _bigEndianInt(Uint8List bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];
