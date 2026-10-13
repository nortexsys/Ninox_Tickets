#!/usr/bin/env python3
"""Writes the synthetic fixture of the photo route's harness, next to this file.

    python app/test/fixtures/ocr/make_synthetic_invoice.py

The fixture is committed (`synthetic_invoice.pdf`) and this script only exists so
that the file can be regenerated and read. It is written with PDF operators
directly, so it needs no library at all: a generator that pulled in a PDF
library would add a licence question to a test fixture, and the fixture does
not need one — it is a page of text objects.

**What the fixture is for.** The device run of `implement-photo-route`
(`app/integration_test/ocr_eval_test.dart`, task 2.2) needs one document on the
device before the photographed corpus is pushed there: a document whose content
is known, so that a harness that writes nothing, or writes without words, is
visible at once instead of after the corpus has been read. This is that
document.

**What it is not.** It is **not a scan and not a photograph**: it is a page of
text, and it says nothing about the recognition quality of the photographed
corpus, which is what T2.5 measures on documents that never enter the
repository. It is also not a regression of a real failure, unlike the invoice
route's fixture: the photo route's failure modes are the engine's, and they are
measured, not reproduced.

**The layout is the binder's.** Each label sits at the left of its line and its
value on the same line, to the right of it, so that the layout rule of
`positional-pdf-text-extraction` has something to bind when T2.1 wires the
route. Nothing overlaps, and every line stands alone.

Nothing on the page comes from a real document: the supplier, the invoice number,
the date and every amount are invented, and no real supplier, tax identifier or
printed value of the private corpus appears here. The committed file is
byte-for-byte what this script writes: no timestamp, no document identifier and
no random value goes into it.
"""

from pathlib import Path

# PDF points, A4: 1/72 inch, origin at the page's bottom-left corner, y growing
# upwards. The page a phone photographs is this shape, and the renderer scales
# it by the resolution each pass asks for.
PAGE_WIDTH = 595.28
PAGE_HEIGHT = 841.89

# Every text object of the page, in the order it is written into the content
# stream: (font size, x from the left, y from the bottom, text). The total's
# label and its value share a line, the value to the right of the label, as a
# printed invoice sets them.
TEXT_OBJECTS = (
    (14, 50, 780, "Beispiel Lieferant GmbH"),
    (10, 50, 762, "Musterstrasse 12, 10115 Beispielstadt"),
    (10, 50, 726, "Rechnungsnummer 2026-0001"),
    (10, 50, 710, "Rechnungsdatum 2026-10-02"),
    (10, 50, 560, "Position 1  Beratung"),
    (10, 430, 560, "500,00"),
    (10, 50, 542, "Position 2  Material"),
    (10, 430, 542, "390,00"),
    (10, 50, 300, "Nettobetrag"),
    (10, 430, 300, "890,00"),
    (10, 50, 282, "Umsatzsteuer 19 Prozent"),
    (10, 430, 282, "169,10"),
    (10, 50, 240, "Gesamtbetrag"),
    (10, 430, 240, "1.059,10"),
    (10, 50, 120, "Zahlungsziel 14 Tage"),
    (9, 50, 60, "Seite 1 von 1"),
)

OBJECTS = (
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R "
    f"/MediaBox [0 0 {PAGE_WIDTH} {PAGE_HEIGHT}] "
    "/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
    "",  # the content stream, filled in below
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica "
    "/Encoding /WinAnsiEncoding >>",
)


def content_stream() -> str:
    """The page's content stream, one text object per line of the page."""
    return "\n".join(
        f"BT /F1 {size} Tf {x} {y} Td ({text}) Tj ET"
        for size, x, y, text in TEXT_OBJECTS
    )


def build() -> bytes:
    """The whole PDF: objects, the content stream, cross-reference and trailer."""
    stream = content_stream()
    objects = list(OBJECTS)
    objects[3] = f"<< /Length {len(stream) + 1} >>\nstream\n{stream}\nendstream"

    pdf = bytearray(b"%PDF-1.4\n")
    offsets = []
    for index, body in enumerate(objects, start=1):
        offsets.append(len(pdf))
        pdf += f"{index} 0 obj\n{body}\nendobj\n".encode("ascii")

    startxref = len(pdf)
    pdf += f"xref\n0 {len(objects) + 1}\n".encode("ascii")
    pdf += b"0000000000 65535 f \n"
    for offset in offsets:
        pdf += f"{offset:010d} 00000 n \n".encode("ascii")
    pdf += (
        f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\n"
        f"startxref\n{startxref}\n%%EOF\n"
    ).encode("ascii")
    return bytes(pdf)


def main() -> None:
    target = Path(__file__).with_name("synthetic_invoice.pdf")
    target.write_bytes(build())
    print(f"wrote {target} ({target.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
