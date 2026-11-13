#!/bin/sh
# Se ejecuta una sola vez, al crear el volumen de la BD local (perfil local-db).
# Aplica los mismos scripts que se usan en Supabase.
set -eu
for f in 00_roles_and_schemas.sql 01_extensions.sql; do
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    -v pw_reportes="$SVC_REPORTES_PASSWORD" \
    -v pw_moderacion="$SVC_MODERACION_PASSWORD" \
    -v pw_indicadores="$SVC_INDICADORES_PASSWORD" \
    -f "/sql/$f"
done
