-- Module schemas. One schema per backend module; a module never reads another
-- module's tables directly. Supabase manages its own auth/storage schemas; the
-- application does not use them (Position A: managed PostgreSQL only).

create schema if not exists identity;
create schema if not exists profile;
create schema if not exists market;
create schema if not exists services;
create schema if not exists errands;
create schema if not exists logistics;
create schema if not exists finance;
create schema if not exists messaging;
create schema if not exists admin;
create schema if not exists platform;
create schema if not exists private;

comment on schema identity is 'Accounts, users, credentials, sessions, devices, memberships, grants, MFA';
comment on schema profile is 'Profiles, activity activation, verification cases, documents, KYC tiers';
comment on schema market is 'Stores, products, taxonomy bindings, carts, orders, fulfilments';
comment on schema services is 'Jobs, applications, engagements, milestones, deliverables';
comment on schema errands is 'Errand requests, offers, assignment, task status';
comment on schema logistics is 'Dispatch pool, assignments, delivery legs, tracking, proof of delivery';
comment on schema finance is 'Ledger accounts, journal entries, escrow, payouts, limits, reconciliation';
comment on schema messaging is 'Threads, messages, attachments, notifications, delivery attempts';
comment on schema admin is 'Admin roles, review queues, moderation, configuration, audit access, disputes';
comment on schema platform is 'Taxonomy, feature flags, media, search, audit log, reference numbers, geo';
comment on schema private is 'Internal helpers that are never exposed to the Data API or a client';
