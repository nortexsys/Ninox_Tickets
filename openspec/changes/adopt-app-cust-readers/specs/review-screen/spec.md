## ADDED Requirements

### Requirement: country-shown-and-editable-per-ticket

The review screen SHALL show the country in force for the ticket, without the user
having to ask for it, and SHALL let the user change it there without leaving the
document; the change SHALL apply to the ticket it was made on, SHALL NOT by itself
re-read the document, and SHALL NOT alter a value already produced by the read —
amounts, dates and identifiers stay as they were read, and the new country SHALL take
effect only if and when the document is read again. The change SHALL be that ticket's
alone: the default country in the settings SHALL NOT change, and the next ticket SHALL
show the default from the settings again. Where the country in force has no row in the
country table, the screen SHALL say that the country has no row and that the ticket's
fields are to be filled by hand, and SHALL present no value on the ticket as read
(`countries-languages` · `country-is-an-input`). Showing and changing the country
SHALL NOT alter the order of the six core fields.
[Origen: Funcional §4.4 FR-REV-004; Funcional §4.11 FR-CTR-001; PDR §7.2; DEC-022]

#### Scenario: the ticket shows the country it was read under

- GIVEN a ticket captured while the default country is Germany
- WHEN the review screen opens
- THEN it shows Germany as that ticket's country

#### Scenario: the country can be changed without leaving the document

- GIVEN a ticket whose country is Germany
- WHEN the user changes it to Spain
- THEN Spain is in force for that ticket
- AND the document is still under review

#### Scenario: changing the country does not rewrite what was read

- GIVEN a ticket read with Germany in force, with its amounts and dates on screen
- WHEN the user changes the country to Spain
- THEN those values are unchanged
- AND the change has not re-read the document

#### Scenario: the six core fields keep their order

- GIVEN the six core fields in their fixed order
- WHEN the country is shown on the review screen
- THEN the order of the six is unchanged
- AND the country is not presented as one of them

#### Scenario: the next ticket goes back to the default

- GIVEN the default country in the settings is Germany
- AND a ticket whose country the user changed to Spain
- WHEN the next document is captured and its review screen opens
- THEN that ticket shows Germany, the default from the settings
- AND the earlier ticket still shows Spain

#### Scenario: a country without a row is announced on the ticket

- GIVEN a ticket whose country in force has no row in the country table
- WHEN the review screen opens
- THEN it says that the country has no row and that the fields are to be filled by
  hand
- AND no value on the ticket is presented as read for that country

---

### Requirement: second-read-is-requested-and-shown-running

The review screen SHALL offer the user a second read of the document on request ("re-read to refine") and SHALL show that it is running while it runs, so that the wait is not mistaken for a block and the result is not mistaken for the first read's. When the second read finishes, the screen SHALL show the values it filled or refined, and SHALL keep every value the user edited or typed as the user's — with the user's value and its edited mark, whatever the second read returned (`user-edits-are-authoritative`). The screen SHALL allow the save while a second read runs and SHALL NOT make it a condition of saving (BR-14, `never-block-a-save`).
[Origen: Funcional §4.4 FR-REV-009; Funcional §4.4 FR-REV-010; Funcional §5 BR-14; DEC-007; DEC-024]

#### Scenario: the user asks for a second read

- GIVEN a document under review whose first read is on screen
- WHEN the user asks for a second read
- THEN the second read starts on the same document
- AND the screen shows that it is running

#### Scenario: the screen shows that the second read is running and then stops showing it

- GIVEN a second read under way
- WHEN it finishes, whether or not it filled anything
- THEN the screen no longer shows it as running
- AND the values it produced are on screen

#### Scenario: a value the user edited is not overwritten by the second read

- GIVEN a total the user typed on the review screen
- WHEN the second read returns another total
- THEN the screen still shows the user's total
- AND it is still marked as edited

#### Scenario: a value the user did not touch may be filled or refined

- GIVEN an empty field, and a date the first read produced that the user has not
  touched
- WHEN the second read returns a value for each
- THEN the screen shows what the second read produced for them

#### Scenario: a save is not held back by a second read

- GIVEN a second read running on the document under review
- WHEN the user saves
- THEN the save proceeds
- AND the second read has not become a condition of saving

---

## Out of Scope

- **The country table, the default country and what a row supplies.**
  `countries-languages` owns them (`country-is-an-input`); this screen displays the
  country in force and offers the change.
- **What a country change does to the values.** Altering a value by reading it again,
  or by an edit, is `extraction-pipeline`'s and this capability's
  `user-edits-are-authoritative`; the change of country alone alters nothing.
- **What may be shown as confirmed.** `validation-confidence` owns the confidence
  states and the lock rule this screen renders. DEC-023 — the green of a currency that
  comes from the country setting — is that capability's exception to BR-04, and this
  screen only renders the state it is given.
- **A save being blocked.** `never-block-a-save` (BR-14) still governs: a country
  change never stands between the user and a save, and neither does a second read.

---

## Cross-Capability References

- `countries-languages` — owns the country table, the default country and the row
  that follows from the country in force (`country-is-an-input`).
- `extraction-pipeline` — owns the readers and the values the country row produces
  (`photo-route-readers-take-their-formats-from-the-country-row`,
  `currency-is-read-from-the-document`) and what the second read is and may write
  (`second-read-on-the-users-request`).
- `validation-confidence` — owns the state in which the currency and every other
  value is presented, which this screen only renders. A currency that comes from the
  country setting is green there by DEC-023, the exception that decision records to
  BR-04 for that one source.

---

## Open Questions

- **Settled on 2026-10-20 (GAP-040, DEC-024).** The second read on the user's request
  is `second-read-is-requested-and-shown-running`, above: the screen offers it, shows
  that it is running, and keeps a value the user edited or typed. The read itself, and
  the rule that it may only fill an empty field or refine a value the user did not
  touch, is `extraction-pipeline` · `second-read-on-the-users-request`. A country
  change made on this screen reaches the values only when the document is read again
  (`country-shown-and-editable-per-ticket`); the requested second read specified here
  is such a read of the same document.
