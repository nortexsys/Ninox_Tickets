/// Deleting a discarded document's local capture — the whole folder, and nothing else.
///
/// Requirement served: FR-REV-011 (`review-screen/discard-a-document`) — a discard creates no
/// record, leaves no history entry and deletes the local file — with the part of
/// `document-history/document-states` that says a discard deletes the entry and its folder instead
/// of moving it to a state. Design §5 of `implement-review-screen` names the mechanism: *the whole
/// folder*.
///
/// **Why the folder is what a discard removes.** `FileHistoryStore` keeps one folder per document —
/// `entry.json`, the stored original and the thumbnail — and `list()` reports a document by the
/// folders it finds. Deleting the folder therefore leaves no entry, no original and no thumbnail
/// behind in one operation, and there is no window in which an entry without its file, or a file
/// without its entry, is left for the history to show. `HistoryStore` itself exposes
/// `deleteOriginal` only, and that one refuses every state but `sent` on purpose
/// (`file-retention`): it is the release that follows a confirmed send, not a discard.
///
/// **What it will not do.** It deletes one document's folder under the root it was given and
/// nothing above it, and it refuses any identifier that is not in the shape `DocumentIntake`
/// assigns — the identifier names the folder, so an identifier with a separator in it would be a
/// path out of the document root (design §3 of the store's change).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Where a discarded document's local capture is deleted from.
abstract interface class CaptureDiscard {
  /// Deletes the folder of [docId]: its entry, its stored original and its thumbnail.
  ///
  /// A document whose folder is already gone is not a failure: the capture is not there, which is
  /// what a discard asks for. A file system that refuses throws an [IOException], because a discard
  /// that silently left the document's file behind would be the failure this requirement exists to
  /// prevent.
  Future<void> deleteCapture(String docId);
}

/// The file-backed [CaptureDiscard]: the document folders under one root.
///
/// The root is the folder the store and the intake share — on the device,
/// `DocumentIntake.originalsFolder` under the application's documents directory — so a test deletes
/// folders it owns and no test needs a device (design §1).
final class FileCaptureDiscard implements CaptureDiscard {
  /// Builds the discard over the folder that holds one folder per document.
  const FileCaptureDiscard(this.root);

  /// The folder `DocumentIntake` put each document's folder in.
  final Directory root;

  /// `DocumentIntake`'s identifier shape: 128 bits as lowercase hex (design §3).
  static final RegExp _docIdPattern = RegExp(r'^[0-9a-f]{32}$');

  @override
  Future<void> deleteCapture(String docId) async {
    if (!_docIdPattern.hasMatch(docId)) {
      throw ArgumentError.value(
        docId,
        'docId',
        'must be the 32 hex digits DocumentIntake assigns: the identifier also '
            'names the document folder',
      );
    }
    final Directory folder = Directory(p.join(root.path, docId));
    if (await folder.exists()) {
      await folder.delete(recursive: true);
    }
  }

  @override
  String toString() => 'FileCaptureDiscard(${root.path})';
}
