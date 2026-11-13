-- Bucket privado de evidencias. Solo Reportes escribe, con la service role key, y entrega
-- URLs firmadas con caducidad. Sin políticas RLS, los clientes no tienen acceso directo.
-- Solo para Supabase (la BD local del perfil local-db no tiene el esquema storage).

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('evidencias', 'evidencias', false, 5242880, ARRAY['image/jpeg', 'image/png'])
ON CONFLICT (id) DO UPDATE
SET public = false,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;
