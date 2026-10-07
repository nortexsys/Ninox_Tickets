# ADR-011 comparison — 2026-10-07

Candidates segment words their own way (design §2): word counts differ by design. The IoU ≥ 0.5 share, not the word count, is the comparable figure.

Documents compared: 5.

## Tool versions

- `pdfbox-android`: pdfbox-android 2.0.27.0
- `pdfrx`: pdfrx 0.5.0

## Per-page word-level fidelity

### pdfbox-android

| doc_id | page | ref words | cand words | recall | precision | IoU≥0.5 share |
| --- | --- | --- | --- | --- | --- | --- |
| doc-01 | 0 | 2 | 2 | 100.0% | 100.0% | 100.0% |
| doc-02 | 0 | 4 | 5 | 100.0% | 80.0% | 100.0% |
| doc-03 | 0 | 5 | 5 | 100.0% | 100.0% | 100.0% |
| doc-04 | 0 | 1 | 1 | 100.0% | 100.0% | 100.0% |
| doc-05 | 0 | 2 | 2 | 100.0% | 100.0% | 100.0% |

### pdfrx

| doc_id | page | ref words | cand words | recall | precision | IoU≥0.5 share |
| --- | --- | --- | --- | --- | --- | --- |
| doc-01 | 0 | 2 | 2 | 100.0% | 100.0% | 100.0% |
| doc-02 | 0 | 4 | 4 | 100.0% | 100.0% | 75.0% |
| doc-03 | 0 | 5 | 4 | 60.0% | 75.0% | 60.0% |
| doc-04 | 0 | 1 | 1 | 100.0% | 100.0% | 100.0% |
| doc-05 | 0 | 2 | 2 | 100.0% | 100.0% | 100.0% |

## Per-document totals

### pdfbox-android

| doc_id | ref words | cand words | recall | precision | IoU≥0.5 share |
| --- | --- | --- | --- | --- | --- |
| doc-01 | 2 | 2 | 100.0% | 100.0% | 100.0% |
| doc-02 | 4 | 5 | 100.0% | 80.0% | 100.0% |
| doc-03 | 5 | 5 | 100.0% | 100.0% | 100.0% |
| doc-04 | 1 | 1 | 100.0% | 100.0% | 100.0% |
| doc-05 | 2 | 2 | 100.0% | 100.0% | 100.0% |

### pdfrx

| doc_id | ref words | cand words | recall | precision | IoU≥0.5 share |
| --- | --- | --- | --- | --- | --- |
| doc-01 | 2 | 2 | 100.0% | 100.0% | 100.0% |
| doc-02 | 4 | 4 | 100.0% | 100.0% | 75.0% |
| doc-03 | 5 | 4 | 60.0% | 75.0% | 60.0% |
| doc-04 | 1 | 1 | 100.0% | 100.0% | 100.0% |
| doc-05 | 2 | 2 | 100.0% | 100.0% | 100.0% |

## Overall

| candidate | ref words | cand words | recall | precision | IoU≥0.5 share |
| --- | --- | --- | --- | --- | --- |
| pdfbox-android | 14 | 15 | 100.0% | 93.3% | 100.0% |
| pdfrx | 14 | 13 | 85.7% | 92.3% | 78.6% |

## Total-label probe

| doc_id | candidate | occurrences | bound confirmed total | outcome |
| --- | --- | --- | --- | --- |
| doc-01 | pdfbox-android | 1 | 1 | yes |
| doc-01 | pdfrx | 1 | 1 | yes |
| doc-02 | pdfbox-android | 1 | 1 | yes |
| doc-02 | pdfrx | 1 | 1 | yes |
| doc-03 | pdfbox-android | 1 | 1 | yes |
| doc-03 | pdfrx | 0 | 0 | no label found |
| doc-04 | pdfbox-android | 0 | 0 | not probed |
| doc-04 | pdfrx | 0 | 0 | not probed |
| doc-05 | pdfbox-android | 1 | 0 | no |
| doc-05 | pdfrx | 1 | 0 | no |

Documents with totals missing: 1.

## Read-only check (sha256 == sha256_after)

| doc_id | candidate | unchanged |
| --- | --- | --- |
| doc-01 | pdfbox-android | yes |
| doc-01 | pdfrx | no |
| doc-02 | pdfbox-android | yes |
| doc-02 | pdfrx | yes |
| doc-03 | pdfbox-android | yes |
| doc-03 | pdfrx | yes |
| doc-04 | pdfbox-android | yes |
| doc-04 | pdfrx | yes |
| doc-05 | pdfbox-android | yes |
| doc-05 | pdfrx | yes |

## Timing (ms per page)

| candidate | median | max | pages measured |
| --- | --- | --- | --- |
| pdfbox-android | 10.0 | 14.0 | 5 |
| pdfrx | 8.0 | 9.0 | 5 |

