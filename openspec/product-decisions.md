# Registro de decisiones de producto — Paperdrop for Ninox

Este registro recoge las decisiones tomadas **durante la fase de especificación**
que divergen del funcional previamente aprobado.

**El funcional no se modifica.** `docs/Fase 2. Define/Paperdrop_Funcional_v1.0_EN.md`
es referencia aprobada y se trata como solo lectura. Este registro es la capa de
trazabilidad entre lo aprobado y lo decidido después.

---

## Decisiones de esta fase

La fase de especificación arranca el 2026-09-23. Toda decisión que se tome a
partir de aquí y que se aparte del funcional entra en esta tabla en el momento en
que se toma, no al cerrar la capability.

| ID | Decisión | Funcional afectado | Sección original | Capability afectada | Fecha | Tomada por |
|---|---|---|---|---|---|---|
| DEC-001 | **El identificador fiscal de una persona física que sostiene el ejemplo fundacional se sustituye por uno sintético.** El ejemplo de reparación por dígito de control —una lectura con un dígito donde va la letra, reparada a la única letra que el algoritmo admite— pasa a mostrarse con el valor sintético **`123456795 → 12345679S`**. El valor anterior **no se reproduce en ningún documento del proyecto**, ni aquí ni en el registro de gaps. El sintético no es arbitrario: `12345679` tiene letra de control `S` (15 mod 23), la `S` es justo el carácter que el OCR confunde con un `5`, y el algoritmo admite una única sustitución del carácter final. La propiedad pedagógica queda intacta y la sustitución es de la misma longitud, así que ningún documento reflowa. Aplicado en seis ficheros: los `.md` y también los tres `.docx` que llevaban el dato. | Anexo D.2; criterio de aceptación de FR-VAL-008; PDR §6.2 — **sin cambio de comportamiento** | Annex D.2, FR-VAL-005/FR-VAL-008, PDR §6.2 | `validation-confidence` (prevista) | 2026-09-23 | PO (decisión) |
| DEC-002 | **`docs/skills_proposed.md` y `docs/TWO_OPTIONS.MD` dejan de figurar como fuentes de verdad** en la jerarquía de `openspec/project.md` §2. Son notas de trabajo: propuestas de índices para el funcional y una lista de skills a evaluar, ya consumidas. Ningún requirement debe citarlas como origen. | `openspec/project.md` §2 | — | Transversal | 2026-09-23 | PO (edición directa del fichero) |
| DEC-003 | **La prohibición de exportar del §1.2 no alcanza al read-back del envío.** El §1.2 prohíbe "informes, conciliación o exportación de datos más allá del fichero de configuración", mientras que FR-SND-001 y BR-18 **exigen** releer el registro recién creado para mostrar en la confirmación lo que realmente se guardó. Las dos afirmaciones son normativas y de frente parecían contradictorias. Se resuelve así: la prohibición es sobre **funciones que el producto ofrece al usuario**, no sobre los pasos internos del pipeline de envío. Queda escrito como requirement con scenario propio (`no-user-facing-reporting-or-export`, escenario *read-back after a send is not an export*) y **no como comentario**, para que un lector posterior no pueda volver a leerlas como una contradicción. No cambia ningún comportamiento: confirma que BR-18 sigue vigente. | Funcional §1.2 · FR-SND-001 · BR-18 | §1.2, §4.7 | `product-invariants`, `ninox-send` | 2026-09-23 | PO |

> **Nota sobre DEC-001 y la regla de solo lectura del funcional.** Es la **única**
> modificación aplicada directamente sobre `docs/`, y no es una divergencia de
> comportamiento: es una **redacción de datos personales** en un documento que va
> a publicarse. La regla de solo lectura del funcional sigue vigente para todo lo
> demás, y una decisión que cambie comportamiento se registra aquí sin editar el
> documento.

---

## Decisiones cerradas antes de esta fase — no reabrir

Estas decisiones se tomaron durante Fase 1 y Fase 2 y **ya están incorporadas al
Funcional v1.0**. Se listan aquí porque el prompt de revisión las marca
explícitamente como cerradas, y porque cada una contradice a alguna fuente
anterior: un agente que lea solo el PDR o el informe del consultor las reabriría.

| ID | Decisión | Qué contradice | Dónde está en el funcional | Tomada por |
|---|---|---|---|---|
| PRE-001 | **"Ausente no es cero" se resuelve por el campo destino, no por el documento.** El ticket de datáfono (registro 1414) con IVA deducible `0,00` es **correcto**: la columna es *IVA deducible* y un ticket que no desglosa IVA no justifica deducir nada. El valor por defecto de la app es **vacío**; cada campo del mapeo tiene la opción *"si no consta, escribir 0"*. Ninguna de las dos se cablea. | El consultor y Opus lo habían calificado de error. El principio general "un valor desconocido no es un cero" se mantiene; lo que cambia es quién decide. | FR-VAL-012, FR-DST-006, BR-13 | PO |
| PRE-002 | **Derivar por identidad está permitido; inventar un tipo, no.** `base = total − IVA` es válido cuando ambos están impresos (caso `PRO1013-26`, donde el total 742,42 y el IVA 117,10 están impresos y la base correcta es la diferencia). `base = total ÷ 1,21` está prohibido. | La propuesta del consultor de "no derivar nunca" era demasiado estricta. | FR-EXT-008, BR-07 | PO |
| PRE-003 | **La tabla `YB` sí tiene campo de total: es un campo fórmula** (base + IVA), y por eso no aparece como escribible. Los campos fórmula **nunca** son destino del mapeo (escribir en ellos devuelve 500) y se usan como **contraste posterior a la escritura**. | El consultor afirmó que la tabla `YB` no tiene campo de total. Era falso. | FR-DST-004, FR-DST-005, BR-22 | PO |
| PRE-004 | **No se amplía el corpus de 16 documentos y no se reponderan las dos rutas de documento**, a pesar de que la prueba se inclinó hacia facturas B2B, justificantes bancarios y documentos no-EUR. El sesgo se compensa manteniendo las dos mitades del corpus de aceptación y sin que la primera ejecución asuma un ticket. | El supuesto del PDR de que las dos rutas pesan igual, contra la evidencia del corpus real. | §2.2, §10.1, FR-WIZ-008 | PO |
| PRE-005 | **Los registros 1413–1428 se quedan como están.** No se corrigen los importes dudosos ni las fechas que quedaron vacías. | La propuesta del consultor de corregir los cinco registros dudosos. | — (evidencia, no normativo) | PO |
| PRE-006 | **No se amplía el modelo canónico** con subtipo de documento ni con doble moneda. El registro 1428 (retirada de efectivo en el extranjero) salió como se esperaba. | La propuesta del consultor de añadir subtipo de documento y doble moneda. | §6.1 | PO |
| PRE-007 | **Mejor no escribir nada que escribir un número falso.** Un registro incompleto se corrige; un registro con un número inventado se cree. | — (ya es normativo en el funcional) | BR-03 | PO |
| PRE-008 | **Cada valor lleva su procedencia** (`read`, `derived`, `repaired`, `from_xml`) y **una comprobación en la que interviene un valor derivado no confirma nada.** En la prueba, 9 de los 16 registros que figuraban como "aritméticamente verificados" tenían base y cuota *derivadas* del total (`metodo_base: derived_from_gross`): la suma cuadra siempre porque es una tautología. Solo 1 de los 16 quedó confirmado de verdad (rotulado y cruzado). | La cifra "10 de 16 con aritmética verificada" del informe del consultor, que estaba vacía. | FR-EXT-011, FR-VAL-002, BR-02, BR-05 | PO |
