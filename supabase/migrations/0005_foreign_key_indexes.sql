do $$
declare
  fk record;
  index_name text;
begin
  for fk in
    select
      n.nspname as schema_name,
      c.relname as table_name,
      a.attname as column_name
    from pg_constraint con
    join pg_class c on c.oid=con.conrelid
    join pg_namespace n on n.oid=c.relnamespace
    join pg_attribute a on a.attrelid=con.conrelid and a.attnum=con.conkey[1]
    where con.contype='f'
      and array_length(con.conkey,1)=1
      and n.nspname='public'
      and not exists (
        select 1 from pg_index i
        where i.indrelid=con.conrelid and con.conkey[1]=any(i.indkey)
      )
  loop
    index_name:=left(fk.table_name||'_'||fk.column_name||'_fk_idx',63);
    execute format('create index if not exists %I on %I.%I (%I)',
      index_name,fk.schema_name,fk.table_name,fk.column_name);
  end loop;
end $$;
