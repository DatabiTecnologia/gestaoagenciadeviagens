alter table public.trips
  add column responsible_agent_id uuid references public.profiles(id);

alter table public.trip_alerts
  add column notify_agent boolean not null default true,
  add column agent_whatsapp_snapshot text;

create index trips_responsible_agent_idx on public.trips(organization_id,responsible_agent_id,start_at);
create index trip_alerts_pending_agent_idx on public.trip_alerts(organization_id,scheduled_at)
where status='scheduled' and notify_agent;

comment on column public.trip_alerts.agent_whatsapp_snapshot is
'Telefone do agente capturado no agendamento para preservar o destinatário histórico.';
