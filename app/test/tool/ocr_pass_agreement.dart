/// The numbers the photo route's harness reports (`implement-photo-passes`,
/// design §5 and task 1.6).
///
/// **Why it lives here and not in `app/lib/`.** Nothing in the application
/// counts words or compares passes: deciding which reading is better is the
/// consensus's job (FR-EXT-006, T2.1/T2.5) and the product owner's, and the
/// evaluation only *reports* what happened. This file is the arithmetic of that
/// report, and it produces **numbers and nothing else**: no word of any document
/// passes through it into a file or a log, and the counters it answers with
/// cannot be read back into text.
///
/// **What is counted, exactly.** The words of a pass, after one normalisation:
/// case-folded, with the punctuation around a word removed and the punctuation
/// inside it kept. `Gesamtbetrag` and `gesamtbetrag` are the same word, `(1.234,50)`
/// and `1.234,50` are the same word, and `1.234,50` and `123450` are not — the
/// engine's own segmentation is what is compared, and the route's word is the
/// element the engine reported.
///
/// **The share.** Between two passes: the words they have in common, counted
/// with multiplicity, over the words of the larger of the two. Two passes that
/// read the same twelve words share all twelve, and the share is 1 no matter how
/// many of them each pass reported twice. Two passes that both read nothing
/// share everything they read, which is 1 — the word counts beside it are what
/// says that nothing was read. **No threshold is applied here**: a share is a
/// measurement, and the decision about what a good one is belongs to T2.5.
library;

import 'package:paperdrop/adapters/ocr/ocr_text_source.dart';
import 'package:paperdrop_core/paperdrop_core.dart';

/// The words of [page], normalised: case-folded, and without the punctuation
/// around them.
List<String> normalisedWordsOf(TextPage page) => page.words
    .map((PositionedWord word) => normaliseWord(word.text))
    .where((String word) => word.isNotEmpty)
    .toList(growable: false);

/// The words of [pass], normalised, in the engine's order and page by page.
List<String> normalisedWordsOfPass(OcrPass pass) => <String>[
  for (final TextPage page in pass.pages) ...normalisedWordsOf(page),
];

/// One word as the comparison reads it: case-folded, with the punctuation
/// around it removed.
///
/// The punctuation inside a word is kept, because it is part of what the engine
/// read: a decimal comma and a thousands point are how this route's values are
/// written, and stripping them would make two different amounts the same word.
String normaliseWord(String text) {
  var word = text.trim().toLowerCase();
  while (true) {
    final String stripped = word.replaceFirst(_aroundAWord, '');
    if (stripped == word) {
      return word;
    }
    word = stripped;
  }
}

/// The punctuation a word may carry at either end: anything that is neither a
/// letter nor a digit, at the start or at the end of the word.
///
/// Letters of every script and not `a-z`: the languages in scope are Latin
/// script, and a normalisation that quietly dropped an accented word would be
/// worse than the comparison it serves.
final RegExp _aroundAWord = RegExp(
  r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$',
  unicode: true,
);

/// How many words [pass] read, punctuation and case aside.
int wordsInPass(OcrPass pass) => normalisedWordsOfPass(pass).length;

/// Two passes and what they read in common.
class OcrPassAgreement {
  /// Creates the measurement of [firstPassId] against [secondPassId].
  const OcrPassAgreement({
    required this.firstPassId,
    required this.secondPassId,
    required this.firstWords,
    required this.secondWords,
    required this.sharedWords,
  });

  /// The first pass of the pair, as the pass list ordered them.
  final String firstPassId;

  /// The second pass of the pair.
  final String secondPassId;

  /// How many words the first pass read.
  final int firstWords;

  /// How many words the second pass read.
  final int secondWords;

  /// How many words, with multiplicity, both read.
  final int sharedWords;

  /// The share of the pair's words that both read: [sharedWords] over the words
  /// of the larger pass, and 1 when neither read a word.
  double get share {
    final int largest = firstWords > secondWords ? firstWords : secondWords;
    if (largest == 0) {
      return 1;
    }
    return sharedWords / largest;
  }

  @override
  String toString() =>
      'OcrPassAgreement($firstPassId vs $secondPassId: '
      '$sharedWords/$firstWords, $secondWords)';
}

/// Every pair of [passes], in the order the list has them, with what the two
/// read in common.
///
/// One pair per two different passes: three passes give three pairs, four give
/// six. The pairs are the whole measurement — a document whose passes all agree
/// and one whose passes read different words are both reported, and neither is
/// judged here.
List<OcrPassAgreement> passAgreements(List<OcrPass> passes) {
  final List<List<String>> words = passes
      .map(normalisedWordsOfPass)
      .toList(growable: false);
  final List<OcrPassAgreement> agreements = <OcrPassAgreement>[];
  for (var first = 0; first < passes.length; first++) {
    for (var second = first + 1; second < passes.length; second++) {
      agreements.add(
        OcrPassAgreement(
          firstPassId: passes[first].passId,
          secondPassId: passes[second].passId,
          firstWords: words[first].length,
          secondWords: words[second].length,
          sharedWords: _shared(words[first], words[second]),
        ),
      );
    }
  }
  return List<OcrPassAgreement>.unmodifiable(agreements);
}

/// The words two lists have in common, counted with multiplicity: a word one
/// pass read twice and the other once is shared once.
int _shared(List<String> first, List<String> second) {
  final Map<String, int> left = _countOf(first);
  var shared = 0;
  for (final String word in second) {
    final int remaining = left[word] ?? 0;
    if (remaining > 0) {
      shared++;
      left[word] = remaining - 1;
    }
  }
  return shared;
}

/// How many different page sizes the passes of one document report.
///
/// It is the invariant of design §4 read as a number: every pass of one document
/// converts its boxes with the same page size, so all of them report the same
/// sizes for the same pages, and a document whose passes disagree has a
/// geometry defect that would make consensus compare boxes of different spaces.
/// One document read by any number of passes answers 1; a document no pass read
/// answers 0.
int distinctPageSizes(List<OcrPass> passes) {
  final Set<String> sizes = <String>{};
  for (final OcrPass pass in passes) {
    sizes.add(
      pass.pages
          .map((TextPage page) => '${page.index}:${page.width}x${page.height}')
          .join(','),
    );
  }
  return sizes.length;
}

Map<String, int> _countOf(List<String> words) {
  final Map<String, int> counted = <String, int>{};
  for (final String word in words) {
    counted[word] = (counted[word] ?? 0) + 1;
  }
  return counted;
}
