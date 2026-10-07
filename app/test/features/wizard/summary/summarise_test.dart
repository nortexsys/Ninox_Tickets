import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/features/wizard/destination.dart';
import 'package:paperdrop/features/wizard/summary/summarise.dart';
import 'package:paperdrop/l10n/generated/app_localizations.dart';

/// The closing summary, as a function (design §6, FR-WIZ-008).
///
/// No widget, no file, no network: a destination goes in and the sentences the user will read come
/// out, which is what lets the three cases the design names — all of it mapped, some of it, none —
/// be pinned in the words themselves.
void main() {
  late AppLocalizations en;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Destination destinationWith(List<CoreField> mapped) => Destination(
    endpoint: NinoxEndpoint.cloud,
    teamId: 'team-1',
    databaseId: 'db-1',
    tableId: 'table-1',
    mappings: <FieldMapping>[
      for (final CoreField coreField in mapped)
        FieldMapping(
          coreField: coreField,
          ninoxFieldId: 'field-1',
          ninoxFieldName: 'Column',
        ),
    ],
  );

  test('[setup-wizard/plain-language-summary-and-first-document-offer] '
      'the summary names the mapped and the unmapped fields', () {
    final SummaryText summary = summarise(
      destinationWith(<CoreField>[CoreField.docDate, CoreField.grossTotal]),
      en,
    );

    // What will be saved, named in plain language, and what will not — both stated, neither left
    // to be discovered.
    expect(summary.mapped, <CoreField>[
      CoreField.docDate,
      CoreField.grossTotal,
    ]);
    expect(summary.unmapped, hasLength(CoreField.values.length - 2));
    expect(summary.lines, hasLength(2));

    final String said = summary.lines.join(' ');
    expect(said, contains(en.wizardFieldDocDate));
    expect(said, contains(en.wizardFieldGrossTotal));
    expect(said, contains(en.wizardFieldSupplierName));
    expect(said, contains(en.wizardFieldTaxTotal));
    expect(summary.isEverythingMapped, isFalse);
    expect(summary.isNothingMapped, isFalse);

    // Plain language rather than keys: no canonical name is shown to anybody.
    for (final CoreField coreField in CoreField.values) {
      expect(said, isNot(contains(coreField.wireName)), reason: coreField.name);
    }
  });

  test('everything mapped says what will be saved and nothing about what will '
      'not', () {
    final SummaryText summary = summarise(
      destinationWith(CoreField.values),
      en,
    );

    expect(summary.lines, hasLength(1));
    expect(summary.lines.single, contains(en.wizardFieldCurrency));
    expect(summary.unmapped, isEmpty);
    expect(summary.isEverythingMapped, isTrue);
  });

  test('[setup-wizard/no-mapping-is-mandatory] the consequence is stated, not implied', () {
    // The requirement's own case: the document is attached to an otherwise empty record, and the
    // summary says so instead of leaving it to be discovered.
    final SummaryText summary = summarise(destinationWith(<CoreField>[]), en);

    expect(summary.isNothingMapped, isTrue);
    expect(summary.mapped, isEmpty);
    expect(summary.unmapped, CoreField.values);
    expect(summary.lines, <String>[en.wizardSummaryNothingMapped]);
    expect(summary.lines.single, contains('no data'));
    expect(summary.lines.single, isNot(contains('will save')));
  });

  test('one field mapped is a case of its own', () {
    final SummaryText summary = summarise(
      destinationWith(<CoreField>[CoreField.docNumber]),
      en,
    );

    expect(summary.mapped, <CoreField>[CoreField.docNumber]);
    expect(summary.lines.first, contains(en.wizardFieldDocNumber));
    expect(summary.lines.last, contains(en.wizardFieldSupplierTaxId));
  });

  test('the same destination always says the same thing', () {
    final Destination destination = destinationWith(<CoreField>[
      CoreField.netTotal,
    ]);

    expect(summarise(destination, en).lines, summarise(destination, en).lines);
  });
}
