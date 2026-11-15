-- Compra virtual atómica: evita que un recibo o el descuento de existencias
-- quede solo en un dispositivo. La transacción se confirma íntegramente o no
-- se crea nada.
create or replace function public.create_online_order(
  p_product_id uuid,
  p_quantity integer,
  p_payment_method text default 'Pago virtual'
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  current_user_id uuid := auth.uid();
  product_record public.products%rowtype;
  order_id uuid;
  receipt_no text;
  subtotal_value numeric(14,2);
  fee_value numeric(14,2);
begin
  if current_user_id is null then
    raise exception 'Debes iniciar sesión para comprar.' using errcode = '28000';
  end if;
  if p_quantity is null or p_quantity < 1 then
    raise exception 'La cantidad no es válida.' using errcode = '22023';
  end if;

  select * into product_record from public.products
  where id = p_product_id and is_active = true
  for update;
  if not found then
    raise exception 'El producto ya no está disponible.' using errcode = 'P0001';
  end if;
  if product_record.stock < p_quantity then
    raise exception 'No hay existencias suficientes.' using errcode = 'P0001';
  end if;

  subtotal_value := product_record.price * p_quantity;
  fee_value := round(subtotal_value * 0.05, 2);
  receipt_no := 'CP-' || to_char(now() at time zone 'America/Bogota', 'YYYY') || '-' ||
    upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));

  insert into public.orders (
    workshop_id, client_id, status, currency, subtotal, platform_fee, payment_method
  ) values (
    product_record.workshop_id, current_user_id, 'paid', 'COP', subtotal_value,
    fee_value, coalesce(nullif(trim(p_payment_method), ''), 'Pago virtual')
  ) returning id into order_id;

  insert into public.order_items (order_id, product_id, product_name, quantity, unit_price)
  values (order_id, product_record.id, product_record.name, p_quantity, product_record.price);
  insert into public.payments (order_id, provider, provider_payment_id, status, approved_at)
  values (order_id, 'sandbox', 'TEST-' || replace(gen_random_uuid()::text, '-', ''), 'approved', now());
  insert into public.receipts (order_id, receipt_number)
  values (order_id, receipt_no);
  update public.products set stock = stock - p_quantity, updated_at = now()
  where id = product_record.id;

  insert into public.user_notifications (recipient_id, workshop_id, type, title, body, reference_id)
  values (current_user_id, product_record.workshop_id, 'purchase', 'Compra confirmada',
    'Tu recibo ' || receipt_no || ' ya está disponible.', order_id);
  insert into public.user_notifications (recipient_id, workshop_id, type, title, body, reference_id)
  select wm.user_id, product_record.workshop_id, 'sale', 'Nueva venta virtual',
    product_record.name || ' · ' || p_quantity || ' unidad(es)', order_id
  from public.workshop_members wm
  where wm.workshop_id = product_record.workshop_id and wm.status = 'active';

  return jsonb_build_object(
    'id', order_id, 'receipt_number', receipt_no, 'subtotal', subtotal_value,
    'platform_fee', fee_value, 'created_at', now(), 'payment_method',
    coalesce(nullif(trim(p_payment_method), ''), 'Pago virtual')
  );
end;
$$;

revoke all on function public.create_online_order(uuid, integer, text) from public;
grant execute on function public.create_online_order(uuid, integer, text) to authenticated;
