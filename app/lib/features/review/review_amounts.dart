/// The amounts block of the review screen: when it collapses, and what it shows when it does not.
///
/// Requirement served: FR-REV-005 and FR-REV-010 (`review-screen/amounts-block-collapse-rule`,
/// `review-screen/user-edits-are-authoritative`) with DEC-007. Design §3 of
/// `implement-review-screen` settles the rule.
///
/// **Where the rule reads from, and why it is two documents.** Whether the block collapses is
/// decided by the **redundancy check on the extracted values** — a green total confirmed by
/// `base + tax = total` — and by nothing the user typed. That is the whole of DEC-007: an edit made
/// after a passing check leaves the block as the check left it
/// (`amounts-block-collapse-rule` · *an edit after a passing check does not re-expand the block*),
/// so the check is computed over the document as it was extracted and never over the edits. The
/// values the block *shows* are the current ones, so an edited amount appears — marked as edited —
/// in the layout the check produced.
///
/// **Collapsed, exactly when the check passed.** The total is green and confirmed, and the base and
/// the tax to check it against were both read, and their sum is the total to the minor unit
/// (`validation-confidence/redundancy-checks-on-amounts`). A card slip printing only a total has no
/// breakdown to check, so it expands (`amounts-block-collapse-rule` · *no breakdown to check means
/// expanded*), and so does every document whose check fails or whose total is amber — *the block is
/// not collapsed merely because no error was raised*.
///
/// **The arithmetic is the core's.** [sumMatchesTotal] is the one place the identity appears
/// (`validation-confidence`), so this file compares nothing itself and holds no tolerance.
library;

import 'package:paperdrop_core/paperdrop_core.dart'
    show
        CanonicalDocument,
        ConfidenceState,
        Edited,
        FieldValue,
        Money,
        Present,
        RateBp,
        TaxSlot,
        sumMatchesTotal;

/// What one line of the amounts block is.
enum AmountLineKind {
  /// The net total, the base the tax is computed on.
  base,

  /// The tax total.
  tax,

  /// One printed tax rate and its amount.
  taxSlot,

  /// The gross total, printed or derived.
  total,
}

/// One line of the block: the amount, and for a tax slot the rate it belongs to.
final class ReviewAmountLine {
  /// Binds the amount to the kind of line it is.
  const ReviewAmountLine({required this.kind, required this.value, this.rate});

  /// Which amount of the document this line shows.
  final AmountLineKind kind;

  /// The amount as the document currently holds it — an [Edited] one if the user changed it.
  final FieldValue<Money> value;

  /// The printed rate of a [AmountLineKind.taxSlot] line, or `null` on every other line.
  final RateBp? rate;

  /// The amount, or `null` when nothing was read for this line.
  Money? get amount => switch (value) {
    Present<Money>(value: final Money value) => value,
    Edited<Money>(value: final Money value) => value,
    _ => null,
  };

  /// Whether the user typed this amount, which is what the *edited* mark says (DEC-007).
  bool get edited => value is Edited<Money>;

  /// Whether the document prints a value for this line at all.
  ///
  /// An occupied slot is one that carries a rate, a base or an amount; [Absent] and [NotInXml] are
  /// not occupied and are not shown (`amounts-block-collapse-rule` · *several slots are all visible
  /// when the check does not pass*).
  bool get occupied => amount != null;

  @override
  String toString() =>
      'ReviewAmountLine(${kind.name}${rate == null ? '' : ', ${rate!.bp}bp'}, '
      '${occupied ? (edited ? 'edited' : 'read') : 'not read'})';
}

/// The amounts block as the screen draws it.
final class ReviewAmounts {
  /// Binds the layout the check produced to the values the block shows.
  const ReviewAmounts({required this.collapsed, required this.lines});

  /// Whether the block is one confirming line, which the redundancy check alone decides (DEC-007).
  final bool collapsed;

  /// Every amount of the document, in the order the block shows them: base, tax, one line per
  /// occupied tax slot, and the total last.
  ///
  /// The list is the whole of the document's amounts, occupied or not — a [ReviewAmountLine] says
  /// whether it is — so the screen can render the expanded block without deciding anything.
  final List<ReviewAmountLine> lines;

  /// The lines a viewer actually sees: all of them when the block is expanded, and only the total
  /// when it is collapsed.
  List<ReviewAmountLine> get visibleLines => collapsed
      ? <ReviewAmountLine>[
          for (final ReviewAmountLine line in lines)
            if (line.kind == AmountLineKind.total) line,
        ]
      : <ReviewAmountLine>[
          for (final ReviewAmountLine line in lines)
            if (line.occupied) line,
        ];

  /// The total the block is about, or `null` when the document carries none.
  Money? get total => _totalLine?.amount;

  /// Whether the user typed the total.
  bool get totalEdited => _totalLine?.edited ?? false;

  /// The line of the gross total — the one the collapsed block is.
  ReviewAmountLine? get _totalLine {
    for (final ReviewAmountLine line in lines.reversed) {
      if (line.kind == AmountLineKind.total) {
        return line;
      }
    }
    return null;
  }

  @override
  String toString() =>
      'ReviewAmounts(${collapsed ? 'collapsed' : 'expanded'}, '
      '${visibleLines.length} visible)';
}

/// The block of [extracted] — which decides its layout — showing the values of [current].
///
/// The two are the same document until the user edits one of its fields; a field that has been
/// edited is an [Edited] in [current] and is still the extracted value in [extracted], which is
/// exactly what DEC-007 needs.
ReviewAmounts reviewAmounts({
  required CanonicalDocument extracted,
  required CanonicalDocument current,
}) => ReviewAmounts(
  collapsed: amountsCheckPassed(extracted),
  lines: <ReviewAmountLine>[
    ReviewAmountLine(kind: AmountLineKind.base, value: current.netTotal),
    ReviewAmountLine(kind: AmountLineKind.tax, value: current.taxTotal),
    for (final TaxSlot slot in current.taxSlots)
      if (_occupiedSlot(slot))
        ReviewAmountLine(
          kind: AmountLineKind.taxSlot,
          value: _slotAmount(slot),
          rate: switch (slot.rate) {
            Present<RateBp>(value: final RateBp value) => value,
            Edited<RateBp>(value: final RateBp value) => value,
            _ => null,
          },
        ),
    ReviewAmountLine(kind: AmountLineKind.total, value: current.grossTotal),
  ],
);

/// Whether [document]'s amounts passed the one redundancy check this screen reads (design §3).
///
/// The total is green — which `validation-confidence` assigns only to a value confirmed by
/// redundancy, never to a clean reading with nothing to cross against — the base and the tax were
/// both read, and `base + tax = total` holds exactly.
bool amountsCheckPassed(CanonicalDocument document) {
  final Present<Money>? net = _present(document.netTotal);
  final Present<Money>? tax = _present(document.taxTotal);
  final Present<Money>? gross = _present(document.grossTotal);
  if (net == null || tax == null || gross == null) {
    return false;
  }
  if (gross.confidence != ConfidenceState.green) {
    return false;
  }
  return sumMatchesTotal(net.value, tax.value, gross.value);
}

/// A tax rate as the block prints it: `21` for 2100 basis points, `5.5` for 550.
///
/// A percentage and not a decimal fraction, because that is what the document prints beside the
/// amount. The form is the canonical one and not a locale format: it is a rate, not an amount.
String ratePercentText(RateBp rate) {
  final int whole = rate.bp ~/ 100;
  final int fraction = rate.bp % 100;
  if (fraction == 0) {
    return '$whole';
  }
  final String digits = fraction.toString().padLeft(2, '0');
  return '$whole.${digits.endsWith('0') ? digits.substring(0, 1) : digits}';
}

/// [value] when it is a read amount, or `null` for an absent one and for a typed one.
///
/// The check is about what the document printed, so an edited amount can never make it pass or
/// fail: DEC-007 leaves the block exactly as the check on the extracted values left it.
Present<Money>? _present(FieldValue<Money> value) => switch (value) {
  Present<Money>() => value,
  _ => null,
};

/// Whether [slot] carries anything at all.
///
/// A slot the document prints no rate, base or amount for is not occupied and is drawn nowhere,
/// even when the block is expanded with several rates beside it.
bool _occupiedSlot(TaxSlot slot) =>
    _isValue(slot.rate) || _isValue(slot.base) || _isValue(slot.amount);

/// The amount of a slot line: its amount when it prints one, its base otherwise.
FieldValue<Money> _slotAmount(TaxSlot slot) =>
    _isValue(slot.amount) ? slot.amount : slot.base;

/// Whether [value] is a value rather than the absence of one.
bool _isValue(FieldValue<Object?> value) => switch (value) {
  Present<Object?>() || Edited<Object?>() => true,
  _ => false,
};
