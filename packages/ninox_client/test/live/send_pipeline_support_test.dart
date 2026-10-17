/// The pure helpers of the T1.11 live run, proved **without a token**.
///
/// `send_pipeline_live_test.dart` runs once, on the product owner's machine, and cannot be the only
/// thing that has ever exercised the payload builder or the read-back comparison: a helper that is
/// first tried during a live write is a helper whose failure costs a record in someone's table. So
/// this file runs in every lane and in every CI run (change design §4) and covers the three things
/// the live run depends on:
///
/// * the payload is built **only** from fields the resolved schema shows, by their current names,
///   with the date as `YYYY-MM-DD` and the amount as an integer — and a formula field is never a
///   write target (`ninox-send/payload-shape`, FR-SND-002; SPIKE_GAP-022);
/// * a date that is not a real calendar date refuses the run rather than reaching the API;
/// * the read-back comparison reports what disagrees by **field name**, and never repeats a value —
///   which is what keeps the results file free of a record's contents (`ninox-send/create-attach-read-back`,
///   FR-SND-001; change design §2.4).
///
/// Nothing here reaches the network, reads the environment or writes a file.
library;

import 'dart:convert';

import 'package:ninox_client/ninox_client.dart';
import 'package:test/test.dart';

import 'send_pipeline_support.dart';

void main() {
  group('the payload of the live send', () {
    test('it targets the date and the amount by their current names, and nothing else', () {
      final SendPayload payload = buildSendPayload(_efSchema());

      expect(payload.keys, <String>['Fecha', 'Importe']);
      expect(payload.dateField, 'Fecha');
      expect(payload.amountField, 'Importe');
      expect(payload.fieldCount, 2);
    });

    test(
      'the date is the invented YYYY-MM-DD string, and a real calendar date',
      () {
        final SendPayload payload = buildSendPayload(_efSchema());

        expect(payload.fieldsByName['Fecha'], inventedDate);
        expect(payload.fieldsByName['Fecha'], isA<String>());
        expect(isIsoDate(inventedDate), isTrue);
      },
    );

    test('the amount is an integer in the minor unit, never a decimal', () {
      final SendPayload payload = buildSendPayload(_efSchema());
      final Object? amount = payload.fieldsByName['Importe'];

      // ADR-004: an amount that round-trips through a binary float can come back a cent wrong, so
      // the payload carries an integer and the comparison below is about the type, not the value.
      expect(amount, isA<int>());
      expect(amount, inventedAmount);
      expect(amount, isNot(isA<double>()));
    });

    test('the body cannot be changed after it is built', () {
      final SendPayload payload = buildSendPayload(_efSchema());

      expect(
        () => payload.fieldsByName['Importe'] = 1,
        throwsUnsupportedError,
        reason:
            'what was sent is what the read-back is compared with: nothing may change the map '
            'between the two',
      );
    });

    test('a field the table does not show refuses the run, and another column is not chosen', () {
      final List<NinoxField> fields = <NinoxField>[
        _field('Importe', 'number'),
        _field('Texto', 'string'),
      ];

      expect(
        () => buildSendPayload(fields),
        throwsA(
          isA<StateError>()
              .having(
                (StateError e) => e.message,
                'message',
                contains('no field called "Fecha"'),
              )
              .having(
                (StateError e) => e.message,
                'message',
                contains('Nothing was written'),
              ),
        ),
      );
    });

    test('a field of another type refuses the run', () {
      final List<NinoxField> fields = <NinoxField>[
        _field('Fecha', 'string'),
        _field('Importe', 'number'),
      ];

      expect(
        () => buildSendPayload(fields),
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            contains('is a "string" and not a date'),
          ),
        ),
      );
    });

    test('a formula field is never a write target', () {
      final List<NinoxField> fields = <NinoxField>[
        _field('Fecha', 'date'),
        _field('Importe', 'number'),
        _field('Total con IVA', 'fn'),
      ];

      // The `fn` marker is what identifies a formula field (SPIKE_GAP-022), and writing one
      // answers HTTP 500, which the retry matrix reports as a mapping error.
      expect(isFormulaField(_field('Total con IVA', 'fn')), isTrue);
      expect(isFormulaField(_field('Importe', 'number')), isFalse);
      expect(
        writableFields(fields).map((NinoxField field) => field.name),
        <String>['Fecha', 'Importe'],
      );
    });

    test(
      'a formula field elsewhere in the schema is skipped rather than sent',
      () {
        final SendPayload payload = buildSendPayload(<NinoxField>[
          ..._efSchema(),
          _field('Total con IVA', 'fn'),
        ]);

        expect(payload.keys, isNot(contains('Total con IVA')));
        expect(payload.fieldCount, 2);
      },
    );

    test(
      'a payload that would have to write a formula field refuses the run',
      () {
        expect(
          () => buildSendPayload(<NinoxField>[
            _field('Fecha', 'date'),
            _field('Importe', 'fn'),
          ]),
          throwsA(
            isA<StateError>()
                .having(
                  (StateError e) => e.message,
                  'message',
                  contains('is a formula field (the `fn` marker)'),
                )
                .having(
                  (StateError e) => e.message,
                  'message',
                  contains('Nothing was written'),
                ),
          ),
        );
      },
    );

    test('the schema, described as one sentence, names fields and types and no value', () {
      final String described = describeFields(_efSchema());

      expect(
        described,
        'id (number), Fecha (date), Importe (number), Texto (string)',
      );
      expect(described, isNot(contains(inventedDate)));
    });

    test('the payload describes a shape, never a value', () {
      final SendPayload payload = buildSendPayload(_efSchema());

      expect('$payload', contains('Fecha'));
      expect('$payload', contains('Importe'));
      expect('$payload', isNot(contains(inventedDate)));
      expect('$payload', isNot(contains('$inventedAmount')));
    });
  });

  group('a date before it is sent', () {
    test('YYYY-MM-DD that names a day is a calendar date', () {
      expect(isIsoDate('2026-10-17'), isTrue);
      expect(isIsoDate('2024-02-29'), isTrue);
    });

    test('everything else is not, including the shapes that look like one', () {
      expect(isIsoDate(''), isFalse);
      expect(isIsoDate('2026-1-1'), isFalse);
      expect(isIsoDate('17/10/2026'), isFalse);
      expect(isIsoDate('2026-02-30'), isFalse, reason: 'February has no 30th');
      expect(
        isIsoDate('2026-13-01'),
        isFalse,
        reason: 'there is no thirteenth month',
      );
      expect(
        isIsoDate('2026-10-17T00:00:00'),
        isFalse,
        reason: 'that is a stamp, not a date',
      );
    });
  });

  group('the read-back comparison', () {
    test('it agrees when the stored values and the file are what was sent', () {
      final ReadBackCheck check = _check(
        stored: <String, Object?>{
          'Fecha': inventedDate,
          'Importe': inventedAmount,
        },
      );

      expect(check.differences, isEmpty);
      expect(check.allMatch, isTrue);
      expect(check.checkedFieldCount, 2);
      expect(check.fileCount, 1);
      expect(check.fileFound, isTrue);
    });

    test('a stored date that is an ISO-8601 stamp of the same day is the date that was sent', () {
      final ReadBackCheck check = _check(
        stored: <String, Object?>{
          'Fecha': '${inventedDate}T00:00:00',
          'Importe': inventedAmount,
        },
      );

      expect(check.allMatch, isTrue, reason: check.differences.join(' | '));
    });

    test(
      'an amount that came back as a decimal is the amount that was sent',
      () {
        final ReadBackCheck check = _check(
          stored: <String, Object?>{
            'Fecha': inventedDate,
            'Importe': inventedAmount.toDouble(),
          },
        );

        // Compared numerically, the same way the reconciliation compares a candidate: `1999` and
        // `1999.0` are one amount, and reading them as two would report a fault that is not there.
        expect(check.allMatch, isTrue);
      },
    );

    test('a field the read-back does not carry is named', () {
      final ReadBackCheck check = _check(
        stored: <String, Object?>{'Importe': inventedAmount},
      );

      expect(check.fieldsNotStored, <String>['Fecha']);
      expect(check.fieldsThatDiffer, isEmpty);
      expect(check.allMatch, isFalse);
      expect(check.differences.single, contains('"Fecha"'));
    });

    test(
      'a value the destination overrode is named, and neither value is quoted',
      () {
        final ReadBackCheck check = _check(
          stored: <String, Object?>{'Fecha': inventedDate, 'Importe': 2049},
        );

        expect(check.fieldsThatDiffer, <String>['Importe']);
        expect(check.fieldsNotStored, isEmpty);
        expect(check.allMatch, isFalse);
        expect(check.differences.single, contains('"Importe"'));
        // The read-back is the evidence, so the results file must not become a copy of the record.
        expect(check.differences.single, isNot(contains('2049')));
        expect(check.differences.single, isNot(contains('$inventedAmount')));
        expect(_encodable(check), isNot(contains('2049')));
        expect(_encodable(check), isNot(contains('$inventedAmount')));
        expect(_encodable(check), isNot(contains(inventedDate)));
      },
    );

    test(
      'an attachment that is not there is reported, and no value is quoted',
      () {
        final ReadBackCheck check = _check(
          stored: <String, Object?>{
            'Fecha': inventedDate,
            'Importe': inventedAmount,
          },
          files: const <NinoxFile>[],
        );

        expect(check.fileFound, isFalse);
        expect(check.fileCount, 0);
        expect(check.allMatch, isFalse);
        expect(check.differences.single, contains('no attachment'));
        expect(_encodable(check), isNot(contains(inventedFilename)));
      },
    );

    test(
      'an attachment of another size or another content type is reported',
      () {
        final ReadBackCheck small = _check(
          stored: <String, Object?>{
            'Fecha': inventedDate,
            'Importe': inventedAmount,
          },
          files: <NinoxFile>[
            const NinoxFile(
              name: inventedFilename,
              size: 7,
              contentType: inventedContentType,
            ),
          ],
        );
        final ReadBackCheck mistyped = _check(
          stored: <String, Object?>{
            'Fecha': inventedDate,
            'Importe': inventedAmount,
          },
          files: <NinoxFile>[
            const NinoxFile(
              name: inventedFilename,
              size: documentSize,
              contentType: 'application/octet-stream',
            ),
          ],
        );

        expect(small.sizeMatches, isFalse);
        expect(small.differences.single, contains('size'));
        expect(mistyped.contentTypeMatches, isFalse);
        expect(mistyped.differences.single, contains('content type'));
      },
    );

    test(
      'another attachment under another name does not count as the document',
      () {
        final ReadBackCheck check = _check(
          stored: <String, Object?>{
            'Fecha': inventedDate,
            'Importe': inventedAmount,
          },
          files: <NinoxFile>[
            const NinoxFile(
              name: 'another-document.pdf',
              size: documentSize,
              contentType: inventedContentType,
            ),
          ],
        );

        expect(check.fileCount, 1);
        expect(check.fileFound, isFalse);
        expect(check.allMatch, isFalse);
      },
    );
  });
}

/// The size the live run's synthetic document is generated at, restated here so this file does not
/// depend on the live test's private constants.
const int documentSize = 64 * 1024;

/// A schema shaped like the disposable `EF` table: a serial identifier, a date, a number and a text
/// column, with the names the approved contract writes.
List<NinoxField> _efSchema() => <NinoxField>[
  _field('id', 'number', id: '1'),
  _field('Fecha', 'date', id: '2'),
  _field('Importe', 'number', id: '3'),
  _field('Texto', 'string', id: '4'),
];

/// One field, so that a test states the name and the type it is about.
NinoxField _field(String name, String type, {String id = 'field'}) =>
    NinoxField(id: id, name: name, type: type);

/// The read-back of the live send's record, with [stored] and a document unless [files] is given.
ReadBackCheck _check({
  required Map<String, Object?> stored,
  List<NinoxFile>? files,
}) => ReadBackCheck.of(
  sent: buildSendPayload(_efSchema()).fieldsByName,
  readBack: NinoxRecord(id: const RecordId('1'), fields: stored),
  files:
      files ??
      <NinoxFile>[
        const NinoxFile(
          name: inventedFilename,
          size: documentSize,
          contentType: inventedContentType,
        ),
      ],
  filename: inventedFilename,
  size: documentSize,
  contentType: inventedContentType,
  dateField: dateFieldName,
);

/// The check as the results file would carry it, so that "no value in it" can be asserted.
String _encodable(ReadBackCheck check) => jsonEncode(check.toJson());
