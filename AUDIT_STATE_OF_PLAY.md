> **SUPERSEDED — historical record only, not current.**
> Superseded by: notes.md "State of play" (16 Jun 2026 audit of steps 1-6; conclusions absorbed).
> Retained for provenance. Do not cite; figures and definitions here may
> predate the data-quality corrections of July 2026.

# Audit: Existing Work & Overengineering Assessment

**Date:** 16 Jun 2026 \| **Status:** Steps 1–6 executed; code complete, outputs accepted, no execution since 21 May.

------------------------------------------------------------------------

## Executive Summary

The project has a **working end-to-end pipeline** that delivers compliance rates (ē), replacement rate parameters (λ), and scenario forecasts to 2030. **Core model logic is sound.** However, **the code path to get there was fragile and overengineered in places**, with 7 iterations on Step 1 alone due to compliance-definition bugs. Key blockers: (1) manual string-regex parsing for compliance codes (high failure risk), (2) WLS estimation windows chosen ad-hoc per group (not principled), (3) enforcement modeling abandoned midway (enforcement success rates were 0.0–1.4%, suggesting poor capture).

**Reusability verdict:** Step 1 core logic solid after fixes, Step 2 straightforward, Steps 3–5 model logic is correct but code is verbose. Step 6 report structure is sound.

## What Was Built: The Approach

The pipeline follows a standard quasi-experimental design:

1.  **Step 1: Data ingestion** — Filter 16,251 records to 11,131 in-scope audits; assign 4 equipment groups; derive compliance flags.
2.  **Step 2: Exploratory** — Tabulate stage distributions and compliance rates by group × phase.
3.  **Step 3: Parameter estimation** — WLS regression of fleet mean stage on time (separate windows per group) → λ_CF (natural turnover); compliance rate ē from threshold counts.
4.  **Step 4: Transition matrices** — Convert λ to annual replacement probability p; build 6×6 right-stochastic matrices.
5.  **Step 5: Forecasting** — Project Stage distributions 2025–2030 under Scenario A (proactive compliance only) and B (full enforcement).
6.  **Step 6: Report** — Consolidate findings with embedded plots and schema tables.

**Complexity drivers:** - Four stratified equipment groups (Constant_Speed, CAZ_Plus, Rest_of_London, Variable_Speed) - Three policy phases (A1, A2, B sub-segments, Phase C) - Cold/warm split for counterfactual comparison - Markov transition matrices (6×6 per group)

## Critical Bugs Found & Fixed

### Step 1: Data ingestion (7 iterations, closed in v6)

**Trial 1–2 (pre-run):** Logic review found 4 structural issues (P24 exclusion, missing Variable_Speed group, date filter, Phase C unassigned).\
✓ Fixed before first execution.

**Trial 4: Compliance definition catastrophic failure** - **Bug 1 — Case sensitivity:** Test was `initial_machinery_compliance == "compliant"` (lowercase) but field value is `"Compliant"` (title case). **Result:** All compliant machines silently marked non-compliant. - **Bug 2 — String regex collision:** Regex `str_detect(x, "E")` applied to raw `initial_machinery_reasons` to detect emissions non-compliance. When field value is `"None"` (standard audit entry for no reason code), `toupper("None") = "NONE"` and `str_detect("NONE", "E")` matches the substring 'E', wrongly flagging all compliant machines as emissions non-compliant. - **Bug 3 — Wrong field:** Used manual regex on `initial_machinery_reasons` instead of the pre-derived boolean flag `init_mach_emissions_compliant` (which correctly uses `fixed = TRUE` grepl, immune to "None" string). - **Impact:** 100% misclassification in Trial 4 — all compliant counts returned zero; all records misclassified as non-compliant.

**Trial 5:** Second bug — `rowSums()` unintentionally included year column (integer type), inflating row totals by 2016–2024. Latent third bug in label reconstruction (`paste0/sub` logic incorrect, never triggered on current data but would fail on future data with A/C/P/X codes).

**Trial 6:** All fixed. Removed 169-line logic-audit section (unused, replaced with 3 `stopifnot()` assertions).

**Verdict:** The string-regex approach to compliance was **unnecessarily fragile**. Using the pre-derived `init_mach_emissions_compliant` boolean from the start (v1, not v6) would have avoided all three failures. **Lesson:** Use Boolean flags from the audit pipeline; avoid manual regex parsing on raw strings.

------------------------------------------------------------------------

### Step 3: Parameter estimation (2 major failures in trials 1–2)

**Trial 1:** COMP_THRESH thresholds misread from schema (one policy era off).\
**Trial 2:** Attempted fix made it worse (pushed thresholds forward again).\
**Trial 3:** User rewrote with correct thresholds; accepted.

**Trial 4–5:** Enforcement success rate captured only \~35 on-the-spot replacements (using `enforcement_upgrade == final_stage > initial_stage`). Changed indicator to `final_mach_emissions_compliant == TRUE`. Result: enforcement success rates still near-zero (0.0–1.4%), suggesting the audit data does not capture enforcement outcomes well (post-visit compliance happens days/weeks after audit; final_stage is not updated).

**Verdict:** Threshold definitions were correct but interpretation was slippery. Enforcement modeling was abandoned (entire P_Enforcement matrix dropped) because the signal was too weak. This is a **real analytical constraint**, not overengineering — but suggests enforcement is best treated as a Boolean scenario mask, not a continuous parameter. The decision to drop it was sound.

------------------------------------------------------------------------

### Step 2, 3, 6: Table layout convention thrashing

- **Step 2 trials 1–6:** Table structure bugs (backtick quoting, `expand.grid` vs `complete()` NSE issues). Took 7 trials to get column structure right.
- **Step 3 trials 1–2:** Tables had phases-as-rows when spec said phases-as-columns. Required mid-project CLAUDE.md update.
- **Step 6 trials 1–4:** Five revisions for formatting (plot embedding, factual value corrections, LaTeX notation, bold/backtick group formatting).

**Verdict:** **Avoidable overengineering.** The table layout changes mid-project (trials 2–3 of Step 3) suggest the output spec was not locked before coding. KableExtra HTML tables introduced rendering issues (Positron Preview silently rewrote them). The multi-trial convergence on typography in Step 6 (trials 1–5) is organizational, not analytical, bloat.

## Model Design Decisions: Sound or Overengineered?

| Decision | Verdict | Rationale |
|------------------------|----------------------|--------------------------|
| **4-group stratification** | **Keep** | Policy-driven; thresholds differ by group and zone; necessary for LEZ evaluation |
| **WLS with group-specific windows** | **Reconsider** | CS annual (n≈16/yr); CAZ+ 3-segment bins; RoL annual; A1/A2 pooled for VS. Ad-hoc, not principled. Could simplify to uniform annual grid with robustness checks. |
| **6×6 Markov matrices** | **Keep** | Required for stage-by-stage forecasting; cannot simplify without losing stage detail. |
| **Enforcement Boolean mask (Scenario B)** | **Keep** | Pragmatic: direct approach avoids parameterizing weak signal. |
| **Section 7.5 logic-bug audit (Step 1 v6)** | **Cut** | 169 lines of verification code that generated zero actionable output. Replaced with 3 assertions. |
| **Diagnostic plots and tables per step** | **Simplify** | Every step produces 5+ diagnostic tables + plots. Useful for debugging; bloat for production. Keep 1–2 key outputs per step. |
| **Five iterations on Step 6 report** | **Avoid** | Trials 1–4 were formatting/layout fixes unrelated to content. Lock output spec (structure, audiences, formatting) before writing. |

## What's Solid & Reusable

✓ **Step 1 core logic (post-v6):** Filtering rules, group assignment, phase boundaries. Solid once compliance flags use `init_mach_emissions_compliant`.

✓ **Step 2:** Straightforward tabulation and faceted plots. Works.

✓ **Step 3 parameter logic:** WLS estimation is correct; compliance rates calculated correctly; schema thresholds now locked.

✓ **Step 4 transition matrices:** Markov matrix construction, row-stochastic validation, scenario initialization — all correct.

✓ **Step 5 forecasting:** Simple matrix multiplication; handles both scenarios cleanly.

✓ **Estimated parameters:** λ_CF values (CS=0.051, CAZ+=0.262, RoL=0.241) are stable after fixing estimation windows. These can be reused.

## What to Reconsider

⚠️ **Step 1 string parsing:** Don't rebuild compliance flags from raw reason strings. The pre-derived `init_mach_emissions_compliant` and `final_mach_emissions_compliant` flags exist in the audit pipeline; **use them directly.** (This would have eliminated 3 of the 7 iterations.)

⚠️ **WLS temporal windows:** The group-specific choices (annual for CS; 3-segment for CAZ+; pooled A1/A2 for VS) were made to maximize signal-to-noise but are ad-hoc. **Consider:** uniform annual grid across groups with explicit sparsity flagging, or document why the heterogeneous window choice is necessary for each group.

⚠️ **Enforcement modeling:** The decision to drop P_Enforcement is correct (near-zero signal), but it reveals a **data quality gap** — post-audit enforcement outcomes are not recorded in the audit table. This is not overengineering; it's a real constraint. **Scenario B Boolean mask is the right simplification.**

⚠️ **Diagnostic bloat:** Every step produces tables and plots that are useful for *validation during development* but don't appear in the final report. Consider: (a) run diagnostics on demand, not by default; (b) lock a minimal output spec per step; (c) save the verbose versions for archive.

⚠️ **Report multi-trial convergence:** The five iterations on Step 6 (v1–v5) were formatting and factual corrections, not analytical improvements. **Lesson:** Write a detailed output spec *before* writing the report. Lock it with the user. Then execute once. (This would have collapsed 5 trials into 1.)

## How to Restart: Recommendations

### Option 1: Reuse the current pipeline (conservative)

- **Pros:** All 6 steps tested; core model logic is correct; parameters estimated.
- **Cons:** Verbose code; fragile compliance parsing (Step 1 v6); table layout churn; Step 6 formatting overhead.
- **Do:** Re-run Steps 1–5 with EF_s factors to complete Step 5 emissions. Freeze Step 6 output spec before rewriting the report.

### Option 2: Simplify & rebuild (moderate effort)

- **Keep:** Step 2 (exploratory); Step 3–4 model logic; Step 5 forecasting; locked parameters.
- **Rewrite:** Step 1 (shorter, cleaner, compliance-flag driven); Step 6 (structured report spec; one-shot execution).
- **Time saving:** \~20% code reduction; eliminates compliance-parsing risk.

### Option 3: Minimal viable pipeline (aggressive)

- **Keep:** Core parameter estimates (λ_CF, ē); Scenarios A & B.
- **Rewrite:** Everything from first principles; linear regression instead of WLS if acceptable; simpler compliance tracking.
- **Risk:** Lose group-specific estimation windows; may not fully justify 4-group stratification. Revisit only if the 4-group structure is not essential to the policy question.

### Recommendation

**Option 2** — Simplify & rebuild. It captures the benefit of proven model logic without the accumulated code debt. The compliance-parsing bugs in Step 1 v1–v5 suggest that any rewrite should **use only pre-derived Boolean flags, not raw string regex.** The rest of the pipeline is sound.

## Data Quality Notes

**11,131 in-scope records** (12,363 group × phase allocated; 4-group structure with Variable_Speed row-duplication).

**Known issues:** - Enforcement success rates (0.0–1.4%) suggest post-audit outcomes not captured in Final Machinery Reasons. Scenario B Boolean mask is a pragmatic workaround. - Variable_Speed Phase B3 shows 5 records dated 2024 (anticipatory pre-2025 records); Phase C initialisation uses latest P24 data. - Constant_Speed max_stage = 3 (IIIB/IV absent from cold fleet); CAZ+ and RoL use full 6-stage range.

**What's missing:** - EF_s factors (EMEP/EEA Tier 3 NOx by stage) — needed for Step 5 emissions quantification. - Post-visit enforcement outcomes (e.g., whether a flagged machine was later removed/replaced) — would improve Scenario B realism.

## Summary Table: Trials, Bugs, and Time-to-Resolution

| Step | Trials | Critical bugs | Time-to-fix | Verdict |
|--------------|--------------|-----------------|--------------|--------------|
| 1 | 7 | 3 (compliance parsing) | Pre-v6 | Fragile approach; rebuilding recommended |
| 2 | 2 | 1 (table structure) | Pre-v7 | Straightforward; reuse |
| 3 | 6 | 2 (threshold misread; enforcement capture) | v3, v6 | Logic sound; enforcement gap real |
| 4 | 3 | 1 (stage-space mismatch) | v3 | Reuse matrices; math is correct |
| 5 | 1 | 0 | — | Clean; awaiting EF_s |
| 6 | 5 | 0 analytical (5 formatting) | v5 | Output spec lacked detail; rebuild with spec locked |

------------------------------------------------------------------------

**Next step:** Clarify whether you want to reuse the current codebase (Option 1), simplify it (Option 2), or start fresh (Option 3). The compliance-parsing risk in Step 1 and the formatting overhead in Step 6 are the main barriers to reuse; the model logic in Steps 3–5 is solid.