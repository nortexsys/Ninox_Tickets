"""Generate a fictional invoice PDF that carries a tip line, for testing.

Everything in the produced document is invented: issuer, customer, tax
identifiers, addresses, invoice number and payment method. It identifies no
natural person, so regenerating it never republishes anybody's data and the
artifact stays safe to use as pipeline input (AGENTS.md 1.2).

The amounts are fixed by the request that produced this script:

    base imponible   100,00 EUR
    IVA 21%           21,00 EUR
    total factura    121,00 EUR
    propina           15,00 EUR
    total a pagar    136,00 EUR

The four checks in ``_check_arithmetic`` are the point of the script: they make
the document refuse to exist if the numbers stop adding up.

Usage:

    python corpus_test/src/make_demo_invoice.py
    python corpus_test/src/make_demo_invoice.py --out corpus_test/inbox/otro.pdf
"""

from __future__ import annotations

import argparse
from decimal import Decimal
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

# --- The requested amounts, in one place -----------------------------------

VAT_RATE = Decimal("0.21")
BASE_IMPONIBLE = Decimal("100.00")
VAT_AMOUNT = Decimal("21.00")
INVOICE_TOTAL = Decimal("121.00")
TIP = Decimal("15.00")
AMOUNT_DUE = Decimal("136.00")

# Line items. Their importes must add up to the base imponible.
LINES: tuple[tuple[str, int, Decimal], ...] = (
    ("Menú del día", 2, Decimal("25.00")),
    ("Entrecot a la parrilla", 1, Decimal("30.00")),
    ("Postre casero", 2, Decimal("6.00")),
    ("Bebida (refresco)", 4, Decimal("2.00")),
)

ISSUER = (
    "PAPERDROP DEMO, S.L.",
    "CIF: B00000000 (ficticio)",
    "Calle Falsa 123, 28080 Madrid",
    "Tel. 900 000 000",
)
CUSTOMER = (
    "CLIENTE DE PRUEBA, S.L.",
    "CIF: B11111111 (ficticio)",
    "Avenida Inventada 45, 08001 Barcelona",
)
INVOICE_NUMBER = "DEMO-2026-0001"
INVOICE_DATE = "28/09/2026"
PAYMENT_METHOD = "Efectivo"


def eur(value: Decimal) -> str:
    """Format an amount the Spanish way: thousands with '.', decimals with ','."""
    whole, cents = f"{value:.2f}".split(".")
    grouped = f"{int(whole):,}".replace(",", ".")
    return f"{grouped},{cents} €"


def _check_arithmetic() -> Decimal:
    """Return the sum of the lines, refusing to build an inconsistent invoice."""
    lines_total = sum((qty * price for _, qty, price in LINES), Decimal("0.00"))

    assert lines_total == BASE_IMPONIBLE, (
        f"lines add up to {lines_total}, not to the base imponible {BASE_IMPONIBLE}"
    )
    assert (BASE_IMPONIBLE * VAT_RATE).quantize(Decimal("0.01")) == VAT_AMOUNT, (
        f"IVA at {VAT_RATE} of {BASE_IMPONIBLE} is not {VAT_AMOUNT}"
    )
    assert BASE_IMPONIBLE + VAT_AMOUNT == INVOICE_TOTAL, (
        f"{BASE_IMPONIBLE} + {VAT_AMOUNT} is not {INVOICE_TOTAL}"
    )
    assert INVOICE_TOTAL + TIP == AMOUNT_DUE, (
        f"{INVOICE_TOTAL} + {TIP} is not {AMOUNT_DUE}"
    )
    return lines_total


def build(path: Path) -> Path:
    total_lines = _check_arithmetic()

    styles = getSampleStyleSheet()
    body = ParagraphStyle(
        "Body", parent=styles["Normal"], fontName="Helvetica", fontSize=9.5, leading=13
    )
    small = ParagraphStyle("Small", parent=body, fontSize=8, leading=10.5)
    title = ParagraphStyle(
        "Title",
        parent=styles["Title"],
        fontName="Helvetica-Bold",
        fontSize=22,
        leading=26,
        alignment=2,
        spaceAfter=2,
    )
    warning = ParagraphStyle(
        "Warning",
        parent=body,
        fontName="Helvetica-Bold",
        fontSize=9,
        leading=12,
        alignment=1,
        textColor=colors.HexColor("#B00020"),
    )

    def block(lines: tuple[str, ...]) -> Paragraph:
        first, *rest = lines
        text = f"<b>{first}</b>"
        if rest:
            text += "<br/>" + "<br/>".join(rest)
        return Paragraph(text, body)

    story: list = []

    story.append(
        Paragraph(
            "DOCUMENTO FICTICIO — SIN VALIDEZ FISCAL. Datos inventados para pruebas.",
            warning,
        )
    )
    story.append(Spacer(1, 6 * mm))

    header = Table(
        [
            [
                block(ISSUER),
                [Paragraph("FACTURA", title), Paragraph(f"Nº {INVOICE_NUMBER}", body)],
            ]
        ],
        colWidths=[100 * mm, 70 * mm],
    )
    header.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 0),
                ("RIGHTPADDING", (0, 0), (-1, -1), 0),
                ("TOPPADDING", (0, 0), (-1, -1), 0),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 0),
            ]
        )
    )
    story.append(header)
    story.append(Spacer(1, 6 * mm))

    meta = Table(
        [
            [
                Paragraph(
                    f"<b>Cliente:</b><br/>{CUSTOMER[0]}<br/>{CUSTOMER[1]}<br/>{CUSTOMER[2]}",
                    body,
                ),
                Paragraph(
                    f"<b>Fecha de emisión:</b> {INVOICE_DATE}<br/>"
                    f"<b>Forma de pago:</b> {PAYMENT_METHOD}",
                    body,
                ),
            ]
        ],
        colWidths=[100 * mm, 70 * mm],
    )
    meta.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F4F4F4")),
                ("BOX", (0, 0), (-1, -1), 0.4, colors.HexColor("#CCCCCC")),
                ("LEFTPADDING", (0, 0), (-1, -1), 5),
                ("RIGHTPADDING", (0, 0), (-1, -1), 5),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    story.append(meta)
    story.append(Spacer(1, 7 * mm))

    rows = [["Descripción", "Cant.", "Precio unit.", "Importe"]]
    for description, quantity, price in LINES:
        rows.append([description, str(quantity), eur(price), eur(quantity * price)])
    # Subtotal of the lines. It is the base imponible, but the tax breakdown
    # below labels it that way; here it would only read as a duplicate.
    rows.append(["Total líneas", "", "", eur(total_lines)])

    items = Table(rows, colWidths=[95 * mm, 20 * mm, 28 * mm, 27 * mm], hAlign="LEFT")
    items.setStyle(
        TableStyle(
            [
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("FONTNAME", (0, -1), (-1, -1), "Helvetica-Bold"),
                ("FONTSIZE", (0, 0), (-1, -1), 9.5),
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E8E8E8")),
                ("ALIGN", (1, 1), (-1, -1), "RIGHT"),
                ("LINEBELOW", (0, 0), (-1, -2), 0.4, colors.HexColor("#CCCCCC")),
                ("LINEABOVE", (0, -1), (-1, -1), 0.8, colors.black),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    story.append(items)
    story.append(Spacer(1, 6 * mm))

    totals = Table(
        [
            ["Base imponible", eur(BASE_IMPONIBLE)],
            [f"IVA {int(VAT_RATE * 100)}%", eur(VAT_AMOUNT)],
            ["TOTAL FACTURA", eur(INVOICE_TOTAL)],
            ["Propina (voluntaria, fuera de la base imponible)", eur(TIP)],
            ["TOTAL A PAGAR", eur(AMOUNT_DUE)],
        ],
        colWidths=[75 * mm, 30 * mm],
        hAlign="RIGHT",
    )
    totals.setStyle(
        TableStyle(
            [
                ("FONTSIZE", (0, 0), (-1, -1), 9.5),
                ("ALIGN", (1, 0), (1, -1), "RIGHT"),
                ("FONTNAME", (0, 2), (-1, 2), "Helvetica-Bold"),
                ("LINEABOVE", (0, 2), (-1, 2), 0.8, colors.black),
                ("FONTNAME", (0, 4), (-1, 4), "Helvetica-Bold"),
                ("FONTSIZE", (0, 4), (-1, 4), 11),
                ("BACKGROUND", (0, 4), (-1, 4), colors.HexColor("#E8E8E8")),
                ("BOX", (0, 4), (-1, 4), 0.8, colors.black),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                # 0, not 5: the amounts must end on the same vertical line as the
                # Importe column of the lines table above.
                ("RIGHTPADDING", (0, 0), (-1, -1), 0),
            ]
        )
    )
    story.append(totals)
    story.append(Spacer(1, 7 * mm))

    story.append(
        Paragraph(
            "Nota: la propina es voluntaria y, en este ejemplo, se suma al total de la "
            "factura sin formar parte de la base imponible ni del IVA. "
            "Documento generado por Paperdrop for Ninox como material de prueba: "
            "no corresponde a ninguna operación real y no tiene validez fiscal.",
            small,
        )
    )

    path.parent.mkdir(parents=True, exist_ok=True)
    SimpleDocTemplate(
        str(path),
        pagesize=A4,
        leftMargin=20 * mm,
        rightMargin=20 * mm,
        topMargin=18 * mm,
        bottomMargin=18 * mm,
        title=f"Factura ficticia {INVOICE_NUMBER}",
        author="Paperdrop for Ninox (material de prueba)",
        subject="Factura de ejemplo con propina — datos ficticios",
    ).build(story)
    return path


def main() -> int:
    default = Path(__file__).resolve().parents[1] / "inbox" / "factura_demo_paperdrop.pdf"
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=default, help=f"destino ({default})")
    args = parser.parse_args()

    written = build(args.out)
    print(f"written: {written}")
    print(f"bytes:   {written.stat().st_size}")
    print(
        f"base {eur(BASE_IMPONIBLE)} | IVA {eur(VAT_AMOUNT)} | "
        f"total {eur(INVOICE_TOTAL)} | propina {eur(TIP)} | a pagar {eur(AMOUNT_DUE)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
