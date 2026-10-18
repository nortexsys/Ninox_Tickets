/// The document thumbnail and the full-screen view of it — the half of FR-REV-003 the MVP builds.
///
/// Requirement served: FR-REV-003 (`review-screen/thumbnail-with-the-read-region`) for the
/// thumbnail and the full-screen view, in the cut the plan makes: *thumbnail and full-screen view
/// only*. The read region, the box around it and the zoom to it are R1 and are not built here
/// (design §6: *no box, no zoom*), so nothing in this file reads a coordinate or draws an overlay.
///
/// **What it shows.** The thumbnail the entry already carries — a path the app wrote, never a name
/// the user's document came with (design §3 of the intake) — and, on a tap, the same file full
/// screen. A thumbnail that is gone, or that cannot be decoded, draws the plain placeholder rather
/// than an error: `file-retention` may have released a file, and a review screen that fails on a
/// missing picture would be a screen nobody could save from.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

/// The thumbnail of one document, tappable to see it full screen.
class ReviewThumbnail extends StatelessWidget {
  /// Builds the thumbnail of the file at [path], or the placeholder when there is none.
  const ReviewThumbnail({super.key, required this.path});

  /// The thumbnail's path, or `null` when the entry has no thumbnail yet.
  final String? path;

  /// The thumbnail itself, so a test can tap it.
  static const Key thumbnailKey = Key('review-thumbnail');

  /// The full-screen view, so a test can find what the tap opened.
  static const Key fullScreenKey = Key('review-document-view');

  /// The height of the thumbnail band. Above the platform's 48 dp minimum tap target (NFR-ACC-001).
  static const double height = 120;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? path = this.path;
    if (path == null) {
      return _placeholder(context, l10n);
    }
    return Semantics(
      button: true,
      label: l10n.reviewThumbnailAction,
      child: InkWell(
        key: thumbnailKey,
        onTap: () => Navigator.of(context).push(ReviewDocumentView.route(path)),
        child: SizedBox(
          height: height,
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            errorBuilder: (context, error, trace) =>
                _placeholder(context, l10n),
          ),
        ),
      ),
    );
  }

  /// What is drawn when there is no picture to draw, for either reason.
  Widget _placeholder(BuildContext context, AppLocalizations l10n) => SizedBox(
    height: height,
    child: Center(
      child: Text(
        l10n.reviewNoThumbnail,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  );
}

/// The document, full screen: the same file, as large as the screen allows.
///
/// No zoom and no overlay: the zooming and the highlighted read region belong to R1 (design §6).
class ReviewDocumentView extends StatelessWidget {
  /// Builds the view over the file at [path].
  const ReviewDocumentView({super.key, required this.path});

  /// The route this view is pushed on.
  static Route<void> route(String path) => MaterialPageRoute<void>(
    builder: (BuildContext context) => ReviewDocumentView(path: path),
  );

  /// The path of the file the view shows.
  final String path;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      key: ReviewThumbnail.fullScreenKey,
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.reviewThumbnailAction),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.reviewCloseAction,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Center(
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (context, error, trace) => Text(l10n.reviewNoThumbnail),
        ),
      ),
    );
  }
}
