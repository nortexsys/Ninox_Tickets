# Proposal — local-config-privacy

## Why

The product's privacy claim is the one statement that can be **falsified by a store
listing**. Google's and Apple's own components — the document scanner and, if ADR-010
selects it, the recognition engine — send operational diagnostics to their vendors. Not
document content, not the image, not the recognised text, but device model, OS version,
latency and error codes. So an unqualified "nothing leaves your device" would be
contradicted by the Data Safety form the publisher has to file, and the contradiction would
be found by a reviewer rather than by the user.

That is why the claim has to be stated **precisely** rather than strongly (NFR-PRV-002,
NFR-PRV-003), and why the two local stores that hold third-party data — the supplier memory
and the exportable configuration file — have to be declared rather than merely described
(NFR-PRV-004).

The capability also owns the things that make privacy real rather than promised: the token
in the platform keystore and never in a backup or a log line, an export that carries no
credential, a clearing action that genuinely empties everything, and no telemetry in a
public build — with supervised measurement before each release as the replacement, because
a product metric that is never gathered is a product metric that is never known.

Finally, it owns the measurable non-functional requirements: tap count and time per
document. Both are release criteria with thresholds that §10.5 deliberately defers to the
first corpus screening, and this spec states them as outcomes rather than inventing
numbers.

## What Changes

- Add one capability spec, `local-config-privacy`, with **14 requirements**: FR-CFG-001…004
  plus ten non-functional requirements that no other capability owns.
- Completes the NFR accounting: with this capability, all 18 non-functional requirements
  have exactly one owner, recorded in `project.md` §3.5.
- **No behaviour changes.** Every requirement traces to FR-CFG or an NFR.

## Capabilities

### New Capabilities

- `local-config-privacy`: the configuration export and import, device migration, genuine
  local data clearing, token storage in the platform keystore, the precise privacy claim,
  the platform-diagnostics distinction, the declaration of both local stores, supervised
  measurement instead of telemetry, tap count, time per document, accessibility,
  externalised user-facing strings, the AGPL exclusion, and application size.

### Modified Capabilities

- None. No approved specification's requirements change.

## Impact

- `openspec/specs/local-config-privacy/spec.md` — new.
- No application code, dependency, schema or API is touched by this proposal.
- Consumes the destination and mapping that `destinations-mapping` defines and the supplier
  memory that `supplier-memory` owns, and owns the export which carries both. Owns the
  interface-language strings that `countries-languages` requires to exist.

---

## Spec type

Lite. Fourteen requirements, all observable, and none of them a contract with expensive
ambiguity: the privacy claim is a wording that either matches the Data Safety form or does
not, the clearing action either empties the stores or does not, and the tap count is
measurable. The confidence semantics this capability's privacy wording has to stay
consistent with are owned by capabilities that already carry Full specs.

## Problem statement

A free application published by a company and installed on a personal device has to make
claims it can keep. It handles third-party business documents, stores supplier identifiers
and names, and holds a credential — and it relies on platform components that emit their
own diagnostics. The honest position is a precise claim rather than a broad one, two
declared stores rather than an unexamined silence, and clearing and export actions that do
what their names say.

## Scope

### In scope

| Group | What it covers |
| --- | --- |
| Export and import (FR-CFG-001, NFR-PRV-004) | Destinations, mappings and supplier memory exportable to and importable from a file the user keeps anywhere. The API token is **never** in the export |
| Device migration (FR-CFG-002) | A file plus a re-entered token, with no backend and no synchronisation service. The token is re-entered because it stays in the platform keystore and never leaves the device |
| Clearing (FR-CFG-003, NFR-PRV-005) | History, supplier memory, destinations and retained document files cleared genuinely and irreversibly, returning the app to its first-run state |
| Token storage (FR-CFG-004, NFR-SEC-001) | Android Keystore or iOS Keychain, never in an export, a backup snapshot or a log line. Biometric protection deferred as a later optional setting |
| The privacy claim (NFR-PRV-002) | The store listing leads with "your documents never leave your device", stated precisely and with NFR-PRV-003's caveat disclosed, rather than as an unqualified claim the Data Safety form would contradict |
| Diagnostics distinguished (NFR-PRV-003) | The notice states exactly that platform components send operational diagnostics — device model, OS version, API latency, error codes — encrypted, and that the image and the recognised text are not sent. Document content is never part of any diagnostic |
| Both stores declared (NFR-PRV-004) | The supplier memory, holding third-party tax identifiers and names, and the exportable configuration file that carries the same pairs |
| No telemetry, supervised measurement instead (NFR-PRV-006) | No telemetry in a public build; product metrics are gathered by supervised measurement before each release (§10.4) |
| Tap count (NFR-PRF-003) | Three taps plus one destination confirmation on the first capture of the day for a clean document, five to six for a typical one. Release criteria, measured by the supervised protocol |
| Time per document (NFR-PRF-001) | Median time from opening capture to a confirmed save low enough that the flow feels light — threshold **deferred** to the first corpus screening |
| Accessibility (NFR-ACC-001) | Platform accessibility standards: every control labelled, colour states paired with a non-colour cue, large-type fields by default, and the read region and confidence state exposed to assistive technology |
| Externalised strings (NFR-I18N-001) | Every user-facing string externalised, including error messages; no hardcoded user-facing string |
| No AGPL component (NFR-LIC-001) | No AGPL-licensed component ships inside the app. PyMuPDF is test-harness-only; iText is excluded outright |
| Application size (NFR-SIZ-001) | The PDF library's contribution to application size acceptable, as part of ADR-011's closure criterion |

### Out of scope

- **The credential invariants themselves.** `product-invariants` owns that the token is the
  only credential and that no password is ever requested, stored or transmitted, and that
  no telemetry is collected in a public build. This capability owns where the token is
  stored and how the claim about it is worded.
- **What the export contains.** `destinations-mapping` owns destinations and mappings and
  `supplier-memory` owns the pairs; this capability owns that the file carries them to
  another device and never carries a credential.
- **The interface languages' existence.** `countries-languages` owns that the interface
  ships in English and German. This capability owns that every string is externalised.
- **The dependency declaration.** `product-invariants` owns that proprietary dependencies
  appear in the README; this capability owns the AGPL exclusion that is stricter than
  declaring.
- **The metrics protected by the deferred thresholds.** §10.4's supervised protocol and
  §10.5's release criteria are the functional's; this spec states the outcomes it can test
  and defers the numbers it cannot.
- **Offline behaviour.** `capture-intake` and `document-history` own it; NFR-PRF-002 and
  NFR-OFL-001 are accounted for there per `project.md` §3.5.

## Source documents

- `docs/Fase 2. Define/Paperdrop_Funcional_v1.0_EN.md` §4.10 (FR-CFG-001…004), §8 (the
  non-functional requirements, NFR-PRV-002…006, NFR-SEC-001, NFR-PRF-001, NFR-PRF-003,
  NFR-ACC-001, NFR-I18N-001, NFR-LIC-001, NFR-SIZ-001), §10.4 (the supervised measurement
  protocol), §10.5 (the deferred thresholds), §2.4 contracts 2, 5 and 7.
- `docs/Fase 1. Discover/Paperdrop_PDR_v0.2_EN.md` §11 (privacy, the two local stores and
  the precise claim), §12 (metrics), §4 (light and simple), §3.2 (non-goals).
- `docs/Fase 1. Discover/Paperdrop_ADR_v0.2_EN.md` — ADR-009 (local stores, export and
  clearing), ADR-011 (the library selection and the AGPL exclusion), ADR-012 (supervised
  measurement), ADR-018 (the token through the system browser).
- Finding 9, the origin of the precise-claim requirement, and the verification of Google's
  ML Kit data disclosure that fixed NFR-PRV-003's wording.

## Key design constraints

1. **The claim is precise, not strong.** An unqualified "nothing leaves the device" would
   be contradicted by the Data Safety form and found by a reviewer. Platform components
   send diagnostics; document content never does; the notice says both.
2. **The token never leaves the device and never appears in a file.** Not in the export,
   not in a backup snapshot, not in a log line. Device migration re-enters it, and that is
   the designed cost rather than an inconvenience.
3. **Clearing is real and returns the app to first run.** Not flagged, not hidden,
   emptied.
4. **Two stores hold third-party data and both are declared.** Supplier identifiers and
   names live in the memory and travel in the export file; a notice that named only one
   would be incomplete.
5. **No telemetry, and measurement replaced by protocol.** A public build carries no
   analytics call, and product metrics come from supervised measurement before each
   release. A metric that is never gathered is a metric that is never known.
6. **The deferred thresholds stay deferred.** Tap count has a figure because the functional
   gives one; time per document does not, because §10.5 defers it to the first corpus
   screening. Inventing it would assert something untested — the same reason
   `extraction-pipeline` states no accuracy figure.
7. **Accessibility is not conveyed by colour alone.** The confidence states carry a
   non-colour cue as well, which is also what makes the review screen legible in sunlight
   on a photographed receipt.

## Open questions at proposal stage

- **None blocking, three bearing on the capability.** **GAP-003** — the acceptance
  thresholds for product metrics are deferred to the first corpus screening, which is why
  `time-per-document` states its outcome without a number. **GAP-002** — ADR-011 has not
  closed, so `application-size` and `no-agpl-component-ships` cannot be fully verified: the
  AGPL exclusion is stated, and the size delta is measured when the library is chosen.
  **GAP-011** — the name "Paperdrop" is unchecked in both stores and at the EUIPO, which
  matters here because the store listing is this capability's deliverable.
- **To confirm while reviewing:** whether `application-size` belongs in this capability or
  in `extraction-pipeline`, whose ADR-011 dependency it shares. This proposal keeps it here
  because it is a non-functional constraint on the shipped artefact rather than on the
  extraction behaviour, and `project.md` §3.5 records that reading. If the product owner
  prefers it beside the library decision, it moves without changing anything else.
