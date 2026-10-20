/// The review screen's state and everything it does — plain Dart, driven by a widget and testable
/// without one.
///
/// Requirement served: FR-REV-001 (`review-screen/destination-bar`), FR-REV-002
/// (`review-screen/daily-destination-confirmation`), FR-REV-004
/// (`review-screen/six-core-fields-in-fixed-order`), FR-REV-005 and FR-REV-010
/// (`review-screen/amounts-block-collapse-rule`), FR-REV-007 (`review-screen/duplicate-notice`),
/// FR-REV-008 (`review-screen/save-button-names-the-destination`), FR-REV-009
/// (`review-screen/never-block-a-save`) and FR-REV-011 (`review-screen/discard-a-document`), with
/// DEC-007. Design §1 to §5 of `implement-review-screen` settle the shape.
///
/// **And two rules of `adopt-app-cust-readers`.** The country of a photographed ticket is an input
/// (`countries-languages` · `country-is-an-input`, DEC-022): the ticket takes the settings default,
/// the screen shows it, and a change made here is that ticket's alone — the settings are not
/// written, nothing is re-read by the change itself, and the values already on screen stay exactly
/// as they were read. And the second read is requested, not automatic
/// (`review-screen` · `second-read-is-requested-and-shown-running`, DEC-024): [ReviewController.reRead]
/// runs it, [ReviewState.reReading] is what the screen draws while it runs, and
/// `mergeSecondRead` is the rule that keeps every value the user edited or typed.
///
/// **State first, widgets second.** The controller owns what the screen shows — the stored entry,
/// the document as far as it has been edited, the destination, the acknowledgement, the duplicate
/// answer and the outcome of a save — and the widget renders it. A host test drives every scenario
/// of the cut requirements through this class with a store in a folder it owns and a sender that
/// records what it was handed (design §1 and §7).
///
/// **An edit is an [Edited], and it is what is sent.** Nothing here recomputes a value, re-imposes a
/// colour or overrides a correction: `user-edits-are-authoritative` is the rule the whole class is
/// built around, and DEC-007 says an edit made after a passing check leaves the amounts block
/// exactly as the check left it. The block's layout is computed over the **extracted** values
/// ([ReviewState.extracted]) while its numbers come from the current ones ([ReviewState.document]).
///
/// **A save leaves the record to the send lane.** [save] hands [ReviewSender] the entry as the user
/// built it and keeps the pipeline's answer: it creates nothing, writes no state and makes no call
/// of its own (`review-screen` *Out of Scope*; `ninox-send` owns the send and the confirmation).
/// The one write this class makes is the duplicate flag, and design §5 asks for it by name.
///
/// **What it never does.** It never blocks a save on a field: no value, no colour and no duplicate
/// can disable the action. The single condition that may is the day's destination acknowledgement,
/// which design §4 and FR-REV-002 make the exception on purpose.
library;

import 'dart:io' show IOException;

import 'package:ninox_client/ninox_client.dart'
    show Clock, RecordId, SendOutcome, TableRef, recordLink;
import 'package:paperdrop/features/review/capture_discard.dart';
import 'package:paperdrop/features/review/destination_acknowledgement.dart';
import 'package:paperdrop/features/review/review_amounts.dart';
import 'package:paperdrop/features/review/review_field.dart';
import 'package:paperdrop/features/review/review_second_read.dart';
import 'package:paperdrop/features/review/review_sender.dart';
import 'package:paperdrop/features/wizard/data/destination_store.dart';
import 'package:paperdrop/features/wizard/destination.dart';
import 'package:paperdrop/history/duplicate_checker.dart';
import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop/history/history_store.dart';
import 'package:paperdrop/settings/country_setting.dart';
import 'package:paperdrop_core/paperdrop_core.dart'
    show CalendarDate, CanonicalDocument, CountryRow, CountryTable;

/// The instant, in local time. The default [Clock].
DateTime _localNow() => DateTime.now();

/// Everything the review screen draws, in one mutable holder.
///
/// The controller is its only writer; the screen reads it after every action and redraws. It is a
/// holder and not a state machine: the rules are the controller's methods, so a widget cannot move
/// the screen by assigning a field.
final class ReviewState {
  /// The entry under review, or `null` before [ReviewController.load] has answered.
  HistoryEntry? entry;

  /// The values as they were extracted (or reloaded) — the block's layout is computed over these
  /// and never over an edit (DEC-007).
  CanonicalDocument? extracted;

  /// The values as they stand now: [extracted] with every edit the user has made as an [Edited].
  CanonicalDocument? document;

  /// The destinations the user may choose from, in the order the store holds them.
  List<Destination> destinations = const <Destination>[];

  /// The destination the save goes to: the one the document was captured with, until the user
  /// changes it from the bar (FR-REV-001, FR-REV-002).
  TableRef? destination;

  /// Whether the day's destination acknowledgement is still owed (FR-REV-002).
  bool acknowledgementRequired = false;

  /// The day it was last acknowledged on, or `null` when it never was.
  CalendarDate? acknowledgedOn;

  /// What the duplicate check found, or `null` when the document matches nothing (FR-REV-007).
  DuplicateMatch? duplicate;

  /// The existing record the notice links to, or `null` when it cannot be built.
  Uri? duplicateLink;

  /// Whether the user chose to proceed past the duplicate notice, which is what set the flag.
  bool duplicateProceeded = false;

  /// The fields whose green lock the user has tapped, and which are therefore editable
  /// (`green-is-editable-only-after-unlocking`).
  final Set<ReviewField> unlocked = <ReviewField>{};

  /// The field the screen puts the focus on when it opens (design §2).
  ReviewField focusField = ReviewField.docDate;

  /// Why the last edit was refused, or `null` when it was taken or none was made.
  ReviewEditRefusal? editRefusal;

  /// The country in force for this ticket, as an ISO 3166-1 alpha-2 code, or `null` when the
  /// settings hold none (`countries-languages` · `country-is-an-input`).
  ///
  /// It starts as the settings default and is this ticket's from the moment the user changes it
  /// here; the settings are never written from this screen.
  String? countryCode;

  /// The row [countryCode] resolves to in the country table, or `null` when the country has no row.
  ///
  /// A `null` row is the case GAP-036 settles: the app says so, applies no row in its place, and
  /// leaves the ticket's fields to be filled by hand. It is also what a ticket whose settings hold
  /// no country at all has.
  CountryRow? countryRow;

  /// The countries the screen may offer for this ticket: the rows the country table holds.
  ///
  /// It is the table's own list and not a list of ISO countries: no source in this project gives a
  /// country list beyond the table (`countries-languages` · `launch-rows`), and inventing one here
  /// would be data no requirement asked for.
  List<CountryRow> countryChoices = const <CountryRow>[];

  /// Whether a second read is running (DEC-024).
  ///
  /// The screen draws it, and it disables nothing: a save made while it runs is a save
  /// (`never-block-a-save`).
  bool reReading = false;

  /// Whether the last requested second read could not run, which changes none of the values.
  bool reReadFailed = false;

  /// Whether a save is in flight. Not a condition that disables the action; it only stops a second
  /// call from sending the same document twice.
  bool saving = false;

  /// What the pipeline answered to the last save, or `null` before one.
  SendOutcome? outcome;

  /// Whether the last save could not be sent because the store refused it (a flag that could not be
  /// written, a revision that was overtaken).
  bool saveFailed = false;

  /// Why the entry could not be loaded, or `null` when it was.
  HistoryStoreFailureCode? loadFailure;

  /// Whether the local capture has been discarded (FR-REV-011).
  bool discarded = false;

  /// Whether [load] is still running.
  bool loading = false;

  /// Whether the screen has something to draw.
  bool get ready => entry != null && document != null;

  /// The six fields of FR-REV-004 as the screen draws them, in their fixed order.
  List<ReviewFieldValue> get fields => switch (document) {
    final CanonicalDocument document? => reviewFieldValues(document),
    _ => const <ReviewFieldValue>[],
  };

  /// The amounts block: the layout the redundancy check produced, with the values as they stand.
  ReviewAmounts? get amounts => switch ((extracted, document)) {
    (final CanonicalDocument extracted?, final CanonicalDocument document?) =>
      reviewAmounts(extracted: extracted, current: document),
    _ => null,
  };

  /// Whether the document was flagged as needing a person's eyes (Core's own `needsReview`).
  ///
  /// A value read without a country row stays amber — the product owner's decision of 2026-10-17
  /// keeps the three states and adds no fourth — so this flag is the only thing that tells that
  /// document apart, and the screen shows one line saying so (design §2).
  bool get needsReview => extracted?.needsReview ?? false;

  /// Whether a country row was applied to this ticket, and so whether the photo route's readers
  /// ran at all (`countries-languages` · `country-is-an-input`, GAP-036).
  ///
  /// `false` is the case the screen has to warn about: no row applies, nothing is assumed in its
  /// place, and the fields are filled by hand.
  bool get countryHasRow => countryRow != null;

  /// Whether the country in force has no row in the country table, which is what the warning of
  /// `review-screen` · *a country without a row is announced on the ticket* is about.
  bool get countryWithoutRow => countryCode != null && countryRow == null;

  /// Whether the save action is enabled: **the acknowledgement is the only condition that may
  /// disable it** (FR-REV-009, design §4).
  bool get saveEnabled => !acknowledgementRequired;
}

/// The review screen's controller: it loads what the screen shows and performs its six actions.
final class ReviewController {
  /// Builds the controller over the store, the duplicate checker, the destination store, the
  /// acknowledgement file, the sender, the discard, the country setting, the second read and the
  /// clock.
  ///
  /// [entry] is the entry a caller already has — `ExtractionCompleted.entry`, or a history list's
  /// own — and it is what makes the screen open without a second read of the store. When it is
  /// `null`, [load] reads the entry by identifier, which is the path a history screen takes
  /// (design §1).
  ///
  /// [country] is the settings' default country and is only ever **read** here: a change made on
  /// this screen belongs to the ticket and never to the settings
  /// (`countries-languages` · *a change made for one ticket is not the new default*). [table] is
  /// the country table the ticket's country resolves its row in, the launch table unless a caller
  /// has one of its own.
  ReviewController({
    required this.store,
    required this.duplicates,
    required this.destinations,
    required this.acknowledgement,
    required this.sender,
    required this.discard,
    required this.country,
    required this.secondRead,
    CountryTable? table,
    Clock? clock,
    HistoryEntry? entry,
  }) : table = table ?? CountryTable.launch,
       clock = clock ?? _localNow,
       _known = entry;

  /// Where the entry is read from, and where a duplicate flag is written.
  final HistoryStore store;

  /// The read-side duplicate check of `document-history/duplicate-criteria`.
  final DuplicateChecker duplicates;

  /// Where the destinations the bar may offer come from.
  final DestinationStore destinations;

  /// The day the destination was last acknowledged.
  final DestinationAcknowledgement acknowledgement;

  /// How a save is sent.
  final ReviewSender sender;

  /// How a discarded document's local capture is deleted.
  final CaptureDiscard discard;

  /// The settings' default country, read once per ticket and never written from here.
  final CountrySettingStore country;

  /// The second read the user may ask for (DEC-024).
  final ReviewSecondRead secondRead;

  /// The table each country resolves its row in.
  final CountryTable table;

  /// What the screen reads the day from. The [DateTime] it answers is read as a local date.
  final Clock clock;

  final HistoryEntry? _known;

  final ReviewState _state = ReviewState();

  /// The settings' default country as it was read for this ticket.
  ///
  /// It is kept beside the state so that [countryFromSettings] can say whether what the ticket
  /// shows is still the default, without writing the setting back.
  String? _defaultCountryCode;

  /// The state the screen draws.
  ReviewState get state => _state;

  /// Whether the country on the ticket is still the settings default, rather than a value the user
  /// chose for this ticket (`review-screen` · *the next ticket goes back to the default*).
  bool get countryFromSettings => _state.countryCode == _defaultCountryCode;

  /// Loads everything the screen opens with (design §1, §4, §5).
  ///
  /// It reads the entry — from the constructor's [HistoryEntry] when one was given, otherwise from
  /// the store by [docId] — and then, in this order: the document the six fields and the amounts
  /// block are drawn from, the country in force for the ticket, the destinations the bar may
  /// offer, the day the destination was last acknowledged (which decides whether the save action
  /// is enabled), and the duplicate check with the link to what it found.
  ///
  /// **The country comes from the settings, not from the device** (`country-is-an-input`): the
  /// first run of the app stored the phone's region, and from then on it is a value of the user's.
  /// A settings file that cannot be read is *no country in force* — never an assumed one — so the
  /// ticket warns and its fields are filled by hand, like those of a country without a row.
  ///
  /// A store that refuses the entry is not an exception: [ReviewState.loadFailure] carries the
  /// refusal's code and the screen says, in the ARB's words, that the document could not be opened.
  /// A destination file that cannot be parsed is not fatal either — the bar still shows the
  /// destination the document was captured with, which is the requirement's *always visible* — and
  /// the sheet simply offers nothing else.
  Future<void> load([String? docId]) async {
    _state.loading = true;
    final HistoryEntry entry;
    try {
      final HistoryEntry? known = _known;
      if (known != null) {
        entry = known;
      } else if (docId != null) {
        entry = await store.get(docId);
      } else {
        throw ArgumentError(
          'load needs a docId when the controller was built without an entry',
        );
      }
    } on HistoryStoreFailure catch (failure) {
      _state.loadFailure = failure.code;
      _state.loading = false;
      return;
    }

    _state.entry = entry;
    _state.extracted = entry.values ?? _emptyDocument(entry);
    _state.document = _state.extracted;
    _state.destination = entry.destination;
    _state.focusField = reviewFocusField(_state.extracted!);
    await _readCountry();

    _state.destinations = await _readDestinations();
    _state.acknowledgedOn = await _lastAcknowledged();
    _state.acknowledgementRequired = _state.acknowledgedOn != _today(clock());

    final DuplicateMatch? match = await duplicates.check(
      DuplicateCandidate.fromDocument(
        docId: entry.docId,
        documentHash: entry.documentHash,
        values: _state.extracted!,
      ),
    );
    _state.duplicate = match;
    _state.duplicateLink = match == null ? null : await _linkTo(match.docId);

    _state.loading = false;
  }

  /// Takes [countryCode] as this ticket's country (`country-shown-and-editable-per-ticket`).
  ///
  /// Requirement served: `review-screen` · `country-shown-and-editable-per-ticket` and
  /// `countries-languages` · `country-is-an-input` — the change applies to the ticket it was made
  /// on, **it does not by itself re-read the document**, and it alters no value already produced by
  /// the read: amounts, dates and identifiers stay as they were read, and the row of the new
  /// country takes effect only if and when the document is read again — which is what the requested
  /// second read of [reRead] is. The settings are not written: the default does not change and the
  /// next ticket takes the default again.
  ///
  /// `null` is *no country*: the same state a settings file that names none leaves the ticket in.
  void chooseCountry(String? countryCode) {
    final String? code = _countryCode(countryCode);
    _state.countryCode = code;
    _state.countryRow = code == null ? null : table.rowFor(code);
  }

  /// Runs the second read of the document on screen, which the user asked for (DEC-024).
  ///
  /// Requirement served: `review-screen` · `second-read-is-requested-and-shown-running` and
  /// `extraction-pipeline` · `second-read-on-the-users-request` — it runs on the document already
  /// captured, under the country **now in force for the ticket** (so a country change reaches the
  /// values here, and only here), and it never overwrites a value the user edited or typed:
  /// [mergeSecondRead] answers the document as it stands with the second read's values where the
  /// user's own are not in the way.
  ///
  /// [ReviewState.reReading] is true for as long as the read runs, whichever way it ends, and the
  /// values on screen are untouched until it answers: a read that could not run sets
  /// [ReviewState.reReadFailed] and changes nothing else.
  Future<void> reRead() async {
    final HistoryEntry? entry = _state.entry;
    final CanonicalDocument? document = _state.document;
    if (entry == null || document == null || _state.reReading) {
      return;
    }
    _state.reReading = true;
    _state.reReadFailed = false;
    try {
      final CanonicalDocument second = await secondRead.reRead(
        entry,
        country: _state.countryRow,
      );
      final CanonicalDocument? extracted = _state.extracted;
      if (extracted != null) {
        _state.extracted = mergeSecondRead(
          current: extracted,
          secondRead: second,
        );
      }
      _state.document = mergeSecondRead(current: document, secondRead: second);
    } on Exception {
      _state.reReadFailed = true;
    } finally {
      _state.reReading = false;
    }
  }

  /// Takes [text] as the new value of [field], or records why it cannot be taken.
  ///
  /// A green value is editable only after its lock is tapped
  /// (`green-is-editable-only-after-unlocking`), and a refused edit changes nothing at all — the
  /// field keeps the value it had, which is what *no validation overrides the user* means in
  /// reverse: the app does not replace one wrong guess with another.
  bool edit(ReviewField field, String text) {
    final CanonicalDocument? document = _state.document;
    if (document == null) {
      return false;
    }
    final ReviewFieldValue current = reviewFieldValue(document, field);
    if (!current.editableWithoutUnlock && !_state.unlocked.contains(field)) {
      return false;
    }
    final ReviewEdit edit = editReviewField(
      document: document,
      field: field,
      text: text,
    );
    final CanonicalDocument? edited = edit.document;
    if (edited == null) {
      _state.editRefusal = edit.refusal;
      return false;
    }
    _state.document = edited;
    _state.editRefusal = null;
    return true;
  }

  /// Taps the lock of a green field, which is the only way into its editor
  /// (`green-is-editable-only-after-unlocking` · *the lock is the way in*).
  void unlock(ReviewField field) {
    _state.unlocked.add(field);
  }

  /// Whether [field] can be edited right now: amber, red and edited values always, green once its
  /// lock has been tapped.
  bool canEdit(ReviewField field) {
    final CanonicalDocument? document = _state.document;
    if (document == null) {
      return false;
    }
    return reviewFieldValue(document, field).editableWithoutUnlock ||
        _state.unlocked.contains(field);
  }

  /// Acknowledges the destination for today, which is what re-enables the save action (FR-REV-002).
  ///
  /// The day is written before the screen stops asking for it: a confirmation that was not recorded
  /// would come back on the next capture of the day, and one that was recorded but not shown would
  /// be worse. An [IOException] travels to the caller, which keeps the save action disabled.
  Future<void> acknowledge() async {
    final CalendarDate today = _today(clock());
    await acknowledgement.acknowledge(today);
    _state.acknowledgedOn = today;
    _state.acknowledgementRequired = false;
  }

  /// Puts [destination] in the bar, without leaving the document (FR-REV-001).
  ///
  /// Only the three identifiers travel: what a destination *is* belongs to the configuration and is
  /// resolved at send time (`document-history` on an entry's destination), so the entry the save
  /// sends names this destination and the mapping stays where it was configured.
  void chooseDestination(Destination destination) {
    _state.destination = TableRef(
      teamId: destination.teamId,
      databaseId: destination.databaseId,
      tableId: destination.tableId,
    );
  }

  /// Sends the document as the user built it (FR-REV-008, FR-REV-009, FR-REV-010).
  ///
  /// Three things happen, in this order: a duplicate notice that is standing is answered by
  /// proceeding — the flag is written, because a second record is being created on purpose
  /// (FR-REV-007, design §5) — the entry is assembled with the edited values and the destination
  /// the bar shows, and the pipeline is called. Nothing else is written: the state a send reaches
  /// is the send lane's, and the pipeline's answer is kept for the confirmation screen.
  ///
  /// A refused store — the flag that could not be written, a revision another write overtook — sets
  /// [ReviewState.saveFailed] and sends nothing: the store refusing is not the document failing, and
  /// the action stays available to try again. An empty document is not a reason to refuse anything:
  /// it is sent with its attachment and no data (`never-block-a-save` · *an empty document can still
  /// be saved*). A second read under way is not a reason to refuse anything either: it is not a
  /// condition of saving (`second-read-is-requested-and-shown-running` · *a save is not held back by
  /// a second read*), and the values sent are the ones on screen at that moment.
  Future<void> save() async {
    final HistoryEntry? entry = _state.entry;
    final CanonicalDocument? document = _state.document;
    if (entry == null || document == null || _state.saving) {
      return;
    }
    _state.saving = true;
    _state.saveFailed = false;
    try {
      HistoryEntry base = entry;
      if (_state.duplicate != null && !base.duplicateFlagged) {
        base = await duplicates.markDuplicate(entry.docId);
        _state.duplicateProceeded = true;
        _state.entry = base;
      }
      _state.outcome = await sender.send(
        _entryToSend(
          base,
          document: document,
          destination: _state.destination ?? base.destination,
        ),
      );
    } on HistoryStoreFailure {
      _state.saveFailed = true;
    } finally {
      _state.saving = false;
    }
  }

  /// Discards the document: no record, no history entry and no local file (FR-REV-011).
  ///
  /// The whole folder goes — the entry, the stored original and the thumbnail — so the history that
  /// reads folders to list documents has nothing left to show. Answers whether the capture is gone;
  /// a file system that refused leaves [ReviewState.discarded] false, which is the answer the screen
  /// needs to say that nothing was discarded.
  Future<bool> discardDocument() async {
    final HistoryEntry? entry = _state.entry;
    if (entry == null) {
      return false;
    }
    try {
      await discard.deleteCapture(entry.docId);
    } on Exception {
      return false;
    }
    _state.discarded = true;
    return true;
  }

  /// Reads the settings' default country and makes it this ticket's country.
  ///
  /// The setting is read once, when the ticket opens, and it is never written from here: the
  /// ticket's country is the default until the user changes it for this ticket, and the next
  /// ticket reads the default again (`countries-languages` · *a change made for one ticket is not
  /// the new default*). An [Exception] from the store is *no country in force*: the ticket then
  /// says so and its fields are filled by hand, rather than an assumed country deciding how the
  /// document was read.
  Future<void> _readCountry() async {
    final CountrySetting setting;
    try {
      setting = await country.read();
    } on Exception {
      // A settings file that cannot be read is no country in force, never an assumed one.
      _applyCountry(const CountrySetting(null));
      return;
    }
    _applyCountry(setting);
  }

  /// Makes [setting] this ticket's country, and remembers it as the default it came from.
  void _applyCountry(CountrySetting setting) {
    _defaultCountryCode = setting.countryCode;
    _state.countryCode = setting.countryCode;
    _state.countryRow = setting.rowIn(table);
    _state.countryChoices = table.rows;
  }

  /// The destinations the bar may offer, or none when the store cannot be read.
  Future<List<Destination>> _readDestinations() async {
    try {
      return await destinations.readAll();
    } on FormatException {
      // An unreadable destination file is reported by the wizard's store; here it means the sheet
      // offers nothing else, and the bar still shows the destination the document carries.
      return const <Destination>[];
    }
  }

  /// The day the destination was last acknowledged, or `null` when the file says nothing.
  Future<CalendarDate?> _lastAcknowledged() async {
    try {
      return await acknowledgement.lastAcknowledged();
    } on IOException {
      return null;
    }
  }

  /// The address of the record the duplicate check matched, or `null` when there is none to build.
  ///
  /// The entry it reads is the earlier document's, and only a `sent` one can match at all, so it
  /// carries the record identifier the link is built from. The link is `recordLink`'s — a pure
  /// function of the destination and the identifier, with no call and no credential (ADR-008,
  /// FR-SND-006) — and a store that refuses the read costs the notice its link, never its notice.
  Future<Uri?> _linkTo(String docId) async {
    final HistoryEntry earlier;
    try {
      earlier = await store.get(docId);
    } on HistoryStoreFailure {
      return null;
    }
    final RecordId? recordId = earlier.ninoxRecordId;
    if (recordId == null) {
      return null;
    }
    return recordLink(earlier.destination, recordId);
  }

  /// The entry a save sends: the stored one with the edited values and the destination the bar
  /// shows, and its revision untouched because this is not a write.
  HistoryEntry _entryToSend(
    HistoryEntry entry, {
    required CanonicalDocument document,
    required TableRef destination,
  }) => HistoryEntry(
    docId: entry.docId,
    revision: entry.revision,
    createdAt: entry.createdAt,
    state: entry.state,
    duplicateFlagged: entry.duplicateFlagged,
    documentHash: entry.documentHash,
    thumbnailPath: entry.thumbnailPath,
    destination: destination,
    values: document,
    confidence: entry.confidence,
    ninoxRecordId: entry.ninoxRecordId,
    failureReason: entry.failureReason,
  );

  /// The document an entry that was never extracted is shown as.
  ///
  /// Six fields nothing was read for, and nothing else: `never-block-a-save` requires that this
  /// document can still be saved with its attachment and no data, and a canonical document of
  /// [Absent] values is exactly *no data*. It carries the entry's own hash as its `sourceHash`
  /// because that is where the hash of the stored document lives, and no recognition engine because
  /// none ran.
  CanonicalDocument _emptyDocument(HistoryEntry entry) => CanonicalDocument(
    sourceHash: entry.documentHash,
    needsReview: false,
    recognitionEngine: '',
  );

  @override
  String toString() => 'ReviewController(${store.runtimeType})';
}

/// The local calendar day of [now], which is what the daily confirmation compares.
///
/// A [Clock] answers a [DateTime]; the day is read from its local fields and kept as the core's
/// [CalendarDate], which has no time zone to shift it (`daily-destination-confirmation` is one
/// calendar day as the person experiencing it counts days, not as UTC does).
CalendarDate _today(DateTime now) => CalendarDate(now.year, now.month, now.day);

/// [countryCode] as a country in force: upper case and trimmed, or `null` when there is none.
///
/// Nothing is inferred from what the user picked: a code the country table has no row for is a
/// country without a row and not a reason to fall back to another one
/// (`countries-languages` · *a country without a row is named and nothing is assumed*).
String? _countryCode(String? countryCode) {
  final String trimmed = (countryCode ?? '').trim().toUpperCase();
  return trimmed.isEmpty ? null : trimmed;
}
