# 260415_step3_parameter_estimation_v3.R
# Step 3: Parameter Estimation — Trial 3
#
# Corrections vs Trials 1-2 (sprint_log.md):
#   F1  COMP_THRESH: A1/A2 = Col 1, B = Col 2. "Era ending" date marks when
#       requirement TOOK EFFECT; col 1 threshold applies during A1/A2 era.
#       Correct: A1/A2 CS=3, CAZ+=4, RoL=3; B CS=6, CAZ+=5, RoL=4.
#   F2  Table layout: phases as column super-headers, groups as row outer index.
#   F3  Every table followed by exactly two lines of plain-English text.
#   F4  Glossary of all abbreviated terms appended to output file.
#   F5  CAZ+ MAX_STAGE integer = 6 (Stage V), not 5 (Stage IV).
#   F6  lambda_Policy/Proactive NA handled via min-observation guard in fit_lambda().

# ── Libraries ─────────────────────────────────────────────────────────────────
suppressPackageStartupMessages({
  library(tidyverse)
  library(knitr)
  library(kableExtra)
})

# ── Script constants ───────────────────────────────────────────────────────────
SCRIPT_STEM <- "260415_step3_parameter_estimation_v3"
OUT_FILE    <- file.path("outputs", paste0(SCRIPT_STEM, ".md"))
INT_DIR     <- "intermediate"
MANIFEST    <- file.path(INT_DIR, "manifest.md")

# Fixed group display order (schema.md Table 1)
GROUP_ORDER <- c("Constant_Speed", "CAZ_Plus", "Rest_of_London", "Variable_Speed")

# Active stage INTEGER ceiling by group (schema.md "Active state spaces" + decisions.md)
# CS max_stage=3 means stages I/II/IIIA only; IIIB/IV never present in cold fleet.
# CAZ+ max_stage INTEGER = 6 (= Stage V); 5 active stages II-V, Stage I near-absent.
MAX_STAGE <- c(
  Constant_Speed = 3L,
  CAZ_Plus       = 6L,
  Rest_of_London = 6L,
  Variable_Speed = 6L
)

# Compliance thresholds — minimum stage integer required to be compliant.
# schema.md Table 2: "era ending" date = date that requirement TOOK EFFECT.
# Phases A1 and A2 fall under the Col 1 era (era ending 1.9.2015 = requirement in
# force from 1.9.2015 onward, covering Phase A1 and A2).
# Phase B falls under the Col 2 era (requirement took effect 1.9.2020).
# Phase C falls under the Col 3 era (requirement took effect 1.1.2025).
COMP_THRESH <- list(
  A1 = c(Constant_Speed = 3L, CAZ_Plus = 4L, Rest_of_London = 3L),
  A2 = c(Constant_Speed = 3L, CAZ_Plus = 4L, Rest_of_London = 3L),
  B  = c(Constant_Speed = 6L, CAZ_Plus = 5L, Rest_of_London = 4L),
  C  = c(Constant_Speed = 6L, Variable_Speed = 6L)
)

# Phase fractional-year boundaries [start, end) — schema.md Table 7
PHASE_BOUNDS <- list(
  A1 = c(2016.0000, 2018.9973),   # 1.1.2016 – 31.12.2018
  A2 = c(2019.0000, 2020.6667),   # 1.1.2019 – 31.8.2020
  B  = c(2020.6667, 2024.9973),   # 1.9.2020 – 31.12.2024
  C  = c(2025.0000, 2031.0000)    # 1.1.2025 – 31.12.2030
)

# Phase B: 3-segment break-points and midpoints (schema.md)
B_BREAKS <- c(2020.6667, 2022.1096, 2023.5534, 2024.9973)
B_MIDS   <- c(2021.389, 2022.832, 2024.278)

# Previous trial reference lambda_CF values (schema.md Table 8)
REF_LAMBDA_CF <- c(
  Constant_Speed = 0.358,
  CAZ_Plus       = 0.363,
  Rest_of_London = 0.219
)

# ── Helper functions ───────────────────────────────────────────────────────────

# Convert a Date vector to fractional year
to_frac_year <- function(d) {
  yr   <- as.integer(format(d, "%Y"))
  doy  <- as.integer(format(d, "%j"))
  leap <- ((yr %% 4L == 0L) & (yr %% 100L != 0L)) | (yr %% 400L == 0L)
  yr + (doy - 1L) / ifelse(leap, 366L, 365L)
}

# WLS regression of mean_stage ~ temporal midpoint, weighted by n.
# Arguments:
#   pts      : tibble with columns mid (fractional year), mean_stage, n
#   min_pts  : minimum data points required; returns NA row if not met
# Returns single-row tibble: lambda, se, ci_lo, ci_hi, n_pts, n_obs
fit_lambda <- function(pts, min_pts = 2L) {
  pts <- pts |> filter(!is.na(mean_stage), !is.na(n), n > 0L, is.finite(mean_stage))
  if (nrow(pts) < min_pts) {
    return(tibble(
      lambda = NA_real_, se = NA_real_,
      ci_lo  = NA_real_, ci_hi = NA_real_,
      n_pts  = nrow(pts), n_obs = sum(pts$n, na.rm = TRUE)
    ))
  }
  fit   <- lm(mean_stage ~ mid, data = pts, weights = n)
  b     <- coef(fit)[["mid"]]
  se_b  <- sqrt(vcov(fit)["mid", "mid"])
  df_r  <- df.residual(fit)
  tc    <- qt(0.975, df = max(df_r, 1L))
  tibble(
    lambda = b, se = se_b,
    ci_lo  = b - tc * se_b, ci_hi = b + tc * se_b,
    n_pts  = nrow(pts), n_obs = as.integer(sum(pts$n))
  )
}

# Aggregate stage_capped into Phase-B segment midpoints.
# Requires columns: frac_year, stage_capped in dat.
phase_b_pts <- function(dat) {
  dat |>
    mutate(seg = findInterval(frac_year, B_BREAKS, rightmost.closed = TRUE)) |>
    filter(seg >= 1L, seg <= 3L) |>
    group_by(seg) |>
    summarise(
      mean_stage = mean(stage_capped, na.rm = TRUE),
      n          = n(),
      .groups    = "drop"
    ) |>
    mutate(mid = B_MIDS[seg])
}

# Save RDS and append one row to the manifest table
save_obj <- function(obj, name, class_str, dim_str, step_str, desc_str) {
  fp <- file.path(INT_DIR, paste0(name, ".rds"))
  saveRDS(obj, fp)
  write_lines(
    sprintf("| %s | %s | %s | %s | %s | %s |",
            name, fp, class_str, dim_str, step_str, desc_str),
    MANIFEST, append = TRUE
  )
  invisible(obj)
}

# Append lines to the output markdown file
md <- function(...) write_lines(c(...), OUT_FILE, append = TRUE)

# Write a kableExtra HTML object to the output markdown file
write_kbl <- function(kbl_obj) {
  write_lines(as.character(kbl_obj), OUT_FILE, append = TRUE)
}

# ── Load data ──────────────────────────────────────────────────────────────────
audits <- readRDS(file.path(INT_DIR, "audits.rds"))

# date_frac already present in audits (computed at ingestion); alias for brevity
audits <- audits |> rename(frac_year = date_frac)

# ── Initialise output file ─────────────────────────────────────────────────────
write_lines(
  c(
    paste0("# Step 3 Parameter Estimation — ", SCRIPT_STEM),
    paste0("*Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "*"),
    ""
  ),
  OUT_FILE, append = FALSE
)

# =============================================================================
# 3.1  lambda_CF — Counterfactual fleet turnover rate
# =============================================================================
# Source: cold-engaged records; stage capped at group-specific MAX_STAGE.
# Estimation windows:
#   Constant_Speed  : annual aggregation 2016–2023 (2024 cold excluded per
#                     schema.md Key analytical note #3; Stage V spike is
#                     anticipatory compliance, not natural turnover).
#   CAZ_Plus        : A1/A2 pooled (1 pt) + Phase B 3 segments (3 pts).
#   Rest_of_London  : same structure as CAZ_Plus.
#   Variable_Speed  : no lambda_CF estimated (Phase C merged group only).
# All fits via lm() with weights argument; SE from vcov().

cold <- audits |>
  filter(
    cold_engaged == TRUE,
    group %in% c("Constant_Speed", "CAZ_Plus", "Rest_of_London")
  ) |>
  mutate(stage_capped = pmin(initial_stage, MAX_STAGE[group]))

# --- Constant Speed: annual midpoints 2016–2023 ---
cs_annual <- cold |>
  filter(
    group    == "Constant_Speed",
    frac_year >= PHASE_BOUNDS$A1[1],
    frac_year <  2024.0
  ) |>
  mutate(yr = floor(frac_year)) |>
  group_by(yr) |>
  summarise(
    mean_stage = mean(stage_capped, na.rm = TRUE),
    n          = n(),
    .groups    = "drop"
  ) |>
  mutate(mid = yr + 0.5)

lam_cf_cs <- fit_lambda(cs_annual)

# --- Variable-speed groups: A1/A2 pooled + B 3-segment ---
vs_cf_lambda <- function(grp) {
  dat   <- cold |> filter(group == grp)
  max_s <- MAX_STAGE[[grp]]

  # A1 and A2 pooled into a single temporal data point
  a12_mid <- (PHASE_BOUNDS$A1[1] + PHASE_BOUNDS$A2[2]) / 2
  a12 <- dat |>
    filter(
      frac_year >= PHASE_BOUNDS$A1[1],
      frac_year <= PHASE_BOUNDS$A2[2]
    ) |>
    summarise(
      mean_stage = mean(pmin(initial_stage, max_s), na.rm = TRUE),
      n          = n(),
      .groups    = "drop"
    ) |>
    mutate(mid = a12_mid)

  # Phase B: 3 equal segments
  b_dat <- dat |>
    filter(
      frac_year >= PHASE_BOUNDS$B[1],
      frac_year <  PHASE_BOUNDS$B[2]
    ) |>
    mutate(stage_capped = pmin(initial_stage, max_s))

  b_pts <- phase_b_pts(b_dat)

  pts <- bind_rows(
    select(a12,   mid, mean_stage, n),
    select(b_pts, mid, mean_stage, n)
  )
  fit_lambda(pts)
}

lam_cf_caz <- vs_cf_lambda("CAZ_Plus")
lam_cf_rol <- vs_cf_lambda("Rest_of_London")

lambda_cf <- list(
  Constant_Speed = lam_cf_cs,
  CAZ_Plus       = lam_cf_caz,
  Rest_of_London = lam_cf_rol,
  Variable_Speed = tibble(lambda = NA_real_, se = NA_real_,
                          ci_lo  = NA_real_, ci_hi = NA_real_,
                          n_pts  = 0L,       n_obs = 0L)
)

save_obj(lambda_cf, "lambda_cf", "list", "4 groups", "3",
         "WLS lambda_CF by group; stages capped at MAX_STAGE; cold-engaged only")

# Build display table — one row per group; no phase breakdown (single slope estimate)
tbl_31 <- map_dfr(GROUP_ORDER, function(g) {
  r <- lambda_cf[[g]]
  ref <- if (g %in% names(REF_LAMBDA_CF)) REF_LAMBDA_CF[g] else NA_real_
  tibble(
    Group      = g,
    Estimate   = if (!is.na(r$lambda)) sprintf("%.3f", r$lambda) else "\u2014",
    SE         = if (!is.na(r$se))     sprintf("%.3f", r$se)     else "\u2014",
    `95% CI`   = if (!is.na(r$ci_lo))
                   sprintf("[%.3f,&nbsp;%.3f]", r$ci_lo, r$ci_hi) else "\u2014",
    `N obs`    = if (r$n_obs > 0L) as.character(r$n_obs) else "\u2014",
    `Prev. ref`= if (!is.na(ref)) sprintf("%.3f", ref) else "\u2014",
    Delta      = if (!is.na(r$lambda) && !is.na(ref))
                   sprintf("%+.3f", r$lambda - ref) else "\u2014"
  )
})

md("## 3.1 lambda_CF — Counterfactual fleet turnover rate", "")

write_kbl(
  tbl_31 |>
    kable(format = "html", align = "lrrrlrr", escape = FALSE,
          col.names = c("Group", "Estimate", "SE", "95% CI",
                        "N obs", "Prev. ref", "\u0394"),
          caption = "Table 3.1: WLS lambda_CF by group (cold-engaged records)") |>
    kable_styling(full_width = FALSE, bootstrap_options = "bordered",
                  position = "left") |>
    add_header_above(
      c(" " = 1,
        "lambda_CF — slope of mean stage vs time (cold-engaged fleet, WLS)" = 6)
    )
)

md(
  "",
  "lambda_CF is the WLS slope of mean emissions Stage over time estimated from cold-engaged records only; SE and 95% CI are computed from vcov() of the lm() fit.",
  "Delta (\u0394) is the difference from the previous-trial reference value in schema.md Table 8; values within \u00b10.05 indicate consistency with prior work.",
  ""
)

# =============================================================================
# 3.2  e-bar — Non-compliance exposure rate
# =============================================================================
# All records (cold + warm) where initial_stage < COMP_THRESH[phase][group].
# Reported as % of all records in that group × phase cell.
# Variable_Speed exists only in Phase C; all earlier phase cells are blank (—).

# Helper: compute e-bar for one group × phase combination
compute_ebar <- function(grp, ph) {
  thresh_vec <- COMP_THRESH[[ph]]
  if (is.null(thresh_vec) || !(grp %in% names(thresh_vec))) {
    return(tibble(ebar_pct = NA_real_, n_nc = 0L, n_tot = 0L))
  }
  threshold <- thresh_vec[[grp]]

  dat   <- audits |> filter(group == grp, phase == ph, !is.na(initial_stage))
  n_tot <- nrow(dat)
  n_nc  <- sum(dat$initial_stage < threshold, na.rm = TRUE)

  tibble(
    ebar_pct = if (n_tot > 0L) 100 * n_nc / n_tot else NA_real_,
    n_nc     = as.integer(n_nc),
    n_tot    = as.integer(n_tot)
  )
}

ebar_long <- expand_grid(group = GROUP_ORDER, phase = c("A1", "A2", "B", "C")) |>
  rowwise() |>
  mutate(res = list(compute_ebar(group, phase))) |>
  unnest(res) |>
  ungroup()

save_obj(ebar_long, "ebar_results", "tbl_df",
         paste0(nrow(ebar_long), " \u00d7 5"), "3",
         "e-bar non-compliance exposure rate (%) by group x phase")

# Wide table: phases as column super-headers, sub-columns = ē% and N
ebar_wide <- ebar_long |>
  mutate(
    ebar_str = case_when(
      is.na(ebar_pct) | n_tot == 0L ~ "\u2014",
      TRUE ~ sprintf("%.1f%%", ebar_pct)
    ),
    n_str = if_else(n_tot == 0L, "\u2014", format(n_tot, big.mark = ","))
  ) |>
  select(group, phase, ebar_str, n_str) |>
  pivot_wider(
    names_from  = phase,
    values_from = c(ebar_str, n_str),
    names_glue  = "{phase}_{.value}"
  ) |>
  mutate(group = factor(group, levels = GROUP_ORDER)) |>
  arrange(group) |>
  select(
    group,
    A1_ebar_str, A1_n_str,
    A2_ebar_str, A2_n_str,
    B_ebar_str,  B_n_str,
    C_ebar_str,  C_n_str
  ) |>
  mutate(across(where(is.character), ~ replace_na(., "\u2014")))

col_display <- c("Group", "\u0113", "N", "\u0113", "N",
                 "\u0113", "N", "\u0113", "N")
names(ebar_wide) <- col_display

md("## 3.2 e-bar — Non-compliance exposure rate", "")

write_kbl(
  ebar_wide |>
    kable(format = "html", align = c("l", rep("r", 8)), escape = FALSE,
          caption = "Table 3.2: e-bar (% of records below compliance threshold) by group \u00d7 phase") |>
    kable_styling(full_width = FALSE, bootstrap_options = "bordered",
                  position = "left") |>
    add_header_above(
      c(" " = 1,
        "Phase A1" = 2, "Phase A2" = 2, "Phase B" = 2, "Phase C" = 2)
    )
)

md(
  "",
  "\u0113 is the percentage of all audited machines in that group\u2013phase cell whose initial emissions stage was strictly below the minimum required threshold; N is the total number of records in the cell.",
  "Variable_Speed rows show Phase C data only (P24 zone records, post-2025 CAZ+/RoL merger); all Phase A1, A2, and B cells for Variable_Speed are blank because that group did not exist before 1 January 2025.",
  ""
)

# =============================================================================
# 3.3  lambda_Policy and lambda_Proactive
# =============================================================================
# lambda_Policy : WLS slope of mean stage in WARM, SELF-COMPLIANT records
#                 (init_mach_emissions_compliant == TRUE, cold_engaged == FALSE).
#                 Captures combined natural turnover + proactive LEZ response.
# lambda_Proactive = max(0, lambda_Policy - lambda_CF).
# Same temporal aggregation structure as lambda_CF estimation per group.
# Sparsity guard: fit_lambda() returns NA row when n_pts < 2.

warm_sc <- audits |>
  filter(
    cold_engaged       == FALSE,
    init_mach_emissions_compliant == TRUE,
    group %in% c("Constant_Speed", "CAZ_Plus", "Rest_of_London")
  ) |>
  mutate(stage_capped = pmin(initial_stage, MAX_STAGE[group]))

# Constant Speed: annual midpoints 2016-2023
cs_wsc_annual <- warm_sc |>
  filter(
    group     == "Constant_Speed",
    frac_year >= PHASE_BOUNDS$A1[1],
    frac_year <  2024.0
  ) |>
  mutate(yr = floor(frac_year)) |>
  group_by(yr) |>
  summarise(
    mean_stage = mean(stage_capped, na.rm = TRUE),
    n          = n(),
    .groups    = "drop"
  ) |>
  mutate(mid = yr + 0.5)

lam_pol_cs <- fit_lambda(cs_wsc_annual)

# Variable-speed groups: A1/A2 pooled + B 3-segment
vs_pol_lambda <- function(grp) {
  dat   <- warm_sc |> filter(group == grp)
  max_s <- MAX_STAGE[[grp]]

  a12_mid <- (PHASE_BOUNDS$A1[1] + PHASE_BOUNDS$A2[2]) / 2
  a12 <- dat |>
    filter(
      frac_year >= PHASE_BOUNDS$A1[1],
      frac_year <= PHASE_BOUNDS$A2[2]
    ) |>
    summarise(
      mean_stage = mean(pmin(initial_stage, max_s), na.rm = TRUE),
      n          = n(),
      .groups    = "drop"
    ) |>
    mutate(mid = a12_mid)

  b_dat <- dat |>
    filter(
      frac_year >= PHASE_BOUNDS$B[1],
      frac_year <  PHASE_BOUNDS$B[2]
    ) |>
    mutate(stage_capped = pmin(initial_stage, max_s))

  b_pts <- phase_b_pts(b_dat)

  pts <- bind_rows(
    select(a12,   mid, mean_stage, n),
    select(b_pts, mid, mean_stage, n)
  )
  fit_lambda(pts)
}

lam_pol_caz <- vs_pol_lambda("CAZ_Plus")
lam_pol_rol <- vs_pol_lambda("Rest_of_London")

# Compute lambda_Proactive = max(0, lambda_Policy - lambda_CF)
proactive <- function(lam_pol, lam_cf) {
  if (is.na(lam_pol$lambda) || is.na(lam_cf$lambda)) return(NA_real_)
  max(0, lam_pol$lambda - lam_cf$lambda)
}

lambda_proactive_tbl <- tibble(
  group          = factor(GROUP_ORDER, levels = GROUP_ORDER),
  lam_policy     = c(lam_pol_cs$lambda, lam_pol_caz$lambda,
                     lam_pol_rol$lambda, NA_real_),
  se_policy      = c(lam_pol_cs$se, lam_pol_caz$se,
                     lam_pol_rol$se, NA_real_),
  lam_cf         = c(lam_cf_cs$lambda, lam_cf_caz$lambda,
                     lam_cf_rol$lambda, NA_real_),
  lam_proactive  = c(
    proactive(lam_pol_cs,  lam_cf_cs),
    proactive(lam_pol_caz, lam_cf_caz),
    proactive(lam_pol_rol, lam_cf_rol),
    NA_real_
  ),
  n_warm_sc      = c(
    as.integer(sum(cs_wsc_annual$n, na.rm = TRUE)),
    lam_pol_caz$n_obs,
    lam_pol_rol$n_obs,
    NA_integer_
  )
) |> arrange(group)

save_obj(lambda_proactive_tbl, "lambda_proactive", "tbl_df",
         paste0(nrow(lambda_proactive_tbl), " \u00d7 6"), "3",
         "lambda_Policy, lambda_CF, lambda_Proactive by group")

# Display table: super-headers separate estimation source columns from derived
# Plain ASCII column names used here; Unicode supplied via kable(col.names=)
tbl_33 <- lambda_proactive_tbl |>
  mutate(
    Group          = as.character(group),
    lam_policy_str = if_else(is.na(lam_policy), "\u2014",
                             sprintf("%.3f", lam_policy)),
    se_str         = if_else(is.na(se_policy), "\u2014",
                             sprintf("%.3f", se_policy)),
    lam_cf_str     = if_else(is.na(lam_cf), "\u2014",
                             sprintf("%.3f", lam_cf)),
    lam_pro_str    = case_when(
      is.na(lam_proactive) ~ "\u2014",
      lam_proactive == 0   ~ "0.000 (floored)",
      TRUE                 ~ sprintf("%.3f", lam_proactive)
    ),
    n_str          = if_else(is.na(n_warm_sc), "\u2014",
                             format(n_warm_sc, big.mark = ","))
  ) |>
  select(Group, lam_policy_str, se_str, lam_cf_str, lam_pro_str, n_str)

md("## 3.3 lambda_Policy and lambda_Proactive", "")

write_kbl(
  tbl_33 |>
    kable(format = "html", align = "lrrrrr", escape = FALSE,
          col.names = c("Group", "\u03bb_Policy", "SE",
                        "\u03bb_CF", "\u03bb_Proactive", "N warm sc."),
          caption = paste0("Table 3.3: \u03bb_Policy, \u03bb_CF, and \u03bb_Proactive by group")) |>
    kable_styling(full_width = FALSE, bootstrap_options = "bordered",
                  position = "left") |>
    add_header_above(
      c(" " = 1,
        "Warm self-compliant (WLS)" = 2,
        "Cold (WLS)" = 1,
        "Derived" = 1,
        " " = 1)
    )
)

md(
  "",
  paste0("\u03bb_Policy is the WLS slope of mean stage over time in warm, self-compliant records",
         " (emissions OK on arrival, no enforcement needed); it reflects combined natural",
         " turnover and proactive LEZ-driven replacement."),
  paste0("\u03bb_Proactive = max(0, \u03bb_Policy \u2212 \u03bb_CF) isolates the incremental rate",
         " attributable to proactive LEZ compliance; a floored value of 0.000 indicates no",
         " detectable proactive response above the counterfactual rate."),
  ""
)

# =============================================================================
# 3.4  Bundle all Step 3 estimates
# =============================================================================

step3_params <- list(
  lambda_cf         = lambda_cf,
  ebar_results      = ebar_long,
  lambda_proactive  = lambda_proactive_tbl
)

save_obj(step3_params, "step3_params", "list", "3 elements", "3",
         "All Step 3 estimates: lambda_CF, e-bar, lambda_Proactive")

# =============================================================================
# Glossary
# =============================================================================

md(
  "---",
  "## Glossary",
  "",
  "| Term | Definition |",
  "|------|------------|",
  paste0("| **\u03bb_CF** (lambda_CF) | Counterfactual fleet turnover rate: the annual rate of",
         " emissions stage improvement expected *without* LEZ enforcement, estimated from",
         " cold-engaged machines (unprompted arrivals). Units: stage integers per year. |"),
  paste0("| **\u03bb_Policy** (lambda_Policy) | Combined fleet improvement rate observed in warm,",
         " self-compliant machines (emissions OK on arrival). Captures both natural turnover",
         " and proactive LEZ-driven replacement. |"),
  paste0("| **\u03bb_Proactive** (lambda_Proactive) | Incremental improvement rate attributable to",
         " LEZ policy, computed as max(0, \u03bb_Policy \u2212 \u03bb_CF). Floored at zero because",
         " negative differences reflect noise, not regression. |"),
  paste0("| **\u0113** (e-bar) | Non-compliance exposure rate: % of all audited machines in a",
         " group\u2013phase cell whose initial stage was strictly below the minimum required",
         " threshold (schema.md Table 2). Computed on all records (cold + warm). |"),
  paste0("| **WLS** | Weighted least squares regression via lm() with the cell sample size as",
         " weights; SE extracted from vcov(). |"),
  paste0("| **Cold-engaged** | Machine present on site but not yet actively engaged with the",
         " LEZ compliance process; used to estimate the counterfactual turnover rate. |"),
  paste0("| **Warm self-compliant** | Machine whose initial emissions stage already met",
         " requirements at audit, with no enforcement action required (outcome Route 1). |"),
  paste0("| **MAX_STAGE** | Group-specific stage integer ceiling applied when computing mean",
         " stage for lambda estimation; CS = 3 (I\u2013IIIA), CAZ+/RoL/VS = 6 (up to Stage V). |"),
  "| **Phase A1** | 1 Jan 2016 \u2013 31 Dec 2018: pre-Stage V market availability. |",
  "| **Phase A2** | 1 Jan 2019 \u2013 31 Aug 2020: Stage V newly available. |",
  paste0("| **Phase B** | 1 Sep 2020 \u2013 31 Dec 2024: tighter LEZ requirements.",
         " COVID-exempt records (Sep 2020\u2013Mar 2021) excluded.",
         " Subdivided into 3 equal segments for variable-speed groups. |"),
  paste0("| **Phase C** | 1 Jan 2025 \u2013 31 Dec 2030: forecast horizon.",
         " CAZ+ and Rest of London merged into Variable_Speed (P24 zone). |"),
  ""
)

# =============================================================================
# Console summary
# =============================================================================

cat("\n=== Step 3 Parameter Estimation: Objects saved ===\n")
cat(sprintf("  lambda_cf        : list [%d groups]\n",       length(lambda_cf)))
cat(sprintf("  ebar_results     : tibble [%d \u00d7 %d]\n",
            nrow(ebar_long), ncol(ebar_long)))
cat(sprintf("  lambda_proactive : tibble [%d \u00d7 %d]\n",
            nrow(lambda_proactive_tbl), ncol(lambda_proactive_tbl)))
cat(sprintf("  step3_params     : list [3 elements]\n"))
cat(sprintf("\n  lambda_CF estimates:\n"))
for (g in c("Constant_Speed", "CAZ_Plus", "Rest_of_London")) {
  r   <- lambda_cf[[g]]
  ref <- REF_LAMBDA_CF[g]
  if (!is.na(r$lambda)) {
    cat(sprintf("    %-18s : %.3f (SE %.3f)  ref %.3f  \u0394 %+.3f\n",
                g, r$lambda, r$se, ref, r$lambda - ref))
  } else {
    cat(sprintf("    %-18s : NA (insufficient data)\n", g))
  }
}
cat(sprintf("\n  Output file: %s\n\n", OUT_FILE))

sessionInfo()
