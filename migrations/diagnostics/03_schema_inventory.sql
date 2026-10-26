-- READ-ONLY. Compare this output with migrations/0001_baseline_schema.sql BEFORE running anything on a live database.
select table_schema, table_name, ordinal_position, column_name, data_type, is_nullable, column_default, is_identity
from information_schema.columns
where table_schema in ('public','private')
  and table_name in ('settings','categories','menu_items','orders','order_items','inventory_purchases','users','sessions')
order by table_schema, table_name, ordinal_position;

select conrelid::regclass as table_name, conname, contype, pg_get_constraintdef(oid) as definition
from pg_constraint where connamespace in ('public'::regnamespace) order by 1,2;

select tablename, indexname, indexdef from pg_indexes where schemaname in ('public','private') order by 1,2;
