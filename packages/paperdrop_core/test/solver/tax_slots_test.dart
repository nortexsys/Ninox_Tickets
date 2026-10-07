import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final eur = CurrencyCode.parse('EUR')!;
  final es = CountryTable.es;
  final de = CountryTable.de;

  PositionedWord word(String text, int x0, int x1, int top, int bottom) =>
      PositionedWord(text, x0, x1, top, bottom);

  ReadOperand amount(OperandRole role, int minor) => ReadOperand.amount(
    role: role,
    amount: Money(minor, eur),
    words: [word('x', 0, 10, 0, 10)],
    pageIndex: 0,
  );

  ReadOperand rate(int bp) => ReadOperand.rate(
    rate: RateBp(bp),
    words: [word('$bp%', 0, 10, 0, 10)],
    pageIndex: 0,
  );

  test('one slot per printed rate, empty slots stay empty', () {
    final slots = buildTaxSlots(
      bases: [amount(OperandRole.base, 10000), amount(OperandRole.base, 5000)],
      taxes: [amount(OperandRole.tax, 1900), amount(OperandRole.tax, 350)],
      grosses: const <ReadOperand>[],
      admittedRates: [rate(1900), rate(700)],
      country: de,
    );

    expect(slots, hasLength(3));
    expect(
      slots[0].rate,
      Present<RateBp>(RateBp(1900), Provenance.read, ConfidenceState.amber),
    );
    expect(
      slots[0].base,
      Present<Money>(Money(10000, eur), Provenance.read, ConfidenceState.amber),
    );
    expect(
      slots[0].amount,
      Present<Money>(Money(1900, eur), Provenance.read, ConfidenceState.amber),
    );
    expect(
      slots[1].rate,
      Present<RateBp>(RateBp(700), Provenance.read, ConfidenceState.amber),
    );
    expect(
      slots[1].base,
      Present<Money>(Money(5000, eur), Provenance.read, ConfidenceState.amber),
    );
    expect(
      slots[1].amount,
      Present<Money>(Money(350, eur), Provenance.read, ConfidenceState.amber),
    );
    expect(slots[2].rate, const Absent<RateBp>());
    expect(slots[2].base, const Absent<Money>());
    expect(slots[2].amount, const Absent<Money>());
  });

  test('tax_total is the sum of printed tax amounts', () {
    final page = TextPage(0, 300000, 400000, [
      word('BASE', 100000, 120000, 100000, 120000),
      word('100,00', 130000, 160000, 100000, 120000),
      word('IVA', 100000, 120000, 140000, 160000),
      word('19,00', 130000, 160000, 140000, 160000),
      word('BASE', 100000, 120000, 180000, 200000),
      word('50,00', 130000, 160000, 180000, 200000),
      word('IVA', 100000, 120000, 220000, 240000),
      word('3,50', 130000, 160000, 220000, 240000),
      word('TOTAL', 100000, 120000, 260000, 280000),
      word('172,50', 130000, 170000, 260000, 280000),
      word('19', 100000, 110000, 300000, 320000),
      word('%', 115000, 125000, 300000, 320000),
      word('7', 100000, 110000, 340000, 360000),
      word('%', 115000, 125000, 340000, 360000),
    ]);

    final result = solveAmounts(
      pages: [page],
      country: de,
      table: CountryTable.launch,
    );

    expect(result.taxSlots, hasLength(3));
    expect(result.taxSlots[2].rate, const Absent<RateBp>());
    expect(
      result.taxTotal,
      Present<Money>(Money(2250, eur), Provenance.read, ConfidenceState.amber),
    );
  });

  test('every produced value carries one of the four provenance tags', () {
    final page = TextPage(0, 300000, 300000, [
      word('TOTAL', 100000, 120000, 100000, 120000),
      word('121,00', 130000, 160000, 100000, 120000),
      word('BASE', 100000, 120000, 140000, 160000),
      word('100,00', 130000, 160000, 140000, 160000),
      word('IVA', 100000, 120000, 180000, 200000),
      word('21,00', 130000, 160000, 180000, 200000),
      word('21', 100000, 110000, 220000, 240000),
      word('%', 115000, 125000, 220000, 240000),
    ]);

    final result = solveAmounts(
      pages: [page],
      country: es,
      table: CountryTable.launch,
    );

    final values = <FieldValue<Object?>>[
      result.currency,
      result.grossTotal,
      result.netTotal,
      result.taxTotal,
      for (final slot in result.taxSlots) ...<FieldValue<Object?>>[
        slot.rate,
        slot.base,
        slot.amount,
      ],
      for (final surcharge in result.surcharges) surcharge.amount,
    ];

    for (final value in values) {
      if (value is Present<Object?>) {
        expect(Provenance.values, contains(value.provenance));
      }
    }
  });

  test('a multi-page input yields one value per field', () {
    final firstPage = TextPage(0, 300000, 300000, [
      word('BASE', 100000, 120000, 100000, 120000),
      word('100,00', 130000, 160000, 100000, 120000),
      word('IVA', 100000, 120000, 140000, 160000),
      word('21,00', 130000, 160000, 140000, 160000),
      word('21', 100000, 110000, 180000, 200000),
      word('%', 115000, 125000, 180000, 200000),
    ]);
    final secondPage = TextPage(1, 300000, 300000, [
      word('TOTAL', 100000, 120000, 100000, 120000),
      word('121,00', 130000, 160000, 100000, 120000),
    ]);

    final result = solveAmounts(
      pages: [firstPage, secondPage],
      country: es,
      table: CountryTable.launch,
    );

    expect(
      result.grossTotal,
      Present<Money>(Money(12100, eur), Provenance.read, ConfidenceState.amber),
    );
    expect(
      result.netTotal,
      Present<Money>(Money(10000, eur), Provenance.read, ConfidenceState.amber),
    );
    expect(
      result.taxTotal,
      Present<Money>(Money(2100, eur), Provenance.read, ConfidenceState.amber),
    );
    expect(
      result.currency,
      Present<CurrencyCode>(eur, Provenance.read, ConfidenceState.amber),
    );
  });
}
