# Sprint Log

## Plan amendments

Each row records a change to schema.md, draft_plan.md, or a script after a trial surfaces an issue. Detailed staging files (e.g. step1_fixes.md) are deleted after implementation; the summary lives here.

| Date | Trigger | Files changed | Summary |
|-------------------|----------------|----------------------|----------------|
| 14 Apr 2026 | Logic review of Step 1 script (Trial 1, pre-run): P24 zone excluded; Phase C unassigned; Variable_Speed group missing; date filter harmful | schema.md, draft_plan.md, 260413_step1_ingestion_v1.R | P24 retained as in-scope; Variable_Speed group added for P24 Variable records; date filter removed entirely; Phase C arm added to assign_phase(); zone message updated; Step 5 init updated to use latest P24 data; Table 6 removed from schema; decisions.md and sprint_log.md created |
| 15 Apr 2026 | Step 3 Trial 1: 5 errors identified (COMP_THRESH one era behind; CAZ+ max_stage integer 5 vs 6; lambda_Policy NA unhandled; e-bar decimal not %; tables not centred) | schema.md, decisions.md, draft_plan.md | CAZ+ max_stage corrected to integer 6 (= Stage V; 5 active stages II–V, Stage I near-absent); COMP_THRESH corrected to use "era ending" column semantics; new decisions log entry added; checklist step3_v2_error_checklist.md created |

------------------------------------------------------------------------

## Step trials

One trial = one execution of a step script in a clean context, followed by user review and reporting. A step is marked complete **\[x\]** when outputs are accepted and the next step begins.

### Step 1 — Data ingestion and preparation

- [x] **Trial 1** \| 14 Apr 2026 \| Pre-run logic review (no execution) \| Script: `260413_step1_ingestion_v1.R`
  - Found: P24 exclusion bug; missing Variable_Speed group; date filter blocks P24; Phase C unassigned.
  - Action: Amendments applied (see Plan amendments above). Script ready for first execution.
- [x] **Trial 2** \| 14 Apr 2026 \| Executed; record counts by group × phase accepted; P24 temporal extent confirmed; anomaly flags reviewed.
  - Found: `audits` saved as `data.frame` not `tbl_df`; downstream impact assessed as irrelevant (all Steps 2–5 use dplyr/tidyr verbs which handle both identically).
  - Action: None.

### Step 2 — Exploratory analysis

Script: `260414_step2_exploratory_v1.R` → `v7.R`

- [ ] **Trial 1** \| 14 Apr 2026 \| Script written; awaiting first execution and user review.
- [ ] **Trials 2–6** \| 14–15 Apr 2026 \| Executed; table presentation issues persisted across all trials. Root cause not fixed: version numbers incremented but make_wide() bug unchanged.
  - Found (all trials): tables show 1 column per phase instead of N_subcols columns; NA shown instead of 0 or —.
  - Root cause: `!!subcol_var := subcols` inside `tidyr::complete()` does not unquote a string to a symbol — `!!sym(subcol_var)` is required. This meant stage/route dimension was never expanded, yielding 1 data column per phase.
  - Action: v7 rewrites make_wide() using expand.grid + left_join (no NSE); adds fill_table_nas() to distinguish structural blanks (—) from incidental zeros (0); updates SCRIPT_STEM to v7 throughout.
- [x] **Trial 7** \| 15 Apr 2026 \| Script: `260414_step2_exploratory_v7.R` — executed; table structure correct (make_wide fix confirmed working). Positron Preview identified as root cause of prior display issues: it silently rewrites inline HTML back to Markdown during preview, unrelated to Claude's HTML generation.
  - Action: v7_1 switches table rendering to kableExtra (kable format="html" + add_header_above) for better Positron compatibility; adds glossary of abbreviations to output .md.
- [x] **Trial 7.1** \| 15 Apr 2026 \| Script: `260414_step2_exploratory_v7_1.R` — executed and accepted. kableExtra tables render correctly with phase super-headers. Structural blanks display as "NA" text (kable `na=` argument does not convert numeric NAs in HTML output); noted, not a blocker. Glossary appended. Step Report written. **Step 2 complete.**

### Step 3 — Parameter estimation

Script: `260415_step3_parameter_estimation_v1.R` → `v2.R`

- [x] **Trial 1** \| 15 Apr 2026 \| Script: `260415_step3_parameter_estimation_v1.R` — executed; 5 errors identified.
  - Found: COMP_THRESH one policy era behind (inherited from old V1_1-22 code); CAZ+ MAX_STAGE integer=5 excludes Stage V → lambda_CF=−0.276 (ref 0.363); lambda_Policy=NA for all groups (Route 1 sparsity not handled + Error 2 secondary); e-bar shown as decimal; tables left-aligned.
  - Action: Working documents amended (schema.md, decisions.md, draft_plan.md). v2 script written with all 5 errors fixed. See step3_v2_error_checklist.md for full diagnosis.
- [ ] **Trial 2** \| 15 Apr 2026 \| Script: `260415_step3_parameter_estimation_v2.R` — awaiting execution and user review.

### Step 4 — Transition matrix construction

Script: TBD

- [ ] **Trial 1** \| Pending Step 3 completion.

### Step 5 — Forecasting and emissions

Script: TBD

- [ ] **Trial 1** \| Pending Step 4 completion.