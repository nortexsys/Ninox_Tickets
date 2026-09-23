"""Rutas del proyecto. Un solo sitio donde se definen, para que mover la
carpeta no obligue a tocar cinco ficheros.

El corpus de entrada vive en el repositorio (docs/corpus). Si en algún momento
se mueve, solo hay que cambiar CORPUS aquí.
"""
from __future__ import annotations

import os

# corpus_test/  (la carpeta que contiene src/, out/, inbox/ y los informes)
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(BASE)

SRC = os.path.join(BASE, "src")
OUT = os.path.join(BASE, "out")
INBOX = os.path.join(BASE, "inbox")

TEXT_OUT = os.path.join(OUT, "text")
RENDER_OUT = os.path.join(OUT, "renders")
PARSED_OUT = os.path.join(OUT, "parsed")
ATTACH_OUT = os.path.join(OUT, "attachments")
LOG_NINOX = os.path.join(OUT, "ninox_log.json")

# documentos de entrada
CORPUS = os.path.join(REPO, "docs", "corpus")

# carpetas de salida que hay que crear antes de escribir
FOR_ALL = (TEXT_OUT, RENDER_OUT, PARSED_OUT, ATTACH_OUT)
