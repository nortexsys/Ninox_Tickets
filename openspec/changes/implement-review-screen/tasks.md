# Tasks: implement-review-screen

## 1. Mobile lane

- [ ] 1.1 `ReviewController`: load entry + document, edits as `Edited`, focus rule, needsReview line (design §1, §2).
- [ ] 1.2 Six fields in fixed order with confidence colour and edited mark; strings in `app_en.arb`; semantic labels (design §2).
- [ ] 1.3 Amounts block collapse rule and DEC-007 behaviour; lock on green (design §3).
- [ ] 1.4 Destination bar, last-used preload, daily acknowledgement persisted, only condition disabling save (design §4).
- [ ] 1.5 Duplicate notice with link and proceed-anyway (design §5).
- [ ] 1.6 Save button named by table, fixed at bottom, never blocked; empty-document save; edited value is what is sent (design §5).
- [ ] 1.7 Discard: no record, no entry, file deleted (design §5).
- [ ] 1.8 Thumbnail and full-screen view (design §6).
- [ ] 1.9 One test per scenario of the cut requirements; lane report; no device run claimed.

## 2. Orchestrator and product owner

- [ ] 2.1 Review report and diff; run the checks of design §7.
- [ ] 2.2 PO approves; merge `--no-ff`.
