# servired-infra

Contratos y orquestación de **SERVI·RED**, plataforma colaborativa para reportar y monitorear cortes de servicios públicos domiciliarios (proyecto del curso Arquitectura de Software, Javeriana). Este repo es la **fuente de verdad de los contratos** y el punto de arranque del sistema. No tiene código de negocio.

## Repositorios (organización `ProyectoArquisoft`)

| Repo | Tecnología | Puerto | Rol |
|---|---|---|---|
| `servired-infra` | Docker Compose, OpenAPI, JSON Schema | – | Este repo |
| `servired-gateway` | Spring Cloud Gateway | 8080 | Único punto de entrada |
| `servired-reportes` | Spring Boot (Java 21) | 8081 | Reportes, restablecimientos, validaciones, evidencia |
| `servired-moderacion` | Spring Boot (Java 21) | 8082 | Denuncias anónimas de fraude |
| `servired-indicadores` | .NET | 8083 | Indicadores a partir de eventos |
| `servired-app` | Flutter | – | App del ciudadano |

## Contenido

```
contracts/    OpenAPI (api pública y por servicio) y esquemas de eventos — v0.1.0, ver CHANGELOG
compose/      docker-compose.yml, override dev, .env.example, definiciones de RabbitMQ
supabase/     scripts SQL de esquemas, roles, PostGIS y bucket (ver supabase/README.md)
scripts/      smoke-test (sh y ps1)
docs/         brief.md (documento de trabajo del repo), runbook-demo.md
```

## Arranque rápido

Requiere Docker. Los comandos se ejecutan desde `compose/`.

```sh
# 1. API simulada para desarrollar la app sin backend  ->  http://localhost:4010
docker compose --profile mock up

# 2. Sistema completo (necesita compose/.env y Supabase listo)
cp .env.example .env        # Windows: copy .env.example .env  y complétalo
docker compose --profile app up

# 3. Construir desde los repos hermanos en vez de bajar imágenes de GHCR
docker compose -f docker-compose.yml -f docker-compose.dev.yml --profile app up --build

# 4. Demo: URL pública HTTPS para la app
docker compose --profile app --profile tunnel up
docker compose logs tunnel      # busca https://<algo>.trycloudflare.com
```

Perfiles: `mock` (Prism), `app` (RabbitMQ + gateway + 3 servicios), `tunnel` (cloudflared), `local-db` (Postgres local en lugar de Supabase, para trabajar sin internet).

El override dev espera los repos lado a lado: `<carpeta>/servired-infra`, `<carpeta>/servired-gateway`, etc. Si las imágenes de GHCR son privadas, haz antes `docker login ghcr.io`.

Para verificar: `sh scripts/smoke-test.sh` o `.\scripts\smoke-test.ps1` (probar los servicios 8081–8083 requiere el override dev).

## Eventos

Exchange `servired.events` (topic, durable). Los servicios publican con la routing key igual al nombre del evento (`reporte.creado`, `reporte.restablecido`, `validacion.registrada`, `fraude.validado`, `fraude.rechazado`). `compose/rabbitmq/definitions.json` se importa al arrancar (servicio `rabbitmq-init`) y deja creada la cola `indicadores.events` con sus bindings y la cola de errores `indicadores.events.dlq` (vía `servired.dlx`). Debe coincidir con lo que declara Indicadores (mismos argumentos); si uno cambia, cambia el otro.

## Reglas

- Un cambio en `contracts/` sube versión, se anota en `contracts/CHANGELOG.md` y afecta a los otros repos: avisar antes de mergear.
- Ningún secreto en git (`.env` está ignorado).
- Donde el repo y el contrato difieran, gana el contrato.
