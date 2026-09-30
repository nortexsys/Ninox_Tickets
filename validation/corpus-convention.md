# Private corpus convention

The private corpus is the ground truth for the end-to-end tests and the benchmark
measurements. It lives **outside the repository**, under:

```
C:\Users\admin\proyectos\Paperdrop_corpus\
```

Nothing in it is committed to this repository, and no document content, name or value
is reproduced here. This file only fixes the layout, the file naming and the shape of
the ground-truth JSON, so every lane reads and writes the corpus the same way.

## Folder layout

```
Paperdrop_corpus/
  inbox/            original documents exactly as received; never modified
  out/              everything derived from the originals (attachments, text, renders, parsed JSON)
  ground-truth/     one JSON per document, in the format below
  prototype/        tools/ and sql/ moved out of the repository (GAP-017)
```

`inbox/` is the source of record. A run never writes into `inbox/`. All derived output
goes under `out/` and is reproducible from `inbox/` plus the app version under test.

## File naming

- Original documents: `<doc_id>.<ext>` (for example `b2b-invoice-01.pdf`). `doc_id` is
  a short, kebab-case, content-free identifier; it never contains a person's name, tax
  identifier, plate or card number.
- Ground truth: `<doc_id>.ground-truth.json`, next to no other file in `ground-truth/`.
- Derived artifacts under `out/` are prefixed with the same `<doc_id>` and a stage
  suffix, for example `<doc_id>.text.json`, `<doc_id>.parsed.json`.

## Ground-truth JSON

One file per document. It records, per canonical-model field, the expected value as a
string **exactly** as the canonical model will hold it, where the value came from, and
whether the product owner has confirmed it.

Every field key is the exact JSON key `CanonicalDocument.toJson()` uses in
`packages/paperdrop_core/lib/src/model/canonical_document.dart` — camelCase, not
snake_case, and never a paraphrase (`grossTotal`, not `total_minor` or `total`). A
ground-truth field that the canonical model has no key for (a ground-truth-only field,
needed for scoring but not part of the model) is still allowed, but its key is prefixed
`gt_` and it is called out as ground-truth-only where it is introduced; none of the
fields below need this.

```json
{
  "doc_id": "<doc_id>",
  "fields": {
    "<field_key>": {
      "value": "<string exactly as the canonical model will hold it>",
      "provenance": "printed | derived | absent",
      "confirmed_by_po": "YYYY-MM-DD | null"
    }
  }
}
```

- `value` is always a string, even for a date, a money amount or a tax identifier, so
  there is no float or formatting ambiguity between the ground truth and the app.
- `provenance` is `printed` when the document prints the value, `derived` when the
  deterministic layer may compute it from printed values, and `absent` when the correct
  outcome is to write nothing.
- `confirmed_by_po` is the date the product owner confirmed that field, or `null` while
  it is still unconfirmed. The product owner's verdict is authoritative; nothing is
  treated as ground truth until it is confirmed.

### Synthetic example

The values below are invented for the format example and are not a real document.

```json
{
  "doc_id": "synthetic-receipt-01",
  "fields": {
    "supplierName": {
      "value": "ACME Supplies S.L.",
      "provenance": "printed",
      "confirmed_by_po": "2026-10-02"
    },
    "supplierTaxId": {
      "value": "12345679S",
      "provenance": "printed",
      "confirmed_by_po": "2026-10-02"
    },
    "docDate": {
      "value": "2026-09-30",
      "provenance": "printed",
      "confirmed_by_po": null
    },
    "grossTotal": {
      "value": "1999",
      "provenance": "printed",
      "confirmed_by_po": "2026-10-02"
    },
    "netTotal": {
      "value": "1652",
      "provenance": "derived",
      "confirmed_by_po": null
    },
    "taxTotal": {
      "value": "347",
      "provenance": "derived",
      "confirmed_by_po": null
    },
    "paymentMethod": {
      "value": "",
      "provenance": "absent",
      "confirmed_by_po": null
    }
  }
}
```

`doc_id` and `fields` are the ground-truth envelope, not canonical-model field keys, and
are unaffected by this. `supplierName`, `supplierTaxId`, `docDate`, `grossTotal`,
`netTotal`, `taxTotal` and `paymentMethod` are exactly `CanonicalDocument`'s own JSON
keys; the amounts (`grossTotal`, `netTotal`, `taxTotal`) hold the amount's minor units as
a string, per the rule above, rather than the model's nested `{"minor": ..., "currency":
...}` shape, precisely so the ground truth never repeats a currency the document convention
already fixes per test document.

`12345679S` is the synthetic tax identifier fixed by DEC-001; it is not a real person's
identifier and may appear in public material.
