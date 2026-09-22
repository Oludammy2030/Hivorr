-- Fix overload ambiguity from 20260922090001
-- That migration created a 5-arg manage_user_list(text,text,int,int,text)
-- alongside the existing 4-arg (text,text,int,int). Positional calls with
-- 4 args became ambiguous (42725). Keep only the 5-arg with capability
-- default null so 4 positional args still work via default.

drop function if exists public.manage_user_list(text, text, int, int);

-- Re-apply comment (kept from 20260922090001)
comment on function public.manage_user_list(text, text, int, int, text) is
  'Paginated admin user directory with capability filter. Supports case-insensitive search on display/legal name, entity status filter, and capability filter (hire | offer | both | professional | client) where professional = offer,both and client = hire,both so Both appears in both filtered views. Row now includes capability. Admin-gated. Pagination 1..100.';

-- Grants for the surviving overload
grant execute on function public.manage_user_list(text, text, int, int, text) to authenticated, service_role;
