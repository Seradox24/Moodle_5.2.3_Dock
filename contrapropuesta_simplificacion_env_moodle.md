# Contrapropuesta de simplificación del entorno Moodle

## Estado

Esta contrapropuesta ya fue aplicada en la rama `refactorizacion` hasta el alcance acordado para las pruebas. El procedimiento vigente está en `README.md` y `deploy-runbook.md`; la evidencia de cada ciclo está en `docs/validation-log.md`. Este documento registra las decisiones y los límites de la implementación, no reemplaza el procedimiento operativo.

El objetivo es instalar Moodle 5.2.3 en contenedores Docker con pocos datos obligatorios, un instalador asistido en Linux y una vía manual en Windows. La versión de Moodle y las imágenes siguen fijadas en `releases/release.env`.

## Decisiones aplicadas

| Tema | Resultado |
| --- | --- |
| Perfil de producción | `.env.example` contiene seis datos: URL pública, contraseña de PostgreSQL, nombre largo y corto del sitio, contraseña y correo iniciales del administrador. El operador crea y completa su `.env` manualmente. |
| URL | `MOODLE_WWWROOT` es obligatoria en Compose y PHP. El acceso de prueba se publica solo en `127.0.0.1:18080`. |
| Proxy | Los valores normales son `MOODLE_SSLPROXY=true` y `MOODLE_REVERSEPROXY=false`. El perfil HTTP local usa `false` y `true`, respectivamente. |
| Perfil de prueba | `scripts/prepare-env.sh` genera contraseñas y un archivo privado para pruebas Linux; avisa que se debe completar el correo. No genera el `.env` de producción. |
| Instalación | `scripts/install.sh` conserva la instalación de la base mediante la CLI de Moodle dentro de `app`. Windows usa los mismos servicios Docker con comandos manuales documentados; se retiraron los tres scripts de instalación específicos de Windows. |
| Arranque | El arranque ordinario no vuelve a instalar la base de datos. |
| Código y plugins | `app`, `web` y `cron` montan el código en solo lectura durante la operación normal. `compose.plugins.yaml` abre temporalmente escritura para `app` y habilita la instalación desde Administración; al cerrarlo vuelve el modo normal. Los plugins persisten en `moodle-code`. |
| Datos de Moodle | La base PostgreSQL y `moodledata` permanecen escribibles. La protección del código no bloquea crear usuarios o cursos ni subir contenido. |
| Respaldo | El script genera un respaldo consistente de base, `moodledata` y código con plugins. Falta ensayar la restauración completa y guardar copias externas antes de producción. Los resultados privados del servidor se guardan en `test-runs/`, fuera de Git. |

Las credenciales iniciales siguen disponibles en el entorno de `app` durante esta etapa. Extraerlas a un servicio instalador temporal sería una mejora posterior y no es requisito para dar por válida esta instalación simplificada.

## Validación realizada

Se validaron sintaxis, configuración Compose y perfiles `.env` válidos e inválidos. En el servidor de pruebas se instaló Docker Engine y Compose desde el repositorio oficial de Docker. Se completaron dos instalaciones limpias de la rama, con respaldo previo y comprobación de integridad del respaldo. La revisión funcional registrada en `docs/validation-log.md` llegó al commit `7936d54`.

La instalación y el reinicio posterior funcionaron con PostgreSQL, Redis, Moodle, cron y router. Las rutas HTTP se comprobaron desde el host contra `localhost:18080`. Se verificó que `app` no escribe código en modo normal, sí puede escribir durante la ventana de plugins y vuelve a solo lectura al cerrarla.

También se ejecutó una prueba con las API de Moodle, como el usuario del servicio, que creó un usuario, un curso y un archivo de contenido, leyó el archivo y limpió los datos de prueba. Esto confirma que el montaje de código en solo lectura no impide esas funciones normales. La prueba no equivale a una revisión de cada pantalla de la interfaz.

Se instaló `mod_customcert` versión `2026042005` desde Administración usando la ventana de escritura temporal. Moodle validó el ZIP y actualizó la base. Tras cerrar la ventana, las páginas del plugin respondieron HTTP 200, el código siguió en solo lectura y volvieron a pasar las pruebas de humo y de operaciones normales. El detalle y el hash del paquete están en `docs/validation-log.md`.

Una prueba funcional posterior creó la actividad en un curso temporal, matriculó a un estudiante, emitió un certificado con código de verificación y generó un PDF válido. Se eliminaron la actividad, la emisión y el curso; el estudiante de prueba quedó desactivado. El resultado está en `docs/validation-log.md`.

## Pendiente para otra etapa

- Si se requiere aceptación visual, recorrer las pantallas de creación de la actividad y descarga del certificado con un usuario de prueba. La prueba funcional automatizada cubre las API que realizan esas operaciones y la generación del PDF.
- Probar la publicación HTTPS por el dominio definitivo y ajustar el Nginx central cuando se prepare producción. Las pruebas actuales usan HTTP local por SSH.
- Si se decide retirar las credenciales iniciales del entorno permanente de `app`, diseñar y probar un instalador temporal como cambio separado.
- Validar los flujos de operación normal que no cubrió la prueba automatizada, como restaurar un curso desde la interfaz.

Para migrar una instalación existente, conservar el nombre del proyecto Compose, las opciones de base de datos y los volúmenes, y respaldarlos antes de cambiar el perfil. No se debe usar una instalación limpia como procedimiento de migración.

## Referencias

- [Guía rápida de Moodle 5.2](https://docs.moodle.org/502/en/Installation_quick_guide)
- [Instalación y permisos de Moodle](https://docs.moodle.org/502/en/Installing_Moodle)
- [Instalación de plugins](https://docs.moodle.org/502/en/Installing_plugins)
- [Instalación de Docker Engine en Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
