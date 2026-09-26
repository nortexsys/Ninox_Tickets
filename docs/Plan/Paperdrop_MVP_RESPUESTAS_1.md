# Paperdrop — Planificación del MVP: comentarios del PO


## 3. El hallazgo: la API no marca los campos fórmula (propuesta de GAP-022, bloqueante)

Los campos fórmula no deben mapearse ni aparecer en la app. Estos campos no admiten en Ninox nigún tipo de modificación por lo que mostrarlos es crear ruido innecesario.

## 4. Los gaps, uno a uno: qué significan y qué te propongo


### Abiertos que afectan al MVP

Todos los gaps aprobados de acuerdo a tus recomendaciones, salvo los especificados abajo:
| Gap | En palabras llanas | Implicación | Propuesta |
| --- | --- | --- | --- 

| **GAP-012** — `NINOX_DB_ID` apunta a producción | La variable de entorno de tu Windows apunta a la base de **producción de CLIENT_A**. | A la app no le afecta, porque nunca lee variables de entorno. Sí afecta a los tests y a los agentes de desarrollo. | Los tests usan siempre ids explícitos. **Además te recomiendo renombrar la variable** (p. ej. `NINOX_DB_ID_CLIENT_A_PROD`) para que ninguna herramienta la coja por defecto. |

En este caso habrá que instruir bien a los agentes, no se va a cambiar una variable actual.

| **GAP-011** — nombre "Paperdrop" | No se ha comprobado en las tiendas ni en la EUIPO. | Parece de FASE 3, pero **no lo es**: el identificador de la app en Android (`applicationId`) es permanente una vez publicado y se elige en M0. | Comprobarlo en la semana 1. |
Verificado no existe. En cualquier caso debemos añadir Ninox al nombre, tal como Paperdrop for Ninnox

### Abiertos que no afectan al MVP (van a R1/R2)

| Gap | En palabras llanas | Cuándo |
| --- | --- | --- |
| **GAP-006** — Ninox en nube privada | Clientes con Ninox en su propio servidor. El campo "host" está en el MVP, pero nadie lo ha probado contra una instancia privada real. | Cuando aparezca el primer cliente con nube privada. |
Esto no lo vamos a poder probar. Ya con la aplicación que tenga un MVP se podrá pedir ayuda a la comunidad.
| **GAP-018** — qué es un documento "confirmado" para la memoria de proveedores | ¿Se aprende un nombre de proveedor si el usuario guardó sin tocarlo, aunque la app lo leyera mal? | R1. Mi inclinación: un nombre que **el usuario escribió o corrigió** se aprende siempre; uno que no tocó no se aprende. Lo decidimos antes de R1. |
Correcto
| **GAP-021** — dónde vive el tamaño de la app | Solo organización documental. | Propongo cerrarlo tal como está (en `local-config-privacy`). |
Correcto
---
## 6. Decisiones que necesito de ti

| ID | Decisión | Mi recomendación | Cuándo |
| --- | --- | --- | --- |
| D-1 | Alcance del MVP (plan §2 y §4) | Aprobar | Semana 1 |**OK**
| D-2 | ¿Ruta de foto en el MVP o al principio de R1? | Dentro. Si el calendario aprieta, es el único bloque que puede pasar a R1 sin rehacer nada | Semana 1 |**ok**
| D-3 | GAP-022 | Opción A | Semana 1 |**YA COMENTADO AL PRINCIPIO**
| D-4 | ADR-010 | ML Kit detrás de interfaz, confirmado por medición | M3 |**OK**
| D-5 | ADR-011 | Evaluar PdfBox-Android y la alternativa PDFium | M3 |**OK**
| D-6 | GAP-019 | Mantener el bloque como lo dejó la comprobación y marcar "editado" | M4 |**OK**
| D-7 | GAP-017 | Mover `tools/` y `sql/` fuera del repo | Semana 1 |**OK**
| D-8 | GAP-011 | Comprobar el nombre ya | Semana 1 |**RESPONDIDO YA**
| D-9 | ¿Quién valida el MVP? | Tú más 2–3 usuarios reales de Ninox, con sus tablas | M4 |**CORRECTO**
| D-10 | Permiso de escritura para tests automáticos | Permanente pero acotado: base de test `db0000000000`, una tabla desechable, borrando solo lo que el test cree | M2 |**OK**

