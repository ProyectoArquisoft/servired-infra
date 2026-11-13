-- Falla con error si algún rol tiene acceso a un esquema que no es el suyo
-- (o si le falta el propio). Ejecutar como administrador después de 00 y 01.

DO $$
DECLARE
  nombre text;
  esquema text;
  tiene boolean;
BEGIN
  FOREACH nombre IN ARRAY ARRAY['reportes', 'moderacion', 'indicadores'] LOOP
    FOREACH esquema IN ARRAY ARRAY['reportes', 'moderacion', 'indicadores'] LOOP
      tiene := has_schema_privilege('svc_' || nombre, esquema, 'USAGE')
            OR has_schema_privilege('svc_' || nombre, esquema, 'CREATE');
      IF tiene <> (nombre = esquema) THEN
        RAISE EXCEPTION 'svc_% % al esquema %', nombre,
          CASE WHEN tiene THEN 'NO debería acceder' ELSE 'debería acceder' END, esquema;
      END IF;
    END LOOP;
  END LOOP;
  IF has_schema_privilege('svc_moderacion', 'extensions', 'USAGE')
     OR has_schema_privilege('svc_indicadores', 'extensions', 'USAGE') THEN
    RAISE EXCEPTION 'Solo svc_reportes debería usar el esquema extensions';
  END IF;
  RAISE NOTICE 'Aislamiento OK: cada rol solo accede a su esquema.';
END
$$;
