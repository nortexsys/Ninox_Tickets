# Scenario coverage

Spec scenarios: 304 · test names read: 4 · orphan tags: 0

## Orphan tags
None

## capture-intake

- Scenarios: 18
- Covered: 0
- Uncovered: 18

Uncovered scenarios:
- `one-entry-point-four-paths`: every path lands on the same screen
- `platform-document-scanner`: the platform crops and deskews the capture
- `platform-document-scanner`: the app carries no pre-processing of its own
- `multi-page-is-one-expense`: a two-page receipt is one record
- `camera-captures-are-assembled`: one captured page becomes a PDF
- `camera-captures-are-assembled`: several captured pages become one PDF
- `received-files-are-attached-byte-for-byte`: the attachment is the input
- `received-files-are-attached-byte-for-byte`: an embedded e-invoice XML survives
- `received-files-are-attached-byte-for-byte`: reading never writes
- `mail-containers-ingest-attachments-only`: a container with a document produces a record
- `mail-containers-ingest-attachments-only`: a container with no document attachment produces nothing
- `attachment-selection-rule`: an invoice and a signature image
- `attachment-selection-rule`: two plausible candidates
- `attachment-selection-rule`: the signature image is never treated as a document
- `ios-share-hands-the-document-to-the-app`: sharing on iOS lands on review
- `ios-share-hands-the-document-to-the-app`: the extension stays inside its memory ceiling
- `capture-without-connectivity`: a document is captured and saved in aeroplane mode
- `capture-without-connectivity`: the offline save is queued, not lost

## countries-languages

- Scenarios: 24
- Covered: 0
- Uncovered: 24

Uncovered scenarios:
- `deterministic-country-detection`: a German invoice needs no user action
- `deterministic-country-detection`: a Spanish ticket is detected from its identifier
- `universal-core`: a country with no row still gets the core checks
- `universal-core`: the EAN-13 check digit
- `universal-core`: the IBAN check
- `country-table-contract`: adding a country touches almost nothing
- `country-table-contract`: the slot count follows the rate set
- `launch-rows`: the German row applies its own rates
- `launch-rows`: the Spanish row uses a different date format
- `launch-rows`: reverse charge is not an error
- `three-spanish-formats-are-three-algorithms`: a valid CIF is not judged by the NIF algorithm
- `three-spanish-formats-are-three-algorithms`: a foreign natural person's identifier is its own type
- `format-inference`: a day greater than twelve resolves the order
- `format-inference`: grouping separates the two decimal conventions
- `interface-languages`: both interface languages are usable
- `document-dictionaries-are-separate-from-interface-language`: a foreign document is parsed regardless of the interface language
- `document-dictionaries-are-separate-from-interface-language`: the negative-context list spans the languages of the market
- `swiss-rounding-is-captured-not-recomputed`: the printed rounding line reaches the record
- `swiss-rounding-is-captured-not-recomputed`: the app never substitutes its own rounding
- `country-identifier-check-digits`: the German Steuernummer is deliberately left unchecked
- `country-identifier-check-digits`: the Swiss UID is validated by its own published weight
- `country-identifier-check-digits`: an Austrian UID
- `tax-identifier-normalisation`: a printed form and its normalised form are both kept
- `tax-identifier-normalisation`: punctuation is removed from a Spanish identifier

## destinations-mapping

- Scenarios: 22
- Covered: 0
- Uncovered: 22

Uncovered scenarios:
- `what-a-destination-is`: two destinations on the same database coexist
- `what-a-destination-is`: the host is part of the destination
- `no-default-destination-until-a-first-send`: a fresh installation has nothing pre-loaded
- `no-default-destination-until-a-first-send`: after the first send the last destination is shown
- `destinations-store-identifiers-not-names`: renaming a column does not break the destination
- `destinations-store-identifiers-not-names`: a destination stored by name fails this criterion
- `formula-and-read-only-fields-are-not-mapping-candidates`: a formula field is not offered
- `formula-and-read-only-fields-are-not-mapping-candidates`: exclusion does not depend on the field's name or type
- `formula-and-read-only-fields-are-not-mapping-candidates`: the app never provokes a 500 on a formula write
- `formula-and-read-only-fields-are-not-mapping-candidates`: an unwritable field without a marker is reported, not probed
- `formula-totals-used-as-post-write-contrast`: a mis-wired mapping is surfaced
- `formula-totals-used-as-post-write-contrast`: the documented blind spot is honoured
- `formula-totals-used-as-post-write-contrast`: the user is asked, not told
- `per-field-absent-setting`: the setting decides the written value
- `per-field-absent-setting`: two destinations yield two different values for the same document
- `per-field-absent-setting`: the default is empty
- `choice-fields-offer-the-existing-options`: the picker shows the field's own options
- `choice-fields-offer-the-existing-options`: the written value belongs to the option list
- `configurable-ninox-host`: a private-cloud customer needs no fork
- `configurable-ninox-host`: an unreachable host is reported early
- `never-write-an-unmapped-field`: no mapping means no field keys
- `never-write-an-unmapped-field`: duplicate prevention cannot rely on a marker

## document-history

- Scenarios: 17
- Covered: 0
- Uncovered: 17

Uncovered scenarios:
- `content-of-a-history-entry`: all eight items are present
- `content-of-a-history-entry`: provenance is visible locally though it is never sent
- `document-states`: an offline save is queued, not failed
- `document-states`: a lost create response is uncertain, not failed
- `document-states`: a completed send carries its record identifier
- `document-states`: no entry holds two states at once
- `correction-and-re-send`: a correction updates rather than duplicates
- `correction-and-re-send`: the correction reaches the record it came from
- `file-retention`: a confirmed send releases the local file
- `file-retention`: an unresolved item keeps its file
- `file-retention`: retention follows the state, not a timer
- `history-is-the-uncertainty-trace`: confidence survives the send with nothing mapped
- `history-is-the-uncertainty-trace`: history is not treated as disposable
- `duplicate-criteria`: the same file captured twice matches on hash
- `duplicate-criteria`: two photographs of one receipt match on their content
- `duplicate-criteria`: two documents from one supplier on one day do not match
- `duplicate-criteria`: the check is read-side and cannot use a marker field

## extraction-pipeline

- Scenarios: 40
- Covered: 0
- Uncovered: 40

Uncovered scenarios:
- `pipeline-order-is-fixed`: the seven stages appear in order
- `pipeline-order-is-fixed`: derivation never precedes reading
- `invoice-route-priority`: a hybrid e-invoice takes the XML route and stops
- `invoice-route-priority`: a plain text-layer PDF takes the text route
- `invoice-route-priority`: a scanned PDF falls through to OCR
- `invoice-route-priority`: the route taken is recorded
- `structured-xml-extraction`: a full-profile sample is read deterministically
- `structured-xml-extraction`: a low-profile sample keeps the third state
- `structured-xml-extraction`: the carrying PDF is not modified
- `positional-pdf-text-extraction`: a label on another line still binds its value
- `positional-pdf-text-extraction`: a registry volume is not bound to a total label
- `render-and-ocr-fallback`: a scanned PDF is read through the render route
- `render-and-ocr-fallback`: the source file survives rendering
- `consensus-by-majority`: three agreeing passes beat one outlier
- `consensus-by-majority`: a maximum-across-passes implementation fails
- `consensus-by-majority`: arithmetic sees only agreed operands
- `read-all-printed-quantities-before-deriving`: three printed quantities are read, none derived
- `read-all-printed-quantities-before-deriving`: two printed quantities permit one derivation by identity
- `read-all-printed-quantities-before-deriving`: one printed quantity leaves the breakdown empty
- `derive-by-identity-never-invent-a-rate`: a total with no printed rate yields no breakdown
- `derive-by-identity-never-invent-a-rate`: a derived base confers nothing
- `derive-by-identity-never-invent-a-rate`: the invented rates of the test are impossible
- `legal-rate-gate-before-derivation`: a rejected rate cannot drive a derivation
- `legal-rate-gate-before-derivation`: the gate runs before the derivation, not after
- `negative-context-suppresses-non-tax-figures`: a conversion mark-up is not a tax rate
- `negative-context-suppresses-non-tax-figures`: registry boilerplate is not a total
- `negative-context-suppresses-non-tax-figures`: the suppression covers the printed languages of the market
- `provenance-on-every-value`: every value is tagged
- `provenance-on-every-value`: provenance does not leave the device
- `provenance-on-every-value`: a derived operand cannot confirm
- `multi-page-consolidation`: totals continuing on a second page produce one model
- `currency-is-read-from-the-document`: a euro receipt is tagged EUR
- `currency-is-read-from-the-document`: a dollar invoice is not turned into euros
- `currency-is-read-from-the-document`: an unreadable currency is not defaulted
- `multilingual-label-dictionaries`: labels bind regardless of interface language
- `multilingual-label-dictionaries`: the label language does not follow the interface
- `photo-route-recognition-quality`: accuracy is measured on the right population
- `photo-route-recognition-quality`: the threshold is the one §10.5 fixes
- `dates-come-only-from-the-document`: a dated filename does not supply the date
- `dates-come-only-from-the-document`: a mail container does not supply the date

## local-config-privacy

- Scenarios: 35
- Covered: 0
- Uncovered: 35

Uncovered scenarios:
- `configuration-export-and-import`: the export carries the three things and no credential
- `configuration-export-and-import`: importing on another device restores all three
- `configuration-export-and-import`: the user chooses where the file lives
- `device-migration`: the token is re-entered rather than carried
- `device-migration`: no synchronisation service is involved
- `local-data-clearing`: everything named is emptied
- `local-data-clearing`: the app returns to first run
- `local-data-clearing`: the clearing is genuine rather than a flag
- `token-storage-in-the-platform-keystore`: the token is outside the writable data containers
- `token-storage-in-the-platform-keystore`: a backup extraction does not yield it in plaintext
- `token-storage-in-the-platform-keystore`: the token does not reach a log
- `token-storage-in-the-platform-keystore`: biometric protection is deferred, not required
- `the-precise-privacy-claim`: the listing and the in-app notice agree
- `the-precise-privacy-claim`: the caveat is disclosed rather than omitted
- `the-precise-privacy-claim`: the Data Safety form matches
- `platform-diagnostics-are-distinguished-from-document-content`: the notice distinguishes the two categories
- `platform-diagnostics-are-distinguished-from-document-content`: no document content appears in a diagnostic
- `both-local-stores-are-declared`: the notice names both
- `both-local-stores-are-declared`: neither store is left unmentioned
- `supervised-measurement-instead-of-telemetry`: a public build carries no analytics call
- `supervised-measurement-instead-of-telemetry`: the release process includes the protocol
- `time-per-document`: the metric is measured by the supervised protocol
- `time-per-document`: no invented threshold is used
- `tap-count`: a clean document takes three taps and one confirmation
- `tap-count`: a typical document costs five to six
- `tap-count`: the count is a release criterion
- `accessibility`: confidence is never conveyed by colour alone
- `accessibility`: the auditor passes the review and history screens
- `accessibility`: the read region reaches assistive technology
- `all-user-facing-strings-are-externalised`: switching the device language switches every string
- `all-user-facing-strings-are-externalised`: no string is hardcoded
- `no-agpl-component-ships`: the harness-only tool stays out of the build
- `no-agpl-component-ships`: an excluded library stays excluded
- `application-size`: the size delta is reported with the decision
- `application-size`: no library is adopted without its size measured

## ninox-send

- Scenarios: 25
- Covered: 0
- Uncovered: 25

Uncovered scenarios:
- `create-attach-read-back`: the confirmation shows stored values
- `create-attach-read-back`: a default that overrode a submitted value is visible
- `create-attach-read-back`: the three steps happen in this order
- `payload-shape`: a payload round-trips without a float
- `payload-shape`: the payload is keyed by name
- `payload-shape`: the attachment is not a field
- `attachment-upload`: the upload succeeds and is readable
- `attachment-upload`: no record is created without its document
- `the-retry-matrix`: a 500 is reported as a mapping error
- `the-retry-matrix`: a 500 is never retried forever
- `the-retry-matrix`: a timed-out create is not retried
- `the-retry-matrix`: an attachment timeout is safe to retry
- `the-retry-matrix`: an authentication failure asks for the token
- `the-retry-matrix`: a vanished destination is not retried
- `the-retry-matrix`: a failed attachment retries alone
- `reconciliation-of-an-uncertain-create`: the POST landed but the response was lost
- `reconciliation-of-an-uncertain-create`: the POST did not land
- `reconciliation-of-an-uncertain-create`: ambiguity is surfaced rather than guessed
- `reconciliation-of-an-uncertain-create`: the reconciliation does not depend on mapping
- `deep-link-back-to-the-record`: the record opens
- `deep-link-back-to-the-record`: a changed URL shape degrades instead of failing
- `automations-may-run-and-the-read-back-is-the-visibility`: the documentation carries the admission
- `automations-may-run-and-the-read-back-is-the-visibility`: the confirmation shows what was stored, not what was sent
- `updates-are-merges`: a correction leaves the rest untouched
- `updates-are-merges`: retrying an attachment changes nothing but the attachment

## product-invariants

- Scenarios: 19
- Covered: 0
- Uncovered: 19

Uncovered scenarios:
- `no-desktop-application`: only mobile builds are published
- `no-backend-and-no-account`: capture without connectivity
- `no-backend-and-no-account`: there is no account to create
- `header-level-records-only`: a document with many lines produces one record
- `never-touch-schema-or-foreign-records`: no request targets the schema
- `never-touch-schema-or-foreign-records`: a correction touches only the app's own record
- `token-is-the-only-credential`: there is no surface for a password
- `token-is-the-only-credential`: sign-in is rendered by the system browser
- `no-user-facing-reporting-or-export`: the only export is the configuration file
- `no-user-facing-reporting-or-export`: read-back after a send is not an export
- `no-multi-user-or-team-features`: the app is single-operator
- `no-cross-device-synchronisation`: two devices are independent
- `no-telemetry-in-public-builds`: a published build emits nothing to the publisher
- `never-read-message-body`: only the attachment is used
- `no-data-leaves-the-device-except-to-ninox`: reading survives the loss of the network
- `no-data-leaves-the-device-except-to-ninox`: platform diagnostics carry no document content
- `proprietary-dependencies-declared`: the README accounts for each proprietary dependency
- `money-as-integer-minor-units`: no float crosses a boundary
- `money-as-integer-minor-units`: the payload does not serialize money as a decimal

## review-screen

- Scenarios: 28
- Covered: 0
- Uncovered: 28

Uncovered scenarios:
- `destination-bar`: the bar is always visible
- `destination-bar`: the destination changes without losing the document
- `daily-destination-confirmation`: the first capture of a day requires acknowledgement
- `daily-destination-confirmation`: later captures on the same day do not
- `daily-destination-confirmation`: the exception is bounded to once a day
- `thumbnail-with-the-read-region`: a field shows where its value came from
- `thumbnail-with-the-read-region`: a confirmed total shows all of its operands
- `six-core-fields-in-fixed-order`: the order is identical everywhere
- `six-core-fields-in-fixed-order`: focus goes to what needs attention
- `six-core-fields-in-fixed-order`: a fully read document focuses the first field
- `amounts-block-collapse-rule`: a confirmed document shows one line
- `amounts-block-collapse-rule`: no breakdown to check means expanded
- `amounts-block-collapse-rule`: several slots are all visible when the check does not pass
- `amounts-block-collapse-rule`: an edit after a passing check does not re-expand the block
- `advanced-section-collapsed`: it starts closed
- `advanced-section-collapsed`: a clean document shows no advanced field by default
- `advanced-section-collapsed`: it expands on demand
- `duplicate-notice`: the notice links to what already exists
- `duplicate-notice`: proceeding anyway is allowed
- `save-button-names-the-destination`: the label names the table
- `save-button-names-the-destination`: the button stays in place
- `never-block-a-save`: an empty document can still be saved
- `never-block-a-save`: only the daily confirmation may disable the button
- `user-edits-are-authoritative`: the correction is what reaches Ninox
- `user-edits-are-authoritative`: no validation overrides the user
- `user-edits-are-authoritative`: editing does not restore a colour
- `user-edits-are-authoritative`: an edited value says so
- `discard-a-document`: discarding leaves nothing behind

## setup-wizard

- Scenarios: 20
- Covered: 0
- Uncovered: 20

Uncovered scenarios:
- `five-screens-at-most`: no sixth screen exists
- `steps-auto-omit-when-there-is-nothing-to-choose`: a single-option subscription sees two screens
- `steps-auto-omit-when-there-is-nothing-to-choose`: omission rather than a hidden step
- `token-step-via-the-system-browser`: the login is presented outside the app's process
- `token-step-via-the-system-browser`: an invalid token keeps the user on the step
- `token-step-via-the-system-browser`: a valid token also delivers the next list
- `table-listing-returns-the-schema`: one round trip per list
- `table-listing-returns-the-schema`: the picker cannot offer a formula field
- `pre-filled-proposals`: a proposal is ready to correct
- `pre-filled-proposals`: nothing plausible is shown as unmapped
- `two-stage-matching-with-a-strict-threshold`: the type filter runs before similarity
- `two-stage-matching-with-a-strict-threshold`: formula fields never reach matching
- `two-stage-matching-with-a-strict-threshold`: a German table receives its proposals
- `two-stage-matching-with-a-strict-threshold`: below the threshold the field stays unmapped
- `two-stage-matching-with-a-strict-threshold`: the failure mode is a confirmed non-suggestion
- `no-mapping-is-mandatory`: finishing with nothing mapped is possible
- `no-mapping-is-mandatory`: the consequence is stated, not implied
- `plain-language-summary-and-first-document-offer`: the summary names the mapped and the unmapped fields
- `plain-language-summary-and-first-document-offer`: the empty-record case is described
- `plain-language-summary-and-first-document-offer`: the flow ends by offering a first document

## supplier-memory

- Scenarios: 15
- Covered: 0
- Uncovered: 15

Uncovered scenarios:
- `the-memory-learns-supplier-pairs`: a corrected name is learned
- `the-memory-learns-supplier-pairs`: a typed name is learned
- `the-memory-learns-supplier-pairs`: an untouched name is not learned
- `the-memory-learns-supplier-pairs`: nothing the user did not accept enters the store
- `the-memory-learns-supplier-pairs`: the store is local and survives the send
- `indexed-only-by-identifiers-that-passed-their-check-digit`: a failing identifier neither creates nor matches
- `indexed-only-by-identifiers-that-passed-their-check-digit`: a wrong name cannot become confirmed
- `indexed-only-by-identifiers-that-passed-their-check-digit`: the safeguard is what stops the laundering
- `indexed-only-by-identifiers-that-passed-their-check-digit`: the safeguard applies a validator it does not define
- `presentation-in-review`: a recognised supplier's name is offered
- `presentation-in-review`: an unrecognised supplier offers nothing from memory
- `presentation-in-review`: the confirmation rule belongs elsewhere
- `real-deletion`: after the action nothing can be matched
- `real-deletion`: a previously recognised supplier is not offered
- `real-deletion`: the deletion is real rather than a flag

## validation-confidence

- Scenarios: 41
- Covered: 0
- Uncovered: 41

Uncovered scenarios:
- `three-confidence-strengths`: redundancy makes a total green
- `three-confidence-strengths`: a clean reading with nothing to cross against is amber
- `three-confidence-strengths`: a check digit is amber, not green
- `a-check-confirms-only-if-every-operand-was-read`: a derived breakdown leaves the total amber
- `a-check-confirms-only-if-every-operand-was-read`: the nine records of the test fail this criterion
- `a-check-confirms-only-if-every-operand-was-read`: a derived value raises nothing
- `green-is-editable-only-after-unlocking`: a locked value does not open its editor
- `green-is-editable-only-after-unlocking`: the lock is the way in
- `green-is-editable-only-after-unlocking`: amber and red need no unlocking
- `the-numeric-score-is-never-shown`: no decimal score appears on any screen
- `the-numeric-score-is-never-shown`: the score reaches Ninox only when mapped
- `check-digit-validators`: each validator is accepted against vectors
- `check-digit-validators`: the German Steuernummer is not validated
- `check-digit-validators`: the Spanish formats are three separate implementations
- `redundancy-checks-on-amounts`: printed values must be exactly equal
- `redundancy-checks-on-amounts`: no tolerance absorbs a misread total
- `redundancy-checks-on-amounts`: the single tolerance is where it is allowed to be
- `legal-tax-rate-check`: an illegal rate is rejected
- `legal-tax-rate-check`: a conversion mark-up is not a rate
- `repair-to-the-only-consistent-value`: the unique repair is applied and shown
- `repair-to-the-only-consistent-value`: two admissible repairs means no repair
- `currency-carries-its-own-confidence-state`: an unsustained currency suppresses the amounts
- `currency-carries-its-own-confidence-state`: the currency's state is its own
- `currency-carries-its-own-confidence-state`: the two mis-detections of the test are caught
- `what-never-reaches-green`: no document number is ever green
- `what-never-reaches-green`: a supplier name is confirmed only from memory
- `what-never-reaches-green`: memory confirms what a check digit admitted
- `what-never-reaches-green`: an identifier failing its check digit offers no memory match
- `tax-slots`: two printed rates occupy two slots and leave a third empty
- `tax-slots`: the tax total is a sum of printed amounts
- `absent-is-not-zero`: the destination setting decides and nothing else changes
- `absent-is-not-zero`: the default is empty, not zero
- `absent-is-not-zero`: a correct zero is not an absence
- `date-coherence-and-ambiguity`: an unambiguous date is read
- `date-coherence-and-ambiguity`: an undecidable date is flagged, not assumed
- `date-coherence-and-ambiguity`: coherence is checked
- `determinism-over-coverage`: this requirement holds when its three parts hold
- `determinism-over-coverage`: doubt is preferred to a convincing guess
- `empty-over-false`: an unsustained amount is written as nothing
- `empty-over-false`: an unprinted rate yields no breakdown
- `empty-over-false`: the empty field is the deliberate outcome
