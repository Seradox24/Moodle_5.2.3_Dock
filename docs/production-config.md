# Configuración de producción

Archivo privado: `.env` en la raíz. Está excluido de Git y del contexto Docker;
las imágenes obtienen los valores al crear los contenedores.

## Perfil del servidor confirmado

| Variable | Valor |
|---|---|
| `COMPOSE_PROJECT_NAME` | `lms-moodle` |
| `IMAGE_NAMESPACE` | `lms` |
| `MOODLE_WWWROOT` | `http://192.168.50.11:18080` |
| `MOODLE_HTTP_BIND` | `192.168.50.11` |
| `MOODLE_HTTP_PORT` | `18080` |
| `MOODLE_REVERSEPROXY` | `true` (puerto externo distinto del interno) |
| `MOODLE_SSLPROXY` | `false` (HTTP en la LAN) |
| `MOODLE_ROUTER_CONFIGURED` | `true` (fallback existente a `r.php`) |
| `MOODLE_PLUGIN_INSTALL` | `true` (instalación de plugins/temas desde Moodle) |
| `MOODLE_MAIL_ENABLED` | `false` (sin SMTP por ahora) |
| `MOODLE_REDIS_SESSIONS` | `false` (sesiones en `moodledata`) |
| `TZ` | `America/Santiago` |

El `.env` privado contiene contraseñas generadas para este despliegue. No se
incluyen contraseñas reales en esta documentación ni en `.env.example`.

**Pendientes de definición por el responsable:** `MOODLE_ADMIN_EMAIL`,
`MOODLE_SITE_FULLNAME` y `MOODLE_SITE_SHORTNAME`. Están vacíos en el `.env`
privado; preflight los detecta antes de instalar. No representan valores de prueba.

## Inventario de las demás variables

| Variables | Uso |
|---|---|
| `MOODLE_GIT_TAG`, `MOODLE_GIT_REF` | Release y commit de Moodle verificado al construir. Cambiar el core requiere el procedimiento de `plugins.md`. |
| `PHP_IMAGE`, `NGINX_IMAGE`, `POSTGRES_IMAGE`, `REDIS_IMAGE` | Imágenes base. Admiten `tag@sha256:...` para fijar digests validados. |
| `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` | Base y usuario privados del servicio; actualmente `moodle` / `moodle`. |
| `MOODLE_DB_PREFIX` | Prefijo de tablas, `mdl_`. |
| `MOODLE_ADMIN_USER`, `MOODLE_ADMIN_PASSWORD`, `MOODLE_ADMIN_EMAIL` | Administrador de la instalación inicial. |
| `MOODLE_SITE_FULLNAME`, `MOODLE_SITE_SHORTNAME`, `MOODLE_LANG` | Identidad inicial del sitio e idioma (`es`). |
| `MOODLE_REDIS_HOST`, `MOODLE_REDIS_PORT` | Servicio interno `redis:6379`. |
| `MOODLE_REDIS_DATABASE`, `MOODLE_REDIS_PREFIX` | Separación lógica de sesiones cuando se habiliten. |
| `SSO_ENABLED`, `SSO_ISSUER_URL`, `SSO_CLIENT_ID`, `INTEGRATION_API_URL` | Reservas para futuras integraciones; todavía no conectan ningún servicio. |

`MOODLE_DB_HOST=db` y `MOODLE_DB_PORT=5432` se fijan en Compose: las conexiones
entre contenedores utilizan nombres internos, no la IP pública del servidor.

Las credenciales/nombres iniciales se aplican al instalar. Editar después
`MOODLE_ADMIN_PASSWORD` no cambia la contraseña de una cuenta ya creada;
tampoco cambia la de PostgreSQL en un volumen ya inicializado. Esos cambios
deben realizarse en cada servicio y reflejarse posteriormente en `.env`.

## Copiar al servidor

Crear `/opt/lms/moodle/.env`, pegar el contenido del archivo privado y completar
los tres campos pendientes. Protegerlo con `chmod 600 .env`.
Usar `sh scripts/preflight.sh --config-only` para validar esos valores.

Con `MOODLE_MAIL_ENABLED=false`, Moodle no enviará recuperaciones de contraseña
ni notificaciones por email. Cuando haya SMTP, configurarlo en Administración
del sitio → Servidor → Correo electrónico, cambiar la variable a `true` y
recrear `app` y `cron` con `docker compose up -d app cron`.

Cambiar el nombre de proyecto cambia también los volúmenes y redes usados.
Mantener `lms-moodle` para volver a utilizar los datos de esta instalación.
