# ANÁLISIS TRAS LA REVISIÓN DE RESULTADOS DEL CORPUS

## 1. Resultado

Errores detectados por el PO:

| Registro | Fecha | Importe (base) | IVA deducible | Documento | Aritmética |
|---|---|---|---|---|---|
| 1413 | 2026-08-08 | 16,51 | 3,47 | WhatsApp 19.17.13 (El Corte Inglés) | correcta |
**El importe es 16,52 no 16,51**
| 1417 | *(vacía)* | 1.658,96 | 149,31 | ticket2.msg | correcta |
**mala calidad de imagen aunque el importe se puede leer y es 110,27**
| 1418 | 2026-08-27 | 334,78 | 70,30 | WhatsApp 15.47.49 (Plenergy) | correcta |
**importes incorrectos ambos, fecha correcta**
| 1419 | 2026-08-21 | 512.307,69 | 153.692,31 | Invoice 21-0113 (ITAP, USD) | correcta |
**El total por suma es correcto pero equivoca la divisa que no es euros sino USD. Inventa importe e IVA Y de haber sido la divisa correcta, tambien hubiera errado pues es factura sin IVA.**
| 1421 | 2026-04-20 | 10,95 | 2,30 | Sin título.msg (Cloud) | correcta |
**importes correctos, fecha inventada**
| 1425 | 2026-07-16 | 45,54 | 9,56 | ticket.msg (55comb) | correcta |
**Ticket con 2 IVAS y dos bases, difícil de leer correctamente.**

## 2. Los 5 documentos que salieron mal (y por qué)

1. **`PRO1013-26.pdf` → Importe 8.741,00 (incorrecto).** El PDF tiene capa de texto, pero
   PyMuPDF extrae rótulos y valores en **líneas separadas**. El parser no encontró el total
   etiquetado y cayó al último recurso, cogiendo un trozo de número de registro
   (`Tomo 8.741`). El importe real liquidado es **742,42**.
   ***Es cierto, en esta factura sí aparece claramente un IVA que es de 117.10. El caso es que el importe que mencionas es el total y es correcto, ese sería el campo calculado. En este caso, lo que habría que haber hecho es ajustar el importe base como diferencia entre total e IVA.***
2. **`sc.jpg` → Importe 26,00 (incorrecto).** Ticket cubano (Fincimex) sin ninguna etiqueta
   "TOTAL": el parser cogió el 26 de una fecha. El importe real no se localizó.
   ***Cierto, cuando la divisa es distinta de la divisa de la tabla es mejor npo escribir nada a escribir con un error.***
3. **`FACTURA de MAGNUS…pdf` → Importe 123.030,00 (correcto como base, pero IVA 0).** Factura
   de EE. UU. en **USD**: no hay IVA español. El valor es correcto pero la moneda no se puede
   representar en `YB`.
   ***Cierto al igual que en el caso anterior, es mejor no escribir nada a escribir con un error.***
4. **`FRA 632/2025` → aritmética incoherente.** El PDF imprime `TOTAL FACTURA 265,00 €` y
   `********265,00 €`; el IVA es 0 % (exportación exenta). El parser detectó candidatos
   contradictorios y lo marcó.
   **se inventa el IVA que no está en factura, mejor no inventar nunca además es que no hay base lógica para ello**
5. **`Santander` (1414) → Importe 19,40 con IVA 0.** El ticket de datáfono **no imprime ni base
   ni IVA**, solo el total. Al no haber tipo de IVA impreso, no se pudo derivar el desglose.
   El 19,40 es correcto; lo que falta es el desglose.
   ***Pues este ticket es correcto en todo la verdad, el importe que es lo único que se ve, se pone***

Además, **3 documentos quedaron sin fecha** (1415, 1417, 1426). En 1417 y 1426 la fecha está
impresa pero el rótulo y el valor quedan en líneas separadas al extraer el texto. 
***Decisión correcta, todo correcto en estos casos***`

## 3. Lo que necesito de ti

1. **¿Corrijo los 5 registros dudosos?** Mi propuesta: dejar `Importe` e `IVA deducible`
   vacíos en 1415, 1416, 1424 y 1427, y completar la fecha en 1415, 1417 y 1426 leyéndola de
   las líneas adyacentes. Dime si prefieres que los deje como están para que los revises tú.
   ***Déjalo como está***
2. **¿Creamos el campo de total en `YB`?** Sin él, el importe realmente pagado no queda
   registrado en Ninox.
   ***Como ya te dije, este campo existe pero no lo ves porque es calculado***
3. **¿Amplío el corpus?** Faltan los 16 documentos del objetivo del PDR, sobre todo
   hostelería y combustible en papel, que son justo donde la validación aporta.
   ***No es necesario***
4. **¿Cómo tratamos el 1428?** Es una retirada de efectivo, no una compra. Si `YB` es para
   cargos de tarjeta, el importe correcto es 96,76 EUR (lo cargado); si es para gastos
   deducibles, probablemente no debería estar ahí.
   ***Documento correcto, salió todo como se esperaba***

## 4. Próximos pasos

1. Analizar los errores comentados.
2. Verificar que solución puede aplicarse para ajustar mejor la lectura.
