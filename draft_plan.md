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
3. Assign every retained record to a machine group (schema.md Table 1) and model phase (schema.md Table 7); store as tibble `audits`. P24 Variable Speed records → group `Variable_Speed`; P24 Constant Speed records → group `Constant_Speed`. Records with date >= 1.1.2025 → Phase C.
4. Report record counts by group and phase; flag anomalies for user review before proceeding. Report P24 record counts separately, categorised as Phase C; flag earliest and latest P24 audit date to confirm initialisation data availability.

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
4. Report all parameter estimates with SE and CI; cross-check against locked values and expected ranges; flag anomalies for user review

---

## Step 4: Transition matrix construction

1. Construct group-specific right-stochastic transition matrices P_Natural, P_Enforcement, P_Proactive with dimensions matching each group's max_stage
2. Combine into composite P_Total; enforce row-sum constraint after every operation; apply floor-and-rescale where lambda_Proactive < 0
3. Validate matrices against observed Stage distributions before use in forecasting

---

## Step 5: Forecasting and emissions

1. Project Stage distributions annually 2025-2030 under two scenarios: Scenario A (proactive only, no enforcement augmentation) and Scenario B (enforcement-augmented, Boolean mask zeroing non-compliant transitions). Initialise Phase C from the Stage distribution of the latest available P24 cold-engaged records; forecast horizon runs from that date to 31.12.2030.
2. For Phase C initialisation, pool Constant_Speed and Variable_Speed P24 records into a combined dataset; extract group-specific Stage distributions as the Phase C starting state. No merge operation required; group assignment at Step 1 handles the CAZ+/Rest of London merge.
3. Estimate annual emissions per group as E = Sum(N x kW x 2000 x EF_s) using EMEP/EEA Tier 3 factors (schema.md TBC section - must be resolved before this step)
4. Produce summary tables and plots of Stage distributions and emissions trajectories for both scenarios; document limitations (schema.md "Known limitations")



## Future work

**Equal-count phase binning (considered, deferred):** Replace time-interval Phase B sub-segments with equal-count bins to stabilise stage-proportion SE across segments. Deferred because: 
1. unequal delta-t complicates WLS lambda estimation;
2. audit clustering means bin boundaries are non-reproducible and policy-uninterpretable; 
3. cross-group sparsity in early phases is the binding constraint, not within-Phase-B variance. 
Revisit if the model moves to continuous-time hazard estimation.
