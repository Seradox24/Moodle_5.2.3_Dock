# Moodle 5.2.3: despliegue y pruebas

Este repositorio contiene el despliegue Docker de Moodle. Los cambios se
preparan en `dev`, rama `refactorizacion`; `produccion` no se modifica durante
este trabajo. La documentación histórica está en
`D:\Servidor\documentacion general\Moodle`, fuera de Git.

## Archivos necesarios

- `compose.yaml`: servicios web, PHP, cron, PostgreSQL y Redis.
- `Dockerfile`, `docker/` y `config/`: imágenes y configuración de Moodle.
- `releases/release.env`: versiones y referencias fijadas de las imágenes.
- `.env.example`: plantilla única, sin contraseñas reales.
- `scripts/`: instalación, validación, operación y copia de seguridad.

No subir archivos `.env`, respaldos, bases de datos ni `moodledata` a Git.
Los tres volúmenes de Compose guardan la base, los archivos de Moodle y el
código compartido; `docker compose down -v` los elimina.

## Desarrollo local en Windows

Requisitos: Docker Desktop con motor Linux, Git y PowerShell. Desde
`D:\Servidor\Moodle_5.2.3_Dock\dev`:

```powershell
Copy-Item .env.example .env
notepad .env
```

Este `.env` de prueba se completa manualmente. Usar contraseñas privadas y
diferentes, un correo propio y los valores siguientes para aislar los datos de
producción y acceder localmente:

```dotenv
COMPOSE_PROJECT_NAME=lms-moodle-dev
IMAGE_NAMESPACE=lmsdev
MOODLE_WWWROOT=http://localhost:18080
MOODLE_SSLPROXY=false
MOODLE_REVERSEPROXY=true
```

Antes de crear datos, confirmar que no hay contenedores ni volúmenes del
proyecto `lms-moodle-dev`. Estos comandos deben devolver listas vacías:

```powershell
docker ps -a --filter 'label=com.docker.compose.project=lms-moodle-dev' --format '{{.Names}}'
docker volume ls --filter 'label=com.docker.compose.project=lms-moodle-dev' --format '{{.Name}}'
```

Si aparece algún recurso, se trata de una instalación existente o incompleta;
revisarlo antes de continuar. Comprobar también que el puerto local 18080 esté
libre. El script `scripts/windows/clean-project.ps1` permite limpiar un
proyecto de prueba después de revisar sus opciones.

Desde PowerShell, en la raíz del clon, ejecutar la instalación inicial con
los mismos servicios y el mismo instalador de Moodle que usa Linux:

```powershell
function Invoke-MoodleCompose {
    docker compose --env-file .env --env-file releases/release.env @args
    if ($LASTEXITCODE -ne 0) { throw "Falló Docker Compose: $($args -join ' ')" }
}
Invoke-MoodleCompose config --quiet
Invoke-MoodleCompose build
Invoke-MoodleCompose up -d db redis
Invoke-MoodleCompose up -d --wait app
Invoke-MoodleCompose exec -T --user www-data app sh /usr/local/bin/install-database.sh
Invoke-MoodleCompose up -d --wait web cron
.\scripts\windows\smoke-test.ps1 -EnvFile .env
```

Ejecutar la instalación de base de datos una sola vez por proyecto nuevo.
Abrir `http://localhost:18080`. Para un proyecto que ya tiene datos, usar
`.\scripts\windows\start.ps1 -EnvFile .env`, sin repetir el instalador.

## Producción en Ubuntu

Requisitos: Docker Engine con el plugin Compose, Git, conexión de salida para
construir las imágenes, Nginx del host y una URL definitiva para Moodle.
Clonar el repositorio en `/srv/plataforma/moodle`:

```bash
git clone https://github.com/Seradox24/Moodle_5.2.3_Dock.git /srv/plataforma/moodle
cd /srv/plataforma/moodle
cp .env.example .env
chmod 600 .env
```

Editar `.env` y completar al menos:

- `POSTGRES_PASSWORD` y `MOODLE_ADMIN_PASSWORD`: contraseñas fuertes y distintas.
- `MOODLE_SITE_FULLNAME`, `MOODLE_SITE_SHORTNAME` y `MOODLE_ADMIN_EMAIL`.
- `MOODLE_WWWROOT`: URL pública definitiva asignada por el Nginx central, por ejemplo `https://moodle.tudominio.cl`.

Compose fija el puerto `127.0.0.1:18080` y los valores de proxy, Redis y
proyecto para producción. No agregarlos al `.env` salvo una excepción
documentada. El entorno local generado con `sh scripts/prepare-env.sh` usa un
proyecto distinto y `http://localhost:18080`.

La URL pública debe resolver hacia el servidor; `localhost:18080` es solo el
destino interno del Nginx central, nunca la URL que ven los usuarios.
Preparar DNS y certificado para el dominio elegido antes de publicar Moodle.

Validar e instalar:

```bash
sh ./scripts/preflight.sh
sh ./scripts/install.sh
sh ./scripts/smoke-test.sh
sh ./scripts/backup.sh
```

`install.sh` realiza una instalación inicial; para iniciar una instalación
existente usar `sh ./scripts/start.sh`. La base de datos y `moodledata` deben
respaldarse también fuera del servidor y restaurarse juntos. Nunca volver a
ejecutar una instalación inicial sobre volúmenes con datos de producción.

Para publicar mediante Nginx, configurar el proxy central del servidor según
la URL definitiva y comprobar `nginx -t` antes de recargar. Mantener el puerto 18080 ligado a
`127.0.0.1`; PostgreSQL y Redis no publican puertos del host.

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

`--no-deps` evita tocar los demás servicios. Confirmar con `docker compose ps`
que `app` esté saludable. Los plugins persisten en el volumen `moodle-code`.
No ejecutar `docker compose up` con `compose.plugins.yaml` como configuración
habitual.

## Pruebas en el servidor sin publicar el sitio

Para una instalación desechable dentro de `/srv/plataforma/moodle`, ejecutar
`sh scripts/prepare-env.sh`, revisar el `.env` privado y luego
`sh scripts/install.sh`. La URL de prueba queda en `localhost:18080` y solo se
consulta desde el servidor o por un túnel SSH. Registrar cada ciclo en
`docs/validation-log.md`; guardar los resultados operativos sin credenciales
en `test-runs/`, que Git ignora.

En un perfil con `MOODLE_WWWROOT=http://localhost:18080`, la comprobación
`admin/cli/checks.php` ejecutada dentro de `app` no puede acceder al puerto del
host: allí `localhost` designa al contenedor. Para esta prueba local, el smoke
test consulta las rutas reales desde el host. En producción, con URL pública,
volver a ejecutar las comprobaciones CLI de Moodle.

## Flujo de cambios de esta rama

1. Modificar y revisar en `dev`, rama `refactorizacion`.
2. Probar una instalación local aislada; conservar sus volúmenes mientras sean útiles.
3. Publicar y desplegar solo la revisión validada, con respaldo previo de los datos existentes.
