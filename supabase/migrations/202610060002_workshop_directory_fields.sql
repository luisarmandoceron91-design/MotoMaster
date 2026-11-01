alter table public.workshops
  add column if not exists department text not null default '',
  add column if not exists municipality text not null default '',
  add column if not exists neighborhood text not null default '',
  add column if not exists address text not null default '',
  add column if not exists phone text not null default '',
  add column if not exists timezone text not null default 'America/Bogota',
  add column if not exists opening_hours jsonb not null default '{}'::jsonb,
  add column if not exists rating numeric(2, 1) not null default 0,
  add column if not exists review_count integer not null default 0;

create index if not exists workshops_directory_location_idx
  on public.workshops (status, department, municipality);

alter table public.workshops
  drop constraint if exists workshops_rating_check,
  add constraint workshops_rating_check check (rating between 0 and 5),
  drop constraint if exists workshops_review_count_check,
  add constraint workshops_review_count_check check (review_count >= 0);
