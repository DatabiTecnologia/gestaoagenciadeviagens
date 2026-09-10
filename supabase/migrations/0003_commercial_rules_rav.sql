create type public.rav_calculation_type as enum ('fixed','percentage','manual');

create table public.commercial_rules (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  supplier_id uuid not null references public.suppliers(id) on delete cascade,
  title text not null,
  applies_to text not null check (applies_to in ('air_only','package','cruise','hotel','service','all')),
  max_installments smallint not null default 1 check (max_installments between 1 and 36),
  interest_free_installments smallint not null default 1 check (interest_free_installments between 0 and max_installments),
  interest_rate numeric(7,4) not null default 0 check (interest_rate >= 0),
  supplier_commission_percent numeric(7,4) not null default 0 check (supplier_commission_percent between 0 and 100),
  rav_type public.rav_calculation_type not null default 'manual',
  rav_value numeric(14,2) not null default 0 check (rav_value >= 0),
  instructions text,
  valid_from date not null default current_date,
  valid_until date,
  active boolean not null default true,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  check (valid_until is null or valid_until >= valid_from)
);

alter table public.sale_items
  add column commercial_rule_id uuid references public.commercial_rules(id),
  add column supplier_base_amount numeric(14,2) not null default 0,
  add column supplier_commission_amount numeric(14,2) not null default 0,
  add column rav_amount numeric(14,2) not null default 0,
  add column installment_count smallint not null default 1 check (installment_count between 1 and 36);

alter table public.trips
  add column client_whatsapp text,
  add column whatsapp_opt_in boolean not null default true;

create index commercial_rules_org_supplier_idx
  on public.commercial_rules(organization_id,supplier_id,valid_from desc);
create index commercial_rules_current_idx
  on public.commercial_rules(organization_id,supplier_id)
  where active and valid_until is null;
create index sale_items_commercial_rule_idx on public.sale_items(commercial_rule_id);
create index sale_items_sale_idx on public.sale_items(sale_id);
create index sale_items_supplier_idx on public.sale_items(supplier_id);

alter table public.commercial_rules enable row level security;
create policy "tenant read commercial rules" on public.commercial_rules for select to authenticated
using ((select private.is_member(organization_id)));
create policy "admin insert commercial rules" on public.commercial_rules for insert to authenticated
with check ((select private.is_member(organization_id,array['owner','admin','manager']::public.member_role[])));
create policy "admin update commercial rules" on public.commercial_rules for update to authenticated
using ((select private.is_member(organization_id,array['owner','admin','manager']::public.member_role[])))
with check ((select private.is_member(organization_id,array['owner','admin','manager']::public.member_role[])));

create view public.monthly_rav_summary with (security_invoker=true) as
select
  s.organization_id,
  date_trunc('month',s.sale_date)::date as reference_month,
  si.supplier_id,
  count(distinct s.id) as sales_count,
  sum(si.supplier_base_amount) as supplier_base_total,
  sum(si.supplier_commission_amount) as supplier_commission_total,
  sum(si.rav_amount) as rav_total,
  sum(si.supplier_commission_amount + si.rav_amount) as gross_margin_total
from public.sales s
join public.sale_items si on si.sale_id=s.id and si.organization_id=s.organization_id
where s.status='confirmed'
group by s.organization_id,date_trunc('month',s.sale_date),si.supplier_id;
