/// The vocabulary-free arithmetic photo reader, ported from the PO's App Cust
/// prototype.
///
/// The logic is copied as it is; only the country parameters are threaded
/// through [ReceiptReaderFormat]. This reader knows no words: it takes every
/// amount the document prints and asks which of them are a base, a VAT and a
/// total, using nothing but the arithmetic a ticket has to satisfy.
library;

import 'labelled_reader.dart';

class _Amount {
  const _Amount(this.value, this.at);

  final double value;

  /// Where the amount sits in the text, so the search can prefer the later
  /// one when two candidates are equally good.
  final int at;
}

class _Pick {
  const _Pick(this.net, this.vat, this.gross, this.rate, this.error, this.at);

  final double net;
  final double vat;
  final double? gross;
  final double rate;
  final double error;
  final int at;
}

double _snapRate(double v) {
  final r = v.roundToDouble();
  return (v - r).abs() < 0.6 ? r : v;
}

bool _legalRate(double v, ReceiptReaderFormat format) =>
    format.legalRates.contains(v.round()) && (v - v.round()).abs() < 0.6;

/// Every amount the document prints, in the order it prints it.
List<_Amount> _amounts(String text, ReceiptReaderFormat format) {
  final out = <_Amount>[];
  for (final m in moneyPattern(format).allMatches(text)) {
    final v = parseAmount(m.group(0)!, format);
    if (v != null) {
      out.add(_Amount(v, m.start));
    }
  }
  return out;
}

/// A percentage as the printers write it: `21%`, and also `21,00%`.
final RegExp _rateRe = RegExp(r'(\d{1,3}(?:[.,]\d{1,3})?)\s*%');

/// Every rate the document prints, snapped, without `0 %`.
List<double> _rates(String text, ReceiptReaderFormat format) {
  final out = <double>[];
  for (final m in _rateRe.allMatches(text)) {
    final v = double.tryParse(m.group(1)!.replaceAll(',', '.'));
    if (v == null || !_legalRate(v, format)) {
      continue;
    }
    final r = _snapRate(v);
    if (r == 0) {
      continue;
    }
    if (!out.contains(r)) {
      out.add(r);
    }
  }
  return out;
}

/// The best reading the arithmetic alone can produce, or null when nothing
/// fits.
_Pick? _search(String text, ReceiptReaderFormat format) {
  final amounts = _amounts(text, format);
  if (amounts.length < 2) {
    return null;
  }

  final rates = _rates(text, format);
  if (rates.isEmpty) {
    return null;
  }

  _Pick? best;

  void consider(double net, double vat, double? gross, double rate, int at) {
    final rateError = (net * rate / 100 - vat).abs();
    if (rateError > 0.05) {
      return;
    }
    var error = rateError;
    if (gross != null) {
      final sumError = (net + vat - gross).abs();
      if (sumError > 0.02) {
        return;
      }
      error += sumError;
    }
    final pick = _Pick(net, vat, gross, rate, error, at);
    if (best == null || _better(pick, best!)) {
      best = pick;
    }
  }

  for (final rate in rates) {
    for (var i = 0; i < amounts.length; i++) {
      for (var j = 0; j < amounts.length; j++) {
        if (i == j) {
          continue;
        }
        for (var k = 0; k < amounts.length; k++) {
          if (k == i || k == j) {
            continue;
          }
          consider(
            amounts[i].value,
            amounts[j].value,
            amounts[k].value,
            rate,
            amounts[k].at,
          );
        }
        consider(amounts[i].value, amounts[j].value, null, rate, amounts[j].at);
      }
    }
  }
  return best;
}

/// Fewer errors first, then the biggest figure, then the latest one.
bool _better(_Pick a, _Pick b) {
  final aHasTotal = a.gross != null;
  final bHasTotal = b.gross != null;
  if (aHasTotal != bHasTotal) {
    return aHasTotal;
  }
  if ((a.error - b.error).abs() > 1e-9) {
    return a.error < b.error;
  }
  final aBiggest = a.gross ?? a.net;
  final bBiggest = b.gross ?? b.net;
  if ((aBiggest - bBiggest).abs() > 1e-9) {
    return aBiggest > bBiggest;
  }
  return a.at > b.at;
}

String? _date(String text, List<String> lines, ReceiptReaderFormat format) {
  final dateWord = format.vocabulary.dateWord;
  if (dateWord.isNotEmpty) {
    for (final l in lines) {
      if (l.toUpperCase().contains(dateWord)) {
        final d = parseDate(l, format);
        if (d != null) {
          return d;
        }
      }
    }
  }
  for (final l in lines) {
    final d = parseDate(l, format);
    if (d != null) {
      return d;
    }
  }
  return null;
}

/// Reads a document with the vocabulary-free arithmetic reader.
Receipt parseReceiptArithmetic(String text, ReceiptReaderFormat format) {
  final lines = text
      .replaceAll('\u00A0', ' ')
      .split(RegExp(r'[\r\n]+'))
      .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((l) => l.isNotEmpty)
      .toList();

  final dateIso = _date(text, lines, format);
  final amounts = _amounts(text, format);
  final candidates = <double>[for (final a in amounts) a.value];

  final pick = _search(text, format);
  if (pick != null) {
    return Receipt(
      rawText: text,
      dateIso: dateIso,
      dateOrigin: dateIso == null ? 'none' : 'read',
      net: ReceiptValue(pick.net, 'read'),
      vat: ReceiptValue(pick.vat, 'read'),
      gross: ReceiptValue(pick.gross, pick.gross == null ? 'none' : 'read'),
      rate: pick.rate,
      totalCandidates: candidates,
    );
  }

  if (amounts.length == 1) {
    return Receipt(
      rawText: text,
      dateIso: dateIso,
      dateOrigin: dateIso == null ? 'none' : 'read',
      net: ReceiptValue(
        amounts.single.value,
        'proposed: the only figure on the ticket',
      ),
      vat: ReceiptValue.none,
      gross: ReceiptValue.none,
      rate: null,
      totalCandidates: candidates,
    );
  }

  return Receipt(
    rawText: text,
    dateIso: dateIso,
    dateOrigin: dateIso == null ? 'none' : 'read',
    net: ReceiptValue.none,
    vat: ReceiptValue.none,
    gross: ReceiptValue.none,
    rate: null,
    totalCandidates: candidates,
  );
}
