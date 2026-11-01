create table if not exists public.workshop_payment_accounts (
  workshop_id uuid primary key references public.workshops(id) on delete cascade,
  provider text not null default 'mercado_pago',
  provider_user_id text,
  connection_status text not null default 'pending' check (connection_status in ('pending','connected','restricted','disconnected')),
  connected_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.products add column if not exists category text not null default 'Otros';
alter table public.products add column if not exists currency text not null default 'COP';

create table if not exists public.commerce_settings (
  id boolean primary key default true check (id),
  default_commission_bps integer not null default 500 check (default_commission_bps between 0 and 3000),
  updated_at timestamptz not null default now()
);
insert into public.commerce_settings (id) values (true) on conflict (id) do nothing;

create table if not exists public.workshop_commissions (
  workshop_id uuid primary key references public.workshops(id) on delete cascade,
  commission_bps integer not null check (commission_bps between 0 and 3000),
  updated_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  workshop_id uuid not null references public.workshops(id),
  client_id uuid not null references auth.users(id),
  status text not null default 'awaiting_payment' check (status in ('awaiting_payment','paid','preparing','ready_for_pickup','delivered','cancelled','refunded')),
  currency text not null default 'COP',
  subtotal numeric(14,2) not null check (subtotal >= 0),
  platform_fee numeric(14,2) not null default 0 check (platform_fee >= 0),
  gateway_fee numeric(14,2),
  payment_method text,
  pickup_code_hash text,
  pickup_verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id),
  product_name text not null,
  quantity integer not null check (quantity > 0),
  unit_price numeric(14,2) not null check (unit_price >= 0),
  unique (order_id, product_id)
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete cascade,
  provider text not null default 'mercado_pago',
  provider_payment_id text unique,
  status text not null default 'pending' check (status in ('pending','approved','rejected','cancelled','refunded','expired')),
  checkout_url text,
  raw_status text,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.receipts (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete cascade,
  receipt_number text not null unique,
  dian_invoice_url text,
  cufe text,
  created_at timestamptz not null default now()
);

create table if not exists public.payment_webhook_events (
  provider text not null,
  event_id text not null,
  event_type text not null,
  payload jsonb not null,
  processed_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (provider, event_id)
);

create index if not exists orders_workshop_created_idx on public.orders(workshop_id, created_at desc);
create index if not exists orders_client_created_idx on public.orders(client_id, created_at desc);
create index if not exists orders_status_idx on public.orders(status, created_at desc);

alter table public.workshop_payment_accounts enable row level security;
alter table public.commerce_settings enable row level security;
alter table public.workshop_commissions enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.payments enable row level security;
alter table public.receipts enable row level security;
alter table public.payment_webhook_events enable row level security;

create policy "payment_accounts_managers_read" on public.workshop_payment_accounts
for select to authenticated using (private.can_manage_workshop(workshop_id));
create policy "payment_accounts_managers_update" on public.workshop_payment_accounts
for update to authenticated using (private.can_manage_workshop(workshop_id));

create policy "commerce_settings_authenticated_read" on public.commerce_settings
for select to authenticated using (true);
create policy "workshop_commissions_manager_read" on public.workshop_commissions
for select to authenticated using (private.can_manage_workshop(workshop_id));

create policy "orders_participants_read" on public.orders
for select to authenticated using (client_id = (select auth.uid()) or private.is_workshop_member(workshop_id));
create policy "orders_client_create" on public.orders
for insert to authenticated with check (client_id = (select auth.uid()));
create policy "orders_staff_update" on public.orders
for update to authenticated using (private.is_workshop_member(workshop_id));

create policy "order_items_participants_read" on public.order_items
for select to authenticated using (exists (
  select 1 from public.orders o where o.id = order_id
  and (o.client_id = (select auth.uid()) or private.is_workshop_member(o.workshop_id))
));
create policy "payments_participants_read" on public.payments
for select to authenticated using (exists (
  select 1 from public.orders o where o.id = order_id
  and (o.client_id = (select auth.uid()) or private.is_workshop_member(o.workshop_id))
));
create policy "receipts_participants_read" on public.receipts
for select to authenticated using (exists (
  select 1 from public.orders o where o.id = order_id
  and (o.client_id = (select auth.uid()) or private.is_workshop_member(o.workshop_id))
));

alter publication supabase_realtime add table public.orders;
alter publication supabase_realtime add table public.payments;
