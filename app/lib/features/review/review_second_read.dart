/// The second read of the ticket on screen, as the review screen asks for it (DEC-024).
///
/// Requirement served: `review-screen` · `second-read-is-requested-and-shown-running` — the screen
/// offers the user a second read, shows that it is running while it runs, and keeps every value the
/// user edited or typed — and `extraction-pipeline` · `second-read-on-the-users-request`, which
/// says what a second read *is*: it works on the document already captured, runs the other reader
/// or further recognition passes, feeds the same consensus, and adds no cap, exception or
/// confidence state.
///
/// **Why an interface and not the service.** The screen must not open a file, pick a route or know
/// what a recognition pass is (design §1 of `implement-review-screen`: state first, widgets second;
/// and BR-09: the app authors no value of Core's model). It asks this seam for *the same document,
/// read again* and receives one reading; what merges it into what the user sees is
/// `user-edits-are-authoritative` and the screen's own merge, which is what [reRead] may not
/// decide.
///
/// **What a caller gets, and what it does not.** [reRead] answers a whole reading of the same
/// stored document under the country in force for the ticket. It is never told which fields to
/// keep: a value the user says is right stays the user's whatever this answers
/// (`review-screen` · *a value the user edited is not overwritten by the second read*).
///
/// **What an implementation owes.** Nothing in the entry: the entry is `reviewing` and a second
/// look is not a state (`document-states`), so a second read writes no entry, bumps no revision
/// and opens no file for writing (ADR-015). An [Exception] — a route that could not read the
/// document this time — leaves the screen's values as they were and stops saying that the read is
/// running; it is not a reason to lose anything the user typed.
library;

import 'package:paperdrop/history/history_entry.dart';
import 'package:paperdrop_core/paperdrop_core.dart'
    show CanonicalDocument, CountryRow;

/// One second read of the document under review.
abstract interface class ReviewSecondRead {
  /// Reads [entry]'s document again, under [country], and answers the whole reading.
  ///
  /// [country] is the country now in force for the ticket — after the user changed it on the
  /// review screen, the new one — and `null` means the country has no row, in which case the photo
  /// route reads nothing at all (GAP-036) and the answer carries no value.
  ///
  /// Throws an [Exception] when the document could not be read this time.
  Future<CanonicalDocument> reRead(
    HistoryEntry entry, {
    required CountryRow? country,
  });
}
