import 'package:flutter_test/flutter_test.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/features/wizard/destination.dart';
import 'package:paperdrop/features/wizard/matching/type_rules.dart';

/// The hard type filter, row by row (design §5).
///
/// **One test per row of the two tables.** The second table below is the `ninox` skill's own list of
/// observed field types (`references/schema-and-fields.md`), every value of it, with the kind it may
/// bind and the reason it may not. A type that is not in the rules' table is never a candidate, which
/// is the row the filter has to get right for a field type nobody has met yet.
///
/// No test here needs a network, a token or a widget: this is arithmetic over names and type strings.
void main() {
  NinoxField field(
    String type, {
    String name = 'Belegdatum',
    String id = '1',
  }) => NinoxField(id: id, name: name, type: type);

  /// The skill's whole list, and the target kind each type may bind, or `null` for "no kind binds
  /// it" with the reason the rules' file gives.
  const List<(String, TargetKind?, String)>
  skillTypes = <(String, TargetKind?, String)>[
    ('string', TargetKind.string, 'writable text — the skill: send a string'),
    ('number', TargetKind.number, 'writable — a total or a tax amount'),
    ('date', TargetKind.date, 'writable — a YYYY-MM-DD string stored verbatim'),
    ('boolean', null, 'writable, and no core field is a boolean'),
    ('choice', null, 'writable, but the MVP maps no choice field (R1)'),
    ('multi', null, 'writable, but the MVP maps no choice field (R1)'),
    (
      'ref',
      null,
      'points at another table: not a value of the canonical model',
    ),
    ('rev', null, 'the reverse half of a relation'),
    ('phone', null, 'the skill treats it as unverified'),
    ('email', null, 'the skill treats it as unverified'),
    ('html', null, 'the skill treats it as unverified'),
    ('link', null, 'the skill treats it as unverified'),
    ('location', null, 'the skill treats it as unverified'),
    ('timeinterval', null, 'the skill treats it as unverified'),
    ('icon', null, 'the skill treats it as unverified'),
  ];

  for (final (String type, TargetKind? kind, String reason) in skillTypes) {
    test('the type table: `$type` binds '
        '${kind == null ? 'no kind' : '${kind.name} only'} — $reason', () {
      final NinoxField candidate = field(type);
      for (final CoreField coreField in CoreField.values) {
        final bool expected = kind != null
            ? targetKindByCoreField[coreField] == kind
            : false;
        expect(
          isTypeCandidate(coreField, candidate),
          expected,
          reason:
              '`$type` against ${coreField.wireName} '
              '(${targetKindByCoreField[coreField]!.name})',
        );
      }
    });
  }

  test('every mappable core field has a kind, and every kind binds a type', () {
    // A core field missing from the kind table would have no candidate at all, silently.
    expect(targetKindByCoreField.keys.toSet(), CoreField.values.toSet());
    for (final TargetKind kind in TargetKind.values) {
      expect(
        ninoxTypesByTargetKind[kind],
        isNotNull,
        reason: '${kind.name} binds nothing',
      );
      expect(ninoxTypesByTargetKind[kind], isNotEmpty);
    }
    // The three kinds of the MVP, and no fourth.
    expect(TargetKind.values, hasLength(3));
  });

  test('a type name nobody has met is never a candidate', () {
    // A field type added by a later Ninox version, or a name this project invented by mistake:
    // the filter answers no, which leaves the field for the user rather than guessing.
    for (final String unknown in <String>[
      'formula',
      'dateTime',
      'currency',
      'unknown',
      '',
    ]) {
      expect(
        isTypeCandidate(CoreField.docDate, field(unknown)),
        isFalse,
        reason: '`$unknown`',
      );
      expect(isTypeCandidate(CoreField.grossTotal, field(unknown)), isFalse);
      expect(isTypeCandidate(CoreField.supplierName, field(unknown)), isFalse);
    }
  });

  test('the filter reads the type and never the name', () {
    // The strongest name in the dictionary, on the wrong type: filtered out. Its own kind's field,
    // whatever it is called: kept. That is the whole of the first stage.
    final NinoxTable table = NinoxTable(
      id: 'table-1',
      name: 'Invoices',
      fields: <NinoxField>[
        field('string', name: 'Date', id: '1'),
        field('date', name: 'Anything at all', id: '2'),
      ],
    );

    expect(typeCandidates(CoreField.docDate, table), <NinoxField>[
      field('date', name: 'Anything at all', id: '2'),
    ]);
    expect(
      typeCandidates(CoreField.docDate, table).single.name,
      'Anything at all',
    );
  });

  test('the filter keeps the table\'s own order, and drops nothing else', () {
    final NinoxTable table = NinoxTable(
      id: 'table-1',
      name: 'Invoices',
      fields: <NinoxField>[
        field('string', name: 'Zweite', id: '1'),
        field('number', name: 'Betrag', id: '2'),
        field('string', name: 'Erste', id: '3'),
      ],
    );

    expect(
      typeCandidates(
        CoreField.supplierName,
        table,
      ).map((NinoxField candidate) => candidate.id),
      <String>['1', '3'],
    );
    // A kind with no field in the table has no candidate: an empty list, not an exception.
    expect(typeCandidates(CoreField.docDate, table), isEmpty);
  });
}
