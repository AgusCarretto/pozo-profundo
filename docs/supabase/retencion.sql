-- Pozo Profundo · retención del día 1 y del día 7. Correlas en Supabase > SQL Editor (una por vez).
--
-- Cohorte = día de la primera sesión de cada dispositivo. "Día N" = volvió exactamente N días después.
-- Solo entran las cohortes cuyo día N ya terminó, así un día a medias no baja el número.
-- Días en hora de Uruguay. La fila TOTAL junta todas las cohortes.
-- Se excluyen las filas de prueba de tools/check_supabase.mjs.

-- Retención del día 1
with dias as (
	select distinct device_id, (created_at at time zone 'America/Montevideo')::date as dia
	from public.session_events
	where app_version <> 'prueba'
),
primeras as (
	select device_id, min(dia) as primer_dia
	from dias
	group by device_id
)
select
	coalesce(p.primer_dia::text, 'TOTAL') as cohorte,
	count(*) as jugadores_nuevos,
	count(d.device_id) as volvieron,
	round(100.0 * count(d.device_id) / nullif(count(*), 0), 1) as retencion_d1_pct
from primeras p
left join dias d on d.device_id = p.device_id and d.dia = p.primer_dia + 1
where p.primer_dia + 1 < (now() at time zone 'America/Montevideo')::date
group by rollup (p.primer_dia)
order by p.primer_dia nulls last;

-- Retención del día 7
with dias as (
	select distinct device_id, (created_at at time zone 'America/Montevideo')::date as dia
	from public.session_events
	where app_version <> 'prueba'
),
primeras as (
	select device_id, min(dia) as primer_dia
	from dias
	group by device_id
)
select
	coalesce(p.primer_dia::text, 'TOTAL') as cohorte,
	count(*) as jugadores_nuevos,
	count(d.device_id) as volvieron,
	round(100.0 * count(d.device_id) / nullif(count(*), 0), 1) as retencion_d7_pct
from primeras p
left join dias d on d.device_id = p.device_id and d.dia = p.primer_dia + 7
where p.primer_dia + 7 < (now() at time zone 'America/Montevideo')::date
group by rollup (p.primer_dia)
order by p.primer_dia nulls last;
