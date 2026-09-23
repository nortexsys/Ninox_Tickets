"""Stage 2 - parsing: text passes become the canonical field model.

Design follows the PDR's confidence model:
  * amount arithmetic is the primary constraint (net + tax = gross)
  * readings are VOTED across OCR passes, and arithmetic adjudicates
  * every field carries a state: confirmed / read / derived / missing

This stage decides what the documents say. What gets written to Ninox is
decided in stage 3 (load_ninox.py).
"""
from __future__ import annotations

import json
import os
import re
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from parse_common import (
    find_amounts, find_dates, parse_amount, vat_split, arithmetic_ok,
    nif_es_ok, iban_ok, ean13_ok,
)

from config import BASE, OUT, TEXT_OUT, RENDER_OUT, PARSED_OUT, ATTACH_OUT, LOG_NINOX, CORPUS
TEXT_DIR = TEXT_OUT
OUT_DIR = PARSED_OUT

# ---------------------------------------------------------------- label sets

# A total, in several languages. Order matters: the most specific first.
TOTAL_LABELS = [
    r"TOTAL\s*(?:A\s*PAGAR|COMPRA|FACTURA|SUMINIST\w*)?",
    r"IMPORTE\s*(?:TOTAL|LIQUIDO|DE\s*FACTURA)?",
    r"SUMA\s*TOTAL",
    r"TOTAL\s*USD",
    r"TOTAL\s*\+?\s*TAX",
    r"GRAND\s*TOTAL",
    r"GESAMT(?:BETRAG|SUMME)?",
    r"SUMME",
    r"TOTAL",
]
NET_LABELS = [
    r"BASE\s*IMP\.?",
    r"BASE\s*IMPONIBLE",
    r"B\.?\s*IMP\.?",
    r"BASE\s*\(E\)\s*XENTA",
    r"BASE",
    r"SUBTOTAL",
    r"IMPORTE\s*BRUTO",
    r"SUBTOTAL\s*US\$?",
    r"SUB-?TOTAL",
    r"NETTO",
    r"NET\s*TOTAL",
]
TAX_LABELS = [
    r"IMP\.?\s*IVA",
    r"IMPORTE\s*IVA",
    r"IVA\s*REPERCUTIDO",
    r"C?UOTA\s*IVA",
    r"CUOTA",
    r"IVA",
    r"VAT",
    r"TAX",
    r"MWST",
]

# Labels that sit next to numbers which are NOT money: authorisation codes,
# terminal ids, AIDs, operation numbers, tax identifiers...
# Kept deliberately narrow: an over-eager list silently discards real totals.
NOISE_LABELS = re.compile(
    r"\b(AUT|AUTH|AUTORIZ|ARC|AID|TPV|TERMINAL|OPERAC|TRANSAC|"
    r"COMERCIO|LICENCIA|MATRICULA|RUC|IBAN|TARJETA|TEL|FAX|"
    r"OPER|PAN|UNL|STAN|CADUCIDAD|TARJETA|TRAFICO)\s*[:.]?\s*\d",
    re.I)

# A line holding any of these is metadata: an id printed on the same line as a
# total would otherwise be read as the total itself.
NOISE_LINE = re.compile(
    r"\b(AUT|AUTH|AUTORIZ|ARC|AID|TPV|OPERAC|TRANSAC|OPER|PAN|UNL|STAN|"
    r"CADUCIDAD|MATRICULA|LICENCIA|IBAN|RUC|TERMINAL|COMERCIO|TRAFICO|"
    r"OPERAD|ACLA|AVL)\b", re.I)

# a line that looks like a date rather than an amount
_DATE_LIKE = re.compile(r"^\s*\d{1,4}[/\-.]\d{1,2}[/\-.]\d{1,4}")

# any money figure carrying an explicit currency mark (group 1 = amount,
# group 2 = the mark itself, so the currency of each figure is known)
CURRENCY_AMOUNT = re.compile(
    r"(\d[\d.,]*(?:\s\d{3})*)\s*(€|EUR|USD|GBP|MAD|\$)", re.I)

_AMOUNT = r"(\d[\d.,]*(?:\s\d{3})*)"

# "21,00 %" is a rate, never an amount
_PCT_AFTER = re.compile(r"^\s*%")


def _is_money(raw, text, end_pos):
    """Reject things that look like numbers but are not money."""
    r = raw.strip()
    # a rate
    if _PCT_AFTER.match(text[end_pos:end_pos + 3]):
        return False
    # a bare integer with no decimals is only money above 31 (below that it is
    # a day, a quantity, a count...)
    if re.fullmatch(r"\d{1,2}", r) and int(r) <= 31:
        return False
    return True


def label_regex(labels):
    """Build the pattern with numbered groups: 1=label, 2=currency, 3=amount.

    The amount must be on the same line as its label (or the line right after),
    otherwise a stray figure from a paragraph can be picked up as the total.
    """
    alt = "|".join(labels)
    return re.compile(
        rf"({alt})[ \t]*:?[ \t]*[€$]?[ \t]*(EUR|USD|GBP|CHF)?[ \t]*{_AMOUNT}",
        re.I)


def classify_line(linea):
    """Locate the money on one line and say what role the line plays.

    Returns (role, value) or (None, None). Roles, in order of authority:
      gross  - what the customer pays
      net    - taxable base
      tax    - tax amount
      rate   - a percentage, never money
    """
    l = linea.strip()
    if not l:
        return None, None
    # a percentage line carries a rate, not an amount
    if re.search(r"\d\s*%", l):
        # "IVA 21,00%  1,99  0,42" -> the rate is 21,00 but 1,99/0,42 are money
        sin_pct = re.sub(r"\d+[.,]?\d*\s*%", "", l)
        valor = _first_money(sin_pct)
        if valor is None:
            return "rate", None
        l = sin_pct
    else:
        valor = _first_money(l)
    if valor is None:
        return None, None
    if valor > 50_000_000:
        return None, None

    up = l.upper()
    if NOISE_LABELS.search(up):
        return None, None

    # a line whose only number is an authorisation/operation code
    if re.search(r"\b(AUT|ARC|AID|TPV|OP|OPERAC|TRANSAC)\b", up) and "TOTAL" not in up:
        return None, None

    # order matters: "TOTAL FACTURA" is not a "SUBTOTAL"
    if re.search(r"\bSUB\s?-?TOTAL\b", up):
        return "net", valor
    if re.search(r"\bTOTAL\b|\bA\s+PAGAR\b|\bGESAMT|\bSUMME\b", up):
        return "gross", valor
    if re.search(r"\bBASE\b|\bB\.?\s?IMP\b|\bNETO\b|\bNETTO\b|\bIMPORTE\s+BRUTO\b|\bBRUTO\b", up):
        return "net", valor
    if re.search(r"\bIVA\b|\bVAT\b|\bCUOTA\b|\bTAX\b|\bIMPUESTO\b", up):
        return "tax", valor
    return None, None


_MONEY_IN_LINE = re.compile(r"\d[\d.,]*(?:\s\d{3})*")


def _last_money(l):
    """Last plausible money figure in a line: on a table row the amount is the
    final column, not the first (the first is usually a quantity or a rate)."""
    vals = []
    for m in _MONEY_IN_LINE.finditer(l):
        raw = m.group(0)
        antes = l[max(0, m.start() - 3):m.start()]
        despues = l[m.end():m.end() + 2]
        if "%" in despues:
            continue
        if re.search(r"\d[/\-.]$", antes):
            continue
        digitos = re.sub(r"\D", "", raw)
        # a bare long integer is an identifier, not an amount, unless it is
        # grouped in thousands ("123 030.00", "50.069,90")
        agrupado = bool(re.match(r"^\d{1,3}(?:[.\s]\d{3})+", raw))
        if "," not in raw and "." not in raw and not agrupado and len(digitos) >= 3:
            continue
        v = parse_amount(raw)
        if v is None:
            continue
        if re.fullmatch(r"\d{1,2}", raw) and int(raw) <= 31:
            continue
        vals.append(v)
    return vals[-1] if vals else None


def _role_of(l):
    up = l.upper()
    if re.search(r"\bSUB\s?-?TOTAL\b", up):
        return "net"
    if re.search(r"\bTOTAL\b|\bA\s+PAGAR\b|\bGESAMT|\bSUMME\b|\bIMPORTE\s+DE\s+FACTURA\b", up):
        return "gross"
    if re.search(r"\bBASE\b|\bB\.?\s?IMP\b|\bNETO\b|\bNETTO\b|\bIMPORTE\s+BRUTO\b|\bBRUTO\b", up):
        return "net"
    if re.search(r"\bIVA\b|\bVAT\b|\bCUOTA\b|\bTAX\b|\bIMPUESTO\b", up):
        return "tax"
    return None


def classify_line(linea):
    """Locate the money on one line and say what role the line plays."""
    l = linea.strip()
    if not l:
        return None, None
    if NOISE_LABELS.search(l):
        return None, None

    rol = _role_of(l)
    if rol is None:
        return None, None
    # a metadata line that incidentally carries a money word ("Total" next to
    # an authorisation code, "Oper" next to a terminal id) is not a source
    if NOISE_LINE.search(l):
        return None, None

    if re.search(r"\d\s*%", l):
        # a rate line: strip the percentage so the money columns remain
        sin_pct = re.sub(r"\d+[.,]?\d*\s*%", "", l)
        valor = _last_money(sin_pct)
        if valor is None:
            return "rate", None
        return rol, valor

    return rol, _last_money(l)


def scan_lines(text):
    """Classify every line, looking one line ahead for a label's value.

    Invoices frequently print the label and its amount on separate lines
    ("A PAGAR" then "2,41"), so a label without a value on its own line
    borrows the first plausible amount below it.
    """
    todos = {"gross": [], "net": [], "tax": [], "rate": []}
    lineas = [l.strip() for l in text.splitlines()]
    for i, linea in enumerate(lineas):
        if not linea:
            continue
        rol, valor = classify_line(linea)

        if rol == "rate" and valor is None:
            m = re.search(r"(\d+)[.,]?(\d*)\s*%", linea)
            if m:
                try:
                    todos["rate"].append(
                        float(f"{m.group(1)}.{m.group(2)}" if m.group(2) else m.group(1)))
                except ValueError:
                    pass
            continue

        if rol is None:
            continue

        if valor is None:
            # look ahead for the amount that belongs to this label
            for j in range(i + 1, min(i + 4, len(lineas))):
                sig = lineas[j]
                if not sig:
                    continue
                if _DATE_LIKE.match(sig):
                    continue
                if _role_of(sig) is not None:
                    break
                cand = _last_money(sig)
                if cand is not None:
                    valor = cand
                    break

        if valor is not None and valor <= 50_000_000:
            todos[rol].append({"value": valor, "line": i, "text": linea[:70]})
    return todos


def vat_rate(text):
    """Rate printed as 21,00 % or 21.00% or IVA 21%."""
    rates = []
    for m in re.finditer(r"(?:IVA|VAT|IMP\.?\s*IVA|MWST)[^\n%]{0,12}?(\d{1,2})\s*[.,]?\s*(\d{0,2})\s*%",
                         text, re.I):
        try:
            r = float(f"{m.group(1)}.{m.group(2)}") if m.group(2) else float(m.group(1))
            rates.append(r)
        except ValueError:
            pass
    for m in re.finditer(r"(\d{1,2})[.,](\d{2})\s*%", text):
        try:
            rates.append(float(f"{m.group(1)}.{m.group(2)}"))
        except ValueError:
            pass
    for m in re.finditer(r"\b(\d{1,2})\s*%", text):
        try:
            rates.append(float(m.group(1)))
        except ValueError:
            pass
    # drop implausible rates
    rates = [r for r in rates if 0 <= r <= 30]
    if not rates:
        return None, []
    c = Counter(rates)
    return c.most_common(1)[0][0], rates


def currency(text):
    """The currency the document is denominated in.

    A receipt drawn abroad mentions two currencies (the local one and the card
    one). The one that labels the amounts is the document's currency.
    """
    principal = _moneda_principal(text)
    if principal:
        return principal, 1.0
    votos = Counter()
    for m in re.finditer(r"\b(EUR|USD|GBP|CHF)\b", text, re.I):
        votos[m.group(1).upper()] += 1
    for m in re.finditer(r"US\$|\$", text):
        votos["USD"] += 1
    for m in re.finditer(r"€", text):
        votos["EUR"] += 1
    if not votos:
        return "EUR", 0.0
    top, n = votos.most_common(1)[0]
    return top, n / sum(votos.values())


def supplier_name(text):
    """First meaningful line that looks like a business name."""
    conocidos = {
        "EL CORTE INGLES": "EL CORTE INGLES, S.A.",
        "ALBASANZ": "U.S. ALBASANZ",
        "PLENERGY": "PLENERGY GRUPO, S.L.",
        "CAIXABANK": "CAIXABANK, S.A.",
        "NIEHOFF": "MASCHINENFABRIK NIEHOFF GmbH & Co. KG",
        "PROFISER": "PROFESIONALES FISCALES Y DE SERVICIOS, S.L.",
        "SUPPLIER_C": "SUPPLIER_C GROUP INC",
        "SUPPLIER_E": "SUPPLIER_E PANAMA INC.",
        "LOGISTICA DE SERVICIOS": "LOGISTICA DE SERVICIOS CONSOLIDADOS SL",
    }
    upper = text.upper()
    for clave, nombre in conocidos.items():
        if clave in upper:
            return nombre, "map"
    # generic: a line with S.L./S.A./GmbH/INC and some length
    for linea in text.splitlines():
        l = linea.strip()
        if 6 < len(l) < 70 and re.search(r"\b(S\.L|S\.A|SL|SA|GMBH|INC|LTD|B\.V|SAS|SRL)\b", l, re.I):
            return re.sub(r"\s{2,}", " ", l), "line"
    for linea in text.splitlines():
        l = linea.strip()
        if 6 < len(l) < 60 and re.search(r"[A-Za-z]{4}", l):
            return re.sub(r"\s{2,}", " ", l), "line"
    return None, None


def tax_ids(text):
    out = []
    for m in re.finditer(r"\b([A-Z])\s?[-.]?\s?(\d{7,8})\s?([0-9A-Z])\b", text):
        candidato = f"{m.group(1)}{m.group(2)}{m.group(3)}"
        ok, kind = nif_es_ok(candidato)
        out.append({"raw": m.group(0).strip(), "normalized": candidato,
                    "valid": ok, "kind": kind})
    # DE USt-IdNr
    for m in re.finditer(r"\bDE\s?(\d{9})\b", text):
        out.append({"raw": m.group(0), "normalized": "DE" + m.group(1),
                    "valid": None, "kind": "DE_USTID"})
    return out


def doc_number(text):
    pats = [
        r"(?:FACTURA|INVOICE|RECIBO|Invoice\s*#|Nº\s*FACTURA)[^\n]{0,30}?([A-Z0-9][A-Z0-9/\-\.]{3,20})",
        r"Nº/fecha\s*documento\s*\n?\s*(\d{5,12})",
        r"C[OÓ]DIGO\s*DE\s*CONTROL\s*:?\s*([0-9A-Z]{6,14})",
    ]
    for p in pats:
        m = re.search(p, text, re.I)
        if m:
            return m.group(1).strip()
    return None


def card_mask(text):
    for m in re.finditer(r"(\d{4,6})\s?[xX*]{2,}\s?[xX*]*\s?(\d{4})", text):
        return f"{m.group(1)}xxxxxx{m.group(2)}"
    for m in re.finditer(r"[xX*]{4,}\s?(\d{4})\b", text):
        return f"xxxx{m.group(1)}"
    return None


TAX_WORDS = re.compile(r"IVA|VAT|MWST|UST|TAX|IMPUESTO", re.I)


def votar_importes(passes):
    """Vote labelled amounts across OCR passes.

    A noisy pass can inflate a figure ("96,76" read as "9676"). The clean
    passes agree with each other, so the majority reading of a given label wins
    and the outlier is discarded. This is the "voting between readings" the PDR
    puts at the centre of the confidence model.
    """
    votos = {}   # label -> Counter of raw values
    for nombre, texto in passes.items():
        if nombre == "pdf_text":
            continue
        for linea in texto.splitlines():
            l = linea.strip()
            if not l:
                continue
            # keep the label, drop the rest
            m = re.match(r"^(.{3,40}?)[\s:+=»]+\s*[\d.,]+\s*(MAD|EUR|USD|GBP|€|\$)?\s*$",
                         l, re.I)
            if not m:
                continue
            etiqueta = re.sub(r"[^A-Z ]", "", m.group(1).upper()).strip()
            etiqueta = re.sub(r"\s+", " ", etiqueta)
            if len(etiqueta) < 4:
                continue
            vals = [v for v in _vals_de_linea(l)]
            if len(vals) != 1:
                continue
            votos.setdefault(etiqueta, Counter())[(vals[0], (m.group(2) or "").upper())] += 1

    consenso = {}
    for etiqueta, c in votos.items():
        (valor, marca), n = c.most_common(1)[0]
        total = sum(c.values())
        consenso[etiqueta] = {
            "valor": valor, "marca": marca or None,
            "votos": n, "pasadas": total,
            "unanimidad": n == total,
            "alternativas": [{"valor": v, "marca": mk, "votos": k}
                             for (v, mk), k in c.most_common()[1:3]],
        }
    return consenso


def _vals_de_linea(l):
    """Every plausible money value in a line (used by the voting stage)."""
    vals = []
    for m in _MONEY_IN_LINE.finditer(l):
        raw = m.group(0)
        despues = l[m.end():m.end() + 4]
        if "%" in despues:
            continue
        if re.search(r"\d[/\-.]$", l[max(0, m.start() - 3):m.start()]):
            continue
        v = parse_amount(raw)
        if v is None:
            continue
        if re.fullmatch(r"\d{1,2}", raw) and int(raw) <= 31:
            continue
        vals.append(v)
    return vals


def _moneda_de(marca):
    """Currency implied by the mark that followed an amount."""
    if not marca:
        return None
    m = marca.upper()
    if m in ("€", "EUR"):
        return "EUR"
    if m in ("$", "USD"):
        return "USD"
    if m == "GBP":
        return "GBP"
    if m == "MAD":
        return "MAD"
    return m


# currency codes that appear as a bare word next to an amount
_CODIGOS_MONEDA = re.compile(r"\b(EUR|USD|GBP|MAD|CHF|DHS?)\b", re.I)


def _moneda_principal(text):
    """The currency the document is mostly written in (the repeated one)."""
    votos = Counter()
    for m in CURRENCY_AMOUNT.finditer(text):
        c = _moneda_de(m.group(2))
        if c:
            votos[c] += 1
    for m in _CODIGOS_MONEDA.finditer(text):
        c = _moneda_de(m.group(1))
        if c:
            votos[c] += 1
    if not votos:
        return None
    return votos.most_common(1)[0][0]


def adjudicate_amounts(text, passes=None):
    """Resolve net / tax / gross from per-line candidates plus arithmetic.

    Priority order, mirroring the PDR's confidence model:
      1. a labelled trio that reconciles            -> confirmed
      2. a labelled pair plus the printed rate       -> confirmed
      3. gross + rate, both of them derived          -> derived
      4. whatever the document prints, unreconciled  -> read (flagged)
    """
    pools = scan_lines(text)
    rate, all_rates = vat_rate(text)
    curr, curr_conf = currency(text)

    grosses = sorted({c["value"] for c in pools["gross"]}, reverse=True)
    nets = sorted({c["value"] for c in pools["net"]}, reverse=True)
    taxes = sorted({c["value"] for c in pools["tax"]}, reverse=True)
    # a zero amount is not "no data": a fully subsidised invoice really is 0,00 €
    cero_gross = any(v == 0 for v in grosses)

    consenso = votar_importes(passes or {}) if passes else {}

    evidencia = {
        "gross_lines": pools["gross"][:6],
        "net_lines": pools["net"][:6],
        "tax_lines": pools["tax"][:6],
        "rates_seen": sorted(set(all_rates))[:8],
        "rate_chosen": rate,
        "consenso_entre_pasadas": consenso,
    }

    gross = gross_method = None
    net = tax = net_method = tax_method = None
    estado = "missing"

    def buscar_trio(exigir_tipo=True):
        """A labelled (net, tax, gross) that reconciles, best-fit on the rate."""
        mejor = None
        for g in grosses:
            for n in nets:
                for t in taxes:
                    if not arithmetic_ok(n, t, g):
                        continue
                    consistente = True
                    if exigir_tipo and rate:
                        esperado = round(n * rate / 100.0, 2)
                        consistente = abs(esperado - t) <= 0.05
                    punt = (consistente, -abs((n + t) - g))
                    if mejor is None or punt > mejor[0]:
                        mejor = (punt, n, t, g)
        return mejor

    # ---- 0) cross-pass voting: the clean passes agree on a labelled amount
    #         while a noisy pass inflates it ("96,76" -> "9676"). A consensus
    #         overrides the per-line maximum, and it also settles which figure
    #         is the charged amount when the receipt carries two currencies.
    if consenso:
        extranjera = bool(curr and curr != "EUR")
        etiqueta_pagada = None
        for et in consenso:
            # "MONTANT EN DEVISE" (amount in card currency) is what was charged
            if extranjera and ("DEVISE" in et or "CARD" in et):
                etiqueta_pagada = et
                break
        elegida = consenso.get(etiqueta_pagada) if etiqueta_pagada else None
        if elegida and elegida["unanimidad"]:
            gross = elegida["valor"]
            gross_method = "voto_entre_pasadas"
            estado = "confirmed"
            if extranjera:
                net = tax = 0.0
                net_method = tax_method = "sin_iva_extranjero"
            elif rate is not None:
                net, tax = vat_split(gross, rate)
                net_method = tax_method = "derived_from_gross"

    # ---- 1) labelled trio that reconciles, and matches the printed rate
    elegido = buscar_trio(True) or buscar_trio(False)
    if elegido:
        _, net, tax, gross = elegido
        net_method = tax_method = "label+arithmetic"
        gross_method = "label"
        estado = "confirmed"

    # ---- 2) gross + rate printed, net/tax derived
    if net is None and grosses and rate is not None:
        gross = grosses[0]
        gross_method = "label"
        net, tax = vat_split(gross, rate)
        net_method = tax_method = "derived_from_gross"
        estado = "derived"

    # ---- 3) net + tax printed but incoherent: keep what is printed
    if net is None and nets and taxes:
        net, tax = nets[0], taxes[0]
        net_method = tax_method = "label_incoherent"
        gross = grosses[0] if grosses else round(net + tax, 2)
        gross_method = "label" if grosses else "derived_sum"
        estado = "incoherent"

    # ---- 4) only a net, with a rate
    if net is None and nets and rate is not None:
        net = nets[0]
        tax = round(net * rate / 100.0, 2)
        gross = round(net + tax, 2)
        net_method, tax_method, gross_method = "label", "derived_rate", "derived"
        estado = "derived"

    # ---- 5) closing rule: gross alone
    if net is None and grosses:
        gross = grosses[0]
        gross_method = "label"
        if rate is not None:
            net, tax = vat_split(gross, rate)
            net_method = tax_method = "derived_from_gross"
            estado = "derived"
        else:
            estado = "read"

    # ---- 6) no labelled total anywhere: net and tax printed, so the total is
    #         their sum (card-processor receipts print only the charged amount)
    if gross is None and nets and taxes:
        net, tax = nets[0], taxes[0]
        gross = round(net + tax, 2)
        net_method, tax_method = "label", "label"
        gross_method = "derived_sum"
        estado = "derived"

    # ---- 7) last resort: no labelled total, but the document prints amounts
    #         with an explicit currency mark. Those are real money; identifiers
    #         never carry a € or a $. Recorded as read, never as confirmed.
    if gross is None and not cero_gross:
        con_moneda = []
        for m in CURRENCY_AMOUNT.finditer(text):
            v = parse_amount(m.group(1))
            if v is None or not (0 < v <= 50_000_000):
                continue
            # a figure introduced by "=" is a rate, not an amount:
            # "TAUX DE CHANGE 1 EUR=10,3348 MAD"
            antes = text[max(0, m.start() - 12):m.start()]
            if "=" in antes or re.search(r"\b(taux|cambio|change|rate|equivalent)\b",
                                         antes, re.I):
                continue
            moneda = _moneda_de(m.group(2))
            con_moneda.append((v, moneda))
        if con_moneda:
            # prefer the main currency of the document (the one repeated most)
            casa = _moneda_principal(text)
            propias = [c for c in con_moneda if c[1] == casa] or con_moneda
            gross = max(c[0] for c in propias)
            gross_method = "currency_marked"
            estado = "read"
            # a foreign-currency receipt carries a conversion rate, so the net
            # and tax cannot simply be divided by a printed percentage
            extranjera = casa and casa != "EUR"
            if rate is not None and not extranjera:
                net, tax = vat_split(gross, rate)
                net_method = tax_method = "derived_from_gross"
            elif extranjera:
                net, tax = gross, 0.0
                net_method = tax_method = "foreign_currency_no_tax_split"

    # ---- 8) truly nothing: the largest plausible figure, flagged for review
    if gross is None and not cero_gross:
        # money on a document with a text layer has decimals; a bare long
        # integer there is an identifier (N.I.F., account, reference)
        decimales = [v for v, _, raw in find_amounts(text)
                     if 0 < v <= 50_000_000 and ("." in raw or "," in raw)]
        candidatos = decimales if decimales else [v for v, _, _ in find_amounts(text)
                                                  if 0 < v <= 50_000_000]
        # plausibility: a "total" wildly larger than the typical figure on the
        # page is an identifier that slipped through
        if candidatos:
            ordenados = sorted(candidatos)
            mediana = ordenados[len(ordenados) // 2]
            razonables = [v for v in candidatos if v <= max(1.0, mediana) * 50]
            candidatos = razonables or candidatos
        if candidatos:
            gross = max(candidatos)
            gross_method = "max_any"
            estado = "read_weak"
            if rate is not None:
                net, tax = vat_split(gross, rate)
                net_method = tax_method = "derived_from_gross"

    return {
        "gross": gross, "gross_method": gross_method,
        "net": net, "net_method": net_method,
        "tax": tax, "tax_method": tax_method,
        "rate": rate, "state": estado,
        "currency": curr, "currency_confidence": round(curr_conf, 2),
        "evidence": evidencia,
    }


# ---------------------------------------------------------------- date pick

def norm_ocr(text):
    """Repair the OCR confusions that actually break date/month parsing.

    "ago" read as "ag0" or "a90", "21/08" read as "21,08", digits glued to a
    month ("ag0726") are the recurring ones on thermal receipts.
    """
    t = text
    t = re.sub(r"\b(ene|feb|mar|abr|may|jun|jul|ago|sep|set|oct|nov|dic)[0-9]",
               lambda m: m.group(0)[:3], t, flags=re.I)
    t = t.replace("ag0", "ago").replace("a90", "ago").replace("se9", "sep")
    t = t.replace("jul", "jul").replace("0ct", "oct").replace("nov", "nov")
    return t


# plausible window: a receipt from the future is a misread
def plausible_date(iso: str, hoy="2026-09-21") -> bool:
    return iso <= hoy and iso >= "2000-01-01"


def pick_date(text, filename, hoy="2026-09-21"):
    cands = find_dates(norm_ocr(text))
    cands = [c for c in cands if plausible_date(c[0], hoy)]
    if not cands:
        return None, "missing", []

    fn_dates = [c[0] for c in find_dates(filename) if plausible_date(c[0], hoy)]
    cont = Counter(c[0] for c in cands)
    votos = cont.most_common()

    for iso, _ in votos:
        if iso in fn_dates:
            return iso, "filename_match", votos

    maxv = votos[0][1]
    empatadas = sorted([iso for iso, n in votos if n == maxv])
    elegida = empatadas[-1] if len(empatadas) > 1 else empatadas[0]
    state = "read" if (len(votos) == 1 or maxv > 1) else "read_ambiguous"
    return elegida, state, votos


def _score_passes(passes):
    """Rank a set of text passes by how much usable document they carry.

    The email signature image produces a couple of lines; a real invoice
    produces hundreds of characters. The text layer always wins.
    """
    if not passes:
        return -1
    if "pdf_text" in passes:
        return 10_000 + len(passes["pdf_text"])
    return len("\n".join(passes.values()))


def parse_document(doc):
    """One document JSON -> canonical field model."""
    if doc.get("kind") == "email":
        # an email carries several attachments; the document is the one with
        # real content, never the signature image
        candidatos = [a for a in doc.get("attachments", []) if a.get("passes")]
        if not candidatos:
            return None
        att = max(candidatos, key=lambda a: _score_passes(a["passes"]))
        passes = att["passes"]
        doc = dict(doc)
        doc["filename_effective"] = att["declared_name"]
    else:
        passes = doc.get("passes") or {}
        doc["filename_effective"] = doc["filename"]

    textos = list(passes.values())
    if not textos:
        return None
    unido = "\n".join(textos)
    # the best single pass = the one with most recognisable words
    mejor_pasada = max(passes.items(), key=lambda kv: len(re.findall(r"[A-Za-zÁÉÍÓÚÑáéíóúñ]{3,}", kv[1])))

    money = adjudicate_amounts(unido, passes)

    # A deterministic text layer should never yield figures that contradict
    # each other. When they do, the document is incoherent and it is recorded
    # as such rather than silently corrected.
    texto_determinista = "pdf_text" in passes
    conflicto = None
    if texto_determinista:
        pools = scan_lines(unido)
        gs = {c["value"] for c in pools["gross"]}
        if len(gs) > 1 and money["gross"] not in (None, max(gs)):
            conflicto = f"candidatos de total contradictorios: {sorted(gs)}"

    nombre, nombre_how = supplier_name(unido)
    ids = tax_ids(unido)
    valido = [i for i in ids if i["valid"]]

    fecha, fecha_estado, votos_fecha = pick_date(unido, doc["filename_effective"])
    # confidence flags
    aritmetica_ok = arithmetic_ok(money["net"], money["tax"], money["gross"])

    return {
        "doc_id": doc["doc_id"],
        "filename": doc["filename"],
        "filename_effective": doc["filename_effective"],
        "route": doc["kind"],
        "sha256": doc["sha256"],
        "pages": doc.get("pages", 1),
        "best_pass": mejor_pasada[0],
        "fields": {
            "doc_date": fecha,
            "supplier_name": nombre,
            "supplier_tax_id": (valido[0]["normalized"] if valido else
                                (ids[0]["normalized"] if ids else None)),
            "supplier_tax_id_raw": (valido[0]["raw"] if valido else
                                    (ids[0]["raw"] if ids else None)),
            "supplier_tax_id_kind": (valido[0]["kind"] if valido else None),
            "doc_number": doc_number(unido),
            "currency": money["currency"],
            "gross_total": money["gross"],
            "net_total": money["net"],
            "tax_total": money["tax"],
            "tax_rate": money["rate"],
            "payment_card": card_mask(unido),
        },
        "field_status": {
            "doc_date": fecha_estado,
            "gross_total": money["gross_method"] or "missing",
            "net_total": money["net_method"] or "missing",
            "tax_total": money["tax_method"] or "missing",
            "tax_rate": "read" if money["rate"] is not None else "missing",
            "supplier_name": nombre_how or "missing",
        },
        "checks": {
            "arithmetic_reconciles": aritmetica_ok,
            "tax_id_control_valid": bool(valido),
            "date_candidates": votos_fecha[:6],
            "conflict": conflicto,
        },
        "evidence": money["evidence"],
    }


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    salida = []
    for nombre in sorted(os.listdir(TEXT_DIR)):
        if not nombre.endswith(".json"):
            continue
        with open(os.path.join(TEXT_DIR, nombre), encoding="utf-8") as f:
            doc = json.load(f)
        r = parse_document(doc)
        if r is None:
            print(f"  {nombre}: sin contenido analizable")
            continue
        salida.append(r)
        f_ = r["fields"]
        chk = "OK " if r["checks"]["arithmetic_reconciles"] else "NO "
        print(f"{r['filename'][:46]:48s} {str(f_['doc_date']):12s} "
              f"net={str(f_['net_total']):>10s} tax={str(f_['tax_total']):>8s} "
              f"gross={str(f_['gross_total']):>11s} IVA={str(f_['tax_rate']):>5s} [{chk}]")
        with open(os.path.join(OUT_DIR, f"{r['doc_id']}.json"), "w", encoding="utf-8") as f:
            json.dump(r, f, ensure_ascii=False, indent=2)
    print(f"\n{len(salida)} documentos parseados -> {OUT_DIR}")


if __name__ == "__main__":
    main()
