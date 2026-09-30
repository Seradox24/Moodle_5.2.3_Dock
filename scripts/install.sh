#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
. ./scripts/lib/compose-env.sh

env_file=.env
while [ "$#" -gt 0 ]; do
    case "$1" in
        --env-file)
            [ "$#" -ge 2 ] || { echo "--env-file requiere una ruta." >&2; exit 1; }
            env_file=$2
            shift 2
            ;;
        *) echo "Argumento desconocido: $1" >&2; exit 1 ;;
    esac
done

compose_init "$env_file" quiet no-config

sh ./scripts/preflight.sh --env-file "$COMPOSE_ENV_FILE" --fresh-install

echo "Construyendo las imágenes de Moodle..."
compose build

echo "Iniciando PostgreSQL y Redis..."
compose up -d db redis

echo "Preparando el código compartido e iniciando PHP-FPM de Moodle..."
compose up -d --wait app

echo "Instalando la base de datos de Moodle..."
compose exec -T --user www-data app sh /usr/local/bin/install-database.sh

echo "Iniciando el servicio web y las tareas programadas..."
compose up -d --wait web cron

echo
echo "Instalación inicial de Moodle completada."
echo "URL pública: $(compose_env_value MOODLE_WWWROOT http://localhost:18080)"
echo "Siguiente paso: configurar el proxy HTTPS y el certificado en el Nginx del servidor."
echo "Cuando la URL pública sea accesible con un certificado válido, ejecutar:"
echo "  sh ./scripts/smoke-test.sh --env-file \"$COMPOSE_ENV_FILE\""
