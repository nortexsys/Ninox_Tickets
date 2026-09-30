import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/intake/document_intake.dart';
import 'package:paperdrop/intake/intake_failure.dart';
import 'package:paperdrop/intake/intake_result.dart';
import 'package:path/path.dart' as p;

import '../tool/fakes.dart';
import '../tool/synthetic_documents.dart';

/// The store of design §3: byte-stream copy, double SHA-256, a content-free
/// identifier and path, the media-type check, and no partial file on error.
void main() {
  late Directory root;
  late DocumentIntake intake;

  setUp(() {
    root = Directory.systemTemp.createTempSync('paperdrop-intake-test');
    // Seeded: the identifier is random, but a test that reads it should not be.
    intake = temporaryIntake(root);
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  test('[capture-intake/received-files-are-attached-byte-for-byte] '
      'the attachment is the input', () async {
    final Uint8List pdf = syntheticPdf();
    final String expectedDigest = sha256.convert(pdf).toString();

    final IntakeResult result = await intake.intake(
      IntakeSource.picker,
      chunksOf(pdf),
      filename: 'invoice.pdf',
      mediaType: 'application/pdf',
    );

    // Digests are compared, never inspected: that is the acceptance condition
    // of the requirement. The "after extraction" half of the scenario needs an
    // extraction stage, which this change does not have (T1.15).
    expect(result.sha256, expectedDigest);
    expect(
      sha256.convert(File(result.storedPath).readAsBytesSync()).toString(),
      expectedDigest,
    );
    expect(File(result.storedPath).readAsBytesSync(), pdf);
    expect(result.byteLength, pdf.length);
  });

  test('an e-invoice XML in the document survives the store', () async {
    // Names the `received-files-are-attached-byte-for-byte` scenario *an
    // embedded e-invoice XML survives*, and proves its first half: the payload
    // is still in the stored copy, because the store compares digest with digest
    // and never re-writes the file it was handed. The second half — that it can
    // still be extracted — is T1.15's reader and the attachment is T1.11's, so
    // the scenario carries no tag yet.
    const String xml = '<?xml version="1.0"?><CrossIndustryInvoice/>';
    final Uint8List pdf = syntheticPdf(trailingPayload: xml);
    final String expectedDigest = sha256.convert(pdf).toString();

    final IntakeResult result = await intake.intake(
      IntakeSource.shareIn,
      chunksOf(pdf),
      mediaType: 'application/pdf',
    );

    expect(result.sha256, expectedDigest);
    expect(
      utf8.decode(File(result.storedPath).readAsBytesSync()),
      contains(xml),
    );
  });

  test('reading the stored copy never changes it', () async {
    // A partial proof of `reading never writes`: no extraction stage exists in
    // this change, so what can be shown is that opening the stored copy the way
    // T1.15's reader will — read-only, no temporary re-save — leaves the file
    // and its digest exactly as the intake left them.
    final Uint8List pdf = syntheticPdf();
    final IntakeResult result = await intake.intake(
      IntakeSource.picker,
      chunksOf(pdf),
      mediaType: 'application/pdf',
    );
    final DateTime written = File(result.storedPath).lastModifiedSync();

    await File(result.storedPath).openRead().drain<void>();

    expect(
      sha256.convert(File(result.storedPath).readAsBytesSync()).toString(),
      result.sha256,
    );
    expect(File(result.storedPath).lastModifiedSync(), written);
  });

  test('the three sources land in the same shape', () async {
    for (final IntakeSource source in IntakeSource.values) {
      final IntakeResult result = await intake.intake(
        source,
        chunksOf(syntheticPdf()),
        mediaType: 'application/pdf',
      );
      expect(result.source, source);
      expect(result.mediaType, 'application/pdf');
      expect(result.docId, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(p.split(p.relative(result.storedPath, from: root.path)), <String>[
        DocumentIntake.originalsFolder,
        result.docId,
        'original.pdf',
      ]);
    }
  });

  test('the identifier is content-free and the path carries no name', () async {
    const String name = 'ACME-2026-0042 supplier invoice.pdf';
    final IntakeResult first = await intake.intake(
      IntakeSource.picker,
      chunksOf(syntheticPdf()),
      filename: name,
      mediaType: 'application/pdf',
    );
    final IntakeResult second = await intake.intake(
      IntakeSource.picker,
      chunksOf(syntheticPdf()),
      filename: name,
      mediaType: 'application/pdf',
    );

    expect(first.docId, isNot(second.docId));
    expect(first.storedPath, isNot(second.storedPath));
    for (final String piece in name.split(' ')) {
      expect(first.storedPath, isNot(contains(piece)));
    }
  });

  test('the stored copy has the extension of its media type', () async {
    final Map<String, String> expectedExtension = <String, String>{
      'application/pdf': 'original.pdf',
      'image/jpeg': 'original.jpg',
      'image/png': 'original.png',
    };
    final Map<String, Uint8List> fixtures = <String, Uint8List>{
      'application/pdf': syntheticPdf(),
      'image/jpeg': syntheticJpeg(),
      'image/png': syntheticPng(),
    };
    for (final String mediaType in expectedExtension.keys) {
      final IntakeResult result = await intake.intake(
        IntakeSource.picker,
        chunksOf(fixtures[mediaType]!),
        mediaType: mediaType,
      );
      expect(p.basename(result.storedPath), expectedExtension[mediaType]);
      expect(result.mediaType, mediaType);
    }
  });

  test('a media type outside the three is refused with its code, and nothing is stored', () async {
    await expectLater(
      intake.intake(
        IntakeSource.picker,
        chunksOf(syntheticPdf()),
        filename: 'scan.heic',
        mediaType: 'image/heic',
      ),
      throwsA(
        isA<IntakeFailure>().having(
          (IntakeFailure failure) => failure.code,
          'code',
          IntakeFailureCode.unsupportedMediaType,
        ),
      ),
    );
    await expectLater(
      intake.intake(
        IntakeSource.picker,
        chunksOf(syntheticPdf()),
        mediaType: 'application/zip',
      ),
      throwsA(
        isA<IntakeFailure>().having(
          (IntakeFailure failure) => failure.code,
          'code',
          IntakeFailureCode.unsupportedMediaType,
        ),
      ),
    );

    expect(_storedFiles(root), isEmpty);
  });

  test('a name is enough when the source declares no type, and a '
      'contradicted type falls back to it', () async {
    final IntakeResult byExtension = await intake.intake(
      IntakeSource.picker,
      chunksOf(syntheticJpeg()),
      filename: 'ticket.JPG',
    );
    expect(byExtension.mediaType, 'image/jpeg');
    expect(p.basename(byExtension.storedPath), 'original.jpg');

    final IntakeResult byFallback = await intake.intake(
      IntakeSource.shareIn,
      chunksOf(syntheticPdf()),
      filename: 'invoice.pdf',
      mediaType: 'application/octet-stream',
    );
    expect(byFallback.mediaType, 'application/pdf');
  });

  test('a stream that fails leaves no partial file behind', () async {
    // What a share-in source really does when the sharing application finishes
    // and the content URI's permission expires (design §8): the read fails
    // half-way through, and nothing may be left behind.
    Stream<List<int>> failing() async* {
      yield syntheticPdf().sublist(0, 32);
      throw const FileSystemException('the shared file is gone');
    }

    await expectLater(
      intake.intake(
        IntakeSource.shareIn,
        failing(),
        mediaType: 'application/pdf',
      ),
      throwsA(
        isA<IntakeFailure>().having(
          (IntakeFailure failure) => failure.code,
          'code',
          IntakeFailureCode.intakeFailed,
        ),
      ),
    );

    expect(_storedFiles(root), isEmpty);
  });

  test(
    'storage that cannot be written fails without throwing an Error',
    () async {
      final DocumentIntake blocked = DocumentIntake(
        storage: TemporaryStorage(
          Directory(p.join(root.path, 'originals', 'not-a-directory')),
        ),
        random: Random(20260930),
      );
      // A file where the folder should be: the copy cannot be written.
      final File obstacle = File(
        p.join(root.path, 'originals', 'not-a-directory'),
      );
      obstacle.parent.createSync(recursive: true);
      obstacle.writeAsStringSync('in the way');

      await expectLater(
        blocked.intake(
          IntakeSource.picker,
          chunksOf(syntheticPdf()),
          mediaType: 'application/pdf',
        ),
        throwsA(isA<IntakeFailure>()),
      );
      expect(obstacle.readAsStringSync(), 'in the way');
    },
  );

  test('an empty stream is stored as an empty document', () async {
    // Nothing refuses a zero-byte file: this change reads no document, and a
    // minimum size would be a validation rule no requirement states.
    final IntakeResult result = await intake.intake(
      IntakeSource.shareIn,
      const Stream<List<int>>.empty(),
      mediaType: 'application/pdf',
    );
    expect(result.byteLength, 0);
    expect(File(result.storedPath).readAsBytesSync(), isEmpty);
  });
}

/// Every file the store has kept, whether or not it created the folder.
List<FileSystemEntity> _storedFiles(Directory root) {
  final Directory originals = Directory(
    p.join(root.path, DocumentIntake.originalsFolder),
  );
  return originals.existsSync()
      ? originals.listSync(recursive: true)
      : <FileSystemEntity>[];
}
