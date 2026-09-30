import 'package:ninox_client/ninox_client.dart';
import 'package:test/test.dart';

void main() {
  group('NinoxEndpoint', () {
    test('a bare host becomes an https base URI under /v1', () {
      final endpoint = NinoxEndpoint.parse('ninox.example.de');

      expect(endpoint, isNotNull);
      expect(endpoint!.host, 'ninox.example.de');
      expect(endpoint.port, isNull);
      expect(endpoint.baseUri, Uri.parse('https://ninox.example.de/v1'));
    });

    test(
      'the cloud default is the vendor host, and it is the only literal of it',
      () {
        // ADR-017, FR-DST-008: the host is configuration, never a compiled constant. `cloud`
        // carries the vendor's name so that no other file of lib/ has to.
        expect(NinoxEndpoint.cloud.host, 'api.ninox.com');
        expect(
          NinoxEndpoint.cloud.baseUri,
          Uri.parse('https://api.ninox.com/v1'),
        );
      },
    );

    test('a host with a port keeps it', () {
      final endpoint = NinoxEndpoint.parse('ninox.example.de:8443');

      expect(endpoint!.host, 'ninox.example.de');
      expect(endpoint.port, 8443);
      expect(endpoint.baseUri, Uri.parse('https://ninox.example.de:8443/v1'));
    });

    test('an https URL with no path or with a bare / is accepted', () {
      expect(
        NinoxEndpoint.parse('https://ninox.example.de')!.baseUri,
        Uri.parse('https://ninox.example.de/v1'),
      );
      expect(
        NinoxEndpoint.parse('https://ninox.example.de/')!.baseUri,
        Uri.parse('https://ninox.example.de/v1'),
      );
      expect(
        NinoxEndpoint.parse('https://NINOX.example.de:8443/')!.baseUri,
        Uri.parse('https://ninox.example.de:8443/v1'),
      );
    });

    test('the host is normalised to lower case', () {
      expect(
        NinoxEndpoint.parse('NINOX.Example.DE'),
        NinoxEndpoint.parse('ninox.example.de'),
      );
      expect(NinoxEndpoint.parse('ninox.example.de')!.host, 'ninox.example.de');
    });

    test(
      'two endpoints with the same host and port are equal and hash alike',
      () {
        final one = NinoxEndpoint.parse('ninox.example.de:8443');
        final other = NinoxEndpoint.parse('https://NINOX.example.de:8443/');

        expect(one, other);
        expect(one.hashCode, other.hashCode);
        expect(one, isNot(NinoxEndpoint.cloud));
      },
    );

    test('the printed form is the base URI and carries no credential', () {
      expect(
        NinoxEndpoint.cloud.toString(),
        'NinoxEndpoint(https://api.ninox.com/v1)',
      );
    });

    group('rejected forms', () {
      const rejected = <String, String>{
        'empty string': '',
        'leading whitespace': ' ninox.example.de',
        'trailing whitespace': 'ninox.example.de ',
        'interior whitespace': 'ninox example.de',
        'http url, which would put the token in clear':
            'http://ninox.example.de',
        'http url with uppercase scheme': 'HTTP://ninox.example.de',
        'another scheme': 'ftp://ninox.example.de',
        'a path beyond /': 'https://ninox.example.de/v1',
        'a path beyond / on a bare host': 'ninox.example.de/records',
        'a doubled slash': 'https://ninox.example.de//',
        'a query': 'ninox.example.de?team=1',
        'a query after an https url': 'https://ninox.example.de/?perPage=2',
        'a fragment': 'ninox.example.de#records',
        'user info': 'https://user@ninox.example.de',
        'an empty port': 'ninox.example.de:',
        'a non-numeric port': 'ninox.example.de:https',
        'a port above 65535': 'ninox.example.de:65536',
        'a port of zero': 'ninox.example.de:0',
        'a scheme with nothing after it': 'https://',
        'only a scheme separator': '://',
        'a host that is not a host': 'ninox_example.de',
        'a trailing dot': 'ninox.example.de.',
        'a percent-encoded host': 'ninox%2Eexample.de',
      };

      rejected.forEach((reason, input) {
        test('$reason: ${input.isEmpty ? '(empty)' : input}', () {
          expect(NinoxEndpoint.parse(input), isNull);
        });
      });
    });
  });

  group('NinoxCredentials', () {
    const token = 'synthetic-token';

    test('the header is Bearer and the token, and nothing else', () {
      const credentials = NinoxCredentials(token);

      expect(credentials.authorizationHeader, 'Bearer $token');
      expect(credentials.token, token);
    });

    test('toString never contains the token', () {
      const credentials = NinoxCredentials(token);

      expect(credentials.toString(), 'NinoxCredentials(***)');
      expect(credentials.toString(), isNot(contains(token)));
    });

    test('two credentials with the same token are equal and hash alike', () {
      expect(const NinoxCredentials(token), const NinoxCredentials(token));
      expect(
        const NinoxCredentials(token).hashCode,
        const NinoxCredentials(token).hashCode,
      );
      expect(
        const NinoxCredentials(token),
        isNot(const NinoxCredentials('another-token')),
      );
    });
  });
}
