/// The Ninox port of ADR-003 and its classic REST adapter.
///
/// One import gives the application everything it needs to talk to Ninox and nothing it may not:
///
/// * [NinoxEndpoint] — the host, which is configuration and never a compiled constant
///   (ADR-017, `destinations-mapping/configurable-ninox-host`), and [NinoxEndpoint.cloud] as the
///   default;
/// * [NinoxCredentials] — the personal access token, the only credential (BR-19), which never
///   leaves the `Authorization` header;
/// * [NinoxPort] — the interface a second implementation can sit behind (ADR-003), and [TableRef],
///   the team, database and table every call states explicitly;
/// * [NinoxTeam], [NinoxDatabase], [NinoxTable], [NinoxField], [NinoxRecord], [NinoxFile] and
///   [RecordId] — what the endpoints return;
/// * [NinoxFailure] and its subtypes, including [CreateOutcomeUncertain], which is how a create
///   whose response was lost is told apart from one that never left (ADR-013);
/// * [ClassicNinoxAdapter] — the classic REST implementation over `package:http`.
///
/// **What this library never does.** It reads no environment variable: the team, the database and
/// the table are arguments of every call, and the production-database variable of `AGENTS.md` §1.4
/// is never named here (GAP-012). It holds one credential and transmits no second one. It retries
/// nothing: classifying a failure and reconciling an uncertain create are the send pipeline's
/// (T1.11).
///
/// **What it does not do yet.** The update primitive of `ninox-send/updates-are-merges`
/// (FR-SND-008) is absent from [NinoxPort]: the `ninox` skill documents no verb, path or body for
/// an update, so the lane reported it as blocked instead of guessing one (change design §3).
library;

export 'src/classic_adapter.dart';
export 'src/credentials.dart';
export 'src/endpoint.dart';
export 'src/errors.dart';

// Only the value types, not the JSON-reading helpers that live beside them: a response shape is
// the adapter's business, and a second implementation of the port (ADR-003) is free to read its
// own generation's shapes rather than inherit this one's.
export 'src/model.dart'
    show
        RecordId,
        NinoxTeam,
        NinoxDatabase,
        NinoxTable,
        NinoxField,
        NinoxRecord,
        NinoxFile;

export 'src/port.dart';

/// The package's name, so the workspace can prove it resolves before any real API exists.
const String packageName = 'ninox_client';
