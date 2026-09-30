import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  group('inferDateOrder', () {
    test('[countries-languages/format-inference] '
        'a day greater than twelve resolves the order', () {
      expect(inferDateOrder(<String>['13.08.2026']), DateOrder.dmy);
      expect(
        parsePrintedDate('13.08.2026', DateOrder.dmy),
        CalendarDate(2026, 8, 13),
      );
    });

    test('a second component greater than twelve resolves mdy', () {
      expect(inferDateOrder(<String>['08/13/2026']), DateOrder.mdy);
      expect(
        parsePrintedDate('08/13/2026', DateOrder.mdy),
        CalendarDate(2026, 8, 13),
      );
    });

    test('four leading digits resolve ymd', () {
      expect(inferDateOrder(<String>['2026-08-13']), DateOrder.ymd);
      expect(
        parsePrintedDate('2026-08-13', DateOrder.ymd),
        CalendarDate(2026, 8, 13),
      );
    });

    test('nothing decisive returns null, never a default', () {
      expect(inferDateOrder(<String>['05.06.2026']), isNull);
      expect(inferDateOrder(<String>[]), isNull);
    });

    test('contradictory orders return null', () {
      expect(inferDateOrder(<String>['13.08.2026', '08/13/2026']), isNull);
    });
  });

  group('parsePrintedDate', () {
    test('rejects a two-digit year', () {
      expect(parsePrintedDate('13.08.26', DateOrder.dmy), isNull);
    });

    test('rejects an invalid calendar date', () {
      expect(parsePrintedDate('31.02.2026', DateOrder.dmy), isNull);
    });

    test('rejects mixed separators', () {
      expect(parsePrintedDate('13.08/2026', DateOrder.dmy), isNull);
    });
  });

  test('[countries-languages/launch-rows] the Spanish row uses a different date format', () {
    final es = CountryTable.es;
    final de = CountryTable.de;

    expect(es.dateOrder, DateOrder.dmy);
    expect(es.dateSeparator, '/');
    expect(de.dateOrder, DateOrder.dmy);
    expect(de.dateSeparator, '.');

    expect(
      parsePrintedDate('05/06/2026', es.dateOrder),
      CalendarDate(2026, 6, 5),
    );

    expect(_separatorOf('05/06/2026'), es.dateSeparator);
    expect(_separatorOf('05.06.2026'), de.dateSeparator);
    expect(_separatorOf('05.06.2026'), isNot(es.dateSeparator));
  });
}

String? _separatorOf(String printed) {
  for (final separator in <String>['.', '/', '-']) {
    if (printed.contains(separator)) {
      return separator;
    }
  }
  return null;
}
