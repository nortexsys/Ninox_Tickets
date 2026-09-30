import 'dart:io';

import 'package:paperdrop/adapters/intake/incoming_document.dart';
import 'package:paperdrop/intake/intake_failure.dart';
import 'package:paperdrop/intake/intake_result.dart';
import 'package:path/path.dart' as p;
import 'package:share_handler/share_handler.dart';

/// Share-in on Android (FR-CAP-008, design §3): `ACTION_SEND` and
/// `ACTION_SEND_MULTIPLE` with `application/pdf` and `image/*`, declared in the
/// manifest. No separate component is needed on this platform — the share-intent
/// filter is the whole of the Android half.
///
/// The platform side copies the shared content URI into the app's cache before
/// handing it over, so the copy into app storage happens immediately on receipt:
/// a content URI's grant can expire as soon as the sharing application finishes
/// (design §8), and the file has to be ours before that happens.
///
/// **Which package, and why.** Design §1 leaves the choice between
/// `share_handler` and `receive_sharing_intent` to whichever builds on Flutter
/// 3.47.5 with `minSdk` 24 and `compileSdk` 36. `receive_sharing_intent` 1.9.0
/// compiles against Android SDK 37 and the debug build fails on
/// `:app:checkDebugAarMetadata`; `share_handler` 0.0.25 (its Android package
/// against SDK 34) builds unchanged. This is the one the app ships.
class SharedIntentShareInSource implements ShareInSource {
  SharedIntentShareInSource({ShareHandlerPlatform? handler})
    : _handler = handler ?? ShareHandlerPlatform.instance;

  final ShareHandlerPlatform _handler;

  @override
  Stream<List<IncomingDocument>> documents() async* {
    final SharedMedia? initial;
    try {
      initial = await _handler.getInitialSharedMedia();
    } on Error {
      rethrow;
    } catch (_) {
      throw const IntakeFailure(IntakeFailureCode.intakeFailed);
    }

    if (initial != null) {
      // The share that started the application is handed over once, and then
      // consumed: storing it twice would create two records for one document.
      yield _documentsOf(initial);
      await _handler.resetInitialSharedMedia();
    }
    yield* _handler.sharedMediaStream.map(_documentsOf);
  }

  /// The documents of one share, in the order the platform gave them.
  ///
  /// A share that carries no file — a link, a piece of text — becomes an empty
  /// list rather than a document: this is a document intake, and the refusal is
  /// the capture screen's message, not a stored file. Nothing of the shared text
  /// is read or kept. A video or an audio file is not a document either (the
  /// MVP's `.msg`/`.eml` and video work is R1).
  List<IncomingDocument> _documentsOf(
    SharedMedia media,
  ) => (media.attachments ?? const <SharedAttachment?>[])
      .whereType<SharedAttachment>()
      .where(
        (SharedAttachment attachment) =>
            attachment.type == SharedAttachmentType.file ||
            attachment.type == SharedAttachmentType.image,
      )
      .map(
        (SharedAttachment attachment) => IncomingDocument(
          source: IntakeSource.shareIn,
          bytes: File(attachment.path).openRead(),
          // The plugin reports an attachment type, not a media type: the store
          // resolves it from the extension of the name the platform kept, and
          // accepts only the three.
          filename: p.basename(attachment.path),
        ),
      )
      .toList();
}
