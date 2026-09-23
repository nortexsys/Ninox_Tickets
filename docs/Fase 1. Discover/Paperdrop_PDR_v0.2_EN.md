**Paperdrop**

Product Design Requirements (PDR) — version 0.2

**Project:** Paperdrop for Ninox (repository: Ninox\_Tickets)

**Owner:** Nortex Systems

**Phase:** FASE 1 — functional definition

**Date:** 22 September 2026

**Status:** Draft for review. Supersedes PDR v0.1 and Funcional\_App\_NinoxTickets.md.

**Related:** Paperdrop — Architecture Decision Records (ADR), version 0.2

**Language:** Product and documentation in English, as required by the project brief.

# Change log — v0.1 → v0.2

This revision incorporates the triage of the 17 findings raised against v0.1 (see the project's internal review record) and the lessons of an end-to-end test that read, validated and wrote 16 real documents into a disposable Ninox table. Every row below cites the finding or the test evidence that motivated it. Sections not listed are unchanged.

|  |  |  |
| --- | --- | --- |
| **Ref** | **Change** | **Motivated by** |
| §5.2 | Added tax\_total as a derived, mappable field. Tax slots are unchanged and remain the source of truth. | Finding 10 — a table with a single VAT column had nowhere to map to. |
| §5.2 | Added doc\_subtype (purchase, cash\_withdrawal, fuel, toll, parking, restaurant…) and a surcharges[] group with a label (dcc\_markup, service, tip), plus gross\_total\_document\_currency / gross\_total\_card\_currency / exchange\_rate for card withdrawals abroad. | 16-document test, record 1428 — a currency-conversion mark-up read as a VAT rate. |
| §6 | Confidence model rebuilt around three explicit strengths: confirmed by redundancy, consistent with a check digit, repaired to the only consistent value. An amount with no independent breakdown to cross against is never green. | Finding 5 — 'green' had collapsed three different things into one. |
| §6 | Currency is no longer listed as mathematically confirmable. It now carries its own evidence (printed ISO code, symbol, issuer country) and its own confidence state. | Finding 3, and the test: a euro receipt was tagged USD, a dollar invoice was tagged MAD. |
| §6 | New rule: a value used in a check is only a check if every operand was read, not derived by assuming an unstated rate. Provenance (read / derived / repaired / from\_xml) travels with every value. | Test finding — 9 of 10 'arithmetic-verified' records had derived the base from the total, so the check was a tautology. |
| §7.2 | 'Three taps' restated as three taps plus one destination confirmation on the first document of the day; reconciled the 'no default destination' rule with 'pre-loaded with the last one used'. | Finding 4 — the two statements contradicted each other. |
| §9 | Retry policy on create no longer retries a timed-out POST blindly. An uncertain outcome triggers a read-side reconciliation against recent records; if inconclusive, the app asks the user instead of guessing. | Finding 1 — a blind retry after a lost response duplicates the record. |
| §10 | Switzerland added as a mandatory DACH row alongside Germany and Austria; explicit, deterministic country detection (no user setting). | Finding 13, and Ninox's installed base being concentrated in DACH. |
| §11 | Privacy claim precision: documents and images never leave the device; ML Kit sends technical diagnostics (device model, OS version, latency) to Google, not document content. Data Safety disclosure to be completed accordingly. | Finding 9, verified against Google's own ML Kit data disclosure. |
| throughout | Terminology unified on team (the classic API's own term); workspace removed. | Finding 8. |
| §4 | New explicit product rule: better to leave a field empty than to write a false number. An incomplete record gets corrected; a record with an invented number gets believed. | 16-document test — every one of its six failure patterns produced a plausible-looking wrong number, not a visible gap. |

The Architecture Decision Records referenced throughout this document (ADR-004, ADR-007, ADR-010, ADR-011, and the new ADR-013 through ADR-018) are detailed in the companion ADR v0.2 document.

# Contents

1. Purpose

2. Users and market

3. Scope of version 1

4. Product principles

5. Canonical data model

6. Confidence model

7. Screens

8. Setup wizard

9. Sending and error handling

10. Countries and languages

11. Privacy and data

12. Success metrics

13. Test corpus

14. Open items

Annex A — Technical contract

# 1. Purpose

Ninox users record business expenses by hand. They read a figure off a paper receipt or a supplier invoice, type it into a Ninox table, and then attach the file — or, more often, do not attach it at all.

Paperdrop turns that into three taps for a document that validates cleanly. The user scans a receipt or shares an invoice from their mail app; Paperdrop reads the document on the device, shows what it read, and creates one record in the user's own Ninox database with the original document attached to it.

The product is free, open source, published by Nortex Systems on Google Play and the App Store, and deliberately narrow: it puts documents into Ninox and does nothing else. Everything downstream — reporting, reconciliation, accounting — is what the user already has Ninox for.

## 1.1 What makes it different

Every receipt scanner on the market reads text. Paperdrop's distinguishing asset is the layer above that: deterministic constraints that confirm or correct a reading instead of trusting it.

The working prototype already demonstrates this. A barcode read as 8435430627640 was confirmed against its EAN-13 check digit while the competing candidate 8435430627840 was ruled out. A tax identifier read as 123456795 was corrected to 12345679S because that is the only check letter the number admits. A total read ambiguously as 19.98 or 19.99 was resolved by arithmetic: 16.52 + 3.47 = 19.99, and 19.99 / 1.21 = 16.52.

A follow-on test, run on 16 real documents against a disposable Ninox table, sharpened this claim rather than weakening it. It showed that the same arithmetic can be made to agree with itself on a wrong premise — a base and a tax amount both computed backwards from a misread total will always sum correctly, and an invented 30% tax rate will pass a check just as cleanly as a real 21% one. The conclusion is not that determinism fails; it is that determinism only proves what it is given. A check performed on read values is evidence. A check performed on derived values is a tautology. Section 6 makes this distinction the center of the confidence model, and it is why the product principle in Section 4 is to prefer an empty field over a plausible but invented one.

# 2. Users and market

The addressed user is an existing Ninox customer who records expenses in a Ninox database. Ninox is a German company and its installed base is concentrated in German-speaking Europe; the Spanish market is a small minority of it. Paperdrop is therefore designed for Europe generally, with no country treated as the reference case.

Two document journeys carry equal weight in version 1:

* Paper receipts — restaurant, taxi, fuel, parking, small purchases. Photographed with the device camera. This is where character recognition is hard and where the validation layer earns its place.
* Supplier invoices — PDFs and structured e-invoices that arrive by email, typically carrying a text layer or embedded XML. Shared into Paperdrop from the mail client. Reading is near-perfect for the e-invoice case; the difficulty for plain PDFs is layout variation between issuers.

The 16-document test run on Nortex's own inbox skewed heavily toward B2B invoices, bank slips and non-EUR documents rather than paper receipts. It is one user and 16 documents, not a market conclusion, and the product owner has decided not to reweight the two routes on that basis alone — but it is a signal worth carrying into the acceptance corpus (Section 13) and worth remembering when the setup wizard's first-run flow is designed: a professional user's first document is as likely to be an invoice as a receipt.

# 3. Scope of version 1

## 3.1 In scope

|  |  |
| --- | --- |
| **Area** | **Version 1** |
| Inputs | System document scanner (camera), device gallery and file picker, documents shared into the app from another application (Android share intent, iOS Share Extension), and mail attachments shared as .msg or .eml containers. |
| Formats | Photographs, PDFs with a text layer, scanned PDFs without a text layer, structured e-invoices (ZUGFeRD / Factur-X hybrid PDFs, XRechnung XML). Multi-page documents supported. |
| Extraction | Entirely on the device. No server, no network dependency for reading. |
| Output | One Ninox record per document, header level only, with the document attached to that record as a PDF. |
| Destination | Any team, database and table the user's API token can reach, chosen from lists the app reads from the Ninox API. |
| Countries | Universal validation everywhere, plus a country table that adds local rules where they exist. |
| Platforms | Android and iOS. Interface in English and German. |

## 3.2 Out of scope (non-goals)

These are deliberate exclusions, not omissions. Each has been considered and rejected for version 1.

* No desktop application.
* No backend service and no Paperdrop user account.
* No line-item detail; one record per document, header only.
* The app never creates, renames or deletes fields or tables in the user's Ninox database.
* The app never deletes or modifies records it did not create.
* No Ninox username or password is ever requested, stored or transmitted. The API token is the only credential.
* No reporting, reconciliation or data export beyond the configuration file — that is what Ninox is for.
* No multi-user or team features inside the app.
* No automatic synchronisation between devices; configuration moves through an exportable file.
* No telemetry in public builds.
* No reading of the .msg/.eml message body — only the document attachment it carries. Email intake is a share-out of one attachment, not a mail client.

# 4. Product principles

The original brief asked for an application that is fast, intuitive, simple and light. Five working principles translate that into decisions that can be checked.

|  |  |
| --- | --- |
| **Principle** | **What it means in practice** |
| Three taps | A document that validates cleanly is captured, reviewed and saved without the user editing anything. Every feature is measured against the tap count it adds. |
| Never block | The user can always save. Missing or unreadable fields never prevent a record from being created with the document attached. |
| Determinism over coverage | A field is presented as confirmed only when a deterministic constraint says so, and only when every operand of that constraint was itself read from the document rather than assumed. The app would rather admit doubt than guess convincingly. |
| Empty over false | When the app cannot sustain a value, it writes nothing rather than a plausible-looking number. An incomplete record costs the user a few seconds of review; a record with an invented figure travels silently into their accounts. This is not a fallback behaviour, it is the default. |
| Nothing leaves the device | No document, image or extracted value is transmitted anywhere except to the user's own Ninox workspace. Platform components used for capture may send their own operational diagnostics (Section 11); no document content is ever part of that. |

# 5. Canonical data model

Paperdrop extracts into a fixed internal model and then writes it to whatever the user's table happens to call those things. The canonical model is what the mapping maps from; it does not constrain the user's schema in any way. Every value in the model carries a provenance tag (Section 6) that is not itself written to Ninox but that governs whether the value may be shown as confirmed and whether it may be written at all.

## 5.1 Core fields

Six fields are presented in the setup wizard and on the review screen. They are the ones that make an expense record useful.

|  |  |  |
| --- | --- | --- |
| **Field** | **Type** | **Notes** |
| doc\_date | date | Issue date of the document. Never derived from a filename or a received-email timestamp. |
| supplier\_name | text | Merchant or issuer. |
| supplier\_tax\_id | text | VAT identification number where present. Normalised; see the country table (Section 10). |
| doc\_number | text | Receipt or invoice number. Never reaches green — see Section 6.2. |
| gross\_total | integer, minor units | Amount payable, taxes included. Stored as an integer in the currency's minor unit (cents), never as a float. |
| currency | text (ISO 4217) | Inferred from the document's own evidence, not defaulted to the table's currency. See Section 6. |

## 5.2 Extended fields

Available under an advanced section of the wizard and collapsed on the review screen. All optional.

|  |  |
| --- | --- |
| **Group** | **Fields** |
| Document | doc\_type, doc\_subtype (purchase, cash\_withdrawal, fuel, toll, parking, restaurant, other), doc\_time, doc\_series, control\_code |
| Supplier | supplier\_address, supplier\_city, supplier\_country |
| Amounts | net\_total, tax\_total (derived, mappable; see Section 6), discount\_total, plus one triplet of tax\_rate / tax\_base / tax\_amount per tax rate present, the number of slots defined by the country table |
| Currency & payment | gross\_total\_document\_currency, gross\_total\_card\_currency, exchange\_rate (for card charges settled in a different currency than the document, e.g. cash withdrawals abroad), payment\_method, card\_brand, card\_masked, auth\_code, iban |
| Surcharges | surcharges[] — repeatable group of { label: dcc\_markup | service\_charge | tip | rounding\_adjustment | other, amount\_minor }, so a currency-conversion mark-up or a tip is never mistaken for a tax line |
| Travel | licence\_number, vehicle\_plate, trip\_from, trip\_to, distance\_km, duration\_min |
| Metadata | confidence, needs\_review, recognition\_engine, source\_hash |

The attachment is not part of this model. In Ninox a file is attached to the record itself rather than to a field, so uploading it is an automatic step of the send pipeline and never appears in the mapping.

## 5.3 Multiple tax rates

A European receipt routinely carries several tax rates at once — a German supermarket receipt mixes 19% and 7%, a Spanish one mixes 21%, 10% and 4%. A single tax\_rate field cannot represent that, and aggregating the figures destroys exactly the breakdown an accountant needs. The 16-document test produced a live instance of this: a receipt with two printed rates and two bases collapsed into a single pair by a pipeline that had no slot for the second one.

The model therefore carries fixed slots, one triplet per rate, and the country table declares how many slots exist and which rates are legal. Slots that do not apply stay empty. Each slot is mapped independently and all of them are optional. tax\_total, where mapped, is the sum of the printed tax amounts across slots — never a value computed from the gross total and an assumed rate (Section 6).

# 6. Confidence model

Every extracted value carries a state that the review screen shows as a colour. The numeric confidence score is never displayed: a figure such as 0.72 means nothing to the user and only casts doubt on values that are probably correct. It is stored locally and written to Ninox only if the user chose to map it.

Version 0.1 treated the colour as a single scale. The 16-document test showed that was a category error: a value can be right for three structurally different reasons, and only one of them is strong enough to justify hiding the number behind a lock icon.

|  |  |  |
| --- | --- | --- |
| **Strength** | **What it actually establishes** | **Example** |
| Confirmed by redundancy | Two values that were both read independently, not derived from each other, agree through an identity. Strong: a coincidence this specific is not an accident. | base + tax = total, where base, tax and total were each read from the document |
| Consistent with a check digit | The value passes a checksum. Medium: it detects a corrupted reading, it does not prove the value is the one the issuer intended. A false accept is possible (about 1 in 10 for EAN-13 and a Spanish CIF, about 1 in 23 for the NIF check letter). | An EAN-13 that passes its checksum |
| Repaired to the only consistent value | One character was replaced by the unique value a checksum admits. Weak: correct only if every other character was read correctly. | 123456795 → 12345679S |

A value produced by any of the three is marked with its strength internally; only the first — confirmed by redundancy — is shown as green with a lock. The other two are amber: read, plausible, but asking the user to glance at them. An amount with no independent figure to cross against — a total with no printed breakdown, such as a card-terminal slip — is never green, however cleanly it was read, because there is nothing for it to be redundant with.

|  |  |
| --- | --- |
| **State** | **Meaning** |
| Green | Confirmed by redundancy between independently read values. Editable only after tapping the lock. |
| Amber | Read from the document, and either consistent with a check digit, repaired to a unique value, or simply un-cross-checked. The user is expected to glance at it. |
| Red | Not read at all, or read and rejected by a constraint. |

## 6.1 Provenance and the rule about derived values

Every value carries a provenance tag, kept internally alongside the confidence state and never written to Ninox:

|  |  |
| --- | --- |
| **Tag** | **Meaning** |
| read | Taken directly from the document's text, OCR consensus, or embedded XML. |
| derived | Computed from other read values through an identity the document itself supports — e.g. base = total − tax, when both total and tax were read. |
| repaired | One implausible character replaced by the unique value a check digit admits. |
| from\_xml | Taken from a structured e-invoice's embedded or attached XML — deterministic by construction. |

**The rule that follows directly from the test: a check that consumes a derived value confirms nothing.** If the base and the tax were both derived from the total by assuming an unstated rate, then base + tax = total is true by construction, not by agreement. The extraction pipeline must therefore attempt to read all three quantities of an amount breakdown wherever the document prints them — the approach the original prototype's solve\_amounts.py takes, matching candidate readings against each other, rather than computing two of the three from the third. Deriving one value from two others that were read is allowed and useful (base = total − tax when both are printed); deriving a value by assuming a rate the document does not state is never allowed, however plausible the rate looks. The pipeline's job when it cannot read a quantity is to leave it empty, not to reconstruct it.

## 6.2 An expectation to set honestly

Not every field can reach green, and the product should not pretend otherwise. Amounts, currency and the tax identifier can, in favourable cases, be confirmed by redundancy. The document number cannot: receipt and invoice numbers carry no check digit, and each recognition pass produces a different variant. The supplier name cannot be confirmed by arithmetic either, only by the supplier memory once the same supplier has been seen before.

A document that validates cleanly therefore costs three taps. A typical one costs five or six, because the user will glance at the document number and the supplier name. That figure belongs in the release criteria, not in a disappointed reaction to the first demonstration.

# 7. Screens

## 7.1 Capture

One entry point with four paths into it: the system document scanner, the device gallery or file picker, documents shared into Paperdrop from another application, and a mail attachment (.msg or .eml) shared the same way. Sharing a mail item shares its attachment, not the message; where a .msg carries more than one attachment (typically the document itself plus the sender's signature image), the app applies a selection rule — largest PDF or image by content, excluding common signature-image dimensions and filenames — and lets the user pick manually if more than one plausible candidate remains.

Capture uses the operating system's own document scanner rather than a raw camera view. Both platforms provide edge detection, perspective correction and contrast enhancement natively, page chaining for multi-page documents, and an interface the user already knows from their notes application. The prototype's pre-processing stage becomes unnecessary.

Multi-page documents stay one expense: several pages produce one record with one multi-page attachment, and extraction reads every page before consolidating into a single canonical model.

## 7.2 Review

The screen the user sees on every single document, and therefore the one that decides whether the application feels light or heavy. From top to bottom:

* Destination bar — full width, persistent, showing team, database and table. Tappable to change. Pre-loaded with the destination last used; on the first capture of each calendar day it is highlighted and the save button stays disabled until the user has acknowledged it once. This is the one deliberate exception to the three-tap principle, made once a day rather than once a document.
* Document thumbnail — tapping any field draws a box around the region the value was read from and zooms to it. Values produced by a redundancy check highlight the regions of every operand that fed it, which also shows the user why the app reached that number.
* The six core fields — fixed order, so the user builds muscle memory, with focus jumping automatically to the first unread field on open. Inline editing, large type, colour per confidence state.
* Amounts block — collapsed to a single confirming line when a redundancy check passes, expanded whenever it does not, including whenever an amount has no breakdown to check against at all. With several tax slots this block can hold seven figures; showing them always would produce exactly the heavy screen the product is trying to avoid.
* Advanced — collapsed, holding the remaining mapped fields, including surcharges and doc\_subtype.
* Duplicate notice — shown when the document hash, or the supplier, date and total together, match an earlier send. Links to the existing record and lets the user proceed anyway.
* Save button — fixed at the bottom and naming the outcome, for example 'Save to Expenses 2026' rather than 'Submit'.

## 7.3 Destinations

A destination is a database, a table and a field mapping. The user may hold several. There is no built-in default the first time the app is configured; once at least one send has happened, the destination bar always shows the destination used last, which is why it is displayed prominently and confirmed once a day rather than tucked into a menu.

A destination stores Ninox field identifiers, not field names, and resolves the current name at send time from a cached schema that refreshes when the app opens. Ninox record payloads are keyed by field name, so a destination stored by name would break silently the moment somebody renamed a column.

Each mapped field carries one additional, per-field setting: what to write when the source value is absent from the document — leave the Ninox field empty (the default), or write zero. This is a property of the destination field, not of the canonical model: whether 'not printed' means nothing happened or means a contractual zero is knowledge only the user has (Section 6.2 and the 16-document test's card-terminal case, where an unprinted VAT breakdown correctly means zero deductible VAT for that specific column).

## 7.4 Destinations — Ninox formula fields

A field the schema marks as a formula or as read-only is excluded from the mapping candidates shown to the user; offering it would guarantee a 500 on every send. Where the destination table happens to hold a formula field that computes a total from mapped components, the app does not write to it — but after a successful send it reads it back and compares it against the total Paperdrop extracted from the document. A mismatch does not by itself mean the extraction was wrong: it means the user's mapping and the table's formula disagree about what the total is made of, which is worth surfacing. It does not catch a total that was misread and then used to derive its own components, because the formula reproduces that same error; that failure mode is caught only by the read-before-derive rule in Section 6.1.

## 7.5 History

Every capture produces a local entry holding the thumbnail, the extracted values with their provenance, the destination, the state, the confidence, the document hash and the Ninox record identifier once sent. It is where the user finds what was sent, what is queued and what failed, and where a record can be corrected and re-sent.

History is not an optional extra. Because the app does not require the user to map the review metadata, a user who mapped nothing has no way of seeing in Ninox which records were uncertain. The local history is the only place that trace exists.

To keep the application light, local document images are deleted once a send is confirmed — the document is in Ninox by then. Only pending and failed items keep their files.

# 8. Setup wizard

Five screens at most, and three of them disappear when there is nothing to choose.

|  |  |  |
| --- | --- | --- |
| **#** | **Step** | **Behaviour** |
| 1 | Token | Instructions for obtaining a Ninox API token, a paste-from-clipboard button, and an option to open the Ninox settings page in the platform's own system browser (Custom Tabs on Android, SFSafariViewController on iOS) so the token can be copied there and pasted on return. The app never renders Ninox's own login inside a WebView it controls. Validated immediately; a successful call also returns the list for the next step. |
| 2 | Team | Chosen from the list returned by the API. Skipped automatically when there is only one. |
| 3 | Database | Same pattern. Skipped when there is only one. |
| 4 | Table | Same pattern. The table listing also returns the schema, so no additional round trip is needed. Formula and read-only fields are annotated so step 5 can exclude them. |
| 5 | Mapping | The six core fields, each shown as a pre-filled proposal rather than an empty selector. The user corrects only what is wrong. |

## 8.1 Field matching

Matching runs in two stages. A hard type filter comes first: a date is only ever proposed against a date field, an amount only against a number field, and any field the schema marks as formula or read-only is removed from consideration before matching starts. String similarity against a synonym dictionary then ranks what survives — total, amount, sum, Summe, Betrag, importe; supplier, merchant, issuer, Lieferant, proveedor; and so on per language.

The threshold is deliberately strict: below it, the field is left unmapped rather than proposed. A mediocre suggestion that the user confirms without reading is worse than a visible gap.

## 8.2 Completing the wizard

No mapping is mandatory. A user may map everything, one field, or nothing at all — in which case Paperdrop simply attaches the document to an otherwise empty record.

The wizard closes with a plain-language summary of the consequence: 'date and total will be saved; supplier, tax identifier and VAT will not', or, when nothing was mapped, 'only the document will be attached, with no data'. The freedom is total; nobody ends up with a useless configuration without having read what it does. The final screen offers to capture the first document rather than returning the user to an empty application.

# 9. Sending and error handling

A send is three steps: create the record, attach the document to it, read the record back. The read-back is not a safeguard, it is a feature. Ninox fields carrying formulas or default values silently override what was submitted, and the response to the create call does not reveal it, so the confirmation screen shows what is actually stored rather than what was sent.

## 9.1 Retry policy

Ninox reports a mistyped or read-only field name as HTTP 500 rather than a 4xx with an explanation. A client that retries server errors blindly would therefore retry a mapping mistake forever, draining battery and data while telling the user it is a server problem. Version 0.1's policy stopped there; the 16-document test and the finding that motivated it (ADR-013 in the companion document) expose a second, separate problem: a POST whose response is lost to a timeout may still have created the record, and retrying it blindly duplicates it. Neither case may be handled by blind retry.

|  |  |  |
| --- | --- | --- |
| **Condition** | **Behaviour** | **Retry** |
| No connectivity | Queued as pending; sent automatically when the connection returns. | Yes, automatic |
| Network error or timeout on POST create | Outcome is unknown, not failed. The app reconciles: it reads the destination table's most recent records and looks for a match by the mapped fields plus a short time window. If found, that record is adopted and the flow continues to the attachment step. If not found, the record is created. If the reconciliation is inconclusive, the app asks the user rather than deciding. | No blind retry — reconciliation first |
| Timeout on any other call (attachment upload, read-back) | Exponential backoff, bounded attempts. These calls are not create calls, so a retry cannot duplicate the record. | Yes, bounded |
| HTTP 401 or 403 | Marked as an authentication problem; the user is asked to re-enter the token. | No |
| HTTP 404 | The database or table no longer exists; the user is sent to the destination. | No |
| HTTP 500 | Almost always a schema change or a mapping mistake. The app refreshes the schema and retries exactly once; a second failure is reported as a mapping error. | Once only |
| Record created, attachment failed | Only the attachment is retried. Ninox updates are merges, so the record is untouched. | Yes |

## 9.2 Returning to Ninox

After a successful send the confirmation screen offers to open the record in Ninox. The link is built entirely from data the app already holds — team and database from the destination, table identifier from the destination, record identifier from the create response — and needs no additional API call and no user credentials.

This closes a requirement from the original brief without the app ever handling a Ninox username or password.

# 10. Countries and languages

Country handling is an internal structure, not a setting. The user activates nothing and chooses nothing; the app detects the document's country from its own evidence (VAT identifier format, currency, address, language) and applies that row.

A universal core applies everywhere: amount arithmetic, date coherence, format inference, EAN-13 and IBAN. A country table then adds, per country, the VAT identifier format and its check-digit algorithm, the legal tax rates, the date format, the decimal separator, and any cash-rounding rule. Adding a country means adding a row and, at most, one small check-digit function. Germany, Austria, Switzerland and Spain are the initial rows; none is the reference case, and Switzerland — non-EU, CHF, UID format CHE…, five-Rappen cash rounding — is included from the start because DACH is the primary market, not an extension of it.

|  |  |  |  |  |
| --- | --- | --- | --- | --- |
| **Country (ISO)** | **Currency** | **Tax ID formats** | **Legal tax rates** | **Notes** |
| DE | EUR | DE\_USTID (VAT), DE\_STNR (no reliable check digit — not validated) | 19%, 7%, 0% | Reverse charge common on intra-EU B2B invoices |
| AT | EUR | AT\_UID | 20%, 13%, 10%, 0% |  |
| CH | CHF | CH\_UID (format CHE-nnn.nnn.nnn) | 8.1%, 3.8%, 2.6%, 0% | Cash payments round to the nearest 5 Rappen; the printed rounding adjustment is captured, never recomputed |
| ES | EUR | ES\_NIF (natural person), ES\_NIE (foreign natural person), ES\_CIF (legal person) — three distinct check-digit algorithms | 21%, 10%, 4%, 0% | The prototype misapplied the NIF algorithm to a CIF; the three formats must never share code |

Because the universal core cannot assume anything, it has to infer format from the document: a day greater than twelve disambiguates the date order, and the thousands grouping pattern separates 1.234,56 from 1,234.56. This is a real algorithm rather than a table of constants, and it is the one genuinely new piece of work the universal layer introduces.

The interface ships in English and German. Document keyword dictionaries — including the negative-context terms in Section 6's derivation rule (DCC mark-up, Skonto, advance payment, and commercial-register boilerplate such as Registro Mercantil / Tomo / Folio / HRB / Amtsgericht) — are a separate matter from interface language and cover several languages from the start, since a German user may well scan a French invoice.

# 11. Privacy and data

No document, image or extracted value leaves the device except toward the user's own Ninox workspace. There is no backend, no analytics service and no Paperdrop account. In the core market this is not merely a technical stance, it is the product's strongest claim, and the store listing should lead with it — stated precisely.

**The precise claim:** your documents never leave your device. The platform's own document-scanner and text-recognition components (Section 7.1, ADR-006) are Google and Apple system services; Google's own disclosure for ML Kit states that it sends operational diagnostics — device model, OS version, API latency, error codes — to Google, encrypted, but does not upload the image or the recognised text. That distinction is real and worth stating exactly this way rather than as an unqualified 'nothing leaves the device', which the Play Store's Data Safety form would then contradict.

Two local stores hold data and both must be declared in the privacy notice. The supplier memory holds tax identifiers and names of third-party businesses; to prevent it from learning wrong values it is indexed only by identifiers that passed their check digit. The exportable configuration file carries destinations, mappings and that same supplier memory — it never carries the API token, which stays in the platform keystore.

The API token is stored in the Android Keystore and the iOS Keychain. Biometric protection is deferred to a later version as an optional setting.

# 12. Success metrics

Product metrics are primary; reach metrics are secondary and do not override them.

|  |  |
| --- | --- |
| **Metric** | **Definition** |
| Time per document | Median seconds from opening capture to a confirmed save. |
| Taps per document | Median number of interactions in the same interval. |
| Untouched rate | Share of documents saved without the user editing any field. |
| Green rate | Share of core fields confirmed by redundancy (Section 6) — not merely check-digit-consistent. |
| Abstention rate | Share of mapped amount fields left empty because no reading could be sustained. Tracked deliberately: a rising abstention rate is the cost of Section 4's 'empty over false' principle made visible, and is expected to be non-zero by design. |
| Reach | Installations, store rating, repository stars and external contributions, mentions in the Ninox community. |

There is no telemetry, so the product metrics are gathered by supervised measurement before each release: observed sessions with real users, plus a benchmark run over the test corpus. Acceptance thresholds are deliberately not fixed in this document. Any number written today would be invented; they will be set once the first corpus screening shows what is achievable.

# 13. Test corpus

Two routes carry equal weight, so the corpus has two halves and they are gathered differently.

|  |  |
| --- | --- |
| **Route** | **Corpus** |
| Photographed paper | Real receipts, photographed. Thermal paper, faded ink, shadows, skew. Different merchants, deliberately including difficult cases. Language is irrelevant here: this route measures paper degradation, not vocabulary. |
| PDF and e-invoices | Supplier invoices — plain PDF, and structured e-invoices (ZUGFeRD/Factur-X, XRechnung) across as many issuers, profiles and countries as possible. |

The initial screening runs on roughly fifteen photographed documents. That is enough to detect gross failure and to eliminate an unusable engine, but not enough to produce a defensible accuracy figure: with fifteen documents a single error moves the result by almost seven points. The screening is therefore treated as a filter, not as a measurement. If one engine clearly loses, the decision is made; if the candidates tie, the corpus is extended before deciding.

What is measured is per-field accuracy after the validation layer, counting only values whose provenance is read or from\_xml as eligible for the 'confirmed' tally — not raw character error rate, and not derived values dressed up as confirmations. An engine that reads worse may well tie on validated fields, because the check digits recover what the recognition lost.

**Status after the 16-document test:** the photographed-paper route was exercised by only 5 documents, and the scanned-PDF route (render + OCR, no text layer) by zero. Neither is enough to inform ADR-010, and the failures observed were traced to consensus-between-passes and PDF-parsing defects in the pipeline, not to the recognition engine itself — evidence in favour of fixing the pipeline before enlarging the corpus purely to pick an engine. The corpus is not being expanded for its own sake (product owner decision); when it is expanded specifically to close ADR-010, it should target the gaps that block that decision — a scanned-PDF sample, and photographed paper from hospitality and fuel receipts, which is where thermal degradation is worst — rather than a round number of documents.

# 14. Open items

|  |  |
| --- | --- |
| **Item** | **Status** |
| Text recognition engine for the photo route | Open. ADR-010. Cannot close on the 16-document test (5 photo documents, 0 scanned-PDF). Reopens once the pipeline fixes in ADR-018 are in place and the corpus covers a scanned PDF and more thermal-paper hospitality/fuel receipts. |
| PDF text extraction library for the invoice route | Partially confirmed. ADR-011. PDFKit / PdfBox-Android confirmed as candidates; positional (coordinate-based) extraction is now a hard acceptance criterion, not only a licence check. |
| Acceptance thresholds for the product metrics | Deferred until the first corpus screening. |
| Name availability | Paperdrop to be checked against both app stores and the EUIPO register before anything is filed. |
| Ninox API attachment upload | Closed for the basic case: verified end-to-end (create → multipart upload → GET .../files → read-back) across 16 real uploads. Still open: file size limit, multi-page PDF behaviour at scale, a choice field written with text outside its option list, and real upload timings from the primary market. |

# Annex A — Technical contract

The lines this project does not cross. Any architectural decision in FASE 2 is reviewed against them.

|  |  |
| --- | --- |
| **#** | **Constraint** |
| 1 | No backend service, in any version. |
| 2 | No user data leaves the device except toward the user's own Ninox workspace. Platform components may send their own operational diagnostics, never document content (Section 11). |
| 3 | No Ninox username or password is ever requested, stored or transmitted. The API token is the only credential, obtained through the platform's system browser, never an app-controlled WebView. |
| 4 | Determinism over coverage: a value is presented as confirmed only when a deterministic constraint establishes it from values that were themselves read, not derived by assumption. |
| 5 | Every proprietary dependency is declared in the repository README. |
| 6 | The app never writes a field the user has not explicitly mapped, and never creates, alters or deletes schema or records it did not create. |
| 7 | No telemetry in public builds. |
| 8 | A document originally received as a PDF is attached exactly as received; only camera captures are assembled into a new PDF by the app. |