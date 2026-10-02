import 'package:flutter/services.dart';

import 'pdf_text_candidate.dart';

/// Candidate A of ADR-011 — **PdfBox-Android** — seen from Dart.
/// (`close-adr-011-pdf-text-route`, design §1, task 1.1.)
///
/// The library is a JVM library ported to Android, so it can only run inside
/// the application process: the Dart side of this candidate is a method channel
/// to the Kotlin in `app/android/`, which does the reading and answers with
/// design §2's shape.
///
/// **The version is stated three times** — the Gradle dependency, the Kotlin
/// channel and here — because a build has to agree with itself and a review has
/// to name what ran. The three are kept honest by [read], which refuses a reply
/// that says a different library ran than the one this file claims: an APK left
/// over from an earlier build would otherwise be measured under the wrong name.
class PdfBoxTextCandidate implements PdfTextCandidate {
  const PdfBoxTextCandidate();

  /// The channel the Kotlin side answers on. It is also the string in
  /// `MainActivity` and in `PdfBoxTextChannel.kt`.
  static const String channelName = 'com.nortexsys.paperdrop/pdf_text_pdfbox';

  /// The method that reads one document, with `{'path': …}` as its argument.
  static const String readWordsMethod = 'readWords';

  /// The library and version this candidate resolves, in design §2's `tool`
  /// format. Kept in step with `pdfbox-android` in
  /// `app/android/app/build.gradle.kts`.
  static const String toolName = 'pdfbox-android 2.0.27.0';

  static const MethodChannel _channel = MethodChannel(channelName);

  @override
  String get tool => toolName;

  @override
  Future<List<CandidatePage>> read(String path) async {
    final Object? reply = await _channel.invokeMethod<Object?>(
      readWordsMethod,
      <String, Object?>{'path': path},
    );
    return pagesFromPdfBoxReply(reply);
  }
}

/// The pages in a reply of [PdfBoxTextCandidate.channelName], and nothing else.
///
/// It is public and pure so that the shape of the channel boundary is unit
/// tested without a device (task 1.1: "a unit test of the Dart side parses a
/// channel reply"). What it checks is *shape*: a reply that does not carry what
/// design §2 fixed for it is a broken harness boundary and must not be recorded
/// as a candidate that found no words.
List<CandidatePage> pagesFromPdfBoxReply(Object? reply) {
  if (reply is! Map<Object?, Object?>) {
    throw const PdfTextReplyFormatException('the reply is not a map');
  }

  final Object? tool = reply['tool'];
  if (tool != PdfBoxTextCandidate.toolName) {
    throw PdfTextReplyFormatException(
      'the platform side says ${tool is String ? '"$tool"' : 'nothing'} ran, '
      'and this build measures ${PdfBoxTextCandidate.toolName}',
    );
  }

  final Object? pages = reply['pages'];
  if (pages is! List<Object?>) {
    throw const PdfTextReplyFormatException('the reply carries no page list');
  }

  final List<CandidatePage> result = <CandidatePage>[];
  for (final Object? page in pages) {
    if (page is! Map<Object?, Object?>) {
      throw const PdfTextReplyFormatException(
        'a page in the reply is not a map',
      );
    }
    final Object? words = page['words'];
    if (words is! List<Object?>) {
      throw const PdfTextReplyFormatException(
        'a page in the reply carries no word list',
      );
    }
    result.add(
      CandidatePage(
        index: _int(page, 'index'),
        width: _double(page, 'width'),
        height: _double(page, 'height'),
        words: words.map(_word).toList(growable: false),
      ),
    );
  }
  return result;
}

CandidateWord _word(Object? word) {
  if (word is! Map<Object?, Object?>) {
    throw const PdfTextReplyFormatException('a word in the reply is not a map');
  }
  return CandidateWord(
    text: _string(word, 'text'),
    x0: _double(word, 'x0'),
    x1: _double(word, 'x1'),
    top: _double(word, 'top'),
    bottom: _double(word, 'bottom'),
  );
}

double _double(Map<Object?, Object?> source, String key) {
  final Object? value = source[key];
  if (value is num) {
    return value.toDouble();
  }
  throw PdfTextReplyFormatException('"$key" is not a number');
}

int _int(Map<Object?, Object?> source, String key) {
  final Object? value = source[key];
  if (value is int) {
    return value;
  }
  throw PdfTextReplyFormatException('"$key" is not an integer');
}

String _string(Map<Object?, Object?> source, String key) {
  final Object? value = source[key];
  if (value is String) {
    return value;
  }
  throw PdfTextReplyFormatException('"$key" is not a string');
}
