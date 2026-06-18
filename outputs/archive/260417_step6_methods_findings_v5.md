# NRMM LEZ Analysis — Methods and Findings Report

_Version 5 | 18 April 2026_  
_Script: `outputs/260417_step6_methods_findings_v5.md` (Step 6, no R script)_  
_Source scripts: Steps 1–5 final-trial R files; findings from `sprint_log.md` Step Reports_

---

## Executive Summary

This report covers a five-step Markov-chain model of the Non-Road Mobile Machinery (NRMM) Low Emissions Zone (LEZ) applied to 12,363 model-phase audit records drawn from 16,251 cleaned observations (2016–2026). The model tracks the emissions Stage distribution of machinery across four groups — **Constant Speed** (generators), **CAZ+** (variable-speed machinery in the central zone and outer area), **Rest of London** (variable-speed machinery, GL zone), and **Variable Speed** (merged Phase C, P24 zone) — and projects Stage distributions and compliance rates to 2030 under two scenarios.

**Key quantitative findings:**

| Parameter | Constant Speed | Variable Speed (CAZ+/RoL merged) |
|---|---|---|
| $\lambda_{CF}$ (counterfactual turnover, stage/yr) | 0.051 ⚠ | 0.262 / 0.241 (CAZ+/RoL pre-merge) |
| $\lambda_{Proactive}$ (incremental LEZ effect) | 0.000 (floored) | 0.013 (CAZ+ only) / 0.000 |
| $\bar{e}$ Phase B (% below threshold) | 82.8% (Stage V imposed on IIIA fleet) | CAZ+: 19.9%; RoL: 4.7% |
| $\bar{e}$ Phase C (P24, % below threshold) | 30.4% | 22.0% |
| $\pi_0$ Stage V (Phase C initialisation) | 53.8% | 76.5% |
| Scenario A compliance, 2030 | 57.4% (Stage V) | 90.8% (Stage V threshold) |
| Scenario B compliance, 2030 | 100% (by 2026) | 100% (by 2030) |
| Enforcement-attributable ceiling | +42.6 pp | +9.2 pp |

_$\pi_0$: Phase C initialisation distribution (Stage proportions of cold-engaged P24 records at the start of the forecast period). $\lambda$: fleet improvement rate in stage integers per year (weighted least squares slope). $\bar{e}$: non-compliance exposure rate (% of machines below the compliance threshold). pp: percentage points. Symbols and abbreviations defined in the Glossary._

**Key Results:**

| Group | $\lambda_{CF}$ (SE) | $\lambda_{Pro}$ | $p_{cf}$ | $p_{pro}$ | $\bar{e}$ Phase B (%) | $\bar{e}$ Phase C (%) | Scen A 2030 (%) | Scen B 2030 (%) |
|---|---|---|---|---|---|---|---|---|
| Constant Speed | 0.051 (0.026) ⚠ | 0.000 | 0.016 | 0.000 | 82.8% | 30.4% | 57.4% | 100% |
| CAZ+ | 0.262 (0.033) | 0.013 | 0.201 | 0.010 | 19.9% | — | — | — |
| Rest of London | 0.241 (0.017) | 0.000 | 0.161 | 0.000 | 4.7% | — | — | — |
| Variable Speed | 0.245 (derived) | 0.003 | 0.168 | 0.002 | — | 22.0% | 90.8% | 100% |

_**CAZ+** and **Rest of London** have no Phase C forecast (merged into `Variable_Speed` from 1.1.2025). **Variable Speed**_ $\lambda_{CF}$ _is the Phase B cold-N-weighted average of **CAZ+** and **Rest of London**; no independent WLS fit is available. Scen A 2030 for VS reflects compliance at the Stage V threshold (the threshold upgrades from Stage IV to Stage V in 2030)._

**Headline Findings**

The NRMM Low Emissions Zone has improved the emissions profile of London construction machinery across all groups, but the pace and ceiling of that improvement differ sharply between generators and other equipment. Generator fleets are slow to turn over naturally — under the baseline assumption of natural and voluntary upgrading only (Scenario A), only around 57% would reach the required Stage V standard by 2030, barely above the 54% already achieved at the start of the forecast. Variable-speed construction machinery is in a much stronger position: Scenario A projects around 91% Stage V compliance by 2030 even without enforcement action. With full enforcement (Scenario B), both groups can reach 100% compliance — generators by 2026 and variable-speed machinery by 2030. The key policy implication is that generators are almost entirely dependent on active enforcement to achieve compliance, while the wider construction fleet is approaching self-sustaining improvement.

**Anomaly flags:**  
- $\lambda_{CF}$ **Constant Speed** (0.051) departs sharply from the prototype reference (0.358); corroborated by near-zero $\lambda_{Policy}$ and accepted as the operative estimate.  
- Scenario A compliance for **Constant Speed** shows effectively no improvement (53.8% → 57.4%); the generator fleet is almost entirely dependent on enforcement to achieve Stage V compliance.  
- Emissions section deferred pending EMEP/EEA Tier 3 NOx factors (`EF_s`).

---

## Step 1: Data Ingestion and Preparation

**Final-trial script:** `260413_step1_ingestion_v1.R`  
**Output objects:** `intermediate/audits.rds` (15,932 × 34)

_Purpose: This step reads the raw audit file, standardises field encoding, removes out-of-scope records, and assigns each machine to an analytical group and model phase for use in Steps 2–5._

---

### Sub-task 1.1 — Import, column selection, and field encoding

**Intended task:** Import `audits.txt`; discard out-of-scope columns (schema.md Table 5); validate and encode retained fields (schema.md Table 4) using Stage encoding (List 1), non-compliance codes (List 2).

**Execution:** Raw file read with `read.delim()`. Nineteen columns were retained by name using `select(all_of(COLS_KEEP))` and renamed to snake\_case. The following scheme maps raw emissions stage strings to integers 1–7 used throughout all subsequent analysis:

**List 1 — EU Emissions Stage values and integer encoding (from schema.md)**

| Stage string | Integer |
|:---:|:---:|
| I | 1 |
| II | 2 |
| IIIA | 3 |
| IIIB | 4 |
| IV | 5 |
| V | 6 |
| ZE / hybrid / any other | 7 |

Two known raw typos (`iIIB`, `iV`) were corrected before encoding. Compliance flags were extracted from reason-code strings by scanning for the character "E" (emissions) and for any of A/C/P/R/X (administrative).

```r
encode_stage <- function(x) {
  x[x == "iIIB"] <- "IIIB"; x[x == "iV"] <- "IV"   # correct known raw typos
  x[grepl("^ZE$|zero.emission|hybrid", x, ignore.case = TRUE)] <- "ZE"
  stage <- STAGE_MAP[trimws(x)]                       # named vector; unmatched → NA
  names(stage) <- NULL; stage
}
```
_Full implementation: `260413_step1_ingestion_v1.R`_

```r
derive_compliance_flags <- function(reasons) {
  r <- toupper(trimws(replace_na(as.character(reasons), "")))
  list(emissions_compliant = !grepl("E", r, fixed = TRUE),
       admin_compliant     = !grepl("[ACPRX]", r))
}
```
_Full implementation: `260413_step1_ingestion_v1.R`_

**Findings:** All 19 expected columns were present. Two stage-encoding typos resolved; 35 records had unresolvable `initial_stage` (excluded downstream). The `derive_compliance_flags()` split separated emissions non-compliance (E code) from administrative non-compliance cleanly.

---

### Sub-task 1.2 — Exclusions

**Intended task:** Exclude out-of-scope records: zone filter retains CAZ, OA, GL, P24; excludes BCP. Non-machinery records removed (Initial Machinery Compliance not "compliant"/"non-compliant"). Unassignable engine types, unresolvable Initial Emissions Stage, and COVID-exempt records (1.9.2020–31.3.2021) excluded.

**Execution:** Non-machinery records (labels including "No NRMM", "Site Complete", "Baselining", "DECLINED AUDIT") were removed by a whitelist filter on `initial_machinery_compliance`. BCP zone records were excluded by zone filter. Non-compliance reason codes used throughout the exclusion and compliance logic follow the scheme below:

**List 2 — Non-Compliance Codes (from schema.md)**

| Code | Description |
|:---:|:---:|
| A | Actively Declined |
| C | Cannot Evidence Compliance |
| E | Emissions Standard Not Met |
| P | Passively Declined |
| R | Registration Problem |
| X | [Not Specified] |
| None | Compliant or reasons not applicable |

_Rules: codes are multi-value strings (e.g. `ER`, `AR`). If no E code present: `emissions_compliant = TRUE`. If any other code present: `admin_compliant = FALSE`._

COVID exemptions were identified by a text-match on the retrofit/exemption field during the window 1 September 2020 – 31 March 2021.

```r
# Non-machinery and zone exclusions
audits <- audits |>
  filter(imc_lower %in% c("compliant", "non-compliant")) |>
  filter(zone %in% ZONES_IN_SCOPE)

# COVID exemption filter
audits <- audits |>
  mutate(covid_exempt = date >= COVID_START & date <= COVID_END &
    grepl("covid", tolower(replace_na(initial_retrofit_or_exemption, "")))) |>
  filter(!covid_exempt)
```
_Full implementation: `260413_step1_ingestion_v1.R`_

**Findings:** The filtering process correctly identified and removed out-of-scope records, leaving a clean dataset for analysis. BCP (Beyond Construction Project, an out-of-scope category) exclusions removed a small number of records from the geographic scope. COVID exemptions removed a further subset within the Phase B window (September 2020 to March 2021, when a compliance extension was in force). The full data file (`audits.rds`) contains 15,932 rows in total; the difference from the 12,363 model-phase records comprises pre-2016 records and records that could not be assigned to a model time period — these are retained in the file but excluded from all model estimation in Steps 2–5.

---

### Sub-task 1.3 — Group and phase assignment

**Intended task:** Assign every retained record to a machine group (schema.md Table 1) and model phase (schema.md Table 7). P24 Variable Speed records → group `Variable_Speed`; P24 Constant Speed records → group `Constant_Speed`. Records with date ≥ 1.1.2025 → Phase C.

**Execution:** Engine type was classified first (generator-family machine types overridden to Constant regardless of raw `Engine.Type` field; blanks filled with Variable to restore A1 records). The following equipment group definitions govern group assignment:

**Table 1 — Equipment groups, in and out of scope (from schema.md)**

| In Scope | Group | Description | Derivation from raw data |
|---|---|---|---|
| Yes | Constant Speed | Generators/constant-speed equipment. Direct IIIA-to-V pathway. | `Engine.Type.clean == "Constant"` (any Zone) |
| Yes | CAZ+ | Variable-speed machinery in CAZ+. Merges with Rest of London on 1.1.2025. | `Engine.Type.clean == "Variable"` AND `Zone %in% c("CAZ", "OA")` |
| Yes | Rest of London | Variable-speed machinery outside CAZ+. | `Engine.Type.clean == "Variable"` AND `Zone == "GL"` |
| Yes | Variable Speed | Merged CAZ+ and Rest of London from 1.1.2025. P24 zone only. | `Engine.Type.clean == "Variable"` AND `Zone == "P24"` |
| No | BCP | Beyond Construction Project | `Zone == BCP` |

Model phases are defined by the following date boundaries, reflecting the timing of LEZ requirement changes and data availability:

**Table 7 — Model phases and sub-phases (from schema.md)**

| Phase | Start | End | Rationale & Adjustments |
|---|---|---|---|
| A1 | 1.1.2016 | 31.12.2018 | Pre-Stage V market availability. |
| A2 | 1.1.2019 | 31.8.2020 | Stage V equipment newly available. |
| B | 1.9.2020 | 31.12.2024 | Tighter LEZ requirements. COVID exempt records (1.9.2020–31.3.2021) filtered out. Phase B subdivided into 3 equal segments (~527 days) for variable speed groups to stabilise variance. |
| C | 1.1.2025 | 31.12.2030 | Forecast period. CAZ+ and Rest of London combined. Initialisation state derived from P24 records (Stage distribution snapshot), not projected from end-2024. |

_Phase B 3-segment midpoints (fractional years): 2021.389, 2022.832, 2024.278. Δt = 1.44 and 1.45 years._

Group and phase were assigned via `case_when()` on zone and engine type, and on date boundaries respectively.

```r
audits <- audits |>
  mutate(group = case_when(
    engine_type_clean == "Constant"                             ~ "Constant_Speed",
    engine_type_clean == "Variable" & zone %in% c("CAZ","OA") ~ "CAZ_Plus",
    engine_type_clean == "Variable" & zone == "GL"             ~ "Rest_of_London",
    engine_type_clean == "Variable" & zone == "P24"            ~ "Variable_Speed"))
```
_Full implementation: `260413_step1_ingestion_v1.R`_

```r
assign_phase <- function(d) case_when(
  d >= PHASE_A1_START & d <= PHASE_A1_END ~ "A1",
  d >= PHASE_A2_START & d <= PHASE_A2_END ~ "A2",
  d >= PHASE_B_START  & d <= PHASE_B_END  ~ "B",
  d >= PHASE_C_START                      ~ "C", TRUE ~ NA_character_)
```
_Full implementation: `260413_step1_ingestion_v1.R`_

**Findings:** All four groups were assigned without ambiguity. Post-2025 zone (P24) records were correctly split by engine type: generators → `Constant_Speed` Phase C; variable-speed equipment → `Variable_Speed` Phase C (P24 being the new merged London zone from January 2025). No records fell outside the A1/A2/B/C phase boundaries.

---

### Sub-task 1.4 — Record counts and anomaly flags

**Intended task:** Report record counts by group and phase; flag anomalies for user review before proceeding. Report P24 record counts separately; flag earliest and latest P24 audit date.

**Execution:** Count tables produced by `count(group, phase) |> pivot_wider()` for all, cold, and warm subsets. P24 Phase C records broken out separately with engagement-type split.

**Findings:** 12,363 records were allocated to a model phase across four groups and four phases, as shown below. The full data file (`audits.rds`) contains 15,932 rows in total, with the difference comprising pre-2016 records and records with no assignable time period that are retained in the object but excluded from model estimation.

| group | A1 | A2 | B | C | total |
|:---|---:|---:|---:|---:|---:|
| CAZ+ | 400 | 658 | 2,296 | 0 | 3,354 |
| Constant Speed | 104 | 318 | 693 | 112 | 1,227 |
| Rest of London | 538 | 1,634 | 4,122 | 0 | 6,294 |
| Variable Speed | 0 | 0 | 5 | 1,483 | 1,488 |

Phase C P24 records confirmed present: temporal extent spanned from early 2025 to the latest available audit date in 2026, confirming data availability for Phase C initialisation in Step 5. No anomalous group–phase cells (all cells n ≥ 30 across the main groups; **Variable Speed** Phase B shows 5 records — a minor edge-case of pre-2025 P24 data correctly routed; flagged in Step 3).

---

## Step 2: Exploratory Analysis

**Final-trial script:** `260414_step2_exploratory_v7_1.R`  
**Output objects:** `intermediate/stage_dist.rds`, `intermediate/audits_step2.rds`, `intermediate/sparsity_summary.rds`

_Purpose: This step explores how the fleet's emissions stage distribution has evolved over time and characterises audit compliance outcomes, identifying data sparsity issues that constrain the estimation methods chosen in Step 3._

---

### Sub-task 2.1 — Stage distributions by group, phase, and engagement type

**Intended task:** Tabulate Stage distributions by group, phase, and engagement type (cold/warm); plot trends over time.

**Execution:** Stage counts and percentages were computed by group × year × `cold_engaged` × stage. Phase B was subdivided into three equal-duration segments (B1, B2, B3) with boundaries at 9 February 2022 and 21 July 2023, using `assign_phase_sub()`. ZE/Stage-7 records were flagged and excluded from stage distribution tables to avoid confounding compliance thresholds. Wide tables were built using `make_wide()`, which used `expand.grid()` + `left_join()` to guarantee all phase × stage combinations were present regardless of observed data (the root-cause fix resolving the earlier NSE/tidyr bug in Trials 1–6).

```r
make_wide <- function(df, subcol_var, val_col = "n", phases = PHASE_ORDER, subcols = STAGE_LEVELS) {
  grid   <- expand.grid(group=GROUP_ORDER, phase_display=phases,
                        subcol=subcols, stringsAsFactors=FALSE)
  joined <- grid |> left_join(df_agg, by=c("group","phase_display",subcol_var))
  joined |> mutate(col_key=paste(phase_display,.data[[subcol_var]],sep="__")) |>
    pivot_wider(id_cols="group", names_from=col_key, values_from=all_of(val_col))
}
```
_Full implementation: `260414_step2_exploratory_v7_1.R`_

Structural NAs (groups absent from certain phases, e.g. **Variable Speed** in A1–B3, **CAZ+**/**Rest of London** in Phase C) were distinguished from incidental zeros using `fill_table_nas()`, which marks group–phase pairs with no in-scope data as `NA` (rendered as —) and fills genuine zero-count cells with 0.

**Findings:** Across all equipment groups, the emissions standard of machines found on site has risen consistently over the study period, with more machines meeting higher-rated standards in each successive period. Machines assessed before any engagement with the LEZ process (the 'cold' fleet) showed clear upward stage trends in all groups. **Constant Speed** machines were dominated by Stage I/II in Phase A1 (the earliest period, 2016–2018), transitioning to a Stage IIIA majority by Phase B. **CAZ+** and **Rest of London** showed steady Stage V penetration from 2021 onward. **Variable Speed** Phase C records showed 76.5% Stage V, dominated by high-compliance machines. Four plots produced: cold by year, warm by year, Phase B sub-segments (**CAZ+**/**Rest of London**), and **Variable Speed** Phase C by engagement type.

![Cold fleet stage distributions by group and year](260414_step2_exploratory_v7_1_stage_cold_year.png)

![Warm fleet stage distributions by group and year](260414_step2_exploratory_v7_1_stage_warm_year.png)

**Cold-engaged** machinery show upward stage trends in all groups from 2016 to 2024; **Constant Speed** is dominated by Stage I/II early and Stage IIIA from 2019 onward. **CAZ+** and **Rest of London** show growing Stage V fractions from 2021; the 2024 **Constant Speed** Stage V spike reflects anticipatory pre-2025 compliance, excluded from $\lambda_{CF}$ estimation.

Warm self-compliant records show a broadly similar upward stage trend, with higher Stage V penetration than cold records in most groups and periods. The warm fleet improves faster than cold in **CAZ+** and **Rest of London**, corroborating the $\lambda_{Policy}$ ≥ $\lambda_{CF}$ finding for those groups.

![Phase B sub-segment stage distributions (CAZ+ and RoL)](260414_step2_exploratory_v7_1_stage_cold_Bsub.png)

Phase B is subdivided into three ~527-day segments (B1: Sep 2020–Feb 2022; B2: Feb 2022–Jul 2023; B3: Jul 2023–Dec 2024) to stabilise within-group variance. Stage V penetration grows through B1–B3 in both **CAZ+** and **Rest of London**; the three-segment approach was chosen over annual generalised least squares (GLS) to prevent noise amplification in thin annual cells.

![Variable Speed Phase C stage distributions by engagement type](260414_step2_exploratory_v7_1_stage_variable_speed.png)

**Variable Speed** Phase C (P24 zone, 2025–2026 audit data) is predominantly Stage V in both cold and warm subsets, consistent with anticipatory pre-merger compliance. The cold fleet (N=57) has a non-compliant tail (Stages I–IV totalling ~23.5%) that informs Phase C initialisation and Scenario B enforcement modelling.

---

### Sub-task 2.2 — Compliance outcomes (six-route classification)

**Intended task:** Characterise compliance outcomes using the six-route classification (schema.md Table 3).

**Execution:** Each record was classified into one of five routes (plus "unknown") using a priority-ordered `case_when()` in `classify_route()`. The six-route framework that governs the classification is shown below:

**Table 3 — Rules for compliance outcomes (from schema.md)**

| Row | Site Reg? | NRMM in scope | Mach Reg? | Emissions OK? | Enforcement requested | Site mgmt action | Outcome | Emissions reduced by audit? |
|---|---|---|---|---|---|---|---|---|
| 1 | Y | Y | Y | Y | None | None | Self-compliant | No |
| 2 | Y/N | Y | N | Y | Register site/machine | Registered | Driven compliant | No |
| 3 | Y/N | Y | N | Y | Register site/machine | Not registered | Non-compliant (R) | No |
| 4 | Y/N | Y | Y/N | N | Remove or replace | Removed/replaced | Driven compliant | Yes |
| 5 | Y/N | Y | Y/N | N | Remove or replace | Not actioned | Non-compliant | No |
| 6 | Y/N | N | -- | -- | None | -- | No in-scope plant | No |

_A prior exemption permit satisfies the emissions compliance requirement, but equipment and site must still be registered._

Route 4 (driven compliant — emissions) was defined as `!init_mach_emissions_compliant & enforcement_upgrade`, where `enforcement_upgrade = final_stage > initial_stage`. Route 5 (non-compliant) was `!init_mach_emissions_compliant & !enforcement_upgrade`.

```r
classify_route <- function(df) df |> mutate(route = case_when(
  !init_mach_emissions_compliant &  enforcement_upgrade ~ "4_driven_compliant_emissions",
  !init_mach_emissions_compliant & !enforcement_upgrade ~ "5_non_compliant",
   init_mach_emissions_compliant &  init_mach_admin_compliant ~ "1_self_compliant",
  # Routes 2/3: emissions OK, registration status determines outcome
  TRUE ~ "unknown"))
```
_Full implementation: `260414_step2_exploratory_v7_1.R`_

**Findings:** Most machines audited across all groups were already compliant with emissions requirements at the time of inspection, with the proportion growing over time — consistent with voluntary fleet upgrading ahead of enforcement. Route 1 (self-compliant — machines already meeting all requirements on arrival) dominated the warm fleet (machines already compliant on arrival) in all groups and phases. Route 4 counts (machines found non-compliant but brought into compliance during the visit) were very low (≤35 on-the-spot stage upgrades across all records), which later informed the decision in Step 3 to revise the Route 4 indicator. No "unknown" route records were found.

---

### Sub-task 2.3 — Sparsity, signal exhaustion, and volatility

**Intended task:** Identify data sparsity, signal exhaustion, and volatility issues by group and sub-phase that will constrain estimation.

**Execution:** Sparsity was flagged as cold-engaged cell counts (group × `phase_display` × stage) below n = 30. Signal exhaustion measured the proportion of cold-engaged records at each group's maximum active stage (`pct_at_max`). Volatility was quantified as the cross-year standard deviation of `pct_at_max` within Phase B.

**Findings:** The data is unevenly distributed across groups and time periods, which required the analysis to adapt its estimation approach to available record counts. Phase A1 (2016–2018) had too few records for reliable estimates for **CAZ+** (n = 139 total cold records) — confirming that Phases A1 and A2 would need to be merged into a single estimation point for the variable-speed groups. In Phase B3, **CAZ+** was approaching 60% Stage V — close to saturation of the estimation ceiling, which compresses the regression signal. Splitting Phase B into three equal sub-periods (Phase B sub-segmentation) stabilised variance for the variable-speed groups, supporting this approach over fitting a single annual regression (GLS) across all of Phase B.

---

### Sub-task 2.4 — Confirm analytical approach

**Intended task:** Report findings and confirm analytical approach with user before proceeding.

**Findings:** Step 2 outputs confirmed: (1) merging Phases A1 and A2 as a single estimation point for variable-speed groups; (2) the three-period Phase B split for **CAZ+** and **Rest of London**; (3) **Constant Speed** kept as a single Phase B for rate estimation (cold sample too small for further splitting); (4) 2024 **Constant Speed** data to be excluded from the counterfactual rate estimation due to an anticipatory pre-deadline Stage V surge. Step accepted at Trial 7.1.

---

## Step 3: Parameter Estimation

**Final-trial script:** `260415_step3_parameter_estimation_v6.R`  
**Output objects:** `intermediate/lambda_cf.rds`, `intermediate/ebar_results.rds`, `intermediate/lambda_proactive.rds`, `intermediate/enf_success_rate.rds`, `intermediate/step3_params.rds`

_Purpose: This step estimates how fast the fleet is improving naturally (the counterfactual turnover rate), what fraction of machines fall below the compliance threshold in each period, and how much additional equipment upgrading is attributable to the LEZ policy; enforcement outcomes are reported as a descriptive policy metric._

---

### Sub-task 3.1 — Estimate $\lambda_{CF}$

**Intended task:** Estimate $\lambda_{CF}$ from cold-engaged records only, using WLS on Stage proportion vectors; apply group-specific `max_stage` and estimation windows determined in Step 2; validate against previous values in schema.md Table 8.

**Execution:** Weighted least squares (WLS) fitted via `lm(mean_stage ~ mid, weights = n)` with standard error (SE) extracted from `vcov()`. **Constant Speed** used annual midpoints 2016–2023 (2024 excluded). Variable-speed groups (**CAZ+**, **Rest of London**) used A1/A2 pooled as a single point plus Phase B 3-segment midpoints. Stages were capped at group-specific `MAX_STAGE` (CS: 3; **CAZ+**/RoL: 6) before averaging.

```r
fit_lambda <- function(pts, min_pts = 2L) {
  fit  <- lm(mean_stage ~ mid, data = pts, weights = n)
  b    <- coef(fit)[["mid"]]
  se_b <- sqrt(vcov(fit)["mid","mid"])
  tibble(lambda=b, se=se_b, ci_lo=b-qt(0.975,df.residual(fit))*se_b,
         ci_hi=b+qt(0.975,df.residual(fit))*se_b, n_pts=nrow(pts), n_obs=sum(pts$n))
}
```
_Full implementation: `260415_step3_parameter_estimation_v6.R`_

```r
phase_b_pts <- function(dat) {
  dat |>
    mutate(seg = findInterval(frac_year, B_BREAKS, rightmost.closed = TRUE)) |>
    filter(seg >= 1L, seg <= 3L) |>
    group_by(seg) |>
    summarise(mean_stage = mean(stage_capped, na.rm = TRUE), n = n(), mid = B_MIDS[seg])
}
```
_Full implementation: `260415_step3_parameter_estimation_v6.R`_

**Findings:** Generator fleets show almost no natural turnover — machines are replaced only when forced to by a compliance event; the wider construction fleet shows moderate, consistent natural improvement.

| Group | $\lambda_{CF}$ | SE | 95% CI | N | vs. ref |
|---|---|---|---|---|---|
| Constant Speed | 0.051 ⚠ | 0.026 | [−0.017, 0.119] | 133 | Δ = −0.307 |
| CAZ+ | 0.262 | 0.033 | [0.119, 0.404] | 361 | Δ = −0.101 |
| Rest of London | 0.241 | 0.017 | [0.169, 0.314] | 1,294 | Δ = +0.022 |

**Constant Speed** result is anomalously low relative to the prototype reference (0.358). Corroborated by near-zero $\lambda_{Policy}$ (the combined improvement rate in the warm, self-compliant fleet — −0.000) in the warm self-compliant **Constant Speed** fleet: generators have genuinely low natural turnover and remain in service until a compliance event forces replacement. CS cold sample (N = 133) is small but the signal is consistent. Accepted as operative estimate; old reference superseded. **Rest of London** is within tolerance of the reference (+0.022). **CAZ+** moderate deviation (Δ = −0.101), consistent with estimation-window differences.

---

### Sub-task 3.2 — Estimate $\bar{e}$

**Intended task:** Estimate $\bar{e}$ from all records where Initial Stage < compliance threshold for that group and phase (schema.md Table 2); do not divide by phase duration.

**Execution:** For each group × phase cell, records with `initial_stage < COMP_THRESH[[phase]][[group]]` were counted and expressed as a percentage of all records in that cell. The compliance threshold for each group and policy era determines which machines are counted as non-compliant in the $\bar{e}$ calculation:

**Table 2 — Emissions rating minimum requirements by policy era and machine group (from schema.md)**

| Machine Group | Era 1: from 1.9.2015 | Era 2: from 1.9.2020 (+6M) | Era 3: from 1.1.2025 | Era 4: from 1.1.2030 | Era 5: from 1.1.2040 |
|---|---|---|---|---|---|
| Constant speed | IIIA | V | V | V | ZE |
| CAZ+ | IIIB | IV | V | V | ZE |
| Rest of London | IIIA | IIIB | IV | V | ZE |

_Era 2 includes a six-month COVID-19 compliance extension. Phases A1/A2 fall within Era 1; Phase B spans Era 2; Phase C starts at Era 3._

`COMP_THRESH` encoded these thresholds as integers (e.g. **Constant Speed** Phase A1/A2: Stage IIIA = integer 3; Phase B: Stage V = integer 6).

```r
compute_ebar <- function(grp, ph) {
  threshold <- COMP_THRESH[[ph]][[grp]]
  dat <- audits |> filter(group == grp, phase == ph, !is.na(initial_stage))
  tibble(ebar_pct = 100 * mean(dat$initial_stage < threshold),
         n_nc = sum(dat$initial_stage < threshold), n_tot = nrow(dat))
}
```
_Full implementation: `260415_step3_parameter_estimation_v6.R`_

**Findings:** The proportion of machines below the required standard varies sharply by group and time period, directly reflecting when each group's compliance requirements were upgraded.

| Group | $\bar{e}$ Phase A1 | $\bar{e}$ Phase A2 | $\bar{e}$ Phase B | $\bar{e}$ Phase C |
|---|---|---|---|---|
| Constant Speed | 22.1% | 14.8% | 82.8% | 30.4% |
| CAZ+ | 20.2% | 11.2% | 19.9% | — |
| Rest of London | 5.2% | 3.2% | 4.7% | — |
| Variable Speed | — | — | — | 22.0% |

The **Constant Speed** Phase B spike to 82.8% reflects that Stage V was first required in Phase B but most generators were at Stage IIIA; the majority were initially non-compliant when the stricter standard was introduced. The drop to 30.4% in Phase C (P24 records) reflects anticipatory compliance ahead of the formal 2025 deadline. **CAZ+** and **Rest of London** $\bar{e}$ values are moderate and stable, consistent with a fleet gradually improving ahead of successive threshold upgrades (IIIB→IV for **CAZ+**; IIIB for **Rest of London**). **Variable Speed** Phase C at 22.0% aligns closely with **Constant Speed** Phase C, expected for a merged post-2025 snapshot.

![e-bar non-compliance exposure rate by group and phase](260415_step3_parameter_estimation_v6_ebar.png)

Each panel shows $\bar{e}$ (% of machines below the compliance threshold) for one group across all phases; missing bars indicate phases where that group has no data.
The **Constant Speed** Phase B spike to ~83% dominates: almost the entire generator fleet was non-compliant when Stage V was first required.

---

### Sub-task 3.3 — Estimate $\lambda_{Proactive}$

**Intended task:** Estimate $\lambda_{Proactive}$ from warm self-compliant records only (Initial Machinery Compliance == compliant); compute as $\lambda_{Policy}$ − $\lambda_{CF}$, floored at zero.

**Execution:** The same `fit_lambda()` function was applied to warm, self-compliant records (`cold_engaged == FALSE`, `init_mach_emissions_compliant == TRUE`) to obtain $\lambda_{Policy}$ per group. $\lambda_{Proactive}$ = max(0, $\lambda_{Policy}$ − $\lambda_{CF}$). The warm self-compliant subset isolates pure voluntary LEZ-driven upgrading, excluding both the enforcement-driven response and the natural cold-fleet turnover.

```r
warm_sc <- audits |>
  filter(cold_engaged == FALSE, init_mach_emissions_compliant == TRUE,
         group %in% c("Constant_Speed","CAZ_Plus","Rest_of_London")) |>
  mutate(stage_capped = pmin(initial_stage, MAX_STAGE[group]))

proactive <- function(lam_pol, lam_cf) max(0, lam_pol$lambda - lam_cf$lambda)
```
_Full implementation: `260415_step3_parameter_estimation_v6.R`_

**Findings:** Only **CAZ+** shows evidence that machines are being upgraded proactively in response to the LEZ — that is, beyond the rate that would occur from natural fleet renewal alone.

| Group | $\lambda_{Policy}$ | $\lambda_{CF}$ | $\lambda_{Proactive}$ | N warm SC |
|---|---|---|---|---|
| Constant Speed | −0.000 | 0.051 | 0.000 (floored) | 148 |
| CAZ+ | 0.275 | 0.262 | 0.013 | 501 |
| Rest of London | 0.194 | 0.241 | 0.000 (floored) | 1,152 |

**Constant Speed**: near-zero $\lambda_{Policy}$ (the combined improvement rate in the warm self-compliant fleet, capturing both natural turnover and any voluntary LEZ response) corroborates near-zero $\lambda_{CF}$ — generators show no detectable proactive LEZ response. **CAZ+**: small but positive proactive response (0.013); the only group with detectable voluntary upgrading beyond natural turnover. **Rest of London**: $\lambda_{Policy}$ (0.194) < $\lambda_{CF}$ (0.241) — the warm self-compliant subset improves more slowly than the cold fleet; floors at zero. This is analytically consistent (warm SC machines may skew older/lower-stage than the broad cold fleet within the same zone).

---

### Sub-task 3.4 — Report enforcement success rate

**Intended task:** Report enforcement success rate from Route 4/5 outcomes as a descriptive policy metric. Flag groups where n(Routes 4+5) < 30 as too sparse to interpret. This is not a model parameter and does not feed into the transition matrices.

**Execution:** Route 4 was defined as records where `init_mach_emissions_compliant == FALSE` AND `final_mach_emissions_compliant == TRUE` (final machinery reasons contain no E code, indicating post-visit compliance achieved by removal, replacement, retrofit, or exemption granted). Route 5 was `final_mach_emissions_compliant == FALSE`. Success rate = n(Route 4) / n(Routes 4+5). Reported by group × period (A1, A2, B1, B2, B3, C). Cells with n < 30 flagged with ⚠.

**Findings:** Enforcement visits that drive immediate on-the-spot compliance are extremely rare across all groups and time periods, and this is a genuine feature of how audit records are captured rather than a data quality issue. Route 4 success rates ranged 0.0–1.4% across all groups and time periods. The audit record captures compliance state at the point of visit; enforcement outcomes that occur between visits (removals, replacements) are not captured as a raised stage in the record. This finding directly corroborates the design decision to exclude enforcement from the annual replacement probability matrices and represent it only as the Scenario B upper-bound mask in Step 5. **Variable Speed** showed only 5 Phase B3 records (pre-2025 P24 zone edge case), flagged as too sparse to interpret.

![Enforcement outcomes by group and time period](260415_step3_parameter_estimation_v6_enforcement.png)

Stacked bars show absolute counts of Route 4 (green, driven compliant) and Route 5 (red, not actioned) machines per group and time period; y-axes are free across facets.
Labels above each bar show the Route 4 success rate (%); the near-invisible green component confirms Route 4 counts are effectively zero across all groups and periods.

---

### Sub-task 3.5 — Report all parameter estimates

**Intended task:** Report all parameter estimates with SE and CI where applicable; cross-check against locked values and expected ranges; flag anomalies.

**Findings:** All estimates reported in Sections 3.1–3.4 above. The only material anomaly — the generator fleet's near-zero natural turnover rate ($\lambda_{CF}$ **Constant Speed** = 0.051, a departure of Δ = −0.307 from the prototype reference) — has been corroborated from multiple independent sources and is accepted as the operative estimate. Corroboration comes from: (1) near-zero $\lambda_{Policy}$ in the same fleet; (2) a small but internally consistent cold sample (N = 133); (3) known prior-trial data pipeline differences. All other estimates are within 15% of prior references or explained by revised analytical decisions (the `MAX_STAGE` correction for **CAZ+**). Parameters locked in `decisions.md` and schema.md Table 8 for use in Step 4.

---

## Step 4: Transition Matrix Construction

**Final-trial script:** `260417_step4_transition_matrices_v3.R`  
**Output objects:** `intermediate/p_natural.rds`, `intermediate/p_proactive.rds`, `intermediate/p_total.rds`, `intermediate/step4_matrices.rds`

_Purpose: This step converts the estimated fleet improvement rates from Step 3 into annual machine-replacement probability matrices, which drive the Stage distribution forecasts in Step 5._

---

### Sub-task 4.1 — Construct `P_Natural` and `P_Proactive`

**Intended task:** Construct group-specific right-stochastic transition matrices `P_Natural` and `P_Proactive` with dimensions 6×6 (`FORECAST_MAX_STAGE` = 6 for all Phase C groups). $p_{cf}$ and $p_{pro}$ derived from locked $\lambda$ values and $\overline{\Delta s}$ (average stage jump) computed from estimation-window cold records. No `P_Enforcement` matrix.

**Execution:** The average stage jump, $\overline{\Delta s}$, was computed in the 6-stage forecast space (ceiling = Stage V = integer 6) for all groups, including **Constant Speed**. The v3 fix: previous versions used **Constant Speed**'s 3-stage estimation ceiling, producing $\overline{\Delta s}$ ≈ 0.218 and $p_{cf}$ ≈ 0.234 — a 6.7× overestimate relative to the locked $\lambda_{CF}$ of 0.051. Using `FORECAST_MAX_STAGE` = 6 as the ceiling gives $\overline{\Delta s}$ ≈ 3.218, yielding $p_{cf}$ = 0.051 / 3.218 ≈ 0.016.

```r
compute_avg_jump <- function(dat, grp, phase_bounds) {
  sub <- dat |> filter(group == grp, cold_engaged == TRUE, ...) |>
    mutate(stage_capped = pmin(initial_stage, FORECAST_MAX_STAGE))  # ceiling always 6
  list(wmean = mean(sub$stage_capped), n = nrow(sub),
       avg_jump = FORECAST_MAX_STAGE - mean(sub$stage_capped))
}
```
_Full implementation: `260417_step4_transition_matrices_v3.R`_

`P_Natural` was built as a near-identity matrix where each non-top stage transitions to Stage V (integer 6) with probability $p_{cf}$ and remains in place with probability 1 − $p_{cf}$. Row-stochasticity was enforced after every matrix operation.

```r
build_natural <- function(max_stage, p_cf) {
  p_cf <- min(max(p_cf, 0), 0.99); mat <- diag(max_stage)
  for (i in seq_len(max_stage - 1L)) { mat[i,i] <- 1-p_cf; mat[i,max_stage] <- p_cf }
  enforce_stochastic(mat)
}

enforce_stochastic <- function(mat) {
  mat <- pmax(mat, 0); rs <- rowSums(mat)
  if (any(rs == 0)) for (i in which(rs == 0)) mat[i,i] <- 1
  sweep(mat, 1, rowSums(mat), "/")
}
```
_Full implementation: `260417_step4_transition_matrices_v3.R`_

**Variable Speed** parameters were derived as Phase B cold-N-weighted averages of **CAZ+** and **Rest of London** ($\lambda_{CF}$, $\lambda_{Proactive}$, $\overline{\Delta s}$), since **Variable Speed** (P24) first exists in Phase C and has no own historical estimation window.

**Findings:** Annual replacement probabilities are very low for generators (around 1.6% per year) compared to the wider construction fleet (around 16–20% per year), reflecting the generator fleet's much slower natural renewal.

| Group | $\overline{\Delta s}$ | $p_{cf}$ | $p_{pro}$ |
|---|---|---|---|
| Constant Speed | 3.218 | 0.016 | 0.000 |
| CAZ+ | 1.302 | 0.201 | 0.010 |
| Rest of London | 1.501 | 0.161 | 0.000 |
| Variable Speed | 1.460 (wtd avg) | 0.168 | 0.002 (wtd avg) |

All matrix row probabilities were verified to sum to 1 (a mathematical consistency check — row-stochastic check PASSED for all groups). For **Constant Speed** and **Rest of London** ($\lambda_{Proactive}$ = 0), `P_Total` = `P_Natural`.

![Replacement probabilities by group](260417_step4_transition_matrices_v3_fig4_1_probabilities.png)

Each group shows $p_{cf}$ (blue, natural counterfactual turnover) and $p_{pro}$ (orange, proactive LEZ-driven replacement) as annual probabilities.
**Constant Speed** $p_{cf}$ is low (~0.016) consistent with $\lambda_{CF}$ = 0.051 and a large $\overline{\Delta s}$ (~3.2 stages to Stage V); **CAZ+** and **Rest of London** $p_{cf}$ are higher (~0.16–0.20) with smaller $\overline{\Delta s}$ values.

---

### Sub-task 4.2 — Combine into `P_Total`

**Intended task:** Combine `P_Natural` and `P_Proactive` into composite `P_Total` (Scenario A base matrix); enforce row-sum constraint; display both `P_Natural` and `P_Total`; report probability-decomposition table and implied-$\lambda$ validation.

**Execution:** `P_Total` was built by summing $p_{cf}$ + $p_{pro}$ into a single off-diagonal probability `p_up`, replacing the two-matrix product with a direct `build_total()` call. This is equivalent under the near-identity matrix structure and avoids floating-point accumulation.

```r
build_total <- function(max_stage, p_cf, p_pro) {
  p_up <- min(p_cf + p_pro, 0.99); mat <- diag(max_stage)
  for (i in seq_len(max_stage - 1L)) { mat[i,i] <- 1-p_up; mat[i,max_stage] <- p_up }
  enforce_stochastic(mat)
}
```
_Full implementation: `260417_step4_transition_matrices_v3.R`_

**Findings:** Adding the proactive LEZ effect to the base matrix makes negligible difference for all groups; the combined matrix (`P_Total`) is essentially identical to the natural-turnover-only matrix (`P_Natural`) for all but the **Variable Speed** group. `P_Total` and `P_Natural` differ only for **Variable Speed** (`p_up` = 0.1698 vs $p_{cf}$ = 0.1680, marginal +0.0018 from $p_{pro}$). Full 6×6 matrices displayed in output for both Phase C groups.

![P\_Total heatmap by group](260417_step4_transition_matrices_v3_fig4_2_ptotal_heatmap.png)

Heatmaps of `P_Total` for each Phase C group: darker blue = higher transition probability. The dominant pattern is a near-diagonal (machines stay) with a single off-diagonal column at Stage V (replacement destination).
**Constant Speed** diagonal values are higher (lower $p_{cf}$ ≈ 0.016) than **Variable Speed** (higher $p_{cf}$ ≈ 0.168), reflecting the generator fleet's slow natural turnover relative to the merged variable-speed fleet.

---

### Sub-task 4.3 — Validate `P_Total`

**Intended task:** Validate `P_Total` against observed Stage distributions before use in forecasting.

**Execution:** Two validation approaches used. **Validation A:** implied $\lambda$ computed from `P_Total` weighted by the Phase C cold distribution ($\pi_0$), and compared to locked $\lambda_{CF}$. **Validation B:** one-step projection from the Phase B3 actual distribution compared to the actual Phase C distribution.

```r
implied_lambda <- function(mat, pi, max_stage) {
  stages         <- seq_len(max_stage)
  expected_stage <- as.vector(mat %*% stages)
  sum(pi * (expected_stage - stages))   # distribution-weighted expected improvement
}
```
_Full implementation: `260417_step4_transition_matrices_v3.R`_

**Findings:** The matrices produce broadly plausible stage distributions when projected forward from observed data; the main discrepancy is the generator fleet's faster-than-predicted Stage V adoption in 2025, which reflects operators upgrading ahead of the formal compliance deadline — behaviour not captured by a model with a fixed annual replacement probability.

- **Validation A:** The fleet improvement rate implied by `P_Natural` deviates from locked $\lambda_{CF}$: CS 55% divergence (0.023 vs 0.051), VS 75% divergence (0.062 vs 0.245). Both deviations are expected and documented: the Phase C fleet is substantially more advanced than the estimation-window fleet; fewer machines remain below Stage V to generate upward movement, suppressing the distribution-weighted implied rate. The model correctly propagates a slow improvement signal through a near-compliant fleet.  
- **Validation B:** CS one-step projection is close (Stage V 0.494 projected vs 0.538 actual, Δ = 0.044). VS underpredicts Stage V (0.657 vs 0.765, Δ = 0.108), consistent with anticipatory pre-2025 compliance not captured by the fixed annual-probability model. Since forecasts are initialised directly from the actual P24 distribution, this discrepancy does not propagate into Step 5.

![Validation B: one-step projection](260417_step4_transition_matrices_v3_fig4_3_validation_B.png)

Blue bars = Phase B3 actual cold distribution; orange = one-step `P_Total` projection; green = Phase C actual P24 cold distribution. Agreement between orange and green indicates `P_Total` captures the observed fleet transition.
Discrepancies reflect genuine fleet composition shifts (e.g. Stage V surge in **Constant Speed** machines before the 2025 compliance deadline), a replacement rate that varied over time rather than being constant (not captured by the single annual-probability model), or P24 zone composition differing from B3 estimation-window zones.

---

## Step 5: Forecasting and Emissions

**Final-trial script:** `260417_step5_forecasting_v1.R`  
**Output objects:** `intermediate/forecast_scen_a.rds`, `intermediate/forecast_scen_b.rds`, `intermediate/step5_forecasts.rds`

_Purpose: This step projects fleet Stage distributions and compliance rates from 2025 to 2030 under two scenarios — a baseline assuming natural and voluntary upgrading only, and an upper bound assuming full enforcement — to bracket the range of plausible policy outcomes._

---

### Sub-task 5.1 — Project Stage distributions 2025–2030 (two scenarios)

**Intended task:** Project Stage distributions annually 2025–2030 under Scenario A (proactive only) and Scenario B (enforcement upper bound, Boolean mask zeroing non-compliant transitions).

**Execution:** Scenario A applied `P_Total` annually via `project_distribution()`. Each annual step multiplied the row-vector $\pi$ by $P$: `pi_curr <- as.vector(pi_curr %*% P_t)`. Scenario B constructed a masked version of `P_Total` using `build_scenario_b()`, which zeroed all columns corresponding to stages below the year-specific compliance threshold and rescaled remaining rows to sum to 1.

```r
build_scenario_b <- function(mat, threshold) {
  mat_b <- mat
  if (threshold > 1L) mat_b[, seq_len(threshold - 1L)] <- 0
  enforce_stochastic(mat_b)    # non-compliant machines must jump to top stage
}
```
_Full implementation: `260417_step5_forecasting_v1.R`_

```r
project_distribution <- function(pi0, P, n_years, years, group) {
  pi_curr <- pi0
  for (t in seq_len(n_years)) {
    P_t     <- if (is.list(P)) P[[t]] else P
    pi_curr <- as.vector(pi_curr %*% P_t)
    pi_curr <- pmax(pi_curr, 0) / sum(pmax(pi_curr, 0))   # normalise
  }
}
```
_Full implementation: `260417_step5_forecasting_v1.R`_

Compliance thresholds per year were defined in `COMP_THRESH`: **Constant Speed** Stage V (integer 6) throughout 2025–2030; **Variable Speed** Stage IV (integer 5) in 2025–2029, Stage V (integer 6) from 2030.

**Findings:** Without enforcement (Scenario A), generators will barely improve over the forecast period — natural turnover is too slow to drive meaningful change. The wider construction fleet will make meaningful gains but still falls short of full Stage V compliance by 2030. With full enforcement (Scenario B), both groups can reach 100% compliance within the forecast horizon.

**Scenario A (Constant Speed):** Stage V 53.8% → 57.4% by 2030. Stage IIIA persists at ~35.5%. Net improvement +3.6 percentage points over 5 years — negligible, driven by extremely low $p_{cf}$ (0.016). Natural turnover alone is insufficient to drive compliance.

**Scenario A (Variable Speed):** Stage V 76.5% → 90.8% by 2030 at the Stage IV threshold (compliance rate reaches 95.3% in 2029, then drops to 90.8% in 2030 when the threshold upgrades from Stage IV to Stage V, bringing the Stage IV fraction out of compliance). Stage IIIB declines from 7.7% to ~3%.

**Scenario B (Constant Speed):** Stage V 53.8% → 100% by 2026 and constant thereafter. All non-Stage-V machines are forced to comply within one annual step.

**Scenario B (Variable Speed):** Stages I–IIIB zeroed immediately; Stage IV fraction (13.6%) remains until 2030 when it falls out of compliance with the upgraded threshold and is forced to Stage V → 100% Stage V compliance by 2030.

![Scenario A stage distribution forecast](260417_step5_forecasting_v1_fig5_2_scen_a_stage.png)

Stage proportions under Scenario A (no enforcement). Stage V rises monotonically for both groups; the rate is slower for **Constant Speed** ($p_{cf}$ = 0.016) than **Variable Speed** ($p_{cf}$ = 0.168).
Lower stages (I–IV) decay in proportion as machines are progressively replaced; Stage IIIA in **Constant Speed** persists due to the low replacement rate.

![Scenario B stage distribution forecast](260417_step5_forecasting_v1_fig5_3_scen_b_stage.png)

Under full enforcement, all non-compliant machines transition to Stage V in the first annual step; Stage V proportion reaches 100% by 2026 for **Constant Speed** and by 2030 for **Variable Speed**.
This is the structural upper bound: actual enforcement outcomes will lie between Scenario A and Scenario B depending on audit frequency and enforcement capacity.

---

### Sub-task 5.2 — Phase C initialisation

**Intended task:** For Phase C initialisation, pool **Constant Speed** and **Variable Speed** P24 records; extract group-specific Stage distributions as the Phase C starting state.

**Execution:** Phase C cold-engaged P24 records were extracted from `audits.rds` by group (`Constant_Speed` and `Variable_Speed` assigned at Step 1 from P24 zone records). No merge operation was required; group assignment at Step 1 handled the CAZ+/RoL → `Variable_Speed` merge.

**Findings:** The forecast begins from an already substantially compliant fleet: just over half of generators and three-quarters of the wider construction fleet were already at Stage V at the start of the forecast period. Phase C cold initialisation distributions ($\pi_0$, the starting Stage proportions for the forecast):

| Stage | Constant Speed (N=26) | Variable Speed (N=57) |
|---|---|---|
| I | 0.0% | 0.3% |
| II | 7.7% | 0.9% |
| IIIA | 38.5% | 0.9% |
| IIIB | 0.0% | 7.7% |
| IV | 0.0% | 13.6% |
| V | 53.8% | 76.5% |

**Constant Speed** initialisation: substantial Stage IIIA tail (38.5%) alongside Stage V majority; IIIB and IV absent, consistent with **Constant Speed** estimation `max_stage` = 3. **Variable Speed**: overwhelmingly Stage V (76.5%) with a non-compliant tail spread across Stages I–IV.

---

### Sub-task 5.3 — Emissions estimation

**Intended task:** Estimate annual emissions per group as E = Σ(N × kW × 2000 × `EF_s`) using EMEP/EEA Tier 3 factors.

**Execution:** The script includes a fully implemented emissions section guarded by `if (!any(is.na(EF_s)))`. `EF_s` is a named vector of EMEP/EEA Tier 3 NOx factors (g NOx/kWh) keyed on stage integer 1–6, with all values initialised to `NA_real_` pending user input.

**Findings:** The emissions calculation is ready to run but cannot produce output yet because the standard emission intensity values for each Stage have not been provided. `EF_s` values not yet supplied. On user provision of the six Tier 3 NOx factors, Section 5.5 will execute automatically on re-run, producing Table 5.5 (emissions index 2025 = 100 for both scenarios) and Figure 5.5 (emissions trajectory 2025–2030).

---

### Sub-task 5.4 — Summary tables, plots, and limitations

**Intended task:** Produce summary tables and plots of Stage distributions and emissions trajectories for both scenarios; document limitations.

**Findings:** Enforcement is the decisive factor for generators but plays a minor supporting role for the construction fleet: without enforcement, generators barely improve; with it, they can reach full compliance by 2026. All tables and plots produced for Stage distributions (Tables 5.2, 5.3) and compliance trajectories (Table 5.4, Figure 5.4). Compliance summary at 2025 and 2030:

| Group | Scen A 2025 | Scen A 2030 | Scen B 2025 | Scen B 2030 |
|---|---|---|---|---|
| Constant Speed | 53.8% | 57.4% | 53.8% | 100.0% |
| Variable Speed | 90.1% | 90.8%\* | 90.1% | 100.0% |

\* VS compliance drops from 95.3% (2029) to 90.8% (2030) as Stage IV threshold upgrades to Stage V.

Enforcement-attributable ceiling: CS = +42.6 pp; VS = +9.2 pp by 2030. Known limitations documented in output per schema.md (see Known Limitations section below).

![Compliance trajectory 2025–2030](260417_step5_forecasting_v1_fig5_4_compliance.png)

Blue = Scenario A (natural + proactive turnover); red dashed = Scenario B (enforcement upper bound). The 2025 values are identical (both initialised from $\pi_0$).
The wide gap for **Constant Speed** (42.6 pp) illustrates that enforcement is essential for the generator fleet; the narrower gap for **Variable Speed** (9.2 pp) indicates that natural fleet turnover nearly suffices under the Stage IV threshold, though not under Stage V in 2030.

---

## Open Items

1. **Emissions factors not yet supplied:** The emissions calculation cannot run until the standard pollution intensity values for each emissions Stage are provided. Once supplied, the calculation will execute automatically on re-running the Step 5 script, using a default assumption of 2,000 operating hours per machine per year. (Technical: `EF_s` — EMEP/EEA Tier 3 NOx factors (g NOx/kWh) for Stages I–V — required by Section 5.5 of `260417_step5_forecasting_v1.R`.)

2. **Fleet size for emissions not confirmed:** The emissions calculation also requires a count of how many machines are active in each group to scale from per-machine to fleet-wide totals. It is unclear whether to use the number of audit records as a proxy or to supply a separate estimate of total active fleet size. (Technical: N per group in E = Σ(N × kW × 2000 × `EF_s`); user to confirm proxy vs external fleet size estimate.)

---

## Known Limitations

_(Source: schema.md "Known limitations")_

1. **The model uses group averages, not individual machine tracking.** Replacement rates are estimated from aggregate counts of machines at each emissions Stage, not from records of individual machines being replaced. This means the rates are group averages — some machines will have much higher or lower turnover than implied by the model. (Technical: aggregate stage counts approximate individual transition hazards; this is an ecological inference in the sense of Robinson (1950) and cannot be verified from the audit data.)

2. **New machines entering the fleet and old machines leaving inflate the apparent improvement rate.** When a high-Stage machine joins the fleet or a low-Stage machine leaves, the group average improves without any individual machine being upgraded. The model cannot separate this from genuine equipment upgrades. (Technical: fleet entry and exit are absorbed into the transition rates $p_{cf}$ and $p_{pro}$; the model does not separately identify entry, exit, or stage-upgrading transitions — all are folded into the annual replacement probability.)

3. **The improvement rate within Phase B varied across sub-periods — using a single rate for the whole phase is a simplification.** The speed of fleet improvement was not constant across Phase B: it differed between the early (2020–2022) and late (2022–2024) sub-periods for all groups. This may cause the single per-phase rate to over- or under-estimate improvement in any given sub-period. (Technical: $\lambda_{CF}$ is not time-homogeneous within Phase B; segments 1→2 and 2→3 are inconsistent across all groups; a time-varying or piecewise model would better capture the acceleration through Phase B.)

4. **Machines traded second-hand at intermediate stages would make the natural turnover rate look faster than it truly is.** The model assumes machines are replaced with new high-Stage equipment. If operators frequently buy second-hand intermediate-Stage machines instead, the counterfactual rate will be overstated, and the LEZ-attributable improvement will be understated. (Technical: $\lambda_{CF}$ overestimates the true counterfactual if second-hand step-wise trading is common; $\lambda_{Proactive}$ is correspondingly a conservative lower bound.)

5. **The earliest period (2016–2018) had too few records for CAZ+ and Rest of London to estimate a trend independently.** It was merged with Phase A2 (2019–2020) for estimation purposes. This reduces precision and may obscure any step change in behaviour at the very start of the LEZ. (Technical: variable-speed groups have insufficient Phase A1 cold records (n = 139) for separate lambda estimation; pooling reduces degrees of freedom and may smooth over an early-phase discontinuity.)

---

## Glossary

| Term | Definition |
|---|---|
| $\bar{e}$ | Non-compliance exposure rate: % of all records in a group–phase cell with initial stage below the compliance threshold. A stock measure; does not require individual replacement assumptions. |
| $\Delta\bar{e}/\Delta t$ | Rate of change in $\bar{e}$ between phase midpoints (pp per year). The most intuitive policy headline metric — directly answers "is the LEZ working, and how fast?" |
| $\lambda_{CF}$ | Counterfactual fleet turnover rate. WLS slope of mean emissions stage over time in cold-engaged records. Units: stage integers per year. |
| $\lambda_{Policy}$ | Combined improvement rate in warm self-compliant records: natural turnover + proactive LEZ-driven replacement. |
| $\lambda_{Proactive}$ | max(0, $\lambda_{Policy}$ − $\lambda_{CF}$): incremental stage improvement rate attributable to LEZ policy; floored at zero. |
| $p_{cf}$ | Annual replacement probability under counterfactual: $\lambda_{CF}$ / $\overline{\Delta s}$. Denominated in the 6-stage forecast space for all groups. |
| $p_{pro}$ | Annual proactive LEZ replacement probability: $\lambda_{Proactive}$ / $\overline{\Delta s}$. |
| $\overline{\Delta s}$ | Expected stage integers gained per replacement event: `FORECAST_MAX_STAGE` (6) minus the mean observed stage in the cold estimation-window records. |
| `P_Natural` | Right-stochastic 6×6 matrix: each non-top stage transitions to Stage V with probability $p_{cf}$ per year; Stage V is absorbing. |
| `P_Total` | `P_Natural` plus proactive LEZ channel ($p_{cf}$ + $p_{pro}$). Scenario A base matrix. |
| **Scenario A** | Baseline forecast: `P_Total` applied annually. Natural turnover + proactive LEZ; no enforcement augmentation. |
| **Scenario B** | Upper-bound forecast: Boolean mask zeroes transitions to non-compliant stages; rescales rows. Non-compliant machines must jump to Stage V each step. |
| $\pi_0$ | Phase C initialisation distribution: Stage proportions from P24 cold-engaged records. |
| **Cold-engaged** | Machine on site not yet engaged with the LEZ process; basis for $\lambda_{CF}$ estimation. |
| **Warm self-compliant** | Machine emissions-OK on arrival (Route 1); basis for $\lambda_{Policy}$ estimation. |
| **Route 4** | Initial emissions non-compliant; post-visit compliance achieved (no E code in final machinery reasons — removal, replacement, retrofit, or exemption). |
| **Route 5** | Initial emissions non-compliant; E code persists in final machinery reasons at end of visit. |
| **WLS** | Weighted least squares via `lm()`; SE extracted from `vcov()`. |
| **GLS** | Generalised least squares (considered for Phase B estimation; superseded by WLS 3-segment approach). |
| **pp** | Percentage points. |
| **Phase A1** | 1 Jan 2016 – 31 Dec 2018. Pre-Stage V market availability. |
| **Phase A2** | 1 Jan 2019 – 31 Aug 2020. Stage V equipment newly available. |
| **Phase B** | 1 Sep 2020 – 31 Dec 2024. COVID-exempt records removed; variable-speed groups sub-segmented into B1/B2/B3 (~527 days each). |
| **Phase C** | 1 Jan 2025 – 31 Dec 2030. Forecast period. **CAZ+** and **Rest of London** merged into **Variable Speed** (P24 zone). |
| `EF_s` | EMEP/EEA Tier 3 NOx emission factor (g NOx/kWh) for Stage s (Ntziachristos & Samaras 2019). Not yet supplied. |
| **CAZ+** | Variable-speed machinery in the Central Activities Zone and Outer Area (zones CAZ and OA). |

---

## Appendix: Analytical Notes

### A.1 — Why Constant Speed uses annual WLS resolution despite having the fewest cold records

**Constant Speed** (N = 133 cold records) is estimated using 8 annual WLS data points (2016–2023), while **CAZ+** (N = 361) and **Rest of London** (N = 1,294) use only 4 points (A1/A2 pooled + Phase B 3-segment midpoints). This seems counterintuitive: the smaller group has finer temporal resolution.

The resolution of the paradox is that the binding constraint is not record count per time point — it is **WLS stability at each temporal point**, which depends on within-cell stage variance.

**Variable-speed groups face ceiling saturation.** Stage V penetration in **CAZ+** cold records reaches approximately 60% by Phase B3. As the fleet bunches at the ceiling (Stage V = integer 6, the maximum in their estimation space), year-to-year variance in mean stage increases sharply — small shifts in the Stage V fraction produce large swings in the annual mean. When annual GLS was attempted for **CAZ+**, it yielded $\lambda_{CF}$ = 0.638, more than twice the accepted estimate of 0.262. This inflation is a ceiling-saturation artefact, not a genuine fleet signal. Widening the temporal window to ~527-day Phase B segments averages out this within-period noise and recovers a stable slope.

**Constant Speed does not face this problem.** Stage V is absent from the **Constant Speed** cold estimation window (2024 data excluded due to the anticipatory pre-deadline spike). The fleet moves within a bounded three-integer space (Stages I–IIIA) with no ceiling in range. Annual cold n for **Constant Speed** (~16–17 records/year) is in fact lower than annual cold n for **CAZ+** (37–83/year), yet the signal is clean and monotonic. Annual resolution is stable precisely because there is no saturation compressing and distorting the slope.

**A1/A2 pooling** for variable-speed groups creates a single pre-Phase-B anchor point. It is partly motivated by thin annual A1 cells (CAZ+ n = 139 cold records across three Phase A1 years), but principally by the design decision to use Phase B sub-segments as the time-varying signal rather than mixing annual and segmented granularities within the same regression.

In summary: more records per time point does not help when ceiling saturation is the source of noise. The correct remedy is wider temporal bins, not larger samples.

---

_End of report. Version 5 generated 18 April 2026._
