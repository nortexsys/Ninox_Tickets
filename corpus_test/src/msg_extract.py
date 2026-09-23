"""Outlook .msg reader (CFB/OLE container) used by the extraction stage.

Returns the message header plus every attachment it carries, each attachment
written to disk so the rest of the pipeline can treat it as a document.
"""
from __future__ import annotations

import os
import re

import olefile

# MAPI property ids we care about
P_SUBJECT = "0037"
P_SENDER_NAME = "0C1A"
P_SENDER_EMAIL = "0C1F"
P_SUBMIT_TIME = "0039"
P_BODY = "1000"
P_ATTACH_LONGNAME = "3707"
P_ATTACH_NAME = "3704"
P_ATTACH_DATA = "3701"


def _decode_stream(ole, stream):
    try:
        data = ole.openstream(stream).read()
    except Exception:
        return None
    unicode_stream = stream[-1].endswith("001F")
    try:
        txt = data.decode("utf-16-le" if unicode_stream else "cp1252", "replace")
    except Exception:
        return None
    return txt.replace("\x00", "").strip()


def _prop_of(ole, tag):
    for stream in ole.listdir():
        if len(stream) >= 2 and stream[-1] == f"__substg1.0_{tag}001F":
            v = _decode_stream(ole, stream)
            if v:
                return v
    for stream in ole.listdir():
        if len(stream) >= 2 and stream[-1] == f"__substg1.0_{tag}001E":
            v = _decode_stream(ole, stream)
            if v:
                return v
    return None


def extract_msg(path: str, doc_id: str, out_dir: str):
    """Read a .msg; write its attachments to out_dir; return the metadata."""
    os.makedirs(out_dir, exist_ok=True)
    ole = olefile.OleFileIO(path)

    subject = _prop_of(ole, P_SUBJECT)
    sender = _prop_of(ole, P_SENDER_EMAIL) or _prop_of(ole, P_SENDER_NAME)
    fecha = _prop_of(ole, P_SUBMIT_TIME)
    body = _prop_of(ole, P_BODY) or ""
    body = re.sub(r"\n{3,}", "\n\n", body).strip()

    # attachments: collect declared names and their binary payloads
    nombres = {}
    for stream in ole.listdir():
        carpeta = stream[0]
        if not carpeta.startswith("__attach"):
            continue
        if len(stream) >= 2 and stream[-1].endswith("__substg1.0_3707001F"):
            n = _decode_stream(ole, stream)
            if n:
                nombres[carpeta] = n
        elif len(stream) >= 2 and stream[-1].endswith("__substg1.0_3704001F"):
            n = _decode_stream(ole, stream)
            if n and carpeta not in nombres:
                nombres[carpeta] = n

    adjuntos = []
    for stream in ole.listdir():
        carpeta = stream[0]
        if not carpeta.startswith("__attach"):
            continue
        if not (len(stream) >= 2 and stream[-1] == "__substg1.0_37010102"):
            continue
        try:
            data = ole.openstream(stream).read()
        except Exception:
            continue
        ext = None
        if data.startswith(b"%PDF"):
            ext = ".pdf"
        elif data.startswith(b"\xff\xd8\xff"):
            ext = ".jpg"
        elif data.startswith(b"\x89PNG"):
            ext = ".png"
        if ext is None:
            continue
        nombre = nombres.get(carpeta) or f"adjunto{len(adjuntos)+1}{ext}"
        limpio = re.sub(r'[<>:"/\\|?*]', "_", nombre)
        destino = os.path.join(out_dir, f"{doc_id}__{limpio}")
        with open(destino, "wb") as f:
            f.write(data)
        adjuntos.append({
            "declared_name": nombre,
            "extracted_path": destino,
            "size": len(data),
        })

    ole.close()
    return {
        "subject": subject,
        "sender": sender,
        "date": fecha,
        "body": body,
        "attachments": adjuntos,
    }


if __name__ == "__main__":
    import json
    import sys
    r = extract_msg(sys.argv[1], "TEST", sys.argv[2] if len(sys.argv) > 2 else "out/attachments")
    print(json.dumps({k: v for k, v in r.items() if k != "body"}, ensure_ascii=False, indent=2))
