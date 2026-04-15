# Pipeline of coding steps

**Version:** 1.4 (Empirical Parameters Integrated)

## Phase 1 & 2: Ingestion, Filtering & Segmentation

**Status:** Completed

- **Input Validation**: 16,251 raw rows.
- **Filter Execution**: Drop dates outside 2016-2024 (2,582), non-machinery (1,779), invalid zones (5), unassignable engine types (428), unresolvable stages (502), COVID-exempt (192).
- **Engine Standardization**: Map 1,316 generator-family records to `Constant Speed`.
- **Output Validation**: 10,749 analysis-ready records (Cold = 1,815; Warm = 8,934).

## Phase 3: Bipartite & Granular Aggregation

**Status:** Completed

- **Compliance Routing**: Map records to administrative vs. physical outcomes.
- **Stream A**: Map empirical stages to Binary Compliance based on Table 1.
- **Stream B**: Tabulate 6-state count matrices per group-year.

## Phase 4: Parameter Estimation (Parallel Streams A & B)

**Inputs**: Stream A & Stream B counts.

**Execution Logic**:

1. **Natural Rate (**$\lambda_{CF}$**)**: Execute WLS on state proportions restricted to physically compliant initial states. Apply empirically derived constraints to resolve identified signal exhaustion and volatility:
   - **Constant_Speed**: Apply `max_stage = 3`. Utilize pooled 2017–2023 estimation window. Ignore Phase B isolation. Expected $\lambda_{CF} \approx 0.358$.
   - **CAZ+ (Phase B)**: Apply `max_stage = 5`. Utilize 3-segment temporal split (midpoints: 2021.389, 2022.832, 2024.278). Expected $\lambda_{CF} \approx 0.363$.
   - **Rest_of_London (Phase B)**: Apply `max_stage = 6`. Utilize 3-segment temporal split. Expected $\lambda_{CF} \approx 0.219$.
   - **Phase A1/A2**: Pool variable speed groups due to sample sparsity (A1 n=139; A2 n=357).
2. **Enforcement Rate (**$\bar{e}$**)**: Calculate empirical probability matrix from strict physical enforcement outcomes (Emissions reduced = Yes). Route absolute removals to the ZE state.
3. **Proactive Rate (**$\lambda_{Proactive}$**)**: Solve WLS for $\lambda_{Total}$ using warm-engaged counts; subtract $\lambda_{CF}$ and $\bar{e}$.

## Phase 5: Matrix Assembly & Normalization

**Execution Logic**:

1. Construct composite matrix $\mathbf{P}_{Total} = \mathbf{P}_{Natural} + \mathbf{P}_{Enforcement} + \mathbf{P}_{Proactive}$.
2. Enforce `max_stage` active state dimensions per group.
3. Apply floor-and-rescale algorithm if $\lambda_{Proactive} < 0$ to satisfy right-stochastic constraint $\sum_j P_{ij} = 1$ (Kemeny & Snell, 1960).

## Phase 6: Forecast & Emissions Execution

**Execution Logic**:

1. **Group Merge**: Combine CAZ+ and Rest of London into "Variable Speed" vector on 1.1.2025.
2. **Scenario B Masking**: Zero non-compliant transitions utilizing Boolean mask $\mathbf{M}$; redistribute excised mass across valid permitted states.
3. **Emissions**: Apply $E_{g,t} = \sum N_{g,s,t} \times \overline{kW}_{g,s} \times 2000 \times EF_s$.