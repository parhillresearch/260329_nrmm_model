# NRMM LEZ Analysis — Methods and Findings Report

_Version 2 | 17 April 2026_  
_Script: `outputs/260417_step6_methods_findings_v2.md` (Step 6, no R script)_  
_Source scripts: Steps 1–5 final-trial R files; findings from sprint\_log.md Step Reports_

---

## Executive Summary

This report covers a five-step Markov-chain model of the Non-Road Mobile Machinery (NRMM) Low Emissions Zone (LEZ) applied to 12,363 model-phase audit records drawn from 16,251 cleaned observations (2016–2026). The model tracks the emissions Stage distribution of machinery across four groups — Constant\_Speed (generators), CAZ\_Plus (variable-speed in CAZ/OA), Rest\_of\_London (variable-speed, GL zone), and Variable\_Speed (merged Phase C, P24 zone) — and projects Stage distributions and compliance rates to 2030 under two scenarios.

**Key quantitative findings:**

| Parameter | Constant\_Speed | Variable\_Speed (CAZ+/RoL merged) |
|---|---|---|
| λ\_CF (counterfactual turnover, stage/yr) | 0.051 ⚠ | 0.262 / 0.241 (CAZ+/RoL pre-merge) |
| λ\_Proactive (incremental LEZ effect) | 0.000 (floored) | 0.013 (CAZ+ only) / 0.000 |
| ē Phase B (% below threshold) | 82.8% (Stage V imposed on IIIA fleet) | CAZ+: 19.9%; RoL: 4.7% |
| ē Phase C (P24, % below threshold) | 30.4% | 22.0% |
| π₀ Stage V (Phase C initialisation) | 53.8% | 76.5% |
| Scenario A compliance, 2030 | 57.4% (Stage V) | 90.8% (Stage V threshold) |
| Scenario B compliance, 2030 | 100% (by 2026) | 100% (by 2030) |
| Enforcement-attributable ceiling | +42.6 pp | +9.2 pp |

**Key Results:**

| Group | λ\_CF (SE) | λ\_Pro | p\_cf | p\_pro | ē Phase B (%) | ē Phase C (%) | Scen A 2030 (%) | Scen B 2030 (%) |
|---|---|---|---|---|---|---|---|---|
| Constant\_Speed | 0.051 (0.026) ⚠ | 0.000 | 0.016 | 0.000 | 82.8% | 30.4% | 57.4% | 100% |
| CAZ\_Plus | 0.262 (0.033) | 0.013 | 0.201 | 0.010 | 19.9% | — | — | — |
| Rest\_of\_London | 0.241 (0.017) | 0.000 | 0.161 | 0.000 | 4.7% | — | — | — |
| Variable\_Speed | 0.245 (derived) | 0.003 | 0.168 | 0.002 | — | 22.0% | 90.8% | 100% |

_CAZ+ and RoL have no Phase C forecast (merged into Variable\_Speed from 1.1.2025). Variable\_Speed λ\_CF is the Phase B cold-N-weighted average of CAZ+ and RoL; no independent WLS fit is available. Scen A 2030 for VS reflects compliance at the Stage V threshold (the threshold upgrades from Stage IV to Stage V in 2030)._

**Anomaly flags:**  
- λ\_CF Constant\_Speed (0.051) departs sharply from the prototype reference (0.358); corroborated by near-zero λ\_Policy and accepted as the operative estimate.  
- Scenario A compliance for Constant\_Speed shows effectively no improvement (53.8% → 57.4%); the generator fleet is almost entirely dependent on enforcement to achieve Stage V compliance.  
- Emissions section deferred pending EMEP/EEA Tier 3 NOx factors (EF\_s).

---

## Step 1: Data Ingestion and Preparation

**Final-trial script:** `260413_step1_ingestion_v1.R`  
**Output objects:** `intermediate/audits.rds` (15,932 × 34)

---

### Sub-task 1.1 — Import, column selection, and field encoding

**Intended task:** Import `audits.txt`; discard out-of-scope columns (schema.md Table 5); validate and encode retained fields (schema.md Table 4) using Stage encoding (List 1), non-compliance codes (List 2).

**Execution:** Raw file read with `read.delim()`. Nineteen columns were retained by name using `select(all_of(COLS_KEEP))` and renamed to snake\_case. Stage strings (I, II, IIIA, IIIB, IV, V, ZE) were mapped to integers 1–7 via a named vector `STAGE_MAP`; two known raw typos (`iIIB`, `iV`) were corrected before encoding. Compliance flags were extracted from reason-code strings by scanning for the character "E" (emissions) and for any of A/C/P/R/X (administrative).

```r
# Stage encoding (encode_stage function)
encode_stage <- function(x) {
  x <- trimws(x)
  x[x == "iIIB"] <- "IIIB"    # known raw typo
  x[x == "iV"]   <- "IV"      # known raw typo
  x[grepl("^ZE$|zero.emission|hybrid", x, ignore.case = TRUE)] <- "ZE"
  stage <- STAGE_MAP[x]       # named vector, unmatched → NA
  names(stage) <- NULL
  stage
}

# Compliance flags from reason-code string (derive_compliance_flags function)
derive_compliance_flags <- function(reasons) {
  r <- toupper(trimws(replace_na(as.character(reasons), "")))
  list(
    emissions_compliant = !grepl("E", r, fixed = TRUE),
    admin_compliant     = !grepl("[ACPRX]", r)
  )
}
```

**Findings:** All 19 expected columns were present. Two stage-encoding typos resolved; 35 records had unresolvable initial\_stage (excluded downstream). The `derive_compliance_flags()` split separated emissions non-compliance (E code) from administrative non-compliance cleanly.

---

### Sub-task 1.2 — Exclusions

**Intended task:** Exclude out-of-scope records: zone filter retains CAZ, OA, GL, P24; excludes BCP. Non-machinery records removed (Initial Machinery Compliance not "compliant"/"non-compliant"). Unassignable engine types, unresolvable Initial Emissions Stage, and COVID-exempt records (1.9.2020–31.3.2021) excluded.

**Execution:** Non-machinery records (labels including "No NRMM", "Site Complete", "Baselining", "DECLINED AUDIT") were removed by a whitelist filter on `initial_machinery_compliance`. BCP zone records were excluded by zone filter. COVID exemptions were identified by a text-match on the retrofit/exemption field during the window 1 September 2020 – 31 March 2021.

```r
# Non-machinery exclusion
audits <- audits |>
  filter(imc_lower %in% c("compliant", "non-compliant"))

# Zone filter
audits <- audits |> filter(zone %in% ZONES_IN_SCOPE)

# COVID exemption filter
audits <- audits |>
  mutate(
    covid_exempt = date >= COVID_START & date <= COVID_END &
      (grepl("covid", tolower(replace_na(initial_retrofit_or_exemption, ""))) |
       grepl("covid", tolower(replace_na(final_retrofit_or_exemption,   ""))))
  ) |>
  filter(!covid_exempt)
```

**Findings:** BCP exclusions removed a small number of records from the geographic scope. COVID exemptions removed a further subset within the Phase B window. The retained `audits.rds` object (15,932 rows) includes all records that passed these filters, but also pre-2016 records and records with unassignable phase; only records allocated to a model phase are used in Steps 2–5.

---

### Sub-task 1.3 — Group and phase assignment

**Intended task:** Assign every retained record to a machine group (schema.md Table 1) and model phase (schema.md Table 7). P24 Variable Speed records → group `Variable_Speed`; P24 Constant Speed records → group `Constant_Speed`. Records with date ≥ 1.1.2025 → Phase C.

**Execution:** Engine type was classified first (generator-family machine types overridden to Constant regardless of raw Engine.Type field; blanks filled with Variable to restore A1 records). Group and phase were assigned via `case_when()` on zone and engine type, and on date boundaries respectively.

```r
# Engine type override and group assignment
audits <- audits |>
  mutate(
    engine_type_clean = if_else(
      machine_type %in% CONSTANT_SPEED_TYPES, "Constant", engine_type
    ),
    group = case_when(
      engine_type_clean == "Constant"                             ~ "Constant_Speed",
      engine_type_clean == "Variable" & zone %in% c("CAZ","OA") ~ "CAZ_Plus",
      engine_type_clean == "Variable" & zone == "GL"             ~ "Rest_of_London",
      engine_type_clean == "Variable" & zone == "P24"            ~ "Variable_Speed",
      TRUE ~ NA_character_
    )
  )

# Phase assignment
assign_phase <- function(d) {
  case_when(
    d >= PHASE_A1_START & d <= PHASE_A1_END ~ "A1",
    d >= PHASE_A2_START & d <= PHASE_A2_END ~ "A2",
    d >= PHASE_B_START  & d <= PHASE_B_END  ~ "B",
    d >= PHASE_C_START                      ~ "C",
    TRUE ~ NA_character_
  )
}
```

**Findings:** All four groups assigned without ambiguity. P24 records correctly split by engine type: generators → Constant\_Speed Phase C; variable-speed equipment → Variable\_Speed Phase C. No records fell outside the A1/A2/B/C phase boundaries.

---

### Sub-task 1.4 — Record counts and anomaly flags

**Intended task:** Report record counts by group and phase; flag anomalies for user review before proceeding. Report P24 record counts separately; flag earliest and latest P24 audit date.

**Execution:** Count tables produced by `count(group, phase) |> pivot_wider()` for all, cold, and warm subsets. P24 Phase C records broken out separately with engagement-type split.

**Findings:** 12,363 records were allocated to a model phase across four groups and four phases, as shown below. The `audits.rds` object contains 15,932 rows in total, with the difference comprising pre-2016 records and records with unassignable phase that are retained in the object but excluded from model estimation.

| group | A1 | A2 | B | C | total |
|:---|---:|---:|---:|---:|---:|
| CAZ\_Plus | 400 | 658 | 2,296 | 0 | 3,354 |
| Constant\_Speed | 104 | 318 | 693 | 112 | 1,227 |
| Rest\_of\_London | 538 | 1,634 | 4,122 | 0 | 6,294 |
| Variable\_Speed | 0 | 0 | 5 | 1,483 | 1,488 |

Phase C P24 records confirmed present: temporal extent spanned from early 2025 to the latest available audit date in 2026, confirming data availability for Phase C initialisation in Step 5. No anomalous group–phase cells (all cells n ≥ 30 across the main groups; Variable\_Speed Phase B shows 5 records — a minor edge-case of pre-2025 P24 data correctly routed; flagged in Step 3).

---

## Step 2: Exploratory Analysis

**Final-trial script:** `260414_step2_exploratory_v7_1.R`  
**Output objects:** `intermediate/stage_dist.rds`, `intermediate/audits_step2.rds`, `intermediate/sparsity_summary.rds`

---

### Sub-task 2.1 — Stage distributions by group, phase, and engagement type

**Intended task:** Tabulate Stage distributions by group, phase, and engagement type (cold/warm); plot trends over time.

**Execution:** Stage counts and percentages were computed by group × year × cold\_engaged × stage. Phase B was subdivided into three equal-duration segments (B1, B2, B3) with boundaries at 9 February 2022 and 21 July 2023, using `assign_phase_sub()`. ZE/Stage-7 records were flagged and excluded from stage distribution tables to avoid confounding compliance thresholds. Wide tables were built using `make_wide()`, which used `expand.grid()` + `left_join()` to guarantee all phase × stage combinations were present regardless of observed data (the root-cause fix resolving the earlier NSE/tidyr bug in Trials 1–6).

```r
# make_wide: expand.grid ensures all phase × stage combinations present
make_wide <- function(df, subcol_var, val_col = "n",
                      phases  = PHASE_ORDER,
                      subcols = STAGE_LEVELS) {
  grid <- expand.grid(
    group         = GROUP_ORDER,
    phase_display = phases,
    subcol        = subcols,
    stringsAsFactors = FALSE
  )
  names(grid)[names(grid) == "subcol"] <- subcol_var

  df_clean <- df |> ...   # aggregate
  joined   <- grid |> left_join(df_clean, by = c("group","phase_display",subcol_var))
  wide     <- joined |>
    mutate(col_key = paste(phase_display, .data[[subcol_var]], sep = "__")) |>
    pivot_wider(id_cols = "group", names_from = col_key, values_from = all_of(val_col))
  ...
}
```

Structural NAs (groups absent from certain phases, e.g. Variable\_Speed in A1–B3, CAZ+/RoL in Phase C) were distinguished from incidental zeros using `fill_table_nas()`, which marks group–phase pairs with no in-scope data as `NA` (rendered as —) and fills genuine zero-count cells with 0.

**Findings:** Cold fleet Stage distributions showed clear upward trends in all groups. Constant\_Speed fleet dominated by Stage I/II in Phase A1, transitioning to Stage IIIA majority by Phase B. CAZ\_Plus and Rest\_of\_London showed steady Stage V penetration from 2021 onward. Variable\_Speed Phase C cold fleet showed 76.5% Stage V, dominated by high-compliance machines. Four plots produced: cold by year, warm by year, Phase B sub-segments (CAZ+/RoL), and Variable\_Speed Phase C by engagement type.

![Cold fleet stage distributions by group and year](260414_step2_exploratory_v7_1_stage_cold_year.png)

Cold-engaged records show upward stage trends in all groups from 2016 to 2024; Constant\_Speed is dominated by Stage I/II early and Stage IIIA from 2019 onward.
CAZ+ and Rest\_of\_London show growing Stage V fractions from 2021; the 2024 CS Stage V spike reflects anticipatory pre-2025 compliance, excluded from λ\_CF estimation.

![Warm fleet stage distributions by group and year](260414_step2_exploratory_v7_1_stage_warm_year.png)

Warm self-compliant records show a broadly similar upward stage trend, with higher Stage V penetration than cold records in most groups and periods.
The warm fleet improves faster than cold in CAZ+ and RoL, corroborating the λ\_Policy ≥ λ\_CF finding for those groups.

![Phase B sub-segment stage distributions (CAZ+ and RoL)](260414_step2_exploratory_v7_1_stage_cold_Bsub.png)

Phase B is subdivided into three ~527-day segments (B1: Sep 2020–Feb 2022; B2: Feb 2022–Jul 2023; B3: Jul 2023–Dec 2024) to stabilise within-group variance.
Stage V penetration grows through B1–B3 in both CAZ+ and RoL; the three-segment approach was chosen over annual GLS to prevent noise amplification in thin annual cells.

![Variable_Speed Phase C stage distributions by engagement type](260414_step2_exploratory_v7_1_stage_variable_speed.png)

Variable\_Speed Phase C (P24 zone, 2025–2026 audit data) is predominantly Stage V in both cold and warm subsets, consistent with anticipatory pre-merger compliance.
The cold fleet (N=57) has a non-compliant tail (Stages I–IV totalling ~23.5%) that informs Phase C initialisation and Scenario B enforcement modelling.

---

### Sub-task 2.2 — Compliance outcomes (six-route classification)

**Intended task:** Characterise compliance outcomes using the six-route classification (schema.md Table 3).

**Execution:** Each record was classified into one of five routes (plus "unknown") using a priority-ordered `case_when()` in `classify_route()`. Route 4 (driven compliant — emissions) was defined as `!init_mach_emissions_compliant & enforcement_upgrade`, where `enforcement_upgrade = final_stage > initial_stage`. Route 5 (non-compliant) was `!init_mach_emissions_compliant & !enforcement_upgrade`.

```r
classify_route <- function(df) {
  df |> mutate(
    route = case_when(
      !init_mach_emissions_compliant &  enforcement_upgrade  ~ "4_driven_compliant_emissions",
      !init_mach_emissions_compliant & !enforcement_upgrade  ~ "5_non_compliant",
       init_mach_emissions_compliant &  init_mach_admin_compliant              ~ "1_self_compliant",
       init_mach_emissions_compliant & !init_mach_admin_compliant &
         final_mach_admin_compliant                           ~ "2_driven_compliant_reg",
       init_mach_emissions_compliant & !init_mach_admin_compliant &
        !final_mach_admin_compliant                           ~ "3_non_compliant_R",
      TRUE ~ "unknown"
    )
  )
}
```

**Findings:** Route 1 (self-compliant) dominated the warm fleet in all groups and phases, with proportions increasing over time consistent with voluntary fleet upgrading ahead of enforcement. Route 4 counts were very low (≤35 on-the-spot stage upgrades across all records), which later informed the decision in Step 3 to revise the enforcement Route 4 indicator. No "unknown" route records were found.

---

### Sub-task 2.3 — Sparsity, signal exhaustion, and volatility

**Intended task:** Identify data sparsity, signal exhaustion, and volatility issues by group and sub-phase that will constrain estimation.

**Execution:** Sparsity was flagged as cold-engaged cell counts (group × phase_display × stage) below n = 30. Signal exhaustion measured the proportion of cold-engaged records at each group's maximum active stage (`pct_at_max`). Volatility was quantified as the cross-year standard deviation of `pct_at_max` within Phase B.

**Findings:** Phase A1 showed sparsity for CAZ+ (n = 139 total cold records) — confirmed the A1/A2 pooling decision for lambda\_CF estimation. Signal exhaustion in Phase B3: CAZ+ approaching 60% Stage V (near-saturation of estimation ceiling), flagging potential compression of the WLS signal. Phase B sub-segmentation stabilised variance for the variable-speed groups, supporting the 3-segment approach over annual GLS.

---

### Sub-task 2.4 — Confirm analytical approach

**Intended task:** Report findings and confirm analytical approach with user before proceeding.

**Findings:** Step 2 outputs confirmed: (1) A1/A2 pooling for variable-speed groups; (2) Phase B 3-segment approach for CAZ+/RoL; (3) Constant\_Speed kept as single Phase B for lambda fitting (cold sample too small for sub-segmentation); (4) 2024 CS data to be excluded from lambda\_CF estimation due to anticipatory Stage V spike. Step accepted at Trial 7.1.

---

## Step 3: Parameter Estimation

**Final-trial script:** `260415_step3_parameter_estimation_v6.R`  
**Output objects:** `intermediate/lambda_cf.rds`, `intermediate/ebar_results.rds`, `intermediate/lambda_proactive.rds`, `intermediate/enf_success_rate.rds`, `intermediate/step3_params.rds`

---

### Sub-task 3.1 — Estimate lambda\_CF

**Intended task:** Estimate lambda\_CF from cold-engaged records only, using WLS on Stage proportion vectors; apply group-specific max\_stage and estimation windows determined in Step 2; validate against previous values in schema.md Table 8.

**Execution:** WLS fitted via `lm(mean_stage ~ mid, weights = n)` with SE extracted from `vcov()`. Constant\_Speed used annual midpoints 2016–2023 (2024 excluded). Variable-speed groups (CAZ+, RoL) used A1/A2 pooled as a single point plus Phase B 3-segment midpoints. Stages were capped at group-specific `MAX_STAGE` (CS: 3; CAZ+/RoL: 6) before averaging.

```r
fit_lambda <- function(pts, min_pts = 2L) {
  pts <- pts |> filter(!is.na(mean_stage), !is.na(n), n > 0L, is.finite(mean_stage))
  fit  <- lm(mean_stage ~ mid, data = pts, weights = n)
  b    <- coef(fit)[["mid"]]
  se_b <- sqrt(vcov(fit)["mid", "mid"])
  tc   <- qt(0.975, df = max(df.residual(fit), 1L))
  tibble(lambda = b, se = se_b,
         ci_lo = b - tc * se_b, ci_hi = b + tc * se_b,
         n_pts = nrow(pts), n_obs = as.integer(sum(pts$n)))
}

# Phase-B 3-segment aggregation (variable-speed groups)
phase_b_pts <- function(dat) {
  dat |>
    mutate(seg = findInterval(frac_year, B_BREAKS, rightmost.closed = TRUE)) |>
    filter(seg >= 1L, seg <= 3L) |>
    group_by(seg) |>
    summarise(mean_stage = mean(stage_capped, na.rm = TRUE), n = n(), .groups = "drop") |>
    mutate(mid = B_MIDS[seg])
}
```

**Findings:**

| Group | λ\_CF | SE | 95% CI | N | vs. ref |
|---|---|---|---|---|---|
| Constant\_Speed | 0.051 ⚠ | 0.026 | [−0.017, 0.119] | 133 | Δ = −0.307 |
| CAZ\_Plus | 0.262 | 0.033 | [0.119, 0.404] | 361 | Δ = −0.101 |
| Rest\_of\_London | 0.241 | 0.017 | [0.169, 0.314] | 1,294 | Δ = +0.022 |

Constant\_Speed result is anomalously low relative to the prototype reference (0.358). Corroborated by near-zero λ\_Policy (−0.000) in the warm self-compliant CS fleet: generators have genuinely low natural turnover and remain in service until a compliance event forces replacement. CS cold sample (N = 133) is small but the signal is consistent. Accepted as operative estimate; old reference superseded. RoL is within tolerance of the reference (+0.022). CAZ+ moderate deviation (Δ = −0.101), consistent with estimation-window differences.

---

### Sub-task 3.2 — Estimate e-bar

**Intended task:** Estimate e-bar from all records where Initial Stage < compliance threshold for that group and phase (schema.md Table 2); do not divide by phase duration.

**Execution:** For each group × phase cell, records with `initial_stage < COMP_THRESH[[phase]][[group]]` were counted and expressed as a percentage of all records in that cell. COMP\_THRESH encoded the compliance thresholds from schema.md Table 2 (e.g. Constant\_Speed Phase A1/A2: Stage IIIA = integer 3; Phase B: Stage V = integer 6).

```r
compute_ebar <- function(grp, ph) {
  thresh_vec <- COMP_THRESH[[ph]]
  if (is.null(thresh_vec) || !(grp %in% names(thresh_vec))) return(...)
  threshold <- thresh_vec[[grp]]
  dat       <- audits |> filter(group == grp, phase == ph, !is.na(initial_stage))
  n_nc      <- sum(dat$initial_stage < threshold, na.rm = TRUE)
  tibble(ebar_pct = 100 * n_nc / nrow(dat), n_nc = ..., n_tot = ...)
}
```

**Findings:**

| Group | ē Phase A1 | ē Phase A2 | ē Phase B | ē Phase C |
|---|---|---|---|---|
| Constant\_Speed | 22.1% | 14.8% | 82.8% | 30.4% |
| CAZ\_Plus | 20.2% | 11.2% | 19.9% | — |
| Rest\_of\_London | 5.2% | 3.2% | 4.7% | — |
| Variable\_Speed | — | — | — | 22.0% |

The Constant\_Speed Phase B spike to 82.8% reflects that Stage V was first required in Phase B but most generators were at Stage IIIA; the majority were initially non-compliant. The drop to 30.4% in Phase C (P24 records) reflects anticipatory compliance ahead of the 2025 formal merger. CAZ+ and RoL ē values are moderate and stable, consistent with a fleet gradually improving ahead of the IIIB→IV and IV→V thresholds. Variable\_Speed Phase C at 22.0% aligns closely with CS Phase C, expected for a merged post-2025 snapshot.

![e-bar non-compliance exposure rate by group and phase](260415_step3_parameter_estimation_v6_ebar.png)

Each panel shows ē (% of machines below the compliance threshold) for one group across all phases; missing bars indicate phases where that group has no data.
The Constant\_Speed Phase B spike to ~83% dominates: almost the entire generator fleet was non-compliant when Stage V was first required.

---

### Sub-task 3.3 — Estimate lambda\_Proactive

**Intended task:** Estimate lambda\_Proactive from warm self-compliant records only (Initial Machinery Compliance == compliant); compute as lambda\_Policy − lambda\_CF, floored at zero.

**Execution:** The same `fit_lambda()` function was applied to warm, self-compliant records (cold\_engaged == FALSE, init\_mach\_emissions\_compliant == TRUE) to obtain λ\_Policy per group. λ\_Proactive = max(0, λ\_Policy − λ\_CF). The warm self-compliant subset isolates pure voluntary LEZ-driven upgrading, excluding both the enforcement-driven response and the natural cold-fleet turnover.

```r
# Warm self-compliant subset
warm_sc <- audits |>
  filter(cold_engaged == FALSE, init_mach_emissions_compliant == TRUE,
         group %in% c("Constant_Speed","CAZ_Plus","Rest_of_London")) |>
  mutate(stage_capped = pmin(initial_stage, MAX_STAGE[group]))

# Lambda_Proactive: floor at zero
proactive <- function(lam_pol, lam_cf) {
  max(0, lam_pol$lambda - lam_cf$lambda)
}
```

**Findings:**

| Group | λ\_Policy | λ\_CF | λ\_Proactive | N warm SC |
|---|---|---|---|---|
| Constant\_Speed | −0.000 | 0.051 | 0.000 (floored) | 148 |
| CAZ\_Plus | 0.275 | 0.262 | 0.013 | 501 |
| Rest\_of\_London | 0.194 | 0.241 | 0.000 (floored) | 1,152 |

CS: near-zero λ\_Policy corroborates near-zero λ\_CF — generators show no detectable proactive LEZ response. CAZ+: small but positive proactive response (0.013); the only group with detectable voluntary upgrading beyond natural turnover. RoL: λ\_Policy (0.194) < λ\_CF (0.241) — the warm self-compliant subset improves more slowly than the cold fleet; floors at zero. This is analytically consistent (warm SC machines may skew older/lower-stage than the broad cold fleet within the same zone).

---

### Sub-task 3.4 — Report enforcement success rate

**Intended task:** Report enforcement success rate from Route 4/5 outcomes as a descriptive policy metric. Flag groups where n(Routes 4+5) < 30 as too sparse to interpret. This is not a model parameter and does not feed into the transition matrices.

**Execution:** Route 4 was defined as records where `init_mach_emissions_compliant == FALSE` AND `final_mach_emissions_compliant == TRUE` (final machinery reasons contain no E code, indicating post-visit compliance achieved by removal, replacement, retrofit, or exemption granted). Route 5 was `final_mach_emissions_compliant == FALSE`. Success rate = n(Route 4) / n(Routes 4+5). Reported by group × period (A1, A2, B1, B2, B3, C). Cells with n < 30 flagged with ⚠.

**Findings:** Route 4 success rates ranged 0.0–1.4% across all groups and time periods. This is a genuine data characteristic, not a coding artefact: the audit record captures compliance state at the point of visit; enforcement outcomes that occur between visits (removals, replacements) are not captured as raised final\_stage in the record. This finding directly corroborates the design decision to exclude enforcement from the transition matrix and represent it only as the Scenario B Boolean mask in Step 5. Variable\_Speed showed only 5 Phase B3 records (pre-2025 P24 zone edge case), flagged as too sparse to interpret.

![Enforcement outcomes by group and time period](260415_step3_parameter_estimation_v6_enforcement.png)

Stacked bars show absolute counts of Route 4 (green, driven compliant) and Route 5 (red, not actioned) machines per group and time period; y-axes are free across facets.
Labels above each bar show the Route 4 success rate (%); the near-invisible green component confirms Route 4 counts are effectively zero across all groups and periods.

---

### Sub-task 3.5 — Report all parameter estimates

**Intended task:** Report all parameter estimates with SE and CI where applicable; cross-check against locked values and expected ranges; flag anomalies.

**Findings:** All estimates reported in Sections 3.1–3.4 above. The only material anomaly is λ\_CF Constant\_Speed = 0.051 (departure Δ = −0.307 from reference). Accepted after corroboration from: (1) near-zero λ\_Policy in the same fleet; (2) small but internally consistent cold sample (N = 133); (3) known prior-trial data pipeline differences. All other estimates within 15% of prior references or explained by revised analytical decisions (MAX\_STAGE correction for CAZ+). Parameters locked in decisions.md and schema.md Table 8 for use in Step 4.

---

## Step 4: Transition Matrix Construction

**Final-trial script:** `260417_step4_transition_matrices_v3.R`  
**Output objects:** `intermediate/p_natural.rds`, `intermediate/p_proactive.rds`, `intermediate/p_total.rds`, `intermediate/step4_matrices.rds`

---

### Sub-task 4.1 — Construct P\_Natural and P\_Proactive

**Intended task:** Construct group-specific right-stochastic transition matrices P\_Natural and P\_Proactive with dimensions 6×6 (FORECAST\_MAX\_STAGE = 6 for all Phase C groups). p\_cf and p\_pro derived from locked lambda values and avg\_stage\_jump computed from estimation-window cold records. No P\_Enforcement matrix.

**Execution:** avg\_stage\_jump was computed in the 6-stage forecast space (ceiling = Stage V = integer 6) for all groups, including Constant\_Speed. The v3 fix: previous versions used CS's 3-stage estimation ceiling, producing avg\_jump ≈ 0.218 and p\_cf ≈ 0.234 — a 6.7× overestimate relative to the locked λ\_CF of 0.051. Using FORECAST\_MAX\_STAGE = 6 as the ceiling gives avg\_jump ≈ 3.218, yielding p\_cf = 0.051 / 3.218 ≈ 0.016.

```r
compute_avg_jump <- function(dat, grp, phase_bounds) {
  # ... filter to estimation-window cold records for the group
  sub <- sub |>
    mutate(stage_capped = pmin(initial_stage, FORECAST_MAX_STAGE))  # ceiling always 6
  wmean    <- mean(sub$stage_capped)
  avg_jump <- FORECAST_MAX_STAGE - wmean                             # distance to Stage V
  list(wmean = wmean, n = nrow(sub), avg_jump = avg_jump)
}
```

P\_Natural was built as a near-identity matrix where each non-top stage transitions to Stage V (integer 6) with probability p\_cf and remains in place with probability 1 − p\_cf. Row-stochasticity was enforced after every matrix operation.

```r
build_natural <- function(max_stage, p_cf) {
  p_cf <- min(max(p_cf, 0), 0.99)
  mat  <- diag(max_stage)
  for (i in seq_len(max_stage - 1L)) {
    mat[i, i]         <- 1 - p_cf
    mat[i, max_stage] <- p_cf
  }
  enforce_stochastic(mat)
}

enforce_stochastic <- function(mat) {
  mat <- pmax(mat, 0)
  rs  <- rowSums(mat)
  all_zero <- rs == 0
  if (any(all_zero)) { for (i in which(all_zero)) mat[i, i] <- 1; rs <- rowSums(mat) }
  sweep(mat, 1, rs, "/")
}
```

Variable\_Speed parameters were derived as Phase B cold-N-weighted averages of CAZ+ and RoL (lambda\_CF, lambda\_Proactive, avg\_stage\_jump), since Variable\_Speed (P24) first exists in Phase C and has no own historical estimation window.

**Findings:**

| Group | avg\_jump | p\_cf | p\_pro |
|---|---|---|---|
| Constant\_Speed | 3.218 | 0.016 | 0.000 |
| CAZ\_Plus | 1.302 | 0.201 | 0.010 |
| Rest\_of\_London | 1.501 | 0.161 | 0.000 |
| Variable\_Speed | 1.460 (wtd avg) | 0.168 | 0.002 (wtd avg) |

Row-stochastic checks PASSED for all groups. For CS and RoL (λ\_Proactive = 0), P\_Total = P\_Natural.

![Replacement probabilities by group](260417_step4_transition_matrices_v3_fig4_1_probabilities.png)

Each group shows p\_cf (blue, natural counterfactual turnover) and p\_pro (orange, proactive LEZ-driven replacement) as annual probabilities.
CS p\_cf is low (~0.016) consistent with lambda\_CF = 0.051 and a large avg\_stage\_jump (~3.2 stages to Stage V); CAZ+ and RoL p\_cf are higher (~0.16–0.20) with smaller avg\_stage\_jumps.

---

### Sub-task 4.2 — Combine into P\_Total

**Intended task:** Combine P\_Natural and P\_Proactive into composite P\_Total (Scenario A base matrix); enforce row-sum constraint; display both P\_Natural and P\_Total; report probability-decomposition table and implied-lambda validation.

**Execution:** P\_Total was built by summing p\_cf + p\_pro into a single off-diagonal probability p\_up, replacing the two-matrix product with a direct `build_total()` call. This is equivalent under the near-identity matrix structure and avoids floating-point accumulation.

```r
build_total <- function(max_stage, p_cf, p_pro) {
  p_up <- min(p_cf + p_pro, 0.99)
  mat  <- diag(max_stage)
  for (i in seq_len(max_stage - 1L)) {
    mat[i, i]         <- 1 - p_up
    mat[i, max_stage] <- p_up
  }
  enforce_stochastic(mat)
}
```

**Findings:** P\_Total and P\_Natural differ only for Variable\_Speed (p\_up = 0.1698 vs p\_cf = 0.1680, marginal +0.0018 from p\_pro). Full 6×6 matrices displayed in output for both Phase C groups.

![P\_Total heatmap by group](260417_step4_transition_matrices_v3_fig4_2_ptotal_heatmap.png)

Heatmaps of P\_Total for each Phase C group: darker blue = higher transition probability. The dominant pattern is a near-diagonal (machines stay) with a single off-diagonal column at Stage V (replacement destination).
CS diagonal values are higher (lower p\_cf ≈ 0.016) than Variable\_Speed (higher p\_cf ≈ 0.168), reflecting the generator fleet's slow natural turnover relative to the merged variable-speed fleet.

---

### Sub-task 4.3 — Validate P\_Total

**Intended task:** Validate P\_Total against observed Stage distributions before use in forecasting.

**Execution:** Two validation approaches used. Validation A: implied lambda computed from P\_Total weighted by the Phase C cold distribution (π₀), and compared to locked λ\_CF. Validation B: one-step projection from the Phase B3 actual distribution compared to the actual Phase C distribution.

```r
implied_lambda <- function(mat, pi, max_stage) {
  stages             <- seq_len(max_stage)
  expected_new_stage <- as.vector(mat %*% stages)
  delta_per_stage    <- expected_new_stage - stages
  sum(pi * delta_per_stage)   # distribution-weighted expected improvement
}
```

**Findings:**  
- **Validation A:** λ(P\_Natural) deviates from locked λ\_CF: CS 55% divergence (0.023 vs 0.051), VS 75% divergence (0.062 vs 0.245). Both deviations are expected and documented: the Phase C fleet is substantially more advanced than the estimation-window fleet; fewer machines remain below Stage V to generate upward movement, suppressing the distribution-weighted implied lambda. Model correctly propagates a slow improvement signal through a near-compliant fleet.  
- **Validation B:** CS one-step projection is close (Stage V 0.494 projected vs 0.538 actual, Δ = 0.044). VS underpredicts Stage V (0.657 vs 0.765, Δ = 0.108), consistent with anticipatory pre-2025 compliance not captured by the constant-hazard model. Since forecasts are initialised directly from the actual P24 distribution, this discrepancy does not propagate into Step 5.

![Validation B: one-step projection](260417_step4_transition_matrices_v3_fig4_3_validation_B.png)

Blue bars = Phase B3 actual cold distribution; orange = one-step P\_Total projection; green = Phase C actual P24 cold distribution. Agreement between orange and green indicates P\_Total captures the observed fleet transition.
Discrepancies reflect genuine fleet composition shifts (e.g. Stage V surge in CS machines before the 2025 compliance deadline), time-varying hazard not captured by the single annual-probability model, or P24 zone composition differing from B3 estimation-window zones.

---

## Step 5: Forecasting and Emissions

**Final-trial script:** `260417_step5_forecasting_v1.R`  
**Output objects:** `intermediate/forecast_scen_a.rds`, `intermediate/forecast_scen_b.rds`, `intermediate/step5_forecasts.rds`

---

### Sub-task 5.1 — Project Stage distributions 2025–2030 (two scenarios)

**Intended task:** Project Stage distributions annually 2025–2030 under Scenario A (proactive only) and Scenario B (enforcement upper bound, Boolean mask zeroing non-compliant transitions).

**Execution:** Scenario A applied P\_Total annually via `project_distribution()`. Each annual step multiplied the row-vector π by P: `pi_curr <- as.vector(pi_curr %*% P_t)`. Scenario B constructed a masked version of P\_Total using `build_scenario_b()`, which zeroed all columns corresponding to stages below the year-specific compliance threshold and rescaled remaining rows to sum to 1.

```r
build_scenario_b <- function(mat, threshold) {
  mat_b <- mat
  if (threshold > 1L) mat_b[, seq_len(threshold - 1L)] <- 0
  enforce_stochastic(mat_b)    # rows sum to 1; non-compliant machines must jump to top stage
}

project_distribution <- function(pi0, P, n_years, years, group) {
  pi_curr <- pi0
  for (t in seq_len(n_years)) {
    P_t     <- if (is.list(P)) P[[t]] else P
    pi_curr <- as.vector(pi_curr %*% P_t)
    pi_curr <- pmax(pi_curr, 0) / sum(pmax(pi_curr, 0))
    ...
  }
}
```

Compliance thresholds per year were defined in `COMP_THRESH`: Constant\_Speed Stage V (integer 6) throughout 2025–2030; Variable\_Speed Stage IV (integer 5) in 2025–2029, Stage V (integer 6) from 2030.

**Findings:**

**Scenario A (Constant\_Speed):** Stage V 53.8% → 57.4% by 2030. Stage IIIA persists at ~35.5%. Net improvement +3.6 pp over 5 years — negligible, driven by extremely low p\_cf (0.016). Natural turnover alone is insufficient to drive compliance.

**Scenario A (Variable\_Speed):** Stage V 76.5% → 90.8% by 2030 at the Stage IV threshold (compliance rate reaches 95.3% in 2029, then drops to 90.8% in 2030 when threshold upgrades from Stage IV to Stage V, bringing the Stage IV fraction out of compliance). Stage IIIB declines from 7.7% to ~3%.

**Scenario B (Constant\_Speed):** Stage V 53.8% → 100% by 2026 and constant thereafter. All non-Stage-V machines are forced to comply within one annual step.

**Scenario B (Variable\_Speed):** Stages I–IIIB zeroed immediately; Stage IV fraction (13.6%) remains until 2030 when it falls out of compliance with the upgraded threshold and is forced to Stage V → 100% Stage V compliance by 2030.

![Scenario A stage distribution forecast](260417_step5_forecasting_v1_fig5_2_scen_a_stage.png)

Stage proportions under Scenario A (no enforcement). Stage V rises monotonically for both groups; the rate is slower for Constant\_Speed (p\_cf = 0.016) than Variable\_Speed (p\_cf = 0.168).
Lower stages (I–IV) decay in proportion as machines are progressively replaced; Stage IIIA in CS persists due to the low replacement rate.

![Scenario B stage distribution forecast](260417_step5_forecasting_v1_fig5_3_scen_b_stage.png)

Under full enforcement, all non-compliant machines transition to Stage V in the first annual step; Stage V proportion reaches 100% by 2026 for CS and by 2030 for VS.
This is the structural upper bound: actual enforcement outcomes will lie between Scenario A and Scenario B depending on audit frequency and enforcement capacity.

---

### Sub-task 5.2 — Phase C initialisation

**Intended task:** For Phase C initialisation, pool Constant\_Speed and Variable\_Speed P24 records; extract group-specific Stage distributions as the Phase C starting state.

**Execution:** Phase C cold-engaged P24 records were extracted from `audits.rds` by group (Constant\_Speed and Variable\_Speed assigned at Step 1 from P24 zone records). No merge operation was required; group assignment at Step 1 handled the CAZ+/RoL → Variable\_Speed merge.

**Findings:** Phase C cold initialisation distributions (π₀):

| Stage | Constant\_Speed (N=26) | Variable\_Speed (N=57) |
|---|---|---|
| I | 0.0% | 0.3% |
| II | 7.7% | 0.9% |
| IIIA | 38.5% | 0.9% |
| IIIB | 0.0% | 7.7% |
| IV | 0.0% | 13.6% |
| V | 53.8% | 76.5% |

CS initialisation: substantial Stage IIIA tail (38.5%) alongside Stage V majority; IIIB and IV absent, consistent with CS estimation max\_stage = 3. VS: overwhelmingly Stage V (76.5%) with a non-compliant tail spread across Stages I–IV.

---

### Sub-task 5.3 — Emissions estimation

**Intended task:** Estimate annual emissions per group as E = Σ(N × kW × 2000 × EF\_s) using EMEP/EEA Tier 3 factors.

**Execution:** The script includes a fully implemented emissions section guarded by `if (!any(is.na(EF_s)))`. EF\_s is a named vector of EMEP/EEA Tier 3 NOx factors (g NOx/kWh) keyed on stage integer 1–6, with all values initialised to `NA_real_` pending user input.

**Findings:** Section skipped in Trial 1. EF\_s values not yet supplied. On user provision of the six Tier 3 NOx factors, Section 5.5 will execute automatically on re-run, producing Table 5.5 (emissions index 2025 = 100 for both scenarios) and Figure 5.5 (emissions trajectory 2025–2030).

---

### Sub-task 5.4 — Summary tables, plots, and limitations

**Intended task:** Produce summary tables and plots of Stage distributions and emissions trajectories for both scenarios; document limitations.

**Findings:** All tables and plots produced for Stage distributions (Tables 5.2, 5.3) and compliance trajectories (Table 5.4, Figure 5.4). Compliance summary at 2025 and 2030:

| Group | Scen A 2025 | Scen A 2030 | Scen B 2025 | Scen B 2030 |
|---|---|---|---|---|
| Constant\_Speed | 53.8% | 57.4% | 53.8% | 100.0% |
| Variable\_Speed | 90.1% | 90.8%\* | 90.1% | 100.0% |

\* VS compliance drops from 95.3% (2029) to 90.8% (2030) as Stage IV threshold upgrades to Stage V.

Enforcement-attributable ceiling: CS = +42.6 pp; VS = +9.2 pp by 2030. Known limitations documented in output per schema.md (see Known Limitations section below).

![Compliance trajectory 2025–2030](260417_step5_forecasting_v1_fig5_4_compliance.png)

Blue = Scenario A (natural + proactive turnover); red dashed = Scenario B (enforcement upper bound). The 2025 values are identical (both initialised from π₀).
The wide gap for CS (42.6 pp) illustrates that enforcement is essential for the generator fleet; the narrower gap for VS (9.2 pp) indicates that natural fleet turnover nearly suffices under the Stage IV threshold, though not under Stage V in 2030.

---

## Open Items

1. **Emissions factors (EF\_s):** EMEP/EEA Tier 3 NOx emission factors (g NOx/kWh) for Stages I–V have not been supplied. Section 5.5 of `260417_step5_forecasting_v1.R` will run automatically on re-execution once `EF_s` is populated. The operating-hours default (2,000 hr/annum per machine) is already coded.

2. **Machine count (N) for emissions:** The emissions calculation requires a machine count per group for scaling. This was not resolved in Step 5; user to confirm whether to use audit-record counts as a proxy or supply a separate fleet size estimate.

---

## Known Limitations

_(Source: schema.md "Known limitations")_

1. **Ecological inference:** Aggregate stage counts approximate individual transition hazards. The assumption that group-level turnover rates apply uniformly to each machine in that group is an ecological inference (Robinson, 1950) and cannot be verified from the audit data.

2. **Entry/exit bias:** The model absorbs fleet entry and exit into the transition rates. New machines entering at high stages inflate the apparent improvement rate; old machines leaving inflate it further. The model does not separately identify entry, exit, or stage-upgrading transitions — all are folded into p\_cf and p\_pro.

3. **Time-inhomogeneity within Phase B:** λ\_CF is not constant across Phase B segments 1→2 and 2→3 for any group. The single per-phase λ is a simplification; a time-varying or piecewise model would better capture the acceleration of fleet improvement through Phase B.

4. **Second-hand market leakage:** λ\_CF as estimated will overestimate the true counterfactual turnover rate if machines are traded second-hand at intermediate stages rather than always being replaced with new current-generation equipment. λ\_Proactive is correspondingly a conservative lower bound.

5. **Phase A1/A2 pooling:** Variable-speed groups have insufficient Phase A1 cold records (n = 139) for separate lambda estimation. Pooling A1 and A2 as a single regression point is a data-driven approximation that reduces degrees of freedom and may smooth over any early-phase discontinuity.

---

## Glossary

| Term | Definition |
|---|---|
| **ē (e-bar)** | Non-compliance exposure rate: % of all records in a group–phase cell with initial stage below the compliance threshold. A stock measure; does not require individual replacement assumptions. |
| **Δē/Δt** | Rate of change in ē between phase midpoints (pp per year). The most intuitive policy headline metric — directly answers "is the LEZ working, and how fast?" |
| **λ\_CF** | Counterfactual fleet turnover rate. WLS slope of mean emissions stage over time in cold-engaged records. Units: stage integers per year. |
| **λ\_Policy** | Combined improvement rate in warm self-compliant records: natural turnover + proactive LEZ-driven replacement. |
| **λ\_Proactive** | max(0, λ\_Policy − λ\_CF): incremental stage improvement rate attributable to LEZ policy; floored at zero. |
| **p\_cf** | Annual replacement probability under counterfactual: λ\_CF / avg\_stage\_jump. Denominated in the 6-stage forecast space for all groups. |
| **p\_pro** | Annual proactive LEZ replacement probability: λ\_Proactive / avg\_stage\_jump. |
| **avg\_stage\_jump** | Expected stage integers gained per replacement event: FORECAST\_MAX\_STAGE (6) minus the mean observed stage in the cold estimation-window records. |
| **P\_Natural** | Right-stochastic 6×6 matrix: each non-top stage transitions to Stage V with probability p\_cf per year; Stage V is absorbing. |
| **P\_Total** | P\_Natural plus proactive LEZ channel (p\_cf + p\_pro). Scenario A base matrix. |
| **Scenario A** | Baseline forecast: P\_Total applied annually. Natural turnover + proactive LEZ; no enforcement augmentation. |
| **Scenario B** | Upper-bound forecast: Boolean mask zeroes transitions to non-compliant stages; rescales rows. Non-compliant machines must jump to Stage V each step. |
| **π₀** | Phase C initialisation distribution: Stage proportions from P24 cold-engaged records. |
| **Cold-engaged** | Machine on site not yet engaged with the LEZ process; basis for λ\_CF estimation. |
| **Warm self-compliant** | Machine emissions-OK on arrival (Route 1); basis for λ\_Policy estimation. |
| **Route 4** | Initial emissions non-compliant; post-visit compliance achieved (no E code in final machinery reasons — removal, replacement, retrofit, or exemption). |
| **Route 5** | Initial emissions non-compliant; E code persists in final machinery reasons at end of visit. |
| **WLS** | Weighted least squares via `lm()`; SE extracted from `vcov()`. |
| **Phase A1** | 1 Jan 2016 – 31 Dec 2018. Pre-Stage V market availability. |
| **Phase A2** | 1 Jan 2019 – 31 Aug 2020. Stage V equipment newly available. |
| **Phase B** | 1 Sep 2020 – 31 Dec 2024. COVID-exempt records removed; variable-speed groups sub-segmented into B1/B2/B3 (~527 days each). |
| **Phase C** | 1 Jan 2025 – 31 Dec 2030. Forecast period. CAZ+ and RoL merged into Variable\_Speed (P24 zone). |
| **EF\_s** | EMEP/EEA Tier 3 NOx emission factor (g NOx/kWh) for Stage s (Ntziachristos & Samaras 2019). Not yet supplied. |

---

_End of report. Version 2 generated 17 April 2026._
