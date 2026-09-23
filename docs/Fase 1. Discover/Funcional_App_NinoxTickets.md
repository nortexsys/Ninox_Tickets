# PLANTEAMIENTO DE LA APP

Se trata de crear una aplicación Android/ios que permita leer tickets de compra o facturas de compras en formato imagen (formatos universales varios), pdfs, word, google docs u otros típicos usados en los comercios minoristas y mayoristas, y que permita extraer la información de los mismos y guardarla en una base de datos de Ninox, adjuntando el fichero leído al registro creado.
La app es gratuita y se puede descargar desde Google Play Store y Apple Store.


## 1. BOSQUEJO DE LA APP (PROPÓSITO GENERAL)

1. El usuario hace una foto, escanea un ticket usando por ejemplo apps como Adobe scan u otras o sube un fichero de algunos de los tipos generales mencionados anteriormente.
2. Variantes potenciales a investigar:
    2.1. Con el fichero abierto en el movil, el usuario desde la interfaz de Android o Ios selecciona nuestra App y se inicia la lectura del fichero.
    2.2. La captura se inicia desde la interfaz de la App, que permite seleccionar el tipo de fichero a capturar o realizar una fotografía
3. La App lee el fichero y extrae la información de los campos de interés, como el importe, el IVA, el cliente, la fecha, etc....
4. Accede a Ninox vía API con su identificador de Team y Base de Datos, crea un registro en una tabla con los datos extraídos y adjunta el fichero leído al mismo.

## 2. PREGUNTAS SIN RESPONDER Y DUDAS LEGÍTIMAS SOBRE LA APLICACIÓN

    I. Acceso a Ninox. La app debería quedar configurada de tal forma que la API (la de Ninox no caduca), y los valores de TEAM_Id y BD_Id sólo los metiera el usuario 1 sola vez y quedarán como dato de configuración de la propia App. Tener que meterlos cada vez que se hace un ticket, inviaviliza el uso de la app.
    II. Los usuarios de Ninox tienen varias bases de datos bajo una suscripción por lo que la app debería permitir seleccionar la base de datos a la que se quiere guardar el ticket. Sería ideal que hubiera una por defecto o quizás que la quedara "activa" la última que se usó.
    III. Me imagino que Ninox te permitirá entrar desde Android/Ios...sin saber esto, igual estoy haciendo el "canelo" :)
    IV. Al igual que en la laptop para correr determinadas cosas necesitas que se yo un python 3.8, en el movil necesitarás un python 3.8? O quizás un python 3.9? igual no necesitas nada pero es que nunca he hecho nada en Andriod/Ios. 
    V. Pensando en la UX de la app, hay que diseñar la app para que cumpla con estas premisas: a)rápida, b)intuitiva, c)sencilla, d)ligera.
    VI. Me imagino que si un usuario ya tiene la API, es que tienes permisos en Ninox para escribir sobre la tabla pero no sé si convendría dar esto por asumido y omitir cualquier tipo de comprobación al respecto y darlo por sentado, advirtiendo al usuario que los permisos deben estar concedidos por el administrador o por el contrario realizar algún tipo de validación previa.
    VII. Entiendo que con el acceso API, no necesitamos hacer login en Ninox para realizar todas las acciones. Pero no obstante, aquí me planteo lo siguiente. Si la app ejecuta bien su trabajo al terminar, Ninox permanecerá cerrado dado que no se ha hecho login, entonces el usuario no puede comprobar lo que ha hecho. Sería interesante que el proceso terminara con la app de Ninox abierta en el registro que se acaba de ejecutar para que el usuario lo viera, pero claro, aquí ya va el tema de login...quizás uno de los parámteros de la app debería ser user y contraseña en Ninox pero claro esto ya puede chocar con algún tema legal...pues la app quizas (??) esté manejando claves privadas de usuario...no sé como va esto.
    VIII. Sobre el tema de mapeo de tabla/campos se abren varios frentes complejos:
        a) La app no sabe que BBDD elegir cuando recibe un ticket, esto debe indicarlo el usuario. Ahora bien, exigir escribir el nombre es inviable por coñazo total y lentitud. Otra cosa sería poder elegirla de una lista cerrada que ya previamente el usuario como parámetro de configuración ha indicado a la app.
        b) Conocida la BBDD contra la que incidir, la app no sabe que tabla elegir, esto debe indicarlo el usuario. Nos encontramos con el mismo interrogante que en la cuestión anterior....no escribir, mejor elegir, que exige previamente configurar.
        c) Conocidas BBDD y tabla...pues nos queda el mapeo de campos en la tabla versus lo que hemos leído del ticket. Cada ticket puede tener diferentes nombres (por ejemplo, precio puede ser también importe, valor, price, value, base imponible....). El nombre del campo es siempre fijo. Aquí puestos a imaginar, se puede "por inteligencia y sentido común" hacer un match por proximidad de nombres, pero esto es un tema complejo y no sé si es viable. Puedes hacer una propuesta de match para que el usuario lo confirme o modifique. pero claro, ahí ya debemos dar la lista cerrada de campos posibles para que el usuario lo revise. Eso exige que la app conozca esos campos de la tabla.
    IX. Me pregunto si meter una app de escritorio sería necesario o no, intentado evitar complejidad al asunto creo que no.

## 3. METODOLOGÍA DE DESARROLLO

### 3.1 FASE 1
En primer lugar, entramos en fase de discusión para concretar la funcionalidad completa de la app, su UI/UX, y los requisitos de configuración. Generamos un PDR. 
A continuación vamos a examinar la arquitectura de la información para generar un ADR. 
Finalmente creamos un funcional de la aplicación. 
Todos los documentos anteriores se crearán en formato .docx.
### 3.2 FASE 2
A partir del funcional, desarrollamos las specs siguiendo la metodología al pie de la letra que ya aplicamos en otros proyectos. Empezamos aquí la fase de desarrollo que organizará las features, tareas, hitos y plazos de entrega en sucesivas subfases, junto con el diseño de los test.
### 3.3 FASE 3
Una vez finalizada la fase de desarrollo, procedemos con las pruebas de despliegue de la aplicación y publicación en google play, apple store y realizamos un resumen de documentación para anunciarlo en la web de Nortex Systems que será el propietario de la aplicación.

## 4. CARPETAS, GITHUB y OTROS DETALLES IMPORTANTES

La carpeta local es: C:\Users\admin\proyectos\Ticket_reader_Ninox.
El proyecto en GitHub es: https://github.com/nortexsys/Ninox_Tickets/
Toda la aplicación será desarrollada en Inglés
Toda la documentación del proyecto será en Inglés.
Este proyecto tiene intención de ser público y gratuito siendo importante para la visibilidad y notoriedad de Nortex Systems.




