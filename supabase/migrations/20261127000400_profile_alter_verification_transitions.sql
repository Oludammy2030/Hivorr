-- Lane transition enforcement and the review freeze (EP-02-011).
--
-- The domain module `server/src/modules/profile/domain/verification.ts` owns the
-- same table; this function is the database half so a direct SQL update cannot
-- skip the rule. A drift test compares the two.
--
-- The table is shared by cases and submissions. A submission never holds
-- NOT_STARTED, so the two case-only edges are unreachable for it; everything else
-- applies to both.
--
-- Withdrawal and resubmission are subject actions. Begin-review, approve and
-- reject are EP-02-015's and are not granted here beyond the state edges.

set local lock_timeout = '5s';

create function profile.verification_transition_allowed(
  p_from text,
  p_to text
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case
    when p_from = p_to then true
    when p_from = 'NOT_STARTED' and p_to = 'DRAFT' then true
    when p_from = 'DRAFT' and p_to in ('SUBMITTED', 'NOT_STARTED') then true
    when p_from = 'SUBMITTED'
      and p_to in ('UNDER_REVIEW', 'DRAFT', 'EXPIRED') then true
    when p_from = 'UNDER_REVIEW' and p_to in ('APPROVED', 'REJECTED') then true
    when p_from = 'APPROVED' and p_to = 'EXPIRED' then true
    when p_from = 'REJECTED' and p_to = 'DRAFT' then true
    when p_from = 'EXPIRED' and p_to = 'DRAFT' then true
    else false
  end
$$;

comment on function profile.verification_transition_allowed(text, text) is
  'The approved lane transition table. Approved never returns to draft or submitted; only expiry leaves an approved lane.';

revoke all on function profile.verification_transition_allowed(text, text) from public;
grant execute on function profile.verification_transition_allowed(text, text) to hivorr_api;
grant execute on function profile.verification_transition_allowed(text, text) to hivorr_readonly;

create function profile.enforce_verification_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.state is distinct from old.state
     and not profile.verification_transition_allowed(old.state, new.state) then
    raise exception 'verification_transition_invalid: % -> %', old.state, new.state
      using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke all on function profile.enforce_verification_transition() from public;
grant execute on function profile.enforce_verification_transition() to hivorr_api;

create trigger verification_cases_transition
before update of state on profile.verification_cases
for each row execute function profile.enforce_verification_transition();

create trigger verification_submissions_transition
before update of state on profile.verification_submissions
for each row execute function profile.enforce_verification_transition();

-- Freeze: the public identity fields cannot change while any submission for the
-- account is under review (matrix §7.3). Bio, locale and timezone stay editable;
-- the frozen set grows when the identity-document table lands (EP-02-012).
create function profile.identity_fields_are_frozen(p_account_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from profile.verification_submissions s
     where s.account_id = p_account_id
       and s.state = 'UNDER_REVIEW'
  )
$$;

comment on function profile.identity_fields_are_frozen(uuid) is
  'True while a verification submission for the account is under review. Security definer so the check is not narrowed by the writer''s row-level security.';

revoke all on function profile.identity_fields_are_frozen(uuid) from public;
grant execute on function profile.identity_fields_are_frozen(uuid) to hivorr_api;

create function profile.enforce_identity_freeze()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (new.display_name is distinct from old.display_name
      or new.avatar_url is distinct from old.avatar_url)
     and profile.identity_fields_are_frozen(old.account_id) then
    raise exception 'identity_frozen_for_review' using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke all on function profile.enforce_identity_freeze() from public;
grant execute on function profile.enforce_identity_freeze() to hivorr_api;

create trigger profiles_identity_freeze
before update of display_name, avatar_url on profile.profiles
for each row execute function profile.enforce_identity_freeze();
