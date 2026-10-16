import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/adapters/ocr/image_decoder.dart';
import 'package:path/path.dart' as p;

import '../../tool/decodable_image.dart';

/// The platform's decoder, on the host (`implement-photo-passes`, design §3).
///
/// **What this proves.** The two things design §3 makes the lane state rather
/// than assume.
///
/// 1. **That the decoder gives an RGBA buffer at a target size**, with no
///    dependency added: an image is decoded at two sizes and the buffer's size
///    and content are read back.
/// 2. **That it applies the EXIF orientation of a JPEG.** A photograph whose
///    tag turns it a quarter turn round comes back turned — with its sides
///    exchanged *and* its content in the place the tag puts it, which is the
///    difference between a decoder that applies the orientation and one that
///    only reports a size. The image used is written by the test from bytes
///    (`decodable_image.dart`): a flat block survives the quantisation of ones
///    exactly, so which half of the picture is on top is a fact and not a
///    threshold.
///
/// **Where it stops.** It runs the engine's decoder on the host. The device
/// decodes through the same `dart:ui` code path, and what the device adds is the
/// assertion the harness makes: that the passes of one photograph agree with
/// each other, which a decoder that ignored the tag would not achieve (design
/// §3, `app/integration_test/ocr_eval_test.dart`).
///
/// **What never enters the repository.** Every image here is built from bytes,
/// with invented flat colours and an EXIF tag the test writes itself. No file of
/// the private corpus is read, copied or referenced.
void main() {
  late Directory work;

  setUp(() {
    work = Directory.systemTemp.createTempSync('paperdrop-decode-test');
  });

  tearDown(() {
    if (work.existsSync()) {
      work.deleteSync(recursive: true);
    }
  });

  /// Writes [bytes] under [name] and answers the file.
  File write(String name, Uint8List bytes) =>
      File(p.join(work.path, name))..writeAsBytesSync(bytes);

  const PlatformImageDecoder decoder = PlatformImageDecoder();

  test('a PNG decodes to an RGBA buffer, at its own size and at a target', () async {
    final File image = write(
      'photo.png',
      decodablePng(width: 800, height: 600, grey: 200),
    );

    // No target: the image's own size, four bytes per pixel, opaque, and the
    // grey level the file was written with.
    final DecodedImage native = await decoder.decode(
      image,
      targetWidth: null,
      targetHeight: null,
    );
    expect(native.width, 800);
    expect(native.height, 600);
    expect(native.pixels, hasLength(800 * 600 * 4));
    expect(native.pixels.sublist(0, 4), <int>[200, 200, 200, 255]);
    expect(native.pixels.sublist(native.pixels.length - 4), <int>[
      200,
      200,
      200,
      255,
    ]);

    // A target: the pass's `p3-lo` size for that image, and the bytes are that
    // size and not the file's.
    final DecodedImage scaled = await decoder.decode(
      image,
      targetWidth: 560,
      targetHeight: 420,
    );
    expect(scaled.width, 560);
    expect(scaled.height, 420);
    expect(scaled.pixels, hasLength(560 * 420 * 4));
    expect(scaled.pixels.sublist(0, 4), <int>[200, 200, 200, 255]);

    // Upscaling too, which is what `p4-hi` needs of a decoded image: the codec
    // is asked to enlarge and does.
    final DecodedImage enlarged = await decoder.decode(
      image,
      targetWidth: 1120,
      targetHeight: 840,
    );
    expect(enlarged.width, 1120);
    expect(enlarged.height, 840);
  });

  test('a JPEG is decoded too, and with its own grey level', () async {
    final File image = write(
      'photo.jpg',
      decodableJpeg(width: 64, height: 48, grey: 128),
    );

    final DecodedImage decoded = await decoder.decode(
      image,
      targetWidth: null,
      targetHeight: null,
    );

    expect(decoded.width, 64);
    expect(decoded.height, 48);
    expect(decoded.pixels, hasLength(64 * 48 * 4));
    expect(decoded.pixels.sublist(0, 4), <int>[128, 128, 128, 255]);
  });

  group('the EXIF orientation', () {
    test('a quarter turn round is applied, and its content is turned', () async {
      // Stored as 16 by 8, its left half dark (64) and its right half light
      // (192), and a tag that turns the picture a quarter turn clockwise to
      // display it.
      final File image = write(
        'turned.jpg',
        decodableJpeg(
          width: 16,
          height: 8,
          blockGreys: <int>[64, 192],
          exifOrientation: 6,
        ),
      );

      final DecodedImage decoded = await decoder.decode(
        image,
        targetWidth: null,
        targetHeight: null,
      );

      // The sides are exchanged: 16 by 8 stored is 8 by 16 shown.
      expect(decoded.width, 8);
      expect(decoded.height, 16);
      // And the dark half is on top, which is where turning the stored picture
      // a quarter turn clockwise puts its left half. A decoder that ignored the
      // tag would answer 16 by 8 with the dark half on the left.
      expect(_at(decoded, 0, 0), <int>[64, 64, 64, 255]);
      expect(_at(decoded, 7, 0), <int>[64, 64, 64, 255]);
      expect(_at(decoded, 0, 15), <int>[192, 192, 192, 255]);
      expect(_at(decoded, 7, 15), <int>[192, 192, 192, 255]);
    });

    test('turning the other way puts the same half at the other end', () async {
      // The other quarter turn round (270 clockwise, which is 90 the other
      // way): the stored left half ends up at the bottom.
      final File image = write(
        'turned-the-other-way.jpg',
        decodableJpeg(
          width: 16,
          height: 8,
          blockGreys: <int>[64, 192],
          exifOrientation: 8,
        ),
      );

      final DecodedImage decoded = await decoder.decode(
        image,
        targetWidth: null,
        targetHeight: null,
      );

      expect(decoded.width, 8);
      expect(decoded.height, 16);
      expect(_at(decoded, 0, 0), <int>[192, 192, 192, 255]);
      expect(_at(decoded, 0, 15), <int>[64, 64, 64, 255]);
    });

    test('all four quarter turns exchange the sides', () async {
      // 5 and 7 are the mirrored quarter turns: the picture has to come back
      // shown, sides exchanged, whatever the mirroring does to its content.
      for (final int orientation in <int>[5, 6, 7, 8]) {
        final File image = write(
          'turned-$orientation.jpg',
          decodableJpeg(width: 16, height: 8, exifOrientation: orientation),
        );

        final DecodedImage decoded = await decoder.decode(
          image,
          targetWidth: null,
          targetHeight: null,
        );

        expect(
          <int>[decoded.width, decoded.height],
          <int>[8, 16],
          reason: 'orientation $orientation is shown a quarter turn round',
        );
      }
    });

    test('no tag, and the unrotated tag, leave the picture as it is', () async {
      for (final int? orientation in <int?>[null, 1]) {
        final File image = write(
          'plain-$orientation.jpg',
          decodableJpeg(
            width: 16,
            height: 8,
            blockGreys: <int>[64, 192],
            exifOrientation: orientation,
          ),
        );

        final DecodedImage decoded = await decoder.decode(
          image,
          targetWidth: null,
          targetHeight: null,
        );

        expect(decoded.width, 16);
        expect(decoded.height, 8);
        expect(_at(decoded, 0, 0), <int>[64, 64, 64, 255]);
        expect(_at(decoded, 15, 0), <int>[192, 192, 192, 255]);
      }
    });

    test('a target size is in the displayed space, as the passes need', () async {
      // The stored picture is 16 by 8 and is shown as 8 by 16. A pass that asks
      // for half of what is displayed asks for 4 by 8 and gets 4 by 8 — not 4
      // by 8 pixels of a picture that then turns into 8 by 4.
      final File image = write(
        'turned.jpg',
        decodableJpeg(width: 16, height: 8, exifOrientation: 6),
      );

      final DecodedImage decoded = await decoder.decode(
        image,
        targetWidth: 4,
        targetHeight: 8,
      );

      expect(decoded.width, 4);
      expect(decoded.height, 8);
    });
  });

  test('the file is read and never written', () async {
    final File image = write(
      'photo.jpg',
      decodableJpeg(width: 32, height: 32, exifOrientation: 6),
    );
    final String before = sha256.convert(image.readAsBytesSync()).toString();

    await decoder.decode(image, targetWidth: 16, targetHeight: 16);

    expect(
      sha256.convert(image.readAsBytesSync()).toString(),
      before,
      reason: 'decoding a photograph must not write to it (ADR-015)',
    );
  });

  test('a file that is not an image is the decoder\'s to refuse', () async {
    final File other = File(p.join(work.path, 'notes.txt'))
      ..writeAsStringSync('this is not a picture and no codec will read it');

    await expectLater(
      decoder.decode(other, targetWidth: null, targetHeight: null),
      throwsA(isA<Exception>()),
    );
  });
}

/// The four bytes of the pixel at ([x], [y]) of [image], which is RGBA.
List<int> _at(DecodedImage image, int x, int y) {
  final int index = (y * image.width + x) * 4;
  return image.pixels.sublist(index, index + 4);
}
