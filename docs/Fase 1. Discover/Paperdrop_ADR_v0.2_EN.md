**Paperdrop**

Architecture Decision Records (ADR) — version 0.2

**Project:** Paperdrop for Ninox (repository: Ninox\_Tickets)

**Owner:** Nortex Systems

**Phase:** FASE 1 — architecture of the information

**Date:** 22 September 2026

**Status:** Fifteen decisions accepted, one open. See Section 2.

**Related:** Paperdrop — Product Design Requirements (PDR), version 0.2

# Change log — v0.1 → v0.2

This revision closes the basic case of ADR-004's open item, adds a rule to ADR-007, sharpens ADR-011's acceptance criterion, keeps ADR-010 open with a revised closure criterion, and adds six new records — five drawn directly from the triage of the 17 findings against v0.1, and one drawn from the 16-document end-to-end test, which is the most consequential of the six.

|  |  |  |
| --- | --- | --- |
| **Ref** | **Change** | **Motivated by** |
| ADR-004 | Closed for the basic case: multipart attachment upload verified end-to-end across 16 real records. Remaining gaps listed explicitly. | 16-document test. |
| ADR-007 | Added rule: a PDF received as a PDF is attached unmodified; only camera captures are assembled into a new PDF. | Finding 6 — VisionKit returns images, not a PDF, and re-generating a PDF would destroy an embedded e-invoice XML. |
| ADR-011 | Positional (coordinate-based) text extraction promoted from a nice-to-have to a hard acceptance criterion. | 16-document test, PRO1013-26 — plain-text extraction decoupled a label from its value and picked up an unrelated number. |
| ADR-010 | Remains open; closure criterion revised to require the pipeline fixes of ADR-018 plus a scanned-PDF sample and more thermal-paper hospitality/fuel documents, not simply a higher document count. | 16-document test — 5 photo documents, 0 scanned-PDF; failures traced to pipeline defects, not the engine. |
| ADR-013 (new) | Reconciliation of a create with an uncertain outcome, instead of a blind retry. | Finding 1. |
| ADR-014 (new) | Extraction priority on the invoice route: embedded/attached XML, then positional text, then OCR. | Finding 12. |
| ADR-015 (new) | Integrity of the original attachment. | Finding 6. |
| ADR-016 (new) | Monetary representation as integers in the minor unit. | 16-document test — the prototype's ±0.02 tolerance let a wrong total pass. |
| ADR-017 (new) | Configurable Ninox host (public and private cloud). | Finding 14. |
| ADR-018 (new) | System-browser token authentication. | Finding 7. |
| ADR-019 (new) | Read-consensus before arithmetic; per-value provenance; the derive/invent boundary; a negative-context dictionary. | 16-document test — the central finding: nine of ten 'arithmetic-verified' records had derived the base from the total, so the check was a tautology, and three records invented a tax rate the document did not state. |

# Contents

1. How to read this document

2. Decision log

ADR-001 — Flutter, with a native iOS share extension

ADR-002 — On-device extraction, no backend

ADR-003 — Ninox classic REST API

ADR-004 — Ninox client contract

ADR-005 — Universal core plus a country table

ADR-006 — Operating-system document scanners for capture

ADR-007 — Attachment integrity: original preserved, captures assembled

ADR-008 — Return to Ninox by deep link

ADR-009 — Local-only storage with a portable configuration file

ADR-010 — Text recognition engine for the photo route (OPEN)

ADR-011 — PDF text extraction library for the invoice route

ADR-012 — No telemetry; supervised measurement

ADR-013 — Reconciliation of sends with an uncertain outcome

ADR-014 — Extraction priority on the invoice route: XML → positional text → OCR

ADR-015 — Integrity of the original attachment

ADR-016 — Monetary representation in integer minor units

ADR-017 — Configurable Ninox host

ADR-018 — Token authentication via the system browser

ADR-019 — Read-consensus, provenance, and the derive/invent boundary

3. Open decisions and what closes them

# 1. How to read this document

Each record states one decision, why it was taken, and what it costs. A record is Accepted when the decision is made and binding, or Proposed when it is written down but not yet closed. A Proposed record names exactly what has to happen before it can be accepted.

The decisions are constrained by the technical contract in Annex A of the PDR. Where a record touches one of those lines, it says so.

# 2. Decision log

|  |  |  |
| --- | --- | --- |
| **Ref** | **Decision** | **Status** |
| ADR-001 | Flutter, with a native iOS share extension | Accepted |
| ADR-002 | On-device extraction, no backend | Accepted |
| ADR-003 | Ninox classic REST API | Accepted |
| ADR-004 | Ninox client contract | Accepted — attachment upload closed for the basic case |
| ADR-005 | Universal core plus a country table | Accepted |
| ADR-006 | Operating-system document scanners for capture | Accepted |
| ADR-007 | Attachment integrity: original preserved, captures assembled | Accepted |
| ADR-008 | Return to Ninox by deep link | Accepted |
| ADR-009 | Local-only storage with a portable configuration file | Accepted |
| ADR-010 | Text recognition engine for the photo route | Proposed — pending measurement, criterion revised |
| ADR-011 | PDF text extraction library for the invoice route | Proposed — positional extraction now required |
| ADR-012 | No telemetry; supervised measurement | Accepted |
| ADR-013 | Reconciliation of sends with an uncertain outcome | Accepted |
| ADR-014 | Extraction priority on the invoice route | Accepted |
| ADR-015 | Integrity of the original attachment | Accepted |
| ADR-016 | Monetary representation in integer minor units | Accepted |
| ADR-017 | Configurable Ninox host | Accepted |
| ADR-018 | Token authentication via the system browser | Accepted |
| ADR-019 | Read-consensus, provenance, and the derive/invent boundary | Accepted |

## ADR-001 — Flutter, with a native iOS share extension

**Status:** Accepted — unchanged in v0.2

**Context.** Two platforms, a small team, and an application that must be free to build and maintain. The work needs a camera and document scanner, on-device text recognition, intake of documents shared from other applications, file handling and an HTTP client.

**Decision.** Flutter for the application. The iOS Share Extension is written natively in Swift inside the same project; Android intake uses a share intent filter and needs no separate component. Both are also the entry point for sharing a mail attachment (.msg/.eml) from the platform's mail client.

**Consequences.** One codebase carries the interface, the extraction pipeline, the validation layer and the Ninox client. The iOS share extension is the single place where the one-codebase promise does not hold, and it must be budgeted as native work rather than discovered late. A small native bridge may also be required to reach the iOS Vision and VisionKit frameworks. Because a Share Extension has a tight memory ceiling, it cannot itself run OCR or show the review screen: on iOS, sharing hands the document to the app, which opens directly into review.

**Alternatives considered.** Native Kotlin and Swift would integrate better with every platform API but doubles the codebase and the release pipeline. React Native fits on-device recognition and iOS share extensions less well. Kotlin Multiplatform shares the logic cleanly but its iOS ergonomics remain costly.

## ADR-002 — On-device extraction, no backend

**Status:** Accepted — unchanged in v0.2

**Context.** The application is free and open source. Any server would create a recurring cost for Nortex with no revenue against it, and would place third parties' fiscal documents on infrastructure Nortex would then have to govern. The core market is the one that cares most about exactly that.

**Decision.** All reading, validation and consolidation happen on the device. There is no Paperdrop server and no call to a hosted model.

**Consequences.** No recurring cost, no data-protection surface beyond the device, and capture works without connectivity. The strongest claim on the store listing follows directly from this decision. The costs are real: there is a ceiling on severely degraded documents that a large multimodal model would clear, improvements ship as store releases rather than server changes, and there is no field data about how the application behaves in the wild.

**Contract.** Implements constraints 1 and 2 of the technical contract.

## ADR-003 — Ninox classic REST API

**Status:** Accepted — unchanged in v0.2

**Context.** Ninox exposes two live interfaces. The classic one is organised as teams, databases and tables and authenticates with a personal access token. The newer one is organised as workspaces and modules, authenticates with a workspace-scoped key, and uploads files through presigned storage URLs in a three-step flow.

**Decision.** Build version 1 against the classic interface.

**Rationale.** A single personal access token enumerates teams, then databases, then tables with their fields — which is precisely the chain the list-driven setup wizard needs in order to ask the user to choose rather than to type. The newer key is bound to one workspace, which conflicts directly with the common case of several databases under one subscription. Attachment upload is also one multipart call instead of three steps through object storage.

**Consequences.** A dependency on an interface the vendor describes as the previous generation. The Ninox client is therefore isolated behind a port so that a second implementation can be added without touching the rest of the application, and the decision is revisited if deprecation is announced.

## ADR-004 — Ninox client contract

**Status:** Accepted — attachment upload closed for the basic case

**Context.** The behaviour of the classic write API was verified against a real Ninox workspace by an earlier Nortex automation project, with a full request and response trace. Those findings are binding here rather than assumptions. A second verification — an end-to-end test that created, uploaded to, read back and inspected 16 real documents against a disposable table (team qCq3JS7q7ptoap8Yg, database db0000000000) — closed the one rule that first trace had left untested.

|  |  |
| --- | --- |
| **Rule** | **Detail** |
| Payload shape | Records are written as a nested object under a fields key. Confirmed by trace. |
| Create response | Returns HTTP 200 with the identifier of the new record, which is what the attachment call and the deep link both need. |
| Updates are merges | Fields not sent are preserved, so a correction sends only what changed and a failed attachment can be retried without touching the record. |
| Choice fields | Accept either the option identifier or the option text; reads always return the text. The mapping therefore offers the user the existing options rather than free text. Behaviour when the written text matches none of the field's options is still unverified. |
| Dates | A YYYY-MM-DD string is stored verbatim. |
| Names versus identifiers | Payloads are keyed by field name while the schema identifies fields by stable identifier. Destinations store the identifier and resolve the current name at send time from a cached schema, refreshed when the app opens. |
| Formula and read-only fields | Excluded from the mapping candidates the wizard proposes (PDR §8.1); writing to one returns HTTP 500. Where a formula field computes a total, it is used as a post-write check, never as a write target (PDR §7.4). |
| Error shape | An invalid or read-only field name returns HTTP 500, not a 4xx with an explanation. |
| Retry policy | Server errors are never retried blindly. On a 500 the client refreshes the schema once and retries once; a second failure is reported as a mapping error, not a server outage. A create call whose response is lost to a timeout is never retried blindly either — see ADR-013. |
| Read after create | The record is always read back, because fields carrying formulas or defaults silently override submitted values and the create response does not reveal it. |
| Attachment upload | POST /v1/teams/{team}/databases/{db}/tables/{table}/records/{id}/files, multipart/form-data, returns HTTP 200. GET .../records/{id}/files returns name, size and content type. Verified with a disposable record (create → upload → read → delete) and then with 16 real uploads, all HTTP 200. |

**Consequences.** The application survives a field being renamed in Ninox, never enters a retry storm on a mapping mistake, and shows the user what is actually stored. The basic attachment contract is now verified rather than assumed.

**Still open.** File size limit; behaviour with a multi-page PDF at the upper end of that limit; a choice field written with text that matches none of its options; real upload timings from the primary market (Section 3).

**Note.** Creating a record may trigger automations inside the user's Ninox database that the API does not expose. The read-after-create step is the only visibility the application has into that, and the documentation should say so.

## ADR-005 — Universal core plus a country table

**Status:** Accepted — unchanged in v0.2, Switzerland confirmed as a launch row

**Context.** The design initially assumed country packs, with Spain as the first and reference implementation. That was wrong: it was anchored on the two documents available in the prototype, not on the market. Ninox's installed base is concentrated in German-speaking Europe and Spain is a small minority of it.

**Decision.** A universal core, valid everywhere, plus a data table of country-specific values. No country is the reference case and there is no user-facing setting. Germany, Austria, Switzerland and Spain are the four launch rows (PDR §10).

|  |  |
| --- | --- |
| **Layer** | **Contents** |
| Universal core | Amount arithmetic, date coherence, date and decimal format inference, EAN-13 check digit, IBAN modulo 97. |
| Country table | VAT identifier format and its check-digit algorithm, the legal set of tax rates and the number of tax slots, date format, decimal separator, cash-rounding rule where one exists (e.g. Swiss 5-Rappen rounding). |
| Language dictionaries | Document keyword vocabulary per language, independent of interface language, including the negative-context terms of ADR-019. |

**Consequences.** Adding a country becomes a table row plus, at most, one small check-digit function, so a single European VAT validator covers most member states at once rather than one country at a time. This is less work than the original plan, not more. The cost is that the universal core cannot assume format and must infer it from the document — a genuine algorithm, and the one new piece of work this layer introduces.

## ADR-006 — Operating-system document scanners for capture

**Status:** Accepted — unchanged in v0.2

**Context.** The prototype spends a substantial amount of code on perspective correction, paper masking and binarisation variants before recognition can begin.

**Decision.** Capture uses the ML Kit Document Scanner on Android and the VisionKit document camera on iOS rather than a raw camera view.

**Consequences.** Edge detection, perspective correction, contrast enhancement and multi-page chaining come from the platform, so the prototype's pre-processing stage is not ported. The user gets the scanning interface they already know from their notes application. What remains to be ported is the part that matters: consensus between recognition passes, and the validation layer. The cost is that the Android scanner is part of Google Play Services, which reinforces a dependency that interacts with ADR-010. The 16-document test, though it did not exercise the platform scanners directly, supports the underlying bet: where its OCR failed it was not for lack of pre-processing, but for lack of consensus and validation (ADR-019).

## ADR-007 — Attachment integrity: original preserved, captures assembled

**Status:** Accepted — rule added in v0.2

**Context.** In Ninox a file is attached to a record, not to a field of file type, so no mapping entry is required and no table can be unsuitable. A camera capture reaches the app as a set of page images; a shared document — a plain PDF, or a structured e-invoice — reaches it as a file that already exists.

**Decision (v0.1, unchanged).** A document produced by the device's own camera capture is assembled into a single PDF — cropped, deskewed and enhanced by the platform scanner — and that assembled PDF is what gets attached.

**Decision (new in v0.2).** A document that arrives already as a file — a PDF shared from another app, an e-invoice, an attachment pulled from a .msg/.eml — is attached exactly as received, byte for byte. The app never re-saves, re-renders or re-compresses it.

**Rationale for the new rule.** Re-generating a PDF/A-3 destroys any XML embedded in it. For a ZUGFeRD/Factur-X e-invoice that embedded XML is the legally authoritative record (ADR-014); silently stripping it on the way to Ninox would remove exactly the asset that makes the document valuable in the first place. The rule also happens to be simpler: the two cases — assembled from a capture, or preserved from a file — cover every input path in PDR §3.1.

**Consequences.** One format throughout the history and the user's database for camera captures; byte-identical preservation for everything else. Multi-page is native for both cases. The original framing of a photographed receipt is lost in the assembled case, which in practice carries no information.

## ADR-008 — Return to Ninox by deep link

**Status:** Accepted — unchanged in v0.2

**Context.** The brief asked that the user be able to see the record that was just created. Doing so through a Ninox login would mean handling the user's credentials, which the technical contract forbids.

**Decision.** After a successful send the confirmation screen offers a link built from data the application already holds: team and database from the destination, table identifier from the destination, record identifier from the create response. The view segment of the URL was verified to be optional, so no additional API call is needed.

**Consequences.** The requirement is met with no credentials, no extra request and no additional field in the destination. The risk is that this URL structure is not published as a contract by the vendor and could change; if it stops resolving, the button degrades to opening the database rather than failing.

**Contract.** Implements constraint 3 of the technical contract.

## ADR-009 — Local-only storage with a portable configuration file

**Status:** Accepted — unchanged in v0.2

**Context.** There is no backend, so destinations, mappings, history and the supplier memory live on the device. Without further provision, changing phone would mean losing all of it and repeating the setup.

**Decision.** All state is local. Configuration — destinations, mappings and supplier memory — can be exported to and imported from a file that the user keeps wherever they like. The API token is never included; it stays in the Android Keystore or the iOS Keychain and is re-entered on the new device.

**Consequences.** A device change becomes a file rather than a fresh setup, with no backend and no synchronisation service. The export file contains tax identifiers and names of third-party businesses, so it is covered by the privacy notice, and the application provides a data-clearing action that genuinely empties the supplier memory.

**Safeguard.** The supplier memory is indexed only by identifiers that passed their check digit. Indexing on an uncertain reading would let a wrong name enter the store and then be presented later as confirmed, which is the one way this feature could become harmful.

## ADR-010 — Text recognition engine for the photo route

**Status:** Proposed — pending measurement, closure criterion revised in v0.2

**Context.** The photographed-paper route needs on-device character recognition. Two families are available and they trade quality against openness. This is the only decision in the document that cannot be settled by reasoning alone.

|  |  |
| --- | --- |
| **Candidate** | **Assessment** |
| ML Kit Text Recognition on Android, Vision on iOS | Best available on-device quality, free of charge, maintained by the platform vendors. Both are proprietary; the Android component ships inside Google Play Services, which excludes devices without it and prevents publication on F-Droid. Verified: Google's own data disclosure states it sends operational diagnostics, not document content. |
| Tesseract compiled for mobile | Fully auditable, no proprietary dependency, publishable anywhere. Weaker on photographed thermal receipts — which is the main case — and pushes pre-processing work back into the application. |
| Both behind one interface | Platform engine by default, free engine as an option. Defensible position for an open-source project, at the cost of two engines to test and two quality levels to document. |

**Coupling to note.** ADR-006 already introduces a Google Play Services dependency on Android through the document scanner. Choosing the free recognition engine would therefore not, by itself, produce a Play-Services-free Android build. Anyone arguing for Tesseract on openness grounds has to argue for replacing the scanner as well.

**What the 16-document test changed.** The test could not close this record — only 5 of its documents were photographs, and none exercised the scanned-PDF route — but it did produce evidence about where quality is actually lost: every failure traced to consensus between OCR passes or to PDF parsing, not to the recognition engine. That is consistent with, not a substitute for, a proper screening.

**What closes this record now.** Two conditions, both required. First, the pipeline fixes of ADR-019 (consensus before arithmetic, no derived rates) are implemented, so the screening measures the engine and not the pipeline's own defects. Second, the photographed-paper corpus is extended to roughly fifteen documents that specifically cover thermal-paper hospitality and fuel receipts — the two categories the test flagged as most exposed to degradation — and includes at least one scanned PDF, so the render+OCR path is represented at all. Measurement is per-field accuracy after the validation layer, using only values whose provenance is read (never derived), and the share of fields confirmed by redundancy rather than raw character error rate. If one candidate clearly loses, the decision is made on that corpus; if the candidates tie, it is extended further before deciding.

**Dependency.** Requires the extended photographed-paper corpus and a test harness on a physical device, since both platform engines are operating-system APIs and cannot be exercised anywhere else.

## ADR-011 — PDF text extraction library for the invoice route

**Status:** Proposed — positional extraction now a hard acceptance criterion

**Context.** A supplier invoice arriving by email usually carries a text layer, so that route needs text and coordinate extraction rather than character recognition. A PDF without a text layer falls back to rendering the page and sending it through ADR-010. The 16-document test used PyMuPDF (AGPL — valid for a test harness, never inside the shipped app) to extract plain text, and the failure it produced is instructive: on PRO1013-26, the label and its value ended up on decoupled lines, and the parser's last-resort fallback picked up an unrelated number (a registry volume reference, 'Tomo 8.741') instead of the total.

**Proposal.** PDFKit on iOS, which is part of the system and raises no licensing question, and PdfBox-Android on Android, which is Apache 2.0 licensed and therefore adds no further proprietary dependency. Both expose per-word position, which is what the acceptance criterion below requires.

**Rejected.** iText is licensed under the AGPL, which is incompatible with the intended distribution of this application. Commercial document SDKs are excluded by the project being free. PyMuPDF, AGPL, is confirmed as test-harness-only and excluded from the shipped app.

**Acceptance criterion (revised in v0.2).** Plain-text extraction is not sufficient and is no longer an acceptable implementation. The chosen library must expose word-level coordinates so the parser can associate a label with the value nearest it in the document's visual layout, not merely nearest it in extraction order. This is now a required behaviour, verified against the sample-invoice corpus, not only a licence and size check.

**What closes this record.** Confirmation of the proposal, a run over the sample-invoice corpus specifically exercising the label-value association rule above, and a check that the resulting increase in application size is acceptable.

## ADR-012 — No telemetry; supervised measurement

**Status:** Accepted — unchanged in v0.2

**Context.** The product metrics are primary and are about behaviour: seconds per document, taps per document, share of documents saved untouched, and — new in v0.2 — the abstention rate (PDR §12). In production those numbers can only be collected by telemetry, and telemetry inside an open-source application whose central claim is that documents never leave the device is precisely the kind of decision the technical contract exists to prevent.

**Decision.** No telemetry in public builds. Product metrics are gathered by supervised measurement before each release: observed sessions with real users, plus a benchmark run over the test corpus.

**Consequences.** The privacy claim stays intact and the store listing can make it without qualification, once stated with the precision PDR §11 now requires. The cost is accepted knowingly: there is no visibility into how the application behaves once published, and regressions in real use surface through reviews and reports rather than through data. A useful side effect is that acceptance thresholds are not invented in advance — they are set once the first screening shows what is achievable.

**Contract.** Implements constraint 7 of the technical contract.

## ADR-013 — Reconciliation of sends with an uncertain outcome

**Status:** Accepted — new in v0.2

**Context.** The v0.1 retry policy retried a POST create on timeout with exponential backoff. If Ninox had actually created the record and only the response was lost, that retry creates a duplicate. There is no idempotency key available to prevent it: the app cannot write a marker of its own, because the technical contract forbids writing a field the user has not mapped, and mapping is optional, so a marker cannot be relied on to exist.

**Decision.** A POST create whose response is lost to a network error or timeout is never retried blindly. The send enters an uncertain-outcome state and the app performs a read-side reconciliation: it reads the destination table's most recently created records (createdAt/createdBy are available on every record regardless of mapping) and looks for a match against the mapped fields, within a short time window around the attempt. If a match is found, that record is adopted and the flow continues to the attachment step as if the create had returned normally. If no match is found, the record is created. If the reconciliation is ambiguous — more than one plausible match, or too few mapped fields to compare — the app does not guess: it surfaces the uncertainty to the user and lets them choose.

**Consequences.** No blind duplication, and no record silently lost either. The cost is one extra read call on the uncertain path only — the common case (a clean POST response) is unaffected — and a small window in which two devices sending near-identical documents in the same few seconds could, in principle, confuse the reconciliation; this is judged acceptable because Paperdrop has no multi-device sync (ADR-009) and the scenario requires the same user, same destination, same moment.

**Contract.** Supports constraint 6 of the technical contract (never write what was not intended) by preventing an unintended duplicate write.

## ADR-014 — Extraction priority on the invoice route: XML → positional text → OCR

**Status:** Accepted — new in v0.2

**Context.** Germany requires businesses to be able to receive structured e-invoices for domestic B2B since 1 January 2025, and to issue them from 1 January 2027 (turnover above roughly €800,000) and 1 January 2028 (the rest of domestic B2B). The compliant formats are XRechnung (pure XML) and ZUGFeRD/Factur-X (a PDF/A-3 with the XML embedded as an attachment); where the two disagree, the XML is the legally authoritative version. In Paperdrop's primary market, a growing share of the invoices a user shares will carry this XML.

**Decision.** The invoice route tries three extraction methods in a fixed order and stops at the first that succeeds: (1) embedded or attached XML — ZUGFeRD/Factur-X embedded in the PDF, or a standalone XRechnung XML — read deterministically, field by field, with provenance from\_xml; (2) the PDF's text layer, extracted with word-level positions (ADR-011) and associated with its nearest label; (3) if the PDF has no text layer, the page is rendered and sent through the OCR pipeline (ADR-010), exactly like the photo route.

**Consequences.** Where step 1 applies, every core field is deterministic and never amber — no OCR, no ambiguity, no confidence judgement to make. This is the strongest form of confirmation in the entire product, stronger than any redundancy check in PDR §6, because the source is a machine-readable record rather than a rendering meant for a human eye. The cost is that ADR-011's chosen library must additionally be able to extract an embedded file from a PDF without modifying it — a read-only operation, compatible with ADR-015 — and the parser must recognise and distinguish XRechnung's syntaxes (UBL, CII) and the ZUGFeRD/Factur-X profile levels, since a MINIMUM or BASIC WL profile does not carry every field the model wants and a missing field there means not\_in\_xml, not absent.

## ADR-015 — Integrity of the original attachment

**Status:** Accepted — new in v0.2, formalises the rule added to ADR-007

**Context.** ADR-007 already decided that a file received as a file is attached unmodified. This record states the underlying principle explicitly, because it constrains every future decision that touches a shared document: opening a file to extract data from it must never be able to alter that file.

**Decision.** Every operation performed on a document the app did not itself generate — reading its text layer, extracting an embedded XML attachment, rendering a page for OCR — uses read-only access. No tool in the pipeline may re-save, flatten, re-compress or otherwise rewrite the source file, even incidentally. The bytes attached to the Ninox record are byte-identical to the bytes the user shared.

**Consequences.** This rules out any PDF library whose only extraction path is 'open, mutate in memory, re-export' unless it also offers a genuinely read-only mode, and it is now an explicit filter on ADR-011's candidate evaluation. It also protects the case ADR-014 depends on: an embedded ZUGFeRD/Factur-X XML has no value if the extraction step that reads it degrades the PDF that carries it.

## ADR-016 — Monetary representation in integer minor units

**Status:** Accepted — new in v0.2

**Context.** The original prototype stored amounts as floating-point numbers and compared them with a fixed ±0.02 tolerance. The 16-document test showed exactly why that is unsafe: a total misread as 19.98 against a correct 19.99 produces a base of 16.51 against a correct 16.52, and 16.51 + 3.47 = 19.98 passes a ±0.02 check even though every figure in it is wrong by one cent. A tolerance wide enough to absorb rounding is also wide enough to absorb a misreading.

**Decision.** Every monetary amount in the canonical model, in local storage and in the Ninox payload is an integer in the currency's minor unit (cents for EUR/CHF/USD/GBP, per ISO 4217's exponent for others), never a float and never a formatted string. The sum of printed values — base + tax = total, or base + surcharges = total — must be exact, integer equality, with no tolerance. Tolerance is permitted in exactly one place: base × rate ≈ tax, where a genuine rounding difference of at most one minor unit per tax line is expected and accepted.

**Consequences.** A misread total can no longer disguise itself as a rounding error. The application's internal arithmetic, its SQLite-equivalent local store, and the JSON sent to Ninox all carry the same integer representation, so no conversion boundary can silently reintroduce a float. Tax rates follow the same logic in basis points (2100 for 21%, not 21.0) so that a rate comparison against the country table's legal set (ADR-019) is also exact.

## ADR-017 — Configurable Ninox host

**Status:** Accepted — new in v0.2

**Context.** Version 0.1 hard-coded api.ninox.com as the only base URL. Ninox offers a private cloud deployment for enterprise customers with a different host, and this is common in larger German companies — exactly the segment the product targets.

**Decision.** The Ninox host is a field in the destination's advanced setup, defaulting to api.ninox.com but editable. The client's base URL is never compiled in as a constant.

**Consequences.** A private-cloud customer can use the app without a fork or a manual build. The host must be validated at the token step (PDR §8) exactly like the token itself, and the technical spike behind ADR-004's remaining open items should be re-run, or at least sanity-checked, against a private-cloud instance before this is considered fully closed for that segment.

## ADR-018 — Token authentication via the system browser

**Status:** Accepted — new in v0.2

**Context.** Version 0.1's setup wizard proposed an in-app browser for the step where the user copies their Ninox API token. An in-app WebView that the application itself controls, showing Ninox's own login form inside it, sits uncomfortably close to the line the technical contract draws around never handling Ninox credentials — the app would be positioned to observe a password field it is never supposed to see, even if it does not.

**Decision.** The token page opens in the platform's own system browser component — Custom Tabs on Android, SFSafariViewController on iOS — never in a WebView the app renders itself. The user logs in, copies the token, and returns to the app, which reads it from the clipboard or a paste field.

**Consequences.** The application is structurally unable to intercept the Ninox login form, which is a stronger guarantee than a promise not to. The system browser also carries the user's existing Ninox session and saved credentials, which a fresh in-app WebView would not, so this is very likely a UX improvement as well as a safety one.

**Contract.** Directly supports constraint 3 of the technical contract.

## ADR-019 — Read-consensus, provenance, and the derive/invent boundary

**Status:** Accepted — new in v0.2, the central lesson of the 16-document test

**Context.** The end-to-end test reported '10 of 16 records with arithmetic verified' at first pass. Inspecting out/ninox\_log.json's metodo\_base field for those 10 shows 9 were derived\_from\_gross — base and tax computed backward from the total by assuming a tax rate — and only 1 was label+arithmetic, a genuine cross-check between independently read values. A check built from derived operands is true by construction and proves nothing; this pattern produced three invented tax rates with no legal basis anywhere in the EU (9%, 30%, and 4.5%, the last one a currency-conversion mark-up, not a tax at all) and mis-corrected the product's own founding example, Shop A (base 16.51/total 19.98 written, against the correct 16.52/19.99 that the original prototype — which matched read candidates instead of deriving them — had already gotten right two versions ago). Separately, the same test showed the pipeline picking the maximum value across OCR passes rather than the majority, letting one noisy pass overrule three that agreed.

**Decision.** Three rules, applied in this order, in every extraction pipeline (photo, scanned PDF, and the OCR fallback of the invoice route):

* 1. Consensus before arithmetic. Where a value has several candidate readings (multiple OCR passes, multiple recognised variants), the value that a majority of passes agree on wins. A single outlier reading never overrides agreement between the others, however extreme its apparent confidence.
* 2. Read, don't derive, wherever the document allows it. The pipeline first tries to read all operands of an amount breakdown as they are printed — following the original prototype's solve\_amounts.py approach of matching independently read candidates against each other — before falling back to computing one from the others.
* 3. Derive by identity from read values only; never derive by assuming an unstated rate. base = total − tax is permitted when both total and tax were read, and is tagged derived, with no confirmatory effect on the confidence state. base = total ÷ (1 + assumed\_rate) is never permitted: if the rate is not printed, the breakdown stays empty. A derived tax rate is checked against the country table's legal set (ADR-005) before it is used for anything, and a negative-context dictionary (DCC mark-up, Skonto, advance payment, commercial-register terms such as Registro Mercantil/Tomo/Folio, HRB, Amtsgericht) suppresses candidates that are percentages or numbers in the document but are not, in fact, tax figures.

**Every value carries a provenance tag.** read, derived, repaired, or from\_xml (PDR §6.1). A value's provenance determines whether a check that consumes it may raise the confidence state: a check is only confirmatory if every operand feeding it has provenance read or from\_xml. This closes the exact gap the test exposed and is the mechanism behind the PDR's confidence-model rebuild (PDR §6).

**Consequences.** The pipeline will, correctly, leave more fields empty than the v0.1 design implied — this is the intended effect of PDR §4's 'empty over false' principle, not a regression. Implementing consensus and the derive/invent boundary is pure pipeline work, independent of which recognition engine is chosen, which is also why ADR-010 now requires this fix to be in place before a fresh screening can attribute its results to the engine rather than to the pipeline around it.

# 3. Open decisions and what closes them

|  |  |  |
| --- | --- | --- |
| **Ref** | **Open question** | **Closure criteria** |
| ADR-010 | Which text recognition engine for the photographed-paper route | ADR-019's pipeline fixes in place, plus a photographed-paper corpus extended to ~15 documents specifically covering thermal-paper hospitality and fuel receipts, plus at least one scanned PDF. Measured as per-field accuracy after validation, counting only read/from\_xml-provenance fields as eligible for 'confirmed'. Extend further if candidates tie. |
| ADR-011 | Which PDF text extraction library on Android | Confirmation of the proposal, verified against the positional-extraction acceptance criterion (label/value association, not just plain-text presence) over the sample-invoice corpus, and an application-size check. |

## 3.1 Also pending, outside this document

* Ninox attachment-upload limits still untested: maximum file size, multi-page PDF behaviour near that limit, real upload timings measured from the primary market rather than from a cloud container.
* Behaviour of a choice field written with text outside its declared options — unverified in both the original trace and the 16-document test.
* Availability check for the name Paperdrop in both app stores and in the EUIPO register.
* Purposeful extension of the test corpus for ADR-010, per the criterion above — not a general enlargement, and not undertaken for its own sake.