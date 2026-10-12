/// The multi-pass strategy of the photo route (`implement-photo-route`,
/// design §3).
///
/// **What it is.** The same page is read several times under controlled
/// variations, and each reading is returned separately. The variation is a
/// rendering: the page at 150, 200 and 100 dots per inch, and once more at 150
/// with the levels stretched. Nothing chooses between them here — which
/// reading wins is Core's consensus (T1.5/T2.1, FR-EXT-006).
///
/// **Why a fixed list.** [ocrRenderPasses] is one constant with stable ids, so
/// that two runs read the same passes under the same names and consensus
/// compares like with like. The list is injectable, so a test can hand the
/// adapter a list of its own, and a pass that fails is dropped and reported
/// rather than silently replaced: a shorter list is legal, and one pass alone
/// is legal too.
library;

/// One rendering of a page, and the id it is known by.
class OcrRenderPass {
  /// Creates a pass named [passId], rendering the page at [dpi] and, when
  /// [greyContrast] is set, with the grey-scale contrast stretch of
  /// `pixels.dart`.
  const OcrRenderPass(
    this.passId, {
    required this.dpi,
    this.greyContrast = false,
  });

  /// The pass's stable name, as design §3's table spells it.
  final String passId;

  /// The resolution the page is rendered at, in dots per inch.
  final int dpi;

  /// Whether the render is grey-scaled and stretched before recognition.
  final bool greyContrast;

  @override
  String toString() =>
      'OcrRenderPass($passId, ${dpi}dpi${greyContrast ? ', contrast' : ''})';
}

/// Design §3's pass list, in its order: native, high, low, contrast.
///
/// Order is part of the contract, not an accident of the list: a pass is
/// reported by its id, so the order a caller reads is the order here, and the
/// same list gives the same ids on every run. No pass is dropped for speed in
/// M1 — the timings are reported per pass so that the product owner can decide
/// to trim later, and the decision is not made here by silently skipping one.
const List<OcrRenderPass> ocrRenderPasses = <OcrRenderPass>[
  OcrRenderPass('p1-native', dpi: 150),
  OcrRenderPass('p2-hi', dpi: 200),
  OcrRenderPass('p3-lo', dpi: 100),
  OcrRenderPass('p4-contrast', dpi: 150, greyContrast: true),
];
