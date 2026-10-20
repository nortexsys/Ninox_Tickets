# Change: add-extraction-stage-trace

## Why

On the Galaxy S22 the photograph route reads a total in 1 of 19 photographs (status 2026-10-19). The
OCR words and the amounts are there (the four passes agree on most amount tokens, and total-like labels
are read), and a **single pass** yields a total in only 2 of 19, so the loss is inside extraction and not
in the consensus between passes. The photographs are third-party documents: they cannot be copied into the
repository or shown to a lane (AGENTS.md §1.2, §6). To find the stage that drops the total without
exposing a document, Core needs a **trace that names the stage and never carries a value**.

## What Changes

Implementation-only (`skip_specs: true`), Core lane, under `packages/paperdrop_core/`. An **optional,
additive** `ExtractionTrace` parameter on `extractDocument` (default null: behaviour and results
unchanged) that records, per canonical field, the stage that left it absent or lowered it, as an enum and
never as text from the document. The orchestrator then runs it over the private photographs on the host
and reports counts per stage; the next change fixes the dominant stages from synthetic reproductions.

## Out of scope

* Any change to what `extractDocument` returns. Any value, word or number of a document in a trace.
* The fix itself (next change). The app, the adapters, the specs.
