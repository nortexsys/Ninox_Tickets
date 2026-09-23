"""Stage 3 - load into Ninox.

Writes one record per corpus file into table YB (Tarjetas Banco) and attaches
the document. Field mapping agreed with Alvaro:

  Tipo                  -> 1, i.e. the choice option "Cargo puntual"
  Fecha                 -> date printed on the document
  Tarjeta Bancaria      -> left NULL (not in the source documents)
  Importe               -> Base Imponible (net_total)
  Importe IVA deducible -> the VAT amount (tax_total)
  attachment            -> the processed document

YB has no total field, so the gross total is preserved in the extraction log
rather than dropped silently.

Usage:
  python src/load_ninox.py --dry-run        show what would be written
  python src/load_ninox.py --only D25eea658 one document
  python src/load_ninox.py                  write everything
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time

import requests

from config import BASE, OUT, TEXT_OUT, RENDER_OUT, PARSED_OUT, ATTACH_OUT, LOG_NINOX, CORPUS
PARSED = PARSED_OUT
TEXTDIR = TEXT_OUT
LOG = LOG_NINOX

TEAM = os.environ.get("NINOX_TEAM_ID", "qCq3JS7q7ptoap8Yg")
DB = "db0000000000"                 # TEST-DB-CLAUDE, per the corpus brief
TABLE = "YB"                        # Tarjetas Banco
API = "https://api.ninox.com/v1"
TIPO_CARGO_PUNTUAL = "Cargo puntual"


def api_key():
    k = os.environ.get("NINOX_API_KEY")
    if k:
        return k
    # the variable exists at user level; the process may not have inherited it
    import winreg
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as key:
            return winreg.QueryValueEx(key, "NINOX_API_KEY")[0]
    except OSError:
        pass
    raise SystemExit("NINOX_API_KEY no disponible")


class Ninox:
    def __init__(self, key):
        self.h = {"Authorization": f"Bearer {key}"}
        self.base = f"{API}/teams/{TEAM}/databases/{DB}/tables/{TABLE}"

    def crear(self, fields):
        r = requests.post(f"{self.base}/records", headers={**self.h,
                          "Content-Type": "application/json"},
                          json={"fields": fields}, timeout=60)
        if r.status_code != 200:
            raise RuntimeError(f"crear -> HTTP {r.status_code}: {r.text[:300]}")
        return r.json()

    def leer(self, rec_id):
        r = requests.get(f"{self.base}/records/{rec_id}", headers=self.h, timeout=60)
        return r.json() if r.status_code == 200 else None

    def subir(self, rec_id, path, nombre):
        mime = "application/pdf" if path.lower().endswith(".pdf") else "image/jpeg"
        with open(path, "rb") as f:
            r = requests.post(f"{self.base}/records/{rec_id}/files", headers=self.h,
                              files={"file": (nombre, f, mime)}, timeout=180)
        if r.status_code != 200:
            raise RuntimeError(f"subir -> HTTP {r.status_code}: {r.text[:300]}")
        return r.text

    def ficheros(self, rec_id):
        r = requests.get(f"{self.base}/records/{rec_id}/files", headers=self.h, timeout=60)
        return r.json() if r.status_code == 200 else None

    def borrar(self, rec_id):
        r = requests.delete(f"{self.base}/records/{rec_id}", headers=self.h, timeout=60)
        return r.status_code


def fecha_valida(iso):
    if not iso or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", iso):
        return False
    from datetime import date
    try:
        y, m, d = (int(x) for x in iso.split("-"))
        date(y, m, d)
    except ValueError:
        return False
    return 2000 <= y <= 2030


def decide_fecha(parsed):
    f = parsed["fields"]["doc_date"]
    if fecha_valida(f):
        return f
    # fall back to a date inside the file name when the document has none
    nombre = parsed["filename_effective"]
    for pat in (r"(20\d{2})-(\d{2})-(\d{2})",
                r"\b(\d{2})[/\-.](\d{2})[/\-.](\d{4})\b",
                r"\b(\d{2})[/\-.](\d{2})[/\-.](\d{2})\b"):
        for m in re.finditer(pat, nombre):
            g = m.groups()
            if len(g[0]) == 4:
                cand = f"{g[0]}-{g[1]}-{g[2]}"
            elif len(g[2]) == 4:
                cand = f"{g[2]}-{g[1]}-{g[0]}"
            else:
                cand = f"20{g[2]}-{g[1]}-{g[0]}"
            if fecha_valida(cand):
                return cand
    return None


def decide_importes(parsed):
    """Return (importe_base, importe_iva) per the agreed mapping.

    `Importe` is the base imponible. Two cases need care:
      * a foreign-currency cash withdrawal has no Spanish base at all, so the
        amount actually charged is what must be recorded;
      * a document where only the gross survived still must not write a zero.
    """
    f = parsed["fields"]
    net, tax, gross = f["net_total"], f["tax_total"], f["gross_total"]
    sin_iva_por_naturaleza = parsed["field_status"].get("tax_total") in (
        "sin_iva_extranjero", "foreign_currency_no_tax_split")

    if sin_iva_por_naturaleza:
        return (gross if gross is not None else 0.0), 0.0

    if net is None and gross is not None and f["tax_rate"]:
        net = round(gross / (1 + f["tax_rate"] / 100.0), 2)
    if tax is None and net is not None and gross is not None:
        tax = round(gross - net, 2)
    if net is None and gross is not None:
        net, tax = gross, 0.0
    if net is None:
        net, tax = 0.0, 0.0
    return net, tax


def adjunto_de(parsed, text_doc):
    """The file to attach: the document itself, or the email's real attachment."""
    if parsed["route"] == "email":
        for a in text_doc.get("attachments", []):
            if a.get("passes"):
                return a["extracted_path"], a["declared_name"]
    return text_doc["path"], os.path.basename(text_doc["path"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--only", default=None)
    args = ap.parse_args()

    n = Ninox(api_key())
    registro = []

    for nombre in sorted(os.listdir(PARSED)):
        if not nombre.endswith(".json"):
            continue
        did = nombre[:-5]
        if args.only and did != args.only:
            continue
        with open(os.path.join(PARSED, nombre), encoding="utf-8") as f:
            parsed = json.load(f)
        with open(os.path.join(TEXTDIR, nombre), encoding="utf-8") as f:
            text_doc = json.load(f)

        fecha = decide_fecha(parsed)
        net, tax = decide_importes(parsed)
        adj_path, adj_nombre = adjunto_de(parsed, text_doc)

        fields = {
            "Tipo": TIPO_CARGO_PUNTUAL,
            "Fecha": fecha,
            "Importe": net,
            "Importe IVA deducible": tax,
        }

        entrada = {
            "doc_id": did,
            "fichero": parsed["filename"],
            "documento_efectivo": parsed["filename_effective"],
            "ruta": parsed["route"],
            "fecha": fecha,
            "base_imponible": net,
            "iva_deducible": tax,
            "total_documento": parsed["fields"]["gross_total"],
            "iva_tipo": parsed["fields"]["tax_rate"],
            "moneda": parsed["fields"]["currency"],
            "proveedor": parsed["fields"]["supplier_name"],
            "aritmetica_cuadra": parsed["checks"]["arithmetic_reconciles"],
            "conflicto": parsed["checks"]["conflict"],
            "metodo_base": parsed["field_status"]["net_total"],
            "metodo_iva": parsed["field_status"]["tax_total"],
            "adjunto": adj_nombre,
            "adjunto_existe": os.path.exists(adj_path),
        }

        if args.dry_run:
            entrada["accion"] = "dry-run"
            registro.append(entrada)
            print(f"{did}  {str(fecha):12s} Importe={net:>12} IVA={tax:>10} "
                  f"total={str(parsed['fields']['gross_total']):>12} "
                  f"[{'OK' if parsed['checks']['arithmetic_reconciles'] else 'REVISAR'}] "
                  f"{parsed['filename'][:34]}")
            continue

        try:
            rec = n.crear(fields)
            rid = rec.get("id")
            entrada["ninox_id"] = rid
            # read back: Ninox formulas and defaults can override what we sent
            leido = n.leer(rid)
            entrada["ninox_leido"] = (leido or {}).get("fields")
            msg = n.subir(rid, adj_path, adj_nombre)
            entrada["subida"] = msg
            entrada["ficheros_en_ninox"] = n.ficheros(rid)
            entrada["accion"] = "creado"
            print(f"  {did} -> registro {rid} + adjunto OK  ({parsed['filename'][:36]})")
        except Exception as e:
            entrada["accion"] = "error"
            entrada["error"] = str(e)
            print(f"  {did} -> ERROR: {e}")
        registro.append(entrada)
        time.sleep(0.3)

    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    with open(LOG, "w", encoding="utf-8") as f:
        json.dump(registro, f, ensure_ascii=False, indent=2)
    print(f"\nlog -> {LOG}  ({len(registro)} documentos)")


if __name__ == "__main__":
    main()
