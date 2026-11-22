-- Un ajuste de stock o una venta debe llegar a todos los dispositivos del
-- taller y a los clientes que estén viendo el catálogo, sin recargar.
do $$
begin
  alter publication supabase_realtime add table public.products;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.order_items;
exception when duplicate_object then null;
end $$;
