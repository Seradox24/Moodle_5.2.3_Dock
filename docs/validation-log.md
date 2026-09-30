# Registro de validación de Moodle 5.2.3

Este archivo recoge resultados verificables sin contraseñas ni contenido de
`.env`. Los logs completos de cada ciclo permanecen en `test-runs/` del servidor
de pruebas y no se incluyen en Git.

Configuración del 30 de septiembre: E-learning SOM, nombre corto SOM, correo
`noreply@minayao.site`, app móvil desactivada. Credenciales y `.env` conservados
fuera de Git en la documentación local de Moodle. Política de respaldos aplazada
por decisión del operador.

## Cierre del 30 de septiembre: contraseña, OpenSSL y permisos

Base comprobada: `c7858a2`, sin cambiar Moodle 5.2.3 ni las referencias de
imágenes. Cambios operativos: contraseña administrativa, paquetes del host y
documentación. El `.env` y los scripts privados locales se sincronizaron con
la contraseña aleatoria nueva, sin registrar su valor en Git. La API de Moodle
comprobó la política antes del cambio y cerró las sesiones del administrador.
`sh scripts/start.sh` actualizó el entorno de los contenedores; se confirmó el
inicio de sesión desde navegador y `REQUESTED_ADMIN_PASSWORD_MEETS_POLICY=yes`.

Se ejecutó `apt-get install --only-upgrade libssl3t64 openssl
openssl-provider-legacy`, con resultado `3.5.5-1ubuntu3.6` para los tres paquetes.
Nginx pasó validación antes de reiniciar. `needrestart -r a -l` reinició los
servicios admitidos por su política automática; se reiniciaron después
`networkd-dispatcher`, `systemd-logind` y `unattended-upgrades`, que había dejado
aplazados. La comprobación final no informa servicios ni sesiones pendientes.
`apt-get -s upgrade` indica cero paquetes pendientes. SSH y Nginx permanecen
activos y Moodle responde HTTPS 200.

Se identificó el aviso de respaldos: únicamente `manager` tiene permiso
explícito `moodle/backup:userinfo`, con cero asignaciones de ese rol y cero
sobrescrituras que otorguen el permiso en otros contextos. `editingteacher` y
`teacher` lo heredan sin concesión explícita. Corregida la referencia anterior
al rol docente: el aviso corresponde al rol Gestor y es consistente con los
permisos predeterminados de Moodle. No se alteraron los roles para ocultarlo.

Se repitió la carga directa con una cuenta temporal nueva, sin reiniciar
servicios durante el recorrido. El navegador automatizado volvió a dejar el
selector esperando; el servidor recibió el archivo de 64 bytes con SHA-256
`07e4db403eb3814e624d06c485ca673997da16b26c8fbdc8bed8ffac5b303b5e`.
No se considera resuelto el recorrido directo. Las API de archivos funcionan y
el ciclo anterior comprobó guardado y descarga mediante Archivos recientes.
Solo está disponible el navegador integrado para esta automatización; no se
concluye todavía si el problema también ocurre en un navegador habitual.
La cuenta y los archivos temporales se limpiaron. Evidencia local:
`D:\Servidor\documentacion general\Moodle\selector-carga-pendiente.jpg`.

Pasaron de nuevo `smoke-test.sh`, `tests/normal-operations.php` y `checks.php`.
El servicio móvil sigue desactivado y el código sigue en solo lectura.
Resultados adicionales en `test-runs/openssl-upgrade-20260930.log`,
`openssl-service-restarts-20260930.log`, `backup-role-review-20260930.log`,
`password-start-20260930.log`, `upload-review-20260930.log` y
`final-smoke-20260930.log`. La prueba de capacidad queda sin ejecutar hasta
definir usuarios concurrentes y tareas representativas; la política de
respaldos continúa aplazada.

## Ciclo del 30 de septiembre: configuración SOM y revisión de seguridad

Revisiones: `e11fefe` bloquea archivos internos en Nginx; `01ba777` corrige cron
y documenta los ajustes posteriores a la instalación. Launcher 1.0.6; Moodle
permanece fijado en 5.2.3. Los cambios se construyeron y aplicaron con
`docker compose build` y `sh scripts/start.sh`, sin repetir el instalador de base.

- Se configuraron los nombres SOM y el correo solicitado mediante las API de
  Moodle; se actualizó el `.env` privado y la cuenta administrativa existente.
  La contraseña administrativa numérica solicitada no pasa
  `check_password_policy`; la política global sigue habilitada. No se registran
  contraseñas aquí.
- En el código de Moodle fijado, `admin/tool/mobile/settings.php` usa
  `is_https() ? 1 : 0` como valor predeterminado. Se aplicó
  `admin_setting_enablemobileservice::write_setting('0')`; se verificaron tanto
  el ajuste como el servicio oficial móvil desactivados. Es un cambio posterior
  a la instalación y no impide navegar desde un teléfono.
- SMTP configurado con SSL en `pro.turbo-smtp.com:465` y LOGIN. Las credenciales
  de la captura fueron rechazadas; el operador proporcionó una pareja nueva.
  La segunda pareja pasó la autenticación con respuesta 235 y verificación del
  certificado TLS. No se enviaron correos y la entrega queda pendiente.
- El informe de seguridad detectó `blog/tests/behat/delete.feature` público
  (HTTP 200). Se añadieron las reglas de archivos internos de la
  [guía oficial de Nginx](https://docs.moodle.org/502/en/Nginx).
  `smoke-test.sh` pasó login, router y cinco rutas protegidas con HTTP 404.
  El informe posterior no presenta errores; señala como aviso un rol con
  permiso para respaldar datos de usuarios. El índice de directorio devuelve
  403, aceptado por Moodle. La primera ejecución del script de informe sin
  `filelib.php` falló al resolver `curl`; se añadió la dependencia y se repitió.
- `checks.php` detectó intervalos de cron de cuatro minutos: la ejecución CLI
  tenía keep-alive y el bucle añadía una espera de 60 segundos. Se configuró
  `cron.php --keep-alive=0` dentro del bucle. Después de construir y reiniciar,
  la ejecución terminó correctamente y las comprobaciones de estado pasaron.
  El log confirma comienzos a las 12:00:56, 12:01:59 y 12:03:00 (hora de Chile),
  con finalización correcta; el intervalo volvió a aproximadamente un minuto.
- Prueba desde navegador con usuario temporal sin permisos administrativos:
  subida de `prueba-carga-som.txt`, guardado en archivos privados y descarga.
  Original y descarga tienen 64 bytes y SHA-256
  `07e4db403eb3814e624d06c485ca673997da16b26c8fbdc8bed8ffac5b303b5e`.
  El selector quedó esperando tras el envío; el archivo ya existía en el
  almacenamiento. Se recuperó desde Archivos recientes, se resolvió la copia
  duplicada, se guardó y descargó. Se registró un error JavaScript
  `M.core.exception is not a constructor` durante la primera ejecución.
  El recorrido directo de subida requiere revisión adicional; el guardado y
  descarga final pasaron. Se limpiaron usuario y archivos temporales.
- Revisión del host: socket Docker `0660 root:docker`, grupo sin miembros;
  `.env` `0600`; solo el puerto web local publicado para Moodle, sin exposición
  directa de base o Redis. Docker Engine 29.8.1 y Compose 5.5.1 coinciden con
  los candidatos del repositorio oficial. Tras `apt-get update`, se detectaron
  tres actualizaciones de OpenSSL; se registraron sin aplicarlas. Disco libre
  aproximadamente 87 GB y RAM disponible 6 GB. Sin carga esperada definida,
  no se concluye una capacidad de usuarios concurrentes.
- Resultados operativos: `test-runs/security-smoke-20260930.log`,
  `security-report-20260930.log`, `smtp-check-20260930.log`,
  `host-update-check-20260930.log`, `cron-build-20260930.log` y
  `cron-start-20260930.log`. Los scripts temporales con credenciales se retiraron
  del servidor; la documentación privada de reinstalación se conserva en el
  equipo local fuera de Git, con permisos restringidos.

## Ciclos anteriores

| Fecha UTC | Commit de `refactorizacion` | Cambios y comandos principales | Pruebas y resultado | Fallos y corrección |
| --- | --- | --- | --- | --- |
| 2026-09-29 16:20 | `88a86ff` | Docker Engine 29.8.1 y Compose 5.5.1 en Ubuntu 26.04; perfil local generado; `preflight.sh`, `install.sh`, `smoke-test.sh`, `start.sh` | Instalación limpia y reinicio correctos; login 200; PostgreSQL, Redis y cron activos; ventana de plugins abre y vuelve a solo lectura | `checks.php` no llega a `localhost:18080` desde `app`; desde el host, las cinco rutas del router devolvieron 200, 200, 404, 302 y 302 |
| 2026-09-29 16:20 | `88a86ff` | `backup.sh test-runs/01-backup`, `sha256sum -c`, `clean-project.sh --force`, segunda ejecución de `install.sh` y `start.sh` | Respaldo íntegro; solo se eliminaron recursos de `lms-moodle-dev`; segunda instalación limpia y reinicio correctos; cinco servicios activos | Sin fallos en el segundo ciclo |
| 2026-09-29 16:20 | `88a86ff` | Preflight con perfil de seis valores ficticios y otro sin `MOODLE_WWWROOT` | Perfil mínimo aceptado; URL ausente rechazada antes del arranque | Sin fallos inesperados |
| 2026-09-29 16:24 | `04a55b3` | `git pull --ff-only`, `sh scripts/start.sh`, prueba de humo ampliada | Login 200; rutas del router 200, 200, 404, 302 y 302 tras el reinicio | Sin fallos |
| 2026-09-29 | `ced19f5` | `tests/normal-operations.php` ejecutado como `www-data` por entrada estándar en `app` | Usuario y curso creados en PostgreSQL; archivo guardado y leído desde `moodledata`; datos temporales eliminados o desactivados | `docker cp` no pudo escribir en la raíz de solo lectura; la ejecución por entrada estándar pasó |
| 2026-09-29 17:12 | `c825911` | Respaldo `test-runs/customcert-before`; ZIP `mod_customcert_2026042005.zip` (SHA-256 `d9abbb34e0f04012d63ad06d3f249dc96cc86653c37d2d9d9233e4fbf415fe6a`); ventana `compose.plugins.yaml`; carga, validación, confirmación y actualización desde Administración; cierre de la ventana | Respaldo íntegro; Moodle instaló `mod_customcert` versión `2026042005`; ajustes iniciales guardados; páginas del plugin HTTP 200; `app` volvió a montar `/var/www/moodle/public` con `RW=false`; prueba de humo y creación de usuario, curso y archivo aprobadas | La primera comprobación de hashes se ejecutó desde el directorio equivocado; se repitió dentro del respaldo y los siete archivos pasaron. La carga se repitió durante la inspección del flujo web y Moodle avisó que reemplazaría el directorio del plugin; la instalación y actualización finalizaron correctamente. |
| 2026-09-29 17:23 | `32b6a9c` | `tests/customcert-functional.php` ejecutado como `www-data` en `app`; `scripts/smoke-test.sh` | Curso y estudiante temporales creados; estudiante matriculado; actividad `customcert` creada con elemento de texto; certificado emitido con código; PDF de 68 023 bytes con cabecera y cierre válidos (SHA-256 `cb00db63278871e5bd68f12ba70475137cd4ae075d15f56e0ec0a111824718b1`); actividad, emisión y curso eliminados y usuario desactivado. Prueba de humo aprobada y código en solo lectura. | Sin fallos en la revisión registrada. La prueba usa las API de Moodle y del plugin; no automatiza el recorrido visual por las pantallas. |
| 2026-09-29 | `0680500` | Revisión de preparación para producción: perfil privado con seis campos, `preflight.sh --config-only`, sintaxis Linux, Compose normal y de plugins; `backup.sh test-runs/customcert-after`, verificación `sha256sum -c` y prueba de humo | Perfil válido aceptado y URL ausente rechazada; siete archivos de respaldo íntegros; `moodle-code.tar.gz` contiene `mod/customcert/version.php`; sitio volvió a responder tras el respaldo | La URL HTTPS pública, el proxy central, SMTP, copia externa y restauración completa no se han probado. No se considera aprobado para producción. |
| 2026-09-30 | `4e07e95` | Ensayo del runbook en el servidor: respaldo `customcert-after` copiado al equipo local y siete hashes verificados; `clean-project.sh --force --remove-images` para `lms-moodle-dev`; eliminación del checkout anterior tras comprobar ruta y recursos; `git clone --branch refactorizacion --single-branch`; `cp .env.example .env`, `chmod 600 .env` | Se eliminaron solo los seis contenedores, tres volúmenes y dos imágenes del proyecto de prueba; el clon nuevo quedó limpio en `/srv/plataforma/moodle`; Docker Compose y Nginx disponibles, `nginx -t` correcto y puerto 18080 libre | El runbook supone que el destino de `git clone` está vacío. En un servidor con la instalación de prueba fue necesario retirar primero el checkout, además de limpiar sus recursos Docker. Instalación nueva pendiente de URL y correo reales para completar el `.env`. |
| 2026-09-30 | `019d35c` | DNS de `moodle.minayao.site` comprobado; se añadió un bloque HTTP exclusivo para el desafío ACME, se ejecutó `nginx -t` y recarga; `certbot certonly --webroot` emitió certificado para el subdominio | El subdominio resuelve a `147.93.132.78`; certificado emitido con vencimiento informado para 2026-12-29; `minayao.site` y los otros sitios Nginx no se modificaron. HTTP responde 503 temporalmente hasta completar Moodle. | La guía no incluye los comandos concretos para crear el sitio Nginx y solicitar el certificado. Se registran aquí para incorporarlos después de cerrar la prueba completa. Pendiente correo real para completar `.env`. |
| 2026-09-30 | `5f6adf8` | `.env` privado de seis campos creado en el servidor con permisos `0600`; `sh scripts/preflight.sh`, `sh scripts/install.sh`, `sh scripts/smoke-test.sh`, `sh scripts/start.sh`; bloque Nginx definitivo para `moodle.minayao.site` con certificado, `Host`, `X-Forwarded-Proto`, límite de 300 MiB y proxy a `127.0.0.1:18080` | Instalación limpia de Moodle 5.2.3; cinco servicios activos, base y Redis saludables, cron operativo; acceso externo HTTPS e inicio de sesión administrador HTTP 200; HTTP redirige a HTTPS; código de `app` en solo lectura. `tests/normal-operations.php` pasó creación de usuario y curso, escritura y lectura de archivo y limpieza. | El 503 observado correspondía al bloque HTTP temporal de ACME y cesó al activar el proxy definitivo. La construcción mostró avisos no fatales de `ARG` en `FROM`. Se usó `admin@minayao.site` como correo provisional, sin prueba SMTP. Las contraseñas no se registran aquí. |
| 2026-09-30 | `5f6adf8` | `sh scripts/backup.sh`; respaldo `backups/20260930_153854` copiado a almacenamiento local fuera del servidor; siete hashes verificados en ambos destinos. Restauración aislada con `COMPOSE_PROJECT_NAME=lms-moodle-restoretest`: creación de volúmenes mediante `docker compose create app`, arranque de `db` y `redis`, extracción de archivos de código y `moodledata`, `pg_restore`, arranque de `app`, comprobación de runtime y `tests/normal-operations.php`; limpieza con `scripts/clean-project.sh --env-file test-runs/restore.env --force` | Base, datos y código recuperados y funcionales en el proyecto aislado; los servicios públicos siguieron funcionando y HTTPS volvió a 200 tras el respaldo. El perfil temporal y sus volúmenes se eliminaron. | `docker compose create --no-deps app` falló porque Compose 5.5.1 no acepta `--no-deps` en `create`; `docker compose create app` funcionó. La guía debe distinguir este caso del `up --no-deps` usado para plugins. El respaldo detuvo brevemente el sitio como está documentado. |
