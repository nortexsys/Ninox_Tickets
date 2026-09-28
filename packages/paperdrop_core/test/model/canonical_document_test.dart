import 'dart:convert';

import 'package:paperdrop_core/paperdrop_core.dart';
import 'package:test/test.dart';

void main() {
  final eur = CurrencyCode.parse('EUR')!;
  final usd = CurrencyCode.parse('USD')!;

  CanonicalDocument fullyPopulatedDocument() {
    return CanonicalDocument(
      docDate: Present<CalendarDate>(
        CalendarDate(2026, 9, 28),
        Provenance.read,
        ConfidenceState.green,
      ),
      supplierName: Present<String>(
        'ACME S.L.',
        Provenance.fromXml,
        ConfidenceState.green,
        source: ValueSource.memory,
      ),
      supplierTaxId: Present<String>(
        'B12345678',
        Provenance.repaired,
        ConfidenceState.amber,
      ),
      docNumber: Edited<String>('INV-2026-001'),
      grossTotal: Present<Money>(
        Money(1999, eur),
        Provenance.read,
        ConfidenceState.green,
      ),
      currency: Present<CurrencyCode>(
        eur,
        Provenance.read,
        ConfidenceState.green,
      ),
      docType: Present<String>(
        'invoice',
        Provenance.fromXml,
        ConfidenceState.green,
      ),
      docTime: Present<DocTime>(
        DocTime(14, 30),
        Provenance.read,
        ConfidenceState.amber,
      ),
      docSeries: Present<String>('A', Provenance.read, ConfidenceState.amber),
      controlCode: Present<String>(
        'CTRL-001',
        Provenance.read,
        ConfidenceState.amber,
      ),
      supplierAddress: Present<String>(
        '1 Main Street',
        Provenance.read,
        ConfidenceState.amber,
      ),
      supplierCity: Present<String>(
        'Madrid',
        Provenance.read,
        ConfidenceState.amber,
      ),
      supplierCountry: Present<String>(
        'ES',
        Provenance.read,
        ConfidenceState.green,
      ),
      netTotal: Present<Money>(
        Money(1652, eur),
        Provenance.derived,
        ConfidenceState.amber,
      ),
      taxTotal: Present<Money>(
        Money(347, eur),
        Provenance.derived,
        ConfidenceState.amber,
      ),
      discountTotal: Present<Money>(
        Money(0, eur),
        Provenance.read,
        ConfidenceState.amber,
      ),
      taxSlots: <TaxSlot>[
        TaxSlot(
          rate: Present<RateBp>(
            RateBp(2100),
            Provenance.read,
            ConfidenceState.green,
          ),
          base: Present<Money>(
            Money(1652, eur),
            Provenance.read,
            ConfidenceState.green,
          ),
          amount: Present<Money>(
            Money(347, eur),
            Provenance.derived,
            ConfidenceState.amber,
          ),
        ),
      ],
      exchangeRate: Present<String>(
        '1.00',
        Provenance.read,
        ConfidenceState.amber,
      ),
      paymentMethod: Present<PaymentMethod>(
        PaymentMethod.card,
        Provenance.read,
        ConfidenceState.green,
      ),
      cardBrand: Present<String>(
        'Visa',
        Provenance.read,
        ConfidenceState.amber,
      ),
      cardMasked: Present<String>(
        '**** 4242',
        Provenance.read,
        ConfidenceState.amber,
      ),
      authCode: Present<String>(
        'AUTH01',
        Provenance.read,
        ConfidenceState.amber,
      ),
      iban: Present<String>(
        'GB00 TEST 0000 0000 0000 12',
        Provenance.read,
        ConfidenceState.amber,
      ),
      surcharges: <Surcharge>[
        Surcharge(
          label: SurchargeLabel.tip,
          amount: Present<Money>(
            Money(100, eur),
            Provenance.read,
            ConfidenceState.amber,
          ),
        ),
      ],
      licenceNumber: Present<String>(
        'B-1234-X',
        Provenance.read,
        ConfidenceState.amber,
      ),
      vehiclePlate: Present<String>(
        '1234 ABC',
        Provenance.read,
        ConfidenceState.amber,
      ),
      tripFrom: Present<String>(
        'Madrid',
        Provenance.read,
        ConfidenceState.amber,
      ),
      tripTo: Present<String>('Toledo', Provenance.read, ConfidenceState.amber),
      distanceKm: Present<int>(72, Provenance.read, ConfidenceState.amber),
      durationMin: Present<int>(55, Provenance.read, ConfidenceState.amber),
      needsReview: true,
      recognitionEngine: 'invoice/from_xml',
      sourceHash: 'abc123',
    );
  }

  group('CanonicalDocument', () {
    test(
      '[extraction-pipeline/provenance-on-every-value] every value is tagged',
      () {
        final document = fullyPopulatedDocument();

        final values = <FieldValue<Object?>>[
          document.docDate,
          document.supplierName,
          document.supplierTaxId,
          document.docNumber,
          document.grossTotal,
          document.currency,
          document.docType,
          document.docTime,
          document.docSeries,
          document.controlCode,
          document.supplierAddress,
          document.supplierCity,
          document.supplierCountry,
          document.netTotal,
          document.taxTotal,
          document.discountTotal,
          for (final slot in document.taxSlots) ...<FieldValue<Object?>>[
            slot.rate,
            slot.base,
            slot.amount,
          ],
          document.exchangeRate,
          document.paymentMethod,
          document.cardBrand,
          document.cardMasked,
          document.authCode,
          document.iban,
          for (final surcharge in document.surcharges) surcharge.amount,
          document.licenceNumber,
          document.vehiclePlate,
          document.tripFrom,
          document.tripTo,
          document.distanceKm,
          document.durationMin,
        ];

        for (final value in values) {
          if (value is Present<Object?>) {
            expect(Provenance.values, contains(value.provenance));
          }
        }
      },
    );

    test('the GAP-027 fields are not part of the model', () {
      final document = fullyPopulatedDocument();

      // The model exposes no docSubtype, grossTotalDocumentCurrency or
      // grossTotalCardCurrency member, so the only assertion possible here is
      // that the JSON surface does not carry those three keys either.
      final json = document.toJson();

      expect(json.containsKey('docSubtype'), isFalse);
      expect(json.containsKey('grossTotalDocumentCurrency'), isFalse);
      expect(json.containsKey('grossTotalCardCurrency'), isFalse);
    });

    test('cardMasked refuses five or more digits', () {
      CanonicalDocument build(FieldValue<String> cardMasked) {
        return CanonicalDocument(
          cardMasked: cardMasked,
          needsReview: false,
          recognitionEngine: 'test',
          sourceHash: 'h',
        );
      }

      expect(
        () => build(
          Present<String>('12345', Provenance.read, ConfidenceState.amber),
        ),
        throwsArgumentError,
      );
      expect(
        () => build(
          Present<String>('**** 1234', Provenance.read, ConfidenceState.amber),
        ),
        returnsNormally,
      );
    });

    test(
      'a document with currency EUR and a USD amount cannot be constructed',
      () {
        expect(
          () => CanonicalDocument(
            currency: Present<CurrencyCode>(
              eur,
              Provenance.read,
              ConfidenceState.green,
            ),
            grossTotal: Present<Money>(
              Money(100, usd),
              Provenance.read,
              ConfidenceState.green,
            ),
            needsReview: false,
            recognitionEngine: 'test',
            sourceHash: 'h',
          ),
          throwsA(isA<CurrencyMismatchError>()),
        );
      },
    );

    test('JSON round-trip of a fully populated document is lossless', () {
      final document = fullyPopulatedDocument();
      final json = document.toJson();

      _assertEveryMoneyIsAnInteger(json);

      final encoded = jsonEncode(json);
      final decodedJson = jsonDecode(encoded) as Map<String, Object?>;
      final decoded = CanonicalDocument.fromJson(decodedJson);

      expect(decoded, document);
    });
  });
}

void _assertEveryMoneyIsAnInteger(Object? node) {
  if (node is Map<String, Object?>) {
    if (node.containsKey('minor') && node.containsKey('currency')) {
      expect(node['minor'], isA<int>());
      expect(node['minor'], isNot(isA<double>()));
    }
    for (final value in node.values) {
      _assertEveryMoneyIsAnInteger(value);
    }
  } else if (node is List<Object?>) {
    for (final value in node) {
      _assertEveryMoneyIsAnInteger(value);
    }
  }
}
