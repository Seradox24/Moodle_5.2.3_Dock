# Registro de validación de Moodle 5.2.3

Este archivo recoge resultados verificables sin contraseñas ni contenido de
`.env`. Los logs completos de cada ciclo permanecen en `test-runs/` del servidor
de pruebas y no se incluyen en Git.

| Fecha UTC | Commit de `refactorizacion` | Cambios y comandos principales | Pruebas y resultado | Fallos y corrección |
| --- | --- | --- | --- | --- |
| 2026-09-29 16:20 | `88a86ff` | Docker Engine 29.8.1 y Compose 5.5.1 en Ubuntu 26.04; perfil local generado; `preflight.sh`, `install.sh`, `smoke-test.sh`, `start.sh` | Instalación limpia y reinicio correctos; login 200; PostgreSQL, Redis y cron activos; ventana de plugins abre y vuelve a solo lectura | `checks.php` no llega a `localhost:18080` desde `app`; desde el host, las cinco rutas del router devolvieron 200, 200, 404, 302 y 302 |
| 2026-09-29 16:20 | `88a86ff` | `backup.sh test-runs/01-backup`, `sha256sum -c`, `clean-project.sh --force`, segunda ejecución de `install.sh` y `start.sh` | Respaldo íntegro; solo se eliminaron recursos de `lms-moodle-dev`; segunda instalación limpia y reinicio correctos; cinco servicios activos | Sin fallos en el segundo ciclo |
| 2026-09-29 16:20 | `88a86ff` | Preflight con perfil de seis valores ficticios y otro sin `MOODLE_WWWROOT` | Perfil mínimo aceptado; URL ausente rechazada antes del arranque | Sin fallos inesperados |
| 2026-09-29 16:24 | `04a55b3` | `git pull --ff-only`, `sh scripts/start.sh`, prueba de humo ampliada | Login 200; rutas del router 200, 200, 404, 302 y 302 tras el reinicio | Sin fallos |
| 2026-09-29 | `ced19f5` | `tests/normal-operations.php` ejecutado como `www-data` por entrada estándar en `app` | Usuario y curso creados en PostgreSQL; archivo guardado y leído desde `moodledata`; datos temporales eliminados o desactivados | `docker cp` no pudo escribir en la raíz de solo lectura; la ejecución por entrada estándar pasó |
| 2026-09-29 17:12 | `c825911` | Respaldo `test-runs/customcert-before`; ZIP `mod_customcert_2026042005.zip` (SHA-256 `d9abbb34e0f04012d63ad06d3f249dc96cc86653c37d2d9d9233e4fbf415fe6a`); ventana `compose.plugins.yaml`; carga, validación, confirmación y actualización desde Administración; cierre de la ventana | Respaldo íntegro; Moodle instaló `mod_customcert` versión `2026042005`; ajustes iniciales guardados; páginas del plugin HTTP 200; `app` volvió a montar `/var/www/moodle/public` con `RW=false`; prueba de humo y creación de usuario, curso y archivo aprobadas | La primera comprobación de hashes se ejecutó desde el directorio equivocado; se repitió dentro del respaldo y los siete archivos pasaron. La carga se repitió durante la inspección del flujo web y Moodle avisó que reemplazaría el directorio del plugin; la instalación y actualización finalizaron correctamente. |
