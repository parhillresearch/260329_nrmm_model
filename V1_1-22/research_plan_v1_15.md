# NRMM LEZ Trend Analysis: Short-Term Research Plan

**Version**: 1.15 (State Space & Temporal Refinement) | **Date**: 30 March 2026 | **First estimates required**: 30 March 2026, 17:00

## 1. Problem and Objectives

### 1.1 Problem statement

The London Non-Road Mobile Machinery (NRMM) Low Emission Zone (LEZ) has been in force since September 2015, requiring machinery in the 37–560 kW range [^1] to meet progressively tighter EU emissions Stage requirements (Table 1). Compliance is enforced through on-site audits of machinery engine plates. This project evaluates the LEZ's effect on fleet Stage composition over the programme period 2016–2025 and projects fleet composition and associated emissions to 2030.
[^1]: kW refers to mechanical power per engine plate, not electrical output or thermal input.

##### Table 1. Emissions Stage Compliance Requirements

| **Policy phase**   | **1: 1.9.2015**[^2] | **2: 1.9.2020 (+6M)**[^3] | **3: 1.1.2025** | **4: 1.1.2030** | **5: 1.1.2040** |
| ------------------ | ---------------- | ---------------------- | --------------- | --------------- | --------------- |
| **Constant speed** | IIIA             | V                      | V               | V               | ZE              |
| **CAZ+**           | IIIB             | IV                     | V               | V               | ZE              |
| **Rest of London** | IIIA             | IIIB                   | IV              | V               | ZE              |

[^2]: Policy phase 1 spans 1.9.2015 onwards. 2015 excluded due to lack of audit data.
[^3]: Six-month COVID-19 compliance extension granted.

### 1.2 Objectives

For each of the three equipment groups and for each model phase:

1. **Compliance rate assessment**: Assess the proportion and rate of change of compliant vs. non-compliant machinery, broken down by group.
2. **Baseline turnover**: Estimate a uniform annual natural upgrade probability ($\lambda_{CF}$) that would have occurred without LEZ intervention.
3. **LEZ-driven compliance turnover**: Estimate the average annual increase in Stage upgrades attributable to the LEZ compliance pathway.
4. **Enforcement-driven turnover**: Estimate the average annual increase in Stage upgrades attributable to LEZ enforcement actions.
5. **Stage distribution forecast**: Project the percentage of fleet in each Stage annually from 2026 to 2030 under two scenarios.
6. **Emissions estimation**: Estimate annual emissions (normalised to emissions per MWh work delivered) per group.
7. **Future work: Damage Costs**: Estimate damage costs avoided.
8. **Future Work: Refined COVID Exemption Modelling**: Implement state-adjustment methodology.

### 1.3 Scope

- **Analysis period**: 1.1.2016–31.12.2024.
- **Forecast horizon**: 2030.
- **Equipment in scope**: 37–560 kW variable-speed and constant-speed machinery.
- **Equipment excluded**: Hybrid, electric, flywheel, hydrogen (treated descriptively).
- **Cold-engaged fleet**: Machines audited without prior registration, used to estimate $\lambda_{CF}$.

## 2. Methodology

### 2.1 Overview: Dual Resolution Architecture

To prevent conflating intermediate non-compliant upgrades with LEZ-mandated compliance while preserving state space for emissions calculations, the model utilizes a **Dual Resolution Architecture** (Courtois, 1977; Wagner et al., 2002):

- **Stream A (Binary Compliance Model):** Collapses states into `Compliant` vs. `Non-Compliant` based on Table 1. This stream is strictly used to estimate the overarching hazard rates ($\lambda_{CF}$, $\lambda_{Total}$, $\lambda_{Proactive}$) answering Objectives 1–4.
- **Stream B (Granular Group-Specific State Model):** Maintains the relevant Stage state space using empirical transition matrices tailored to each group's viable pathways. This stream tracks absolute machine counts ($N_{g,s,t}$) required for accurate forecast distribution and emissions estimation (Objectives 5–6).

### 2.2 Equipment groups

| **Group**          | **Description**                                              | **Derivation from raw data**                             |
| ------------------ | ------------------------------------------------------------ | -------------------------------------------------------- |
| **Constant Speed** | Generators/constant-speed equipment. Direct IIIA-to-V pathway. | `Engine.Type.clean == "Constant"` (any Zone)             |
| **CAZ+**           | Variable-speed machinery in CAZ+. Merges with Rest of London on 1.1.2025. | `Engine.Type.clean == "Variable"` AND `Zone ∈ {CAZ, OA}` |
| **Rest of London** | Variable-speed machinery outside CAZ+.                       | `Engine.Type.clean == "Variable"` AND `Zone == GL`       |

Zone values `P24` and `BCP` are excluded.

### 2.3 Exact Phase Boundaries

Model phases utilize exact policy interval dates to prevent temporal aggregation bias (Petersen, 1991).

| **Model phase** | **Period (Exact Dates)** | **Rationale & Adjustments**                                  |
| --------------- | ------------------------ | ------------------------------------------------------------ |
| A1              | 1.1.2016 – 31.12.2018    | Pre-Stage V market availability.                             |
| A2              | 1.1.2019 – 31.8.2020     | Stage V equipment newly available.                           |
| B               | 1.9.2020 – 31.12.2024    | Tighter LEZ requirements. COVID Exemptions (1.9.2020–31.3.2021) filtered out. Phase B is further subdivided into 3 equal periods (segments) of ~527 days for variable speed equipment to stabilize variance. |
| Forecast (C)    | 1.1.2025 onwards         | CAZ+ and Rest of London combined.                            |

### 2.4 Transition Rate Estimation (Stream A: Binary)

1. **Natural Rate (**$\lambda_{CF}$**):** Estimated via Weighted Least Squares (WLS) on the shift in the proportion of `Compliant` machinery within the Cold-Engaged fleet.
   - **State Space Weighting:** Probability mass is distributed equally only across stages physically present within a specific group's active set, strictly avoiding impossible transitions (Allison, 1982).
   - **Variable Speed (CAZ+ / Rest of London):** Calculations utilize the 3-segment equal temporal division within Phase B to stabilize variance in sparse samples. Groups are NOT pooled. A1/A2 utilize pooled approximations due to sample sparsity.
   - **Constant Speed:** Due to signal exhaustion by Phase B and an absent Phase A1 Stage IIIB/IV pathway, $\lambda_{CF}$ is estimated by pooling data from 2017–2023. Year 2024 is excluded from the estimation window to omit anticipatory regulatory compliance bias prior to the 2025 mandate.
2. **Enforcement Rate (**$\bar{e}$**):** Direct count of observed audit upgrades from `Non-Compliant` to `Compliant` divided by the initial `Non-Compliant` audited fleet.
3. **Proactive Rate (**$\lambda_{Proactive}$**):** Uniform overall compliance hazard ($\lambda_{Total}$) estimated via WLS on Warm-Engaged counts, minus $\lambda_{CF}$ and $\bar{e}$.

**Variance Estimation:** Asymptotic standard errors derived from the WLS covariance matrix (Greene, 2018).

### 2.5 Matrix Construction & Forecasting (Stream B: Granular)

The composite right-stochastic matrix ($\mathbf{P}_{Total}$) is constructed empirically for each phase to preserve exact Stage counts. Matrices are dimensioned according to each group's active state space rather than a uniform 6-state model, preventing probability mass from leaking into impossible states (e.g., Constant Speed bypasses Stages IIIB/IV; CAZ+ has a compliance floor of IV). Forecasting (2025–2030) utilizes $C^{t+1} = C^t \cdot \mathbf{P}_{forecast}$.

- **Scenario A (Status Quo):** $\mathbf{P}_{forecast} = \mathbf{P}_{Total}^{(B)}$.
- **Scenario B (Strict Enforcement):** Upgrades to non-compliant stages are zeroed. Permitted compliant target stages are hardcoded via a Boolean mask $\mathbf{M}$ applied to the transition matrix (Kemeny & Snell, 1960). Excised mass redistributes equally across valid states. Target stages:
  - **Constant Speed:** Stage V, ZE.
  - **Merged Variable Speed:** Stage IV (Rest of London boundaries only, until 2030), Stage V, ZE.

### 2.6 Emissions estimation

Annual emissions per group estimated as:

$$E_{g,t} = \sum_{s} N_{g,s,t} \times \overline{kW}_{g,s} \times \overline{H}_{g,s} \times EF_s$$

$N_{g,s,t}$ extracted natively from Stream B Count-First arrays.

**Hard Defaults:**

- **Operating Hours (**$\overline{H}_{g,s}$**):** 2,000 hours/annum.
- **Emission Factors (**$EF_s$**):** EMEP/EEA Tier 3 methodology standard factors (Ntziachristos & Samaras, 2019).
- **Unregistered Fleet:** Total estimates abandoned; emissions scope strictly audited population.

## 3. Delivery Plan

- **M1: Data ready** (Completed)
- **M2: Exploratory analysis complete** (Completed)
- **M3: Model estimated** * **M4: Forecast and emissions complete**
- **M5: Final outputs** (Due 30 March, 17:00)

## Appendix A & B: Methodological Limitations & Future Work

1. **Ecological Inference Fallacy:** Estimating transition probabilities from aggregate count snapshots assumes macro-level shifts accurately represent individual transition hazards (Robinson, 1950).
2. **Entry/Exit Bias:** The model tracks aggregate volumes, absorbing fleet entry and exit. Differential Stage composition between entering/exiting machines violates the Markov property of time-homogeneity.
3. **Time-Heterogeneous Hazard Rates:** Inconsistencies between Phase B segment pairs suggest the natural upgrade rate accelerated over time due to Stage V market availability. Assuming a single constant $\lambda_{CF}$ represents a model simplification.
4. **State-Space Conflation in Early Phases:** Pooling groups for Phase A1/A2 variable speed $\lambda_{CF}$ estimation conflates disparate compliance state spaces to overcome statistical sparsity (Allison, 1982).