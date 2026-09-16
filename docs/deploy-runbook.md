# Runbook: despliegue de Moodle en el servidor nuevo

Procedimiento ordenado desde cero. Ejecutar los comandos en el orden indicado
y verificar cada verificación (✓) antes de continuar. Servidor de destino:
Ubuntu 26.04 LTS, IP fija `192.168.50.11`, proyecto `lms-moodle` en
`/opt/lms/moodle`.

---

## 1. Conectar al servidor y ubicarse

Desde una PC de la LAN (PowerShell o SSH client):

```bash
ssh usuario@192.168.50.11
```

Verificar que estamos en el servidor correcto:

```bash
hostname
lsb_release -ds        # esperado: Ubuntu 26.04 LTS
ip -4 addr show | grep 192.168.50.11
```

hostname
lsb_release -ds
ip -4 addr show | grep 192.168.50.11

✓ Servidor correcto, Ubuntu 26.04 y la IP fija existen en el host.

## 2. Verificar el directorio de trabajo

```bash
pwd                     # normalmente /home/usuario
mkdir -p ~/workspace && cd ~/workspace
pwd                     # verificar: /home/usuario/workspace
```

✓ Estamos en un directorio conocido antes de instalar cualquier cosa.

## 3. Paquetes base (git, curl, certificados)

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git
```

Verificar:

```bash
git --version
curl --version | head -n 1
```

✓ `git` y `curl` instalados. (Se usan para clonar/copiar el proyecto y para el
smoke test; sin ellos, `preflight.sh` fallará con mensaje claro.)

## 4. Instalar Docker Engine + Compose (repositorio oficial)

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Verificar:

```bash
docker --version
docker compose version
sudo systemctl enable --now docker
sudo systemctl status docker --no-pager | head -n 5
sudo docker run --rm hello-world   # opcional: valida el motor
```

✓ Docker Engine activo y habilitado al arranque, plugin `compose` disponible.

## 5. Usuario sin sudo (recomendado)

```bash
sudo usermod -aG docker "$USER"
```

Cerrar la sesión y volver a entrar:

```bash
exit
ssh usuario@192.168.50.11
docker info | head -n 3    # ya sin sudo
```

✓ `docker info` funciona sin `sudo`. Si no se quiere re-entrar, continuar
usando `sudo docker` en los pasos siguientes.

## 6. Copiar el proyecto desde la PC (Windows)

El `.env` privado viaja con la copia. En PowerShell de la PC:

```powershell
cd D:\Servidor
scp -r Moodle_5.2.3_Dock usuario@192.168.50.11:/tmp/
```

De vuelta en el servidor:

```bash
sudo mkdir -p /opt/lms/moodle
sudo cp -a /tmp/Moodle_5.2.3_Dock/. /opt/lms/moodle/
sudo chown -R "$USER":"$USER" /opt/lms/moodle
rm -rf /tmp/Moodle_5.2.3_Dock
```

Verificar:

```bash
cd /opt/lms/moodle
pwd                      # debe ser /opt/lms/moodle
ls -la                   # debe verse compose.yaml, Dockerfile, .env, scripts/, docs/, docker/, config/, plugins/
```

✓ Proyecto en su ruta definitiva y propiedad del usuario.

> Alternativa futura: si el repositorio se publica en Git, se puede
> `git clone` aquí. El `.env` está ignorado por Git, así que en ese caso
> copiarlo aparte a `/opt/lms/moodle/.env` antes de continuar.

## 7. Completar el `.env`

```bash
cd /opt/lms/moodle && pwd
chmod 600 .env
nano .env
```

Completar SOLO estos tres valores (el resto ya está listo para producción):

```text
MOODLE_SITE_FULLNAME=<nombre completo del sitio>
MOODLE_SITE_SHORTNAME=<nombre corto>
MOODLE_ADMIN_EMAIL=<correo real del admin>
```

Verificar (no debe quedar ninguna línea vacía de esos tres campos):

```bash
grep -E '^MOODLE_(SITE_FULLNAME|SITE_SHORTNAME|ADMIN_EMAIL)=' .env
```

✓ Tres valores con contenido real. `MOODLE_WWWROOT` debe ser
`http://192.168.50.11:18080` y `MOODLE_HTTP_BIND=192.168.50.11`.

## 8. Preflight

```bash
cd /opt/lms/moodle && pwd
sh scripts/preflight.sh
```

Revisa Docker, Compose, `.env` completo y el puerto `18080` libre.

✓ Salida `Preflight OK.` Si falla, corregir lo que indica y repetir.

## 9. Instalar (build de imágenes + base de datos)

```bash
cd /opt/lms/moodle && pwd
sh scripts/install.sh
```

- Compila las imágenes `lms/moodle-web:5.2.3` y `lms/moodle-app:5.2.3`
  (5–15 min la primera vez).
- Inicializa el volumen compartido `moodle-code` con permisos para instalar
  plugins y temas.
- Levanta db, redis, app y ejecuta el instalador CLI de Moodle.
- Arranca web y cron.

✓ Salida `Fresh Moodle installation completed.` con la URL pública.

## 10. Smoke test

```bash
cd /opt/lms/moodle && pwd
sh scripts/smoke-test.sh
```

Verifica contenedores, PostgreSQL, Redis, versión de Moodle, extensiones PHP,
permisos de plugins y la página de login por la URL pública.

✓ `Smoke test completed.` sin errores (login HTTP 200).

## 11. Verificación manual desde la LAN

En un navegador de otra PC:

```text
http://192.168.50.11:18080
```

Iniciar sesión:

- Usuario: `admin` (valor de `MOODLE_ADMIN_USER`)
- Contraseña: valor de `MOODLE_ADMIN_PASSWORD` en el `.env`

✓ Login exitoso. Probar instalar un tema en Administración del sitio →
Apariencia → Temas → Instalar tema (validará la escritura en `moodle-code`).

## 12. Primer backup

```bash
cd /opt/lms/moodle && pwd
sh scripts/backup.sh
ls -la backups/ | tail -n 5
```

✓ Backup con `database.dump`, `moodledata.tar.gz`, `moodle-code.tar.gz`,
`images.txt` y `SHA256SUMS`.

## 13. Chequeos finales de operación

```bash
cd /opt/lms/moodle && pwd
docker compose ps                    # 5 servicios activos + code-init Exited (0)
docker compose logs --tail 20 web app cron
sudo systemctl is-enabled docker     # enabled: arranca solo tras reinicio
```

✓ Stack saludable, logs sin errores y arranque automático confirmado.

## 14. Reinicio del servidor (prueba recomendada antes de producción)

```bash
sudo reboot
```

Al volver (esperar 1–2 minutos):

```bash
ssh usuario@192.168.50.11
cd /opt/lms/moodle && pwd
docker compose ps                    # 5 servicios (healthy) + code-init Exited (0)
sh scripts/smoke-test.sh
```

Qué esperar y por qué funciona:

- `docker.service` está habilitado: el motor arranca en el boot.
- Los 5 servicios usan `restart: unless-stopped` y vuelven solos.
- `code-init` no se reinicia (es one-shot) y no hace falta: el volumen
  `moodle-code` ya está inicializado; `app` y `cron` verifican el marcador al
  arrancar y continúan.
- PostgreSQL recupera su estado solo (WAL) y Nginx re-resuelve la IP de `app`;
  es normal un 502 momentáneo en los primeros segundos hasta que `app` esté
  healthy.

✓ Tras el reinicio: contenedores arriba, login HTTP 200 y smoke test OK.

La IP del servidor debe mantenerse fija (reserva DHCP o IP estática). Si cambia,
actualizar `MOODLE_HTTP_BIND` y `MOODLE_WWWROOT` en `.env` y ejecutar
`docker compose up -d`.

---

## Resumen de rutas y puertos

| Elemento | Valor |
|---|---|
| Proyecto en disco | `/opt/lms/moodle` |
| Backups | `/opt/lms/moodle/backups/` |
| Acceso público | `http://192.168.50.11:18080` |
| Contenedores/volúmenes/redes | prefijo `lms-moodle_*` |
| Futuros servicios | `/opt/lms/{auth,api,lrs,analytics}` con puertos 18081–18084 |

## Problemas frecuentes

- **`Preflight` dice que faltan valores**: revisar paso 7; los tres campos no
  pueden quedar vacíos ni usar `example.com`.
- **Puerto 18080 en uso**: `ss -ltn | grep 18080` en el host y liberar o cambiar
  `MOODLE_HTTP_PORT`/`MOODLE_WWWROOT` juntos.
- **No abre desde otra PC**: confirmar que la IP `192.168.50.11` existe
  (`ip -4 addr`) y que la red no bloquea el puerto (Docker se salta UFW; ver
  `docs/ubuntu-26-deploy.md` §3).
- **El build falla por red**: el paso `moodle-source` descarga desde GitHub;
  validar salida a internet y reintentar.
