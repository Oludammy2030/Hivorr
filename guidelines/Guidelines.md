# Project Guidelines

This file is a pointer, not a rulebook. It holds no requirements of its own. Every rule lives in an
approved document under `documents/Context/`, and those documents win over this file if they ever
disagree.

Read these, in this order:

1. [`VISION.md`](../documents/Context/VISION.md) — product purpose, activities, business principles.
2. [`ARCHITECTURE.md`](../documents/Context/ARCHITECTURE.md) — the system design, and the
   consolidated open-decision register (§16.4).
3. [`Unified-Account-and-Activity-Permission-Matrix.md`](../documents/Context/Unified-Account-and-Activity-Permission-Matrix.md)
   — who may do what.
4. [`Database-Migration-and-Supabase-Data-API-Rules.md`](../documents/Context/Database-Migration-and-Supabase-Data-API-Rules.md)
   — how the database is reached and changed.
5. [`ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md`](../documents/Context/ENGINEERING_SECURITY_AND_TECHNICAL_STANDARDS.md)
   — how engineering work is done, reviewed, tested and gated.
6. [`OWASP_APPLICATION_SECURITY_STANDARD.md`](../documents/Context/OWASP_APPLICATION_SECURITY_STANDARD.md)
   — the AfriNova-wide application security baseline, applied through the engineering standards.
7. [`VISUAL-IDENTITY.md`](../documents/Context/VISUAL-IDENTITY.md) — the written visual reference.
8. [`AGENTS.md`](../documents/Context/AGENTS.md) — the AI development directive.

Three rules are worth repeating here because they are absolute:

- `src/app/App.tsx` is the only source of truth for the UI, and it is never modified to match a
  document. If a document disagrees with the prototype, the prototype wins and the document has a
  defect.
- No colour, type size, radius, shadow or spacing value may be added or substituted. Every colour
  resolves to a token in `AGENTS.md` §2.2 or §2.3.
- Every production release needs explicit founder approval.

Nothing in this file may be cited as a requirement. Cite the section of the approved document that
actually states the rule.
