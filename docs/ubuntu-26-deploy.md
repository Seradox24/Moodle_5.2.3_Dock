# Despliegue en Ubuntu (servidor local)

Guía para Ubuntu 26.04 LTS (Resolute). Acceso directo por IP, sin dominio ni
TLS en esta etapa.

Procedimiento paso a paso desde cero, con verificaciones en cada etapa:
ver `deploy-runbook.md`.

## 1. Requisitos

- Ubuntu Server con IP fija en la LAN.
- Docker Engine + plugin `docker compose` moderno (v2.20+ o posterior).
- Puerto `18080` alcanzable desde la LAN (se publica solo en la IP fija; ver sección 3).

No se instala PHP, PostgreSQL ni Redis en el host: todo corre en contenedores.

## 2. Instalar Docker Engine (repositorio oficial)

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Verificar:

```bash
docker --version
docker compose version
```

Opcional, usar Docker sin `sudo`:

```bash
sudo usermod -aG docker "$USER"
# cerrar sesión y volver a entrar
```

Docker queda habilitado al arranque (`systemctl is-enabled docker`); junto con
`restart: unless-stopped`, el stack levanta solo después de un reinicio.

Referencia oficial, que incluye soporte para Ubuntu 26.04:
https://docs.docker.com/engine/install/ubuntu/

## 3. Publicación en la LAN

El perfil privado publica únicamente en la IP fija `192.168.50.11:18080`.
Comprobar con `ip -4 addr` que esa IP pertenece al host antes de levantarlo.
Para otro servidor, cambiar `MOODLE_HTTP_BIND` y `MOODLE_WWWROOT` juntos.

Los puertos publicados por Docker pueden saltarse las reglas de UFW; una regla
`ufw allow/deny 18080` por sí sola no define su alcance. Si hay restricciones de
origen, integrarlas en la política Docker (`DOCKER-USER` con iptables) o en el
firewall de la red. Conservar las reglas que ya usan los demás servicios.
Referencia: https://docs.docker.com/engine/network/packet-filtering-firewalls/

## 4. Preparar el stack

```bash
sudo mkdir -p /opt/lms/moodle
sudo chown "$USER":"$USER" /opt/lms/moodle
# copiar o clonar el contenido del repositorio en /opt/lms/moodle
cd /opt/lms/moodle
# Si se usa el .env privado preparado, copiar/pegarlo aquí.
# Solo para un entorno nuevo sin ese archivo:
cp -n .env.example .env
chmod 600 .env
nano .env
```

Valores obligatorios en `.env`:

```text
MOODLE_WWWROOT=http://<IP-DEL-SERVIDOR>:18080
POSTGRES_PASSWORD=<contraseña fuerte>
MOODLE_ADMIN_PASSWORD=<contraseña fuerte>
MOODLE_ADMIN_EMAIL=<correo real>
MOODLE_SITE_FULLNAME=<nombre completo real>
MOODLE_SITE_SHORTNAME=<nombre corto real>
```

El `.env` privado preparado contiene IP y contraseñas reales, instalación de
plugins/temas activada y correo saliente deshabilitado. Quedan por completar los
nombres del sitio y el correo administrador. Ver `production-config.md`.

## 5. Validar e instalar

```bash
sh ./scripts/preflight.sh
sh ./scripts/install.sh
```

El instalador compila las imágenes (Moodle 5.2.3 verificado por commit), levanta
PostgreSQL y Redis, inicializa `moodle-code` con permisos para instalar plugins,
instala la base de datos con el CLI de Moodle y arranca web + cron. No vuelve a
instalar si se reinician contenedores. Se invocan los scripts con `sh` para no
depender del bit ejecutable al copiar el proyecto desde Windows.

## 6. Verificación

```bash
sh ./scripts/smoke-test.sh
curl -I http://192.168.50.11:18080/login/index.php
```

Acceder desde un equipo de la LAN a `http://192.168.50.11:18080` e iniciar
sesión con `MOODLE_ADMIN_USER` / `MOODLE_ADMIN_PASSWORD`.

## 7. Operación

```bash
docker compose up -d
docker compose down
docker compose logs -f web app cron db redis
```

Backup manual:

```bash
sh ./scripts/backup.sh
```

El backup pausa las escrituras de web/app/cron y guarda los tres volúmenes.
`docker compose down -v` elimina base, datos y código con plugins y temas.
Ver `operations.md` para restauración y `plugins.md` para administración de plugins.

## 8. Etapa futura (dominio + TLS)

Cuando exista dominio y Nginx host con TLS:

```text
MOODLE_HTTP_BIND=127.0.0.1
MOODLE_WWWROOT=https://<dominio>
MOODLE_REVERSEPROXY=true
MOODLE_SSLPROXY=true
```

El Nginx del host debe hacer reverse proxy hacia `http://127.0.0.1:18080`
preservando host y esquema originales.

## Notas

- Los scripts son POSIX `sh`; requieren `docker`, `curl` y `ss` (iproute2).
- `MOODLE_ROUTER_CONFIGURED=true` requiere que el fallback a `r.php` del Nginx
  interno se mantenga tal cual (`docker/nginx/default.conf`).
- `MOODLE_REVERSEPROXY=true` es obligatorio porque el puerto publicado
  (`MOODLE_HTTP_PORT`) difiere del puerto interno 80 del contenedor.
