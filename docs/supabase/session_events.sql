-- Pozo Profundo · métricas mínimas (F4).
-- Pegalo entero en Supabase > SQL Editor y ejecutalo. Se puede correr de nuevo sin romper nada.
--
-- Desde el juego (rol anon) solo se puede INSERTAR esas cuatro columnas: no leer, no modificar, no borrar.
-- La fecha (created_at) y el id los pone el servidor. No se guarda ningún dato personal.
-- max_biome: 0 Tierra, 1 Roca, 2 Cristal, 3 Magma, 4 Abismo.

create table if not exists public.session_events (
	id bigint generated always as identity primary key,
	device_id uuid not null,
	created_at timestamptz not null default now(),
	app_version text not null check (char_length(app_version) between 1 and 20),
	max_biome smallint not null check (max_biome between 0 and 100),
	relics integer not null check (relics between 0 and 1000000)
);

create index if not exists session_events_device_day on public.session_events (device_id, created_at);

alter table public.session_events enable row level security;

revoke all on table public.session_events from anon, authenticated;
grant insert (device_id, app_version, max_biome, relics) on table public.session_events to anon;

drop policy if exists "anon solo inserta" on public.session_events;
create policy "anon solo inserta" on public.session_events
	for insert to anon
	with check (true);
