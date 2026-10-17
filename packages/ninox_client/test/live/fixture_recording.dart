/// The re-recording helper for the recorded classic-API fixtures (change design §3).
///
/// `create-response` and `error-500` are re-recorded **from the real responses, structure only**:
/// the keys and their types are kept and every value is replaced by a synthetic one, so that no
/// live value of any kind reaches `test/fixtures/classic/`. This file is that transformation and
/// nothing else: it takes the recorded body **as text** and returns the fixture's text. It writes
/// no file and reads no file — the orchestrator applies it, on the machine that has the token, and
/// commits the result (change tasks 2.4).
///
/// **Why it is pure, and why it is here.** It is proved without a token by
/// `test/live/fixture_recording_test.dart`, in every lane and in every CI run: a helper that only
/// runs during a live run is a helper nobody has seen work. It touches no network, no environment
/// and no file.
///
/// **What the re-recording does not settle.** Whether the create response's identifier arrives as a
/// JSON number or as a string is still open (`test/fixtures/classic/README.md`); this helper keeps
/// whichever type the recorded body carried and gives it a placeholder value, and the fixture tests
/// that assert on a specific value are updated in the same commit as the re-recorded file. The
/// placeholders are the constants below, so that update is mechanical.
library;

import 'dart:convert';

/// The value a recorded **string** becomes.
///
/// A string is where a person's name, an identifier or a free-text note would live, so no string of
/// the recorded body survives the transformation.
const String syntheticText = 'synthetic';

/// The value a recorded **integer** becomes.
const int syntheticInteger = 1;

/// The value a recorded **decimal number** becomes. A decimal stays a decimal: the type is part of
/// the structure.
const double syntheticDecimal = 1.5;

/// The value a recorded **boolean** becomes. A boolean carries no person and no identifier; it is
/// replaced anyway, because the rule is that every value is.
const bool syntheticBoolean = true;

/// Re-records one recorded response body as a fixture: keys and types kept, every value synthetic.
///
/// [body] is the response body as the API returned it, as text. The result is the fixture's text:
/// the same JSON, indented by two spaces as every fixture in `test/fixtures/classic/` is, with each
/// value replaced according to its type ([syntheticText], [syntheticInteger], [syntheticDecimal],
/// [syntheticBoolean], and `null` for a `null`) and every key kept.
///
/// **Arrays keep one example of each distinct structure** and not their length: how many records a
/// listing happened to hold is a fact about the live database, not about the shape of the answer.
/// Two elements with the same structure collapse to one; two with different structures both
/// survive, so a body's shape is never flattened by accident.
///
/// Throws a [FormatException] when [body] is not JSON, or when its top level is neither an object
/// nor a list — neither is a recorded response, and a fixture that cannot be read back as one is
/// worse than no fixture.
String structureOnlyFixture(String body) {
  final Object? decoded = jsonDecode(body);
  if (decoded is! Map<Object?, Object?> && decoded is! List<Object?>) {
    throw FormatException(
      'a recorded response is a JSON object or a JSON list, and this body is '
      '${_kindOf(decoded)}',
      body,
    );
  }
  return const JsonEncoder.withIndent('  ').convert(_replace(decoded));
}

/// The structure-preserving replacement of one decoded JSON value.
Object? _replace(Object? value) => switch (value) {
  final Map<Object?, Object?> object => <String, Object?>{
    for (final MapEntry<Object?, Object?> entry in object.entries)
      '${entry.key}': _replace(entry.value),
  },
  final List<Object?> list => _oneOfEachStructure(list),
  String() => syntheticText,
  bool() => syntheticBoolean,
  double() => syntheticDecimal,
  int() => syntheticInteger,
  null => null,
  _ => throw FormatException(
    'a recorded response holds only JSON values, and this one holds '
    '${value.runtimeType}',
  ),
};

/// The elements of [list] that are the first of their structure, in the order they appear.
List<Object?> _oneOfEachStructure(List<Object?> list) {
  final Set<String> seen = <String>{};
  return <Object?>[
    for (final Object? element in list)
      if (seen.add(_structureOf(element))) _replace(element),
  ];
}

/// A canonical description of one decoded JSON value's structure: its keys and its types, with an
/// array described by the distinct structures it holds. Two values with the same description have
/// the same shape, which is what makes an element's length droppable and its shape not.
String _structureOf(Object? value) => switch (value) {
  final Map<Object?, Object?> object =>
    '{${<String>[for (final MapEntry<Object?, Object?> entry in object.entries) '${entry.key}:${_structureOf(entry.value)}'].join(',')}}',
  final List<Object?> list =>
    '[${<String>{for (final Object? element in list) _structureOf(element)}.join('|')}]',
  _ => _kindOf(value),
};

/// The JSON type of [value], as one word.
String _kindOf(Object? value) => switch (value) {
  Map<Object?, Object?>() => 'an object',
  List<Object?>() => 'a list',
  String() => 'a string',
  bool() => 'a boolean',
  double() => 'a decimal number',
  int() => 'an integer',
  null => 'null',
  _ => 'a ${value.runtimeType}',
};
