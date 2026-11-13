# Runbook de demo

## 24 horas antes
- [ ] Reactivar el proyecto de Supabase si se pausó (los gratuitos se pausan por inactividad).
- [ ] Probar un reporte de punta a punta (app → gateway → reportes → indicadores).
- [ ] Grabar un video corto de respaldo (plan B).
- [ ] `docker login ghcr.io` en el computador de la demo y `docker compose pull`.

## Levantar
1. `cd servired-infra/compose` y verificar `.env` (Supabase, claves de BD, `GATEWAY_CONFIAR_CF_IP=true`).
2. `docker compose --profile app --profile tunnel up -d`
3. `docker compose ps` — todos `healthy`/`running`.
4. `docker compose logs tunnel` — copiar la URL `https://….trycloudflare.com`.
5. Poner esa URL como `API_BASE_URL` en la app (`config/*.json`) y compilar el APK (`flutter build apk --release --dart-define-from-file=config/dev.json`). El APK release solo acepta HTTPS.
6. `curl <URL>/actuator/health` — debe responder `UP`.

La URL del quick tunnel cambia cada vez que se reinicia el túnel: hay que recompilar el APK si cambia.

## Si algo falla
| Síntoma | Revisar |
|---|---|
| Un servicio reinicia en bucle | `docker compose logs <servicio>`: normalmente `DB_URL`/usuario/contraseña (usa el session pooler, usuario `svc_x.<ref>`) |
| `401` en todo | `SUPABASE_URL` y `SUPABASE_JWKS_URL` (o `SUPABASE_JWT_SECRET`) del `.env` |
| Indicadores no se actualizan | Consola de RabbitMQ (`localhost:15672`): cola `indicadores.events`; mensajes en `indicadores.events.dlq` indican eventos rechazados |
| La app no conecta | URL del túnel vigente, HTTPS, y el APK compilado con esa URL |
| Supabase no responde | Proyecto pausado: reactivarlo; plan B: perfil `local-db` o el video |
