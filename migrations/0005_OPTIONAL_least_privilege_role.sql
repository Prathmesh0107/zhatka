-- 0005_OPTIONAL_least_privilege_role.sql      *** OPTIONAL TEMPLATE: read, adapt, run by hand ***
-- PURPOSE   Today the app connects as Supabase's "postgres" role (owner, bypasses RLS). A dedicated role limits the damage of any
--           SQL-injection-style bug or leaked DATABASE_URL: it can only touch the application's tables, cannot create/alter/drop,
--           and cannot bypass RLS.
-- PASSWORD  NEVER put the real password in this file or in git. Replace the placeholder below only in the Supabase SQL editor window,
--           then put the new connection string in Render. Keep the old DATABASE_URL until the new one is verified.
-- SCHEMA    Adjust "public"/"private" below to where users/sessions live (see 0004).
-- NOT EXECUTED by the author. Test on a copy of the database first.

BEGIN;

CREATE ROLE ruchira_app LOGIN NOBYPASSRLS NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD 'REPLACE_IN_SQL_EDITOR_ONLY';

GRANT USAGE ON SCHEMA public TO ruchira_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.settings, public.categories, public.menu_items, public.orders,
      public.order_items, public.inventory_purchases TO ruchira_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ruchira_app;

-- users / sessions in public (default):
GRANT SELECT, INSERT, UPDATE, DELETE ON public.users, public.sessions TO ruchira_app;
-- ...or, after 0004:
-- GRANT USAGE ON SCHEMA private TO ruchira_app;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON private.users, private.sessions TO ruchira_app;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA private TO ruchira_app;

-- RLS is enabled (0002) and ruchira_app obeys it, so it needs an explicit allow-all policy per table:
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['settings','categories','menu_items','orders','order_items','inventory_purchases','users','sessions'] LOOP
    IF to_regclass('public.' || t) IS NOT NULL AND NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename=t AND policyname='ruchira_app_all') THEN
      EXECUTE format('CREATE POLICY ruchira_app_all ON public.%I FOR ALL TO ruchira_app USING (true) WITH CHECK (true)', t);
    END IF;
  END LOOP;
END $$;
-- (for tables in schema private, repeat the policy with private.%I)

COMMIT;
-- The app role has no DDL rights, which is why the app no longer runs CREATE/ALTER TABLE at startup (migrations are applied by YOU as postgres).
