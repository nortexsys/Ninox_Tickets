/// Reading every printed operand before deriving any.
///
/// Requirement served: `extraction-pipeline` ·
/// `read-all-printed-quantities-before-deriving` — this step collects gross,
/// base, each tax amount and each printed rate as `read` candidates with their
/// positions. Nothing is computed here.
library;

import '../countries/country_table.dart';
import '../dictionaries/labels.dart';
import '../dictionaries/lookup.dart';
import '../format/decimal.dart';
import '../layout/binding.dart';
import '../layout/lines.dart';
import '../layout/positioned_word.dart';
import '../layout/text_page.dart';
import '../model/provenance.dart';
import '../money/money.dart';
import '../money/rate.dart';

/// The role a printed operand plays in an amount breakdown.
enum OperandRole {
  /// A gross total amount.
  gross,

  /// A taxable base amount.
  base,

  /// A tax amount.
  tax,

  /// A printed tax rate.
  rate,
}

/// One printed operand, read from the document and never computed.
class ReadOperand {
  /// The role the operand was printed under.
  final OperandRole role;

  /// The printed amount, when [role] is not [OperandRole.rate].
  final Money? amount;

  /// The printed rate, when [role] is [OperandRole.rate].
  final RateBp? rate;

  /// The words that carried the printed operand.
  final List<PositionedWord> words;

  /// The page the operand was read from.
  final int pageIndex;

  /// Every operand of this step is read, never computed.
  final Provenance provenance;

  ReadOperand._({
    required this.role,
    required this.amount,
    required this.rate,
    required List<PositionedWord> words,
    required this.pageIndex,
  }) : words = List.unmodifiable(words),
       provenance = Provenance.read;

  /// Creates an amount operand for [role], which must not be [OperandRole.rate].
  factory ReadOperand.amount({
    required OperandRole role,
    required Money amount,
    required List<PositionedWord> words,
    required int pageIndex,
  }) {
    if (role == OperandRole.rate) {
      throw ArgumentError.value(role, 'role', 'must not be rate');
    }
    return ReadOperand._(
      role: role,
      amount: amount,
      rate: null,
      words: words,
      pageIndex: pageIndex,
    );
  }

  /// Creates a rate operand.
  factory ReadOperand.rate({
    required RateBp rate,
    required List<PositionedWord> words,
    required int pageIndex,
  }) {
    return ReadOperand._(
      role: OperandRole.rate,
      amount: null,
      rate: rate,
      words: words,
      pageIndex: pageIndex,
    );
  }

  /// A value-only string form.
  @override
  String toString() {
    final Object? value = role == OperandRole.rate ? rate : amount;
    return 'ReadOperand($role, $value, page $pageIndex)';
  }

  /// Value equality on every field.
  @override
  bool operator ==(Object other) =>
      other is ReadOperand &&
      other.role == role &&
      other.amount == amount &&
      other.rate == rate &&
      other.pageIndex == pageIndex &&
      other.provenance == provenance &&
      _listEquals(other.words, words);

  @override
  int get hashCode => Object.hash(
    role,
    amount,
    rate,
    pageIndex,
    provenance,
    Object.hashAll(words),
  );
}

/// The printed operands of a document: what step 1 read, all of it.
class ReadOperands {
  /// Every printed operand, in reading order.
  final List<ReadOperand> operands;

  /// Creates a read-operands collection from [operands].
  ReadOperands(Iterable<ReadOperand> operands)
    : operands = List.unmodifiable(operands);

  /// The printed gross totals.
  List<ReadOperand> get gross => _where(OperandRole.gross);

  /// The printed base amounts.
  List<ReadOperand> get bases => _where(OperandRole.base);

  /// The printed tax amounts.
  List<ReadOperand> get taxes => _where(OperandRole.tax);

  /// The printed rates.
  List<ReadOperand> get rates => _where(OperandRole.rate);

  List<ReadOperand> _where(OperandRole role) =>
      operands.where((ReadOperand operand) => operand.role == role).toList();

  /// A value-only string form naming the operand count.
  @override
  String toString() => 'ReadOperands(${operands.length} operands)';

  /// Value equality on the operand list.
  @override
  bool operator ==(Object other) {
    if (other is! ReadOperands) {
      return false;
    }
    if (other.operands.length != operands.length) {
      return false;
    }
    for (var i = 0; i < operands.length; i++) {
      if (other.operands[i] != operands[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(operands);
}

/// Reads every printed operand from [pages] under [country]'s convention.
///
/// Amount operands are bound to their labels by visual layout; rate operands
/// are read from tokens that print a percentage sign. Nothing is computed:
/// every returned operand carries [Provenance.read].
ReadOperands readOperands(Iterable<TextPage> pages, CountryRow country) {
  final operands = <ReadOperand>[];

  for (final page in pages) {
    final lines = groupIntoLines(page);
    for (final line in lines) {
      final matches = findTerms(line.text);
      for (final match in matches) {
        final role = _roleFor(match.kind);
        if (role == null) {
          continue;
        }

        final labelWords = _wordsCoveredBy(line, match);
        if (labelWords.isEmpty) {
          continue;
        }

        final binding = bindLabel(
          LabelOccurrence(match, labelWords),
          page,
          ValueKind.amount,
          country,
        );
        final money = binding?.amount;
        if (binding == null || money == null) {
          continue;
        }

        _addIfNew(
          operands,
          ReadOperand.amount(
            role: role,
            amount: money,
            words: binding.words,
            pageIndex: page.index,
          ),
        );
      }

      _readRatesFromLine(line, country, page.index, operands);
    }
  }

  return ReadOperands(operands);
}

OperandRole? _roleFor(LabelKind? kind) => switch (kind) {
  LabelKind.total => OperandRole.gross,
  LabelKind.base => OperandRole.base,
  LabelKind.tax => OperandRole.tax,
  _ => null,
};

List<PositionedWord> _wordsCoveredBy(LayoutLine line, TermMatch match) {
  final covered = <PositionedWord>[];
  var cursor = 0;
  for (final word in line.words) {
    final start = cursor;
    final end = cursor + word.text.length;
    if (start < match.end && end > match.start) {
      covered.add(word);
    }
    cursor = end + 1;
  }
  return covered;
}

void _readRatesFromLine(
  LayoutLine line,
  CountryRow country,
  int pageIndex,
  List<ReadOperand> operands,
) {
  final words = line.words;
  for (var i = 0; i < words.length; i++) {
    final word = words[i];
    final rateWords = <PositionedWord>[];
    String? candidate;

    if (word.text.endsWith('%')) {
      candidate = word.text.substring(0, word.text.length - 1);
      rateWords.add(word);
    } else if (i + 1 < words.length && words[i + 1].text == '%') {
      candidate = word.text;
      rateWords.add(word);
      rateWords.add(words[i + 1]);
      i++;
    }

    if (candidate == null) {
      continue;
    }

    final rate = _parseRateText(candidate, country);
    if (rate != null) {
      _addIfNew(
        operands,
        ReadOperand.rate(rate: rate, words: rateWords, pageIndex: pageIndex),
      );
    }
  }
}

RateBp? _parseRateText(String text, CountryRow country) {
  var normalized = text.trim();
  if (normalized.isEmpty) {
    return null;
  }

  final groupingSeparator =
      country.decimalConvention == DecimalConvention.commaDecimal ? '.' : ',';
  final decimalSeparator =
      country.decimalConvention == DecimalConvention.commaDecimal ? ',' : '.';

  normalized = normalized
      .replaceAll(groupingSeparator, '')
      .replaceAll(decimalSeparator, '.');

  try {
    return RateBp.parsePercent(normalized);
  } on FormatException {
    return null;
  } on ArgumentError {
    return null;
  }
}

void _addIfNew(List<ReadOperand> operands, ReadOperand operand) {
  if (!operands.contains(operand)) {
    operands.add(operand);
  }
}

bool _listEquals(List<PositionedWord> left, List<PositionedWord> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}
