# REVISAR LAS DOS PROPUESTAS DE INDICES PARA EL FUNCIONAL DE PAPERDROP

## OPCION 1. 
Propuesta de índice
1. Introduction

1.1 Purpose and role of this document — puente PDR/ADR → desarrollo; define comportamiento, no arquitectura; sucede a Funcional_App_NinoxTickets.md.
1.2 Scope of version 1 — hereda el alcance del PDR §3.1 y reexpresa los non-goals del §3.2 como exclusiones explícitas y testeables ("la app nunca…").
1.3 Related documents — PDR v0.2, ADR v0.2, evidencia del test de 16 documentos, triage de los 17 findings.
1.4 Glossary — team, destination, provenance, redundancy, slot, abstention… (terminología ya unificada en v0.2).
1.5 Conventions — identificación de requisitos (FR-/BR-/NFR-/UC-), estados (defined / blocked by ADR-XXX), prioridad.
2. Overall description

2.1 Product context — app complementaria de Ninox, gratuita, open source, sin backend ni cuenta (ADR-002).
2.2 Users and journeys — cliente Ninox; rutas de recibo en papel y factura de proveedor con peso igual (PDR §2) y su consecuencia en la primera ejecución.
2.3 Platforms and environment — Android/iOS, extracción en el dispositivo, captura sin conexión; restricciones de la iOS Share Extension (ADR-001).
2.4 Constraints — el contrato técnico de 8 líneas (Anexo A del PDR) reexpresado como restricciones verificables.
2.5 Assumptions and dependencies — disponibilidad de la API clásica de Ninox (ADR-003), Play Services en Android (ADR-006/010), cierre pendiente de ADR-010/011.
3. Use cases and end-to-end flows (UC-XX) — un caso por recorrido real, cada uno con precondiciones, flujo principal, variantes y aceptación:

Primera ejecución y wizard (con pasos auto-omitidos) · documento limpio (3 taps + confirmación diaria de destino) · documento típico (vistazo a los ámbar, 5–6 taps — el PDR §6.2 fija esta expectativa con honestidad) · e-factura estructurada (todo from_xml) · resguardo de datáfono (sin desglose → nunca verde; el cero contractual) · recido multi-tipo impositivo (slots) · reintegro en el extranjero (DCC, dos divisas, recargo) · .msg con varios adjuntos (regla de selección + elección manual) · duplicado detectado · captura offline y envío en cola · create con resultado incierto → reconciliación → pregunta al usuario si es ambiguo · corrección y reenvío desde historial · migración de dispositivo (export/import, reintroducir token).
4. Functional requirements by module (FR-XX) — el comportamiento, módulo a módulo, cada requisito con su criterio de aceptación:

4.1 FR-CAP Capture — cuatro vías de entrada; escáneres del sistema (ADR-006); multipágina = un registro; ensamblado de capturas frente a preservación byte a byte de archivos recibidos (ADR-007/015); la extensión iOS entrega directamente a revisión (ADR-001); regla de selección de adjuntos en correo.
4.2 FR-EXT Extraction pipeline — prioridad fija XML → texto posicional → OCR (ADR-014); sintaxis/perfiles XRechnung y semántica not_in_xml; consenso por mayoría, nunca el máximo (ADR-019); leer todos los operandos antes de derivar; derivar solo por identidad, nunca asumiendo un tipo no impreso; diccionario de contexto negativo; consolidación multipágina; fallback render+OCR para PDF sin capa de texto.
4.3 FR-VAL Validation and confidence — dígitos de control (EAN-13, IBAN mod-97, ES NIF/NIE/CIF como tres algoritmos separados, AT UID, CH UID; DE STNR explícitamente no validado); verificaciones por redundancia con la regla de procedencia de operandos; reparación a valor único; divisa con evidencia propia; tres fuerzas → verde/ámbar/rojo; slots y tipos legales por país.
4.4 FR-REV Review — barra de destino con confirmación en la primera captura del día; miniatura con recuadro sobre la región leída, incluidos todos los operandos de una redundancia; seis campos núcleo en orden fijo con foco en el primero no leído; reglas de colapso/expansión del bloque de importes; avanzado colapsado; aviso de duplicado; botón que nombra el destino; verde editable solo tras tocar el candado.
4.5 FR-DST Destinations and mapping — destino = team/base/tabla + identificadores de campo; sin destino por defecto la primera vez, precarga del último usado después; caché de esquema, refresco al abrir y resolución de nombres al enviar; host de Ninox configurable (ADR-017); campos fórmula/read-only excluidos del mapeo y usados como contraste post-escritura (PDR §7.4); ajuste por campo de "ausente = vacío o cero"; campos choice con las opciones existentes.
4.6 FR-WIZ Setup wizard — cinco pasos y lógica de omisión; token vía navegador del sistema + pegado (ADR-018) con validación inmediata; emparejamiento en dos etapas (filtro duro de tipo, luego sinónimos con umbral estricto → sin mapear antes que sugerencia mediocre); propuestas precargadas; mapeo opcional; resumen en lenguaje llano; cierre ofreciendo capturar el primer documento.
4.7 FR-SND Send pipeline — create → attach → read-back y visualización de lo realmente almacenado; la matriz completa de reintentos del PDR §9.1 como requisitos por caso; reconciliación de creates inciertos (ADR-013: registros recientes, createdAt/createdBy, ventana temporal, ambigüedad → preguntar); reintento solo del adjunto gracias a la semántica merge; deep link de retorno con degradación elegante (ADR-008); aviso de que el create puede disparar automatizaciones no expuestas por la API (ADR-004).
4.8 FR-HIS History — contenido de cada entrada (miniatura, valores con procedencia, destino, estado, confianza, hash, id de registro); estados pendiente/en cola/enviado/fallido/incierto; corrección y reenvío; retención de archivos (borrado tras envío confirmado; conservados en pendientes y fallidos).
4.9 FR-MEM Supplier memory — aprendizaje de proveedores; indexación solo por identificadores que pasaron su dígito de control (la salvaguarda de ADR-009); presentación en revisión; acción de borrado real.
4.10 FR-CFG Configuration and data management — export/import (destinos, mapeos y memoria de proveedores; nunca el token); migración de dispositivo; vaciado de datos locales.
4.11 FR-CTR Countries and languages — detección de país determinista desde la evidencia del documento (sin ajuste de usuario); núcleo universal + tabla DE/AT/CH/ES; inferencia de formato (día > 12, patrones de agrupación); redondeo suizo de 5 Rappen capturado, nunca recalculado; interfaz EN/DE; diccionarios de documento multilingües incluidos los términos de contexto negativo.
4.12 FR-DUP Duplicate detection — hash, o proveedor+fecha+total; aviso con enlace al registro existente; posibilidad de continuar.
5. Business rules catalogue (BR-XX) — el núcleo testeable, cada regla con su origen: determinismo sobre cobertura; una verificación solo confirma si todos los operandos son read/from_xml; vacío antes que falso como valor por defecto; nunca verde sin redundancia; doc_number nunca verde; nombre de proveedor confirmable solo vía memoria; importes en unidades menores enteras y tipos en puntos básicos, igualdad exacta salvo base×tasa≈impuesto con ±1 unidad menor por línea (ADR-016); consenso por mayoría; derivación solo por identidad; los valores derivados nunca elevan la confianza; integridad byte a byte del adjunto; nunca escribir campos sin mapear; nunca tocar esquema ni registros ajenos; el token como única credencial.

6. Data specification

6.1 Canonical data dictionary — los seis campos núcleo y los grupos extendidos (PDR §5), campo a campo: tipo, formato, procedencia, mapeabilidad.
6.2 Provenance and confidence model — etiquetas, estados, transiciones, qué puede mostrarse como confirmado y qué puede escribirse.
6.3 Local stores — historial, destinos, memoria de proveedores, archivo de configuración, keystore/keychain; reglas de retención.
6.4 Ninox payload and mapping rules — identificadores frente a nombres, fechas literales, campos choice, serialización entera (ADR-004/016).
7. Interface specification — composición y navegación (el comportamiento ya está en la sección 4):

7.1 Inventario de pantallas y mapa de navegación · 7.2 Capture · 7.3 Review · 7.4 Editor de destino y mapeo · 7.5 Wizard (cinco pantallas + variantes con pasos omitidos) · 7.6 History y detalle · 7.7 Confirmación (read-back + deep link) · 7.8 Estados globales: vacío, primera ejecución, sin conexión, superficies de error según la matriz de reintentos.
8. Non-functional requirements (NFR-XX)

Privacidad (la afirmación precisa del PDR §11, alineación con el Data Safety form, declaración de los dos almacenes locales, distinción de diagnósticos de ML Kit); seguridad (keystore/keychain, sin WebView controlado por la app, jamás credenciales); rendimiento (umbrales diferidos al primer screening, PDR §12); comportamiento offline; accesibilidad; i18n EN/DE; licencias (dependencias propietarias declaradas en el README, AGPL excluida — ADR-011); restricciones de plataforma.
9. Error handling and user messaging

Taxonomía de errores por operación (token, lectura de esquema, create, adjunto, read-back); la matriz de reintentos expandida a comportamiento y textos visibles para el usuario; error de mapeo frente a error de servidor (semántica del 500); flujo de expiración de autenticación (401/403).
10. Acceptance criteria, metrics and validation

Criterio de aceptación por requisito; definición del corpus de dos mitades y la semántica de "screening como filtro, no medición" (PDR §13); precisión por campo tras la validación contando solo procedencia read/from_xml; protocolo de medición supervisada (ADR-012); definiciones de métricas incluida la tasa de abstención; criterios de release con umbrales a fijar tras el primer screening.
11. Traceability

Matriz FR/BR/NFR/UC → PDR § → ADR-XXX; requisitos bloqueados por decisiones abiertas marcados; los 17 findings y los hallazgos del test de 16 documentos trazados a los requisitos que motivaron.
12. Open items and risks — heredados del PDR §14 y del ADR §3.1, más lo que surja al especificar.

Annexes

A. Ninox API external contract — las reglas verificadas de ADR-004 como referencia de interfaz vinculante, con sus puntos aún abiertos. · B. Country table — DE/AT/CH/ES completos (formatos, algoritmos de dígito de control, tipos legales, slots, redondeo). · C. Keyword and negative-context dictionaries — contenido inicial por idioma. · D. Worked examples — los casos fundacionales como ejemplos de aceptación: confirmación EAN-13, reparación 123456795→S, 16.52+3.47=19.99, el recargo DCC leído como IVA, y la tautología de base derivada como test negativo. · E. Numbering and status conventions.

## OPCION 2.
1. Introducción
1.1 Propósito del funcional y límite con el SDD 1.2 Relación con PDR v0.2 y ADR v0.2 (qué hereda, qué descompone, qué no añade) 1.3 Glosario y terminología (team, destino, mapeo, provenance, slot de impuesto, unidad menor…)

2. Visión funcional del producto
2.1 Problema y propuesta de valor 2.2 Perfiles de usuario y jornadas tipo (ticket fotografiable, factura PDF, e-invoice estructurada, adjunto .msg/.eml) 2.3 Los cinco principios de producto como requisitos verificables (tres taps / never block / determinismo / vacío sobre falso / nada sale del dispositivo) — PDR §4 2.4 Alcance de v1 y no-objetos — PDR §3.2

3. Entrada y captura de documentos
3.1 Scanner nativo del sistema (ML Kit Document Scanner / VisionKit) — ADR-006 3.2 Galería y file picker 3.3 Entrada por share (intent filter / Share Extension; paso al flujo de revisión en iOS) 3.4 Adjuntos de correo .msg/.eml: regla de selección del candidato y overrides manuales 3.5 Documentos multi-página (un registro, un adjunto multi-página) 3.6 Integridad e inmutabilidad del original (byte a byte; solo el capturado se ensambla) — ADR-007 / ADR-015

4. Pipeline de extracción
4.1 Rutas y orden de prioridad: XML → texto posicional → OCR — ADR-014 4.2 Extracción desde XML estructurado (ZUGFeRD/Factur-X, XRechnung; perfiles MINIMUM/BASIC WL y not_in_xml) 4.3 Extracción posicional de PDF (asociación label↔valor por coordenadas) — ADR-011 4.4 OCR y consenso entre pasadas (gana la mayoría; un outlier nunca domina) — ADR-019 4.5 Regla leer antes de derivar y frontera derivar/inventar (base = total − tax sí; base = total ÷ (1+r) no) 4.6 Diccionario de contexto negativo (DCC, Skonto, Registro Mercantil/Tomo/Folio, HRB…) 4.7 Provenance de cada valor (read / derived / repaired / from_xml) y su efecto

5. Modelo de datos canónico
5.1 Los seis campos núcleo — PDR §5.1 5.2 Campos extendidos, grupo a grupo (Documento, Proveedor, Importes, Moneda y pago, surcharges[], Viaje, Metadatos) — PDR §5.2 5.3 Slots de tipos impositivos múltiples y tax_total — PDR §5.3 5.4 Representación monetaria entera en unidades menores; tipos en basis points — ADR-016 5.5 Normalización y validadores (NIF/CIF/NIE separados, UID suizo, EAN-13, IBAN, fechas, separador decimal)

6. Validación y modelo de confianza
6.1 Las tres fuerzas (redundancia / dígito de control / reparado) y por qué solo la primera es verde — PDR §6 6.2 Semáforo verde-ámbar-rojo, candado y reglas de edición 6.3 Reglas de validación universales + tabla de país; detección determinista de país — PDR §10 6.4 Moneda: evidencia propia y estado propio 6.5 Detección de duplicados (hash; proveedor+fecha+total) y comportamiento del aviso 6.6 Qué nunca puede llegar a verde (número de documento, nombre de proveedor sin memoria)

7. Pantallas (especificación funcional)
7.1 Captura y entrada 7.2 Revisión (destination bar, thumbnail con cajas de proveniencia, seis campos fijos, bloque de importes colapsable, avanzado, aviso de duplicado, botón de guardar con nombre del destino) 7.3 Destinos: alta/edición, ajustes por campo ("vacío o cero"), ajustes avanzados (host Ninox) — ADR-017 7.4 Historial: estados, reenvío, corrección, borrado de imágenes locales tras envío confirmado 7.5 Confirmación y regreso a Ninox por deep link — ADR-008 7.6 Estados vacíos, de error y de cola offline

8. Asistente de configuración
8.1 Token por navegador del sistema (Custom Tabs / SFSafariViewController) — ADR-018 8.2 Selección de team → database → table (auto-skip con un solo elemento) 8.3 Mapeo de campos: filtro duro por tipo + sinonimia, umbral estricto, exclusión de fórmulas y solo-lectura — PDR §8.1 8.4 Uso post-escritura de la fórmula total del usuario — PDR §7.4 8.5 Resumen final en lenguaje natural y oferta de capturar el primer documento

9. Envío a Ninox
9.1 Contrato del cliente clásico (payload, merges, choice fields, read-after-create) — ADR-004 9.2 Pipeline: create → attach → read-back 9.3 Tabla de reintentos y conciliación ante resultado incierto — ADR-013 / PDR §9.1 9.4 Errores 500 como errores de mapeo; refresco de esquema una sola vez 9.5 Cola offline y envío automático al recuperar conexión 9.6 Deep link de regreso y degradación elegante

10. Almacenamiento local y configuración
10.1 Qué se guarda, cuándo y qué se borra 10.2 Memoria de proveedores: indexación solo por identificadores con dígito válido 10.3 Export/import de configuración (sin token, nunca) 10.4 Acciones de borrado y privacidad del usuario

11. Países e idiomas
11.1 Núcleo universal e inferencia de formato 11.2 Tabla de país (DE/AT/CH/ES) y separación estricta de los tres algoritmos españoles 11.3 Diccionarios de palabras clave documentales independientes del idioma de la UI

12. Privacidad y datos (requisitos)
12.1 Claims precisas para stores (ML Kit: diagnósticos, no contenido) 12.2 Declaración de los dos stores locales 12.3 Cumplimiento de Data Safety / App Privacy

13. Requisitos no funcionales
13.1 Rendimiento y flujos de tiempo por documento 13.2 Funcionamiento offline 13.3 Tamaño de la app y dependencias propietarias declaradas (contrato #5) 13.4 Accesibilidad e idiomas de UI (EN/DE) 13.5 Plataformas y versiones mínimas soportadas

14. Aceptación y corpus de pruebas
14.1 Corpus: dos rutas y su construcción 14.2 Métricas de producto y umbrales (a fijar tras el primer screening) — PDR §12 14.3 Criterios de cierre de ADR-010 y ADR-011 14.4 Criterios de aceptación por release

15. Trazabilidad y contrato técnico
15.1 Matriz PDR § → ADR → FR (cubre los 19 ADR y las 8 líneas del Anexo A) 15.2 Contrato técnico como filtro de revisión de cualquier requisito nuevo

16. Abiertos, supuestos y dependencias
16.1 Items abiertos heredados (ADR-010/011, límites de subida, choice fuera de opciones, disponibilidad del nombre) 16.2 Supuestos del mercado y del producto 16.3 Dependencias externas (API Ninox clásica, Google Play Services, VisionKit)

Anexos
A. Contrato técnico (íntegro del Anexo A del PDR) B. Glosario ampliado C. Catálogo de reglas de validación universales y por país D. Plantilla de requisito FR y plantilla de caso de uso asociado

Notas de diseño del índice
Estructura en tres bloques: contexto de producto (§1–2), requisitos funcionales por capacidad (§3–12), restricciones y aceptación (§13–16). Así el SDD posterior puede mapear módulos de arquitectura directamente a bloques del funcional.
Novedad respecto al PDR: los §3, §4, §5, §9 y §10 bajan el nivel de detalle a reglas concretas y orden de prioridad (p. ej. el orden XML→posicional→OCR o la política de reintentos como tabla de condiciones), que es justo lo que el SDD necesita para no tener que re-decidir.
Trazabilidad desde el minuto uno (§15), para que ninguna decisión del ADR se quede sin requisito que la implemente y viceversa.
