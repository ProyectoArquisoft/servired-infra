# Brief para Claude: repo `servired-infra`

> Lee este documento completo antes de tocar nada.
> No tienes acceso al documento original del proyecto (SAD); todo lo que necesitas está aquí. Si algo falta o se contradice, **pregunta antes de inventar**.

---

## 1. Contexto del proyecto

**SERVI·RED** es una plataforma colaborativa de reporte y monitoreo de servicios públicos domiciliarios en Colombia (acueducto, energía, gas, aseo, etc.). Es el proyecto del curso *Arquitectura de Software* (Pontificia Universidad Javeriana, equipo de 3 personas).

- Los **ciudadanos** reportan cortes no programados, restablecimientos y conexiones fraudulentas desde una **app móvil**.
- El sistema valida los reportes, calcula indicadores de continuidad y los expone a operadores, entes reguladores (SSPD / CRA) y público/academia.
- Estilo arquitectónico: **microservicios**, una base de datos por servicio, comunicación **híbrida** (asíncrona por bus de eventos; solo dos llamadas síncronas, ambas originadas en Moderación).

### Los 6 repositorios (organización de GitHub, uno por pieza)

| Repo | Tecnología | Rol |
|---|---|---|
| `servired-infra` | Docker Compose, OpenAPI, JSON Schema | **Este repo.** Contratos, orquestación local/demo, scripts de Supabase, plantillas de CI |
| `servired-gateway` | Spring Cloud Gateway (⚠ por confirmar) | Único punto de entrada; enruta y valida JWT; sin lógica de negocio |
| `servired-reportes` | Spring Boot (Java) | Crea/consulta reportes de corte y restablecimiento; único dueño del almacenamiento de evidencia |
| `servired-moderacion` | Spring Boot (Java) | Valida reportes de fraude anónimos |
| `servired-indicadores` | .NET (ASP.NET Core) | Consume eventos y mantiene estadísticas agregadas |
| `servired-mobile` | Flutter (Dart) | App del ciudadano |

**No hay panel web.** Las funciones de operador/regulador (gestionar y cerrar reportes, exportar datos) quedan expuestas **solo por API** y se demuestran con Swagger/Postman.

### Decisiones de arquitectura ya tomadas (no las cuestiones)

- **D1** Microservicios (no monolito).
- **D2** Base de datos por microservicio. Las relaciones entre BDs distintas **no son llaves foráneas físicas**, son referencias lógicas resueltas por eventos.
- **D3** Comunicación híbrida. Asíncrona por bus de eventos por defecto. Excepciones síncronas, solo desde Moderación: (a) consultar a Reportes que el reporte referenciado exista; (b) consultar a Indicadores patrones históricos de la zona.
- **D4** Evidencia fotográfica en almacenamiento de objetos compartido; **Reportes es su único escritor**. En la BD solo se guarda la URL/ruta.
- Anonimato verificable en reportes de fraude: **Moderación nunca debe recibir ni guardar identidad del usuario**.
- Atributos de calidad que mandan: disponibilidad, escalabilidad, modificabilidad (desplegar un servicio sin tumbar los otros), seguridad/privacidad (RBAC), interoperabilidad (JSON/CSV), observabilidad.

### Stack decidido para datos e infraestructura

- **PostgreSQL en Supabase** (el profesor lo recomendó). Supabase aporta: BD administrada con PostGIS, **Storage** (bucket de evidencias) y **Auth** (JWT).
- **No** se usa la API REST automática de Supabase ni Edge Functions como backend: los servicios Spring Boot y .NET se conectan como a cualquier PostgreSQL (JDBC / Npgsql).
- **Bus de eventos: RabbitMQ** (⚠ supuesto, ver §11).
- El gateway y los servicios corren en contenedores (Docker Compose) en el computador del equipo o en un VPS; la app se conecta por un túnel HTTPS (Cloudflare Tunnel / ngrok) durante la demo.

---

## 2. Qué es este repo y qué NO es

`servired-infra` es la **fuente de verdad de los contratos** y el **punto de arranque de todo el sistema**.

Contiene: contratos OpenAPI y esquemas de eventos, `docker-compose` (más perfiles `mock`, `local-db`, `tunnel`), scripts SQL de bootstrap de Supabase, plantillas de Dockerfile/CI y la documentación general.

**No contiene** código de negocio de ningún servicio ni de la app. **No modifiques otros repos.** Los demás repos y Claudes leen los contratos de aquí; por eso un cambio de contrato es un cambio grave (ver §10).

---

## 3. Estructura objetivo

```
servired-infra/
├── README.md
├── CLAUDE.md
├── contracts/
│   ├── CHANGELOG.md
│   ├── openapi/
│   │   ├── servired-public.yaml      # API pública vía gateway (la usan la app y el mock)
│   │   ├── reportes.yaml             # incluye endpoints /internal/*
│   │   ├── moderacion.yaml
│   │   └── indicadores.yaml          # incluye endpoints /internal/*
│   └── events/
│       ├── envelope.schema.json
│       ├── reporte.creado.v1.schema.json
│       ├── reporte.restablecido.v1.schema.json
│       ├── validacion.registrada.v1.schema.json
│       ├── fraude.validado.v1.schema.json
│       ├── fraude.rechazado.v1.schema.json
│       └── examples/
├── compose/
│   ├── docker-compose.yml            # imágenes desde GHCR
│   ├── docker-compose.dev.yml        # override: build desde repos hermanos (../servired-*)
│   ├── .env.example
│   └── rabbitmq/definitions.json     # exchange, colas y bindings precargados
├── supabase/
│   ├── README.md
│   ├── 00_roles_and_schemas.sql
│   └── 01_extensions.sql
├── templates/
│   ├── spring-boot/{Dockerfile, ci.yml}
│   ├── dotnet/{Dockerfile, ci.yml}
│   └── flutter/ci.yml
├── scripts/                          # up / down / smoke-test / tunnel (ver nota)
└── docs/
    ├── architecture.md
    ├── data-model.md
    └── runbook-demo.md
```

> Nota: el equipo probablemente trabaja en **Windows**. Los scripts deben funcionar en PowerShell y en bash, o bien documenta en el README los comandos `docker compose` directos y evita depender de scripts.

---

## 4. Contratos

### 4.1 Convenciones transversales (aplican a todo)

- JSON en **camelCase**. Fechas ISO-8601 en UTC. IDs numéricos enteros (int64) como en el modelo de datos; `codigoTrazabilidad` (string) es lo que ve el usuario.
- Errores: **RFC 7807** (`application/problem+json`).
- Paginación: query `page` (desde 0) y `size`; respuesta `{ items, page, size, total }`.
- Auth: `Authorization: Bearer <JWT de Supabase>`. El rol viaja en el claim `app_metadata.rol` ∈ `CIUDADANO | OPERADOR | REGULADOR`.
- **Idempotencia**: los POST que crean cosas desde la app aceptan el header `Idempotency-Key` (UUID generado por el cliente). Un reintento con la misma llave devuelve el mismo resultado y **no duplica**. Es obligatorio porque la app tiene cola offline con reintentos.
- Coordenadas: `lat`, `lng` (decimal, WGS84).

### 4.2 API pública (vía gateway, puerto 8080), `servired-public.yaml`

| Método | Ruta | RF | Auth | Notas |
|---|---|---|---|---|
| GET | `/api/servicios` | – | pública | Catálogo de tipos de servicio (para que la app arme el selector) |
| POST | `/api/reportes` | RF1 | CIUDADANO | `multipart/form-data`: `idServicio`, `tipoEvento=CORTE`, `lat`, `lng`, `descripcion?`, `severidad?`, `evidencia?` (JPEG ≤ 2 MB). Header `Idempotency-Key`. → `201 Reporte` |
| POST | `/api/reportes/{id}/restablecimiento` | RF2 | CIUDADANO | Notifica que el servicio volvió. Header `Idempotency-Key` |
| POST | `/api/reportes/{id}/validaciones` | RF3 | CIUDADANO | Otro ciudadano confirma el restablecimiento. `409` si ya validó |
| GET | `/api/reportes` | RF6 | CIUDADANO/OPERADOR | Filtros: `bbox=minLng,minLat,maxLng,maxLat`, `estado`, `idServicio`, `mios=true`. Paginado |
| GET | `/api/reportes/{id}` | – | CIUDADANO/OPERADOR | Detalle con URL firmada de evidencia (caduca) |
| PATCH | `/api/reportes/{id}/estado` | RF7 | OPERADOR | Gestionar / cerrar |
| POST | `/api/fraudes` | RF4/RF5 | **SIN AUTH (anónimo)** | JSON: `idServicio`, `lat`, `lng`, `descripcion`, `idReporteRef?`. → `201 { idFraude, resultado }`, con `resultado ∈ APROBADO \| RECHAZADO \| PENDIENTE_REVISION` |
| GET | `/api/indicadores` | RF9 | pública | Filtros: `idServicio`, `departamento`, `municipio`, `periodo` |
| GET | `/api/indicadores/export` | RF8 | OPERADOR/REGULADOR | `formato=csv\|json` |

**Reglas especiales de `/api/fraudes`:**
- El gateway **no valida JWT** en esa ruta y **no reenvía** ningún header de identidad, IP del cliente ni identificador de dispositivo hacia Moderación (aunque venga alguno).
- Limitar tasa por IP **en el gateway** (rate limiting), sin persistir esa IP en ningún servicio de negocio.
- `Idempotency-Key` es **opcional** aquí y debe ser un UUID aleatorio por petición, sin relación con ninguna cuenta; Moderación no lo persiste junto a datos identificables.
- La respuesta es síncrona (el ciudadano ve el resultado). Si una consulta síncrona de Moderación falla por timeout, el resultado es `PENDIENTE_REVISION` (comportamiento de respaldo del riesgo R3 del SAD).

### 4.3 Endpoints internos (NO expuestos por el gateway)

Solo para llamadas síncronas desde Moderación. Timeout sugerido 2 s, 1 reintento:
- `GET /internal/reportes/{id}` → `{ existe, idServicio, estado, lat, lng }` (Reportes)
- `GET /internal/indicadores/patrones?idServicio&lat&lng` → patrón histórico de fraudes de la zona (Indicadores)

### 4.4 Eventos (RabbitMQ)

- Exchange `servired.events` (topic, durable). Routing keys = nombre del evento.
- Colas: `indicadores.events` con bindings `reporte.*`, `validacion.*`, `fraude.*`; cola de errores `indicadores.events.dlq` vía exchange `servired.dlx`.
- Sobre (`envelope.schema.json`): `{ eventId (uuid), type, version, occurredAt, source, correlationId, data }`.
- Los consumidores **deben ser idempotentes por `eventId`** (por eso existe la tabla `evento_consumido`).

| Evento | Publica | Consume | `data` mínimo |
|---|---|---|---|
| `reporte.creado` | Reportes | Indicadores | `idReporte, codigoTrazabilidad, idServicio, tipoServicio, severidad, departamento, municipio, lat, lng, fechaCreacion` |
| `reporte.restablecido` | Reportes | Indicadores | `idReporte, idServicio, departamento, municipio, fechaCreacion, fechaResolucion, duracionInterrupcionHoras` |
| `validacion.registrada` | Reportes | Indicadores | `idReporte, totalValidaciones` |
| `fraude.validado` | Moderación | Indicadores | `idFraude, idServicio, lat, lng, fecha` (**sin ningún dato de usuario**) |
| `fraude.rechazado` | Moderación | Indicadores | `idFraude, idServicio, fecha` |

---

## 5. Modelo de datos de referencia (`docs/data-model.md`)

Cada servicio es dueño de su esquema y mantiene sus propias migraciones **en su repo** (Flyway en Spring Boot, EF Core en .NET). Este es el modelo del SAD; documéntalo en `docs/data-model.md`:

**Esquema `reportes`** (PostgreSQL + PostGIS)
- `usuario(id_usuario, nombre, es_anonimo, rol)`
- `servicio(id_servicio, tipo, descripcion)`
- `operador(id_operador, nombre, empresa)`
- `reporte(id_reporte, id_usuario→usuario, id_servicio→servicio, id_operador→operador, tipo_evento, estado, severidad, departamento, municipio, ubicacion_lat, ubicacion_lng, magnitud_area_afectada, tiempo_inicio_estimado, duracion_interrupcion, evidencia_url, codigo_trazabilidad, fecha_creacion, fecha_resolucion)`
- `validacion_comunitaria(id_validacion, id_reporte→reporte, id_usuario→usuario, fecha)`

**Esquema `moderacion`**
- `reporte_fraude(id_fraude, id_reporte_ref [sin FK física], id_servicio [referencia lógica], ubicacion_lat, ubicacion_lng, descripcion, fecha_creacion)`
- `decision_moderacion(id_decision, id_fraude→reporte_fraude, resultado, justificacion, fecha_decision)`

**Esquema `indicadores`**
- `indicador_agregado(id_indicador, tipo_servicio, tipo_novedad, departamento, municipio, periodo, horas_interrupcion_prom, frecuencia_cortes)`
- `evento_consumido(id_evento, tipo_evento, id_origen, fecha_consumo)`

⚠ **Propuesta de cambio al modelo (coordinar con `servired-reportes`):** agregar `usuario.auth_uid UUID UNIQUE` para enlazar con `auth.users` de Supabase. Reportes crea la fila de `usuario` la primera vez que ve un JWT nuevo (`sub` = `auth_uid`).

---

## 6. Docker Compose

### Servicios y puertos

| Servicio | Puerto host | Notas |
|---|---|---|
| `gateway` | **8080** | Es lo **único** que se expone al exterior (y al túnel) |
| `reportes` | 8081 | Solo red interna en `docker-compose.yml`; se publica en el override `dev` |
| `moderacion` | 8082 | Idem |
| `indicadores` | 8083 | Idem |
| `rabbitmq` | 5672 / 15672 | 15672 = consola de administración |

Red única `servired-net`; los servicios se hablan por nombre DNS (`http://reportes:8081`).

### Perfiles

- **(sin perfil)**: gateway + 3 servicios + RabbitMQ; la BD y el storage son **Supabase** (variables de entorno).
- `local-db`: un único Postgres+PostGIS local con 3 esquemas y 3 roles (mismo layout que `supabase/00_roles_and_schemas.sql`), para desarrollo **sin internet**.
- `mock`: **Prism** (`stoplight/prism`) sirviendo `servired-public.yaml` en el puerto **4010**. **Es lo que destraba a la app móvil**: puede avanzar sin que exista el backend. Prioridad alta.
- `tunnel`: `cloudflared` (quick tunnel) hacia `gateway:8080`; imprime la URL pública.
- `obs` (opcional, al final): Prometheus + Grafana.

### Variables (`.env.example`, **nunca** commitear `.env`)

Por servicio: `DB_URL`, `DB_USER`, `DB_PASSWORD`, `DB_SCHEMA`, `RABBITMQ_URL`.
Supabase: `SUPABASE_URL`, `SUPABASE_JWKS_URL` (o `SUPABASE_JWT_SECRET` si el proyecto usa HS256 ⚠), `SUPABASE_SERVICE_ROLE_KEY` (**solo** Reportes, para Storage), `STORAGE_BUCKET=evidencias`.
Moderación: `REPORTES_BASE_URL`, `INDICADORES_BASE_URL`, `SYNC_TIMEOUT_MS=2000`.

Cada servicio recibe **su propia** `DB_URL`, de modo que se pueda apuntar a un mismo proyecto Supabase o a dos distintos **solo cambiando variables** (ver §11).

### Healthchecks y orden

Spring: `/actuator/health`; .NET: `/health`; RabbitMQ: `rabbitmq-diagnostics ping`. Usa `depends_on: condition: service_healthy`.

### Imágenes

`docker-compose.yml` usa `ghcr.io/<ORG>/servired-<servicio>:latest`. `docker-compose.dev.yml` las reemplaza por `build: ../servired-<servicio>` (repos clonados lado a lado).

---

## 7. Supabase (`supabase/`)

- `00_roles_and_schemas.sql`: crea los esquemas `reportes`, `moderacion`, `indicadores` y los roles `svc_reportes`, `svc_moderacion`, `svc_indicadores` (LOGIN). Cada rol: `GRANT` solo sobre **su** esquema, `REVOKE` sobre los demás, `search_path` propio. Las contraseñas **no** van hardcodeadas (variables de `psql`). No toques los esquemas `auth`, `storage` ni `public`.
- `01_extensions.sql`: `postgis` (solo lo necesita Reportes). ⚠ **No asumas TimescaleDB**: puede no estar disponible en Supabase. Indicadores debe funcionar con tablas normales + índice por `periodo`.
- **Storage**: bucket privado `evidencias`, tipos `image/jpeg` y `image/png`, límite ~5 MB, sin acceso directo desde clientes. Reportes sube con la service role key y entrega **URLs firmadas** con caducidad (p. ej. 1 h).
- **Auth**: email + contraseña; rol del usuario en `app_metadata.rol` (default `CIUDADANO`). Documenta en el README cómo asignar `OPERADOR` y `REGULADOR` a mano para las demos.
- **Conexión**: usar conexión directa o *session pooler* (puerto 5432). Si usan el *transaction pooler* (6543), desactivar prepared statements (pgjdbc: `prepareThreshold=0`; Npgsql: `Max Auto Prepare=0`).
- ⚠ Los proyectos gratuitos **se pausan por inactividad**: el runbook de demo debe incluir "reactivar proyecto 24 h antes".

---

## 8. Plantillas de CI/CD (`templates/`)

- `spring-boot/`: Dockerfile multi-stage (JDK 21 build → JRE runtime, usuario no root, `HEALTHCHECK`) y `ci.yml` (setup-java, `mvn verify`, build y push a GHCR con tags `sha` y `latest` en `main`).
- `dotnet/`: igual con SDK/runtime de .NET (8 o superior), `dotnet test`.
- `flutter/ci.yml`: `flutter analyze`, `flutter test`, `flutter build apk --release`, sube el APK como artefacto.
- En `contracts/` agrega un workflow que valide los OpenAPI (Spectral) y los ejemplos de eventos contra sus JSON Schema (ajv).

---

## 9. Hitos y criterios de aceptación

Trabaja **en este orden** y haz commits pequeños. Antes de empezar, escribe un plan corto y confírmalo conmigo.

1. **H1: Contratos v0.1 + perfil `mock`** *(desbloquea a todos)*. Aceptación: `docker compose --profile mock up` sirve la API simulada en `:4010` con respuestas de ejemplo para todos los endpoints de §4.2; Spectral y ajv pasan.
2. **H2: Compose base.** RabbitMQ con `definitions.json`, `.env.example`, healthchecks, gateway + servicios como imágenes (aunque aún sean *placeholders*). Aceptación: `docker compose config` valida; RabbitMQ arriba con exchange y colas creados.
3. **H3: Scripts Supabase + README.** Aceptación: ejecutados en un proyecto vacío, crean esquemas y roles; cada rol falla al leer el esquema de otro.
4. **H4: Plantillas** de Dockerfile y CI.
5. **H5: Túnel + `runbook-demo.md`** (levantar, URL pública, reactivar Supabase, plan B con video).
6. **H6 (opcional):** perfil `obs`.

---

## 10. Reglas de trabajo

- Un cambio en `contracts/` implica: subir versión, anotar en `CHANGELOG.md` y avisarme **antes** de mergear (afecta a los otros 5 repos).
- Ningún secreto en git. `.gitignore` con `.env`. Si ves uno, detente y avísame.
- Documentación en español; identificadores del dominio como en el modelo de datos; commits convencionales; trabaja en ramas y abre PR (la rama `main` estará protegida).
- No añadas tecnologías fuera de este brief sin preguntar.

---

## 11. Supuestos y preguntas abiertas (resuélvelos conmigo, no por tu cuenta)

1. ⚠ **RabbitMQ vs Kafka.** Asumí RabbitMQ por simplicidad.
2. ⚠ **Supabase: 1 proyecto con 3 esquemas vs 2 proyectos** (Moderación aislada por anonimato). Diseña para que el cambio sea solo de variables de entorno.
3. ⚠ **Tecnología del gateway** (Spring Cloud Gateway asumido; YARP es la alternativa).
4. ⚠ **¿Cómo se obtienen `departamento`/`municipio` de un fraude?** Solo trae `lat/lng`. Opciones: Reportes resuelve la zona con PostGIS y una tabla de municipios, o geocodificación inversa. Afecta el contrato interno de Indicadores.
5. ⚠ **JWT de Supabase:** ¿el proyecto usa JWKS (asimétrico) o secreto HS256? Revisar en el dashboard.
6. Valores propuestos a confirmar: radio de validación comunitaria 500 m; validaciones necesarias para confirmar un restablecimiento: 3.
