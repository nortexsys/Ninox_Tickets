#!/usr/bin/env python3
"""Writes the synthetic fixture of the ADR-011 regression, next to this file.

    python app/test/fixtures/pdf/make_tomo_regression.py

The fixture is committed (`tomo_regression.pdf`) and this script only exists so
that the file can be regenerated and read. It is written with PDF operators
directly, so it needs no library at all: a generator that pulled in a PDF
library would add a licence question to a test fixture, and the fixture does not
need one — it is a page of text objects.

**What the fixture reproduces.** The failure ADR-011 was raised for, on
document PRO1013-26 of the 16-document test: a label and its value that plain
text extraction decoupled, after which the parser's last-resort fallback took
the number nearest the label *in extraction order* — a commercial-register
volume reference, `Tomo 8.741` — instead of the total. So the page carries:

* a total label (`Gesamtbetrag`) and its value (`1.234,50`) on **one visual
  line**, the value to the right of the label, but written as **two separate
  text objects far apart in the content stream**, which is what decouples them
  in an extractor that keeps the stream's order;
* the registry volume `Tomo 8.741` on the line below the label, written
  **immediately after the label** in the content stream — nearer to it in
  extraction order than the total is, and one line below it, which is where the
  second branch of the association rule would look.

Nothing on the page comes from a real document: the supplier, the invoice
number, the date and every amount are invented, and no real supplier, tax
identifier or printed value of the private corpus appears here.

The committed file is byte-for-byte what this script writes: no timestamp, no
document identifier, and no random value goes into it.
"""

from pathlib import Path

# PDF points, A4. The page is 595.28 x 841.89 pt, and the text is placed in
# PDF coordinates — origin at the page's bottom-left corner, y growing upwards.
PAGE_WIDTH = 595.28
PAGE_HEIGHT = 841.89

# Every text object of the page, in the order it is written into the content
# stream: (font size, x from the left, y from the bottom, text).
#
# The order is the point of the fixture. `Gesamtbetrag` is followed by
# `Tomo 8.741` and only much later by `1.234,50`, so an extractor that trusts
# the stream's order binds the volume; the positions put the total on the
# label's line and to its right, so an extractor that reads the visual layout
# binds the total.
TEXT_OBJECTS = (
    (12, 50, 780, "Beispiel Lieferant"),
    (10, 50, 762, "Rechnungsnummer 2026-0001"),
    (10, 50, 746, "Rechnungsdatum 2026-10-02"),
    (10, 50, 560, "Position 1  Beratung"),
    (10, 430, 560, "500,00"),
    (10, 50, 542, "Position 2  Material"),
    (10, 430, 542, "390,00"),
    (10, 50, 300, "Nettobetrag"),
    (10, 430, 300, "890,00"),
    # The label, and the number that follows it in the stream but not on its
    # line: the registry volume, one line below.
    (10, 50, 200, "Gesamtbetrag"),
    (10, 50, 182, "Tomo 8.741"),
    # The rest of the page, so that the total is not the next text object.
    (10, 50, 120, "Zahlungsziel 14 Tage"),
    (10, 50, 104, "Bankverbindung siehe Anlage"),
    # The total, on the label's line, to the right of it, written last.
    (10, 430, 200, "1.234,50"),
    (9, 50, 60, "Seite 1 von 1"),
)

CONTENTS = "\n".join(
    f"BT /F1 {size} Tf {x} {y} Td ({text}) Tj ET"
    for size, x, y, text in TEXT_OBJECTS
)


def build() -> bytes:
    """The whole PDF: objects, content stream, cross-reference table, trailer."""
    stream = f"stream\n{CONTENTS}\nendstream"
    objects = [
        "<< /Type /Catalog /Pages 2 0 R >>",
        "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        "<< /Type /Page /Parent 2 0 R "
        f"/MediaBox [0 0 {PAGE_WIDTH} {PAGE_HEIGHT}] "
        "/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
        f"<< /Length {len(CONTENTS) + 1} >>\n{stream}",
        "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica "
        "/Encoding /WinAnsiEncoding >>",
    ]

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
    target = Path(__file__).with_name("tomo_regression.pdf")
    target.write_bytes(build())
    print(f"wrote {target} ({target.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
