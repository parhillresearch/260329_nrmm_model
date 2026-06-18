# Sprint Log

## Plan amendments

Each row records a change to schema.md, draft_plan.md, or a script after a trial surfaces an issue. Detailed staging files (e.g. step1_fixes.md) are deleted after implementation; the summary lives here.

| Date | Trigger | Files changed | Summary |
|------------------|------------------|-------------------|------------------|
| 14 Apr 2026 | Logic review of Step 1 script (Trial 1, pre-run): P24 zone excluded; Phase C unassigned; Variable_Speed group missing; date filter harmful | schema.md, draft_plan.md, 260413_step1_ingestion_v1.R | P24 retained as in-scope; Variable_Speed group added for P24 Variable records; date filter removed entirely; Phase C arm added to assign_phase(); zone message updated; Step 5 init updated to use latest P24 data; Table 6 removed from schema; decisions.md and sprint_log.md created |
| 15 Apr 2026 | Step 3 Trial 1: 5 errors identified (COMP_THRESH one era behind; CAZ+ max_stage integer 5 vs 6; lambda_Policy NA unhandled; e-bar decimal not %; tables not centred) | schema.md, decisions.md, draft_plan.md | CAZ+ max_stage corrected to integer 6 (= Stage V; 5 active stages II–V, Stage I near-absent); COMP_THRESH corrected to use "era ending" column semantics; new decisions log entry added; checklist step3_v2_error_checklist.md created |
| 17 Apr 2026 | Step 4 Trial 1 pre-run review: p_enf was not a valid matrix parameter (conditional on non-compliance; per audit event not per machine per year — incommensurable with p_cf and p_pro); P_Enforcement matrix design flawed | schema.md, draft_plan.md, sprint_log.md, decisions.md | P_Enforcement dropped from model; enforcement enters only as Scenario B Boolean mask in Step 5; Step 3 Trial 4 adds Route 4/5 enforcement success rate as descriptive policy metric (not a matrix parameter); Step 4 v2 uses P_Natural + P_Proactive only |
| 17 Apr 2026 | Step 3 Trial 6 accepted: user requested new table layout convention for group × phase breakdowns across all steps | CLAUDE.md | New convention: for group × phase tables → one kable per group, phases as columns, statistics as rows, "Phase" super-header via add_header_above; for group-only tables → single table, groups as rows. Plots: at every opportunity with group × phase data produce a faceted ggplot (facet_wrap(\~group, nrow=2)); 16×12cm faceted. v4 and v5 scripts retain as audit trail; v6 implements new layout. |
| 21 Apr 2026 | Director review (director_review_step1.md): Step 1 requires vs_member flag, continuous Variable_Speed, checksum analysis, exclusion statistics and bar charts (new Step 1.5), formal checksum verification (new Step 1.6) | draft_plan.md, sprint_log.md, 260421_step1_ingestion_v3.R | Step 1 sub-tasks 3–6 expanded; Variable_Speed continuous via row duplication (group_primary for deduplication); exclusions.rds saved for Step 1.5 analysis; six stacked bar chart plots added; formal checksum table (raw = unique_retained + excluded) added as Step 1.6 |

------------------------------------------------------------------------

## Step trials

One trial = one execution of a step script in a clean context, followed by user review and reporting. A step is marked complete **\[x\]** when outputs are accepted and the next step begins.

### Step 1 — Data ingestion and preparation

- **Trial 1** \| 14 Apr 2026 \| Pre-run logic review (no execution) \| Script: `260413_step1_ingestion_v1.R`
  - Found: P24 exclusion bug; missing Variable_Speed group; date filter blocks P24; Phase C unassigned.
  - Action: Amendments applied (see Plan amendments above). Script ready for first execution.
- **Trial 2** \| 14 Apr 2026 \| Executed; record counts by group × phase accepted; P24 temporal extent confirmed; anomaly flags reviewed.
  - Found: `audits` saved as `data.frame` not `tbl_df`; downstream impact assessed as irrelevant (all Steps 2–5 use dplyr/tidyr verbs which handle both identically).
  - Action: None.
- **Trial 3** \| 21 Apr 2026 \| Script: `260421_step1_ingestion_v3.R` — written; awaiting first execution and user review.
  - Director review amendments: (1) Variable_Speed made continuous via row duplication — CAZ_Plus/RoL records appear in both their zone group and in Variable_Speed; group_primary column for deduplication; (2) check for unexpected group/zone codes; (3) checksum table (5 checks, pipeline + group + phase levels); (4) new Step 1.5 — statistics and stacked bar charts for excluded records, stages (all + faceted by group), non-compliance codes, group × engagement, Variable_Speed continuous, pre-2016; (5) new Step 1.6 — formal checksum verification (raw = unique_retained + all exclusions).
- **Trial 4** \| 22 Apr 2026 \| Script: `260422_step1_ingestion_v4.R` — executed; rejected. Three layered compliance definition failures in section 8c.
  - Section 8c revised: (1) hierarchical NC code assignment (E \> R \> Other) — each machine counted once, eliminating double-counting of multi-code records; (2) compliant machine counts added to table; (3) two plots: non-compliant categories only (stacked bar), and compliant vs non-compliant together for ratio comparison.
  - **Failure 1 — Case sensitivity:** The fallback "Compliant" category tested `initial_machinery_compliance == "compliant"` (lowercase). The actual field value is `"Compliant"` (title case). This silently suppressed all compliant matches.
  - **Failure 2 — "None" regex collision:** The diagnostic regex `[ACEPQRX]` intended to flag records with no compliance reason code was applied to the raw string `initial_machinery_reasons`. When the audit data entry convention is `"None"` (literal string for no reason), `toupper("None") = "NONE"` and `str_detect("NONE", "[ACEPQRX]")` matches 'N'... wait — actually `[ACEPQRX]` does include no N, but `str_detect("NONE", "E")` used in `classify_nc_top()` does match 'E' in the substring "NONE". Root issue: `classify_nc_top()` checks `str_detect(r, "E")` as the highest-priority branch. With `r = toupper("None") = "NONE"`, `str_detect("NONE", "E") = TRUE`, so every record with `initial_machinery_reasons = "None"` (the standard entry for a compliant machine) is wrongly classified as "E: Emissions" non-compliant.
  - **Failure 3 — Wrong field for emissions compliance:** The fundamental conceptual error is using `initial_machinery_reasons` with manual string regex to determine compliance, when `init_mach_emissions_compliant` (a pre-derived boolean flag from step 3g of the pipeline, computed as `!grepl("E", initial_machinery_reasons, fixed = TRUE)`) already encodes this correctly. `fixed = TRUE` matches the literal character 'E' only in positions that are actual compliance codes — it does not fire on "NONE" because `grepl("E", "None", fixed=TRUE) = FALSE` (case-sensitive, matches uppercase E only).
  - **Diagnostic result:** When diagnostic counts run with `filter(group == group_primary)` on `audits` (n = 12,363), all definition variants returned n = 0 except `n_neither = n_total = 12,363`, confirming 100% misclassification. No valid compliant counts were produced.
    - Action: Trial 5 to fix section 8c using `init_mach_emissions_compliant` flag; add `final_mach_emissions_compliant` as "became compliant" overlay; conduct logic-bug audit across all assignment tasks.
- **Trial 5** \| 22 Apr 2026 \| Script: `260422_step1_ingestion_v5.R` — executed; rejected. Two bugs in section 8c identified via interactive diagnostics.
  - **Bug 1 (Total column):** `rowSums(across(where(is.integer)))` included `year` (integer) in each row sum → 2016 row showed Total = 2077 instead of 61. Confirmed via Option A diagnostic.
  - **Bug 2 (latent — paste0/sub reconstruction):** `paste0(sub(...), ": ", sub(...))` reconstructed the nc_status label for "Other (A/C/P/X)" incorrectly (no ': ' separator in that string → second sub() returned full original → label `"Other: Other (A/C/P/X) (remained NC)"` not in NC_STATUS_LEVELS). Does not fire on current data (all non-compliant machines have E codes) but logic was broken.
  - Action: v6 written. Fix 1: `across(!any_of("year"))`. Fix 2: replace paste0/sub with direct lookup vector `NC_SUB_TO_LEVEL`.
- **Trial 6** \| 22 Apr 2026 \| Script: `260422_step1_ingestion_v6.R` — written; awaiting execution and user review.
  - Section 7.5 logic-bug audit (169 lines) removed: all eight fields passed clean in Trial 5 and the audit generated no output used downstream. Replaced with three `stopifnot()` assertions that catch regressions on future re-runs.
  - Root bug fixed: `derive_compliance_flags()` no longer applies `toupper()` before `grepl("E", ..., fixed=TRUE)`; `"None"` (sentinel for no NC code) was previously uppercased to `"NONE"` which contains uppercase 'E', causing all compliant machines with `reasons="None"` to be wrongly flagged as emissions non-compliant.
  - Section 8c rewritten: uses `init_mach_emissions_compliant` and `final_mach_emissions_compliant` boolean flags exclusively; removes `classify_nc_top()`. Three categories: `Compliant`, `Became compliant` (enforcement uplift), `E: Emissions (remained NC)`. Two plots: (1) non-compliant stacked bar with compliant reference line; (2) full compliant/non-compliant ratio bar.
  - Section 7.5 added: logic-bug audit of all eight pipeline assignment tasks (`cold_engaged`, `emissions_compliant`/`admin_compliant`, `initial_stage`/`final_stage`, `zone`, `group_primary`, `phase`, `no_power_rating`, `engine_type_clean`). Reports raw field values, derivation correctness, and bugs/fixes. Audit summary table written to output .md.
- Trial 7 \| Major rewrite by user with Claude.
  - Removed objects defined and libraries called, but never used:
    - STAGE_LABELS, GROUP_ORDER, n_raw, audits_vs, n_vs_dupes — remove
    - libraries: knitr, kableExtra, scales — remove
  - Created a frequency table of machine types x engine types, so undefined engine types could have a value set based on the modal value. This is not applied for Generators, as 1/3rd of these are Variable while 2/3rd are constant.

### Step 2 — Exploratory analysis

Script: `260414_step2_exploratory_v1.R` → `v7.R`

- **Trial 1** \| 14 Apr 2026 \| Script written; awaiting first execution and user review.
- **Trials 2–6** \| 14–15 Apr 2026 \| Executed; table presentation issues persisted across all trials. Root cause not fixed: version numbers incremented but make_wide() bug unchanged.
  - Found (all trials): tables show 1 column per phase instead of N_subcols columns; NA shown instead of 0 or —.
  - Root cause: `!!subcol_var := subcols` inside `tidyr::complete()` does not unquote a string to a symbol — `!!sym(subcol_var)` is required. This meant stage/route dimension was never expanded, yielding 1 data column per phase.
  - Action: v7 rewrites make_wide() using expand.grid + left_join (no NSE); adds fill_table_nas() to distinguish structural blanks (—) from incidental zeros (0); updates SCRIPT_STEM to v7 throughout.
- **Trial 7** \| 15 Apr 2026 \| Script: `260414_step2_exploratory_v7.R` — executed; table structure correct (make_wide fix confirmed working). Positron Preview identified as root cause of prior display issues: it silently rewrites inline HTML back to Markdown during preview, unrelated to Claude's HTML generation.
  - Action: v7_1 switches table rendering to kableExtra (kable format="html" + add_header_above) for better Positron compatibility; adds glossary of abbreviations to output .md.
- **Trial 7.1** \| 15 Apr 2026 \| Script: `260414_step2_exploratory_v7_1.R` — executed and accepted. kableExtra tables render correctly with phase super-headers. Structural blanks display as "NA" text (kable `na=` argument does not convert numeric NAs in HTML output); noted, not a blocker. Glossary appended. Step Report written. **Step 2 complete.**

### Step 3 — Parameter estimation

Script: `260415_step3_parameter_estimation_v1.R` → `v3.R`

- **Trial 1** \| 15 Apr 2026 \| Script: `260415_step3_parameter_estimation_v1.R` — executed; 5 errors identified.
- Found: COMP_THRESH one policy era behind (inherited from old V1_1-22 code); CAZ+ MAX_STAGE integer=5 excludes Stage V → lambda_CF=−0.276 (ref 0.363); lambda_Policy=NA for all groups (Route 1 sparsity not handled + Error 2 secondary); e-bar shown as decimal; tables left-aligned.
- Action: Working documents amended (schema.md, decisions.md, draft_plan.md). v2 script written with all 5 errors fixed. See step3_v2_error_checklist.md for full diagnosis.
- **Trial 2** \| 16 Apr 2026 \| Script: `260415_step3_parameter_estimation_v2.R` — executed; rejected. Four failures identified.
  - **Failure 1 — COMP_THRESH regression (E1 "fix" was itself wrong):** The Trial 1 error checklist misread schema.md Table 2's "era ending" column headers as meaning the requirement *during* the era ending on that date. The correct reading is the date marks when that requirement *took effect*. v1's thresholds (A1/A2 = Col 1; B = Col 2) were correct. The v2 "fix" pushed them forward one column, producing CS Phase A1/A2 threshold = V → 100% non-compliance, which is analytically nonsensical (Stage V was not commercially available in Phase A1). Correct COMP_THRESH: A1/A2 = CS:IIIA(3), CAZ+:IIIB(4), RoL:IIIA(3); B = CS:V(6), CAZ+:IV(5), RoL:IIIB(4).
  - **Failure 2 — Table layout violates standing instruction:** CLAUDE.md specifies phases as column super-headers and groups as row index for all steps. Every Step 3 table has phases as rows and groups as rows — the convention is completely inverted. This was not addressed in v1 or v2.
  - **Failure 3 — No plain-English text after tables:** CLAUDE.md requires every table to be followed by exactly two lines of plain-English explanatory text. The Step 3 output contains zero explanatory text.
  - **Failure 4 — No glossary:** Step 2 v7_1 established a glossary of abbreviations as part of the output. Step 3 carried none forward. Terms lambda_CF, lambda_Policy, lambda_Proactive, e-bar appear undefined throughout.
  - **Note on pre-run review:** Claude's pre-run review of v2 incorrectly confirmed all 5 errors from the Trial 1 checklist as fixed. Failures 2–4 were present in v1 and not identified in the checklist. Failure 1 was introduced by the checklist itself. The review gave false assurance.
  - Action: User is rewriting v3 independently.
- **Trial 3** \| 17 Apr 2026 \| Script: `260415_step3_parameter_estimation_v3.R` — executed and accepted. Step Report written.
  - Found: λ_CF Constant_Speed = 0.051 (ref 0.358, Δ = −0.307) — major anomaly flagged; small cold sample (N=133); corroborated by near-zero λ_Policy (−0.000). λ_CF CAZ+ = 0.262 (ref 0.363, Δ = −0.101); λ_CF RoL = 0.241 (ref 0.219, Δ = +0.022, within tolerance). λ_Proactive positive only for CAZ+ (0.013); CS and RoL floor at zero. ē Phase B CS = 82.8% (Stage V threshold newly imposed); ē Phase C CS = 30.4% (compliance improvement). schema.md Table 8 updated with v3 estimates.
  - Action: Accepted, but Step 4 pre-run review identified that p_enf (enforcement effectiveness rate) was estimated inside Step 4 rather than Step 3. Step 3 reopened: Trial 4 adds sub-task 3.4. **Step 3 not yet fully complete.**
- **Trial 4** \| 17 Apr 2026 \| Script: `260415_step3_parameter_estimation_v4.R` — executed; rejected. Route 4 indicator (`enforcement_upgrade == TRUE`) captured only \~35 on-the-spot stage-upgrade records. Near-100% Route 5 rates (e.g. CS A2: 186/187 = Route 5) flagged by user as implausible.
  - Found: `enforcement_upgrade = final_stage > initial_stage` is too narrow — machine removals and non-site replacements produce no higher final_stage, so almost all non-compliant machines show as Route 5.
  - Action: v5 changes Route 4 indicator to `final_mach_emissions_compliant == TRUE` (no E code in final machinery reasons), which captures removals, replacements, retrofits, and exemptions granted post-visit.
- **Trial 5** \| 17 Apr 2026 \| Script: `260415_step3_parameter_estimation_v5.R` — executed. Enforcement success rates revised but still near-zero (0.0–1.4% across all groups and periods). User requested new per-group table layout (phases as columns, statistics as rows) and plots at every opportunity.
  - Found (data finding, not a code bug): Near-zero Route 4 rates confirmed as genuine — audit records capture point-in-time visit state; E code persists in final reasons because post-visit enforcement outcomes are not resolved on the day of audit. This directly corroborates the decision to exclude enforcement from the transition matrix.
  - Action: v6 rewrites all group × phase tables to new layout (one kable per group; phases as columns; statistics as rows); adds faceted ggplot2 plots for ē and enforcement section; CLAUDE.md updated with new table/plot convention.
- **Trial 6** \| 17 Apr 2026 \| Script: `260415_step3_parameter_estimation_v6.R` — executed and accepted. New per-group table layout and faceted plots confirmed working. Step Report written. **Step 3 complete.**
  - Found: ē Phase B CS = 82.8% (Stage V threshold newly imposed); Phase C CS = 30.4% (anticipatory compliance pre-2025 P24 records). λ_Proactive positive only for CAZ+ (0.013); CS and RoL floor at zero. Enforcement success rates 0.0–1.4% throughout all groups and periods; Variable_Speed B3 = 5 pre-2025 P24 records (anomalous, flagged).
  - Action: None. Step 4 v2 proceeds.

### Step 4 — Transition matrix construction

Script: `260417_step4_transition_matrices_v1.R` → `v2.R`

- **Trial 1** \| 17 Apr 2026 \| Script written; superseded before execution. Step 4 pre-run review found p_enf estimated internally rather than read from Step 3, and enforcement outputs insufficient. Rolled back to Step 3 Trial 4.
  - Action: v2 removes P_Enforcement; P_Total = P_Natural + P_Proactive only; Route 4/5 enforcement reported descriptively in Step 3 v6.
- **Trial 2** \| 17 Apr 2026 \| Script: `260417_step4_transition_matrices_v2.R` — executed before Step 3 enforcement fork; retained as audit trail. Critical error identified in pre-trial review: CS avg_stage_jump computed in 3-stage estimation space (0.218) and applied in 6-stage forecast matrix, producing lambda(P_Natural)=0.342 vs locked 0.051 (6.7× discrepancy). Also: `\u2212` inside backtick column name caused parse error. Action: v3 written with both fixes.
- **Trial 3** \| 17 Apr 2026 \| Script: `260417_step4_transition_matrices_v3.R` — executed and accepted. avg_stage_jump fix confirmed: CS avg_jump = 3.218 → p_cf = 0.0158 (was 0.234 in v2). Row-stochastic checks PASS for both groups. Validation B shows P_Total projection close to actual Phase C distribution for CS; VS under-predicts Stage V (0.657 projected vs 0.765 actual) consistent with anticipatory pre-2025 compliance shift not captured by the constant-hazard model. Lambda divergence warnings (CS 55%, VS 75%) are expected and explained by high Stage V fraction in Phase C pi_0 suppressing the distribution-weighted implied lambda. **Step 4 complete.**

### Step 5 — Forecasting and emissions

Script: `260417_step5_forecasting_v1.R`

- **Trial 1** \| 17 Apr 2026 \| Script: `260417_step5_forecasting_v1.R` — executed and accepted. Step Report written. **Step 5 complete.**
  - Found: CS Stage V at initialisation = 53.8%; VS = 76.5%. Scenario A: CS reaches 57.4% Stage V by 2030 (+3.6 pp, very slow — enforcement essential); VS reaches 90.8% by 2030 at Stage IV threshold, drops to 90.8% when threshold upgrades to Stage V in 2030. Scenario B: CS reaches 100% Stage V by 2026; VS eliminates Stages I–IIIB immediately, Stage IV persists until 2030 threshold uplift → 100% Stage V by 2030. Enforcement-attributable ceiling: CS = 42.6 pp, VS = 9.2 pp. Emissions section skipped — EF_s not supplied.
  - Action: EF_s (EMEP/EEA Tier 3 NOx factors) to be supplied by user; emissions section will run automatically on re-execution.

### Step 6 — Methods and findings report

Report: `outputs/260417_step6_methods_findings_v1.md` → `v2.md`

- **Trial 1** \| 17 Apr 2026 \| Report: `outputs/260417_step6_methods_findings_v1.md` — written by Claude; reviewed by user. Structure and content accepted; two classes of deficiency identified: (1) factual errors in six specific values; (2) no plots embedded and no embedded record-counts table; no Key Results consolidated table. Trial 1 is not executed (it is a written .md document, not an R script). **Step 6 not complete.**
- **Errors found (to correct in v2):**
  1.  Sub-task 1.4 record count: states "15,932 across four groups and four phases" — actual group × phase total is 12,363 (CAZ+ 3,354; CS 1,227; RoL 6,294; VS 1,488); 15,932 is the `audits.rds` row count including pre-2016/NA-phase records.
  2.  Sub-task 3.2 ē table CS Phase A2: shows 22.1% — actual 14.8%.
  3.  Sub-task 3.2 ē table RoL Phase A1/A2: shows A1=3.5%, A2=5.2% — actual A1=5.2%, A2=3.2% (values were swapped).
  4.  Executive summary ē Phase B row, RoL: shows 5.2% — actual Phase B value is 4.7% (5.2% is RoL Phase A1).
  5.  Sub-task 3.3 N warm SC: CAZ+ shown as "2,000+" — actual 501; RoL shown as "large" — actual 1,152.
  6.  Sub-task 4.1 avg_stage_jump table: CAZ+ 1.826 (actual 1.302), RoL 2.128 (actual 1.501), VS "\~2.0" (actual 1.460). The p_cf values in the same table are correct.
  7.  Sub-task 5.2 π₀ table VS: Stage I=0.0% (actual 0.3%), Stage II=1.8% (actual 0.9%), Stage IIIA=0.0% (actual 0.9%).
- **Additions required for v2:**
  - Embed all 12 PNG plots from `outputs/` at the correct sub-task location using `![caption](filename.png)` (filename only, no path; file is in outputs/).
  - Replace Sub-task 1.4 Findings prose with actual markdown table from `outputs/260413_step1_counts_all.md`.
  - Add Key Results consolidated table to Executive Summary: one row per group, columns: Group, λ_CF (SE), λ_Pro, p_cf, p_pro, ē Phase B (%), ē Phase C (%), Scen A 2030 (%), Scen B 2030 (%).
  - Action: v2 report to be written in fresh context; see draft_plan.md Step 6 for full Trial 2 specification.
- **Trial 2** \| 17 Apr 2026 \| Report: `outputs/260417_step6_methods_findings_v2.md` — accepted. User verdict: "a good improvement."
  - Corrections applied: 7 factual errors fixed. Additions: Key Results table, Glossary, 12 embedded plots, actual record-count table.
  - Lessons for Trial 3: (1) embed schema tables where they aid comprehension; (2) LaTeX notation $\lambda_{CF}$ etc. consistently throughout including table cells; (3) two-tier formatting — **bold** for conceptual group references, `backtick` for code objects; (4) collapse code excerpts to ≤5-line illustrative snippets + script reference; (5) add PM-layer: Purpose sentence per Step, Headline Findings paragraph in Exec Summary, spell out acronyms on first use; (6) structural alternatives (Option A policy-led, Option B two-part) considered and deferred to Future Work in draft_plan.md.
  - Action: Trial 3 spec written in draft_plan.md. Trial 4 spec added (typography pass — LaTeX + bold/backtick formatting). Split rationale: sub-tasks 2 and 3 (global symbol and formatting sweeps) deferred to Trial 4 to reduce consistency risk in a single-pass rewrite. Trial 3 to be executed in a new context.
- **Trial 3** \| 17 Apr 2026 \| Report: `outputs/260417_step6_methods_findings_v3.md` — accepted. Trial 4 typography pass to be executed.
  - Applied: (1) six schema tables embedded at specified locations (List 1, List 2, Table 1, Table 2, Table 3, Table 7), each with one-sentence lead-in; (2) all code blocks \>5 lines collapsed to ≤5-line illustrative excerpts + `_Full implementation: <script>_` reference; (3) PM-layer: Purpose sentence added to each Step; Headline Findings paragraph added after Key Results table; acronyms (WLS, GLS, pp, CAZ+) defined on first use or in Glossary; Glossary extended with GLS and pp entries; π₀ footnote added below quantitative findings table.
  - Action: Trial 4 spec written in draft_plan.md — typography-only pass (LaTeX + bold/backtick).
- **Trial 4** \| 18 Apr 2026 \| Report: `outputs/260417_step6_methods_findings_v4.md` — accepted.
- Applied: (1) LaTeX math notation throughout body text and table cells — $\lambda_{CF}$, $\lambda_{Policy}$, $\lambda_{Proactive}$, $\bar{e}$, $\pi_0$, $p_{cf}$, $p_{pro}$, $\overline{\Delta s}$, $\Delta\bar{e}/\Delta t$, $\lambda(P_\text{Natural})$, $\lambda(P_\text{Total})$; (2) two-tier group/object formatting — **bold** for conceptual group references in prose (**Constant Speed**, **CAZ+**, **Rest of London**, **Variable Speed**), plain text in table headers/cells, backtick for code objects (`P_Total`, `EF_s`, `Constant_Speed`, etc.); no content changes.
  - Action: Trial 5 spec written in draft_plan.md — human-readability review pass for Project Director and Programme Manager audience.
- **Trial 5** \| 18 Apr 2026 \| Report: `outputs/260417_step6_methods_findings_v5.md` — written and accepted.
  - Applied: (1) plain-English lead sentence prepended to every Findings block that opened with a technical value or symbol (sub-tasks 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 3.4, 3.5, 4.1, 4.2, 4.3, 5.1, 5.2, 5.3, 5.4); (2) Headline Findings revised to name both scenarios explicitly as "Scenario A" and "Scenario B"; (3) jargon audit of all Findings prose — "cold fleet" explained on first use, "Route 1/4/5" contextualised, "warm fleet" parenthetically defined, "sparsity"/"signal exhaustion" replaced with plain English, "GLS" written out, "coding artefact" changed to "data quality issue", "constant-hazard model" replaced with "fixed annual-probability model", "time-varying hazard" replaced with "replacement rate that varied over time"; (4) Open Items and Known Limitations fully rewritten — plain-English statement first, technical detail in parentheses. No content changes, no code block changes, no restructuring.
- Action: None. **Step 6 complete.**

### Analytical note — 18 Apr 2026

**Why does Constant Speed use annual WLS resolution despite having the fewest cold records?**

The apparent paradox (CS N=133 cold records → 8 annual data points; CAZ+ N=361 → 4 points after pooling) resolves through signal quality, not record count. The operative constraint is WLS stability at each temporal point, which is determined by within-cell stage variance, not cell size alone.

- **CAZ+ and Rest of London (max_stage = 6):** Stage V penetration reaches \~60% of cold records in Phase B3. As the fleet bunches at the ceiling, year-to-year variance in mean stage explodes — small fluctuations in Stage V fraction produce large swings in the annual mean. Annual GLS attempted for CAZ+ produced λ = 0.638 (\>2× the accepted 0.262). The inflation is a ceiling-saturation artefact. The 3-segment binning widens the temporal window to average out this noise.
- **Constant Speed (max_stage = 3):** Stage V is absent from the CS cold estimation window (2024 excluded). The fleet moves within a bounded 3-integer space with no saturation risk. Annual CS cold n (\~16–17/year) is actually lower than annual CAZ+ cold n (37–83/year), yet the signal is cleaner and annual resolution is stable.
- **A1/A2 pooling for variable-speed groups** creates a pre-Phase-B anchor point and is partly driven by thin annual A1 cells, but principally by the decision to use Phase B sub-segments as the time-varying signal rather than mixing annual granularities across the full window.

Conclusion: more records per year does not help if ceiling saturation is the noise source. The solution is wider temporal bins, not more data.