# Analytical Decisions

# Auto-loaded via @decisions.md in CLAUDE.md. Keep under 120 lines.

## Parameter estimates from old trials for comparison

| Parameter                | Value | Source                                  |
|--------------------------|-------|-----------------------------------------|
| lambda_CF Constant_Speed | 0.358 | step3c, 2017–2023 pooled, max_stage=3   |
| lambda_CF CAZ+           | 0.363 | step3b, temporal 3-segment, max_stage=6 |
| lambda_CF Rest_of_London | 0.219 | step3b, temporal 3-segment, max_stage=6 |

## Active state spaces

- Constant_Speed: max_stage = 3 (stages I, II, IIIA only; IIIB/IV absent from cold fleet)
- CAZ+: max_stage = 6 (active stages II–V; Stage I near-absent from cold fleet; 5 active stages, max integer = 6 = Stage V)
- Rest_of_London: max_stage = 6 (full stage range present)

## Phase boundaries

| Phase | Start | End | Notes |
|----------------|------------------|----------------------|----------------|
| A1 | 1.1.2016 | 31.12.2018 | Pre-Stage V market availability |
| A2 | 1.1.2019 | 31.8.2020 | Stage V newly available |
| B | 1.9.2020 | 31.12.2024 | Those marked COVID exempt (1.9.2020–31.3.2021) excluded. 3-segment midpoints: 2021.389, 2022.832, 2024.278; Δt = 1.44, 1.45 yr |
| C | 1.1.2025 | 31.12.2030 | Forecast period. Initialised from latest P24 cold records (Constant_Speed + Variable_Speed pooled snapshot) |

## Decisions log

| Date | Decision | Rationale | Downstream impact |
|----------------|----------------|----------------|-------------------------|
| 29 Mar 2026 | Constant_Speed max_stage = 3 | IIIB/IV absent from cold fleet; max_stage=6 dilutes signal into impossible states | Step 3 estimation |
| 29 Mar 2026 | Phase B CAZ+ uses 3-segment temporal split, not annual GLS | Annual n=37–83; annual GLS λ=0.638 inflated by noise; temporal estimate = 0.363 | Step 3 |
| 29 Mar 2026 | 2024 CS cold excluded from λ_CF estimation | Stage V spike 0%→61% is anticipatory compliance, not natural turnover | Step 3; Phase C init |
| 31 Mar 2026 | ē = Stage-threshold all records | Enforcement_Upgrade flag = 35 records only; threshold yields 10–20% exposure consistent with raw data | Step 3 |
| 31 Mar 2026 | λ_Proactive estimated from warm self-compliant subset only | All-warm WLS confounds proactive and enforcement trajectories | Step 3 |
| 31 Mar 2026 | ē not subtracted from λ_Policy in λ_Proactive calculation | Non-compliant machines excluded from estimation window by construction | Step 3 |
| 14 Apr 2026 | P24 records retained; assigned to Constant_Speed or Variable_Speed by engine type | P24 is the post-2025 merged zone; records contain 2025–2026 audit data needed for Phase C initialisation | Step 1 ingestion; Step 5 init |
| 14 Apr 2026 | Phase C initialised from latest P24 data, not end-2024 | 2025–2026 audit data available; initialising from 2024 introduces \~16 months of unnecessary lag. Generators are all automatically classified as constant speed, correctly mis-classification in the MLOG/audit data. | Step 5 |
| 15 Apr 2026 | CAZ+ max_stage integer = 6 (Stage V), not 5 (Stage IV) | Schema "max_stage=5" means 5 active stages (Stage I near-absent → active: II–V). The max stage INTEGER is 6=Stage V, matching step3b implementation that produced locked λ=0.363. Coding integer as 5 excludes Stage V and is catastrophic in Phase B3 where Stage V is 58% of cold fleet. | Step 3 estimation |

## Known limitations

1.  Ecological inference: aggregate counts approximate individual transition hazards (Robinson, 1950)
2.  Entry/exit bias: model absorbs fleet entry/exit; violates Markov time-homogeneity
3.  λ_CF not time-homogeneous within Phase B: seg 1→2 and 2→3 inconsistent across all groups; single λ per phase is a simplification
4.  λ_CF overestimates true counterfactual due to second-hand market leakage; λ_Proactive is conservative lower bound
5.  Phase A1/A2 variable speed groups pooled due to sparsity (A1 n=139; A2 n=357)