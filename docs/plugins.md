# Plugins, complementos y temas

## Instalación desde Moodle

`MOODLE_PLUGIN_INSTALL=true` permite usar Administración del sitio → Plugins →
Instalar plugins. Un tema se instala como plugin `theme`, con ZIP o desde el
directorio de Moodle cuando la descarga esté disponible. Después se selecciona
en Administración del sitio → Apariencia → Temas → Selector de temas.

Los paquetes deben ser compatibles con Moodle 5.2 y PHP 8.3. Completar el proceso
de actualización de la base de datos que presenta Moodle después de instalar.

Tras instalar o actualizar un plugin/tema:

```bash
docker compose exec -T --user www-data app php /var/www/moodle/admin/cli/purge_caches.php
docker compose restart cron
sh scripts/smoke-test.sh
```

Reiniciar cron recarga los procesos PHP de larga duración. OPcache en FPM
comprueba las modificaciones de código en cada petición.

## Dónde se guardan y cómo funcionan los permisos

- `moodle-code` contiene todo `public/`, incluyendo `theme`, `mod`, `local`,
  `admin/tool` y los demás tipos de plugins.
- `code-init` copia la fuente verificada en un volumen vacío; en siguientes
  arranques comprueba la referencia y conserva el contenido.
- PHP ejecuta como `www-data` (UID/GID 33), propietario del código compartido.
- Los directorios iniciales tienen modo `2770` (grupo heredado); los archivos
  permiten lectura/escritura del propietario y grupo, conservando ejecutables.
- Nginx pertenece al GID 33, por lo que puede leer también los archivos nuevos
  extraídos por Moodle con permisos `0770`. Su montaje es de solo lectura.
- Cron lee el mismo volumen en solo lectura. App y cron escriben sus datos en
  `moodledata`, que Nginx no tiene montado.
- El `config.php` real y los archivos de arranque externos a `public/` permanecen
  en la imagen de aplicación con filesystem de solo lectura.

Esto permite gestionar plugins desde la interfaz y conservarlos al recrear
contenedores. `MOODLE_PLUGIN_INSTALL=false` oculta/deshabilita el despliegue
desde Moodle; no convierte el volumen de código en solo lectura.

## Actualización del core y reconstrucción de imágenes

Reconstruir una imagen con el mismo `MOODLE_GIT_REF` actualiza la configuración
externa y el runtime; **no sobrescribe** el código persistente ni reinstala plugins.
Los cambios de código en `public/` que se añadan a una futura imagen tampoco se
sincronizan automáticamente sobre un volumen existente.

El marcador `.deployment-ref` del volumen debe coincidir con `.build-ref` de la
imagen. Un volumen no vacío sin marcador, incompleto o perteneciente a otro
commit detiene la inicialización para evitar reutilizar una versión equivocada.

Para cambiar el core se requiere preparar una actualización explícita:

1. Respaldar juntos la base, `moodledata` y `moodle-code` y conservar las imágenes
   y el `.env` de esa versión.
2. Preparar en otro entorno un volumen de código con la nueva fuente y todos
   los plugins adicionales en versiones compatibles. El nuevo `code-init`
   puede sembrar ese volumen vacío desde la nueva imagen verificada.
3. Restaurar una copia de la base y de `moodledata`, ejecutar el CLI
   `admin/cli/upgrade.php --non-interactive` y validar la actualización.
4. Programar el cambio conjunto del core, los plugins y la base en producción.
   Ante un rollback, restaurar los tres respaldos del mismo punto.

Cambiar solo el tag de la imagen o borrar solo `moodle-code` no realiza una
actualización completa. El repositorio no automatiza todavía upgrades del core.

## Registro y respaldo

Registrar componentes, versiones y procedencia en `plugins/manifest.lock` después
de cada cambio. La instalación desde la interfaz no modifica ese archivo de Git.
El listado real se consulta en Administración del sitio → Plugins → Vista general.

Los scripts de backup incluyen `moodle-code.tar.gz`. Consultar `operations.md`
para la pausa de escrituras y la restauración.
