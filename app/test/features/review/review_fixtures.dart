/// The documents, destinations and fakes the review screen's tests share.
///
/// **Nothing here reaches Ninox, a device or a token.** The sender is scripted, the destination
/// store and the acknowledgement are in memory, and the entries live in a folder the test owns
/// (`implement-review-screen`, design §1 and §7). Every identifier and every value is synthetic.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart' show addTearDown;
import 'package:ninox_client/ninox_client.dart'
    show NinoxEndpoint, SendOutcome, TableRef;
import 'package:paperdrop/features/review/capture_discard.dart';
import 'package:paperdrop/features/review/destination_acknowledgement.dart';
import 'package:paperdrop/features/review/review_second_read.dart';
import 'package:paperdrop/features/review/review_sender.dart';
import 'package:paperdrop/features/wizard/data/destination_store.dart';
import 'package:paperdrop/features/wizard/destination.dart';
import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop/history/history_store.dart';
import 'package:paperdrop/settings/country_setting.dart';
import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:path/path.dart' as p;

import '../../history/history_fixtures.dart';
import '../../history/send_fakes.dart';

/// The one currency of every fixture.
final CurrencyCode euro = CurrencyCode.parse('EUR')!;

/// The instant every fixture reads as *now*: a local date, as the daily confirmation reads it.
DateTime fixedClock() => DateTime(2026, 10, 17, 9, 30);

/// The day [fixedClock] is on.
CalendarDate fixedDay() => CalendarDate(2026, 10, 17);

/// A read amount in euro.
Present<Money> aReadAmount(int minor, ConfidenceState confidence) =>
    Present<Money>(Money(minor, euro), Provenance.read, confidence);

/// A document whose six core fields were all read, and whose `base + tax = total` check passed.
///
/// `10.00 + 2.10 = 12.10`, all in euro, with a green total — which is the state
/// `validation-confidence` gives a value confirmed by redundancy, and the only one the amounts block
/// collapses on (design §3). The supplier name and the document number are amber because Core never
/// confirms those two (`validation-confidence/three-confidence-strengths`).
CanonicalDocument aConfirmedDocument({bool needsReview = false}) =>
    CanonicalDocument(
      docDate: Present<CalendarDate>(
        CalendarDate(2026, 10, 1),
        Provenance.read,
        ConfidenceState.green,
      ),
      supplierName: Present<String>(
        'Acme Ibérica',
        Provenance.read,
        ConfidenceState.amber,
      ),
      supplierTaxId: Present<String>(
        'B00000000',
        Provenance.read,
        ConfidenceState.amber,
      ),
      docNumber: Present<String>(
        '2026-0042',
        Provenance.read,
        ConfidenceState.amber,
      ),
      grossTotal: aReadAmount(1210, ConfidenceState.green),
      currency: Present<CurrencyCode>(
        euro,
        Provenance.read,
        ConfidenceState.green,
      ),
      netTotal: aReadAmount(1000, ConfidenceState.green),
      taxTotal: aReadAmount(210, ConfidenceState.green),
      needsReview: needsReview,
      recognitionEngine: 'pdf-text/pdfrx',
      sourceHash: aDocumentHash(),
    );

/// A card-terminal slip that prints only a total: nothing to check the amount against.
///
/// Every amount is amber — *a clean reading with nothing to cross against is amber* — and the
/// amounts block has no breakdown, so it is expanded (design §3).
CanonicalDocument aTotalOnlyDocument() => CanonicalDocument(
  docDate: Present<CalendarDate>(
    CalendarDate(2026, 10, 2),
    Provenance.read,
    ConfidenceState.green,
  ),
  supplierName: Present<String>(
    'Card Terminal',
    Provenance.read,
    ConfidenceState.amber,
  ),
  grossTotal: aReadAmount(1999, ConfidenceState.amber),
  currency: Present<CurrencyCode>(euro, Provenance.read, ConfidenceState.green),
  needsReview: false,
  recognitionEngine: 'pdf-text/pdfrx',
  sourceHash: aDocumentHash('total-only'),
);

/// A two-rate receipt whose redundancy check does not pass: `20.00 + 1.90 ≠ 22.10`.
CanonicalDocument aMultiRateDocument() => CanonicalDocument(
  docDate: Present<CalendarDate>(
    CalendarDate(2026, 10, 3),
    Provenance.read,
    ConfidenceState.green,
  ),
  supplierName: Present<String>(
    'Two Rates S.L.',
    Provenance.read,
    ConfidenceState.amber,
  ),
  grossTotal: aReadAmount(2210, ConfidenceState.amber),
  currency: Present<CurrencyCode>(euro, Provenance.read, ConfidenceState.green),
  netTotal: aReadAmount(2000, ConfidenceState.green),
  taxTotal: aReadAmount(190, ConfidenceState.amber),
  taxSlots: <TaxSlot>[
    TaxSlot(
      rate: Present<RateBp>(
        RateBp(2100),
        Provenance.read,
        ConfidenceState.green,
      ),
      base: aReadAmount(1000, ConfidenceState.green),
      amount: aReadAmount(210, ConfidenceState.green),
    ),
    TaxSlot(
      rate: Present<RateBp>(
        RateBp(1000),
        Provenance.read,
        ConfidenceState.green,
      ),
      base: aReadAmount(1000, ConfidenceState.green),
      amount: aReadAmount(90, ConfidenceState.amber),
    ),
  ],
  needsReview: false,
  recognitionEngine: 'ocr/mlkit',
  sourceHash: aDocumentHash('multi-rate'),
);

/// A document read without a country row: every value amber, and Core's own `needsReview` set.
///
/// The product owner's decision of 2026-10-17 (point 6) keeps the three states: this document is
/// amber exactly like any other unconfirmed one, and only `needsReview` tells it apart — which is
/// what the screen's one line says (design §2).
CanonicalDocument aDocumentWithoutCountryRow() => CanonicalDocument(
  docDate: Present<CalendarDate>(
    CalendarDate(2026, 10, 4),
    Provenance.read,
    ConfidenceState.amber,
  ),
  supplierName: Present<String>(
    'Universal Core',
    Provenance.read,
    ConfidenceState.amber,
  ),
  grossTotal: aReadAmount(500, ConfidenceState.amber),
  currency: Present<CurrencyCode>(euro, Provenance.read, ConfidenceState.amber),
  needsReview: true,
  recognitionEngine: 'ocr/mlkit [country=noEvidence]',
  sourceHash: aDocumentHash('no-country-row'),
);

/// A document from which nothing could be read: every one of the six fields absent.
CanonicalDocument anUnreadDocument() => CanonicalDocument(
  needsReview: false,
  recognitionEngine: 'pdf-text/pdfrx',
  sourceHash: aDocumentHash('unread'),
);

/// A photographed ticket's document: its currency comes from the country row (DEC-023).
///
/// It is green — the state DEC-023 gives that one source — and its `ValueSource` is the country
/// setting, which is what the screen has to be able to say.
CanonicalDocument aPhotoDocument() => CanonicalDocument(
  docDate: Present<CalendarDate>(
    CalendarDate(2026, 10, 5),
    Provenance.read,
    ConfidenceState.amber,
  ),
  grossTotal: aReadAmount(1250, ConfidenceState.amber),
  currency: Present<CurrencyCode>(
    euro,
    Provenance.derived,
    ConfidenceState.green,
    source: ValueSource.countrySetting,
  ),
  needsReview: true,
  recognitionEngine: 'photo-ocr/google_mlkit_text_recognition 0.17.1',
  sourceHash: aDocumentHash('photo'),
);

/// A first read that produced the date and nothing else, for the second read's merge to fill.
CanonicalDocument aDocumentWithOnlyTheDate() => CanonicalDocument(
  docDate: Present<CalendarDate>(
    CalendarDate(2026, 10, 6),
    Provenance.read,
    ConfidenceState.amber,
  ),
  needsReview: true,
  recognitionEngine: 'photo-ocr/google_mlkit_text_recognition 0.17.1',
  sourceHash: aDocumentHash('date-only'),
);

/// The destination this device holds, and shows in the bar.
const Destination aStoredDestination = Destination(
  endpoint: NinoxEndpoint.cloud,
  teamId: 'team-1',
  databaseId: 'db-1',
  tableId: 'Expenses 2026',
);

/// A one-pixel PNG: a thumbnail that really is an image, built here instead of taken from anywhere.
final Uint8List onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNkYAAAAAYAAjCB'
  '0C8AAAAASUVORK5CYII=',
);

/// Writes a thumbnail into the document's own folder and answers its path.
///
/// The path is the app's own, as an entry's `thumbnailPath` is: it carries no name the user's
/// document came with (design §3 of the intake), and the folder is the one the test owns.
String aThumbnailFor(Directory root, String docId) {
  final Directory folder = Directory(p.join(root.path, docId))
    ..createSync(recursive: true);
  final File file = File(p.join(folder.path, 'thumbnail.png'))
    ..writeAsBytesSync(onePixelPng);
  return file.path;
}

/// A folder this test owns, removed when the test ends.
Directory aTempRoot() {
  final Directory root = Directory.systemTemp.createTempSync(
    'paperdrop-review',
  );
  addTearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });
  return root;
}

/// A second destination, so a test has something to choose.
const Destination anotherStoredDestination = Destination(
  endpoint: NinoxEndpoint.cloud,
  teamId: 'team-2',
  databaseId: 'db-2',
  tableId: 'Other table',
);

/// An entry under review, in the folder the test owns.
HistoryEntry aReviewingEntry({
  String? docId,
  CanonicalDocument? values,
  bool withoutValues = false,
  String? thumbnailPath,
  bool duplicateFlagged = false,
}) => anEntry(
  docId: docId,
  state: DocumentState.reviewing,
  values: withoutValues ? null : (values ?? aConfirmedDocument()),
  thumbnailPath: thumbnailPath,
  duplicateFlagged: duplicateFlagged,
  destination: aStoredDestination.toTableRef(),
);

/// The three identifiers of [aStoredDestination], as an entry carries them.
extension on Destination {
  /// The table reference an entry stores: the three identifiers and nothing else.
  TableRef toTableRef() =>
      TableRef(teamId: teamId, databaseId: databaseId, tableId: tableId);
}

/// A [DestinationStore] that holds what a test put in it.
final class FakeDestinationStore implements DestinationStore {
  /// Builds the store over [stored].
  FakeDestinationStore([this.stored = const <Destination>[aStoredDestination]]);

  /// What [readAll] answers.
  List<Destination> stored;

  /// Set when a read should behave like an unreadable file.
  bool unreadable = false;

  @override
  Future<List<Destination>> readAll() async {
    if (unreadable) {
      throw const FormatException('a destination that is not one');
    }
    return stored;
  }

  @override
  Future<void> save(Destination destination) async =>
      stored = <Destination>[destination];
}

/// A [DestinationAcknowledgement] whose file is a field.
final class MemoryAcknowledgement implements DestinationAcknowledgement {
  /// Builds the store over the day it already holds, or over none.
  MemoryAcknowledgement([this.day]);

  /// The day last acknowledged, or `null`.
  CalendarDate? day;

  /// Set when a write should behave like a file system that refused.
  bool refuse = false;

  @override
  Future<CalendarDate?> lastAcknowledged() async => day;

  @override
  Future<void> acknowledge(CalendarDate day) async {
    if (refuse) {
      throw const FileSystemException(
        'the acknowledgement could not be written',
      );
    }
    this.day = day;
  }
}

/// A [ReviewSender] that records what it was handed and answers a scripted outcome.
final class FakeReviewSender implements ReviewSender {
  /// Builds the sender over the answer each call gets.
  FakeReviewSender({SendOutcome Function(HistoryEntry entry)? answer})
    : answer = answer ?? ((HistoryEntry entry) => aSent());

  /// What a call answers.
  final SendOutcome Function(HistoryEntry entry) answer;

  /// Every entry a save sent, in order.
  final List<HistoryEntry> sent = <HistoryEntry>[];

  @override
  Future<SendOutcome> send(HistoryEntry entry) async {
    sent.add(entry);
    return answer(entry);
  }
}

/// A [CaptureDiscard] that records what it deleted.
final class FakeCaptureDiscard implements CaptureDiscard {
  /// Every document whose capture was deleted, in order.
  final List<String> deleted = <String>[];

  /// Set when a deletion should behave like a file system that refused.
  bool refuse = false;

  @override
  Future<void> deleteCapture(String docId) async {
    if (refuse) {
      throw const FileSystemException('the capture could not be deleted');
    }
    deleted.add(docId);
  }
}

/// A [CountrySettingStore] in memory: the settings' default country.
///
/// It exists so that a test can prove the two halves of `country-is-an-input` that are about the
/// settings rather than about the screen: the default is **read** when a ticket opens, and a change
/// made for one ticket **writes nothing here**.
final class FakeCountrySetting implements CountrySettingStore {
  /// Builds the store over [setting] — Spain unless a test says otherwise.
  FakeCountrySetting([this.setting = const CountrySetting('ES')]);

  /// What [read] answers.
  CountrySetting setting;

  /// Set when a read should behave like a file that is not one this app wrote.
  bool unreadable = false;

  /// How many times the setting was read.
  int reads = 0;

  /// How many times the setting was written.
  int writes = 0;

  @override
  Future<CountrySetting> read() async {
    reads++;
    if (unreadable) {
      throw const FormatException('the country file is not one of ours');
    }
    return setting;
  }

  @override
  Future<void> write(CountrySetting setting) async {
    writes++;
    this.setting = setting;
  }
}

/// A [ReviewSecondRead] a test scripts: what it answers, and what it was asked.
final class FakeReviewSecondRead implements ReviewSecondRead {
  /// Builds the read over [answer], which is the reading a call produces.
  FakeReviewSecondRead({CanonicalDocument Function(HistoryEntry entry)? answer})
    : answer = answer ?? ((HistoryEntry entry) => anUnreadDocument());

  /// What a call answers, unless [failure] says otherwise.
  CanonicalDocument Function(HistoryEntry entry) answer;

  /// The documents the second read was asked about, in order.
  final List<String> docIds = <String>[];

  /// The country each call was given, in order.
  final List<CountryRow?> countries = <CountryRow?>[];

  /// Set while a call should wait, so that a test can look at the screen while it runs.
  Completer<void>? pending;

  /// Set when the read should behave like a route that could not read the document.
  Exception? failure;

  @override
  Future<CanonicalDocument> reRead(
    HistoryEntry entry, {
    required CountryRow? country,
  }) async {
    docIds.add(entry.docId);
    countries.add(country);
    final Completer<void>? gate = pending;
    if (gate != null) {
      await gate.future;
    }
    final Exception? refusal = failure;
    if (refusal != null) {
      throw refusal;
    }
    return answer(entry);
  }
}

/// A [HistoryStore] in memory, for the widget tests.
///
/// **Why the widget tests do not use `FileHistoryStore`.** A `testWidgets` body runs in a zone whose
/// timers are the test binding's, so a real file system's completions are not delivered while the
/// tree is being pumped — the screen would still be loading when the frame under test was built. The
/// store's own behaviour is covered by the history tests and by the controller tests, which are
/// plain `test` bodies over a real file system (`review_controller_test.dart`); a widget test only
/// needs *a* store, and it does not need the file system to be the one.
final class MemoryHistoryStore implements HistoryStore {
  /// The entries by document identifier.
  final Map<String, HistoryEntry> entries = <String, HistoryEntry>{};

  @override
  Future<void> create(HistoryEntry entry) async {
    if (entries.containsKey(entry.docId)) {
      throw HistoryStoreFailure(
        HistoryStoreFailureCode.alreadyExists,
        docId: entry.docId,
      );
    }
    entries[entry.docId] = entry;
  }

  @override
  Future<HistoryEntry> get(String docId) async =>
      entries[docId] ??
      (throw HistoryStoreFailure(
        HistoryStoreFailureCode.notFound,
        docId: docId,
      ));

  @override
  Future<void> update(String docId, HistoryEntry entry) async {
    final HistoryEntry? stored = entries[docId];
    if (stored == null) {
      throw HistoryStoreFailure(HistoryStoreFailureCode.notFound, docId: docId);
    }
    if (entry.revision <= stored.revision) {
      throw HistoryStoreFailure(
        HistoryStoreFailureCode.staleRevision,
        docId: docId,
      );
    }
    entries[docId] = entry;
  }

  @override
  Future<HistoryListing> list() async {
    final List<HistoryEntry> sorted = entries.values.toList()
      ..sort((HistoryEntry a, HistoryEntry b) {
        final int byTime = b.createdAt.compareTo(a.createdAt);
        return byTime != 0 ? byTime : a.docId.compareTo(b.docId);
      });
    return HistoryListing(
      entries: List<HistoryEntry>.unmodifiable(sorted),
      unreadable: const <UnreadableEntry>[],
    );
  }

  @override
  Future<void> deleteOriginal(String docId) async {
    final HistoryEntry entry = await get(docId);
    if (entry.state != DocumentState.sent) {
      throw HistoryStoreFailure(
        HistoryStoreFailureCode.originalRetained,
        docId: docId,
      );
    }
  }
}
