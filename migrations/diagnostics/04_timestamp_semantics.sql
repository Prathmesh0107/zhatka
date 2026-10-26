-- READ-ONLY. Confirms how created_at is stored before any time-zone decision.
select column_name, data_type from information_schema.columns where table_schema='public' and table_name='orders' and column_name='created_at';
show timezone;   -- expect UTC
-- Newest orders: compare to the real wall-clock time in UTC and in India.
select id, order_number, created_at,
       (now() at time zone 'UTC') as now_utc, (now() at time zone 'Asia/Kolkata') as now_india
from public.orders order by id desc limit 5;
-- Orders whose UTC date differs from their India date (these are the ones old reports put in the wrong day/month):
select count(*) as orders_in_that_window
from public.orders
where ((created_at at time zone 'UTC') at time zone 'Asia/Kolkata')::date <> created_at::date;
-- Rows created while the app ran on a laptop in India would look 5h30m "ahead": look for created_at in the FUTURE:
select count(*) as future_dated from public.orders where created_at > (now() at time zone 'UTC') + interval '1 hour';
