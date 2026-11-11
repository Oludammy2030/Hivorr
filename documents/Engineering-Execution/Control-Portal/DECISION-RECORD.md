# Control Portal — Decision Record

| Field | Value |
|---|---|
| **Document** | `documents/Engineering-Execution/Control-Portal/DECISION-RECORD.md` |
| **Workstream** | `CP` — Control Portal governance programme |
| **Decision date** | 11 November 2026 |
| **Decision authority** | Founder, AfriNova Digital Limited |
| **Status** | **APPROVED — 11 November 2026.** Binding for the P0 and P1 scope it names. |
| **Basis** | Founder approval of `CONTROL-PORTAL-ARCHITECTURE-ASSESSMENT.md` and `CONTROL-PORTAL-IMPLEMENTATION-PLAN.md` |

> This record closes the decisions the assessment marked `[OPEN]` where the founder approved a
> recommendation. It does **not** close financial, verification, retention or legal-policy decisions
> that were not stated as concrete recommendations. Those remain `[OPEN]` and are listed in §3.

---

## 1. Decisions approved

| ID | Decision | Approved position | Effect |
|---|---|---|---|
| **D-01** | Control / staff / partner scope | **One governance architecture, two operational shells.** Keep the four approved portals. `control` is privileged governance; `staff` is job-scoped operations; `partner` is external partnership. All three consume the same `admin` governance domain and authorization engine. | No merge of staff into control. No new portal. No change to session audiences. |
| **D-02** | Management visibility vs record-level data | Platform-wide **aggregate** visibility by default for management roles. Record-level identity, financial, verification and investigation data require a scoped capability, a stated reason where sensitive, and an audit record. | Role catalogue and read models are built to this rule. Exports require a capability. |
| **D-03** | Role ownership | `admin` owns roles, permissions and assignments. `identity.grants` remains the privileged-surface grant record. The capability engine composes both. | New tables live in `admin`; `identity.grants` is not overloaded. |
| **D-04** | Case model | **One case spine** with typed cases (`support`, `complaint`, `dispute`, `investigation`, `incident`, `verification_review`, `financial_exception`, `security_incident`, `staff_conduct`, `partner_conduct`) and `parent_case_id` for escalation. | No separate support, dispute and investigation systems. |
| **D-05** | Partner organisation | Partner organisations are `admin` entities. Representatives are users linked through identity memberships. No second account, credential store, wallet or activity capability. | Partner schema references `identity.users`; isolation by organisation scope. |
| **D-06** | Approval engine | A narrow, typed approval service with fixed stages and configurable thresholds. No BPMN, workflow engine, expression language or plugin runtime. | Maker-checker and separation of duties are enforceable without a generic engine. |
| **D-07** | Audit integrity | Keep the append-only audit; add reason, approval reference and session context. Hash-chain and signed-export work is approved in principle; its implementation timing may be sequenced after the P0 audit contract. | No weakening of the append-only control. |
| **D-08** | Initial role catalogue | Approved in principle: the roles and permission families in `Administrative-Governance-Architecture.md` §5. The detailed permission-to-role mapping is finalised in CP-012 and recorded there. | Roles exist as collections; scope is separate. |
| **D-13** | Workstream model | The Control Portal is a cross-phase `CP` workstream. Identifiers are `CP-001` … `CP-043`, mapped to an owning phase. | Recorded as an explicit exception in `ENGINEERING_EXECUTION_STRUCTURE.md` §8.1. |

## 2. Execution authority

- The **P0 tranche** (`CP-001` … `CP-008`) is authorised to proceed in dependency order.
- The **P1 tranche** (`CP-010` … `CP-024`) is authorised in principle but remains gated by the EP-02
  entry gate and by the decisions in §3.
- The **P2 tranche** (`CP-030` … `CP-038`) remains gated by the existence of the ledger and the
  activity modules.
- The **P3 tranche** (`CP-040` … `CP-043`) remains gated by the conditions in the implementation plan.
- No agent may deploy to production, change DNS, change secrets or approve a release.

## 3. Decisions that remain open

These are **not** approved by the 11 November 2026 decision and must not be implemented as if they
were.

| # | Item | Why still open | Blocks |
|---|---|---|---|
| O-01 | Funds custody and ledger policy (BD-D01) | Requires the recorded business/legal decision and VFD confirmation | `finance` module; CP-030/031 |
| O-02 | Take rate and fee model (BD-D02) | Commercial decision | Commission, fee reporting |
| O-03 | Escrow holding period and dispute rules (BD-D03) | Commercial/legal decision | Escrow, refunds, CP-031 |
| O-04 | KYC tier ladder and limits | Not specified in any approved source | Verification and finance gating |
| O-05 | Verification vendor / standard | Not chosen | CP-019 evidence flow |
| O-06 | Retention periods and legal hold | Requires founder and counsel | Audit, evidence, documents, deletion |
| O-07 | Data residency and primary region | Not decided | Hosting and data governance |
| O-08 | Investigation authority limits | Approved in principle; the specific sanction matrix is finalised in CP-021 | Case decisions and executions |
| O-09 | Staff performance measurement purpose | Not approved; must not become surveillance | CP-041 |
| O-10 | Financial metric definitions (rates and periods) | Definitions in the assessment are proposed; numeric policy is open | CP-030/035 |
| O-11 | Export policy details (watermark, row limits, approver) | Not specified | CP-035 |
| O-12 | Future activity scope | No new activity is approved | CP-042 |

## 4. Conditions and constraints

1. No package starts before its G0 record exists.
2. No financial or verification package starts before its open decision is closed.
3. No activity-governance screen is built before the activity module exists.
4. No account-scoped table has its RLS policy relaxed to make an administrative read work.
5. No second identity, role, capability, audit, ledger, file store, notification system or design
   system is introduced.
6. Every sensitive action has a deny-path test and an audit record.
7. The founder remains the only authority for production release and for widening who may do what.
8. `DEV-003` (single reviewer) remains a recorded residual until a second reviewer is appointed; the
   compensating controls apply to authorization and audit changes.

## 5. Change control

A change to an approved position in §1 requires:

1. a written proposal naming the decision, the reason and the alternatives;
2. an impact statement covering schema, capabilities, audit and existing users;
3. founder approval recorded in this file;
4. a changelog entry below;
5. no retroactive rewrite of history.

## 6. Changelog

| Date | Change | Authority |
|---|---|---|
| 11 November 2026 | Initial decision record; D-01…D-08 and D-13 approved; open items O-01…O-12 recorded | Founder |

---

**End of decision record.**
