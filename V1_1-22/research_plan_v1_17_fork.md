1. # NRMM LEZ Trend Analysis: Short-Term Research Plan

   **Version**: 1.20 (Empirical Adjustments Integration) | **Date**: 31 March 2026

   ## 1. Problem and Objectives

   ### 1.1 Problem statement

   The London Non-Road Mobile Machinery (NRMM) Low Emission Zone (LEZ) requires machinery (37–560 kW) to meet progressively tighter EU emissions Stage requirements (Table 1). This project evaluates the LEZ's effect on fleet Stage composition (2016–2025) and projects future emissions to 2030.

   ##### Table 1. Emissions Stage Compliance Requirements

   | **Policy phase**   | **1: 1.9.2015** | **2: 1.9.2020 (+6M)** | **3: 1.1.2025** | **4: 1.1.2030** | **5: 1.1.2040** |
   | ------------------ | --------------- | --------------------- | --------------- | --------------- | --------------- |
   | **Constant speed** | IIIA            | V                     | V               | V               | ZE              |
   | **CAZ+**           | IIIB            | IV                    | V               | V               | ZE              |
   | **Rest of London** | IIIA            | IIIB                  | IV              | V               | ZE              |

   ### 1.2 Objectives

   1. **Compliance Routing**: Quantify administrative versus physical compliance outcomes.
   2. **Counterfactual Turnover (**$\lambda_{CF}$**)**: Estimate natural replacement rates from cold-engaged data.
   3. **LEZ Policy Effects (**$\lambda_{Proactive}$**)**: Estimate indirect compliance rates from warm-engaged data.
   4. **LEZ Enforcement (**$\bar{e}$**)**: Isolate physical emission reductions from direct audits.
   5. **Forecast**: Project fleet composition (2026–2030).
   6. **Emissions**: Estimate normalized annual emissions.

   ## 2. Methodology

   ### 2.1 Dual Resolution Architecture

   To prevent conflating administrative non-compliance with physical emissions reduction, the model uses a bifurcated state space (Courtois, 1977, *Decomposability*):

   - **Stream A (Binary)**: Evaluates overarching compliance hazards based on Table 1.
   - **Stream B (Granular)**: Tracks absolute machine counts ($N_{g,s,t}$) across empirical transition matrices for emissions forecasting.

   ### 2.2 Compliance Outcomes & Enforcement

   Records are mapped to compliance routes to distinguish paperwork faults from physical emissions non-compliance (Hand, 2004, *Measurement Theory and Practice*).

   - **Enforcement Attribution**: Direct enforcement ($\bar{e}$) is strictly restricted to audits resulting in physical equipment replacement or complete site removal. Administrative registrations are excluded from emissions reduction models.

   ### 2.3 Transition Rate Estimation

   WLS regression is applied to state proportions ($p_{s,t}$). Sensitivity testing dictates specific empirical constraints to resolve data sparsity and signal exhaustion:

   1. **State-Space Specification (`max_stage`)**: Applying uniform matrix dimensions dilutes probability mass into physically impossible states, biasing the estimator (Allison, 1982, *Sociological Methodology*). Group-specific active states are enforced:
      - **Constant Speed**: `max_stage = 3`.
      - **CAZ+**: `max_stage = 5`.
      - **Rest of London**: `max_stage = 6`.
   2. **Temporal Windowing**:
      - **Constant Speed**: Stage II signals exhausted by 2021 (4% remainder). Phase B is statistically uninformative. $\lambda_{CF}$ utilizes a pooled 2017–2023 window ($\lambda_{CF} = 0.358$).
      - **Variable Speed (Phase B)**: High annual volatility in CAZ+ (n=37 to 83) causes extreme estimate swings. Phase B utilizes a 3-segment temporal division to stabilize variance (Petersen, 1991, *Sociological Methods & Research*), yielding $\lambda_{CF} = 0.363$ for CAZ+ and $0.219$ for Rest of London.
      - **Variable Speed (A1/A2)**: Extreme cold-fleet sparsity strictly prohibits unpooled estimation. Groups are pooled as a mathematical approximation.

   ### 2.4 Forecasting & Emissions

   Forecasts ($C^{t+1} = C^t \cdot \mathbf{P}_{forecast}$) project to 2030. Emissions utilize standard EMEP/EEA Tier 3 methodology standard factors applied to absolute matrix counts (Ntziachristos & Samaras, 2019).

   ## 3. Appendix: Methodological Limitations

   1. **Ecological Inference**: Aggregate counts approximate individual transition hazards (Robinson, 1950, *American Sociological Review*).
   2. **Time-Heterogeneous Hazards**: Accelerating upgrade rates within Phase B due to Stage V market maturation violate strict Markov time-homogeneity.