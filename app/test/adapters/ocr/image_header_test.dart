import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/adapters/ocr/image_header.dart';

/// What identifies a file before it is read (`implement-photo-route`,
/// design §1).
///
/// **What this proves.** That a PDF is recognised by its own marker, that a PNG
/// and a JPEG are recognised by theirs with the size each declares, that the
/// walk past a JPEG's application segments reaches its frame header, and that a
/// file which is neither — or a truncated one, or one that declares no pixel —
/// is not mistaken for one. On that answer depends which route the file takes:
/// rendered page by page, or read as it is.
///
/// **Where it stops.** It reads the bytes this test writes. That the real
/// scanner's PDF and a real camera's JPEG are identified the same way is what
/// the device run measures; a JPEG whose frame header sits beyond the prefix
/// the adapter reads is stated as a limit of the adapter, not proved here.
void main() {
  test('a PDF is recognised by its marker, and an image is not', () {
    expect(looksLikePdf(_bytes('%PDF-1.7\n')), isTrue);
    expect(looksLikePdf(_bytes('%PDF-')), isTrue);
    expect(looksLikePdf(_bytes(' %PDF-')), isFalse);
    expect(looksLikePdf(_png(width: 10, height: 10)), isFalse);
    expect(looksLikePdf(_bytes('PK')), isFalse);
  });

  test('a PNG carries its size in the IHDR chunk it starts with', () {
    expect(
      imagePixelSize(_png(width: 1240, height: 1754)),
      const ImagePixelSize(1240, 1754),
    );
    expect(
      imagePixelSize(_png(width: 1, height: 1)),
      const ImagePixelSize(1, 1),
    );
    // 0x0102_0304 and 0x0506_0708, which only a correct big-endian read gets.
    expect(
      imagePixelSize(_png(width: 0x01020304, height: 0x05060708)),
      const ImagePixelSize(0x01020304, 0x05060708),
    );
  });

  test('a JPEG carries its size in its first frame header', () {
    expect(
      imagePixelSize(_jpeg(width: 4032, height: 3024)),
      const ImagePixelSize(4032, 3024),
    );
    expect(
      imagePixelSize(_jpeg(width: 1, height: 1, applicationSegments: 3)),
      const ImagePixelSize(1, 1),
      reason: 'the segments before the frame are walked, not read',
    );
  });

  test('a file that is neither answers with no size', () {
    expect(imagePixelSize(_bytes('not an image at all')), isNull);
    expect(imagePixelSize(Uint8List(0)), isNull);
  });

  test('an image that declares no pixel answers with no size', () {
    // A zero in either direction is not a size: the conversion to Core's units
    // divides by the pixel count.
    expect(imagePixelSize(_png(width: 0, height: 100)), isNull);
    expect(imagePixelSize(_png(width: 100, height: 0)), isNull);
    expect(imagePixelSize(_jpeg(width: 0, height: 100)), isNull);
  });

  test('a truncated header answers with no size', () {
    expect(
      imagePixelSize(_png(width: 800, height: 1200).sublist(0, 12)),
      isNull,
      reason: 'a PNG signature without its IHDR is not a size',
    );
    expect(
      imagePixelSize(_jpeg(width: 800, height: 1200).sublist(0, 12)),
      isNull,
      reason: 'a JPEG cut before its frame header is not a size',
    );
  });

  test('a JPEG that ends before any frame answers with no size', () {
    expect(
      imagePixelSize(Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xD9])),
      isNull,
    );
  });

  test('the size is a value', () {
    expect(const ImagePixelSize(10, 20), const ImagePixelSize(10, 20));
    expect(const ImagePixelSize(10, 20), isNot(const ImagePixelSize(20, 10)));
    expect(const ImagePixelSize(10, 20).toString(), 'ImagePixelSize(10x20)');
  });
}

Uint8List _bytes(String text) =>
    Uint8List.fromList(text.codeUnits.map((int unit) => unit & 0x7F).toList());

/// A PNG: the eight-byte signature, then the `IHDR` chunk with the two sizes
/// every PNG carries first.
Uint8List _png({required int width, required int height}) {
  final Uint8List bytes = Uint8List(24);
  bytes.setAll(0, <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  bytes.setAll(12, <int>[0x49, 0x48, 0x44, 0x52]);
  _writeInt(bytes, 16, width);
  _writeInt(bytes, 20, height);
  return bytes;
}

/// A JPEG: start of image, [applicationSegments] application segments to be
/// skipped, then a baseline frame header carrying the size.
Uint8List _jpeg({
  required int width,
  required int height,
  int applicationSegments = 1,
}) {
  final List<int> bytes = <int>[0xFF, 0xD8];
  for (var i = 0; i < applicationSegments; i++) {
    bytes.addAll(<int>[0xFF, 0xE0, 0x00, 0x10]);
    bytes.addAll(List<int>.filled(14, 0x00));
  }
  bytes.addAll(<int>[
    0xFF, 0xC0, 0x00, 0x11, 0x08, //
    (height >> 8) & 0xFF, height & 0xFF,
    (width >> 8) & 0xFF, width & 0xFF,
    0x03, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
  ]);
  return Uint8List.fromList(bytes);
}

void _writeInt(Uint8List bytes, int offset, int value) {
  bytes[offset] = (value >> 24) & 0xFF;
  bytes[offset + 1] = (value >> 16) & 0xFF;
  bytes[offset + 2] = (value >> 8) & 0xFF;
  bytes[offset + 3] = value & 0xFF;
}
