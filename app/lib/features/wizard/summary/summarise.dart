/// The closing summary, as a pure function over the string resources (design §6).
///
/// Requirement served: FR-WIZ-008 (`setup-wizard/plain-language-summary-and-first-document-offer`):
/// *a plain-language summary of the consequence — naming exactly which core fields will be saved and
/// which will not* — and FR-WIZ-007's consequence half, *the empty-record case is described*.
///
/// **A function and not a screen.** `summarise` takes a destination and the resources and returns
/// what to say; the screen that shows it is beside this file. That is what lets the three cases —
/// everything mapped, some of it, nothing — be tested without a widget, in the words the user reads.
///
/// **Plain language, not keys.** The sentences name the fields through `wizardCoreFieldLabel`, the
/// same switch the mapping step uses, so nobody is ever shown `doc_date`. The consequence is stated
/// rather than left to be discovered: what will be written, and what will not.
library;

import 'package:paperdrop/l10n/generated/app_localizations.dart';

import '../destination.dart';
import '../wizard_messages.dart';

/// What Paperdrop will do with a document sent to one destination.
final class SummaryText {
  /// Binds the sentences to the two lists they talk about.
  const SummaryText({
    required this.lines,
    required this.mapped,
    required this.unmapped,
  });

  /// The sentences to show, in order: what will be saved, then what will not — or the single
  /// sentence of the empty-record case.
  final List<String> lines;

  /// The core fields that will be saved, in the canonical order.
  final List<CoreField> mapped;

  /// The core fields that will not be saved, in the canonical order.
  final List<CoreField> unmapped;

  /// Whether nothing at all is mapped, which is the case the requirement describes in its own
  /// words.
  bool get isNothingMapped => mapped.isEmpty;

  /// Whether every mappable field is mapped.
  bool get isEverythingMapped => unmapped.isEmpty;

  @override
  String toString() => 'SummaryText(${lines.join(' ')})';
}

/// What to say about [destination], in plain language (design §6).
///
/// The mapping is a set of core fields, so a destination that names the same core field twice — it
/// cannot, `FieldMapping` is one per field in the state, but a stored file could — is summarised
/// once, by the core field.
///
/// Nothing here reads a clock, a file or a network: the same destination always gives the same
/// sentences, which is what lets the tests assert them and the screen show them unchanged.
SummaryText summarise(Destination destination, AppLocalizations l10n) {
  final Set<CoreField> mappedFields = <CoreField>{
    for (final FieldMapping mapping in destination.mappings) mapping.coreField,
  };
  final List<CoreField> saved = <CoreField>[
    for (final CoreField coreField in CoreField.values)
      if (mappedFields.contains(coreField)) coreField,
  ];
  final List<CoreField> notSaved = <CoreField>[
    for (final CoreField coreField in CoreField.values)
      if (!mappedFields.contains(coreField)) coreField,
  ];

  if (saved.isEmpty) {
    // The requirement's own sentence for this case: only the document will be attached, with no
    // data. Nothing is named, because nothing is saved.
    return SummaryText(
      lines: <String>[l10n.wizardSummaryNothingMapped],
      mapped: saved,
      unmapped: notSaved,
    );
  }

  return SummaryText(
    lines: <String>[
      l10n.wizardSummarySaved(_labels(l10n, saved)),
      if (notSaved.isNotEmpty)
        l10n.wizardSummaryNotSaved(_labels(l10n, notSaved)),
    ],
    mapped: saved,
    unmapped: notSaved,
  );
}

/// The fields' plain-language names, as one list a sentence can carry.
String _labels(AppLocalizations l10n, List<CoreField> coreFields) => coreFields
    .map((CoreField coreField) => wizardCoreFieldLabel(l10n, coreField))
    .join(', ');
