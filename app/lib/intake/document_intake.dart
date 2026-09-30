import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:paperdrop/adapters/storage/app_storage.dart';
import 'package:paperdrop/intake/intake_failure.dart';
import 'package:paperdrop/intake/intake_result.dart';
import 'package:path/path.dart' as p;

/// The one entry of every path into the application (design §3): a file the app
/// was handed, or the PDF its own scanner produced.
///
/// **What it guarantees.** The stored copy is the input byte for byte — never
/// decoded, re-rendered, re-saved, flattened or re-compressed — and the SHA-256
/// of the stored copy equals the SHA-256 of the input. The digest is computed
/// over the input stream while copying and again over the file on disk, and the
/// two are compared: that comparison is the point of FR-CAP-005, because
/// re-saving a ZUGFeRD or Factur-X invoice destroys the legally authoritative
/// XML embedded in it while leaving a PDF that still looks right.
///
/// **What it does not keep.** No original file name reaches the path or the
/// result: the path is built from a random, content-free identifier, so nothing
/// about a person or a supplier travels in a file name.
class DocumentIntake {
  DocumentIntake({required this.storage, Random? random})
    : _random = random ?? Random.secure();

  /// Where the untouched originals are kept.
  final AppStorage storage;

  final Random _random;

  /// The folder of untouched originals, under the app documents directory.
  static const String originalsFolder = 'originals';

  /// The extension of the stored copy, per accepted media type (design §3).
  static const Map<String, String> extensionsByMediaType = <String, String>{
    'application/pdf': 'pdf',
    'image/jpeg': 'jpg',
    'image/png': 'png',
  };

  /// Stores [bytes] and returns what proves it happened.
  ///
  /// Throws [IntakeFailure] — and stores nothing — if the media type is not one
  /// of [IntakeResult.supportedMediaTypes], if the stream fails, if the storage
  /// cannot be written, or if the stored copy is not the input.
  Future<IntakeResult> intake(
    IntakeSource source,
    Stream<List<int>> bytes, {
    String? filename,
    String? mediaType,
  }) async {
    final String? resolvedType = resolveMediaType(
      mediaType: mediaType,
      filename: filename,
    );
    if (resolvedType == null) {
      // The declared type, when there is one, is what the refusal reports; a
      // file name is not, because nothing here keeps one.
      throw IntakeFailure(
        IntakeFailureCode.unsupportedMediaType,
        detail: mediaType,
      );
    }

    try {
      return await _store(
        docId: _newDocId(),
        source: source,
        mediaType: resolvedType,
        bytes: bytes,
      );
    } on IntakeFailure {
      rethrow;
    } on Error {
      // A programming mistake is not a broken document, and reporting it as one
      // would hide it behind a message about the user's file.
      rethrow;
    } catch (_) {
      throw const IntakeFailure(IntakeFailureCode.intakeFailed);
    }
  }

  Future<IntakeResult> _store({
    required String docId,
    required IntakeSource source,
    required String mediaType,
    required Stream<List<int>> bytes,
  }) async {
    final Directory root = await storage.documentsDirectory();
    final Directory folder = Directory(
      p.join(root.path, originalsFolder, docId),
    );
    await folder.create(recursive: true);
    final File target = File(
      p.join(folder.path, 'original.${extensionsByMediaType[mediaType]}'),
    );
    // Written beside its final name and renamed only once its digest has been
    // checked, so a document is either whole or absent.
    final File partial = File('${target.path}.part');

    bool stored = false;
    try {
      final Digest inputDigest = await _copyAndHash(bytes, partial);
      final Digest storedDigest = await _hashOf(partial);
      final int byteLength = await partial.length();
      if (storedDigest != inputDigest) {
        throw const IntakeFailure(IntakeFailureCode.intakeFailed);
      }
      await partial.rename(target.path);
      stored = true;
      return IntakeResult(
        docId: docId,
        source: source,
        mediaType: mediaType,
        byteLength: byteLength,
        sha256: storedDigest.toString(),
        storedPath: target.path,
      );
    } finally {
      if (!stored && await folder.exists()) {
        // The partial file lives inside the document's own folder, so this
        // removes both: no half-written document survives a failure.
        await folder.delete(recursive: true);
      }
    }
  }

  /// The media type this document is accepted as, or null if it is not accepted.
  ///
  /// The declared type wins when it is one of the three. A declared type that is
  /// not — `application/octet-stream` from a share that did not describe itself,
  /// for instance — falls back to the extension of the name. A document is never
  /// accepted as a media type outside the three, whatever either of them says.
  static String? resolveMediaType({String? mediaType, String? filename}) {
    final String declared = (mediaType ?? '').trim().toLowerCase();
    if (IntakeResult.supportedMediaTypes.contains(declared)) {
      return declared;
    }
    if (filename == null || filename.isEmpty) {
      return null;
    }
    switch (p.extension(filename).toLowerCase()) {
      case '.pdf':
        return 'application/pdf';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      default:
        return null;
    }
  }

  /// 128 bits from [Random.secure], hex encoded: random, and derived from
  /// nothing about the document (design §3).
  String _newDocId() {
    final List<int> bits = List<int>.generate(16, (_) => _random.nextInt(256));
    return bits.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Streams [bytes] into [partial], hashing as it copies, and returns the
  /// digest of the input. It never holds the document in memory.
  Future<Digest> _copyAndHash(Stream<List<int>> bytes, File partial) async {
    final _DigestSink sink = _DigestSink();
    final ByteConversionSink input = sha256.startChunkedConversion(sink);
    final RandomAccessFile out = await partial.open(mode: FileMode.write);
    try {
      await for (final List<int> chunk in bytes) {
        if (chunk.isEmpty) {
          continue;
        }
        input.add(chunk);
        await out.writeFrom(chunk);
      }
      input.close();
      return sink.digest;
    } finally {
      await out.close();
    }
  }

  /// The digest of the file on disk, read in chunks.
  Future<Digest> _hashOf(File file) => sha256.bind(file.openRead()).first;

  @override
  String toString() => 'DocumentIntake(originals: $originalsFolder)';
}

/// Keeps the single digest a `Hash` emits when its input is closed.
class _DigestSink implements Sink<Digest> {
  late Digest digest;

  @override
  void add(Digest data) => digest = data;

  @override
  void close() {}
}
