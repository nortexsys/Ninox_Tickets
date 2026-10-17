/// Images a decoder can really open, built from bytes
/// (`implement-photo-passes`, design §3 and §4).
///
/// **Why they exist.** The photo route's image passes decode a photograph, and
/// an oriented JPEG is decoded differently from one that is not. A host test
/// therefore needs images with real compressed data — and with an EXIF
/// `Orientation` tag where the test is about orientation — and no image of the
/// private corpus may enter the repository. These functions write the bytes of
/// such an image themselves: every pixel is a grey level the test chose, every
/// byte is invented here, and the files are as small as a valid file can be.
///
/// **What they are not.** [decodableJpeg] and [decodablePng] are pictures;
/// `synthetic_jpeg.dart` beside this file is **structure** — segment headers
/// with zero-filled bodies, which is what the header walk reads and what no
/// decoder can open. A test that opens a file with a decoder uses this file; a
/// test that only reads a size uses that one. The exception is a test about the
/// EXIF tag itself, which reads a picture's `APP1` and needs no decoder: the
/// tool that writes one is this one.
///
/// **The JPEG is a real one.** Baseline sequential, one grey component, the
/// two standard luminance Huffman tables of the JPEG standard's Annex K, a
/// quantisation table of ones, and every block coded from its DC coefficient
/// plus the end-of-block symbol — which is exactly what a flat image needs and
/// which a decoder (libjpeg-turbo through Skia, in this application) reads like
/// any other baseline file. No library is involved and none was added: the
/// bytes are assembled here.
library;

import 'dart:io' show ZLibCodec;
import 'dart:typed_data';

/// A baseline JPEG of [width] by [height] pixels, every pixel the grey level
/// [grey] — or, when [blockGreys] is given, one grey level per 8x8 block, in
/// row-major block order.
///
/// [exifOrientation] is one of the eight values the tag defines (1 is the
/// unrotated default, 6 means the stored image must be turned a quarter turn
/// clockwise for display, and 5, 6, 7 and 8 are the four that exchange the
/// image's width and height). The tag is written in an `APP1` segment ahead of
/// the frame, which is where a camera puts it.
///
/// The width and height written in the frame header are the **stored** size
/// and not the displayed one: a JPEG declares what it holds, and the tag says
/// how to show it. That is the difference the orientation tests are about.
///
/// A two-tone file ([blockGreys]) is what tells a decoder that applied the
/// orientation from one that only reported a size: the flat blocks survive the
/// quantisation of ones exactly, so a dark block and a light one come back as
/// the grey levels that were written, in the place the orientation puts them.
Uint8List decodableJpeg({
  required int width,
  required int height,
  int grey = 128,
  List<int>? blockGreys,
  int? exifOrientation,
}) {
  if (width <= 0 || height <= 0) {
    throw ArgumentError.value('$width x $height', 'width');
  }
  if (grey < 0 || grey > 255) {
    throw ArgumentError.value(grey, 'grey');
  }
  if (exifOrientation != null && (exifOrientation < 1 || exifOrientation > 8)) {
    throw ArgumentError.value(exifOrientation, 'exifOrientation');
  }
  final int blocksAcross = (width + 7) ~/ 8;
  final int blocksDown = (height + 7) ~/ 8;
  if (blockGreys != null && blockGreys.length != blocksAcross * blocksDown) {
    throw ArgumentError.value(
      blockGreys.length,
      'blockGreys',
      'an image of $width x $height holds ${blocksAcross * blocksDown} blocks',
    );
  }

  final BytesBuilder out = BytesBuilder();
  out.add(<int>[0xFF, 0xD8]); // start of image

  // JFIF, the segment every encoder writes first and no decoder requires.
  out.add(<int>[
    0xFF, 0xE0, 0x00, 0x10, //
    ...'JFIF'.codeUnits, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01,
    0x00, 0x00,
  ]);

  if (exifOrientation != null) {
    out.add(_exifApp1(exifOrientation));
  }

  // A quantisation table of ones: the DC of a flat block survives it exactly,
  // which is what keeps this encoder thirty lines long.
  out.add(<int>[0xFF, 0xDB, 0x00, 0x43, 0x00]);
  out.add(List<int>.filled(64, 1));

  out.add(<int>[
    0xFF, 0xC0, 0x00, 0x0B, 0x08, // frame header, baseline, 8 bits
    (height >> 8) & 0xFF, height & 0xFF, //
    (width >> 8) & 0xFF, width & 0xFF,
    0x01, // one component
    0x01, 0x11, 0x00, // its id, its sampling factors, its quantisation table
  ]);

  out.add(_huffmanSegment(tableClass: 0x00, bits: _dcBits, values: _dcValues));
  out.add(_huffmanSegment(tableClass: 0x10, bits: _acBits, values: _acValues));

  out.add(<int>[
    0xFF, 0xDA, 0x00, 0x08, // start of scan
    0x01, 0x01, 0x00, // one component, its Huffman tables
    0x00, 0x3F, 0x00, // the spectral selection of a sequential file
  ]);

  // One DC coefficient and one end-of-block symbol per 8x8 block, which is all
  // a flat image has. The blocks past the edge are flat too, so no padding
  // rule is exercised. Each block's DC is coded as the difference from the one
  // before it, which is what a sequential JPEG does.
  final _EntropyWriter entropy = _EntropyWriter();
  var previousDc = 0;
  for (var block = 0; block < blocksAcross * blocksDown; block++) {
    final int level = blockGreys?[block] ?? grey;
    final int dc = 8 * (level - 128);
    final int difference = dc - previousDc;
    previousDc = dc;
    final int category = _category(difference);
    entropy.write(_code(_dcCodes, category), _dcLengths[category]!);
    if (difference != 0) {
      final int value = difference > 0
          ? difference
          : difference + (1 << category) - 1;
      entropy.write(value, category);
    }
    entropy.write(_code(_acCodes, 0x00), _acLengths[0x00]!); // end of block
  }
  out.add(entropy.finish());

  out.add(<int>[0xFF, 0xD9]); // end of image
  return out.takeBytes();
}

/// A grey PNG of [width] by [height] pixels, every pixel the grey level [grey].
///
/// Eight bits per pixel, one colour component, no interlacing and the `none`
/// filter on every row: a decoder reads it as the simplest PNG there is, and a
/// PNG carries no orientation of its own — which is exactly the point, since
/// the orientation question is a JPEG's.
Uint8List decodablePng({
  required int width,
  required int height,
  int grey = 128,
}) {
  if (width <= 0 || height <= 0) {
    throw ArgumentError.value('$width x $height', 'width');
  }
  final BytesBuilder raw = BytesBuilder();
  for (var row = 0; row < height; row++) {
    raw.addByte(0x00); // filter: none
    raw.add(List<int>.filled(width, grey));
  }

  final List<int> ihdr = <int>[
    ..._bigEndian(width),
    ..._bigEndian(height),
    0x08, // eight bits per pixel
    0x00, // colour type 0: one grey component
    0x00, // compression: the only one PNG defines
    0x00, // filter method: the only one
    0x00, // no interlacing
  ];
  final BytesBuilder out = BytesBuilder();
  out.add(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  out.add(_chunk('IHDR', ihdr));
  // zlib, which is what an IDAT holds: dart:io's codec writes the header and
  // the checksum PNG expects.
  out.add(_chunk('IDAT', ZLibCodec(level: 6).encode(raw.takeBytes())));
  out.add(_chunk('IEND', const <int>[]));
  return out.takeBytes();
}

/// One PNG chunk: its length, its type, its data, and the CRC of the last two.
List<int> _chunk(String type, List<int> data) {
  final List<int> payload = <int>[...type.codeUnits, ...data];
  return <int>[
    ..._bigEndian(data.length),
    ...payload,
    ..._bigEndian(_crc32(payload)),
  ];
}

List<int> _bigEndian(int value) => <int>[
  (value >> 24) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
];

/// The CRC PNG checks a chunk with: the standard polynomial, reflected, and a
/// table built once here.
int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final int byte in bytes) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

final List<int> _crcTable = List<int>.generate(256, (int index) {
  var value = index;
  for (var bit = 0; bit < 8; bit++) {
    value = value & 1 == 1 ? 0xEDB88320 ^ (value >> 1) : value >> 1;
  }
  return value;
});

/// The `APP1` segment holding an EXIF `Orientation` tag: the `Exif` signature,
/// a little-endian TIFF header, one IFD entry, and no second IFD.
///
/// This is the whole of what a camera's EXIF says that this route needs, and
/// it is what a decoder's orientation reader looks for.
List<int> _exifApp1(int orientation) {
  final List<int> payload = <int>[
    ...'Exif'.codeUnits, 0x00, 0x00, //
    0x49, 0x49, 0x2A, 0x00, // "II", little-endian, TIFF magic
    0x08, 0x00, 0x00, 0x00, // the first IFD starts right after this header
    0x01, 0x00, // one entry
    0x12, 0x01, // tag 0x0112: Orientation
    0x03, 0x00, // type 3: SHORT
    0x01, 0x00, 0x00, 0x00, // one value, written in the entry itself
    orientation & 0xFF, (orientation >> 8) & 0xFF, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, // no second IFD
  ];
  final int length = payload.length + 2;
  return <int>[
    0xFF, 0xE1, (length >> 8) & 0xFF, length & 0xFF, //
    ...payload,
  ];
}

/// One Huffman table, as a `DHT` segment: its class and destination, the count
/// of codes of each length, and the symbols.
List<int> _huffmanSegment({
  required int tableClass,
  required List<int> bits,
  required List<int> values,
}) {
  final int length = 2 + 1 + 16 + values.length;
  return <int>[
    0xFF, 0xC4, (length >> 8) & 0xFF, length & 0xFF, //
    tableClass,
    ...bits,
    ...values,
  ];
}

/// The number of bits a DC difference of [value] is coded in: zero for zero,
/// and the position of its highest bit otherwise.
int _category(int value) {
  var magnitude = value.abs();
  var bits = 0;
  while (magnitude != 0) {
    magnitude >>= 1;
    bits++;
  }
  return bits;
}

/// The canonical Huffman code of [symbol], from the table built below.
int _code(Map<int, int> codes, int symbol) {
  final int? code = codes[symbol];
  if (code == null) {
    throw StateError('the table holds no code for $symbol');
  }
  return code;
}

/// The codes of a Huffman table, from its code counts and its symbols, by the
/// algorithm the JPEG standard's Annex C gives: codes of one length in the
/// order the symbols are listed, then one bit shifted left per longer length.
Map<int, int> _codesFor(List<int> bits, List<int> values) {
  final Map<int, int> codes = <int, int>{};
  var code = 0;
  var symbol = 0;
  for (var length = 1; length <= 16; length++) {
    for (var index = 0; index < bits[length - 1]; index++) {
      if (symbol >= values.length) {
        throw StateError('the table declares more codes than it has symbols');
      }
      codes[values[symbol]] = code;
      code++;
      symbol++;
    }
    code <<= 1;
  }
  if (symbol != values.length) {
    throw StateError('the table declares fewer codes than it has symbols');
  }
  return codes;
}

/// The standard luminance DC table (JPEG standard, Annex K.3.3.1): the codes
/// of the twelve categories a 8-bit sample can need.
const List<int> _dcBits = <int>[0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0];

const List<int> _dcValues = <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

/// The standard luminance AC table (Annex K.3.3.2). Only its end-of-block
/// symbol is used to write a flat image, and the whole table is written because
/// a decoder expects the table an encoder names in its scan header.
const List<int> _acBits = <int>[
  0,
  2,
  1,
  3,
  3,
  2,
  4,
  3,
  5,
  5,
  4,
  4,
  0,
  0,
  1,
  0x7D,
];

const List<int> _acValues = <int>[
  0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, //
  0x21, 0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07,
  0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xA1, 0x08,
  0x23, 0x42, 0xB1, 0xC1, 0x15, 0x52, 0xD1, 0xF0,
  0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0A, 0x16,
  0x17, 0x18, 0x19, 0x1A, 0x25, 0x26, 0x27, 0x28,
  0x29, 0x2A, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
  0x3A, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49,
  0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59,
  0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69,
  0x6A, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79,
  0x7A, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
  0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98,
  0x99, 0x9A, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7,
  0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6,
  0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5,
  0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xD2, 0xD3, 0xD4,
  0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xE1, 0xE2,
  0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA,
  0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8,
  0xF9, 0xFA,
];

/// The codes and the lengths of the tables, built once.
final Map<int, int> _dcCodes = _codesFor(_dcBits, _dcValues);
final Map<int, int> _acCodes = _codesFor(_acBits, _acValues);

/// The length of each code, which writing one symbol needs.
final Map<int, int> _dcLengths = _lengthsFor(_dcBits, _dcValues);
final Map<int, int> _acLengths = _lengthsFor(_acBits, _acValues);

Map<int, int> _lengthsFor(List<int> bits, List<int> values) {
  final Map<int, int> lengths = <int, int>{};
  var symbol = 0;
  for (var length = 1; length <= 16; length++) {
    for (var index = 0; index < bits[length - 1]; index++) {
      lengths[values[symbol]] = length;
      symbol++;
    }
  }
  return lengths;
}

/// The bits of one scan: written most significant bit first, and every `0xFF`
/// byte followed by a zero byte, which is how a JPEG keeps a marker out of its
/// entropy-coded data.
class _EntropyWriter {
  final BytesBuilder _bytes = BytesBuilder();
  int _current = 0;
  int _bits = 0;

  /// Writes the [length] lowest bits of [value].
  void write(int value, int length) {
    for (var bit = length - 1; bit >= 0; bit--) {
      _current = (_current << 1) | ((value >> bit) & 1);
      _bits++;
      if (_bits == 8) {
        _flush();
      }
    }
  }

  /// The scan's bytes, with the last byte padded with ones, as the standard
  /// says it must be.
  Uint8List finish() {
    while (_bits != 0) {
      _current = (_current << 1) | 1;
      _bits++;
      if (_bits == 8) {
        _flush();
      }
    }
    return _bytes.takeBytes();
  }

  void _flush() {
    _bytes.addByte(_current);
    if (_current == 0xFF) {
      _bytes.addByte(0x00);
    }
    _current = 0;
    _bits = 0;
  }
}
