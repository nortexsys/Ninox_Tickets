import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final eur = CurrencyCode.parse('EUR')!;
  final es = CountryTable.es;

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

  group('solveBreakdown', () {
    test('[extraction-pipeline/read-all-printed-quantities-before-deriving] '
        'three printed quantities are read, none derived', () {
      final solution = solveBreakdown(
        bases: [amount(OperandRole.base, 10000)],
        taxes: [amount(OperandRole.tax, 2100)],
        grosses: [amount(OperandRole.gross, 12100)],
        admittedRates: [rate(2100)],
      );

      expect(
        solution.base,
        Present<Money>(
          Money(10000, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(
        solution.tax,
        Present<Money>(
          Money(2100, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(
        solution.gross,
        Present<Money>(
          Money(12100, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
    });

    test('identical triples count once', () {
      final solution = solveBreakdown(
        bases: [
          amount(OperandRole.base, 10000),
          amount(OperandRole.base, 10000),
        ],
        taxes: [amount(OperandRole.tax, 2100)],
        grosses: [amount(OperandRole.gross, 12100)],
        admittedRates: [rate(2100)],
      );

      expect(
        solution.gross,
        Present<Money>(
          Money(12100, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
    });

    test('several accepted triples leave the roles empty', () {
      final solution = solveBreakdown(
        bases: [
          amount(OperandRole.base, 10000),
          amount(OperandRole.base, 20000),
        ],
        taxes: [amount(OperandRole.tax, 2100), amount(OperandRole.tax, 4200)],
        grosses: [
          amount(OperandRole.gross, 12100),
          amount(OperandRole.gross, 24200),
        ],
        admittedRates: [rate(2100)],
      );

      expect(solution.base, const Absent<Money>());
      expect(solution.tax, const Absent<Money>());
      expect(solution.gross, const Absent<Money>());
    });

    test('no accepted triple derives nothing', () {
      final solution = solveBreakdown(
        bases: const <ReadOperand>[],
        taxes: const <ReadOperand>[],
        grosses: [amount(OperandRole.gross, 12100)],
        admittedRates: const <ReadOperand>[],
      );

      expect(solution.base, const Absent<Money>());
      expect(solution.tax, const Absent<Money>());
      expect(solution.gross, const Absent<Money>());
    });

    test('[extraction-pipeline/read-all-printed-quantities-before-deriving] '
        'two printed quantities permit one derivation by identity', () {
      final solution = solveBreakdown(
        bases: [amount(OperandRole.base, 10000)],
        taxes: const <ReadOperand>[],
        grosses: [amount(OperandRole.gross, 12100)],
        admittedRates: [rate(2100)],
      );

      expect(
        solution.base,
        Present<Money>(
          Money(10000, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(
        solution.tax,
        Present<Money>(
          Money(2100, eur),
          Provenance.derived,
          ConfidenceState.amber,
        ),
      );
      expect(
        solution.gross,
        Present<Money>(
          Money(12100, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
    });

    test('[extraction-pipeline/derive-by-identity-never-invent-a-rate] '
        'a total with no printed rate yields no breakdown', () {
      final solution = solveBreakdown(
        bases: [amount(OperandRole.base, 10000)],
        taxes: const <ReadOperand>[],
        grosses: [amount(OperandRole.gross, 12100)],
        admittedRates: const <ReadOperand>[],
      );

      expect(solution.base, const Absent<Money>());
      expect(solution.tax, const Absent<Money>());
      expect(solution.gross, const Absent<Money>());
    });
  });

  group('solveAmounts', () {
    test('reads a consistent synthetic page', () {
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

      expect(
        result.grossTotal,
        Present<Money>(
          Money(12100, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(
        result.netTotal,
        Present<Money>(
          Money(10000, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(
        result.taxTotal,
        Present<Money>(
          Money(2100, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
    });

    test('derives exactly one missing operand, tagged derived', () {
      final page = TextPage(0, 300000, 300000, [
        word('TOTAL', 100000, 120000, 100000, 120000),
        word('121,00', 130000, 160000, 100000, 120000),
        word('IVA', 100000, 120000, 140000, 160000),
        word('21,00', 130000, 160000, 140000, 160000),
        word('21', 100000, 110000, 180000, 200000),
        word('%', 115000, 125000, 180000, 200000),
      ]);

      final result = solveAmounts(
        pages: [page],
        country: es,
        table: CountryTable.launch,
      );

      expect(
        result.grossTotal,
        Present<Money>(
          Money(12100, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(
        result.taxTotal,
        Present<Money>(
          Money(2100, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
      expect(
        result.netTotal,
        Present<Money>(
          Money(10000, eur),
          Provenance.derived,
          ConfidenceState.amber,
        ),
      );
    });

    test('keeps the printed tax without deriving a breakdown', () {
      final page = TextPage(0, 300000, 300000, [
        word('TOTAL', 100000, 120000, 100000, 120000),
        word('121,00', 130000, 160000, 100000, 120000),
        word('IVA', 100000, 120000, 140000, 160000),
        word('21,00', 130000, 160000, 140000, 160000),
      ]);

      final result = solveAmounts(
        pages: [page],
        country: es,
        table: CountryTable.launch,
      );

      expect(result.grossTotal, const Absent<Money>());
      expect(result.netTotal, const Absent<Money>());
      expect(
        result.taxTotal,
        Present<Money>(
          Money(2100, eur),
          Provenance.read,
          ConfidenceState.amber,
        ),
      );
    });
  });
}
