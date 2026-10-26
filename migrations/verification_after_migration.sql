-- READ-ONLY post-migration checks. Run after 0002 / 0003 (and 0004 / 0005 if used).
-- A) Expect rls_enabled = true on all rows
select c.relname, c.relrowsecurity as rls_enabled from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname in ('public','private') and c.relkind='r' and c.relname in ('settings','categories','menu_items','orders','order_items','inventory_purchases','users','sessions') order by 1;
-- B) Expect ZERO rows
select table_schema, table_name, grantee, privilege_type from information_schema.role_table_grants
where table_schema in ('public','private') and grantee in ('anon','authenticated','PUBLIC');
-- C) Expect 4 constraints (users_role_ok, orders_order_type_ok, orders_delivery_fee_nonneg, order_items_quantity_pos)
select conname, convalidated from pg_constraint where conname in ('users_role_ok','orders_order_type_ok','orders_delivery_fee_nonneg','order_items_quantity_pos') order by 1;
-- D) 0003: expect client_request_id column and both unique indexes (the second one only if there were no duplicates)
select column_name from information_schema.columns where table_schema='public' and table_name='orders' and column_name='client_request_id';
select indexname from pg_indexes where schemaname='public' and indexname in ('uq_orders_client_request_id','uq_orders_order_number');
-- E) Data survived: compare these counts with the counts you saved before the migration
select 'users' t, count(*) from public.users union all select 'orders', count(*) from public.orders union all select 'order_items', count(*) from public.order_items
union all select 'menu_items', count(*) from public.menu_items union all select 'categories', count(*) from public.categories union all select 'inventory_purchases', count(*) from public.inventory_purchases;
-- (use private.users in E after migration 0004)
-- F) Optional: constraints that were added NOT VALID can be validated once you are sure old rows comply:
--    select count(*) from public.orders where order_type not in ('Pickup','Delivery');   -- must be 0, then:  ALTER TABLE public.orders VALIDATE CONSTRAINT orders_order_type_ok;
