# Paperdrop for Ninox — working contract

Read this file at the start of every session. It exists because the same
mistakes have already been made more than once in this project and in its
sibling project, and each one is written down here so it is not re-discovered
by error.

The specification layer lives in `openspec/`. This file is the layer above it:
where things are, what may not be touched, and what must be verified rather than
assumed.

---

## 1. Non-negotiable rules

1. **This folder is its own git repository, and it is public.**
   `github.com/nortexsys/Ninox_Tickets`. Before any commit, confirm the
   repository you are about to write into:

   ```
   git rev-parse --show-toplevel
   ```

   It must answer `C:/Users/admin/proyectos/04_01_Ticket_reader_Ninox`.
   **`C:\Users\admin` is itself a misconfigured git repository that swallows
   everything hanging below it.** If the answer is `C:/Users/admin`, stop: the
   next commit would publish this project's contents into an unrelated
   repository.

2. **Nothing that identifies a natural person is published.** Not a name, not a
   tax identifier, not a registration plate, not more than the last four digits
   of a card, not a full address — and not "anonymised" by removing the name
   while keeping the identifier, because the identifier *is* the identification.
   Third-party documents and everything derived from them stay out of the
   repository. Section 6 lists what is currently excluded and what is still
   exposed.

3. **`NINOX_API_KEY` never lives in a file.** It is a user-level variable in the
   Windows registry, not in the process environment. Read it programmatically;
   never print it, never write it to a document, never pass it as a command-line
   argument. To check a credential, check its length or its effect — never its
   value.

4. **Never use `NINOX_DB_ID`. Ever.** In this project's test environment that
   variable points at the **production database of CLIENT A**. The test
   environment is always named explicitly:

   | | |
   | --- | --- |
   | Test team | `qCq3JS7q7ptoap8Yg` |
   | Test database | `db0000000000` |

   Pulling credentials from the environment and letting them pick the target is
   how the test records would have landed in a real company's ERP. It did not
   happen because the target was passed explicitly — that is the rule, not luck.

5. **Never write to Ninox without the product owner's explicit approval** — not
   even to the test base. Reading the schema is not writing; creating, updating
   or attaching is.

6. **`openspec/` is the source of truth for behaviour.** The documents in `docs/`
   are approved reference and are **read-only**. Where this phase decides
   something that diverges from the functional, the divergence is recorded in
   `openspec/product-decisions.md` and the functional is not edited.

7. **Everything is written in English** — application, documentation,
   specifications, commit messages. Conversation with the product owner is in
   Spanish.

8. **Requirement identifiers are borrowed, never invented.** `FR-EXT-006` means
   what the functional says it means. Reproduce identifiers exactly as the
   source spells them; never translate, renumber or paraphrase them.

---

## 2. Where everything lives

### 2.1 Local

| What | Where |
| --- | --- |
| Project root | `C:\Users\admin\proyectos\04_01_Ticket_reader_Ninox` |
| Renamed from | `C:\Users\admin\proyectos\Ticket_reader_Ninox` — an older, mostly empty folder of the same name still exists. **It is not the project.** Documents that cite the old path mean the new one |
| Measurement corpus | `C:\Users\admin\proyectos\Paperdrop_corpus\` — **outside the repository by design** |
| Mobile test harness | `Ticket_reader_Ninox\phone-harness\` — a separate concern (driving a real phone over adb), not part of the app |

### 2.2 The documents

| Document | Path | State |
| --- | --- | --- |
| PDR v0.2 | `docs/Fase 1. Discover/Paperdrop_PDR_v0.2_EN.md` | Approved |
| ADR v0.2 | `docs/Fase 1. Discover/Paperdrop_ADR_v0.2_EN.md` | Approved. ADR-010 and ADR-011 still **proposed** |
| Funcional v1.0 | `docs/Fase 2. Define/Paperdrop_Funcional_v1.0_EN.md` | Approved. 2376 lines, 12 FR modules, BR-01…22, NFR series, UC-01…15, Annexes A–E |
| Original brief | `docs/Fase 1. Discover/Funcional_App_NinoxTickets.md` | **Superseded** by PDR v0.2. Provenance only |
| 16-document test | `corpus_test/`, `REPORT-CORPUS.md` | Evidence. The PO's verdicts in `corpus_test/REPORT_after_review.md` are authoritative |
| Specifications | `openspec/` | **Current phase** |

### 2.3 The registries that hold state across sessions

| File | Holds |
| --- | --- |
| `openspec/gaps-register.md` | Every open hole or pending decision. Closed entries are kept, never deleted |
| `openspec/product-decisions.md` | Every decision taken in this phase that diverges from the functional |
| `openspec/project.md` | Project context, source-of-truth hierarchy, spec format, capability tree |
| `openspec/AGENTS.md` | How the specification agent must work |

---

## 3. Where the project is

| Phase | State |
| --- | --- |
| **FASE 1 — Discover.** Original brief → PDR v0.2 → ADR v0.2 → Funcional v1.0 | **Done.** Plus a real end-to-end test: 16 documents read, validated, written to a Ninox test base with their attachments, and read back |
| **FASE 2 — Specify.** Specifications through OpenSpec | **Done.** 12 capabilities, all archived, `openspec validate --all --strict` green |
| **Next, still within FASE 2** — features, tasks, milestones, delivery dates and test design | Not started. This is where the project goes next |
| **FASE 3 — Deployment.** Store publication and the Nortex Systems website write-up | Not started |

The specification phase is a gate, not a formality: the 16-document test left
five documents with wrong or invented values, and the functional answers each
one. A specification that lets any of them happen again has failed.

---

## 4. What must be verified rather than remembered

1. **Never assert a state you have not read in this session.** The state of a
   document, of a database, or of the repository is read at the moment it is
   asserted. Reconstructing it from memory between sessions has produced false
   statements in this project's sibling project three times.
2. **A passing validator is not a review.** `openspec validate --strict` proves
   that every requirement has at least one well-formed scenario. It does **not**
   prove that the scenario has a `WHEN`, and it does not prove that the
   requirement is normative. Measured behaviour is in `openspec/project.md` §5.
3. **Verify the repository before writing, not after.** Rule §1.1.
4. **Check a credential by its length or its effect, never by printing it.**
5. **Do not fix a document to make a check pass.** Where a document is genuinely
   inconsistent, the inconsistency is data. This rule was established for the
   corpus and applies unchanged to specifications.

---

## 5. What is open, right now

Written down so the next session starts from the truth instead of from a guess.

| Item | State |
| --- | --- |
| ADR-010 — recognition engine for the photo route | **Proposed.** Blocks `FR-EXT-005`, `FR-EXT-015`, `UC-14` |
| ADR-011 — PDF text-extraction library | **Proposed.** Blocks `FR-EXT-004`, `NFR-SIZ-001`. Must expose word positions |
| Ninox attachment-upload limits | Closed for the basic case. Open: maximum file size, multi-page PDF near that limit, real upload timings |
| A choice field written with text outside its option list | Unverified in every test so far |
| Acceptance thresholds for product metrics | Deferred until the first corpus screening |
| The name "Paperdrop" | Not yet checked in either app store, nor at the EUIPO |
| Capability tree | **Approved and complete.** Recorded in openspec/project.md §3 |
| Specifications | **Complete.** 12 specs in `openspec/specs/`, all changes archived, validated by `openspec validate --all --strict` |
| Privacy gate | **Closed** on 2026-09-23. Section 6 |
| Residue of real personal data in excluded material | Open, and protected by the `.gitignore` alone. GAP-017, §6 |

---

## 6. The privacy gate

**Closed on 2026-09-23.** Two layers, and both were verified by reading rather
than assumed.

**Layer 1 — exclusion.** The `.gitignore` excludes, with the reason recorded in
the file itself: `docs/corpus/` (13 third-party documents), `out/` (OCR output,
including a card's BIN and last four digits), `corpus_test/out/` and
`corpus_test/inbox/`, `tools/`, `sql/`, and any `.env`. Verified path by path with
`git check-ignore -v`.

**Layer 2 — substitution.** Six files that *are* published carried the real tax
identifier of a natural person. Five were plain text:
`corpus_test/REPORT.md` (L117-118, which additionally carried the full name,
registration plate and licence), `Paperdrop_PDR_v0.2_EN.md` (L84, L195),
`Paperdrop_Funcional_v1.0_EN.md` (L749, L2293), `REPORT-CORPUS.md` (L61) and
`docs/TWO_OPTIONS.MD` (L63). **Three `.docx` carried it too**, inside
`word/document.xml` — a discovery that only came from opening the binaries, since
a text search does not see into them (PDR v0.1, PDR v0.2, Funcional v1.0).

All of it was replaced with the synthetic **`12345679S`**, read wrongly as
`123456795`. The value is not arbitrary: `12345679` has check letter `S`
(15 mod 23), `S` is precisely the character OCR confuses with `5`, and the
algorithm admits a single replacement of the final character. The worked example
keeps its exact property, and the substitution is length-preserving (9 characters
for 9), so no document reflows. The `.docx` were patched inside the zip archive
and verified: zip entries intact, XML well-formed, zero occurrences of the old
value.

`corpus_test/REPORT.md`'s privacy warning was rewritten to **describe** what was
found instead of reproducing it. The functional's assertion that no natural
person's data is reproduced is now true.

Recorded as **DEC-001** in `openspec/product-decisions.md`; closed as **GAP-010**.

**Known residue, and it is not covered by anything but the `.gitignore`.**
`tools/load_db.py`, `tools/taxi_extract.py` and `sql/schema.sql` still hold that
person's name, identifier, plate and licence. They are excluded from the
repository and verified ignored, and they are the working record of a real
analysis — changing the plate would break code that validates its format against a
real document — so they were deliberately left alone. **Anyone who later wants to
publish the prototype, or who edits `.gitignore`, re-exposes that data.** Tracked
as GAP-017.

---

## 7. Closing ritual for a session

1. Update `openspec/gaps-register.md` with anything opened or closed.
2. Update `openspec/product-decisions.md` with any decision that diverges from
   the functional.
3. State plainly what is finished, what is open, and what the next session
   starts with. A capability described as "practically done" is not done.
