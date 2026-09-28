# Moodle 5.2.3 con Docker

Este repositorio reúne lo necesario para construir y ejecutar Moodle 5.2.3 con
Docker Compose. `compose.yaml` define los contenedores; `Dockerfile` construye
las imágenes de Moodle y Nginx; `releases/release.env` fija las versiones.
La instalación detallada está en **[deploy-runbook.md](deploy-runbook.md)**.

## Qué contiene el stack

| Componente | Función |
| --- | --- |
| `web` | Nginx dentro de Docker. Recibe las peticiones y sirve los archivos públicos de Moodle. |
| `app` | Moodle con PHP-FPM. Ejecuta la aplicación y se conecta a PostgreSQL y Redis. |
| `cron` | Ejecuta las tareas programadas de Moodle usando la misma imagen de `app`. |
| `db` | PostgreSQL 16. Guarda la base de datos en el volumen `postgres-data`. |
| `redis` | Redis disponible para sesiones; el ejemplo lo deja desactivado inicialmente. |
| `code-init` | Copia el código verificado de Moodle al volumen compartido la primera vez y termina. |

Compose crea dos redes de tipo `bridge`: `application` conecta `web` con
`app`, mientras que `data` conecta `app` y `cron` con PostgreSQL y Redis.
La red `data` es interna; la base de datos y Redis no publican puertos en el
servidor. Solo `web` publica el puerto configurado para el proxy del host.

## Estructura esperada en el servidor

```text
/srv/plataforma/moodle/          ← clon de este repositorio
├── compose.yaml
├── Dockerfile
├── .env                     ← configuración privada creada desde .env.example
├── .env.example
├── config/                  ← configuración de Moodle
├── docker/                  ← archivos para construir las imágenes
├── releases/release.env     ← versiones fijadas
├── scripts/                 ← instalación, comprobaciones y respaldos
└── deploy/                  ← ejemplo de configuración del Nginx del host

```

Compose crea tres **volúmenes administrados por Docker** al iniciar el stack.
Son espacios de almacenamiento del servidor, no carpetas del clon de Git. Con
`COMPOSE_PROJECT_NAME=lms-moodle`, sus nombres y contenidos son:

| Volumen | Qué conserva |
| --- | --- |
| `lms-moodle_postgres-data` | Las tablas, usuarios y configuración guardados en PostgreSQL. |
| `lms-moodle_moodledata` | Los archivos que Moodle almacena fuera del código, incluidos los subidos por usuarios. |
| `lms-moodle_moodle-code` | La copia de los archivos públicos de Moodle que comparten los contenedores, junto con los plugins y temas instalados allí. |

Los volúmenes permanecen al detener o recrear contenedores. La opción
`down -v` de Compose **también elimina esos datos**, por lo que solo debe
usarse en un entorno de prueba que se quiera reiniciar. En producción,
respaldar la base de datos, `moodledata` y el código compartido antes de
cualquier cambio que afecte los volúmenes. El prefijo de sus nombres cambia si se modifica
`COMPOSE_PROJECT_NAME`.

Nginx del host recibe HTTPS y reenvía a `web` por `127.0.0.1:18080`; su
configuración activa vive fuera de este repositorio.

## Crear el archivo `.env`

En Ubuntu, desde la raíz del clon:

```bash
cp .env.example .env
chmod 600 .env
nano .env
```

Sustituye los valores de ejemplo antes de instalar:

- `POSTGRES_PASSWORD` y `MOODLE_ADMIN_PASSWORD`: dos contraseñas fuertes y distintas.
- `MOODLE_SITE_FULLNAME`, `MOODLE_SITE_SHORTNAME` y `MOODLE_ADMIN_EMAIL`: identidad y correo reales del sitio.
- `MOODLE_WWWROOT`: URL pública definitiva de Moodle. El valor `localhost` del ejemplo es solo para pruebas locales.
- `MOODLE_HTTP_BIND=127.0.0.1` y `MOODLE_HTTP_PORT=18080` cuando Nginx del host actúa como proxy.
- `MOODLE_SSLPROXY=true` si la URL pública usa HTTPS detrás de ese proxy. Mantén `MOODLE_REVERSEPROXY=true`.
- `COMPOSE_PROJECT_NAME=lms-moodle` para dar un nombre propio a contenedores, redes y volúmenes.

El `.env` contiene credenciales y está excluido de Git. Los valores de
`releases/release.env` pertenecen a la versión del repositorio y no se copian
al `.env`. Para crear el entorno de prueba en Windows se usa
`environments/local.env.example`; el procedimiento también está en el
[runbook](deploy-runbook.md).
