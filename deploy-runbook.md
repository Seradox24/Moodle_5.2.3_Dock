# Moodle 5.2.3: instalación y operación en Linux

Este repositorio contiene el despliegue Docker de Moodle en Linux. `main` contiene la
base validada para pseudoproducción. Las versiones de Moodle y de las imágenes
están fijadas en `releases/release.env`. Los registros de pruebas y
el estado de preparación para producción se conservan en documentación
operativa separada. La URL de su repositorio se añadirá cuando esté disponible.
Las rutas de despliegue, dominios y correos mostrados son ejemplos; adaptarlos
al entorno de instalación. `127.0.0.1:18080` es el destino local del proxy
definido por Compose.
El `.env`, las credenciales SMTP y el procedimiento privado para aplicar los
ajustes tras reinstalar se guardan fuera de Git en una ruta local, con permisos
restringidos para los archivos privados.

## Archivos necesarios

- `compose.yaml`: servicios web, PHP, cron, PostgreSQL y Redis.
- `Dockerfile`, `docker/` y `config/`: imágenes y configuración de Moodle.
- `releases/release.env`: versiones y referencias fijadas de las imágenes.
- `.env.example`: plantilla única, sin contraseñas reales.
- `scripts/`: instalación, validación, operación y copia de seguridad.

No subir archivos `.env`, respaldos, bases de datos ni `moodledata` a Git.
Los tres volúmenes de Compose guardan la base, los archivos de Moodle y el
código compartido; `docker compose down -v` los elimina.

## Producción en Ubuntu

Requisitos: Docker Engine con el plugin Compose, Git, curl, conexión de salida para
construir las imágenes, Nginx del host y una URL definitiva para Moodle.
Instalar Docker siguiendo su [guía oficial para Ubuntu](https://docs.docker.com/engine/install/ubuntu/).
Comprobar que el puerto local 18080 esté libre. Clonar el repositorio en una
carpeta vacía; los comandos usan `/srv/plataforma/moodle` como ejemplo:

```bash
git clone --branch main --single-branch https://github.com/Seradox24/Moodle_5.2.3_Dock.git /srv/plataforma/moodle
cd /srv/plataforma/moodle
git rev-parse HEAD
cp .env.example .env
chmod 600 .env
nano .env
```

Completar los seis campos de `.env`:

- `POSTGRES_PASSWORD` y `MOODLE_ADMIN_PASSWORD`: contraseñas fuertes y distintas.
- `MOODLE_SITE_FULLNAME`, `MOODLE_SITE_SHORTNAME` y `MOODLE_ADMIN_EMAIL`.
- `MOODLE_WWWROOT`: URL pública definitiva asignada por el Nginx central, por ejemplo `https://moodle.example.com`.

Compose fija el puerto `127.0.0.1:18080` y los valores de proxy, Redis y
proyecto para producción. No agregarlos al `.env` salvo una excepción
documentada. `scripts/prepare-env.sh` genera únicamente perfiles de prueba;
el `.env` de producción se crea y completa manualmente.

La URL pública debe resolver hacia el servidor; `localhost:18080` es solo el
destino interno del Nginx central, nunca la URL que ven los usuarios.
Preparar DNS y certificado para el dominio elegido antes de publicar Moodle.
La rama `main` contiene la base validada; registrar y comprobar el commit
seleccionado antes de instalar y revisar los pendientes documentados. El archivo `.env` se crea y edita en el
servidor. No copiar el perfil local de pruebas al sitio público.

Validar e instalar:

```bash
sh ./scripts/preflight.sh
sh ./scripts/install.sh
```

El instalador construye las imágenes, inicia PostgreSQL y Redis, prepara el
código compartido, instala la base con la CLI de Moodle e inicia web y cron.
La comprobación HTTP se realiza después de activar el proxy HTTPS.

Después de instalar y publicar por HTTPS, revisar los ajustes desde Administración.
El usuario administrador inicial es `admin`. En Moodle 5.2.3,
el acceso de la app móvil se activa por defecto si el sitio usa HTTPS. Para
mantenerlo desactivado, desmarcar «Habilitar servicios web para dispositivos móviles»
en Características avanzadas. Esto conserva el acceso desde navegadores móviles.
Configurar el servidor SMTP, el tipo de seguridad, la autenticación, el usuario,
la contraseña y el remitente en «Configuración de correo saliente». Guardar esas
credenciales por separado del repositorio; los seis campos de `.env.example`
siguen siendo los datos de instalación.

Los datos del sitio y del administrador son valores iniciales: cambiar esos
campos en `.env` no actualiza por sí solo la cuenta ni el sitio ya instalado.
Gestionar esos cambios desde Moodle y actualizar por separado la documentación
privada de reinstalación.

## Publicación HTTPS y comprobaciones

Para publicar mediante Nginx, configurar el proxy central del servidor según
la URL definitiva y comprobar `nginx -t` antes de recargar. Mantener el puerto 18080 ligado a
`127.0.0.1`; PostgreSQL y Redis no publican puertos del host.
En un host que ya sirve otros dominios, crear un bloque `server_name` exclusivo
para el subdominio Moodle y conservar los bloques existentes. Para solicitar el
certificado con Certbot en modo `--webroot`, habilitar primero la ruta
`/.well-known/acme-challenge/` por HTTP; un bloque temporal que devuelva 503
en el resto de rutas mostrará ese error hasta completar la instalación. Después
de emitir el certificado, activar el bloque HTTPS con proxy a
`http://127.0.0.1:18080`, `proxy_set_header Host $host`,
`proxy_set_header X-Forwarded-Proto https` y `client_max_body_size 300M`,
acorde con el límite de petición predeterminado de Moodle. Si se cambia
`MOODLE_MAX_REQUEST_MB`, ajustar también el límite del Nginx central.
Ejecutar `nginx -t`, recargar Nginx y comprobar desde otra máquina
el inicio de sesión HTTPS y la redirección HTTP a HTTPS.

Desde la raíz del clon, con la URL pública accesible:

```bash
sh ./scripts/status.sh
sh ./scripts/release-info.sh
sh ./scripts/smoke-test.sh
docker compose -f compose.yaml --env-file .env --env-file releases/release.env exec -T --user www-data app php /var/www/moodle/public/admin/cli/checks.php
```

La prueba de humo verifica la base, Redis, el runtime, los permisos del código,
el acceso HTTP y las rutas internas protegidas. Revisar también los informes
de seguridad desde Administración.

Probar el acceso HTTPS real, el inicio de sesión, la creación y descarga de
contenido con una cuenta de usuario final, el correo saliente y la recuperación
de contraseña. El código de solo lectura protege los archivos de la aplicación;
PostgreSQL y `moodledata` siguen permitiendo crear cursos, usuarios y contenido.
Antes de recibir usuarios, disponer de copias externas al servidor y comprobar la
restauración conjunta de base, `moodledata` y código con plugins. El estado de
estas comprobaciones debe registrarse en la documentación operativa externa.

## Arranque de una instalación existente

```bash
sh ./scripts/start.sh
sh ./scripts/status.sh
sh ./scripts/smoke-test.sh
```

`start.sh` inicia los servicios sin reinstalar la base. `install.sh` se usa
únicamente para un proyecto nuevo. Conservar el nombre del proyecto Compose,
los tres volúmenes y la configuración de base de datos de una instalación
existente. Cambiar la contraseña de PostgreSQL solo en `.env` no cambia la
contraseña del rol almacenada en la base.

## Respaldo y recuperación

En una ventana de mantenimiento, con los servicios activos:

```bash
sh ./scripts/backup.sh
```

El script detiene temporalmente `web`, `app` y `cron`, respalda PostgreSQL,
`moodledata` y `moodle-code`, y vuelve a iniciar los servicios. Conserva los
plugins y temas instalados junto con el código. El destino predeterminado es
`backups/FECHA_HORA`; comprobar su integridad sustituyendo ese nombre por
la carpeta indicada al terminar:

```bash
(cd backups/FECHA_HORA && sha256sum -c SHA256SUMS)
sh ./scripts/status.sh
sh ./scripts/smoke-test.sh
```

Guardar una copia fuera del servidor y conservar el `.env` privado por separado:
el respaldo no lo incluye. Este procedimiento es manual; la frecuencia y
retención se definen en la documentación operativa externa.

La recuperación debe usar un proyecto Compose aislado y los tres componentes
del mismo respaldo: base, `moodledata` y `moodle-code`, junto con su revisión e
imágenes correspondientes. No restaurar sobre los volúmenes del sitio activo.
El procedimiento detallado y la evidencia del ensayo se conservan en la
documentación operativa externa. Validar la base, los archivos y el acceso antes
de cambiar el proxy hacia el sitio recuperado.

## Instalar plugins desde Administración

En operación normal `app`, `web` y `cron` leen `moodle-code` sin permiso de
escritura. Para instalar un plugin compatible con Moodle 5.2.3, probarlo primero
en desarrollo y respaldar base, `moodledata` y código. Abrir la ventana solo el
tiempo necesario. Desde la raíz del clon, con el `.env` seleccionado:

```bash
docker compose -f compose.yaml -f compose.plugins.yaml --env-file .env --env-file releases/release.env up -d --no-deps --force-recreate app
docker compose -f compose.yaml -f compose.plugins.yaml --env-file .env --env-file releases/release.env exec -T --user www-data app php /usr/local/bin/check-runtime.php
```

Instalar el ZIP desde Administración > Plugins > Instalar plugins, confirmar
las pantallas de actualización y comprobar el sitio. Cerrar la ventana incluso
si falla la instalación:

```bash
docker compose -f compose.yaml --env-file .env --env-file releases/release.env up -d --no-deps --force-recreate app
docker compose -f compose.yaml --env-file .env --env-file releases/release.env exec -T --user www-data app php /usr/local/bin/check-runtime.php
```

`--no-deps` evita tocar los demás servicios. Esperar a que `app` esté saludable
antes de ejecutar la comprobación de runtime o acceder al instalador de plugins.
Consultar su estado incluyendo ambos archivos de entorno:

```bash
docker compose -f compose.yaml --env-file .env --env-file releases/release.env ps
```

Los plugins persisten en el volumen `moodle-code`.
No ejecutar `docker compose up` con `compose.plugins.yaml` como configuración
habitual.
