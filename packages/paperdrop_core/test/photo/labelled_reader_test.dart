// The labelled reader, ported from the PO's App Cust prototype.
//
// Every sample here is synthetic. No real receipt, no real name, no real
// fiscal identifier: these are strings invented to look like what a Spanish
// printer emits. With Spain in force the expectations are the prototype's,
// unchanged.

import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final spain = ReceiptReaderFormat.fromCountryRow(CountryTable.es);

  const String fullTicket = '''
RESTAURANTE EJEMPLO S.L.
CIF: B12345678
FECHA: 12/03/2026
FACTURA SIMPLIFICADA
2 x MENU DEL DIA         24,00
BASE IMPONIBLE           24,00
IVA 10%                   2,40
TOTAL                    26,40
GRACIAS POR SU VISITA
''';

  const String onlyTotalAndRate = '''
SUPERMERCADO EJEMPLO
FECHA 04/03/26
IVA 21%
TOTAL                    12,10
''';

  const String cuotaButNoRate = '''
ESTACION DE SERVICIO EJEMPLO
FECHA: 15/07/2026
GASOIL A                  35,00
CUOTA IVA                  3,50
TOTAL                     38,50
''';

  const String noDateNoAmounts = '''
DOCUMENTO SIN DATOS LEGIBLES
TEXTO SUELTO
''';

  group('parseAmount', () {
    test('reads the Spanish grouping and decimal marks', () {
      expect(parseAmount('1.234,56', spain), 1234.56);
      expect(parseAmount('12,34', spain), 12.34);
      expect(parseAmount('1234.56', spain), 1234.56);
      expect(parseAmount('26,40 EUR', spain), 26.40);
    });

    test('never treats a bare integer as money', () {
      expect(amountsIn('IVA 21%', spain), isEmpty);
      expect(amountsIn('IVA 21% 3,45', spain), <double>[3.45]);
    });
  });

  group('parseDate', () {
    test('reads the Spanish order and expands a two digit year', () {
      expect(parseDate('FECHA: 12/03/2026', spain), '2026-03-12');
      expect(parseDate('4-3-26', spain), '2026-03-04');
      expect(parseDate('1.2.2026', spain), '2026-02-01');
    });

    test('swaps only when day and month cannot be told apart', () {
      expect(parseDate('2026/03/12', spain), isNull);
      expect(parseDate('03/12/2026', spain), '2026-12-03');
    });

    test('rejects a day that does not exist', () {
      expect(parseDate('31/02/2026', spain), isNull);
      expect(parseDate('no hay fecha aqui', spain), isNull);
    });

    test('survives the whitespace the camera inserts around a separator', () {
      expect(parseDate('FECHA: 20/09/ 2026', spain), '2026-09-20');
      expect(parseDate('20 / 09 / 2026', spain), '2026-09-20');
    });
  });

  group('parseReceipt', () {
    test('reads base, VAT and total when all three are printed', () {
      final r = parseReceipt(fullTicket, spain);
      expect(r.dateIso, '2026-03-12');
      expect(r.net.value, 24.00);
      expect(r.vat.value, 2.40);
      expect(r.gross.value, 26.40);
      expect(r.rate, 10);
      expect(r.net.isRead, isTrue);
      expect(r.vat.isRead, isTrue);
      expect(r.reconciles, isTrue);
    });

    test(
      'calculates from a rate the document itself declares, and says so',
      () {
        final r = parseReceipt(onlyTotalAndRate, spain);
        expect(r.dateIso, '2026-03-04');
        expect(r.net.value, 10.00);
        expect(r.vat.value, 2.10);
        expect(r.gross.value, 12.10);
        expect(r.net.isRead, isFalse);
        expect(r.vat.isRead, isFalse);
        expect(r.net.origin, contains('calculated'));
      },
    );

    test('derives by identity when the total and the VAT are printed', () {
      final r = parseReceipt(cuotaButNoRate, spain);
      expect(r.vat.value, 3.50);
      expect(r.vat.isRead, isTrue, reason: '3,50 is printed on the ticket');
      expect(r.net.value, 35.00);
      expect(r.net.origin, contains('derived'));
      expect(r.reconciles, isTrue);
    });

    test('invents nothing when the document carries nothing', () {
      final r = parseReceipt(noDateNoAmounts, spain);
      expect(r.dateIso, isNull);
      expect(r.net.has, isFalse);
      expect(r.vat.has, isFalse);
      expect(r.gross.has, isFalse);
      expect(r.reconciles, isNull);
    });

    test('prefers the line that says FECHA over a date printed elsewhere', () {
      final r = parseReceipt(
        'TICKET 01/01/2026\nFECHA: 12/03/2026\nTOTAL 10,00\n',
        spain,
      );
      expect(r.dateIso, '2026-03-12');
    });

    test('never mistakes a VAT line for the total', () {
      final r = parseReceipt(
        'FECHA: 01/01/2026\nIVA 21% 2,10\nTOTAL 12,10\n',
        spain,
      );
      expect(r.gross.value, 12.10);
      expect(r.vat.value, 2.10);
    });
  });

  group('the ticket read on the PO phone, 2026-09-28', () {
    const String realTicket =
        'FECHA: 20/09/2026\n'
        'TOTAL EUR 101,978IVA Base IVA21,008 84,273 17,697**';

    test('reads base and VAT out of the tabular breakdown', () {
      final r = parseReceipt(realTicket, spain);
      expect(r.net.value, 84.273);
      expect(r.vat.value, 17.697);
      expect(r.rate, 21);
      expect(r.net.isRead, isTrue, reason: 'both figures are printed');
      expect(r.vat.isRead, isTrue);
    });

    test('does not round the third decimal away', () {
      final r = parseReceipt(realTicket, spain);
      expect(r.net.value, isNot(84.27));
      expect(r.vat.value, isNot(17.70));
    });

    test(
      'the arithmetic the ticket must satisfy is what settles the columns',
      () {
        final r = parseReceipt(realTicket, spain);
        expect(r.net.value! * r.rate! / 100, closeTo(r.vat.value!, 0.05));
        expect(r.net.value! + r.vat.value!, closeTo(r.gross.value!, 0.02));
      },
    );

    test('reads the total, stray glyph and all, and it still reconciles', () {
      final r = parseReceipt(realTicket, spain);
      expect(r.gross.value, 101.978);
      expect(r.reconciles, isTrue);
    });

    test('settles the columns whatever order the ticket prints them in', () {
      final r = parseReceipt('Base IVA IVA\n84,273 17,697 21,008\n', spain);
      expect(r.net.value, 84.273);
      expect(r.vat.value, 17.697);
      expect(r.rate, 21);
    });

    test(
      'a lone IVA column beside Base is the rate, and the VAT is calculated',
      () {
        final r = parseReceipt('IVA Base\n21,00 84,27\n', spain);
        expect(r.net.value, 84.27);
        expect(r.rate, 21);
        expect(r.vat.value, 17.697);
        expect(r.vat.isRead, isFalse, reason: 'the paper prints no VAT amount');
        expect(r.vat.origin, contains('calculated'));
      },
    );

    test('a VAT-inclusive total claims no breakdown, and writes no zero', () {
      const String taxi =
          'TAXI DEL A.P.C DE MADRID\n'
          'NOMBRE EJEMPLO APELLIDO\n'
          'N° LICENCIA:  00000\n'
          'N.I.F.:  12345679S\n'
          'MATRICULA:  0000XXX\n'
          'FECHA:  26/09/26\n'
          'N RECIBO:  0000\n'
          'TOTAL(I/IVA) : 20.25 €\n'
          '** I.V.A. INCLUIDO **\n'
          'DIST. SERVICIO:  9,8 km\n';

      final r = parseReceipt(taxi, spain);

      expect(r.dateIso, '2026-09-26');
      expect(r.gross.value, 20.25);
      expect(r.vat.has, isFalse, reason: 'the 20,25 is the total, not the VAT');
      expect(
        r.net.has,
        isFalse,
        reason: 'nothing may be derived from a rate the ticket never declares',
      );
      expect(r.reconciles, isNull);
    });

    test('never derives a figure that cannot be right', () {
      final r = parseReceipt(
        'FECHA: 01/01/2026\nIVA 20,25\nTOTAL 20,25\n',
        spain,
      );
      expect(r.net.has, isFalse);
      expect(r.net.value, isNot(0.0));
    });

    test('reads a header whose columns carry a % and the word Total', () {
      const String restaurant =
          'RESTAURANTE EJEMPLO S.L.\n'
          'CIF: B00000000 10% IVA INCLUIDO\n'
          'Fecha 01/06/2026  15:45\n'
          '2  PAN CON TOMATE  2,90  5,80\n'
          '1  AGUA  3,50  3,50\n'
          'SUPLEMENTO TERRAZA:  5,13\n'
          'Base  % IVA  Total IVA\n'
          '97,94  10,00  9,79\n'
          'TOTAL  107,73 €\n';

      final r = parseReceipt(restaurant, spain);
      expect(r.net.value, 97.94);
      expect(r.vat.value, 9.79);
      expect(r.rate, 10);
      expect(r.gross.value, 107.73);
      expect(r.net.isRead, isTrue);
      expect(r.vat.isRead, isTrue);
      expect(r.reconciles, isTrue);
    });

    test('reads the whole tabular ticket, date included', () {
      const String onDevice =
          'MERCADONA EJEMPLO S.L.\n'
          'CIF: B12345678\n'
          'C/ MAYOR 1, MADRID\n'
          'FECHA: 20/09/ 2026\n'
          'ARTICULOS VARIOS  101,97\n'
          'TOTAL EUR  101,97\n'
          'IVA  Base  IVA\n'
          '21,00  84,273  17,697\n'
          'GRACIAS POR SU COMPRA\n';
      final r = parseReceipt(onDevice, spain);
      expect(r.dateIso, '2026-09-20');
      expect(r.net.value, 84.273);
      expect(r.vat.value, 17.697);
      expect(r.gross.value, 101.97);
      expect(r.rate, 21);
      expect(r.reconciles, isTrue);
    });
  });

  group('reading a breakdown the labels cannot reach', () {
    test('names and figures in different rows', () {
      const String invoice =
          'Tipo  Cantidad  P/U.  Descuento  Importe\n'
          '10.00%  12,00  0,00  12,00\n'
          '10.00%  12.00  0,00  12.00\n'
          'Total  13,53 €\n'
          'Tipo  Base imponible  Cuota  Total\n'
          '10%  12,30  1,23  13,53\n';

      final r = parseReceipt(invoice, spain);

      expect(r.net.value, 12.30);
      expect(r.vat.value, 1.23);
      expect(r.gross.value, 13.53);
      expect(r.rate, 10);
      expect(r.net.isRead, isTrue);
      expect(
        r.vat.isRead,
        isTrue,
        reason: '1,23 is printed on the paper, so it is read, not calculated',
      );
      expect(r.reconciles, isTrue);
    });

    test('the line items of an invoice are not its breakdown', () {
      final r = parseReceipt(
        '10.00%  12,00  0,00  12,00\n'
        '10.00%  12.00  0,00  12.00\n',
        spain,
      );

      expect(r.net.has, isFalse);
      expect(r.vat.has, isFalse);
      expect(r.reconciles, isNull);
    });

    test('a stray glyph between the header and its figures loses nothing', () {
      const String withGlyph =
          'FECHA: 01/06/2026\n'
          'Base  % IVA  Total |VA\n'
          '97,94  10,00  9,79\n'
          'TOTAL  107,73 €\n';

      final r = parseReceipt(withGlyph, spain);

      expect(r.net.value, 97.94);
      expect(r.net.isRead, isTrue);
      expect(r.rate, 10);
      expect(r.vat.value, 9.79);
      expect(
        r.vat.isRead,
        isFalse,
        reason:
            'the base and the total are printed; the VAT is derived from'
            ' total minus base, and the label says so',
      );
      expect(r.gross.value, 107.73);
      expect(r.reconciles, isTrue);
    });

    test('a restated total does not replace the invoice total', () {
      const String invoice =
          'Factura Total  EUR 53,90\n'
          'Tipo  Base imponible  Cuota  Total\n'
          '10%  49,00  4,90  53,90\n'
          'Total en  49,00  4,90\n';

      final r = parseReceipt(invoice, spain);

      expect(r.net.value, 49.00);
      expect(r.vat.value, 4.90);
      expect(r.totalCandidates, contains(49.00));
      expect(
        r.gross.value,
        53.90,
        reason: '49,00 + 4,90 is 53,90, which the invoice also prints',
      );
      expect(r.reconciles, isTrue);
    });
  });
}
