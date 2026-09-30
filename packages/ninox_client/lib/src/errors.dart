/// Every failure a [NinoxPort] method can throw, and nothing else.
///
/// A port method never lets an `http.ClientException`, a `FormatException` or a
/// `TimeoutException` escape: each of those is one of the conditions of the retry matrix
/// (`ninox-send/the-retry-matrix`), and the matrix is only classifiable if the conditions are
/// distinct types. The adapter does not interpret a failure — on an HTTP 500 it does **not**
/// retry, refresh a schema or call it a mapping error; that is the send pipeline's (T1.11), which
/// consumes this classification.
///
/// No failure carries the token: the credential travels in one request header and is redacted
/// out of every message this package builds (design §1).
library;

/// The base of every failure this package raises.
///
/// Sealed, so a consumer's `switch` over a failure is checked for exhaustiveness.
sealed class NinoxFailure implements Exception {
  /// Builds a failure, optionally with a detail drawn from the response body.
  const NinoxFailure([this.message]);

  /// A short description of what Ninox said — the body's `message`, or the transport's own
  /// text. Never a field value, never the token, and `null` when there was nothing to quote.
  final String? message;

  /// The failure without the token, whatever the message says.
  @override
  String toString() =>
      message == null ? '$runtimeType' : '$runtimeType($message)';
}

/// HTTP 401 or 403: the token is absent, expired, revoked, or lacks access.
///
/// The matrix's answer is to ask the human for a new token and not retry.
final class Unauthorized extends NinoxFailure {
  /// Builds the failure, optionally quoting the body's message.
  const Unauthorized([super.message]);
}

/// HTTP 404: the team, database, table or record does not exist, or the endpoint does.
///
/// The matrix's answer is to send the human to the destination and not retry.
final class NotFound extends NinoxFailure {
  /// Builds the failure, optionally quoting the body's message.
  const NotFound([super.message]);
}

/// HTTP 429: the client is being rate-limited.
///
/// The matrix does not name it; it is modelled so that a status the API is seen to return is
/// never silently reported as an unparsed response (design §4).
final class RateLimited extends NinoxFailure {
  /// Builds the failure, optionally quoting the body's message.
  const RateLimited([super.message]);
}

/// An HTTP 5xx.
///
/// **This is usually the mapping, not an outage**: Ninox reports an invalid, formula or
/// read-only field name as HTTP 500, not as a 4xx with an explanation (ADR-004, verified). The
/// adapter therefore carries the status and nothing else — the matrix's *refresh the schema, retry
/// exactly once, then report a mapping error* is the send pipeline's (T1.11).
final class ServerError extends NinoxFailure {
  /// Builds the failure with the status that produced it.
  const ServerError(this.status, [super.message]);

  /// The HTTP status, 500 or above.
  final int status;

  @override
  String toString() =>
      'ServerError($status${message == null ? '' : ': $message'})';
}

/// A response that is neither a success nor one of the conditions above.
///
/// Two cases: any status outside 2xx that is not 401/403/404/429/5xx, and a 2xx whose body does
/// not carry the documented shape (it is not JSON, or not the object, list or key that endpoint
/// returns). Both mean the adapter cannot say what happened, which is worth surfacing rather than
/// guessing.
final class UnexpectedResponse extends NinoxFailure {
  /// Builds the failure, naming what was expected.
  const UnexpectedResponse([super.message]);
}

/// No response arrived: DNS, a refused connection, TLS, a timeout.
///
/// A failure *before* the request left the device is exactly this and nothing more, and it is
/// safe to retry. A timeout on a **create** may have landed, which is
/// [CreateOutcomeUncertain] instead — see there.
class TransportFailure extends NinoxFailure {
  /// Builds the failure with the transport's own description, redacted.
  const TransportFailure([super.message]);
}

/// A create whose outcome is unknown: the request may have created the record.
///
/// ADR-013 and `ninox-send/reconciliation-of-an-uncertain-create`: a `POST` whose response was
/// lost to a timeout may have landed, and retrying it writes a duplicate into someone's
/// accounting. The matrix's answer is never a retry — it is a read-side reconciliation.
///
/// It is a [TransportFailure], so code that only wants to know "the network failed" keeps
/// working; code that must not blind-retry a create matches this type.
///
/// Where `package:http` cannot tell a lost response apart from a refused connection, the adapter
/// says **uncertain**, the safe side: erring this way costs one reconciliation read, erring the
/// other way costs a duplicate record (design §8).
final class CreateOutcomeUncertain extends TransportFailure {
  /// Builds the failure with the transport's own description, redacted.
  const CreateOutcomeUncertain([super.message]);
}
