-- 0002_security_hardening.sql
-- PURPOSE   Make sure nobody holding the public Supabase "anon" / "authenticated" key can read or write any application table
--           through the Data API (PostgREST). Protects password hashes, session-token hashes, roles AND customer data (orders contain phone numbers).
-- WHAT IT DOES (idempotent; no rows are read, changed or deleted)
--           1. ENABLE ROW LEVEL SECURITY on every application table, with NO policies  -> deny-all for roles that obey RLS.
--           2. REVOKE every privilege on those tables and their sequences from anon, authenticated and PUBLIC.
--           3. Change default privileges so tables created LATER in schema public do not auto-grant to anon/authenticated.
--           4. Add NOT VALID check constraints: they apply to new and updated rows only, so existing rows can never make this fail.
-- IMPORTANT  The application connects with DATABASE_URL directly (not through the Data API). A role that is a superuser or has
--           BYPASSRLS (Supabase's "postgres" role does) IGNORES row level security. So RLS alone does not restrict the app's own role;
--           this migration protects the Data API. For least privilege on the app's own connection, see 0005 (optional).
-- BEFORE    Run diagnostics/06_constraint_precheck.sql (NOT VALID constraints still apply to any legacy row you later UPDATE).
--           Take a backup (docs/DEPLOYMENT.md, section "Backup checklist"). NOT EXECUTED by the author.
-- ROLLBACK  See migrations/ROLLBACK.md (section 0002).

BEGIN;

DO $$
DECLARE t text; r text;
BEGIN
  FOREACH t IN ARRAY ARRAY['settings','categories','menu_items','orders','order_items','inventory_purchases','users','sessions'] LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
      EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC', t);
      FOREACH r IN ARRAY ARRAY['anon','authenticated'] LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
          EXECUTE format('REVOKE ALL ON TABLE public.%I FROM %I', t, r);
        END IF;
      END LOOP;
    END IF;
  END LOOP;

  FOREACH r IN ARRAY ARRAY['anon','authenticated'] LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
      EXECUTE format('REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM %I', r);
      EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM %I', r);
      EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM %I', r);
      EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM %I', r);
    END IF;
  END LOOP;
  -- Supabase creates objects as these roles; cover their default privileges too when they exist.
  FOREACH r IN ARRAY ARRAY['postgres','supabase_admin'] LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) AND EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
      BEGIN
        EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public REVOKE ALL ON TABLES FROM anon, authenticated', r);
        EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated', r);
      EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'Could not change default privileges for role % (insufficient privilege): skipped.', r;
      END;
    END IF;
  END LOOP;
END $$;

-- Defence in depth at the database level. NOT VALID = checked for new/changed rows only (existing rows are not scanned).
DO $$
BEGIN
  IF to_regclass('public.users') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'users_role_ok') THEN
    ALTER TABLE public.users ADD CONSTRAINT users_role_ok CHECK (role IN ('owner','staff')) NOT VALID;
  END IF;
  IF to_regclass('public.orders') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'orders_order_type_ok') THEN
    ALTER TABLE public.orders ADD CONSTRAINT orders_order_type_ok CHECK (order_type IN ('Pickup','Delivery')) NOT VALID;
  END IF;
  IF to_regclass('public.orders') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'orders_delivery_fee_nonneg') THEN
    ALTER TABLE public.orders ADD CONSTRAINT orders_delivery_fee_nonneg CHECK (delivery_fee >= 0) NOT VALID;
  END IF;
  IF to_regclass('public.order_items') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'order_items_quantity_pos') THEN
    ALTER TABLE public.order_items ADD CONSTRAINT order_items_quantity_pos CHECK (quantity >= 1) NOT VALID;
  END IF;
END $$;

COMMIT;
