/// Group 6 of the negative release checklist: **no mail-body byte** (Funcional §10.6, §1.2).
///
/// The non-goal: *the app never reads the body of a `.msg` / `.eml` message, only the document
/// attachment it carries*. The requirements it protects are
/// `product-invariants/never-read-message-body` (*only the document attachment the container
/// carries shall be used*), `capture-intake/mail-containers-ingest-attachments-only` (FR-CAP-006)
/// and FR-CAP-001's list of accepted inputs — with NFR-PRV-002 behind them: a message body is
/// somebody's correspondence, and none of it may be stored or sent.
///
/// **What this file proves**, against the real share-intake adapter over a fake platform:
///
/// * a share that carries a text body **and** one attachment hands over the attachment alone —
///   one document, the attachment's bytes, and no field of it derived from the body;
/// * a share that carries only text produces **no** document, rather than a document made of the
///   text: the shared text is never read;
/// * an audio or video attachment is not a document;
/// * a mail container (`.msg`, `.eml`, `message/rfc822`) is refused by the intake before anything
///   of it is stored — the container's bytes, body included, cannot enter the pipeline as a
///   document;
/// * no shipped source parses a mail container, and no declared dependency is a MIME or mail
///   parser.
///
/// **Where it stops.** Ingesting the **attachment inside** a `.msg`/`.eml` container is FR-CAP-006/
/// FR-CAP-007 work that the MVP does not have: `IntakeSource` says so in its own doc comment
/// (*the fourth path … is R1*). The negative half — that no body byte is read — is therefore
/// proved two ways: the share path reads no text, and the container is not accepted at all. When
/// the container path arrives, `capture-intake/mail-containers-ingest-attachments-only`'s two
/// scenarios become the tests here, and this file says so.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperdrop/adapters/intake/incoming_document.dart';
import 'package:paperdrop/adapters/intake/share_in_source.dart';
import 'package:paperdrop/intake/document_intake.dart';
import 'package:paperdrop/intake/intake_failure.dart';
import 'package:paperdrop/intake/intake_result.dart';
import 'package:share_handler/share_handler.dart';

import 'checklist_support.dart';

/// A correspondence body: the thing that may never be read, stored or sent.
const String _body =
    'Dear Sir, please find the invoice attached. Kind regards, a person.';

/// The platform's share handler, replaced by what a test decides.
///
/// It answers the *initial* share (the one that started the application) and a stream for shares
/// that arrive while it runs, exactly as the plugin's contract does — so the adapter under test is
/// the real one, and only the platform is doubled.
final class _FakeShareHandler extends ShareHandlerPlatform {
  /// The share that started the application, handed over once.
  SharedMedia? initial;

  final StreamController<SharedMedia> _stream =
      StreamController<SharedMedia>.broadcast();

  @override
  Future<SharedMedia?> getInitialSharedMedia() async => initial;

  @override
  Future<void> resetInitialSharedMedia() async {
    initial = null;
  }

  @override
  Stream<SharedMedia> get sharedMediaStream => _stream.stream;

  /// Closes the stream the adapter subscribes to.
  Future<void> close() => _stream.close();
}

/// A share attachment of [type] pointing at [path].
SharedAttachment _attachment(String path, SharedAttachmentType type) =>
    SharedAttachment(path: path, type: type);

/// The bytes a document's stream carries.
Future<List<int>> _bytesOf(IncomingDocument document) =>
    document.bytes.expand((List<int> chunk) => chunk).toList();

/// The attachments the source produced for [media].
Future<List<IncomingDocument>> _documentsOf(
  _FakeShareHandler handler,
  SharedMedia media,
) async {
  handler.initial = media;
  final SharedIntentShareInSource source = SharedIntentShareInSource(
    handler: handler,
  );
  return source.documents().first;
}

void main() {
  const String nonGoal = 'no mail-body byte';
  const String requirements =
      'product-invariants/never-read-message-body, FR-CAP-006, FR-CAP-001';

  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('release-checklist-share');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  test('[$nonGoal] a share of a body and one attachment hands over the '
      'attachment alone ($requirements)', () async {
    final File attachment = File('${root.path}/invoice.pdf');
    await attachment.writeAsBytes(<int>[37, 80, 68, 70, 45, 49]);
    final _FakeShareHandler handler = _FakeShareHandler();
    addTearDown(handler.close);

    final List<IncomingDocument> documents = await _documentsOf(
      handler,
      SharedMedia(
        content: _body,
        attachments: <SharedAttachment?>[
          _attachment(attachment.path, SharedAttachmentType.file),
        ],
      ),
    );

    expect(
      documents,
      hasLength(1),
      reason:
          '[$nonGoal] one document attachment is one document; the body is '
          'not a second input ($requirements)',
    );
    expect(documents.single.source, IntakeSource.shareIn);
    final List<int> bytes = await _bytesOf(documents.single);
    expect(
      bytes,
      await attachment.readAsBytes(),
      reason: '[$nonGoal] the attachment travels byte for byte (BR-17)',
    );
    expect(documents.single.filename, 'invoice.pdf');
    expect(
      '${documents.single.filename}${documents.single.mediaType}',
      isNot(contains('Dear Sir')),
      reason:
          '[$nonGoal] no field of the incoming document is derived from the '
          'message body ($requirements)',
    );
  });

  test('[$nonGoal] a share that carries only text produces no document '
      '($requirements)', () async {
    final _FakeShareHandler handler = _FakeShareHandler();
    addTearDown(handler.close);

    final List<IncomingDocument> documents = await _documentsOf(
      handler,
      SharedMedia(content: _body),
    );

    expect(
      documents,
      isEmpty,
      reason:
          '[$nonGoal] a link or a piece of text is not a document: nothing of '
          'the shared text is read, stored or kept ($requirements)',
    );
  });

  test('[$nonGoal] an audio or video attachment is not a document '
      '($requirements)', () async {
    final File video = File('${root.path}/clip.mp4');
    await video.writeAsBytes(<int>[0, 0, 0, 1]);
    final _FakeShareHandler handler = _FakeShareHandler();
    addTearDown(handler.close);

    final List<IncomingDocument> documents = await _documentsOf(
      handler,
      SharedMedia(
        content: _body,
        attachments: <SharedAttachment?>[
          _attachment(video.path, SharedAttachmentType.video),
          _attachment(video.path, SharedAttachmentType.audio),
        ],
      ),
    );

    expect(
      documents,
      isEmpty,
      reason:
          '[$nonGoal] only a file or an image is a document to this app '
          '($requirements)',
    );
  });

  test('[$nonGoal] a mail container is refused before any of it is stored '
      '(FR-CAP-006)', () async {
    // The container's own bytes would carry the body; nothing of it may enter the pipeline.
    expect(DocumentIntake.resolveMediaType(filename: 'message.msg'), isNull);
    expect(DocumentIntake.resolveMediaType(filename: 'MESSAGE.EML'), isNull);
    expect(
      DocumentIntake.resolveMediaType(mediaType: 'message/rfc822'),
      isNull,
      reason:
          '[$nonGoal] an RFC 822 message is not one of the three accepted '
          'media types ($requirements)',
    );

    final DocumentIntake intake = DocumentIntake(
      storage: TemporaryStorage(root),
    );
    await expectLater(
      intake.intake(
        IntakeSource.shareIn,
        Stream<List<int>>.value(_body.codeUnits),
        filename: 'message.eml',
      ),
      throwsA(
        isA<IntakeFailure>().having(
          (IntakeFailure failure) => failure.code,
          'code',
          IntakeFailureCode.unsupportedMediaType,
        ),
      ),
      reason:
          '[$nonGoal] the container is refused, so no part of the message '
          'reaches a stored file ($requirements)',
    );
    expect(
      root.listSync(recursive: true),
      isEmpty,
      reason:
          '[$nonGoal] a refused intake stores nothing at all ($requirements)',
    );
  });

  test('[$nonGoal] no shipped source parses a mail container ($requirements)', () {
    // Names: a parser, a MIME type, a library that would bring one.
    final List<TokenOccurrence> found = occurrencesIn(
      shippedSources(),
      <String>[
        'message/rfc822',
        'MimeMessage',
        'MimeMultipart',
        'parseMsg',
        'parseEml',
        'enough_mail',
        'mailparser',
      ],
    );
    expect(
      unauthorised(found, const <String, String>{}),
      isEmpty,
      reason:
          '[$nonGoal] a container parser in the shipped code is what would '
          'read a body byte ($requirements)',
    );

    // And the file names: a literal that ends in `.eml` or `.msg` is code that would open a
    // container rather than a document. The whole-word scan above cannot see these, because a
    // dot before `eml` is preceded by a letter — so the literals are read instead.
    final List<TokenOccurrence> containerNames = <TokenOccurrence>[
      for (final File file in shippedSources())
        for (final TokenOccurrence literal in literalsIn(file))
          if (_isContainerName(literal.token)) literal,
    ];
    expect(
      unauthorised(containerNames, const <String, String>{}),
      isEmpty,
      reason:
          '[$nonGoal] a `.eml`/`.msg` literal in shipped code is a container '
          'this app would open ($requirements)',
    );

    final List<TokenOccurrence> declared = occurrencesIn(
      pubspecFiles(),
      <String>['enough_mail', 'mailparser', 'mime_parser', 'message_rfc822'],
    );
    expect(
      unauthorised(declared, const <String, String>{}),
      isEmpty,
      reason:
          '[$nonGoal] a MIME or mail parser as a dependency is what would read '
          'a body byte ($requirements)',
    );
  });

  test('[$nonGoal] the scan catches a planted container parser', () async {
    // A guard is only worth having if it would catch the thing it is written for: a file name and
    // a MIME type, planted where the scans read, and the *comment* left alone.
    final File planted = File('${root.path}/planted.dart');
    await planted.writeAsString('''
const String path = 'message.eml';
// Nothing here reads a message/rfc822 body.
''');

    final List<TokenOccurrence> byName = <TokenOccurrence>[
      for (final TokenOccurrence literal in literalsIn(planted))
        if (_isContainerName(literal.token)) literal,
    ];
    expect(byName, hasLength(1));
    expect(byName.single.token, 'message.eml');

    final List<TokenOccurrence> byToken = findOccurrences(
      planted.readAsStringSync(),
      <String>['message/rfc822'],
      path: 'planted.dart',
    );
    expect(
      byToken,
      isEmpty,
      reason: 'the MIME type is only in a comment, and comments are masked',
    );
  });
}

/// Whether [literal] reads as a mail container's file name.
bool _isContainerName(String literal) {
  final String lowered = literal.toLowerCase();
  return lowered.endsWith('.eml') || lowered.endsWith('.msg');
}
