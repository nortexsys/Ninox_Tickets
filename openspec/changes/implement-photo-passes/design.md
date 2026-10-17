# Design: implement-photo-passes

Owner: Mobile lane. Written by the orchestrator, 2026-10-16.

## 1. Facts this rests on

| Fact | Source |
| --- | --- |
| A PDF page is rendered to RGBA by pdfrx and read with `InputImage.fromBitmap`; a bare image is read with `InputImage.fromFilePath` and yields the single pass `p1-native` | `mlkit_text_recognizer.dart`, `mlkit_ocr_text_source.dart` |
| `pixels.dart` already stretches the levels of an RGBA buffer (the `p4-contrast` pass) | `pixels.dart` |
| 18 real photographs read on the S22: all returned 1 pass, 30–195 words, median 562 ms | status 2026-10-16 |
| The corpus photographs are 2200×1650 (camera), 1080×1920 (messaging) and 899×1599 (unknown): already scaled, portrait and landscape | measured, sizes only |

## 2. The passes for an image

Same fixed, ordered, injectable list as design §3 of `implement-photo-route`, with an image list
beside the page list. A starting list, **to be measured, not defended**:

| passId | Variation of the photograph |
| --- | --- |
| `p1-native` | as today: the file as ML Kit reads it (`fromFilePath`); unchanged, so today's results stay comparable |
| `p2-contrast` | decoded to RGBA at native size, grey-scale and level stretch (`pixels.dart`) |
| `p3-lo` | decoded at about 0.7× the long side |
| `p4-hi` | decoded at about 1.4× the long side |

Ids are stable. A pass that throws is dropped and reported (existing `onPassDropped`); a shorter list
is legal; at least one surviving pass is required or the call fails as today.

## 3. The two checks that decide whether this needs more than the platform

**Orientation.** `fromFilePath` lets ML Kit honour the EXIF orientation. A decode for `fromBitmap`
might not. If a pass reads the picture rotated, its words come out in another geometry than
`p1-native` and consensus compares nothing. The lane must (a) state, from the platform's decoder
documentation or a probe, whether the decoder applies EXIF orientation; (b) if it does not, apply the
orientation itself from the EXIF tag it already walks (`image_header.dart`), and test it on a
synthetic oriented image; (c) assert in the device harness that the width/height of all passes of one
photo agree (after scale) and report it.

**Decoder.** Use what the platform gives with no new dependency (Dart's image codec). If it cannot
produce an RGBA buffer at a target size, stop and report; do not add a package without the PO.

## 4. Geometry

Each pass converts pixel boxes to Core's milli-points with **its own** pixel size and the **same**
nominal page size, so words of different passes land in the same coordinates (this is the invariant
that makes consensus meaningful). A test builds two passes of one synthetic image at different
scales and checks that the same word's box agrees within a small tolerance in milli-points.

## 5. Testing

Host: the decode and the pass list behind the existing backend seam, faked; orientation and scale
geometry as above; read-only (hash before/after) and cleanup unchanged. Device: the existing
`ocr_eval_test.dart` over the photographs, one JSON per photo with a pass each. The orchestrator runs
it on the S22 and reports only numbers: words per pass, agreement between passes (share of words
equal after normalisation), ms per pass. No threshold is applied.

## 6. Dispatch

One Mobile dispatch after `fix-jpeg-frame-header` is merged (both touch `app/lib/adapters/ocr/`).
