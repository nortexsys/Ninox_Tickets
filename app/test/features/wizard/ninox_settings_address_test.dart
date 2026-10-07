import 'package:flutter_test/flutter_test.dart';
import 'package:ninox_client/ninox_client.dart';
import 'package:paperdrop/features/wizard/token/system_browser.dart';
import 'package:paperdrop/features/wizard/token/token_screen.dart';

/// The address of Ninox's own settings page (design §4, task 3.10).
///
/// The vendor's documentation settles it (forum.ninox.com, *Introduction to Ninox API*): the public
/// cloud hands out API keys at `https://admin.ninox.com` — Integrations, then New API Key — and a
/// private cloud at `https://<domain>/admin`. This file pins both forms, and the two properties that
/// matter whatever the host is: the scheme is always `https`, and the host is the user's own.
///
/// No widget, no network, no token: this is arithmetic over a host.
void main() {
  test('the public cloud is sent to the vendor\'s admin host', () {
    expect(
      ninoxApiTokenSettingsUri(NinoxEndpoint.cloud),
      Uri.parse('https://admin.ninox.com'),
    );
  });

  test('a private cloud is sent to its own host, at /admin', () {
    expect(
      ninoxApiTokenSettingsUri(NinoxEndpoint.parse('ninox.example.de')!),
      Uri.parse('https://ninox.example.de/admin'),
    );
  });

  test('a private cloud on a port keeps the port', () {
    // The host the user configured is the host whose admin page they are sent to, port and all: a
    // reverse proxy that serves the API on 8443 serves its web UI there too.
    expect(
      ninoxApiTokenSettingsUri(NinoxEndpoint.parse('ninox.example.de:8443')!),
      Uri.parse('https://ninox.example.de:8443/admin'),
    );
  });

  test('the address is https whatever the host is, and never the API host of a '
      'private cloud', () {
    // A token travels in this page's session: plain text would put it on the wire in clear, which is
    // the same reason `NinoxEndpoint.parse` refuses an `http://` host.
    for (final String host in <String>[
      'ninox.example.de',
      'ninox.example.de:8443',
      'ninox.other.example',
    ]) {
      final Uri address = ninoxApiTokenSettingsUri(NinoxEndpoint.parse(host)!);
      expect(address.scheme, 'https', reason: host);
      expect(address.host, host.split(':').first, reason: host);
    }
    // The vendor's cloud API host is not where keys are made: the admin host is.
    expect(
      ninoxApiTokenSettingsUri(NinoxEndpoint.cloud).host,
      'admin.ninox.com',
    );
  });

  test('the host field reads and writes an endpoint with its port', () {
    // The field is what the user corrects and what the address above is built from, so an endpoint
    // configured on a port must come back through it unchanged.
    expect(
      TokenScreen.hostText(NinoxEndpoint.parse('ninox.example.de:8443')!),
      'ninox.example.de:8443',
    );
    expect(TokenScreen.hostText(NinoxEndpoint.cloud), 'api.ninox.com');
    expect(
      NinoxEndpoint.parse(
        TokenScreen.hostText(NinoxEndpoint.parse('ninox.example.de:8443')!),
      ),
      NinoxEndpoint.parse('ninox.example.de:8443'),
    );
  });
}
