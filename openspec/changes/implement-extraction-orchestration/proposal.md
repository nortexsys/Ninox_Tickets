# Proposal: implement-extraction-orchestration

T2.1 (plan v0.2 M2). The two recognition ports (`PdfTextSource`, `OcrTextSource`) and Core's
reading, consensus, solver and confidence pieces exist but nothing connects them: no function turns
pages or passes into a `CanonicalDocument`, and nothing chooses the route. This change adds Core's
`extractDocument` (pure) and the app's `ExtractionRouter`. Requirements: `FR-EXT-001`, `FR-EXT-002`,
`FR-EXT-006`, `FR-EXT-012`. Detail, split by layer and open points: `design.md`. Out of scope: review
screen, history, the ADR-010 screening, XML (R1), accuracy thresholds.
