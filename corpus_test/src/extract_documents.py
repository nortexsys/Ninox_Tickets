"""Stage 1 - extraction: every corpus file becomes text + metadata.

Routes (per the PDR):
  photo      image file                        -> multi-pass OCR
  pdf_scan   PDF with no text layer            -> render at 300dpi + OCR
  pdf_text   PDF carrying a text layer         -> direct text extraction
  email      .msg container                    -> MAPI body + attachment, recursively

Produces one JSON per document under out/text/<doc_id>.json, with all OCR
passes kept so later stages can vote between them.
"""
from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys

import fitz  # PyMuPDF

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from config import (BASE, OUT, TEXT_OUT, RENDER_OUT, PARSED_OUT, ATTACH_OUT,
                    LOG_NINOX, CORPUS)

TESS = "tesseract"


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def tesseract(img_path, psm=6, lang="spa"):
    try:
        r = subprocess.run([TESS, img_path, "stdout", "-l", lang, "--psm", str(psm)],
                           capture_output=True, text=True, encoding="utf-8",
                           errors="replace", timeout=600)
        return (r.stdout or "").strip()
    except Exception as e:
        return f"[tesseract error: {e}]"


def pdf_has_text(path, min_chars=200):
    doc = fitz.open(path)
    total = 0
    for page in doc:
        total += len(page.get_text("text").strip())
        if total >= min_chars:
            doc.close()
            return True
    doc.close()
    return False


def pdf_text(path):
    doc = fitz.open(path)
    parts = []
    for i, page in enumerate(doc):
        parts.append(f"----- page {i+1} -----")
        parts.append(page.get_text("text"))
    doc.close()
    return "\n".join(parts)


def pdf_render_pages(path, doc_id, dpi=300):
    """Render every page to PNG; returns the list of paths."""
    doc = fitz.open(path)
    out = []
    for i, page in enumerate(doc):
        pix = page.get_pixmap(dpi=dpi)
        p = os.path.join(RENDER_OUT, f"{doc_id}_p{i+1}.png")
        pix.save(p)
        out.append(p)
    doc.close()
    return out


def extract_image(path, doc_id):
    """Multi-pass OCR of a photographed receipt."""
    passes = {}
    for psm in (4, 6, 11):
        passes[f"psm{psm}"] = tesseract(path, psm=psm, lang="spa")
    # a second language pack sometimes helps with mixed receipts
    passes["psm6_eng"] = tesseract(path, psm=6, lang="spa+eng")
    return passes, [path]


def process_pdf(path, doc_id):
    if pdf_has_text(path):
        return {"pdf_text": pdf_text(path)}, [], "pdf_text"
    pages = pdf_render_pages(path, doc_id)
    passes = {}
    for i, p in enumerate(pages):
        passes[f"page{i+1}_psm6"] = tesseract(p, psm=6, lang="spa")
        passes[f"page{i+1}_psm4"] = tesseract(p, psm=4, lang="spa")
    return passes, pages, "pdf_scan"


def main():
    os.makedirs(TEXT_OUT, exist_ok=True)
    os.makedirs(RENDER_OUT, exist_ok=True)

    sys.path.insert(0, os.path.join(BASE, "src"))
    from msg_extract import extract_msg

    docs = []
    archivos = sorted(os.listdir(CORPUS))
    for nombre in archivos:
        ruta = os.path.join(CORPUS, nombre)
        if not os.path.isfile(ruta):
            continue
        ext = os.path.splitext(nombre)[1].lower()
        if ext not in (".jpeg", ".jpg", ".png", ".pdf", ".msg"):
            continue

        doc_id = "D" + hashlib.sha1(nombre.encode("utf-8")).hexdigest()[:8]
        print(f"\n=== {nombre}  [{doc_id}] ===")

        if ext == ".msg":
            info = extract_msg(ruta, doc_id, ATTACH_OUT)
            entrada = {
                "doc_id": doc_id, "filename": nombre, "path": ruta,
                "sha256": sha256(ruta), "kind": "email",
                "email": {
                    "subject": info["subject"],
                    "sender": info["sender"],
                    "date": info["date"],
                },
                "attachments": info["attachments"],
                "passes": {},
            }
            # el adjunto se procesa como documento propio si es imagen o pdf
            for att in info["attachments"]:
                ap = att["extracted_path"]
                aext = os.path.splitext(ap)[1].lower()
                if aext in (".jpeg", ".jpg", ".png"):
                    p, pages = extract_image(ap, doc_id)
                    att["passes"] = p
                    att["route"] = "photo"
                elif aext == ".pdf":
                    if pdf_has_text(ap):
                        att["passes"] = {"pdf_text": pdf_text(ap)}
                        att["route"] = "pdf_text"
                    else:
                        pg = pdf_render_pages(ap, doc_id + "_att")
                        p = {}
                        for i, x in enumerate(pg):
                            p[f"page{i+1}_psm6"] = tesseract(x, 6)
                        att["passes"] = p
                        att["route"] = "pdf_scan"
                    att["pages"] = pages_of_pdf(ap)
            print(f"  asunto: {info['subject']!r}  adjuntos: {len(info['attachments'])}")

        elif ext == ".pdf":
            passes, pages, route = process_pdf(ruta, doc_id)
            entrada = {
                "doc_id": doc_id, "filename": nombre, "path": ruta,
                "sha256": sha256(ruta), "kind": route,
                "passes": passes, "pages": pages_of_pdf(ruta),
            }
            print(f"  ruta: {route}  paginas: {entrada['pages']}  pasadas: {len(passes)}")

        else:
            passes, pages = extract_image(ruta, doc_id)
            entrada = {
                "doc_id": doc_id, "filename": nombre, "path": ruta,
                "sha256": sha256(ruta), "kind": "photo",
                "passes": passes, "pages": 1,
            }
            print(f"  ruta: photo  pasadas: {len(passes)}")

        with open(os.path.join(TEXT_OUT, f"{doc_id}.json"), "w", encoding="utf-8") as f:
            json.dump(entrada, f, ensure_ascii=False, indent=2)
        docs.append({"doc_id": doc_id, "filename": nombre, "kind": entrada["kind"]})

    with open(os.path.join(OUT, "docs_index.json"), "w", encoding="utf-8") as f:
        json.dump(docs, f, ensure_ascii=False, indent=2)
    print(f"\n{len(docs)} documentos procesados -> {TEXT_OUT}")


def pages_of_pdf(path):
    doc = fitz.open(path)
    n = len(doc)
    doc.close()
    return n


if __name__ == "__main__":
    main()
