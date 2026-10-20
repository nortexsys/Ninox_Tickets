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
  change never stands between the user and a save.

---

## Cross-Capability References

- `countries-languages` — owns the country table, the default country and the row
  that follows from the country in force (`country-is-an-input`).
- `extraction-pipeline` — owns the readers and the values the country row produces
  (`photo-route-readers-take-their-formats-from-the-country-row`,
  `currency-is-read-from-the-document`).
- `validation-confidence` — owns the state in which the currency and every other
  value is presented, which this screen only renders. A currency that comes from the
  country setting is green there by DEC-023, the exception that decision records to
  BR-04 for that one source.

---

## Open Questions

- **GAP-040** — the "re-read to refine" second read (proposal, item 4) is the only way
  a changed country reaches the values, and it has no requirement yet: this change
  does not specify it.
