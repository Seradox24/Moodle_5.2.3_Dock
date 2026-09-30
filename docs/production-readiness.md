# Estado de preparación para producción

Revisión del 30 de septiembre de 2026, rama `refactorizacion`. La instalación limpia de Moodle 5.2.3 en `/srv/plataforma/moodle` quedó operativa en `https://moodle.minayao.site`. El servidor se usa todavía como ensayo de producción: faltan el correo real, SMTP y decisiones operativas antes de incorporar usuarios.

## Comprobado

| Área | Resultado |
| --- | --- |
| Revisión instalada | `5f6adf8`, clon nuevo y `.env` privado creado directamente en el servidor con los seis campos de `.env.example` y permisos `0600`. |
| Instalación | `preflight.sh`, construcción, `install.sh`, `smoke-test.sh` y `start.sh` pasaron. PostgreSQL, Redis, `app`, `web` y cron están activos; reiniciar no reinstaló la base. |
| HTTPS | DNS apunta al servidor, certificado válido emitido para el subdominio y Nginx central entrega Moodle por HTTPS. La prueba externa de inicio de sesión devolvió HTTP 200; HTTP redirige a HTTPS. |
| Funciones normales | Inicio de sesión de administrador, creación de usuario y curso, carga y lectura de archivo, y limpieza de datos temporales aprobados. El código de `app` continúa en solo lectura. |
| Respaldo | `backup.sh` generó siete archivos íntegros. Se verificaron sus hashes tanto en el servidor como en una copia local fuera de él. |
| Recuperación | Base, `moodledata` y código restaurados en un proyecto Compose aislado; comprobaciones de runtime y funciones normales aprobadas. Se eliminó solo el proyecto aislado. |

El ZIP de `mod_customcert` se probó en el sitio de desarrollo anterior. La instalación limpia pública aún no incluye ese plugin.

## Pendiente antes de recibir usuarios

1. Reemplazar `admin@minayao.site`, usado provisionalmente en el ensayo, por el correo real del administrador; configurar SMTP y comprobar recepción, recuperación de contraseña y notificaciones.
2. Definir frecuencia, retención y destino estable de copias externas al servidor, incluido el `.env` privado, que `backup.sh` no respalda. La copia local de este ensayo y la restauración aislada prueban el procedimiento, pero no establecen una política de respaldo.
3. Revisar los informes de seguridad de Moodle, actualizaciones del host y de Docker, permisos de acceso a Docker y capacidad según la carga esperada. Verificar una subida y descarga desde navegador con una cuenta de usuario final.
4. Rotar las credenciales de ensayo antes de admitir usuarios reales. La contraseña inicial del administrador permanece en el entorno de `app` por el diseño sencillo acordado; restringir el acceso al host, Docker y `.env`.

El registro detallado, incluido el 503 temporal durante el desafío del certificado y la restauración, está en [validation-log.md](validation-log.md).
