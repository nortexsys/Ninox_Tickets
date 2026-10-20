# Proposal: add-amount-coherence-rules

## Why
The PO checked the photo route against the tickets (2026-10-20, 17 usable photographs): 42 judged fields correct, 13 wrong, 2 missed. The wrong ones are mostly *impossible* amounts, not misreadings:
* the VAT, the base and the total read as the same number (one ticket: three equal amounts);
* a VAT or base equal to a printed rate (`21,00` taken as an amount);
* a base/VAT pair that does not add up to the total.
One more is a single misread digit (a VAT of 10 for 11): not fixable by a rule, out of scope.

## What changes
Coherence rules in Core, applied to the photo route's amounts, **without changing the ported readers' logic**:
1. If gross, net and tax are all equal, keep the gross and drop net and tax (absent, not guessed).
2. A tax or net amount that equals a rate printed on the same ticket (e.g. `21,00` beside `21 %`) is not an amount: drop it.
3. A tax equal to the gross is impossible: drop the tax.
4. Where base + tax does not equal the gross (± 0,02) and the arithmetic reader has a consistent triple, prefer that triple; otherwise keep today's behaviour.
A rule drops or prefers; it never invents a value.

## Rollback (PO's condition)
The tag `pre-coherence-rules` marks `main` before this change. The change is merged only if the scorer (`Paperdrop_corpus\tools\score.py`, outside the repo) shows: **zero** correct fields broken, wrong fields not increased, and at least one wrong field improved (now absent or changed for the PO to review). Otherwise it is not merged; if merged and later found worse, `git revert -m 1` of the merge, back to the tag.
