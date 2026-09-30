/// GAP-023, read-only: does `order` / `desc` actually sort the record list?
///
/// The spike measured that `perPage` and `page` page correctly and that `limit` and `pageSize` are
/// accepted and ignored, but it counted records and never looked at their **order**
/// (`docs/Plan/SPIKE_GAP-022_schema_formula_fields.md` §5). The reconciliation of an uncertain
/// create depends on that one behaviour: if `order`/`desc` sort, the most recent records can be
/// fetched in one bounded page; if they do not, the fallback is to page through recent records by
/// `sequence` and to re-open GAP-023 against that evidence (change proposal, GAP-023).
///
/// This test is written now and **never run by the lane**: it is tagged `live`, excluded by default
/// in `dart_test.yaml`, and it skips when the token variable is absent, so it never fails CI. The
/// orchestrator runs it on the product owner's machine once the product owner has approved
/// `--allow-ninox-token` (change design §5, §6).
///
/// **It reads only.** Every call is a GET through [NinoxPort.listRecords]; nothing here creates,
/// updates, attaches or deletes anything, and nothing reads a target from the environment — the
/// team, database and table are the literals below (`AGENTS.md` §1.4, GAP-012).
@Tags(['live'])
library;

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:ninox_client/ninox_client.dart';
import 'package:test/test.dart';

/// The test environment, named explicitly and never taken from the environment
/// (`docs/Plan/SPIKE_GAP-022_schema_formula_fields.md` §1).
const String _teamId = 'qCq3JS7q7ptoap8Yg';
const String _databaseId = 'db0000000000';

/// The reference table of the spike — `YB`, "Tarjetas Banco" — which carries a date field and a
/// number field, and which `corpus_test/REPORT.md` also wrote to.
const String _tableId = 'YB';

/// The variable the token is read from, as the spike and the skill's checker read it.
const String _tokenVariable = 'NINOX_API_KEY';

/// The field whose order the reconciliation itself would use.
const String _sequenceField = 'sequence';

/// A date field of the reference table, so that the check covers "a date or number field" too.
const String _dateField = 'Fecha';

const int _perPage = 20;

void main() {
  final token = Platform.environment[_tokenVariable];

  test(
    'order and desc put the records of the test table in that order, or they do not',
    () async {
      final adapter = ClassicNinoxAdapter(
        endpoint: NinoxEndpoint.cloud,
        credentials: NinoxCredentials(token!),
        client: http.Client(),
        timeout: const Duration(seconds: 60),
      );
      const ref = TableRef(
        teamId: _teamId,
        databaseId: _databaseId,
        tableId: _tableId,
      );

      for (final field in const [_sequenceField, _dateField]) {
        for (final desc in const [true, false]) {
          final records = await adapter.listRecords(
            ref,
            perPage: _perPage,
            order: field,
            desc: desc,
          );
          expect(
            records.length,
            lessThanOrEqualTo(_perPage),
            reason: 'perPage bounds the page (measured 2026-09-25)',
          );

          final values = _valuesOf(records, field);
          expect(
            values.length,
            greaterThan(1),
            reason:
                'a single record cannot show whether the order holds: fetch a table with '
                'more than one record, or re-run with a larger perPage',
          );
          _expectSorted(
            values,
            descending: desc,
            what: 'order=$field desc=$desc',
          );
        }
      }
    },
    skip: token == null
        ? '$_tokenVariable is absent: this live read is not run (change design §5).'
        : null,
  );
}

/// The values of [field] on the records that carry it, in the order the API returned them.
///
/// `sequence` is absent on some records (the skill's `references/rest-api.md`), and a date field can
/// be empty on a row, so a record that does not carry the field is skipped rather than sorted to
/// one end: this test is about the order of the values that exist.
List<Comparable<Object>> _valuesOf(List<NinoxRecord> records, String field) {
  final values = <Comparable<Object>>[];
  for (final record in records) {
    final value = switch (field) {
      _sequenceField => record.sequence,
      _dateField => record.fields[field],
      _ => record.fields[field],
    };
    if (value is Comparable<Object>) values.add(value);
  }
  return values;
}

void _expectSorted(
  List<Comparable<Object>> values, {
  required bool descending,
  required String what,
}) {
  for (var index = 1; index < values.length; index++) {
    final previous = values[index - 1];
    final current = values[index];
    final holds = descending
        ? previous.compareTo(current) >= 0
        : previous.compareTo(current) <= 0;
    expect(
      holds,
      isTrue,
      reason:
          'GAP-023: with $what the API returned $previous before $current, so `order`/`desc` '
          'do not sort this list. The reconciliation must page through recent records by '
          '`sequence` and filter in memory instead, and GAP-023 must be re-opened against this '
          'evidence (change proposal, GAP-023) — never assumed away.',
    );
  }
}
