/// The score of the second stage: how much one Ninox field's name resembles one term of the
/// dictionary (design §5).
///
/// Requirement served: FR-WIZ-006 (`setup-wizard/two-stage-matching-with-a-strict-threshold`) — the
/// similarity stage its scenario *the type filter runs before similarity* names, and the reason a
/// term below the threshold leaves a field unmapped.
///
/// **The design's two components, and the compound rule its own fixtures need.** Design §5 states the
/// score as *the greater of the whole-string similarity (one minus normalised edit distance) and the
/// token-set similarity, taken as the maximum over the field's synonyms*. Measured against the
/// dictionary this project actually ships, that sketch **cannot** produce the outcome the same design
/// requires of its German fixture: Annex C carries no `Belegdatum` and no `Betrag`, and
/// `Belegdatum` against the nearest term that exists (`Datum`) scores one half by edit distance and
/// zero by token set. Two rules were therefore added to the score, and they are the whole of the
/// difference:
///
/// 1. **A term a name *contains* is a compound part of it, and scores [containedTermSimilarity].**
///    German writes its compounds closed (`Belegdatum` = document + date, `Gesamtbetrag` = total +
///    amount), so a comparison that only looks at two whole strings and their tokens misses exactly
///    the tables that need the dictionary most. The rule is bounded twice: the contained term must
///    cover at least [minContainedTermShare] of the longer name, and a contained term scores *below*
///    a literal match, so an exact column name always wins against a longer name that merely
///    contains it (`Total` beats `Subtotal` for the gross total).
/// 2. **When one name is longer and neither contains the other, the edit distance is measured
///    against the best window of the longer name** of the shorter's length — the standard
///    substring-aware form of *one minus normalised edit distance*. `Invoice No.` therefore reaches
///    a column called `Invoice Number`, which no whole-string comparison of those two reaches.
///
/// Both bounds point the same way the threshold does: what is not scored highly is left unmapped
/// rather than proposed weakly (design §5: *the failure it must have is an unmapped field, not a
/// wrong one*).
///
/// **What this file does not contain.** Neither the threshold nor the margin: those are
/// `field_matcher.dart`'s, and its fixture tests are what would fail if the two were ever moved out
/// of step with [containedTermSimilarity]. No money, no `Decimal`: the score is a real number over a
/// field *name*, which is not a monetary value and owes the core's no-float rule nothing.
library;

import 'dart:math' as math;

/// The smallest share of the longer name that a contained term must cover to count as one of its
/// parts.
///
/// A half: the two halves of a compound must be of comparable length. That is what admits
/// `Beleg`+`Datum` and `Gesamt`+`Betrag` — the design's German fixture, exactly on the line and no
/// further — while `Rechnungsdatum`, `Buchungsdatum` and `Fälligkeitsdatum` all carry `Datum` and
/// none of them is this term inside a longer word. It is also what stops a short term from finding
/// itself anywhere: `IVA` covers a quarter of `Privatanteil`, and `Netto` a little over two fifths of
/// `Nettogewicht`. A German date column the dictionary knows under its own name does not need the
/// rule (`Rechnungsdatum` is a term of Annex C), and one it does not know — a due date — is left
/// unmapped, which is the failure the threshold is built to prefer.
const double minContainedTermShare = 0.5;

/// What a term scores when the candidate's name contains it as a compound part.
///
/// Below a literal match (1) and above the proposal threshold `field_matcher.dart` holds, so a
/// compound name is proposed and an exact name still wins the tie between the two.
const double containedTermSimilarity = 0.9;

/// The letters the dictionary's languages print, folded to ASCII.
///
/// Spanish, German, French, Italian and Portuguese — the languages of Annex C — plus the
/// Central-European letters a customer's own column names may carry. A letter outside this map is
/// kept as it is by [normalise], so a name that uses one is compared, not mangled.
const Map<String, String> _foldedLetters = <String, String>{
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ø': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ñ': 'n',
  'ç': 'c',
  'ý': 'y',
  'ÿ': 'y',
  'ß': 'ss',
  'æ': 'ae',
  'œ': 'oe',
  'č': 'c',
  'š': 's',
  'ž': 'z',
  'ł': 'l',
  'ń': 'n',
  'ř': 'r',
  'ť': 't',
  'ď': 'd',
  'ě': 'e',
  'ů': 'u',
  'ā': 'a',
  'ē': 'e',
  'ī': 'i',
  'ō': 'o',
  'ū': 'u',
};

/// The letters and digits of a normalised string, either side of which a space is not needed.
final RegExp _letterOrDigit = RegExp(r'[\p{L}\p{Nd}]', unicode: true);

/// What separates two words of a normalised string.
final RegExp _separators = RegExp(r'\s+');

/// The split between a lower-case letter or a digit and the capital that follows it: `DocNumber` is
/// two words, `YB` is one.
final RegExp _camelBoundary = RegExp(r'([a-z0-9])([A-Z])');

/// [text] as the matcher compares names, both sides of every comparison going through this:
///
/// * lower case;
/// * diacritics folded to ASCII ([_foldedLetters]);
/// * camel case split (`DocNumber` → `doc number`), and `_` and `-` become spaces;
/// * every punctuation mark dropped, and whitespace collapsed.
///
/// A name and a term that differ only in one of those ways are the same string afterwards — which is
/// the point: `Nº FACTURA`, `Nº Factura` and `nº factura` are one term to the dictionary.
String normalise(String text) {
  final String camelSplit = text.replaceAllMapped(
    _camelBoundary,
    (Match match) => '${match[1]} ${match[2]}',
  );
  final StringBuffer out = StringBuffer();
  for (final int rune in camelSplit.toLowerCase().runes) {
    final String character = String.fromCharCode(rune);
    final String? folded = _foldedLetters[character];
    if (folded != null) {
      out.write(folded);
      continue;
    }
    if (_letterOrDigit.hasMatch(character)) {
      out.write(character);
      continue;
    }
    // `_`, `-` and any other punctuation or symbol end a word rather than joining two.
    out.write(' ');
  }
  return out.toString().replaceAll(_separators, ' ').trim();
}

/// The score of one candidate name against one term of the dictionary, in `[0, 1]`.
///
/// The greater of the whole-string comparison and the token-set comparison, as design §5 states it,
/// with the two rules this file's header explains.
double termSimilarity(String name, String term) =>
    _similarityOf(normalise(name), normalise(term));

/// The score of one candidate name against every synonym of a core field: the maximum.
///
/// An empty list of synonyms scores nothing, which is the honest answer for a field the dictionary
/// does not describe.
double bestSimilarity(String name, Iterable<String> synonyms) {
  double best = 0;
  for (final String synonym in synonyms) {
    best = math.max(best, termSimilarity(name, synonym));
  }
  return best;
}

/// [termSimilarity] over two strings that are already normalised.
double _similarityOf(String name, String term) {
  if (name.isEmpty || term.isEmpty) {
    return 0;
  }
  return math.max(
    _wholeStringSimilarity(name, term),
    _tokenSetSimilarity(name, term),
  );
}

/// One minus the normalised edit distance, over the whole strings or the best window of them.
double _wholeStringSimilarity(String a, String b) {
  if (a == b) {
    return 1;
  }
  final String longer = a.length >= b.length ? a : b;
  final String shorter = a.length >= b.length ? b : a;
  if (shorter.length / longer.length >= minContainedTermShare) {
    if (longer.contains(shorter)) {
      // A compound name that carries the term: `Belegdatum` and `Datum`, `Gesamtbetrag` and
      // `Betrag`.
      return containedTermSimilarity;
    }
    return 1 - _bestWindowDistance(shorter, longer) / longer.length;
  }
  return 1 - _editDistance(a, b) / longer.length;
}

/// The Sørensen–Dice coefficient of the two token sets: `2·|A∩B| / (|A|+|B|)`.
///
/// The token half of design §5's score, and the guard the whole-string half cannot give: a column
/// called `Fecha de factura` shares a whole token with `Fecha`, while a column called `Invoice Date`
/// shares one with `Date` and is *not* the same claim — the coefficient stays low for the second and
/// the threshold keeps it unmapped.
double _tokenSetSimilarity(String a, String b) {
  final Set<String> left = a.split(' ').toSet();
  final Set<String> right = b.split(' ').toSet();
  if (left.isEmpty || right.isEmpty) {
    return 0;
  }
  final int shared = left.intersection(right).length;
  return 2 * shared / (left.length + right.length);
}

/// The smallest edit distance between [shorter] and any window of [longer] of the same length.
int _bestWindowDistance(String shorter, String longer) {
  int best = shorter.length;
  for (int start = 0; start + shorter.length <= longer.length; start++) {
    best = math.min(
      best,
      _editDistance(shorter, longer.substring(start, start + shorter.length)),
    );
    if (best == 0) {
      break;
    }
  }
  return best;
}

/// The Levenshtein distance between two strings, in one pass and two rows.
int _editDistance(String a, String b) {
  if (a.isEmpty) {
    return b.length;
  }
  if (b.isEmpty) {
    return a.length;
  }
  List<int> previous = List<int>.generate(b.length + 1, (int i) => i);
  List<int> current = List<int>.filled(b.length + 1, 0);
  for (int i = 1; i <= a.length; i++) {
    current[0] = i;
    for (int j = 1; j <= b.length; j++) {
      final int substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
      current[j] = math.min(
        math.min(current[j - 1] + 1, previous[j] + 1),
        substitution,
      );
    }
    final List<int> swap = previous;
    previous = current;
    current = swap;
  }
  return previous[b.length];
}
