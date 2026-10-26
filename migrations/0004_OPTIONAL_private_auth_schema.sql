-- 0004_OPTIONAL_private_auth_schema.sql      *** OPTIONAL, NOT REQUIRED, causes a short outage ***
-- PURPOSE   Move users and sessions out of schema "public" (which Supabase exposes through its Data API) into schema "private",
--           which is not exposed. 0002 already blocks anon/authenticated on these tables; this is a second, independent barrier.
-- HOW       The application reads the schema name from the AUTH_SCHEMA environment variable (default: public).
--           1. Take a backup.  2. Run this file.  3. IMMEDIATELY set AUTH_SCHEMA=private on Render and redeploy/restart.
--           Between steps 2 and 3 logins fail (the app still looks in public). Do it outside opening hours.
-- NOTE      ALTER TABLE ... SET SCHEMA keeps all rows, indexes, constraints and the id sequence. NOT EXECUTED by the author.
-- ROLLBACK  See migrations/ROLLBACK.md (section 0004): move the tables back and set AUTH_SCHEMA=public.

BEGIN;
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC;
DO $$
DECLARE r text;
BEGIN
  FOREACH r IN ARRAY ARRAY['anon','authenticated'] LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN EXECUTE format('REVOKE ALL ON SCHEMA private FROM %I', r); END IF;
  END LOOP;
  IF to_regclass('public.users')    IS NOT NULL AND to_regclass('private.users')    IS NULL THEN ALTER TABLE public.users    SET SCHEMA private; END IF;
  IF to_regclass('public.sessions') IS NOT NULL AND to_regclass('private.sessions') IS NULL THEN ALTER TABLE public.sessions SET SCHEMA private; END IF;
  ALTER TABLE private.users    ENABLE ROW LEVEL SECURITY;
  ALTER TABLE private.sessions ENABLE ROW LEVEL SECURITY;
END $$;
COMMIT;
