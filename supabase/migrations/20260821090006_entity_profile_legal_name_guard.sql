-- EP-01-06 (corrective #6): legal_name mutation gate.
--
-- D5 requires that the legal_name anchor may only be mutated through the
-- validating RPC (entity_profile_update), never via direct PostgREST PATCH,
-- while keeping all RPCs SECURITY INVOKER (no new SECURITY DEFINER) per plan.
--
-- Resolution: grant UPDATE(legal_name) to authenticated and install a BEFORE
-- UPDATE trigger that blocks any legal_name change unless the calling RPC set
-- the platform.rpc_invocation GUC. This enforces AGENT.md Rule 3 anchor
-- discipline without bypassing invoker privilege checks.

grant update (entity_id, legal_name, display_name, bio, avatar_path, country_code)
  on table public.entity_profiles to authenticated;

create or replace function public.entity_profiles_guard_legal_name()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if (new.legal_name is distinct from old.legal_name)
     and coalesce(current_setting('platform.rpc_invocation', true), '') <> 'on' then
    perform public.platform_raise_error(
      'PLT002',
      'Legal name may only be changed through the validated entity_profile_update RPC.'
    );
  end if;
  return new;
end;
$$;

comment on function public.entity_profiles_guard_legal_name() is
  'Enforces AGENT.md Rule 3 anchor discipline: direct legal_name changes are blocked; only entity_profile_update (sets platform.rpc_invocation) may mutate it.';

drop trigger if exists entity_profiles_guard_legal_name_update on public.entity_profiles;

create trigger entity_profiles_guard_legal_name_update
  before update on public.entity_profiles
  for each row
  execute function public.entity_profiles_guard_legal_name();

comment on trigger entity_profiles_guard_legal_name_update on public.entity_profiles is
  'Blocks non-RPC legal_name mutation; pairs with entity_profile_update setting platform.rpc_invocation.';
