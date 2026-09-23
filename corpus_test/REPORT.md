# Prueba del corpus → inserción en Ninox

Fecha: 21/09/2026 · Destino: `TEST-DB-CLAUDE` (db0000000000), tabla **`YB` — Tarjetas Banco**
Trabajo realizado fuera del repositorio público, en `C:\Users\admin\proyectos\Paperdrop_ninox_test\`,
para no meter documentos con datos personales en `Ticket_reader_Ninox`.

## 1. Resultado

**15 documentos procesados, 15 registros creados en Ninox, 15 adjuntos subidos.** Verificado
leyendo cada registro de vuelta desde la API.

Los ficheros de `docs\corpus` eran 15, no 16: hay 6 PDF, 5 imágenes y 4 `.msg`. El `.msg` que
tu enunciado mencionaba como "un adjunto por email" resultó tener **2 adjuntos cada uno** (la
factura o foto, más la firma de correo `image001.png`). El pipeline elige el adjunto con
contenido real, no la firma.

| Registro | Fecha | Importe (base) | IVA deducible | Documento | Aritmética |
|---|---|---|---|---|---|
| 1413 | 2026-08-08 | 16,51 | 3,47 | WhatsApp 19.17.13 (Shop A) | correcta |
| 1414 | 2026-08-19 | 19,40 | 0,00 | WhatsApp 15.55.26 (Bank A) | **revisar** |
| 1415 | *(vacía)* | 26,00 | 0,00 | sc.jpg (Shop B Cuba) | **revisar** |
| 1416 | 2026-09-07 | 123.030,00 | 0,00 | FACTURA SUPPLIER_C (USD) | **revisar** |
| 1417 | *(vacía)* | 1.658,96 | 149,31 | ticket2.msg | correcta |
| 1418 | 2026-08-27 | 334,78 | 70,30 | WhatsApp 15.47.49 (Supplier D) | correcta |
| 1419 | 2026-08-21 | 512.307,69 | 153.692,31 | Invoice 21-0113 (SUPPLIER_E, USD) | correcta |
| 1420 | 2025-10-20 | 1,99 | 0,42 | Factura 018125603 (Bank B) | correcta |
| 1421 | 2026-04-20 | 10,95 | 2,30 | Sin título.msg (Cloud) | correcta |
| 1422 | 2025-09-17 | 6.709,24 | 0,00 | Invoice 91164408 (Supplier F) | correcta |
| 1423 | 2026-08-11 | 93,20 | 19,57 | WhatsApp 19.10.49 (Shop C) | correcta |
| 1424 | 2025-12-17 | 265,00 | 37,00 | FRA 632/2025 (transitario) | **revisar** |
| 1425 | 2026-07-16 | 45,54 | 9,56 | ticket.msg (Fuel station A) | correcta |
| 1426 | *(vacía)* | 0,00 | 0,00 | ti.msg (Client A, 0,00 € real) | correcta |
| 1427 | 2026-09-01 | 8.741,00 | 0,00 | PRO1013-26 (Supplier G) | **revisar** |

**9 de 15 con aritmética verificada. 5 marcados para revisión.**

## 2. Mapeo aplicado (según tu indicación)

| Campo Ninox | Origen |
|---|---|
| `Tipo` | siempre `Cargo puntual` |
| `Fecha` | fecha impresa; si no hay, la del nombre del fichero; si no, vacía |
| `Tarjeta Bancaria` | **NULL** |
| `Importe` | Base Imponible |
| `Importe IVA deducible` | cuota de IVA |
| adjunto | el documento, a nivel de registro |

**Discrepancia que debes conocer:** `YB` **no tiene campo de total**. El enunciado pedía
informar 6 campos, incluido "Importe total", pero el esquema real de la tabla tiene 9 campos y
ninguno es el total. Como elegiste `Importe = Base Imponible`, **el importe total del ticket no
se guarda en Ninox**. Está preservado en `out/ninox_log.json` (campo `total_documento`) y en
`out/parsed/*.json`, pero si lo quieres dentro de Ninox habría que crear un campo.

## 3. Cierre del punto abierto del ADR-004

El ADR-004 decía que la subida de adjuntos era *"la única regla no verificada"*. **Queda
verificada:**

- `POST /v1/teams/{team}/databases/{db}/tables/{table}/records/{id}/files`
  con `multipart/form-data`, campo `file` → **HTTP 200, "File Uploaded Successfully"**.
- `GET .../records/{id}/files` → 200, devuelve `name`, `size`, `contentType`.
- Ciclo completo probado con un registro desechable (crear → subir → leer → borrar), borrado
  después. Los 15 registros definitivos empiezan en **1413**.
- Límite de tamaño: no alcanzado; el mayor adjunto subido fue de ~146 KB.

## 4. Los 5 documentos que salieron mal (y por qué)

Esto es lo valioso de la prueba: son fallos **del parser**, no del OCR, y son los que la app
tiene que saber reconocer para pedir revisión.

1. **`PRO1013-26.pdf` → Importe 8.741,00 (incorrecto).** El PDF tiene capa de texto, pero
   PyMuPDF extrae rótulos y valores en **líneas separadas**. El parser no encontró el total
   etiquetado y cayó al último recurso, cogiendo un trozo de número de registro
   (`Tomo 8.741`). El importe real liquidado es **742,42**.
2. **`sc.jpg` → Importe 26,00 (incorrecto).** Ticket cubano (Shop B) sin ninguna etiqueta
   "TOTAL": el parser cogió el 26 de una fecha. El importe real no se localizó.
3. **`FACTURA de SUPPLIER_C…pdf` → Importe 123.030,00 (correcto como base, pero IVA 0).** Factura
   de EE. UU. en **USD**: no hay IVA español. El valor es correcto pero la moneda no se puede
   representar en `YB`.
4. **`FRA 632/2025` → aritmética incoherente.** El PDF imprime `TOTAL FACTURA 265,00 €` y
   `********265,00 €`; el IVA es 0 % (exportación exenta). El parser detectó candidatos
   contradictorios y lo marcó.
5. **`Bank A` (1414) → Importe 19,40 con IVA 0.** El ticket de datáfono **no imprime ni base
   ni IVA**, solo el total. Al no haber tipo de IVA impreso, no se pudo derivar el desglose.
   El 19,40 es correcto; lo que falta es el desglose.

Además, **3 documentos quedaron sin fecha** (1415, 1417, 1426). En 1417 y 1426 la fecha está
impresa pero el rótulo y el valor quedan en líneas separadas al extraer el texto.

## 5. Qué dice esto para Paperdrop (ADR-010 y ADR-011)

- **ADR-011 (librería PDF):** confirmado que hace falta extraer con **coordenadas**, no en
  texto plano. El fallo de PRO1013 y de las fechas de 1417/1426 viene de perder la relación
  entre un rótulo y el valor de la línea siguiente. `pdfplumber` con `extract_words()` (que da
  x/y de cada palabra) resolvería los tres sin cambiar de librería, pero **hay que medirlo**,
  como pide el ADR-011.
- **ADR-010 (motor OCR):** los tickets de papel dieron buenos resultados gracias a la capa de
  validación. Dos casos concretos donde el OCR fue incoherente entre pasadas y solo la
  aritmética rescató el valor: Shop A (leyó base 18,52; la correcta es 16,52/16,51) y
  Supplier D (el total se leyó 405,08 y el importe 485,48 en la misma pasada).
- **Regla que faltaba y conviene añadir a la tabla del §6.1 del PDR:** un ticket de datáfono
  **no imprime base ni IVA**. Sin tipo de IVA impreso, la derivación `bruto ÷ (1+tipo)` no
  puede aplicarse. La app debe marcar esos campos como `absent`, no como `derived`.

## 6. Estado del corpus

- **Faltan 16 ficheros** respecto al objetivo del PDR (§4.1): 5 de comercio, 5 de hostelería,
  5 de transporte/combustible y hasta 5 facturas recibidas. Aquí solo había 15 en total.
- **`sc.jpg` es de Cuba (Shop B)** y `ti.msg` es una factura de CLIENT_A: son documentos reales
  con datos personales, útiles pero **solo para corpus privado**.
- No se ha tocado ni copiado nada dentro de `Ticket_reader_Ninox`.

## 7. Aviso de privacidad que el prompt del corpus pedía anotar

El prompt (§2) advierte de datos personales en el repositorio público. **Confirmado y ampliado:**
`Ticket_reader_Ninox\out\INFORME.md` y `out\taxi_ticket.json` contienen el **nombre, el NIF, la
matrícula y la licencia de un conductor de taxi** —una persona física— además del **resto
enmascarado de una tarjeta**. No lo he modificado, como indicaba el prompt, y los valores
concretos no se reproducen aquí porque este informe se publica.

## 8. Artefactos

```
Paperdrop_ninox_test/
  src/
    extract_documents.py   etapa 1: cada fichero -> texto + metadatos (4 rutas del PDR)
    msg_extract.py         lector de .msg (OLE/MAPI) con extracción de adjuntos
    parse_common.py        importes, fechas, EAN-13, NIF/NIE/CIF, IBAN
    parse_documents.py     etapa 2: texto -> modelo canónico con estado por campo
    load_ninox.py          etapa 3: creación del registro + adjunto (con --dry-run)
    verify_ninox.py        lectura de vuelta y auditoría
  out/
    text/                  texto y todas las pasadas OCR, por documento
    parsed/                campo a campo con método y evidencia
    attachments/           adjuntos extraídos de los .msg
    ninox_log.json         qué se escribió, id de Ninox y validaciones
```

Reproducción: `python src/extract_documents.py` → `python src/parse_documents.py` →
`python src/load_ninox.py --dry-run` → `python src/load_ninox.py` → `python src/verify_ninox.py`

## 9. Añadido después: recibo de cajero del Bank C

Fichero: `WhatsApp Image 2026-09-21 at 17.10.11.jpeg` (99571 bytes, 1080x1920).
**Registro 1428** creado con su adjunto.

| Campo | Valor |
|---|---|
| Emisor | CREDIT DU MAROC |
| Fecha | 2026-08-31 (17:59:48) |
| Operación | RETRAIT D'ESPECES (retirada de efectivo) |
| Importe dispensado | 1.000,00 MAD |
| Tipo de cambio | 1 EUR = 10,3348 MAD |
| Mark-up DCC | 4,50 % |
| **Cargado en la tarjeta** | **96,76 EUR** |
| Tarjeta | ****5013 (nº de tarjeta, no enmascarado) |
| Autorización | 594764 |
| Comercio | GAB 210440038 |

Valores escritos en Ninox: `Fecha = 2026-08-31`, `Importe = 96,76`, `IVA deducible = 0`.

**Este documento encontró un fallo real del pipeline.** En la primera pasada el parser dio
`Importe = 9.676,00` con `IVA = 416,67` al 4,5 %. Dos causas:

1. **Lectura cruzada entre pasadas.** La pasada `psm11` leyó **`9676`** donde las otras tres
   leían **`96.76`**. El parser cogía el mayor entre todas las pasadas, así que el ruido de una
   sola pasada ganaba a la coincidencia de las otras tres.
2. **El mark-up DCC no es IVA.** `MARKE UP : 4,50 %` es la comisión de conversión de divisa de
   Global Blue, no un impuesto. El parser lo tomó como tipo de IVA y derivó base y cuota de ahí.

**Corregido** añadiendo la votación por rótulo entre pasadas —que es justo lo que el PDR pone
en el centro de su modelo de confianza (§6.1)— y la conciencia de moneda: un recibo en divisa
no lleva desglose de IVA español, así que `IVA deducible = 0` y el importe registrado es el
**realmente cargado en la tarjeta** (96,76 EUR), no el dispensado en efectivo (1.000 MAD).
La corrección **no introdujo regresiones**: los otros 15 documentos mantienen el mismo valor.

Consecuencia para el PDR: hay un **caso de documento que no está contemplado** en el modelo
canónico. Una retirada de efectivo en el extranjero con conversión DCC tiene dos importes
legítimos y distintos (moneda local y moneda de la tarjeta), y ninguno de los dos campos del
§5.1 (`net_total` / `gross_total`) los distingue. Haría falta, como mínimo, guardar por
separado importe en moneda del documento, importe cargado en la tarjeta, moneda y tipo de
cambio — o marcar el documento como `cash_withdrawal`, que no es un gasto deducible.

## 10. Lo que necesito de ti

1. **¿Corrijo los 5 registros dudosos?** Mi propuesta: dejar `Importe` e `IVA deducible`
   vacíos en 1415, 1416, 1424 y 1427, y completar la fecha en 1415, 1417 y 1426 leyéndola de
   las líneas adyacentes. Dime si prefieres que los deje como están para que los revises tú.
2. **¿Creamos el campo de total en `YB`?** Sin él, el importe realmente pagado no queda
   registrado en Ninox.
3. **¿Amplío el corpus?** Faltan los 16 documentos del objetivo del PDR, sobre todo
   hostelería y combustible en papel, que son justo donde la validación aporta.
4. **¿Cómo tratamos el 1428?** Es una retirada de efectivo, no una compra. Si `YB` es para
   cargos de tarjeta, el importe correcto es 96,76 EUR (lo cargado); si es para gastos
   deducibles, probablemente no debería estar ahí.
