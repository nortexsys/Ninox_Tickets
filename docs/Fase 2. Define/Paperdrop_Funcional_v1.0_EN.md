**Paperdrop**

Functional Specification â€” version 1.0

**Project:** Paperdrop for Ninox (repository: Ninox\_Tickets)

**Owner:** Nortex Systems

**Phase:** FASE 2 â€” functional specification, pre-SDD

**Date:** 23 September 2026

**Status:** Draft for review. Supersedes `Funcional_App_NinoxTickets.md` and the v1.0 draft skeleton of this document.

**Related:** Paperdrop â€” Product Design Requirements (PDR), version 0.2 Â· Paperdrop â€” Architecture Decision Records (ADR), version 0.2

**Language:** Product and documentation in English, as required by the project brief.

# Change log

|  |  |  |
| --- | --- | --- |
| **Ref** | **Change** | **Motivated by** |
| v1.0 | First complete functional specification. Operationalises PDR v0.2 into verifiable requirements and references the accepted ADRs by identifier rather than restating them. | PDR v0.2, ADR v0.2. |
| v1.0 | Replaces the earlier 17-section draft skeleton of this document with the approved 12-section index. Behaviour is concentrated in Â§4 and Â§5; screen composition and navigation are separated into Â§7. | Product owner review of the skeleton. |
| v1.0 | Requirements that depend on the two open architecture decisions are marked `Blocked by ADR-010` / `Blocked by ADR-011` so that development can proceed on everything else. | ADR Â§3 â€” ADR-010 and ADR-011 remain Proposed. |
| v1.0 | Product principles re-expressed as testable business rules (BR-01 â€¦ BR-22) backed by the worked examples of Annex D. | PDR Â§4; the 16-document end-to-end test. |
| v1.0 | The "3 taps" expectation is stated precisely as an acceptance criterion: three taps plus one destination confirmation on the first capture of the day; five to six taps for a typical document. | PDR Â§6.2, Â§7.2. |

# Contents

1. Introduction

2. Overall description

3. Use cases and end-to-end flows

4. Functional requirements by module

5. Business rules catalogue

6. Data specification

7. Interface specification

8. Non-functional requirements

9. Error handling and user messaging

10. Acceptance criteria, metrics and validation

11. Traceability

12. Open items and risks

Annex A â€” Ninox API external contract

Annex B â€” Country table

Annex C â€” Keyword and negative-context dictionaries

Annex D â€” Worked examples

Annex E â€” Numbering and status conventions

# 1. Introduction

## 1.1 Purpose and role of this document

The PDR states **what** Paperdrop must be and **why**; the ADR records **how the architectural decisions were taken**. This document supplies the layer that is still missing: the **functional requirements themselves** â€” end-to-end flows, exact business behaviour, per-screen specification, an error taxonomy with user-visible behaviour, and an acceptance criterion for every requirement.

The decomposition obeys three rules:

1. **Operationalise the PDR, do not duplicate it.** Every product principle of PDR Â§4 is converted into at least one numbered business rule with an acceptance test in Â§5, rather than restated as an intention.
2. **Reference the ADRs by identifier.** A requirement cites `ADR-004`, `ADR-019`, and so on. No decision is reopened, summarised or re-argued here; where a requirement depends on a decision that is still open, the requirement says so and is marked blocked.
3. **Mark blocked requirements explicitly.** Requirements whose acceptance test cannot run until ADR-010 or ADR-011 closes carry status `Blocked by ADR-XXX`. Everything else is `Defined` and can be built and accepted today. This lets development advance on the whole of the specification except a small, bounded surface.

This document defines behaviour, not architecture. It names no library, framework or layer; those belong to the Software Design Document (SDD) of FASE 3. It supersedes `Funcional_App_NinoxTickets.md`, which the PDR v0.2 itself declares surpassed, and the earlier draft skeleton of this document whose index was replaced.

## 1.2 Scope of version 1

The scope is inherited from PDR Â§3.1 without change. The non-goals of PDR Â§3.2 are re-expressed here as **negative requirements** â€” statements of the form "the app neverâ€¦" â€” so that they can be tested rather than merely agreed. They are normative: BR-15, BR-16 and BR-19 in Â§5 carry them, and the acceptance corpus of Â§10 includes a negative check for each.

**In scope**

|  |  |
| --- | --- |
| **Area** | **Version 1** |
| Inputs | System document scanner (camera), device gallery and file picker, share-in from another application, and mail attachments shared as `.msg` or `.eml` containers. |
| Formats | Photographs, PDFs with a text layer, scanned PDFs without one, structured e-invoices (ZUGFeRD / Factur-X hybrid PDFs, XRechnung XML). Multi-page supported. |
| Extraction | Entirely on the device. |
| Output | One Ninox record per document, header level only, with the document attached. |
| Destination | Any team, database and table the user's API token can reach, chosen from lists read from the Ninox API. |
| Countries | Universal validation everywhere, plus a country table (DE / AT / CH / ES at launch). |
| Platforms | Android and iOS. Interface in English and German. |

**Out of scope, expressed as negative requirements**

* The app never provides a desktop application.
* The app never runs a backend service and never creates a Paperdrop user account.
* The app never writes line-item detail: one record per document, header only.
* The app never creates, renames or deletes fields or tables in the user's Ninox database.
* The app never deletes or modifies a record it did not create.
* The app never requests, stores or transmits a Ninox username or password. The API token is the only credential.
* The app never offers reporting, reconciliation or data export beyond the configuration file.
* The app never offers multi-user or team features inside the app.
* The app never synchronises between devices; configuration moves through an exportable file.
* The app never collects telemetry in a public build.
* The app never reads the body of a `.msg` / `.eml` message, only the document attachment it carries.

## 1.3 Related documents

|  |  |
| --- | --- |
| **Document** | **Role** |
| PDR v0.2 | Product definition; the *what* and the *why*. Sole source for scope, principles, data model, confidence model, screens and metrics. |
| ADR v0.2 | Architecture of the information; the *how it was decided*. Nineteen records, fifteen accepted, two proposed (ADR-010, ADR-011). |
| Internal review record | The triage of the seventeen findings raised against PDR v0.1, with verdict and action per finding. Cited in this document by finding number where the PDR or ADR change log cites it. |
| 16-document end-to-end test | The test that read, validated and wrote sixteen real documents into a disposable Ninox table. Its evidence is cited as "the test" throughout; the product owner's per-record verdicts are authoritative where they differ from the consultant's report. |
| `Funcional_App_NinoxTickets.md` | The original Spanish brief. Superseded; retained for provenance only. |

## 1.4 Glossary

|  |  |
| --- | --- |
| **Term** | **Meaning** |
| Team | A Ninox classic-API organisational unit containing databases. The API's own term; `workspace` is not used. |
| Destination | A team, a database, a table and a field mapping, plus a Ninox host. The unit the user picks before saving. |
| Canonical model | Paperdrop's fixed internal field set. What the mapping maps *from*; it does not constrain the user's schema. |
| Provenance | Per-value tag: `read`, `derived`, `repaired` or `from_xml`. Internal; never written to Ninox. |
| Consensus | The rule that a majority of recognition-pass readings wins over any single outlier. |
| Redundancy | Agreement between two or more values that were each read independently, through an identity such as base + tax = total. |
| Operand | A value consumed by a check. A check is only confirmatory if every operand is `read` or `from_xml`. |
| Slot | One tax triplet (rate / base / amount). The country table declares how many exist. |
| Minor unit | The currency's smallest unit (cents for EUR). All amounts are integers of it. |
| Basis point | One hundredth of a percent. 21% = 2100. All rates are integers of basis points. |
| Confidence state | The green / amber / red state shown on the review screen; derived from provenance and checks, never from a numeric score shown to the user. |
| Abstention | A mapped amount field left empty because no reading could be sustained. Deliberately non-zero by design. |
| Negative context | Document terms (DCC mark-up, *Skonto*, commercial-register boilerplate) whose numbers must be suppressed as tax candidates. |
| Supplier memory | The local store of supplier identifierâ€“name pairs, indexed only by identifiers that passed their check digit. |
| Reverse charge | Inversion of the taxable person; the supplier's invoice shows tax lines at 0. |
| ZUGFeRD / Factur-X | A PDF/A-3 with a legally authoritative XML embedded as an attachment. |
| XRechnung | A standalone structured e-invoice XML, in UBL or CII syntax. |
| Profile level | The field coverage of an e-invoice XML: `MINIMUM`, `BASIC WL`, `BASIC`, `EN16931`, `EXTENDED`, `XRECHNUNG`. A missing field in a low profile is `not_in_xml`, not absent. |
| Read-back | The mandatory read of the record after create; the only visibility into defaults, formulas and automations. |
| Screening | The initial per-field run over the photographed-paper corpus. A filter to eliminate an unusable engine, not a measurement. |
| Deep link | The URL built from data the app already holds to open the created record in Ninox. |

## 1.5 Conventions

**Requirement identifiers.** Four series, each with a two-part number:

|  |  |  |
| --- | --- | --- |
| **Series** | **Form** | **Content** |
| FR | `FR-<MOD>-nn` | Functional requirement. `<MOD>` is the module code of Â§4: CAP, EXT, VAL, REV, DST, WIZ, SND, HIS, MEM, CFG, CTR, DUP. |
| BR | `BR-nn` | Business rule. Cross-cutting, testable, sourced. Catalogued in Â§5. |
| NFR | `NFR-nn` | Non-functional requirement. Catalogued in Â§8. |
| UC | `UC-nn` | Use case: a real end-to-end journey. Catalogued in Â§3. |

**Status values.**

|  |  |
| --- | --- |
| **Status** | **Meaning** |
| Defined | The requirement is complete, unambiguous and can be built and accepted against its stated criterion today. |
| Blocked by ADR-XXX | The requirement is specified and its behaviour is fixed, but its acceptance test cannot run until the named open decision closes. Development may proceed against the stated behaviour; the decision is not reopened here. |
| Deferred | Deliberately out of v1; listed so it is not forgotten. |

**Priority.** `Must` (v1) Â· `Should` (desirable, may slip a release) Â· `May` (explicitly not promised).

**Representation conventions.**

* Money is an integer in the currency's minor unit (ISO 4217 exponent). Never a float, never a formatted string (ADR-016).
* Tax rates are integers in basis points (2100 = 21%).
* Dates are `YYYY-MM-DD`; times `HH:MM`.
* RFC-style keywords: **shall** / **must** are mandatory in v1; **should** is desirable; **may** is an option, explicitly not promised.

**Examples.** All figures in this document are synthetic or refer to legal entities whose fiscal identifiers are public. No natural person's data is reproduced (project operating rule).

**Every requirement states its acceptance condition.** Anything that cannot be accepted is an intention, not a requirement, and has no place in Â§4 or Â§5.

# 2. Overall description

## 2.1 Product context

Paperdrop is a free, open-source Android and iOS application, published by Nortex Systems, that reads receipts and supplier invoices **on the device** and writes one record per document into the user's own Ninox database, with the original document attached.

It is a complement to Ninox, not a substitute for it. It puts documents in and does nothing else: reporting, reconciliation and accounting remain what the user already has Ninox for (PDR Â§1). There is no backend, no Paperdrop account, and no call to a hosted model (ADR-002). Capture works without connectivity; a send is queued until the connection returns.

The distinguishing asset is not reading but the **deterministic layer above reading**: check digits, arithmetic on independently read values, legal-rate checks and negative-context suppression confirm or correct a reading instead of trusting it (PDR Â§1.1). The prototype demonstrated it â€” a barcode confirmed against its EAN-13 check digit, a tax identifier repaired to the only check letter it admits, an ambiguous total resolved by arithmetic â€” and the 16-document test sharpened the claim: a check performed on derived operands is a tautology, so provenance now governs which check may confirm anything (PDR Â§6.1, ADR-019).

## 2.2 Users and journeys

The addressed user is an existing Ninox customer who records expenses in a Ninox database, concentrated in German-speaking Europe (PDR Â§2).

Two document journeys carry equal weight in v1, and both must be first-class in the interface and the corpus:

* **Photographed paper** â€” restaurant, taxi, fuel, parking, small purchases. Captured with the device camera through the platform document scanner. Recognition is hard; the validation layer earns its place here.
* **Supplier invoices** â€” PDFs and structured e-invoices arriving by email, shared into the app from the mail client. Reading is near-perfect for the e-invoice case; the difficulty for plain PDFs is layout variation between issuers.

The 16-document test skewed toward B2B invoices, bank slips and non-EUR documents. It is one user and sixteen documents, not a market conclusion, and the product owner has decided not to reweight the routes on that basis â€” but two consequences are carried into this specification: the acceptance corpus keeps two halves (Â§10.1), and the first-run experience must not assume a receipt (FR-WIZ-008, UC-01).

**Consequence for the first execution.** A professional user's first document is as likely to be an invoice as a receipt, so the wizard closes by offering to capture a document of any kind, and the review screen's muscle-memory field order (FR-REV-004) is identical for both routes.

## 2.3 Platforms and environment

* Android and iOS, one Flutter codebase (ADR-001). The iOS Share Extension is native Swift in the same project; Android intake is a share-intent filter with no separate component.
* Capture uses the platform document scanner â€” ML Kit Document Scanner on Android, VisionKit document camera on iOS â€” never a raw camera view (ADR-006).
* **iOS Share Extension constraint (ADR-001).** A Share Extension has a tight memory ceiling: it cannot run recognition or show the review screen. On iOS, sharing hands the document to the app, which opens directly into review. The extension is budgeted as native work, not discovered late. A small native bridge to the iOS Vision / VisionKit frameworks may be required.
* Extraction is entirely on the device; no network dependency for reading (ADR-002).
**Android dependency.** The ML Kit document scanner is part of Google Play Services (ADR-006), which excludes devices without it. This coupling is noted in ADR-010: arguing for a fully open Android build requires replacing the scanner as well as the recognition engine.

## 2.4 Constraints

The technical contract of PDR Annex A is binding on this specification and is reproduced as **Annex A** of this document for interface-reference purposes. Its eight lines are re-expressed here as verifiable constraints; each is traced to a requirement in Â§11.

|  |  |  |
| --- | --- | --- |
| **#** | **Constraint, as a verifiable requirement** | **Traced to** |
| 1 | The app shall operate with no backend service, in any version. | BR-19, NFR-PRV-001 |
| 2 | No user data shall leave the device except toward the user's own Ninox database. Platform components may emit their own operational diagnostics, never document content. | NFR-PRV-002, NFR-PRV-003 |
| 3 | No Ninox username or password shall ever be requested, stored or transmitted. The API token is the only credential, obtained through the platform's system browser, never an app-controlled WebView. | BR-19, FR-WIZ-003 |
| 4 | A value shall be presented as confirmed only when a deterministic constraint establishes it from values that were themselves read, not derived by assumption. | BR-01, BR-02, BR-05 |
| 5 | Every proprietary dependency shall be declared in the repository README. | NFR-LIC-001 |
| 6 | The app shall never write a field the user has not explicitly mapped, and never create, alter or delete schema or records it did not create. | BR-15, BR-16, BR-21 |
| 7 | No telemetry shall be collected in public builds. | NFR-PRV-006 |
| 8 | A document originally received as a PDF shall be attached exactly as received; only camera captures shall be assembled into a new PDF. | BR-17, FR-CAP-004, FR-CAP-005 |

## 2.5 Assumptions and dependencies

**Assumptions.**

* The Ninox classic API remains available for the foreseeable future. It is described by the vendor as the previous generation; the client is isolated behind a port so a second implementation can be added without touching the rest of the application (ADR-003). The decision is revisited if deprecation is announced.
* The user's API token carries write permission on the destination table; the app does not verify permissions beyond the token's own validity (original brief, item VI).
* The user's table is suitable for header-level expense records. No table is unsuitable for the attachment, because in Ninox a file is attached to the record rather than to a field (ADR-007).

**Dependencies.**

* Google Play Services on Android, for the document scanner (ADR-006) and, if ADR-010 selects the platform engine, for recognition.
* VisionKit / Vision on iOS for capture and, if selected, recognition.
* The Ninox classic REST API for every write path.
* **Open decisions.** ADR-010 (recognition engine for the photo route) and ADR-011 (PDF text-extraction library) are still Proposed. Requirements affected are marked `Blocked by ADR-010` / `Blocked by ADR-011`; Â§12 carries the closure criteria.


# 3. Use cases and end-to-end flows

One use case per real journey. Each carries preconditions, the main flow, the alternative flows that are actually reachable, and the acceptance condition that proves the journey works. Screen composition for each is in Â§7; requirement-level behaviour is in Â§4.

## Use case inventory

|  |  |  |
| --- | --- | --- |
| **ID** | **Journey** | **Route / trigger** |
| UC-01 | First run and setup wizard | App first launch |
| UC-02 | Clean document | Any route; validates completely |
| UC-03 | Typical document | Any route; amber fields to glance at |
| UC-04 | Structured e-invoice | `einvoice` |
| UC-05 | Card-terminal slip | `photo` / `pdf_text` |
| UC-06 | Multi-rate receipt | `photo` / `pdf_text` |
| UC-07 | Cash withdrawal abroad (DCC) | `pdf_text` |
| UC-08 | Mail container with several attachments | `.msg` / `.eml` share-in |
| UC-09 | Duplicate detected | Any route |
| UC-10 | Offline capture and queued send | Any route, no connectivity |
| UC-11 | Create with an uncertain outcome | `send`, response lost |
| UC-12 | Correct and re-send from history | History entry |
| UC-13 | Device migration | New device |
| UC-14 | Scanned PDF without a text layer | `pdf_scan` |
| UC-15 | Supplier recognised from memory | Any route, known supplier |

---

## UC-01 â€” First run and setup wizard

|  |  |
| --- | --- |
| **Actor** | The user, on a first launch with no destination configured. |
| **Preconditions** | The user has a Ninox account and can reach the Ninox settings page to copy an API token. Connectivity is available. |
| **Main flow** | 1. The app opens with no destination and offers the wizard; there is no built-in default destination (FR-DST-002). 2. Token step: instructions for obtaining a token, a paste-from-clipboard button, and an option to open the Ninox settings page in the platform's own system browser (FR-WIZ-003). 3. The user returns and pastes the token; it is validated immediately, and a successful call returns the team list for the next step. 4. Team â†’ database â†’ table, each chosen from a list; a step with only one option is skipped automatically (FR-WIZ-002). The table listing returns the schema in the same call, so there is no extra round trip. 5. Mapping step: the six core fields are each shown as a pre-filled proposal over a hard type filter and a synonym ranking with a strict threshold; the user corrects only what is wrong (FR-WIZ-005, FR-WIZ-006). 6. The wizard closes with a plain-language summary of what will and will not be saved, and offers to capture the first document (FR-WIZ-008). |
| **Alternative flows** | a) The user maps nothing at all: the summary reads "only the document will be attached, with no data"; finishing is allowed. b) The token fails validation: the step stays, the error is shown, no partial destination is stored. c) A step's list cannot be read (connectivity lost mid-wizard): the step retries with bounded backoff; the user may cancel and resume later with nothing stored. |
| **Postconditions** | Exactly one destination exists, storing field identifiers (not names), the host, and the mapping. The token is in the platform keystore/keychain, not in the destination. |
| **Acceptance** | A first-run user reaches a working destination in at most five screens; with single-option steps the visible count is two (token + mapping). The stored destination resolves field names correctly at send time after a column rename. |
| **Source** | PDR Â§7.3, Â§8 Â· ADR-003, ADR-017, ADR-018 |

## UC-02 â€” Clean document

|  |  |
| --- | --- |
| **Actor** | The user with at least one configured destination. |
| **Preconditions** | The document validates completely: every core field read, and at least one amount confirmed by redundancy. |
| **Main flow** | 1. The user captures or shares the document (FR-CAP-001). 2. Extraction runs to completion and the app opens directly into review. 3. The destination bar shows the last destination used. If this is the first capture of the calendar day, the bar is highlighted and the save button stays disabled until the user acknowledges it once (FR-REV-002). 4. Focus jumps to the first unread field; every core field is green and the amounts block is collapsed to one confirming line (FR-REV-004, FR-REV-005). 5. The user taps Save. The button names the destination. 6. The send pipeline runs: create â†’ attach â†’ read-back (FR-SND-001). 7. The confirmation screen shows what is actually stored and offers to open the record in Ninox by deep link (FR-SND-006). |
| **Alternative flows** | a) Not the first capture of the day: no destination confirmation, saving is immediate. b) No connectivity at save time: the document is queued and sent automatically on return (UC-10). |
| **Postconditions** | Exactly one Ninox record exists with the document attached; the local entry is `sent`; the document image is deleted locally. |
| **Acceptance** | **Three taps plus one destination confirmation on the first capture of the day** â€” capture, (destination confirm,) save. No field is edited (PDR Â§7.2, Â§6.2). |
| **Source** | PDR Â§6.2, Â§7.2, Â§9 Â· ADR-008 |

## UC-03 â€” Typical document

|  |  |
| --- | --- |
| **Actor** | The user. |
| **Preconditions** | The document is read but not every field can be confirmed: the document number and the supplier name are amber, or an amount has no breakdown to cross-check. |
| **Main flow** | 1. Capture / share, extraction, review opens as UC-02. 2. The user glances at the amber fields; tapping one draws a box around the region it was read from (FR-REV-003). 3. The user corrects or accepts each amber field without unlocking any green field. 4. Save â†’ send â†’ confirmation as UC-02. |
| **Alternative flows** | a) A red field: the value is not written; the record is created with the attachment and the fields that could be sustained (BR-03, BR-14). b) The user disagrees with a green value: tapping the lock unlocks it for editing (FR-VAL-003). |
| **Postconditions** | As UC-02. The untouched-rate metric counts this document as edited (Â§10.4). |
| **Acceptance** | **Five to six taps** for a typical document (PDR Â§6.2). This figure is a release criterion, not a disappointed reaction to a demonstration. |
| **Source** | PDR Â§6.2, Â§7.2 |

## UC-04 â€” Structured e-invoice

|  |  |
| --- | --- |
| **Actor** | The user receiving ZUGFeRD / Factur-X hybrid PDFs or standalone XRechnung XML by mail. |
| **Preconditions** | The shared document carries embedded or attached XML. |
| **Main flow** | 1. The document is shared in from the mail client (FR-CAP-001). 2. The invoice route tries extraction methods in order and stops at the first success: XML first (ADR-014). 3. The parser identifies the syntax (UBL / CII) and the profile level and reads field by field, deterministically; every value carries provenance `from_xml` (FR-EXT-003). 4. The app opens into review. Core fields are shown as confirmed â€” the strongest form of confirmation in the product, stronger than any redundancy check, because the source is a machine-readable record (ADR-014). 5. The document is attached byte-for-byte as received (FR-CAP-005). 6. Save â†’ send â†’ confirmation. |
| **Alternative flows** | a) A `MINIMUM` or `BASIC WL` profile: a field the XML does not carry is `not_in_xml`, not absent; the review screen shows it as absent, never as zero (FR-EXT-003, BR-13). b) The XML is malformed or is a deliberately erroneous sample: the XML route fails, the app falls to the positional text route, and the user is not told the document is an e-invoice. c) The PDF has no text layer and no XML: the page is rendered and sent through the OCR pipeline (UC-14). |
| **Postconditions** | One record; the attached bytes are identical to the received bytes, embedded XML intact. |
| **Acceptance** | Given a Factur-X `EN16931` sample, every core field the profile carries is presented as confirmed with no recognition pass involved; the SHA-256 of the attachment equals that of the input. |
| **Source** | PDR Â§3.1 Â· ADR-014, ADR-015 |

## UC-05 â€” Card-terminal slip

|  |  |
| --- | --- |
| **Actor** | The user photographing a card-terminal receipt. |
| **Preconditions** | The document prints a total and no breakdown. |
| **Main flow** | 1. Capture, extraction, review. 2. The total is read and shown amber â€” an amount with nothing to be redundant against is **never green**, however cleanly it was read (BR-04). 3. The amounts block is expanded, because the redundancy check did not pass (FR-REV-005). 4. The destination's per-field setting decides what "not printed" means for the VAT column: empty (default) or zero (FR-DST-006). 5. Save â†’ send â†’ confirmation. |
| **Alternative flows** | a) The user knows the breakdown and enters it manually; the entered values are authoritative. |
| **Postconditions** | One record carrying the total and, for the VAT column, exactly what the destination's absent-value setting prescribes. |
| **Acceptance** | Given a terminal slip with total 19.40 and no printed breakdown: the total is amber and never green; the VAT column receives empty or zero strictly per the per-field setting; no rate is assumed; the record is created. |
| **Source** | PDR Â§6, Â§7.2, Â§7.3 Â· 16-document test, record 1414 (product owner's verdict: the record is correct). |

## UC-06 â€” Multi-rate receipt

|  |  |
| --- | --- |
| **Actor** | The user photographing a receipt with several tax rates. |
| **Preconditions** | The document prints two or more rate / base / amount triplets. |
| **Main flow** | 1. Capture, extraction. 2. Each printed rate is read into its own slot; the country table declares how many slots exist and which rates are legal (FR-VAL-011). 3. Consolidation sums the printed bases and the printed tax amounts; `tax_total`, where mapped, is the sum of printed amounts, never computed from an assumed rate (PDR Â§5.3). 4. Review shows the amounts block, expanded unless a redundancy check passes across all slots. 5. Save â†’ send â†’ confirmation. |
| **Alternative flows** | a) A rate that is not in the country table's legal set: the slot is not written as a tax line; a derived rate is rejected before use (FR-EXT-009). b) More printed rates than the country has slots: the surplus is reported to the user as a review issue, not silently aggregated. |
| **Postconditions** | One record with one triplet per printed rate; no aggregation of distinct rates into a single pair. |
| **Acceptance** | Given a receipt printing 19% and 7% lines, both triplets survive into the mapped slots; the record does not contain a single collapsed pair. |
| **Source** | PDR Â§5.3 Â· 16-document test, record 1425 (two rates and two bases). |

## UC-07 â€” Cash withdrawal abroad (DCC)

|  |  |
| --- | --- |
| **Actor** | The user with a card charge settled in a currency different from the document's. |
| **Preconditions** | The document is a cash withdrawal or a card charge carrying a conversion mark-up. |
| **Main flow** | 1. Share / capture, extraction. 2. Currency is detected from the document's own evidence â€” printed ISO code, symbol, issuer country â€” and carries its own confidence state (BR-12). 3. The mark-up is not a tax: it is suppressed as a tax candidate by the negative-context dictionary and the legal-rate check, and is read into `surcharges[]` with label `dcc_markup` (FR-EXT-010). 4. The two amounts â€” document currency and card currency â€” plus the exchange rate are captured into the currency group (PDR Â§5.2). 5. Review, save, send. |
| **Alternative flows** | a) The currency cannot be sustained from evidence: the amounts are not written; the record carries the document and whatever could be sustained (BR-03, BR-12). |
| **Postconditions** | One record in which the mark-up is not presented as a tax line under any rate. |
| **Acceptance** | Given a withdrawal with a printed conversion percentage, the written record contains a surcharge entry, not a tax line at that percentage; a pipeline that reads the mark-up as a VAT rate fails this case (the failure the 16-document test produced, record 1428). |
| **Source** | PDR Â§5.2 Â· ADR-019 Â· 16-document test, record 1428 (product owner's verdict: correct as produced). |

## UC-08 â€” Mail container with several attachments

|  |  |
| --- | --- |
| **Actor** | The user sharing a mail item from the platform mail client. |
| **Preconditions** | The shared `.msg` or `.eml` carries more than one attachment â€” typically the document plus the sender's signature image. |
| **Main flow** | 1. The app ingests the container and never reads the message body (FR-CAP-006). 2. The selection rule runs: prefer the largest PDF or image by content, excluding common signature-image dimensions and filenames (FR-CAP-007). 3. Exactly one plausible candidate remains; it is used. 4. Extraction and review proceed on the selected attachment; the attachment is preserved byte-for-byte. |
| **Alternative flows** | a) More than one plausible candidate remains after the rule: the app offers the candidate list and the user picks. b) No candidate is a document: the app reports that the mail carries no usable attachment and creates nothing. |
| **Postconditions** | One record whose attachment is the selected document, not the signature image. |
| **Acceptance** | Given a `.msg` containing an invoice PDF and `image001.png` of typical signature dimensions, the app selects the invoice without asking. |
| **Source** | PDR Â§7.1 Â· 16-document test (containers carried a signature image alongside the document). |

## UC-09 â€” Duplicate detected

|  |  |
| --- | --- |
| **Actor** | The user capturing a document already sent. |
| **Preconditions** | A earlier send exists whose document hash matches, or whose supplier, date and total together match. |
| **Main flow** | 1. Capture, extraction, review opens. 2. The duplicate check runs against local history (FR-DUP-001). 3. A duplicate notice is shown, linking to the existing record (FR-REV-007, FR-DUP-002). 4. The user opens the existing record by deep link, or proceeds anyway. |
| **Alternative flows** | a) The user proceeds: a second record is created, deliberately; the history marks both. |
| **Postconditions** | The user made an informed choice; no silent duplicate and no blocked save. |
| **Acceptance** | Given the same document captured twice, the second review shows the notice before save and the deep link opens the first record. |
| **Source** | PDR Â§7.2 |

## UC-10 â€” Offline capture and queued send

|  |  |
| --- | --- |
| **Actor** | The user with no connectivity. |
| **Preconditions** | A configured destination; device offline. |
| **Main flow** | 1. Capture and extraction work without connectivity â€” reading is entirely on the device (ADR-002). 2. Review works; the user saves. 3. The send enters the pending/queued state; the history entry shows it (FR-HIS-002). 4. Connectivity returns; the queue is sent automatically, in order, with the normal pipeline (FR-SND-004). |
| **Alternative flows** | a) The user turns the device off before the queue drains: the entries survive as pending and send on the next launch. b) A queued send fails with 401/403: it is marked failed with an authentication error, not retried forever. |
| **Postconditions** | Every queued document is eventually sent or reports a failure the user can act on. |
| **Acceptance** | With aeroplane mode on, a document is captured, reviewed and saved; the history entry reads queued; after reconnect it reaches `sent` with no user action. |
| **Source** | PDR Â§3.1, Â§9.1 Â· ADR-002 |

## UC-11 â€” Create with an uncertain outcome

|  |  |
| --- | --- |
| **Actor** | The user; the app, on an uncertain create. |
| **Preconditions** | Connectivity; a reviewed document; the create POST's response is lost to a network error or timeout. |
| **Main flow** | 1. The app POSTs the create; the response is lost. 2. The document enters the `uncertain` state; the create is **never retried blindly** (BR-21). 3. The app reads the destination table's most recent records and matches by the mapped fields plus `createdAt` / `createdBy` within a short time window (FR-SND-005). 4. Exactly one match is found: the app adopts it and continues to the attachment step as if the create had returned normally. |
| **Alternative flows** | a) No match: the record is created, and the flow continues. b) Ambiguous â€” more than one plausible match, or too few mapped fields to compare: the app surfaces the uncertainty and asks the user to choose; it never guesses (FR-SND-005). |
| **Postconditions** | Exactly one record exists; no blind duplicate; the document reaches `sent`. |
| **Acceptance** | Given a create whose response is dropped, no duplicate record is created whether the original POST landed or not; the extra read call occurs on the uncertain path only and the common path is unaffected. |
| **Source** | PDR Â§9.1 Â· ADR-013 Â· Finding 1 |

## UC-12 â€” Correct and re-send from history

|  |  |
| --- | --- |
| **Actor** | The user reviewing a past send. |
| **Preconditions** | A history entry in `failed`, or a `sent` entry the user wants to correct. |
| **Main flow** | 1. The user opens history and the entry's detail (FR-HIS-001). 2. The detail shows the thumbnail, the values with their provenance, the destination, the state, the confidence, the document hash and the Ninox record identifier once sent. 3. The user edits a value; because updates are merges, the correction sends only what changed (FR-SND-009). 4. The send pipeline runs; the read-back shows what is now stored. |
| **Alternative flows** | a) The entry is `failed` and its file was retained: the user corrects and re-sends the same document. b) The entry is `sent`: the local image was deleted on confirmation, so the correction operates on the stored values; the attachment is not re-uploaded unless it failed. |
| **Postconditions** | The existing record is updated in place; no second record is created. |
| **Acceptance** | Correcting a base amount in history changes exactly that field in the Ninox record and leaves every other mapped value untouched. |
| **Source** | PDR Â§7.5, Â§9.1 Â· ADR-004 |

## UC-13 â€” Device migration

|  |  |
| --- |--- |
| **Actor** | The user moving to a new device. |
| **Preconditions** | An export file exists and is reachable on the new device. |
| **Main flow** | 1. On the old device the user exports the configuration: destinations, mappings and supplier memory (FR-CFG-001). The file never carries the API token. 2. On the new device the user imports the file and re-enters the token, which is validated exactly as in the wizard (FR-CFG-002). 3. The destinations resolve field names from a freshly read schema; the supplier memory is restored intact. |
| **Alternative flows** | a) The export file is stale relative to a renamed column: the destination resolves names at send time and reports unmapped fields rather than writing to a wrong column. |
| **Postconditions** | The new device reaches a working state without a fresh wizard and without a backend. |
| **Acceptance** | After export â†’ import â†’ token, a document can be sent to the same destination with no further configuration; the supplier memory recognises a previously seen supplier. |
| **Source** | PDR Â§3.2 Â· ADR-009 |

## UC-14 â€” Scanned PDF without a text layer

|  |  |
| --- |--- |
| **Actor** | The user sharing a scanned invoice. |
| **Preconditions** | A PDF with no text layer and no embedded XML. |
| **Main flow** | 1. The invoice route tries XML (absent), then the text layer (absent), and falls back to rendering the page and sending it through the OCR pipeline, exactly like the photo route (FR-EXT-005, ADR-014). 2. Consensus, read-before-derive and validation run as on the photo route. 3. The attachment is preserved byte-for-byte â€” rendering for OCR is a read-only operation and never re-saves the source (FR-CAP-005, ADR-015). |
| **Alternative flows** | a) The render fails: the document is reported unreadable and nothing is created. |
| **Postconditions** | One record; the attached PDF is the received PDF, unmodified. |
| **Acceptance** | Given a scanned PDF, the extraction path taken is render+OCR and the attached file's hash is unchanged. This route was exercised by zero documents in the 16-document test and is named in ADR-010's closure criteria. |
| **Status** | Route defined; engine quality **blocked by ADR-010**. |
| **Source** | PDR Â§13 Â· ADR-010, ADR-011, ADR-014 |

## UC-15 â€” Supplier recognised from memory

|  |  |
| --- |--- |
| **Actor** | The user capturing a document from a supplier seen before. |
| **Preconditions** | The supplier memory holds an entry for this supplier, indexed by a tax identifier that passed its check digit. |
| **Main flow** | 1. Capture, extraction; the tax identifier is read and passes its check digit (FR-VAL-005). 2. The memory lookup finds the stored name and offers it (FR-MEM-003). 3. The supplier name is presented as confirmable â€” memory is the only mechanism that can confirm a name (BR-11). |
| **Alternative flows** | a) The identifier does not pass its check digit: the memory is not consulted and no entry is created or offered; an uncertain reading must never enter the store (FR-MEM-002). b) The user corrects the name: the correction is offered for the memory, and the updated pair is stored on send. |
| **Postconditions** | The record carries the confirmed name; the memory holds the identifierâ€“name pair. |
| **Acceptance** | A second document from the same supplier presents the name as confirmed without a lookup error; an identifier that fails its check digit never seeds the memory. |
| **Source** | PDR Â§6.2, Â§11 Â· ADR-009 |


# 4. Functional requirements by module

Behaviour, module by module. Each requirement carries its own acceptance condition, its source, and its status. Requirements whose acceptance test cannot run until an open decision closes are marked `Blocked by ADR-010` or `Blocked by ADR-011`; the behaviour is fixed and may be built, the decision is not reopened (Â§1.5). Screen composition for these behaviours is in Â§7.

## 4.1 FR-CAP â€” Capture

### FR-CAP-001 â€” One entry point, four input paths

|  |  |
| --- | --- |
| **Requirement** | The app shall offer exactly one capture entry point reached by four paths: the system document scanner, the device gallery or file picker, share-in from another application, and a mail attachment shared as `.msg` or `.eml`. All four paths deliver into the same pipeline. |
| **Acceptance** | A document arriving by each of the four paths reaches the same review screen with the same field set and the same available actions. |
| **Source** | PDR Â§3.1, Â§7.1 |
| **Status / priority** | Defined Â· Must |

### FR-CAP-002 â€” Platform document scanner for camera capture

|  |  |
| --- | --- |
| **Requirement** | Camera capture shall use the platform's document scanner â€” ML Kit Document Scanner on Android, VisionKit document camera on iOS â€” never a raw camera view. Edge detection, perspective correction, contrast enhancement and multi-page chaining come from the platform; the prototype's pre-processing stage is not ported. |
| **Acceptance** | A photographed receipt reaches extraction having been cropped and deskewed by the platform; the application contains no perspective-correction or binarisation code of its own. |
| **Source** | PDR Â§7.1 Â· ADR-006 |
| **Status / priority** | Defined Â· Must |

### FR-CAP-003 â€” Multi-page documents are one expense

|  |  |
| --- | --- |
| **Requirement** | Several captured or shared pages shall produce one record with one multi-page attachment. Extraction shall read every page before consolidating into a single canonical model. |
| **Acceptance** | A two-page receipt produces one record and one attachment containing both pages in order; fields read from either page appear in the same review screen. |
| **Source** | PDR Â§7.1, Â§5.3 |
| **Status / priority** | Defined Â· Must |

### FR-CAP-004 â€” Camera captures are assembled into one PDF

|  |  |
| --- | --- |
| **Requirement** | A document produced by the device's own camera capture shall be assembled into a single PDF â€” cropped, deskewed and enhanced by the platform scanner â€” and that assembled PDF is what is attached. |
| **Acceptance** | A camera capture of one page is attached as a PDF; a multi-page capture is attached as one multi-page PDF. |
| **Source** | PDR Â§7.1 Â· ADR-007 Â· Contract 8 |
| **Status / priority** | Defined Â· Must |

### FR-CAP-005 â€” Received files are attached byte-for-byte

|  |  |
| --- | --- |
| **Requirement** | A document that arrives already as a file â€” a PDF shared from another app, an e-invoice, an attachment pulled from a `.msg` / `.eml` â€” shall be attached exactly as received, byte for byte. The app shall never re-save, re-render, flatten or re-compress it. Opening a file for extraction â€” reading a text layer, extracting an embedded XML, rendering a page for OCR â€” shall be read-only by construction. |
| **Acceptance** | For a shared PDF, the SHA-256 of the attached file equals that of the input, before and after extraction. For a ZUGFeRD / Factur-X PDF, the embedded XML survives the pipeline and is extractable from the attachment. |
| **Source** | ADR-007, ADR-015 Â· Contract 8 Â· Finding 6 |
| **Status / priority** | Defined Â· Must |

### FR-CAP-006 â€” Mail containers deliver attachments, never message bodies

|  |  |
| --- | --- |
| **Requirement** | Sharing a `.msg` or `.eml` item shall ingest only its attachments. The message body shall never be read, parsed or stored. |
| **Acceptance** | No byte of a message body appears in any extracted value, in history, or in the attached file; the app creates nothing from a container with no document attachment. |
| **Source** | PDR Â§3.2, Â§7.1 |
| **Status / priority** | Defined Â· Must |

### FR-CAP-007 â€” Attachment selection rule for multi-attachment containers

|  |  |
| --- | --- |
| **Requirement** | Where a mail container carries more than one attachment â€” typically the document plus the sender's signature image â€” the app shall apply a selection rule: prefer the largest PDF or image by content, excluding common signature-image dimensions and filenames. Where more than one plausible candidate remains, the app shall offer the list and let the user choose. |
| **Acceptance** | A container holding an invoice PDF and a signature-scale PNG selects the invoice silently; a container holding two invoice-scale PDFs asks. |
| **Source** | PDR Â§7.1 Â· 16-document test |
| **Status / priority** | Defined Â· Must |

### FR-CAP-008 â€” iOS share-in hands the document to the app

|  |  |
| --- | --- |
| **Requirement** | On iOS, the Share Extension shall hand the document to the application and the app shall open directly into review. The extension shall not run recognition or render the review screen. Android intake shall use a share-intent filter and needs no separate component. |
| **Acceptance** | Sharing from the platform mail client on iOS lands on the review screen without an intermediate view in the extension; the extension's memory use stays within the platform ceiling. |
| **Source** | ADR-001 |
| **Status / priority** | Defined Â· Must |

### FR-CAP-009 â€” Capture without connectivity

|  |  |
| --- | --- |
| **Requirement** | Capture and extraction shall work with no connectivity. A save performed offline shall queue the send rather than fail it. |
| **Acceptance** | In aeroplane mode a document is captured, extracted, reviewed and saved; the history entry reads queued until connectivity returns. |
| **Source** | PDR Â§3.1 Â· ADR-002 |
| **Status / priority** | Defined Â· Must |

## 4.2 FR-EXT â€” Extraction pipeline

### FR-EXT-001 â€” The pipeline order is fixed

|  |  |
| --- | --- |
| **Requirement** | The extraction pipeline shall run in this order and no other: (1) consensus between candidate readings; (2) read all printed quantities, matching independently read candidates against each other; (3) derive by identity only, from read values; (4) validation; (5) write; (6) read back; (7) compare with the destination's formula fields. |
| **Acceptance** | Inspection of the pipeline shows the seven stages in this order; a stage never consumes the output of a stage that runs after it. |
| **Source** | PDR Â§6.1, Â§7.4 Â· ADR-019 |
| **Status / priority** | Defined Â· Must |

### FR-EXT-002 â€” Invoice route priority: XML, then positional text, then OCR

|  |  |
| --- | --- |
| **Requirement** | The invoice route shall try extraction methods in a fixed order and stop at the first that succeeds: (1) embedded or attached XML â€” ZUGFeRD / Factur-X inside the PDF, or standalone XRechnung â€” read deterministically with provenance `from_xml`; (2) the PDF's text layer, extracted with word-level positions; (3) page render and OCR, exactly like the photo route. |
| **Acceptance** | For a Factur-X PDF the XML route is taken and no OCR pass runs; for a plain text-layer PDF route 2 is taken; for a scanned PDF route 3 is taken. The route chosen is recorded in the recognition-engine metadata. |
| **Source** | ADR-014 Â· Finding 12 |
| **Status / priority** | Defined Â· Must |

### FR-EXT-003 â€” Structured XML extraction

|  |  |
| --- | --- |
| **Requirement** | XML extraction shall be deterministic, field by field, and shall distinguish XRechnung's syntaxes (UBL, CII) and the ZUGFeRD / Factur-X profile levels. A field the profile does not carry shall be reported as `not_in_xml`, never as absent. Extraction shall be a read-only operation on the carrying PDF. |
| **Acceptance** | Given an `EN16931` sample, every field the profile carries is read deterministically; given a `MINIMUM` sample, a field the profile omits is shown as `not_in_xml` and never as zero. The carrying PDF is unmodified afterwards. |
| **Source** | ADR-014, ADR-015 |
| **Status / priority** | Defined Â· Must |

### FR-EXT-004 â€” Positional PDF text extraction

|  |  |
| --- | --- |
| **Requirement** | Text-layer extraction shall associate a label with the value nearest it in the document's **visual layout**, using word-level coordinates. Plain-text extraction â€” associating by extraction order alone â€” shall not be accepted as an implementation. |
| **Acceptance** | Given an invoice whose label and value sit on different lines, the correct value is bound to its label. The case this rule exists to prevent: a registry volume reference ("Tomo 8.741") picked up as the total because the parser's last-resort fallback took the nearest number in extraction order. |
| **Source** | ADR-011 Â· 16-document test, PRO1013-26 |
| **Status / priority** | **Blocked by ADR-011** (library selection) Â· Must |

### FR-EXT-005 â€” Render + OCR fallback for PDFs without a text layer

|  |  |
| --- | --- |
| **Requirement** | A PDF with no text layer and no XML shall have its pages rendered and sent through the OCR pipeline, exactly like the photo route, with consensus and validation applying. Rendering shall be read-only; the source file is never re-saved. |
| **Acceptance** | A scanned PDF is extracted through the render+OCR path and attached unmodified. |
| **Source** | ADR-010, ADR-014, ADR-015 |
| **Status / priority** | **Blocked by ADR-010** (engine selection) Â· Must |

### FR-EXT-006 â€” Consensus by majority, never by maximum

|  |  |
| --- | --- |
| **Requirement** | Where a value has several candidate readings â€” multiple recognition passes or recognised variants â€” the value a **majority** of passes agree on shall win. A single outlier shall never override agreement between the others, however extreme its apparent confidence. Arithmetic shall be applied only to operands that passed consensus. |
| **Acceptance** | Given three passes reading 19.99 and one reading 19.98, the value used is 19.99 and the arithmetic consumes 19.99. A pipeline that takes the maximum across passes fails this case â€” the failure the 16-document test produced when one noisy pass overruled three that agreed. |
| **Source** | ADR-019 Â· 16-document test |
| **Status / priority** | Defined Â· Must |

### FR-EXT-007 â€” Read all printed quantities before deriving any

|  |  |
| --- | --- |
| **Requirement** | The pipeline shall attempt to read **all** operands of an amount breakdown as they are printed â€” matching independently read candidates against each other, in the approach of the prototype's `solve_amounts.py` â€” before computing any of them from the others. Where a quantity cannot be read, the pipeline shall leave it empty rather than reconstruct it. |
| **Acceptance** | Given a document printing base, tax and total, all three are read and none is derived. Given a document printing only total and tax, the base may be derived by identity, tagged `derived`. Given a document printing only the total, the breakdown stays empty. |
| **Source** | PDR Â§6.1 Â· ADR-019 Â· 16-document test |
| **Status / priority** | Defined Â· Must |

### FR-EXT-008 â€” Derive by identity only; never invent a rate

|  |  |
| --- | --- |
| **Requirement** | Deriving a value by **identity from read values** â€” `base = total âˆ’ tax` when both total and tax were read â€” shall be permitted, tagged `derived`, and shall carry **no confirmatory effect** on the confidence state. Deriving a value by **assuming a rate the document does not state** â€” `base = total Ã· (1 + assumed_rate)` â€” shall never be permitted; if the rate is not printed, the breakdown stays empty. |
| **Acceptance** | Given a total with no printed rate, no base or tax is computed. Given a document printing total and tax, the derived base is tagged `derived` and a subsequent `base + tax = total` check does not raise the total's confidence (see BR-05). |
| **Source** | ADR-019 Â· 16-document test (three invented rates: 9%, 30%, 4.5%) |
| **Status / priority** | Defined Â· Must |

### FR-EXT-009 â€” Derived rates checked against the legal set

|  |  |
| --- | --- |
| **Requirement** | A tax rate shall be checked against the country table's legal set before it is used for anything, and rejected if it is not legal for the detected country. |
| **Acceptance** | A printed or derived rate of 30% on a Spanish document is rejected and not used to derive a breakdown. The three rates the 16-document test invented â€” 9%, 30% and a 4.5% conversion mark-up â€” would all be rejected by this rule. |
| **Source** | ADR-005, ADR-019 Â· 16-document test |
| **Status / priority** | Defined Â· Must |

### FR-EXT-010 â€” Negative-context dictionary suppresses non-tax figures

|  |  |
| --- | --- |
| **Requirement** | The pipeline shall apply a negative-context dictionary that suppresses candidates which are percentages or numbers in the document but are not tax figures: currency-conversion mark-ups, *Skonto*, advance payments, and commercial-register boilerplate (*Registro Mercantil*, *Tomo*, *Folio*, *HRB*, *Amtsgericht*). Suppressed surcharge-like amounts shall be captured as `surcharges[]` with an appropriate label where the document supports it. |
| **Acceptance** | Given a document printing a DCC mark-up percentage, the percentage is not read as a tax rate; a surcharge entry is recorded instead. Given a document whose only number near a total label is a registry volume reference, that number is not used as the total. |
| **Source** | ADR-019 Â· 16-document test, PRO1013-26 and record 1428 Â· Annex C |
| **Status / priority** | Defined Â· Must |

### FR-EXT-011 â€” Provenance on every value

|  |  |
| --- | --- |
| **Requirement** | Every extracted value shall carry a provenance tag â€” `read`, `derived`, `repaired` or `from_xml` â€” held internally alongside the confidence state. Provenance shall never be written to Ninox; it shall determine whether a consuming check may raise the confidence state (FR-VAL-002). |
| **Acceptance** | Every value in the review model carries a tag; the payload sent to Ninox contains no provenance field; a check over a `derived` operand does not confirm. |
| **Source** | PDR Â§6.1 Â· ADR-019 |
| **Status / priority** | Defined Â· Must |

### FR-EXT-012 â€” Multi-page consolidation

|  |  |
| --- | --- |
| **Requirement** | For a multi-page document the pipeline shall read every page and consolidate into a single canonical model, with one value per field and provenance per value. |
| **Acceptance** | A two-page invoice whose totals continue on page 2 produces one consolidated model, not two; the page contributing each value is recorded internally. |
| **Source** | PDR Â§7.1 |
| **Status / priority** | Defined Â· Must |

### FR-EXT-013 â€” Currency is read, with its own evidence

|  |  |
| --- | --- |
| **Requirement** | Currency shall be extracted from the document's own evidence â€” printed ISO code, symbol, issuer country â€” and shall carry its own confidence state independent of any amount. It shall never be defaulted to the table's currency and is not mathematically confirmable. |
| **Acceptance** | A euro receipt is tagged EUR and a dollar invoice USD; a document whose currency cannot be sustained is shown as such rather than defaulted. The two mis-detections of the 16-document test â€” a euro receipt tagged USD, a dollar invoice tagged MAD â€” fail this criterion. |
| **Source** | PDR Â§6 (v0.2) Â· Finding 3 |
| **Status / priority** | Defined Â· Must |

### FR-EXT-014 â€” Multilingual label dictionaries, independent of interface language

|  |  |
| --- | --- |
| **Requirement** | Label dictionaries shall cover the document languages the product expects, independent of the interface language, since a German user may scan a French invoice. Seeds are in Annex C. |
| **Acceptance** | A French invoice labelled *Total Ã  payer* and a German invoice labelled *Zu zahlen* both bind their total correctly with the interface set to English. |
| **Source** | PDR Â§10 Â· ADR-005 Â· Annex C |
| **Status / priority** | Defined Â· Must |

### FR-EXT-015 â€” Recognition quality of the photo route

|  |  |
| --- | --- |
| **Requirement** | The photo route shall produce candidate readings of sufficient quality that, after consensus and validation, per-field accuracy over the screening corpus meets the threshold fixed in Â§10.5. |
| **Acceptance** | Measured as per-field accuracy after validation, counting only `read` / `from_xml` provenance, over the photographed-paper corpus extended per ADR-010's closure criterion. |
| **Source** | ADR-010 Â· PDR Â§12, Â§13 |
| **Status / priority** | **Blocked by ADR-010** (engine selection and corpus extension) Â· Must |

## 4.3 FR-VAL â€” Validation and confidence

### FR-VAL-001 â€” Three confidence strengths; only redundancy is green

|  |  |
| --- | --- |
| **Requirement** | A value's confidence shall be one of three strengths: **confirmed by redundancy** (two values that were each read independently agree through an identity â€” strong); **consistent with a check digit** (medium); **repaired to the only consistent value** (weak). Only the first shall be shown green with a lock; the other two shall be amber. An amount with no independent figure to cross against shall never be green, however cleanly it was read. |
| **Acceptance** | A total confirmed by base + tax = total with all operands read is green; a total passing no check and having no breakdown is amber; an EAN-13 passing its checksum is amber, not green. |
| **Source** | PDR Â§6 Â· Finding 5 |
| **Status / priority** | Defined Â· Must |

### FR-VAL-002 â€” A check is confirmatory only if every operand was read

|  |  |
| --- | --- |
| **Requirement** | A check that consumes a value shall raise the confidence state only if **every operand** feeding it has provenance `read` or `from_xml`. A check built from a derived operand is true by construction and confirms nothing. |
| **Acceptance** | Given a document whose base and tax were both derived from the total, the identity `base + tax = total` leaves the total amber. The nine records of the 16-document test whose base was derived from the gross total fail this criterion. |
| **Source** | PDR Â§6.1 Â· ADR-019 Â· 16-document test |
| **Status / priority** | Defined Â· Must |

### FR-VAL-003 â€” Green is editable only after unlocking

|  |  |
| --- | --- |
| **Requirement** | A green value shall be editable only after the user taps its lock icon. Amber and red values shall be directly editable. |
| **Acceptance** | Tapping a green field's value does not open the editor; tapping the lock does. |
| **Source** | PDR Â§6 |
| **Status / priority** | Defined Â· Must |

### FR-VAL-004 â€” The numeric confidence score is never shown

|  |  |
| --- | --- |
| **Requirement** | The numeric recognition score shall never be displayed to the user. It shall be stored locally and written to Ninox only if the user explicitly mapped it. |
| **Acceptance** | No decimal score appears on any screen; the score appears in Ninox only on a destination whose mapping includes it. |
| **Source** | PDR Â§6 |
| **Status / priority** | Defined Â· Must |

### FR-VAL-005 â€” Check-digit validators

|  |  |
| --- | --- |
| **Requirement** | The validation layer shall implement these check-digit validators: EAN-13 and IBAN modulo 97 (universal core); per country, `ES_NIF`, `ES_NIE` and `ES_CIF` as **three separate algorithms that never share code**, `AT_UID`, `CH_UID`, and the `DE_USTID` format check. `DE_STNR` shall be explicitly **not validated** â€” it has no reliable check digit. |
| **Acceptance** | Each validator reproduces the known-valid and known-invalid test vectors of Annex B. The prototype's misapplication of the NIF algorithm to a valid CIF (`A28017895`) is impossible: the three Spanish formats run separate code. |
| **Source** | PDR Â§10 Â· ADR-005 Â· Annex B |
| **Status / priority** | Defined Â· Must |

### FR-VAL-006 â€” Redundancy checks on amounts

|  |  |
| --- | --- |
| **Requirement** | The layer shall evaluate, in integer minor units: the sum of printed bases equals the net total; the sum of printed tax amounts equals the tax total; net + tax (+ printed rounding) equals the gross total â€” **exact integer equality, no tolerance**; and `base Ã— rate â‰ˆ tax` with a tolerance of at most one minor unit per tax line. |
| **Acceptance** | A document printing 16.52 + 3.47 against 19.99 confirms the total; the same figures against 19.98 do not, and no tolerance absorbs the difference. The prototype's Â±0.02 tolerance, which let 16.51 + 3.47 pass against 19.98, fails this criterion. |
| **Source** | ADR-016 Â· PDR Â§6 Â· Annex D |
| **Status / priority** | Defined Â· Must |

### FR-VAL-007 â€” Legal tax rate check

|  |  |
| --- | --- |
| **Requirement** | Any tax rate used by the pipeline shall be checked against the detected country's legal rate set and rejected when it is not legal. |
| **Acceptance** | A 30% rate on any launch country is rejected; a 4.5% mark-up is rejected as a rate. |
| **Source** | ADR-005, ADR-019 Â· Annex B |
| **Status / priority** | Defined Â· Must |

### FR-VAL-008 â€” Repair to the only consistent value

|  |  |
| --- | --- |
| **Requirement** | Where a reading fails a check digit and exactly one replacement of the offending character makes it pass, the app may apply that repair, tagging the value `repaired`, and shall present it as amber â€” weak strength: correct only if every other character was read correctly. |
| **Acceptance** | `123456795` read from a document whose issuer is `12345679S` is repaired and shown amber with its repair visible; a reading with two admissible repairs is not repaired. |
| **Source** | PDR Â§6, Â§1.1 Â· Annex D |
| **Status / priority** | Defined Â· Must |

### FR-VAL-009 â€” Currency carries its own confidence state

|  |  |
| --- | --- |
| **Requirement** | Currency shall hold a confidence state separate from amounts. A currency that cannot be sustained from evidence shall suppress the writing of amounts rather than allow a wrong-currency figure to be written. |
| **Acceptance** | A document whose currency cannot be determined produces a record with no amounts, not a record with defaulted-currency amounts. |
| **Source** | PDR Â§6 (v0.2) Â· Finding 3 Â· 16-document test |
| **Status / priority** | Defined Â· Must |

### FR-VAL-010 â€” What never reaches green

|  |  |
| --- | --- |
| **Requirement** | `doc_number` shall never be presented as green: receipt and invoice numbers carry no check digit and each recognition pass produces a different variant. `supplier_name` shall be presentable as confirmed only via the supplier memory, never by arithmetic. |
| **Acceptance** | No document number ever shows green in any state; a supplier name shows green only when the memory supplied it from a check-digit-passing identifier. |
| **Source** | PDR Â§6.2 |
| **Status / priority** | Defined Â· Must |

### FR-VAL-011 â€” Tax slots

|  |  |
| --- | --- |
| **Requirement** | The model shall carry one slot per printed tax rate â€” a `tax_rate` / `tax_base` / `tax_amount` triplet â€” with the number of slots declared by the country table. Slots that do not apply stay empty. Each slot maps independently and all are optional. `tax_total`, where mapped, shall be the sum of printed tax amounts, never a value computed from the gross total and an assumed rate. |
| **Acceptance** | A German receipt printing 19% and 7% occupies two slots with a third empty; the record does not collapse the pair. |
| **Source** | PDR Â§5.3 Â· ADR-005 Â· Annex B |
| **Status / priority** | Defined Â· Must |

### FR-VAL-012 â€” Absent is not zero; the destination decides

|  |  |
| --- | --- |
| **Requirement** | A value not printed shall not be treated as zero. Whether "not printed" means an empty field or a contractual zero shall be a per-field property of the destination mapping, chosen by the user; the app shall never hardcode either. The default shall be to write empty. |
| **Acceptance** | A card-terminal slip with no printed VAT writes empty or zero into the VAT column strictly according to the per-field setting; changing the setting changes the written value and nothing else. |
| **Source** | PDR Â§7.3, Â§6 Â· 16-document test, record 1414 |
| **Status / priority** | Defined Â· Must |

### FR-VAL-013 â€” Date coherence and format inference

|  |  |
| --- |--- |
| **Requirement** | The universal layer shall infer date and decimal formats from the document's own evidence â€” a day greater than twelve disambiguates date order; the thousands grouping pattern separates `1.234,56` from `1,234.56` â€” and shall check dates for coherence. `doc_date` shall never be derived from a filename or a received-email timestamp. |
| **Acceptance** | A document printing `27.08.2026` is read as 27 August 2026; a document printing `03/04/2026` with no disambiguating evidence is flagged ambiguous rather than silently assumed. |
| **Source** | PDR Â§10, Â§5.1 Â· ADR-005 |
| **Status / priority** | Defined Â· Must |

### FR-VAL-014 â€” Determinism over coverage

|  |  |
| --- |--- |
| **Requirement** | A value shall be presented as confirmed only when a deterministic constraint establishes it from values that were themselves read, not derived by assumption. The app shall prefer admitting doubt to guessing convincingly. |
| **Acceptance** | This is the normative form of contract constraint 4; its acceptance is the conjunction of FR-VAL-001, FR-VAL-002 and FR-EXT-008. |
| **Source** | PDR Â§4 Â· Contract 4 |
| **Status / priority** | Defined Â· Must |

## 4.4 FR-REV â€” Review

### FR-REV-001 â€” Destination bar

|  |  |
| --- | --- |
| **Requirement** | The review screen shall carry a full-width, persistent destination bar showing team, database and table, tappable to change destination. |
| **Acceptance** | The bar is visible throughout review; tapping it opens destination selection without leaving the document. |
| **Source** | PDR Â§7.2 |
| **Status / priority** | Defined Â· Must |

### FR-REV-002 â€” Daily destination confirmation

|  |  |
| --- | --- |
| **Requirement** | The destination bar shall be pre-loaded with the destination last used. On the first capture of each calendar day it shall be highlighted, and the save button shall stay disabled until the user has acknowledged the destination once. This is the one deliberate exception to the three-tap principle, made once a day rather than once per document. |
| **Acceptance** | The first capture on a day requires the confirmation and no later capture does; the destination shown on the second capture is the one used for the first. |
| **Source** | PDR Â§7.2, Â§7.3 Â· Finding 4 |
| **Status / priority** | Defined Â· Must |

### FR-REV-003 â€” Thumbnail with the read region

|  |  |
| --- | --- |
| **Requirement** | The review screen shall show a document thumbnail. Tapping any field shall draw a box around the region the value was read from and zoom to it. A value produced by a redundancy check shall highlight the regions of **every operand** that fed the check. |
| **Acceptance** | Tapping a green total highlights base, tax and total regions together â€” showing the user *why* the app reached that number, not only that it did. |
| **Source** | PDR Â§7.2 |
| **Status / priority** | Defined Â· Must |

### FR-REV-004 â€” The six core fields in fixed order

|  |  |
| --- | --- |
| **Requirement** | The six core fields â€” `doc_date`, `supplier_name`, `supplier_tax_id`, `doc_number`, `gross_total`, `currency` â€” shall be shown in a fixed order with inline editing, large type and a colour per confidence state. On opening review, focus shall jump automatically to the first field that was not read. |
| **Acceptance** | Field order is identical across routes and documents; for a document with no supplier name, focus lands on `supplier_name`. |
| **Source** | PDR Â§7.2, Â§5.1 |
| **Status / priority** | Defined Â· Must |

### FR-REV-005 â€” Amounts block collapse rule

|  |  |
| --- |--- |
| **Requirement** | The amounts block shall collapse to a single confirming line when a redundancy check passes, and shall be expanded whenever it does not â€” including whenever an amount has no breakdown to check against at all. With several tax slots the block may hold seven figures; it shall not be shown expanded by default when the check passes. |
| **Acceptance** | A fully confirmed document shows one confirming line; a card-terminal slip with no breakdown shows the block expanded; a multi-rate receipt shows all occupied slots. |
| **Source** | PDR Â§7.2, Â§5.3 |
| **Status / priority** | Defined Â· Must |

### FR-REV-006 â€” Advanced section collapsed

|  |  |
| --- | --- |
| **Requirement** | The advanced section â€” remaining mapped fields, `surcharges[]`, `doc_subtype` and the other extended groups â€” shall be collapsed by default on the review screen. |
| **Acceptance** | The section is closed on open and expands on demand; no advanced field is visible in the default view of a clean document. |
| **Source** | PDR Â§7.2, Â§5.2 |
| **Status / priority** | Defined Â· Must |

### FR-REV-007 â€” Duplicate notice

|  |  |
| --- | --- |
| **Requirement** | When the duplicate check matches, the review screen shall show a duplicate notice that links to the existing record and lets the user proceed anyway. |
| **Acceptance** | See FR-DUP-002 and UC-09. |
| **Source** | PDR Â§7.2 |
| **Status / priority** | Defined Â· Must |

### FR-REV-008 â€” Save button names the destination

|  |  |
| --- | --- |
| **Requirement** | The save button shall be fixed at the bottom of the review screen and shall name the outcome â€” for example "Save to Expenses 2026" â€” rather than reading "Submit". |
| **Acceptance** | The button label contains the destination table name and no generic verb. |
| **Source** | PDR Â§7.2 |
| **Status / priority** | Defined Â· Must |

### FR-REV-009 â€” Never block a save

|  |  |
| --- | --- |
| **Requirement** | The user shall always be able to save. Missing, unreadable or low-confidence fields shall never prevent a record from being created with the document attached. |
| **Acceptance** | A document from which nothing could be read is saved as a record with the attachment and no data; no field state disables the save button other than the daily destination confirmation. |
| **Source** | PDR Â§4, Â§3.2 Â· BR-14 |
| **Status / priority** | Defined Â· Must |

### FR-REV-010 â€” User edits are authoritative

|  |  |
| --- |--- |
| **Requirement** | A value the user edits shall be the value sent. Editing shall not re-impose a confidence colour, and an edited value shall not be recomputed by the pipeline. |
| **Acceptance** | Correcting a total and saving writes the corrected total; the read-back shows it; no validation overrides the user's value. |
| **Source** | PDR Â§4, Â§7.2 |
| **Status / priority** | Defined Â· Must |

### FR-REV-011 â€” Discard a document

|  |  |
| --- | --- |
| **Requirement** | From review the user shall be able to discard the document; no record is created and the local capture is deleted. |
| **Acceptance** | Discarding leaves no history entry and no local file. |
| **Source** | PDR Â§7.2 Â· state machine Â§6.2 |
| **Status / priority** | Defined Â· Must |


## 4.5 FR-DST â€” Destinations and mapping

### FR-DST-001 â€” What a destination is

|  |  |
| --- | --- |
| **Requirement** | A destination shall be the tuple: Ninox team, database, table, field mapping, and Ninox host. The user may hold several destinations. |
| **Acceptance** | Two destinations pointing at different tables of the same database coexist, and the destination bar switches between them. |
| **Source** | PDR Â§7.3 Â· ADR-017 |
| **Status / priority** | Defined Â· Must |

### FR-DST-002 â€” No default destination until a first send

|  |  |
| --- | --- |
| **Requirement** | There shall be no built-in default destination when the app is first configured. Once at least one send has happened, the destination bar shall always show the destination used last. |
| **Acceptance** | A fresh installation shows an empty destination requiring the wizard; after the first send the bar is pre-loaded and the daily confirmation is the only required acknowledgement. |
| **Source** | PDR Â§7.2, Â§7.3 Â· Finding 4 |
| **Status / priority** | Defined Â· Must |

### FR-DST-003 â€” Destinations store identifiers, not names

|  |  |
| --- |--- |
| **Requirement** | A destination shall store Ninox **field identifiers**, never field names. The current name shall be resolved at send time from a cached schema that refreshes when the app opens. |
| **Acceptance** | Rename a mapped column in Ninox; the next send resolves the new name and writes to the same column. A destination stored by name â€” which would break silently on rename â€” fails this criterion. |
| **Source** | PDR Â§7.3 Â· ADR-004 |
| **Status / priority** | Defined Â· Must |

### FR-DST-004 â€” Formula and read-only fields are not mapping candidates

|  |  |
| --- |--- |
| **Requirement** | Fields the schema marks as formula or read-only shall be excluded from the mapping candidates offered to the user. |
| **Acceptance** | The mapping picker for a table whose total is a formula field does not offer it; writing to such a field returns HTTP 500, which the app never provokes. |
| **Source** | PDR Â§7.4, Â§8.1 Â· ADR-004 |
| **Status / priority** | Defined Â· Must |

### FR-DST-005 â€” Formula totals used as post-write contrast

|  |  |
| --- | --- |
| **Requirement** | Where the destination table holds a formula field computing a total from mapped components, the app shall not write to it; after a successful send it shall read the field back and compare it against the total extracted from the document. A mismatch shall be surfaced to the user as a question about the mapping or the formula, not as a verdict on the extraction. |
| **Acceptance** | For a table whose formula is `base + tax` where the app mapped base and tax to the wrong columns, the read-back mismatch is surfaced; the message names the mapping as the suspect. **Known limit, documented in the UI:** the check does not catch a total misread and then used to derive its own components â€” the formula reproduces the error. Only FR-EXT-007 / BR-05 catch that. |
| **Source** | PDR Â§7.4 Â· 16-document test (the `YB` total is a formula field) |
| **Status / priority** | Defined Â· Must |

### FR-DST-006 â€” Per-field "absent = empty or zero" setting

|  |  |
| --- |--- |
| **Requirement** | Each mapped field shall carry one additional setting: what to write when the source value is absent from the document â€” leave the Ninox field empty (the default) or write zero. This is a property of the destination field, not of the canonical model. |
| **Acceptance** | A card-terminal slip's VAT column receives empty or zero strictly per the setting; the same document against two destinations with different settings yields the two expected values. |
| **Source** | PDR Â§7.3 Â· 16-document test, record 1414 |
| **Status / priority** | Defined Â· Must |

### FR-DST-007 â€” Choice fields offer the existing options

|  |  |
| --- |--- |
| **Requirement** | For a Ninox choice field, the mapping shall offer the field's existing options rather than free text. Choice fields accept the option identifier or the option text, and reads always return the text. |
| **Acceptance** | Mapping `doc_subtype` to a choice field shows the field's options; the written value is one of them. |
| **Source** | ADR-004 |
| **Status / priority** | Defined Â· Must |

### FR-DST-008 â€” Configurable Ninox host

|  |  |
| --- |--- |
| **Requirement** | The Ninox host shall be a field in the destination's advanced setup, defaulting to `api.ninox.com` and editable. The client's base URL shall never be compiled in as a constant. The host shall be validated at the token step exactly like the token itself. |
| **Acceptance** | A private-cloud customer configures the app against their own host with no fork and no manual build; an unreachable host is reported at the token step, not at send time. |
| **Source** | ADR-017 Â· Finding 14 |
| **Status / priority** | Defined Â· Must |

### FR-DST-009 â€” Never write an unmapped field

|  |  |
| --- |--- |
| **Requirement** | The app shall never write a Ninox field the user has not explicitly mapped. Because mapping is optional, no marker field may be relied on to exist, which is why duplicate prevention is handled read-side (ADR-013). |
| **Acceptance** | A destination with no mapping produces a record carrying only the attachment; the payload contains no field keys at all. |
| **Source** | Contract 6 Â· ADR-013 Â· PDR Â§8.2 |
| **Status / priority** | Defined Â· Must |

## 4.6 FR-WIZ â€” Setup wizard

### FR-WIZ-001 â€” Five screens at most

|  |  |
| --- | --- |
| **Requirement** | The wizard shall have at most five screens: token, team, database, table, mapping. |
| **Acceptance** | The wizard never presents a sixth screen; the five are the only steps. |
| **Source** | PDR Â§8 |
| **Status / priority** | Defined Â· Must |

### FR-WIZ-002 â€” Steps auto-omit when there is nothing to choose

|  |  |
| --- |--- |
| **Requirement** | The team, database and table steps shall each be skipped automatically when the list contains exactly one option. |
| **Acceptance** | A subscription with one team and one database presents two screens: token and mapping. |
| **Source** | PDR Â§8 |
| **Status / priority** | Defined Â· Must |

### FR-WIZ-003 â€” Token step via the system browser

|  |  |
| --- |--- |
| **Requirement** | The token step shall offer instructions for obtaining a Ninox API token, a paste-from-clipboard button, and an option to open the Ninox settings page in the platform's own system browser â€” Custom Tabs on Android, SFSafariViewController on iOS. The app shall never render Ninox's login inside a WebView it controls. The token shall be validated immediately, and a successful call shall also return the list needed for the next step. |
| **Acceptance** | The login form is presented by the system browser, outside the app's process; on return, pasting an invalid token keeps the user on the step with an error; a valid token populates the next step's list. |
| **Source** | PDR Â§8 Â· ADR-018 Â· Finding 7 Â· Contract 3 |
| **Status / priority** | Defined Â· Must |

### FR-WIZ-004 â€” Table listing returns the schema

|  |  |
| --- |--- |
| **Requirement** | The table listing shall also return the table's schema, so the mapping step needs no additional round trip. Formula and read-only fields shall be annotated in what is returned so the mapping step can exclude them. |
| **Acceptance** | Reaching the mapping step after a single network round trip per list; the picker contains no formula or read-only field. |
| **Source** | PDR Â§8 Â· ADR-004 |
| **Status / priority** | Defined Â· Must |

### FR-WIZ-005 â€” Pre-filled proposals, not empty selectors

|  |  |
| --- |--- |
| **Requirement** | The mapping step shall show each of the six core fields as a pre-filled proposal over the table's real fields, so the user corrects only what is wrong. |
| **Acceptance** | The mapping screen never presents an unmapped core field as an empty dropdown where a plausible candidate exists; where nothing plausible exists it is visibly unmapped. |
| **Source** | PDR Â§8 |
| **Status / priority** | Defined Â· Must |

### FR-WIZ-006 â€” Two-stage matching with a strict threshold

|  |  |
| --- |--- |
| **Requirement** | Field matching shall run in two stages: a hard type filter first â€” a date is only ever proposed against a date field, an amount only against a number field, and any formula or read-only field removed before matching starts â€” then string similarity against a multilingual synonym dictionary. The threshold shall be deliberately strict: below it, the field is left unmapped rather than proposed. |
| **Acceptance** | A table with `Belegdatum`, `Betrag` and `Lieferant` receives proposals for date, total and supplier; a table with no date-like field leaves `doc_date` unmapped rather than proposing something weak. A mediocre suggestion a user confirms without reading is the failure mode this rule prevents. |
| **Source** | PDR Â§8.1 Â· Annex C |
| **Status / priority** | Defined Â· Must |

### FR-WIZ-007 â€” No mapping is mandatory

|  |  |
| --- |--- |
| **Requirement** | No mapping shall be mandatory. A user may map everything, one field, or nothing â€” in which case Paperdrop attaches the document to an otherwise empty record. |
| **Acceptance** | Finishing the wizard with zero mapped fields is possible and produces the plain-language summary for that case. |
| **Source** | PDR Â§8.2 |
| **Status / priority** | Defined Â· Must |

### FR-WIZ-008 â€” Plain-language summary and first-document offer

|  |  |
| --- |--- |
| **Requirement** | The wizard shall close with a plain-language summary of the consequence â€” "date and total will be saved; supplier, tax identifier and VAT will not", or "only the document will be attached, with no data" â€” and the final screen shall offer to capture the first document rather than returning the user to an empty application. |
| **Acceptance** | The summary names exactly the mapped and unmapped core fields; accepting the offer opens capture for any document type, not a receipt-specific flow. |
| **Source** | PDR Â§8.2, Â§2 |
| **Status / priority** | Defined Â· Must |

## 4.7 FR-SND â€” Send pipeline

### FR-SND-001 â€” Create, attach, read back

|  |  |
| --- | --- |
| **Requirement** | A send shall be three steps: create the record, attach the document to it, read the record back. The read-back shall be presented to the user as what is actually stored, not what was sent, because fields carrying formulas or default values silently override submitted values and the create response does not reveal it. |
| **Acceptance** | The confirmation screen displays values read back from Ninox; where a default overrode a submitted value, the displayed value is the stored one. |
| **Source** | PDR Â§9 Â· ADR-004 |
| **Status / priority** | Defined Â· Must |

### FR-SND-002 â€” Payload shape

|  |  |
| --- |--- |
| **Requirement** | Records shall be written as a nested object under a `fields` key, keyed by field **name**. Dates shall be sent as `YYYY-MM-DD` and stored verbatim. Amounts shall be sent as integers in the minor unit; rates as integers in basis points. |
| **Acceptance** | A sent payload round-trips: the read-back returns the same dates and the same integer amounts, with no float at any boundary. |
| **Source** | ADR-004, ADR-016 |
| **Status / priority** | Defined Â· Must |

### FR-SND-003 â€” Attachment upload

|  |  |
| --- |--- |
| **Requirement** | The document shall be attached with a single multipart call to the record's files endpoint, which returns HTTP 200. The app shall be able to read the attachment back â€” name, size, content type. |
| **Acceptance** | After a send, `GET .../files` returns the attached document's name, size and content type matching what was uploaded. Verified end-to-end across sixteen real uploads in the test (ADR-004). |
| **Source** | ADR-004 Â· Annex A |
| **Status / priority** | Defined Â· Must |

### FR-SND-004 â€” The retry matrix

|  |  |
| --- |--- |
| **Requirement** | Send errors shall be handled per this matrix and no other way: **no connectivity** â†’ queued and sent automatically on return; **timeout or network error on create** â†’ uncertain outcome, reconciliation per FR-SND-005, never a blind retry; **timeout on attachment or read-back** â†’ bounded exponential backoff, since these cannot duplicate a record; **HTTP 401/403** â†’ authentication problem, the user re-enters the token, no retry; **HTTP 404** â†’ the database or table no longer exists, the user is sent to the destination, no retry; **HTTP 500** â†’ refresh the schema and retry exactly once, then report a mapping error rather than a server outage; **record created with attachment failed** â†’ retry the attachment only. |
| **Acceptance** | Each row is exercised by a test that injects the condition; the observed behaviour matches the row exactly. A client that retries a 500 forever, or a timed-out create blindly, fails this requirement. |
| **Source** | PDR Â§9.1 Â· ADR-013, ADR-004 Â· Â§9 of this document |
| **Status / priority** | Defined Â· Must |

### FR-SND-005 â€” Reconciliation of an uncertain create

|  |  |
| --- |--- |
| **Requirement** | A create whose response was lost shall enter the `uncertain` state and trigger a read-side reconciliation: the app reads the destination table's most recently created records â€” `createdAt` and `createdBy` are available regardless of mapping â€” and looks for a match against the mapped fields within a short time window. On exactly one match, that record is adopted and the flow continues to the attachment step. On no match, the record is created. On ambiguity â€” more than one plausible match, or too few mapped fields to compare â€” the app shall surface the uncertainty to the user and let them choose; it never guesses. |
| **Acceptance** | Given a create whose POST landed but whose response was lost, exactly one record exists after the flow; given one whose POST did not land, exactly one record exists; given two near-identical candidate matches, the user is asked. See UC-11. |
| **Source** | ADR-013 Â· PDR Â§9.1 Â· Finding 1 |
| **Status / priority** | Defined Â· Must |

### FR-SND-006 â€” Deep link back to the record

|  |  |
| --- |--- |
| **Requirement** | After a successful send the confirmation screen shall offer a link to open the record in Ninox, built entirely from data the app already holds â€” team and database from the destination, table identifier from the destination, record identifier from the create response â€” with no additional API call and no credentials. If the URL structure no longer resolves, the button shall degrade to opening the database rather than fail. |
| **Acceptance** | The button opens the created record; with an artificially broken URL shape, it opens the database instead of showing an error. |
| **Source** | PDR Â§9.2 Â· ADR-008 Â· Contract 3 |
| **Status / priority** | Defined Â· Must |

### FR-SND-007 â€” Automations may run; the read-back is the visibility

|  |  |
| --- |--- |
| **Requirement** | The app shall treat creating a record as an action that may trigger automations inside the user's Ninox database which the API does not expose. The read-after-create step is the app's only visibility into them, and the user-facing documentation shall say so. |
| **Acceptance** | The documentation text exists and the confirmation screen shows read-back values rather than submitted values. |
| **Source** | ADR-004, note |
| **Status / priority** | Defined Â· Must |

### FR-SND-008 â€” Updates are merges

|  |  |
| --- |--- |
| **Requirement** | A correction or a retry shall send only what changed. Fields not sent shall be preserved, so a failed attachment can be retried without touching the record and a correction does not wipe unrelated fields. |
| **Acceptance** | Correcting one field leaves every other mapped value unchanged in the read-back; retrying a failed attachment after a successful create changes nothing but the attachment. |
| **Source** | ADR-004 Â· PDR Â§9.1 |
| **Status / priority** | Defined Â· Must |

## 4.8 FR-HIS â€” History

### FR-HIS-001 â€” Content of a history entry

|  |  |
| --- | --- |
| **Requirement** | Every capture shall produce a local history entry holding: the thumbnail, the extracted values **with their provenance**, the destination, the state, the confidence, the document hash, and the Ninox record identifier once sent. |
| **Acceptance** | Opening an entry shows all eight items; provenance is visible in the detail even though it is never sent to Ninox. |
| **Source** | PDR Â§7.5 |
| **Status / priority** | Defined Â· Must |

### FR-HIS-002 â€” Document states

|  |  |
| --- |--- |
| **Requirement** | A history entry shall carry exactly one state of: `pending`, `queued`, `extracting`, `reviewing`, `sending`, `uncertain`, `sent`, `failed`, `duplicate-flagged`. Transitions shall be those of the state machine in Â§6.2. |
| **Acceptance** | An offline save reads `queued`, not `failed`; a lost create response reads `uncertain`; a completed send reads `sent` with the record identifier populated. |
| **Source** | PDR Â§7.5 Â· Â§6.2 of this document |
| **Status / priority** | Defined Â· Must |

### FR-HIS-003 â€” Correction and re-send

|  |  |
| --- |--- |
| **Requirement** | From a history entry the user shall be able to correct values and re-send, producing an update of the same record rather than a new one. |
| **Acceptance** | See UC-12. |
| **Source** | PDR Â§7.5, Â§9.1 |
| **Status / priority** | Defined Â· Must |

### FR-HIS-004 â€” File retention

|  |  |
| --- |--- |
| **Requirement** | Local document images shall be deleted once a send is confirmed â€” the document is in Ninox by then. Only pending and failed items shall keep their files. |
| **Acceptance** | After a `sent` entry, the local file is gone and the thumbnail remains; a `failed` entry's file is still openable. |
| **Source** | PDR Â§7.5 |
| **Status / priority** | Defined Â· Must |

### FR-HIS-005 â€” History is the uncertainty trace

|  |  |
| --- |--- |
| **Requirement** | History shall be treated as a first-class surface, not an optional extra: because mapping the review metadata is optional, a user who mapped nothing has no other way to see in Ninox which records were uncertain. |
| **Acceptance** | With no metadata mapped, history remains the only place the confidence and provenance of a past document can be inspected; it survives the send. |
| **Source** | PDR Â§7.5 |
| **Status / priority** | Defined Â· Must |

## 4.9 FR-MEM â€” Supplier memory

### FR-MEM-001 â€” The memory learns supplier pairs

|  |  |
| --- |--- |
| **Requirement** | The app shall maintain a local store of supplier identifierâ€“name pairs, learned from documents the user has confirmed. |
| **Acceptance** | After sending a document from a supplier, the memory holds the pair; the store contains no entry the user did not confirm. |
| **Source** | PDR Â§11 Â· ADR-009 |
| **Status / priority** | Defined Â· Must |

### FR-MEM-002 â€” Indexed only by identifiers that passed their check digit

|  |  |
| --- |--- |
| **Requirement** | The supplier memory shall be indexed only by identifiers that passed their check digit. Indexing on an uncertain reading shall never occur. |
| **Acceptance** | An identifier that fails its check digit neither creates nor matches an entry, even when the name is plausible. This is the safeguard that prevents a wrong name entering the store and later being presented as confirmed. |
| **Source** | ADR-009 Â· PDR Â§11 |
| **Status / priority** | Defined Â· Must |

### FR-MEM-003 â€” Presentation in review

|  |  |
| --- |--- |
| **Requirement** | On review, a recognised supplier shall be offered as the confirmed name. Memory is the only mechanism that can confirm a supplier name. |
| **Acceptance** | See UC-15. |
| **Source** | PDR Â§6.2, Â§11 |
| **Status / priority** | Defined Â· Must |

### FR-MEM-004 â€” Real deletion

|  |  |
| --- |--- |
| **Requirement** | The app shall provide a data-clearing action that genuinely empties the supplier memory. |
| **Acceptance** | After the action, no identifierâ€“name pair can be matched; a previously recognised supplier is offered no longer. |
| **Source** | ADR-009 |
| **Status / priority** | Defined Â· Must |

## 4.10 FR-CFG â€” Configuration and data management

### FR-CFG-001 â€” Export and import of configuration

|  |  |
| --- |--- |
| **Requirement** | Configuration â€” destinations, mappings and supplier memory â€” shall be exportable to and importable from a file the user keeps wherever they like. The API token shall never be included in the export. |
| **Acceptance** | An export file contains destinations, mappings and supplier memory and no credential; importing it on a second device restores all three. |
| **Source** | ADR-009 Â· PDR Â§3.2, Â§11 |
| **Status / priority** | Defined Â· Must |

### FR-CFG-002 â€” Device migration

|  |  |
| --- |--- |
| **Requirement** | A device change shall be a file plus a re-entered token, with no backend and no synchronisation service. The token is re-entered because it stays in the platform keystore and never leaves the device. |
| **Acceptance** | See UC-13. |
| **Source** | ADR-009 |
| **Status / priority** | Defined Â· Must |

### FR-CFG-003 â€” Local data clearing

|  |  |
| --- |--- |
| **Requirement** | The app shall provide an action that clears local data â€” history, supplier memory, destinations and retained document files â€” genuinely and irreversibly. |
| **Acceptance** | After the action, history is empty, the memory is empty, no retained document file remains, and the app returns to the first-run state. |
| **Source** | ADR-009 Â· PDR Â§11 |
| **Status / priority** | Defined Â· Must |

### FR-CFG-004 â€” Token storage

|  |  |
| --- |--- |
| **Requirement** | The API token shall be stored in the Android Keystore or the iOS Keychain. Biometric protection of the token is deferred to a later version as an optional setting. |
| **Acceptance** | The token is not present in the application's writable data containers; a device backup extraction does not yield it in plaintext. |
| **Source** | PDR Â§11 Â· Contract 3 |
| **Status / priority** | Defined (biometrics Deferred) Â· Must |

## 4.11 FR-CTR â€” Countries and languages

### FR-CTR-001 â€” Deterministic country detection, no user setting

|  |  |
| --- |--- |
| **Requirement** | The app shall detect the document's country from its own evidence â€” VAT identifier format, currency, address, language â€” and apply that row of the country table. There shall be no user-facing country setting and nothing to activate. |
| **Acceptance** | A German invoice with a `DE` VAT identifier applies the DE row without any user action; a Spanish ticket with an `ES_CIF` applies the ES row. |
| **Source** | PDR Â§10 Â· ADR-005 Â· Finding 13 |
| **Status / priority** | Defined Â· Must |

### FR-CTR-002 â€” Universal core

|  |  |
| --- |--- |
| **Requirement** | A universal core shall apply everywhere: amount arithmetic, date coherence, date and decimal format inference, the EAN-13 check digit, and IBAN modulo 97. |
| **Acceptance** | A document from a country with no country-table row still receives arithmetic and date checks and validates its EAN-13 and IBAN where present. |
| **Source** | ADR-005 Â· PDR Â§10 |
| **Status / priority** | Defined Â· Must |

### FR-CTR-003 â€” Country table contents

|  |  |
| --- |--- |
| **Requirement** | The country table shall declare, per country: the VAT identifier format and its check-digit algorithm; the legal set of tax rates and the number of tax slots; the date format; the decimal separator; and any cash-rounding rule. Adding a country shall be a table row plus at most one small check-digit function. |
| **Acceptance** | Annex B is the launch content; adding a fifth country touches no code outside the table and its identifier validator. |
| **Source** | ADR-005 Â· PDR Â§10 Â· Annex B |
| **Status / priority** | Defined Â· Must |

### FR-CTR-004 â€” Four launch rows; the three Spanish formats never share code

|  |  |
| --- |--- |
| **Requirement** | Germany, Austria, Switzerland and Spain shall be the four launch rows; none is the reference case. The three Spanish identifier formats â€” `ES_NIF` (natural person), `ES_NIE` (foreign natural person), `ES_CIF` (legal person) â€” shall be implemented as three distinct algorithms that never share code. Switzerland is included from the start because DACH is the primary market, not as an extension of it. |
| **Acceptance** | A valid `ES_CIF` passes its own algorithm and is not checked against the NIF algorithm â€” the prototype's false doubt on `A28017895` is impossible. |
| **Source** | PDR Â§10 Â· Finding 13 Â· 16-document test |
| **Status / priority** | Defined Â· Must |

### FR-CTR-005 â€” Format inference is a real algorithm

|  |  |
| --- |--- |
| **Requirement** | Because the universal core cannot assume a format, the app shall infer it: a day greater than twelve disambiguates the date order, and the thousands grouping pattern separates `1.234,56` from `1,234.56`. This is the one genuinely new piece of work the universal layer introduces. |
| **Acceptance** | A document printing `13.08.2026` and `1.234,56` is read as 13 August and one thousand two hundred thirty-four and 56/100; the same inputs in US grouping are read correctly and differently. |
| **Source** | PDR Â§10 Â· ADR-005 |
| **Status / priority** | Defined Â· Must |

### FR-CTR-006 â€” Interface languages; document dictionaries are separate

|  |  |
| --- |--- |
| **Requirement** | The interface shall ship in English and German. Document keyword dictionaries â€” including the negative-context terms â€” shall be a separate matter from interface language and shall cover several languages from the start. |
| **Acceptance** | With the interface in English, a German and a French document are both parsed with their own label dictionaries. |
| **Source** | PDR Â§10 Â· ADR-005 Â· Annex C |
| **Status / priority** | Defined Â· Must |

### FR-CTR-007 â€” Swiss rounding is captured, never recalculated

|  |  |
| --- |--- |
| **Requirement** | For Switzerland, the printed cash-rounding adjustment to the nearest 5 Rappen shall be captured into `rounding_minor` and used in the gross-total identity, and shall never be recomputed by the app. |
| **Acceptance** | A Swiss cash receipt with a printed rounding line has that line in the record, and `net + tax + rounding = gross` holds exactly; the app never substitutes its own rounding. |
| **Source** | PDR Â§10 Â· ADR-016 Â· Annex B |
| **Status / priority** | Defined Â· Must |

## 4.12 FR-DUP â€” Duplicate detection

### FR-DUP-001 â€” Duplicate criteria

|  |  |
| --- |--- |
| **Requirement** | A document shall be flagged as a duplicate when its hash matches an earlier send, or when supplier, date and total together match one. The check shall run against local history before a save. |
| **Acceptance** | The same file captured twice matches on hash; two different photographs of the same receipt match on supplier + date + total; two different documents from the same supplier on the same day do not match. |
| **Source** | PDR Â§7.2 |
| **Status / priority** | Defined Â· Must |

### FR-DUP-002 â€” Notice, link, proceed

|  |  |
| --- |--- |
| **Requirement** | On a duplicate match the review screen shall show a notice linking to the existing record, and the user shall be able to proceed anyway, creating a second record deliberately. |
| **Acceptance** | See UC-09. |
| **Source** | PDR Â§7.2 |
| **Status / priority** | Defined Â· Must |


# 5. Business rules catalogue

The testable core. Each rule states the behaviour, the decision it comes from, and the test that proves it. The catalogue is normative: where a screen or a pipeline step appears to conflict with one of these, the rule wins. The founding examples behind several of them are worked in Annex D.

## BR-01 â€” Determinism over coverage

|  |  |
| --- | --- |
| **Rule** | A value is presented as confirmed only when a deterministic constraint establishes it from values that were themselves read, not derived by assumption. The app prefers admitting doubt to guessing convincingly. |
| **Source** | PDR Â§4 Â· Contract 4 |
| **Test** | A total with no breakdown is amber. An EAN-13 that passes its checksum is amber, not green. No confidence colour is assigned from a numeric score. |

## BR-02 â€” A check confirms only if every operand was read

|  |  |
| --- | --- |
| **Rule** | A check that consumes a value raises the confidence state only if every operand feeding it has provenance `read` or `from_xml`. A check built from derived operands is true by construction and confirms nothing. |
| **Source** | PDR Â§6.1 Â· ADR-019 Â· 16-document test (nine of ten "arithmetic-verified" records had derived the base from the total) |
| **Test** | Annex D, example 5 â€” a document whose base and tax were both derived from the total does not turn the total green. |

## BR-03 â€” Empty over false

|  |  |
| --- | --- |
| **Rule** | When the app cannot sustain a value, it writes nothing rather than a plausible-looking number. This is not a fallback behaviour; it is the default. An incomplete record costs the user seconds of review; a record with an invented figure travels silently into their accounts. |
| **Source** | PDR Â§4 Â· 16-document test (every one of its six failure patterns produced a plausible-looking wrong number, not a visible gap) |
| **Test** | A document whose currency cannot be sustained is written with no amounts. A document whose rate is not printed is written with no breakdown. |

## BR-04 â€” Never green without redundancy

|  |  |
| --- | --- |
| **Rule** | An amount with no independent breakdown to cross against is never green, however cleanly it was read. Check-digit consistency and repair are amber. |
| **Source** | PDR Â§6 Â· Finding 5 |
| **Test** | A card-terminal slip printing only a total shows the total amber and the amounts block expanded. |

## BR-05 â€” Derived values never raise confidence

|  |  |
| --- | --- |
| **Rule** | A value computed from other values â€” `base = total âˆ’ tax` â€” is tagged `derived` and may not raise the confidence of anything, including the values it was computed from. |
| **Source** | ADR-019 Â· PDR Â§6.1 |
| **Test** | Deriving a base from a read total and a read tax does not turn the total green. |

## BR-06 â€” Consensus by majority, never by maximum

|  |  |
| --- | --- |
| **Rule** | Where several candidate readings exist, the value a majority agree on wins. A single outlier never overrides agreement, and arithmetic runs only on operands that passed consensus. |
| **Source** | ADR-019 Â· 16-document test |
| **Test** | Three passes reading 19.99 against one reading 19.98 yield 19.99. |

## BR-07 â€” Derive by identity; never invent a rate

|  |  |
| --- | --- |
| **Rule** | Deriving a value by identity from two read values is allowed and useful. Deriving a value by assuming a rate the document does not state is never allowed, however plausible the rate looks. When a quantity cannot be read, the pipeline leaves it empty. |
| **Source** | ADR-019 Â· 16-document test (invented rates of 9%, 30% and a 4.5% conversion mark-up) |
| **Test** | Annex D, examples 3 and 4. A total with no printed rate yields no base, no tax and no rate. |

## BR-08 â€” Legal rates and negative context gate tax candidates

|  |  |
| --- | --- |
| **Rule** | A tax rate is checked against the detected country's legal set before use, and candidates suppressed by the negative-context dictionary are never treated as tax figures. |
| **Source** | ADR-019, ADR-005 Â· Annex C |
| **Test** | A printed DCC mark-up of 4.5% is captured as a surcharge, not a tax. A registry volume "Tomo 8.741" is never bound to a total label. |

## BR-09 â€” Integer minor units; one tolerance only

|  |  |
| --- | --- |
| **Rule** | Every monetary amount is an integer in the currency's minor unit, in the model, the local store and the Ninox payload; every rate is an integer in basis points. The sum of printed values is required to be **exactly** equal, with no tolerance. Tolerance exists in exactly one place: `base Ã— rate â‰ˆ tax`, with at most one minor unit per tax line. |
| **Source** | ADR-016 Â· 16-document test (the prototype's Â±0.02 let 16.51 + 3.47 pass against 19.98) |
| **Test** | Annex D, example 3. No conversion boundary in the pipeline reintroduces a float. |

## BR-10 â€” The document number never reaches green

|  |  |
| --- | --- |
| **Rule** | `doc_number` is never presented as confirmed: receipt and invoice numbers carry no check digit and every recognition pass produces a different variant. |
| **Source** | PDR Â§6.2 |
| **Test** | No document number is green on any screen in any state. |

## BR-11 â€” A supplier name is confirmable only via memory

|  |  |
| --- | --- |
| **Rule** | `supplier_name` cannot be confirmed by arithmetic. It is presented as confirmed only when the supplier memory supplies it from an identifier that passed its check digit. |
| **Source** | PDR Â§6.2, Â§11 Â· ADR-009 |
| **Test** | A first sighting of a supplier is amber; the second is green from memory; an identifier failing its check digit offers no memory match. |

## BR-12 â€” Currency carries its own evidence

|  |  |
| --- | --- |
| **Rule** | Currency is read from the document's own evidence â€” printed ISO code, symbol, issuer country â€” with its own confidence state, and is never defaulted to the table's currency. Where the currency cannot be sustained, amounts are not written. |
| **Source** | PDR Â§6 (v0.2) Â· Finding 3 Â· 16-document test (a euro receipt tagged USD; a dollar invoice tagged MAD) |
| **Test** | A USD invoice is written as USD; an unreadable currency suppresses the amounts rather than defaulting them. |

## BR-13 â€” Absent is not zero; the destination decides

|  |  |
| --- | --- |
| **Rule** | A value not printed is not a zero. Whether "not printed" means empty or a contractual zero is a per-field property of the destination, chosen by the user; the app never hardcodes either, and defaults to empty. In an e-invoice, a field the profile does not carry is `not_in_xml`, not absent. |
| **Source** | PDR Â§7.3, Â§6 Â· ADR-014 Â· 16-document test, record 1414 |
| **Test** | A terminal slip's VAT column reflects the per-field setting exactly; a `MINIMUM`-profile e-invoice shows `not_in_xml` fields as absent, never as zero. |

## BR-14 â€” Never block a save

|  |  |
| --- | --- |
| **Rule** | The user can always save. Missing or unreadable fields never prevent a record from being created with the document attached. |
| **Source** | PDR Â§4 |
| **Test** | A document from which nothing could be read is saved as a record with the attachment and no data. |

## BR-15 â€” Never write an unmapped field

|  |  |
| --- | --- |
| **Rule** | The app never writes a Ninox field the user has not explicitly mapped. It follows that no marker field may be relied on to exist, and duplicate prevention is handled read-side. |
| **Source** | Contract 6 Â· ADR-013 Â· PDR Â§8.2 |
| **Test** | A destination with no mapping sends a payload with no field keys; the record carries only the attachment. |

## BR-16 â€” Never touch schema or records the app did not create

|  |  |
| --- | --- |
| **Rule** | The app never creates, renames or deletes fields or tables, and never deletes or modifies records it did not create. |
| **Source** | PDR Â§3.2 Â· Contract 6 |
| **Test** | No API call from the app targets a schema endpoint; a correction updates a record whose identifier the app itself received from a create. |

## BR-17 â€” Byte-integrity of received files

|  |  |
| --- | --- |
| **Rule** | A document the app did not generate is attached byte-for-byte as received. No tool in the pipeline may re-save, flatten, re-compress or otherwise rewrite the source, even incidentally. |
| **Source** | ADR-007, ADR-015 Â· Finding 6 Â· Contract 8 |
| **Test** | The SHA-256 of a shared PDF's attachment equals the input's; the embedded XML of a Factur-X PDF survives into Ninox. |

## BR-18 â€” The record is always read back

|  |  |
| --- | --- |
| **Rule** | After create, the record is read back and the result is what the confirmation screen shows. Fields with formulas or defaults silently override submitted values, and the create response does not reveal it. |
| **Source** | PDR Â§9 Â· ADR-004 |
| **Test** | Where a table default overrides a submitted value, the confirmation shows the stored value. |

## BR-19 â€” The token is the only credential

|  |  |
| --- | --- |
| **Rule** | No Ninox username or password is ever requested, stored or transmitted. The API token is the only credential, it is obtained through the platform's system browser, and it lives in the platform keystore or keychain. |
| **Source** | PDR Â§3.2, Â§11 Â· ADR-018 Â· Contract 3 |
| **Test** | No password field exists in the app; the login page is only ever rendered by the system browser; the token never appears in the export file. |

## BR-20 â€” Dates come only from the document

|  |  |
| --- | --- |
| **Rule** | `doc_date` is never derived from a filename or a received-email timestamp; it is read from the document, and its format is inferred from the document's own evidence. |
| **Source** | PDR Â§5.1, Â§10 |
| **Test** | A file named `2026-08-27_invoice.pdf` whose document prints no date yields an empty date, not the filename's. |

## BR-21 â€” Never blindly retry a create

|  |  |
| --- | --- |
| **Rule** | A POST create whose response is lost is never retried blindly. It enters the uncertain state and is resolved by read-side reconciliation, or by asking the user. |
| **Source** | ADR-013 Â· Finding 1 Â· PDR Â§9.1 |
| **Test** | Annex D is silent here, but UC-11 is the test: no duplicate record exists after the flow, whether or not the original POST landed. |

## BR-22 â€” The attachment is never a mapping target

|  |  |
| --- | --- |
| **Rule** | The document is attached to the record itself, never to a mapped field. Uploading it is an automatic step of the send pipeline; no table can be unsuitable for the attachment. |
| **Source** | PDR Â§5.2 Â· ADR-007 |
| **Test** | A destination whose table has no file-type field still receives the attachment. |

# 6. Data specification

## 6.1 Canonical data dictionary

The canonical model is what the mapping maps **from**; it does not constrain the user's schema in any way (PDR Â§5). Every value carries provenance (Â§6.2). "Mappable" means the field may appear in the mapping picker; the attachment is not mappable (BR-22).

### 6.1.1 Core fields

Presented in the wizard and on the review screen, in this fixed order.

|  |  |  |  |  |
| --- | --- | --- | --- | --- |
| **Field** | **Type** | **Format** | **Provenance** | **Mappable** |
| `doc_date` | date | `YYYY-MM-DD` | `read`, `from_xml` | Yes Â· date fields only |
| `supplier_name` | text | â€” | `read`, `from_xml`, memory | Yes Â· text fields |
| `supplier_tax_id` | text | Normalised; uppercase, no separators, country prefix for intra-EU VAT | `read`, `from_xml`, `repaired` | Yes Â· text fields |
| `doc_number` | text | â€” | `read`, `from_xml` | Yes Â· text fields |
| `gross_total` | integer, minor units | Per ISO 4217 exponent | `read`, `from_xml`, `derived` | Yes Â· number fields |
| `currency` | text | ISO 4217 | `read`, `from_xml` | Yes Â· text fields |

### 6.1.2 Extended groups

Available under the wizard's advanced section and collapsed on the review screen. All optional.

|  |  |  |  |
| --- | --- | --- | --- |
| **Group** | **Field** | **Type / format** | **Notes** |
| Document | `doc_type` | enum | Document class. |
| Document | `doc_subtype` | enum: purchase, cash\_withdrawal, fuel, toll, parking, restaurant, other | Distinguishes a cash withdrawal from a purchase (16-document test, record 1428). |
| Document | `doc_time` | `HH:MM` | â€” |
| Document | `doc_series` | text | Invoice series prefix. |
| Document | `control_code` | text | Where a fiscal control code is printed. |
| Supplier | `supplier_address` | text | â€” |
| Supplier | `supplier_city` | text | â€” |
| Supplier | `supplier_country` | ISO 3166-1 alpha-2 | Feeds country detection. |
| Amounts | `net_total` | integer, minor units | Sum of printed bases. |
| Amounts | `tax_total` | integer, minor units | Derived from printed tax amounts; mappable (Finding 10). Never computed from an assumed rate. |
| Amounts | `discount_total` | integer, minor units | â€” |
| Amounts | `tax_rate[n]` | integer, basis points | One slot per printed rate; slot count per country table. |
| Amounts | `tax_base[n]` | integer, minor units | Per slot. |
| Amounts | `tax_amount[n]` | integer, minor units | Per slot. |
| Currency & payment | `gross_total_document_currency` | integer, minor units | Card charges settled in another currency. |
| Currency & payment | `gross_total_card_currency` | integer, minor units | â€” |
| Currency & payment | `exchange_rate` | decimal, as printed | â€” |
| Currency & payment | `payment_method` | enum: card, cash, transfer, direct\_debit, other | â€” |
| Currency & payment | `card_brand` | text | â€” |
| Currency & payment | `card_masked` | text | Last four digits only; never more, even if the ticket shows more. |
| Currency & payment | `auth_code` | text | â€” |
| Currency & payment | `iban` | text, normalised | Validated by IBAN modulo 97. |
| Surcharges | `surcharges[]` | repeatable `{ label, amount_minor }` | `label` âˆˆ dcc\_markup, service\_charge, tip, rounding\_adjustment, other. A conversion mark-up or a tip is never a tax line. |
| Travel | `licence_number` | text | â€” |
| Travel | `vehicle_plate` | text | â€” |
| Travel | `trip_from`, `trip_to` | text | â€” |
| Travel | `distance_km` | integer | â€” |
| Travel | `duration_min` | integer | â€” |
| Metadata | `confidence` | enum (green/amber/red per core field, or a score) | Optional mapping; the numeric score is never shown. |
| Metadata | `needs_review` | boolean | â€” |
| Metadata | `recognition_engine` | text | Includes the extraction route taken. |
| Metadata | `source_hash` | text | Document hash; feeds duplicate detection. |

The attachment is not part of this model (BR-22).

## 6.2 Provenance and confidence model

### 6.2.1 Provenance tags

|  |  |  |
| --- | --- | --- |
| **Tag** | **Meaning** | **Effect on a consuming check** |
| `read` | Taken directly from the document's text, OCR consensus, or positional extraction. | May confirm. |
| `from_xml` | Taken from a structured e-invoice's embedded or attached XML â€” deterministic by construction. | May confirm; the strongest form. |
| `derived` | Computed from other read values through an identity the document itself supports. | Never confirms. |
| `repaired` | One implausible character replaced by the unique value a check digit admits. | Never confirms. |

Provenance is internal, travels with every value, is stored in history, and is **never written to Ninox** (FR-EXT-011).

### 6.2.2 Confidence states

|  |  |  |
| --- | --- | --- |
| **State** | **Meaning** | **Editing** |
| Green | Confirmed by redundancy between independently read values. | Only after tapping the lock. |
| Amber | Read, and either check-digit-consistent, repaired, or simply un-cross-checked. The user is expected to glance at it. | Directly editable. |
| Red | Not read at all, or read and rejected by a constraint. | Directly editable; the value is not written. |

The numeric recognition score is never displayed (FR-VAL-004).

### 6.2.3 Document state machine

A document moves through exactly these states; every transition is triggered and observable in history.

```
capturing â†’ ingested â†’ extracting â†’ reviewing â†’ queued â†’ sending â†’ attaching â†’ reading-back â†’ sent
                |           |              |             |          |
                |           â†“              |             â†“          â†“
                |        (failed)      (discarded)   uncertain    failed
                |                                        |
                +----------------------------------------+
                                     â†“
                                reconciling â†’ (adopt | create | ask the user)
```

|  |  |
| --- | --- |
| **From `reviewing`** | The user may edit anything and save, or discard (FR-REV-011). |
| **From `queued`** | Sent automatically when connectivity returns (UC-10). |
| **From `uncertain`** | Never a blind retry: reconcile, or ask (FR-SND-005, BR-21). |
| **From `failed`** | The file is retained; the entry can be corrected and re-sent (UC-12). |
| **From `sent`** | The local image is deleted; the entry stays in history (FR-HIS-004). |
| **Any state** | A duplicate match sets `duplicate-flagged` alongside the underlying state; it never blocks a save. |

### 6.2.4 What may be shown as confirmed, and what may be written

|  |  |
| --- | --- |
| **Shown as confirmed (green)** | Only a value established by redundancy whose every operand is `read` or `from_xml` (BR-01, BR-02), or a supplier name supplied by memory from a check-digit-passing identifier (BR-11). |
| **Written to Ninox** | Any value the user did not correct away, that is not red, and that has a mapped destination field. Red values are never written. An unsustained currency suppresses the amounts (BR-12). |
| **Written as zero** | Only where the destination's per-field setting says so and the value is genuinely absent (BR-13). |

## 6.3 Local stores

There is no backend; all state is local (ADR-009).

|  |  |  |
| --- | --- | --- |
| **Store** | **Contents** | **Retention** |
| History | One entry per capture: thumbnail, values with provenance, destination, state, confidence, hash, record identifier once sent. | Entries persist until the user clears them. Document files are deleted on `sent`; pending and failed keep theirs. |
| Destinations | Team, database, table, field mapping, host, per-field absent-value settings. Stored as field identifiers. | Persists; included in export/import. |
| Supplier memory | Identifierâ€“name pairs, indexed only by check-digit-passing identifiers. | Persists; included in export/import; emptied by the data-clearing action. |
| Configuration file | The export/import artefact: destinations, mappings, supplier memory. Never the token. | Wherever the user keeps it. Covered by the privacy notice. |
| Keystore / Keychain | The API token. | Never exported; re-entered on a new device. |

## 6.4 Ninox payload and mapping rules

|  |  |
| --- | --- |
| **Keying** | Payloads are keyed by field **name**; the destination stores field **identifiers** and resolves the current name at send time from a cached schema that refreshes when the app opens (FR-DST-003). |
| **Envelope** | Records are written as a nested object under a `fields` key (FR-SND-002). |
| **Dates** | A `YYYY-MM-DD` string is stored verbatim. |
| **Amounts** | Integers in the minor unit; never floats, never formatted strings. |
| **Rates** | Integers in basis points. |
| **Choice fields** | The mapping offers the field's existing options; the value written is one of them (FR-DST-007). |
| **Formula / read-only fields** | Excluded from mapping candidates; never written (FR-DST-004). A formula total is read back and used as contrast (FR-DST-005). |
| **Absent values** | Empty by default, or zero per the destination's per-field setting (FR-DST-006). |
| **Attachment** | Never part of the payload; attached to the record in a separate multipart call (FR-SND-003, BR-22). |
| **Updates** | Merges â€” a correction sends only what changed (FR-SND-008). |


# 7. Interface specification

Composition and navigation only. The behaviour of every element below is specified in Â§4; this section fixes what is on each screen, where it sits, and what the user can reach from it.

## 7.1 Screen inventory and navigation map

|  |  |
| --- | --- |
| **Screen** | **Reached from** |
| Capture | The app's single entry point; the capture affordance; share-in from another app |
| Review | Capture, or the iOS Share Extension hand-off |
| Destination list and editor | The review screen's destination bar; settings |
| Mapping editor | The destination editor; the wizard's last step |
| Wizard (5 steps) | First run; settings â†’ add destination |
| History list | The app's history surface |
| History detail | A history entry |
| Confirmation | A successful send |
| Settings | The app's settings surface |
| Empty state | First run, or history with no entries |

**Navigation map.** Every arrow is a user-reachable transition; review is the hub.

```
                     [system scanner / share-in / file picker / mail]
                                          â”‚
   first run â”€â”€â–º Wizard â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”â”‚
                   â”‚                     â”‚â–¼
                   â–¼                  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”        â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
              Destination list â—„â”€â”€â”€â”€â”€â”€â”¤ Review  â”‚â”€â”€â”€â”€â”€â”€â–º â”‚ Confirmation  â”‚
                   â”‚                  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜        â””â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”˜
                   â–¼                       â”‚ â–²                    â”‚
              Mapping editor              â”‚ â”‚                    â”‚ deep link
                   â”‚                      â”‚ â”‚                    â–¼
                   â””â”€â”€â”€ destination bar â”€â”€â”˜ â”‚              [Ninox record]
                                          â”‚
                                          â”‚ discard
                                          â–¼
                                     [deleted]
   History list â”€â”€â–º History detail â”€â”€â–º (correct) â”€â”€â–º Review â”€â”€â–º â€¦
        â”‚                â”‚
        â””â”€â”€ settings â”€â”€â”€â”€â”´â”€â”€â–º Settings â”€â”€â–º Wizard (add destination)
                                  â”‚
                                  â””â”€â”€â–º export / import / clear data
```

## 7.2 Capture

A single entry point with four paths in (FR-CAP-001). The camera path uses the platform document scanner's own interface â€” edge detection, perspective correction, contrast enhancement and page chaining â€” which the user already knows from their notes application (FR-CAP-002). Multi-page chaining stays one expense (FR-CAP-003). From share-in and from the iOS extension the app opens **directly into review** with no intermediate screen (FR-CAP-008).

**Visible states:** normal capture Â· page added (multi-page) Â· capture cancelled Â· no camera permission (with a path to system settings) Â· storage full.

## 7.3 Review

The screen the user sees on every document, and therefore the one that decides whether the application feels light or heavy. From top to bottom:

1. **Destination bar** â€” full width, persistent, showing team, database and table; tappable. Pre-loaded with the last destination used; highlighted once per day with the save button disabled until acknowledged (FR-REV-001, FR-REV-002).
2. **Document thumbnail** â€” tapping a field draws a box around the read region and zooms; a redundancy-checked value highlights every operand's region (FR-REV-003).
3. **The six core fields** â€” fixed order, inline editing, large type, colour per confidence; focus jumps to the first unread field (FR-REV-004).
4. **Amounts block** â€” one confirming line when redundancy passes; expanded when it does not, including when there is no breakdown to check against (FR-REV-005).
5. **Advanced** â€” collapsed by default; the remaining mapped fields, `surcharges[]`, `doc_subtype` (FR-REV-006).
6. **Duplicate notice** â€” when the check matches, with a link to the existing record and a "send anyway" path (FR-REV-007).
7. **Save button** â€” fixed at the bottom, naming the destination (FR-REV-008).

**Visible states:** all six core fields green, amounts collapsed (clean document) Â· amber fields present, amounts expanded (typical document) Â· red fields present (partial document â€” still saveable) Â· duplicate notice shown Â· destination confirmation pending Â· offline save (queued) Â· extraction in progress Â· extraction failed.

## 7.4 Destination editor and mapping

A destination is team + database + table + mapping + host (FR-DST-001). The editor presents the three pickers in order, then the mapping. The mapping picker shows, per canonical field, the table's real fields filtered by type, with formula and read-only fields absent from the list (FR-DST-004, FR-WIZ-006). Each mapped field carries the "absent = empty or zero" setting (FR-DST-006). Choice fields offer the existing options (FR-DST-007). The Ninox host sits in the advanced section, defaulting to `api.ninox.com` (FR-DST-008).

**Visible states:** no destination yet Â· one destination Â· several destinations Â· schema unreadable (offline at configuration time) Â· mapping with unmapped fields (shown visibly, not hidden).

## 7.5 Wizard

At most five screens; three of them disappear when there is nothing to choose (FR-WIZ-001, FR-WIZ-002).

|  |  |  |
| --- | --- | --- |
| **Step** | **Content** | **Omitted when** |
| 1 Â· Token | Instructions, paste button, "open Ninox settings" in the system browser; immediate validation | Never |
| 2 Â· Team | List from the API | Exactly one team |
| 3 Â· Database | List from the API | Exactly one database |
| 4 Â· Table | List, with schema returned in the same call | Exactly one table |
| 5 Â· Mapping | Six core fields as pre-filled proposals; plain-language summary; offer to capture | Never (but may be skipped past with nothing mapped) |

**Variants with omitted steps.** A single-team, single-database subscription shows two screens: token and mapping. A subscription with several databases shows four. The user always ends on mapping, because that is the step with consequences, and the summary spells them out (FR-WIZ-008).

## 7.6 History and detail

The history list shows every capture with its state (FR-HIS-002), grouped so that pending, failed and uncertain items surface first â€” those are the ones that need the user. The detail view shows the thumbnail, the values with their provenance, the destination, the state, the confidence, the document hash and the Ninox record identifier once sent (FR-HIS-001), with a path to correct and re-send (FR-HIS-003).

**Visible states:** empty history Â· pending / queued Â· sent Â· failed (file retained) Â· uncertain Â· duplicate-flagged.

## 7.7 Confirmation

After a successful send, the confirmation shows what is **actually stored** â€” the read-back â€” and offers the deep link to the record in Ninox (FR-SND-006, BR-18). Where a formula field's total disagrees with the extracted total, the mismatch is surfaced here as a question about the mapping, not as an extraction verdict (FR-DST-005). If the URL structure no longer resolves, the button degrades to opening the database.

**Visible states:** sent, read-back matches Â· sent, read-back differs (mapping question) Â· sent, attachment still uploading or retried Â· deep link unavailable (degraded).

## 7.8 Global states

|  |  |
| --- | --- |
| **State** | **Behaviour** |
| Empty application | No destination; the wizard is offered; nothing else is possible until it completes. |
| First execution | The wizard; its close offers to capture the first document of any kind (FR-WIZ-008). |
| No connectivity | Capture, extraction and review work; saves are queued; the queue drains automatically on return (UC-10). |
| Authentication expired | 401/403 surfaces as an authentication problem; the user re-enters the token; queued items are not retried until it is fixed. |
| Destination missing | 404 sends the user to the destination editor rather than reporting a server error. |
| Error surfaces | Per the matrix in Â§9; every error names the operation that failed and the next action, never a bare status code. |

# 8. Non-functional requirements

### NFR-PRV-001 â€” No backend, ever

|  |  |
| --- | --- |
| **Requirement** | The application shall operate with no backend service, in any version. |
| **Acceptance** | No network call other than to the user's own Ninox database exists in the codebase or in observed traffic. |
| **Source** | ADR-002 Â· Contract 1 |

### NFR-PRV-002 â€” The precise privacy claim

|  |  |
| --- | --- |
| **Requirement** | No document, image or extracted value shall leave the device except toward the user's own Ninox database. The store listing shall lead with the claim stated precisely: "your documents never leave your device", with the platform-component caveat of NFR-PRV-003 disclosed, never as an unqualified "nothing leaves the device" that the Data Safety form would then contradict. |
| **Acceptance** | The store listing text and the in-app privacy notice match; the Data Safety form is completed accordingly. |
| **Source** | PDR Â§11 Â· Finding 9 |

### NFR-PRV-003 â€” Platform diagnostics are distinguished from document content

|  |  |
| --- | --- |
| **Requirement** | Google's and Apple's own disclosures for the scanner and recognition components state that operational diagnostics â€” device model, OS version, API latency, error codes â€” are sent to the vendor, encrypted, but that the image and the recognised text are not. The privacy notice shall state exactly this distinction, and document content shall never be part of any diagnostic. |
| **Acceptance** | The notice text distinguishes the two; no document content appears in any platform diagnostic the app causes. |
| **Source** | PDR Â§11 Â· Finding 9 Â· verified against Google's ML Kit data disclosure |

### NFR-PRV-004 â€” Both local stores are declared

|  |  |
| --- | --- |
| **Requirement** | Two local stores hold data and both shall be declared in the privacy notice: the supplier memory, holding tax identifiers and names of third-party businesses, and the exportable configuration file, which carries those same pairs. |
| **Acceptance** | The notice names both stores and their contents. |
| **Source** | PDR Â§11 Â· ADR-009 |

### NFR-PRV-005 â€” Data clearing is real

|  |  |
| --- | --- |
| **Requirement** | The data-clearing action shall genuinely empty the supplier memory and the other local stores. |
| **Acceptance** | FR-CFG-003, FR-MEM-004. |
| **Source** | ADR-009 Â· PDR Â§11 |

### NFR-PRV-006 â€” No telemetry in public builds

|  |  |
| --- | --- |
| **Requirement** | No telemetry shall be collected in public builds. Product metrics shall be gathered by supervised measurement before each release instead (Â§10.4). |
| **Acceptance** | No analytics call exists in a public build; the release process includes the supervised-measurement protocol. |
| **Source** | ADR-012 Â· Contract 7 |

### NFR-SEC-001 â€” Token in the platform keystore

|  |  |
| --- | --- |
| **Requirement** | The API token shall be stored in the Android Keystore or the iOS Keychain and shall never appear in an export, a backup snapshot, or a log line. |
| **Acceptance** | FR-CFG-004; the export file contains no credential. |
| **Source** | PDR Â§11 Â· ADR-009, ADR-018 |

### NFR-SEC-002 â€” No app-controlled WebView for Ninox authentication

|  |  |
| --- | --- |
| **Requirement** | The Ninox login shall only ever be rendered by the platform's system browser component. The application shall be structurally unable to observe a Ninox password field. |
| **Acceptance** | FR-WIZ-003; inspection shows no WebView in the authentication path. |
| **Source** | ADR-018 Â· Contract 3 |

### NFR-SEC-003 â€” No credentials beyond the token

|  |  |
| --- | --- |
| **Requirement** | No Ninox username or password shall be requested, stored or transmitted. |
| **Acceptance** | BR-19. |
| **Source** | PDR Â§3.2 Â· Contract 3 |

### NFR-PRF-001 â€” Time per document

|  |  |
| --- | --- |
| **Requirement** | Median time from opening capture to a confirmed save shall be low enough that the flow feels light; the threshold is **deferred** until the first corpus screening shows what is achievable (PDR Â§12). A threshold written today would be invented. |
| **Acceptance** | Measured by the supervised protocol of Â§10.4 against the threshold fixed after the first screening. |
| **Source** | PDR Â§12 Â· ADR-012 |
| **Status** | Defined; threshold deferred |

### NFR-PRF-002 â€” Reading requires no network

|  |  |
| --- | --- |
| **Requirement** | Extraction and validation shall complete with no network dependency, so that capture works without connectivity and the send is the only step that waits. |
| **Acceptance** | FR-CAP-009, UC-10. |
| **Source** | ADR-002 Â· PDR Â§3.1 |

### NFR-OFL-001 â€” Offline behaviour

|  |  |
| --- | --- |
| **Requirement** | The app shall remain fully usable offline for capture, extraction, review and queueing; only the send waits. |
| **Acceptance** | UC-10. |
| **Source** | PDR Â§3.1, Â§9.1 |

### NFR-PRF-003 â€” Tap count

|  |  |
| --- | --- |
| **Requirement** | A document that validates cleanly shall be captured, reviewed and saved in three taps plus one destination confirmation on the first capture of the day. A typical document shall cost five to six taps. Both figures are release criteria, measured by the supervised protocol. |
| **Acceptance** | UC-02, UC-03; Â§10.4. |
| **Source** | PDR Â§6.2, Â§7.2 |

### NFR-ACC-001 â€” Accessibility

|  |  |
| --- | --- |
| **Requirement** | The interface shall meet the platform accessibility standards: every control labelled, colour states paired with a non-colour cue, large-type fields by default, and the read region and confidence state exposed to assistive technology. |
| **Acceptance** | A pass with the platform accessibility auditor over the review and history screens; confidence states are not conveyed by colour alone. |
| **Source** | PDR Â§4 (light and simple) |

### NFR-I18N-001 â€” Interface languages

|  |  |
| --- | --- |
| **Requirement** | The interface shall ship in English and German, with all user-facing strings externalised. Document dictionaries are independent of interface language (FR-CTR-006). |
| **Acceptance** | Switching the device language switches every string, including error messages; no hardcoded user-facing string exists. |
| **Source** | PDR Â§3.1, Â§10 |

### NFR-LIC-001 â€” Declared dependencies

|  |  |
| --- | --- |
| **Requirement** | Every proprietary dependency shall be declared in the repository README. No AGPL-licensed component shall ship inside the app: PyMuPDF, used by the 16-document test harness, is test-harness-only and excluded from the shipped application; iText is excluded outright. |
| **Acceptance** | The README lists every dependency with its licence; no AGPL artefact is linked into a release build. |
| **Source** | Contract 5 Â· ADR-011 |

### NFR-PLT-001 â€” Platforms

|  |  |
| --- | --- |
| **Requirement** | The application shall ship for Android and iOS. Minimum OS versions are fixed in the SDD, not here. |
| **Acceptance** | Both store builds install and complete UC-02. |
| **Source** | PDR Â§3.1 |

### NFR-SIZ-001 â€” Application size

|  |  |
| --- | --- |
| **Requirement** | The contribution of the PDF library to application size shall be acceptable; this is part of ADR-011's closure criterion. |
| **Acceptance** | Measured size delta reported with the library decision. |
| **Source** | ADR-011 |
| **Status** | Blocked by ADR-011 |

# 9. Error handling and user messaging

## 9.1 Error taxonomy by operation

Every error names the operation that failed and the next action. A bare status code is never shown to the user.

|  |  |  |  |
| --- | --- | --- | --- |
| **Operation** | **Condition** | **Behaviour** | **Message (EN / DE)** |
| Token entry | Invalid or rejected | Stay on the step; no partial destination stored | "The API token was not accepted. Check it in your Ninox settings and paste it again." / "Das API-Token wurde nicht akzeptiert. PrÃ¼fen Sie es in den Ninox-Einstellungen und fÃ¼gen Sie es erneut ein." |
| Token in use | 401 / 403 on any call | Mark authentication problem; stop the queue; ask for the token | "Your token is no longer valid. Re-enter it to continue sending." / "Ihr Token ist nicht mehr gÃ¼ltig. Geben Sie es erneut ein, um weiter zu senden." |
| Schema read | Network failure | Bounded backoff; the wizard step stays | "The destination list could not be read. Check your connection." / "Die Zielliste konnte nicht gelesen werden. PrÃ¼fen Sie Ihre Verbindung." |
| Schema read | 404 | The database or table no longer exists; send the user to the destination | "The database or table no longer exists. Choose another destination." / "Datenbank oder Tabelle existiert nicht mehr. WÃ¤hlen Sie ein anderes Ziel." |
| Create | Timeout / network error | Uncertain state â†’ reconciliation â†’ ask if ambiguous (FR-SND-005) | "The send could not be confirmed. Checking whether the record was createdâ€¦" / "Der Versand konnte nicht bestÃ¤tigt werden. PrÃ¼fung, ob der Datensatz erstellt wurdeâ€¦" then "One similar record was found â€” use it?" / "Ein Ã¤hnlicher Datensatz wurde gefunden â€” verwenden?" |
| Create | 500 | Refresh schema, retry once, then report a **mapping** error (Â§9.3) | "A field could not be saved. The mapping may need correcting." / "Ein Feld konnte nicht gespeichert werden. MÃ¶glicherweise muss das Mapping korrigiert werden." |
| Attachment | Timeout / failure | Retry the attachment only; the record is untouched | "The document is being uploaded again." / "Das Dokument wird erneut hochgeladen." |
| Read-back | Timeout | Bounded backoff; the confirmation waits | "Reading the stored recordâ€¦" / "Gespeicherten Datensatz wird gelesenâ€¦" |
| Deep link | URL no longer resolves | Degrade to opening the database | "Open in Ninox" still opens the database rather than failing. |
| Extraction | No value can be sustained | Not an error: the field is empty (BR-03) | No error is shown; the field renders red or empty. |

## 9.2 The retry matrix, expanded to user-visible behaviour

The matrix of FR-SND-004, with what the user sees.

|  |  |  |
| --- | --- | --- |
| **Condition** | **Retry** | **User-visible behaviour** |
| No connectivity | Yes, automatic | History entry reads *Queued* / *In Warteschlange*; it turns *Sent* / *Gesendet* on reconnect with no user action. |
| Timeout or network error on create | No blind retry â€” reconciliation first | Entry reads *uncertain* briefly; then either the flow completes silently (match found or record created) or the user is asked. |
| Timeout on attachment or read-back | Yes, bounded exponential backoff | A progress indicator with a retry count the user can see, not an infinite spinner. |
| 401 / 403 | No | Authentication message; the queue halts until the token is re-entered. |
| 404 | No | Destination message; the user is taken to the destination editor. |
| 500 | Once only | Schema refresh; a second failure is a mapping error, and the message says so â€” never "server problem". |
| Record created, attachment failed | Attachment only | The record is not re-created; the attachment retry is visible on the confirmation screen. |

## 9.3 Mapping error versus server error â€” the semantics of 500

Ninox reports a mistyped or read-only field name as HTTP 500 rather than a 4xx with an explanation (ADR-004). A client that retried server errors blindly would retry a mapping mistake forever, draining battery and data while telling the user it was a server problem. Therefore:

* A 500 is treated as a **mapping problem until proven otherwise**: refresh the schema, retry once, and if it fails again, report a mapping error by name.
* Only a genuine, repeated failure across *several* distinct destinations may be reported as a server-side problem, and only through the supervised-measurement channel, never by the user-facing text.
* A user who sees "a field could not be saved" is being told the truth: the most likely cause is a mapping or schema mismatch, and the next action is to inspect the mapping.

## 9.4 Authentication expiry flow

1. Any call returns 401 or 403.
2. The destination is marked as having an authentication problem; queued items are **not** retried against a stale token.
3. The user is asked to re-enter the token, via the same system-browser flow as the wizard (FR-WIZ-003).
4. On a valid token, the queue resumes in order; the uncertain-create reconciliation is not confused by the pause, because its time window is around the original attempt.


# 10. Acceptance criteria, metrics and validation

## 10.1 The corpus has two halves

Two routes carry equal weight, so the corpus has two halves and they are gathered differently (PDR Â§13).

|  |  |
| --- | --- |
| **Half** | **Content** |
| Photographed paper | Real receipts, photographed: thermal paper, faded ink, shadows, skew. Different merchants, deliberately including difficult cases. Language is irrelevant here â€” this route measures paper degradation, not vocabulary. |
| PDF and e-invoices | Supplier invoices â€” plain PDF and structured e-invoices (ZUGFeRD / Factur-X, XRechnung) across as many issuers, profiles and countries as possible. |

The 16-document test skewed toward B2B invoices and non-EUR documents; the corpus keeps both halves equal and is not reweighted on sixteen documents (PDR Â§2).

## 10.2 Screening is a filter, not a measurement

The initial screening runs on roughly fifteen photographed documents. That is enough to detect gross failure and eliminate an unusable engine, but not enough to produce a defensible accuracy figure: with fifteen documents a single error moves the result by almost seven points. The screening is therefore treated as a **filter**. If one engine clearly loses, the decision is made; if the candidates tie, the corpus is extended before deciding (PDR Â§13).

When the corpus is extended, it is extended **toward the gaps that block the decision** â€” a scanned-PDF sample, and photographed paper from hospitality and fuel receipts, where thermal degradation is worst â€” never toward a round number of documents (ADR Â§3.1).

## 10.3 What is measured

**Per-field accuracy after the validation layer**, not raw character error rate:

* Only values whose provenance is `read` or `from_xml` are eligible for the "confirmed" tally.
* Derived values are never dressed up as confirmations; a check built from derived operands proves nothing (BR-02).
* An engine that reads worse may well tie on validated fields, because the check digits recover what the recognition lost â€” which is the point of the product (PDR Â§1.1).

Ground truth is what is **printed** on the document. The corpus's annotation rules apply: money in integer minor units, rates in basis points, and a field state that distinguishes `present`, `absent`, `illegible` and, for e-invoices, `not_in_xml`. `illegible` is not scored against any engine.

## 10.4 Supervised measurement protocol

There is no telemetry (ADR-012), so product metrics are gathered by supervised measurement before each release:

1. **Observed sessions** with real users: median seconds and taps per document, from opening capture to a confirmed save.
2. **Benchmark run** over the test corpus: per-field accuracy after validation, per route.
3. Both are recorded per release; regressions are caught by comparison, not by absolute threshold.

The tap-count criterion is explicit and is part of this protocol: **three taps plus one destination confirmation** for a clean document (UC-02), **five to six taps** for a typical one (UC-03). Holding the universal "three taps" expectation that the PDR considers dishonest is a failure of this criterion.

## 10.5 Metrics and release criteria

|  |  |  |
| --- | --- | --- |
| **Metric** | **Definition** | **Release criterion** |
| Time per document | Median seconds from opening capture to a confirmed save. | Threshold fixed after the first screening. |
| Taps per document | Median interactions in the same interval. | 3 + 1 daily confirmation for a clean document; 5â€“6 typical. |
| Untouched rate | Share of documents saved without the user editing any field. | Tracked; threshold after the first screening. |
| Green rate | Share of core fields confirmed by redundancy â€” not merely check-digit-consistent. | Tracked; threshold after the first screening. |
| Abstention rate | Share of mapped amount fields left empty because no reading could be sustained. | **Deliberately non-zero by design.** A rising rate is the visible cost of the "empty over false" principle (BR-03), not a regression. |
| Reach | Installations, store rating, repository stars, contributions, mentions in the Ninox community. | Secondary; never overrides a product metric. |

**Thresholds are deliberately not fixed in this document.** Any number written today would be invented; they are set once the first corpus screening shows what is achievable (PDR Â§12).

## 10.6 Acceptance conventions

* Every FR, BR and NFR in this document carries its own acceptance condition; a requirement without one is an intention and was not admitted (Â§1.5).
* Every non-goal of Â§1.2 has a negative test in the release checklist: no backend call, no schema mutation, no credential beyond the token, no unmapped write, no telemetry artefact, no mail-body byte.
* Every worked example of Annex D is an acceptance case, including the negative ones.
* Blocked requirements (Â§11.5) are excluded from the release checklist until their ADR closes; their acceptance tests are written now and run then.

# 11. Traceability

The matrix in both directions, so that no decision stays without a requirement and no requirement appears without a source. Blocked requirements are listed in Â§11.5.

## 11.1 ADR â†’ requirements

|  |  |
| --- | --- |
| **ADR** | **Requirements that implement it** |
| ADR-001 Flutter, native iOS share extension | FR-CAP-001, FR-CAP-008, NFR-PLT-001 |
| ADR-002 On-device extraction, no backend | FR-CAP-009, FR-EXT-014, NFR-PRV-001, NFR-PRF-002, NFR-OFL-001, UC-10 |
| ADR-003 Ninox classic REST API | FR-WIZ-003, FR-DST-001, Â§2.5 dependency |
| ADR-004 Ninox client contract | FR-DST-003, FR-DST-004, FR-DST-007, FR-SND-001, FR-SND-002, FR-SND-003, FR-SND-008, BR-18, Annex A |
| ADR-005 Universal core plus country table | FR-CTR-001 â€¦ FR-CTR-007, FR-VAL-005, FR-VAL-007, FR-VAL-011, Annex B |
| ADR-006 OS document scanners | FR-CAP-002, Â§2.3 dependency |
| ADR-007 Attachment integrity | FR-CAP-004, FR-CAP-005, BR-17, BR-22 |
| ADR-008 Return by deep link | FR-SND-006, UC-02 |
| ADR-009 Local storage, portable config | FR-CFG-001 â€¦ FR-CFG-004, FR-MEM-001 â€¦ FR-MEM-004, FR-HIS-004, UC-13, NFR-PRV-004 |
| ADR-010 Recognition engine (OPEN) | FR-EXT-015, FR-EXT-005, UC-14 â€” blocked |
| ADR-011 PDF text extraction (PROPOSED) | FR-EXT-004, NFR-SIZ-001 â€” blocked |
| ADR-012 No telemetry; supervised measurement | NFR-PRV-006, Â§10.4 |
| ADR-013 Reconciliation of uncertain sends | FR-SND-005, FR-SND-004, BR-21, UC-11 |
| ADR-014 Extraction priority | FR-EXT-002, FR-EXT-003, FR-EXT-005, BR-13, UC-04 |
| ADR-015 Integrity of the original | FR-CAP-005, FR-EXT-003, FR-EXT-005, BR-17 |
| ADR-016 Integer minor units | FR-SND-002, FR-VAL-006, BR-09, FR-CTR-007, Â§6.1 |
| ADR-017 Configurable host | FR-DST-001, FR-DST-008, FR-WIZ-003 |
| ADR-018 Token via system browser | FR-WIZ-003, NFR-SEC-002, BR-19 |
| ADR-019 Consensus, provenance, derive/invent boundary | FR-EXT-001, FR-EXT-006 â€¦ FR-EXT-011, FR-VAL-002, BR-02, BR-05, BR-06, BR-07, BR-08, Annex D |

## 11.2 PDR section â†’ requirements

|  |  |
| --- | --- |
| **PDR** | **Requirements** |
| Â§1 Purpose, Â§1.1 differentiation | Â§2.1, FR-VAL-001, FR-VAL-006, FR-VAL-008 |
| Â§2 Users and market | UC-01 â€¦ UC-15, Â§2.2, Â§10.1 |
| Â§3.1 Scope | FR-CAP-001, FR-CTR-006, NFR-PLT-001, NFR-I18N-001 |
| Â§3.2 Non-goals | Â§1.2 negative requirements, BR-14 â€¦ BR-19, Â§10.6 |
| Â§4 Principles | BR-01 (determinism), BR-03 (empty over false), BR-14 (never block), FR-REV-009, NFR-PRF-003 |
| Â§5.1 Core fields | Â§6.1.1, FR-REV-004, FR-WIZ-005 |
| Â§5.2 Extended fields | Â§6.1.2, FR-REV-006, FR-SND-002 |
| Â§5.3 Multiple tax rates | FR-CAP-003, FR-VAL-011, UC-06 |
| Â§6 Confidence model | FR-VAL-001 â€¦ FR-VAL-004, FR-VAL-009, FR-VAL-010, Â§6.2 |
| Â§6.1 Provenance and derived values | FR-EXT-007, FR-EXT-008, FR-EXT-011, BR-02, BR-05, FR-VAL-002 |
| Â§6.2 An honest expectation | FR-VAL-010, NFR-PRF-003, Â§10.4, UC-03 |
| Â§7.1 Capture | FR-CAP-001 â€¦ FR-CAP-008, Â§7.2 |
| Â§7.2 Review | FR-REV-001 â€¦ FR-REV-011, Â§7.3 |
| Â§7.3 Destinations | FR-DST-001 â€¦ FR-DST-003, FR-DST-006, FR-REV-002 |
| Â§7.4 Formula fields | FR-DST-004, FR-DST-005 |
| Â§7.5 History | FR-HIS-001 â€¦ FR-HIS-005, Â§7.6 |
| Â§8 Wizard | FR-WIZ-001 â€¦ FR-WIZ-008, Â§7.5 |
| Â§8.1 Field matching | FR-WIZ-006, FR-DST-004 |
| Â§8.2 Completing the wizard | FR-WIZ-007, FR-WIZ-008 |
| Â§9 Sending | FR-SND-001, FR-SND-003, FR-SND-007 |
| Â§9.1 Retry policy | FR-SND-004, FR-SND-005, Â§9.2 |
| Â§9.2 Returning to Ninox | FR-SND-006, Â§7.7 |
| Â§10 Countries and languages | FR-CTR-001 â€¦ FR-CTR-007, Annex B, Annex C |
| Â§11 Privacy and data | NFR-PRV-001 â€¦ NFR-PRV-005, FR-MEM-002, FR-CFG-001, FR-CFG-004 |
| Â§12 Success metrics | Â§10.4, Â§10.5, NFR-PRF-001, NFR-PRF-003 |
| Â§13 Test corpus | Â§10.1, Â§10.2, Â§10.3, FR-EXT-015 |
| Â§14 Open items | Â§12 |
| Annex A Technical contract | Â§2.4, Annex A |

## 11.3 Findings â†’ requirements

The seventeen findings raised against PDR v0.1 were triaged with a verdict and an action each. This matrix traces the findings whose triage produced a functional requirement; it is sourced from the change logs of PDR v0.2 and ADR v0.2, which cite finding numbers explicitly.

|  |  |
| --- | --- |
| **Finding** | **Requirements it motivated** |
| 1 â€” blind retry duplicates records | ADR-013, FR-SND-005, FR-SND-004, BR-21, UC-11 |
| 3 â€” currency treated as confirmable | FR-EXT-013, FR-VAL-009, BR-12 |
| 4 â€” destination default contradicted pre-load | FR-REV-002, FR-DST-002 |
| 5 â€” "green" collapsed three different things | FR-VAL-001, BR-04 |
| 6 â€” VisionKit returns images; re-saving destroys XML | ADR-007, ADR-015, FR-CAP-005, BR-17 |
| 7 â€” in-app browser for the token | ADR-018, FR-WIZ-003, NFR-SEC-002 |
| 8 â€” `workspace` terminology | Â§1.4 (team), throughout |
| 9 â€” privacy claim imprecise | NFR-PRV-002, NFR-PRV-003 |
| 10 â€” no field for tax\_total | Â§6.1.2 (`tax_total` derived, mappable) |
| 12 â€” extraction priority on the invoice route | ADR-014, FR-EXT-002 |
| 13 â€” Switzerland not a first-class row | ADR-005, FR-CTR-004, FR-CTR-001 |
| 14 â€” hard-coded host | ADR-017, FR-DST-008 |

Findings 2, 11, 15, 16 and 17 are recorded in the project's internal review record; their triage actions are reflected in the PDR v0.2 change log and introduce no requirement beyond those traced above. No finding was closed without an action.

## 11.4 16-document test â†’ requirements

|  |  |
| --- | --- |
| **Test finding** | **Requirements it motivated** |
| Nine of ten "arithmetic-verified" records derived the base from the total â€” the check was a tautology | ADR-019, FR-VAL-002, BR-02, BR-05, FR-EXT-007 |
| Three invented rates (9%, 30%, 4.5% DCC mark-up) | FR-EXT-008, FR-EXT-009, FR-EXT-010, BR-07, BR-08 |
| The pipeline took the maximum across OCR passes instead of the majority | FR-EXT-006, BR-06 |
| A euro receipt tagged USD and a dollar invoice tagged MAD | FR-EXT-013, FR-VAL-009, BR-12 |
| PRO1013-26: a registry volume reference ("Tomo 8.741") picked up as the total | ADR-011, FR-EXT-004 |
| `.msg` containers carried a signature image alongside the document | FR-CAP-007, UC-08 |
| Card-terminal slips print no breakdown | FR-VAL-012, FR-DST-006, BR-13, UC-05 |
| The destination table's total is a formula field, not writable | FR-DST-004, FR-DST-005, BR-22 |
| Attachment upload verified end-to-end across sixteen uploads | ADR-004, FR-SND-003, Annex A |
| A receipt with two printed rates collapsed into one pair | FR-VAL-011, UC-06 |
| Record 1428, a cash withdrawal with a conversion mark-up | Â§6.1.2 (doc\_subtype, surcharges, card-currency amounts), UC-07 |

## 11.5 Blocked requirements

Requirements whose acceptance test cannot run until an open decision closes. The behaviour is specified; development may proceed against it.

|  |  |
| --- | --- |
| **Requirement** | **Blocked by** |
| FR-EXT-004 â€” positional PDF text extraction | ADR-011 (library selection) |
| FR-EXT-005 â€” render + OCR fallback | ADR-010 (engine selection) |
| FR-EXT-015 â€” photo-route recognition quality | ADR-010 (engine selection + corpus extension) |
| NFR-SIZ-001 â€” application size contribution of the PDF library | ADR-011 |
| UC-14 â€” scanned-PDF route (quality) | ADR-010 |

# 12. Open items and risks

Inherited from PDR Â§14 and ADR Â§3.1, plus what surfaced while specifying.

|  |  |  |
| --- | --- | --- |
| **Item** | **Status / closure criterion** | **Source** |
| Recognition engine for the photo route | Open (ADR-010). Closes only with the ADR-019 pipeline fixes in place plus a photographed-paper corpus of ~15 documents covering thermal hospitality and fuel receipts and at least one scanned PDF. Measured as per-field accuracy after validation, counting only `read` / `from_xml` values. Extended further if candidates tie. | ADR Â§3 |
| PDF text-extraction library | Proposed (ADR-011). Closes with confirmation of the proposal verified against the positional-extraction criterion over the sample-invoice corpus, plus a size check. | ADR Â§3 |
| Acceptance thresholds for product metrics | Deferred until the first corpus screening (Â§10.5). | PDR Â§12 |
| Attachment-upload limits | Closed for the basic case. Still open: maximum file size; multi-page PDF behaviour near that limit; a choice field written with text outside its option list; real upload timings from the primary market. | PDR Â§14, ADR-004 |
| Choice field with text outside its options | Unverified in every test so far. FR-DST-007 offers only existing options, which contains the risk; the residual case is documented as open. | ADR Â§3.1 |
| Private-cloud host | The technical spike behind ADR-004's open items should be re-run or sanity-checked against a private-cloud instance before FR-DST-008 is considered fully closed for that segment. | ADR-017 |
| Name availability | "Paperdrop" to be checked in both app stores and at the EUIPO register before anything is filed. | PDR Â§14 |
| iOS Share Extension native work | Budgeted as native work, not discovered late (ADR-001). A bridge to Vision / VisionKit may be required; its cost is a FASE-3 estimate, not specified here. | ADR-001 |
| Deep link is not a vendor contract | The URL structure was verified but is not published as a contract; FR-SND-006 degrades to opening the database if it changes. | ADR-008 |
| Formula-field contrast has a known blind spot | It does not catch a total misread and then used to derive its own components; only the read-before-derive rule does. Documented in the UI (FR-DST-005). | PDR Â§7.4 |
| Corpus skew | The 16-document test skewed to B2B invoices; the corpus keeps both halves equal and the first-run flow does not assume a receipt. | PDR Â§2 |
| Operating risk carried from the test harness | `NINOX_DB_ID` in the test environment pointed at a production database. Project operating rule: never use it; the test base is always specified explicitly. | Test operating rules |


# Annex A â€” Ninox API external contract

The verified behaviour of the Ninox classic REST interface, as the binding external reference for this specification. These rules were confirmed by an earlier Nortex automation project with a full request and response trace, and by the 16-document end-to-end test against a disposable table (team `qCq3JS7q7ptoap8Yg`, database `db0000000000`). The application is isolated behind a port (ADR-003) so a second implementation can be added without touching the rest of the app.

|  |  |
| --- | --- |
| **Rule** | **Detail** |
| Payload shape | Records are written as a nested object under a `fields` key. Confirmed by trace. |
| Create response | HTTP 200 with the identifier of the new record â€” what the attachment call and the deep link both need. |
| Updates are merges | Fields not sent are preserved, so a correction sends only what changed and a failed attachment can be retried without touching the record. |
| Choice fields | Accept either the option identifier or the option text; reads always return the text. The mapping therefore offers the existing options, never free text. **Still open:** behaviour when the written text matches none of the field's options. |
| Dates | A `YYYY-MM-DD` string is stored verbatim. |
| Names versus identifiers | Payloads are keyed by field name while the schema identifies fields by stable identifier. Destinations store the identifier and resolve the current name at send time. |
| Formula and read-only fields | Writing to one returns HTTP 500. They are excluded from mapping candidates and used, where they compute a total, as a post-write check. |
| Error shape | An invalid or read-only field name returns HTTP 500, not a 4xx with an explanation. |
| Retry policy | Server errors are never retried blindly: on a 500 the client refreshes the schema once and retries once; a second failure is a mapping error. A create whose response is lost to a timeout is never retried blindly either (ADR-013). |
| Read after create | Always. Fields carrying formulas or defaults silently override submitted values, and the create response does not reveal it. |
| Attachment upload | `POST /v1/teams/{team}/databases/{db}/tables/{table}/records/{id}/files`, `multipart/form-data`, returns HTTP 200. `GET .../records/{id}/files` returns name, size and content type. Verified with a disposable record and then with sixteen real uploads, all HTTP 200. |

**Note.** Creating a record may trigger automations inside the user's Ninox database that the API does not expose. The read-after-create step is the only visibility the application has into that, and the documentation says so (FR-SND-007).

**Still open (ADR-004).** File size limit; behaviour with a multi-page PDF at the upper end of that limit; a choice field written with text that matches none of its options; real upload timings from the primary market rather than from a cloud container.

# Annex B â€” Country table

The launch content of the country table (ADR-005, FR-CTR-003). The universal core applies everywhere and does not depend on this table: amount arithmetic, date coherence, date and decimal format inference, EAN-13, and IBAN modulo 97.

## B.1 Rows

|  |  |  |  |  |  |  |
| --- | --- | --- | --- | --- | --- | --- |
| **Country** | **Currency** | **Tax ID formats** | **Legal rates (bp)** | **Slots** | **Date format** | **Cash rounding** |
| DE Germany | EUR | `DE_USTID`, `DE_STNR` | 1900, 700, 0 | 3 | `DD.MM.YYYY` | none |
| AT Austria | EUR | `AT_UID` | 2000, 1300, 1000, 0 | 4 | `DD.MM.YYYY` | none |
| CH Switzerland | CHF | `CH_UID` | 810, 380, 260, 0 | 4 | `DD.MM.YYYY` | 5-Rappen |
| ES Spain | EUR | `ES_NIF`, `ES_NIE`, `ES_CIF` | 2100, 1000, 400, 0 | 4 | `DD/MM/YYYY` | none |

**Slot count rule.** The number of slots equals the cardinality of the country's legal rate set, including the 0 rate where exempt lines are printed. Slots that do not apply stay empty; each slot maps independently and all are optional (FR-VAL-011).

**Swiss rounding.** Cash payments in CHF round to the nearest 5 Rappen. The printed rounding adjustment is captured into `rounding_minor` and used in the exact identity `net + tax + rounding = gross`; it is never recomputed (FR-CTR-007).

**Reverse charge.** Common on intra-EU B2B invoices in DE; recognised by the country row and by tax lines printed at 0 with a reverse-charge notice. Not an error (Â§6.1.2, UC-06).

## B.2 Identifier formats and check digits

|  |  |  |
| --- | --- | --- |
| **Type** | **Format** | **Check digit** |
| EAN-13 *(universal)* | 13 digits | Weighted sum over the twelve digits with alternating weights 1 and 3 beginning with 1; the check digit makes the total a multiple of 10. Medium strength. |
| IBAN *(universal)* | 2 letters + 2 check digits + up to 30 alphanumerics; length fixed per country, at most 34 | Modulo 97: move the first four characters to the end, convert letters to 10â€“35, compute the remainder; valid if it is 1. Medium strength. |
| `DE_USTID` | `DE` + 9 digits | ISO 7064 mod-97-10 as implemented for German VAT identifiers. Medium strength. |
| `DE_STNR` | Varies by issuing tax office; no stable national format | **Explicitly not validated** â€” no reliable check digit exists. |
| `AT_UID` | `ATU` + 8 digits (`U` + 8 digits, prefixed `AT` when normalised as intra-EU VAT) | ISO 7064 mod-97-10 as published by the Austrian Ministry of Finance. Medium strength. |
| `CH_UID` | `CHE` + 9 digits, printed `CHE-nnn.nnn.nnn` | Weighted modulo-11 check over the nine digits, as published by the Swiss federal register. Medium strength. |
| `ES_NIF` | 8 digits + letter | Letter index = numeric part mod 23 over the sequence `TRWAGMYFPDXBNJZSQVHLCKE`. Medium strength. |
| `ES_NIE` | `X` / `Y` / `Z` + 7 digits + letter | Replace `X`â†’0, `Y`â†’1, `Z`â†’2, then the mod-23 letter as NIF. Separate code from NIF. Medium strength. |
| `ES_CIF` | letter + 7 digits + control | Weighted sum over the seven digits with doubling of alternating positions, digits of the products summed; control = `(10 âˆ’ sum mod 10) mod 10`; for issuing letters in `{N, P, Q, R, S, W}` the control is the corresponding letter of `JABCDEFGHI`. **A separate algorithm that never shares code with NIF or NIE.** Medium strength. |

**Acceptance.** The algorithms are stated here at reference precision; each validator is accepted only when it reproduces the standard valid and invalid test vectors for its identifier type (FR-VAL-005). The three Spanish formats run as three separate implementations (FR-CTR-004) â€” the prototype's misapplication of the NIF algorithm to a valid CIF (`A28017895`, Shop A) is the failure this rule exists to prevent.

**Normalisation.** `supplier_tax_id_raw` holds the value exactly as printed; `supplier_tax_id` is normalised â€” uppercase, no spaces, dots or hyphens, with the country prefix where the number is an intra-EU VAT identifier (`DE123456789`).

# Annex C â€” Keyword and negative-context dictionaries

Independent of the interface language (FR-CTR-006): a German user may well scan a French invoice. Seeds; to be extended as real documents demand.

**Positive labels â€” totals**

`A PAGAR` Â· `TOTAL` Â· `TOTAL A PAGAR` Â· `IMPORTE TOTAL` Â· `TOTAL FACTURA` Â· `TOTAL GENERAL` Â· `SUMA TOTAL` Â· `Zu zahlen` Â· `Gesamtbetrag` Â· `Endbetrag` Â· `Rechnungsbetrag` Â· `Total` Â· `Total TTC` Â· `Montant TTC` Â· `Total Ã  payer` Â· `Importo` Â· `Totale` Â· `Totale fattura`

**Positive labels â€” tax**

`IVA` Â· `CUOTA` Â· `Cuota IVA` Â· `VAT` Â· `MwSt.` Â· `USt.` Â· `TVA` Â· `MWST`

**Positive labels â€” base**

`BASE` Â· `Base imponible` Â· `BASE IMPONIBLE` Â· `NETO` Â· `Netto` Â· `HT` Â· `Subtotal` Â· `SUBTOTAL` Â· `Zwischensumme`

**Positive labels â€” supplier (issuer)**

`PROVEEDOR` Â· `Emisor` Â· `RazÃ³n social` Â· `RazÃ³n Social` Â· `Lieferant` Â· `Absender` Â· `Rechnungsteller` Â· `Seller` Â· `Merchant` Â· `Fornecedor` Â· `Fornitore`

**Positive labels â€” date**

`FECHA` Â· `Fecha` Â· `Fecha de factura` Â· `Date` Â· `Datum` Â· `Rechnungsdatum` Â· `Date de facture` Â· `Data`

**Positive labels â€” document number**

`FACTURA N.Âº` Â· `NÂº FACTURA` Â· `Factura` Â· `Invoice No.` Â· `Invoice` Â· `Rechnungsnummer` Â· `Rechnung Nr.` Â· `N.Âº de factura` Â· `Ticket` Â· `Recibo` Â· `Boleta`

**Negative context â€” suppressed as tax candidates**

`DCC` Â· `mark-up` Â· `markup` Â· `currency conversion` Â· `conversiÃ³n de divisa` Â· `Skonto` Â· `anticipo` Â· `advance payment` Â· `adelanto` Â· `Registro Mercantil` Â· `Tomo` Â· `Folio` Â· `HRB` Â· `Amtsgericht` Â· `Handelsregister` Â· `commission` Â· `comisiÃ³n` Â· `propina` Â· `tip` Â· `service charge` Â· `Gutschein` Â· `voucher`

**How negative context applies.** A percentage or numeric candidate found within the influence radius of a negative-context term is never bound to a tax label; where the document supports it, the amount is captured as a `surcharges[]` entry with the appropriate label instead (FR-EXT-010, BR-08).

# Annex D â€” Worked examples

The founding cases as acceptance examples, including the negative ones. Each is a runnable test of the rule it belongs to.

## D.1 â€” EAN-13 confirmed against its check digit *(medium, amber)*

A barcode is read as two candidates: `8435430627640` and `8435430627840`. The weighted sum of the first twelve digits with alternating weights 1 and 3 admits exactly one check digit, and only the first candidate satisfies it.

**Result:** `8435430627640` is accepted; the competing candidate is ruled out. Strength: consistent with a check digit â€” **amber**, not green, because a checksum detects a corrupted reading without proving the value is the one the issuer intended (a false accept is roughly 1 in 10 for EAN-13). Provenance: `read`.

**Rule exercised:** FR-VAL-005, FR-VAL-001, BR-01.

## D.2 â€” Repair to the only consistent value *(weak, amber)*

A tax identifier is read as `123456795`. The check-digit algorithm admits exactly one replacement for the final character, and it is a letter: `123456795` â†’ `12345679S`.

**Result:** the value is repaired and tagged `repaired`. Strength: weak â€” the repair is correct only if every other character was read correctly. Presented **amber**, with the repair visible to the user.

**Rule exercised:** FR-VAL-008, BR-01.

## D.3 â€” Arithmetic resolves an ambiguous total *(strong, green â€” and the negative variant)*

A retail ticket's total is read ambiguously as `19.98` or `19.99`. The document also prints a base of `16.52` and tax of `3.47`.

**Positive result:** in integer minor units, `1652 + 347 = 1999` holds exactly and `1652 + 347 = 1998` does not. The total `19.99` is confirmed by redundancy between three independently read values, so it is **green**, with the thumbnail highlighting all three regions. The sum of printed values is required to be exactly equal â€” no tolerance (BR-09); the prototype's Â±0.02 tolerance, which let `16.51 + 3.47` pass against `19.98`, is the failure this rule prevents.

**Negative variant:** if the base and tax had been *computed backwards* from a misread total by assuming a 21% rate, the identity would hold by construction and prove nothing. That case is D.5.

**Rule exercised:** FR-VAL-006, FR-VAL-002, BR-09, BR-02.

## D.4 â€” A DCC mark-up read as VAT *(negative test)*

A card charge abroad prints a currency-conversion mark-up of 4.5%. A pipeline without the negative-context dictionary reads it as a tax rate, derives a base from the total at 4.5%, and writes a breakdown that never existed on the document â€” exactly the failure the 16-document test produced (record 1428).

**Required result:** the 4.5% candidate is suppressed by the negative-context dictionary (`DCC`, `mark-up`, `conversiÃ³n de divisa`) and, independently, rejected by the legal-rate check (4.5% is not a legal rate in any launch country). The amount is captured instead as `surcharges[]` with label `dcc_markup`, together with the document-currency and card-currency amounts and the exchange rate. The written record contains **no tax line at 4.5%**.

**Rule exercised:** FR-EXT-008, FR-EXT-009, FR-EXT-010, FR-VAL-007, BR-07, BR-08.

## D.5 â€” The derived-base tautology *(negative test)*

A document prints a total of `19.98` and no rate. A pipeline derives `base = 19.98 Ã· 1.21 = 16.51` and `tax = 19.98 âˆ’ 16.51 = 3.47`, then evaluates `16.51 + 3.47 = 19.98`.

**Required result:** the check consumes two `derived` operands and therefore confirms nothing (BR-02). The total remains **amber**, never green. The nine "arithmetic-verified" records of the 16-document test that had derived the base from the gross total are exactly this case: the arithmetic agreed with itself on a wrong premise, and the confirmation was worth nothing.

**Rule exercised:** FR-VAL-002, BR-02, BR-05, FR-EXT-008.

# Annex E â€” Numbering and status conventions

## E.1 Requirement identifiers

|  |  |  |
| --- | --- | --- |
| **Series** | **Form** | **Content** |
| FR | `FR-<MOD>-nn` | Functional requirement. Module codes: `CAP` capture Â· `EXT` extraction Â· `VAL` validation and confidence Â· `REV` review Â· `DST` destinations and mapping Â· `WIZ` setup wizard Â· `SND` send pipeline Â· `HIS` history Â· `MEM` supplier memory Â· `CFG` configuration and data management Â· `CTR` countries and languages Â· `DUP` duplicate detection. |
| BR | `BR-nn` | Business rule â€” cross-cutting, testable, sourced. Â§5. |
| NFR | `NFR-nn` | Non-functional requirement, prefixed by concern: `PRV` privacy, `SEC` security, `PRF` performance, `OFL` offline, `ACC` accessibility, `I18N` internationalisation, `LIC` licences, `PLT` platforms, `SIZ` size. Â§8. |
| UC | `UC-nn` | Use case â€” a real end-to-end journey. Â§3. |

## E.2 Status values

|  |  |
| --- | --- |
| **Status** | **Meaning** |
| Defined | Complete, unambiguous, buildable and acceptable today against its stated criterion. |
| Blocked by ADR-XXX | Behaviour fixed and buildable; the acceptance test cannot run until the named open decision closes. Listed in Â§11.5. |
| Deferred | Deliberately out of v1, listed so it is not forgotten. |

## E.3 Requirement template

|  |  |
| --- | --- |
| **ID** | `FR-VAL-004` |
| **Requirement** | The system shall raise a value's confidence state only when every operand of the confirming identity has provenance `read` or `from_xml`. |
| **Acceptance** | Given a document whose base and tax were both derived from the total, when the pipeline evaluates `base + tax = total`, then no operand has provenance `read` and the total remains amber. |
| **Source** | PDR Â§6.1 Â· ADR-019 |
| **Status / priority** | Defined Â· Must |

## E.4 Use case template

|  |  |
| --- | --- |
| **ID** | `UC-11` |
| **Name** | Send a document whose create response was lost |
| **Actor** | The user |
| **Preconditions** | A reviewed document; connectivity; a working destination |
| **Main flow** | The app POSTs the create Â· the response is lost Â· the document enters `uncertain` Â· the app reads the most recent records Â· exactly one matches within the window Â· the app adopts it and continues to the attachment step |
| **Alternative flows** | No match â†’ the record is created. Ambiguous â†’ the app surfaces the uncertainty and the user chooses. |
| **Postconditions** | Exactly one record exists; no blind duplicate; the document reaches `sent` |
| **Source** | ADR-013 Â· PDR Â§9.1 |

## E.5 How to add a requirement after this version

1. It must carry a source â€” a PDR section, an ADR, a finding or test evidence. No orphan requirements.
2. It must pass the technical contract of Annex A / Â§2.4. That contract is the review filter.
3. It must state an acceptance condition, or it is an intention and is not admitted.
4. It must be entered into the traceability matrix of Â§11 on the day it is added, not later.


