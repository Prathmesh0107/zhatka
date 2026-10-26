# Rollback and recovery

First rule: **take a backup before any migration** (docs/DEPLOYMENT.md). The strongest rollback is restoring that backup.
None of these migrations deletes or rewrites rows, so rollback is about restoring access/constraints, not recovering data.

## 0001 baseline
Nothing to undo on an existing database. On a new, empty database: `DROP` the tables.

## 0002 security hardening
Undo only if the app or a tool you rely on lost access (the app's own `postgres` connection is NOT affected by RLS).
```sql
-- re-open a table to the API roles (NOT recommended; this re-creates the exposure)
ALTER TABLE public.orders DISABLE ROW LEVEL SECURITY;      -- repeat per table
-- drop the NOT VALID constraints
ALTER TABLE public.users       DROP CONSTRAINT IF EXISTS users_role_ok;
ALTER TABLE public.orders      DROP CONSTRAINT IF EXISTS orders_order_type_ok, DROP CONSTRAINT IF EXISTS orders_delivery_fee_nonneg;
ALTER TABLE public.order_items DROP CONSTRAINT IF EXISTS order_items_quantity_pos;
```
Revoked grants are not restored automatically; re-grant only what you need, e.g. `GRANT SELECT ON public.menu_items TO anon;`.

## 0003 order integrity
```sql
DROP INDEX IF EXISTS public.uq_orders_order_number;
DROP INDEX IF EXISTS public.uq_orders_client_request_id;
ALTER TABLE public.orders DROP COLUMN IF EXISTS client_request_id;   -- only loses duplicate-submit protection
```
The app keeps working (it detects the missing column at startup).

### Duplicate order numbers (if diagnostics/02 returned rows)
1. Decide per case which order keeps the number (usually the earliest `id`); printed bills already carry the old number, so **do not renumber automatically**.
2. For each extra order, either leave it and skip the unique index, or give it a new number with a deliberate manual statement, e.g. `update public.orders set order_number = (select max(order_number)+1 from public.orders) where id = <extra id>;` and record the change.
3. Re-run diagnostics/02 until empty, then run 0003 again.

## 0004 private schema
```sql
ALTER TABLE private.users    SET SCHEMA public;
ALTER TABLE private.sessions SET SCHEMA public;
```
then set `AUTH_SCHEMA=public` (or remove it) on Render and restart.

## 0005 least-privilege role
Point `DATABASE_URL` back to the previous value (keep it until the new one is proven), then `DROP OWNED BY ruchira_app; DROP ROLE ruchira_app;`.

## Application rollback
Redeploy the previous Render release. The old code works with the new schema (extra column/indexes are ignored) **except** that
it still contains the old behaviours (default `admin123` account on an empty database, inline-script XSS). Do not roll back for long.
