# Change: implement-ninox-client

## Why

Everything the app does to Ninox, and everything it refuses to do, routes through one port.
ADR-003 chose the classic REST interface and ADR-004 recorded its measured contract; until a
client exists behind a port, neither is code, and every later Ninox change — the wizard reading
the user's own tables (T1.10), the send pipeline with its reconciliation (T1.11) — would invent
its own HTTP and its own mistakes. Plan v0.2 §7.2 makes this the Ninox lane's week-1 change
precisely so it does not: the port and adapter land once, and the two changes that follow code
against them.

Two things that are not code sit inside that decision, and both are decided here rather than
rediscovered later. The client is the **only** component that holds the token and reaches the
network, so the isolation is structural and not a convention: the team and database are always
explicit arguments and **no** step of this change reads `NINOX_DB_ID`, which in this project's
test environment points at a production database (`AGENTS.md` §1.4, GAP-012). And the classic
API's pagination and ordering were measured to be wrong about half the parameters
(`limit` and `pageSize` are accepted and ignored; `perPage` and `page` do page). The one
behaviour the reconciliation of an uncertain create actually depends on — that `order`/`desc`
sort, and not merely return some records — is still unverified, because the 2026-09-25 spike
counted records and never looked at their order. Closing that read-only is what lets
`reconciliation-of-an-uncertain-create` be coded against reality instead of against an
assumption, and it is why this change ends with live tests rather than only contract ones.

## What Changes

An **implementation-only change** (`skip_specs: true`, plan §8.2). No requirement is added,
modified, removed or renamed, and no living spec is touched. All code goes in
`packages/ninox_client/`, plus recorded-response fixtures and the live-test source the lane
runs on the product owner's machine.

* **T1.8 — the port and the classic adapter** (plan §9 M1). The port of ADR-003: a
  Ninox-facing interface behind which a second implementation can sit without touching the rest
  of the application, and its classic REST adapter over `package:http`. The **host is
  configuration**, never a compiled constant: it defaults to `api.ninox.com` and is supplied per
  call site alongside the team and database, so a private-cloud customer needs no fork
  (ADR-017, `configurable-ninox-host`). The team and database are always explicit arguments;
  no environment variable ever picks a target.
* **T1.8 — contract tests on sanitised recorded responses.** Every recorded response is
  sanitised: no token, no record content of a real person, no host credential. The repository is
  public and the token never enters CI (plan §7.2); CI runs contract tests on these fixtures
  only, and the negative release checklist's *no credential beyond the token* is asserted here
  rather than hoped for. Covered: the endpoints ADR-004 measured — teams, databases, tables with
  their fields, the record list, create, the multipart attachment upload returning HTTP 200, the
  read-back — plus the error shapes of `the-retry-matrix`, with fault injection for a timed-out
  create and for HTTP 500.
* **T1.8 — read-only check of `order`/`desc`** (GAP-023). A live read against the test base,
  never a write, that settles what the reconciliation will rely on: whether `order=sequence` with
  `desc` actually returns records in that order, given that `perPage` and `page` were measured to
  page and `limit` and `pageSize` to be ignored.
* **T1.9 — live write tests under D-10** (GAP-004). Create → attach → read back → delete, on
  team `qCq3JS7q7ptoap8Yg`, database `db0000000000`, one disposable table, deleting only what
  the test created — exactly the bounds of the standing approval. Their purpose is measurement,
  not coverage: the maximum attachment size, the behaviour of a multi-page PDF near that limit,
  and the real upload size and timing from Spain rather than from a cloud container.

## Requirements implemented

Identifiers as the functional spells them; the requirement name is the one that owns the
behaviour in `openspec/specs/`. Each item states the part this change satisfies, because several
of these requirements have a half that belongs to a later change.

* **FR-DST-008** — `destinations-mapping` · `configurable-ninox-host`: the adapter half. The host
  is a constructor parameter with a default of `api.ninox.com`, is never compiled into a base
  URL, and is used for every call. The validation half — validating it at the token step exactly
  as the token is validated — is T1.10's, in `implement-setup-wizard`.
* **FR-SND-002** — `ninox-send` · `payload-shape`: the serialisation half. Records are written as
  a nested object under a `fields` key, dates as `YYYY-MM-DD` verbatim, amounts and rates as the
  integers of `paperdrop_core` (`Money`, `RateBp`), and the attachment is never a field. The
  pipeline half — the send itself, staged after create — is T1.11's.
* **FR-SND-003** — `ninox-send` · `attachment-upload`: the call and its read. A single multipart
  POST to the record's files endpoint, HTTP 200, and the read-back of name, size and content
  type. The *no record without its document* half is T1.11's, where the send treats a failed
  attachment as incomplete.
* **FR-SND-004** — `ninox-send` · `the-retry-matrix`: the classification half. The adapter maps
  every condition of the matrix to its behaviour — a 401 or 403 is authentication with no retry,
  a 404 is a vanished destination with no retry, a 500 refreshes the schema and retries exactly
  once, a timeout on create is `uncertain` and never a blind retry, an attachment or read-back
  timeout gets bounded exponential backoff. The state machine that consumes it is T1.11's.
* **FR-SND-005** — `ninox-send` · `reconciliation-of-an-uncertain-create`: the read half. The
  client reads the destination table's most recently created records with `perPage`/`page` and
  the ordering this change verifies, and returns `createdAt` and `createdBy` so the
  reconciliation does not depend on a marker field. The reconciliation *logic* — exactly one
  match adopts, no match creates, ambiguity asks the user — is T1.11's.
* **FR-SND-008** — `ninox-send` · `updates-are-merges`: the update primitive itself, sending only
  what changed. Its two uses are later changes': the attachment-only retry is T1.11's, and the
  correction flow is R1 with FR-HIS-003.
* **FR-SND-001** — `ninox-send` · `create-attach-read-back`: the three calls, in order, as one
  adapter operation. The confirmation screen that shows the read-back values is T2.2's.
* **BR-19** — `product-invariants` · `token-is-the-only-credential`: the client asks for one
  bearer token and nothing else, and never transmits a second credential.
* **BR-16** — `product-invariants` · `never-touch-schema-or-foreign-records`: no request of this
  change mutates a schema, and the live writes of T1.9 delete only the records they created.

## Gaps and decisions this change acts on

* **GAP-023** (open, `NO BLOQUEANTE`) — `perPage` and `page` page correctly and `limit` /
  `pageSize` are ignored, but whether `order`/`desc` actually sort was never verified; the spike
  counted records and never looked at their order. T1.8 closes it **read-only**, and the
  reconciliation of `reconciliation-of-an-uncertain-create` is coded afterwards against what it
  measured. If ordering does not behave, the reconciliation falls back to paging through recent
  records by `sequence` and the gap is re-opened against that evidence rather than silently
  assumed away.
* **GAP-004** (open, `NO BLOQUEANTE`) — the maximum attachment size, a multi-page PDF near that
  limit, and real upload size and timing from the primary market. T1.9 measures all three under
  D-10 and reports them; **no threshold is stated by this change**, because the functional states
  none and inventing one would assert something untested. The measurement is what the gap is
  waiting on.
* **GAP-012** (open, `NO BLOQUEANTE`) — `NINOX_DB_ID` points at a production database and the CI
  `no-ninox-db-id` job is the registered mitigation. This change is the other half of the same
  mitigation, in the component that could have used the variable: **no step reads it**, the test
  base is named explicitly in every live test as `qCq3JS7q7ptoap8Yg` / `db0000000000`, and the
  fixtures carry no credential either.
* **ADR-003 / ADR-004 / ADR-017** (approved) — the classic API, its measured contract and the
  configurable host are what the adapter implements, rather than a choice re-taken in code.
* **D-10** (standing approval, plan v0.1 §6.3 / v0.2 §7.1) — writes to the test base are
  permitted bounded to that team, that database, one disposable table and deletes of the records
  the test created. T1.9 stays inside those bounds or does not run.

## Deferred

Design and tasks are the orchestrator's; the boundary below is stated so the next two Ninox
changes do not have to renegotiate it.

* **T1.10 — the wizard** (`implement-setup-wizard`, plan §8.3 change 5, W1–W2): the token step
  through the system browser, the team/database/table listing with auto-omitted steps, the
  two-stage field matching, the summary, and the per-field absent setting. It consumes this
  change's enumeration and validation of the host, and it is where `configurable-ninox-host`'s
  validation half lands.
* **T1.11 — the send pipeline** (`implement-send-pipeline`, plan §8.3 change 6, W2): the send
  itself, staged create → attach → read-back, the retry matrix's state transitions, the
  reconciliation logic, the deep link, the queue that drains while the app is open, and the
  user-facing documentation line of `automations-may-run-and-the-read-back-is-the-visibility`
  (FR-SND-007, plan §4.7: a documentation requirement, and one that has no API half). It consumes
  this change's port, payload shape, ordering evidence and update primitive.
* **The deep link** (`deep-link-back-to-the-record`) is built from data the app already holds and
  needs no API call, so it is T1.11's and costs this change nothing.
* **The formula-field contrast** of `formula-totals-used-as-post-write-contrast` (FR-DST-005,
  R1) needs the full database schema's `fn` expression, which GAP-025 records as an unstable
  contract; this change reads only `.../tables` and `.../records`, never `.../schema`.
* **R1** — the choice of endpoint beyond `.../tables` is a wizard design matter, and no privacy
  notice or clearing action ships (FR-CFG-001…003, R1).

## Impact

`packages/ninox_client/` (source, tests and the sanitised recorded-response fixtures the contract
tests run on) and the live-test sources T1.9 runs on the product owner's machine. No living spec
changes; no functional change; no new decision is taken, so nothing is recorded in
`openspec/product-decisions.md`.

**Two approvals this change cannot proceed without, stated plainly.** Any live call — the
read-only ordering check of T1.8 included — needs the product owner's approval of
`--allow-ninox-token`, and **no step of this change uses `NINOX_DB_ID`**: the test base is the
explicit `qCq3JS7q7ptoap8Yg` / `db0000000000` (GAP-012, `AGENTS.md` §1.4). Writes additionally
need the product owner, and T1.9's writes stay inside the bounds of the standing approval D-10
or they do not run (`AGENTS.md` §1.5).
