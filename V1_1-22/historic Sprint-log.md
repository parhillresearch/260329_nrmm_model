# Sprint log

Each entry: analytical question → result (2 sentences) → objective impact.

------

## Completed sprints

- [x] **Sprint 1** | Step 1–2: Ingestion, filtering, segmentation
  - Applied 6 filter rules to 16,251 raw records; 10,749 analysis-ready records retained (Cold=1,815, Warm=8,934). Engine standardisation mapped 1,316 generator-family records to Constant Speed.
  - *Objective impact*: Established clean analysis population; group derivation rules confirmed viable.
- [x] **Sprint 2** | Step 3: Compliance routing and Stream A/B aggregation
  - Mapped all records to 6 compliance outcome routes (Table: rules for compliance outcomes); Stream A binary compliance and Stream B 6-state count matrices produced per group-year. Enforcement attribution restricted to Row 4 (physical replacement/removal) only.
  - *Objective impact*: Confirmed dual-resolution architecture viable; administrative and physical non-compliance clearly separable.
- [x] **Sprint 3** (260329_step3_lambda_diagnostics.R) | Is CAZ+ annual GLS reliable for λ_CF Phase B?
  - Annual Phase B CAZ+ cold counts (69, 37, 83, 40) produce wildly inconsistent year-pair estimates (0.864, −2.26, 0.914); root cause is sampling noise on small counts, not systematic bias. Leave-one-out confirms no single year-pair drives the instability.
  - *Objective impact*: Annual GLS rejected for CAZ+ Phase B; temporal 3-segment approach mandated.
- [x] **Sprint 4** (260329_step3b_lambda_temporal.R) | Does 3-segment temporal split stabilise Phase B λ_CF?
  - Segment counts for CAZ+ become 86, 72, 83 — substantially more balanced; combined estimate falls from 0.638 to 0.363 (SE=0.052, CI [0.261, 0.464]). Segment pair inconsistency across all groups confirms Phase B rate is not time-homogeneous (limitation flagged).
  - *Objective impact*: Temporal 3-segment estimates adopted for all groups; Phase B non-homogeneity added to limitations.
- [x] **Sprint 5** (260329_step3c_cs_lambda.R) | What is the correct λ_CF for Constant_Speed?
  - Setting max_stage=3 (excluding absent stages IIIB/IV) raises estimate from 0.158–0.176 to 0.358; 2024 data excluded as anticipatory regulatory compliance (Stage V 0%→61% spike). Phase B window uninformative (Stage II exhausted by 2021 at 4%).
  - *Objective impact*: Constant_Speed λ_CF locked at 0.358; max_stage per group locked; 2024 CS cold data designated Phase C initialisation state only.
- [x] **Sprint 6** (260331_step4_revised.R) | v1.18 revisions: ē definition, λ_Policy estimation window, λ_Proactive formula
  - ē revised to Stage-threshold all-records definition (yields 10–20% exposure vs 0.4% from Enforcement_Upgrade flag); λ_Policy estimated from warm self-compliant subset only; λ_Proactive = λ_Policy − λ_CF with ē not subtracted. CS Phase B ē ≈ 1 confirmed correct and expected.
  - *Objective impact*: All three rate parameters revised; research_plan updated to v1.18 then v1.21; Step 4 key objects (lambda_cf_streamA, lambda_policy_streamA, e_bar_rows, lambda_proactive_streamA, kw_by_group_stage) authoritative.

------

## Backlog

- [ ] **Sprint 7** | Step 5: Matrix assembly and normalisation
  - Construct P_Total per group; enforce max_stage active dimensions; apply floor-and-rescale if λ_Proactive < 0; verify rows sum to 1.
- [ ] **Sprint 8** | Step 6A: Forecast — Scenario A (status quo / proactive only)
  - Project Stage distributions 2026–2030 using P_forecast from λ_Policy. Produce annual count tables per group.
- [ ] **Sprint 9** | Step 6B: Forecast — Scenario B (with enforcement)
  - Add ē to non-compliant transitions; apply Boolean mask M; redistribute excised mass across valid compliant states. Compare trajectories A vs B.
- [ ] **Sprint 10** | Step 6C: Group merge on 1.1.2025
  - Combine CAZ+ and Rest_of_London into Variable Speed vector for Phase C. Verify state space alignment before matrix multiplication.
- [ ] **Sprint 11** | Step 7: Emissions estimation
  - Apply E_{g,t} = Σ N_{g,s,t} × kW_{g,s} × 2000 × EF_s to forecast counts. Produce annual emissions series per group and total, both scenarios.
- [ ] **Sprint 12** | Final outputs and sensitivity summary
  - Collate all outputs; document limitations; produce summary tables and plots for delivery.