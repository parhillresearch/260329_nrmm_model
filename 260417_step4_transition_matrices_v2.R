# 260417_step4_transition_matrices_v2.R
# Step 4: Transition matrix construction
#
# Substeps covered:
#   4.1  Replacement probabilities (p_cf, p_pro per group)
#   4.2  Construct P_Natural and P_Proactive per group; combine into P_Total
#   4.3  Validate matrices; two-way lambda decomposition λ(P_Natural) and λ(P_Total)
#
# Design notes:
#   - No P_Enforcement matrix: enforcement enters only as Scenario B Boolean mask
#     in Step 5 (see decisions.md 17 Apr 2026; sprint_log.md plan amendment row).
#   - P_Total = P_Natural + P_Proactive; row sums capped and rescaled after combination.
#   - All Phase C matrices are 6×6 (Stage I–V, ZE excluded). CS max_stage=3 was
#     estimation-only; Phase C uses FORECAST_MAX_STAGE=6 for all groups (P24 data
#     shows Stage V CS machines in Phase C).
#   - p_cf = lambda_CF / avg_stage_jump; avg_stage_jump from estimation-window cold records.
#   - Variable_Speed p parameters are Phase B cold-N-weighted averages of CAZ+ and RoL.
#   - Table layout: group-only dimension → single table, groups as rows.
#     Matrix display: one kable per group (per-group structure, stages as axes).
#
# Inputs:
#   intermediate/audits.rds       — Step 1 (base audit data)
#   intermediate/step3_params.rds — Step 3 (lambda_CF, lambda_Proactive, e-bar)
#
# Outputs (intermediate/):
#   p_natural.rds, p_proactive.rds, p_total.rds, step4_matrices.rds
# Outputs (outputs/):
#   260417_step4_transition_matrices_v2.md

suppressPackageStartupMessages({
  library(tidyverse)
  library(knitr)
  library(kableExtra)
  library(ggplot2)
})

# ── Script constants ────────────────────────────────────────────────────────────

SCRIPT_STEM <- "260417_step4_transition_matrices_v2"
OUT_FILE    <- file.path("outputs", paste0(SCRIPT_STEM, ".md"))
INT_DIR     <- "intermediate"
MANIFEST    <- file.path(INT_DIR, "manifest.md")

GROUP_ORDER    <- c("Constant_Speed", "CAZ_Plus", "Rest_of_London", "Variable_Speed")
PHASE_C_GROUPS <- c("Constant_Speed", "Variable_Speed")

# State space for all Phase C matrices
FORECAST_MAX_STAGE <- 6L

# Stage labels for display
STAGE_LABELS <- c("I", "II", "IIIA", "IIIB", "IV", "V")
names(STAGE_LABELS) <- as.character(1:6)

# Estimation ceiling per group (from estimation-window cold records)
# CS: max_stage=3 (Stage V absent from 2016-2023 cold fleet)
# Variable-speed: max_stage=6 (full stage range present)
EST_MAX_STAGE <- c(Constant_Speed = 3L, CAZ_Plus = 6L, Rest_of_London = 6L)

# Phase boundaries (fractional years; schema.md Table 7)
PHASE_BOUNDS <- list(
  A1 = c(2016.0000, 2018.9973),
  A2 = c(2019.0000, 2020.6667),
  B  = c(2020.6667, 2024.9973),
  C  = c(2025.0000, 2031.0000)
)
B3_START <- 2023.5534   # Phase B3 start (for Phase B end-state approximation)

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
  all_zero <- rs == 0
  if (any(all_zero)) {
    for (i in which(all_zero)) mat[i, i] <- 1
    rs <- rowSums(mat)
  }
  sweep(mat, 1, rs, "/")
}

#' Build P_Natural: non-top stages transition to max_stage with prob p_cf per year.
#' Arguments:
#'   max_stage : integer, dimension of the square matrix
#'   p_cf      : annual replacement probability (scalar, [0, 0.99])
#' Returns a max_stage × max_stage right-stochastic matrix.
build_natural <- function(max_stage, p_cf) {
  p_cf <- min(max(p_cf, 0), 0.99)
  mat  <- diag(max_stage)
  for (i in seq_len(max_stage - 1L)) {
    mat[i, i]         <- 1 - p_cf
    mat[i, max_stage] <- p_cf
  }
  enforce_stochastic(mat)
}

#' Combine P_Natural and P_Proactive into P_Total.
#' For each row i < max_stage: diagonal = 1 - (p_cf + p_pro), top = p_cf + p_pro.
#' Row max_stage: absorbing (stays at top stage). Floor-and-rescale applied.
#' Arguments:
#'   max_stage : integer, dimension
#'   p_cf      : natural replacement probability
#'   p_pro     : proactive LEZ replacement probability
#' Returns a max_stage × max_stage right-stochastic matrix.
build_total <- function(max_stage, p_cf, p_pro) {
  p_up <- min(p_cf + p_pro, 0.99)
  mat  <- diag(max_stage)
  for (i in seq_len(max_stage - 1L)) {
    mat[i, i]         <- 1 - p_up
    mat[i, max_stage] <- p_up
  }
  enforce_stochastic(mat)
}

#' Compute implied lambda from a transition matrix and an initial stage distribution.
#' lambda_implied = Σᵢ πᵢ × (E[stage | start at i] − i)
#' Arguments:
#'   mat       : max_stage × max_stage right-stochastic matrix
#'   pi        : numeric vector of stage proportions (must sum to 1)
#'   max_stage : integer
#' Returns scalar lambda (stage integers per year).
implied_lambda <- function(mat, pi, max_stage) {
  stages             <- seq_len(max_stage)
  expected_new_stage <- as.vector(mat %*% stages)
  delta_per_stage    <- expected_new_stage - stages
  sum(pi * delta_per_stage)
}

#' Save RDS and append one row to the cumulative manifest.
#' Arguments: obj, name, class_str, dim_str, step_str, desc_str
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

audits <- readRDS(file.path(INT_DIR, "audits.rds"))

# Ensure frac_year column present (aliased from date_frac in Step 1)
if (!"frac_year" %in% names(audits) && "date_frac" %in% names(audits)) {
  audits <- audits |> rename(frac_year = date_frac)
}

# step3_params for reference (lambda values read from locked constants above)
step3 <- readRDS(file.path(INT_DIR, "step3_params.rds"))

# ── Initialise output file ──────────────────────────────────────────────────────

write_lines(
  c(paste0("# Step 4 Transition Matrices — ", SCRIPT_STEM),
    paste0("*Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "*"),
    ""),
  OUT_FILE, append = FALSE
)

# =============================================================================
# 4.1  avg_stage_jump and replacement probabilities (p_cf, p_pro)
# =============================================================================

md("## 4.1 Replacement probabilities", "")

# --- avg_stage_jump from estimation-window cold records ---
# Uses the SAME cold records used to estimate lambda_CF to preserve structural
# interpretation: avg_stage_jump = est_max_stage - mean(observed stage in window).

compute_avg_jump <- function(dat, grp, est_max, phase_bounds) {
  if (grp == "Constant_Speed") {
    # CS: cold records 2016-2023 (2024 excluded per decisions.md)
    sub <- dat |>
      filter(
        group        == "Constant_Speed",
        cold_engaged == TRUE,
        frac_year    >= phase_bounds$A1[1],
        frac_year    <  2024.0
      )
  } else {
    # Variable-speed groups: cold A1/A2 + Phase B
    sub <- dat |>
      filter(
        group        == grp,
        cold_engaged == TRUE,
        frac_year    >= phase_bounds$A1[1],
        frac_year    <  phase_bounds$B[2]
      )
  }
  sub <- sub |>
    mutate(stage_capped = pmin(initial_stage, est_max)) |>
    filter(!is.na(stage_capped), is.finite(stage_capped))

  if (nrow(sub) == 0L) return(list(wmean = NA_real_, n = 0L, avg_jump = NA_real_))
  wmean    <- mean(sub$stage_capped)
  avg_jump <- est_max - wmean
  list(wmean = wmean, n = nrow(sub), avg_jump = avg_jump)
}

jump_cs  <- compute_avg_jump(audits, "Constant_Speed",  EST_MAX_STAGE["Constant_Speed"],  PHASE_BOUNDS)
jump_caz <- compute_avg_jump(audits, "CAZ_Plus",        EST_MAX_STAGE["CAZ_Plus"],        PHASE_BOUNDS)
jump_rol <- compute_avg_jump(audits, "Rest_of_London",  EST_MAX_STAGE["Rest_of_London"],  PHASE_BOUNDS)

# Variable_Speed: Phase B cold-N-weighted average of CAZ+ and RoL
n_caz_b <- audits |>
  filter(group == "CAZ_Plus", cold_engaged == TRUE,
         frac_year >= PHASE_BOUNDS$B[1], frac_year < PHASE_BOUNDS$B[2]) |>
  nrow()
n_rol_b <- audits |>
  filter(group == "Rest_of_London", cold_engaged == TRUE,
         frac_year >= PHASE_BOUNDS$B[1], frac_year < PHASE_BOUNDS$B[2]) |>
  nrow()
w_total <- n_caz_b + n_rol_b

lambda_cf_vs  <- (n_caz_b * LAMBDA_CF_LOCKED["CAZ_Plus"]  +
                  n_rol_b * LAMBDA_CF_LOCKED["Rest_of_London"])  / w_total
lambda_pro_vs <- (n_caz_b * LAMBDA_PRO_LOCKED["CAZ_Plus"] +
                  n_rol_b * LAMBDA_PRO_LOCKED["Rest_of_London"]) / w_total
avg_jump_vs   <- (n_caz_b * jump_caz$avg_jump +
                  n_rol_b * jump_rol$avg_jump) / w_total

# Compute p_cf and p_pro per group
# Guard: if avg_jump <= 0 (all machines already at max stage), set p = 0
safe_p <- function(lambda, avg_jump) {
  if (is.na(avg_jump) || avg_jump <= 0 || is.na(lambda) || lambda <= 0) return(0)
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

# --- Table 4.1a: Probability decomposition — single table, groups as rows ---
tbl_41 <- tibble(
  Group               = GROUP_ORDER,
  `lambda_CF`         = c(unname(LAMBDA_CF_LOCKED), lambda_cf_vs),
  `avg_stage_jump`    = c(jump_cs$avg_jump, jump_caz$avg_jump,
                           jump_rol$avg_jump, avg_jump_vs),
  `p_cf`              = p_cf[GROUP_ORDER],
  `lambda_Proactive`  = c(unname(LAMBDA_PRO_LOCKED), lambda_pro_vs),
  `p_pro`             = p_pro[GROUP_ORDER]
) |>
  mutate(across(where(is.numeric), \(x) if_else(is.na(x), "\u2014", sprintf("%.4f", x))))

write_kbl(
  tbl_41 |>
    kable(format = "html", align = c("l", rep("r", 5)), escape = FALSE,
          caption = "Table 4.1a: Replacement probabilities derived from locked lambda estimates") |>
    kable_styling(full_width = FALSE, bootstrap_options = "bordered", position = "left") |>
    add_header_above(c(
      " "                                         = 1,
      "Natural turnover (lambda_CF \u2192 p_cf)"  = 3,
      "Proactive LEZ (lambda_Pro \u2192 p_pro)"   = 2
    ))
)
md(
  "",
  "p_cf and p_pro are derived by dividing each locked lambda estimate by avg_stage_jump (the gap between the estimation ceiling and the mean observed stage in the cold estimation window).",
  "Variable_Speed values are Phase B cold-N-weighted averages of the CAZ+ and Rest_of_London estimates; CS lambda_Proactive = 0 (floored) and RoL lambda_Proactive = 0 (floored) produce p_pro = 0 for those groups.",
  ""
)

# --- Plot 4.1: p_cf and p_pro bar chart ---
prob_plot_dat <- tibble(
  Group = rep(GROUP_ORDER, 2),
  prob  = c(p_cf[GROUP_ORDER], p_pro[GROUP_ORDER]),
  type  = rep(c("p_cf (natural turnover)", "p_pro (proactive LEZ)"), each = 4)
) |>
  mutate(
    Group = factor(Group, levels = GROUP_ORDER),
    type  = factor(type, levels = c("p_cf (natural turnover)", "p_pro (proactive LEZ)"))
  )

p_probs_file <- paste0(SCRIPT_STEM, "_fig4_1_probabilities.png")
p_probs <- prob_plot_dat |>
  ggplot(aes(x = Group, y = prob, fill = type)) +
  geom_col(position = "dodge", width = 0.6) +
  geom_text(aes(label = sprintf("%.4f", prob)),
            position = position_dodge(width = 0.6),
            vjust = -0.35, size = 2.8) +
  scale_fill_manual(values = c("p_cf (natural turnover)" = "#4C9BE8",
                                "p_pro (proactive LEZ)"   = "#E88C4C")) +
  scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.12))) +
  scale_x_discrete(labels = function(x) str_replace_all(x, "_", "\n")) +
  labs(title = "Replacement probabilities by group",
       x = NULL, y = "Annual probability", fill = NULL) +
  theme_bw(base_size = 10) +
  theme(legend.position = "bottom", plot.title = element_text(size = 10))

ggsave(file.path("outputs", p_probs_file), p_probs,
       width = 16, height = 10, units = "cm", dpi = 180)
md(sprintf("![Replacement probabilities by group](%s)", p_probs_file), "")
md(
  "Each group shows p_cf (blue, natural counterfactual turnover) and p_pro (orange, proactive LEZ-driven replacement) as annual probabilities.",
  "CS and RoL have p_pro = 0 (lambda_Proactive floored); CAZ+ is the only group with a detectable proactive component (p_pro = 0.013 / avg_jump).",
  ""
)

# =============================================================================
# 4.2  Construct P_Natural and P_Total; display per group
# =============================================================================

md("## 4.2 Matrix construction", "")

mat_list <- lapply(PHASE_C_GROUPS, function(grp) {
  pcf  <- p_cf[[grp]]
  ppro <- p_pro[[grp]]

  P_N <- build_natural(FORECAST_MAX_STAGE, pcf)
  P_P <- build_natural(FORECAST_MAX_STAGE, ppro)   # same structure, encodes p_pro
  P_T <- build_total(FORECAST_MAX_STAGE, pcf, ppro)

  list(
    group       = grp,
    P_Natural   = P_N,
    P_Proactive = P_P,
    P_Total     = P_T,
    p_cf        = pcf,
    p_pro       = ppro
  )
})
names(mat_list) <- PHASE_C_GROUPS

# Row-stochastic validation
check_stochastic <- function(mat, tol = 1e-10) {
  all(abs(rowSums(mat) - 1) < tol) && all(mat >= 0)
}

stoch_checks <- lapply(PHASE_C_GROUPS, function(grp) {
  m <- mat_list[[grp]]
  c(P_Natural  = check_stochastic(m$P_Natural),
    P_Proactive = check_stochastic(m$P_Proactive),
    P_Total     = check_stochastic(m$P_Total))
})
names(stoch_checks) <- PHASE_C_GROUPS

for (grp in PHASE_C_GROUPS) {
  failed <- names(which(!stoch_checks[[grp]]))
  if (length(failed) > 0) {
    warning(sprintf("Row-stochastic check FAILED for %s: %s",
                    grp, paste(failed, collapse = ", ")))
  }
}

# Format matrix as data frame with stage labels
format_matrix <- function(mat) {
  df           <- as.data.frame(round(mat, 4))
  colnames(df) <- STAGE_LABELS
  rownames(df) <- STAGE_LABELS
  df
}

# Display P_Natural and P_Total per group
for (grp in PHASE_C_GROUPS) {
  m <- mat_list[[grp]]

  md(sprintf("### %s", grp), "")

  write_kbl(
    kable(format_matrix(m$P_Natural), format = "html", escape = FALSE,
          caption = sprintf("P_Natural — %s (p_cf = %.4f)", grp, m$p_cf)) |>
      kable_styling(full_width = FALSE, bootstrap_options = "bordered", position = "left") |>
      add_header_above(c("From \\ To stage" = 1, "To stage" = FORECAST_MAX_STAGE)) |>
      column_spec(1, bold = TRUE)
  )
  md(
    "",
    sprintf(
      "Rows = origin stage; columns = destination stage; all rows sum to 1. Each non-top stage stays with probability %.4f and upgrades directly to Stage V with probability %.4f (= p_cf).",
      1 - m$p_cf, m$p_cf
    ),
    "The top row (Stage V) is absorbing — machines at Stage V remain there. This is the counterfactual fleet turnover matrix with no LEZ policy effect.",
    ""
  )

  write_kbl(
    kable(format_matrix(m$P_Total), format = "html", escape = FALSE,
          caption = sprintf("P_Total — %s (p_cf + p_pro = %.4f)", grp, m$p_cf + m$p_pro)) |>
      kable_styling(full_width = FALSE, bootstrap_options = "bordered", position = "left") |>
      add_header_above(c("From \\ To stage" = 1, "To stage" = FORECAST_MAX_STAGE)) |>
      column_spec(1, bold = TRUE)
  )
  md(
    "",
    sprintf(
      "P_Total encodes both natural turnover and proactive LEZ replacement: combined annual upgrade probability = %.4f (p_cf %.4f + p_pro %.4f).",
      m$p_cf + m$p_pro, m$p_cf, m$p_pro
    ),
    if (m$p_pro == 0) "p_pro = 0 for this group, so P_Total is identical to P_Natural; the LEZ proactive channel has no additional effect in the base model." else
      "P_Total differs from P_Natural only in the off-diagonal upgrade probability; p_pro adds a measurable additional LEZ-driven acceleration.",
    ""
  )
}

# --- Plot 4.2: heatmap of P_Total per group ---
heatmap_dat <- map_dfr(PHASE_C_GROUPS, function(grp) {
  mat <- mat_list[[grp]]$P_Total
  expand_grid(from = 1:FORECAST_MAX_STAGE, to = 1:FORECAST_MAX_STAGE) |>
    mutate(
      prob  = map2_dbl(from, to, \(r, c) mat[r, c]),
      group = grp,
      from_lbl = factor(STAGE_LABELS[from], levels = rev(STAGE_LABELS)),
      to_lbl   = factor(STAGE_LABELS[to],  levels = STAGE_LABELS)
    )
})

heatmap_file <- paste0(SCRIPT_STEM, "_fig4_2_ptotal_heatmap.png")
p_heat <- heatmap_dat |>
  mutate(group = factor(group, levels = PHASE_C_GROUPS),
         label = if_else(prob > 0.001, sprintf("%.3f", prob), "")) |>
  ggplot(aes(x = to_lbl, y = from_lbl, fill = prob)) +
  geom_tile(colour = "white", linewidth = 0.4) +
  geom_text(aes(label = label), size = 2.5, colour = "white") +
  scale_fill_gradient(low = "#DDEEFF", high = "#1A5AAB",
                      name = "Transition\nprobability",
                      limits = c(0, 1)) +
  facet_wrap(~group, nrow = 1) +
  labs(title = "P_Total transition matrices — Phase C groups",
       x = "To stage", y = "From stage") +
  theme_bw(base_size = 10) +
  theme(panel.grid = element_blank(),
        axis.text  = element_text(size = 8))

ggsave(file.path("outputs", heatmap_file), p_heat,
       width = 16, height = 10, units = "cm", dpi = 180)
md(sprintf("![P_Total heatmap by group](%s)", heatmap_file), "")
md(
  "Heatmaps of P_Total for each Phase C group: darker blue = higher transition probability; lighter cells = near-zero. The dominant pattern is a near-diagonal (machines stay) with a single off-diagonal column at Stage V (replacement destination).",
  "CS and Variable_Speed differ in their diagonal values (1 − p_cf − p_pro), reflecting the lower natural turnover rate of the constant-speed generator fleet versus the merged variable-speed fleet.",
  ""
)

# Save matrices
p_natural   <- lapply(mat_list, `[[`, "P_Natural")
p_proactive <- lapply(mat_list, `[[`, "P_Proactive")
p_total     <- lapply(mat_list, `[[`, "P_Total")

save_obj(p_natural,   "p_natural",   "list", "2 groups [6x6]", "4",
         "P_Natural: right-stochastic matrix encoding counterfactual fleet turnover (lambda_CF)")
save_obj(p_proactive, "p_proactive", "list", "2 groups [6x6]", "4",
         "P_Proactive: right-stochastic matrix encoding proactive LEZ replacement (lambda_Proactive)")
save_obj(p_total,     "p_total",     "list", "2 groups [6x6]", "4",
         "P_Total: P_Natural + P_Proactive combined; row-stochasticity enforced; Scenario A base matrix")

# =============================================================================
# 4.3  Validation
# =============================================================================

md("## 4.3 Validation", "")

# --- Phase C initialisation distributions from P24 cold records ---
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

# --- Validation A: two-way lambda decomposition — λ(P_Natural) and λ(P_Total) ---
val_A <- map_dfr(PHASE_C_GROUPS, function(grp) {
  m    <- mat_list[[grp]]
  pi_i <- pi_list[[grp]]
  lam_cf_lock  <- if (grp == "Variable_Speed") lambda_cf_vs  else LAMBDA_CF_LOCKED[grp]
  lam_pro_lock <- if (grp == "Variable_Speed") lambda_pro_vs else LAMBDA_PRO_LOCKED[grp]
  tibble(
    Group                     = grp,
    `lambda_CF (locked)`      = lam_cf_lock,
    `lambda(P_Natural)`       = implied_lambda(m$P_Natural, pi_i, FORECAST_MAX_STAGE),
    `lambda_Pro (locked)`     = lam_pro_lock,
    `lambda(P_Total)`         = implied_lambda(m$P_Total,   pi_i, FORECAST_MAX_STAGE),
    `marginal lambda_Pro (P_Total - P_Natural)` =
      implied_lambda(m$P_Total, pi_i, FORECAST_MAX_STAGE) -
      implied_lambda(m$P_Natural, pi_i, FORECAST_MAX_STAGE)
  )
})

write_kbl(
  val_A |>
    mutate(across(where(is.numeric), \(x) sprintf("%.4f", x))) |>
    kable(format = "html", escape = FALSE, align = c("l", rep("r", 5)),
          caption = "Table 4.3a: Implied lambda from matrices vs locked estimates (Phase C initialisation)") |>
    kable_styling(full_width = FALSE, bootstrap_options = "bordered", position = "left") |>
    add_header_above(c(" "                   = 1,
                       "Natural turnover"    = 2,
                       "Full model"         = 2,
                       "Proactive increment" = 1))
)
md(
  "",
  "lambda(P_Natural) and lambda(P_Total) are computed by applying each matrix to the Phase C cold initialisation distribution (pi_0) and measuring expected mean stage change per year; deviations from locked values arise because the Phase C stage distribution differs from the estimation-window mean stage.",
  "The marginal lambda_Pro column shows P_Total's additional contribution beyond P_Natural; this should be close to lambda_Proactive (locked) for CAZ+ and near zero for CS and RoL.",
  ""
)

# --- Validation B: one-step P_Total projection vs actual Phase C initialisation ---

phaseB_end_dist <- function(dat, grp) {
  sub <- dat |>
    filter(group == grp, cold_engaged == TRUE,
           frac_year >= B3_START, frac_year < PHASE_BOUNDS$B[2],
           !is.na(initial_stage), initial_stage <= 6L)
  if (nrow(sub) == 0L) return(rep(1 / FORECAST_MAX_STAGE, FORECAST_MAX_STAGE))
  counts <- tabulate(sub$initial_stage, nbins = FORECAST_MAX_STAGE)
  counts / sum(counts)
}

pi_b_caz <- phaseB_end_dist(audits, "CAZ_Plus")
pi_b_rol <- phaseB_end_dist(audits, "Rest_of_London")

n_caz_b3 <- audits |> filter(group == "CAZ_Plus",       cold_engaged == TRUE,
                               frac_year >= B3_START, frac_year < PHASE_BOUNDS$B[2],
                               !is.na(initial_stage), initial_stage <= 6L) |> nrow()
n_rol_b3 <- audits |> filter(group == "Rest_of_London", cold_engaged == TRUE,
                               frac_year >= B3_START, frac_year < PHASE_BOUNDS$B[2],
                               !is.na(initial_stage), initial_stage <= 6L) |> nrow()
w_b3     <- n_caz_b3 + n_rol_b3
pi_b_vs  <- if (w_b3 == 0) rep(1 / FORECAST_MAX_STAGE, FORECAST_MAX_STAGE) else
  (n_caz_b3 * pi_b_caz + n_rol_b3 * pi_b_rol) / w_b3

pi_b_list <- list(
  Constant_Speed = phaseB_end_dist(audits, "Constant_Speed"),
  Variable_Speed = pi_b_vs
)

val_B_rows <- map_dfr(PHASE_C_GROUPS, function(grp) {
  pi_b    <- pi_b_list[[grp]]
  pi_c    <- pi_list[[grp]]
  pi_proj <- as.vector(pi_b %*% mat_list[[grp]]$P_Total)

  bind_rows(
    tibble(Group = grp, Distribution = "Phase B3 end (actual cold)",
           !!!setNames(as.list(round(pi_b,    3)), STAGE_LABELS)),
    tibble(Group = grp, Distribution = "Phase C init projected (B3 \u00d7 P_Total)",
           !!!setNames(as.list(round(pi_proj, 3)), STAGE_LABELS)),
    tibble(Group = grp, Distribution = "Phase C init actual (P24 cold)",
           !!!setNames(as.list(round(pi_c,    3)), STAGE_LABELS))
  )
})

write_kbl(
  val_B_rows |>
    kable(format = "html", escape = FALSE,
          align = c("l", "l", rep("r", FORECAST_MAX_STAGE)),
          caption = "Table 4.3b: One-step P_Total projection vs actual Phase C cold initialisation") |>
    kable_styling(full_width = FALSE, bootstrap_options = "bordered", position = "left") |>
    add_header_above(c(" " = 2, "Stage proportion" = FORECAST_MAX_STAGE))
)
md(
  "",
  "Each group shows three rows: Phase B3 cold distribution (input), one-step P_Total projection (= B3 \u00d7 P_Total), and the actual Phase C cold distribution from P24 records.",
  "Systematic under-prediction of Stage V or over-prediction of lower stages would indicate that the combined p_cf + p_pro underestimates the observed fleet transition rate between late Phase B and Phase C.",
  ""
)

# --- Plot 4.3: Phase C init — actual vs projected bar chart ---
val_B_plot_dat <- val_B_rows |>
  pivot_longer(all_of(STAGE_LABELS), names_to = "stage", values_to = "prop") |>
  mutate(
    group = factor(Group, levels = PHASE_C_GROUPS),
    stage = factor(stage, levels = STAGE_LABELS),
    Distribution = factor(Distribution,
                          levels = c("Phase B3 end (actual cold)",
                                     "Phase C init projected (B3 \u00d7 P_Total)",
                                     "Phase C init actual (P24 cold)"))
  )

val_B_plot_file <- paste0(SCRIPT_STEM, "_fig4_3_validation_B.png")
p_valB <- val_B_plot_dat |>
  ggplot(aes(x = stage, y = prop, fill = Distribution)) +
  geom_col(position = "dodge", width = 0.7) +
  facet_wrap(~group, nrow = 1) +
  scale_fill_manual(values = c(
    "Phase B3 end (actual cold)"                      = "#AACDE8",
    "Phase C init projected (B3 \u00d7 P_Total)"      = "#E8A44C",
    "Phase C init actual (P24 cold)"                   = "#2E8B57"
  )) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                     expand = expansion(mult = c(0, 0.08))) +
  labs(title = "Validation B: one-step projection vs Phase C actual distribution",
       x = "Emissions Stage", y = "Proportion of cold fleet", fill = NULL) +
  theme_bw(base_size = 10) +
  theme(legend.position = "bottom",
        legend.text = element_text(size = 7),
        plot.title  = element_text(size = 10))

ggsave(file.path("outputs", val_B_plot_file), p_valB,
       width = 16, height = 12, units = "cm", dpi = 180)
md(sprintf("![Validation B: one-step projection](%s)", val_B_plot_file), "")
md(
  "Blue bars = Phase B3 actual cold distribution; orange = one-step P_Total projection; green = Phase C actual P24 cold distribution. Agreement between orange and green indicates P_Total captures the observed fleet transition.",
  "Discrepancies reflect genuine fleet composition shifts (e.g. surge of Stage V CS machines in 2024 pre-compliance), structural features not captured by the single annual-probability model (time-varying hazard), or P24 zone composition differing from the B3 estimation-window zones.",
  ""
)

# --- Bundle Step 4 outputs ---
step4_matrices <- list(
  mat_list    = mat_list,
  p_cf        = p_cf,
  p_pro       = p_pro,
  avg_jump    = c(
    Constant_Speed = jump_cs$avg_jump,
    CAZ_Plus       = jump_caz$avg_jump,
    Rest_of_London = jump_rol$avg_jump,
    Variable_Speed = avg_jump_vs
  ),
  pi_phase_c  = pi_list,
  pi_phase_b3 = pi_b_list,
  stoch_checks = stoch_checks
)

save_obj(step4_matrices, "step4_matrices", "list",
         sprintf("%d elements", length(step4_matrices)), "4",
         "Step 4 output bundle: matrices (P_Natural, P_Proactive, P_Total), probabilities, phase init distributions, validation")

# =============================================================================
# Glossary
# =============================================================================

md(
  "---",
  "## Glossary",
  "",
  "| Term | Definition |",
  "|------|------------|",
  "| **P_Natural** | Right-stochastic 6\u00d76 transition matrix encoding counterfactual fleet turnover (lambda_CF). Each non-top stage transitions to Stage V with probability p_cf per year. |",
  "| **P_Proactive** | Same structure as P_Natural, encoding the proactive LEZ replacement rate (lambda_Proactive). Identity-like for CS and RoL where lambda_Proactive = 0. |",
  "| **P_Total** | Combined matrix: P_Natural + P_Proactive channels. Used as Scenario A base matrix for Step 5 forecasting. Enforcement enters only as the Scenario B Boolean mask in Step 5. |",
  "| **p_cf** | Annual replacement probability under counterfactual: lambda_CF / avg_stage_jump. |",
  "| **p_pro** | Annual proactive LEZ replacement probability: lambda_Proactive / avg_stage_jump. |",
  "| **avg_stage_jump** | Mean stage integers gained per replacement: estimation ceiling \u2212 weighted mean observed stage in cold estimation-window records. |",
  "| **lambda(P_Natural)** | Implied lambda computed by applying P_Natural to the Phase C initialisation distribution; compared to locked lambda_CF to validate p_cf. |",
  "| **lambda(P_Total)** | Implied lambda from P_Total; the difference from lambda(P_Natural) is the matrix-implied proactive increment. |",
  "| **Right-stochastic** | Matrix where every row sums to 1 and all entries are \u2265 0; each row is a probability distribution over destination stages. |",
  "| **Phase C initialisation (pi_0)** | Stage distribution of P24 cold-engaged records used as the starting state vector for Phase C forecasting. |",
  ""
)

# =============================================================================
# Console summary
# =============================================================================

cat("\n=== Step 4 Transition Matrices (v2): Objects saved ===\n\n")

cat("Replacement probabilities:\n")
for (grp in GROUP_ORDER) {
  cat(sprintf("  %-18s p_cf = %.4f   p_pro = %.4f\n",
              grp, p_cf[grp], p_pro[grp]))
}

cat("\nRow-stochastic checks:\n")
for (grp in PHASE_C_GROUPS) {
  ok <- all(stoch_checks[[grp]])
  cat(sprintf("  %-18s %s\n", grp,
              if (ok) "PASS (P_Natural, P_Proactive, P_Total)" else "FAIL — see warnings"))
}

cat("\nObjects saved to intermediate/:\n")
cat("  p_natural.rds, p_proactive.rds, p_total.rds, step4_matrices.rds\n")
cat(sprintf("\nOutput file: %s\n\n", OUT_FILE))

sessionInfo()
