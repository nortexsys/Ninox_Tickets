import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ninox_client/ninox_client.dart' show TableRef;
import 'package:paperdrop/adapters/ocr/mlkit_ocr_text_source.dart';
import 'package:paperdrop/adapters/pdf_text/pdfrx_text_source.dart';
import 'package:paperdrop/adapters/storage/app_storage.dart';
import 'package:paperdrop/features/extraction/extraction_router.dart';
import 'package:paperdrop/features/extraction/extraction_service.dart';
import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop/history/history_store.dart';
import 'package:paperdrop/intake/document_intake.dart';
import 'package:paperdrop/intake/intake_result.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../test/tool/extraction_eval_json.dart';

/// The extraction step's evaluation harness — an Android integration test, run on
/// the device **by the orchestrator and never in CI**
/// (`add-extraction-device-harness`, task 1.2).
///
/// **What it does.** Given the directory of documents on the command line
/// (`--dart-define=EXTRACTION_EVAL_DIR=…`, the app's private storage, where the
/// orchestrator pushes the synthetic fixture and the private corpus with `adb`),
/// it takes every document in it through the pipeline that ships: `DocumentIntake`
/// copies it into a store of the harness's own, the entry it leaves behind is
/// created `pending` in a temporary `FileHistoryStore`, and `ExtractionService`
/// runs the real `ExtractionRouter` over the real adapters — the PDF text layer
/// through `pdfrx`, recognition through ML Kit — so the route is chosen, the
/// country detected and the values built on the device and not over fakes. One
/// **numbers-only** summary is written per document beside the input,
/// `<doc_id>.extraction-summary.json`, in the shape
/// `app/test/tool/extraction_eval_json.dart` writes.
///
/// **What the harness proves besides the numbers.** That the pipeline runs end to
/// end on the device — router, country detection, `extractDocument`, the state
/// machine and the store — which until now was proved only over fakes. That the
/// stored copy is the bytes the intake wrote, and that reading it changed nothing
/// (ADR-015, `capture-intake` · `received-files-are-attached-byte-for-byte`,
/// FR-CAP-005): the SHA-256 of the copy is taken around the call and the file
/// holds both hashes and the flag that says whether they agree. That the entry
/// the extraction wrote reads back from the device's own file system as the same
/// entry, so a document that a screen would open after a restart still has its
/// values and its state. And that every document in the directory was read: a
/// document no route could read, or a document whose entry came back in another
/// state than the one the step answers with, fails the run and is not a clean
/// result with a number nobody looked at.
///
/// **What it refuses to do.** It never sends: no Ninox call, no token, no table.
/// It scores nothing and applies no threshold — accuracy needs ground truth (T2.5)
/// and FR-EXT-015's threshold is GAP-003's, so the file reports a route, a set of
/// states and a duration, and the product owner takes the decision. It reads no
/// document outside the directory it was given, it writes nothing into that
/// directory except the summaries, and the private corpus never enters the
/// repository: what comes back is these JSON files and nothing else, holding no
/// value of any document.
///
/// **Without the define it is skipped**, so that `flutter test` stays green on a
/// machine with no corpus and no device.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const String evalDirectory = String.fromEnvironment('EXTRACTION_EVAL_DIR');

  test('every document goes through the extraction, one summary each', () async {
    final Directory input = Directory(evalDirectory);
    if (!input.existsSync()) {
      fail(
        'EXTRACTION_EVAL_DIR is not a directory on this device: $evalDirectory',
      );
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
      fail('EXTRACTION_EVAL_DIR holds no document: $evalDirectory');
    }

    final Directory cache = await getApplicationCacheDirectory();
    final List<String> failures = <String>[];
    for (final File file in documents) {
      final String docId = p.basenameWithoutExtension(file.path);
      // A store of the harness's own, one folder per document under the cache
      // directory: the intake copies the document into it, the extraction reads
      // the copy, and it is deleted once the numbers are written — so a run over
      // the corpus leaves the corpus as it found it and nothing behind on the
      // device.
      final Directory work = Directory(
        p.join(cache.path, _workDirectoryName, docId),
      );
      try {
        final DocumentIntake intake = DocumentIntake(storage: _StorageIn(work));
        // The source says only how a document reached the pipeline, and no value
        // of it depends on that: a file the orchestrator pushed is read as one the
        // user picked, which is what it is — a file the app was handed.
        final IntakeResult document = await intake.intake(
          IntakeSource.picker,
          file.openRead(),
          filename: p.basename(file.path),
        );
        final FileHistoryStore store = FileHistoryStore(
          Directory(p.join(work.path, DocumentIntake.originalsFolder)),
        );
        // The entry the capture step leaves behind: `pending`, with the stored
        // copy's own hash, which is what `ExtractionService.extract` starts from.
        await store.create(
          HistoryEntry(
            docId: document.docId,
            revision: 1,
            createdAt: DateTime.now().toUtc(),
            state: DocumentState.pending,
            documentHash: document.sha256,
            destination: _nowhere,
          ),
        );

        final ExtractionService service = ExtractionService(
          store: store,
          router: ExtractionRouter(
            pdfText: const PdfrxTextSource(),
            ocr: MlKitOcrTextSource(),
          ),
        );

        // The route reads the stored copy, so that is the document whose hash
        // says whether reading it wrote to it (ADR-015).
        final File stored = File(document.storedPath);
        final String sha256Before = sha256
            .convert(stored.readAsBytesSync())
            .toString();
        final Stopwatch elapsed = Stopwatch()..start();
        final ExtractionOutcome outcome = await service.extract(document);
        elapsed.stop();
        final String sha256After = sha256
            .convert(stored.readAsBytesSync())
            .toString();

        // The numbers the product owner reads, beside the input and never inside
        // the repository.
        File(p.join(file.parent.path, extractionSummaryFileName(docId: docId)))
            .writeAsStringSync(
              extractionEvalSummaryJson(
                outcome: outcome,
                sha256Before: sha256Before,
                sha256After: sha256After,
                ms: elapsed.elapsedMilliseconds,
              ),
            );

        if (sha256Before != sha256After) {
          failures.add('$docId: extracting changed the stored copy');
        }
        if (sha256Before != document.sha256) {
          failures.add(
            '$docId: the stored copy is not the bytes the intake wrote',
          );
        }
        if (await store.get(document.docId) != outcome.entry) {
          failures.add(
            '$docId: the entry does not read back as the one the extraction '
            'wrote',
          );
        }

        switch (outcome) {
          case ExtractionCompleted(
            entry: HistoryEntry(:final state),
            document: final values,
          ):
            if (state != DocumentState.reviewing) {
              failures.add(
                '$docId: a document that was read is in ${state.name}',
              );
            }
            if (values.sourceHash != document.sha256) {
              failures.add('$docId: the values carry another document');
            }
          case ExtractionRefused(
            :final failure,
            entry: HistoryEntry(:final state),
          ):
            if (state != DocumentState.failed) {
              failures.add(
                '$docId: a document that was refused is in ${state.name}',
              );
            }
            // A refusal is reported, and it is a failure of the run: every
            // document in the directory must be readable end to end, and the
            // code names the port that could not read it.
            failures.add(
              '$docId: no route could read the document '
              '(${failure.code.code})',
            );
        }
      } catch (error) {
        failures.add('$docId: $error');
      } finally {
        if (work.existsSync()) {
          work.deleteSync(recursive: true);
        }
      }
    }

    expect(
      failures,
      isEmpty,
      reason:
          'every document must be read by the route before its numbers can be '
          'compared; these were not:\n${failures.join('\n')}',
    );
  }, skip: evalDirectory.isEmpty ? _noDirectory : null);
}

/// The folder under the cache directory one document's store is built in, and
/// deleted with it.
const String _workDirectoryName = 'extraction-eval';

/// The documents the pipeline reads: the two media types of the intake's
/// `supportedMediaTypes` that carry pages, and the PDF the scanner produces.
const List<String> _documentExtensions = <String>[
  '.pdf',
  '.jpg',
  '.jpeg',
  '.png',
];

String _extension(File file) => p.extension(file.path).toLowerCase();

/// The destination a harness entry carries.
///
/// A `HistoryEntry` has the field and it cannot be defaulted, so the harness
/// gives it three content-free placeholders: nothing here sends, no workspace is
/// named, and no token is read — the extraction is the last step before review and
/// the send pipeline is not part of this run.
const TableRef _nowhere = TableRef(
  teamId: 'eval',
  databaseId: 'eval',
  tableId: 'eval',
);

/// The store one document is copied into: the folder the harness made for it, so
/// that `DocumentIntake` writes the copy under `originals/<docId>/` inside it and
/// the eval directory the document was read from is never written to.
final class _StorageIn implements AppStorage {
  /// Keeps the copy of one document in [root].
  const _StorageIn(this.root);

  /// The folder this run's documents directory is.
  final Directory root;

  @override
  Future<Directory> documentsDirectory() async => root;
}

const String _noDirectory =
    'EXTRACTION_EVAL_DIR is not set: the harness runs on the device, over the '
    'synthetic fixture and the private corpus, and reads nothing here';
