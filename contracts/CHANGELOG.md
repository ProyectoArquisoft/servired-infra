# Changelog de contratos

Todo cambio en `contracts/` sube versión (SemVer) y se anota aquí **antes** de mergear, porque
afecta a los otros 5 repos. Mientras la versión sea `0.x`, puede haber cambios incompatibles entre
versiones menores; se marcan con **⚠ BREAKING**.

## [0.1.0] — 2026-10-26

Primera versión.

### API (OpenAPI 3.0.3)
- `openapi/servired-public.yaml`: 10 operaciones de la API pública (gateway :8080 / mock :4010).
- `openapi/reportes.yaml`, `moderacion.yaml`, `indicadores.yaml`: contrato por servicio. Reutilizan
  las rutas `/api/*` de la API pública por `$ref` y agregan los endpoints `/internal/*`:
  - `GET /internal/reportes/{id}` → `{ existe, idServicio, estado, lat, lng }`.
  - `GET /internal/indicadores/patrones?idServicio&lat&lng` → `PatronZona`.

### Eventos (JSON Schema draft-07)
- `envelope.schema.json` y `reporte.creado`, `reporte.restablecido`, `validacion.registrada`,
  `fraude.validado`, `fraude.rechazado` (todos `v1`), con ejemplos en `events/examples/`.
- `data` tiene `additionalProperties: false`: los eventos de fraude **no pueden** llevar datos de
  usuario (lo verifica el CI con `examples/invalid/`).

### Decisiones tomadas en esta versión (no venían en el brief; revisar)
- Estados del reporte: `ACTIVO → EN_ATENCION → RESTABLECIMIENTO_REPORTADO → RESTABLECIDO`, y
  `CERRADO` por el operador. `reporte.restablecido` se publica al pasar a `RESTABLECIDO`
  (validaciones requeridas alcanzadas).
- Enumeraciones: `TipoServicio` (`ENERGIA, GAS, ACUEDUCTO, ALCANTARILLADO, ASEO`), `Severidad`
  (`BAJA, MEDIA, ALTA`), `MagnitudArea` (`VIVIENDA, CUADRA, BARRIO, SECTOR`), `tipoNovedad`
  (`CORTE, FRAUDE`).
- `POST /api/reportes` acepta además `magnitudAreaAfectada?` y `tiempoInicioEstimado?` (están en el
  modelo de datos y en el enunciado).
- `POST /api/reportes/{id}/validaciones` recibe `{ lat, lng }` del validador para comprobar el radio;
  `422` si está fuera de radio, `409` si ya validó o es el autor.
- `PATCH /api/reportes/{id}/estado` solo permite `EN_ATENCION` y `CERRADO`.
- `IndicadorAgregado` incluye `idServicio` además de `tipoServicio` para poder filtrar por
  `idServicio` como pide la API.
- `PatronZona` (`radioMetros, ventanaDias, fraudesValidados, fraudesRechazados, cortesReportados`).

### Pendiente
- ⚠ §11.4 del brief: `fraude.validado` solo trae `lat/lng`; falta decidir cómo obtener
  `departamento/municipio` para agregarlo en Indicadores.
- ⚠ El modelo de datos de Reportes no tiene columna `descripcion` en `reporte`, aunque la API la
  recibe. Coordinar con `servired-reportes`.
