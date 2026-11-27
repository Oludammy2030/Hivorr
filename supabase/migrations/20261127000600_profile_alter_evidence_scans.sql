-- Evidence scan state machine (EP-02-012, scanning slice).
--
-- A reference is PENDING until one scan decides it. Every decided state is
-- terminal: a rescan is a new reference, so a bad object cannot be laundered into
-- a clean one by a second update. The domain module mirrors this table and a
-- drift test compares them.

set local lock_timeout = '5s';

create function profile.evidence_scan_transition_allowed(
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
    when p_from = 'PENDING' and p_to in ('CLEAN', 'INFECTED', 'FAILED') then true
    else false
  end
$$;

comment on function profile.evidence_scan_transition_allowed(text, text) is
  'Evidence scan transitions: PENDING may be decided once; CLEAN, INFECTED and FAILED are terminal.';

revoke all on function profile.evidence_scan_transition_allowed(text, text) from public;
grant execute on function profile.evidence_scan_transition_allowed(text, text) to hivorr_api;
grant execute on function profile.evidence_scan_transition_allowed(text, text) to hivorr_readonly;

create function profile.enforce_evidence_scan_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.scan_state is distinct from old.scan_state
     and not profile.evidence_scan_transition_allowed(old.scan_state, new.scan_state) then
    raise exception 'evidence_scan_transition_invalid: % -> %', old.scan_state, new.scan_state
      using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke all on function profile.enforce_evidence_scan_transition() from public;
grant execute on function profile.enforce_evidence_scan_transition() to hivorr_api;

create trigger verification_evidence_scan_transition
before update of scan_state on profile.verification_evidence
for each row execute function profile.enforce_evidence_scan_transition();
