-- EP-02-01: Two-Tier Taxonomy Seed Data & Registry Population
--
-- Seeds the existing `industries` (tier-1) and `professions` (tier-2) registry
-- tables — created and finalized in EP-01-06 (migration
-- 20260821090001_entity_taxonomy_tables.sql) — with the initial Nigerian-market
-- taxonomy.
--
-- This migration is PURE DML. It introduces no DDL, no RLS policy changes, no
-- GRANT/REVOKE statements, and no client-side code. Writes execute under the
-- migration (superuser) context which bypasses RLS; the existing service-role
-- write grant and default-deny + public-read RLS posture are left untouched.
--
-- Idempotency: every INSERT uses ON CONFLICT (slug) DO NOTHING so the migration
-- is safe to re-run across dev / staging / prod without duplication or failure.
--
-- Referential integrity: profession rows resolve `industry_id` via a slug
-- subselect against `industries` (never hardcoded UUIDs), so FK validity holds
-- regardless of gen_random_uuid() output.
--
-- Conventions inherited from EP-01-06:
--   - Slugs are lowercase kebab-case, globally unique, SEO-stable, format-enforced
--     by the table CHECK constraints.
--   - `created_by` is set to NULL to mark system-seeded (not user-authored) data.
--   - `sort_order` uses increments of 10, leaving room for future insertions
--     without renumbering.

-- ─── 1. industries (tier-1) ──────────────────────────────────────────────────────
insert into public.industries (slug, name, description, sort_order, is_active, created_by)
values
  ('legal',              'Legal',              'Legal services, advisory, and compliance',           10, true, null),
  ('technology',         'Technology',         'Software, hardware, IT, and digital services',        20, true, null),
  ('healthcare',         'Healthcare',         'Medical, pharmaceutical, and wellness services',      30, true, null),
  ('construction',       'Construction',       'Building, civil engineering, and trades',             40, true, null),
  ('financial-services', 'Financial Services', 'Accounting, auditing, tax, and advisory',              50, true, null),
  ('creative',           'Creative',           'Design, media, content, and entertainment',           60, true, null),
  ('education',          'Education',          'Tutoring, training, and academic services',           70, true, null),
  ('logistics',          'Logistics',          'Transport, delivery, warehousing, and supply chain',  80, true, null)
on conflict (slug) do nothing;

-- ─── 2. professions (tier-2) ──────────────────────────────────────────────────────

-- Legal
insert into public.professions (industry_id, slug, name, description, sort_order, is_active, created_by)
select i.id, v.slug, v.name, v.description, v.sort_order, true, null
from public.industries i
cross join (values
  ('corporate-lawyer', 'Corporate Lawyer', 'Corporate law, contracts, and commercial advisory',  10),
  ('criminal-lawyer',  'Criminal Lawyer',  'Criminal defense and litigation representation',      20),
  ('family-lawyer',    'Family Lawyer',    'Family, divorce, and matrimonial law',                30),
  ('legal-consultant', 'Legal Consultant', 'General legal advisory and compliance consulting',    40),
  ('notary-public',    'Notary Public',    'Document notarization and certification',             50)
) as v(slug, name, description, sort_order)
where i.slug = 'legal'
on conflict (slug) do nothing;

-- Technology
insert into public.professions (industry_id, slug, name, description, sort_order, is_active, created_by)
select i.id, v.slug, v.name, v.description, v.sort_order, true, null
from public.industries i
cross join (values
  ('software-engineer',    'Software Engineer',    'Design and build software applications and systems',  10),
  ('web-developer',        'Web Developer',        'Build and maintain web applications and sites',        20),
  ('mobile-developer',     'Mobile Developer',     'Develop iOS, Android, and cross-platform mobile apps',  30),
  ('data-analyst',         'Data Analyst',         'Analyze data and produce actionable insights',         40),
  ('ui-ux-designer',       'UI/UX Designer',       'Design user interfaces and experiences',               50),
  ('devops-engineer',      'DevOps Engineer',      'Automate deployment, CI/CD, and infrastructure',       60),
  ('cybersecurity-analyst','Cybersecurity Analyst','Assess and defend against security threats',            70),
  ('it-support-specialist','IT Support Specialist', 'Provide technical support and troubleshooting',        80)
) as v(slug, name, description, sort_order)
where i.slug = 'technology'
on conflict (slug) do nothing;

-- Healthcare
insert into public.professions (industry_id, slug, name, description, sort_order, is_active, created_by)
select i.id, v.slug, v.name, v.description, v.sort_order, true, null
from public.industries i
cross join (values
  ('general-practitioner',  'General Practitioner',  'Primary and general medical care',              10),
  ('pharmacist',            'Pharmacist',            'Dispense medication and advise on drug therapy', 20),
  ('nurse',                 'Nurse',                 'Patient care and clinical support',              30),
  ('dentist',               'Dentist',              'Oral and dental health care',                    40),
  ('physiotherapist',       'Physiotherapist',      'Physical rehabilitation and mobility therapy',   50),
  ('medical-lab-technician','Medical Lab Technician','Diagnostic laboratory testing and analysis',     60)
) as v(slug, name, description, sort_order)
where i.slug = 'healthcare'
on conflict (slug) do nothing;

-- Construction
insert into public.professions (industry_id, slug, name, description, sort_order, is_active, created_by)
select i.id, v.slug, v.name, v.description, v.sort_order, true, null
from public.industries i
cross join (values
  ('electrician',       'Electrician',       'Electrical wiring, installation, and repair',     10),
  ('plumber',           'Plumber',           'Water, drainage, and pipe systems',               20),
  ('civil-engineer',    'Civil Engineer',    'Infrastructure and structural engineering',       30),
  ('architect',         'Architect',         'Building design and planning',                    40),
  ('carpenter',         'Carpenter',         'Woodwork, framing, and finishing',                50),
  ('quantity-surveyor', 'Quantity Surveyor', 'Cost estimation and project surveying',            60)
) as v(slug, name, description, sort_order)
where i.slug = 'construction'
on conflict (slug) do nothing;

-- Financial Services
insert into public.professions (industry_id, slug, name, description, sort_order, is_active, created_by)
select i.id, v.slug, v.name, v.description, v.sort_order, true, null
from public.industries i
cross join (values
  ('chartered-accountant', 'Chartered Accountant', 'Accounting, audit, and financial reporting', 10),
  ('tax-consultant',       'Tax Consultant',       'Tax planning and filing advisory',          20),
  ('auditor',              'Auditor',              'Independent financial and compliance audits', 30),
  ('financial-advisor',    'Financial Advisor',    'Investment and wealth planning',             40),
  ('bookkeeper',           'Bookkeeper',           'Record-keeping and ledger management',       50)
) as v(slug, name, description, sort_order)
where i.slug = 'financial-services'
on conflict (slug) do nothing;

-- Creative
insert into public.professions (industry_id, slug, name, description, sort_order, is_active, created_by)
select i.id, v.slug, v.name, v.description, v.sort_order, true, null
from public.industries i
cross join (values
  ('graphic-designer',   'Graphic Designer',   'Visual design, branding, and layout',         10),
  ('photographer',       'Photographer',       'Photography for events, products, and editorial', 20),
  ('videographer',       'Videographer',       'Video production and editing',                 30),
  ('content-writer',     'Content Writer',     'Written content, copy, and articles',          40),
  ('music-producer',     'Music Producer',     'Music recording, mixing, and production',      50),
  ('social-media-manager','Social Media Manager','Social media strategy and management',        60)
) as v(slug, name, description, sort_order)
where i.slug = 'creative'
on conflict (slug) do nothing;

-- Education
insert into public.professions (industry_id, slug, name, description, sort_order, is_active, created_by)
select i.id, v.slug, v.name, v.description, v.sort_order, true, null
from public.industries i
cross join (values
  ('private-tutor',      'Private Tutor',      'One-on-one academic tutoring',          10),
  ('language-instructor', 'Language Instructor', 'Language teaching and instruction',      20),
  ('exam-prep-coach',    'Exam Prep Coach',    'Exam and test preparation coaching',     30),
  ('corporate-trainer',  'Corporate Trainer',  'Workplace skills and training',          40),
  ('music-instructor',   'Music Instructor',   'Music lessons and instruction',          50)
) as v(slug, name, description, sort_order)
where i.slug = 'education'
on conflict (slug) do nothing;

-- Logistics
insert into public.professions (industry_id, slug, name, description, sort_order, is_active, created_by)
select i.id, v.slug, v.name, v.description, v.sort_order, true, null
from public.industries i
cross join (values
  ('delivery-rider',        'Delivery Rider',        'Last-mile delivery and courier',          10),
  ('logistics-coordinator', 'Logistics Coordinator', 'Shipment coordination and tracking',      20),
  ('warehouse-manager',     'Warehouse Manager',     'Warehouse and inventory operations',      30),
  ('fleet-manager',         'Fleet Manager',         'Vehicle fleet operations and dispatch',   40),
  ('supply-chain-analyst',  'Supply Chain Analyst',  'Supply chain planning and optimization',  50)
) as v(slug, name, description, sort_order)
where i.slug = 'logistics'
on conflict (slug) do nothing;
