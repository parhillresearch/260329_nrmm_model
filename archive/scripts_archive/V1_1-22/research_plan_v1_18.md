# NRMM LEZ Trend Analysis: Short-Term Research Plan

**Version**: 1.18 (ē Definition: Stage-Threshold All Records) | **Date**: 31 March 2026 | **First estimates required**: 30 March 2026, 17:00

## 1. Problem and Objectives

### 1.1 Problem statement

The London Non-Road Mobile Machinery (NRMM) Low Emission Zone (LEZ) has been in force since September 2015, requiring machinery in the 37–560 kW range[^1] to meet progressively tighter EU emissions Stage requirements (Table 1). Compliance is enforced through on-site audits of machinery engine plates. This project evaluates the LEZ's effect on fleet Stage composition over the programme period 2016–2025 and projects fleet composition and associated emissions to 2030.
[^1]: kW refers to mechanical power per engine plate, not electrical output or thermal input. ↩

##### Table 1. Emissions Stage Compliance Requirements

| **Policy phase**   | **1: 1.9.2015**[^2] | **2: 1.9.2020 (+6M)**[^3] | **3: 1.1.2025** | **4: 1.1.2030** | **5: 1.1.2040** |
| ------------------ | ------------------- | ------------------------- | --------------- | --------------- | --------------- |
| **Constant speed** | IIIA                | V                         | V               | V               | ZE              |
| **CAZ+**           | IIIB                | IV                        | V               | V               | ZE              |
| **Rest of London** | IIIA                | IIIB                      | IV              | V               | ZE              |

[^2]: Policy phase 1 spans 1.9.2015 onwards. 2015 excluded due to lack of audit data.
[^3]: Six-month COVID-19 compliance extension granted.

### 1.2 Objectives

For each of the three equipment groups and for each model phase:

1. **Counterfactual Turnover**: Determine compliance rates and stage replacement rates that would have occurred without LEZ intervention, estimated from cold-engaged audit data.
2. **LEZ Policy Effects**: Determine compliance rates and stage replacement rates attributable to the LEZ compliance pathway, estimated from warm-engaged audit data.
3. **LEZ Enforcement Effects**: Determine compliance rates and stage replacement rates attributable to direct LEZ enforcement actions.
4. **Forecast**: Project both compliance percentages and granular stage distributions annually from 2026 to 2030 under two scenarios.
5. **Emissions estimation**: Estimate annual emissions (normalised to emissions per MWh work delivered) per group.
6. **Future work: Damage Costs**: Estimate damage costs avoided.
7. **Future Work: Refined COVID Exemption Modelling**: Implement state-adjustment methodology.

### 1.3 Scope

- **Analysis period**: 1.1.2016–31.12.2024.
- **Forecast horizon**: 2030.
- **Equipment in scope**: 37–560 kW variable-speed and constant-speed machinery.
- **Equipment excluded**: Hybrid, electric, flywheel, hydrogen (treated descriptively).
- **Cold-engaged fleet**: Machines audited without prior registration, used to estimate counterfactual baselines.

## 2. Methodology

### 2.1 Overview: Dual Resolution Architecture

To prevent conflating intermediate non-compliant stage replacements with LEZ-mandated compliance while preserving state space for emissions calculations, the model utilizes a **Dual Resolution Architecture** (Courtois, 1977; Wagner et al., 2002):

- **Stream A (Binary Compliance Model):** Collapses states into `Compliant` vs. `Non-Compliant` based on Table 1. This stream estimates the overarching hazard rates ($\lambda_{CF}$, $\lambda_{Total}$, $\lambda_{Proactive}$) answering the compliance rate requirements of Objectives 1–3.
- **Stream B (Granular Group-Specific State Model):** Maintains the relevant Stage state space using empirical transition matrices tailored to each group's viable pathways. This stream tracks absolute machine counts ($N_{g,s,t}$) and granular stage replacement rates required for Objectives 1-3, accurate forecast distributions (Objective 4), and emissions estimation (Objective 5).

### 2.2 Equipment groups

| **Group**          | **Description**                                              | **Derivation from raw data**                             |
| ------------------ | ------------------------------------------------------------ | -------------------------------------------------------- |
| **Constant Speed** | Generators/constant-speed equipment. Direct IIIA-to-V pathway. | `Engine.Type.clean == "Constant"` (any Zone)             |
| **CAZ+**           | Variable-speed machinery in CAZ+. Merges with Rest of London on 1.1.2025. | `Engine.Type.clean == "Variable"` AND `Zone ∈ {CAZ, OA}` |
| **Rest of London** | Variable-speed machinery outside CAZ+.                       | `Engine.Type.clean == "Variable"` AND `Zone == GL`       |

Zone values `P24` and `BCP` are excluded.

### 2.3 Model Phases, exact dates

Model phases utilize exact policy interval dates to prevent temporal aggregation bias (Petersen, 1991).

| **Model phase** | **Period (Exact Dates)** | **Rationale & Adjustments**                                  |
| --------------- | ------------------------ | ------------------------------------------------------------ |
| A1              | 1.1.2016 – 31.12.2018    | Pre-Stage V market availability.                             |
| A2              | 1.1.2019 – 31.8.2020     | Stage V equipment newly available.                           |
| B               | 1.9.2020 – 31.12.2024    | Tighter LEZ requirements. COVID Exemptions (1.9.2020–31.3.2021) filtered out. Phase B is further subdivided into 3 equal periods (segments) of ~527 days for variable speed equipment to stabilize variance. |
| Forecast (C)    | 1.1.2025 onwards         | CAZ+ and Rest of London combined.                            |

### 2.4 Transition Rate Estimation (Stream A & B)

1. **Natural Rate (**$\lambda_{CF}$**):** Estimated via Weighted Least Squares (WLS) on the shift in the proportion of machinery within the Cold-Engaged fleet. Calculated separately for binary compliance (Stream A) and stage replacements (Stream B).
   - **State Space Weighting:** Probability mass is distributed equally only across stages physically present within a specific group's active set, strictly avoiding impossible transitions (Allison, 1982).
   - **Variable Speed (CAZ+ / Rest of London):** Calculations utilize the 3-segment equal temporal division within Phase B to stabilize variance in sparse samples. Groups are NOT pooled. A1/A2 utilize pooled approximations due to sample sparsity.
   - **Constant Speed:** Due to signal exhaustion by Phase B and an absent Phase A1 Stage IIIB/IV pathway, $\lambda_{CF}$ is estimated by pooling data from 2017–2023. Year 2024 is excluded from the estimation window to omit anticipatory regulatory compliance bias prior to the 2025 mandate.
2. **Enforcement Rate (**$\bar{e}$**):** Proportion of ALL audited records (cold-engaged and warm-engaged combined) where `Initial.Stage < compliance threshold` for that group × phase, divided by total records. This is an average annual proportion (not a cumulative count) and must **not** be divided by phase duration. The Stage-threshold filter is authoritative: it isolates the "emissions not OK" pathway (removal/replacement enforcement), which is the only pathway that produces a Stage transition and reduces emissions. Registration-only non-compliance — where Stage is acceptable but site or machine is not registered — does not produce a Stage change and must not be counted in ē. Cold-engaged records represent sites at their first audit (unregistered site), so their non-compliance is largely structural; however, those cold machines whose Stage is genuinely below threshold are correctly included in ē. CS Phase B ($\bar{e}$ high) is expected given the abrupt Stage V mandate.
3. **Policy Rate (**$\lambda_{Policy}$**)** and **Proactive Rate (**$\lambda_{Proactive}$**):** The voluntary policy compliance rate is estimated via WLS applied **only to warm-engaged records where `Initial.Machinery.Compliance == "compliant"`** (the self-compliant subset). This subset isolates operators who maintained compliance without enforcement pressure and represents the pure proactive LEZ policy response. WLS on all warm records would confound proactive and enforcement-driven compliance trajectories. $\lambda_{Proactive} = \lambda_{Policy} - \lambda_{CF}$, floored at zero. $\bar{e}$ is **not** subtracted from $\lambda_{Policy}$ because non-compliant machines are excluded from the estimation window by construction. **Bias note:** $\lambda_{CF}$ overestimates the true market counterfactual due to second-hand market leakage (LEZ demand pressure elevates stage composition of second-hand stock entering cold sites). Consequently $\lambda_{Proactive}$ is a conservative lower bound on the true proactive LEZ effect.

**Variance Estimation:** Asymptotic standard errors derived from the WLS covariance matrix (Greene, 2018).

### 2.5 Matrix Construction & Forecasting (Stream B: Granular)

The composite right-stochastic matrix ($\mathbf{P}_{Total}$) is constructed empirically for each phase to preserve exact Stage counts. Matrices are dimensioned according to each group's active state space rather than a uniform 6-state model, preventing probability mass from leaking into impossible states (e.g., Constant Speed bypasses Stages IIIB/IV; CAZ+ has a compliance floor of IV). Forecasting (2025–2030) utilizes $C^{t+1} = C^t \cdot \mathbf{P}_{forecast}$.

- **Scenario A (Status Quo / Proactive Only):** $\mathbf{P}_{forecast}$ constructed from $\lambda_{Policy}$ (compliant-warm WLS). Machines in non-compliant stages transition upward at $\lambda_{Policy}$; machines in compliant stages transition at $\lambda_{Policy}$ toward higher compliant stages. No enforcement augmentation.
- **Scenario B (With Enforcement):** Machines in non-compliant stages receive an additional enforcement-driven transition rate $\bar{e}$ (from §2.4.2) on top of $\lambda_{Policy}$. The combined upward transition rate for non-compliant stages is $\lambda_{Policy} + \bar{e}$, capped such that the row remains right-stochastic. Transitions into non-compliant stages from compliant stages are zeroed (Boolean mask $\mathbf{M}$, Kemeny & Snell, 1960). Excised mass redistributes equally across valid compliant states. This produces a materially faster compliance trajectory than Scenario A, particularly for CS (high $\bar{e}$). Target compliant stages:
  - **Constant Speed:** Stage V, ZE.
  - **Merged Variable Speed:** Stage IV (until 2030), Stage V, ZE.

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
- **M3: Model estimated** (Phase 4 complete — see `260330_step4_output.md`; revised in v1.18, script `260331_step4_revised.R`). Key objects: `lambda_cf_streamA`, `lambda_policy_streamA`, `e_bar_rows`, `lambda_proactive_streamA`, `kw_by_group_stage`. **v1.18 revisions:** (1) ē computed from `Initial.Stage < threshold` across all records (cold + warm) — Stage-threshold definition isolates emissions enforcement only; (2) λ_Policy estimated from warm records where `Initial.Machinery.Compliance == "compliant"` (self-compliant subset); (3) λ_Proactive = λ_Policy − λ_CF (ē not subtracted). Granular Stream B λ_CF (CS: 0.358, CAZ+: 0.363, RoL: 0.219) remain authoritative.
- **M4: Forecast and emissions complete**
- **M5: Final outputs** (Due 30 March, 17:00)

## Appendix A & B: Methodological Limitations & Future Work

1. **Ecological Inference Fallacy:** Estimating transition probabilities from aggregate count snapshots assumes macro-level shifts accurately represent individual transition hazards (Robinson, 1950).
2. **Entry/Exit Bias:** The model tracks aggregate volumes, absorbing fleet entry and exit. Differential Stage composition between entering/exiting machines violates the Markov property of time-homogeneity.
3. **Time-Heterogeneous Hazard Rates:** Inconsistencies between Phase B segment pairs suggest the natural replacement rate accelerated over time due to Stage V market availability. Assuming a single constant $\lambda_{CF}$ represents a model simplification.
4. **State-Space Conflation in Early Phases:** Pooling groups for Phase A1/A2 variable speed $\lambda_{CF}$ estimation conflates disparate compliance state spaces to overcome statistical sparsity (Allison, 1982).