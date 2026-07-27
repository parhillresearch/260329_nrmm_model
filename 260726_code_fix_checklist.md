# Code fix checklist: data capture and classification issues

**26 July 2026, updated 28 July | Working list for the analysis code.**

> **Status 28 July: all 13 unblocked items are implemented in `nrmm_model_v5.R` and
> `nrmm_dashboard_v5.R`.** Rows below marked DONE. The 5 blocked items remain open pending
> the audit team's response. `nrmm_model_v4.R` and `nrmm_dashboard_v4.R` are superseded.

Ordered by impact on published figures. "Blocked" means the fix depends on an auditor answer (see `260726_audit_data_queries.md`); "Ready" means it can be done now without further input.

---

## A. Classification and grouping

| # | Issue | Where | Impact | Status |
|---|---|---|---|---|
| A1 | Generators leave the Constant Speed group when they reach Stage V, because `Engine Type` is recorded "Variable" for all 218 Stage V units. Group cannot improve by construction. | `nrmm_model_v4.R`, spine `subgroup` assignment | Invalidates the generator finding; contaminates CAZ+ and Rest of London | **Blocked** — needs classification intent |
| A2 | Crushers show the same pattern: 15 "Constant" records all at Stage IIIA, all 76 at IIIB/IV/V "Variable" | same | ~2% of Constant Speed group | **Blocked** — same answer resolves it |
| A3 | Restore the classification choice as an explicit sensitivity toggle rather than a hard-coded rule, as `tree_dashboard_v3-v5.R` had before unification | model + dashboard | Makes the assumption visible instead of silent | Ready (design now, populate when A1 answered) — **DONE (v5)** |
| A4 | BCP and P24 Machine Groups not implemented, so the 2025 variable-speed cohort is dropped and phase C holds 63 machines | spine `subgroup` | Phase C effectively unanalysed | **Backlog, not now** — P24 is a different timeframe and project. Under P24 there is a single group/zone, so there is a structural discontinuity; a comparison would require regrouping everything onto a common basis. Get the pre-2025 analysis right first. |

## B. Stage field handling

| # | Issue | Where | Impact | Status |
|---|---|---|---|---|
| B1 | `"Electric"` (31 records, growing: 1 in 2022 to 15 in 2025) maps to NA and drops out. Schema treats zero-emission as stage 7. | `stage_to_int()` | Systematically removes the cleanest machines, concentrated in recent years — same failure mode as A1 | **Blocked** — confirm Electric = ZE |
| B2 | Case typos `"iIIB"` (1) and `"iV"` (3) map to NA | `stage_to_int()` | 4 records | Ready — normalise case before matching — **DONE (v5)** |
| B3 | `"Uncertified"` (25 initial, 26 final) maps to NA with no explicit handling or count | `stage_to_int()` | Silent exclusion | **Blocked** — now a question to auditors (query note §5) |
| B4 | Same machine recorded at different stages across visits: 40 of 598 repeat-audited machines (7%), 5 of them differing by 3-4 stages | not currently detected | Undermines stage reliability; already known to be ~1% symmetric noise at record level | Ready — add a detection report, flag implausible spreads — **DONE (v5)** |

## C. Outcome and situation fields

| # | Issue | Where | Impact | Status |
|---|---|---|---|---|
| C1 | `"Pending"` final compliance (23 records, 2018-2020) falls into "not remediated" | `nc_outcome` | Conflates unresolved with unremediated | **Blocked** — confirm meaning |
| C2 | Site-level markers (Baselining, Site Complete, No Apparent Works, DECLINED AUDIT) written into `Initial`/`Final Machinery Compliance` (1,662 rows each), the stage fields (883/884) and `Initial`/`Final Site Compliance` (1,592/1,590) — the same marker across machine and site fields on one row | spine filter, `initial_status` | 60 rows reach the spine (0.5%), but **34 of them sit in phase C, which holds only 63 machines**; all 59 with a usable stage are currently counted non-compliant | Ready — rule agreed, see section F — **DONE (v5)** |
| C3 | `"Inappropriate for Audit"` (131) not excluded, unlike `"No NRMM"` (891) | spine filter | None on stage results | **Blocked** — confirm scope, then exclude |
| C4 | TAN capture begins 2021; all 345 pre-2021 removals are untraceable by construction, and recent removals are right-censored (displacement 62% for 2021 removals falling to 45% for 2025) | `removal_fate`, report | Reported 55.9% is a blend across observation windows and is a lower bound | Ready — restrict to the measurable window, report by removal year, state censoring — **DONE (v5)** |

## D. Processing defects (ours, not the data's)

| # | Issue | Where | Impact | Status |
|---|---|---|---|---|
| D1 | `TYPE_CANONICAL` only maps `"Piling rig"`. `"Mewp"` (13) and `"Drilling rig"` (1) fall into "Other" | `nrmm_model_v4.R` constants | Negligible on emissions weighting; trivially avoidable | Ready — **DONE (v5)** |
| D2 | Machine-type matching is case- and whitespace-sensitive throughout | spine derivation | Latent: any new capitalisation variant silently creates a category | Ready — normalise once at ingestion — **DONE (v5)** |

## E. Verification gaps that let these through

| # | Issue | Impact | Status |
|---|---|---|---|
| E1 | No structural-implausibility checks. A group at exactly 0% compliance across two phases, a fitted rate of exactly zero, or a category with no members above a given stage all passed silently | This is why A1 survived four model versions | Ready — **DONE (v5)** |
| E2 | No check that every distinct value of a categorical input is either mapped or explicitly excluded with a count | B1, B2, B3, D1 would all have been caught | Ready — **DONE (v5)** |
| E3 | No check that a derived population is stable over time. A cohort that shrinks as the fleet improves is the signature shared by A1 and B1 | Would catch this class of error generically | Ready — **DONE (v5)** |
| E4 | Unification dropped the generator sensitivity toggle and its guard, which existed in `tree_dashboard_v3-v5.R` | Regression introduced at `nrmm_model_v1.R` | Ready — see A3 — **DONE (v5)** |

---

## F. C2 resolution (cross-check completed 26 July)

Per direction, checked whether the machine data was accidentally recorded elsewhere on these rows:

- **Often yes.** Of the 1,662 rows, 1,660 carry a real `Machine Type`, 577 a usable initial stage (including 388 at Stage V), 695 a numeric kW, 581 a usable TAN, 475 a definite engine type. The separate `EU Stage` column is empty on every one of these rows, so it offers nothing.
- **The E-flag fallback is not available.** `Initial Machinery Reasons` is "None" or blank on 1,594 of the 1,662 rows (one "P", no E flags anywhere). There is no flag to infer an acceptable stage from. On a Baselining or Site Complete visit, "None" most likely means *not assessed* rather than *no problem found*, so inferring compliance from the absence of a flag would be unsafe.

**Rule ADOPTED (confirmed 28 July):** keep the machine's stage wherever the stage field is usable, since fleet composition is genuine data, but mark the **compliance outcome as undefined**, because no compliance determination was made on that visit. These rows then contribute to stage distributions and emissions intensity but are excluded from compliance rates and outcome counts.

---

**Suggested order of work once answers arrive:** E1-E3 first (so the fixes are checked by something), then A1/A2/A4, then B1-B3, then C4 and the report caveats, then the ready-now tidy-ups D1/D2, B4 and C2.
