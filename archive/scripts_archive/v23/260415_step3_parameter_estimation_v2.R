# 260415_step3_parameter_estimation_v2.R
# NRMM LEZ Trend Analysis — Step 3: Parameter Estimation (Trial 2)
#
# Changes from v1 (see step3_v2_error_checklist.md):
#   E1  COMP_THRESH corrected: A1/A2 use "era ending 1.9.2020" column;
#       B uses "era ending 1.1.2025" column (schema.md Table 2)
#   E2  MAX_STAGE["CAZ_Plus"] = 6L (Stage V integer), not 5L (Stage IV);
#       "max_stage=5" in schema means 5 active stages (II–V, Stage I near-absent)
#   E3  Warm self-compliant sparsity reported explicitly before GLS fits;
#       NA results flagged in output with explanation, not silently returned
#   E4  e_bar_pct column added to e-bar display table
#   E5  position = "center" added to kable_styling() in save_table_md()
#
# Sub-tasks (draft_plan.md Step 3):
#   3.1  lambda_CF        — WLS on Stage proportions, cold fleet, group-specific max_stage
#   3.2  e-bar            — proportion below threshold, all records, by group × phase
#   3.3  lambda_Proactive — WLS on warm self-compliant fleet; lambda_Policy − lambda_CF
#   3.4  Report           — summary tables + cross-check against locked reference values
#
# Key decisions (decisions.md):
#   - CS max_stage = 3; phase window 2017–2023 (annual year-pairs; 2024 excluded)
#   - CAZ+ max_stage = 6 (integer; Stage V); Phase B primary via 3-segment temporal split
#   - RoL max_stage = 6; Phase B primary via 3-segment temporal split
#   - Phase A1/A2 variable speed: pooled as single A1→A2 transition (sparsity)
#   - e-bar = Stage-threshold proportion, all records (cold + warm)
#   - lambda_Policy from warm, route == "1_self_compliant" only
#   - lambda_Proactive = lambda_Policy − lambda_CF, floored at 0 (no e-bar subtraction)
#
# Inputs:
#   intermediate/audits_step2.rds   (12363 × 37: includes phase_sub, ze_flag, route)
#
# Outputs (intermediate/):
#   lambda_cf_estimates.rds   list: per-group WLS results (primary + sensitivity fits)
#   e_bar_estimates.rds       tbl_df: group × phase e-bar table
#   lambda_pol_estimates.rds  list: per-group lambda_Policy WLS results
#   lambda_proactive.rds      tbl_df: group × lambda_Proactive summary
#
# Outputs (outputs/):
#   260415_step3_parameter_estimation_v2.md

library(tidyverse)
library(kableExtra)

# ── Schema constants ───────────────────────────────────────────────────────────

OUT_DIR       <- "intermediate"
OUTPUTS_DIR   <- "outputs"
MANIFEST_FILE <- file.path(OUT_DIR, "manifest.md")
SCRIPT_STEM   <- "260415_step3_parameter_estimation_v2"

GROUP_ORDER  <- c("Constant_Speed", "CAZ_Plus", "Rest_of_London")

# Active stage space per group (schema.md "Active state spaces")
# CAZ+: 5 active stages (II–V, Stage I near-absent); max integer = 6 = Stage V
MAX_STAGE <- c(Constant_Speed = 3L, CAZ_Plus = 6L, Rest_of_London = 6L)

# Stage integer labels (List 1)
STAGE_LABELS <- c("1"="I","2"="II","3"="IIIA","4"="IIIB","5"="IV","6"="V","7"="ZE")

# Compliance thresholds by group × phase era (schema.md Table 2; stage integers)
# Column "era ending" semantics: Phase A1/A2 → era-ending col 2 (1.9.2020);
#                                Phase B     → era-ending col 3 (1.1.2025)
# [E1 fix] v1 used col-1 for A1/A2 and col-2 for B (one era behind)
COMP_THRESH <- list(
  A1 = c(Constant_Speed = 6L, CAZ_Plus = 5L, Rest_of_London = 4L),
  A2 = c(Constant_Speed = 6L, CAZ_Plus = 5L, Rest_of_London = 4L),
  B  = c(Constant_Speed = 6L, CAZ_Plus = 6L, Rest_of_London = 5L)
)

# Phase B temporal segment boundaries (schema.md Table 7; consistent with step 2)
PHASE_B_START <- as.Date("2020-09-01")
PHASE_B1_END  <- as.Date("2022-02-09")
PHASE_B2_END  <- as.Date("2023-07-21")
PHASE_B_END   <- as.Date("2024-12-31")

# Phase B segment midpoints — fractional years (schema.md; step3b confirmed)
SEG_B_MIDS <- c(2021.389, 2022.832, 2024.278)

# Phase A midpoints (fractional years; derived from exact phase boundaries)
# A1: 2016-01-01 to 2018-12-31; mid ≈ 2017-07-01 = 2017.497
# A2: 2019-01-01 to 2020-08-31; mid ≈ 2019-10-31 = 2019.832
PHASE_A1_MID <- 2017.497
PHASE_A2_MID <- 2019.832

# Locked reference lambda_CF values for cross-check (schema.md Table 8)
LAMBDA_CF_REF <- c(Constant_Speed = 0.358, CAZ_Plus = 0.363, Rest_of_London = 0.219)

# Anomaly threshold for cross-check flag
ANOMALY_THRESH <- 0.05

# Minimum viable warm self-compliant records per segment to attempt GLS fit
MIN_WARM_RECORDS <- 5L

# ── Helper functions ───────────────────────────────────────────────────────────

#' Assign Phase B sub-segment index (1, 2, or 3) from a Date vector.
#' Returns NA for dates outside Phase B.
assign_seg_b <- function(dates) {
  case_when(
    dates >= PHASE_B_START & dates <= PHASE_B1_END ~ 1L,
    dates >  PHASE_B1_END  & dates <= PHASE_B2_END ~ 2L,
    dates >  PHASE_B2_END  & dates <= PHASE_B_END  ~ 3L,
    TRUE ~ NA_integer_
  )
}

#' Build GLS rows from annual stage counts (annual year-pairs; dt = 1 year implicitly).
#' Inflow formula: sum of p[j] / (max_stage − j) for j < s (uniform spread assumption).
#' @param counts_df  tibble with columns: year (int), initial_stage (int), n (int)
#' @param max_stage  integer: maximum stage integer in active state space
#' @return tibble: t0, stage, stage_label, predictor, delta, weight
make_gls_annual <- function(counts_df, max_stage) {
  years <- sort(unique(counts_df$year))
  if (length(years) < 2L) return(tibble())

  get_props <- function(yr) {
    sub <- counts_df |> filter(year == yr, initial_stage <= max_stage)
    x   <- setNames(sub$n, as.character(sub$initial_stage))
    raw <- vapply(as.character(seq_len(max_stage)),
                  function(s) if (s %in% names(x)) as.numeric(x[[s]]) else 0,
                  numeric(1))
    total <- sum(raw)
    if (total == 0L) return(list(raw = raw, prop = rep(NA_real_, max_stage)))
    list(raw = raw, prop = raw / total)
  }

  bind_rows(lapply(seq_len(length(years) - 1L), function(i) {
    t0 <- years[i]; t1 <- years[i + 1L]
    r0 <- get_props(t0); r1 <- get_props(t1)
    if (anyNA(r0$prop) || anyNA(r1$prop)) return(NULL)
    p0 <- r0$prop; p1 <- r1$prop; c0 <- r0$raw

    bind_rows(lapply(seq_len(max_stage - 1L), function(s) {
      inflow    <- if (s == 1L) 0 else
        sum(vapply(seq_len(s - 1L),
                   function(j) p0[j] / (max_stage - j), numeric(1)))
      tibble(t0          = t0,
             stage       = s,
             stage_label = STAGE_LABELS[as.character(s)],
             predictor   = inflow - p0[s],
             delta       = p1[s] - p0[s],   # dt = 1 year; no annualisation needed
             weight      = pmax(c0[s], 1))
    }))
  }))
}

#' Build GLS rows from N temporal segments (N ≥ 2).
#' Delta is annualised by dividing by dt between consecutive segment midpoints.
#' @param seg_counts  list of N tibbles, each with columns: initial_stage (int), n (int)
#' @param seg_mids   numeric vector of N fractional-year midpoints
#' @param max_stage  integer
#' @return tibble: seg_pair, stage, stage_label, predictor, delta (annualised), weight, dt
make_gls_temporal <- function(seg_counts, seg_mids, max_stage) {
  n_segs <- length(seg_counts)
  stopifnot(length(seg_mids) == n_segs, n_segs >= 2L)

  get_props <- function(counts) {
    x   <- setNames(counts$n, as.character(counts$initial_stage))
    raw <- vapply(as.character(seq_len(max_stage)),
                  function(s) if (s %in% names(x)) as.numeric(x[[s]]) else 0,
                  numeric(1))
    total <- sum(raw)
    if (total == 0L) return(list(raw = raw, prop = rep(NA_real_, max_stage)))
    list(raw = raw, prop = raw / total)
  }

  seg_props <- lapply(seg_counts, get_props)

  bind_rows(lapply(seq_len(n_segs - 1L), function(i) {
    s0 <- seg_props[[i]]; s1 <- seg_props[[i + 1L]]
    dt <- seg_mids[i + 1L] - seg_mids[i]
    if (anyNA(s0$prop) || anyNA(s1$prop)) return(NULL)
    p0 <- s0$prop; p1 <- s1$prop; c0 <- s0$raw

    bind_rows(lapply(seq_len(max_stage - 1L), function(s) {
      inflow    <- if (s == 1L) 0 else
        sum(vapply(seq_len(s - 1L),
                   function(j) p0[j] / (max_stage - j), numeric(1)))
      tibble(seg_pair    = paste0(i, "->", i + 1L),
             stage       = s,
             stage_label = STAGE_LABELS[as.character(s)],
             predictor   = inflow - p0[s],
             delta       = (p1[s] - p0[s]) / dt,   # annualised
             weight      = pmax(c0[s], 1),
             dt          = dt)
    }))
  }))
}

#' Fit lambda via WLS: lm(delta ~ 0 + predictor, weights = weight).
#' SE extracted from vcov(). Returns NULL if no signal (logged to console).
#' @param gls_df  tibble with predictor, delta, weight
#' @param label   description for console output
#' @return list(lambda, se, ci_lo, ci_hi, n_rows) or NULL
fit_lambda_wls <- function(gls_df, label = "") {
  if (is.null(gls_df) || nrow(gls_df) == 0L ||
      anyNA(gls_df$predictor) || anyNA(gls_df$delta) ||
      sum(abs(gls_df$predictor) * gls_df$weight, na.rm = TRUE) < 1e-10) {
    message(sprintf("  %-64s  SKIPPED (no signal)", label))
    return(NULL)
  }
  fit <- lm(delta ~ 0 + predictor, data = gls_df, weights = weight)
  lam <- coef(fit)[["predictor"]]
  se  <- sqrt(vcov(fit)["predictor", "predictor"])
  ci  <- lam + c(-1.96, 1.96) * se
  message(sprintf("  %-64s  λ = %7.4f  SE = %6.4f  95%% CI [%7.4f, %7.4f]  n=%d",
                  label, lam, se, ci[1], ci[2], nrow(gls_df)))
  list(lambda = lam, se = se, ci_lo = ci[1], ci_hi = ci[2], n_rows = nrow(gls_df))
}

#' Write a kableExtra HTML table to the output .md file and print to console.
#' [E5 fix] position = "center" added to kable_styling()
#' @param df        data frame to render
#' @param caption   table caption string
#' @param out_file  path to output .md file
save_table_md <- function(df, caption, out_file) {
  tbl <- knitr::kable(df, format = "html", caption = caption, na = "—",
                      align = c("l", rep("r", ncol(df) - 1L))) |>
    kable_styling(bootstrap_options = c("condensed", "bordered"),
                  full_width = FALSE, font_size = 9, position = "center") |>
    row_spec(0, bold = TRUE)
  cat(paste0("\n### ", caption, "\n\n"), file = out_file, append = TRUE)
  cat(as.character(tbl), "\n", file = out_file, append = TRUE)
  cat("\n###", caption, "\n")
  print(knitr::kable(df, format = "simple", na = "—"))
  cat("\n")
  invisible(tbl)
}

#' Append new rows to the cumulative manifest.md.
update_manifest <- function(entries) {
  rows <- entries |>
    mutate(line = paste0("| ", object, " | ", file, " | ", class,
                         " | ", dim, " | ", step, " | ", description, " |")) |>
    pull(line)
  write(rows, file = MANIFEST_FILE, append = TRUE)
}

# ── Load data ──────────────────────────────────────────────────────────────────

message("=== ", SCRIPT_STEM, " — NRMM Step 3 ===\n")

audits <- readRDS(file.path(OUT_DIR, "audits_step2.rds"))
message("Loaded audits_step2.rds: ", nrow(audits), " rows x ", ncol(audits), " cols")

if (!dir.exists(OUTPUTS_DIR)) dir.create(OUTPUTS_DIR, recursive = TRUE)
out_file <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, ".md"))
writeLines(paste0("# Step 3 Parameter Estimation\n\nScript: ", SCRIPT_STEM,
                  "\nDate: ", Sys.Date()), out_file)

# Historical groups only (A1, A2, B); Phase C is forecast period / initialisation
audits_hist <- audits |>
  filter(group %in% GROUP_ORDER, phase %in% c("A1", "A2", "B"))

message("Historical groups (A1/A2/B): ", nrow(audits_hist), " records")

# Cold fleet: cold_engaged = TRUE, not ZE, historical
cold_hist <- audits_hist |> filter(cold_engaged, !ze_flag)
message("Cold-engaged (non-ZE, historical): ", nrow(cold_hist), " records")

# Summary: cold counts by group × phase (for context)
message("\nCold records by group × phase:")
cold_hist |>
  count(group, phase) |>
  pivot_wider(names_from = phase, values_from = n, values_fill = 0L) |>
  print()

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 1: lambda_CF (sub-task 3.1)
# ═══════════════════════════════════════════════════════════════════════════════

message("\n═══ SECTION 1: lambda_CF (cold fleet WLS) ═══\n")
cat("\n## Section 1: lambda_CF\n", file = out_file, append = TRUE)

lambda_cf_results <- list()

# ── 1a. Constant_Speed — annual year-pairs, max_stage=3, 2017–2023 ─────────────
message("-- Constant_Speed (max_stage=3) --")

cs_cold_counts <- cold_hist |>
  filter(group == "Constant_Speed", year >= 2017L, year <= 2023L,
         initial_stage <= MAX_STAGE[["Constant_Speed"]]) |>
  count(year, initial_stage, name = "n")

cs_gls_primary <- make_gls_annual(cs_cold_counts, MAX_STAGE[["Constant_Speed"]])

# Print GLS inspection rows
message("  GLS rows (", nrow(cs_gls_primary), " rows):")
print(cs_gls_primary |> mutate(across(where(is.double), round, 4)))

cs_primary <- fit_lambda_wls(cs_gls_primary, "CS 2017–2023 all phases pooled [primary]")

# Sensitivity: Phase A only (2017–2020)
cs_cold_A_counts <- cold_hist |>
  filter(group == "Constant_Speed", year >= 2017L, year <= 2020L,
         initial_stage <= MAX_STAGE[["Constant_Speed"]]) |>
  count(year, initial_stage, name = "n")
cs_phA <- fit_lambda_wls(
  make_gls_annual(cs_cold_A_counts, MAX_STAGE[["Constant_Speed"]]),
  "CS 2017–2020 Phase A only [sensitivity]")

# Sensitivity: Phase B only (2021–2023)
cs_cold_B_counts <- cold_hist |>
  filter(group == "Constant_Speed", year >= 2021L, year <= 2023L,
         initial_stage <= MAX_STAGE[["Constant_Speed"]]) |>
  count(year, initial_stage, name = "n")
cs_phB <- fit_lambda_wls(
  make_gls_annual(cs_cold_B_counts, MAX_STAGE[["Constant_Speed"]]),
  "CS 2021–2023 Phase B only [sensitivity]")

lambda_cf_results$Constant_Speed <- list(primary = cs_primary, phase_A = cs_phA, phase_B = cs_phB)

# ── 1b. CAZ_Plus — Phase B 3-segment (primary); Phase A1→A2 (sensitivity) ────
# [E2 fix] max_stage = 6L (integer for Stage V); v1 used 5L (= Stage IV), excluding Stage V
message("-- CAZ_Plus (max_stage=6) --")

caz_cold_B <- cold_hist |>
  filter(group == "CAZ_Plus", phase == "B",
         initial_stage <= MAX_STAGE[["CAZ_Plus"]]) |>
  mutate(seg = assign_seg_b(date))

message("  CAZ+ cold Phase B — records per segment:")
caz_cold_B |> count(seg) |> print()

caz_seg_counts_B <- lapply(1:3, function(i)
  caz_cold_B |> filter(seg == i) |> count(initial_stage, name = "n"))

caz_gls_B <- make_gls_temporal(caz_seg_counts_B, SEG_B_MIDS,
                                max_stage = MAX_STAGE[["CAZ_Plus"]])

message("  GLS rows Phase B (", nrow(caz_gls_B), " rows):")
print(caz_gls_B |> mutate(across(where(is.double), round, 4)))

caz_B_primary <- fit_lambda_wls(caz_gls_B, "CAZ+ Phase B 3-seg temporal [primary]")

# Sensitivity: Phase A1→A2 single transition
caz_A1_counts <- cold_hist |>
  filter(group == "CAZ_Plus", phase == "A1",
         initial_stage <= MAX_STAGE[["CAZ_Plus"]]) |>
  count(initial_stage, name = "n")
caz_A2_counts <- cold_hist |>
  filter(group == "CAZ_Plus", phase == "A2",
         initial_stage <= MAX_STAGE[["CAZ_Plus"]]) |>
  count(initial_stage, name = "n")

message("  CAZ+ cold Phase A1 n=", sum(caz_A1_counts$n),
        " A2 n=", sum(caz_A2_counts$n))

caz_gls_A <- make_gls_temporal(
  list(caz_A1_counts, caz_A2_counts),
  c(PHASE_A1_MID, PHASE_A2_MID),
  max_stage = MAX_STAGE[["CAZ_Plus"]])

caz_A_est <- fit_lambda_wls(caz_gls_A, "CAZ+ Phase A1→A2 pooled [sensitivity]")

lambda_cf_results$CAZ_Plus <- list(primary = caz_B_primary, phase_A = caz_A_est)

# ── 1c. Rest_of_London — Phase B 3-segment (primary); Phase A1→A2 (sensitivity) ─
message("-- Rest_of_London (max_stage=6) --")

rol_cold_B <- cold_hist |>
  filter(group == "Rest_of_London", phase == "B",
         initial_stage <= MAX_STAGE[["Rest_of_London"]]) |>
  mutate(seg = assign_seg_b(date))

message("  RoL cold Phase B — records per segment:")
rol_cold_B |> count(seg) |> print()

rol_seg_counts_B <- lapply(1:3, function(i)
  rol_cold_B |> filter(seg == i) |> count(initial_stage, name = "n"))

rol_gls_B <- make_gls_temporal(rol_seg_counts_B, SEG_B_MIDS,
                                max_stage = MAX_STAGE[["Rest_of_London"]])

message("  GLS rows Phase B (", nrow(rol_gls_B), " rows):")
print(rol_gls_B |> mutate(across(where(is.double), round, 4)))

rol_B_primary <- fit_lambda_wls(rol_gls_B, "RoL Phase B 3-seg temporal [primary]")

# Sensitivity: Phase A1→A2
rol_A1_counts <- cold_hist |>
  filter(group == "Rest_of_London", phase == "A1",
         initial_stage <= MAX_STAGE[["Rest_of_London"]]) |>
  count(initial_stage, name = "n")
rol_A2_counts <- cold_hist |>
  filter(group == "Rest_of_London", phase == "A2",
         initial_stage <= MAX_STAGE[["Rest_of_London"]]) |>
  count(initial_stage, name = "n")

message("  RoL cold Phase A1 n=", sum(rol_A1_counts$n),
        " A2 n=", sum(rol_A2_counts$n))

rol_gls_A <- make_gls_temporal(
  list(rol_A1_counts, rol_A2_counts),
  c(PHASE_A1_MID, PHASE_A2_MID),
  max_stage = MAX_STAGE[["Rest_of_London"]])

rol_A_est <- fit_lambda_wls(rol_gls_A, "RoL Phase A1→A2 pooled [sensitivity]")

lambda_cf_results$Rest_of_London <- list(primary = rol_B_primary, phase_A = rol_A_est)

# ── Summary table: lambda_CF primary estimates ───────────────────────────────

lam_cf_tbl <- bind_rows(lapply(GROUP_ORDER, function(grp) {
  prim <- lambda_cf_results[[grp]]$primary
  tibble(
    group        = grp,
    window       = switch(grp,
                          Constant_Speed  = "2017–2023 annual (all phases)",
                          CAZ_Plus        = "Phase B 3-segment temporal",
                          Rest_of_London  = "Phase B 3-segment temporal"),
    lambda_CF    = if (is.null(prim)) NA_real_ else round(prim$lambda, 4),
    se           = if (is.null(prim)) NA_real_ else round(prim$se,     4),
    ci_95_lo     = if (is.null(prim)) NA_real_ else round(prim$ci_lo,  4),
    ci_95_hi     = if (is.null(prim)) NA_real_ else round(prim$ci_hi,  4),
    n_gls_rows   = if (is.null(prim)) NA_integer_ else prim$n_rows,
    ref_locked   = LAMBDA_CF_REF[[grp]],
    delta_vs_ref = if (is.null(prim)) NA_real_
                   else round(prim$lambda - LAMBDA_CF_REF[[grp]], 4)
  )
}))

save_table_md(lam_cf_tbl,
              caption = paste0("lambda_CF — primary estimates vs locked reference",
                               " values (schema.md Table 8; |delta| > ",
                               ANOMALY_THRESH, " flagged)"),
              out_file = out_file)

# Sensitivity estimates table
lam_cf_sens <- bind_rows(lapply(GROUP_ORDER, function(grp) {
  res <- lambda_cf_results[[grp]]
  rows <- list()
  if (!is.null(res$phase_A))
    rows[[length(rows) + 1L]] <- tibble(
      group = grp, window = "Phase A sensitivity",
      lambda_CF = round(res$phase_A$lambda, 4),
      se        = round(res$phase_A$se,     4),
      n_rows    = res$phase_A$n_rows)
  if (!is.null(res$phase_B))
    rows[[length(rows) + 1L]] <- tibble(
      group = grp, window = "Phase B only",
      lambda_CF = round(res$phase_B$lambda, 4),
      se        = round(res$phase_B$se,     4),
      n_rows    = res$phase_B$n_rows)
  if (length(rows) > 0L) bind_rows(rows) else NULL
}))

save_table_md(lam_cf_sens,
              caption = "lambda_CF — sensitivity estimates by phase window",
              out_file = out_file)

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 2: e-bar (sub-task 3.2)
# ═══════════════════════════════════════════════════════════════════════════════

message("\n═══ SECTION 2: e-bar (enforcement exposure rate) ═══\n")
cat("\n## Section 2: e-bar\n", file = out_file, append = TRUE)

e_bar_rows <- bind_rows(lapply(GROUP_ORDER, function(grp) {
  bind_rows(lapply(c("A1", "A2", "B"), function(ph) {
    thresh <- COMP_THRESH[[ph]][[grp]]
    sub    <- audits_hist |> filter(group == grp, phase == ph)
    n_tot  <- nrow(sub)
    if (n_tot == 0L) return(NULL)
    n_nc   <- sum(sub$initial_stage < thresh, na.rm = TRUE)
    tibble(group          = grp,
           phase          = ph,
           threshold      = STAGE_LABELS[as.character(thresh)],
           threshold_int  = thresh,
           n_all_records  = n_tot,
           n_below_thresh = n_nc,
           e_bar          = round(n_nc / n_tot, 4),
           e_bar_pct      = round(n_nc / n_tot * 100, 1))  # [E4 fix]
  }))
}))

message("e-bar by group × phase:")
print(e_bar_rows)

save_table_md(e_bar_rows |> select(-threshold_int),
              caption = paste0("e-bar — proportion (and %) of all records below compliance threshold",
                               " (schema.md Table 2); all groups × historical phases"),
              out_file = out_file)

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 3: lambda_Policy and lambda_Proactive (sub-task 3.3)
# ═══════════════════════════════════════════════════════════════════════════════

message("\n═══ SECTION 3: lambda_Policy and lambda_Proactive ═══\n")
cat("\n## Section 3: lambda_Policy and lambda_Proactive\n", file = out_file, append = TRUE)

# Warm, self-compliant records only (route 1 = init_mach_emissions_compliant AND
# init_mach_admin_compliant; see decisions.md #5 and #6)
warm_self <- audits_hist |>
  filter(!cold_engaged, route == "1_self_compliant", !ze_flag)

# [E3 fix] Explicit sparsity report before any GLS attempt
# Step 2 pre-flagged near-zero Route 1 records in most phases; report counts here
message("Warm self-compliant records by group × phase (Route 1 subset):")
warm_self_counts <- warm_self |>
  count(group, phase) |>
  pivot_wider(names_from = phase, values_from = n, values_fill = 0L)
print(warm_self_counts)

cat("\n### Warm self-compliant record counts (Route 1)\n\n", file = out_file, append = TRUE)
save_table_md(warm_self_counts,
              caption = paste0("Warm self-compliant records by group × phase",
                               " (Route 1; basis for lambda_Policy estimation).",
                               " Known constraint: step 2 flagged near-zero Route 1 records in most phases."),
              out_file = out_file)

# Identify groups × phases with insufficient data
warm_self_by_grp_phase <- warm_self |> count(group, phase)
sparse_flag <- warm_self_by_grp_phase |> filter(n < MIN_WARM_RECORDS)
if (nrow(sparse_flag) > 0L) {
  message(sprintf("\nFLAG — %d group × phase cells below minimum (%d records) for lambda_Policy:",
                  nrow(sparse_flag), MIN_WARM_RECORDS))
  print(sparse_flag)
  cat(sprintf("\n**FLAG:** %d group × phase cells have fewer than %d warm self-compliant records; lambda_Policy will be NA for affected groups.\n\n",
              nrow(sparse_flag), MIN_WARM_RECORDS), file = out_file, append = TRUE)
}

lambda_pol_results <- list()

# ── 3a. Constant_Speed — annual year-pairs, max_stage=3, all available years ──
message("-- CS warm self-compliant --")

cs_warm_counts <- warm_self |>
  filter(group == "Constant_Speed",
         initial_stage <= MAX_STAGE[["Constant_Speed"]]) |>
  count(year, initial_stage, name = "n")

message("  CS warm self-compliant annual counts:")
print(cs_warm_counts)

cs_pol_primary <- fit_lambda_wls(
  make_gls_annual(cs_warm_counts, MAX_STAGE[["Constant_Speed"]]),
  "CS warm self-compl all years pooled [primary]")

# Phase B only sensitivity
cs_warm_B_counts <- warm_self |>
  filter(group == "Constant_Speed", phase == "B",
         initial_stage <= MAX_STAGE[["Constant_Speed"]]) |>
  count(year, initial_stage, name = "n")
cs_pol_B <- fit_lambda_wls(
  make_gls_annual(cs_warm_B_counts, MAX_STAGE[["Constant_Speed"]]),
  "CS warm self-compl Phase B only [sensitivity]")

lambda_pol_results$Constant_Speed <- list(primary = cs_pol_primary, phase_B = cs_pol_B)

# ── 3b. CAZ_Plus — Phase B 3-segment, max_stage=6 ────────────────────────────
# [E2 fix cascades here] max_stage = 6, so Stage V warm self-compliant records included
message("-- CAZ+ warm self-compliant --")

caz_warm_B <- warm_self |>
  filter(group == "CAZ_Plus", phase == "B",
         initial_stage <= MAX_STAGE[["CAZ_Plus"]]) |>
  mutate(seg = assign_seg_b(date))

message("  CAZ+ warm self-compliant Phase B — records per segment:")
caz_warm_B |> count(seg) |> print()

caz_warm_seg_B <- lapply(1:3, function(i)
  caz_warm_B |> filter(seg == i) |> count(initial_stage, name = "n"))

caz_pol_B <- fit_lambda_wls(
  make_gls_temporal(caz_warm_seg_B, SEG_B_MIDS, MAX_STAGE[["CAZ_Plus"]]),
  "CAZ+ warm self-compl Phase B 3-seg [primary]")

# Phase A sensitivity
caz_warm_A1 <- warm_self |>
  filter(group == "CAZ_Plus", phase == "A1",
         initial_stage <= MAX_STAGE[["CAZ_Plus"]]) |>
  count(initial_stage, name = "n")
caz_warm_A2 <- warm_self |>
  filter(group == "CAZ_Plus", phase == "A2",
         initial_stage <= MAX_STAGE[["CAZ_Plus"]]) |>
  count(initial_stage, name = "n")
caz_pol_A <- fit_lambda_wls(
  make_gls_temporal(list(caz_warm_A1, caz_warm_A2),
                    c(PHASE_A1_MID, PHASE_A2_MID), MAX_STAGE[["CAZ_Plus"]]),
  "CAZ+ warm self-compl Phase A1→A2 [sensitivity]")

lambda_pol_results$CAZ_Plus <- list(primary = caz_pol_B, phase_A = caz_pol_A)

# ── 3c. Rest_of_London — Phase B 3-segment, max_stage=6 ──────────────────────
message("-- RoL warm self-compliant --")

rol_warm_B <- warm_self |>
  filter(group == "Rest_of_London", phase == "B",
         initial_stage <= MAX_STAGE[["Rest_of_London"]]) |>
  mutate(seg = assign_seg_b(date))

message("  RoL warm self-compliant Phase B — records per segment:")
rol_warm_B |> count(seg) |> print()

rol_warm_seg_B <- lapply(1:3, function(i)
  rol_warm_B |> filter(seg == i) |> count(initial_stage, name = "n"))

rol_pol_B <- fit_lambda_wls(
  make_gls_temporal(rol_warm_seg_B, SEG_B_MIDS, MAX_STAGE[["Rest_of_London"]]),
  "RoL warm self-compl Phase B 3-seg [primary]")

rol_warm_A1 <- warm_self |>
  filter(group == "Rest_of_London", phase == "A1",
         initial_stage <= MAX_STAGE[["Rest_of_London"]]) |>
  count(initial_stage, name = "n")
rol_warm_A2 <- warm_self |>
  filter(group == "Rest_of_London", phase == "A2",
         initial_stage <= MAX_STAGE[["Rest_of_London"]]) |>
  count(initial_stage, name = "n")
rol_pol_A <- fit_lambda_wls(
  make_gls_temporal(list(rol_warm_A1, rol_warm_A2),
                    c(PHASE_A1_MID, PHASE_A2_MID), MAX_STAGE[["Rest_of_London"]]),
  "RoL warm self-compl Phase A1→A2 [sensitivity]")

lambda_pol_results$Rest_of_London <- list(primary = rol_pol_B, phase_A = rol_pol_A)

# ── Compute lambda_Proactive = lambda_Policy − lambda_CF, floored at 0 ────────
# e-bar NOT subtracted: non-compliant machines excluded from warm self-compliant
# estimation window by construction (decisions.md #6)

proactive_tbl <- bind_rows(lapply(GROUP_ORDER, function(grp) {
  pol <- lambda_pol_results[[grp]]$primary
  cf  <- lambda_cf_results[[grp]]$primary
  raw <- if (!is.null(pol) && !is.null(cf)) pol$lambda - cf$lambda else NA_real_
  na_reason <- if (is.na(raw)) {
    if (is.null(pol) && is.null(cf)) "lambda_Policy and lambda_CF both NA"
    else if (is.null(pol)) "lambda_Policy NA (insufficient warm self-compliant records)"
    else "lambda_CF NA"
  } else NA_character_
  tibble(
    group                = grp,
    lambda_policy        = if (!is.null(pol)) round(pol$lambda, 4) else NA_real_,
    se_policy            = if (!is.null(pol)) round(pol$se,     4) else NA_real_,
    lambda_cf            = if (!is.null(cf))  round(cf$lambda,  4) else NA_real_,
    se_cf                = if (!is.null(cf))  round(cf$se,      4) else NA_real_,
    lambda_proactive_raw = round(raw, 4),
    lambda_proactive     = round(max(raw, 0, na.rm = TRUE), 4),
    floored              = !is.na(raw) & raw < 0,
    na_reason            = na_reason
  )
}))

message("\nlambda_Proactive results:")
print(proactive_tbl)

# Separate display table (drop internal na_reason if no NAs; keep if any exist)
proactive_display <- if (all(is.na(proactive_tbl$na_reason))) {
  proactive_tbl |> select(-na_reason)
} else {
  proactive_tbl
}

save_table_md(proactive_display,
              caption = paste0("lambda_Proactive = lambda_Policy − lambda_CF",
                               " (warm self-compliant fleet, Phase B primary;",
                               " floored at 0; e-bar not subtracted per decisions.md #6)"),
              out_file = out_file)

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 4: Summary and cross-check (sub-task 3.4)
# ═══════════════════════════════════════════════════════════════════════════════

message("\n═══ SECTION 4: Summary and cross-check ═══\n")
cat("\n## Section 4: Summary and cross-check\n", file = out_file, append = TRUE)

# Full parameter summary table
e_bar_B <- e_bar_rows |> filter(phase == "B") |> select(group, e_bar_B = e_bar, e_bar_B_pct = e_bar_pct)
e_bar_A <- e_bar_rows |> filter(phase %in% c("A1", "A2")) |>
  group_by(group) |>
  summarise(e_bar_A     = round(mean(e_bar), 4),
            e_bar_A_pct = round(mean(e_bar) * 100, 1),
            .groups = "drop")

summary_tbl <- lam_cf_tbl |>
  select(group, window, lambda_CF, se, ci_95_lo, ci_95_hi, ref_locked, delta_vs_ref) |>
  left_join(e_bar_A,  by = "group") |>
  left_join(e_bar_B,  by = "group") |>
  left_join(proactive_tbl |> select(group, lambda_policy, lambda_proactive),
            by = "group")

save_table_md(summary_tbl,
              caption = "Step 3 full parameter summary (Phase B primary estimates)",
              out_file = out_file)

# Anomaly report
message("Cross-check against locked values (schema.md Table 8):")
message(sprintf("  %-20s  %s", "Group", "Δ vs locked"))
anomaly_flag <- FALSE
for (grp in GROUP_ORDER) {
  prim <- lambda_cf_results[[grp]]$primary
  ref  <- LAMBDA_CF_REF[[grp]]
  if (!is.null(prim)) {
    d    <- prim$lambda - ref
    flag <- if (abs(d) > ANOMALY_THRESH) " *** ANOMALY ***" else ""
    if (abs(d) > ANOMALY_THRESH) anomaly_flag <- TRUE
    message(sprintf("  %-20s  new=%.4f  ref=%.4f  delta=%+.4f%s",
                    grp, prim$lambda, ref, d, flag))
  } else {
    message(sprintf("  %-20s  SKIPPED (no estimate)", grp))
  }
}
if (!anomaly_flag) message("  All lambda_CF within ±", ANOMALY_THRESH, " of locked values. No anomalies.")

# Flooring report for lambda_Proactive
n_floored <- sum(proactive_tbl$floored, na.rm = TRUE)
if (n_floored > 0L) {
  message("\nFLAG — ", n_floored, " group(s) had lambda_Proactive floored at 0:")
  print(proactive_tbl |> filter(floored) |> select(group, lambda_proactive_raw))
}

# NA report for lambda_Proactive
n_na_pol <- sum(is.na(proactive_tbl$lambda_policy))
if (n_na_pol > 0L) {
  message("\nNOTE — ", n_na_pol, " group(s) have lambda_Policy = NA:")
  print(proactive_tbl |> filter(is.na(lambda_policy)) |>
          select(group, na_reason))
  cat(sprintf("\n**Note:** %d group(s) have lambda_Policy = NA (see Route 1 sparsity table above).\n",
              n_na_pol), file = out_file, append = TRUE)
}

message("\n[STOP] All parameter estimates written to outputs/", SCRIPT_STEM, ".md")
message("Review lambda_CF cross-check and lambda_Proactive tables before Step 4.")

# ── Save intermediate objects ──────────────────────────────────────────────────

saveRDS(lambda_cf_results,  file.path(OUT_DIR, "lambda_cf_estimates.rds"))
saveRDS(e_bar_rows,         file.path(OUT_DIR, "e_bar_estimates.rds"))
saveRDS(lambda_pol_results, file.path(OUT_DIR, "lambda_pol_estimates.rds"))
saveRDS(proactive_tbl,      file.path(OUT_DIR, "lambda_proactive.rds"))

manifest_entries <- tibble(
  object = c("lambda_cf_estimates", "e_bar_estimates",
             "lambda_pol_estimates", "lambda_proactive"),
  file   = file.path("intermediate",
                     c("lambda_cf_estimates.rds", "e_bar_estimates.rds",
                       "lambda_pol_estimates.rds", "lambda_proactive.rds")),
  class  = c("list", "tbl_df", "list", "tbl_df"),
  dim    = c(
    paste0(length(lambda_cf_results), " groups"),
    paste0(nrow(e_bar_rows), " x ", ncol(e_bar_rows)),
    paste0(length(lambda_pol_results), " groups"),
    paste0(nrow(proactive_tbl), " x ", ncol(proactive_tbl))
  ),
  step        = "step3",
  description = c(
    "lambda_CF WLS estimates: named list per group with primary + sensitivity fits",
    "e-bar: proportion (and pct) below compliance threshold, all records, group x phase",
    "lambda_Policy WLS estimates: named list per group, warm self-compliant fleet",
    "lambda_Proactive: lambda_Policy - lambda_CF, floored at 0, 3 groups x summary cols"
  )
)
update_manifest(manifest_entries)
message("Manifest updated: ", MANIFEST_FILE)

message("\n=== OBJECTS SAVED (step 3) ===")
message(sprintf("  %-28s  %-8s  %s", "object", "class", "dim"))
for (i in seq_len(nrow(manifest_entries))) {
  message(sprintf("  %-28s  %-8s  %s",
                  manifest_entries$object[i],
                  manifest_entries$class[i],
                  manifest_entries$dim[i]))
}

sessionInfo()
