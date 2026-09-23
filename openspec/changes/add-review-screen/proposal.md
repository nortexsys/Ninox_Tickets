# Proposal — review-screen

## Why

Review is the screen the user sees on every document, and therefore the one that decides
whether the application feels light or heavy. The functional fixes an expectation for it
honestly — three taps on a clean document, five or six on a typical one — and every
requirement here exists to protect that number without hiding anything the user needs in
order to trust the result.

Two of them are doing more than layout. The **daily destination confirmation** is the one
deliberate exception to the three-tap principle: made once a day rather than once per
document, because sending a document to the wrong table is a mistake the user cannot see
afterwards. And the **thumbnail with the read region** is how the app shows *why* it
reached a number: tapping a green total highlights the regions of every operand that fed
the check, which is the only way the user can audit a confirmation rather than take it on
faith.

The capability also owns the two requirements that keep the screen from fighting the
product's own principles: **never block a save**, so that no field state can disable the
button except the daily confirmation, and **user edits are authoritative**, so that
correcting a value is final and the pipeline does not recompute it. Without those two, a
screen built to be careful becomes a screen that refuses to let the user finish.

## What Changes

- Add one capability spec, `review-screen`, with **11 requirements**: FR-REV-001…011.
  FR-DUP-002 is the duplicate notice, the link and the permission to proceed, which is
  the same behaviour as FR-REV-007, so the two are carried as one requirement with both
  origins. BR-14 is carried by FR-REV-009.
- **No behaviour changes.** Every requirement traces to FR-REV or FR-DUP-002.

## Capabilities

### New Capabilities

- `review-screen`: the persistent destination bar and its once-a-day confirmation, the
  thumbnail with the read region and the operand highlighting, the six core fields in
  fixed order with focus on the first unread one, the amounts block's collapse rule, the
  collapsed advanced section, the duplicate notice, a save button that names its
  destination, the guarantee that a save is never blocked, the authority of a user edit,
  and discard.

### Modified Capabilities

- None. No approved specification's requirements change.

## Impact

- `openspec/specs/review-screen/spec.md` — new.
- No application code, dependency, schema or API is touched by this proposal.
- Renders the state `validation-confidence` determines and the duplicate flag
  `document-history` sets. Named the destination that `destinations-mapping` owns.

---

## Spec type

Lite. The requirements are concrete and their failures are visible: a mis-ordered field
list, an expanded block, a disabled save button. Nothing here is silent, and nothing here
is a contract with expensive ambiguity — the confidence semantics and the duplicate
criteria that this screen presents are owned by capabilities that already carry Full
specs.

## Problem statement

The screen must present an uncertain result honestly, make correcting it quick, and never
stand between the user and the save. Those three goals pull against each other: showing
everything makes the screen heavy, hiding uncertainty makes it dishonest, and requiring
confirmation makes it obstructive. The functional's answer is a fixed field order with
automatic focus on the first value the app could not read, a block that collapses only
when a check actually passed, and exactly one acknowledgement per day.

## Scope

### In scope

| Group | What it covers |
| --- | --- |
| Destination bar (FR-REV-001) | Full-width and persistent, showing team, database and table, tappable to change destination without leaving the document |
| Daily confirmation (FR-REV-002) | Pre-loaded with the last destination; on the first capture of each calendar day it is highlighted and the save button stays disabled until acknowledged once. The one deliberate exception to three taps |
| Thumbnail and read region (FR-REV-003) | Tapping a field boxes and zooms the region the value came from. A value produced by a redundancy check highlights the regions of **every** operand that fed it |
| Six core fields (FR-REV-004) | `doc_date`, `supplier_name`, `supplier_tax_id`, `doc_number`, `gross_total`, `currency` in a fixed order, inline editing, large type, a colour per confidence state, and focus jumping to the first field that was not read |
| Amounts block (FR-REV-005) | Collapses to one confirming line when a redundancy check passes, and expands whenever it does not — including when there is no breakdown to check against at all |
| Advanced section (FR-REV-006) | Collapsed by default: remaining mapped fields, `surcharges[]`, `doc_subtype` and the other extended groups |
| Duplicate notice (FR-REV-007, FR-DUP-002) | A notice linking to the existing record, and the ability to proceed anyway, creating a second record deliberately |
| Save button (FR-REV-008) | Fixed at the bottom, naming the outcome — "Save to Expenses 2026" — rather than reading "Submit" |
| Never block a save (FR-REV-009, BR-14) | Missing, unreadable or low-confidence fields never prevent a record being created with the document attached |
| User edits (FR-REV-010) | An edited value is the value sent, editing does not re-impose a colour, and an edited value is not recomputed |
| Discard (FR-REV-011) | Discard the document: no record is created and the local capture is deleted |

### Out of scope

- **What a confidence state means.** `validation-confidence` owns the three strengths,
  what may be shown as confirmed and the lock-and-unlock rule. This screen renders the
  state and the lock affordance.
- **The duplicate criteria.** `document-history` owns them and the read-side check. This
  capability owns only what the user is shown when they match, and the permission to
  proceed.
- **What a destination is.** `destinations-mapping` owns the tuple, the per-field absent
  setting and everything about what may be written. The bar displays it and changes it.
- **The save itself.** `ninox-send` owns the send, the read-back and the confirmation
  screen that follows.
- **The document's state after a discard.** `document-history` owns the state machine and
  the file retention that a discard triggers.
- **Where a value came from.** `extraction-pipeline` owns provenance and the read
  regions' coordinates; this capability draws them.

## Source documents

- `docs/Fase 2. Define/Paperdrop_Funcional_v1.0_EN.md` §4.4 (FR-REV-001…011), §4.12
  FR-DUP-002, §5 BR-14, §7.1 (the screen inventory and navigation map), §7.3 (review,
  top to bottom).
- `docs/Fase 1. Discover/Paperdrop_PDR_v0.2_EN.md` §4 (the three-tap principle),
  §7.2 (review), §7.3 (the destination bar and the absent setting), §6 (the states).
- `docs/Fase 1. Discover/Paperdrop_ADR_v0.2_EN.md` — ADR-004 (the destination bar's
  values come from the destination), ADR-013 (the duplicate check is read-side).
- Finding 4, which is the origin of the daily destination confirmation.

## Key design constraints

1. **Focus lands on the first field that was not read.** This is the screen's whole
   efficiency argument: the user is taken to the value that needs attention rather than
   walking a form.
2. **The block collapses only when a check actually passed.** A document with no
   breakdown to check against shows the block expanded, because there is nothing
   confirming it. Collapsing on "no error" would hide the app's uncertainty.
3. **A redundant value highlights all its operands.** Showing the total's own region
   would show the user that a number was found, not why the app believes it.
4. **Exactly one acknowledgement per day, not per document.** The daily confirmation is
   the deliberate exception to three taps, and it is bounded to once a day on purpose.
5. **No field state disables the save button.** The only thing that may is the daily
   destination confirmation. A screen that refuses to let the user finish is worse than a
   screen that accepts an incomplete record.
6. **An edited value is never recomputed and never recoloured.** The user's correction is
   final; the pipeline does not get a second opinion.
7. **No invented layout.** The functional fixes the field list and its order, the button
   wording and the collapse rule. Where it does not fix a detail, the spec does not
   invent one.

## Open questions at proposal stage

- **None blocking, one bearing on the capability.** **GAP-006** records that INV-style
  panel content and demo fixtures once produced a mismatch between the conversation and
  an empty result table in the reference project; nothing equivalent applies here, since
  this screen has no such panel. The open entries that touch this screen at all are
  GAP-009 (the formula contrast, whose mismatch message this screen would surface) and
  GAP-005 (a choice field outside its options, whose error text the user would see).
  Neither prevents the capability being written.
- **To confirm while reviewing:** whether the amounts block's collapse rule should also
  collapse when the check passed but a later stage changed a value — for instance a user
  edit after the check ran. This proposal reads FR-REV-010 as authoritative over the
  collapse: an edited value does not re-impose a colour and therefore does not restore a
  collapsed block's confirmation. If the product owner prefers the block to re-expand on
  edit, that is a requirement here rather than in `validation-confidence`.
