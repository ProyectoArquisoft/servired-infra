# Supabase

Supabase aporta PostgreSQL (con PostGIS), Storage y Auth. Los servicios se conectan como a cualquier Postgres: no se usa la API REST automática ni Edge Functions.

## 1. Crear el proyecto
1. Crea un proyecto en supabase.com y guarda la contraseña de la base de datos.
2. En **Connect → Session pooler** copia el host (`aws-0-<region>.pooler.supabase.com`, puerto 5432) y el ref del proyecto. El host directo (`db.<ref>.supabase.co`) puede ser solo IPv6 y fallar en tu red.
3. En **Project Settings → API** anota la URL, y en la sección de JWT/Signing keys si el proyecto usa llaves asimétricas (JWKS) o un secreto HS256.

## 2. Crear esquemas, roles, PostGIS y bucket
Las contraseñas de los 3 roles las inventas tú (sin `@ : / ? #`). Desde la raíz de `servired-infra`, en PowerShell, con Docker (no necesitas instalar `psql`):

```powershell
$env:ADMIN_URL = "postgresql://postgres.<ref>:<contraseña-bd>@aws-0-<region>.pooler.supabase.com:5432/postgres"
$run = { param($f) docker run --rm -v "${PWD}/supabase:/sql:ro" postgres:16-alpine psql $env:ADMIN_URL -v ON_ERROR_STOP=1 `
  -v pw_reportes="CLAVE1" -v pw_moderacion="CLAVE2" -v pw_indicadores="CLAVE3" -f "/sql/$f" }
& $run 00_roles_and_schemas.sql
& $run 01_extensions.sql
& $run 02_storage.sql
& $run 03_verificar_aislamiento.sql   # debe terminar con "Aislamiento OK"
```

Los scripts son idempotentes: puedes repetirlos (por ejemplo para cambiar una contraseña).

## 3. Usuarios y roles de la app
- Auth: email + contraseña. El rol viaja en `app_metadata.rol` (`CIUDADANO` por defecto si falta).
- Para las demos, asigna operador o regulador en el SQL Editor de Supabase:

```sql
update auth.users
set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"rol":"OPERADOR"}'
where email = 'operador@ejemplo.com';   -- o "REGULADOR"
```
El usuario debe cerrar sesión y volver a entrar para que el JWT traiga el rol nuevo.

## Notas
- Los proyectos gratuitos **se pausan por inactividad**: reactívalo al menos un día antes de la demo.
- Con el *transaction pooler* (6543) hay que desactivar prepared statements; por eso se usa el session pooler (5432).
- `SUPABASE_SERVICE_ROLE_KEY` solo va en Reportes. Nunca en la app ni en git.
