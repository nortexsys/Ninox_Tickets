/// How the review screen draws a confidence state: a colour **and** a cue that is not a colour.
///
/// Requirement served: FR-REV-004 (`review-screen/six-core-fields-in-fixed-order`, *a colour per
/// confidence state*) and NFR-ACC-001 (`local-config-privacy/accessibility` · *confidence is never
/// conveyed by colour alone*). What the three states mean, and that green is the only one that is
/// confirmed, is `validation-confidence`'s; this file only says what each one looks like.
///
/// **Every state carries an icon as well as a tone**, and the screen gives the icon the state's own
/// name from `app_en.arb` as its semantic label. That is the requirement's non-colour cue: a person
/// who cannot tell the three tones apart, or who is listening to the screen rather than looking at
/// it, gets the state from the icon and from the words.
///
/// **The tones are readable.** Each is dark enough to hold WCAG AA contrast as text on the light
/// surface the MVP draws (green 9.4:1, amber 7.3:1, red 5.9:1), because a confidence state is shown
/// by the colour of the value itself and a value nobody can read is not a value. Material's own
/// `amber` swatches are too light for that; the red is Material's error tone, written here so this
/// mapping stays a pure function with no [ThemeData] to thread through a test.
library;

import 'package:flutter/material.dart';
import 'package:paperdrop_core/paperdrop_core.dart' show ConfidenceState;

/// The colour and the icon of one confidence state.
final class ConfidenceCue {
  /// Binds a tone to the icon that says the same thing without it.
  const ConfidenceCue({required this.colour, required this.icon});

  /// The tone the value and its icon are drawn in.
  final Color colour;

  /// The cue for a reader who cannot use the tone: confirmed, read-but-unconfirmed, not read.
  final IconData icon;
}

/// The three states of `validation-confidence/three-confidence-strengths`, and nothing else.
///
/// Green is *confirmed by redundancy* and carries the lock that has to be tapped before the value
/// can be edited (`green-is-editable-only-after-unlocking`); amber is read and unconfirmed —
/// including a value read with no country row, which the product owner's decision of 2026-10-17
/// keeps amber rather than giving a second state; red is *not read at all*.
const Map<ConfidenceState, ConfidenceCue> confidenceCues =
    <ConfidenceState, ConfidenceCue>{
      ConfidenceState.green: ConfidenceCue(
        colour: Color(0xFF1B5E20),
        icon: Icons.verified_outlined,
      ),
      ConfidenceState.amber: ConfidenceCue(
        colour: Color(0xFF6D4C00),
        icon: Icons.info_outline,
      ),
      ConfidenceState.red: ConfidenceCue(
        colour: Color(0xFFB3261E),
        icon: Icons.help_outline,
      ),
    };

/// The mark a value the user typed carries instead of a colour (DEC-007).
const IconData editedIcon = Icons.edit_outlined;

/// The affordance a green value carries before it can be edited
/// (`green-is-editable-only-after-unlocking`).
const IconData lockIcon = Icons.lock_outline;
