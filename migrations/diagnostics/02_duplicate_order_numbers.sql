-- READ-ONLY. Expect ZERO rows. Any row = the same bill number was used more than once.
select order_number, count(*) as times_used, array_agg(id order by id) as order_ids, min(created_at) as first_seen, max(created_at) as last_seen
from public.orders group by order_number having count(*) > 1 order by order_number;
