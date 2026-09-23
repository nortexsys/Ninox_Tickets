"""Common helpers: number/date parsing and deterministic validations.

Product context: Paperdrop (Ninox). Money is EUR here; parsing is locale-aware
because the corpus mixes Spanish (1.234,56) and English/US (1,234.56) formats.
"""
from __future__ import annotations

import re
from datetime import date

# ---------------------------------------------------------------- amounts

_NUM_RE = re.compile(r"\d{1,3}(?:[.\s]\d{3})+(?:,\d{1,2})?|\d+(?:[.,]\d{1,2})?")


def parse_amount(raw: str):
    """Parse a locale-ambiguous amount string into a float, or None.

    Handles: 1.234,56 / 1,234.56 / 1234,56 / 1234.56 / 123 030.00 / 19.99
    """
    if raw is None:
        return None
    s = str(raw).strip().replace("\u00a0", " ")
    s = re.sub(r"[€$£]|EUR|USD|GBP", "", s, flags=re.I).strip()
    s = s.replace(" ", "")
    if not s:
        return None

    # a space used as a thousands separator: "123 030.00" -> "123030.00"
    s = re.sub(r"(?<=\d)\s(?=\d{3}\b)", "", s)

    has_dot, has_comma = "." in s, "," in s
    try:
        if has_dot and has_comma:
            # the LAST separator is the decimal one
            if s.rfind(",") > s.rfind("."):
                s = s.replace(".", "").replace(",", ".")
            else:
                s = s.replace(",", "")
        elif has_comma:
            # 1234,56 -> decimal ; 1,234 -> thousands (3 digits after)
            last = s.rsplit(",", 1)[1]
            if len(last) == 3 and s.count(",") >= 1 and len(s.split(",")[0]) <= 3:
                s = s.replace(",", "")
            else:
                s = s.replace(",", ".")
        elif has_dot:
            last = s.rsplit(".", 1)[1]
            if len(last) == 3 and s.count(".") >= 1 and len(s.split(".")[0]) <= 3:
                # ambiguous: 1.234 -> could be thousands. Treat as thousands
                # only when there are exactly 3 trailing digits and no decimals.
                s = s.replace(".", "")
        return round(float(s), 2)
    except ValueError:
        return None


def find_amounts(text: str):
    """All amounts in the text, in order of appearance."""
    out = []
    for m in _NUM_RE.finditer(text):
        v = parse_amount(m.group(0))
        if v is not None:
            out.append((v, m.start(), m.group(0)))
    return out


# ---------------------------------------------------------------- dates

MESES = {
    "ene": 1, "feb": 2, "mar": 3, "abr": 4, "may": 5, "jun": 6,
    "jul": 7, "ago": 8, "sep": 9, "set": 9, "oct": 10, "nov": 11, "dic": 12,
    "jan": 1, "apr": 4, "aug": 8, "dec": 12,
}

_DATE_PATTERNS = [
    # 08/ago/26  06-ago-2026
    (re.compile(r"\b(\d{1,2})[/\-.]\s*([a-zA-Z]{3,4})[/\-.]\s*(\d{2,4})\b"),
     lambda m: (int(m.group(1)), MESES.get(m.group(2)[:3].lower()), int(m.group(3)))),
    # 08/08/26  08.08.2026  08-08-26
    (re.compile(r"\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})\b"),
     lambda m: (int(m.group(1)), int(m.group(2)), int(m.group(3)))),
    # 2026-08-08
    (re.compile(r"\b(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})\b"),
     lambda m: (int(m.group(3)), int(m.group(2)), int(m.group(1)))),
]


def _norm_year(y: int) -> int:
    if y < 100:
        return 2000 + y
    return y


def find_dates(text: str):
    """Candidate dates as (iso_string, position, raw)."""
    out = []
    for pat, extract in _DATE_PATTERNS:
        for m in pat.finditer(text):
            try:
                d, mo, y = extract(m)
            except (TypeError, ValueError):
                continue
            if not (d and mo and y):
                continue
            y = _norm_year(y)
            if not (1 <= d <= 31 and 1 <= mo <= 12 and 2000 <= y <= 2100):
                continue
            try:
                iso = date(y, mo, d).isoformat()
            except ValueError:
                continue
            out.append((iso, m.start(), m.group(0)))
    return out


MONTH_NAMES = {
    1: ("enero", "january", "januar"), 2: ("febrero", "february", "februar"),
    3: ("marzo", "march", "maerz", "märz"), 4: ("abril", "april"),
    5: ("mayo", "may"), 6: ("junio", "june", "juni"),
    7: ("julio", "july", "juli"), 8: ("agosto", "august"),
    9: ("septiembre", "september"), 10: ("octubre", "october", "oktober"),
    11: ("noviembre", "november"), 12: ("diciembre", "december", "dezember"),
}


def spell_out(iso: str) -> str:
    y, m, d = (int(x) for x in iso.split("-"))
    return f"{d} de {MONTH_NAMES[m][0]} de {y}"


# ---------------------------------------------------------------- validations

def vat_split(gross: float, rate_pct: float):
    """Derive (net, tax) from a tax-inclusive gross. Universal core rule."""
    net = round(gross / (1 + rate_pct / 100.0), 2)
    tax = round(gross - net, 2)
    return net, tax


def arithmetic_ok(net, tax, gross, tol=0.02) -> bool:
    if None in (net, tax, gross):
        return False
    return abs((net + tax) - gross) <= tol


def ean13_ok(code: str) -> bool:
    if not code or len(code) != 13 or not code.isdigit():
        return False
    d = [int(c) for c in code]
    chk = (10 - (sum(d[i] if i % 2 == 0 else 3 * d[i] for i in range(12)) % 10)) % 10
    return chk == d[12]


def nif_es_ok(nif: str):
    """Spanish NIF/NIE/CIF. Returns (valid, kind).

    NIF (natural person): 8 digits + letter, letter = TRWAGMYFPDXBNJZSQVHLCKE[num % 23]
    NIE: X/Y/Z + 7 digits + letter, same alphabet with X=0,Y=1,Z=2
    CIF (legal person): letter + 7 digits + control (digit or A-J letter)
    """
    if not nif:
        return False, None
    s = re.sub(r"[^0-9A-Za-z]", "", nif).upper()
    letters = "TRWAGMYFPDXBNJZSQVHLCKE"

    # NIE
    if len(s) == 9 and s[0] in "XYZ" and s[1:8].isdigit() and s[8].isalpha():
        num = int(str("XYZ".index(s[0])) + s[1:8])
        return letters[num % 23] == s[8], "ES_NIE"

    # NIF persona fisica
    if len(s) == 9 and s[:8].isdigit() and s[8].isalpha():
        return letters[int(s[:8]) % 23] == s[8], "ES_NIF"

    # CIF persona juridica
    if len(s) == 9 and s[0].isalpha() and s[1:8].isdigit() and s[8].isalnum():
        body = s[1:8]
        odd = sum(int(body[i]) for i in (0, 2, 4, 6))
        even = 0
        for i in (1, 3, 5):
            d = int(body[i]) * 2
            even += d // 10 + d % 10
        total = odd + even
        digit = (10 - (total % 10)) % 10
        ctrl = s[8]
        if s[0] in "ABCDEFGHJ":       # control is a digit
            return ctrl.isdigit() and int(ctrl) == digit, "ES_CIF"
        if s[0] in "KPQRSNW":          # control is a letter
            return ctrl.isalpha() and letters[digit] == ctrl, "ES_CIF"
        if s[0] in "ABEH":             # handled above; keep for completeness
            return False, "ES_CIF"
        return False, "ES_CIF"

    return False, None


def iban_ok(iban: str) -> bool:
    s = re.sub(r"[^0-9A-Za-z]", "", iban or "").upper()
    if len(s) < 15 or not s[:2].isalpha() or not s[2:4].isdigit():
        return False
    reordered = s[4:] + s[:4]
    num = "".join(str(int(c, 36)) if c.isalpha() else c for c in reordered)
    try:
        return int(num) % 97 == 1
    except ValueError:
        return False
