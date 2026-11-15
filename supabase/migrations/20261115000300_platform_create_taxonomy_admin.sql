-- Taxonomy administration functions (EP-02-021).
--
-- The API role has read-only table grants. These security-definer functions are
-- the narrow write path: they check `admin.configuration.write`, keep the
-- hierarchy stable, and return the row. The service layer appends the audit
-- record in the same transaction.

set local lock_timeout = '5s';

create function platform.create_taxonomy_node(
  p_actor_user_id uuid,
  p_taxonomy text,
  p_level text,
  p_parent_id uuid,
  p_slug text,
  p_name text,
  p_description text,
  p_version integer,
  p_effective_from timestamptz
)
returns platform.taxonomy_nodes
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_node platform.taxonomy_nodes;
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.configuration.write') then
    raise exception 'taxonomy_write_forbidden' using errcode = '42501';
  end if;

  insert into platform.taxonomy_nodes
    (taxonomy, level, parent_id, slug, name, description, version, effective_from)
  values
    (p_taxonomy, p_level, p_parent_id, btrim(p_slug), btrim(p_name),
     nullif(btrim(coalesce(p_description, '')), ''),
     coalesce(p_version, 1), coalesce(p_effective_from, now()))
  returning * into v_node;

  return v_node;
end;
$$;

create function platform.update_taxonomy_node(
  p_actor_user_id uuid,
  p_id uuid,
  p_name text,
  p_description text,
  p_version integer,
  p_effective_from timestamptz,
  p_effective_to timestamptz,
  p_is_active boolean
)
returns platform.taxonomy_nodes
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_node platform.taxonomy_nodes;
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.configuration.write') then
    raise exception 'taxonomy_write_forbidden' using errcode = '42501';
  end if;

  update platform.taxonomy_nodes
     set name = btrim(p_name),
         description = nullif(btrim(coalesce(p_description, '')), ''),
         version = coalesce(p_version, version),
         effective_from = coalesce(p_effective_from, effective_from),
         effective_to = p_effective_to,
         is_active = coalesce(p_is_active, is_active),
         updated_at = now()
   where id = p_id
  returning * into v_node;

  if v_node.id is null then
    raise exception 'taxonomy_node_missing' using errcode = 'P0002';
  end if;

  return v_node;
end;
$$;

create function platform.create_taxonomy_attribute(
  p_actor_user_id uuid,
  p_node_id uuid,
  p_key text,
  p_label text,
  p_data_type text,
  p_is_required boolean,
  p_enum_values text[],
  p_unit text,
  p_sort_order integer
)
returns platform.taxonomy_attributes
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attribute platform.taxonomy_attributes;
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.configuration.write') then
    raise exception 'taxonomy_write_forbidden' using errcode = '42501';
  end if;

  insert into platform.taxonomy_attributes
    (node_id, key, label, data_type, is_required, enum_values, unit, sort_order)
  values
    (p_node_id, btrim(p_key), btrim(p_label), p_data_type,
     coalesce(p_is_required, false), p_enum_values,
     nullif(btrim(coalesce(p_unit, '')), ''), coalesce(p_sort_order, 0))
  returning * into v_attribute;

  return v_attribute;
end;
$$;

create function platform.update_taxonomy_attribute(
  p_actor_user_id uuid,
  p_id uuid,
  p_label text,
  p_data_type text,
  p_is_required boolean,
  p_enum_values text[],
  p_unit text,
  p_sort_order integer
)
returns platform.taxonomy_attributes
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attribute platform.taxonomy_attributes;
begin
  if not admin.actor_holds_platform_permission(p_actor_user_id, 'admin.configuration.write') then
    raise exception 'taxonomy_write_forbidden' using errcode = '42501';
  end if;

  update platform.taxonomy_attributes
     set label = btrim(p_label),
         data_type = p_data_type,
         is_required = coalesce(p_is_required, is_required),
         enum_values = p_enum_values,
         unit = nullif(btrim(coalesce(p_unit, '')), ''),
         sort_order = coalesce(p_sort_order, sort_order),
         updated_at = now()
   where id = p_id
  returning * into v_attribute;

  if v_attribute.id is null then
    raise exception 'taxonomy_attribute_missing' using errcode = 'P0002';
  end if;

  return v_attribute;
end;
$$;

revoke all on function platform.create_taxonomy_node(uuid, text, text, uuid, text, text, text, integer, timestamptz) from public;
revoke all on function platform.update_taxonomy_node(uuid, uuid, text, text, integer, timestamptz, timestamptz, boolean) from public;
revoke all on function platform.create_taxonomy_attribute(uuid, uuid, text, text, text, boolean, text[], text, integer) from public;
revoke all on function platform.update_taxonomy_attribute(uuid, uuid, text, text, text, boolean, text[], text, integer) from public;

grant execute on function platform.create_taxonomy_node(uuid, text, text, uuid, text, text, text, integer, timestamptz) to hivorr_api;
grant execute on function platform.update_taxonomy_node(uuid, uuid, text, text, integer, timestamptz, timestamptz, boolean) to hivorr_api;
grant execute on function platform.create_taxonomy_attribute(uuid, uuid, text, text, text, boolean, text[], text, integer) to hivorr_api;
grant execute on function platform.update_taxonomy_attribute(uuid, uuid, text, text, text, boolean, text[], text, integer) to hivorr_api;
