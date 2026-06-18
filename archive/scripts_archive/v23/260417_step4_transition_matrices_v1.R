# 260417_step4_transition_matrices_v1.R
# Step 4: Transition matrix construction
#
# Substeps covered (all three):
#   4.1  Construct P_Natural, P_Enforcement, P_Proactive per group (6×6)
#   4.2  Combine into P_Total; enforce row-stochasticity; floor-and-rescale
#   4.3  Validate matrices against observed Stage distributions
#
# Design notes:
#   - All Phase C matrices are 6×6 (Stage I–V integer 1–6; ZE excluded).
#     MAX_STAGE=3 for CS was estimation-only; P24 data shows Stage V CS machines.
#   - p_cf = lambda_CF / avg_stage_jump, where avg_stage_jump is computed from the
#     same estimation-window cold records used to estimate lambda_CF. This preserves
#     the structural replacement hazard; the implied lambda in Phase C will differ
#     slightly due to a different stage distribution, but p_cf is the consistent
#     structural estimate.
#   - p_enf from Phase B Route 4/5 audit outcomes: n(Route 4) / n(Routes 4+5)
#     / phase_B_years. Enforcement drives non-compliant machines to the compliance
#     threshold (Stage V = integer 6 in Phase C).
#   - Variable_Speed p parameters are weighted averages of CAZ+ and Rest_of_London,
#     weighted by Phase B cold N (for p_cf/p_pro) and non-compliant N (for p_enf).
#   - P_Total combines all three channels additively; row sums capped at 1 then
#     rescaled to enforce right-stochasticity.
#   - P_Total Scenario B (enforcement Boolean mask) is applied in Step 5, not here.
#     Step 4 builds probabilistic P_Enforcement; Step 5 applies the deterministic mask.
#
# Inputs:
#   intermediate/audits.rds        — Step 1 (base audit data)
#   intermediate/audits_step2.rds  — Step 2 (adds compliance route column)
#   intermediate/step3_params.rds  — Step 3 (lambda_CF, lambda_Proactive, e-bar)
#
# Outputs (intermediate/):
#   p_natural.rds, p_proactive.rds, p_enforcement.rds, p_total.rds, step4_matrices.rds
# Outputs (outputs/):
#   260417_step4_transition_matrices_v1.md

suppressPackageStartupMessages({
  library(tidyverse)
  library(knitr)
  library(kableExtra)
})

# ── Script constants ────────────────────────────────────────────────────────────

SCRIPT_STEM <- "260417_step4_transition_matrices_v1"
OUT_FILE    <- file.path("outputs", paste0(SCRIPT_STEM, ".md"))
INT_DIR     <- "intermediate"
MANIFEST    <- file.path(INT_DIR, "manifest.md")

GROUP_ORDER    <- c("Constant_Speed", "CAZ_Plus", "Rest_of_London", "Variable_Speed")
PHASE_C_GROUPS <- c("Constant_Speed", "Variable_Speed")

# State space for all Phase C matrices
FORECAST_MAX_STAGE <- 6L   # Stage V = integer 6

# Stage labels for display
STAGE_LABELS <- c("I", "II", "IIIA", "IIIB", "IV", "V")
names(STAGE_LABELS) <- as.character(1:6)

# Estimation ceiling per group (used to compute avg_stage_jump from historical data)
# CS: max_stage=3 in estimation window (2016-2023 cold fleet, Stage V absent)
# VS groups: max_stage=6 (full stage range in estimation window)
EST_MAX_STAGE <- c(Constant_Speed = 3L, CAZ_Plus = 6L, Rest_of_London = 6L)

# Phase B compliance thresholds (for p_enf estimation from Phase B audit data)
PHASE_B_THRESH <- c(Constant_Speed = 6L, CAZ_Plus = 5L, Rest_of_London = 4L)

# Phase C compliance thresholds (decisions.md COMP_THRESH C)
PHASE_C_THRESH <- c(Constant_Speed = 6L, Variable_Speed = 6L)

# Phase boundaries (fractional years; schema.md Table 7)
PHASE_BOUNDS <- list(
  A1 = c(2016.0000, 2018.9973),
  A2 = c(2019.0000, 2020.6667),
  B  = c(2020.6667, 2024.9973),
  C  = c(2025.0000, 2031.0000)
)
PHASE_B_YEARS <- diff(PHASE_BOUNDS$B)   # ≈ 4.331

# Locked Step 3 estimates (decisions.md / schema.md Table 8)
LAMBDA_CF_LOCKED <- c(
  Constant_Speed = 0.051,
  CAZ_Plus       = 0.262,
  Rest_of_London = 0.241
)
LAMBDA_PRO_LOCKED <- c(
  Constant_Speed = 0.000,
  CAZ_Plus       = 0.013,
  Rest_of_London = 0.000
)

# ── Helper functions ────────────────────────────────────────────────────────────

#' Enforce right-stochasticity: floor negatives at 0, rescale rows to sum to 1.
#' Arguments:
#'   mat : numeric matrix
#' Returns rescaled matrix with row sums == 1.
enforce_stochastic <- function(mat) {
  mat <- pmax(mat, 0)
  rs  <- rowSums(mat)
  # Guard: if a row is all zero (degenerate), set diagonal to 1
  all_zero <- rs == 0
  if (any(all_zero)) {
    for (i in which(all_zero)) mat[i, i] <- 1
    rs <- rowSums(mat)
  }
  sweep(mat, 1, rs, "/")
}

#' Build P_Natural: right-stochastic matrix where each non-top stage transitions to
#' max_stage with prob p_cf, and stays with prob 1 - p_cf.
#' Arguments:
#'   max_stage : integer, dimension of the square matrix
#'   p_cf      : replacement probability per year (scalar)
#' Returns a max_stage × max_stage right-stochastic matrix.
build_natural <- function(max_stage, p_cf) {
  p_cf <- min(max(p_cf, 0), 0.99)
  mat  <- diag(max_stage)
  for (i in seq_len(max_stage - 1L)) {
    mat[i, i]         <- 1 - p_cf
    mat[i, max_stage] <- p_cf
  }
  # Row max_stage is already (0,...,0,1) from diag() — absorbing state
  enforce_stochastic(mat)
}

#' Build P_Enforcement: right-stochastic matrix where stages below threshold
#' transition to threshold with prob p_enf, and stay with prob 1 - p_enf.
#' Arguments:
#'   max_stage : integer, dimension
#'   p_enf     : annual enforcement probability for non-compliant machines (scalar)
#'   threshold : integer, minimum compliant stage
#' Returns a max_stage × max_stage right-stochastic matrix.
build_enforcement <- function(max_stage, p_enf, threshold) {
  p_enf <- min(max(p_enf, 0), 0.99)
  mat   <- diag(max_stage)
  for (i in seq_len(threshold - 1L)) {
    mat[i, i]         <- 1 - p_enf
    mat[i, threshold] <- p_enf
  }
  enforce_stochastic(mat)
}

#' Combine P_Natural, P_Proactive, P_Enforcement into P_Total via additive channels.
#' For each row i:
#'   - Compliant (i >= threshold): upgrade to max_stage at rate p_cf + p_pro
#'   - Non-compliant (i < threshold): upgrade at rate p_cf + p_pro + p_enf
#'     (all three channels target max_stage when threshold == max_stage in Phase C)
#' Arguments:
#'   max_stage : integer, dimension
#'   p_cf      : natural replacement probability
#'   p_pro     : proactive replacement probability
#'   p_enf     : enforcement probability (for non-compliant stages only)
#'   threshold : integer, minimum compliant stage
#' Returns a max_stage × max_stage right-stochastic matrix.
build_total <- function(max_stage, p_cf, p_pro, p_enf, threshold) {
  mat <- diag(max_stage)
  for (i in seq_len(max_stage)) {
    if (i == max_stage) {
      mat[i, i] <- 1
    } else {
      p_up <- p_cf + p_pro + if (i < threshold) p_enf else 0
      # When threshold == max_stage (Phase C), enforcement and nat/pro go to same column
      mat[i, i]         <- 1 - min(p_up, 0.99)
      mat[i, max_stage] <- min(p_up, 0.99)
    }
  }
  enforce_stochastic(mat)
}

#' Compute implied lambda from a transition matrix and an initial stage distribution.
#' lambda_implied = dot(pi, row_mean_stage_change) = Σᵢ πᵢ × (Σⱼ P[i,j] × j - i)
#' Arguments:
#'   mat       : max_stage × max_stage right-stochastic transition matrix
#'   pi        : named numeric vector of stage proportions (must sum to 1)
#'   max_stage : integer
#' Returns scalar lambda.
implied_lambda <- function(mat, pi, max_stage) {
  stages <- seq_len(max_stage)
  expected_new_stage <- as.vector(mat %*% stages)
  delta_per_stage    <- expected_new_stage - stages
  sum(pi * delta_per_stage)
}

#' Save RDS and append one row to the manifest.
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

# Append lines to output markdown
md <- function(...) write_lines(c(...), OUT_FILE, append = TRUE)

# Write a kableExtra HTML object to output markdown
write_kbl <- function(kbl_obj) write_lines(as.character(kbl_obj), OUT_FILE, append = TRUE)

# ── Load inputs ─────────────────────────────────────────────────────────────────

audits      <- readRDS(file.path(INT_DIR, "audits.rds"))
audits_s2   <- readRDS(file.path(INT_DIR, "audits_step2.rds"))
step3       <- readRDS(file.path(INT_DIR, "step3_params.rds"))

# Ensure frac_year column present (aliased from date_frac in Step 3)
if (!"frac_year" %in% names(audits) && "date_frac" %in% names(audits)) {
  audits <- audits |> rename(frac_year = date_frac)
}
if (!"frac_year" %in% names(audits_s2) && "date_frac" %in% names(audits_s2)) {
  audits_s2 <- audits_s2 |> rename(frac_year = date_frac)
}

# ── Initialise output file ──────────────────────────────────────────────────────

write_lines(
  c(paste0("# Step 4 Transition Matrices — ", SCRIPT_STEM),
    paste0("*Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "*"),
    ""),
  OUT_FILE, append = FALSE
)

# =============================================================================
# 4.1  avg_stage_jump and replacement probabilities (p_cf, p_pro, p_enf)
# =============================================================================

md("## 4.1 Replacement probabilities", "")

# --- avg_stage_jump from estimation-window cold records ---
# Uses the SAME cold records used to estimate lambda_CF (not Phase C init data).
# This preserves the structural interpretation of p_cf as the underlying machine
# replacement hazard, independent of the current fleet stage distribution.

compute_avg_jump <- function(dat, grp, est_max, phase_bounds) {
  # Constant Speed: cold records 2016-2023 (2024 excluded per decisions.md)
  # Variable-speed groups: cold A1/A2 + Phase B
  if (grp == "Constant_Speed") {
    sub <- dat |>
      filter(
        group        == "Constant_Speed",
        cold_engaged == TRUE,
        frac_year    >= phase_bounds$A1[1],
        frac_year    <  2024.0
      ) |>
      mutate(stage_capped = pmin(initial_stage, est_max))
  } else {
    sub <- dat |>
      filter(
        group        == grp,
        cold_engaged == TRUE,
        frac_year    >= phase_bounds$A1[1],
        frac_year    <  phase_bounds$B[2]
      ) |>
      mutate(stage_capped = pmin(initial_stage, est_max))
  }

  sub <- sub |> filter(!is.na(stage_capped), is.finite(stage_capped))
  if (nrow(sub) == 0L) return(list(wmean = NA_real_, n = 0L, avg_jump = NA_real_))

  wmean    <- mean(sub$stage_capped)  # unweighted mean (one record = one machine observation)
  avg_jump <- est_max - wmean

  list(wmean = wmean, n = nrow(sub), avg_jump = avg_jump)
}

jump_cs  <- compute_avg_jump(audits, "Constant_Speed",  EST_MAX_STAGE["Constant_Speed"],  PHASE_BOUNDS)
jump_caz <- compute_avg_jump(audits, "CAZ_Plus",        EST_MAX_STAGE["CAZ_Plus"],        PHASE_BOUNDS)
jump_rol <- compute_avg_jump(audits, "Rest_of_London",  EST_MAX_STAGE["Rest_of_London"],  PHASE_BOUNDS)

# Variable_Speed: weighted average of CAZ+ and RoL parameters, weighted by Phase B cold N
n_caz_b <- audits |>
  filter(group == "CAZ_Plus", cold_engaged == TRUE,
         frac_year >= PHASE_BOUNDS$B[1], frac_year < PHASE_BOUNDS$B[2]) |>
  nrow()
n_rol_b <- audits |>
  filter(group == "Rest_of_London", cold_engaged == TRUE,
         frac_year >= PHASE_BOUNDS$B[1], frac_year < PHASE_BOUNDS$B[2]) |>
  nrow()
w_total  <- n_caz_b + n_rol_b

lambda_cf_vs  <- (n_caz_b * LAMBDA_CF_LOCKED["CAZ_Plus"] +
                  n_rol_b * LAMBDA_CF_LOCKED["Rest_of_London"]) / w_total
lambda_pro_vs <- (n_caz_b * LAMBDA_PRO_LOCKED["CAZ_Plus"] +
                  n_rol_b * LAMBDA_PRO_LOCKED["Rest_of_London"]) / w_total
avg_jump_vs   <- (n_caz_b * jump_caz$avg_jump +
                  n_rol_b * jump_rol$avg_jump) / w_total

# Compute p_cf and p_pro per group
# Guard: if avg_jump <= 0 (all machines at max stage), p = 0
safe_p <- function(lambda, avg_jump) {
  if (is.na(avg_jump) || avg_jump <= 0 || is.na(lambda)) return(0)
  min(lambda / avg_jump, 0.99)
}

p_cf <- c(
  Constant_Speed = safe_p(LAMBDA_CF_LOCKED["Constant_Speed"],  jump_cs$avg_jump),
  CAZ_Plus       = safe_p(LAMBDA_CF_LOCKED["CAZ_Plus"],        jump_caz$avg_jump),
  Rest_of_London = safe_p(LAMBDA_CF_LOCKED["Rest_of_London"],  jump_rol$avg_jump),
  Variable_Speed = safe_p(lambda_cf_vs,                        avg_jump_vs)
)
p_pro <- c(
  Constant_Speed = safe_p(LAMBDA_PRO_LOCKED["Constant_Speed"], jump_cs$avg_jump),
  CAZ_Plus       = safe_p(LAMBDA_PRO_LOCKED["CAZ_Plus"],       jump_caz$avg_jump),
  Rest_of_London = safe_p(LAMBDA_PRO_LOCKED["Rest_of_London"], jump_rol$avg_jump),
  Variable_Speed = safe_p(lambda_pro_vs,                       avg_jump_vs)
)

# --- p_enf from Phase B Route 4/5 audit data ---
# p_enf = n(Route 4 emissions non-compliance) / n(Routes 4+5) / phase_B_years
# Interpretation: of all non-compliant audit events in Phase B, what fraction per year
# resulted in enforcement-driven compliance upgrade?
# Route identifiers from audits_step2 (classify_route() in Step 2):
#   "4_driven_compliant_emissions" = enforcement success
#   "5_non_compliant"              = enforcement failure

compute_p_enf <- function(dat_s2, grp, phase_b_years) {
  # Route 4 = enforcement success (emissions non-compliant, machine removed/replaced)
  # Route 5 = enforcement failure (emissions non-compliant, not actioned)
  # Route classification in audits_step2 already reflects group-specific Phase B
  # thresholds, so no additional threshold filter is needed here.
  sub <- dat_s2 |>
    filter(
      group        == grp,
      phase        == "B",
      route %in% c("4_driven_compliant_emissions", "5_non_compliant")
    )
  n4  <- sum(sub$route == "4_driven_compliant_emissions")
  n45 <- nrow(sub)
  if (n45 == 0L) return(list(n4 = 0L, n45 = 0L, p_enf = 0))
  # Annualise: proportion of enforcement events per non-compliant audit per year
  list(n4 = n4, n45 = n45,
       p_enf = min((n4 / n45) / phase_b_years, 0.99))
}

enf_cs  <- compute_p_enf(audits_s2, "Constant_Speed",  PHASE_B_YEARS)
enf_caz <- compute_p_enf(audits_s2, "CAZ_Plus",        PHASE_B_YEARS)
enf_rol <- compute_p_enf(audits_s2, "Rest_of_London",  PHASE_B_YEARS)

# Variable_Speed p_enf: weighted average by Phase B non-compliant N
n_nc_caz <- enf_caz$n45
n_nc_rol <- enf_rol$n45
n_nc_tot <- n_nc_caz + n_nc_rol
p_enf_vs  <- if (n_nc_tot == 0L) 0 else
  (n_nc_caz * enf_caz$p_enf + n_nc_rol * enf_rol$p_enf) / n_nc_tot

p_enf <- c(
  Constant_Speed = enf_cs$p_enf,
  CAZ_Plus       = enf_caz$p_enf,
  Rest_of_London = enf_rol$p_enf,
  Variable_Speed = p_enf_vs
)

# --- Table 4.1: Replacement probabilities ---
tbl_41 <- tibble(
  Group              = GROUP_ORDER,
  `lambda_CF`        = c(LAMBDA_CF_LOCKED, Variable_Speed = lambda_cf_vs),
  `avg_jump`         = c(
    jump_cs$avg_jump, jump_caz$avg_jump, jump_rol$avg_jump, avg_jump_vs
  ),
  `p_cf`             = p_cf[GROUP_ORDER],
  `lambda_Proactive` = c(LAMBDA_PRO_LOCKED, Variable_Speed = lambda_pro_vs),
  `p_pro`            = p_pro[GROUP_ORDER],
  `p_enf (Phase B)`  = p_enf[GROUP_ORDER]
) |>
  mutate(across(where(is.numeric), \(x) if_else(is.na(x), "—", sprintf("%.4f", x))))

write_kbl(
  tbl_41 |>
    kable(format = "html", align = c("l", rep("r", 6)), escape = FALSE,
          caption = "Table 4.1: Replacement probabilities derived from locked lambda estimates") |>
    kable_styling(full_width = FALSE, bootstrap_options = "bordered", position = "left") |>
    add_header_above(c(
      " " = 1,
      "Natural turnover (lambda_CF → p_cf)" = 3,
      "Proactive LEZ (lambda_Proactive → p_pro)" = 2,
      "Enforcement (Phase B)" = 1
    ))
)
md(
  "",
  "p_cf and p_pro are derived by dividing each locked lambda estimate by avg_stage_jump, which is the gap between the estimation-window stage ceiling and the weighted mean observed stage in the cold estimation records.",
  "p_enf is the proportion of Phase B enforcement events (Routes 4 and 5) that resulted in a compliance upgrade (Route 4), annualised by dividing by the Phase B duration (≈4.33 years).",
  ""
)

# =============================================================================
# 4.2  Construct P_Natural, P_Proactive, P_Enforcement; combine into P_Total
# =============================================================================

md("## 4.2 Matrix construction", "")

# Build matrices for the two Phase C groups (Constant_Speed and Variable_Speed).
# Dimension: FORECAST_MAX_STAGE × FORECAST_MAX_STAGE (6×6).
# Phase C threshold = Stage V = integer 6 for both groups.

mat_list <- lapply(PHASE_C_GROUPS, function(grp) {
  thresh <- PHASE_C_THRESH[[grp]]
  pcf    <- p_cf[[grp]]
  ppro   <- p_pro[[grp]]
  penf   <- p_enf[[grp]]

  P_N <- build_natural(FORECAST_MAX_STAGE, pcf)
  P_P <- build_natural(FORECAST_MAX_STAGE, ppro)   # same structure, diff probability
  P_E <- build_enforcement(FORECAST_MAX_STAGE, penf, thresh)
  P_T <- build_total(FORECAST_MAX_STAGE, pcf, ppro, penf, thresh)

  list(
    group        = grp,
    P_Natural    = P_N,
    P_Proactive  = P_P,
    P_Enforcement = P_E,
    P_Total      = P_T,
    p_cf         = pcf,
    p_pro        = ppro,
    p_enf        = penf,
    threshold    = thresh
  )
})
names(mat_list) <- PHASE_C_GROUPS

# Verify all matrices are right-stochastic (rows sum to 1)
check_stochastic <- function(mat, tol = 1e-10) {
  rs <- rowSums(mat)
  all(abs(rs - 1) < tol) && all(mat >= 0)
}

stoch_checks <- lapply(PHASE_C_GROUPS, function(grp) {
  m <- mat_list[[grp]]
  c(P_Natural     = check_stochastic(m$P_Natural),
    P_Proactive   = check_stochastic(m$P_Proactive),
    P_Enforcement = check_stochastic(m$P_Enforcement),
    P_Total       = check_stochastic(m$P_Total))
})
names(stoch_checks) <- PHASE_C_GROUPS

# Report any failures immediately
for (grp in PHASE_C_GROUPS) {
  failed <- names(which(!stoch_checks[[grp]]))
  if (length(failed) > 0) {
    warning(sprintf("Row-stochastic check FAILED for %s: %s",
                    grp, paste(failed, collapse = ", ")))
  }
}

# --- Display P_Total matrices ---
format_matrix <- function(mat, stage_labs = STAGE_LABELS) {
  df <- as.data.frame(mat)
  colnames(df) <- stage_labs
  rownames(df) <- stage_labs
  df
}

for (grp in PHASE_C_GROUPS) {
  md(sprintf("### P_Total — %s", grp), "")
  mat_df <- format_matrix(mat_list[[grp]]$P_Total)
  write_kbl(
    kable(mat_df, format = "html", digits = 4, escape = FALSE,
          caption = sprintf("P_Total (%s): right-stochastic transition matrix (6×6)", grp)) |>
      kable_styling(full_width = FALSE, bootstrap_options = "bordered", position = "left") |>
      add_header_above(c(" " = 1, "To stage" = 6)) |>
      column_spec(1, bold = TRUE)
  )
  md(
    "",
    sprintf(
      "Rows = 'from stage'; columns = 'to stage'. Each row sums to 1 (right-stochastic). p_cf = %.4f, p_pro = %.4f, p_enf = %.4f; P_Total diagonal = 1 − (p_cf + p_pro + p_enf) for non-compliant stages.",
      mat_list[[grp]]$p_cf, mat_list[[grp]]$p_pro, mat_list[[grp]]$p_enf
    ),
    "Only two columns carry non-zero probability mass: the diagonal (stay) and column VI (Stage V, replacement destination), because all three channels target Stage V in Phase C.",
    ""
  )
}

# Save individual matrices and combined list
p_natural     <- lapply(mat_list, `[[`, "P_Natural")
p_proactive   <- lapply(mat_list, `[[`, "P_Proactive")
p_enforcement <- lapply(mat_list, `[[`, "P_Enforcement")
p_total       <- lapply(mat_list, `[[`, "P_Total")

save_obj(p_natural,     "p_natural",     "list", "2 groups [6x6]", "4",
         "P_Natural: right-stochastic transition matrix based on lambda_CF (counterfactual)")
save_obj(p_proactive,   "p_proactive",   "list", "2 groups [6x6]", "4",
         "P_Proactive: right-stochastic matrix based on lambda_Proactive (LEZ proactive response)")
save_obj(p_enforcement, "p_enforcement", "list", "2 groups [6x6]", "4",
         "P_Enforcement: right-stochastic matrix based on Phase B Route 4/5 enforcement probability")
save_obj(p_total,       "p_total",       "list", "2 groups [6x6]", "4",
         "P_Total: combined P_Natural + P_Proactive + P_Enforcement; row-stochastic enforced")

# =============================================================================
# 4.3  Validation
# =============================================================================

md("## 4.3 Validation", "")

# --- Validation A: implied lambda from P_Total vs locked lambda ---
# lambda_implied = Σᵢ πᵢ × E[stage change | stage i]
# where πᵢ is the Phase C initial stage distribution of cold-engaged records.
# Expected: lambda_implied(P_Natural) ≈ lambda_CF; full equality only if pi matches
# the estimation-window mean stage exactly.

# Phase C initialisation distributions from P24 cold records (audits.rds, phase == "C")
phaseC_cold_dist <- function(dat, grp) {
  sub <- dat |>
    filter(group == grp, phase == "C", cold_engaged == TRUE,
           !is.na(initial_stage), initial_stage <= 6L)
  if (nrow(sub) == 0L) return(rep(1 / FORECAST_MAX_STAGE, FORECAST_MAX_STAGE))
  counts <- tabulate(sub$initial_stage, nbins = FORECAST_MAX_STAGE)
  counts / sum(counts)
}

pi_cs <- phaseC_cold_dist(audits, "Constant_Speed")
pi_vs <- phaseC_cold_dist(audits, "Variable_Speed")

pi_list <- list(Constant_Speed = pi_cs, Variable_Speed = pi_vs)

val_A <- map_dfr(PHASE_C_GROUPS, function(grp) {
  m    <- mat_list[[grp]]
  pi_i <- pi_list[[grp]]
  tibble(
    Group              = grp,
    lam_cf_locked      = if (grp == "Variable_Speed") lambda_cf_vs
                         else LAMBDA_CF_LOCKED[grp],
    lam_implied_Pnat   = implied_lambda(m$P_Natural,    pi_i, FORECAST_MAX_STAGE),
    lam_pro_locked     = if (grp == "Variable_Speed") lambda_pro_vs
                         else LAMBDA_PRO_LOCKED[grp],
    lam_implied_Ptotal = implied_lambda(m$P_Total,      pi_i, FORECAST_MAX_STAGE)
  )
})

write_kbl(
  val_A |>
    mutate(across(where(is.numeric), \(x) sprintf("%.4f", x))) |>
    kable(format = "html", escape = FALSE, align = c("l", rep("r", 4)),
          col.names = c("Group",
                        "lambda_CF (locked)", "lambda implied by P_Natural",
                        "lambda_Proactive (locked)", "lambda implied by P_Total"),
          caption = "Table 4.3a: Implied lambda from matrices vs locked estimates") |>
    kable_styling(full_width = FALSE, bootstrap_options = "bordered", position = "left") |>
    add_header_above(c(" " = 1,
                       "Natural turnover check" = 2,
                       "Full model check" = 2))
)
md(
  "",
  "lambda_implied is computed by applying the matrix to the Phase C cold initialisation distribution and measuring the expected mean stage change per year; it will deviate from the locked lambda if the Phase C stage distribution differs from the estimation-window mean stage.",
  "Close agreement (within ±0.05) confirms that p_cf faithfully encodes the locked lambda in the Phase C fleet context; larger deviations reflect a fleet composition shift between the estimation window and Phase C initialisation.",
  ""
)

# --- Validation B: one-step projection from Phase B end-state vs Phase C init ---
# Project the Phase B final cold distribution one step using P_Total,
# and compare to the actual Phase C cold initialisation distribution.

phaseB_end_cold_dist <- function(dat, grp) {
  # Use Phase B3 (latest Phase B sub-period) cold records as proxy for Phase B end-state
  sub <- dat |>
    filter(
      group        == grp,
      cold_engaged == TRUE,
      frac_year    >= 2023.5534,    # B3 start
      frac_year    <  PHASE_BOUNDS$B[2],
      !is.na(initial_stage), initial_stage <= 6L
    )
  if (nrow(sub) == 0L) return(rep(1 / FORECAST_MAX_STAGE, FORECAST_MAX_STAGE))
  counts <- tabulate(sub$initial_stage, nbins = FORECAST_MAX_STAGE)
  counts / sum(counts)
}

# For CAZ+ and RoL as precursors to Variable_Speed
pi_b_caz <- phaseB_end_cold_dist(audits, "CAZ_Plus")
pi_b_rol <- phaseB_end_cold_dist(audits, "Rest_of_London")

# Variable_Speed Phase B end state: weighted average of CAZ+ and RoL B3 cold N
n_caz_b3 <- sum(audits$group == "CAZ_Plus" & audits$cold_engaged &
                  audits$frac_year >= 2023.5534 & audits$frac_year < PHASE_BOUNDS$B[2] &
                  !is.na(audits$initial_stage) & audits$initial_stage <= 6L)
n_rol_b3 <- sum(audits$group == "Rest_of_London" & audits$cold_engaged &
                  audits$frac_year >= 2023.5534 & audits$frac_year < PHASE_BOUNDS$B[2] &
                  !is.na(audits$initial_stage) & audits$initial_stage <= 6L)
w_b3     <- n_caz_b3 + n_rol_b3
pi_b_vs  <- if (w_b3 == 0) rep(1 / FORECAST_MAX_STAGE, FORECAST_MAX_STAGE) else
  (n_caz_b3 * pi_b_caz + n_rol_b3 * pi_b_rol) / w_b3

pi_b_list <- list(Constant_Speed = phaseB_end_cold_dist(audits, "Constant_Speed"),
                  Variable_Speed = pi_b_vs)

val_B_rows <- map_dfr(PHASE_C_GROUPS, function(grp) {
  pi_b    <- pi_b_list[[grp]]
  pi_c    <- pi_list[[grp]]
  pi_proj <- as.vector(pi_b %*% mat_list[[grp]]$P_Total)

  bind_rows(
    tibble(Group = grp, Distribution = "Phase B3 end (actual)",
           !!!setNames(as.list(round(pi_b,    3)), STAGE_LABELS)),
    tibble(Group = grp, Distribution = "Phase C init (projected)",
           !!!setNames(as.list(round(pi_proj, 3)), STAGE_LABELS)),
    tibble(Group = grp, Distribution = "Phase C init (actual P24)",
           !!!setNames(as.list(round(pi_c,    3)), STAGE_LABELS))
  )
})

write_kbl(
  val_B_rows |>
    kable(format = "html", escape = FALSE,
          align = c("l", "l", rep("r", FORECAST_MAX_STAGE)),
          caption = "Table 4.3b: One-step P_Total projection vs actual Phase C initialisation distribution") |>
    kable_styling(full_width = FALSE, bootstrap_options = "bordered", position = "left") |>
    add_header_above(c(" " = 2, "Stage proportion" = FORECAST_MAX_STAGE))
)
md(
  "",
  "Each group shows three rows: the Phase B3 cold distribution used as input, the one-step P_Total projection (= Phase B3 × P_Total), and the actual Phase C initialisation distribution from P24 cold records.",
  "Close alignment between projected and actual Phase C rows validates that P_Total captures the observed fleet evolution; systematic under-prediction of Stage V or over-prediction of lower stages would indicate that the combined p parameters understate the actual transition rate.",
  ""
)

# --- Bundle all Step 4 outputs ---
step4_matrices <- list(
  mat_list         = mat_list,
  p_cf             = p_cf,
  p_pro            = p_pro,
  p_enf            = p_enf,
  avg_jump         = c(
    Constant_Speed = jump_cs$avg_jump,
    CAZ_Plus       = jump_caz$avg_jump,
    Rest_of_London = jump_rol$avg_jump,
    Variable_Speed = avg_jump_vs
  ),
  pi_phase_c       = pi_list,
  pi_phase_b3      = pi_b_list,
  stoch_checks     = stoch_checks
)

save_obj(step4_matrices, "step4_matrices", "list",
         sprintf("%d elements", length(step4_matrices)), "4",
         "Step 4 output bundle: matrices, probabilities, phase init distributions, validation")

# =============================================================================
# Glossary
# =============================================================================

md(
  "---",
  "## Glossary",
  "",
  "| Term | Definition |",
  "|------|------------|",
  "| **P_Natural** | Right-stochastic transition matrix encoding the counterfactual fleet turnover rate (lambda_CF). Each non-top stage transitions to Stage V with probability p_cf per year. |",
  "| **P_Proactive** | Same structure as P_Natural but encodes the proactive LEZ replacement rate (lambda_Proactive). Zero-probability matrix for CS and RoL where lambda_Proactive = 0 (floored). |",
  "| **P_Enforcement** | Right-stochastic matrix encoding enforcement-driven upgrades. Non-compliant stages (i < threshold) transition to the compliance threshold (Stage V = 6 in Phase C) with probability p_enf per year. |",
  "| **P_Total** | Combined matrix: P_Natural + P_Proactive + P_Enforcement channels, combined additively. Row-stochasticity enforced by capping and rescaling. Used for Scenario A and as base for Scenario B Boolean mask in Step 5. |",
  "| **p_cf** | Annual replacement probability under counterfactual: lambda_CF / avg_stage_jump. |",
  "| **p_pro** | Annual proactive replacement probability: lambda_Proactive / avg_stage_jump. |",
  "| **p_enf** | Annual enforcement-driven compliance probability: (n Route 4 / n Routes 4+5) / Phase B years. |",
  "| **avg_stage_jump** | Mean number of stage integers gained per replacement event, computed from the estimation-window cold records as (estimation ceiling) − (weighted mean observed stage). |",
  "| **Right-stochastic** | Matrix where every row sums to 1 and all entries are ≥ 0; each row is a probability distribution over destination stages. |",
  "| **Phase C initialisation (pi_0)** | Stage distribution of P24 cold-engaged records used as the starting state vector for Phase C forecasting. |",
  ""
)

# =============================================================================
# Console summary
# =============================================================================

cat("\n=== Step 4 Transition Matrices: Objects saved ===\n\n")

cat("Replacement probabilities:\n")
for (grp in GROUP_ORDER) {
  cat(sprintf("  %-18s p_cf=%.4f  p_pro=%.4f  p_enf=%.4f\n",
              grp, p_cf[grp], p_pro[grp], p_enf[grp]))
}

cat("\nRow-stochastic checks:\n")
for (grp in PHASE_C_GROUPS) {
  ok_all <- all(stoch_checks[[grp]])
  cat(sprintf("  %-18s %s\n", grp, if (ok_all) "PASS (all 4 matrices)" else "FAIL — see warnings"))
}

cat("\nObjects saved to intermediate/:\n")
cat("  p_natural.rds, p_proactive.rds, p_enforcement.rds, p_total.rds, step4_matrices.rds\n")
cat(sprintf("\nOutput file: %s\n\n", OUT_FILE))

sessionInfo()
