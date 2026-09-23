"""Verify what actually landed in Ninox: read back every created record."""
from __future__ import annotations

import json
import os
import sys

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
    log = json.load(open(LOG_NINOX, encoding="utf-8"))

    print(f"{'id':>6}  {'Fecha':11s} {'Importe':>12s} {'IVA ded.':>9s}  "
          f"{'Tipo':14s} {'fich':>4s}  documento")
    print("-" * 110)

    ok, avisos = 0, []
    for e in log:
        rid = e.get("ninox_id")
        if not rid:
            avisos.append((e["doc_id"], "no se creo registro"))
            continue
        f = requests.get(f"{BASE}/records/{rid}", headers=h, timeout=30).json().get("fields", {})
        fs = requests.get(f"{BASE}/records/{rid}/files", headers=h, timeout=30)
        try:
            nfiles = len(fs.json()) if isinstance(fs.json(), list) else 1
        except Exception:
            nfiles = 0

        fecha = f.get("Fecha")
        imp = f.get("Importe")
        iva = f.get("Importe IVA deducible")
        print(f"{rid:>6}  {str(fecha):11s} {str(imp):>12s} {str(iva):>9s}  "
              f"{str(f.get('Tipo')):14s} {nfiles:>4}  {e['fichero'][:44]}")

        if nfiles < 1:
            avisos.append((e["doc_id"], "sin adjunto"))
        if not fecha:
            avisos.append((e["doc_id"], "sin fecha"))
        if imp in (None, 0):
            avisos.append((e["doc_id"], "importe vacio o cero"))
        if not e.get("aritmetica_cuadra"):
            avisos.append((e["doc_id"], "aritmetica no verificada en el documento"))
        ok += 1

    print()
    print(f"registros verificados en Ninox: {ok}")
    print(f"avisos ({len(avisos)}):")
    for d, m in avisos:
        print(f"   {d}  {m}")


if __name__ == "__main__":
    main()
