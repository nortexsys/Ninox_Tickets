# Proposal — setup-wizard

## Why

Configuration is the only part of the product the user cannot skip and the part they will
do once. Everything about it therefore has to be judged against one risk: the user
confirming a proposal they did not read. A field mapped to the wrong column does not fail
loudly — it writes a plausible value into the wrong place, and the read-back shows the app
succeeded.

That risk decides the design of the mapping step. Proposals are **pre-filled** so the user
corrects rather than constructs (FR-WIZ-005), and the matching threshold is deliberately
**strict**, so that below it a field is left unmapped rather than offered a mediocre
suggestion (FR-WIZ-006). The functional names the failure mode exactly: "a mediocre
suggestion a user confirms without reading". Leaving `doc_date` visibly unmapped is worse
for the wizard's appearance and better for the user.

Two more requirements keep the wizard honest about what it is doing. It may never render
Ninox's login inside a WebView it controls — the token is obtained through the platform's
own browser, which is a contract line rather than a preference (FR-WIZ-003). And no mapping
is mandatory: a user may map nothing and let Paperdrop attach the document to an otherwise
empty record (FR-WIZ-007), which the closing summary has to say in plain language.

## What Changes

- Add one capability spec, `setup-wizard`, with **8 requirements**: FR-WIZ-001…008.
- Applies `destinations-mapping`'s rules — formula and read-only fields excluded, choice
  options offered, identifiers stored — rather than redefining them.
- **No behaviour changes.** Every requirement traces to FR-WIZ.

## Capabilities

### New Capabilities

- `setup-wizard`: at most five screens, steps that omit themselves when there is nothing to
  choose, the token step through the system browser, a table listing that also returns the
  schema, pre-filled proposals, two-stage matching with a strict threshold, the permission
  to map nothing, and a plain-language summary that ends by offering the first document.

### Modified Capabilities

- None. No approved specification's requirements change.

## Impact

- `openspec/specs/setup-wizard/spec.md` — new.
- No application code, dependency, schema or API is touched by this proposal.
- Produces the destinations `destinations-mapping` defines and the stored token
  `local-config-privacy` owns. Depends on `product-invariants` for the credential rules
  the token step implements.

---

## Spec type

Lite. Eight concrete requirements with visible outcomes. The two that carry real weight —
the strict threshold and the system-browser rule — are already sharp in the functional, and
the confidence and duplicate semantics that a weaker wizard would corrupt are owned by
capabilities with Full specs.

## Problem statement

A first-run flow has to get a non-technical user from an installed app to a working
destination without a support ticket, while never asking them to make a decision they are
not equipped to make. The tension is that the fastest-looking wizard is the one that
proposes something for every field, and that is precisely the one that produces silent
mis-mappings. The flow must therefore be short, and honest where it has nothing good to
offer.

## Scope

### In scope

| Group | What it covers |
| --- | --- |
| Five screens (FR-WIZ-001) | Token, team, database, table, mapping — and never a sixth |
| Omitting steps (FR-WIZ-002) | Team, database and table each skipped automatically when their list holds exactly one option |
| Token step (FR-WIZ-003) | Instructions, paste from clipboard, and an option to open Ninox's settings in the platform's own system browser — Custom Tabs on Android, SFSafariViewController on iOS. The app never renders Ninox's login in a WebView it controls. The token is validated immediately and a successful call also returns the next step's list |
| Table listing (FR-WIZ-004) | Also returns the table's schema, so the mapping step needs no extra round trip, with formula and read-only fields annotated so the mapping step can exclude them |
| Pre-filled proposals (FR-WIZ-005) | Each of the six core fields proposed over the table's real fields, so the user corrects rather than constructs. Where nothing plausible exists the field is visibly unmapped rather than an empty selector |
| Two-stage matching (FR-WIZ-006) | A hard type filter first — a date only against a date field, an amount only against a number field, formula and read-only fields removed before matching — then string similarity against a multilingual synonym dictionary. Strict threshold: below it the field is left unmapped. A mediocre suggestion a user confirms without reading is the failure mode this prevents |
| No mapping is mandatory (FR-WIZ-007) | Everything, one field, or nothing — in which case the document is attached to an otherwise empty record |
| Closing summary (FR-WIZ-008) | Plain language about the consequence — "date and total will be saved; supplier, tax identifier and VAT will not" — and a final offer to capture the first document rather than returning to an empty app |

### Out of scope

- **What a destination is and what its fields obey.** `destinations-mapping` owns the
  tuple, identifier storage, choice fields, formula and read-only fields, the per-field
  absent setting and the prohibition on writing an unmapped field. This capability applies
  those rules.
- **Storage of the token and the rest of local data.** `local-config-privacy` owns the
  keystore storage, the export that carries a destination to another device, and the
  clearing action.
- **The credential invariants.** `product-invariants` owns that the token is the only
  credential and that no password is ever requested; the token step implements them.
- **The review screen's field order and presentation.** `review-screen` owns those; the
  wizard's summary names the same six fields but does not define their presentation.
- **The first capture itself.** `capture-intake` owns it; the wizard's last screen offers
  it.

## Source documents

- `docs/Fase 2. Define/Paperdrop_Funcional_v1.0_EN.md` §4.6 (FR-WIZ-001…008), §7.5 (the
  wizard's screens and their omitted-step variants), §2.2 (why the first-run flow must not
  assume a receipt).
- `docs/Fase 1. Discover/Paperdrop_PDR_v0.2_EN.md` §8 (first run), §8.1 (mapping), §8.2
  (no mapping is mandatory), §2 (the addressed user), §3.2 (non-goals).
- `docs/Fase 1. Discover/Paperdrop_ADR_v0.2_EN.md` — ADR-004 (the schema the listing
  returns), ADR-018 (the token through the system browser).
- Finding 7, the origin of the system-browser rule, and Finding 4, which bounds the
  acknowledgement the review screen later requires.

## Key design constraints

1. **The strict threshold is a feature, not a shortcoming.** An unmapped field is visible
   and correctable; a wrong mapping is invisible and writes to the wrong column.
2. **The app never renders Ninox's login.** The system browser presents it, outside the
   app's process. This is contract line 3 and is not negotiable for convenience.
3. **Steps are omitted, not hidden.** A one-option list skips its screen entirely, so a
   single-team single-database subscription sees token and mapping rather than five steps
   of nothing.
4. **One round trip per list.** The table listing returns the schema with it, and annotates
   formula and read-only fields, so the mapping step needs no further call and cannot
   propose a field that cannot be written.
5. **Nothing is mandatory, and the summary says so.** A user who maps nothing gets a record
   with the document attached and no data, and the closing screen states that in the user's
   own terms rather than leaving it to be discovered.
6. **The first run does not assume a receipt.** The wizard closes by offering to capture a
   document of any kind, because the addressed user's first document is as likely to be a
   supplier invoice as a till receipt.
7. **No invented content.** The functional does not fix the similarity threshold, the
   synonym dictionary's contents beyond Annex C, or the signature of "plausible". The spec
   states the outcome the threshold must produce rather than a number the source does not
   give.

## Open questions at proposal stage

- **None blocking.** GAP-005 (a choice field written outside its options) concerns
  `destinations-mapping` but touches the mapping step's picker; GAP-006 (the private-cloud
  host) touches the destination's advanced setup, which this wizard reaches. Neither
  prevents the capability being written.
- **To confirm while reviewing:** whether the strict threshold should be stated as a
  requirement with a placeholder value or left as an outcome. This proposal leaves it as an
  outcome — below the threshold the field is left unmapped — for the same reason the photo
  route's accuracy threshold is not stated in `extraction-pipeline`: the functional gives no
  number, and a number invented here would be asserted by the spec and tested by nobody.
