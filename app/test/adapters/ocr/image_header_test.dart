import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/adapters/ocr/image_header.dart';
import 'package:path/path.dart' as p;

import '../../tool/decodable_image.dart';
import '../../tool/synthetic_jpeg.dart';

/// What identifies a file before it is read (`implement-photo-route`,
/// design §1).
///
/// **What this proves.** That a PDF is recognised by its own marker, that a PNG
/// and a JPEG are recognised by theirs with the size each declares, that a
/// JPEG's size is found by walking the file's segments by the lengths they
/// declare — however far past the head of the file its frame header sits — and
/// that a file which is neither, or a truncated one, or one whose declared
/// length runs past its end, or one that declares no pixel, is not mistaken for
/// an image. On that answer depends which route the file takes: rendered page
/// by page, or read as it is.
///
/// **Why the camera's file is built here.** The shape walked below is the one
/// measured on a real device on 2026-10-16 — an `APP1` of 45313 bytes, an
/// `APP4` of 36627, the frame header at byte 82084 — and it is a file this test
/// writes from bytes in its own temporary directory: no file of the private
/// corpus is read, copied or referenced, and no pixel is decoded or written.
///
/// **Where it stops.** It reads the bytes this test writes. That the real
/// scanner's PDF and the real camera's JPEG are identified the same way is what
/// the device run measures (task 2.2).
void main() {
  late Directory work;

  setUp(() {
    work = Directory.systemTemp.createTempSync('paperdrop-header-test');
  });

  tearDown(() {
    if (work.existsSync()) {
      work.deleteSync(recursive: true);
    }
  });

  /// A file of this test's own, named [name] and holding [bytes].
  File write(String name, List<int> bytes) =>
      File(p.join(work.path, name))..writeAsBytesSync(bytes);

  test('a PDF is recognised by its marker, and an image is not', () {
    expect(looksLikePdf(_bytes('%PDF-1.7\n')), isTrue);
    expect(looksLikePdf(_bytes('%PDF-')), isTrue);
    expect(looksLikePdf(_bytes(' %PDF-')), isFalse);
    expect(looksLikePdf(_png(width: 10, height: 10)), isFalse);
    expect(looksLikePdf(_bytes('PK')), isFalse);
  });

  test('a PDF is not an image, and its marker is in its first bytes', () {
    final File document = write('scan.pdf', _bytes('%PDF-1.7\n1 0 obj\n'));

    expect(imagePixelSizeIn(document), isNull);
    expect(looksLikePdf(document.readAsBytesSync()), isTrue);
  });

  test('a PNG carries its size in the IHDR chunk it starts with', () {
    expect(
      imagePixelSizeIn(write('scan.png', _png(width: 1240, height: 1754))),
      const ImagePixelSize(1240, 1754),
    );
    expect(
      imagePixelSizeIn(write('pixel.png', _png(width: 1, height: 1))),
      const ImagePixelSize(1, 1),
    );
    // 0x0102_0304 and 0x0506_0708, which only a correct big-endian read gets.
    expect(
      imagePixelSizeIn(
        write('wide.png', _png(width: 0x01020304, height: 0x05060708)),
      ),
      const ImagePixelSize(0x01020304, 0x05060708),
    );
  });

  test('a JPEG carries its size in its first frame header', () {
    expect(
      imagePixelSizeIn(write('small.jpg', _jpeg(width: 4032, height: 3024))),
      const ImagePixelSize(4032, 3024),
    );
    expect(
      imagePixelSizeIn(
        write('exif.jpg', _jpeg(width: 1, height: 1, applicationSegments: 3)),
      ),
      const ImagePixelSize(1, 1),
      reason: 'the segments before the frame are walked, not read',
    );
  });

  test('a camera JPEG is identified although its frame header is 82 KB in', () {
    final Uint8List camera = cameraLikeJpeg(width: 4032, height: 3024);

    // The measured shape, and the reason a prefix cannot do this job: the frame
    // header is past the 64 KiB the adapter used to read, and the file is past
    // it too.
    expect(
      camera.sublist(cameraLikeFrameOffset, cameraLikeFrameOffset + 2),
      <int>[0xFF, 0xC0],
      reason: 'the frame header is at byte 82084, where the camera put it',
    );
    expect(camera.length, greaterThan(64 * 1024));

    expect(
      imagePixelSizeIn(write('camera.jpg', camera)),
      const ImagePixelSize(4032, 3024),
    );
  });

  test('a camera JPEG cut before its frame header is not identified', () {
    final Uint8List camera = cameraLikeJpeg(width: 4032, height: 3024);

    expect(
      imagePixelSizeIn(write('cut.jpg', camera.sublist(0, 64 * 1024))),
      isNull,
      reason: 'the app4 segment declares more bytes than the file holds',
    );
    expect(
      imagePixelSizeIn(write('cut-late.jpg', camera.sublist(0, 82083))),
      isNull,
      reason: 'the frame header starts one byte after the file ends',
    );
  });

  test(
    'a segment whose declared length runs past the end is not identified',
    () {
      // An APP1 that declares 45313 bytes in a file that holds twenty of them.
      expect(
        imagePixelSizeIn(
          write('overrun.jpg', <int>[
            0xFF, 0xD8, //
            0xFF, 0xE1, 0xB1, 0x01,
            ...List<int>.filled(18, 0x00),
          ]),
        ),
        isNull,
      );
      // A declared length below two is not a segment either.
      expect(
        imagePixelSizeIn(
          write('no-length.jpg', <int>[0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x01]),
        ),
        isNull,
      );
    },
  );

  test('a JPEG that reaches its scan without a frame is not identified', () {
    final List<int> bytes = <int>[0xFF, 0xD8];
    bytes.addAll(<int>[0xFF, 0xE0, 0x00, 0x10]);
    bytes.addAll(List<int>.filled(14, 0x00));
    bytes.addAll(<int>[0xFF, 0xDA, 0x00, 0x0C]);
    bytes.addAll(List<int>.filled(10, 0x00));
    bytes.addAll(frameHeader(width: 64, height: 48));

    // The frame-sized bytes are exactly where the start-of-scan segment leads,
    // and are not read: no frame header comes after a scan.
    expect(bytes.sublist(34, 36), <int>[0xFF, 0xC0]);
    expect(imagePixelSizeIn(write('scan-start.jpg', bytes)), isNull);
  });

  test('a JPEG is walked through many segments, and abandoned past them', () {
    List<int> withEmptySegments(int count) {
      final List<int> bytes = <int>[0xFF, 0xD8];
      for (var i = 0; i < count; i++) {
        bytes.addAll(<int>[0xFF, 0xE0, 0x00, 0x02]);
      }
      bytes.addAll(frameHeader(width: 64, height: 48));
      return bytes;
    }

    // A hundred empty segments are walked, not skipped.
    expect(
      imagePixelSizeIn(write('many.jpg', withEmptySegments(100))),
      const ImagePixelSize(64, 48),
    );
    // Thousands are not: the walk is bounded, and a file that declares them —
    // frame header or not — is answered null rather than read to no end.
    expect(
      imagePixelSizeIn(write('endless.jpg', withEmptySegments(50000))),
      isNull,
    );
  });

  test('a file that is neither answers with no size', () {
    expect(
      imagePixelSizeIn(write('notes.txt', _bytes('not an image at all'))),
      isNull,
    );
    expect(imagePixelSizeIn(write('empty', <int>[])), isNull);
  });

  test('an image that declares no pixel answers with no size', () {
    // A zero in either direction is not a size: the conversion to Core's units
    // divides by the pixel count.
    expect(
      imagePixelSizeIn(write('zero.png', _png(width: 0, height: 100))),
      isNull,
    );
    expect(
      imagePixelSizeIn(write('zero-height.png', _png(width: 100, height: 0))),
      isNull,
    );
    expect(
      imagePixelSizeIn(write('zero.jpg', _jpeg(width: 0, height: 100))),
      isNull,
    );
  });

  test('a truncated header answers with no size', () {
    expect(
      imagePixelSizeIn(
        write('cut.png', _png(width: 800, height: 1200).sublist(0, 12)),
      ),
      isNull,
      reason: 'a PNG signature without its IHDR is not a size',
    );
    expect(
      imagePixelSizeIn(
        write('cut.jpg', _jpeg(width: 800, height: 1200).sublist(0, 12)),
      ),
      isNull,
      reason: 'a JPEG cut before its frame header is not a size',
    );
  });

  test('a JPEG that ends before any frame answers with no size', () {
    expect(
      imagePixelSizeIn(write('empty.jpg', <int>[0xFF, 0xD8, 0xFF, 0xD9])),
      isNull,
    );
  });

  test('a file that is not there is the caller\'s to report', () {
    expect(
      () => imagePixelSizeIn(File(p.join(work.path, 'nothing-here.jpg'))),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('the size is a value', () {
    expect(const ImagePixelSize(10, 20), const ImagePixelSize(10, 20));
    expect(const ImagePixelSize(10, 20), isNot(const ImagePixelSize(20, 10)));
    expect(const ImagePixelSize(10, 20).toString(), 'ImagePixelSize(10x20)');
  });

  group('the EXIF orientation', () {
    test('a JPEG that declares a quarter turn is read as such', () {
      // A real file with a real EXIF segment, written from bytes by the test
      // (`decodable_image.dart`): an `APP1` holding `Exif`, a little-endian
      // TIFF header and the `Orientation` tag.
      for (final int orientation in <int>[1, 3, 6, 8]) {
        final File image = write(
          'turned-$orientation.jpg',
          decodableJpeg(width: 16, height: 8, exifOrientation: orientation),
        );

        expect(imageExifOrientationIn(image), orientation);
      }
    });

    test('a file that declares none answers with none', () {
      // A JPEG with no EXIF, a PNG, a PDF and a file that is not an image: none
      // of them carries an orientation, and none is mistaken for one that does.
      expect(
        imageExifOrientationIn(write('plain.jpg', _jpeg(width: 4, height: 2))),
        isNull,
      );
      expect(
        imageExifOrientationIn(
          write('photo.jpg', decodableJpeg(width: 8, height: 8)),
        ),
        isNull,
      );
      expect(
        imageExifOrientationIn(write('scan.png', _png(width: 4, height: 2))),
        isNull,
      );
      expect(
        imageExifOrientationIn(write('scan.pdf', _bytes('%PDF-1.7\n'))),
        isNull,
      );
      expect(
        imageExifOrientationIn(write('notes.txt', _bytes('nothing'))),
        isNull,
      );
    });

    test('an APP1 that is not EXIF is walked past', () {
      // A camera writes XMP in an `APP1` as well as EXIF, and the walk has to
      // read the segment's own signature instead of taking the first `APP1` for
      // an orientation.
      final List<int> bytes = <int>[0xFF, 0xD8];
      bytes.addAll(
        _applicationSegment(0xE1, _bytes('http://ns.adobe.com/xap/')),
      );
      bytes.addAll(_exifApp1(8));
      bytes.addAll(frameHeader(width: 64, height: 48));

      expect(imageExifOrientationIn(write('xmp-first.jpg', bytes)), 8);
    });

    test('a big-endian TIFF header is read too', () {
      final List<int> bytes = <int>[0xFF, 0xD8];
      bytes.addAll(_exifApp1(6, bigEndian: true));
      bytes.addAll(frameHeader(width: 64, height: 48));

      expect(imageExifOrientationIn(write('big-endian.jpg', bytes)), 6);
    });

    test('a tag outside the eight values is not an orientation', () {
      final List<int> bytes = <int>[0xFF, 0xD8];
      bytes.addAll(_exifApp1(9));
      bytes.addAll(frameHeader(width: 64, height: 48));

      expect(imageExifOrientationIn(write('ninth.jpg', bytes)), isNull);
    });

    test('a truncated or corrupt EXIF answers with no orientation', () {
      // Cut inside the segment: the signature is there and the IFD is not.
      final List<int> exif = _exifApp1(6);
      final List<int> cut = <int>[0xFF, 0xD8, ...exif.sublist(0, 10)];
      expect(imageExifOrientationIn(write('cut.jpg', cut)), isNull);

      // A segment whose declared length runs past the end of the file.
      expect(
        imageExifOrientationIn(
          write('overrun.jpg', <int>[
            0xFF, 0xD8, //
            0xFF, 0xE1, 0xB1, 0x01,
            ...List<int>.filled(18, 0x00),
          ]),
        ),
        isNull,
      );

      // An `Exif` signature and then a TIFF header whose byte order is neither.
      final List<int> neither = <int>[0xFF, 0xD8];
      neither.addAll(
        _applicationSegment(0xE1, <int>[
          ...'Exif'.codeUnits, 0x00, 0x00, //
          0x58, 0x58, 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00,
        ]),
      );
      neither.addAll(frameHeader(width: 64, height: 48));
      expect(imageExifOrientationIn(write('neither.jpg', neither)), isNull);
    });

    test('the displayed size exchanges the sides for a quarter turn', () {
      const ImagePixelSize stored = ImagePixelSize(4032, 3024);

      // The four tags that turn the picture a quarter turn round.
      for (final int orientation in <int>[5, 6, 7, 8]) {
        expect(orientationExchangesAxes(orientation), isTrue);
        expect(
          displayedImageSize(stored, orientation),
          const ImagePixelSize(3024, 4032),
        );
      }
      // And the four that do not: as stored, or mirrored, or half a turn.
      for (final int? orientation in <int?>[null, 1, 2, 3, 4]) {
        expect(
          displayedImageSize(stored, orientation),
          stored,
          reason: 'orientation $orientation does not exchange the sides',
        );
      }
      expect(orientationExchangesAxes(1), isFalse);
      expect(orientationExchangesAxes(9), isFalse);
    });
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
  bytes.addAll(frameHeader(width: width, height: height));
  return Uint8List.fromList(bytes);
}

void _writeInt(Uint8List bytes, int offset, int value) {
  bytes[offset] = (value >> 24) & 0xFF;
  bytes[offset + 1] = (value >> 16) & 0xFF;
  bytes[offset + 2] = (value >> 8) & 0xFF;
  bytes[offset + 3] = value & 0xFF;
}

/// An application segment of [marker] carrying [payload].
List<int> _applicationSegment(int marker, List<int> payload) {
  final int length = payload.length + 2;
  return <int>[
    0xFF, marker, (length >> 8) & 0xFF, length & 0xFF, //
    ...payload,
  ];
}

/// An `APP1` segment holding an EXIF `Orientation` tag: the `Exif` signature, a
/// TIFF header in the byte order asked for, one IFD entry, and no second IFD.
///
/// It is the same structure `decodable_image.dart` writes into the pictures a
/// decoder opens; here it is built on its own so that a file which is not a
/// picture can carry a tag the walk has to read — or refuse.
List<int> _exifApp1(int orientation, {bool bigEndian = false}) {
  List<int> order(int value, int size) => <int>[
    for (
      var shift = bigEndian ? size - 1 : 0;
      bigEndian ? shift >= 0 : shift < size;
      bigEndian ? shift-- : shift++
    )
      (value >> (shift * 8)) & 0xFF,
  ];
  return _applicationSegment(0xE1, <int>[
    ...'Exif'.codeUnits, 0x00, 0x00, //
    ...(bigEndian ? <int>[0x4D, 0x4D] : <int>[0x49, 0x49]),
    ...order(42, 2), // the TIFF magic
    ...order(8, 4), // the first IFD starts right after the header
    ...order(1, 2), // one entry
    ...order(0x0112, 2), // Orientation
    ...order(3, 2), // SHORT
    ...order(1, 4), // one value
    ...order(orientation, 2), 0x00, 0x00, // and the value itself
    ...order(0, 4), // no second IFD
  ]);
}
