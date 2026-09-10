alter table public.organizations
  add column logo_path text,
  add column whatsapp_number text,
  add column whatsapp_message_template text;

create type public.campaign_channel as enum ('google_ads','meta_ads','instagram','facebook','organic','referral','other');
create type public.lead_status as enum ('new','contacted','qualified','proposal','won','lost');
create type public.trip_status as enum ('planned','confirmed','in_progress','completed','cancelled');
create type public.alert_type as enum ('checkin','departure','payment','document','insurance','custom');

create table public.marketing_campaigns (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  name text not null, channel public.campaign_channel not null,
  external_campaign_id text, start_date date not null, end_date date,
  budget numeric(14,2) not null default 0, spent numeric(14,2) not null default 0,
  active boolean not null default true, created_at timestamptz not null default now()
);
create table public.leads (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  campaign_id uuid references public.marketing_campaigns(id),
  client_id uuid references public.clients(id), name text not null, email text, phone text,
  source text, utm_source text, utm_medium text, utm_campaign text,
  status public.lead_status not null default 'new', created_at timestamptz not null default now()
);
alter table public.sales add column lead_id uuid references public.leads(id);

create table public.trips (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  sale_id uuid not null references public.sales(id), client_id uuid not null references public.clients(id),
  title text not null, destination text not null, start_at timestamptz not null, end_at timestamptz not null,
  status public.trip_status not null default 'planned', booking_code text, notes text,
  created_at timestamptz not null default now()
);
create table public.travelers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  trip_id uuid not null references public.trips(id) on delete cascade,
  client_id uuid references public.clients(id), full_name text not null,
  birth_date date, document text, passport text, emergency_contact text
);
create table public.trip_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  trip_id uuid not null references public.trips(id) on delete cascade,
  title text not null, event_type text not null, starts_at timestamptz not null,
  location text, confirmation_code text, metadata jsonb not null default '{}'
);
create table public.trip_alerts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  trip_id uuid not null references public.trips(id) on delete cascade,
  event_id uuid references public.trip_events(id) on delete cascade,
  type public.alert_type not null, scheduled_at timestamptz not null,
  notify_agency boolean not null default true, notify_client boolean not null default true,
  status text not null default 'scheduled' check(status in ('scheduled','sent','failed','cancelled')),
  message text, sent_at timestamptz
);
create table public.message_log (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  trip_id uuid references public.trips(id), client_id uuid references public.clients(id),
  channel text not null check(channel in ('whatsapp','email','sms','internal')),
  recipient text not null, template_name text, message text not null,
  status text not null default 'queued', external_message_id text,
  created_by uuid references public.profiles(id), created_at timestamptz not null default now(), sent_at timestamptz
);

create index campaign_org_date_idx on public.marketing_campaigns(organization_id,start_date desc);
create index leads_org_status_idx on public.leads(organization_id,status);
create index trips_org_start_idx on public.trips(organization_id,start_at);
create index alerts_org_schedule_idx on public.trip_alerts(organization_id,status,scheduled_at);

do $$ declare t text; begin
  foreach t in array array['marketing_campaigns','leads','trips','travelers','trip_events','trip_alerts','message_log']
  loop
    execute format('alter table public.%I enable row level security',t);
    execute format('create policy "tenant read %1$s" on public.%1$I for select to authenticated using ((select private.is_member(%1$I.organization_id)))',t);
    execute format('create policy "tenant insert %1$s" on public.%1$I for insert to authenticated with check ((select private.is_member(%1$I.organization_id,array[''owner'',''admin'',''manager'',''seller'',''finance'']::public.member_role[])))',t);
    execute format('create policy "tenant update %1$s" on public.%1$I for update to authenticated using ((select private.is_member(%1$I.organization_id,array[''owner'',''admin'',''manager'',''seller'',''finance'']::public.member_role[]))) with check ((select private.is_member(%1$I.organization_id,array[''owner'',''admin'',''manager'',''seller'',''finance'']::public.member_role[])))',t);
  end loop;
end $$;

-- Criação de usuários será executada no servidor por uma Edge Function usando
-- auth.admin.inviteUserByEmail. A função deve validar que o solicitante possui
-- papel owner/admin antes de criar o perfil e o vínculo com a organização.
