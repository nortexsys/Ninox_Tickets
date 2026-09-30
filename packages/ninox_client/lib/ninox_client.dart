/// The Ninox port of ADR-003 and its classic REST adapter.
///
/// The team and the database are always explicit arguments. This package never reads an
/// environment variable to choose a target (`AGENTS.md` §1.4).
library;

export 'src/credentials.dart';
export 'src/endpoint.dart';
export 'src/errors.dart';
export 'src/model.dart';
export 'src/port.dart';

/// The package's name, so the workspace can prove it resolves before any real API exists.
const String packageName = 'ninox_client';
