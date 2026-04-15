# NRMM LEZ Trend Analysis: Short-Term Research Plan

**Version**: 1.10 | **Date**: 29 March 2026 | **First estimates required**: 30 March 2026, 17:00

## 1. Problem and Objectives

### 1.1 Problem statement

The London Non-Road Mobile Machinery (NRMM) Low Emission Zone (LEZ) has been in force since September 2015, requiring machinery in the 37–560 kW range[^1] to meet progressively tighter EU emissions Stage requirements (Table 1). Compliance is enforced through on-site audits of machinery engine plates. This project evaluates the LEZ's effect on fleet Stage composition over the programme period 2016–2025 and projects fleet composition and associated emissions to 2030.

[^1]: kW refers to mechanical power per engine plate, not electrical output or thermal input.

##### Table 1. Emissions Stage Compliance Requirements



| **Policy phase**   | **1: 1.9.2015[^2]** | **2: 1.9.2020 (+6M)[^3]** | **3: 1.1.2025** | **4: 1.1.2030** | **5: 1.1.2040** |
| ------------------ | ------------------- | ------------------------- | --------------- | --------------- | --------------- |
| **Constant speed** | IIIA                | V                         | V               | V               | ZE              |
| **CAZ+**           | IIIB                | IV                        | V               | V               | ZE              |
| **Rest of London** | IIIA                | IIIB                      | IV              | V               | ZE              |

[^2]: Policy phase 1 spans 1.9.2015 onwards. 2015 excluded due to lack of audit data. [^3]: Six-month COVID-19 compliance extension granted.

### 1.2 Objectives

For each of the three equipment groups (Constant Speed, CAZ+, Rest of London) and for each model phase:

1. **Baseline turnover**: Estimate a uniform annual natural upgrade probability ($\lambda_{CF}$) that would have occurred without LEZ intervention.
2. **LEZ-driven compliance turnover**: Estimate the average annual increase in Stage upgrades attributable to the LEZ compliance pathway.
3. **Enforcement-driven turnover**: Estimate the average annual increase in Stage upgrades attributable to LEZ enforcement actions.
4. **Stage distribution forecast**: Project the percentage of fleet in each Stage annually from 2026 to 2030 under two scenarios.
5. **Emissions estimation**: Estimate annual emissions (normalised to emissions per MWh work delivered) per group.
6. **Future work: Damage Costs**: Estimate damage costs avoided.
7. **Future Work: Refined COVID Exemption Modelling**: Implement state-adjustment methodology.

### 1.3 Scope

- **Analysis period**: 1.1.2016–31.12.2024.
- **Forecast horizon**: 2030.
- **Equipment in scope**: 37–560 kW variable-speed and constant-speed machinery.
- **Equipment excluded**: Hybrid, electric, flywheel, hydrogen (treated descriptively).
- **Cold-engaged fleet**: Machines audited without prior registration, used to estimate $\lambda_{CF}$.

## 2. Methodology

### 2.1 Overview: Count-First Transition Model

The core model utilizes a **Count-First Architecture**. Raw absolute machine counts ($C$) are tracked through all preprocessing stages, strictly converting to transition probabilities ($\mathbf{P}$) at the final calculation step. This avoids aggregating proportions prematurely, yielding statistically stable matrices (Agresti, 2013) and natively providing absolute counts ($N_{g,s,t}$) for emissions calculations.

$$C_g^{t+1} = C_g^t \cdot \left(\mathbf{P}_{Natural} + \mathbf{P}_{Enforcement} + \mathbf{P}_{Proactive}\right)^{(g,k)}$$

### 2.2 Equipment groups

| **Group**          | **Description** | **Derivation from raw data** |
| ------------------ | ------------------------------------------------------------ | --- |
| **Constant Speed** | Generators and other constant-speed equipment. Direct IIIA-to-V upgrade pathway. | `Engine.Type.clean == "Constant"` (any Zone) |
| **CAZ+**           | Variable-speed machinery in the CAZ+ zone. Merges with Rest of London on 1.1.2025. | `Engine.Type.clean == "Variable"` AND `Zone ∈ {CAZ, OA}` |
| **Rest of London** | Variable-speed machinery outside CAZ+. | `Engine.Type.clean == "Variable"` AND `Zone == GL` |

Zone values `P24` and `BCP` are excluded — they belong to non-NRMM projects and have no group assignment. Group is derived during ingestion from the combination of the `Zone` column and the (corrected) `Engine.Type` column; neither column alone is sufficient.

### 2.3 Exact Phase Boundaries

Model phases utilize exact policy interval dates to prevent temporal aggregation bias (Petersen, 1991).

**Table: Model phase definitions**

| **Model phase** | **Period (Exact Dates)** | **Rationale**                                                |
| --------------- | ------------------------ | ------------------------------------------------------------ |
| A1              | 1.1.2016 – 31.12.2018    | Pre-Stage V market availability.                             |
| A2              | 1.1.2019 – 31.8.2020     | Stage V equipment newly available.                           |
| B               | 1.9.2020 – 31.12.2024    | Tighter LEZ requirements. CAZ+ and Rest of London modeled separately. The 200 audits with COVID Exemptions during 1.9.2020 – 31.3.2021 are filtered out, the rest treated as Model Phase B. |
| Forecast (C)    | 1.1.2025 onwards         | CAZ+ and Rest of London combined. Forecast projection space. |

### 2.4 Composite Transition Estimation

1. **Natural Rate (**$\lambda_{CF}$**):** Estimated via Generalized Least Squares (GLS) on the aggregate count shifts of the Cold-Engaged fleet. This rate populates the off-diagonal permitted pathways in $\mathbf{P}_{Natural}$. To avoid conflating existing fleet proportions with supply-side market availability, assign equal weights ($w_{ij} = 1/k$, where $k$ is the number of permitted target stages).
2. **Enforcement Rate (**$\hat{e}_{ij}$**):** Direct count of observed audit upgrades divided by the total audited fleet initially in stage $i$. Upgrades are identified where `Final.Emissions.Stage > Initial.Emissions.Stage` within the same audit record (columns `Initial.Emissions.Stage` and `Final.Emissions.Stage`).
3. **Proactive Rate (**$\lambda_{Proactive}$**):** Uniform overall rate estimated via GLS minus $\lambda_{CF}$ and $\bar{e}$.

**Variance Estimation:** Asymptotic standard errors are derived directly from the GLS covariance matrix (Greene, 2018), discarding computationally unstable non-parametric bootstrapping.

**Note:  **If $\lambda_{Proactive}<0$ apply the floor-and-rescale procedure, specified in the Appendix (floor at zero, proportional scaling of natural and enforcement components) to resolve.

### 2.5 Separation of baseline, LEZ-compliance, and enforcement effects

**Counterfactual baseline:** Cold-engaged machine records (§3.3) are modelled using a uniform natural upgrade rate ($\lambda_{CF}$) applied across all non-terminal stages. Cold-engaged operators have lower LEZ awareness; their fleet dynamics represent a closer approximation to natural fleet turnover. The uniform rate $\lambda_{CF}$ populates $\mathbf{P}_{Natural}^{(g,k)}$, which serves as the counterfactual; the element-wise difference $\mathbf{P}_{Total}^{(g,k)} - \mathbf{P}_{Natural}^{(g,k)}$ isolates the attributable LEZ transition effect.

**Limitation (Bias in proxy):** Cold-engaged operators operate within London's LEZ-influenced market. This proxy likely overestimates $\lambda_{CF}$ (leakage of LEZ demand into the second-hand market), producing a conservative (underestimated) bound on the true LEZ-attributable effect.

**Cold-engaged matrix structure by phase** — determined from aggregate counts:

| **Phase**[^4] | **Cold-engaged n**     | **State space** | **Group treatment**      | **Rationale**                                                |
| ------------- | ---------------------- | --------------- | ------------------------ | ------------------------------------------------------------ |
| A1            | 133 (avg ~44/group)    | 5-state (I–IV)  | Pooled across all groups | Per-group count too sparse; Stage V absent in A1 cold-engaged (0/133 = 0%). |
| A2            | 563 (avg ~188/group)   | 5-state (I–IV)  | Pooled across all groups | Per-group count $n=188$ insufficient for stable 5-state multinomial estimation (Agresti, 2013). |
| B             | 1,972 (avg ~657/group) | 6-state (I–V)   | Per-group                | Adequate counts; Stage V accounts for 52.9% of B cold-engaged fleet. |

[^4]:Dates specified in **Table: Model phase definitions**

**Main (warm-engaged) matrix adequacy**: Clearly sufficient at all phases — A1 n=796 (~265/group), A2 n=2,714 (~905/group), B n=6,455 (~2,152/group).

**Within-fleet attribution via audit metadata**:

| **Audit outcome**  | **Attribution**                                              |
| ------------------ | ------------------------------------------------------------ |
| Self-compliant     | Natural turnover (consistent with $\mathbf{P}_{Natural}$) if cold-engaged group; LEZ+natural turnover if warm-engaged fleet |
| Driven compliant   | Audit-driven                                                 |
| Removed / replaced | Audit-driven                                                 |
| Illegal operation  | Excluded from model; reported separately                     |

**External cross-check**: A literature search for UK or European construction equipment fleet turnover rates is used to validate the baseline parameters.

### 2.6 Forecasting (2025–2030)

As each NRMM machine group (see 2.2) has a different population distribution at the end of Phase B, we create 3 forecasts, one for each group. Standard Markov chain projection: $C^{t+1} = C^t \cdot \mathbf{P}_{forecast}$

- **Scenario A (Status Quo):** $\mathbf{P}_{forecast} = \mathbf{P}_{Total}^{(B)}$.
- **Scenario B (Strict Enforcement):** Upgrades to non-compliant stages are zeroed. Permitted compliant target stages are hardcoded via a Boolean mask $\mathbf{M}$ applied to the transition matrix (Kemeny & Snell, 1960). Excised probability mass is redistributed equally across valid states. Post-2025 permitted target stages ($\mathbf{M} = 1$) are explicitly defined per Table 1 as:
  - **Constant Speed:** Stage V, ZE.
  - **Merged Variable Speed (CAZ+ / Rest of London):** Stage IV (Rest of London boundaries only, until 2030), Stage V, ZE.

### 2.7 Sensitivity analyses

- Phase model sensitivity: Compare 2-phase vs 3-phase outputs.



### 2.8 Emissions estimation

Annual emissions for each group are estimated as:

$$E_{g,t} = \sum_{s} N_{g,s,t} \times \overline{kW}_{g,s} \times \overline{H}_{g,s} \times EF_s$$

$N_{g,s,t}$ is extracted natively from the Count-First arrays.

**Hard Defaults (Triggered if client inputs are missing by 26 March):**

- **Operating Hours (**$\overline{H}_{g,s}$**):** Defaults to an industry-standard 2,000 hours/annum.
- **Emission Factors (**$EF_s$**):** Defaults to EMEP/EEA Tier 3 methodology standard factors (Ntziachristos & Samaras, 2019).
- **Unregistered Fleet:** Total estimates deferred to future work; emissions scope strictly restricted to the audited population.

## 3. Data Preprocessing

1. **Compliance filter:** Keep only records where `Initial.Machinery.Compliance ∈ {compliant, non-compliant}` (case-insensitive). All other values (No NRMM, Site Complete, Baselining, Declined Audit, Removed from site, blank) are tabulated and excluded. Both compliant and non-compliant records are retained — non-compliant machines are in-scope NRMM machinery that has not yet met requirements.
2. **Zone filter:** Retain `Zone ∈ {CAZ, OA, GL}`. Exclude `P24` and `BCP` (non-NRMM projects). Assign Group per §2.2 derivation rules.
3. **kW scope filter:** Parse `kW.Power` as numeric. Records with missing or non-numeric kW are **kept and flagged** (`kW_missing = TRUE`) for downstream handling — do not drop. Records with a valid numeric kW outside 37–560 are excluded.
4. **Filter Alternative Drivetrains:** Extract ZE and Electric records into a separate object (`df_ze`); retain the count (`n_ze`) for reporting. Do not discard — include in headline summary statistics.
5. **Segment by Exact Phase:** Assign audits by exact date (Section 2.3).
6. **COVID Filter:** Exclude machines audited between 1.9.2020 and 31.3.2021 with recorded exemptions (text "covid" in `Initial.Retrofit.or.Exemption` or `Final.Retrofit.or.Exemption`).
7. **Calculate Counts:** Derive $C_{g,s}^t$ from `Initial.Emissions.Stage`.
8. **Zone Merge:** Post-2024 records merge CAZ+ and Rest of London group identifiers.

## 4. Delivery Plan

| **Milestone**                           | **Tasks**                                                    |
| --------------------------------------- | ------------------------------------------------------------ |
| **M1: Data ready**                      | Extract and segment audit records into three groups. Tabulate Stage statistics per group-year. Extract kW data by segment. Complete audit frequency QA (RT-04). Isolate cold-engaged dataset. |
| **M2: Exploratory analysis complete**   | Produce descriptive Stage distribution charts per group and year. Complete phase model viability test (RT-03). Complete power analysis for aggregation thresholds (RT-05). Validate actual upgrade pathways observed in data (RT-07). Produce initial uniform natural upgrade rate ($\lambda_{CF}$) estimate from cold-engaged data (RT-01). |
| **M3: Model estimated**                 | Fit transition matrices per group and phase. Compute 95% CIs on all transition probabilities. Run COVID sensitivity test (2020 excluded vs included). Confirm emission factors and counterfactual reference scenario (RT-02 deadline). |
| **M4: Forecast and emissions complete** | Run Forecast Scenarios A and B (2026–2030). Compute annual emissions time series with counterfactual comparison. Produce unregistered fleet extrapolation if RT-06 is resolved; otherwise document audited-population-only scope. Must be complete by end of day 28 March to isolate M5. |
| **M5: Final outputs**                   | Finalise all charts, transition probability tables (with 95% CIs), and emissions time series. Verify internal consistency across all outputs. 29–30 March reserved strictly for QA, formatting, and verification; no estimation debugging. |



## 5. Research Tasks

### RT-01: Counterfactual baseline

**Status**: Completed. $\lambda_{CF}$ estimated via GLS on Cold-Engaged counts.

### RT-02: Emissions parameters (Hard Default)

**Status**: Hard Default Triggered (26 March deadline missed).

- **Emission Factors:** Locked to EMEP/EEA Tier 3 methodology (Ntziachristos & Samaras, 2019).
- **Operating Hours:** Locked to standard 2,000 hours/annum.

### RT-03: Phase model viability test

**Status**: Completed. 3-phase model confirmed via likelihood ratio/Wald testing.

### RT-04: Audit frequency quality assurance

**Status**: Completed. Annual time steps validated.

### RT-05: Aggregation threshold

**Status**: Completed. Minimum cell count established.

### RT-06: Unregistered fleet size (Hard Default)

**Status**: Hard Default Triggered (26 March deadline missed). Total fleet estimation abandoned. Emissions calculations restricted strictly to the audited population to prevent mathematically unconstrained scaling variance (Kuik et al., 2015).

### RT-07: Observed upgrade pathway validation

**Status**: Completed. Non-permitted LEZ upgrades quantified.

# 6. Computational Pipeline Sequence

### Phase 1: Data Ingestion & Sanitization

1. Load raw audit dataset.
2. Standardize categorical variables (e.g., map Stage definitions to ordinal integers).
3. Drop records missing critical fields: Date, Initial Stage, Equipment Group (Wickham, 2014, *Journal of Statistical Software*).

### Phase 2: Segmentation & Filtering

1. Extract and separate "Stage ZE" and alternative drivetrain records.
2. Apply exact-date boundaries to assign Model Phases (A1, A2, B).
3. Apply COVID filter: Drop exempt records (1.9.2020 – 31.3.2021).
4. Divide remaining data into `Cold-Engaged` and `Warm-Engaged` subsets, categorised by group.

### Phases 1–2 Findings

See `research_results.md` → Phases 1–2.

### Phases 1–2 Implementation Notes

1. **Engine Type two-step correction.** Raw data contained ~360 Phase B generator-family records (`Machine.Type` ∈ {Generator, Hybrid Generator, Flywheel Generator, Flybrid Generator}) mislabelled "Variable" in the Engine Type column; all A1 non-generator records had blank Engine Type. Applied two sequential mutations: (i) unconditionally override generator-family Machine Types to "Constant", regardless of existing Engine Type value; (ii) fill any remaining blank Engine Type with "Variable". Order matters — step (i) must precede step (ii) or generators with blank Engine Type would be incorrectly assigned "Variable".

2. **Cold-Engaged normalisation.** `Cold.Engaged` column contains "Yes", "V", and blank. Map `toupper(trimws(...)) %in% c("YES", "V")` to produce a logical `Cold_Engaged` flag. This captures both the standard and legacy "V" encoding.

3. **Year 2020 phase straddle.** Date 1 September 2020 is the A2/B boundary. Year 2020 therefore contains two Phase values in the data. Any `pivot_wider` keyed on `(Group, year)` without first collapsing Phase will produce list columns and fail. Add a `group_by(...) %>% summarise(n = sum(n))` step before each `pivot_wider` to collapse Phase.

### Phase 3: Count Aggregation

1. Calculate annual aggregate Stage counts ($C^t_{g,s}$) for the `Cold-Engaged` fleet.
2. Calculate annual aggregate Stage counts ($C^t_{g,s}$) for the `Warm-Engaged` fleet per group.
3. Tabulate annual observed enforcement upgrade counts ($\hat{e}_{ij}$) per group.

### Phase 4: Parameter Estimation

1. **Natural Rate:** Solve GLS for $\lambda_{CF}$ using aggregated `Cold-Engaged` counts.
2. **Enforcement Rate:** Calculate empirical probability matrix $\mathbf{P}_{Enforcement}$ from $\hat{e}_{ij}$ divided by initial states.
3. **Proactive Rate:** Solve GLS for $\lambda_{Total}$ using `Warm-Engaged` counts. Isolate $\lambda_{Proactive}$ by subtracting $\lambda_{CF}$ and the mean enforcement rate.

### Phase 4 Implementation Notes

4. **Proportions normalisation in WLS (critical).** Annual cold-engaged audit volumes vary dramatically (A1: 21→50→84; A2: 252→151). Using raw count deltas (ΔC_s) as the response variable makes λ_CF sensitive to audit volume changes rather than fleet composition shifts, producing impossible negative rates. The WLS regression must operate on stage *proportions* (p_{s,t} = C_{s,t} / Σ C_{s,t}): response = Δp_s, predictor = Σ_{j<s} p_{j,t}/k_j − p_{s,t}. Absolute counts are retained as WLS weights only.

5. **Pooling for A1/A2.** Per-group cold-engaged counts for A1 (avg ~52/group, 1–2 year-pairs) and A2 (avg ~188/group, 1 year-pair for most groups) yield only 4–8 GLS rows — insufficient for stable estimation. Pool all groups for A1 and A2 λ_CF. Phase B per-group estimation is viable only for Rest_of_London; CAZ_Plus Phase B estimate (λ_CF = 0.64, CI [0.44, 0.84]) is elevated relative to the other groups and pooling CAZ_Plus + Rest_of_London for Phase B should be tested.

6. **A2 partial year.** The A2 cold-pooled estimate (λ_CF = 0.063, CI [−0.15, 0.28]) is not significantly different from zero because year 2020 is truncated at 31 August, distorting the 2019→2020 proportion shift. Treat A2 λ_CF as unreliable; carry forward the A1 pooled estimate or pool A1/A2 when applying to Phases 3–5.

### Phase 5: Matrix Assembly & Normalization

1. Construct composite matrix: $\mathbf{P}_{Total} = \mathbf{P}_{Natural} + \mathbf{P}_{Enforcement} + \mathbf{P}_{Proactive}$.
2. Apply floor-and-rescale algorithm if $\lambda_{Proactive} < 0$ to satisfy right-stochastic constraints (Kemeny & Snell, 1960, *Finite Markov Chains*).

### Phase 6: Forecast & Emissions Execution

1. Apply 1.1.2025 Group merge mapping (CAZ+ and Rest of London).

2. Execute Markov chain projections (Scenarios A and B) iteratively to 2030.

3. Calculate absolute emissions using static Hard Default multipliers ($E_{g,t}$).

   

## Appendix A: Methodological Limitations

1. **Ecological Inference Fallacy:** Estimating transition probabilities ($\mathbf{P}_{Total}$) from aggregate count snapshots rather than longitudinal individual machine histories assumes macro-level shifts accurately represent individual transition hazards (Robinson, 1950).

2. **Entry/Exit Bias:** The model tracks aggregate volumes, implicitly absorbing fleet entry (purchases) and exit (scrap/relocation). Differential Stage composition between entering and exiting machines violates the Markov property of time-homogeneous transition probabilities.

3. **Competing Risks Additivity:** Proportional row scaling applied when $\lambda_{Proactive} < 0$ mathematically distorts underlying true hazard rates, an inherent limitation of linear additive probability modeling (Pintilie, 2006).

4. **Sparse Data Artefacts:** Pooling $\lambda_{CF}$ counts in early phases while isolating enforcement counts per group can trigger asymmetric $\lambda_{Proactive} < 0$ floors, representing an artefact of sparse matrices rather than observed behavioural shifts (Agresti, 2013).

5. **Reconciliation of Additive Identity:**

   When $\lambda_{Proactive} < 0$, it is floored at zero. This violates the decomposition $\mathbf{P}_{Total} = \mathbf{P}_{Natural} + \mathbf{P}_{Enforcement} + \mathbf{P}_{Proactive}$ as the sum exceeds $P_{Total}$. To maintain a strictly right-stochastic matrix while preserving relative competing transition hazards (Pintilie, 2006, *Competing Risks: A Practical Perspective*), apply proportional scaling to affected row $i$:

   - Set $P_{Proactive, i} = 0$
   - Calculate scaling factor: $S_i = \frac{P_{Total, i}}{P_{Natural, i} + P_{Enforcement, i}}$
   - Scale remaining components:
     - $P_{Natural, i}^* = P_{Natural, i} \times S_i$
     - $P_{Enforcement, i}^* = P_{Enforcement, i} \times S_i$

   **Confidence Intervals:** 95% CIs are computed using non-parametric bootstrap resampling of *individual machine records* within each group-year, recomputing aggregate proportions per iteration.

## Appendix B: Future Work – Addressing COVID Exemption Data Loss

Excluding machines with COVID exemptions from the primary model introduces a potential systemic bias by removing a specific subset of the population. Future iterations of the model will test replace the exclusion rule with a Calendar Boundary and State Adjustment methodology, **perhaps something like these ideas.**

1. **Maintain Calendar Boundaries:** Strict calendar year boundaries will be maintained for the transition matrices (Phase A2 = 2019–2020; Phase B = 2021–2025). 
2. **Override Compliance Targets:** For exempt machines audited during the 1.9.2020–31.3.2021 interregnum, the expected compliance target will be overridden to match their specific exemption status.
3. **Transition Probability Impact:** An exempt machine audited in Q1 2021 belongs temporally to Phase B. It will be treated as legally compliant at its observed Initial Stage. Consequently, it will contribute to the annual population denominator ($N_g^t$) but will register a zero enforcement-driven transition ($\mathbf{P}_{Enforcement} = 0$).

This approach preserves the mathematical integrity of the annual composite transition matrix ($\mathbf{P}_{Total}$) and prevents the structural complexities of staggered timelines without discarding valid audit data.