-- Taxonomy registry (EP-02-020).
--
-- One registry supports the two approved taxonomies:
--   profession: Industry -> Profession
--   product:    vertical -> category -> subcategory -> product type -> attributes
--
-- Nodes are reference data. Reads are public to the API/read-only roles; writes
-- are deliberately not granted to the API role. Admin writes arrive through the
-- configuration service in EP-02-021. Cycles, orphans, duplicate siblings and
-- invalid level/parent combinations are rejected by the database as well as the
-- domain.

set local lock_timeout = '5s';

create table platform.taxonomy_nodes (
  id uuid primary key default platform.uuidv7(),
  taxonomy text not null check (taxonomy in ('profession', 'product')),
  level text not null check (level in (
    'industry', 'profession',
    'vertical', 'category', 'subcategory', 'product_type'
  )),
  parent_id uuid references platform.taxonomy_nodes (id) on delete restrict,
  slug text not null check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name text not null check (length(btrim(name)) between 1 and 160),
  description text,
  version integer not null default 1 check (version > 0),
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (parent_id is null or parent_id <> id),
  check (effective_to is null or effective_to > effective_from),
  check (
    (taxonomy = 'profession' and level in ('industry', 'profession'))
    or
    (taxonomy = 'product' and level in ('vertical', 'category', 'subcategory', 'product_type'))
  )
);

comment on table platform.taxonomy_nodes is
  'Admin-configurable profession and product taxonomy nodes. Reference data; not a marketplace listing table.';

create unique index taxonomy_nodes_sibling_slug_idx
  on platform.taxonomy_nodes (taxonomy, parent_id, slug)
  where parent_id is not null;

create unique index taxonomy_nodes_root_slug_idx
  on platform.taxonomy_nodes (taxonomy, slug)
  where parent_id is null;

create index taxonomy_nodes_parent_idx on platform.taxonomy_nodes (parent_id);
create index taxonomy_nodes_active_idx
  on platform.taxonomy_nodes (taxonomy, level, is_active);

create function platform.validate_taxonomy_node()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_parent_taxonomy text;
  v_parent_level text;
  v_cycle boolean;
begin
  if new.parent_id is null then
    if new.level not in ('industry', 'vertical') then
      raise exception 'taxonomy_root_level_invalid' using errcode = '23514';
    end if;
    return new;
  end if;

  if new.level in ('industry', 'vertical') then
    raise exception 'taxonomy_root_must_not_have_parent' using errcode = '23514';
  end if;

  select taxonomy, level
    into v_parent_taxonomy, v_parent_level
    from platform.taxonomy_nodes
   where id = new.parent_id;

  if not found then
    raise exception 'taxonomy_parent_missing' using errcode = '23503';
  end if;

  if v_parent_taxonomy <> new.taxonomy then
    raise exception 'taxonomy_parent_taxonomy_mismatch' using errcode = '23514';
  end if;

  if not (
    (new.level = 'profession' and v_parent_level = 'industry')
    or (new.level = 'category' and v_parent_level = 'vertical')
    or (new.level = 'subcategory' and v_parent_level = 'category')
    or (new.level = 'product_type' and v_parent_level = 'subcategory')
  ) then
    raise exception 'taxonomy_parent_level_invalid' using errcode = '23514';
  end if;

  with recursive ancestors as (
    select id, parent_id
      from platform.taxonomy_nodes
     where id = new.parent_id
    union all
    select n.id, n.parent_id
      from platform.taxonomy_nodes n
      join ancestors a on n.id = a.parent_id
  )
  select exists (select 1 from ancestors where id = new.id) into v_cycle;

  if v_cycle then
    raise exception 'taxonomy_cycle' using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger taxonomy_nodes_validate
before insert or update of taxonomy, level, parent_id
on platform.taxonomy_nodes
for each row execute function platform.validate_taxonomy_node();

create table platform.taxonomy_attributes (
  id uuid primary key default platform.uuidv7(),
  node_id uuid not null references platform.taxonomy_nodes (id) on delete cascade,
  key text not null check (key ~ '^[a-z][a-z0-9_]*$'),
  label text not null check (length(btrim(label)) between 1 and 120),
  data_type text not null check (data_type in (
    'text', 'number', 'boolean', 'enum', 'date'
  )),
  is_required boolean not null default false,
  enum_values text[],
  unit text,
  sort_order integer not null default 0 check (sort_order >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (node_id, key),
  check (
    data_type <> 'enum'
    or (enum_values is not null and cardinality(enum_values) > 0)
  )
);

comment on table platform.taxonomy_attributes is
  'Typed attribute definitions attached to a profession or product-type node. Values are not stored here.';

create function platform.validate_taxonomy_attribute()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_level text;
begin
  select level into v_level
    from platform.taxonomy_nodes
   where id = new.node_id;

  if not found then
    raise exception 'taxonomy_node_missing' using errcode = '23503';
  end if;

  if v_level not in ('profession', 'product_type') then
    raise exception 'taxonomy_attribute_level_invalid' using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger taxonomy_attributes_validate
before insert or update of node_id
on platform.taxonomy_attributes
for each row execute function platform.validate_taxonomy_attribute();

alter table platform.taxonomy_nodes enable row level security;
alter table platform.taxonomy_attributes enable row level security;

create policy taxonomy_nodes_select on platform.taxonomy_nodes
  for select to hivorr_api, hivorr_readonly using (true);
create policy taxonomy_attributes_select on platform.taxonomy_attributes
  for select to hivorr_api, hivorr_readonly using (true);

grant select on platform.taxonomy_nodes to hivorr_api, hivorr_readonly;
grant select on platform.taxonomy_attributes to hivorr_api, hivorr_readonly;
