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
