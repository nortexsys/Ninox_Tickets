# Change: implement-review-screen

## Why

T2.2 of plan v0.2 §9: the review screen is the screen the user sees on every document. Everything it
needs now exists on `main`: the extraction service returns a stored `reviewing` entry with a
`CanonicalDocument` (T2.1), history, duplicates and retry exist (T2.3), the send pipeline exists
(T1.11) and the destinations are stored by the wizard (T1.10). Without this screen no document can be
saved by a user, so alpha (T2.6, Fri 16 Oct, already past) cannot happen.

## What Changes

An **implementation-only change** (`skip_specs: true`); requirements are the `review-screen` capability
cut by plan §4.4: FR-REV-001, 002, 003 (thumbnail and full-screen view only), 004, 005, 007, 008, 009,
010, 011, with DEC-007. **FR-REV-006 (advanced section) is R1** and not built. Owner: Mobile lane, under
`app/lib/features/review/` and `app/test/features/review/`.

* **Confidence rendering** by `ConfidenceState` (green / amber / red) plus an *edited* mark (DEC-007).
  **PO decision 2026-10-17 (point 6): no new state.** A value read without a country row stays amber;
  only the document's `needsReview` tells it apart, and the screen may show one line saying so.
* Six core fields in fixed order, inline editing, focus on the first unread field.
* Amounts block with the collapse rule; destination bar with the daily acknowledgement; duplicate
  notice; save button naming the table; discard.

## Out of scope

* Read-region box and operand highlighting (R1); the advanced section (R1).
* Supplier memory (FR-MEM-*), the confirmation screen after the send (ninox-send), the share/scan entry.
* Any write to Ninox: tests use a fake `SendPipeline` port. No device run is claimed.
