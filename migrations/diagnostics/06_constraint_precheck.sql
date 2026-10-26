-- READ-ONLY. Run BEFORE 0002. The NOT VALID constraints in 0002 are checked whenever a row is INSERTED OR UPDATED, so a legacy
-- row that violates one would make later edits of THAT row fail. Every query below should return zero rows.
select id, order_number, order_type from public.orders where order_type not in ('Pickup','Delivery');
select id, order_number, delivery_fee from public.orders where delivery_fee < 0;      -- negative fees: possible abuse of the old bug, review these orders
select id, order_id, quantity from public.order_items where quantity < 1;
select id, username, role from public.users where role not in ('owner','staff');
-- If any query returns rows: fix those rows deliberately, OR delete the matching ADD CONSTRAINT block from 0002 before running it.
