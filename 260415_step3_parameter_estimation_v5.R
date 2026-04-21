# 260415_step3_parameter_estimation_v5.R
# Step 3: Parameter Estimation — Trial 5
#
# Changes vs Trial 4 (sprint_log.md):
#   FIX 3.4  Route 4 indicator corrected.
#            v4 used enforcement_upgrade (final_stage > initial_stage), which
#            captures only ~35 on-the-spot replacements (schema.md analytical
#            note 5). Most enforcement actions are machine removals or removals
#            from site, not in-place replacements, so no higher final_stage is
#            recorded → almost all records fell to Route 5 → near-zero rates.
#            Fix: Route 4 = final_mach_emissions_compliant == TRUE (no E code
#            in final machinery reasons), which captures all outcomes —
#            replacements, removals, and retrofits.
#            Caveat: blank final_machinery_reasons → final_mach_emissions_compliant
#            = TRUE (no E detected). If a non-actioned machine's final reasons
#            were left blank, it would be misclassified as Route 4 (slight
#            upward bias on success rate; flagged in output).
#
# Sub-tasks 3.1–3.3 are identical to Trials 3 and 4.
#
# Route definitions (schema.md Table 3):
#   Routes 4+5 = init_mach_emissions_compliant == FALSE (E code in initial reasons)
#   Route 4    = Routes 4+5 AND final_mach_emissions_compliant == TRUE
#                (no E code in final reasons: machine driven compliant by any
#                 means — replacement, removal, retrofit, or exemption)
#   Route 5    = Routes 4+5 AND final_mach_emissions_compliant == FALSE
#                (E code still present in final reasons: enforcement not actioned)

# ── Libraries ─────────────────────────────────────────────────────────────────
suppressPackageStartupMessages({
  library(tidyverse)
  library(knitr)
  library(kableExtra)
})

# ── Script constants ───────────────────────────────────────────────────────────
SCRIPT_STEM <- "260415_step3_parameter_estimation_v5"
OUT_FILE    <- file.path("outputs", paste0(SCRIPT_STEM, ".md"))
INT_DIR     <- "intermediate"
MANIFEST    <- file.path(INT_DIR, "manifest.md")

# Fixed group display order (schema.md Table 1)
GROUP_ORDER <- c("Constant_Speed", "CAZ_Plus", "Rest_of_London", "Variable_Speed")

# Active stage INTEGER ceiling by group (schema.md "Active state spaces" + decisions.md)
MAX_STAGE <- c(
  Constant_Speed = 3L,
  CAZ_Plus       = 6L,
  Rest_of_London = 6L,
  Variable_Speed = 6L
)

# Compliance thresholds — minimum stage integer required to be compliant.
# schema.md Table 2: "era ending" date = date that requirement TOOK EFFECT.
# A1/A2 = Col 1; B = Col 2; C = Col 3.
COMP_THRESH <- list(
  A1 = c(Constant_Speed = 3L, CAZ_Plus = 4L, Rest_of_London = 3L),
  A2 = c(Constant_Speed = 3L, CAZ_Plus = 4L, Rest_of_London = 3L),
  B  = c(Constant_Speed = 6L, CAZ_Plus = 5L, Rest_of_London = 4L),
  C  = c(Constant_Speed = 6L, Variable_Speed = 6L)
)

# Phase fractional-year boundaries [start, end) — schema.md Table 7
PHASE_BOUNDS <- list(
  A1 = c(2016.0000, 2018.9973),
  A2 = c(2019.0000, 2020.6667),
  B  = c(2020.6667, 2024.9973),
  C  = c(2025.0000, 2031.0000)
)

# Phase B: 3-segment break-points and midpoints (schema.md)
B_BREAKS <- c(2020.6667, 2022.1096, 2023.5534, 2024.9973)
B_MIDS   <- c(2021.389, 2022.832, 2024.278)

# Time period display order (Phase B expanded to 3 sub-segments)
PERIOD_ORDER <- c("A1", "A2", "B1", "B2", "B3", "C")

# Sparsity threshold for enforcement success rate interpretation
ENF_SPARSE_N <- 30L

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

tbl_31 <- map_dfr(GROUP_ORDER, function(g) {
  r   <- lambda_cf[[g]]
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

md("## 3.1 lambda_CF \u2014 Counterfactual fleet turnover rate", "")

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
        "lambda_CF \u2014 slope of mean stage vs time (cold-engaged fleet, WLS)" = 6)
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

md("## 3.2 e-bar \u2014 Non-compliance exposure rate", "")

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

warm_sc <- audits |>
  filter(
    cold_engaged       == FALSE,
    init_mach_emissions_compliant == TRUE,
    group %in% c("Constant_Speed", "CAZ_Plus", "Rest_of_London")
  ) |>
  mutate(stage_capped = pmin(initial_stage, MAX_STAGE[group]))

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
# 3.4  Enforcement success rate — Route 4/5 descriptive analysis
# =============================================================================
# Routes 4+5 = init_mach_emissions_compliant == FALSE (E code in initial reasons)
# Route 4    = init_mach_emissions_compliant == FALSE AND
#              final_mach_emissions_compliant == TRUE
#              (no E code in final reasons: driven compliant by any means —
#               replacement, removal from site, retrofit, or exemption)
# Route 5    = init_mach_emissions_compliant == FALSE AND
#              final_mach_emissions_compliant == FALSE
#              (E code still in final reasons: enforcement not actioned)
# Caveat: blank final_machinery_reasons resolves to final_mach_emissions_compliant
# = TRUE (no E detected). Auditors who left final reasons blank for a still-non-
# compliant machine would be misclassified as Route 4 (slight upward bias).
#
# Broken down by group × time period: A1, A2, B1, B2, B3, C.
# Phase C included if P24 records exist (Constant_Speed, Variable_Speed only;
# CAZ_Plus and Rest_of_London merged out from 1.1.2025).
# Sparsity flag: rate marked ⚠ where n(Routes 4+5) < ENF_SPARSE_N.
# Not a model parameter; not added to step3_params.

# Assign granular time-period label to every record
audits_period <- audits |>
  filter(group %in% GROUP_ORDER, !is.na(phase)) |>
  mutate(
    period = case_when(
      phase == "A1" ~ "A1",
      phase == "A2" ~ "A2",
      phase == "B"  ~ paste0("B", findInterval(frac_year, B_BREAKS[1:3])),
      phase == "C"  ~ "C",
      TRUE          ~ NA_character_
    )
  ) |>
  filter(!is.na(period), period %in% PERIOD_ORDER)

# Subset to Routes 4+5: emissions non-compliant at initial audit
routes45 <- audits_period |>
  filter(init_mach_emissions_compliant == FALSE)

# Compute counts per group × period
# Route 4: final_mach_emissions_compliant == TRUE (no E in final reasons)
# Route 5: final_mach_emissions_compliant == FALSE (E still present in final reasons)
enf_counts <- routes45 |>
  group_by(group, period) |>
  summarise(
    n_R4    = sum( final_mach_emissions_compliant == TRUE,  na.rm = TRUE),
    n_R5    = sum( final_mach_emissions_compliant == FALSE, na.rm = TRUE),
    n_total = n(),
    .groups = "drop"
  )

# Expand to all group × period combinations; fill zeros for absent combinations
enf_long <- expand_grid(
  group  = GROUP_ORDER,
  period = PERIOD_ORDER
) |>
  left_join(enf_counts, by = c("group", "period")) |>
  mutate(
    n_R4    = replace_na(as.integer(n_R4),    0L),
    n_R5    = replace_na(as.integer(n_R5),    0L),
    n_total = replace_na(as.integer(n_total), 0L),
    rate_pct = if_else(n_total > 0L, 100 * n_R4 / n_total, NA_real_),
    sparse   = n_total > 0L & n_total < ENF_SPARSE_N
  )

save_obj(enf_long, "enf_success_rate", "tbl_df",
         paste0(nrow(enf_long), " \u00d7 7"), "3",
         "Route 4/5 enforcement success rate by group x time period (descriptive)")

# Build display strings
# "—" for cells with zero total records (group not present in that period)
# "⚠" suffix on rate for sparse cells (n_total < ENF_SPARSE_N, but > 0)
enf_disp <- enf_long |>
  mutate(
    n_R4_str  = if_else(n_total == 0L, "\u2014", as.character(n_R4)),
    n_R5_str  = if_else(n_total == 0L, "\u2014", as.character(n_R5)),
    n_tot_str = if_else(n_total == 0L, "\u2014", as.character(n_total)),
    rate_str  = case_when(
      n_total == 0L ~ "\u2014",
      sparse        ~ sprintf("%.1f%%\u26a0", rate_pct),
      TRUE          ~ sprintf("%.1f%%",        rate_pct)
    )
  ) |>
  mutate(
    group  = factor(group, levels = GROUP_ORDER),
    period = factor(period, levels = PERIOD_ORDER)
  ) |>
  arrange(group, period)

# Pivot to wide: one block of 4 sub-columns per period
enf_wide_raw <- enf_disp |>
  select(group, period, n_R4_str, n_R5_str, n_tot_str, rate_str) |>
  pivot_wider(
    names_from  = period,
    values_from = c(n_R4_str, n_R5_str, n_tot_str, rate_str),
    names_glue  = "{period}__{.value}"
  )

# Reorder columns: group, then for each period in PERIOD_ORDER: n_R4, n_R5, n_tot, rate
# t() transposes so as.vector fills row-first: A1__n_R4, A1__n_R5, A1__n_tot, A1__rate,
# A2__n_R4, ... (interleaved order required by add_header_above grouping of 4 per phase)
col_seq <- as.vector(t(outer(PERIOD_ORDER, c("n_R4_str", "n_R5_str", "n_tot_str", "rate_str"),
                              FUN = function(p, v) paste0(p, "__", v))))
enf_wide <- enf_wide_raw |>
  mutate(group = as.character(group)) |>
  select(group, all_of(col_seq))

# Short sub-column names (4 per period block)
sub_col_names <- rep(c("n R4", "n R5", "n tot", "Rate%"), times = length(PERIOD_ORDER))
names(enf_wide) <- c("Group", sub_col_names)

# Header: 1 group col + 4 sub-cols per period
period_labels <- c(
  "Phase A1" = 4, "Phase A2" = 4,
  "Phase B1" = 4, "Phase B2" = 4, "Phase B3" = 4,
  "Phase C"  = 4
)
header_vec <- c(" " = 1, period_labels)

md("## 3.4 Enforcement success rate \u2014 Route 4/5 descriptive analysis", "")

write_kbl(
  enf_wide |>
    kable(format = "html", escape = FALSE,
          align = c("l", rep("r", length(sub_col_names))),
          caption = paste0(
            "Table 3.4: Route 4/5 enforcement success rate by group \u00d7 time period. ",
            "\u26a0 = n(Routes 4+5) < ", ENF_SPARSE_N, "; interpret with caution."
          )) |>
    kable_styling(full_width = FALSE, bootstrap_options = "bordered",
                  position = "left") |>
    add_header_above(header_vec)
)

md(
  "",
  paste0("n R4 = machines driven compliant by any means (Route 4; indicator: no E code in final machinery reasons);",
         " n R5 = E code still present in final reasons (Route 5; enforcement not actioned);",
         " Rate% = n R4 / n tot; \u26a0 = n tot < ", ENF_SPARSE_N, " (interpret with caution).",
         " Slight upward bias possible where auditors left final reasons blank for still-non-compliant machines."),
  paste0("Variable_Speed appears only in Phase C (P24 zone post-2025 merger); CAZ_Plus and Rest_of_London",
         " have no Phase C records; all such cells show \u2014."),
  ""
)

# =============================================================================
# 3.5  Bundle all Step 3 parameter estimates
# =============================================================================
# enf_success_rate is descriptive only; not included in step3_params.

step3_params <- list(
  lambda_cf         = lambda_cf,
  ebar_results      = ebar_long,
  lambda_proactive  = lambda_proactive_tbl
)

save_obj(step3_params, "step3_params", "list", "3 elements", "3",
         "All Step 3 model parameter estimates: lambda_CF, e-bar, lambda_Proactive")

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
  paste0("| **Route 4** | Audit outcome: initial emissions non-compliant; enforcement actioned;",
         " machine driven compliant by any means (replacement, removal from site, retrofit,",
         " or exemption). Identified here by final_mach_emissions_compliant == TRUE (no E",
         " code in final machinery reasons). |"),
  paste0("| **Route 5** | Audit outcome: initial emissions non-compliant; enforcement requested",
         " but not actioned; E code remains in final machinery reasons. |"),
  paste0("| **Enforcement success rate** | n(Route 4) / n(Routes 4+5): fraction of emissions-",
         "non-compliant audit records where enforcement resulted in the machine being driven",
         " compliant. Descriptive policy metric only; not used in transition matrices. |"),
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
         " Subdivided into 3 equal-interval segments (B1/B2/B3) for variable-speed groups. |"),
  paste0("| **Phase C** | 1 Jan 2025 \u2013 31 Dec 2030: forecast horizon.",
         " CAZ+ and Rest of London merged into Variable_Speed (P24 zone). |"),
  ""
)

# =============================================================================
# Console summary
# =============================================================================

cat("\n=== Step 3 Parameter Estimation v5: Objects saved ===\n")
cat(sprintf("  lambda_cf         : list [%d groups]\n",       length(lambda_cf)))
cat(sprintf("  ebar_results      : tibble [%d \u00d7 %d]\n",
            nrow(ebar_long), ncol(ebar_long)))
cat(sprintf("  lambda_proactive  : tibble [%d \u00d7 %d]\n",
            nrow(lambda_proactive_tbl), ncol(lambda_proactive_tbl)))
cat(sprintf("  enf_success_rate  : tibble [%d \u00d7 %d] (descriptive; not in step3_params)\n",
            nrow(enf_long), ncol(enf_long)))
cat(sprintf("  step3_params      : list [3 elements]\n"))

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

cat(sprintf("\n  Enforcement success rate (n R4 / n tot, by group x period):\n"))
enf_summary <- enf_long |>
  filter(n_total > 0) |>
  mutate(rate_str = sprintf("%.1f%%", rate_pct),
         sparse_flag = if_else(sparse, " [SPARSE]", ""))
for (i in seq_len(nrow(enf_summary))) {
  r <- enf_summary[i, ]
  cat(sprintf("    %-18s %3s : n=%3d (R4=%3d R5=%3d) rate=%s%s\n",
              r$group, r$period, r$n_total, r$n_R4, r$n_R5,
              r$rate_str, r$sparse_flag))
}

cat(sprintf("\n  Output file: %s\n\n", OUT_FILE))

sessionInfo()
