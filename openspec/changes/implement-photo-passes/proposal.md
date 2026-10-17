# Proposal: implement-photo-passes

Requirements: `FR-EXT-006` (consensus by majority), `FR-EXT-015` (photo-route recognition quality).
Written by the orchestrator, 2026-10-16. Corrects a gap in `implement-photo-route` design §3.

## Why

`implement-photo-route` §3 defined four passes (150, 200 and 100 dpi; 150 dpi with contrast), which
only exist for a **PDF**: they are renders of a page. A photo has no page to render, and the adapter
returns **one** pass (`p1-native`) for an image. Measured on the Galaxy S22 on 2026-10-16 over 18
real photographs: 1 pass each. With one pass the consensus returns `Single`, which the confidence
rules cap below green, so a photographed ticket — the product's main route — could never be green.
The design did not distinguish the two inputs; this change does.

## What changes

* The photo route returns several passes per image, with stable ids, from variations of the image
  itself (design §2), through the same `OcrPass` shape, so Core's consensus needs no change.
* The decoding needed for that stays in the adapter; nothing outside `app/lib/adapters/ocr/`.

## What it does not decide

* Which variations are worth keeping. The change builds a small injectable list, and the device
  harness reports each pass separately. Choosing, trimming or weighting passes needs ground truth,
  which is T2.5's (ADR-010 screening, with the PO's confirmed values). No accuracy threshold is
  stated (GAP-003).
* ADR-010 itself stays *proposed*.

## Out of scope

Cropping, perspective correction, de-skew and any pre-processing the platform scanner already does
(`DocumentScanner`: the app adds none). A new dependency, unless §2's check proves the platform
decoder insufficient, in which case the lane stops and reports.

## Impact

`app/lib/adapters/ocr/` and its tests; the device harness `ocr_eval_test.dart` already reports per
pass. No Ninox, no private corpus in the repository.
