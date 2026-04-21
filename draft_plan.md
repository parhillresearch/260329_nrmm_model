# NRMM LEZ Trend Analysis: Execution Plan

version 0.2 | 13 April 2026

---

## Carried-forward findings

The following values and constraints are locked from previous estimation work. See schema.md Tables 8 and "Key analytical decisions" for full provenance.

**Previous lambda_CF:** Constant_Speed = 0.358, CAZ+ = 0.363, Rest_of_London = 0.219

**Active state spaces (max_stage):** Constant_Speed = 3, CAZ+ = 6, Rest_of_London = 6

**Key constraints:** (1) 2024 CS cold data is Phase C initialisation only, not used in lambda_CF. (2) e-bar uses Stage-threshold on all records, not Enforcement_Upgrade flag. (3) lambda_Proactive from warm self-compliant subset only; e-bar not subtracted.

---

## Step 1: Data ingestion and preparation

1. Import `audits.txt`; discard out-of-scope columns (schema.md Table 5); validate and encode retained fields (schema.md Table 4) using Stage encoding (List 1), non-compliance codes (List 2)
2. Exclude out-of-scope records: zone filter retains CAZ, OA, GL, P24; excludes BCP. Non-machinery records removed (Initial Machinery Compliance not "compliant"/"non-compliant"). Unassignable engine types, unresolvable Initial Emissions Stage, and COVID-exempt records (1.9.2020–31.3.2021) excluded.
3. Assign every retained record to a machine group (schema.md Table 1) and model phase (schema.md Table 7); store as tibble `audits`. P24 Variable Speed records → group `Variable_Speed`; P24 Constant Speed records → group `Constant_Speed`. Records with date >= 1.1.2025 → Phase C. Check for unexpected zone/group codes. Add `vs_member` boolean flag (TRUE for all variable-engine records) so Variable_Speed can be analysed continuously across all phases; save `audits_vs.rds` (all variable-engine records with group = "Variable_Speed").
4. Report record counts by group and phase; flag anomalies for user review before proceeding. Report P24 record counts separately. Conduct checksum analysis confirming group coding: (a) raw = retained + excluded; (b) sum(group counts) = n_retained; (c) vs_member count = CAZ_Plus + RoL + VS; (d) cold + warm = n_retained.
5. Generate basic statistics and stacked bar charts by year for: (a) excluded records by exclusion reason; (b) Stage distributions (all records and faceted by group); (c) non-compliance codes; (d) group × engagement type; (e) Variable_Speed continuous (vs_member); (f) pre-2016 records characterisation.
6. Formal checksum verification: raw total = sum of all exclusion categories + retained; phase-level checksum; group-level checksum.

---

## Step 2: Exploratory analysis

1. Tabulate Stage distributions by group, phase, and engagement type (cold/warm); plot trends over time
2. Characterise compliance outcomes using the six-route classification (schema.md Table 3)
3. Identify data sparsity, signal exhaustion, and volatility issues by group and sub-phase that will constrain estimation
4. Report findings and confirm analytical approach with user before proceeding

---

## Step 3: Parameter estimation

1. Estimate lambda_CF from cold-engaged records only, using WLS on Stage proportion vectors; apply group-specific max_stage and estimation windows determined in Step 2; validate against Previous values in schema.md Table 8
2. Estimate e-bar from all records where Initial Stage < compliance threshold for that group and phase (schema.md Table 2); do not divide by phase duration
3. Estimate lambda_Proactive from warm self-compliant records only (Initial Machinery Compliance == compliant); compute as lambda_Policy - lambda_CF, floored at zero
4. Report enforcement success rate from Route 4/5 outcomes as a descriptive policy metric: for each group report n(Route 4 emissions), n(Route 5 emissions), n(Routes 4+5), and the per-audit success rate n(Route 4)/n(Routes 4+5), broken down by group × phase (A1, A2, B sub-segments, Phase C if P24 records present). Flag groups where n(Routes 4+5) < 30 as too sparse to interpret. This is a characterisation of enforcement intensity and effectiveness from the audit record; it is not a model parameter and does not feed into the transition matrices.
5. Report all parameter estimates with SE and CI where applicable; cross-check against locked values and expected ranges; flag anomalies for user review

---

## Step 4: Transition matrix construction

1. Construct group-specific right-stochastic transition matrices P_Natural and P_Proactive with dimensions 6×6 (FORECAST_MAX_STAGE = 6 for all Phase C groups). p_cf and p_pro derived from locked lambda values and avg_stage_jump computed from estimation-window cold records. No P_Enforcement matrix: enforcement is not modelled as a continuous annual probability; it enters forecasting only as the Scenario B Boolean mask in Step 5.
2. Combine P_Natural and P_Proactive into composite P_Total (Scenario A base matrix); enforce row-sum constraint after every operation; apply floor-and-rescale where lambda_Proactive < 0. Display both P_Natural and P_Total. Report a probability-decomposition table (p_cf, p_pro per group). Extend implied-lambda validation to two columns: λ(P_Natural) and λ(P_Total), confirming p_pro's marginal contribution.
3. Validate P_Total against observed Stage distributions before use in forecasting

---

## Step 5: Forecasting and emissions

1. Project Stage distributions annually 2025-2030 under two scenarios: Scenario A (proactive only, no enforcement augmentation) and Scenario B (enforcement-augmented, Boolean mask zeroing non-compliant transitions). Initialise Phase C from the Stage distribution of the latest available P24 cold-engaged records; forecast horizon runs from that date to 31.12.2030.
2. For Phase C initialisation, pool Constant_Speed and Variable_Speed P24 records into a combined dataset; extract group-specific Stage distributions as the Phase C starting state. No merge operation required; group assignment at Step 1 handles the CAZ+/Rest of London merge.
3. Estimate annual emissions per group as E = Sum(N x kW x 2000 x EF_s) using EMEP/EEA Tier 3 factors (schema.md TBC section - must be resolved before this step)
4. Produce summary tables and plots of Stage distributions and emissions trajectories for both scenarios; document limitations (schema.md "Known limitations")



---

## Step 6: Methods and findings report

Trial 1 produced `outputs/260417_step6_methods_findings_v1.md` — structure accepted. Trial 2 writes `outputs/260417_step6_methods_findings_v2.md` correcting all errors from Trial 1 and adding plots and embedded tables throughout.

**Trial 2 sub-tasks:**

1. **Fix factual errors** — the following values are wrong in v1 and must be corrected from the step output files:
   - Sub-task 1.4 record count: "15,932 records retained across four groups and four phases" is incorrect; the group × phase table (`outputs/260413_step1_counts_all.md`) totals 12,363. Replace the claim with actual group × phase counts: CAZ+ 3,354; CS 1,227; RoL 6,294; VS 1,488; total 12,363. State that the `audits.rds` object (15,932 rows) includes pre-2016 and NA-phase records not allocated to any model phase.
   - Sub-task 3.2 ē table: CS Phase A2 shows 22.1% — correct to 14.8%. RoL Phase A1 shows 3.5%, Phase A2 shows 5.2% — swap: A1 = 5.2%, A2 = 3.2%.
   - Executive summary ē Phase B row: RoL shown as 5.2% — correct to 4.7%.
   - Sub-task 3.3 N warm SC: CAZ+ shown as "2,000+" — correct to 501. RoL shown as "large" — correct to 1,152.
   - Sub-task 4.1 avg\_stage\_jump table: CAZ+ shows 1.826 (correct: 1.302), RoL shows 2.128 (correct: 1.501), VS shows "~2.0 (wtd avg)" (correct: 1.460). The p\_cf and p\_pro values are correct.
   - Sub-task 5.2 π₀ table for Variable\_Speed: Stage I = 0.0% (correct: 0.3%), Stage II = 1.8% (correct: 0.9%), Stage IIIA = 0.0% (correct: 0.9%).

2. **Embed all plots** — insert a `![caption](filename.png)` markdown image line immediately after the relevant Findings paragraph in each sub-task. All filenames are relative (no path prefix; the report is in `outputs/`). Use the final-trial version of each plot:
   - Sub-task 2.1: `260414_step2_exploratory_v7_1_stage_cold_year.png`, `260414_step2_exploratory_v7_1_stage_warm_year.png`, `260414_step2_exploratory_v7_1_stage_cold_Bsub.png`, `260414_step2_exploratory_v7_1_stage_variable_speed.png`
   - Sub-task 3.2: `260415_step3_parameter_estimation_v6_ebar.png`
   - Sub-task 3.4: `260415_step3_parameter_estimation_v6_enforcement.png`
   - Sub-task 4.1: `260417_step4_transition_matrices_v3_fig4_1_probabilities.png`
   - Sub-task 4.2: `260417_step4_transition_matrices_v3_fig4_2_ptotal_heatmap.png`
   - Sub-task 4.3: `260417_step4_transition_matrices_v3_fig4_3_validation_B.png`
   - Sub-task 5.1: `260417_step5_forecasting_v1_fig5_2_scen_a_stage.png`, `260417_step5_forecasting_v1_fig5_3_scen_b_stage.png`
   - Sub-task 5.4: `260417_step5_forecasting_v1_fig5_4_compliance.png`

3. **Embed record counts table** — replace the prose in Sub-task 1.4 Findings with an actual markdown table copied from `outputs/260413_step1_counts_all.md`, retaining the prose explanation below it.

4. **Add Key Results table** — insert a consolidated "Key Results" markdown table immediately after the existing quantitative findings table in the Executive Summary. The table should have one row per model group (Constant\_Speed, CAZ\_Plus, Rest\_of\_London, Variable\_Speed) and columns: Group, λ\_CF (SE), λ\_Pro, p\_cf, p\_pro, ē Phase B (%), ē Phase C (%), Scen A 2030 compliance (%), Scen B 2030 compliance (%). Use values from the step output files; mark cells with — where the group has no Phase C forecast (CAZ+, RoL) or no ē Phase B (Variable\_Speed). Use actual step output values throughout (corrected per sub-task 1 above).

5. Follow output conventions: filename stem `260417_step6_methods_findings_v2`; retain all code excerpts, prose, Open Items, and Known Limitations from v1 unchanged except where sub-tasks 1–4 above require edits.

Trial 2 accepted. Outputs: `outputs/260417_step6_methods_findings_v2.md`. Added: Key Results table, Glossary, 12 embedded plots, actual record-count table. Corrected 7 factual errors.

**Trial 3 sub-tasks:**

Trial 3 writes `outputs/260417_step6_methods_findings_v3.md` from v2, applying content and structure improvements only. Typography (LaTeX notation and bold/backtick formatting) is deferred to Trial 4. Structure stays as-is (chronological steps). Audience: technical analysts/modellers + Programme Manager.

1. **Embed schema tables** — insert the following schema.md tables at the indicated locations to aid reader comprehension. Copy the table verbatim from schema.md; add a one-sentence lead-in explaining its purpose in context. Embed additional tables from schema.md or decisions.md only if they materially clarify a finding without adding bulk.
   - **List 1** (Stage encoding, integers 1–7) → Sub-task 1.1, before the `encode_stage` code excerpt.
   - **List 2** (Non-compliance codes A/C/E/P/R/X) → Sub-task 1.2, before the exclusion logic.
   - **Table 1** (Equipment groups and derivation rules) → Sub-task 1.3, before the `group = case_when(...)` excerpt.
   - **Table 7** (Phase boundaries and rationale) → Sub-task 1.3, after Table 1, before Sub-task 1.4.
   - **Table 3** (Compliance outcome routing, six routes) → Sub-task 2.2, before the `classify_route` code excerpt.
   - **Table 2** (Compliance thresholds by era and group) → Sub-task 3.2, before the `compute_ebar` code excerpt.

2. **Collapse code excerpts** — for each code block in the report, replace the full function body with a ≤5-line illustrative excerpt showing only the key logic. Append a reference line immediately after each collapsed block: `_Full implementation: \`<script_filename>\`_`. Do not collapse code blocks that are already ≤5 lines.

3. **Audience — Programme Manager layer** — make each Step section accessible to a Programme Manager without requiring them to read sub-tasks:
   - Add a one-sentence plain-English **Purpose** line at the top of each Step section (between the bold script/output header and the first sub-task heading). Example for Step 3: "This step estimates how fast the fleet is improving and what fraction of machines fall below the compliance threshold in each period."
   - Ensure the Executive Summary uses no unexplained acronyms or symbols on first reference; spell out on first use (e.g. "weighted least squares (WLS)").
   - After the Key Results table in the Executive Summary, add a 3–5 sentence plain-English **Headline Findings** paragraph written for a non-technical reader (no equations, no parameter names).

4. Follow output conventions: filename stem `260417_step6_methods_findings_v3`; preserve all content from v2 except where sub-tasks 1–3 above require edits. All plots remain embedded as-is.

**Trial 4 sub-tasks:**

Trial 4 writes `outputs/260417_step6_methods_findings_v4.md` from v3, applying typography changes only. No content changes.

1. **Apply LaTeX math notation throughout** — replace every plain-text symbol reference with the LaTeX inline form. Apply in body text AND in markdown table cells (Typora renders both). Key substitutions:
   - `lambda_CF` / `λ_CF` → `$\lambda_{CF}$`
   - `lambda_Policy` / `λ_Policy` → `$\lambda_{Policy}$`
   - `lambda_Proactive` / `λ_Proactive` → `$\lambda_{Proactive}$`
   - `e-bar` / `ē` → `$\bar{e}$`
   - `pi_0` / `π₀` → `$\pi_0$`
   - `p_cf` (quantity, not code object) → `$p_{cf}$`
   - `p_pro` (quantity) → `$p_{pro}$`
   - `avg_stage_jump` (quantity) → `$\overline{\Delta s}$`; define on first use: "average stage jump, $\overline{\Delta s}$"
   - `Δē/Δt` → `$\Delta\bar{e}/\Delta t$`
   - `lambda(P_Natural)` → `$\lambda(P_\text{Natural})$`; `lambda(P_Total)` → `$\lambda(P_\text{Total})$`
   - Do not alter code object names inside backtick spans or fenced code blocks.

2. **Apply object/group formatting** — two-tier system applied consistently throughout:
   - **Bold** for conceptual group references in body prose: **Constant Speed**, **CAZ+**, **Rest of London**, **Variable Speed**. Plain text (no formatting) in table headers.
   - Backtick monotype for literal code objects, file names, column names, and R object names: `Constant_Speed`, `audits.rds`, `cold_engaged`, `P_Total`, `p_cf`, `lambda_CF`, `stage_capped`, `COMP_THRESH`, etc.
   - First occurrence in each section sets the pattern; subsequent occurrences in the same paragraph may use the shorter form if unambiguous.

3. Follow output conventions: filename stem `260417_step6_methods_findings_v4`; no content changes beyond sub-tasks 1–2.

Trial 4 accepted. Outputs: `outputs/260417_step6_methods_findings_v4.md`. Applied LaTeX math notation and two-tier bold/backtick group formatting throughout; no content changes.

**Trial 5 sub-tasks:**

Trial 5 writes `outputs/260417_step6_methods_findings_v5.md` from v4, applying a human-readability review pass only. Audience for this pass: **Project Director** and **Programme Manager** — policy-focused readers who will not read sub-task code or parameter derivations in detail. No new content, no restructuring, no code changes.

1. **Plain-English lead for every Findings paragraph** — for each sub-task Findings block, check whether the opening sentence is interpretable without technical knowledge. If not, prepend a one-sentence plain-English statement of what was found and why it matters. The technical detail follows. Example: before "λ\_CF Constant\_Speed = 0.051 (departure Δ = −0.307 from reference)..." add "Generator fleets show almost no natural turnover — machines are replaced only when forced to by a compliance event."

2. **Executive Summary Headline Findings review** — re-read the paragraph as a PD/PM. Confirm it: (a) opens with the most important finding; (b) names the two scenarios explicitly; (c) states the policy implication clearly; (d) uses no unexplained symbols or codes. Rewrite sentences that fail any of these checks.

3. **Jargon audit of all Findings prose** — scan every Findings paragraph outside the Executive Summary. For any term that a PD/PM would not recognise on first encounter (e.g. "WLS", "right-stochastic", "ecological inference", "Phase B sub-segmentation"), either replace with plain English or add a brief parenthetical. Do not alter Execution paragraphs (these are for technical readers).

4. **Open Items and Known Limitations** — rewrite each bullet as a one-sentence plain-English risk or caveat legible to a PD/PM, followed by the original technical detail in parentheses or as a sub-sentence.

5. Follow output conventions: filename stem `260417_step6_methods_findings_v5`; preserve all content from v4 except where sub-tasks 1–4 above require edits. All plots, code blocks, and schema tables remain unchanged.

---

## Future work

**Equal-count phase binning (considered, deferred):** Replace time-interval Phase B sub-segments with equal-count bins to stabilise stage-proportion SE across segments. Deferred because: 
1. unequal delta-t complicates WLS lambda estimation;
2. audit clustering means bin boundaries are non-reproducible and policy-uninterpretable; 
3. cross-group sparsity in early phases is the binding constraint, not within-Phase-B variance. 
Revisit if the model moves to continuous-time hazard estimation.

**Report structure alternatives (considered, deferred for Step 6):** Two restructuring options were evaluated before Trial 3 and deferred in favour of the chronological step structure.
- **Option A — Policy-led single document:** Reorder sections as Context & Data → Key Findings → Methods → Forecasts → Limitations. Each section leads with the finding; methods follow. No content lost. Pros: more readable for policy audiences. Cons: separates method from result, harder to cross-reference code. Revisit if the report is published for a non-technical audience.
- **Option B — Two-part document:** Part I = Findings (ē, compliance trajectories, scenario comparison; tables and plots only, ~2 pages). Part II = Technical Methods (current step-by-step content with code). Policy readers read Part I; technical reviewers read both. Pros: highest readability gain for mixed audience. Cons: two sections must be kept in sync; overhead not justified for a one-time deliverable. Revisit if the report is issued in two separate formats (e.g. executive brief + technical annex).
