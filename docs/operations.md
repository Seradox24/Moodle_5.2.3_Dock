# Operación y respaldos

## Inicio, parada y logs

```bash
docker compose up -d --wait
docker compose down
docker compose logs -f web app cron db redis
docker compose logs code-init
```

Los tres volúmenes (`postgres-data`, `moodledata`, `moodle-code`) sobreviven a
`down`. El inicializador `code-init` termina con `Exited (0)`; los otros cinco
servicios permanecen activos. Un cambio de `COMPOSE_PROJECT_NAME` crea otro
conjunto de volúmenes, por lo que debe conservarse el nombre del proyecto.

`docker compose down -v` elimina los tres volúmenes, incluyendo plugins y temas.

## Reconstruir configuración o runtime (mismo core)

```bash
docker compose build
docker compose up -d --wait
sh scripts/smoke-test.sh
```

Esto conserva el código persistente. Para cambiar el core consultar `plugins.md`;
una nueva imagen no reemplaza automáticamente `moodle-code`.

## Backup consistente

Linux:

```bash
sh scripts/backup.sh
```

Windows:

```powershell
.\scripts\windows\backup.ps1
```

El script requiere `db`, `app`, `web` y `cron` activos. **Pausa web, app y cron
durante el respaldo**, manteniendo PostgreSQL activo para `pg_dump`. Copia:

- `database.dump`: base PostgreSQL en formato custom.
- `moodledata.tar.gz`: archivos, sesiones y datos de Moodle.
- `moodle-code.tar.gz`: código compartido, plugins, temas y marcador de versión.
- `images.txt`: inventario de imágenes usadas.
- `SHA256SUMS`: sumas de los cuatro archivos anteriores.

Reanuda los servicios al terminar o fallar. Ante un cierre forzado del proceso,
revisar `docker compose ps` y ejecutar `docker compose start app cron web` si
quedaron detenidos. Un backup sin `SHA256SUMS` se considera incompleto.

Guardar también el `.env` de forma privada y las imágenes/tag/commit utilizados.
El script no incluye el `.env`; el `config.php` real vive en la imagen y sus
valores llegan desde ese archivo privado.

## Restauración en un entorno vacío (Linux)

Usar el mismo commit del repo, la misma referencia del core y los mismos plugins
que el respaldo. Comprobar antes `sha256sum -c SHA256SUMS` desde el directorio del
backup. Configurar el `.env` correspondiente en la raíz del proyecto.

Con las imágenes ya disponibles y volúmenes nuevos/vacíos:

```bash
docker compose up -d --wait db redis
docker compose exec -T db sh -c 'pg_restore --exit-on-error --no-owner -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < backups/FECHA/database.dump
docker compose run --rm -T --no-deps --entrypoint tar app -C /var/moodledata -xzpf - < backups/FECHA/moodledata.tar.gz
docker compose run --rm -T --no-deps --entrypoint tar app -C /var/www/moodle/public -xzpf - < backups/FECHA/moodle-code.tar.gz
docker compose up -d --wait
sh scripts/smoke-test.sh
```

Los `tar` se restauran como root para preservar propietarios y modos. El
inicializador verifica el marcador de core ya restaurado y conserva los plugins.
No ejecutar el instalador de base de datos sobre una restauración. Ensayar la
restauración completa en otro entorno antes de usarla como recuperación real.
