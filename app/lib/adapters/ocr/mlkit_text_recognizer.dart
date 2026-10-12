import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as mlkit;

import 'text_recognizer_backend.dart';

/// ML Kit's text recognition, Latin script, behind [TextRecognizerBackend]
/// (`implement-photo-route`, design §2).
///
/// **Why this engine.** ADR-010 is *proposed*: the approach is decided — the
/// platform's engine behind a port — and the engine itself is confirmed by the
/// screening T2.5 runs over the photographed corpus. This adapter is what that
/// confirmation can be measured on; it claims no accuracy of its own.
///
/// **What it hands the engine.** The Latin script recognizer, because the
/// languages in scope are all Latin script: ES, EN, FR, DE, IT and PT. An image
/// is handed either as the pixels of a rendered page, as the platform's bitmap
/// input, or as a file path when the file is an image and is read as it is.
///
/// **What it takes back.** The engine's own **elements** — never a line and
/// never a block — with the box each element reports, in pixels of the image it
/// was given, rounded to whole pixels (a fifth of a pixel at the resolutions
/// the passes render at). The order is the engine's. Nothing is merged, sorted,
/// split or dropped here.
class MlKitTextRecognizer implements TextRecognizerBackend {
  /// Creates a recognizer over a fresh ML Kit client.
  MlKitTextRecognizer()
    : _recognizer = mlkit.TextRecognizer(
        script: mlkit.TextRecognitionScript.latin,
      );

  /// The library and the version this engine resolves, in the `tool` format the
  /// evaluation harness writes into every JSON (design §4).
  ///
  /// It is kept in step with `google_mlkit_text_recognition` in
  /// `app/pubspec.yaml`. Nothing in the application reads it.
  static const String toolName = 'google_mlkit_text_recognition 0.17.1';

  final mlkit.TextRecognizer _recognizer;
  bool _closed = false;

  @override
  Future<List<OcrElement>> recogniseImage({
    required Uint8List pixels,
    required int width,
    required int height,
  }) async {
    final mlkit.RecognizedText recognised = await _recognizer.processImage(
      mlkit.InputImage.fromBitmap(bitmap: pixels, width: width, height: height),
    );
    return _elementsOf(recognised);
  }

  @override
  Future<List<OcrElement>> recogniseFile(String path) async {
    final mlkit.RecognizedText recognised = await _recognizer.processImage(
      mlkit.InputImage.fromFilePath(path),
    );
    return _elementsOf(recognised);
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _recognizer.close();
  }

  /// The engine's elements, in the engine's order: blocks, then their lines,
  /// then the line's elements.
  ///
  /// The nesting is walked only to reach the elements — a block and a line are
  /// not words and are not returned as one.
  List<OcrElement> _elementsOf(mlkit.RecognizedText recognised) {
    final List<OcrElement> elements = <OcrElement>[];
    for (final mlkit.TextBlock block in recognised.blocks) {
      for (final mlkit.TextLine line in block.lines) {
        for (final mlkit.TextElement element in line.elements) {
          final Rect box = element.boundingBox;
          elements.add(
            OcrElement(
              element.text,
              box.left.round(),
              box.top.round(),
              box.right.round(),
              box.bottom.round(),
            ),
          );
        }
      }
    }
    return elements;
  }
}
