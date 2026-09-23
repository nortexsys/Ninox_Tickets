# Proposal — document-history

## Why

Because mapping is optional, the local history is the **only** place a document's
confidence and provenance can be inspected after the fact. A user who mapped nothing
gets records in Ninox carrying an attachment and nothing else; if the history did not
survive the send, there would be no way to tell afterwards which records the app had
been unsure about.

That makes history a first-class surface rather than a convenience view (FR-HIS-005),
and it is also where the document **state machine** lives. The states are not
cosmetic: `queued`, `uncertain` and `failed` are three different things that are easy
to collapse into one, and collapsing them is how a document whose create response was
lost gets retried and duplicated. `extraction-pipeline` and `ninox-send` both drive
transitions of a state machine that is defined here.

Third, this capability owns the **duplicate criteria** — hash, or supplier together
with date and total — and it does so read-side against local history. That is not a
design preference: `destinations-mapping` forbids relying on a marker field in the
user's table, so a write-side duplicate check has nothing to rely on. The *notice*
that the criteria produce belongs to `review-screen`; the criteria and the check
belong here.

## What Changes

- Add one capability spec, `document-history`, with **6 requirements**: FR-HIS-001…005
  plus FR-DUP-001, the duplicate criteria.
- Corrects the tree: FR-DUP-002 is the duplicate notice, the link and the permission to
  proceed, which is the same behaviour as FR-REV-007 and belongs to `review-screen`.
  The tree previously listed both FR-DUP requirements here.
- **No behaviour changes.** Every requirement traces to FR-HIS or FR-DUP-001.

## Capabilities

### New Capabilities

- `document-history`: what a history entry holds, the document state machine, correction
  and re-send of the same record, local file retention, history as the uncertainty trace,
  and the duplicate criteria.

### Modified Capabilities

- None. No approved specification's requirements change.

## Impact

- `openspec/specs/document-history/spec.md` — new.
- No application code, dependency, schema or API is touched by this proposal.
- `ninox-send` drives the state transitions this capability defines and must not
  redefine the states. `capture-intake` requires the `queued` state for an offline save.
  `review-screen` owns the duplicate notice that these criteria trigger, and
  `local-config-privacy` owns clearing what is stored here.

---

## Spec type

Lite. The behaviour is short and observable, and its failures are visible rather than
silent: a missing history entry, a state that never resolves, or a file that was
deleted too early are all apparent to the user. It is not Full for the same reason it
sits in the middle of the dependency order — it is the record of what happened, not the
contract that decides it.

## Problem statement

A document passes through many states between being captured and being recorded, and
some of them are ambiguous: a create whose response was lost is neither done nor not
done. The app must be able to represent that honestly, keep enough local evidence to
resolve it, and keep that evidence only as long as it is needed — which means deleting a
document's local image as soon as the send is confirmed, and keeping it while anything
is still unresolved.

## Scope

### In scope

| Group | What it covers |
| --- | --- |
| Entry content (FR-HIS-001) | Thumbnail, extracted values **with their provenance**, destination, state, confidence, document hash, and the Ninox record identifier once sent |
| State machine (FR-HIS-002) | Exactly one of `pending`, `queued`, `extracting`, `reviewing`, `sending`, `uncertain`, `sent`, `failed`, `duplicate-flagged`, with the transitions of §6.2 |
| Correction (FR-HIS-003) | Correct values from an entry and re-send, producing an **update of the same record** rather than a new one |
| File retention (FR-HIS-004) | Local images deleted once a send is confirmed; retained for pending and failed items |
| First-class surface (FR-HIS-005) | History is where confidence and provenance remain inspectable when nothing was mapped in Ninox |
| Duplicate criteria (FR-DUP-001) | Flagged when the hash matches an earlier send, or when supplier, date and total together match one. Checked against local history before a save |

### Out of scope

- **The duplicate notice, its link and the permission to proceed.** FR-DUP-002 is that
  behaviour and it is the same as FR-REV-007; both belong to `review-screen`. This
  capability owns the criteria and the check, and the `duplicate-flagged` state.
- **Performing the send and the transitions it drives.** `ninox-send` drives the state
  machine defined here, owns the retry matrix and owns the reconciliation that resolves
  the `uncertain` state.
- **The queued state's cause.** `capture-intake` requires that an offline save queues
  rather than fails; this capability defines what `queued` means.
- **What is stored besides history.** Supplier memory is `supplier-memory`'s,
  destinations and mappings are `destinations-mapping`'s, and clearing local data is
  `local-config-privacy`'s.
- **The confidence and provenance of a value.** `validation-confidence` and
  `extraction-pipeline` own those; this capability stores and displays them.

## Source documents

- `docs/Fase 2. Define/Paperdrop_Funcional_v1.0_EN.md` §4.8 (FR-HIS-001…005), §4.12
  (FR-DUP-001, FR-DUP-002), §5 BR-15, §6.2.3 (the document state machine), §6.3 (local
  stores and retention).
- `docs/Fase 1. Discover/Paperdrop_PDR_v0.2_EN.md` §7.5 (history), §7.2 (the duplicate
  notice), §9.1 (retry and the uncertain state).
- `docs/Fase 1. Discover/Paperdrop_ADR_v0.2_EN.md` — ADR-009 (local stores and export),
  ADR-013 (read-side reconciliation, which is what the `uncertain` state exists for).
- `corpus_test/REPORT_after_review.md` and the test's record states, where an uncertain
  create and a duplicate were exercised.

## Key design constraints

1. **The state machine is a contract, not a label.** Nine states, exactly one at a
   time, and transitions per §6.2. `queued`, `uncertain` and `failed` must not be
   collapsed: the first is waiting, the second is genuinely unknown, and the third is
   known to have failed. Only the second requires reconciliation.
2. **Provenance stays local and stays visible.** The entry holds provenance, it is never
   sent to Ninox, and `history-is-the-uncertainty-trace` is the reason it must remain
   inspectable on the device after the send.
3. **Correction updates; it does not create.** A correction produces an update to the
   record the app created, which is what makes the `sent` state's record identifier
   load-bearing rather than cosmetic.
4. **Retention follows resolution, not age.** A file is deleted when the send is
   confirmed — the document is in Ninox by then — and kept while the item is pending or
   failed. Retention is therefore a consequence of the state machine, not of a timer.
5. **The duplicate check is read-side, and the reason is external.** It is read-side
   because `destinations-mapping` forbids relying on a marker field in the user's table;
   stating that reason in the spec is what stops a later reader from "improving" it into
   a write-side marker.

## Open questions at proposal stage

- **None blocking.** GAP-004 (upload limits) and GAP-005 (a choice field outside its
  options) concern `ninox-send` and `destinations-mapping`; GAP-009 (the formula
  contrast's blind spot) is recorded against `destinations-mapping`. None prevents this
  capability being written.
- **To confirm while reviewing:** the correction of the tree above. FR-DUP-002 describes
  the review screen's notice, link and permission to proceed, which is FR-REV-007's
  behaviour; this proposal leaves both to `review-screen` and keeps only the criteria
  and the check here. If the product owner prefers the duplicate capability to be whole
  in one place, the pair belongs together — and it would then be the notice that moves,
  not the criteria, because the criteria depend on local history.
