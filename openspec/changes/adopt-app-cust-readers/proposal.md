# Proposal: adopt-app-cust-readers

## Why

Measured on 2026-10-19 over the 19 private photographs (Core on `main`, four passes): the photo route
reads a total in 5 of 19, a date in about half, and the country is undetected in 15 of 19. Three fixes
aimed at symptoms (amount tokens, lone totals, trace) did not change that. The PO's own prototype
(`C:\Users\admin\proyectos\Paperdrop_App_Cust`, local, no remote) reads Spanish receipts well on real
phones with two readers: a labelled reader (`receipt.dart`, table pass then label-to-value) and a
vocabulary-free arithmetic reader (`receipt_arithmetic.dart`), fed by rows rebuilt from ML Kit
bounding boxes (`ocr.dart`). Its tests are synthetic.

## What changes (PO decisions of 2026-10-19)

1. **Port the three readers into Core as the photo route's reader**, logic unchanged. `DECOUPLING.md`
   of the App Cust says nothing is copied without a decision; this is that decision.
2. **Parametrise by country row**, not by hard-coded Spain: decimal convention, date order and
   separator, legal VAT rates, currency and label vocabulary come from `CountryRow`. Spain must stay
   byte-for-byte equivalent to the prototype on its tests.
3. **The country is an input, not a detection.** A default country lives in settings (first value from
   the phone's region), shows on the review screen for each ticket and can be changed there. Currency
   follows from the country row. Detection from evidence (`detectCountry`) stops deciding the photo
   route. This diverges from the Funcional (country detection) and needs a DEC entry.
4. **Two reads:** a first read automatically; a second, on the user's request ("re-read to refine"),
   that runs the other reader / more passes. The prototype's *Relectura* toggle is the model.
5. Scope: **photo route only.** The PDF text route and the Ninox layers are not touched.

## Out of scope

Supplier name from an unlabelled header (still open); iOS; any write to Ninox.

## Constraints

Nothing from the App Cust enters the repository except the three reader files and tests with
**synthetic** data (the prototype's tests use `B12345678`, `12345679S`, "EJEMPLO S.L."; check each
before copying). No `config.dart`, no destinations, no tokens, no company names (AGENTS.md §1.2, §6).
