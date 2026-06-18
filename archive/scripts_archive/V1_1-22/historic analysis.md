# Analysis objectives and decisions log

**Current version**: 1.21 | **Last updated**: 2 April 2026

## Current objectives

1. **Compliance routing**: Quantify administrative vs physical compliance outcomes per Table 1 (research_plan_v1_21.md §2.2).
2. **Counterfactual turnover (λ_CF)**: Natural replacement rates from cold-engaged fleet. Authoritative values locked (see Locked parameters below).
3. **LEZ policy effects (λ_Proactive)**: Proactive compliance from warm-engaged self-compliant subset only (`Initial.Machinery.Compliance == "compliant"`). λ_Proactive = λ_Policy − λ_CF, floored at zero.
4. **LEZ enforcement effects (ē)**: Proportion of ALL records (cold + warm) where `Initial.Stage < compliance_threshold`. Do NOT divide by phase duration. Do NOT use Enforcement_Upgrade flag (yields only 35 records — wrong definition).
5. **Forecast (2026–2030)**: Two scenarios. CAZ+ and RoL merge into Variable Speed on 1.1.2025.
6. **Emissions**: E_{g,t} = Σ N_{g,s,t} × kW_{g,s} × 2000 × EF_s. EMEP/EEA Tier 3 factors.

## Locked parameters (do not re-estimate without approval)

| Parameter           | Value | Source                                  |
| ------------------- | ----- | --------------------------------------- |
| λ_CF Constant_Speed | 0.358 | step3c, 2017–2023 pooled, max_stage=3   |
| λ_CF CAZ+           | 0.363 | step3b, temporal 3-segment, max_stage=5 |
| λ_CF Rest_of_London | 0.219 | step3b, temporal 3-segment, max_stage=6 |

## Active state spaces (max_stage per group)

- Constant_Speed: 3 (active stages I, II, IIIA only — IIIB/IV never present in cold fleet)
- CAZ+: 5 (active transition IV→V; stages I–IV present)
- Rest_of_London: 6 (full stage range present)

## Phase boundaries (exact dates)

| Phase        | Start    | End        | Notes                                                  |
| ------------ | -------- | ---------- | ------------------------------------------------------ |
| A1           | 1.1.2016 | 31.12.2018 | Pre-Stage V market availability                        |
| A2           | 1.1.2019 | 31.8.2020  | Stage V newly available                                |
| B            | 1.9.2020 | 31.12.2024 | COVID exempt records (1.9.2020–31.3.2021) filtered out |
| C (forecast) | 1.1.2025 | 31.12.2030 | CAZ+ and RoL merged                                    |

Phase B 3-segment midpoints (fractional years): 2021.389, 2022.832, 2024.278. Δt = 1.44 and 1.45 years.

## Decisions log

| Date        | Decision                                                   | Rationale                                                    |
| ----------- | ---------------------------------------------------------- | ------------------------------------------------------------ |
| 29 Mar 2026 | Constant_Speed max_stage set to 3, not 6                   | IIIB/IV absent from cold fleet; uniform max_stage=6 dilutes signal into impossible states (finding 16/19/20, lambda_sensitivity_tests.md) |
| 29 Mar 2026 | Phase B CAZ+ uses 3-segment temporal split, not annual GLS | Annual sample sizes 37–83; annual GLS yields λ=0.638 inflated by sampling noise; temporal estimate 0.363 (finding 12) |
| 29 Mar 2026 | 2024 CS cold data excluded from λ_CF estimation            | Stage V spike 0%→61% is anticipatory regulatory compliance, not natural turnover; use as Phase C initialisation state only (finding 22) |
| 31 Mar 2026 | ē definition revised to Stage-threshold all records        | Enforcement_Upgrade flag captures only 35 on-the-spot replacements; threshold-based definition yields 10–20% exposure rates consistent with raw data (finding 32–35) |
| 31 Mar 2026 | λ_Proactive estimated from warm self-compliant subset only | All-warm WLS confounds proactive and enforcement trajectories; self-compliant subset isolates pure LEZ policy response (research_plan_v1_18.md §2.4.3) |
| 31 Mar 2026 | ē not subtracted from λ_Policy in λ_Proactive calculation  | Non-compliant machines excluded from estimation window by construction (research_plan_v1_18.md §2.4.3) |

## Known limitations (flag in outputs)

1. Ecological inference: aggregate counts approximate individual transition hazards (Robinson, 1950)
2. Entry/exit bias: model absorbs fleet entry/exit; violates Markov time-homogeneity
3. λ_CF not time-homogeneous within Phase B: seg 1→2 and seg 2→3 inconsistent across all groups; single λ per phase is a simplification
4. λ_CF overestimates true counterfactual due to second-hand market leakage; λ_Proactive is conservative lower bound
5. Phase A1/A2 variable speed groups pooled due to sparsity (A1 n=139; A2 n=357)