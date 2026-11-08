-- Talleres nuevos: 15 días de prueba. El propietario conserva los RPC de
-- extensión y puede conceder más días a cualquier taller desde el control.
alter table public.workshops
  alter column trial_ends_at set default (now() + interval '15 days');

-- Ajusta únicamente pruebas que aún conservaban el plazo inicial de 3 días.
update public.workshops
set trial_ends_at = trial_started_at + interval '15 days'
where access_status = 'trial'
  and trial_ends_at <= trial_started_at + interval '3 days 1 minute';

-- Catálogo compartido: todos los administradores y clientes del mismo taller
-- consultan la misma información. La imagen se conserva junto al producto
-- para que se vea igual desde cualquier dispositivo.
alter table public.products
  add column if not exists brand text not null default '',
  add column if not exists barcode text not null default '',
  add column if not exists image_base64 text;

create index if not exists products_catalog_search_idx
  on public.products (workshop_id, is_active, category);
