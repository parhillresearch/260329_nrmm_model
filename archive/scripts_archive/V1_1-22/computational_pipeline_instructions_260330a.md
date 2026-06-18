# NRMM LEZ Trend Analysis: Computational Pipeline

**Purpose:** This document provides the exact implementation constraints and execution logic for coding the analysis pipeline. It supplements `research_plan.md`.

## Phase 1 & 2: Ingestion, Filtering & Segmentation

**Inputs:** Raw audit dataset.

**Outputs:** `df_warm`, `df_cold`, `df_ze`, `n_ze`

**Execution Logic:**

1. **Initial Filter Cascade:** - Exclude dates outside 2016–2024.
   - Retain only `Initial.Machinery.Compliance ∈ {compliant, non-compliant}`.
   - Retain `Zone ∈ {CAZ, OA, GL}`.
   - Exclude missing `Initial.Emissions.Stage`.
2. **Engine Type Overrides (Order Critical):**
   - Override any generator-family `Machine.Type` to `Engine.Type = "Constant"`.
   - Fill any remaining blank `Engine.Type` with `"Variable"`.
3. **Group Assignment:** Map strictly via Section 2.2 rules (`Engine.Type` and `Zone` combination).
4. **Alternative Drivetrains:** Extract ZE/Electric records to `df_ze` prior to modeling.
5. **Exact Phase Assignment:** Assign A1, A2, and B based strictly on exact dates (Section 2.3).
6. **COVID Filter:** Exclude records audited `1.9.2020 – 31.3.2021` with recorded exemptions.
7. **Cold-Engaged Flag:** Map `toupper(trimws(...)) %in% c("YES", "V")` in the Registration column.

## Phase 3: Bipartite & Granular Aggregation

**Inputs:** `df_warm`, `df_cold`

**Outputs:** Stream A (Binary Counts), Stream B (Granular Group-Specific Counts)

**Execution Logic:**

1. **Year 2020 Straddle Check:** Collapse phases before wide-pivoting. 1.9.2020 boundary splits the year.
2. **Stream A (Binary):** Map empirical initial stages to `Compliant`/`Non-Compliant` utilizing Table 1.
3. **Stream B (Granular):** Tabulate count matrices per group-year. Restrict state dimensions to each group's active set.

## Phase 4: Parameter Estimation (Stream A)

**Outputs:** $\lambda_{CF}$, $\hat{e}_{ij}$, $\lambda_{Proactive}$

**Execution Logic & Methodological Corrections:**

1. **WLS Normalisation:** WLS regression must operate on stage *proportions* ($p_{s,t}$), not absolute count deltas. Use raw counts exclusively as WLS weights.
2. **Group-Specific GLS State Spaces (`max_stage`):**
   - **Constant_Speed:** `max_stage = 3` (Active stages: I, II, IIIA). Do not distribute mass to IIIB/IV. Expected output $\lambda_{CF} \approx 0.358$.
   - **CAZ+:** `max_stage = 5` (Active transition is IV $\to$ V). Expected Phase B output $\lambda_{CF} \approx 0.363$.
   - **Rest_of_London:** `max_stage = 6` (Full stage range present). Expected Phase B output $\lambda_{CF} \approx 0.219$.
3. **Estimation Window & Temporal Splitting:**
   - **Constant_Speed:** Pool all cold records 2017–2023. Explicitly exclude 2024 from $\lambda_{CF}$ fit (use 2024 solely as Phase C starting state). Do not split by phase.
   - **CAZ+ and Rest_of_London (Phase B):** Split Phase B (1 Sep 2020 – 31 Dec 2024 = 1582 days) into 3 equal segments (~527 days). Segment midpoints: `2021.389`, `2022.832`, `2024.278`. Annualize $\Delta p$ by dividing by $\Delta t$ between midpoints. Do NOT pool these groups together.
   - **CAZ+ and Rest_of_London (Phases A1 & A2):** Pool these two groups due to data sparsity.

## Phase 5: Granular Matrix Assembly (Stream B)

**Outputs:** $\mathbf{P}_{Total}$ (empirical group-specific matrices per phase)

**Execution Logic:**

1. Construct empirical matrices from Stream B counts based strictly on active state dimensions per group.
2. **Reconciliation (Floor & Rescale):** If $\lambda_{Proactive} < 0$, set to 0. Calculate scaling factor $S_i = \frac{P_{Total, i}}{P_{Natural, i} + P_{Enforcement, i}}$ and scale the remaining components to satisfy right-stochastic constraint $\sum_j P_{ij} = 1$.

## Phase 6: Forecast & Emissions Execution

**Inputs:** $\mathbf{P}_{Total}^{(B)}$, Phase B final counts.

**Outputs:** Forecasted Stage proportions 2026-2030, $E_{g,t}$

**Execution Logic:**

1. **Group Merge:** On 1.1.2025, sum CAZ+ and Rest of London into a single "Variable Speed" population vector.
2. **Scenario A:** Project using unadjusted $\mathbf{P}_{Total}^{(B)}$.
3. **Scenario B:** - Apply Boolean target mask $\mathbf{M}$ (Section 2.5).
   - Zero out non-compliant transition elements.
   - Redistribute excised probability mass equally across the permitted compliant stages for that group.
4. **Emissions:** Calculate $E_{g,t}$ utilizing Hard Defaults: 2,000 hrs/annum and standard EMEP/EEA Tier 3 emission factors. Scope is restricted strictly to audited equipment.