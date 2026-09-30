/// The Ninox host a client talks to, and the base URI every request is built on.
///
/// The host is **configuration**, never a compiled constant (ADR-017,
/// `destinations-mapping/configurable-ninox-host`): a customer running Ninox on their own host
/// enters it and needs no fork, so no other file of this package may build a Ninox URL from a
/// host literal. [cloud] is the default, and it is the only place in this package where the
/// vendor's host name appears.
///
/// Immutable and compared by value.
final class NinoxEndpoint {
  const NinoxEndpoint._(this._host, this._port);

  /// The vendor's public cloud host, used when the user has not configured another one.
  ///
  /// ADR-017: this is a default, not a compilation target — a private-cloud customer overrides
  /// it per destination, in the wizard's advanced setup (`FR-DST-008`).
  static const NinoxEndpoint cloud = NinoxEndpoint._('api.ninox.com', null);

  /// A bare host label, optionally dotted and optionally followed by a port.
  static final RegExp _hostAndPort = RegExp(
    r'^([a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)*)'
    r'(?::(\d{1,5}))?$',
    caseSensitive: false,
  );

  static final RegExp _whitespace = RegExp(r'\s');

  final String _host;
  final int? _port;

  /// The configured host, normalised to lower case. Never read from the environment.
  String get host => _host;

  /// The configured port, or `null` when the host uses the scheme's default one.
  int? get port => _port;

  /// `https://<host>[:<port>]/v1` — the prefix every classic call is built on (ADR-003).
  Uri get baseUri =>
      Uri(scheme: 'https', host: _host, port: _port, path: '/v1');

  /// Reads a host as the user typed it, or returns `null` when it is not an accepted form.
  ///
  /// Accepted: a bare host (`ninox.example.de`), a host with a port (`ninox.example.de:8443`),
  /// and an `https://` URL whose path is empty or `/`. The result is normalised to lower case,
  /// so `NINOX.Example.DE` and `https://ninox.example.de/` are the same endpoint.
  ///
  /// Rejected, all returning `null` rather than a partly-built endpoint:
  ///
  /// * an empty string, and any input with leading, trailing or interior whitespace;
  /// * an `http://` URL, or any other scheme — a plain-text scheme would put the bearer token
  ///   and the user's documents on the wire in clear;
  /// * user info (`https://user@host`), a query, a fragment, and any path beyond `/`;
  /// * a host or port that is not a host or port (`host:`, `host:abc`, a port above 65535).
  ///
  /// This is a **syntactic** check. Whether the host resolves and answers is settled by the
  /// token step, by its effect (`configurable-ninox-host`, scenario *an unreachable host is
  /// reported early*) — that half is the wizard's (T1.10).
  static NinoxEndpoint? parse(String input) {
    if (input.isEmpty || input.trim() != input || _whitespace.hasMatch(input)) {
      return null;
    }
    final String body;
    if (input.length >= 8 &&
        input.substring(0, 8).toLowerCase() == 'https://') {
      body = input.substring(8);
    } else if (input.contains('://')) {
      // `http://` above all: the token would travel in clear. Every other scheme is simply not
      // an accepted form.
      return null;
    } else {
      body = input;
    }
    if (body.contains('?') || body.contains('#') || body.contains('@')) {
      return null;
    }
    var hostAndPort = body;
    final slash = hostAndPort.indexOf('/');
    if (slash >= 0) {
      if (slash != hostAndPort.length - 1) return null; // a path beyond `/`
      hostAndPort = hostAndPort.substring(0, slash);
    }
    final match = _hostAndPort.firstMatch(hostAndPort);
    if (match == null) return null;
    final host = match.group(1)!.toLowerCase();
    final portText = match.group(2);
    int? port;
    if (portText != null) {
      port = int.tryParse(portText);
      if (port == null || port < 1 || port > 65535) return null;
    }
    return NinoxEndpoint._(host, port);
  }

  @override
  bool operator ==(Object other) =>
      other is NinoxEndpoint && other._host == _host && other._port == _port;

  @override
  int get hashCode => Object.hash(_host, _port);

  /// Prints the base URI and never a credential — an endpoint holds none.
  @override
  String toString() => 'NinoxEndpoint($baseUri)';
}
