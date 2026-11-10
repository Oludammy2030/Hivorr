-- Activity activation state machine (EP-01-033).
--
-- The domain module owns the transition table; this trigger is the database
-- backstop. A new row may start INACTIVE or ACTIVE. RESTRICTED and SUSPENDED
-- are platform actions on an existing activation.
--
-- Allowed transitions:
--   INACTIVE  -> ACTIVE
--   ACTIVE    -> INACTIVE | RESTRICTED | SUSPENDED
--   RESTRICTED-> ACTIVE | INACTIVE
--   SUSPENDED -> ACTIVE | INACTIVE
-- A same-state update is a no-op (idempotent activation/deactivation).

create or replace function profile.enforce_activation_transition()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    if new.state in ('RESTRICTED', 'SUSPENDED') then
      raise exception 'a new activation cannot start in %', new.state
        using errcode = '23514';
    end if;
    return new;
  end if;

  if old.state = new.state then
    return new;
  end if;

  if (old.state = 'INACTIVE' and new.state = 'ACTIVE')
     or (old.state = 'ACTIVE'
         and new.state in ('INACTIVE', 'RESTRICTED', 'SUSPENDED'))
     or (old.state in ('RESTRICTED', 'SUSPENDED')
         and new.state in ('ACTIVE', 'INACTIVE')) then
    return new;
  end if;

  raise exception 'invalid activity activation transition % -> %',
    old.state, new.state using errcode = '23514';
end;
$$;

revoke all on function profile.enforce_activation_transition() from public;

create trigger activity_activation_transition
  before insert or update of state on profile.activity_activations
  for each row execute function profile.enforce_activation_transition();

comment on function profile.enforce_activation_transition() is
  'Rejects an activation state transition outside the approved table.';
