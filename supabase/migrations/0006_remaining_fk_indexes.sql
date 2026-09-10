create index commercial_rules_supplier_fk_idx on public.commercial_rules(supplier_id);
create index memberships_user_fk_idx on public.memberships(user_id);
create index sale_participants_user_fk_idx on public.sale_participants(user_id);
create index trips_responsible_agent_fk_idx on public.trips(responsible_agent_id);
