# Design: implement-validation-and-extraction-core

Owner: Core lane. Written by the orchestrator on 2026-10-07. The proposal says *what* and *which
requirements*; this document says *how*, in the order the lane builds it, and states the few decisions
the proposal and the spec leave to implementation. Where a rule's behaviour is already written as a
scenario in `openspec/specs/`, this design does not restate it: the lane reads the scenario and the
test cites it. The design adds only what a scenario cannot say — file layout, data shapes, the order of
steps, and the numbers that are implementation constants rather than product thresholds.

## 1. Rules that bind every file of this change

* `packages/paperdrop_core/lib/` stays pure Dart: no `dart:io`, no `package:http`, no new dependency
  without the orchestrator, no network, no token, no environment variable (`AGENTS.md` §1.3–§1.4).
  `python .github/scripts/core_purity.py` is part of every check.
* **No `double`, `num`, `toDouble` or float parse anywhere in `lib/`.** The scan test of
  `implement-core-model-and-countries` (`test/no_float_test.dart`) is **not edited by this change**.
  Geometry is the one place a float is natural, and §2 shows how it is avoided rather than excepted.
* Money is `Money` in integer minor units, rates are `RateBp`, and every comparison is exact integer
  arithmetic on the types T1.1–T1.2 published. No rounding function is introduced; §6 states the one
  tolerance once.
* Everything immutable, value equality, dartdoc on every public member citing the requirement it
  serves. Tests are tagged `[capability/requirement-name] scenario title` as in
  `implement-core-model-and-countries` §1.4; a partial proof is untagged and names the scenario in a
  comment. `python .github/scripts/scenario_coverage.py` must stay green.
* **Fixtures are synthetic and invented.** No file of the private corpus is read, copied or paraphrased
  by the lane; its folder is outside the lane's writable paths and the lane does not look for it. A
  fixture contains no supplier name, tax identifier, plate, address or printed value that came from a
  real document. `python .github/scripts/privacy_check.py` runs **after `git add`**, because it scans
  tracked files only.
* Checks, from the repository root, per package folder (`AGENTS.md`, memory note: never run
  `dart test` from the root, it can reach the `live` tests of the Ninox package):
  `cd packages/paperdrop_core` then `dart analyze --fatal-infos`, `dart format --set-exit-if-changed .`,
  `dart test`; and from the root `python .github/scripts/core_purity.py`,
  `python .github/scripts/privacy_check.py`, `python .github/scripts/scenario_coverage.py`.

## 2. The positioned-word contract — first commit, before any layout logic

```
lib/src/layout/positioned_word.dart   PositionedWord
lib/src/layout/text_page.dart         TextPage
```

`PositionedWord(text, x0, x1, top, bottom)` and
`TextPage(index, width, height, words, hasTextLayer)`. The field names are pdfplumber's, as
`close-adr-011-pdf-text-route` design §3 says, so the reference JSON, the harness and the model agree
without a mapping.

**One amendment to that design's wording, decided here:** the coordinates are `int`, in **thousandths
of a PDF point** (top-left origin), not floating-point points. The reason is rule 2 above — the
no-float scan is a blanket guard and the core's value is determinism — and the cost is nil: a library
reports positions to a hundredth of a point at best, so `(points * 1000).round()` loses nothing the
comparison can see. The conversion lives in the **adapter** (`app/`, Mobile), which receives the
library's floats; Core never sees one. `width` and `height` of `TextPage` are in the same unit.
`PositionedWord` and `TextPage` carry a doc comment stating the unit in the first line, and a typedef
`MilliPoint = int` names it where it appears in a signature. The orchestrator tells Mobile on the day
this commit lands, because Mobile's adapter (after the ADR-011 decision) fills these types.

Invariants checked in the constructor or a named test: `x0 <= x1`, `top <= bottom`, `text` is
non-empty and contains no whitespace (a *word*), `index >= 0`, `hasTextLayer` is false **exactly when**
`words` is empty (a derived property, not a field the caller can set inconsistently). A page's words
may arrive in **any order**; nothing downstream may depend on it (§3).

This commit changes `paperdrop_core.dart` only to export the two types. The lane reports the commit
hash in its report so the orchestrator can start the dependent work.

## 3. T1.5 — layout reasoning and consensus

```
lib/src/layout/lines.dart       LayoutLine, groupIntoLines
lib/src/layout/binding.dart     LabelBinding, bindLabel
lib/src/consensus/consensus.dart  Reading<T>, ConsensusResult<T>, resolveConsensus
```

**Lines.** `groupIntoLines(TextPage)` ignores the order of `words`. It sorts by `top`, then `x0`, and
puts a word on the current line when its vertical interval overlaps the line's by at least half of the
**shorter** of the two heights, in integer arithmetic (`2 * overlap >= min(heightA, heightB)`). Words of
a line are ordered by `x0`; lines by their top. A `LayoutLine` exposes its words, its text (words
joined by one space — gaps are not interpreted), its bounding box and its page index. The half-height
rule is an implementation constant in one place with a test; it is not a product threshold and does
not touch GAP-003.

**Binding.** `bindLabel` takes a label occurrence (a `TermMatch` from `dictionaries/lookup.dart`
located on a line, mapped back to the words it covers) and a value kind (amount, date, document
number) and returns the bound value or nothing:

1. On the **label's own line**, the candidates are the words to the **right** of the label's last word,
   nearest first.
2. If that line holds no candidate of the expected kind, the **next line below** that overlaps the label
   horizontally, nearest first, in reading order, no further than a fixed number of line heights below
   (an implementation constant; beyond it the answer is "nothing").
3. A candidate is a word, or run of words, that parses as the expected kind with the helpers
   `format/decimal.dart` and `format/date.dart` under the **document's** convention (country row), not
   the interface language.
4. Never the nearest in **extraction order**. The test that proves it shuffles `TextPage.words` into
   several orders and requires the same binding every time.
5. Nothing binds a value that sits **above** the label or **left** of it. A last-resort fallback to any
   number on the page does not exist; that fallback is what bound `Tomo 8.741`.

The structure that failed (`PRO1013-26`) is reproduced **synthetically**: a label on one line, its
value on the line below, and a registry-volume line placed *next* to the label in `words` order but
visually on a different row. `[extraction-pipeline/positional-pdf-text-extraction]` — the binding
returns the value below, never the volume, for every permutation of the words. A second synthetic page
puts the volume on the label's own line to the right of a closer, valid amount, and proves the nearest
valid amount wins; whether that volume is then suppressed as a non-total is T1.6's negative-context
rule, not the binder's.

**Consensus.** `Reading<T>(value, passId, provenance)` and
`resolveConsensus(List<Reading<T>>)` returning a sealed `ConsensusResult<T>`: `Agreed(value, votes, of)`,
`NoConsensus`, or `Single(value)` when exactly one pass read anything. Equality is exact equality of the
canonical value (`Money` equality, not a numeric distance). The value with strictly the most votes
wins when it has at least two; a tie is `NoConsensus`; a single pass is `Single` and is **never**
treated as agreed (T1.7 turns that into amber at most). Three passes reading `96.76` and one reading
`9.676,00` yield `Agreed(96.76, 3, 4)`; no code path takes a maximum. Arithmetic downstream receives
only `Agreed` values or is explicitly marked as working on a `Single`.

## 4. T1.6 — the amount solver

```
lib/src/solver/operands.dart      ReadOperands (what the document printed, all of it)
lib/src/solver/currency.dart      CurrencyEvidence, resolveCurrency
lib/src/solver/negative.dart      suppression with the influence radius
lib/src/solver/rate_gate.dart     admit a printed rate against the country's legal set
lib/src/solver/solve.dart         solveAmounts → SolverResult
```

The pipeline order is fixed by `extraction-pipeline` · `pipeline-order-is-fixed`; the lane reads that
requirement and implements the stages that belong to this change in its order. In summary:

1. **Read every printed operand first** — gross, base, each tax amount, each printed rate — as `read`
   candidates with their positions. Nothing is computed yet (`read-all-printed-quantities-before-deriving`).
2. **Currency** from the document's own evidence — the printed ISO code, the symbol, the issuer country
   — with its own confidence state. Evidence that conflicts, or none, leaves the currency **absent**,
   and an absent currency suppresses the amounts (§5). It is never defaulted to the destination
   table's currency.
3. **Negative context**: a figure inside the influence radius of a negative term
   (`dictionaries/negative.dart`) is suppressed from the tax, base and total roles; one that the
   dictionary hints is surcharge-like is captured as a `Surcharge` with that label (`dcc_markup`,
   `service_charge`, `tip`, `rounding_adjustment`, `other`) — D.4's 4,5 % mark-up is the acceptance case.
   The radius is an implementation constant in one place.
4. **Legal-rate gate**: a printed rate is admitted only if the detected country's legal set contains
   it (`CountryRow.isLegalRate`); a rejected rate is discarded and takes no part in any
   later step. No rate is ever assumed.
5. **Match independent candidates against each other.** The prototype this approach comes from lives
   in the private corpus and **is not read by the lane**; its idea is stated here. Enumerate triples
   `(base, tax, gross)` drawn from the independently read amounts, accept those with
   `base + tax == gross` exactly in minor units and, where a rate was admitted, with the tax inside the
   tolerance of §6; exactly one accepted triple is a read-consistent solution, none means nothing is
   derived, several means the reading is ambiguous and the roles stay empty rather than one being
   guessed. With several tax slots the same is done per slot, then the slots are summed.
6. **Derive by identity, last.** Only when exactly one of base, tax, gross is missing **and** the other
   two were read and agree with a printed rate does the solver compute the third, tagged `derived`. A
   derived operand never confirms anything (§5), and without a printed rate the breakdown stays empty
   (`derive-by-identity-never-invent-a-rate`).

`SolverResult` carries, per field of the canonical document the solver touches, a `FieldValue` with its
provenance, plus the `surcharges` and the list of discarded rates and suppressed figures (for the
tests; they carry no content that identifies a document). Multi-page consolidation (FR-EXT-012): the
solver takes **all** pages' lines and produces one value per field; which route produced a page is not
visible to it.

## 5. T1.7 — confidence, repair and the honest empty

```
lib/src/confidence/redundancy.dart   exact sums and the tax tolerance
lib/src/confidence/repair.dart       repair to the only consistent value
lib/src/confidence/states.dart       assign ConfidenceState per field
lib/src/confidence/finalize.dart     apply the destination's absent setting
```

The strengths and their meaning are the spec's (`three-confidence-strengths`); the code is built
around one rule, **`a-check-confirms-only-if-every-operand-was-read`**, in this shape:

* `confirms(check)` is true only if every operand feeding the check has `Provenance.mayConfirm`. A
  check with a `derived` operand is recorded as `NonConfirmatory`, not as passed, and **raises no
  state** — D.5's derived-base tautology is the acceptance test, and its negative variant (the same
  numbers all `read`) confirms.
* **Green** needs a passing, confirming redundancy check. **Amber** is a check-digit-consistent
  identifier, a `repaired` value, or an amount with nothing to cross against — an uncrossed amount is
  never green. **Red** is unread or rejected by a constraint.
* **Never green**: `doc_number`, and in the MVP `supplier_name` (the memory that could raise it is R1;
  the empty-memory behaviour is the specified one, not a deviation). The numeric score is stored on the
  value and no state is computed from it.
* **Check digits** use the validators of `countries-languages` (IBAN, EAN-13, ES NIF/NIE/CIF). A
  validator is *accepted* only if it reproduces its standard valid and invalid vectors — one test per
  validator. `DE_STNR` and `DE_USTID` are left unchecked, and that **raises no doubtful state**
  (GAP-030).
* **Repair** (`repair-to-the-only-consistent-value`): try every single-character substitution from a
  small, named confusion table (the pairs Annex D.2 names, such as `5`/`S`), keep those whose result
  passes the identifier's check, and apply the repair **only if exactly one** does; two admissible
  repairs means none. The value is tagged `repaired` and is amber. `123456795 → 12345679S` is D.2.
* **Absent is not zero**: `AbsentPolicy { empty, zero }`, supplied **per destination field** to
  `finalize`; the default is `empty`. The core holds an absent value distinctly from `Present(0)` — the
  model already has three unequal values — and never decides the policy itself. The setting's storage
  is the wizard's.
* **Dates**: coherence and ambiguity are checked against the country row's `dateOrder`; where the
  document's own evidence does not decide between two readings the date is flagged ambiguous and left
  amber, never silently assumed. The lane reads `date-coherence-and-ambiguity` for the exact cases.
* **Empty over false**: when nothing sustains a value, the field is `Absent` by default — written
  deliberately, not as the fall-through of an error.
* A currency that is not sustained suppresses the **amounts** (their `FieldValue` becomes `Absent`),
  independently of any amount's own state (`currency-carries-its-own-confidence-state`). The two
  mis-detections of the test — a euro receipt tagged in dollars and a dollar invoice tagged in dirham
  — are reproduced synthetically.

## 6. The one tolerance, stated once

`redundancy-checks-on-amounts` allows **at most one minor unit per tax line**, only where `base × rate`
is compared with the printed tax, and nowhere else (sums of printed amounts are compared for exact
equality). With `T` the printed tax and `B` the base in minor units and `R` the rate in basis points
of the `RateBp` of T1.2 (`21 %` is `2100`), the product is exact and the comparison is, with no
rounding function and no division:

```
| 10000 · T  −  B · R |  ≤  10000
```

This is the only place this inequality appears in `lib/`; every caller goes through `taxWithinTolerance`
in `confidence/redundancy.dart`. The lane reads `ExactAmount` and `timesRate` as T1.1–T1.2 shipped them
and, if the shipped API makes this expression awkward, reports it rather than adding a rounding
function. Cash rounding (`CountryRow.cashRounding`) is **not** applied to this check; it concerns a
document's payable amount, which this change does not compare.

## 7. Annex D and the failed documents

`test/annex_d/` holds one file per worked example, **each with its negative variant**:

| File | Example | Proves |
| --- | --- | --- |
| `d1_ean13_candidates_test.dart` | two EAN-13 candidates | the check digit decides; neither is chosen without it |
| `d2_check_letter_repair_test.dart` | `123456795 → 12345679S` | the only admissible repair; two admissible means none |
| `d3_sum_test.dart` | `1652 + 347 = 1999`, and the variant that does not add up | exact equality on read operands |
| `d4_markup_test.dart` | 4,5 % mark-up | suppressed from the tax role, captured as `dcc_markup` |
| `d5_derived_tautology_test.dart` | derived base from the gross | confirms nothing; the all-`read` variant confirms |

The Annex's numbers are quoted from the Funcional (`docs/Fase 2. Define/Paperdrop_Funcional_v1.0_EN.md`,
Annex D), which is public, approved and the only place the lane takes them from.

**The five failed documents** are regressions in two forms, and only the first is in this change:

1. **Synthetic structures**, committed in `test/regressions/`, one per way a document failed: label and
   value on different lines with a registry volume nearer in extraction order; a card slip with no
   printed breakdown (nothing derived, breakdown empty); a document whose only number near a total label
   is a registry volume (empty rather than the volume); a foreign-currency document (amounts
   suppressed until the currency is sustained); a document printing no rate (breakdown empty, no
   assumed rate). Each file's header comment says which *structure* it reproduces and never names a
   document.
2. **Private runs** over the private corpus, **numbers only**, run by QA outside the repository
   (`validation/`), after the adapters exist. This change delivers the function they call; it does not
   run them.

## 8. Sequence

Four dispatches, because the lane's step limit (400) has already cut a run short once and every dispatch
should end on a green commit.

| # | Tasks | Result the orchestrator checks |
| --- | --- | --- |
| A | 1.1 contract; 2.1 lines; 2.2 binding | the contract commit hash, reported first; the shuffle test green |
| B | 2.3 consensus; 3.1 operands and currency; 3.2 suppression and gate | consensus and gate tests green |
| C | 3.3 matching and derivation; 4.1 redundancy and tolerance | D.3 and D.5 green |
| D | 4.2 repair and check digits; 4.3 states and finalize; 5.1 Annex D; 5.2 regressions | all of Annex D green, both negative variants |

The orchestrator reads each dispatch's diff against `packages/paperdrop_core/` only (the bounds check
reports any write outside it), and tells Mobile when A's first commit lands.

## 9. Risks recorded, not decided

* **Integer geometry** is an amendment of the ADR-011 design's wording (§2). If the product owner
  prefers floating-point points, the alternative is a narrow exception to the no-float scan for
  `lib/src/layout/` alone; the cost is editing a guard of an archived change.
* **The half-height line rule** and the **influence radius** are tuned on synthetic pages; the first
  private run may need them moved. They are single constants with tests, so moving them is one edit.
* **Several accepted triples** in §4 step 5 can occur on a document with repeated totals (a summary
  repeated on a last page); the lane treats identical triples as one. If real documents show this
  returning ambiguity too often, that is a measurement for GAP-003, not a reason to guess.
