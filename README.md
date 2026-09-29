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
| `redis` | Guarda las sesiones de Moodle en memoria. |
| `code-init` | Copia el código verificado de Moodle al volumen compartido la primera vez y termina. |

Compose crea dos redes de tipo `bridge`: `application` conecta `web` con
`app`, mientras que `data` conecta `app` y `cron` con PostgreSQL y Redis.
La red `data` es interna; la base de datos y Redis no publican puertos en el
servidor. Solo `web` publica el puerto configurado para el proxy del host.

> [!IMPORTANT]
> **Redis no tiene contraseña en esta configuración.** Solo se conecta a la red
> interna `data` y no publica el puerto `6379` en el host. Conserva ambas
> condiciones: no agregues `ports:` al servicio `redis` ni lo conectes a una
> red accesible desde otros proyectos. Si necesitas acceso externo, configura
> autenticación y revisa el aislamiento antes de exponerlo.

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
└── scripts/                 ← instalación, comprobaciones y respaldos

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

Las sesiones en Redis son temporales: al reiniciar Redis, los usuarios deberán
iniciar sesión de nuevo. Los cursos, usuarios y archivos permanecen en
PostgreSQL y `moodledata`.

Nginx del host recibe HTTPS y reenvía a `web` por `127.0.0.1:18080`; su
configuración activa vive fuera de este repositorio.

> [!IMPORTANT]
> **El límite de subida debe coincidir en ambos Nginx.** La plantilla permite
> archivos de hasta `MOODLE_MAX_UPLOAD_MB=256` MiB y peticiones de hasta
> `MOODLE_MAX_REQUEST_MB=300` MiB. En el bloque del Nginx central que envía
> tráfico a Moodle, configura al menos:
>
> ```nginx
> client_max_body_size 300M;
> ```
>
> Si el límite del Nginx central es menor, rechazará la petición antes de que
> llegue al contenedor. Si cambias `MOODLE_MAX_REQUEST_MB`, ajusta también este
> valor en el Nginx central.

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
- `MOODLE_WWWROOT`: URL pública definitiva asignada por el Nginx central. Es la dirección que usará Moodle en sus enlaces, aunque Nginx se conecte al contenedor por localhost.
- `MOODLE_HTTP_BIND=127.0.0.1` y `MOODLE_HTTP_PORT=18080` cuando Nginx del host actúa como proxy.
- `MOODLE_SSLPROXY=true` porque Nginx termina HTTPS. Mantén `MOODLE_REVERSEPROXY=true`.
- `COMPOSE_PROJECT_NAME=lms-moodle` para dar un nombre propio a contenedores, redes y volúmenes.

El `.env` contiene credenciales y está excluido de Git. Los valores de
`releases/release.env` pertenecen a la versión del repositorio y no se copian
al `.env`. La misma plantilla sirve para desarrollo: `prepare-env.ps1` crea
un `.env` privado con contraseñas aleatorias y un proyecto Compose distinto.
El procedimiento también está en el
[runbook](deploy-runbook.md).

Los plugins y temas opcionales se instalan desde la administración de Moodle
con una versión compatible. Sus archivos quedan en el volumen `moodle-code`.
