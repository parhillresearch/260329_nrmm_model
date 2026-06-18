| object | file | class | dim | step | description |
|--------|------|-------|-----|------|-------------|
| audits | intermediate/audits.rds | tbl_df | 12363 x 32 | step1 | Clean filtered audit records 2016+: in-scope zones (CAZ/OA/GL/P24), machinery only, engine-type classified, stages encoded, COVID exempt removed, group + phase assigned (A1/A2/B/C) |
| audits | intermediate/audits.rds | tbl_df | 12363 x 32 | step1 | Clean filtered audit records 2016+: in-scope zones (CAZ/OA/GL/P24), machinery only, engine-type classified, stages encoded, COVID exempt removed, group + phase assigned (A1/A2/B/C) |
| stage_dist | intermediate/stage_dist.rds | tbl_df | 236 x 7 | step2 | Stage counts with pct by group × year × cold_engaged × initial_stage |
| audits_step2 | intermediate/audits_step2.rds | tbl_df | 12363 x 35 | step2 | audits enriched with phase_sub, stage_label, and compliance route (Table 3) |
| sparsity_summary | intermediate/sparsity_summary.rds | list | 5 elements | step2 | Sparsity: cold cell counts, signal exhaustion (% at max_stage), volatility by group × phase_sub |
| stage_dist | intermediate/stage_dist.rds | tbl_df | 236 x 7 | step2 | Stage counts with pct by group × year × cold_engaged × initial_stage (ZE excluded) |
| audits_step2 | intermediate/audits_step2.rds | tbl_df | 12363 x 37 | step2 | audits enriched with phase_sub, phase_display, stage_label, ze_flag, compliance route |
| sparsity_summary | intermediate/sparsity_summary.rds | list | 5 elements | step2 | Sparsity: cold cell counts, signal exhaustion, volatility by group × phase_display |
| stage_dist | intermediate/stage_dist.rds | tbl_df | 236 x 7 | step2 | Stage counts with pct by group × year × cold_engaged × initial_stage (ZE excluded) |
| audits_step2 | intermediate/audits_step2.rds | tbl_df | 12363 x 37 | step2 | audits enriched with phase_sub, phase_display, stage_label, ze_flag, compliance route |
| sparsity_summary | intermediate/sparsity_summary.rds | list | 5 elements | step2 | Sparsity: cold cell counts, signal exhaustion, volatility by group × phase_display |
| stage_dist | intermediate/stage_dist.rds | tbl_df | 236 x 7 | step2 | Stage counts with pct by group × year × cold_engaged × initial_stage (ZE excluded) |
| audits_step2 | intermediate/audits_step2.rds | tbl_df | 12363 x 37 | step2 | audits enriched with phase_sub, phase_display, stage_label, ze_flag, compliance route |
| sparsity_summary | intermediate/sparsity_summary.rds | list | 5 elements | step2 | Sparsity: cold cell counts, signal exhaustion, volatility by group × phase_display |
| stage_dist | intermediate/stage_dist.rds | tbl_df | 236 x 7 | step2 | Stage counts with pct by group × year × cold_engaged × initial_stage (ZE excluded) |
| audits_step2 | intermediate/audits_step2.rds | tbl_df | 12363 x 37 | step2 | audits enriched with phase_sub, phase_display, stage_label, ze_flag, compliance route |
| sparsity_summary | intermediate/sparsity_summary.rds | list | 5 elements | step2 | Sparsity: cold cell counts, signal exhaustion, volatility by group × phase_display |
| stage_dist | intermediate/stage_dist.rds | tbl_df | 236 x 7 | step2 | Stage counts with pct by group x year x cold_engaged x initial_stage (ZE excluded) |
| audits_step2 | intermediate/audits_step2.rds | tbl_df | 12363 x 37 | step2 | audits enriched with phase_sub, phase_display, stage_label, ze_flag, compliance route |
| sparsity_summary | intermediate/sparsity_summary.rds | list | 5 elements | step2 | Sparsity: cold cell counts, signal exhaustion, volatility by group x phase_display |
| stage_dist | intermediate/stage_dist.rds | tbl_df | 236 x 7 | step2 | Stage counts with pct by group x year x cold_engaged x initial_stage (ZE excluded) |
| audits_step2 | intermediate/audits_step2.rds | tbl_df | 12363 x 37 | step2 | audits enriched with phase_sub, phase_display, stage_label, ze_flag, compliance route |
| sparsity_summary | intermediate/sparsity_summary.rds | list | 5 elements | step2 | Sparsity: cold cell counts, signal exhaustion, volatility by group x phase_display |
| stage_dist | intermediate/stage_dist.rds | tbl_df | 236 x 7 | step2 | Stage counts with pct by group x year x cold_engaged x initial_stage (ZE excluded) |
| audits_step2 | intermediate/audits_step2.rds | tbl_df | 12363 x 37 | step2 | audits enriched with phase_sub, phase_display, stage_label, ze_flag, compliance route |
| sparsity_summary | intermediate/sparsity_summary.rds | list | 5 elements | step2 | Sparsity: cold cell counts, signal exhaustion, volatility by group x phase_display |
| lambda_cf_estimates | intermediate/lambda_cf_estimates.rds | list | 3 groups | step3 | lambda_CF WLS estimates: named list per group with primary + sensitivity fits |
| e_bar_estimates | intermediate/e_bar_estimates.rds | tbl_df | 9 x 7 | step3 | e-bar: proportion below compliance threshold, all records, group x phase |
| lambda_pol_estimates | intermediate/lambda_pol_estimates.rds | list | 3 groups | step3 | lambda_Policy WLS estimates: named list per group, warm self-compliant fleet |
| lambda_proactive | intermediate/lambda_proactive.rds | tbl_df | 3 x 8 | step3 | lambda_Proactive: lambda_Policy - lambda_CF, floored at 0, 3 groups x summary cols |
| lambda_cf_estimates | intermediate/lambda_cf_estimates.rds | list | 3 groups | step3 | lambda_CF WLS estimates: named list per group with primary + sensitivity fits |
| e_bar_estimates | intermediate/e_bar_estimates.rds | tbl_df | 9 x 8 | step3 | e-bar: proportion (and pct) below compliance threshold, all records, group x phase |
| lambda_pol_estimates | intermediate/lambda_pol_estimates.rds | list | 3 groups | step3 | lambda_Policy WLS estimates: named list per group, warm self-compliant fleet |
| lambda_proactive | intermediate/lambda_proactive.rds | tbl_df | 3 x 9 | step3 | lambda_Proactive: lambda_Policy - lambda_CF, floored at 0, 3 groups x summary cols |
| lambda_cf | intermediate/lambda_cf.rds | list | 4 groups | 3 | WLS lambda_CF by group; stages capped at MAX_STAGE; cold-engaged only |
| ebar_results | intermediate/ebar_results.rds | tbl_df | 16 × 5 | 3 | e-bar non-compliance exposure rate (%) by group x phase |
| lambda_proactive | intermediate/lambda_proactive.rds | tbl_df | 4 × 6 | 3 | lambda_Policy, lambda_CF, lambda_Proactive by group |
| step3_params | intermediate/step3_params.rds | list | 3 elements | 3 | All Step 3 estimates: lambda_CF, e-bar, lambda_Proactive |
| p_natural | intermediate/p_natural.rds | list | 2 groups [6x6] | 4 | P_Natural: right-stochastic transition matrix based on lambda_CF (counterfactual) |
| p_proactive | intermediate/p_proactive.rds | list | 2 groups [6x6] | 4 | P_Proactive: right-stochastic matrix based on lambda_Proactive (LEZ proactive response) |
| p_enforcement | intermediate/p_enforcement.rds | list | 2 groups [6x6] | 4 | P_Enforcement: right-stochastic matrix based on Phase B Route 4/5 enforcement probability |
| p_total | intermediate/p_total.rds | list | 2 groups [6x6] | 4 | P_Total: combined P_Natural + P_Proactive + P_Enforcement; row-stochastic enforced |
| step4_matrices | intermediate/step4_matrices.rds | list | 8 elements | 4 | Step 4 output bundle: matrices, probabilities, phase init distributions, validation |
| lambda_cf | intermediate/lambda_cf.rds | list | 4 groups | 3 | WLS lambda_CF by group; stages capped at MAX_STAGE; cold-engaged only |
| ebar_results | intermediate/ebar_results.rds | tbl_df | 16 × 5 | 3 | e-bar non-compliance exposure rate (%) by group x phase |
| lambda_proactive | intermediate/lambda_proactive.rds | tbl_df | 4 × 6 | 3 | lambda_Policy, lambda_CF, lambda_Proactive by group |
| enf_success_rate | intermediate/enf_success_rate.rds | tbl_df | 24 × 7 | 3 | Route 4/5 enforcement success rate by group x time period (descriptive) |
| step3_params | intermediate/step3_params.rds | list | 3 elements | 3 | All Step 3 model parameter estimates: lambda_CF, e-bar, lambda_Proactive |
| lambda_cf | intermediate/lambda_cf.rds | list | 4 groups | 3 | WLS lambda_CF by group; stages capped at MAX_STAGE; cold-engaged only |
| ebar_results | intermediate/ebar_results.rds | tbl_df | 16 × 5 | 3 | e-bar non-compliance exposure rate (%) by group x phase |
| lambda_proactive | intermediate/lambda_proactive.rds | tbl_df | 4 × 6 | 3 | lambda_Policy, lambda_CF, lambda_Proactive by group |
| enf_success_rate | intermediate/enf_success_rate.rds | tbl_df | 24 × 7 | 3 | Route 4/5 enforcement success rate by group x time period (descriptive) |
| step3_params | intermediate/step3_params.rds | list | 3 elements | 3 | All Step 3 model parameter estimates: lambda_CF, e-bar, lambda_Proactive |
| p_natural | intermediate/p_natural.rds | list | 2 groups [6x6] | 4 | P_Natural: right-stochastic matrix encoding counterfactual fleet turnover (lambda_CF) |
| p_proactive | intermediate/p_proactive.rds | list | 2 groups [6x6] | 4 | P_Proactive: right-stochastic matrix encoding proactive LEZ replacement (lambda_Proactive) |
| p_total | intermediate/p_total.rds | list | 2 groups [6x6] | 4 | P_Total: P_Natural + P_Proactive combined; row-stochasticity enforced; Scenario A base matrix |
| p_natural | intermediate/p_natural.rds | list | 2 groups [6x6] | 4 | P_Natural: right-stochastic matrix encoding counterfactual fleet turnover (lambda_CF) |
| p_proactive | intermediate/p_proactive.rds | list | 2 groups [6x6] | 4 | P_Proactive: right-stochastic matrix encoding proactive LEZ replacement (lambda_Proactive) |
| p_total | intermediate/p_total.rds | list | 2 groups [6x6] | 4 | P_Total: P_Natural + P_Proactive combined; row-stochasticity enforced; Scenario A base matrix |
| p_natural | intermediate/p_natural.rds | list | 2 groups [6x6] | 4 | P_Natural: right-stochastic matrix encoding counterfactual fleet turnover (lambda_CF) |
| p_proactive | intermediate/p_proactive.rds | list | 2 groups [6x6] | 4 | P_Proactive: right-stochastic matrix encoding proactive LEZ replacement (lambda_Proactive) |
| p_total | intermediate/p_total.rds | list | 2 groups [6x6] | 4 | P_Total: P_Natural + P_Proactive combined; row-stochasticity enforced; Scenario A base matrix |
| step4_matrices | intermediate/step4_matrices.rds | list | 7 elements | 4 | Step 4 output bundle: matrices (P_Natural, P_Proactive, P_Total), probabilities, phase init distributions, validation |
| forecast_scen_a | intermediate/forecast_scen_a.rds | tbl_df | 72 x 5 | 5 | Scenario A: annual Stage distribution forecast 2025-2030 (P_Total, proactive + natural) |
| forecast_scen_b | intermediate/forecast_scen_b.rds | tbl_df | 72 x 5 | 5 | Scenario B: enforcement-augmented Stage distribution forecast 2025-2030 (Boolean mask upper bound) |
| step5_forecasts | intermediate/step5_forecasts.rds | list | 6 elements | 5 | Step 5 bundle: Scenario A/B forecasts, compliance trajectories, pi_0, COMP_THRESH |
| forecast_scen_a | intermediate/forecast_scen_a.rds | tbl_df | 72 x 5 | 5 | Scenario A: annual Stage distribution forecast 2025-2030 (P_Total, proactive + natural) |
| forecast_scen_b | intermediate/forecast_scen_b.rds | tbl_df | 72 x 5 | 5 | Scenario B: enforcement-augmented Stage distribution forecast 2025-2030 (Boolean mask upper bound) |
| step5_forecasts | intermediate/step5_forecasts.rds | list | 6 elements | 5 | Step 5 bundle: Scenario A/B forecasts, compliance trajectories, pi_0, COMP_THRESH |
| audits | intermediate/audits.rds | tbl_df | 12363 x 33 | step1v2 | Clean filtered audits: in-scope zones (CAZ/OA/GL/P24), machinery only, stages encoded, COVID removed; group (4-way primary) + phase + vs_member flag |
| audits_vs | intermediate/audits_vs.rds | tbl_df | 11136 x 33 | step1v2 | All variable-engine records with group = 'Variable_Speed'; enables continuous Variable_Speed trend analysis across A1/A2/B/C |
| exclusions | intermediate/exclusions.rds | tbl_df | 3888 x 5 | step1v2 | Pipeline-excluded records with excl_reason label; for Step 1.5 exclusion analysis |
| audits | intermediate/audits.rds | tbl_df | 22011 x 34 | step1v3 | Expanded audit records: 12363 unique records + 9648 VS duplicate rows. group = active group for filtering; group_primary = 4-way zone assignment; filter(group == group_primary) recovers unique records. vs_member = TRUE for all variable-engine records. |
| exclusions | intermediate/exclusions.rds | tbl_df | 3888 x 5 | step1v3 | Pipeline-excluded records with excl_reason label; for Step 1.5 exclusion analysis |
| audits | intermediate/audits.rds | tbl_df | 22011 x 34 | step1v4 | Expanded audit records: 12363 unique records + 9648 VS duplicate rows. group = active group for filtering; group_primary = 4-way zone assignment; filter(group == group_primary) recovers unique records. vs_member = TRUE for all variable-engine records. |
| exclusions | intermediate/exclusions.rds | tbl_df | 3888 x 5 | step1v4 | Pipeline-excluded records with excl_reason label; for Step 1.5 exclusion analysis |
| audits | intermediate/audits.rds | tbl_df | 22011 x 34 | step1v5 | Expanded audit records: 12363 unique records + 9648 VS duplicate rows. group = active group for filtering; group_primary = 4-way zone assignment; filter(group == group_primary) recovers unique records. vs_member = TRUE for all variable-engine records. init_mach_emissions_compliant derived with fixed=TRUE without toupper (v5 bug fix). |
| exclusions | intermediate/exclusions.rds | tbl_df | 3888 x 5 | step1v5 | Pipeline-excluded records with excl_reason label; for Step 1.5 exclusion analysis |
