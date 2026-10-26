-- READ-ONLY. Run in the Supabase SQL editor. Changes nothing.
-- 1) RLS status (expect rls_enabled = true for every application table)
select n.nspname as schema, c.relname as table_name, c.relrowsecurity as rls_enabled, c.relforcerowsecurity as rls_forced
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname in ('public','private') and c.relkind = 'r' order by 1,2;

-- 2) Privileges held by the public API roles (expect NO rows for anon / authenticated / PUBLIC)
select table_schema, table_name, grantee, string_agg(privilege_type, ', ' order by privilege_type) as privileges
from information_schema.role_table_grants
where table_schema in ('public','private') and grantee in ('anon','authenticated','PUBLIC')
group by 1,2,3 order by 1,2,3;

-- 3) RLS policies that exist (a broad "true" policy for anon/authenticated would be a hole)
select schemaname, tablename, policyname, roles, cmd, qual, with_check from pg_policies where schemaname in ('public','private') order by 1,2,3;

-- 4) Which role does an application connection use, and does it bypass RLS?
select rolname, rolsuper, rolbypassrls, rolcanlogin from pg_roles where rolname in ('postgres','anon','authenticated','service_role','ruchira_app') order by 1;

-- 5) Schemas exposed through the Data API: Dashboard > Settings > API > "Exposed schemas" (cannot be read from SQL reliably).
