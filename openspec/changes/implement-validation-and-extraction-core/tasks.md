# Tasks: implement-validation-and-extraction-core

Plan v0.2 M1, Core lane, W2. A task is done when its check passes, not when its files exist. Every
check is run on Flutter 3.47.5 / Dart 3.13.4, **from inside the package folder** for Dart commands:
`cd packages/paperdrop_core`, then `dart analyze --fatal-infos`, `dart format --set-exit-if-changed .`,
`dart test`; and from the repository root `python .github/scripts/core_purity.py`,
`python .github/scripts/privacy_check.py` (after `git add`), `python .github/scripts/scenario_coverage.py`.
No file of the private corpus is read, copied or paraphrased (design §1). Dispatches A–D are those of
design §8; stop a dispatch on a green commit.

## 1. Core — dispatch A: the contract first

- [x] 1.1 **`PositionedWord` and `TextPage`** (design §2), as **the first commit of the change**,
      before any layout logic: integer thousandths of a point, top-left origin, `hasTextLayer`
      derived from `words`, invariants enforced, both exported from `paperdrop_core.dart`.
      *Done when* a test builds a page with words in any order, proves `hasTextLayer` is false exactly
      when `words` is empty, proves each invariant of design §2 is rejected when broken, and the
      no-float scan still passes **unedited**. The lane reports the commit hash first.

## 2. Core — layout reasoning and consensus (T1.5)

- [x] 2.1 **Lines** (design §3): `groupIntoLines`, ignoring the order of `words`. *Done when* the same
      page in several shuffled word orders gives identical lines, a word that overlaps by less than
      half the shorter height starts a new line, and the rule's constant lives in one place.
- [x] 2.2 **Binding** (design §3): same line to the right, else the line below, never extraction
      order, nothing from above or the left, no last-resort fallback. *Done when*
      `[extraction-pipeline/positional-pdf-text-extraction]` — on the synthetic `Tomo`-shaped page the
      value below the label binds for **every** permutation of the words and the registry volume never
      does; on the second synthetic page the nearest valid amount on the label's own line wins; and a
      label with no candidate returns nothing.
- [x] 2.3 **Consensus** (design §3, FR-EXT-006). *Done when*
      `[extraction-pipeline/consensus-by-majority]` — three readings of `96.76` against one of
      `9.676,00` yield `Agreed(96.76, 3, 4)`; a two-two tie is `NoConsensus`; one pass is `Single` and
      never `Agreed`; and no code path of the package takes a maximum across passes (a test greps the
      source of `consensus/` for `max`).

## 3. Core — the amount solver (T1.6)

- [x] 3.1 **Operands and currency** (design §4 steps 1–2): `ReadOperands`, `resolveCurrency`. *Done
      when* every printed operand is collected with provenance `read` and no operand is computed in this
      step; the ISO code, the symbol and the issuer country each resolve a currency on a synthetic
      page; conflicting or absent evidence leaves the currency `Absent` and **never** the table's
      currency (`[extraction-pipeline/currency-is-read-from-the-document]`).
- [x] 3.2 **Negative context and the rate gate** (design §4 steps 3–4). *Done when*
      `[extraction-pipeline/negative-context-suppresses-non-tax-figures]` — a figure inside the radius
      is excluded from the tax, base and total roles and a surcharge-like one is captured with the
      dictionary's label, D.4 among them; `[extraction-pipeline/legal-rate-gate-before-derivation]` — an
      illegal printed rate is discarded and takes no part in any later step, and every rate the
      country table holds for ES (`CountryRow.isLegalRate`) is admitted while the neighbouring values
      (such as `22`, `9`, `5` and `30`) are not, and the same for the DE row.
- [x] 3.3 **Matching and derivation** (design §4 steps 5–6). *Done when* exactly one accepted triple is
      a read-consistent solution, none derives nothing, several leaves the roles empty, identical
      triples count once; and `[extraction-pipeline/derive-by-identity-never-invent-a-rate]` — a derived
      value is tagged `derived`, is computed only with one operand missing and a printed admitted
      rate, and without a printed rate the breakdown stays empty.

## 4. Core — confidence, repair and the honest empty (T1.7)

- [x] 4.1 **Redundancy and the one tolerance** (design §6): exact sums in minor units and
      `taxWithinTolerance`. *Done when* the inequality of design §6 appears **once** in `lib/`, a tax
      one minor unit off passes and two off fails, a sum off by one minor unit fails, and no rounding
      function exists in the public API.
- [x] 4.2 **Repair and check digits** (design §5): the validators' acceptance against their standard
      valid and invalid vectors, one test per validator, and repair to the only consistent value. *Done
      when* `123456795` repairs to `12345679S` and is `repaired`, a value with two admissible repairs is
      not repaired, `DE_STNR` and `DE_USTID` are unchecked **and raise no doubtful state**.
- [x] 4.3 **States and `finalize`** (design §5). *Done when*
      `[validation-confidence/a-check-confirms-only-if-every-operand-was-read]` — a check with a
      `derived` operand is `NonConfirmatory` and raises nothing, the same numbers all `read` go green;
      an amount with nothing to cross against is never green; `doc_number` is never green and in the
      MVP `supplier_name` is never green; the numeric score influences no state (a test mutates the
      score and compares every state); an unsustained currency suppresses every amount independently
      of the amounts' own states; `AbsentPolicy.empty` is the default, `zero` is applied only when the
      destination says so, and the three values `Absent`, `NotInXml` and `Present(0)` stay unequal.
- [x] 4.4 **Dates** (design §5). *Done when* the scenarios of
      `validation-confidence` · `date-coherence-and-ambiguity` each have a test, and an ambiguous date is
      amber and never silently resolved.

## 5. Core — acceptance

- [x] 5.1 **Annex D.1–D.5 with negative variants** (design §7). *Done when* the five files of design §7
      exist, each with its negative variant, and every figure is quoted from the Funcional's Annex D
      rather than recalled.
- [x] 5.2 **The five failed structures, synthetic** (design §7): `test/regressions/`. *Done when* each
      of the five structures of design §7 has a test whose header says which structure it reproduces
      and names no document, and `privacy_check.py` is green after `git add`.
- [x] 5.3 **Tax slots and the rest of the model** (FR-VAL-011, FR-EXT-011, FR-EXT-012). *Done when*
      one slot is produced per printed rate up to the country table's count, empty slots stay empty,
      `tax_total` is the sum of printed amounts and is **never** computed from the gross and an assumed
      rate, every value this change produces carries one of the four provenance tags, and a
      multi-page input yields one value per field.

## 6. Closing — orchestrator

- [x] 6.1 `openspec validate implement-validation-and-extraction-core --strict` and
      `openspec validate --all --strict` green; the diff of every dispatch touches `packages/paperdrop_core/`
      only; no row of `openspec/gaps-register.md` or `openspec/product-decisions.md` changed.
- [ ] 6.2 Tell Mobile the contract is merged (the adapters of `close-adr-011-pdf-text-route` and
      `implement-photo-route` fill `TextPage`) and record the unit amendment of design §2 in the daily
      status for the product owner. **Not archived** until the private runs of QA have reported numbers.
