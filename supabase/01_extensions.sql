-- PostGIS solo lo necesita Reportes. En Supabase las extensiones viven en el esquema "extensions".
-- No se asume TimescaleDB: Indicadores usa tablas normales con índice por periodo.
-- Ejecutar después de 00_roles_and_schemas.sql.

CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA extensions;
GRANT USAGE ON SCHEMA extensions TO svc_reportes;
