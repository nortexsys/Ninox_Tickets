# REPORT-CORPUS — Conclusiones de la prueba de lectura e inserción en Ninox

**Proyecto:** Paperdrop for Ninox (Nortex Systems)
**Fecha:** 21 de septiembre de 2026
**Alcance:** prueba de lectura de documentos, validación determinista e inserción en Ninox
**Estado:** 16 documentos procesados; informe de conclusiones y recomendaciones

---

## 1. Objetivo y qué se probó

El objetivo era verificar de extremo a extremo la hipótesis central de Paperdrop: que un
documento puede leerse en el dispositivo y volcarse como registro en Ninox con la lectura
**validada por restricciones deterministas** en lugar de confiada a la calidad del
reconocimiento.

La prueba cubrió la cadena completa: extracción → votación entre lecturas → validación
aritmética → creación del registro → subida del adjunto → lectura de vuelta.

| Qué | Resultado |
|---|---|
| Documentos procesados | 16 (15 del corpus + 1 añadido después) |
| Registros creados en Ninox | **16** (ids 1413–1428) |
| Adjuntos subidos | **16 de 16** |
| Lecturas con aritmética verificada | 10 de 16 |
| Punto abierto del ADR-004 (subida de adjuntos) | **cerrado y verificado** |

---

## 2. Composición real del corpus

Conviene saber qué se probó de verdad, porque no coincide con lo previsto:

| Ruta del PDR | Documentos | Observación |
|---|---|---|
| `photo` (foto de papel) | 5 | tickets térmicos, tickets de datáfono, gasolinera |
| `pdf_text` (PDF con capa de texto) | 6 | facturas de proveedor, varias divisas |
| `email` (contenedor `.msg`) | 4 | cada uno con 2 adjuntos: el documento real y la firma de correo |
| `pdf_scan` (PDF escaneado) | **0** | **la ruta no quedó cubierta ni una sola vez** |
| `einvoice` (XML ZUGFeRD / XRechnung) | **0** | fuera del alcance de esta prueba |

Dos hechos que condicionan todas las conclusiones:

1. **No hay ni un solo PDF escaneado.** La ruta `pdf_scan` del PDR (§4.1) es justamente la
   que combina render más OCR, y no se ha ejercitado. El corpus no permite afirmar nada sobre
   ella.
2. **Los `.msg` no contienen un adjunto, sino dos.** El segundo es la firma del remitente
   (`image001.png`). El pipeline elige el de contenido real, pero es un caso que la app deberá
   resolver en la bandeja de entrada de correo.

---

## 3. Lo que funcionó

**La validación determinista hace su trabajo donde hay una restricción matemática que aplicar.**
Casos concretos y verificados:

| Constraint | Documento | Qué resolvió |
|---|---|---|
| Dígito de control EAN-13 | Ticket de comercio | Confirmó `8435430627640` y descartó el candidato rival que el OCR leyó con la misma verosimilitud aparente |
| Dígito de control de NIF | Recibo de taxi | El OCR leyó `123456795`; con 8 dígitos la letra de control es `S`, que es justo el carácter confundido con un `5`. Se recuperó el NIF correcto desde una lectura errónea |
| Aritmética de importes | Ticket de comercio | Confirmó el desglose base/cuota/total frente a una lectura de total incorrecta |
| Formato de matrícula | Recibo de taxi | La matrícula del recibo cumple el patrón español moderno (4 dígitos + 3 consonantes sin vocales ni Q/Ñ) |
| Coherencia temporal | Recibo de taxi | 12,6 km en 21 minutos = 36 km/h, plausible en urbano; si los datos estuvieran mal leídos el resultado sería absurdo |

**La subida de adjuntos funciona y el contrato del ADR-004 queda verificado.** No era una
suposición: se probó el ciclo completo con un registro desechable (crear → subir → leer →
borrar), todo HTTP 200, y después se repitió 16 veces. El endpoint es
`POST /v1/teams/{team}/databases/{db}/tables/{table}/records/{id}/files` con
`multipart/form-data`, y `GET .../records/{id}/files` devuelve nombre, tamaño y tipo.

**La lectura de vuelta es útil, no un trámite.** Confirma que lo escrito es lo almacenado, y
detecta cuándo Ninox sobrescribe lo enviado.

**La ruta `pdf_text` es la más fiable del corpus**, como anticipaba el PDR: texto limpio, sin
OCR y sin ambigüedad de caracteres.

---

## 4. Los fallos: seis síntomas, una sola causa

Esta es la conclusión principal de la prueba. Los errores encontrados en revisión no son seis
fallos independientes: son **la misma causa repetida seis veces**.

> **El parser escribió números inventados, y la capa de validación no podía detectarlo porque
> el error estaba en la premisa, no en la aritmética.**

El caso más claro: una factura en USD produjo una base de 512.307,69 y una cuota de
153.692,31 con IVA al 30 %. La aritmética **cuadraba consigo misma** —base + cuota = total,
base × 30 % = cuota— así que ninguna restricción podía objetarla. El error no era el cálculo:
era que el tipo de IVA se había inventado y que la moneda no era la de la tabla.

Y otros dos ejemplos del mismo patrón:

- Un ticket de comercio produjo base 16,51 partiendo de una lectura ruidosa del total (19,98)
  cuando el total real es 19,99. La división `19,98 / 1,21 = 16,51` es exacta, y por eso pasó
  la validación. **Una validación sobre datos equivocados no valida nada.**
- Un recibo de cajero en dirhams produjo un importe de 9.676,00 al tomar la lectura inflada de
  una sola pasada de OCR (`9676` donde las otras tres leían `96.76`) y al interpretar el
  mark-up de conversión de divisa del 4,5 % como si fuera un tipo de IVA.

### 4.1 Clasificación por causa raíz

| Causa raíz | Documentos afectados | Qué falló |
|---|---|---|
| **Consenso entre pasadas** | 2 | Se tomó el mayor valor entre todas las pasadas OCR, así que el ruido de una sola ganaba a la coincidencia de las otras tres. Debería ganar el consenso |
| **Inventar lo que no está impreso** | 2 | Se derivó un tipo de IVA que el documento no declara (una factura sin IVA, una comisión de cambio de divisa) |
| **Falta de conciencia de moneda** | 2 | Importes en USD o MAD tratados como euros, y comparados contra el importe cargado en la tarjeta |
| **Pérdida de la relación rótulo–valor** | 2 | Con capa de texto, el rótulo y su importe quedan en líneas separadas; el valor se perdió o se tomó otro |
| **Fecha derivada del nombre del fichero** | 1 | Se inventó una fecha cuando el documento no la tenía localizable |
| **Modelo de un solo tipo de IVA** | 1 | Un ticket con dos tipos y dos bases quedó colapsado en un único par |

### 4.2 Comparación con lo que el PDR ya anticipaba

El PDR acierta en su diagnóstico general y hay que reconocerlo:

- **§5.3 «Multiple tax rates»** describe exactamente el fallo del ticket con dos IVAS:
  *«un único tax_rate no puede representarlo, y agregar las cifras destruye exactamente el
  desglose que el asesor necesita»*. La prueba confirma que ocurre en la práctica, y que el
  modelo de slots es necesario, no un lujo.
- **§6.2 «An expectation to set honestly»** avisa de que el número de documento no puede
  confirmarse nunca, y así fue: cada pasada produjo una variante distinta.
- **§6.1** enumera la aritmética de importes como la constraint principal. Funciona, pero
  **solo si los operandos son correctos**: la prueba demuestra que hace falta un paso previo de
  consenso entre lecturas que el documento no describe con suficiente peso.

Lo que el PDR **no** contempla y la prueba ha revelado:

| Hueco | Detalle |
|---|---|
| Retirada de efectivo con conversión de divisa | El recibo tiene dos importes legítimos y distintos (moneda local y moneda cargada en la tarjeta). Ninguno de los campos del §5.1 los distingue |
| Ticket de datáfono | No imprime base ni IVA. Sin tipo impreso, `bruto ÷ (1+tipo)` no puede aplicarse |
| Mark-up DCC | Una comisión de conversión con formato `4,50 %` parece un tipo de IVA y no lo es |
| Propinas, descuentos y redondeos | No tienen campo en el modelo canónico del §5.1 |

---

## 5. Recomendaciones

### 5.1 Sobre el orden de las validaciones (crítico)

La lección más importante de la prueba: **validar no es suficiente; hay que validar la
premisa antes que el cálculo.** Se propone invertir el orden actual:

1. **Consenso entre pasadas, primero.** Un valor en el que coinciden tres de cuatro lecturas
   vale más que el máximo de todas. Un outlier aislado debe perder siempre.
2. **Solo después, la aritmética.** Y solo sobre operandos que hayan pasado el paso 1.
3. **Nunca derivar un dato que el documento no declara.** Si no hay tipo de IVA impreso, no
   hay desglose: los campos quedan vacíos. **Un campo vacío es información; un campo inventado
   es un error que viaja hasta la contabilidad.**

### 5.2 Reglas de escritura («policy de vacío»)

Cuando la app no pueda sostener un valor, la conducta por defecto debe ser **no escribir**:

| Situación | Conducta |
|---|---|
| La moneda del documento no es la de la tabla destino | No escribir importe. Un número en la divisa equivocada es peor que un hueco |
| El IVA impreso contradice la aritmética | Escribir lo impreso y marcar revisión; **jamás corregirlo** |
| No hay total etiquetado y los candidatos discrepan mucho | No escribir |
| El documento no imprime base ni IVA | Escribir solo el total disponible, con los otros dos vacíos |
| Fecha no localizable en el documento | Dejar vacío. **No derivarla del nombre del fichero** |

El principio que subyace: **un registro incompleto se corrige; un registro con un número falso
se cree.**

### 5.3 Sobre la arquitectura de lectura (ADR-010 y ADR-011)

- **ADR-011:** la prueba confirma que **extraer texto plano de un PDF no basta**. Hay que
  extraer con **coordenadas** para reconstruir qué valor pertenece a qué rótulo. El fallo de la
  factura que cayó al último recurso viene de ahí. Se propone `pdfplumber` con `extract_words()`
  —que ya da x/y por palabra— y **medirlo**, como pide el propio ADR.
- **ADR-010:** sigue abierto y esta prueba **no puede cerrarlo**: no hay ni un PDF escaneado en
  el corpus y la ruta de foto se probó con 5 documentos, muy por debajo de los ~15 que el PDR
  exige para que la cifra sea defendible. Lo que sí aporta la prueba es que **la capa de
  validación rescata lecturas malas**, que es exactamente el argumento del §13 del PDR: *«un
  motor que lee peor puede empatar en campos validados»*.
- **Preprocesado:** el ADR-006 lo delega en el escáner del sistema operativo. La prueba lo
  respalda: donde el OCR falló no fue por falta de preprocesado, sino por **votos y validación**.

### 5.4 Sobre el modelo canónico

Ampliar el §5.2 del PDR con:

- `gross_total_document_currency` y `gross_total_card_currency`, más `exchange_rate`, para
  retiradas en el extranjero con conversión.
- `doc_subtype`: `purchase`, `cash_withdrawal`, `fuel`, `toll`, `parking`, `restaurant`… Un
  retirada de efectivo no es un gasto deducible y no debería tratarse igual.
- `surcharges` con su etiqueta (`dcc_markup`, `service`, `tip`), para que una comisión no se
  confunda con un impuesto.
- Confirmar los tripletes de IVA del §5.3 en la implementación: la prueba demuestra que hacen
  falta de verdad.

---

## 6. Sobre el corpus

**El corpus actual no alcanza para cerrar ADR-010.** El PDR fija ~15 documentos fotografiados
como umbral de cribado, y aquí hay 5. Con esa muestra un solo error mueve el resultado ~7
puntos, tal como advierte el §13.

Casillas que quedan vacías y que conviene cubrir antes de decidir el motor:

| Casilla | Estado | Por qué importa |
|---|---|---|
| `pdf_scan` | **vacía** | Es una de las cuatro rutas del PDR y no se ha probado |
| Hostelería en papel | vacía | Degradación térmica típica; el caso donde el OCR sufre |
| Combustible en papel | 2 | Es donde aparecieron las lecturas cruzadas más graves |
| Varios tipos de IVA | 1 | Un solo caso; el §5.3 necesita más |
| Inversión del sujeto pasivo | 1 | Factura intracomunitaria al 0 % |
| Redondeo suizo | vacía | Mercado DACH, que es el principal |
| Divisa distinta de EUR | 3 | USD y MAD; demostró ser una fuente de error grave |

**Recomendación:** no fabricar documentos para llenar casillas, como pide el prompt del corpus.
Pedirlos, y mientras tanto tratar la cifra de precisión como lo que es: **un filtro, no una
medición**.

---

## 7. Sobre privacidad

La prueba manejó documentos con datos personales reales y conviene dejar constancia:

- **Datos de personas físicas:** el recibo de taxi contiene nombre, NIF, matrícula y licencia
  de un conductor. Un recibo de datáfono contiene el número de tarjeta **completo y sin
  enmascarar**.
- **Datos de personas jurídicas:** dos facturas reales con NIF y firmas de correo de sus
  emisores.
- **Rutas del equipo:** los JSON de texto contienen rutas absolutas del sistema.

**Medidas adoptadas:** todo el material de prueba vive en `corpus_test/`, con `.gitignore` en
dos niveles que bloquea `out/`, `inbox/`, `docs/corpus/` y el fichero `.env` (que contiene una
API key en claro). Verificado con `git check-ignore`: **38 ficheros publicables, todos código y
documentos de trabajo**; ninguna factura, NIF, tarjeta ni credencial.

**Pendiente de decisión del propietario:** el repositorio git es privado hoy, por lo que el
riesgo es bajo; pero la protección depende de que se mantenga así. Si se publica, la
separación ya está hecha. Queda por decidir si el `INFORME.md` del prototipo (que menciona el
nombre del conductor) debe publicarse en una versión anonimizada.

---

## 8. Estado de los puntos abiertos del ADR

| Ref | Punto | Estado tras la prueba |
|---|---|---|
| ADR-004 | Subida de adjuntos en Ninox | **Cerrado.** Verificado con ciclo completo y 16 subidas reales |
| ADR-010 | Motor OCR para la ruta de foto | **Sigue abierto.** La prueba aporta evidencia pero no cierra: faltan documentos y falta `pdf_scan` |
| ADR-011 | Librería de extracción de PDF | **Parcialmente confirmado.** Se confirma que hace falta extracción con coordenadas; queda elegir librería y medirla |
| — | Umbrales de aceptación | **Sin fijar.** Siguen dependiendo del cribado, como preveía el PDR |

---

## 9. Conclusión

La hipótesis del producto **se sostiene**: la validación determinista recuperó lecturas que el
reconocimiento había estropeado —un NIF reconstruido desde un dígito mal leído, un código de
barras desambiguado por su dígito de control— y la cadena completa hasta Ninox funciona, con el
adjunto incluido.

Pero la prueba también pone una condición que el diseño actual no cumple del todo:

> **La validación determinista no protege contra una premisa falsa.** Puede confirmar con
> total solvencia matemática un desglose construido sobre un tipo de IVA inventado. La
> consecuencia práctica es que la app debe **abstenerse** con más frecuencia de la que hoy
> tiene prevista, y que el paso de consenso entre lecturas tiene que ir **antes** de la
> aritmética, no después.

Un registro con un campo vacío cuesta cinco segundos de revisión. Un registro con un importe
inventado cuesta una corrección contable. La prueba ha demostrado que el segundo caso es
perfectamente posible sin que ninguna validación se queje, y arreglar eso es más urgente que
mejorar la precisión del OCR.

---

### Anexo — Artefactos de la prueba

Todo en `corpus_test/`, con el pipeline reproducible:

| Fichero | Contenido |
|---|---|
| `src/extract_documents.py` | Etapa 1: cada fichero → texto y metadatos, según las cuatro rutas del PDR |
| `src/msg_extract.py` | Lector de `.msg` (OLE/MAPI) con extracción de adjuntos |
| `src/parse_common.py` | Importes, fechas, EAN-13, NIF/NIE/CIF, IBAN |
| `src/parse_documents.py` | Etapa 2: texto → modelo canónico con estado y evidencia por campo |
| `src/load_ninox.py` | Etapa 3: creación del registro y adjunto, con `--dry-run` |
| `src/verify_ninox.py` | Lectura de vuelta y auditoría |
| `src/config.py` | Rutas en un solo sitio |
| `out/parsed/` | Campo a campo, con el método y la evidencia de cada valor |
| `out/ninox_log.json` | Qué se escribió, con id de Ninox y validaciones |

Reproducción: `extract_documents.py` → `parse_documents.py` → `load_ninox.py --dry-run` →
`load_ninox.py` → `verify_ninox.py`

*Fin del informe.*
