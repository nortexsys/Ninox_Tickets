import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:paperdrop/adapters/intake/incoming_document.dart';
import 'package:paperdrop/adapters/storage/app_storage.dart';
import 'package:paperdrop/intake/document_intake.dart';
import 'package:paperdrop/intake/intake_failure.dart';
import 'package:paperdrop/intake/intake_result.dart';

import 'synthetic_documents.dart';

/// The platform, replaced by what a test decides (design §1: no test needs a
/// device).

/// Storage over a directory the test owns.
class TemporaryStorage implements AppStorage {
  const TemporaryStorage(this.root);

  final Directory root;

  @override
  Future<Directory> documentsDirectory() async => root;
}

/// An intake over a temporary directory.
///
/// Real file work, so it belongs in a plain `test`, where the clock is real:
/// `test/intake/document_intake_test.dart`.
DocumentIntake temporaryIntake(Directory root, {Random? random}) =>
    DocumentIntake(
      storage: TemporaryStorage(root),
      random: random ?? Random(20260930),
    );

/// The store, answering at once, for the widget tests.
///
/// Widget tests run on a fake clock, and the real store's copy is a chain of
/// real file operations that a fake clock cannot advance. This double answers
/// without touching the disk, but it does read the whole stream and compute the
/// real SHA-256 of it, so a widget test still proves that the bytes the picker
/// or the share produced are the bytes that reached the store.
class FakeDocumentIntake extends DocumentIntake {
  FakeDocumentIntake({required this.root, Random? random})
    : super(
        storage: TemporaryStorage(root),
        random: random ?? Random(20260930),
      );

  final Directory root;

  /// How many documents reached the store. Zero is what "nothing was stored"
  /// means.
  int calls = 0;

  /// The sources the store was handed, in order.
  final List<IntakeSource> sources = <IntakeSource>[];

  /// Makes the next intake fail, as the storage or the copy can.
  IntakeFailure? failure;

  @override
  Future<IntakeResult> intake(
    IntakeSource source,
    Stream<List<int>> bytes, {
    String? filename,
    String? mediaType,
  }) async {
    calls++;
    sources.add(source);
    final IntakeFailure? refuses = failure;
    if (refuses != null) {
      throw refuses;
    }
    // The one rule of the real store that the screen depends on: a document is
    // accepted only as one of the three media types.
    final String resolved =
        DocumentIntake.resolveMediaType(
          mediaType: mediaType,
          filename: filename,
        ) ??
        '';
    if (!IntakeResult.supportedMediaTypes.contains(resolved)) {
      throw const IntakeFailure(IntakeFailureCode.unsupportedMediaType);
    }
    final List<int> copy = <int>[];
    await for (final List<int> chunk in bytes) {
      copy.addAll(chunk);
    }
    final String docId = 'document-$calls';
    return IntakeResult(
      docId: docId,
      source: source,
      mediaType: resolved,
      byteLength: copy.length,
      sha256: sha256.convert(copy).toString(),
      storedPath: <String>[
        root.path,
        DocumentIntake.originalsFolder,
        docId,
        'original.pdf',
      ].join(Platform.pathSeparator),
    );
  }
}

/// The picker, answering with what the test put in it.
class FakeFilePickerSource implements FilePickerSource {
  FakeFilePickerSource({this.document});

  /// What the next pick returns; null stands for the user closing the dialog.
  IncomingDocument? document;

  /// What the next pick throws, if anything.
  Object? error;

  /// How many times the picker was asked.
  int calls = 0;

  @override
  Future<IncomingDocument?> pick() async {
    calls++;
    final Object? failure = error;
    if (failure != null) {
      throw failure;
    }
    return document;
  }
}

/// Share-in, driven by the test.
class FakeShareInSource implements ShareInSource {
  final StreamController<List<IncomingDocument>> _shares =
      StreamController<List<IncomingDocument>>();

  /// How many times the pipeline listened to share-in.
  int listeners = 0;

  /// Hands a share — one document, several, or none — to the pipeline.
  void share(List<IncomingDocument> documents) => _shares.add(documents);

  /// A share that fails on its way in.
  void fail(Object error) => _shares.addError(error);

  @override
  Stream<List<IncomingDocument>> documents() {
    listeners++;
    return _shares.stream;
  }

  Future<void> close() => _shares.close();
}

/// One incoming document over a fixture, in chunks, the way a platform service
/// delivers it.
IncomingDocument incomingDocument(
  IntakeSource source,
  List<int> bytes, {
  String? mediaType,
  String? filename,
}) => IncomingDocument(
  source: source,
  bytes: chunksOf(bytes),
  mediaType: mediaType,
  filename: filename,
);
