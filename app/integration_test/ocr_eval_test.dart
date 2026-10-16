import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:paperdrop/adapters/ocr/image_header.dart';
import 'package:paperdrop/adapters/ocr/mlkit_ocr_text_source.dart';
import 'package:paperdrop/adapters/ocr/ocr_text_source.dart';
import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../test/tool/ocr_eval_json.dart';
import '../test/tool/ocr_pass_agreement.dart';

/// The photo route's evaluation harness — an Android integration test, run on
/// the device **by the orchestrator and never in CI**
/// (`implement-photo-route`, design §4).
///
/// **What it does.** Given the directory of documents on the command line
/// (`--dart-define=OCR_EVAL_DIR=…`, the app's private storage, where the
/// orchestrator pushes the photographed corpus and the synthetic fixture with
/// `adb`), it reads every document through the adapter that ships — PDFs
/// rendered page by page, photographs in the passes of
/// `implement-photo-passes` design §2 — and writes **two** JSON files per
/// document next to the input: `<doc_id>.mlkit-ocr.json`, the detailed one in
/// the shape `test/tool/ocr_eval_json.dart` writes, to be pulled back to the
/// private corpus and read by whoever compares the passes in T2.5; and
/// `<doc_id>.mlkit-ocr-summary.json`, which holds **numbers and pass ids only**
/// — the words each pass read, the share of words two passes agree on after
/// normalising case and the punctuation around a word, the milliseconds of each
/// pass, and whether the passes reported the same page sizes — and not one word
/// of the document, so that the numbers the product owner reads can be read or
/// sent on without carrying a supplier's name.
///
/// **Every pass is reported separately.** The four readings of design §2 are
/// four readings of the same photograph, and this is what gives consensus
/// something to agree on (FR-EXT-006): the harness merges nothing, averages
/// nothing and takes no maximum, it applies **no threshold**, and it decides
/// nothing about which pass is worth keeping — that is T2.5's screening and the
/// product owner's. It reports what each pass read and which passes were
/// dropped, with the milliseconds each took.
///
/// **What it proves besides the words.** The SHA-256 of each input is taken
/// before and after the read and both are written into the detailed file (design
/// §1, "whether opening the file ever writes to it"): rendering for recognition
/// is read-only (ADR-015, `received-files-are-attached-byte-for-byte`), and a
/// read that changed the file is reported as a failure of the run and not as a
/// clean result with a different hash nobody looked at. The directory the render
/// buffers live in is checked as well, once per document: it must hold no file
/// after `recognise` has returned, on a device and not only in a host test.
/// Both failures are reported as numbers, in the summary file.
///
/// **The page sizes of one photograph.** Design §4 makes the passes of one
/// document convert their boxes with the same page size, and design §3 asks the
/// harness to assert it: a document whose passes disagree would have consensus
/// comparing boxes of different spaces, and the run fails with the count of
/// distinct sizes. That count is also what tells the orchestrator, without
/// reading a word, whether the device decoded an EXIF-oriented photograph the
/// way the file says it is shown.
///
/// **What it refuses to do.** It does not score the engine or decide anything:
/// ADR-010 is *proposed* and the threshold of FR-EXT-015 is GAP-003's, so this
/// harness produces numbers and the product owner takes the decision. It never
/// reads a document that is not in the directory it was given, and the private
/// corpus never enters the repository: what comes back is these JSON files and
/// nothing else.
///
/// **Without the define it is skipped**, so that `flutter test` stays green on a
/// machine with no corpus and no device.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const String evalDirectory = String.fromEnvironment('OCR_EVAL_DIR');

  test('every document is read, pass by pass, one JSON each', () async {
    final Directory input = Directory(evalDirectory);
    if (!input.existsSync()) {
      fail('OCR_EVAL_DIR is not a directory on this device: $evalDirectory');
    }

    final List<File> documents =
        input
            .listSync()
            .whereType<File>()
            .where(
              (File file) => _documentExtensions.contains(_extension(file)),
            )
            .toList()
          ..sort((File a, File b) => a.path.compareTo(b.path));
    if (documents.isEmpty) {
      fail('OCR_EVAL_DIR holds no document: $evalDirectory');
    }

    final Directory cache = await getApplicationCacheDirectory();
    final Directory buffers = Directory(
      p.join(cache.path, MlKitOcrTextSource.bufferDirectoryName),
    );

    final List<String> failures = <String>[];
    for (final File file in documents) {
      final String docId = p.basenameWithoutExtension(file.path);
      try {
        final Uint8List before = file.readAsBytesSync();
        final String sha256Before = sha256.convert(before).toString();

        final Map<String, int> msPerPass = <String, int>{};
        final List<OcrDroppedPass> dropped = <OcrDroppedPass>[];
        final List<OcrPass> passes = await MlKitOcrTextSource(
          onPassRecognised: (String passId, Duration elapsed) =>
              msPerPass[passId] = elapsed.inMilliseconds,
          onPassDropped: (String passId, Object error) =>
              dropped.add(OcrDroppedPass(passId, error.toString())),
        ).recognise(file.path);

        final String sha256After = sha256
            .convert(file.readAsBytesSync())
            .toString();
        File(p.join(file.parent.path, ocrEvalJsonFileName(docId: docId)))
            .writeAsStringSync(
              ocrEvalDocumentJson(
                docId: docId,
                tool: MlKitOcrTextSource.toolName,
                sha256Before: sha256Before,
                sha256After: sha256After,
                passes: passes,
                msPerPass: msPerPass,
                droppedPasses: dropped,
              ),
            );
        // The numbers the product owner reads: words per pass and the share of
        // words two passes agree on, with no word of the document in the file.
        File(p.join(file.parent.path, ocrEvalSummaryFileName(docId: docId)))
            .writeAsStringSync(
              ocrEvalSummaryJson(
                docId: docId,
                tool: MlKitOcrTextSource.toolName,
                sha256Before: sha256Before,
                sha256After: sha256After,
                passes: passes,
                msPerPass: msPerPass,
                droppedPasses: dropped,
              ),
            );

        // The written files hold both hashes whether they agree or not; the
        // disagreement is what makes the run fail.
        if (sha256Before != sha256After) {
          failures.add(
            '$docId: reading changed the file '
            '($sha256Before became $sha256After)',
          );
        }
        if (buffers.existsSync() && buffers.listSync().isNotEmpty) {
          failures.add(
            '$docId: a render buffer outlived the call: '
            '${buffers.listSync().map((FileSystemEntity entity) => p.basename(entity.path)).join(', ')}',
          );
        }
        if (passes.isEmpty) {
          failures.add('$docId: no pass read the document');
        }
        // Design §4, asserted on the device and reported as a number: the
        // passes of one document convert their boxes with the same page size,
        // so they report the same sizes for the same pages. A pass that
        // measured another page would have consensus compare boxes of different
        // spaces — which is also how a decoder that ignored a photograph's EXIF
        // orientation would show up.
        final int sizes = distinctPageSizes(passes);
        if (passes.isNotEmpty && sizes != 1) {
          failures.add(
            '$docId: the passes disagree on the page size ($sizes sizes)',
          );
        }
        // A photograph's page size is the size the picture is *displayed* at:
        // its frame header's size, with the sides exchanged when its EXIF
        // orientation says the picture is shown a quarter turn round. On the
        // device this says whether the passes of a real photographed page were
        // converted with the size the file declares — as a count of passes, and
        // not with any word of the document.
        if (_imageExtensions.contains(_extension(file))) {
          final ImagePixelSize? stored = imagePixelSizeIn(file);
          final ImagePixelSize? displayed = stored == null
              ? null
              : displayedImageSize(stored, imageExifOrientationIn(file));
          if (displayed != null) {
            final List<int> expected = <int>[
              displayed.width * 1000,
              displayed.height * 1000,
            ];
            final int wrong = passes
                .where(
                  (OcrPass pass) => pass.pages.any(
                    (TextPage page) =>
                        page.width != expected[0] || page.height != expected[1],
                  ),
                )
                .length;
            if (wrong != 0) {
              failures.add(
                '$docId: $wrong of ${passes.length} passes report another page '
                'size than the photograph displays',
              );
            }
          }
        }
      } catch (error) {
        failures.add('$docId: $error');
      }
    }

    expect(
      failures,
      isEmpty,
      reason:
          'every document must be read before it can be compared; these were '
          'not:\n${failures.join('\n')}',
    );
  }, skip: evalDirectory.isEmpty ? _noDirectory : null);
}

/// The documents the photo route reads: a PDF the scanner produced, or one of
/// the two image types the MVP accepts.
const List<String> _documentExtensions = <String>[
  '.pdf',
  '.jpg',
  '.jpeg',
  '.png',
];

/// The two of those that are one photograph rather than a document of pages:
/// the files whose page size is the size the picture is displayed at, and whose
/// passes are the passes of `implement-photo-passes` design §2.
const List<String> _imageExtensions = <String>['.jpg', '.jpeg', '.png'];

String _extension(File file) => p.extension(file.path).toLowerCase();

const String _noDirectory =
    'OCR_EVAL_DIR is not set: the harness runs on the device, over the private '
    'corpus and the synthetic fixture, and reads nothing here';
