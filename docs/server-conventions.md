# Convenciones de despliegue en el servidor

Este stack se diseña para convivir con otros servicios y microservicios Docker en el mismo servidor.

## Nombre de proyecto

```text
lms-moodle
```

Compose utilizará este prefijo para redes, volúmenes y contenedores administrados.

Ejemplos esperados:

```text
lms-moodle_application
lms-moodle_data
lms-moodle_postgres-data
lms-moodle_moodledata
lms-moodle_moodle-code
```

No se utiliza `container_name`, evitando colisiones globales con otros stacks.

## Rutas en el host

Cada servicio vive en su propio directorio bajo una base común de la plataforma:

```text
/opt/lms/
├── moodle/        ← este stack (compose.yaml, .env, scripts, backups/)
├── auth/          ← futuro Identity/SSO
├── api/           ← futuro Backend API
├── lrs/           ← futuro LRS
├── analytics/     ← futuro Dashboard/analytics
└── edge/          ← futuro Nginx host único (dominio + TLS)
```

La ruta en disco es una convención de orden; el aislamiento real lo dan
`COMPOSE_PROJECT_NAME`, las redes y los volúmenes de cada stack. Los backups se
generan por defecto dentro de `backups/` en el directorio de cada servicio.

## Puerto publicado

Mientras no exista dominio ni Nginx host con TLS, Moodle se publica directamente por IP:

```text
MOODLE_HTTP_BIND=0.0.0.0
MOODLE_HTTP_PORT=18080
```

En producción se puede usar la IP LAN concreta como `MOODLE_HTTP_BIND`; así
se publica el puerto únicamente en esa interfaz del host.

Acceso:

```text
http://<IP-del-servidor>:18080
```

El puerto `80` del contenedor `web` no se publica en el puerto `80` del host.

Cuando más adelante se agregue Nginx host con TLS y dominio, usar:

```text
MOODLE_HTTP_BIND=127.0.0.1
MOODLE_HTTP_PORT=18080
MOODLE_WWWROOT=https://<dominio>
MOODLE_REVERSEPROXY=true
MOODLE_SSLPROXY=true
```

Y hacer reverse proxy desde el Nginx del host hacia:

```text
http://127.0.0.1:18080
```

## Convención propuesta para futuros stacks

La siguiente tabla es una convención de planificación, no una reserva técnica automática. Mientras no exista Nginx host, Moodle se publica en `0.0.0.0:18080` para acceso directo por IP; la columna muestra el loopback previsto cuando se agregue el reverse proxy:

| Servicio | Loopback sugerido |
|---|---:|
| Moodle | `127.0.0.1:18080` |
| Identity / SSO | `127.0.0.1:18081` |
| Backend API | `127.0.0.1:18082` |
| LRS | `127.0.0.1:18083` |
| Instructor Dashboard | `127.0.0.1:18084` |

Los puertos deben verificarse antes de desplegar cada stack.

## Redes

Moodle mantiene redes propias:

```text
application
data
```

Compose las prefija con el nombre del proyecto.

La red `data` es interna y contiene:

```text
app
cron
db
redis
```

`db` y `redis` no publican puertos al host.

## Imágenes locales

Las imágenes Moodle se etiquetan:

```text
lms/moodle-web:5.2.3
lms/moodle-app:5.2.3
```

Esto evita nombres genéricos y permite identificar claramente el propietario lógico de la imagen.

El prefijo se configura con `IMAGE_NAMESPACE=lms`. `code-init`, `app` y `cron`
utilizan la misma imagen de aplicación. `code-init` es un proceso de una sola
ejecución; es normal que quede en estado `Exited (0)`.

## Volúmenes

Los volúmenes son administrados por Compose y quedan asociados al proyecto.

Conceptualmente:

```text
lms-moodle_postgres-data
lms-moodle_moodledata
lms-moodle_moodle-code
```

No se utilizan nombres globales externos en esta primera versión.

## Convivencia con otros servicios

Cada futuro sistema debe preferir:

- su propio `COMPOSE_PROJECT_NAME`;
- sus propias redes privadas;
- sus propios volúmenes;
- sus propias credenciales;
- sus propios roles/bases;
- un puerto loopback distinto si necesita exposición al Nginx del host.

Ejemplos:

```text
lms-auth
lms-api
lms-lrs
lms-analytics
```

Los stacks sólo compartirán redes de forma explícita cuando exista una necesidad arquitectónica concreta.
