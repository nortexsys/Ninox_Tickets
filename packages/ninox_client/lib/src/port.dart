/// The Ninox-facing port of ADR-003, and the tuple every table-bound call quotes.
///
/// ADR-003 chose the classic interface and, because the vendor describes it as the previous
/// generation, required it to sit behind a port: a second implementation — a newer-interface
/// adapter, or a private-cloud variant — is addable without touching the rest of the application.
/// This file is that port; `classic_adapter.dart` is one implementation of it.
library;

import 'dart:typed_data';

import 'errors.dart';
import 'model.dart';

/// The three identifiers a call is bound to: **team, database and table**, all explicit.
///
/// `AGENTS.md` §1.4 and the `ninox` skill's rule 7: the target is never inferred and never read
/// from the environment — an environment variable in this project's test environment points at a
/// production database (GAP-012). None of the three can be defaulted, so a call that does not know
/// its destination cannot be written.
///
/// Immutable and compared by value.
final class TableRef {
  /// Binds a team, a database and a table.
  const TableRef({
    required this.teamId,
    required this.databaseId,
    required this.tableId,
  });

  /// The team identifier.
  final String teamId;

  /// The database identifier, inside [teamId].
  final String databaseId;

  /// The table identifier, inside [databaseId].
  final String tableId;

  @override
  bool operator ==(Object other) =>
      other is TableRef &&
      other.teamId == teamId &&
      other.databaseId == databaseId &&
      other.tableId == tableId;

  @override
  int get hashCode => Object.hash(teamId, databaseId, tableId);

  @override
  String toString() => 'TableRef($teamId, $databaseId, $tableId)';
}

/// Everything this application does to Ninox, and everything it refuses to do (ADR-003).
///
/// **Contract of every method.** It returns `Future<T>` and throws **only** [NinoxFailure]
/// subtypes: never an `http.ClientException`, a `FormatException` or a `TimeoutException`. The
/// adapter never retries anything, and never a create: classifying a failure — a 500 means *refresh
/// the schema and retry once*, a lost create means *reconcile* — is the send pipeline's state
/// machine (`ninox-send/the-retry-matrix`, T1.11).
///
/// **The update primitive carries no measured provenance yet.** `ninox-send/updates-are-merges`
/// (FR-SND-008) needs a merge update, and the `ninox` skill documents every other call of this
/// port — endpoint, verb and body — but **not** the update: no path, no verb and no body appear
/// anywhere in its reference or its client. The lane therefore reported it as blocked rather than
/// guessing (design §3). The shape is now settled from the vendor's own documentation of the
/// classic API, and [NinoxPort.updateRecord] carries that provenance in its dartdoc, marked as
/// still to be confirmed against a live workspace in T1.9.
abstract interface class NinoxPort {
  /// `GET /v1/teams` — the teams the token can see, each with its identifier and name.
  ///
  /// A token is scoped to the user, not to a database, so this is everything that user can see.
  /// Throws [Unauthorized], [UnexpectedResponse] or [TransportFailure].
  Future<List<NinoxTeam>> listTeams();

  /// `GET /v1/teams/{team}/databases` — the databases of one team.
  ///
  /// [teamId] is an argument, always: no method of this port reads a target from anywhere else.
  /// Throws [Unauthorized], [NotFound], [UnexpectedResponse] or [TransportFailure].
  Future<List<NinoxDatabase>> listDatabases(String teamId);

  /// `GET /v1/teams/{team}/databases/{database}/tables` — the tables **with their fields**, in one
  /// call. There is no second schema request: `.../tables/{table}/fields` does not exist (404).
  ///
  /// Formula fields are absent from this listing rather than marked, and this method adds no
  /// filtering of its own (`docs/Plan/SPIKE_GAP-022_schema_formula_fields.md` §3).
  /// Throws [Unauthorized], [NotFound], [UnexpectedResponse] or [TransportFailure].
  Future<List<NinoxTable>> listTables(String teamId, String databaseId);

  /// `POST .../tables/{table}/records` — creates one record and returns its identifier.
  ///
  /// [fieldsByName] is keyed by the fields' **current names** and is sent nested under a `fields`
  /// key, which is the shape ADR-004 verified. An empty mapping is sent as `{"fields": {}}`: a
  /// destination with nothing mapped must never have a field written for it
  /// (`destinations-mapping/never-write-an-unmapped-field`). Field **identifiers** are a
  /// destination's business, not this port's.
  ///
  /// Throws [Unauthorized], [NotFound], [ServerError] (a 500 here is usually a bad, formula or
  /// read-only field name — the pipeline's mapping error, not an outage), [UnexpectedResponse], or
  /// [CreateOutcomeUncertain]: **a lost create response may have created the record**, so this
  /// method never retries and says which side it is on.
  Future<RecordId> createRecord(
    TableRef ref,
    Map<String, Object?> fieldsByName,
  );

  /// `GET .../records/{id}` — one record, its values and, when the endpoint returns them, the audit
  /// keys, including the `createdAt` / `createdBy` the reconciliation reads.
  ///
  /// Throws [Unauthorized], [NotFound], [ServerError], [UnexpectedResponse] or [TransportFailure]
  /// — the last of which is safe to retry, because a read cannot duplicate a record.
  Future<NinoxRecord> readRecord(TableRef ref, RecordId recordId);

  /// `PUT .../records/{id}` — updates **only** the fields given; every field not sent is preserved.
  ///
  /// ADR-004, measured: *updates are merges*. That is the primitive
  /// `ninox-send/updates-are-merges` (FR-SND-008) is built from: a correction sends only what
  /// changed, and a failed attachment can be retried without touching the record. The body is
  /// nested under a `fields` key keyed by the fields' **current names**, exactly as a create is,
  /// and it contains nothing else: a field the user has not mapped is never sent, and an empty
  /// mapping is `{"fields": {}}`, which changes nothing (the skill's *send nothing, and nothing
  /// changes*).
  ///
  /// **Provenance: verb and path from vendor documentation; to be confirmed live in T1.9.** The
  /// vendor's documentation of the classic API ("API endpoints for Public Cloud") gives the update
  /// as `PUT /v1/teams/{teamid}/databases/{dbid}/tables/{tid}/records/{rid}` with the body
  /// `{"fields": {"<field name>": <value>, ...}}`; ADR-004 supplies the measured merge semantics.
  /// The `ninox` skill settles neither, which is why this primitive arrived after the rest of the
  /// port (design §3) and why T1.9 re-records it against the test base before anything depends on
  /// it.
  ///
  /// Throws [Unauthorized], [NotFound], [ServerError] (a 500 here is usually a bad, formula or
  /// read-only field name), [UnexpectedResponse] or [TransportFailure] — always a **plain**
  /// [TransportFailure] and never [CreateOutcomeUncertain]: an update cannot create a record, and
  /// sending the same fields twice leaves the record as one update would, so a lost response is
  /// safe to send again.
  Future<void> updateRecord(
    TableRef ref,
    RecordId recordId,
    Map<String, Object?> fieldsByName,
  );

  /// `POST .../records/{id}/files` — attaches one document to the **record**, in a single
  /// `multipart/form-data` call that answers HTTP 200.
  ///
  /// The document is not a mapping target and no table is unsuitable: a file belongs to the record,
  /// not to a field (ADR-004). [bytes] are sent exactly as given — never re-encoded, never
  /// re-rendered (ADR-007, BR-17) — and [contentType] is the type to declare for them. An invalid
  /// [contentType] is a programming error and throws `ArgumentError` before any request is sent.
  ///
  /// Throws [Unauthorized], [NotFound], [ServerError], [UnexpectedResponse] or [TransportFailure].
  /// A timeout here is safe to retry: it cannot create a second record.
  Future<void> uploadFile(
    TableRef ref,
    RecordId recordId, {
    required String filename,
    required Uint8List bytes,
    required String contentType,
  });

  /// `GET .../records/{id}/files` — what is attached to the record: name, size and content type.
  ///
  /// This is the read-back of [uploadFile] and is compared against what was uploaded.
  /// Throws [Unauthorized], [NotFound], [ServerError], [UnexpectedResponse] or [TransportFailure].
  Future<List<NinoxFile>> listFiles(TableRef ref, RecordId recordId);

  /// `GET .../tables/{table}/records` — a page of records.
  ///
  /// `perPage` and `page` were measured to page correctly and are the only paging parameters this
  /// port offers; `limit` and `pageSize` are accepted by the API and **ignored**, so they are not
  /// offered. The API's own default page is 100 records, so a caller that treats an unparameterised
  /// call as "the whole table" is wrong on any table above that.
  ///
  /// [order] and [desc] are passed through and are **not** trusted: the read-only check of GAP-023
  /// (`test/live/order_desc_check_test.dart`) is what settles whether they sort. Until it has run
  /// and been recorded, a caller must sort and filter locally — which is what
  /// `ninox-send/reconciliation-of-an-uncertain-create` requires anyway.
  ///
  /// Throws [Unauthorized], [NotFound], [ServerError], [UnexpectedResponse] or [TransportFailure].
  Future<List<NinoxRecord>> listRecords(
    TableRef ref, {
    int? page,
    int? perPage,
    String? order,
    bool? desc,
  });
}
