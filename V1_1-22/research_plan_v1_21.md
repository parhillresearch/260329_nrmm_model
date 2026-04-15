# NRMM LEZ Trend Analysis: Short-Term Research Plan

**Version**: 1.21 | **Date**: 31 March 2026

## 1. Problem and Objectives

### 1.1 Problem statement

The London Non-Road Mobile Machinery (NRMM) Low Emission Zone (LEZ) requires machinery (37–560 kW) to meet progressively tighter EU emissions Stage requirements. This project evaluates the LEZ's effect on fleet Stage composition (2016–2025) and projects future emissions to 2030.

### 1.2 Objectives

1. **Compliance Routing Assessment**: Quantify overall compliance, distinguishing between administrative faults and physical emissions failures.
2. **Counterfactual Turnover (**$\lambda_{CF}$**)**: Estimate natural replacement rates from cold-engaged audit data.
3. **LEZ Policy Effects (**$\lambda_{Proactive}$**)**: Estimate proactive compliance rates attributable to the LEZ, derived from warm-engaged data.
4. **LEZ Enforcement Effects (**$\bar{e}$**)**: Estimate rates of direct physical equipment replacement/removal caused by enforcement.
5. **Forecast**: Project stage distributions annually from 2026 to 2030.
6. **Emissions Estimation**: Calculate annual emissions per group.

## 2. Methodology

### 2.1 Dual Resolution Architecture

A bifurcated architecture prevents conflating intermediate non-compliant stage replacements with administrative LEZ-mandated compliance (Courtois, 1977, *Decomposability*):

- **Stream A (Binary Compliance Model)**: Collapses states into `Compliant` vs. `Non-Compliant`. Estimates overarching hazard rates ($\lambda_{CF}$, $\lambda_{Total}$, $\lambda_{Proactive}$).
- **Stream B (Granular Group-Specific State Model)**: Maintains empirical Stage state space transition matrices for absolute counts ($N_{g,s,t}$) and emissions forecasting.

### 2.2 Compliance Outcomes and Enforcement Attribution

Audit outcomes are parsed into discrete routes to distinguish administrative faults from physical emissions non-compliance (Hand, 2004, *Measurement Theory and Practice*).

##### Table: Rules for compliance outcomes

| **Row** | **Site Reg?** | **NRMM in scope** | **Mach Reg?** | **Emissions OK?** | **Enforcement requested** | **Site mgmt action** | **Outcome**       | **Emissions reduced by audit?** |
| ------- | ------------- | ----------------- | ------------- | ----------------- | ------------------------- | -------------------- | ----------------- | ------------------------------- |
| 1       | ✓             | ✓                 | ✓             | ✓                 | None                      | None                 | Self-compliant    | No                              |
| 2       | ✓/✗           | ✓                 | ✗             | ✓                 | Register site/machine     | Registered           | Driven compliant  | No                              |
| 3       | ✓/✗           | ✓                 | ✗             | ✓                 | Register site/machine     | Not registered       | Non-compliant (R) | No                              |
| 4       | ✓/✗           | ✓                 | ✓/✗           | ✗                 | Remove or replace         | Removed/replaced     | Driven compliant  | Yes                             |
| 5       | ✓/✗           | ✓                 | ✓/✗           | ✗                 | Remove or replace         | Not actioned         | Non-compliant     | No                              |
| 6       | ✓/✗           | ✗                 | --            | --                | None                      | --                   | No in-scope plant | No                              |

**Attribution Logic:**

- **Natural/Proactive Turnover**: Machinery in Rows 1, 2, and 3 represents fleet physically meeting standards. Utilized to estimate $\lambda_{CF}$ and $\lambda_{Total}$.
- **Direct Enforcement Effect (**$\bar{e}$**)**: Restricted strictly to Row 4 events. Audits resulting in physical equipment replacement or complete site removal are mathematically modeled as direct enforcement-driven transitions. Removals map to a zero-emission (ZE) state.

### 2.3 Transition Rate Estimation Constraints

Weighted Least Squares (WLS) is applied to state proportions ($p_{s,t}$). The following mathematical constraints are enforced to prevent estimator bias from sparse data or impossible transitions (Allison, 1982, *Sociological Methodology*):

1. **Group-Specific State Spaces (`max_stage`)**:
   - **Constant Speed**: `max_stage = 3`.
   - **CAZ+**: `max_stage = 5`.
   - **Rest of London**: `max_stage = 6`.
2. **Estimation Windowing & Temporal Splitting**:
   - **Constant Speed**: Stage II signals are exhausted by 2021 (4% remaining). $\lambda_{CF}$ is estimated by pooling data from 2017–2023.
   - **Variable Speed (Phase B)**: Due to high annual volatility (e.g., CAZ+ sample sizes of 37–83), Phase B is split into 3 equal segments (~527 days) to stabilize variance (Petersen, 1991, *Sociological Methods & Research*). Groups are not pooled.
   - **Variable Speed (Phases A1 & A2)**: Groups are pooled due to severe cold-fleet sparsity.

### 2.4 Matrix Construction & Forecasting

The composite matrix ($\mathbf{P}_{Total} = \mathbf{P}_{Natural} + \mathbf{P}_{Enforcement} + \mathbf{P}_{Proactive}$) is constructed empirically based strictly on active state dimensions per group. Forecasting utilizes $C^{t+1} = C^t \cdot \mathbf{P}_{forecast}$.

- **Scenario B (Strict Enforcement)**: Replacements to non-compliant stages are zeroed. Permitted compliant target stages are hardcoded via a Boolean mask $\mathbf{M}$. Excised mass redistributes equally across valid states.

### 2.5 Emissions Estimation

Annual emissions per group estimated as:

$E_{g,t} = \sum_{s} N_{g,s,t} \times \overline{kW}_{g,s} \times \overline{H}_{g,s} \times EF_s$![img]()

- **Operating Hours**: 2,000 hours/annum.
- **Emission Factors**: EMEP/EEA Tier 3 methodology standard factors (Ntziachristos & Samaras, 2019).

## Appendix: Methodological Limitations

1. **Ecological Inference Fallacy**: Estimating transition probabilities from aggregate count snapshots assumes macro-level shifts accurately represent individual transition hazards (Robinson, 1950, *American Sociological Review*).
2. **Entry/Exit Bias**: The model absorbs fleet entry and exit. Differential Stage composition between entering/exiting machines violates Markov time-homogeneity.