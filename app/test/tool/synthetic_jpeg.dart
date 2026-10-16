import 'dart:typed_data';

/// JPEG structures built for the header tests of the photo route
/// (`implement-photo-route`, task T1.16).
///
/// **Why they exist.** The photo route identifies a file by its own header: a
/// JPEG declares its size in its first frame header, and that header sits behind
/// the application segments — EXIF and the like — that a camera writes ahead of
/// it. The file measured on a real device on 2026-10-16 is [cameraLikeJpeg]:
/// start of image, an `APP1` of 45313 bytes, an `APP4` of 36627, two
/// quantisation tables of 67 bytes each, and the frame header at byte
/// [cameraLikeFrameOffset] — 82 KB into the file, out of reach of any fixed
/// prefix short enough to be read into memory.
///
/// **What they are not.** Structure and nothing else: every byte outside the
/// segment headers is zero, and a zero-filled segment is not a picture. Nothing
/// here decodes a pixel or writes one, and no file of the private corpus
/// (`Paperdrop_corpus`, outside the repository by design) is read, copied or
/// referenced.

/// Where the frame header of a camera-like JPEG starts, byte for byte as
/// measured on a real device on 2026-10-16: the two bytes of start of image, an
/// `APP1` of 45313 bytes, an `APP4` of 36627, two tables of 67, and it.
const int cameraLikeFrameOffset = 82084;

/// A JPEG of the shape a camera wrote on 2026-10-16, declaring [width] by
/// [height] pixels in its frame header.
Uint8List cameraLikeJpeg({required int width, required int height}) {
  final List<int> bytes = <int>[0xFF, 0xD8]; // start of image
  for (final List<int> segment in <List<int>>[
    <int>[0xE1, 45313], // APP1, where a camera puts its EXIF
    <int>[0xE4, 36627], // APP4
    <int>[0xDB, 67], // a quantisation table
    <int>[0xDB, 67], // and another
  ]) {
    bytes.addAll(<int>[
      0xFF, segment[0], (segment[1] >> 8) & 0xFF, segment[1] & 0xFF, //
    ]);
    bytes.addAll(List<int>.filled(segment[1] - 2, 0x00));
  }
  if (bytes.length != cameraLikeFrameOffset) {
    throw StateError(
      'the segments put the frame header at ${bytes.length}, not at '
      '$cameraLikeFrameOffset',
    );
  }
  bytes.addAll(frameHeader(width: width, height: height));
  return Uint8List.fromList(bytes);
}

/// A baseline frame header — `SOF0` — declaring [width] by [height] pixels:
/// the marker, the length the segment declares, one byte of sample precision,
/// the height and the width, and three components.
List<int> frameHeader({required int width, required int height}) => <int>[
  0xFF, 0xC0, 0x00, 0x11, 0x08, //
  (height >> 8) & 0xFF, height & 0xFF,
  (width >> 8) & 0xFF, width & 0xFF,
  0x03, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
];
