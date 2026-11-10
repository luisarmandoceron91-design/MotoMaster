-- Ficha técnica pública para que cada taller pueda describir bien sus repuestos.
alter table public.products
  add column if not exists part_number text not null default '',
  add column if not exists package_weight text not null default '',
  add column if not exists product_condition text not null default 'Nuevo',
  add column if not exists origin text not null default '',
  add column if not exists oem_code text not null default '',
  add column if not exists includes_pistons boolean not null default false,
  add column if not exists includes_rings boolean not null default false,
  add column if not exists is_kit boolean not null default false;
