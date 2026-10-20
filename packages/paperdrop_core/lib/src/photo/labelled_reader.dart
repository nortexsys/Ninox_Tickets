/// The labelled photo reader, ported from the PO's App Cust prototype.
///
/// The logic is copied as it is; only the country parameters are threaded
/// through. The prototype's Spanish constants are replaced by a
/// [ReceiptReaderFormat] built from a [CountryRow]:
///
///  * [DecimalConvention] drives [parseAmount] and [moneyPattern];
///  * [DateOrder] drives [parseDate], keeping the prototype's whitespace
///    tolerance and its swap-only-when-ambiguous rule;
///  * the row's legal rates replace `kLegalSpanishRates`;
///  * the row's currency is carried for the caller that turns the reader's
///    `double` results into `Money`;
///  * the label words come from [photoReaderLabelTerms], Spain's list being
///    exactly the words the prototype uses.
library;

import '../countries/country_table.dart';
import '../dictionaries/labels.dart';
import '../format/date.dart';
import '../format/decimal.dart';
import '../money/currency.dart';

/// The label vocabulary the labelled reader matches.
class ReceiptReaderVocabulary {
  /// Words that bind the printed total.
  final Set<String> totalWords;

  /// Words that bind the taxable base.
  final Set<String> baseWords;

  /// Words that bind the tax amount.
  final Set<String> vatWords;

  /// Words that can announce a printed rate (`IVA`, `TIPO` for Spain).
  final Set<String> rateWords;

  /// Words that can open a table header run.
  final Set<String> headerWords;

  /// The date word a line must contain to win over other dates (`FECHA`).
  final String dateWord;

  /// Creates a vocabulary. Every set is copied into an unmodifiable set.
  ReceiptReaderVocabulary({
    required Set<String> totalWords,
    required Set<String> baseWords,
    required Set<String> vatWords,
    required Set<String> rateWords,
    required Set<String> headerWords,
    required this.dateWord,
  }) : totalWords = _unmodifiable(totalWords),
       baseWords = _unmodifiable(baseWords),
       vatWords = _unmodifiable(vatWords),
       rateWords = _unmodifiable(rateWords),
       headerWords = _unmodifiable(headerWords);

  /// An empty vocabulary: the labelled reader binds no label.
  static final ReceiptReaderVocabulary none = ReceiptReaderVocabulary(
    totalWords: <String>{},
    baseWords: <String>{},
    vatWords: <String>{},
    rateWords: <String>{},
    headerWords: <String>{},
    dateWord: '',
  );
}

Set<String> _unmodifiable(Set<String> values) =>
    Set<String>.unmodifiable(values);

/// The country parameters the two photo readers consume.
class ReceiptReaderFormat {
  /// The printed decimal convention.
  final DecimalConvention decimalConvention;

  /// The printed date order.
  final DateOrder dateOrder;

  /// The printed date separator declared by the row.
  final String dateSeparator;

  /// The legal rates as whole percentage points (`21`, `10`, `4`, `0` for
  /// Spain). The readers use whole percentages exactly as the prototype does.
  final Set<int> legalRates;

  /// The currency declared by the row.
  final CurrencyCode currency;

  /// The label vocabulary the labelled reader matches.
  final ReceiptReaderVocabulary vocabulary;

  /// Creates a reader format.
  ReceiptReaderFormat({
    required this.decimalConvention,
    required this.dateOrder,
    required this.dateSeparator,
    required Set<int> legalRates,
    required this.currency,
    required this.vocabulary,
  }) : legalRates = Set<int>.unmodifiable(legalRates);

  /// Builds the format a country row supplies.
  factory ReceiptReaderFormat.fromCountryRow(CountryRow row) {
    return ReceiptReaderFormat(
      decimalConvention: row.decimalConvention,
      dateOrder: row.dateOrder,
      dateSeparator: row.dateSeparator,
      legalRates: row.legalRates.map((rate) => rate.bp ~/ 100).toSet(),
      currency: row.currency,
      vocabulary: _vocabularyForCountry(row),
    );
  }
}

/// Builds the reader vocabulary a country row supplies.
///
/// Spain is the exact prototype vocabulary; any other row gets an empty
/// vocabulary, so the labelled reader contributes no labelled amount for it
/// and the vocabulary-free arithmetic reader still applies.
ReceiptReaderVocabulary _vocabularyForCountry(CountryRow row) {
  if (row.countryCode == 'ES') {
    final byRole = <PhotoReaderRole, Set<String>>{};
    for (final term in photoReaderLabelTerms) {
      if (term.languages.contains('es')) {
        (byRole[term.role] ??= <String>{}).add(term.term);
      }
    }
    final totalWords = byRole[PhotoReaderRole.total] ?? const <String>{};
    final baseWords = byRole[PhotoReaderRole.base] ?? const <String>{};
    final vatWords = byRole[PhotoReaderRole.vat] ?? const <String>{};
    final rateWords = byRole[PhotoReaderRole.rate] ?? const <String>{};
    final dateWords = byRole[PhotoReaderRole.date] ?? const <String>{};
    return ReceiptReaderVocabulary(
      totalWords: totalWords,
      baseWords: baseWords,
      vatWords: vatWords,
      rateWords: rateWords,
      headerWords: <String>{
        ...baseWords,
        ...vatWords,
        ...rateWords,
        if (totalWords.contains('TOTAL')) 'TOTAL',
      },
      dateWord: dateWords.isEmpty ? '' : dateWords.first,
    );
  }
  return ReceiptReaderVocabulary.none;
}

/// One value the labelled reader produced, with its origin.
class ReceiptValue {
  /// The value, when one was produced.
  final double? value;

  /// Where the value came from (`read`, `calculated ...`, `derived ...`,
  /// `proposed ...` or `none`).
  final String origin;

  /// Creates a receipt value.
  const ReceiptValue(this.value, this.origin);

  /// Whether this value was read off the paper.
  bool get isRead => origin == 'read';

  /// Whether a value is present.
  bool get has => value != null;

  /// The absent value.
  static const ReceiptValue none = ReceiptValue(null, 'none');
}

/// The labelled reader's answer for one document.
class Receipt {
  /// The text the reader ran over.
  final String rawText;

  /// The date as `YYYY-MM-DD`, when one was read.
  final String? dateIso;

  /// Where the date came from.
  final String dateOrigin;

  /// The net amount.
  final ReceiptValue net;

  /// The VAT amount.
  final ReceiptValue vat;

  /// The gross total.
  final ReceiptValue gross;

  /// The printed rate, when one was read.
  final double? rate;

  /// Every printed total candidate, in reading order.
  final List<double> totalCandidates;

  /// Creates a receipt.
  const Receipt({
    required this.rawText,
    required this.dateIso,
    required this.dateOrigin,
    required this.net,
    required this.vat,
    required this.gross,
    required this.rate,
    required this.totalCandidates,
  });

  /// True when net + vat adds up to the printed total, within a cent.
  bool? get reconciles {
    if (net.value == null || vat.value == null || gross.value == null) {
      return null;
    }
    return ((net.value! + vat.value!) - gross.value!).abs() <= 0.02;
  }
}

/// Spanish tickets print two or three decimals. Three is not a typo and must
/// not be rounded away: `84,273` and `17,697` are the numbers on the paper.
double roundMoney(double v) => (v * 1000).roundToDouble() / 1000;

/// Parses a printed amount under [format]'s decimal convention.
double? parseAmount(String raw, ReceiptReaderFormat format) {
  var t = raw.replaceAll(RegExp(r'[^0-9,.]'), '');
  if (t.isEmpty) {
    return null;
  }

  if (format.decimalConvention == DecimalConvention.commaDecimal) {
    if (t.contains(',')) {
      t = t.replaceAll('.', '').replaceAll(',', '.');
    } else {
      final m = RegExp(r'\.(\d+)$').firstMatch(t);
      if (m != null && m.group(1)!.length == 3) {
        t = t.replaceAll('.', '');
      }
    }
  } else {
    if (t.contains('.')) {
      t = t.replaceAll(',', '');
    } else {
      final m = RegExp(r',(\d+)$').firstMatch(t);
      if (m != null && m.group(1)!.length == 3) {
        t = t.replaceAll(',', '');
      } else {
        t = t.replaceAll(',', '.');
      }
    }
  }

  final v = double.tryParse(t);
  if (v == null) {
    return null;
  }
  return roundMoney(v);
}

/// The money pattern under [format]'s decimal convention.
///
/// It requires an explicit decimal mark, so `21%` is never mistaken for money.
RegExp moneyPattern(ReceiptReaderFormat format) {
  final decimal = format.decimalConvention == DecimalConvention.commaDecimal
      ? ','
      : '.';
  final grouping = format.decimalConvention == DecimalConvention.commaDecimal
      ? '.'
      : ',';
  return RegExp(
    '\\d{1,3}(?:${RegExp.escape(grouping)}\\d{3})*'
    '${RegExp.escape(decimal)}\\d{1,3}|\\d+[.,]\\d{1,3}',
  );
}

/// The percent pattern, unchanged from the prototype.
final RegExp kPercent = RegExp(r'(\d{1,2})\s*%');

/// Every money amount printed on [line].
List<double> amountsIn(String line, ReceiptReaderFormat format) =>
    moneyPattern(format)
        .allMatches(line)
        .map((m) => parseAmount(m.group(0)!, format))
        .whereType<double>()
        .toList();

/// Parses a printed date under [format]'s date order.
///
/// The separator set stays as lenient as the prototype's: `.`, `/` and `-`
/// are accepted with whitespace allowed around them, and a two-digit year is
/// pivoted to the 2000s. The swap rule runs only when the order is ambiguous
/// under the row (never for [DateOrder.ymd]).
String? parseDate(String raw, ReceiptReaderFormat format) {
  final m = RegExp(r'\b(\d{1,2})\s*[/\-.]\s*(\d{1,2})\s*[/\-.]\s*(\d{2,4})\b')
      .firstMatch(raw);
  if (m == null) {
    return null;
  }

  final first = int.parse(m.group(1)!);
  final second = int.parse(m.group(2)!);
  final third = int.parse(m.group(3)!);

  int year;
  int month;
  int day;
  switch (format.dateOrder) {
    case DateOrder.dmy:
      day = first;
      month = second;
      year = third;
    case DateOrder.mdy:
      month = first;
      day = second;
      year = third;
    case DateOrder.ymd:
      year = first;
      month = second;
      day = third;
  }

  if (year < 100) {
    year += 2000;
  }
  if (year < 2000 || year > 2100) {
    return null;
  }
  if (format.dateOrder != DateOrder.ymd && month > 12 && day <= 12) {
    final swap = day;
    day = month;
    month = swap;
  }
  return _formatIsoDate(year, month, day);
}

String? _formatIsoDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  final d = DateTime(year, month, day);
  if (d.year != year || d.month != month || d.day != day) {
    return null;
  }
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

// --------------------------------------------------------------------- tokens

final RegExp _tokenRe = RegExp(r'[A-Za-zÁÉÍÓÚÜÑ]+|[0-9][0-9.,]*|%');
final RegExp _allDigitsAndMarks = RegExp(r'^\d[\d.,]*$');
final RegExp _endingInDecimals = RegExp(r'[.,]\d{1,3}$');

class _Tok {
  const _Tok(this.text, this.isNumber, this.value);

  final String text;
  final bool isNumber;
  final double? value;

  /// Money has an explicit decimal mark. `21` and `2026` are numbers, not
  /// money.
  bool get isMoney =>
      isNumber &&
      _allDigitsAndMarks.hasMatch(text) &&
      _endingInDecimals.hasMatch(text);
}

List<_Tok> _tokenize(String s, ReceiptReaderFormat format) {
  final out = <_Tok>[];
  for (final m in _tokenRe.allMatches(s.toUpperCase())) {
    final t = m.group(0)!;
    final c = t.codeUnitAt(0);
    final isDigit = c >= 0x30 && c <= 0x39;
    out.add(_Tok(t, isDigit, isDigit ? parseAmount(t, format) : null));
  }
  return out;
}

/// Whether [t] can sit inside a column header run.
bool _isHeaderToken(String t, ReceiptReaderFormat format) =>
    format.vocabulary.headerWords.contains(t) || t == '%';

/// Turns a run of header words into the columns it defines, one entry per
/// value the following row is expected to carry.
List<String> _columnsOf(List<int> run, List<_Tok> toks) {
  final cols = <String>[];
  for (final at in run) {
    switch (toks[at].text) {
      case '%':
      case 'TOTAL':
        break;
      case 'BASE':
        cols.add('base');
      case 'TIPO':
        cols.add('rate');
      case 'CUOTA':
        cols.add('cuota');
      case 'IVA':
        cols.add('iva');
    }
  }
  return cols;
}

double _snapRate(double v) {
  final r = v.roundToDouble();
  return (v - r).abs() < 0.6 ? r : v;
}

bool _isLegalRateValue(double v, ReceiptReaderFormat format) =>
    format.legalRates.contains(v.round()) && (v - v.round()).abs() < 0.6;

/// How many tokens that are not money may sit between a header run and the
/// values that belong to it.
const int _kJunkWindow = 3;

// ---------------------------------------------------------------------- table

class _FromTable {
  const _FromTable(this.net, this.vat, this.rate);
  final double? net;
  final double? vat;
  final double? rate;
}

/// Reads an `IVA | Base | IVA` style breakdown: a run of column headers
/// followed by their values in the same order.
_FromTable? _readBreakdown(List<_Tok> toks, ReceiptReaderFormat format) {
  for (var start = 0; start < toks.length; start++) {
    if (!_isHeaderToken(toks[start].text, format)) {
      continue;
    }

    final run = <int>[start];
    var j = start + 1;
    while (j < toks.length && _isHeaderToken(toks[j].text, format)) {
      run.add(j);
      j++;
    }

    final cols = _columnsOf(run, toks);
    if (cols.length < 2) {
      continue;
    }

    final values = <double>[];
    var k = j;
    var skipped = 0;
    while (k < toks.length && values.length < cols.length) {
      if (toks[k].isMoney) {
        values.add(toks[k].value!);
        k++;
        skipped = 0;
      } else if (skipped < _kJunkWindow) {
        k++;
        skipped++;
      } else {
        break;
      }
    }
    if (values.length < cols.length) {
      continue;
    }

    double? net;
    double? vat;
    double? rate;
    final ivaColumns = <int>[];

    for (var n = 0; n < cols.length; n++) {
      switch (cols[n]) {
        case 'base':
          net ??= values[n];
        case 'cuota':
          vat ??= values[n];
        case 'iva':
          ivaColumns.add(n);
        case 'rate':
          rate ??= _snapRate(values[n]);
      }
    }

    if (net == null) {
      continue;
    }

    if (ivaColumns.length >= 2) {
      final a = values[ivaColumns[0]];
      final b = values[ivaColumns[1]];
      final firstAsRate = (net * _snapRate(a) / 100 - b).abs();
      final secondAsRate = (net * _snapRate(b) / 100 - a).abs();
      if (vat == null && rate == null) {
        if (firstAsRate <= secondAsRate && firstAsRate <= 0.05) {
          rate = _snapRate(a);
          vat = b;
        } else if (secondAsRate <= 0.05) {
          rate = _snapRate(b);
          vat = a;
        } else {
          vat = b;
        }
      }
    } else if (ivaColumns.length == 1) {
      final only = values[ivaColumns.first];
      if (rate == null && vat == null && _isLegalRateValue(only, format)) {
        rate = _snapRate(only);
      } else {
        vat ??= only;
      }
    }

    return _FromTable(net, vat, rate);
  }
  return null;
}

// -------------------------------------------------------------- percent row

class _FromPercentRow {
  const _FromPercentRow(this.net, this.vat, this.gross, this.rate);
  final double net;
  final double? vat;
  final double? gross;
  final double rate;
}

/// Reads a breakdown anchored on the `%` instead of on words.
_FromPercentRow? _readPercentRow(String text, ReceiptReaderFormat format) {
  for (final line in text.split(RegExp(r'[\r\n]+'))) {
    final toks = _tokenize(line, format);

    double? rate;
    for (var j = 0; j + 1 < toks.length; j++) {
      final v = toks[j].value;
      if (toks[j].isNumber && toks[j + 1].text == '%' && v != null) {
        if (_isLegalRateValue(v, format)) {
          rate = _snapRate(v);
          break;
        }
      }
    }
    if (rate == null) {
      continue;
    }

    final amounts = <double>[
      for (final t in toks)
        if (t.isMoney) t.value!,
    ];

    if (amounts.length >= 3) {
      final base = amounts[0];
      final cuota = amounts[1];
      final total = amounts[2];
      if ((base + cuota - total).abs() <= 0.05 &&
          (base * rate / 100 - cuota).abs() <= 0.05) {
        return _FromPercentRow(base, cuota, total, rate);
      }
    } else if (amounts.length == 2) {
      final base = amounts[0];
      final cuota = amounts[1];
      if ((base * rate / 100 - cuota).abs() <= 0.05) {
        return _FromPercentRow(base, cuota, null, rate);
      }
    }
  }
  return null;
}

// ----------------------------------------------------------------- label scan

int? _nextMoney(List<_Tok> toks, int from, {int window = 4}) {
  for (var j = from + 1; j < toks.length && j <= from + window; j++) {
    if (toks[j].isMoney) {
      return j;
    }
  }
  return null;
}

/// A number written immediately before a `%`.
int? _nextRate(List<_Tok> toks, int from, {int window = 3}) {
  for (var j = from + 1; j < toks.length && j <= from + window; j++) {
    if (toks[j].isNumber && j + 1 < toks.length && toks[j + 1].text == '%') {
      return j;
    }
  }
  return null;
}

class _Acc {
  double? net;
  double? vat;
  double? gross;
  double? rate;
  String netOrigin = 'none';
  String vatOrigin = 'none';
  String grossOrigin = 'none';
  final List<double> totals = <double>[];
}

/// Reads one line of labels and figures.
void _scanLine(String line, _Acc acc, ReceiptReaderFormat format) {
  final toks = _tokenize(line, format);

  final claims = <int, Set<String>>{};
  for (var i = 0; i < toks.length; i++) {
    final t = toks[i];
    if (t.isNumber || t.text == '%') {
      continue;
    }

    final String? role = format.vocabulary.totalWords.contains(t.text)
        ? 'total'
        : format.vocabulary.baseWords.contains(t.text)
        ? 'base'
        : format.vocabulary.vatWords.contains(t.text)
        ? 'vat'
        : null;
    if (role == null) {
      continue;
    }

    final at = _nextMoney(toks, i);
    if (at != null) {
      (claims[at] ??= <String>{}).add(role);
    }
  }

  final ordered = claims.keys.toList()..sort();
  for (final at in ordered) {
    final v = toks[at].value!;
    final roles = claims[at]!;
    if (roles.contains('total')) {
      acc.totals.add(v);
    } else if (roles.contains('base')) {
      if (acc.net == null) {
        acc.net = v;
        acc.netOrigin = 'read';
      }
    } else if (roles.contains('vat') && acc.vat == null) {
      acc.vat = v;
      acc.vatOrigin = 'read';
    }
  }

  // The rate is a number written immediately before a `%`, never a bare
  // figure.
  for (var i = 0; i < toks.length; i++) {
    if (!format.vocabulary.rateWords.contains(toks[i].text)) {
      continue;
    }
    final rateAt = _nextRate(toks, i);
    if (rateAt != null && acc.rate == null) {
      acc.rate = _snapRate(toks[rateAt].value!);
    }
  }
}

// ------------------------------------------------------------------ the parse

/// The single amount the document carries, or null when it carries none or
/// more than one.
double? _onlyAmount(String text, ReceiptReaderFormat format) {
  double? only;
  for (final t in _tokenize(text, format)) {
    if (!t.isMoney) {
      continue;
    }
    if (only != null) {
      return null;
    }
    only = t.value;
  }
  return only;
}

/// Reads a document with the labelled reader.
Receipt parseReceipt(String text, ReceiptReaderFormat format) {
  final lines = text
      .replaceAll('\u00A0', ' ')
      .split(RegExp(r'[\r\n]+'))
      .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((l) => l.isNotEmpty)
      .toList();

  // ---- date: a line that says FECHA wins; otherwise the first date on the
  // ticket.
  String? dateIso;
  var dateOrigin = 'none';
  final dateWord = format.vocabulary.dateWord;
  if (dateWord.isNotEmpty) {
    for (final l in lines) {
      if (l.toUpperCase().contains(dateWord)) {
        final d = parseDate(l, format);
        if (d != null) {
          dateIso = d;
          break;
        }
      }
    }
  }
  if (dateIso == null) {
    for (final l in lines) {
      final d = parseDate(l, format);
      if (d != null) {
        dateIso = d;
        break;
      }
    }
  }
  if (dateIso != null) {
    dateOrigin = 'read';
  }

  final acc = _Acc();

  // The table first: its columns are the most explicit statement on the
  // ticket, and the label scan below would misread them.
  final table = _readBreakdown(_tokenize(text, format), format);
  if (table != null) {
    if (table.net != null) {
      acc.net = table.net;
      acc.netOrigin = 'read';
    }
    if (table.vat != null) {
      acc.vat = table.vat;
      acc.vatOrigin = 'read';
    }
    if (table.rate != null) {
      acc.rate = table.rate;
    }
  }

  for (final l in lines) {
    _scanLine(l, acc, format);
  }

  // A second attempt, and only when no label reached a figure.
  if (acc.net == null && acc.vat == null) {
    final row = _readPercentRow(text, format);
    if (row != null) {
      acc.net = row.net;
      acc.netOrigin = 'read';
      if (row.vat != null) {
        acc.vat = row.vat;
        acc.vatOrigin = 'read';
      }
      if (row.gross != null) {
        acc.gross = row.gross;
        acc.grossOrigin = 'read';
      }
      acc.rate ??= row.rate;
    }
  }

  if (acc.totals.isNotEmpty) {
    acc.gross = acc.totals.last;
    acc.grossOrigin = 'read';

    if (acc.net != null && acc.vat != null && acc.totals.length > 1) {
      final sum = roundMoney(acc.net! + acc.vat!);
      for (final t in acc.totals) {
        if ((t - sum).abs() <= 0.02) {
          acc.gross = t;
          acc.grossOrigin = 'read';
          break;
        }
      }
    }
  }

  // ---- reconcile. Derive only by identity, or from a rate the document
  // itself declares.
  if (acc.gross != null && acc.rate != null && acc.gross! > 0) {
    final computedNet = roundMoney(acc.gross! / (1 + acc.rate! / 100));
    if (acc.net == null && computedNet > 0) {
      acc.net = computedNet;
      acc.netOrigin =
          'calculated from the total and the printed ${acc.rate}% rate';
    }
    if (acc.vat == null && acc.net != null && acc.gross! > acc.net!) {
      acc.vat = roundMoney(acc.gross! - acc.net!);
      acc.vatOrigin =
          'calculated from the total and the printed ${acc.rate}% rate';
    }
  }
  if (acc.net == null &&
      acc.gross != null &&
      acc.vat != null &&
      acc.gross! > acc.vat!) {
    acc.net = roundMoney(acc.gross! - acc.vat!);
    acc.netOrigin = 'derived: total minus VAT';
  }
  if (acc.vat == null &&
      acc.gross != null &&
      acc.net != null &&
      acc.gross! > acc.net!) {
    acc.vat = roundMoney(acc.gross! - acc.net!);
    acc.vatOrigin = 'derived: total minus net';
  }

  // A read base and a rate the document itself declares are enough for the
  // VAT, even when the ticket never prints the amount and never prints a
  // total.
  if (acc.vat == null && acc.net != null && acc.rate != null && acc.rate! > 0) {
    acc.vat = roundMoney(acc.net! * acc.rate! / 100);
    acc.vatOrigin = 'calculated from the read base and the ${acc.rate}% rate';
  }

  // One figure and nothing else.
  if (acc.net == null && acc.vat == null) {
    final only = _onlyAmount(text, format);
    if (only != null) {
      acc.net = only;
      acc.netOrigin = 'proposed: the only figure on the ticket';
    }
  }

  return Receipt(
    rawText: text,
    dateIso: dateIso,
    dateOrigin: dateOrigin,
    net: ReceiptValue(acc.net, acc.netOrigin),
    vat: ReceiptValue(acc.vat, acc.vatOrigin),
    gross: ReceiptValue(acc.gross, acc.grossOrigin),
    rate: acc.rate,
    totalCandidates: acc.totals,
  );
}
