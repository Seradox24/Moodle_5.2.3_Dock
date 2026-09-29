# Registro de validación de Moodle 5.2.3

Este archivo recoge resultados verificables sin contraseñas ni contenido de
`.env`. Los logs completos de cada ciclo permanecen en `test-runs/` del servidor
de pruebas y no se incluyen en Git.

| Fecha UTC | Commit de `refactorizacion` | Cambios y comandos principales | Pruebas y resultado | Fallos y corrección |
| --- | --- | --- | --- | --- |
| 2026-09-29 16:20 | `88a86ff` | Docker Engine 29.8.1 y Compose 5.5.1 en Ubuntu 26.04; perfil local generado; `preflight.sh`, `install.sh`, `smoke-test.sh`, `start.sh` | Instalación limpia y reinicio correctos; login 200; PostgreSQL, Redis y cron activos; ventana de plugins abre y vuelve a solo lectura | `checks.php` no llega a `localhost:18080` desde `app`; desde el host, las cinco rutas del router devolvieron 200, 200, 404, 302 y 302 |
| 2026-09-29 16:20 | `88a86ff` | `backup.sh test-runs/01-backup`, `sha256sum -c`, `clean-project.sh --force`, segunda ejecución de `install.sh` y `start.sh` | Respaldo íntegro; solo se eliminaron recursos de `lms-moodle-dev`; segunda instalación limpia y reinicio correctos; cinco servicios activos | Sin fallos en el segundo ciclo |
| 2026-09-29 16:20 | `88a86ff` | Preflight con perfil de seis valores ficticios y otro sin `MOODLE_WWWROOT` | Perfil mínimo aceptado; URL ausente rechazada antes del arranque | Sin fallos inesperados |
