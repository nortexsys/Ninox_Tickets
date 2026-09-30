import 'dart:convert';
import 'dart:typed_data';

/// Documents built for the tests of the intake store.
///
/// They are synthetic and generated here, never taken from the private corpus
/// (`Paperdrop_corpus`, outside the repository by design) and never a real
/// supplier document: the batch of the 16-document test is not read, copied or
/// referenced from here.
///
/// [syntheticPdf] writes a small but structurally valid PDF — objects, content
/// stream, cross-reference table and trailer — so that a test can assert the
/// exact bytes it handed to the store.

/// A one-page PDF, optionally carrying [trailingPayload] after its end marker.
///
/// The payload stands in for what makes byte integrity load-bearing: a ZUGFeRD
/// or Factur-X invoice is a PDF with an XML document embedded in it, and a
/// re-save of that PDF would drop the XML. Extracting or re-attaching the XML is
/// not this change's (T1.15); what is proved here is that the bytes the store
/// was handed are the bytes the store kept, payload included.
Uint8List syntheticPdf({
  String text = 'Synthetic document for the intake tests',
  String trailingPayload = '',
}) {
  final List<String> objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
        '/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
    '',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  final String content = 'BT /F1 12 Tf 72 770 Td ($text) Tj ET';
  objects[3] = '<< /Length ${content.length} >>\nstream\n$content\nendstream';

  final StringBuffer pdf = StringBuffer('%PDF-1.4\n');
  final List<int> offsets = <int>[];
  for (int i = 0; i < objects.length; i++) {
    offsets.add(pdf.length);
    pdf.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final int xref = pdf.length;
  pdf.write('xref\n0 ${objects.length + 1}\n');
  pdf.write('0000000000 65535 f \n');
  for (final int offset in offsets) {
    pdf.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  pdf.write(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
    'startxref\n$xref\n%%EOF\n',
  );
  if (trailingPayload.isNotEmpty) {
    pdf.write(trailingPayload);
  }
  return Uint8List.fromList(utf8.encode(pdf.toString()));
}

/// A small JPEG-shaped fixture. Only its bytes matter to the intake store,
/// which never decodes an image.
Uint8List syntheticJpeg({String marker = 'synthetic-jpeg'}) =>
    Uint8List.fromList(<int>[
      0xFF,
      0xD8,
      0xFF,
      0xE0,
      ...utf8.encode(marker),
      0xFF,
      0xD9,
    ]);

/// A small PNG-shaped fixture, the same way.
Uint8List syntheticPng({String marker = 'synthetic-png'}) =>
    Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, ...utf8.encode(marker)]);

/// The stream of a fixture, in chunks, as a platform service would deliver it.
Stream<List<int>> chunksOf(List<int> bytes, {int chunkSize = 16}) async* {
  for (int i = 0; i < bytes.length; i += chunkSize) {
    final int end = i + chunkSize > bytes.length ? bytes.length : i + chunkSize;
    yield bytes.sublist(i, end);
  }
}
