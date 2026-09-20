-- Registration identity extension — grant fix for overload
-- The 20260920090001 migration added a 7-arg overload
-- (p_first_name, p_middle_name, p_last_name, p_display_name, p_phone_number, p_bio, p_legal_name)
-- but left the legacy 3-arg overload (p_legal_name, p_display_name, p_bio) without a grant
-- after the `revoke execute on all functions` baseline. Legacy callers (existing onboarding
-- installs, e.g. TestFlight) still invoke the 3-arg form, so both overloads must be granted.
grant execute on function public.entity_profile_update(text, text, text) to authenticated, service_role;
grant execute on function public.entity_profile_update(text, text, text, text, text, text, text) to authenticated, service_role;
