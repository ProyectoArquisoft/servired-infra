-- SERVI·RED — esquemas y roles por servicio (un esquema y un rol LOGIN por microservicio).
-- Se puede ejecutar varias veces: crea lo que falta y vuelve a fijar contraseñas y permisos.
--
--   psql "<conexión de admin>" -v ON_ERROR_STOP=1 \
--     -v pw_reportes='...' -v pw_moderacion='...' -v pw_indicadores='...' \
--     -f 00_roles_and_schemas.sql
--
-- Las contraseñas llegan como variables de psql: no se escriben en este archivo.
-- No toca los esquemas auth, storage ni public.

\if :{?pw_reportes}
\else
  \echo 'Falta -v pw_reportes=...'
  \quit
\endif
\if :{?pw_moderacion}
\else
  \echo 'Falta -v pw_moderacion=...'
  \quit
\endif
\if :{?pw_indicadores}
\else
  \echo 'Falta -v pw_indicadores=...'
  \quit
\endif

-- Roles (si no existen)
SELECT format('CREATE ROLE %I LOGIN NOINHERIT PASSWORD %L', v.rol, v.pw)
FROM (VALUES
  ('svc_reportes',    :'pw_reportes'),
  ('svc_moderacion',  :'pw_moderacion'),
  ('svc_indicadores', :'pw_indicadores')
) AS v(rol, pw)
WHERE NOT EXISTS (SELECT 1 FROM pg_roles r WHERE r.rolname = v.rol)
\gexec

-- Contraseñas (también si el rol ya existía)
ALTER ROLE svc_reportes    PASSWORD :'pw_reportes';
ALTER ROLE svc_moderacion  PASSWORD :'pw_moderacion';
ALTER ROLE svc_indicadores PASSWORD :'pw_indicadores';

-- Esquemas
CREATE SCHEMA IF NOT EXISTS reportes;
CREATE SCHEMA IF NOT EXISTS moderacion;
CREATE SCHEMA IF NOT EXISTS indicadores;

-- Nadie entra a un esquema ajeno: se quita lo heredado de PUBLIC y se da solo el propio.
REVOKE ALL ON SCHEMA reportes, moderacion, indicadores FROM PUBLIC;
REVOKE ALL ON SCHEMA reportes, moderacion, indicadores FROM svc_reportes, svc_moderacion, svc_indicadores;

GRANT USAGE, CREATE ON SCHEMA reportes    TO svc_reportes;
GRANT USAGE, CREATE ON SCHEMA moderacion  TO svc_moderacion;
GRANT USAGE, CREATE ON SCHEMA indicadores TO svc_indicadores;

-- Cada rol trabaja en su esquema por defecto. Reportes añade extensions (PostGIS).
ALTER ROLE svc_reportes    SET search_path = reportes, extensions;
ALTER ROLE svc_moderacion  SET search_path = moderacion;
ALTER ROLE svc_indicadores SET search_path = indicadores;
