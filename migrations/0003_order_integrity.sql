-- 0003_order_integrity.sql
-- PURPOSE   (a) orders.client_request_id: lets the app recognise a re-sent "Confirm" and return the existing order instead of creating a duplicate.
--           (b) UNIQUE order numbers, enforced by the database, but ONLY if no duplicates exist today.
-- SAFE      Adds one nullable column and indexes. Never renumbers, edits or deletes an order. Idempotent.
-- BEFORE    Run migrations/diagnostics/02_duplicate_order_numbers.sql. If it returns rows, this script skips (b) and prints a NOTICE;
--           follow migrations/ROLLBACK.md "Duplicate order numbers" and run this file again. NOT EXECUTED by the author.
-- APP       Works with or without this migration: without it the app logs a warning and duplicate-submit protection is off.

BEGIN;

ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS client_request_id TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS uq_orders_client_request_id ON public.orders(client_request_id) WHERE client_request_id IS NOT NULL;

DO $$
BEGIN
  IF to_regclass('public.uq_orders_order_number') IS NOT NULL THEN
    RAISE NOTICE 'uq_orders_order_number already exists.';
  ELSIF EXISTS (SELECT 1 FROM public.orders GROUP BY order_number HAVING COUNT(*) > 1) THEN
    RAISE NOTICE 'SKIPPED unique order numbers: duplicate order_number values exist. Run diagnostics/02_duplicate_order_numbers.sql and resolve them (no automatic renumbering is done).';
  ELSE
    CREATE UNIQUE INDEX uq_orders_order_number ON public.orders(order_number);
    RAISE NOTICE 'Created uq_orders_order_number.';
  END IF;
END $$;

COMMIT;
