-- Verification lane registry, cases, submissions, evidence and decisions (EP-02-010).
--
-- Six independent lanes. A lane state is not an account status and one lane
-- never implies another (matrix §7). This migration owns the value sets, the
-- structural invariants and the access rules; the transition graph arrives with
-- EP-02-011 and the review path with EP-02-015.
--
-- Decisions are append-only: a correction is a new decision, never an edit. The
-- API has no insert, update or delete privilege on them; the verifier writes
-- through a security-definer function in EP-02-015.
--
-- Every table forces RLS. An account reads and writes only its own rows; the
-- lane registry itself is readable by every authenticated account.
--
-- The KYC tier is NOT duplicated here. It stays on `identity.accounts.kyc_tier`
-- (EP-02-014); the `kyc` lane case is the evidence and review record that will
-- drive the tier. A second tier table would create two sources of truth.
--
-- Known divergence, recorded not resolved: `admin.verification_reviews.lane`
-- (CP-019) carries a legacy vocabulary — identity, business, address, phone,
-- document — that does not match the six approved lanes. Closing that gap is a
-- control-portal change and is listed as an outstanding issue in the record.

set local lock_timeout = '5s';

create table profile.verification_lanes (
  key text primary key check (key in (
    'identity',
    'kyc',
    'trade',
    'seller',
    'logistics',
    'business'
  )),
  title text not null check (length(btrim(title)) between 1 and 80),
  description text,
  requires_evidence boolean not null default true,
  sort_order integer not null unique check (sort_order > 0),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

comment on table profile.verification_lanes is
  'The six verification lanes and their display order. Configuration, not per-account state; one row per lane, never one per account.';

create table profile.verification_cases (
  id uuid primary key default platform.uuidv7(),
  account_id uuid not null references identity.accounts (id) on delete cascade,
  lane text not null references profile.verification_lanes (key) on update cascade,
  state text not null default 'NOT_STARTED' check (state in (
    'NOT_STARTED',
    'DRAFT',
    'SUBMITTED',
    'UNDER_REVIEW',
    'APPROVED',
    'REJECTED',
    'EXPIRED'
  )),
  reason_code text check (
    reason_code is null or length(btrim(reason_code)) between 1 and 64
  ),
  state_changed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (account_id, lane)
);

comment on table profile.verification_cases is
  'One case per account and lane. The current lane state, not an account status; approving one lane never changes another.';

create index verification_cases_account_state_idx
  on profile.verification_cases (account_id, state);
create index verification_cases_lane_state_idx
  on profile.verification_cases (lane, state);

create table profile.verification_submissions (
  id uuid primary key default platform.uuidv7(),
  case_id uuid not null references profile.verification_cases (id) on delete cascade,
  account_id uuid not null references identity.accounts (id) on delete cascade,
  lane text not null references profile.verification_lanes (key) on update cascade,
  state text not null default 'DRAFT' check (state in (
    'DRAFT',
    'SUBMITTED',
    'UNDER_REVIEW',
    'APPROVED',
    'REJECTED',
    'EXPIRED'
  )),
  reason_code text check (
    reason_code is null or length(btrim(reason_code)) between 1 and 64
  ),
  submitted_at timestamptz,
  decided_at timestamptz,
  frozen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (decided_at is null or submitted_at is not null),
  check (frozen_at is null or state in ('UNDER_REVIEW', 'APPROVED', 'REJECTED'))
);

comment on table profile.verification_submissions is
  'One submission per review attempt. Identity fields freeze while a submission is under review and reopen after rejection (matrix §7.3); the enforcing trigger arrives with EP-02-011.';

comment on column profile.verification_submissions.frozen_at is
  'When the subject''s identity fields were frozen for this review. Null means not frozen.';

-- One active attempt per lane. A rejected or expired attempt frees the slot so
-- the account can resubmit; two open attempts cannot coexist.
create unique index verification_submissions_active_lane_idx
  on profile.verification_submissions (account_id, lane)
  where state in ('DRAFT', 'SUBMITTED', 'UNDER_REVIEW');

create index verification_submissions_case_idx
  on profile.verification_submissions (case_id, created_at desc);

create table profile.verification_evidence (
  id uuid primary key default platform.uuidv7(),
  submission_id uuid not null references profile.verification_submissions (id) on delete cascade,
  account_id uuid not null references identity.accounts (id) on delete cascade,
  object_key text not null check (length(btrim(object_key)) between 1 and 512),
  content_type text not null check (length(btrim(content_type)) between 1 and 120),
  size_bytes bigint not null check (size_bytes > 0 and size_bytes <= 26214400),
  sha256 text not null check (sha256 ~ '^[a-f0-9]{64}$'),
  scan_state text not null default 'PENDING' check (scan_state in (
    'PENDING',
    'CLEAN',
    'INFECTED',
    'FAILED'
  )),
  uploaded_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (submission_id, object_key)
);

comment on table profile.verification_evidence is
  'A private-object reference attached to a submission. The database stores the object key, never a public URL or the document. Scanning is EP-02-012.';

create index verification_evidence_submission_idx
  on profile.verification_evidence (submission_id, uploaded_at);

create table profile.verification_decisions (
  id uuid primary key default platform.uuidv7(),
  case_id uuid not null references profile.verification_cases (id) on delete cascade,
  submission_id uuid references profile.verification_submissions (id) on delete set null,
  account_id uuid not null references identity.accounts (id) on delete cascade,
  lane text not null references profile.verification_lanes (key) on update cascade,
  decision text not null check (decision in ('APPROVED', 'REJECTED')),
  reason_code text not null check (length(btrim(reason_code)) between 1 and 64),
  reason text not null check (length(btrim(reason)) between 5 and 1000),
  decided_by uuid not null references identity.users (id) on delete restrict,
  decided_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

comment on table profile.verification_decisions is
  'Append-only verification outcome. A correction is a new decision row; update and delete are refused by trigger as well as by grant.';

create index verification_decisions_case_idx
  on profile.verification_decisions (case_id, decided_at desc);
create index verification_decisions_lane_idx
  on profile.verification_decisions (lane, decision, decided_at desc);

create trigger verification_decisions_append_only
before update or delete on profile.verification_decisions
for each row execute function platform.reject_append_only_mutation();

-- Six lanes. `trade` is the professional trade proof; `seller` is the store and
-- proof-of-trade; `logistics` is the vehicle and equipment proof; `business` is
-- registration. Order is display order, not precedence.
insert into profile.verification_lanes (key, title, description, sort_order)
values
  ('identity', 'Identity', 'Government identity document and selfie match.', 1),
  ('kyc', 'KYC tier', 'The evidence required to reach a financial tier.', 2),
  ('trade', 'Trade proof', 'Professional licence, certification or portfolio proof.', 3),
  ('seller', 'Seller store', 'Store profile, identity and proof of trade.', 4),
  ('logistics', 'Logistics equipment', 'Vehicle, rider and equipment proof.', 5),
  ('business', 'Business registration', 'Company registration and representative authority.', 6);

alter table profile.verification_lanes enable row level security;
alter table profile.verification_lanes force row level security;
alter table profile.verification_cases enable row level security;
alter table profile.verification_cases force row level security;
alter table profile.verification_submissions enable row level security;
alter table profile.verification_submissions force row level security;
alter table profile.verification_evidence enable row level security;
alter table profile.verification_evidence force row level security;
alter table profile.verification_decisions enable row level security;
alter table profile.verification_decisions force row level security;

revoke all on profile.verification_lanes from public;
revoke all on profile.verification_cases from public;
revoke all on profile.verification_submissions from public;
revoke all on profile.verification_evidence from public;
revoke all on profile.verification_decisions from public;

-- The registry is configuration every authenticated account may read. It has no
-- writer in the API: a lane is added or retired by migration.
create policy verification_lanes_select on profile.verification_lanes
  for select using (platform.current_account_id() is not null);

create policy verification_cases_select on profile.verification_cases
  for select using (account_id = platform.current_account_id());
create policy verification_cases_insert on profile.verification_cases
  for insert with check (account_id = platform.current_account_id());
create policy verification_cases_update on profile.verification_cases
  for update
  using (account_id = platform.current_account_id())
  with check (account_id = platform.current_account_id());

create policy verification_submissions_select on profile.verification_submissions
  for select using (account_id = platform.current_account_id());
create policy verification_submissions_insert on profile.verification_submissions
  for insert with check (
    account_id = platform.current_account_id()
    and exists (
      select 1 from profile.verification_cases c
       where c.id = case_id
         and c.account_id = platform.current_account_id()
         and c.lane = lane
    )
  );
create policy verification_submissions_update on profile.verification_submissions
  for update
  using (account_id = platform.current_account_id())
  with check (account_id = platform.current_account_id());

create policy verification_evidence_select on profile.verification_evidence
  for select using (account_id = platform.current_account_id());
create policy verification_evidence_insert on profile.verification_evidence
  for insert with check (
    account_id = platform.current_account_id()
    and exists (
      select 1 from profile.verification_submissions s
       where s.id = submission_id
         and s.account_id = platform.current_account_id()
    )
  );

create policy verification_decisions_select on profile.verification_decisions
  for select using (account_id = platform.current_account_id());

grant usage on schema profile to hivorr_api;
grant usage on schema profile to hivorr_readonly;

grant select on profile.verification_lanes to hivorr_api;
grant select, insert, update on profile.verification_cases to hivorr_api;
grant select, insert, update on profile.verification_submissions to hivorr_api;
grant select, insert on profile.verification_evidence to hivorr_api;
grant select on profile.verification_decisions to hivorr_api;

grant select on profile.verification_lanes to hivorr_readonly;
grant select on profile.verification_cases to hivorr_readonly;
grant select on profile.verification_submissions to hivorr_readonly;
grant select on profile.verification_evidence to hivorr_readonly;
grant select on profile.verification_decisions to hivorr_readonly;
