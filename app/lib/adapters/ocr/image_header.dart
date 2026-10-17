/// What a file's own header says about it (`implement-photo-route`, design §1).
///
/// **Why it exists.** The photo route is handed a file and has to know what it
/// is: a PDF, whose pages are rendered, or an image, which is read as it is.
/// And an image's boxes come back from the engine in the image's own pixels,
/// which have to become Core's milli-points, so the image's size has to be
/// known before it is read — and reading the size out of the file's own header
/// is the only way to know it without decoding the image.
///
/// **What it does not do.** It decodes nothing: no pixel is read, no channel is
/// converted, and nothing is written. It returns numbers the format itself
/// declares. The formats are the two image types the MVP accepts
/// (`IntakeResult.supportedMediaTypes`): **PNG** and **JPEG**.
///
/// **Where an image's size is.** A PNG declares its own in the `IHDR` chunk it
/// carries first, so twenty-four bytes of its head settle it. A JPEG declares
/// it in a frame header that sits behind the application segments — EXIF and
/// the like — that precede it, and those are not small: the camera photo
/// measured on a real device on 2026-10-16 carries an `APP1` of 45313 bytes and
/// an `APP4` of 36627, which puts its frame header at byte 82084. No fixed
/// prefix of a file reaches that, so [imagePixelSizeIn] walks the segment
/// structure instead: it seeks past each segment by the length that segment
/// declares, reading four bytes of each of them — a marker and a length — and
/// never holding the file.
///
/// **Where the walk stops.** At the first frame header; at the start of the
/// scan (`0xDA`, which comes after the frame header in a file that has one); at
/// the end of the file; and after [_maxSegments] segments. A truncated or
/// corrupt file is also stopped by the length it declares for a segment that
/// runs past its end. Every one of those answers null — not identified — rather
/// than looping or throwing.
///
/// **The orientation.** A JPEG declares its size as the picture is *stored*, and
/// says in its EXIF `Orientation` tag how it must be turned to be shown: a
/// camera held on its side writes a picture wider than it is tall and a tag
/// that turns it a quarter turn round. What the decoder in `image_decoder.dart`
/// hands back is the picture as it is *shown* — measured, not assumed, and
/// asserted by `test/adapters/ocr/image_decoder_test.dart` — so the size the
/// photo route converts boxes with is [displayedImageSize], and
/// [imageExifOrientationIn] reads the tag the walk passes on its way to the
/// frame header. The tag is read and nothing else: no pixel is decoded here and
/// nothing is written.
library;

import 'dart:io';
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

/// The size the PNG or JPEG in [file] declares for itself, or null when the
/// file is neither or its header does not carry a usable size.
///
/// A PDF is not an image and answers null here. Its marker, `%PDF-`, is in the
/// file's first bytes, and [looksLikePdf] reads it to tell the two routes
/// apart.
///
/// **What it reads.** A PNG: its first [_pngHeaderBytes] bytes, which hold the
/// signature and the whole `IHDR` chunk. A JPEG: the four bytes of one segment
/// header at a time, seeking over each segment's body by the length that
/// segment declares, until the first frame header — the one that carries the
/// size. Nothing else is read, and the file is opened for reading and closed
/// again on every path out of here.
///
/// A size of no pixel in either direction is not a size and answers null: the
/// conversion to Core's units divides by the pixel count, and a zero there
/// would be a division this layer must not perform.
///
/// A file the process cannot open or read throws [FileSystemException], which
/// is the caller's to state as its own failure.
ImagePixelSize? imagePixelSizeIn(File file) {
  final RandomAccessFile handle = file.openSync();
  try {
    final int length = handle.lengthSync();
    final Uint8List head = _bytesAt(handle, 0, _pngHeaderBytes);
    if (_startsWithPng(head)) {
      return _pngSize(head);
    }
    if (!_startsWithJpeg(head)) {
      return null;
    }
    return _jpegSize(handle, length);
  } finally {
    handle.closeSync();
  }
}

/// The EXIF `Orientation` tag the JPEG in [file] declares, or null when it
/// declares none — because it is a PNG, because it carries no EXIF, because its
/// IFD has no orientation entry, or because the file is truncated, corrupt or
/// runs out of bytes before the entry is reached.
///
/// **What it reads.** The walk of [imagePixelSizeIn], stopping at the frame
/// header: an `APP1` segment may be EXIF — the `Exif` signature, a TIFF header,
/// and a first IFD whose entries are read two bytes at a time — or it may be
/// something else (a camera writes XMP in an `APP1` too) and the walk goes on to
/// the next segment. The value is the tag's own, 1 to 8; anything outside that
/// range is not an orientation this layer will act on and answers null.
///
/// **What it does not do.** It decodes nothing and rotates nothing: the tag is
/// a number a decoder or a caller acts on, and this function only reports it.
/// The file is opened for reading and closed again on every path out of here.
///
/// A file the process cannot open or read throws [FileSystemException], which
/// is the caller's to state as its own failure.
int? imageExifOrientationIn(File file) {
  final RandomAccessFile handle = file.openSync();
  try {
    final int length = handle.lengthSync();
    final Uint8List head = _bytesAt(handle, 0, _pngHeaderBytes);
    if (_startsWithPng(head) || !_startsWithJpeg(head)) {
      return null;
    }
    return _jpegExifOrientation(handle, length);
  } finally {
    handle.closeSync();
  }
}

/// Whether an EXIF [orientation] shows the picture a quarter turn round, which
/// is the four tags that exchange an image's width and height.
///
/// The eight values are the standard's: 1 as stored, 2 mirrored horizontally, 3
/// half a turn, 4 mirrored vertically, and 5, 6, 7 and 8 the four that show the
/// picture a quarter turn round — of which 6 is the one a camera held on its
/// side writes.
bool orientationExchangesAxes(int orientation) =>
    orientation >= 5 && orientation <= 8;

/// The size a picture of [stored] pixels is **displayed** at, given the EXIF
/// [orientation] its file declares (or null when it declares none).
///
/// A JPEG declares the size it holds and not the size it is shown at: with a
/// quarter-turn tag the two differ by an exchanged pair of sides, and everything
/// downstream — the page's size in points, and therefore every box of every
/// pass — is about the picture as it is shown and read.
ImagePixelSize displayedImageSize(ImagePixelSize stored, int? orientation) =>
    orientation != null && orientationExchangesAxes(orientation)
    ? ImagePixelSize(stored.height, stored.width)
    : stored;

/// The orientation tag of an IFD entry: `0x0112`, the one number this file
/// knows inside an EXIF directory.
const int _orientationTag = 0x0112;

/// The `Exif` signature that tells an `APP1` holding EXIF from one holding
/// something else.
const List<int> _exifSignature = <int>[0x45, 0x78, 0x69, 0x66, 0x00, 0x00];

/// What a TIFF header declares in its magic number: `42`, in the file's own
/// byte order.
const int _tiffMagic = 42;

/// The most entries a first IFD may declare before the file is taken as
/// corrupt.
///
/// It bounds a file that claims tens of thousands of entries, not a real one: a
/// camera writes tens of entries, and a directory of this many is twelve
/// kilobytes of a segment body this layer would otherwise read whole.
const int _maxExifEntries = 1024;

/// The orientation an `APP1` segment of [handle] declares, or null when the
/// segment is not EXIF or declares none.
///
/// [payload] is where the segment's bytes start, [payloadLength] how many the
/// segment declares, and [length] how long the file is: every read is bounded
/// by the smaller of the two, so a segment that declares more than the file
/// holds is not followed past its end.
int? _jpegExifOrientation(RandomAccessFile handle, int length) {
  var offset = 2; // past the start-of-image marker
  for (var segment = 0; segment < _maxSegments; segment++) {
    final Uint8List header = _bytesAt(handle, offset, _segmentHeaderBytes);
    if (header.isEmpty || header[0] != 0xFF) {
      return null;
    }
    if (header.length >= 2 && header[1] == 0xFF) {
      offset++;
      continue;
    }
    if (header.length < 2) {
      return null;
    }
    final int marker = header[1];
    if (marker == 0xD9 || marker == 0xDA || _isFrameHeader(marker)) {
      // The end of the image, the start of the scan, or the frame header: the
      // application segments come before all three, so there is nothing left to
      // find.
      return null;
    }
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD8)) {
      offset += 2;
      continue;
    }
    if (header.length < 4) {
      return null;
    }
    final int declared = (header[2] << 8) | header[3];
    if (declared < 2) {
      return null;
    }
    if (offset + 2 + declared > length) {
      return null;
    }
    if (marker == 0xE1) {
      final int? orientation = _exifOrientationIn(
        handle,
        payload: offset + 4,
        payloadLength: declared - 2,
        length: length,
      );
      if (orientation != null) {
        return orientation;
      }
    }
    offset += 2 + declared;
  }
  return null;
}

/// The orientation one `APP1` segment declares, read entry by entry.
int? _exifOrientationIn(
  RandomAccessFile handle, {
  required int payload,
  required int payloadLength,
  required int length,
}) {
  final int end = payload + payloadLength > length
      ? length
      : payload + payloadLength;
  final Uint8List signature = _bytesAt(handle, payload, _exifSignature.length);
  if (signature.length < _exifSignature.length) {
    return null;
  }
  for (var i = 0; i < _exifSignature.length; i++) {
    if (signature[i] != _exifSignature[i]) {
      return null;
    }
  }

  // The TIFF header: the byte order, the magic number, and where the first IFD
  // starts, both of the latter in that byte order.
  final int tiff = payload + _exifSignature.length;
  if (tiff + 8 > end) {
    return null;
  }
  final Uint8List header = _bytesAt(handle, tiff, 8);
  if (header.length < 8) {
    return null;
  }
  final bool? littleEndian = switch ((header[0], header[1])) {
    (0x49, 0x49) => true, // "II"
    (0x4D, 0x4D) => false, // "MM"
    _ => null,
  };
  if (littleEndian == null || _uint16(header, 2, littleEndian) != _tiffMagic) {
    return null;
  }

  final int directory = tiff + _uint32(header, 4, littleEndian);
  if (directory + 2 > end) {
    return null;
  }
  final Uint8List countBytes = _bytesAt(handle, directory, 2);
  if (countBytes.length < 2) {
    return null;
  }
  final int entries = _uint16(countBytes, 0, littleEndian);
  if (entries == 0 || entries > _maxExifEntries) {
    return null;
  }
  final int size = entries * 12;
  if (directory + 2 + size > end) {
    return null;
  }
  final Uint8List directoryBytes = _bytesAt(handle, directory + 2, size);
  if (directoryBytes.length < size) {
    return null;
  }

  for (var entry = 0; entry < entries; entry++) {
    final int at = entry * 12;
    if (_uint16(directoryBytes, at, littleEndian) != _orientationTag) {
      continue;
    }
    // The tag's type must be a SHORT and it must carry at least one value: an
    // orientation written as anything else is not the orientation a decoder
    // acts on, and is left alone.
    if (_uint16(directoryBytes, at + 2, littleEndian) != 3 ||
        _uint32(directoryBytes, at + 4, littleEndian) < 1) {
      continue;
    }
    final int value = _uint16(directoryBytes, at + 8, littleEndian);
    return value >= 1 && value <= 8 ? value : null;
  }
  return null;
}

/// A 16-bit integer in the byte order [littleEndian] names.
int _uint16(Uint8List bytes, int offset, bool littleEndian) => littleEndian
    ? bytes[offset] | (bytes[offset + 1] << 8)
    : (bytes[offset] << 8) | bytes[offset + 1];

/// A 32-bit integer in the byte order [littleEndian] names.
int _uint32(Uint8List bytes, int offset, bool littleEndian) => littleEndian
    ? bytes[offset] |
          (bytes[offset + 1] << 8) |
          (bytes[offset + 2] << 16) |
          (bytes[offset + 3] << 24)
    : (bytes[offset] << 24) |
          (bytes[offset + 1] << 16) |
          (bytes[offset + 2] << 8) |
          bytes[offset + 3];

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

/// How much of a file's head is read to settle a PNG: its eight bytes of
/// signature, four of `IHDR` chunk length, four of chunk type, and the eight of
/// the two sizes the chunk declares.
const int _pngHeaderBytes = 24;

/// How many bytes of one segment header a JPEG walk reads: the marker and the
/// length the segment declares for itself.
const int _segmentHeaderBytes = 4;

/// How many bytes a frame header carries before the sizes: the declared length,
/// one byte of sample precision, then the height and the width.
const int _frameHeaderBytes = 7;

/// The most segments a JPEG walk follows before it gives up.
///
/// It bounds a corrupt file, not a real one: a camera's JPEG carries tens of
/// segments and this is a hundred times that. Each step advances by at least
/// two bytes, so a file that declares thousands of empty segments ends the walk
/// — with no frame header found — instead of being read to no end.
const int _maxSegments = 4096;

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

/// The width and height of a JPEG, from its first frame header, found by
/// walking the segments of [handle] up to [length] bytes.
///
/// The segments between the start-of-image marker and the frame are walked by
/// their own declared lengths, because that is the only way to reach the frame
/// header: a JPEG may carry any number of application and table segments first,
/// their content means nothing here, and a camera fills them with tens of
/// kilobytes — the file that exposed this defect puts the frame header at byte
/// 82084, past any prefix short enough to hold in memory. So each step reads
/// the four bytes of one segment header and seeks past the body, and the file
/// is never read whole nor held.
///
/// Every way the walk can end without a frame header answers null: a byte that
/// is not a marker, a marker without its declared length, a declared length
/// below two or one that runs past the end of the file, the end of image, the
/// start of the scan, the end of the file, and [_maxSegments] segments read.
ImagePixelSize? _jpegSize(RandomAccessFile handle, int length) {
  var offset = 2; // past the start-of-image marker
  for (var segment = 0; segment < _maxSegments; segment++) {
    final Uint8List header = _bytesAt(handle, offset, _segmentHeaderBytes);
    if (header.isEmpty || header[0] != 0xFF) {
      // The end of the file, or not a marker where a marker must be: the
      // stream cannot be walked any further.
      return null;
    }
    if (header.length >= 2 && header[1] == 0xFF) {
      // A marker may be preceded by any number of fill bytes.
      offset++;
      continue;
    }
    if (header.length < 2) {
      return null;
    }
    final int marker = header[1];
    if (marker == 0xD9 || marker == 0xDA) {
      // End of image, or start of scan: no frame header came before it.
      return null;
    }
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD8)) {
      // Standalone markers: no length field, nothing to skip.
      offset += 2;
      continue;
    }
    if (header.length < 4) {
      // A marker whose declared length is not in the file.
      return null;
    }
    final int declared = (header[2] << 8) | header[3];
    if (declared < 2) {
      return null;
    }
    if (offset + 2 + declared > length) {
      // The length the segment declares runs past the end of the file: the file
      // is truncated or corrupt, and what follows cannot be trusted.
      return null;
    }
    if (_isFrameHeader(marker)) {
      // The declared length, then one byte of sample precision, then the height
      // and the width, each 16 bits big-endian.
      final Uint8List frame = _bytesAt(handle, offset + 2, _frameHeaderBytes);
      if (frame.length < _frameHeaderBytes) {
        return null;
      }
      final int height = (frame[3] << 8) | frame[4];
      final int width = (frame[5] << 8) | frame[6];
      if (width <= 0 || height <= 0) {
        return null;
      }
      return ImagePixelSize(width, height);
    }
    offset += 2 + declared;
  }
  return null;
}

/// Up to [count] bytes of [handle] at [offset], and fewer when the file ends
/// first.
Uint8List _bytesAt(RandomAccessFile handle, int offset, int count) {
  handle.setPositionSync(offset);
  return handle.readSync(count);
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
