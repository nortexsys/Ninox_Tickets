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
///
/// **Where `package:http` appears.** Exactly once, in the composition this file holds beside the
/// typedef — `ClassicNinoxAdapter(endpoint:, credentials:, client: http.Client())`. That composition
/// lands with the dependency itself (`app/pubspec.yaml` gains `http`, `url_launcher` and
/// `flutter_secure_storage` in this change, design §7); until then the typedef below is the whole
/// file, every test and every screen uses a fake, and no widget knows either the adapter or `http`.
library;

import 'package:ninox_client/ninox_client.dart';

/// Builds the port the wizard will use, from the endpoint the token step parsed and the token it
/// accepted.
typedef NinoxPortFactory = NinoxPort Function(
  NinoxEndpoint endpoint,
  NinoxCredentials credentials,
);
