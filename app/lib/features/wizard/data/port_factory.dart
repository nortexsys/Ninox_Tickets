/// How the wizard gets a `NinoxPort` (design §3).
///
/// Requirement served: ADR-003's port, through `setup-wizard`'s design §3: *the wizard reaches Ninox
/// through `NinoxPort` only. It builds no URL, sends no request of its own and parses no Ninox
/// JSON.* The port is built once, after the token step's call succeeded, and it holds the endpoint
/// and the credential for as long as the wizard needs a call.
///
/// **The controller is the only caller of a factory.** A screen never builds a port: it hands the
/// controller a token, and the controller decides what to build. That is what lets every widget test
/// hand in a factory that returns a fake and make no network call at all (design §1).
library;

import 'package:http/http.dart' as http;
import 'package:ninox_client/ninox_client.dart';

/// Builds the port the wizard will use, from the endpoint the token step parsed and the token it
/// accepted.
typedef NinoxPortFactory = NinoxPort Function(
  NinoxEndpoint endpoint,
  NinoxCredentials credentials,
);

/// The composition the device uses: the classic adapter over a real `http.Client`.
///
/// **This is the only place `package:http` appears in the application**, and the only place a
/// `ClassicNinoxAdapter` is built (design §3). Every screen takes a controller, a controller takes a
/// [NinoxPortFactory], and every test passes a factory that returns a fake — so no test can reach
/// Ninox by accident, and a second API generation (ADR-003) is one function away.
///
/// The client is created here, per port, exactly as design §3 states it: one wizard run, one port,
/// one client. The adapter is left to own it for the run's lifetime rather than closed under it,
/// because the client is also the connection pool the run's calls share.
NinoxPort classicNinoxPort(
  NinoxEndpoint endpoint,
  NinoxCredentials credentials,
) => ClassicNinoxAdapter(
  endpoint: endpoint,
  credentials: credentials,
  client: http.Client(),
);
