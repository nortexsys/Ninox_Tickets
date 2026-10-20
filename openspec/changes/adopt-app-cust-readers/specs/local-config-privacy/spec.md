## MODIFIED Requirements

### Requirement: configuration-export-and-import

Configuration — destinations, mappings, supplier memory and the default country — SHALL be exportable to and importable from a file the user keeps wherever they like, and the API token SHALL never be included in the export. The default country SHALL travel in that file, so that a restored device keeps the country the user was working in rather than taking that device's region again; it is one value, the default of the settings, and never the country a ticket was changed to for one ticket (`countries-languages` · `country-is-an-input`). Reaching the file and leaving it SHALL change nothing else about the value: it is neither read from the device's region on import nor reset by it, and the export file is the only carrier of it beyond the device.
[Origen: Funcional §4.10 FR-CFG-001; Funcional §8 NFR-PRV-004; ADR-009; PDR §3.2, §11; DEC-022]

The default country is added to what the file carries by the product owner's decision of 2026-10-20 (GAP-039, item (1)). The other two questions that gap records are **not** decided and this requirement does not answer them: whether the clearing action returns the default country to the phone's region (`local-data-clearing`, which promises the first-run state), and whether the first-run wizard offers it as a step (`setup-wizard` · `five-screens-at-most`, `steps-auto-omit-when-there-is-nothing-to-choose`).

#### Scenario: the export carries the three things and no credential

- GIVEN a configured app
- WHEN an export is produced
- THEN it contains the destinations, the mappings and the supplier memory
- AND it contains no credential of any kind

#### Scenario: importing on another device restores all three

- GIVEN an export file
- WHEN it is imported on a second device
- THEN destinations, mappings and supplier memory are all restored there

#### Scenario: the user chooses where the file lives

- GIVEN the export action
- WHEN the file is written
- THEN its location is the user's choice
- AND the app does not confine it to a location of its own

#### Scenario: the default country travels with the configuration

- GIVEN an app whose default country in the settings is Germany
- WHEN an export is produced and imported on another device whose region is Spain
- THEN the file carries the default country
- AND that device's default country is Germany
- AND the region of that device did not replace it

#### Scenario: a country changed for one ticket is not what the file carries

- GIVEN a default country of Germany in the settings
- AND a ticket whose country the user changed to Spain, for that ticket alone
- WHEN an export is produced
- THEN the country it carries is Germany, the default of the settings
- AND Spain is not carried as the default by that ticket's change

---

## Out of Scope

- **The country table, the default country and what a row supplies.**
  `countries-languages` owns them (`country-is-an-input`); this capability owns only
  whether that value travels in the configuration file.
- **What the clearing action does to the default country.** Not decided (GAP-039,
  item (2)); `local-data-clearing` is left exactly as it stands.
- **Whether the first-run wizard offers the country as a step.** Not decided
  (GAP-039, item (3)); `setup-wizard` is not touched here.
- **The token.** `token-storage-in-the-platform-keystore` and `device-migration` keep
  the rule that it is re-entered and never carried, and the default country's
  presence in the file changes nothing about that.

---

## Cross-Capability References

- `countries-languages` — owns the default country as a setting and the row a country
  resolves to (`country-is-an-input`); this requirement only carries that default
  through the configuration file.
- `review-screen` — shows the country in force per ticket and owns the change that
  applies to one ticket only (`country-shown-and-editable-per-ticket`), which is why
  the file carries the default and never a ticket's override.

---

## Open Questions

- **GAP-039, items (2) and (3) — open, non-blocking.** Item (1) is settled above (PO,
  2026-10-20): the default country travels in the configuration export/import file.
  Still undecided: whether the clearing action returns the default country to the
  phone's region — if the answer is no, `local-data-clearing`'s promise of the
  first-run state is not true as written and it will have to be amended — and whether
  the first-run wizard offers the country as a step.
