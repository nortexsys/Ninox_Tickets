import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:paperdrop/adapters/pdf_text/pdf_text_candidate.dart';
import 'package:paperdrop/adapters/pdf_text/pdfbox_text_candidate.dart';
import 'package:paperdrop/adapters/pdf_text/pdfrx_text_candidate.dart';
import 'package:path/path.dart' as p;

import '../test/tool/pdf_eval_json.dart';

/// The evaluation harness of ADR-011 — an Android integration test, run on the
/// device **by the orchestrator and never in CI** (`close-adr-011-pdf-text-route`,
/// design §2, task 1.3).
///
/// **What it does.** Given the directory of PDFs on the command line
/// (`--dart-define=PDF_EVAL_DIR=…`, the app's private storage, where the
/// orchestrator pushes the corpus with `adb`), it makes *both* candidates read
/// every PDF, and writes one JSON per document and candidate next to the input —
/// `<doc_id>.<candidate>-words.json`, in design §2's schema, to be pulled back
/// to the private corpus's `out` directory and compared by QA's script.
///
/// **What it proves besides the words.** The SHA-256 of each input is taken
/// before and after the read and both are written into the file (design §1,
/// "whether opening the file ever writes to it"): extraction is read-only
/// (ADR-015, `received-files-are-attached-byte-for-byte`), and a candidate that
/// changed the file is reported as a failure of the run and not as a clean
/// result with a different hash nobody looked at.
///
/// **What it refuses to do.** It does not compare the candidates, score them, or
/// decide anything: no threshold exists for the positional criterion or for the
/// size delta (GAP-003), so the harness produces numbers and the product owner
/// takes the decision on Tue 6 Oct. It also never reads a document that is not
/// in the directory it was given, and the private corpus never enters the
/// repository: what comes back is this JSON and nothing else.
///
/// **Without the define it is skipped**, so that `flutter test` stays green on a
/// machine with no corpus and no device.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const String evalDirectory = String.fromEnvironment('PDF_EVAL_DIR');

  test('both candidates read every PDF, one JSON each', () async {
    final Directory input = Directory(evalDirectory);
    if (!input.existsSync()) {
      fail('PDF_EVAL_DIR is not a directory on this device: $evalDirectory');
    }

    final List<File> documents =
        input
            .listSync()
            .whereType<File>()
            .where((File file) => p.extension(file.path).toLowerCase() == '.pdf')
            .toList()
          ..sort((File a, File b) => a.path.compareTo(b.path));
    if (documents.isEmpty) {
      fail('PDF_EVAL_DIR holds no PDF: $evalDirectory');
    }

    final List<String> failures = <String>[];
    for (final File file in documents) {
      final String docId = p.basenameWithoutExtension(file.path);
      for (final ({String token, PdfTextCandidate candidate}) entry
          in _candidates) {
        try {
          final Uint8List before = file.readAsBytesSync();
          final String sha256Before = sha256.convert(before).toString();

          final CandidateDocument document = await entry.candidate.read(
            file.path,
          );

          final String sha256After = sha256
              .convert(file.readAsBytesSync())
              .toString();
          File(
            p.join(
              file.parent.path,
              evalJsonFileName(docId: docId, candidateToken: entry.token),
            ),
          ).writeAsStringSync(
            evalDocumentJson(
              docId: docId,
              tool: entry.candidate.tool,
              sha256Before: sha256Before,
              sha256After: sha256After,
              msPerPage: document.msPerPage,
              pages: document.pages,
            ),
          );

          // The written file holds both hashes whether they agree or not; the
          // disagreement is what makes the run fail.
          if (sha256Before != sha256After) {
            failures.add(
              '$docId / ${entry.token}: reading changed the file '
              '($sha256Before became $sha256After)',
            );
          }
        } catch (error) {
          failures.add('$docId / ${entry.token}: $error');
        }
      }
    }

    expect(
      failures,
      isEmpty,
      reason:
          'every document must be read by both candidates before either can be '
          'compared; these were not:\n${failures.join('\n')}',
    );
  }, skip: evalDirectory.isEmpty ? _noDirectory : null);
}

/// The two candidates, with the token each is written under in a file name
/// (design §2). Both are here on purpose: the comparison needs both numbers, and
/// neither leaves the build before the decision of Tue 6 Oct.
const List<({String token, PdfTextCandidate candidate})> _candidates =
    <({String token, PdfTextCandidate candidate})>[
      (token: 'pdfbox-android', candidate: PdfBoxTextCandidate()),
      (token: 'pdfrx', candidate: PdfrxTextCandidate()),
    ];

const String _noDirectory =
    'PDF_EVAL_DIR is not set: the harness runs on the device, over the private '
    'corpus, and reads nothing here';
