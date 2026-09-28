/// The canonical document model of Funcional §6.1.
///
/// Requirement served: FR-EXT-011 (`provenance-on-every-value`) — every field
/// carries one of the four provenance tags, or is explicitly absent or
/// `not_in_xml`. GAP-027 fields are deliberately not present.
library;

import '../money/currency.dart';
import '../money/money.dart';
import '../money/rate.dart';
import 'calendar_date.dart';
import 'doc_time.dart';
import 'field_value.dart';

/// The payment methods the model recognises.
enum PaymentMethod {
  /// Card payment.
  card('card'),

  /// Cash payment.
  cash('cash'),

  /// Bank transfer.
  transfer('transfer'),

  /// Direct debit.
  directDebit('direct_debit'),

  /// A payment method outside the fixed list.
  other('other');

  /// Creates a payment method with its [wireName].
  const PaymentMethod(this.wireName);

  /// The wire name used for serialisation.
  final String wireName;

  /// Serialises this method by its wire name.
  String toJson() => wireName;

  /// Reads a method from its wire name.
  static PaymentMethod fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('payment method JSON must be a string');
    }

    for (final value in values) {
      if (value.wireName == json) {
        return value;
      }
    }

    throw FormatException('unknown payment method: $json');
  }
}

/// The labels a surcharge entry may carry.
enum SurchargeLabel {
  /// A dynamic currency conversion mark-up.
  dccMarkup('dcc_markup'),

  /// A service charge.
  serviceCharge('service_charge'),

  /// A tip.
  tip('tip'),

  /// A rounding adjustment.
  roundingAdjustment('rounding_adjustment'),

  /// Any surcharge label outside the fixed list.
  other('other');

  /// Creates a surcharge label with its [wireName].
  const SurchargeLabel(this.wireName);

  /// The wire name used for serialisation.
  final String wireName;

  /// Serialises this label by its wire name.
  String toJson() => wireName;

  /// Reads a label from its wire name.
  static SurchargeLabel fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('surcharge label JSON must be a string');
    }

    for (final value in values) {
      if (value.wireName == json) {
        return value;
      }
    }

    throw FormatException('unknown surcharge label: $json');
  }
}

/// One printed tax rate and its base and amount, all as field values.
class TaxSlot {
  /// The printed tax rate.
  final FieldValue<RateBp> rate;

  /// The printed tax base.
  final FieldValue<Money> base;

  /// The printed or derived tax amount.
  final FieldValue<Money> amount;

  /// Creates a tax slot from [rate], [base] and [amount].
  const TaxSlot({required this.rate, required this.base, required this.amount});

  /// Serialises this slot using the shared JSON shape.
  Map<String, Object?> toJson() => <String, Object?>{
    'rate': rate.toJson(rateBpCodec),
    'base': base.toJson(moneyCodec),
    'amount': amount.toJson(moneyCodec),
  };

  /// Reads a tax slot from its JSON object.
  static TaxSlot fromJson(Object? json) {
    final map = _asMap(json);
    return TaxSlot(
      rate: FieldValue.fromJson<RateBp>(map['rate'], rateBpCodec),
      base: FieldValue.fromJson<Money>(map['base'], moneyCodec),
      amount: FieldValue.fromJson<Money>(map['amount'], moneyCodec),
    );
  }

  /// The slot's three field values, and nothing more.
  @override
  String toString() => 'TaxSlot(rate: $rate, base: $base, amount: $amount)';

  /// Value equality on rate, base and amount.
  @override
  bool operator ==(Object other) =>
      other is TaxSlot &&
      other.rate == rate &&
      other.base == base &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(rate, base, amount);
}

/// A surcharge-like amount that is not a tax line (FR-EXT-010, Funcional
/// §6.1.2).
class Surcharge {
  /// The surcharge label.
  final SurchargeLabel label;

  /// The surcharge amount.
  final FieldValue<Money> amount;

  /// Creates a surcharge entry from [label] and [amount].
  const Surcharge({required this.label, required this.amount});

  /// Serialises this surcharge entry using the shared JSON shape.
  Map<String, Object?> toJson() => <String, Object?>{
    'label': label.toJson(),
    'amount': amount.toJson(moneyCodec),
  };

  /// Reads a surcharge entry from its JSON object.
  static Surcharge fromJson(Object? json) {
    final map = _asMap(json);
    return Surcharge(
      label: SurchargeLabel.fromJson(map['label']),
      amount: FieldValue.fromJson<Money>(map['amount'], moneyCodec),
    );
  }

  /// The label and amount, and nothing more.
  @override
  String toString() => 'Surcharge(label: ${label.wireName}, amount: $amount)';

  /// Value equality on label and amount.
  @override
  bool operator ==(Object other) =>
      other is Surcharge && other.label == label && other.amount == amount;

  @override
  int get hashCode => Object.hash(label, amount);
}

/// The immutable canonical model of one extracted document.
class CanonicalDocument {
  /// The document date, as `YYYY-MM-DD` without a time zone.
  final FieldValue<CalendarDate> docDate;

  /// The supplier name.
  final FieldValue<String> supplierName;

  /// The supplier tax identifier, normalised text.
  final FieldValue<String> supplierTaxId;

  /// The document number.
  final FieldValue<String> docNumber;

  /// The gross total in minor units.
  final FieldValue<Money> grossTotal;

  /// The document currency.
  final FieldValue<CurrencyCode> currency;

  /// The document class.
  final FieldValue<String> docType;

  /// The document time, as `HH:MM`.
  final FieldValue<DocTime> docTime;

  /// The invoice series prefix.
  final FieldValue<String> docSeries;

  /// The fiscal control code, where printed.
  final FieldValue<String> controlCode;

  /// The supplier address.
  final FieldValue<String> supplierAddress;

  /// The supplier city.
  final FieldValue<String> supplierCity;

  /// The supplier country, as an ISO 3166-1 alpha-2 code.
  final FieldValue<String> supplierCountry;

  /// The net total in minor units.
  final FieldValue<Money> netTotal;

  /// The tax total in minor units.
  final FieldValue<Money> taxTotal;

  /// The discount total in minor units.
  final FieldValue<Money> discountTotal;

  /// One slot per printed tax rate.
  final List<TaxSlot> taxSlots;

  /// The exchange rate, kept as the printed text.
  final FieldValue<String> exchangeRate;

  /// The payment method.
  final FieldValue<PaymentMethod> paymentMethod;

  /// The card brand.
  final FieldValue<String> cardBrand;

  /// The masked card number; at most four digits, optionally preceded by mask
  /// characters.
  final FieldValue<String> cardMasked;

  /// The authorisation code.
  final FieldValue<String> authCode;

  /// The normalised IBAN text.
  final FieldValue<String> iban;

  /// Surcharge-like amounts that are not tax lines.
  final List<Surcharge> surcharges;

  /// A travel or transport licence number.
  final FieldValue<String> licenceNumber;

  /// A vehicle plate.
  final FieldValue<String> vehiclePlate;

  /// The trip origin.
  final FieldValue<String> tripFrom;

  /// The trip destination.
  final FieldValue<String> tripTo;

  /// The trip distance in kilometres.
  final FieldValue<int> distanceKm;

  /// The trip duration in minutes.
  final FieldValue<int> durationMin;

  /// Whether the review screen must show this document before it is sent.
  final bool needsReview;

  /// The recognition engine and route that produced the values.
  final String recognitionEngine;

  /// The document hash, which feeds duplicate detection.
  final String sourceHash;

  /// Creates an immutable document. Optional fields default to [Absent].
  ///
  /// When [currency] is present, every present amount must be in that currency;
  /// the constructor throws [CurrencyMismatchError] otherwise.
  CanonicalDocument({
    this.docDate = const Absent<CalendarDate>(),
    this.supplierName = const Absent<String>(),
    this.supplierTaxId = const Absent<String>(),
    this.docNumber = const Absent<String>(),
    this.grossTotal = const Absent<Money>(),
    this.currency = const Absent<CurrencyCode>(),
    this.docType = const Absent<String>(),
    this.docTime = const Absent<DocTime>(),
    this.docSeries = const Absent<String>(),
    this.controlCode = const Absent<String>(),
    this.supplierAddress = const Absent<String>(),
    this.supplierCity = const Absent<String>(),
    this.supplierCountry = const Absent<String>(),
    this.netTotal = const Absent<Money>(),
    this.taxTotal = const Absent<Money>(),
    this.discountTotal = const Absent<Money>(),
    List<TaxSlot> taxSlots = const <TaxSlot>[],
    this.exchangeRate = const Absent<String>(),
    this.paymentMethod = const Absent<PaymentMethod>(),
    this.cardBrand = const Absent<String>(),
    this.cardMasked = const Absent<String>(),
    this.authCode = const Absent<String>(),
    this.iban = const Absent<String>(),
    List<Surcharge> surcharges = const <Surcharge>[],
    this.licenceNumber = const Absent<String>(),
    this.vehiclePlate = const Absent<String>(),
    this.tripFrom = const Absent<String>(),
    this.tripTo = const Absent<String>(),
    this.distanceKm = const Absent<int>(),
    this.durationMin = const Absent<int>(),
    required this.needsReview,
    required this.recognitionEngine,
    required this.sourceHash,
  }) : taxSlots = List.unmodifiable(taxSlots),
       surcharges = List.unmodifiable(surcharges) {
    _validateCardMasked();
    _validateSupplierCountry();
    _validateCurrency();
  }

  static final RegExp _cardMaskedPattern = RegExp(r'^[^0-9]*[0-9]{0,4}$');
  static final RegExp _countryPattern = RegExp(r'^[A-Z]{2}$');

  void _validateCardMasked() {
    final value = cardMasked;
    if (value is Present<String> && !_cardMaskedPattern.hasMatch(value.value)) {
      throw ArgumentError.value(
        value.value,
        'cardMasked',
        'must hold at most four digits, optionally preceded by mask characters',
      );
    }
  }

  void _validateSupplierCountry() {
    final value = supplierCountry;
    if (value is Present<String> && !_countryPattern.hasMatch(value.value)) {
      throw ArgumentError.value(
        value.value,
        'supplierCountry',
        'must be an ISO 3166-1 alpha-2 code',
      );
    }
  }

  void _validateCurrency() {
    final currencyValue = currency;
    if (currencyValue is! Present<CurrencyCode>) {
      return;
    }

    final expected = currencyValue.value;
    void checkMoney(FieldValue<Money> field) {
      final value = field;
      if (value is Present<Money> && value.value.currency != expected) {
        throw CurrencyMismatchError(
          'amount currency ${value.value.currency.code} does not match '
          'document currency ${expected.code}',
        );
      }
    }

    checkMoney(grossTotal);
    checkMoney(netTotal);
    checkMoney(taxTotal);
    checkMoney(discountTotal);
    for (final slot in taxSlots) {
      checkMoney(slot.base);
      checkMoney(slot.amount);
    }
    for (final surcharge in surcharges) {
      checkMoney(surcharge.amount);
    }
  }

  /// Serialises this document using the shared JSON shape.
  Map<String, Object?> toJson() => <String, Object?>{
    'docDate': docDate.toJson(calendarDateCodec),
    'supplierName': supplierName.toJson(stringCodec),
    'supplierTaxId': supplierTaxId.toJson(stringCodec),
    'docNumber': docNumber.toJson(stringCodec),
    'grossTotal': grossTotal.toJson(moneyCodec),
    'currency': currency.toJson(currencyCodec),
    'docType': docType.toJson(stringCodec),
    'docTime': docTime.toJson(docTimeCodec),
    'docSeries': docSeries.toJson(stringCodec),
    'controlCode': controlCode.toJson(stringCodec),
    'supplierAddress': supplierAddress.toJson(stringCodec),
    'supplierCity': supplierCity.toJson(stringCodec),
    'supplierCountry': supplierCountry.toJson(stringCodec),
    'netTotal': netTotal.toJson(moneyCodec),
    'taxTotal': taxTotal.toJson(moneyCodec),
    'discountTotal': discountTotal.toJson(moneyCodec),
    'taxSlots': taxSlots.map((slot) => slot.toJson()).toList(),
    'exchangeRate': exchangeRate.toJson(stringCodec),
    'paymentMethod': paymentMethod.toJson(paymentMethodCodec),
    'cardBrand': cardBrand.toJson(stringCodec),
    'cardMasked': cardMasked.toJson(stringCodec),
    'authCode': authCode.toJson(stringCodec),
    'iban': iban.toJson(stringCodec),
    'surcharges': surcharges.map((surcharge) => surcharge.toJson()).toList(),
    'licenceNumber': licenceNumber.toJson(stringCodec),
    'vehiclePlate': vehiclePlate.toJson(stringCodec),
    'tripFrom': tripFrom.toJson(stringCodec),
    'tripTo': tripTo.toJson(stringCodec),
    'distanceKm': distanceKm.toJson(intCodec),
    'durationMin': durationMin.toJson(intCodec),
    'needsReview': needsReview,
    'recognitionEngine': recognitionEngine,
    'sourceHash': sourceHash,
  };

  /// Reads a document from its shared JSON shape.
  static CanonicalDocument fromJson(Map<String, Object?> json) {
    FieldValue<T> field<T>(
      String key,
      FieldCodec<T> codec,
      FieldValue<T> fallback,
    ) {
      final value = json[key];
      return value == null ? fallback : FieldValue.fromJson<T>(value, codec);
    }

    return CanonicalDocument(
      docDate: field<CalendarDate>(
        'docDate',
        calendarDateCodec,
        const Absent<CalendarDate>(),
      ),
      supplierName: field<String>(
        'supplierName',
        stringCodec,
        const Absent<String>(),
      ),
      supplierTaxId: field<String>(
        'supplierTaxId',
        stringCodec,
        const Absent<String>(),
      ),
      docNumber: field<String>(
        'docNumber',
        stringCodec,
        const Absent<String>(),
      ),
      grossTotal: field<Money>('grossTotal', moneyCodec, const Absent<Money>()),
      currency: field<CurrencyCode>(
        'currency',
        currencyCodec,
        const Absent<CurrencyCode>(),
      ),
      docType: field<String>('docType', stringCodec, const Absent<String>()),
      docTime: field<DocTime>('docTime', docTimeCodec, const Absent<DocTime>()),
      docSeries: field<String>(
        'docSeries',
        stringCodec,
        const Absent<String>(),
      ),
      controlCode: field<String>(
        'controlCode',
        stringCodec,
        const Absent<String>(),
      ),
      supplierAddress: field<String>(
        'supplierAddress',
        stringCodec,
        const Absent<String>(),
      ),
      supplierCity: field<String>(
        'supplierCity',
        stringCodec,
        const Absent<String>(),
      ),
      supplierCountry: field<String>(
        'supplierCountry',
        stringCodec,
        const Absent<String>(),
      ),
      netTotal: field<Money>('netTotal', moneyCodec, const Absent<Money>()),
      taxTotal: field<Money>('taxTotal', moneyCodec, const Absent<Money>()),
      discountTotal: field<Money>(
        'discountTotal',
        moneyCodec,
        const Absent<Money>(),
      ),
      taxSlots: _listFromJson(json['taxSlots'], TaxSlot.fromJson),
      exchangeRate: field<String>(
        'exchangeRate',
        stringCodec,
        const Absent<String>(),
      ),
      paymentMethod: field<PaymentMethod>(
        'paymentMethod',
        paymentMethodCodec,
        const Absent<PaymentMethod>(),
      ),
      cardBrand: field<String>(
        'cardBrand',
        stringCodec,
        const Absent<String>(),
      ),
      cardMasked: field<String>(
        'cardMasked',
        stringCodec,
        const Absent<String>(),
      ),
      authCode: field<String>('authCode', stringCodec, const Absent<String>()),
      iban: field<String>('iban', stringCodec, const Absent<String>()),
      surcharges: _listFromJson(json['surcharges'], Surcharge.fromJson),
      licenceNumber: field<String>(
        'licenceNumber',
        stringCodec,
        const Absent<String>(),
      ),
      vehiclePlate: field<String>(
        'vehiclePlate',
        stringCodec,
        const Absent<String>(),
      ),
      tripFrom: field<String>('tripFrom', stringCodec, const Absent<String>()),
      tripTo: field<String>('tripTo', stringCodec, const Absent<String>()),
      distanceKm: field<int>('distanceKm', intCodec, const Absent<int>()),
      durationMin: field<int>('durationMin', intCodec, const Absent<int>()),
      needsReview: json['needsReview'] as bool,
      recognitionEngine: json['recognitionEngine'] as String,
      sourceHash: json['sourceHash'] as String,
    );
  }

  static List<T> _listFromJson<T>(Object? json, T Function(Object?) decode) {
    if (json == null) {
      return List<T>.unmodifiable(<T>[]);
    }
    if (json is! List<Object?>) {
      throw FormatException('expected a JSON list');
    }
    return List<T>.unmodifiable(json.map(decode));
  }

  /// A compact rendering of the document's field values.
  @override
  String toString() =>
      'CanonicalDocument(docDate: $docDate, supplierName: $supplierName, '
      'supplierTaxId: $supplierTaxId, docNumber: $docNumber, '
      'grossTotal: $grossTotal, currency: $currency, docType: $docType, '
      'docTime: $docTime, netTotal: $netTotal, taxTotal: $taxTotal, '
      'discountTotal: $discountTotal, taxSlots: ${taxSlots.length}, '
      'exchangeRate: $exchangeRate, paymentMethod: $paymentMethod, '
      'cardBrand: $cardBrand, cardMasked: $cardMasked, iban: $iban, '
      'surcharges: ${surcharges.length}, needsReview: $needsReview, '
      'recognitionEngine: $recognitionEngine, sourceHash: $sourceHash)';

  /// Value equality on every field and list entry.
  @override
  bool operator ==(Object other) {
    if (other is! CanonicalDocument) {
      return false;
    }

    return other.docDate == docDate &&
        other.supplierName == supplierName &&
        other.supplierTaxId == supplierTaxId &&
        other.docNumber == docNumber &&
        other.grossTotal == grossTotal &&
        other.currency == currency &&
        other.docType == docType &&
        other.docTime == docTime &&
        other.docSeries == docSeries &&
        other.controlCode == controlCode &&
        other.supplierAddress == supplierAddress &&
        other.supplierCity == supplierCity &&
        other.supplierCountry == supplierCountry &&
        other.netTotal == netTotal &&
        other.taxTotal == taxTotal &&
        other.discountTotal == discountTotal &&
        _listEquals(other.taxSlots, taxSlots) &&
        other.exchangeRate == exchangeRate &&
        other.paymentMethod == paymentMethod &&
        other.cardBrand == cardBrand &&
        other.cardMasked == cardMasked &&
        other.authCode == authCode &&
        other.iban == iban &&
        _listEquals(other.surcharges, surcharges) &&
        other.licenceNumber == licenceNumber &&
        other.vehiclePlate == vehiclePlate &&
        other.tripFrom == tripFrom &&
        other.tripTo == tripTo &&
        other.distanceKm == distanceKm &&
        other.durationMin == durationMin &&
        other.needsReview == needsReview &&
        other.recognitionEngine == recognitionEngine &&
        other.sourceHash == sourceHash;
  }

  /// Hash of every field and list entry.
  @override
  int get hashCode => Object.hashAll(<Object?>[
    docDate,
    supplierName,
    supplierTaxId,
    docNumber,
    grossTotal,
    currency,
    docType,
    docTime,
    docSeries,
    controlCode,
    supplierAddress,
    supplierCity,
    supplierCountry,
    netTotal,
    taxTotal,
    discountTotal,
    Object.hashAll(taxSlots),
    exchangeRate,
    paymentMethod,
    cardBrand,
    cardMasked,
    authCode,
    iban,
    Object.hashAll(surcharges),
    licenceNumber,
    vehiclePlate,
    tripFrom,
    tripTo,
    distanceKm,
    durationMin,
    needsReview,
    recognitionEngine,
    sourceHash,
  ]);
}

/// Encodes [PaymentMethod] field values.
final FieldCodec<PaymentMethod> paymentMethodCodec = FieldCodec<PaymentMethod>(
  (value) => value.toJson(),
  PaymentMethod.fromJson,
);

Map<String, Object?> _asMap(Object? json) {
  if (json is! Map<String, Object?>) {
    throw FormatException('expected a JSON object');
  }
  return json;
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}
