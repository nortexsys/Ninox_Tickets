# Proposal — destinations-mapping

## Why

The user's Ninox database is theirs, and the app has no rights over its shape. It may
not create fields, rename columns or assume anything exists — so everything the app is
allowed to write has to be stated by the user, field by field, and stored in a form
that survives the user reorganising their own database.

That requirement turns out to be sharp. A destination that stored field **names**
would break silently the first time the user renamed a column: the write would go to
a field that no longer exists, or worse, the app would stop resolving and start
guessing. Identifiers are stable and names are not, which is why the functional makes
this a requirement rather than a detail (FR-DST-003).

Two more traps live here, both of which produce a plausible record rather than an
error. A **formula field** cannot be written to at all — the API answers HTTP 500 —
so it must never be offered as a mapping candidate; but where that formula computes a
total, reading it back afterwards is the app's only independent sight of what the
user's own table made of the values it was sent. And a value the document **does not
print** has to become either an empty field or a zero depending on what that column
means to the user — a property of their table, not of the document, and the one place
in the product where the honest answer is a per-field setting rather than a rule.

## What Changes

- Add one capability spec, `destinations-mapping`, with **9 requirements**:
  FR-DST-001…009. BR-15 is carried by FR-DST-009, which is the same rule.
- Splits Annex A's rows between this capability and `ninox-send`, which the tree had
  previously left ambiguous: this capability owns the mapping-facing rows — names
  versus identifiers, choice fields, and formula or read-only fields — while
  `ninox-send` owns the write-path rows: payload shape, create response, merges,
  dates, error shape, retry policy, read-after-create and attachment upload.
- **No behaviour changes.** Every requirement traces to FR-DST or BR-15.

## Capabilities

### New Capabilities

- `destinations-mapping`: what a destination is, that none exists until the first
  send, that identifiers rather than names are stored, that formula and read-only
  fields are neither mapping candidates nor write targets but are used as a
  post-write contrast, the per-field absent-versus-zero setting, choice fields,
  the configurable Ninox host, and the prohibition on writing an unmapped field.

### Modified Capabilities

- None. No approved specification's requirements change.

## Impact

- `openspec/specs/destinations-mapping/spec.md` — new.
- No application code, dependency, schema or API is touched by this proposal.
- `ninox-send` consumes the resolved destination and the payload this capability
  defines. `setup-wizard` produces destinations and must apply this capability's
  rules rather than redefine them. `validation-confidence` owns the principle behind
  the per-field setting and this capability owns the setting itself.

---

## Spec type

Lite. Failures here are loud rather than silent: a mapping error surfaces as an HTTP
500 followed by a read-back, and FR-DST-005's contrast is a deliberate second check
whose blind spot is already recorded as GAP-009. The behaviour is also short and
concrete — nine requirements over a tuple, a storage rule and a setting.

## Problem statement

The app writes into a database it does not own, cannot inspect beyond the schema the
API returns, and must not alter. Everything it is permitted to write therefore comes
from an explicit user decision, recorded durably and resolved safely at the moment of
writing. The difficulty is not the mapping screen; it is that three separate kinds of
field must be treated differently — writable, formula, and read-only — and that the
"what if the value is absent" question has no single right answer.

## Scope

### In scope

| Group | What it covers |
| --- | --- |
| The destination tuple (FR-DST-001) | Team, database, table, field mapping and Ninox host. Several destinations may coexist |
| No default at first (FR-DST-002) | Nothing is pre-loaded before a first send; afterwards the bar shows the destination used last |
| Identifiers, not names (FR-DST-003) | Ninox field **identifiers** are stored; the current name is resolved at send time from a schema cached on app open. Payloads are keyed by name while the schema identifies fields by identifier |
| Formula and read-only fields (FR-DST-004) | Excluded from mapping candidates. Writing to one returns HTTP 500, which the app never provokes |
| Formula totals as contrast (FR-DST-005) | Never written to; read back after a successful send and compared against the extracted total. A mismatch is surfaced as a question about the mapping or the formula, not as a verdict on the extraction. Its known blind spot is stated in the requirement |
| Absent versus zero (FR-DST-006) | One additional per-field setting: empty (the default) or zero. A property of the destination field, not of the canonical model |
| Choice fields (FR-DST-007) | The mapping offers the field's existing options, never free text. Choice fields accept the option identifier or its text; reads always return the text |
| Configurable host (FR-DST-008) | A field in the advanced setup, defaulting to `api.ninox.com`, editable, never compiled in as a constant, validated at the token step |
| Never write an unmapped field (FR-DST-009, BR-15) | With the consequence that no marker field may be relied on to exist, which is why duplicate prevention is read-side |

### Out of scope

- **Writing anything.** The payload, the attachment upload, the retry matrix, the
  reconciliation of an uncertain create and the read-back are `ninox-send`'s, along
  with Annex A's write-path rows.
- **Producing a destination.** The wizard flow, the two-stage matching with its
  strict threshold and the pre-filled proposals are `setup-wizard`'s. This capability
  defines what a destination *is* and what its rules are; the wizard applies them.
- **The principle behind the absent setting.** That a value not printed is not a zero,
  and that whether it is empty or zero depends on the destination, is
  `validation-confidence`'s (FR-VAL-012, BR-13). This capability owns the per-field
  setting itself.
- **The duplicate criteria.** `document-history` owns them, and does so read-side
  precisely because FR-DST-009 forbids relying on a marker field.
- **The confidence of a value.** `validation-confidence` owns it. This capability
  decides what is written, not how sure the app is.

## Source documents

- `docs/Fase 2. Define/Paperdrop_Funcional_v1.0_EN.md` §4.5 (FR-DST-001…009), §5
  BR-15, §2.4 contract line 6, **Annex A** (the mapping-facing rows: names versus
  identifiers, choice fields, formula and read-only fields), §6.4 (payload and
  mapping rules), §9.3 (the semantics of HTTP 500).
- `docs/Fase 1. Discover/Paperdrop_PDR_v0.2_EN.md` §7.3 (destination bar and the
  absent setting), §7.4 (formula fields), §8.1 (mapping), §8.2 (no mapping is
  mandatory).
- `docs/Fase 1. Discover/Paperdrop_ADR_v0.2_EN.md` — ADR-004 (the verified Ninox
  contract), ADR-013 (read-side reconciliation, which FR-DST-009 forces), ADR-017
  (the configurable host).
- The 16-document test: the `YB` table's total is a formula field, which is the
  origin of FR-DST-005 and of the record-1414 verdict behind FR-DST-006.

## Key design constraints

1. **Identifiers are stored and names are resolved at send time.** This is the rule
   that makes the app survive the user renaming a column, and it is the difference
   between a silent break and no break at all.
2. **Three kinds of field are not the same.** Writable, formula and read-only. Only
   the first may be a mapping candidate; the second is read back as a contrast; the
   third is not touched. Collapsing them is what produces an HTTP 500 at send time.
3. **The contrast has a known blind spot and the spec says so.** It does not catch a
   total misread and then used to derive its own components, because the formula
   reproduces the error. Only `extraction-pipeline`'s read-before-derive and
   derive-by-identity rules do. Recording this in the requirement keeps the contrast
   from being overvalued by a later reader.
4. **The absent setting belongs to the field, not to the model.** It is the one place
   where two users with the same document and the same table legitimately want
   different written values, so it cannot be a rule.
5. **The host is configuration, not a constant.** Stated with its reason: a
   private-cloud customer must not need a fork.
6. **No invented content.** The functional fixes the default host string and the HTTP
   status the API returns on a formula write; both are reproduced. Where Annex A
   records a still-open point — a choice field written with text matching no option
   (GAP-005) — the spec does not resolve it.

## Open questions at proposal stage

- **None blocking, one bearing on the capability.** **GAP-005** — a choice field
  written with text matching none of its options is unverified and remains open.
  FR-DST-007 offers only existing options, which contains the risk rather than
  solving it, and the requirement says so.
- **GAP-006** — the private-cloud host has not been re-verified against a private
  instance, so FR-DST-008 cannot be considered closed for that segment. The
  requirement is written; its verification for that segment is not.
- **To confirm while reviewing:** the split of Annex A between this capability and
  `ninox-send`. This proposal assigns the mapping-facing rows here and the write-path
  rows there, which is what the functional's own traces imply but not what the tree
  previously said. If the product owner prefers Annex A to be owned whole by one
  capability, it is `ninox-send` that should hold it, since the write path is where
  most of its rows act.
