create or replace function public.create_or_recover_trial_workshop(
  p_name text,
  p_slug text,
  p_tagline text,
  p_accent_color bigint,
  p_department text,
  p_municipality text,
  p_neighborhood text,
  p_address text,
  p_phone text,
  p_email text,
  p_opening_hours jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  workshop_row public.workshops%rowtype;
  already_had_owner boolean := false;
begin
  if actor_id is null then
    raise exception 'Debes iniciar sesion para crear el taller';
  end if;
  if length(trim(coalesce(p_name, ''))) < 2 then
    raise exception 'El nombre del taller es obligatorio';
  end if;
  if length(trim(coalesce(p_department, ''))) < 2
      or length(trim(coalesce(p_municipality, ''))) < 2 then
    raise exception 'La ubicacion del taller es obligatoria';
  end if;

  select * into workshop_row
  from public.workshops
  where created_by = actor_id
  for update;

  if found then
    if workshop_row.deleted_at is not null then
      raise exception 'El taller esta en la papelera y debe restaurarse desde el panel del propietario';
    end if;

    select exists (
      select 1 from public.workshop_members member
      where member.workshop_id = workshop_row.id
        and member.user_id = actor_id
        and member.role = 'owner'
        and member.status = 'active'
    ) into already_had_owner;

    update public.workshops
    set name = trim(p_name),
        slug = trim(lower(p_slug)),
        tagline = trim(coalesce(p_tagline, '')),
        accent_color = p_accent_color,
        department = trim(p_department),
        municipality = trim(p_municipality),
        neighborhood = trim(coalesce(p_neighborhood, '')),
        address = trim(coalesce(p_address, '')),
        phone = trim(coalesce(p_phone, '')),
        email = trim(lower(coalesce(p_email, ''))),
        opening_hours = coalesce(p_opening_hours, '{}'::jsonb),
        status = 'active',
        trial_started_at = case
          when not already_had_owner and access_status = 'trial' then now()
          else trial_started_at
        end,
        trial_ends_at = case
          when not already_had_owner and access_status = 'trial' then now() + interval '3 days'
          else trial_ends_at
        end,
        updated_at = now()
    where id = workshop_row.id
    returning * into workshop_row;
  else
    insert into public.workshops (
      name, slug, tagline, accent_color, created_by, department,
      municipality, neighborhood, address, phone, email, opening_hours,
      status, access_status, permanent_access
    ) values (
      trim(p_name), trim(lower(p_slug)), trim(coalesce(p_tagline, '')),
      p_accent_color, actor_id, trim(p_department), trim(p_municipality),
      trim(coalesce(p_neighborhood, '')), trim(coalesce(p_address, '')),
      trim(coalesce(p_phone, '')), trim(lower(coalesce(p_email, ''))),
      coalesce(p_opening_hours, '{}'::jsonb), 'active', 'trial', false
    )
    returning * into workshop_row;
  end if;

  insert into public.workshop_members (workshop_id, user_id, role, status)
  values (workshop_row.id, actor_id, 'owner', 'active')
  on conflict (workshop_id, user_id) do update
  set role = 'owner', status = 'active';

  return to_jsonb(workshop_row);
end;
$$;

revoke all on function public.create_or_recover_trial_workshop(
  text, text, text, bigint, text, text, text, text, text, text, jsonb
) from public, anon;
grant execute on function public.create_or_recover_trial_workshop(
  text, text, text, bigint, text, text, text, text, text, text, jsonb
) to authenticated;
