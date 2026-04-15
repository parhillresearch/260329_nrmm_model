# NRMM LEZ Analysis — Research Results

Results are organised by computational pipeline phase (§6 of `research_plan.md`).

---

## Phases 1–2: Data Ingestion & Segmentation

**Script:** `260329_step1_ingestion.R` | **Objects:** `df_raw`, `df`, `df_cold`, `df_warm`, `df_ze`, `n_ze`

### Filter cascade

16,251 raw rows → **10,749 analysis-ready records** (Cold = 1,815; Warm = 8,934).

| Filter | Rows excluded | Detail |
| --- | ---: | --- |
| Date outside 2016–2024 | 2,582 | — |
| Non-machinery compliance | 1,779 | No NRMM 733, Site Complete 698, Baselining 254, Declined 67, Other 27 |
| Zone (P24; BCP absent) | 5 | Non-NRMM project zones |
| Unassignable Engine Type | 428 | Unidentified 419, Electric 3, NA 3, Other 3 |
| kW outside 37–560 (numeric only) | 14 | — |
| Unresolvable Initial Stage | 502 | — |
| COVID-exempt (1.9.2020–31.3.2021) | 192 | — |

### Engine Type corrections

1,316 generator-family records (Generator, Hybrid Generator, Flywheel Generator, Flybrid Generator) overridden to "Constant" unconditionally — approximately 360 were mislabelled "Variable" in the raw data; the remainder were blank or Unidentified. Blank Engine Type for remaining machine types (primarily A1 non-generators) filled as "Variable". ZE/Electric: 0 records reached extraction step (3 Electric removed at engine type filter). kW missing/non-numeric (kept, flagged): 612.

### Fleet counts — Warm fleet (Group × Phase)

| Group | A1 | A2 | B | Total |
| --- | ---: | ---: | ---: | ---: |
| Constant_Speed | 88 | 270 | 593 | 951 |
| CAZ_Plus | 349 | 589 | 2,051 | 2,989 |
| Rest_of_London | 450 | 1,346 | 3,198 | 4,994 |
| **Total** | **887** | **2,205** | **5,842** | **8,934** |

### Fleet counts — Cold fleet (Group × Phase)

| Group | A1 | A2 | B | Total |
| --- | ---: | ---: | ---: | ---: |
| Constant_Speed | 16 | 46 | 99 | 161 |
| CAZ_Plus | 51 | 69 | 241 | 361 |
| Rest_of_London | 88 | 288 | 917 | 1,293 |
| **Total** | **155** | **403** | **1,257** | **1,815** |

### Other

| Metric | Value |
| --- | --- |
| Phase distribution (A1 / A2 / B) | 1,042 / 2,608 / 7,099 |
| Within-audit enforcement upgrades (Final Stage > Initial Stage) | 35 |

---

## Phases 3–4 (partial): Count Aggregation & λ_CF Estimation

**Script:** `260329_step2_exploratory.R` | **Objects:** `stage_counts_warm`, `stage_counts_cold_nonpooled`, `stage_counts_cold_pooled`, `stage_counts_cold_B`, `kw_summary`, `audit_by_year`, `transitions`, `lambda_cf`
**Research goals addressed:** RT-01 (λ_CF), RT-04 (audit frequency QA), RT-05 (cell count thresholds), RT-07 (upgrade pathway validation)

---

### Warm fleet — Stage counts by Group × Year

| Group | Year | I | II | IIIA | IIIB | IV | V |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| CAZ_Plus | 2016 | 1 | 1 | 2 | 7 | 1 | 0 |
| | 2017 | 0 | 7 | 22 | 92 | 12 | 0 |
| | 2018 | 1 | 5 | 26 | 140 | 32 | 0 |
| | 2019 | 1 | 12 | 27 | 223 | 79 | 7 |
| | 2020 | 2 | 5 | 21 | 164 | 144 | 47 |
| | 2021 | 0 | 5 | 16 | 129 | 173 | 128 |
| | 2022 | 0 | 2 | 15 | 77 | 129 | 219 |
| | 2023 | 1 | 5 | 11 | 56 | 144 | 422 |
| | 2024 | 0 | 0 | 4 | 29 | 91 | 252 |
| Constant_Speed | 2016 | 0 | 1 | 6 | 0 | 0 | 0 |
| | 2017 | 0 | 3 | 25 | 0 | 0 | 0 |
| | 2018 | 0 | 12 | 41 | 0 | 0 | 0 |
| | 2019 | 0 | 32 | 149 | 1 | 0 | 0 |
| | 2020 | 0 | 7 | 143 | 0 | 0 | 0 |
| | 2021 | 0 | 6 | 129 | 0 | 0 | 0 |
| | 2022 | 0 | 4 | 139 | 0 | 1 | 6 |
| | 2023 | 0 | 4 | 107 | 0 | 0 | 24 |
| | 2024 | 0 | 1 | 38 | 0 | 0 | 72 |
| Rest_of_London | 2016 | 0 | 0 | 12 | 9 | 0 | 0 |
| | 2017 | 0 | 4 | 49 | 121 | 21 | 0 |
| | 2018 | 0 | 13 | 44 | 145 | 32 | 0 |
| | 2019 | 1 | 26 | 110 | 561 | 235 | 13 |
| | 2020 | 3 | 7 | 25 | 378 | 204 | 47 |
| | 2021 | 0 | 12 | 39 | 341 | 199 | 132 |
| | 2022 | 0 | 9 | 28 | 210 | 190 | 208 |
| | 2023 | 1 | 7 | 18 | 151 | 201 | 375 |
| | 2024 | 1 | 4 | 4 | 134 | 151 | 519 |

---

### Cold fleet — Stage counts

#### Non-pooled (Group × Year, all phases)

| Group | Year | I | II | IIIA | IIIB | IV | V |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| CAZ_Plus | 2016 | 0 | 1 | 0 | 0 | 0 | 0 |
| | 2017 | 0 | 1 | 3 | 2 | 1 | 0 |
| | 2018 | 0 | 1 | 10 | 25 | 7 | 0 |
| | 2019 | 0 | 2 | 8 | 24 | 0 | 0 |
| | 2020 | 0 | 1 | 11 | 12 | 20 | 3 |
| | 2021 | 0 | 1 | 4 | 17 | 32 | 15 |
| | 2022 | 0 | 0 | 2 | 9 | 7 | 19 |
| | 2023 | 0 | 0 | 3 | 16 | 25 | 39 |
| | 2024 | 0 | 0 | 0 | 6 | 5 | 29 |
| Constant_Speed | 2017 | 0 | 4 | 3 | 0 | 0 | 0 |
| | 2018 | 0 | 3 | 6 | 0 | 0 | 0 |
| | 2019 | 1 | 8 | 28 | 0 | 0 | 0 |
| | 2020 | 0 | 5 | 22 | 0 | 0 | 0 |
| | 2021 | 0 | 1 | 24 | 0 | 0 | 0 |
| | 2022 | 0 | 4 | 15 | 0 | 0 | 0 |
| | 2023 | 0 | 2 | 7 | 0 | 0 | 0 |
| | 2024 | 0 | 0 | 11 | 0 | 0 | 17 |
| Rest_of_London | 2016 | 1 | 1 | 3 | 15 | 0 | 0 |
| | 2017 | 0 | 5 | 9 | 20 | 2 | 0 |
| | 2018 | 1 | 3 | 8 | 19 | 1 | 0 |
| | 2019 | 2 | 9 | 33 | 111 | 23 | 3 |
| | 2020 | 0 | 12 | 15 | 137 | 49 | 11 |
| | 2021 | 1 | 5 | 17 | 118 | 51 | 51 |
| | 2022 | 0 | 8 | 8 | 72 | 37 | 60 |
| | 2023 | 1 | 1 | 8 | 59 | 51 | 88 |
| | 2024 | 2 | 1 | 5 | 34 | 20 | 102 |

#### Pooled A1/A2 (all groups combined)

| Phase | Year | I | II | IIIA | IIIB | IV | V |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A1 | 2016 | 1 | 2 | 3 | 15 | 0 | 0 |
| | 2017 | 0 | 10 | 15 | 22 | 3 | 0 |
| | 2018 | 1 | 7 | 24 | 44 | 8 | 0 |
| A2 | 2019 | 3 | 19 | 69 | 135 | 23 | 3 |
| | 2020 | 0 | 14 | 24 | 81 | 28 | 4 |

#### Pooled B (per group)

| Group | Year | I | II | IIIA | IIIB | IV | V |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| CAZ_Plus | 2020 | 0 | 0 | 4 | 1 | 6 | 1 |
| | 2021 | 0 | 1 | 4 | 17 | 32 | 15 |
| | 2022 | 0 | 0 | 2 | 9 | 7 | 19 |
| | 2023 | 0 | 0 | 3 | 16 | 25 | 39 |
| | 2024 | 0 | 0 | 0 | 6 | 5 | 29 |
| Constant_Speed | 2020 | 0 | 1 | 17 | 0 | 0 | 0 |
| | 2021 | 0 | 1 | 24 | 0 | 0 | 0 |
| | 2022 | 0 | 4 | 15 | 0 | 0 | 0 |
| | 2023 | 0 | 2 | 7 | 0 | 0 | 0 |
| | 2024 | 0 | 0 | 11 | 0 | 0 | 17 |
| Rest_of_London | 2020 | 0 | 3 | 3 | 67 | 35 | 9 |
| | 2021 | 1 | 5 | 17 | 118 | 51 | 51 |
| | 2022 | 0 | 8 | 8 | 72 | 37 | 60 |
| | 2023 | 1 | 1 | 8 | 59 | 51 | 88 |
| | 2024 | 2 | 1 | 5 | 34 | 20 | 102 |

---

### RT-04 — Audit frequency QA (warm fleet)

| Year | Phase | Audits |
| ---: | --- | ---: |
| 2016 | A1 | 40 |
| 2017 | A1 | 356 |
| 2018 | A1 | 491 |
| 2019 | A2 | 1,477 |
| 2020 | A2 | 728 |
| 2020 | B | 469 |
| 2021 | B | 1,309 |
| 2022 | B | 1,237 |
| 2023 | B | 1,527 |
| 2024 | B | 1,300 |

Annual time steps validated. 2016 count (40) is low; subsequent years are consistent. Year 2020 straddles two phases at the 1 September boundary.

---

### kW summary (warm fleet)

| Group | n | Missing kW (%) | Mean kW | Median kW | P25 | P75 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| CAZ_Plus | 2,989 | 3.2 | 104 | 75 | 55 | 128 |
| Constant_Speed | 951 | 16.4 | 172 | 150 | 80 | 240 |
| Rest_of_London | 4,994 | 2.0 | 96 | 73 | 55 | 124 |

Constant_Speed has a notably higher kW profile and higher missing rate (16.4%). CAZ_Plus and Rest_of_London are similar in distribution.

---

### RT-07 — Observed transition pathways (warm fleet)

| Initial | Final | n | Permitted |
| --- | --- | ---: | --- |
| I | I | 12 | — |
| II | II | 184 | — |
| II | IIIA/IV/V | 4 | ✓ |
| IIIA | IIIA | 1,231 | — |
| IIIA | IIIB/IV/V | 5 | ✓ |
| IIIB | IIIB | 2,943 | — |
| IIIB | IV/V | 11 | ✓ |
| IIIB | IIIA | 5 | ✗ downgrade |
| IV | IV | 2,020 | — |
| IV | V | 9 | ✓ |
| IV | IIIA/IIIB | 6 | ✗ downgrade |
| V | V | 2,461 | — |
| V | IIIB/IV | 9 | ✗ downgrade |

20 non-permitted downgrade transitions (0.22% of warm fleet); likely data entry errors or equipment swaps. Excluded from transition matrix estimation.

---

### RT-05 — Cell count adequacy

| Phase | Group | Min cell n | Max cell n | Stage cells |
| --- | --- | ---: | ---: | ---: |
| A1 | CAZ_Plus | 1 | 140 | 14 |
| A1 | Constant_Speed | 1 | 41 | 6 |
| A1 | Rest_of_London | 4 | 145 | 10 |
| A2 | CAZ_Plus | 1 | 223 | 11 |
| A2 | Constant_Speed | 1 | 149 | 5 |
| A2 | Rest_of_London | 1 | 561 | 12 |
| B | CAZ_Plus | 1 | 422 | 26 |
| B | Constant_Speed | 1 | 139 | 14 |
| B | Rest_of_London | 1 | 519 | 28 |

Sparse cells (n = 1) present across all phases and groups, concentrated in low stages in later years and high stages in early years — expected given fleet progression. Warm fleet totals are adequate for transition matrix estimation at phase level.

---

### RT-01 — λ_CF estimation (natural upgrade rate, cold-engaged fleet)

**Method:** WLS regression on stage proportions: Δp_s = λ_CF × (Σ_{j<s} p_{j,t}/k_j − p_{s,t}), where p_{s,t} is the proportion of cold-engaged machines at stage s in year t and k_j = max_stage − j. Weights = max(raw count at stage s in year t, 1). Normalising to proportions removes the confound of changing annual audit volume before computing year-on-year deltas (§2.4).

| Phase | Pooling | λ_CF | SE | 95% CI |
| --- | --- | ---: | ---: | --- |
| A1 | All groups | 0.2937 | 0.1254 | [0.0479, 0.5395] |
| A2 | All groups | 0.0633 | 0.1080 | [−0.1485, 0.2751] |
| B | Constant_Speed | 0.1760 | 0.0408 | [0.0960, 0.2560] |
| B | CAZ_Plus | 0.6384 | 0.1021 | [0.4384, 0.8385] |
| B | Rest_of_London | 0.2499 | 0.0354 | [0.1806, 0.3192] |

**Commentary:**

- **A1 (λ_CF = 0.294):** Physically plausible and within the literature range (~5–30%/yr). Wide CI [0.05, 0.54] reflects sparsity (n = 155 cold records, 2 year-pairs). Usable as a pooled A1 estimate with caution.
- **A2 (λ_CF = 0.063):** CI includes zero [−0.15, 0.28]; not significantly different from zero. Year 2020 is a partial year (Jan–Aug only), distorting the inter-year shift. Too uncertain for standalone use; recommend pooling A1/A2 or carrying forward A1 estimate.
- **B Constant_Speed (0.176) and Rest_of_London (0.250):** Both physically plausible with tight CIs; mutually consistent at ~18–25%/yr. These form reliable counterfactual baseline estimates.
- **B CAZ_Plus (0.638, CI [0.44, 0.84]):** CI is within [0, 1] but notably elevated relative to Constant_Speed and Rest_of_London. Rapid Stage V uptake in CAZ_Plus cold fleet (2020–2024) may reflect LEZ-driven demand rather than purely natural turnover, compressing inter-stage variation. Recommend pooling CAZ_Plus with Rest_of_London for λ_CF in Phase B as a robustness check.

---

### Charts — Stage distribution

Three PNG files produced by `260329_step2_exploratory.R`:

| File | Description |
| --- | --- |
| `260329_stage_distribution_warm.png` | Warm fleet Stage proportions by Group × Year (stacked bar, 3 panels). Shows clear Stage V ramp in CAZ_Plus and Rest_of_London from 2021; Stage V appears in Constant_Speed from 2022–2024. |
| `260329_stage_distribution_cold_nonpooled.png` | Cold fleet (non-pooled) Stage proportions by Group × Year. Mirrors warm fleet trends with expected sparsity in early years and small group totals. |
| `260329_stage_distribution_cold_pooled.png` | Cold fleet Stage distributions: (A) all groups pooled by year across A1/A2 phases; (B) per-group pooled by year for Phase B. Steady stage improvement visible across the full 2016–2024 period. |

---

### Viability of unpooled λ_CF estimation

**Question:** Do the Phase 3 cold-engaged counts support per-group λ_CF estimation for A1 and A2?

| Phase | Group | Cold n | Year-pairs | GLS rows | Viable? |
| --- | --- | ---: | ---: | ---: | --- |
| A1 | Constant_Speed | 16 | 1 | 4 | ✗ |
| A1 | CAZ_Plus | 51 | 2 | 8 | ✗ |
| A1 | Rest_of_London | 88 | 2 | 8 | ✗ |
| A2 | Constant_Speed | 46 | 1 | 4 | ✗ |
| A2 | CAZ_Plus | 69 | 1 | 4 | ✗ |
| A2 | Rest_of_London | 288 | 1 | 4 | ✗ |
| B | Constant_Speed | 99 | 3 | 15 | ⚠ marginal |
| B | CAZ_Plus | 241 | 4 | 20 | ✗ unstable |
| B | Rest_of_London | 917 | 4 | 20 | ✓ |

**Conclusion:** Unpooled λ_CF is not viable for A1 or A2 — per-group cold counts yield only 4–8 GLS rows across 1–2 year-pairs, insufficient for stable estimation. The methodology's pooling decision is confirmed. For Phase B, Rest_of_London is the only group yielding a stable per-group estimate; pooling variable-speed groups (CAZ_Plus + Rest_of_London) for Phase B is recommended and should be tested in the next step.

---
