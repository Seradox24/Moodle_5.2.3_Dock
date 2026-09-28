# Moodle 5.2.3: despliegue y pruebas

Este repositorio contiene el despliegue Docker de Moodle. `produccion` es la
única carpeta donde se editan y publican cambios. `dev` es un clon descartable
del repositorio de GitHub para pruebas en Windows. La documentación histórica
está en `D:\Servidor\documentacion general\Moodle`, fuera de Git.

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
`D:\Servidor\Moodle_5.2.3_Dock`:

```powershell
git clone https://github.com/Seradox24/Moodle_5.2.3_Dock.git dev
Set-Location dev
.\scripts\windows\prepare-env.ps1
```

El último comando crea `.env` con contraseñas aleatorias.
Antes de instalar, cambiar `MOODLE_ADMIN_EMAIL` por un correo propio y revisar
`MOODLE_WWWROOT=http://localhost:18080` y
`COMPOSE_PROJECT_NAME=lms-moodle-dev`. Después:

```powershell
.\scripts\windows\preflight.ps1 -EnvFile .env -ConfigOnly
.\scripts\windows\install.ps1 -EnvFile .env
.\scripts\windows\smoke-test.ps1 -EnvFile .env
```

Abrir `http://localhost:18080`. Para probar una revisión nueva, editar y
publicar en `produccion`, bajar el stack de `dev` y clonar de nuevo la
revisión publicada. Una instalación totalmente nueva también requiere retirar
los volúmenes de prueba; guardar antes lo que se necesite. El script
`scripts/windows/clean-project.ps1` permite hacer esa limpieza tras revisar
sus opciones.

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
- `MOODLE_WWWROOT`: URL pública final, por ejemplo `https://moodle.midominio.cl`.
- `MOODLE_HTTP_BIND=127.0.0.1` y `MOODLE_HTTP_PORT=18080` si Nginx sirve la URL.
- `MOODLE_SSLPROXY=true` cuando Nginx termina HTTPS.
- `COMPOSE_PROJECT_NAME=lms-moodle` para aislar este stack.

No instalar con `MOODLE_WWWROOT=http://localhost:18080` en producción.
La URL pública debe resolver hacia el servidor. El certificado actual para
`147.93.132.78` cubre esa IP, no un futuro subdominio. Preparar DNS y
certificado para el dominio elegido antes de publicar Moodle.

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

## Flujo único de cambios

1. Modificar archivos únicamente en `produccion`.
2. Revisar y validar la configuración, luego confirmar y subir a GitHub.
3. En `dev`, recrear el clon desde GitHub y repetir la instalación de prueba.
4. Tras aprobar la prueba, desplegar exactamente la revisión publicada.

No copiar cambios de `dev` hacia producción. Si una prueba revela un
problema, corregirlo en `produccion` y volver a crear el clon de prueba.
