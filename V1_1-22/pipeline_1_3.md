# Coding Implementation

**Version:** 1.3 (Aligns with Research Plan v1.19)

## Phase 1: Data Ingestion & Sanitization

1. Load raw audit dataset.
2. Standardize categorical variables (e.g., map Stage definitions to ordinal integers).
3. Drop records missing critical fields: Date, Initial Stage, Equipment Group (Wickham, 2014, *Journal of Statistical Software*).
4. **Compliance Outcome Mapping:** Map every record to a compliance routing tier (Rows 1–6) based on Site Registration, Machine Registration, and Emissions Compliance status (per Table 2 of the Research Plan).

## Phase 2: Segmentation & Filtering

1. Extract and separate "Stage ZE" and alternative drivetrain records.
2. Apply exact-date boundaries to assign Model Phases (A1, A2, B).
3. Apply COVID filter: Drop exempt records (1.9.2020 – 31.3.2021).
4. Bifurcate remaining data into `Cold-Engaged` and `Warm-Engaged` subsets.

## Phase 3: Count Aggregation & Visualisation

1. **Compliance Routing Visualisation (New):** Compute annual descriptive statistics for each compliance routing type (Rows 1–6). Generate stacked bar charts displaying overall compliance vs. non-compliance routing distributions by group and year for visual inspection.
2. **Stream A (Binary):** Map empirical initial stages to `Compliant`/`Non-Compliant` utilizing Table 1 for physically compliant machinery (Rows 1–3).
3. **Stream B (Granular):** Tabulate annual aggregate 6-state counts ($C^t_{g,s}$) for `Cold-Engaged` and `Warm-Engaged` fleets per group.
4. Tabulate annual observed enforcement counts ($\hat{e}_{ij}$) per group, **strictly restricted to Row 4 outcomes** (Emissions reduced by audit = Yes), which includes physical upgrades and absolute site removals.

## Phase 4: Parameter Estimation (Parallel Streams A & B)

1. **Parallel Execution:** Execute Weighted Least Squares (WLS) regressions twice on state *proportions* ($p_{s,t}$): once on Stream A (binary compliance rates) and once on Stream B (granular replacement rates) using raw counts exclusively as weights.
2. **Natural Rate (**$\lambda_{CF}$**):** Solve WLS using aggregated `Cold-Engaged` counts restricted to physically compliant initial states (Rows 1-3) (Allison, 1982, *Sociological Methodology*).
   - *Constant_Speed:* Pool 2017–2023. `max_stage = 3`.
   - *Variable Speed (Phase B):* Split Phase B into 3 equal segments (~527 days). Do not pool groups. CAZ+ `max_stage = 5`; Rest_of_London `max_stage = 6`.
   - *Variable Speed (A1/A2):* Pool groups due to sparsity.
3. **Enforcement Rate (**$\bar{e}$**):** Calculate empirical probability matrix $\mathbf{P}_{Enforcement}$ from Row 4 $\hat{e}_{ij}$ divided by initial states. Removals are routed to the ZE state.
4. **Proactive Rate (**$\lambda_{Proactive}$**):** Solve WLS for $\lambda_{Total}$ using `Warm-Engaged` counts. Isolate $\lambda_{Proactive}$ by subtracting $\lambda_{CF}$ and the mean enforcement rate.

## Phase 5: Matrix Assembly & Normalization

1. Construct composite matrix per group: $\mathbf{P}_{Total} = \mathbf{P}_{Natural} + \mathbf{P}_{Enforcement} + \mathbf{P}_{Proactive}$. Dimensions are restricted to active states defined in Phase 4.
2. Apply floor-and-rescale algorithm if $\lambda_{Proactive} < 0$ to satisfy right-stochastic constraints (Kemeny & Snell, 1960, *Finite Markov Chains*).

## Phase 6: Forecast & Emissions Execution

1. Apply 1.1.2025 Group merge mapping (CAZ+ and Rest of London into "Variable Speed").
2. Execute Markov chain projections (Scenarios A and B) iteratively to 2030. Scenario B strictly zeroes non-compliant transitions utilizing mask $\mathbf{M}$.
3. Calculate absolute emissions using static Hard Default multipliers ($E_{g,t}$) applied to the Stream B granular absolute counts.