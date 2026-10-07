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
volume reference, `Tomo 8.741` — instead of the total. The fixture carries that
failure on two pages, because the association rule has two branches and the
spec's two scenarios are one each
(`extraction-pipeline` · `positional-pdf-text-extraction`):

* **page 1** — the total is on the label's **own line, to the right of it**
  (the rule's first branch), written as a separate text object far from the
  label in the content stream, with the registry volume on the line below: the
  first branch must win, and the volume — which is what a naive rule reading
  only the line below would take — must not bind;
* **page 2** — the total is on the **line below** the label (the rule's second
  branch), overlapping it horizontally, while the registry volume is written
  **immediately after the label in the content stream** but on the row above,
  where nothing can bind it. This is the structure Core's own regression
  reproduces
  (`packages/paperdrop_core/test/regressions/regression_label_value_different_lines_test.dart`),
  and the scenario "a label on another line still binds its value".

Nothing on either page comes from a real document: the supplier, the invoice
numbers and every amount are invented, and no real supplier, tax identifier or
printed value of the private corpus appears here.

The committed file is byte-for-byte what this script writes: no timestamp, no
document identifier, and no random value goes into it.
"""

from pathlib import Path

# PDF points, A4. Each page is 595.28 x 841.89 pt, and the text is placed in
# PDF coordinates — origin at the page's bottom-left corner, y growing upwards.
PAGE_WIDTH = 595.28
PAGE_HEIGHT = 841.89

# Every text object of page 1, in the order it is written into the content
# stream: (font size, x from the left, y from the bottom, text).
#
# The order is half the point of the fixture. `Gesamtbetrag` is followed by
# `Tomo 8.741` and only much later by `1.234,50`, so an extractor that trusts
# the stream's order binds the volume; the positions put the total on the
# label's line and to its right, so an extractor that reads the visual layout
# binds the total.
PAGE_ONE = (
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
    (9, 50, 60, "Seite 1 von 2"),
)

# Every text object of page 2, in the same order. The label's line holds
# nothing but the label, so the rule's first branch finds no candidate; the
# registry volume is the **next** text object after the label, one row above it,
# so it is nearer in extraction order and unreachable by the layout rule; and
# the total is on the line below the label, overlapping it horizontally, which
# is where the second branch looks. The line spacing is 14 pt: a line's own
# height at 10 pt is under 10 pt, and the rule reaches no further below than one
# such height, so a wider gap would put the value out of reach.
PAGE_TWO = (
    (12, 50, 780, "Beispiel Lieferant"),
    (10, 50, 762, "Rechnungsnummer 2026-0002"),
    (10, 50, 560, "Position 1  Beratung"),
    (10, 430, 560, "500,00"),
    (10, 50, 300, "Nettobetrag"),
    (10, 430, 300, "890,00"),
    (10, 50, 400, "Gesamtbetrag"),
    (10, 50, 414, "Tomo 8.741"),
    (10, 50, 386, "1.234,50"),
    (9, 50, 60, "Seite 2 von 2"),
)


def content_stream(text_objects) -> str:
    """The content stream of one page, one text object per entry."""
    return "\n".join(
        f"BT /F1 {size} Tf {x} {y} Td ({text}) Tj ET"
        for size, x, y, text in text_objects
    )


def build() -> bytes:
    """The whole PDF: objects, both content streams, cross-reference and trailer."""
    pages = (content_stream(PAGE_ONE), content_stream(PAGE_TWO))
    objects = [
        "<< /Type /Catalog /Pages 2 0 R >>",
        "<< /Type /Pages /Kids [3 0 R 6 0 R] /Count 2 >>",
        # Page 1 and its content stream, then the shared font, then page 2.
        "<< /Type /Page /Parent 2 0 R "
        f"/MediaBox [0 0 {PAGE_WIDTH} {PAGE_HEIGHT}] "
        "/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
        f"<< /Length {len(pages[0]) + 1} >>\nstream\n{pages[0]}\nendstream",
        "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica "
        "/Encoding /WinAnsiEncoding >>",
        "<< /Type /Page /Parent 2 0 R "
        f"/MediaBox [0 0 {PAGE_WIDTH} {PAGE_HEIGHT}] "
        "/Resources << /Font << /F1 5 0 R >> >> /Contents 7 0 R >>",
        f"<< /Length {len(pages[1]) + 1} >>\nstream\n{pages[1]}\nendstream",
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
