# Estado de preparación para producción

Revisión del 29 de septiembre de 2026 sobre `refactorizacion`, commit base `0680500`. **El repositorio sirve para instalar y probar Moodle 5.2.3 en Docker, pero el sitio aún no está aprobado para recibir usuarios de producción.** El `.env` público se debe crear y completar manualmente en el servidor; `.env.example` es solo la plantilla de seis campos.

## Comprobado

| Área | Evidencia |
| --- | --- |
| Configuración mínima | Un perfil privado con solo los seis campos pasó `preflight.sh --config-only`; otro sin `MOODLE_WWWROOT` fue rechazado. Los dos archivos temporales se eliminaron. |
| Repositorio | No hay `.env`, ZIP, respaldos ni datos de Moodle versionados. La rama local y el servidor estaban sincronizados al iniciar esta revisión. |
| Configuración técnica | Sintaxis de los scripts Linux y ambas combinaciones de Compose válidas. Moodle 5.2.3 y las imágenes siguen fijados en `releases/release.env`. |
| Sitio de prueba | Instalaciones limpias y reinicio, cinco servicios activos, PostgreSQL, Redis, cron y rutas HTTP comprobados. Código de `app` en solo lectura durante operación normal. |
| Funciones | Creación de usuario y curso, carga de contenido, instalación de `mod_customcert` desde Administración, emisión de certificado y generación de PDF comprobadas. Los detalles están en `validation-log.md`. |
| Respaldo | Se generó un respaldo consistente posterior a la instalación de `mod_customcert`; pasaron los siete hashes y se comprobó que el archivo de código incluye el plugin. El sitio volvió a responder después del respaldo. |

El servidor de prueba tiene aproximadamente 89 GB libres y 6,7 GiB de memoria disponible al momento de la revisión. Estas cifras no sustituyen una estimación de capacidad según usuarios, archivos y retención de copias.

## Falta antes de publicar

1. Definir el dominio real, apuntar DNS, instalar un certificado válido y configurar el Nginx central para conservar el encabezado `Host` y comunicar HTTPS a Moodle. Verificar desde fuera del servidor el acceso, inicio de sesión, enlaces, archivos y redirecciones. Hasta ahora el sitio solo se probó por `localhost:18080`.
2. Crear el `.env` de producción directamente en el servidor desde `.env.example`, con permisos `0600`, URL HTTPS definitiva, dos contraseñas fuertes y distintas, nombres y correo reales. Ejecutar `preflight.sh` y registrar el commit aprobado. El perfil HTTP local de pruebas y sus volúmenes no se reutilizan como producción.
3. Configurar y probar el correo saliente desde Administración. Moodle lo necesita para notificaciones y recuperación de cuentas; el repositorio no configura un servicio SMTP.
4. Establecer frecuencia, retención y destino **fuera del servidor** para las copias de PostgreSQL, `moodledata` y `moodle-code`. Conservar el `.env` privado por separado y con acceso restringido; no está incluido en `backup.sh`. Ensayar una restauración completa en un entorno aislado y comprobar cursos, archivos y plugins. Los hashes verificados prueban integridad del archivo, pero todavía no una recuperación funcional. El respaldo detiene brevemente `web`, `app` y `cron`.
5. Ejecutar las comprobaciones de seguridad de Moodle y revisar las políticas del host, acceso a Docker, actualizaciones y capacidad antes de abrir el servicio. Mantener el código en solo lectura salvo durante una instalación controlada de plugins.

La contraseña inicial de administrador permanece en el entorno de `app` por el diseño simplificado acordado. Por ello el acceso al host, a Docker y al `.env` debe limitarse a administradores. Si se decide eliminarla del entorno permanente, será un cambio separado del instalador.

En el servidor usado para las pruebas, `/srv/plataforma/moodle` ya contiene un clon y el proyecto `lms-moodle-dev`. El comando `git clone` del runbook corresponde a un directorio vacío en un despliegue nuevo; no debe ejecutarse encima de esta instalación de prueba. Ambos proyectos usarían el puerto 18080, por lo que el sitio de prueba debe detenerse antes de publicar otro proyecto en ese puerto.

## Criterio de aprobación

Marcar producción como lista solo después de registrar: commit instalado, URL HTTPS comprobada, correo de prueba recibido, copia externa disponible, restauración ensayada y comprobaciones de seguridad revisadas. El runbook describe la instalación y operación; `validation-log.md` conserva las pruebas ya efectuadas.
