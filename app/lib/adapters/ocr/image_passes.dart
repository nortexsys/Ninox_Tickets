/// The image pass list of the photo route (`implement-photo-passes`,
/// design §2), beside the page list of `render_passes.dart`.
///
/// **What a pass of a photograph is.** A page is rendered several times because
/// it *can* be rendered: the same page at 150, 200 and 100 dots per inch, and
/// once more with its levels stretched (`implement-photo-route`, design §3). A
/// photograph has no page to render — it *is* the image — so its passes are
/// variations of the image itself: read as the file is, decoded and
/// grey-stretched, decoded smaller, decoded larger. Every pass is returned
/// separately and nothing chooses between them: which reading wins is Core's
/// consensus (FR-EXT-006), and a starting list "to be measured, not defended"
/// (design §2) is a list the screening T2.5 may trim, not a claim this layer
/// makes.
///
/// **Why a fixed list.** [ocrImagePasses] is one constant with stable ids, so
/// that two runs read the same passes under the same names and consensus
/// compares like with like. The list is injectable, so a test can hand the
/// adapter a list of its own, and a pass that fails is dropped and reported
/// rather than silently replaced: a shorter list is legal, and one pass alone
/// is legal too.
///
/// **`p1-native` is the pass that was there.** It reads the file as it is, the
/// way the adapter read every image before this change — ML Kit opens the file
/// itself, honouring the orientation the file declares — so today's results stay
/// comparable. It is the first pass and the only one that decodes nothing.
///
/// **Stable ids, and the same ids across a PDF and a photograph.** `p1-native`
/// is also the first id of the page list, and that is deliberate: design §3's
/// table and design §2's table are two lists of readings and not two
/// vocabularies, and a pass is reported by its id so that a reader of either
/// document finds the name it knows.
library;

import 'image_header.dart';

/// One reading of a photograph: the file as it is, or the image decoded to a
/// target size, optionally grey-stretched.
class OcrImagePass {
  /// Creates a pass named [passId] that decodes the image scaled by
  /// [longSideScale] and, when [greyContrast] is set, with its levels stretched.
  const OcrImagePass(
    this.passId, {
    this.longSideScale = 1,
    this.greyContrast = false,
  }) : readsTheFileAsItIs = false;

  /// Creates the pass named [passId] that reads the file as it is, which is
  /// what ML Kit's own file input does and the pass today's results came from.
  const OcrImagePass.asTheFileIs(this.passId)
    : longSideScale = 1,
      greyContrast = false,
      readsTheFileAsItIs = true;

  /// The pass's stable name, as design §2's table spells it.
  final String passId;

  /// How much the decoded image is scaled, as a factor of both of its sides.
  ///
  /// The design states it as a factor of the image's long side, and scaling both
  /// sides by the same factor is what makes it that: the long side stays the
  /// long side, and a word's position as a fraction of the picture — which is
  /// what Core's milli-points of the page are — is unchanged by the scale.
  final double longSideScale;

  /// Whether the decoded image is grey-scaled and stretched before recognition,
  /// which is design §2's `p2-contrast`.
  final bool greyContrast;

  /// Whether this pass hands the engine the file and no bytes of its own.
  final bool readsTheFileAsItIs;

  /// The pixel size this pass decodes an image that is displayed at [displayed]
  /// pixels to — or null when the pass reads the file as it is and decodes
  /// nothing.
  ///
  /// Every side is rounded to whole pixels and never to none: a target size in
  /// thousandths is not a size a decoder takes, and a target of no pixel is not
  /// an image. The rounding is the only arithmetic this list adds to the
  /// design's factors, and it is why §4's tolerance is one pixel and not zero.
  ImagePixelSize? decodeTargetFor(ImagePixelSize displayed) {
    if (readsTheFileAsItIs) {
      return null;
    }
    final int width = (displayed.width * longSideScale).round();
    final int height = (displayed.height * longSideScale).round();
    return ImagePixelSize(width < 1 ? 1 : width, height < 1 ? 1 : height);
  }

  @override
  String toString() =>
      'OcrImagePass($passId, ${longSideScale}x'
      '${greyContrast ? ', contrast' : ''}'
      '${readsTheFileAsItIs ? ', as the file is' : ''})';
}

/// Design §2's pass list, in its order: the file as it is, then contrast, low
/// and high.
///
/// Order is part of the contract, not an accident of the list: a pass is
/// reported by its id, so the order a caller reads is the order here, and the
/// same list gives the same ids on every run. No pass is dropped for speed in
/// M1 — the timings are reported per pass so that the product owner can decide
/// to trim later, and the decision is not made here by silently skipping one.
///
/// The two scales are the design's "about": 0.7 and 1.4 of the long side, both
/// sides scaled by the same factor.
const List<OcrImagePass> ocrImagePasses = <OcrImagePass>[
  OcrImagePass.asTheFileIs('p1-native'),
  OcrImagePass('p2-contrast', greyContrast: true),
  OcrImagePass('p3-lo', longSideScale: 0.7),
  OcrImagePass('p4-hi', longSideScale: 1.4),
];
