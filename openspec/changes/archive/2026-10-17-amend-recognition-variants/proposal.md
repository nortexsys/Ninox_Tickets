# Proposal: amend-recognition-variants

## Why

`capture-intake` · `platform-document-scanner` currently reads: "the prototype's
pre-processing stage SHALL NOT be ported", and its scenario *the app carries no
pre-processing of its own* asserts that the application's code contains no
perspective-correction and no binarisation routine, and that "no stage re-enhances
an image the platform scanner already produced." Taken literally, that forbids the
photo route from ever touching an image a second time.

`extraction-pipeline` · `consensus-by-majority` (BR-06) needs several independent
readings to choose a value by agreement rather than by a single pass's apparent
confidence, and `validation-confidence` · `three-confidence-strengths` (BR-04)
caps a value confirmed by one reading alone below green — "an amount with no
independent figure to cross against SHALL never be green however cleanly it was
read." A rendered PDF page already gets several readings for free: the render
route (`render-and-ocr-fallback`) produces one bitmap per page and the implemented
multi-pass strategy (`implement-photo-route` design §3) reads that bitmap at
several resolutions, plus once more in grey-scale with a contrast stretch
(`p4-contrast`), already shipped. A photograph handed to the photo route without
going through a PDF render has no equivalent: the platform scanner produces one
image, and one reading of one image is one reading, so the photo route's
consensus has nothing to agree or disagree with, and the result is capped below
green by construction — not because the image was unclear, but because the
pipeline gave itself only one chance to read it.

The product owner decided on 2026-10-16, option 1 of the orchestrator's note: the
photo route may read an image more than once, under controlled variations of an
**in-memory copy** of that image — rescaled, and grey-scale with a level stretch —
created for the sole purpose of one extra recognition reading. The copy is never
the image of record. This is recorded as **DEC-017**.

The decision narrows `platform-document-scanner` rather than reversing it. ADR-006's
intent survives intact: the app still performs no perspective correction and no
binarisation of its own on the image that is **stored, attached or shown** — the
platform scanner still owns that image, completely, and still produces it exactly
as before. What changes is that the prohibition on "a stage that re-enhances an
image" is read as a prohibition on re-enhancing the image **of record**, not as a
prohibition on an in-memory copy that exists for one extra reading and is then
discarded. A pre-processing stage that silently replaces what is stored or shown
is exactly the failure ADR-006 and this requirement exist to prevent; a copy that
is read once and discarded, and never surfaces anywhere a user or a later stage
can see it, is not that failure.

The same narrowing covers ground already shipped: `p4-contrast` in
`implement-photo-route` grey-scales and contrast-stretches a *rendered PDF page*,
not a photograph, so it was never in tension with `platform-document-scanner` (a
PDF page has no platform scanner output to begin with) — but it is the same kind
of variation the decision now names and governs, and DEC-017 says so explicitly so
a later reader does not re-litigate it as a second case.

## What Changes

- `capture-intake` — MODIFIED `platform-document-scanner`. The original text is
  kept in full: edge detection, perspective correction, contrast enhancement and
  multi-page chaining come from the platform, and the prototype's pre-processing
  stage is not ported. Added: the definition of a **recognition variant** (an
  in-memory copy made for one extra recognition reading, never stored, attached,
  shown or used as the image of record), and the constraint that a variant SHALL
  NOT include perspective correction, binarisation, cropping, deskew or any
  re-encoding. The scenario *the app carries no pre-processing of its own* is
  narrowed to admit exactly one decoding routine, the recognition-variant decoder,
  and two scenarios are added: that a variant is never persisted, and that the
  attached image is the scanner's output, byte for byte.
- No requirement is added, removed or renamed.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `capture-intake`: narrows `platform-document-scanner`'s prohibition on
  re-processing an image to the image of record, and admits an in-memory
  recognition variant used for one extra reading and then discarded.

## Spec type

Lite — `capture-intake` is Lite in `openspec/project.md` §3.1; this change touches
one requirement of it and leaves the capability's shape unchanged.

## Impact

- `openspec/specs/capture-intake/spec.md` — `platform-document-scanner` amended on
  archive.
- No other living spec changes. `extraction-pipeline`'s `consensus-by-majority` and
  `render-and-ocr-fallback`, and `validation-confidence`'s `three-confidence-strengths`,
  are cited as the reason the decision was needed; none of their text changes.
- **Not this change's to do:** writing `app/lib/adapters/ocr/image_decoder.dart`,
  narrowing `app/test/tool/no_image_processing_test.dart` to admit exactly that
  file, and measuring whether `p4-contrast` (and any new photo-route variant)
  earns its place in T2.5 are implementation and evaluation work, dispatched to
  the Mobile lane after this change is archived. DEC-017 records the decision that
  authorises that work; it does not perform it.

---

## Problem statement

A requirement written to stop a prototype's always-on perspective-correction and
binarisation stage, read literally, also stops the one thing the photo route needs
to meet the product's own redundancy rule: more than one reading of the same
image. The conflict is in the wording, not in the intent — ADR-006 was never about
forbidding an extra reading, it was about who owns the image that gets stored,
attached and shown. This change rewrites the requirement so it says what it always
protected, instead of a larger claim the product owner has now narrowed.

## Decision recorded

**DEC-017**, `openspec/product-decisions.md`: the photo route may read an image
more than once under controlled variations of an in-memory copy; ADR-006's intent
is kept; the decision also covers the `p4-contrast` pass already shipped for
rendered PDF pages; the guard test is narrowed to admit exactly one decoding file;
the contrast pass's usefulness is measured in T2.5 and removed if it adds nothing.
PO, 2026-10-16.
