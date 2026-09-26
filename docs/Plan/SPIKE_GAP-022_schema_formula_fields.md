# SPIKE — GAP-022: can a formula field be told apart from a writable one?

**Date:** 2026-09-25
**Related requirements:** FR-DST-004, FR-WIZ-004 (hide formula and read-only fields in the mapping)
**Registers:** closes GAP-022; adds evidence to GAP-023

## 1. Provenance of this spike

**Destination used, stated explicitly and never taken from the environment:**

| | |
| --- | --- |
| Host | `api.ninox.com` (configuration; not compiled in) |
| Team | `qCq3JS7q7ptoap8Yg` |
| Database | `db0000000000` |
| Table | `YB` ("Tarjetas Banco") |

`NINOX_DB_ID` was **not** consulted. The two environment variables that do exist
in this session (`NINOX_DBFAWALT_ID`, `NINOX_TEAMFAWALT_ID`) were read only by
`check_credentials.py`'s informational report and were never used to choose a
target.

**Only GET requests were issued.** No `POST`, `PUT`, `PATCH` or `DELETE`, and no
`POST /query`. The token was read from `NINOX_API_KEY` (user-level registry
variable, `HKCU\Environment`) and was never printed, written to a file or passed
as a command-line argument. It was verified **by its effect**: `GET /v1/teams`
answered `200`. Raw JSON responses are stored outside the repository, in
`C:\Users\admin\proyectos\Paperdrop_corpus\spike_gap022\`.

**Prior claim being tested.** `references/rest-api.md` states that a field object
carries only `id`, `name`, `type` (plus `choices` and the relation keys), and
concludes that the schema carries no formula marker. That claim was measured
against `GET .../tables` and it is **true for that endpoint**. It is **false for
the two endpoints this spike was asked about**, and the reason is that they do not
return the same objects at all.

## 2. Results per endpoint

All four calls answered `200`.

| # | Request (no token) | HTTP | Top-level keys | Where field definitions live |
| --- | --- | --- | --- | --- |
| A1 | `GET /v1/teams/qCq3JS7q7ptoap8Yg/databases/db0000000000` | `200` | `schema`, `settings` | `schema.types[*].fields` |
| A2 | `GET /v1/teams/qCq3JS7q7ptoap8Yg/databases/db0000000000/schema` | `200` | `afterOpenBehavior`, `compatibility`, `dateFix`, `fileSync`, `hideCalendar`, `hideDatabase`, `hideNavigation`, `hideSearch`, `knownDatabases`, `nextTypeId`, `seq`, `serverSideReadableIf`, `types`, `version` | `types[*].fields` |
| A3 | `GET /v1/teams/qCq3JS7q7ptoap8Yg/databases/db0000000000/tables` | `200` | *(an array of 97 elements)* | `[*].fields` (an array) |
| A4 | `GET /v1/teams/qCq3JS7q7ptoap8Yg/databases/db0000000000/tables/YB` | `200` | `fields`, `id`, `name` | `fields` (an array) |

Two structural findings that matter for the implementation:

- **A1 is A2 plus settings.** `db.json["schema"] == schema.json` compared equal,
  byte for byte after parsing. The database endpoint adds only `settings`, and
  `settings.lock` is `false`.
- **`/tables` and `/schema` do not describe the same set of fields.** A3 reports
  **1,416** fields across 97 tables; A2 reports **2,143** fields across the same 97
  tables. A4 reports 9 fields for `YB`; A2 reports 11.

### The complete set of keys on a field object, per endpoint

Measured over the whole database — 2,143 fields in A2, 1,416 in A3.

| Endpoint | Keys a field object can carry |
| --- | --- |
| **A2 `/schema`** (and A1, identical) | **Always:** `base`, `caption`, `captions`, `formWidth`, `order`, `tooltips`, `uuid`. **Sometimes:** `afterUpdate`, `booleanDefault`, `booleanRenderer`, `canWrite`, `cascade`, `choiceDefault`, `choiceRenderer`, `dateCalendar`, `dateCalendarColor`, `dateCalendarFormat`, `dateDefault`, `dateYearly`, `fieldType`, **`fn`**, `globalSearch`, `hasIndex`, `height`, `htmlDefault`, `labelPosition`, `linkPreview`, `multiDefault`, `multiRenderer`, `nextChoiceId`, `numberDefault`, `numberFormat`, `numberMax`, `numberMin`, `readRoles`, `refFieldId`, `refTypeId`, `referenceFormat`, `referenceRenderer`, `required`, `reverseRenderer`, `stringAutocorrect`, `stringDefault`, `stringMaxLength`, `stringMinLength`, `stringMultiline`, `style`, `timeintervalFormat`, `values`, `viewConfig`, `visibility`, `width`, `writeRoles` |
| **A3 `/tables`** | `id`, `name`, `type`, plus `choices` (choice/multi) and `referenceToTable`/`reverseField`/`referenceFromTable`/`referenceFromField` (relations). No other key appeared. |
| **A4 `/tables/YB`** | Identical in shape to A3; its `fields` array is exactly the one A3 returns for `YB`. |

Note the vocabulary shift: `/schema` calls the display name **`caption`** and the
kind **`base`**, where `/tables` calls them `name` and `type`. The
`referenceToTable`/`reverseField` pair in A3 corresponds to `refTypeId`/`refFieldId`
in A2, and `choices` in A3 corresponds to `values` in A2.

## 3. Verdict on GAP-022

**SE PUEDE distinguir.** There is an exact marker.

**The rule: a field object in `GET .../schema` (or `.../databases/{db}`) is a
formula field if and only if it carries the key `fn`.**

Equivalently and identically: `base == "fn"`. The two formulations select the
**same 727 fields**, with no field in either difference set.

Coverage, measured over the whole database:

| Measure | Count |
| --- | --- |
| Fields where the rule is decidable | 2,143 / 2,143 |
| Formula fields (carry `fn`, `base == "fn"`) | 727 |
| Non-formula fields (no `fn`) | 1,416 |
| `base == "fn"` but no `fn` key | 0 |
| `fn` key but `base != "fn"` | 0 |
| Exceptions to the rule | **0** |

**Independent cross-check, and this is the strong part.** The classic `/tables`
endpoint and `/schema` were compared field by field across all 97 tables:

- `/tables` returns 1,416 fields; `/schema` returns 2,143.
- The 727 fields `/schema` has and `/tables` does not are **exactly** the 727 that
  carry `fn`. Set equality held per table, not merely in aggregate.
- Of the 1,416 fields `/tables` does return, **0** carry `fn`.

So two structurally unrelated signals agree with no exceptions: the positive
marker (`fn` is present) and the negative one (`/tables` omits the field
altogether).

Table `YB`, the reference table, in full:

| Field | `base` | Rule says | Present in `/tables`? |
| --- | --- | --- | --- |
| `Bancos` | `ref` | writable | yes |
| `Tarjeta Bancaria` | `ref` | writable | yes |
| `Fecha` | `date` | writable | yes |
| `Importe` | `number` | writable | yes |
| `Código Presupuestario` | `ref` | writable | yes |
| `Expediente` | `ref` | writable | yes |
| `Tipo` | `choice` | writable | yes |
| `Tesorería` | `ref` | writable | yes |
| `Importe IVA deducible` | `number` | writable | yes |
| **`Importe total`** | `fn` | **formula** | **no — omitted** |
| **`Año`** | `fn` | **formula** | **no — omitted** |

The product owner's own account of the table — two formula fields, `Importe total`
and `Año`, everything else writable — matches this column exactly, 2 of 2 and 0
false positives. That is the one table in this database where the rule has been
checked against a human rather than against the server's other view of itself.

### JSON fragments, trimmed to their keys

One formula field — `Importe total`. Its `fn` is `"(D+J)"`, which is the base plus
the VAT the product owner described:

```json
{
  "base": "fn",
  "caption": "Importe total",
  "fn": "(D+J)",
  "order": 11,
  "required": true,
  "uuid": "<redacted>"
}
```

One writable field — `Importe IVA deducible`. Same shape, no `fn`, and it is the
one field that differs from a formula only by that key:

```json
{
  "base": "number",
  "caption": "Importe IVA deducible",
  "numberFormat": "#,##0.00 €",
  "order": 6,
  "required": true,
  "uuid": "<redacted>"
}
```

### What the rule does *not* give you

There is **no field-level read-only marker.** The keys that look like one are not:

- `canWrite` (46 fields) holds a **Ninox expression** — a condition such as
  `"((I2 = null) and (W1 = null))"` — not a boolean. It means "editable when",
  which is a different question from "is this field computed". No `canWrite` field
  carries `fn`, and no `fn` field carries `canWrite`.
- `readRoles` (4 fields) and `writeRoles` (5 fields) are **role grants**, not
  formula markers, and none of them carries `fn`.
- `afterUpdate` (25 fields) is a **write trigger** on an otherwise writable field.
  None carries `fn`.

So `fn` answers the formula half of FR-DST-004/FR-WIZ-004 exactly. The
"read-only" half is **not** answered by any mark in this schema; the closest thing
that exists is the expression-valued `canWrite`, which is a display rule rather
than a storage property.

### Consequence for the mapping design

`/tables` cannot be used to build the mapping picker. It **silently omits** the
formula fields rather than marking them — 727 of 2,143 fields in this database,
including the `YB` total the mapping is supposed to show as a computed column. A
picker built on `/tables` would not "hide" the formula fields; it would never know
they exist. The picker must read `GET .../schema` (or the database endpoint, which
contains the same object) and filter on `fn`.

## 4. Password and schema encryption

**The database is not password-protected, and the schema arrived in plaintext.**
`settings.lock` is `false`, and `schema.json` parsed as ordinary JSON with readable
captions. So the documented "the schema may be encrypted if the database has a
password" case did **not** arise here, and nothing in this spike is explained away
by an encrypted payload.

That case remains genuinely untested: whether an encrypted schema is undecryptable
or merely opaque to the client has not been observed. It is not evidence that the
endpoint returns nothing.

## 5. Part B — GAP-023, query parameters on the records endpoint

`GET /v1/teams/qCq3JS7q7ptoap8Yg/databases/db0000000000/tables/YB/records`, one
parameter set per call. Only counts and the `sequence` field were retained; no
record content was copied.

| Parameters | HTTP | Records returned | Paged? |
| --- | --- | --- | --- |
| *(none — baseline)* | `200` | **100** | — (this is the default page) |
| `?perPage=2` | `200` | **2** | **yes** |
| `?page=0&perPage=2` | `200` | **2** | **yes** |
| `?order=_id&desc=true&perPage=2` | `200` | **2** | **yes** |
| `?sinceSq=89886` | `200` | **100** | **no — ignored** |

No parameter produced a `500` or any `4xx`; every call answered `200`.

**`perPage` corrected the skill's earlier negative result.** The skill recorded
that `?limit=2` and `?pageSize=2` are accepted and ignored, and concluded that no
paging exists. `perPage` and `page` do work, and the baseline call was itself
paged — the unparameterised response is capped at 100 records, not the whole
table. Additional probes confirm the parameters are real rather than coincidental:

| Parameters | HTTP | Records returned | Reading |
| --- | --- | --- | --- |
| `?perPage=200` | `200` | 200 | `perPage` is honoured above the default |
| `?perPage=1000` | `200` | 1000 | still honoured; the table holds more than 1,000 records |
| `?page=50&perPage=2` | `200` | 2 | a **different** pair than `page=0`, so `page` is an offset, not a no-op |

Implications worth carrying into the design:

- **`?limit=` and `?pageSize=` are ignored, but `?perPage=` is not.** Two of the
  three names are wrong; the third is right. A client must not generalise from the
  two that failed.
- **The default page size is 100.** Any code that treats an unparameterised
  `records` call as "the whole table" is wrong on any table with more than 100
  rows — which includes this test table.
- **Ordering is not by `sequence`.** In the baseline response the last record's
  `sequence` (89589) was lower than the penultimate record's (89886), so the
  default order is not sequence-ascending. Any "most recent N" logic must supply
  its own `order`, and `sequence` is absent on some records entirely.
- `sinceSq` returned the full default page, so it neither filtered nor errored. It
  is unverified rather than proven absent: the value used was the penultimate
  record's `sequence`, and if that parameter expects a different coordinate or
  ordering, this probe would not have exercised it correctly.

## 6. What has not been verified

1. **One table and one database.** The 727/727 coverage is measured over
   `db0000000000` only — 97 tables, 2,143 fields, one team. A different workspace
   could use a field shape this spike never saw. Read `fn` as a strong signal, not
   as a vendor contract.
2. **The reference truth is one table deep, and it now agrees with the rule.** The
   product owner confirmed that `YB` has exactly **two** formula fields — `Importe
   total` (`fn = "(D+J)"`) and `Año` (`fn = "year(C)"`) — and that every other
   field in the table is writable. An earlier answer of "only `Importe total`" was
   corrected by the product owner, not adjusted here.

   Verified against that truth, the rule scores **precision 2/2 and recall 2/2 on
   `YB`**, with no false positive and no false negative. The intermediate
   contradiction was recorded as data and left standing until the human resolved
   it; neither the payload nor the stated truth was edited to make the other fit.

   This is still one table. The whole-database figure in §3 rests on the
   `/schema`-versus-`/tables` cross-check, which compares two server-side views and
   needs no human judgement — but no second table has been confirmed field by
   field against a human's own account of which fields are formulas.
3. **`fn` with an empty string.** Exactly one of the 727 formula fields carries
   `fn` as an empty string. Its meaning is unknown: an emptied formula, or a field
   whose formula was cleared but whose kind was not converted. A client filtering
   on the presence of the key will treat it as a formula; that may or may not be
   right.
4. **Read-only fields.** As set out in §3, no read-only marker was found at all.
   Whether read-only is expressible in this schema through a mechanism this sweep
   did not recognise is open, so the read-only half of FR-DST-004 and FR-WIZ-004
   is **not** satisfied by this finding.
5. **Encrypted schemas.** Untested — this database has no password (§4).
6. **Stability of `/schema` and `/databases/{db}`.** Both returned large, internal
   payloads (`db.json` is ~1.5 MB) that look like the workspace's own
   serialisation rather than a designed public contract — `nextFieldId`,
   `nextTypeId`, `uuid`, `seq` and editor state such as `viewConfig` and
   `tooltips` are all present. The vendor may change this shape without notice.
   The port must isolate it, and the mapping must degrade rather than break if
   `fn` disappears.
7. **Whether `perPage`/`page` are a contract.** They behaved correctly across five
   probes, but they are not documented in the skill, and the skill's own negative
   result shows how easily a plausible-looking parameter can be a silent no-op.
   Bound the result set locally as well, and never treat a count as the table's
   size without controlling `perPage`.
