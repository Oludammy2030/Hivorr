-- UUIDv7 generation for server-side identifiers. The timestamp occupies the
-- first 48 bits; the version and variant bits are set per RFC 9562.
-- Uses gen_random_uuid() bytes so no pgcrypto extension is required.

create or replace function platform.uuidv7()
returns uuid
language plpgsql
volatile
as $$
declare
  ts_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  bytes bytea;
begin
  bytes :=
    substring(int8send(ts_ms) from 3 for 6) ||
    substring(decode(replace(gen_random_uuid()::text, '-', ''), 'hex') from 1 for 10);

  bytes := set_byte(bytes, 6, (get_byte(bytes, 6) & 15) | 112);
  bytes := set_byte(bytes, 8, (get_byte(bytes, 8) & 63) | 128);

  return encode(bytes, 'hex')::uuid;
end;
$$;

comment on function platform.uuidv7() is
  'Server-side UUIDv7 identifier. Version and variant bits follow RFC 9562.';

revoke all on function platform.uuidv7() from public;
grant execute on function platform.uuidv7() to hivorr_api, hivorr_worker;
