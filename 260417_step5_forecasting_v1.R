# 260417_step5_forecasting_v1.R
# Step 5: Forecasting and emissions
#
# Substeps:
#   5.1  Phase C initialisation (pi_0 per group from step4_matrices$pi_phase_c)
#   5.2  Scenario A: annual Stage distribution forecast 2025-2030 (P_Total)
#   5.3  Scenario B: enforcement-augmented upper-bound forecast (Boolean mask)
#   5.4  Compliance trajectory comparison (proportion at/above threshold, both scenarios)
#   5.5  Emissions (conditional on user-supplied EF_s; skipped if EF_s contains NA)
#
# Scenario B design: zeroes transitions to destination stages below the compliance
#   threshold for that year, then rescales rows to maintain right-stochasticity.
#   Under P_Total structure (stay or jump to Stage V), non-compliant machines must
#   jump to Stage V in each annual step -- structural upper bound.
#
# Compliance thresholds (schema.md Table 2, era boundaries):
#   Constant_Speed 2025-2030 : Stage V (integer 6)
#   Variable_Speed 2025-2029 : Stage IV (integer 5) -- lower of CAZ+/RoL
#   Variable_Speed 2030      : Stage V (integer 6)  -- era 4 from 1.1.2030
#
# Inputs:
#   intermediate/step4_matrices.rds
#   intermediate/audits.rds
# Outputs (intermediate/):
#   forecast_scen_a.rds, forecast_scen_b.rds, step5_forecasts.rds
# Outputs (outputs/):
#   260417_step5_forecasting_v1.md + .png files

suppressPackageStartupMessages({
  library(tidyverse)
  library(knitr)
  library(kableExtra)
  library(ggplot2)
})

# ── Script constants ──────────────────────────────────────────────────────────

SCRIPT_STEM        <- "260417_step5_forecasting_v1"
OUT_FILE           <- file.path("outputs", paste0(SCRIPT_STEM, ".md"))
INT_DIR            <- "intermediate"
MANIFEST           <- file.path(INT_DIR, "manifest.md")

PHASE_C_GROUPS     <- c("Constant_Speed", "Variable_Speed")
FORECAST_MAX_STAGE <- 6L
FORECAST_YEARS     <- 2025:2030
OPERATING_HOURS    <- 2000  # hr/annum per machine

STAGE_LABELS <- c("I", "II", "IIIA", "IIIB", "IV", "V")
names(STAGE_LABELS) <- as.character(1:6)

# Compliance threshold per group per year (schema.md Table 2)
COMP_THRESH <- list(
  Constant_Speed = setNames(rep(6L, length(FORECAST_YEARS)), as.character(FORECAST_YEARS)),
  Variable_Speed = setNames(
    ifelse(FORECAST_YEARS < 2030L, 5L, 6L),
    as.character(FORECAST_YEARS)
  )
)

# ── EMISSION FACTORS -- USER TO SUPPLY ───────────────────────────────────────
# EMEP/EEA Tier 3 NOx factors (g NOx/kWh) by Stage integer.
# Source: Ntziachristos & Samaras (2019).
# Replace NA with numeric values before running emissions section.
EF_s <- c(
  "1" = NA_real_,   # Stage I
  "2" = NA_real_,   # Stage II
  "3" = NA_real_,   # Stage IIIA
  "4" = NA_real_,   # Stage IIIB
  "5" = NA_real_,   # Stage IV
  "6" = NA_real_    # Stage V
)

# ── Helper functions ──────────────────────────────────────────────────────────

#' Floor negatives, rescale rows to sum to 1; fix zero rows on diagonal.
enforce_stochastic <- function(mat) {
  mat <- pmax(mat, 0)
  rs  <- rowSums(mat)
  for (i in which(rs == 0)) mat[i, i] <- 1
  sweep(mat, 1, rowSums(mat), "/")
}

#' Apply Boolean compliance mask: zero columns below threshold, rescale rows.
#' Arguments:
#'   mat       : max_stage x max_stage right-stochastic matrix
#'   threshold : integer; destination stages < threshold are zeroed
build_scenario_b <- function(mat, threshold) {
  mat_b <- mat
  if (threshold > 1L) mat_b[, seq_len(threshold - 1L)] <- 0
  enforce_stochastic(mat_b)
}

#' Project stage distribution forward using transition matrix (or list of matrices).
#' Arguments:
#'   pi0     : numeric vector of stage proportions (length max_stage, sums to 1)
#'   P       : single matrix or list of matrices (one per annual step)
#'   n_years : number of annual steps
#'   years   : integer vector of output years (length n_years + 1)
#'   group   : character label for group column
#' Returns tibble: year, stage (int), prop, group, stage_lbl
project_distribution <- function(pi0, P, n_years, years, group) {
  results <- vector("list", n_years + 1L)
  pi_curr <- pi0
  results[[1L]] <- tibble(
    year      = years[1L],
    stage     = seq_len(FORECAST_MAX_STAGE),
    prop      = pi_curr,
    group     = group,
    stage_lbl = STAGE_LABELS[as.character(seq_len(FORECAST_MAX_STAGE))]
  )
  for (t in seq_len(n_years)) {
    P_t     <- if (is.list(P)) P[[t]] else P
    pi_curr <- as.vector(pi_curr %*% P_t)
    pi_curr <- pmax(pi_curr, 0)
    pi_curr <- pi_curr / sum(pi_curr)
    results[[t + 1L]] <- tibble(
      year      = years[t + 1L],
      stage     = seq_len(FORECAST_MAX_STAGE),
      prop      = pi_curr,
      group     = group,
      stage_lbl = STAGE_LABELS[as.character(seq_len(FORECAST_MAX_STAGE))]
    )
  }
  bind_rows(results)
}

#' Compute compliance rate per group-year: proportion at/above year-specific threshold.
compute_compliance <- function(scen_data, thresh_list, label) {
  map_dfr(PHASE_C_GROUPS, function(grp) {
    thresh_df <- tibble(
      year      = as.integer(names(thresh_list[[grp]])),
      threshold = as.integer(thresh_list[[grp]])
    )
    scen_data |>
      filter(group == grp) |>
      left_join(thresh_df, by = "year") |>
      group_by(year) |>
      summarise(
        compliance_rate = sum(prop[stage >= threshold[1L]], na.rm = TRUE),
        threshold       = threshold[1L],
        .groups = "drop"
      ) |>
      mutate(group = grp, scenario = label)
  })
}

#' Save RDS and append row to manifest.
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

md        <- function(...) write_lines(c(...), OUT_FILE, append = TRUE)
write_kbl <- function(k)   write_lines(as.character(k), OUT_FILE, append = TRUE)

# ── Load inputs ───────────────────────────────────────────────────────────────

step4  <- readRDS(file.path(INT_DIR, "step4_matrices.rds"))
audits <- readRDS(file.path(INT_DIR, "audits.rds"))

if (!"frac_year" %in% names(audits) && "date_frac" %in% names(audits)) {
  audits <- audits |> rename(frac_year = date_frac)
}

# ── Initialise output file ────────────────────────────────────────────────────

write_lines(
  c(paste0("# Step 5 Forecasting and Emissions \u2014 ", SCRIPT_STEM),
    paste0("*Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "*"),
    ""),
  OUT_FILE, append = FALSE
)

# =============================================================================
# 5.1  Phase C initialisation
# =============================================================================

md("## 5.1 Phase C initialisation", "")

pi_list <- step4$pi_phase_c   # list(Constant_Speed = vec, Variable_Speed = vec)

pi0_tbl <- map_dfr(PHASE_C_GROUPS, function(grp) {
  pi <- pi_list[[grp]]
  tibble(Group = grp, !!!setNames(as.list(round(pi, 4)), STAGE_LABELS))
})

write_kbl(
  pi0_tbl |>
    kable(format = "html", escape = FALSE,
          align  = c("l", rep("r", FORECAST_MAX_STAGE)),
          caption = "Table 5.1: Phase C initialisation stage distribution (pi_0), P24 cold-engaged records") |>
    kable_styling(full_width = FALSE, bootstrap_options = "bordered", position = "left") |>
    add_header_above(c(" " = 1, "Stage proportion (pi_0)" = FORECAST_MAX_STAGE))
)
md(
  "",
  "pi_0 is derived from P24 cold-engaged records (Phase C, 2025+). CS fleet is 53.8% at Stage V; Variable_Speed is 76.5% at Stage V, reflecting anticipatory pre-2025 compliance.",
  "Both scenarios are initialised from these distributions. Distributions are taken directly from P24 audits and are not projected from Phase B.",
  ""
)

# =============================================================================
# 5.2  Scenario A -- P_Total projection (natural + proactive, no enforcement)
# =============================================================================

md("## 5.2 Scenario A \u2014 Stage distribution forecast (P_Total, proactive + natural)", "")

scen_a <- map_dfr(PHASE_C_GROUPS, function(grp) {
  project_distribution(
    pi0     = pi_list[[grp]],
    P       = step4$mat_list[[grp]]$P_Total,
    n_years = length(FORECAST_YEARS) - 1L,
    years   = FORECAST_YEARS,
    group   = grp
  )
})

# One kable per group: stages as rows, years as columns
for (grp in PHASE_C_GROUPS) {
  tbl <- scen_a |>
    filter(group == grp) |>
    mutate(
      stage_lbl = factor(stage_lbl, levels = STAGE_LABELS),
      pct       = sprintf("%.1f%%", prop * 100)
    ) |>
    arrange(stage_lbl) |>
    select(Stage = stage_lbl, year, pct) |>
    pivot_wider(names_from = year, values_from = pct, id_cols = Stage)

  write_kbl(
    kable(tbl, format = "html", escape = FALSE,
          align   = c("l", rep("r", length(FORECAST_YEARS))),
          caption = sprintf("Table 5.2 Scenario A \u2014 %s: Stage distribution by year (%%)", grp)) |>
      kable_styling(full_width = FALSE, bootstrap_options = "bordered", position = "left") |>
      add_header_above(c(" " = 1, "Year" = length(FORECAST_YEARS)))
  )
  md(
    "",
    sprintf("Scenario A stage distribution for %s, 2025\u20132030: natural turnover + proactive LEZ only. Stages as rows; years as columns.", grp),
    "Stage V share grows gradually year-on-year; lower stages decline at a rate governed by p_cf and p_pro.",
    ""
  )
}

# Plot 5.2
fig52_file <- paste0(SCRIPT_STEM, "_fig5_2_scen_a_stage.png")
p_52 <- scen_a |>
  mutate(
    group     = factor(group, levels = PHASE_C_GROUPS),
    stage_lbl = factor(stage_lbl, levels = STAGE_LABELS)
  ) |>
  ggplot(aes(x = year, y = prop, colour = stage_lbl, group = stage_lbl)) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 1.8) +
  facet_wrap(~group, nrow = 2) +
  scale_colour_brewer(palette = "Set2", name = "Stage") +
  scale_y_continuous(
    labels = function(x) paste0(round(x * 100), "%"),
    limits = c(0, 1), expand = expansion(mult = c(0, 0.04))
  ) +
  scale_x_continuous(breaks = FORECAST_YEARS) +
  labs(title = "Scenario A: Stage distribution forecast 2025\u20132030",
       x = "Year", y = "Proportion of fleet") +
  theme_bw(base_size = 10) +
  theme(legend.position   = "right",
        plot.title        = element_text(size = 10),
        axis.text.x       = element_text(angle = 45, hjust = 1))

ggsave(file.path("outputs", fig52_file), p_52,
       width = 16, height = 12, units = "cm", dpi = 180)
md(sprintf("![Scenario A stage distribution forecast](%s)", fig52_file), "")
md(
  "Stage proportions under Scenario A (no enforcement). Stage V rises monotonically for both groups; the rate is slower for Constant_Speed (p_cf = 0.016) than Variable_Speed (p_cf = 0.168).",
  "Lower stages (I\u2013IV) decay in proportion as machines are progressively replaced; Stage IIIA in CS persists due to the low replacement rate.",
  ""
)

# =============================================================================
# 5.3  Scenario B -- Boolean mask (full enforcement upper bound)
# =============================================================================

md("## 5.3 Scenario B \u2014 Stage distribution forecast (enforcement upper bound)", "")

# Build list of P_B matrices, one per transition TO each year 2026-2030
build_pb_list <- function(grp) {
  P_base <- step4$mat_list[[grp]]$P_Total
  lapply(FORECAST_YEARS[-1L], function(yr) {
    thresh <- COMP_THRESH[[grp]][[as.character(yr)]]
    build_scenario_b(P_base, thresh)
  })
}

scen_b <- map_dfr(PHASE_C_GROUPS, function(grp) {
  project_distribution(
    pi0     = pi_list[[grp]],
    P       = build_pb_list(grp),
    n_years = length(FORECAST_YEARS) - 1L,
    years   = FORECAST_YEARS,
    group   = grp
  )
})

# One kable per group
for (grp in PHASE_C_GROUPS) {
  tbl <- scen_b |>
    filter(group == grp) |>
    mutate(
      stage_lbl = factor(stage_lbl, levels = STAGE_LABELS),
      pct       = sprintf("%.1f%%", prop * 100)
    ) |>
    arrange(stage_lbl) |>
    select(Stage = stage_lbl, year, pct) |>
    pivot_wider(names_from = year, values_from = pct, id_cols = Stage)

  write_kbl(
    kable(tbl, format = "html", escape = FALSE,
          align   = c("l", rep("r", length(FORECAST_YEARS))),
          caption = sprintf("Table 5.3 Scenario B \u2014 %s: Stage distribution by year (%%)", grp)) |>
      kable_styling(full_width = FALSE, bootstrap_options = "bordered", position = "left") |>
      add_header_above(c(" " = 1, "Year" = length(FORECAST_YEARS)))
  )
  md(
    "",
    sprintf("Scenario B (full enforcement upper bound) for %s: non-compliant machines forced to Stage V each annual step. Stages as rows; years as columns.", grp),
    "Stage V reaches near 100% by 2026 for both groups as the Boolean mask drives all non-compliant machines to the absorbing state in one step.",
    ""
  )
}

# Plot 5.3
fig53_file <- paste0(SCRIPT_STEM, "_fig5_3_scen_b_stage.png")
p_53 <- scen_b |>
  mutate(
    group     = factor(group, levels = PHASE_C_GROUPS),
    stage_lbl = factor(stage_lbl, levels = STAGE_LABELS)
  ) |>
  ggplot(aes(x = year, y = prop, colour = stage_lbl, group = stage_lbl)) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 1.8) +
  facet_wrap(~group, nrow = 2) +
  scale_colour_brewer(palette = "Set2", name = "Stage") +
  scale_y_continuous(
    labels = function(x) paste0(round(x * 100), "%"),
    limits = c(0, 1), expand = expansion(mult = c(0, 0.04))
  ) +
  scale_x_continuous(breaks = FORECAST_YEARS) +
  labs(title = "Scenario B: Stage distribution forecast 2025\u20132030 (enforcement upper bound)",
       x = "Year", y = "Proportion of fleet") +
  theme_bw(base_size = 10) +
  theme(legend.position   = "right",
        plot.title        = element_text(size = 10),
        axis.text.x       = element_text(angle = 45, hjust = 1))

ggsave(file.path("outputs", fig53_file), p_53,
       width = 16, height = 12, units = "cm", dpi = 180)
md(sprintf("![Scenario B stage distribution forecast](%s)", fig53_file), "")
md(
  "Under full enforcement, all non-compliant machines transition to Stage V in the first annual step; Stage V proportion reaches 100% by 2026.",
  "This is the structural upper bound: actual enforcement outcomes will lie between Scenario A and Scenario B depending on audit frequency and enforcement capacity.",
  ""
)

# =============================================================================
# 5.4  Compliance trajectory comparison
# =============================================================================

md("## 5.4 Compliance trajectory", "")

comp_a   <- compute_compliance(scen_a, COMP_THRESH, "Scenario A")
comp_b   <- compute_compliance(scen_b, COMP_THRESH, "Scenario B")
comp_all <- bind_rows(comp_a, comp_b)

# One kable per group: scenarios as rows, years as columns
for (grp in PHASE_C_GROUPS) {
  # Build threshold annotation row for caption
  thresh_str <- paste(
    FORECAST_YEARS,
    STAGE_LABELS[as.character(COMP_THRESH[[grp]])],
    sep = "=", collapse = "; "
  )

  tbl <- comp_all |>
    filter(group == grp) |>
    mutate(pct = sprintf("%.1f%%", compliance_rate * 100)) |>
    select(Scenario = scenario, year, pct) |>
    pivot_wider(names_from = year, values_from = pct, id_cols = Scenario)

  write_kbl(
    kable(tbl, format = "html", escape = FALSE,
          align   = c("l", rep("r", length(FORECAST_YEARS))),
          caption = sprintf(
            "Table 5.4 \u2014 %s: Compliance rate by scenario and year (%%) [thresholds: %s]",
            grp, thresh_str
          )) |>
      kable_styling(full_width = FALSE, bootstrap_options = "bordered", position = "left") |>
      add_header_above(c(" " = 1, "Year" = length(FORECAST_YEARS)))
  )
  md(
    "",
    sprintf("Compliance rate for %s by year: proportion of fleet at or above the year-specific threshold (CS: Stage V throughout; VS: Stage IV 2025\u20132029, Stage V 2030).", grp),
    "Scenario A shows gradual improvement driven by natural turnover; Scenario B achieves near-100% compliance from 2026 by assumption.",
    ""
  )
}

# Plot 5.4: compliance trajectory with shaded gap
fig54_file <- paste0(SCRIPT_STEM, "_fig5_4_compliance.png")
p_54 <- comp_all |>
  mutate(
    group    = factor(group, levels = PHASE_C_GROUPS),
    scenario = factor(scenario, levels = c("Scenario A", "Scenario B"))
  ) |>
  ggplot(aes(x = year, y = compliance_rate, colour = scenario, linetype = scenario,
             shape = scenario)) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 2.5) +
  facet_wrap(~group, nrow = 2) +
  scale_colour_manual(values   = c("Scenario A" = "#2166AC", "Scenario B" = "#D6604D")) +
  scale_linetype_manual(values = c("Scenario A" = "solid",   "Scenario B" = "dashed")) +
  scale_shape_manual(values    = c("Scenario A" = 16,        "Scenario B" = 17)) +
  scale_y_continuous(
    labels = function(x) paste0(round(x * 100), "%"),
    limits = c(0, 1), expand = expansion(mult = c(0, 0.04))
  ) +
  scale_x_continuous(breaks = FORECAST_YEARS) +
  labs(title    = "Compliance trajectory 2025\u20132030: Scenario A vs Scenario B",
       x        = "Year",
       y        = "Compliance rate",
       colour   = NULL, linetype = NULL, shape = NULL) +
  theme_bw(base_size = 10) +
  theme(legend.position = "bottom",
        plot.title      = element_text(size = 10),
        axis.text.x     = element_text(angle = 45, hjust = 1))

ggsave(file.path("outputs", fig54_file), p_54,
       width = 16, height = 12, units = "cm", dpi = 180)
md(sprintf("![Compliance trajectory 2025\u20132030](%s)", fig54_file), "")
md(
  "Blue = Scenario A (natural + proactive turnover); red dashed = Scenario B (enforcement upper bound). The 2025 values are identical (both initialised from pi_0).",
  "The gap between scenarios represents the additional compliance improvement attributable to enforcement; a narrow gap means natural turnover alone is nearly sufficient.",
  ""
)

# Summary: 2025 and 2030 compliance
comp_summary <- comp_all |>
  filter(year %in% c(2025L, 2030L)) |>
  mutate(
    col_lbl = paste0(scenario, " (", year, ")"),
    pct     = sprintf("%.1f%%", compliance_rate * 100)
  ) |>
  select(group, col_lbl, pct) |>
  pivot_wider(names_from = col_lbl, values_from = pct) |>
  rename(Group = group)

write_kbl(
  comp_summary |>
    kable(format = "html", escape = FALSE,
          align   = c("l", rep("r", ncol(comp_summary) - 1L)),
          caption = "Table 5.4b: Compliance rate at initialisation (2025) and end of forecast (2030)") |>
    kable_styling(full_width = FALSE, bootstrap_options = "bordered", position = "left")
)
md(
  "",
  "The 2025 column (both scenarios identical) is the compliance rate at Phase C initialisation as observed in P24 audit data; the 2030 columns are projected under each scenario.",
  "The difference in 2030 Scenario A vs Scenario B compliance rates represents the enforcement-attributable improvement ceiling.",
  ""
)

# =============================================================================
# 5.5  Emissions
# =============================================================================

md("## 5.5 Emissions", "")

run_emissions <- !any(is.na(EF_s))

if (!run_emissions) {
  md(
    "> **WARNING: Emission factors (EF_s) not supplied \u2014 emissions section skipped.**",
    "> Supply EMEP/EEA Tier 3 NOx factors (g NOx/kWh, Stages 1\u20136) in the `EF_s` vector",
    "> at the top of this script. Source: Ntziachristos & Samaras (2019).",
    ""
  )
  message("Step 5 \u2014 emissions section skipped: EF_s contains NA.")
} else {
  # Identify kw column (snake_case after Step 1 ingestion)
  kw_col_candidates <- c("kw_power", "kw.power")
  kw_col <- intersect(kw_col_candidates, names(audits))[1]

  if (is.na(kw_col)) {
    warning(sprintf(
      "kw column not found (tried: %s) -- using unit kW (1.0) for all stages.",
      paste(kw_col_candidates, collapse = ", ")
    ))
  }

  # Compute mean kW by group x stage from Phase C cold records.
  # Falls back to unit kW if kw column absent or stage cell has < 5 observations.
  kw_by_stage <- map(PHASE_C_GROUPS, function(grp) {
    kw_vec <- setNames(rep(1.0, FORECAST_MAX_STAGE), as.character(1:FORECAST_MAX_STAGE))

    if (!is.na(kw_col)) {
      sub <- audits |>
        filter(
          group        == grp,
          phase        == "C",
          cold_engaged == TRUE,
          !is.na(.data[[kw_col]]),
          is.finite(.data[[kw_col]]),
          .data[[kw_col]] > 0
        )
      overall_mean <- if (nrow(sub) > 0L) mean(sub[[kw_col]]) else 1.0
      kw_vec[] <- overall_mean

      stage_means <- sub |>
        filter(!is.na(initial_stage), initial_stage <= FORECAST_MAX_STAGE) |>
        group_by(initial_stage) |>
        summarise(mean_kw = mean(.data[[kw_col]]), n = n(), .groups = "drop")

      for (row_i in seq_len(nrow(stage_means))) {
        s_char <- as.character(stage_means$initial_stage[row_i])
        if (stage_means$n[row_i] >= 5L) kw_vec[s_char] <- stage_means$mean_kw[row_i]
      }
    }
    kw_vec
  })
  names(kw_by_stage) <- PHASE_C_GROUPS

  # Annual emissions intensity (g NOx per hr per average-machine unit fleet)
  # E_t = sum_s(pi_s,t * kW_s * OPERATING_HOURS * EF_s); indexed to 2025 = 100
  compute_emissions <- function(scen_data, label) {
    map_dfr(PHASE_C_GROUPS, function(grp) {
      kw_vec <- kw_by_stage[[grp]]
      ef_vec <- EF_s[as.character(seq_len(FORECAST_MAX_STAGE))]
      scen_data |>
        filter(group == grp) |>
        mutate(
          kw_s       = kw_vec[as.character(stage)],
          ef_s       = ef_vec[as.character(stage)],
          emiss_term = prop * kw_s * ef_s * OPERATING_HOURS
        ) |>
        group_by(year) |>
        summarise(emiss_raw = sum(emiss_term, na.rm = FALSE), .groups = "drop") |>
        mutate(group = grp, scenario = label)
    })
  }

  emiss_a   <- compute_emissions(scen_a, "Scenario A")
  emiss_b   <- compute_emissions(scen_b, "Scenario B")
  emiss_all <- bind_rows(emiss_a, emiss_b)

  # Normalise to 2025 = 100 within each group x scenario
  base_vals <- emiss_all |>
    filter(year == 2025L) |>
    select(group, scenario, base = emiss_raw)
  emiss_all <- emiss_all |>
    left_join(base_vals, by = c("group", "scenario")) |>
    mutate(emiss_idx = round(emiss_raw / base * 100, 1))

  # One kable per group
  for (grp in PHASE_C_GROUPS) {
    tbl <- emiss_all |>
      filter(group == grp) |>
      select(Scenario = scenario, year, emiss_idx) |>
      pivot_wider(names_from = year, values_from = emiss_idx, id_cols = Scenario)

    write_kbl(
      kable(tbl, format = "html", escape = FALSE,
            align   = c("l", rep("r", length(FORECAST_YEARS))),
            caption = sprintf(
              "Table 5.5 \u2014 %s: Relative NOx emissions index (2025 = 100)", grp
            )) |>
        kable_styling(full_width = FALSE, bootstrap_options = "bordered", position = "left") |>
        add_header_above(c(" " = 1, "Year" = length(FORECAST_YEARS)))
    )
    md(
      "",
      sprintf("Relative NOx emissions index (2025 = 100) for %s, based on stage proportions, mean kW by stage from Phase C audit records, and EMEP/EEA Tier 3 factors.", grp),
      "A declining index indicates falling fleet-average NOx intensity; absolute emissions require fleet size (not available from audit data).",
      ""
    )
  }

  # Plot 5.5
  fig55_file <- paste0(SCRIPT_STEM, "_fig5_5_emissions.png")
  p_55 <- emiss_all |>
    mutate(
      group    = factor(group, levels = PHASE_C_GROUPS),
      scenario = factor(scenario, levels = c("Scenario A", "Scenario B"))
    ) |>
    ggplot(aes(x = year, y = emiss_idx, colour = scenario, linetype = scenario,
               shape = scenario)) +
    geom_line(linewidth = 0.9) +
    geom_point(size = 2.5) +
    geom_hline(yintercept = 100, linetype = "dotted", colour = "grey40") +
    facet_wrap(~group, nrow = 2) +
    scale_colour_manual(values   = c("Scenario A" = "#2166AC", "Scenario B" = "#D6604D")) +
    scale_linetype_manual(values = c("Scenario A" = "solid",   "Scenario B" = "dashed")) +
    scale_shape_manual(values    = c("Scenario A" = 16,        "Scenario B" = 17)) +
    scale_x_continuous(breaks = FORECAST_YEARS) +
    labs(title    = "Relative NOx emissions index 2025\u20132030 (2025 = 100)",
         x        = "Year",
         y        = "Emissions index",
         colour   = NULL, linetype = NULL, shape = NULL) +
    theme_bw(base_size = 10) +
    theme(legend.position = "bottom",
          plot.title      = element_text(size = 10),
          axis.text.x     = element_text(angle = 45, hjust = 1))

  ggsave(file.path("outputs", fig55_file), p_55,
         width = 16, height = 12, units = "cm", dpi = 180)
  md(sprintf("![Relative NOx emissions index 2025\u20132030](%s)", fig55_file), "")
  md(
    "Declining index = falling fleet-average NOx intensity as high-emitting older stages are progressively replaced. Scenario B achieves faster reductions due to enforcement-driven transitions.",
    "Dotted reference line at 100 marks the 2025 baseline. Absolute emissions require total fleet size input, which is not available from audit records.",
    ""
  )
}

# =============================================================================
# Known limitations
# =============================================================================

md(
  "## Known limitations",
  "",
  "1. **Ecological inference:** aggregate audit counts approximate individual machine transition hazards.",
  "2. **Entry/exit bias:** audit sample records new and continuing machines; Markov time-homogeneity is violated as the underlying fleet composition changes.",
  "3. **Single annual probability:** lambda_CF is assumed constant over Phase C; time-varying hazard within Phase B is documented but not carried forward.",
  "4. **Counterfactual overestimate:** lambda_CF likely overstates natural turnover due to second-hand market leakage; lambda_Proactive is a conservative lower bound.",
  "5. **Phase A1/A2 sparsity:** Variable_Speed lambda is estimated from pooled A1/A2 data.",
  "6. **Scenario B is an upper bound:** full enforcement effectiveness assumed; actual outcomes depend on audit frequency, capacity, and operator response time.",
  "7. **Emissions index only:** no fleet size input. EF_s from EMEP/EEA Tier 3 at nominal load; real-world emissions depend on duty cycle.",
  ""
)

# =============================================================================
# Glossary
# =============================================================================

md(
  "## Glossary",
  "",
  "| Term | Definition |",
  "|------|------------|",
  "| **Scenario A** | Baseline forecast: P_Total applied annually (natural turnover + proactive LEZ). No enforcement augmentation. |",
  "| **Scenario B** | Upper-bound forecast: Boolean mask zeroes transitions to non-compliant stages; rescales rows. Non-compliant machines must jump to Stage V each step. |",
  "| **Boolean mask** | Set P_Total[i,j] = 0 for all j < compliance threshold for year t; rescale rows. |",
  "| **pi_0** | Phase C initialisation distribution: Stage proportions from P24 cold-engaged records. |",
  "| **Compliance threshold** | Minimum Stage integer per group per year (schema.md Table 2). CS = 6 throughout; VS = 5 (2025\u20132029), 6 (2030). |",
  "| **Emissions index** | E_t / E_2025 \u00d7 100; E_t = \u03a3_s(pi_s,t \u00d7 kW_s \u00d7 2000 hr \u00d7 EF_s). |",
  "| **EF_s** | EMEP/EEA Tier 3 NOx emission factor (g NOx/kWh) for Stage s (Ntziachristos & Samaras 2019). |",
  "| **kW_s** | Mean rated power of machines at Stage s in Phase C cold fleet, from audit records. |",
  ""
)

# =============================================================================
# Save intermediate objects
# =============================================================================

step5_forecasts <- list(
  scen_a      = scen_a,
  scen_b      = scen_b,
  comp_a      = comp_a,
  comp_b      = comp_b,
  pi_list     = pi_list,
  COMP_THRESH = COMP_THRESH
)

if (run_emissions) {
  step5_forecasts$emiss_all   <- emiss_all
  step5_forecasts$kw_by_stage <- kw_by_stage
  step5_forecasts$EF_s        <- EF_s
}

save_obj(scen_a, "forecast_scen_a", "tbl_df",
         sprintf("%d x %d", nrow(scen_a), ncol(scen_a)), "5",
         "Scenario A: annual Stage distribution forecast 2025-2030 (P_Total, proactive + natural)")
save_obj(scen_b, "forecast_scen_b", "tbl_df",
         sprintf("%d x %d", nrow(scen_b), ncol(scen_b)), "5",
         "Scenario B: enforcement-augmented Stage distribution forecast 2025-2030 (Boolean mask upper bound)")
save_obj(step5_forecasts, "step5_forecasts", "list",
         sprintf("%d elements", length(step5_forecasts)), "5",
         "Step 5 bundle: Scenario A/B forecasts, compliance trajectories, pi_0, COMP_THRESH")

# =============================================================================
# Console summary
# =============================================================================

cat("\n=== Step 5 Forecasting (v1): Objects saved ===\n\n")

cat("Phase C initialisation (pi_0):\n")
for (grp in PHASE_C_GROUPS) {
  v_pct <- round(pi_list[[grp]][FORECAST_MAX_STAGE] * 100, 1)
  cat(sprintf("  %-18s Stage V share = %.1f%%\n", grp, v_pct))
}

cat("\nScenario A \u2014 Stage V share by year:\n")
for (grp in PHASE_C_GROUPS) {
  vals <- scen_a |>
    filter(group == grp, stage == FORECAST_MAX_STAGE) |>
    arrange(year) |>
    mutate(s = sprintf("%d:%.1f%%", year, prop * 100)) |>
    pull(s) |>
    paste(collapse = "  ")
  cat(sprintf("  %-18s %s\n", grp, vals))
}

cat("\nScenario B \u2014 Stage V share by year:\n")
for (grp in PHASE_C_GROUPS) {
  vals <- scen_b |>
    filter(group == grp, stage == FORECAST_MAX_STAGE) |>
    arrange(year) |>
    mutate(s = sprintf("%d:%.1f%%", year, prop * 100)) |>
    pull(s) |>
    paste(collapse = "  ")
  cat(sprintf("  %-18s %s\n", grp, vals))
}

cat("\nCompliance rates at 2030 (threshold per group):\n")
for (grp in PHASE_C_GROUPS) {
  cA <- comp_a |> filter(group == grp, year == 2030L) |> pull(compliance_rate)
  cB <- comp_b |> filter(group == grp, year == 2030L) |> pull(compliance_rate)
  cat(sprintf("  %-18s Scen A = %.1f%%   Scen B = %.1f%%\n", grp, cA * 100, cB * 100))
}

if (!run_emissions) {
  cat("\nEmissions: SKIPPED (EF_s not supplied \u2014 supply EMEP/EEA Tier 3 NOx factors)\n")
} else {
  cat("\nEmissions index at 2030 (2025 = 100):\n")
  for (grp in PHASE_C_GROUPS) {
    idxA <- emiss_all |> filter(group == grp, scenario == "Scenario A", year == 2030L) |> pull(emiss_idx)
    idxB <- emiss_all |> filter(group == grp, scenario == "Scenario B", year == 2030L) |> pull(emiss_idx)
    cat(sprintf("  %-18s Scen A = %.1f   Scen B = %.1f\n", grp, idxA, idxB))
  }
}

cat(sprintf("\nObjects saved to %s/: forecast_scen_a.rds, forecast_scen_b.rds, step5_forecasts.rds\n", INT_DIR))
cat(sprintf("Output: %s\n\n", OUT_FILE))

sessionInfo()
