-- Las ventas presenciales también son información oficial del taller: se
-- registran de forma atómica en la nube, descuentan existencias y generan el
-- recibo al instante para que todos los administradores vean el mismo dato.
alter table public.orders
  add column if not exists sale_channel text not null default 'virtual'
    check (sale_channel in ('virtual', 'local')),
  add column if not exists counter_customer_name text,
  add column if not exists counter_customer_document text,
  add column if not exists counter_customer_phone text,
  add column if not exists discount numeric(14,2) not null default 0
    check (discount >= 0);

create or replace function public.create_local_sale(
  p_workshop_id uuid,
  p_items jsonb,
  p_payment_method text default 'Efectivo',
  p_customer_name text default '',
  p_customer_document text default '',
  p_customer_phone text default '',
  p_discount numeric default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  current_user_id uuid := auth.uid();
  item jsonb;
  product_record public.products%rowtype;
  product_id_value uuid;
  quantity_value integer;
  order_id uuid;
  receipt_no text;
  subtotal_value numeric(14,2) := 0;
  discount_value numeric(14,2) := greatest(coalesce(p_discount, 0), 0);
  fee_value numeric(14,2);
begin
  if current_user_id is null then
    raise exception 'Debes iniciar sesión para registrar una venta.' using errcode = '28000';
  end if;
  if not private.can_manage_workshop(p_workshop_id) then
    raise exception 'No tienes permiso para registrar ventas de este taller.' using errcode = '42501';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Agrega al menos un producto a la venta.' using errcode = '22023';
  end if;

  -- Bloquea cada producto mientras se valida: dos cajas no pueden vender la
  -- misma última unidad simultáneamente.
  for item in select value from jsonb_array_elements(p_items) loop
    product_id_value := nullif(item ->> 'product_id', '')::uuid;
    quantity_value := coalesce((item ->> 'quantity')::integer, 0);
    if quantity_value < 1 then
      raise exception 'La cantidad no es válida.' using errcode = '22023';
    end if;
    select * into product_record from public.products
    where id = product_id_value and workshop_id = p_workshop_id
    for update;
    if not found or not product_record.is_active then
      raise exception 'Uno de los productos no está disponible.' using errcode = 'P0001';
    end if;
    if product_record.stock < quantity_value then
      raise exception 'No hay existencias suficientes para %.', product_record.name using errcode = 'P0001';
    end if;
    subtotal_value := subtotal_value + product_record.price * quantity_value;
  end loop;

  if discount_value > subtotal_value then
    raise exception 'El descuento no puede superar el subtotal.' using errcode = '22023';
  end if;
  fee_value := 0;
  receipt_no := 'PV-' || to_char(now() at time zone 'America/Bogota', 'YYYY') || '-' ||
    upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));

  insert into public.orders (
    workshop_id, client_id, status, currency, subtotal, platform_fee,
    payment_method, sale_channel, counter_customer_name,
    counter_customer_document, counter_customer_phone, discount
  ) values (
    p_workshop_id, current_user_id, 'paid', 'COP', subtotal_value - discount_value,
    fee_value, coalesce(nullif(trim(p_payment_method), ''), 'Efectivo'), 'local',
    coalesce(nullif(trim(p_customer_name), ''), 'Consumidor final'),
    nullif(trim(p_customer_document), ''), nullif(trim(p_customer_phone), ''), discount_value
  ) returning id into order_id;

  for item in select value from jsonb_array_elements(p_items) loop
    product_id_value := (item ->> 'product_id')::uuid;
    quantity_value := (item ->> 'quantity')::integer;
    select * into product_record from public.products where id = product_id_value;
    insert into public.order_items (order_id, product_id, product_name, quantity, unit_price)
    values (order_id, product_record.id, product_record.name, quantity_value, product_record.price);
    update public.products set stock = stock - quantity_value, updated_at = now()
    where id = product_record.id;
  end loop;

  insert into public.payments (order_id, provider, provider_payment_id, status, approved_at)
  values (order_id, 'local', 'POS-' || replace(gen_random_uuid()::text, '-', ''), 'approved', now());
  insert into public.receipts (order_id, receipt_number) values (order_id, receipt_no);

  insert into public.user_notifications (recipient_id, workshop_id, type, title, body, reference_id)
  select wm.user_id, p_workshop_id, 'sale', 'Nueva venta en el local',
    receipt_no || ' · ' || coalesce(nullif(trim(p_customer_name), ''), 'Consumidor final'), order_id
  from public.workshop_members wm
  where wm.workshop_id = p_workshop_id and wm.status = 'active';

  return jsonb_build_object(
    'id', order_id, 'receipt_number', receipt_no, 'created_at', now(),
    'subtotal', subtotal_value - discount_value, 'discount', discount_value,
    'payment_method', coalesce(nullif(trim(p_payment_method), ''), 'Efectivo')
  );
end;
$$;

revoke all on function public.create_local_sale(uuid, jsonb, text, text, text, text, numeric) from public;
grant execute on function public.create_local_sale(uuid, jsonb, text, text, text, text, numeric) to authenticated;
