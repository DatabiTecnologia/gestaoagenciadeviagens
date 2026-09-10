create extension if not exists pgcrypto;

create type public.member_role as enum ('owner','admin','manager','seller','finance','viewer');
create type public.sale_status as enum ('draft','proposal','negotiation','confirmed','cancelled');
create type public.entry_status as enum ('pending','paid','overdue','cancelled');
create type public.supplier_type as enum ('consolidator','operator','airline','hotel','insurance','transport','other');

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  document text,
  currency char(3) not null default 'BRL',
  timezone text not null default 'America/Sao_Paulo',
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text,
  created_at timestamptz not null default now()
);
create table public.memberships (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.member_role not null default 'seller',
  active boolean not null default true,
  commission_percent numeric(7,4) not null default 0 check (commission_percent between 0 and 100),
  primary key (organization_id,user_id)
);
create table public.clients (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
  name text not null, email text, phone text, document text, birth_date date, notes text,
  created_at timestamptz not null default now()
);
create table public.suppliers (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
  name text not null, type public.supplier_type not null, document text, contact_name text, email text, phone text,
  payment_terms text, active boolean not null default true, created_at timestamptz not null default now()
);
create table public.product_categories (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
  name text not null, unique(organization_id,name)
);
create table public.products (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
  category_id uuid references public.product_categories(id), supplier_id uuid references public.suppliers(id),
  name text not null, description text, cost numeric(14,2) not null default 0, sale_price numeric(14,2) not null default 0,
  agency_commission_percent numeric(7,4) not null default 0, active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.sales (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
  code text not null, client_id uuid not null references public.clients(id), seller_id uuid not null references public.profiles(id),
  status public.sale_status not null default 'draft', sale_date date not null default current_date,
  gross_amount numeric(14,2) not null default 0, discount_amount numeric(14,2) not null default 0,
  net_amount numeric(14,2) generated always as (gross_amount-discount_amount) stored,
  notes text, created_by uuid not null references public.profiles(id), created_at timestamptz not null default now(),
  unique(organization_id,code)
);
create table public.sale_items (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
  sale_id uuid not null references public.sales(id) on delete cascade, product_id uuid not null references public.products(id),
  supplier_id uuid references public.suppliers(id), description text not null, quantity numeric(10,2) not null default 1,
  unit_price numeric(14,2) not null, unit_cost numeric(14,2) not null default 0,
  agency_commission_percent numeric(7,4) not null default 0
);
create table public.sale_participants (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
  sale_id uuid not null references public.sales(id) on delete cascade, user_id uuid not null references public.profiles(id),
  participation_percent numeric(7,4) not null check (participation_percent > 0 and participation_percent <= 100),
  unique(sale_id,user_id)
);
create table public.commission_rules (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
  name text not null, product_id uuid references public.products(id), category_id uuid references public.product_categories(id),
  agency_percent numeric(7,4) not null default 0, seller_percent numeric(7,4) not null default 0,
  participant_percent numeric(7,4) not null default 0, active boolean not null default true,
  valid_from date not null default current_date, valid_until date
);
create table public.commissions (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
  sale_id uuid not null references public.sales(id) on delete cascade, beneficiary_id uuid references public.profiles(id),
  beneficiary_kind text not null check (beneficiary_kind in ('agency','seller','participant')),
  calculation_base numeric(14,2) not null, percent numeric(7,4) not null, amount numeric(14,2) not null,
  status public.entry_status not null default 'pending', due_date date, paid_at timestamptz
);
create table public.receivables (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
  sale_id uuid references public.sales(id), description text not null, installment integer not null default 1,
  amount numeric(14,2) not null, due_date date not null, status public.entry_status not null default 'pending',
  paid_amount numeric(14,2) not null default 0, paid_at timestamptz
);
create table public.payables (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
  supplier_id uuid references public.suppliers(id), sale_id uuid references public.sales(id),
  description text not null, amount numeric(14,2) not null, due_date date not null,
  status public.entry_status not null default 'pending', paid_at timestamptz
);
create table public.audit_logs (
  id bigint generated always as identity primary key, organization_id uuid not null references public.organizations(id),
  user_id uuid references public.profiles(id), action text not null, entity text not null, entity_id text,
  details jsonb not null default '{}', created_at timestamptz not null default now()
);

create index sales_org_date_idx on public.sales(organization_id,sale_date desc);
create index receivables_org_due_idx on public.receivables(organization_id,due_date,status);
create index payables_org_due_idx on public.payables(organization_id,due_date,status);
create index commissions_org_status_idx on public.commissions(organization_id,status);

alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.memberships enable row level security;
alter table public.clients enable row level security;
alter table public.suppliers enable row level security;
alter table public.product_categories enable row level security;
alter table public.products enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.sale_participants enable row level security;
alter table public.commission_rules enable row level security;
alter table public.commissions enable row level security;
alter table public.receivables enable row level security;
alter table public.payables enable row level security;
alter table public.audit_logs enable row level security;

create schema if not exists private;
create function private.is_member(org_id uuid, allowed_roles public.member_role[] default null)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(
  select 1 from public.memberships m
  where m.organization_id=org_id and m.user_id=(select auth.uid()) and m.active
    and (allowed_roles is null or m.role=any(allowed_roles))
) $$;
revoke all on function private.is_member(uuid,public.member_role[]) from public;
grant usage on schema private to authenticated;
grant execute on function private.is_member(uuid,public.member_role[]) to authenticated;

create policy "members read organizations" on public.organizations for select to authenticated
using ((select private.is_member(id)));
create policy "users read own profile" on public.profiles for select to authenticated using (id=(select auth.uid()));
create policy "members read memberships" on public.memberships for select to authenticated
using ((select private.is_member(organization_id)));

do $$ declare t text; begin
  foreach t in array array['clients','suppliers','product_categories','products','sales','sale_items','sale_participants','commission_rules','commissions','receivables','payables','audit_logs']
  loop
    execute format('create policy "tenant read %1$s" on public.%1$I for select to authenticated using ((select private.is_member(%1$I.organization_id)))',t);
    execute format('create policy "tenant insert %1$s" on public.%1$I for insert to authenticated with check ((select private.is_member(%1$I.organization_id,array[''owner'',''admin'',''manager'',''seller'',''finance'']::public.member_role[])))',t);
    execute format('create policy "tenant update %1$s" on public.%1$I for update to authenticated using ((select private.is_member(%1$I.organization_id,array[''owner'',''admin'',''manager'',''seller'',''finance'']::public.member_role[]))) with check ((select private.is_member(%1$I.organization_id,array[''owner'',''admin'',''manager'',''seller'',''finance'']::public.member_role[])))',t);
  end loop;
end $$;
