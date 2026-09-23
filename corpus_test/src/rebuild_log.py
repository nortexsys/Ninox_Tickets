"""Rebuild the Ninox log by reading the created records back from the API.

Used after a single-document load, which rewrites the log with one entry.
"""
from __future__ import annotations

import json
import os

import requests

from config import BASE, OUT, TEXT_OUT, RENDER_OUT, PARSED_OUT, ATTACH_OUT, LOG_NINOX, CORPUS
TEAM = os.environ.get("NINOX_TEAM_ID", "qCq3JS7q7ptoap8Yg")
DB = "db0000000000"
BASE = f"https://api.ninox.com/v1/teams/{TEAM}/databases/{DB}/tables/YB"


def key():
    k = os.environ.get("NINOX_API_KEY")
    if k:
        return k
    import winreg
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as kk:
        return winreg.QueryValueEx(kk, "NINOX_API_KEY")[0]


def main():
    h = {"Authorization": f"Bearer {key()}"}
    filas = []
    for nombre in sorted(os.listdir(PARSED_OUT)):
        if not nombre.endswith(".json"):
            continue
        did = nombre[:-5]
        p = json.load(open(os.path.join(PARSED_OUT, nombre), encoding="utf-8"))
        filas.append({"doc_id": did, "parsed": p, "ninox_id": None})

    # The ids assigned by the corpus run, keyed explicitly: the alphabetical
    # order of the extraction stage is NOT the order in which Ninox assigned
    # ids, so this mapping must be stated rather than inferred.
    MAPA = {
        "D25eea658": 1413,   # WhatsApp 19.17.13  Shop A
        "D276edb12": 1414,   # WhatsApp 15.55.26  Bank A
        "D493486fc": 1415,   # sc.jpg             Shop B
        "D532b6722": 1416,   # SUPPLIER_C             (USD)
        "D5e12f790": 1417,   # ticket2.msg
        "D6d76839a": 1418,   # WhatsApp 15.47.49  Supplier D
        "D742d8b86": 1419,   # Invoice 21-0113    (USD)
        "D76be7d4b": 1420,   # Factura 018125603  Bank B
        "D82841a5c": 1421,   # Sin titulo.msg
        "D876a9e1e": 1422,   # Invoice 91164408   Supplier F
        "D9bf63262": 1423,   # WhatsApp 19.10.49  Shop C
        "Daab285a1": 1424,   # FRA 632/2025
        "Dc53bc0e8": 1425,   # ticket.msg
        "Dda18bcca": 1426,   # ti.msg             Client A 0,00
        "Ddf913bc4": 1427,   # PRO1013-26
        "D08323367": 1428,   # WhatsApp 17.10.11  Bank C (ATM)
    }

    for fila in filas:
        fila["ninox_id"] = MAPA.get(fila["doc_id"])

    registro = []
    for fila in filas:
        p = fila["parsed"]
        rid = fila["ninox_id"]
        r = requests.get(f"{BASE}/records/{rid}", headers=h, timeout=30)
        campos = r.json().get("fields", {}) if r.status_code == 200 else {}
        fs = requests.get(f"{BASE}/records/{rid}/files", headers=h, timeout=30)
        try:
            adjuntos = fs.json() if isinstance(fs.json(), list) else [fs.json()]
        except Exception:
            adjuntos = []
        registro.append({
            "doc_id": fila["doc_id"],
            "fichero": p["filename"],
            "documento_efectivo": p["filename_effective"],
            "ruta": p["route"],
            "fecha": campos.get("Fecha"),
            "base_imponible": campos.get("Importe"),
            "iva_deducible": campos.get("Importe IVA deducible"),
            "total_documento": p["fields"]["gross_total"],
            "iva_tipo": p["fields"]["tax_rate"],
            "moneda": p["fields"]["currency"],
            "proveedor": p["fields"]["supplier_name"],
            "aritmetica_cuadra": p["checks"]["arithmetic_reconciles"],
            "conflicto": p["checks"]["conflict"],
            "metodo_base": p["field_status"]["net_total"],
            "metodo_iva": p["field_status"]["tax_total"],
            "ninox_id": rid,
            "adjuntos": [a.get("name") for a in adjuntos],
            "accion": "creado",
        })

    destino = LOG_NINOX
    with open(destino, "w", encoding="utf-8") as f:
        json.dump(registro, f, ensure_ascii=False, indent=2)
    print(f"log reconstruido: {len(registro)} registros -> {destino}")


if __name__ == "__main__":
    main()
