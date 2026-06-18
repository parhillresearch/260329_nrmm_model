# 260415_step3_parameter_estimation_v6.R
# Step 3: Parameter Estimation — Trial 6
#
# Changes vs Trial 5 (CLAUDE.md convention update):
#   NEW layout  Sections 3.2 and 3.4 rewritten to per-group tables.
#               Each table: one group, phases as columns, statistics as rows.
#               One faceted plot added per section (stacked / grouped bars).
#   3.1, 3.3    Unchanged (group-only dimension → single table, groups as rows).
#
# Route definitions (schema.md Table 3, unchanged from Trial 5):
#   Routes 4+5 = init_mach_emissions_compliant == FALSE
#   Route 4    = Routes 4+5 AND final_mach_emissions_compliant == TRUE
#   Route 5    = Routes 4+5 AND final_mach_emissions_compliant == FALSE

# ── Libraries ─────────────────────────────────────────────────────────────────
suppressPackageStartupMessages({
  library(tidyverse)
  library(knitr)
  library(kableExtra)
})

# ── Script constants ───────────────────────────────────────────────────────────
SCRIPT_STEM <- "260415_step3_parameter_estimation_v6"
OUT_FILE    <- file.path("outputs", paste0(SCRIPT_STEM, ".md"))
INT_DIR     <- "intermediate"
MANIFEST    <- file.path(INT_DIR, "manifest.md")

GROUP_ORDER  <- c("Constant_Speed", "CAZ_Plus", "Rest_of_London", "Variable_Speed")
EBAR_PHASES  <- c("A1", "A2", "B", "C")          # phase labels for e-bar tables
PERIOD_ORDER <- c("A1", "A2", "B1", "B2", "B3", "C")  # period labels for enforcement

MAX_STAGE <- c(
  Constant_Speed = 3L, CAZ_Plus = 6L, Rest_of_London = 6L, Variable_Speed = 6L
)

COMP_THRESH <- list(
  A1 = c(Constant_Speed = 3L, CAZ_Plus = 4L, Rest_of_London = 3L),
  A2 = c(Constant_Speed = 3L, CAZ_Plus = 4L, Rest_of_London = 3L),
  B  = c(Constant_Speed = 6L, CAZ_Plus = 5L, Rest_of_London = 4L),
  C  = c(Constant_Speed = 6L, Variable_Speed = 6L)
)

PHASE_BOUNDS <- list(
  A1 = c(2016.0000, 2018.9973),
  A2 = c(2019.0000, 2020.6667),
  B  = c(2020.6667, 2024.9973),
  C  = c(2025.0000, 2031.0000)
)

B_BREAKS     <- c(2020.6667, 2022.1096, 2023.5534, 2024.9973)
B_MIDS       <- c(2021.389, 2022.832, 2024.278)
ENF_SPARSE_N <- 30L

REF_LAMBDA_CF <- c(
  Constant_Speed = 0.358, CAZ_Plus = 0.363, Rest_of_London = 0.219
)

# ── Helper functions ───────────────────────────────────────────────────────────

to_frac_year <- function(d) {
  yr   <- as.integer(format(d, "%Y"))
  doy  <- as.integer(format(d, "%j"))
  leap <- ((yr %% 4L == 0L) & (yr %% 100L != 0L)) | (yr %% 400L == 0L)
  yr + (doy - 1L) / ifelse(leap, 366L, 365L)
}

# WLS of mean_stage ~ mid, weighted by n; returns single-row tibble.
fit_lambda <- function(pts, min_pts = 2L) {
  pts <- pts |> filter(!is.na(mean_stage), !is.na(n), n > 0L, is.finite(mean_stage))
  if (nrow(pts) < min_pts) {
    return(tibble(lambda = NA_real_, se = NA_real_,
                  ci_lo = NA_real_, ci_hi = NA_real_,
                  n_pts = nrow(pts), n_obs = sum(pts$n, na.rm = TRUE)))
  }
  fit  <- lm(mean_stage ~ mid, data = pts, weights = n)
  b    <- coef(fit)[["mid"]]
  se_b <- sqrt(vcov(fit)["mid", "mid"])
  df_r <- df.residual(fit)
  tc   <- qt(0.975, df = max(df_r, 1L))
  tibble(lambda = b, se = se_b,
         ci_lo = b - tc * se_b, ci_hi = b + tc * se_b,
         n_pts = nrow(pts), n_obs = as.integer(sum(pts$n)))
}

# Phase-B 3-segment midpoint aggregation (requires frac_year, stage_capped).
phase_b_pts <- function(dat) {
  dat |>
    mutate(seg = findInterval(frac_year, B_BREAKS, rightmost.closed = TRUE)) |>
    filter(seg >= 1L, seg <= 3L) |>
    group_by(seg) |>
    summarise(mean_stage = mean(stage_capped, na.rm = TRUE), n = n(), .groups = "drop") |>
    mutate(mid = B_MIDS[seg])
}

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

md       <- function(...) write_lines(c(...), OUT_FILE, append = TRUE)
write_kbl <- function(kbl_obj) write_lines(as.character(kbl_obj), OUT_FILE, append = TRUE)

# Build a statistics-as-rows, phases-as-columns tibble for one group.
# Arguments:
#   stat_names : character vector — row labels (statistics)
#   stat_vals  : named list keyed on phase/period; each element is a character
#                vector of length(stat_names) for that column.
#   cols       : character vector of phase/period column names (in display order)
# Returns a tibble ready for kable.
build_group_tbl <- function(stat_names, stat_vals, cols) {
  tbl <- tibble(Statistic = stat_names)
  for (col in cols) {
    vals <- stat_vals[[col]]
    tbl[[col]] <- if (is.null(vals)) rep("\u2014", length(stat_names)) else vals
  }
  tbl
}

# Render a per-group tibble as a kableExtra HTML table with "Phase" super-header.
# Arguments:
#   tbl     : tibble from build_group_tbl()
#   caption : string — table caption
#   cols    : character vector of phase/period column names
render_group_kbl <- function(tbl, caption, cols) {
  tbl |>
    kable(format = "html", escape = FALSE,
          align = c("l", rep("r", length(cols))),
          caption = caption) |>
    kable_styling(full_width = FALSE, bootstrap_options = "bordered", position = "left") |>
    add_header_above(c(" " = 1, "Phase" = length(cols)))
}

# ── Load data ──────────────────────────────────────────────────────────────────
audits <- readRDS(file.path(INT_DIR, "audits.rds")) |>
  rename(frac_year = date_frac)

write_lines(
  c(paste0("# Step 3 Parameter Estimation \u2014 ", SCRIPT_STEM),
    paste0("*Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "*"), ""),
  OUT_FILE, append = FALSE
)

# =============================================================================
# 3.1  lambda_CF — Counterfactual fleet turnover rate (unchanged from Trial 5)
# =============================================================================

cold <- audits |>
  filter(cold_engaged == TRUE,
         group %in% c("Constant_Speed", "CAZ_Plus", "Rest_of_London")) |>
  mutate(stage_capped = pmin(initial_stage, MAX_STAGE[group]))

cs_annual <- cold |>
  filter(group == "Constant_Speed",
         frac_year >= PHASE_BOUNDS$A1[1], frac_year < 2024.0) |>
  mutate(yr = floor(frac_year)) |>
  group_by(yr) |>
  summarise(mean_stage = mean(stage_capped, na.rm = TRUE), n = n(), .groups = "drop") |>
  mutate(mid = yr + 0.5)

lam_cf_cs <- fit_lambda(cs_annual)

vs_cf_lambda <- function(grp) {
  dat   <- cold |> filter(group == grp)
  max_s <- MAX_STAGE[[grp]]
  a12_mid <- (PHASE_BOUNDS$A1[1] + PHASE_BOUNDS$A2[2]) / 2
  a12 <- dat |>
    filter(frac_year >= PHASE_BOUNDS$A1[1], frac_year <= PHASE_BOUNDS$A2[2]) |>
    summarise(mean_stage = mean(pmin(initial_stage, max_s), na.rm = TRUE),
              n = n(), .groups = "drop") |>
    mutate(mid = a12_mid)
  b_pts <- dat |>
    filter(frac_year >= PHASE_BOUNDS$B[1], frac_year < PHASE_BOUNDS$B[2]) |>
    mutate(stage_capped = pmin(initial_stage, max_s)) |>
    phase_b_pts()
  fit_lambda(bind_rows(select(a12, mid, mean_stage, n),
                       select(b_pts, mid, mean_stage, n)))
}

lam_cf_caz <- vs_cf_lambda("CAZ_Plus")
lam_cf_rol <- vs_cf_lambda("Rest_of_London")

lambda_cf <- list(
  Constant_Speed = lam_cf_cs, CAZ_Plus = lam_cf_caz,
  Rest_of_London = lam_cf_rol,
  Variable_Speed = tibble(lambda = NA_real_, se = NA_real_,
                          ci_lo = NA_real_, ci_hi = NA_real_,
                          n_pts = 0L, n_obs = 0L)
)
save_obj(lambda_cf, "lambda_cf", "list", "4 groups", "3",
         "WLS lambda_CF by group; stages capped at MAX_STAGE; cold-engaged only")

tbl_31 <- map_dfr(GROUP_ORDER, function(g) {
  r   <- lambda_cf[[g]]
  ref <- if (g %in% names(REF_LAMBDA_CF)) REF_LAMBDA_CF[g] else NA_real_
  tibble(
    Group     = g,
    Estimate  = if (!is.na(r$lambda)) sprintf("%.3f", r$lambda) else "\u2014",
    SE        = if (!is.na(r$se))     sprintf("%.3f", r$se)     else "\u2014",
    `95% CI`  = if (!is.na(r$ci_lo))  sprintf("[%.3f,&nbsp;%.3f]", r$ci_lo, r$ci_hi) else "\u2014",
    `N obs`   = if (r$n_obs > 0L) as.character(r$n_obs) else "\u2014",
    `Prev ref`= if (!is.na(ref)) sprintf("%.3f", ref) else "\u2014",
    Delta     = if (!is.na(r$lambda) && !is.na(ref)) sprintf("%+.3f", r$lambda - ref) else "\u2014"
  )
})

md("## 3.1 lambda_CF \u2014 Counterfactual fleet turnover rate", "")
write_kbl(
  tbl_31 |>
    kable(format = "html", align = "lrrrlrr", escape = FALSE,
          col.names = c("Group", "Estimate", "SE", "95% CI", "N obs", "Prev ref", "\u0394"),
          caption = "Table 3.1: WLS \u03bb_CF by group (cold-engaged records; group-only dimension)") |>
    kable_styling(full_width = FALSE, bootstrap_options = "bordered", position = "left") |>
    add_header_above(c(" " = 1,
                       "\u03bb_CF \u2014 slope of mean stage vs time (cold-engaged, WLS)" = 6))
)
md("",
   "\u03bb_CF is the WLS slope of mean emissions stage over time in cold-engaged records; SE and 95% CI from vcov() of the lm() fit.",
   "\u0394 is the difference from the previous-trial reference; values within \u00b10.05 are consistent with prior work.",
   "")

# =============================================================================
# 3.2  e-bar — Non-compliance exposure rate
# =============================================================================
# One table per group: phases (A1, A2, B, C) as columns; ē(%) and N as rows.
# One faceted bar-chart plot across all groups.

compute_ebar <- function(grp, ph) {
  thresh_vec <- COMP_THRESH[[ph]]
  if (is.null(thresh_vec) || !(grp %in% names(thresh_vec)))
    return(tibble(ebar_pct = NA_real_, n_nc = 0L, n_tot = 0L))
  threshold <- thresh_vec[[grp]]
  dat   <- audits |> filter(group == grp, phase == ph, !is.na(initial_stage))
  n_tot <- nrow(dat)
  n_nc  <- sum(dat$initial_stage < threshold, na.rm = TRUE)
  tibble(ebar_pct = if (n_tot > 0L) 100 * n_nc / n_tot else NA_real_,
         n_nc = as.integer(n_nc), n_tot = as.integer(n_tot))
}

ebar_long <- expand_grid(group = GROUP_ORDER, phase = EBAR_PHASES) |>
  rowwise() |>
  mutate(res = list(compute_ebar(group, phase))) |>
  unnest(res) |>
  ungroup()

save_obj(ebar_long, "ebar_results", "tbl_df",
         paste0(nrow(ebar_long), " \u00d7 5"), "3",
         "e-bar non-compliance exposure rate (%) by group x phase")

# Build per-group statistics values for the table
ebar_group_vals <- function(grp) {
  dat <- ebar_long |> filter(group == grp)
  setNames(lapply(EBAR_PHASES, function(ph) {
    row <- dat |> filter(phase == ph)
    if (nrow(row) == 0 || row$n_tot[[1]] == 0L)
      return(rep("\u2014", 2L))
    c(sprintf("%.1f%%", row$ebar_pct[[1]]),
      format(row$n_tot[[1]], big.mark = ","))
  }), EBAR_PHASES)
}

EBAR_STAT_NAMES <- c("\u0113 (%)", "N (records)")

# Group-specific interpretive text (two lines each)
EBAR_TEXT <- list(
  Constant_Speed = c(
    "Constant_Speed ē rises sharply in Phase B when the Stage\u2009V threshold first applies; most generators were below Stage\u2009V at that point.",
    "Phase\u2009C data comes from P24 records; the fall from Phase B reflects anticipatory compliance ahead of the 2025 requirement."
  ),
  CAZ_Plus = c(
    "CAZ_Plus ē is moderate and relatively stable across Phase A and B, consistent with a mixed fleet straddling the IIIB\u2192IV compliance boundary.",
    "Phase\u2009C is blank because CAZ+ records are merged into Variable_Speed from 1 January 2025."
  ),
  Rest_of_London = c(
    "Rest_of_London maintains the lowest ē across all phases, reflecting that the IIIA\u2192IIIB threshold is met by the majority of the RoL fleet.",
    "Phase\u2009C is blank because RoL records merge into Variable_Speed from 1 January 2025."
  ),
  Variable_Speed = c(
    "Variable_Speed exists only from 1 January 2025 (P24 zone merger); Phase A1, A2, and B cells are structurally blank.",
    "Phase\u2009C ē of approximately 22% indicates roughly one in five P24 variable-speed machines was below Stage\u2009V at the start of the forecast period."
  )
)

md("## 3.2 e-bar \u2014 Non-compliance exposure rate", "")

for (grp in GROUP_ORDER) {
  md(paste0("### ", grp), "")
  tbl <- build_group_tbl(EBAR_STAT_NAMES, ebar_group_vals(grp), EBAR_PHASES)
  write_kbl(render_group_kbl(tbl,
    caption = paste0("Table 3.2 (", grp, "): ē and record count by phase"),
    cols = EBAR_PHASES))
  txt <- EBAR_TEXT[[grp]]
  md("", txt[1], txt[2], "")
}

# ── e-bar plot ─────────────────────────────────────────────────────────────────
p_ebar <- ebar_long |>
  filter(!is.na(ebar_pct), n_tot > 0L) |>
  mutate(group = factor(group, levels = GROUP_ORDER),
         phase = factor(phase, levels = EBAR_PHASES)) |>
  ggplot(aes(x = phase, y = ebar_pct)) +
  geom_col(fill = "#4C9BE8", width = 0.65) +
  geom_text(aes(label = sprintf("%.1f%%", ebar_pct)),
            vjust = -0.35, size = 2.8) +
  facet_wrap(~group, nrow = 2) +
  scale_y_continuous(limits = c(0, 105), expand = expansion(mult = c(0, 0))) +
  labs(title = "Non-compliance exposure rate (\u0113) by group and phase",
       subtitle = "Phases where a group has no data are absent from the panel",
       x = "Phase", y = "\u0113 (%)") +
  theme_minimal(base_size = 10) +
  theme(panel.grid.major.x = element_blank(),
        strip.text = element_text(face = "bold"))

ebar_plot_file <- paste0(SCRIPT_STEM, "_ebar.png")
ggsave(file.path("outputs", ebar_plot_file), p_ebar,
       width = 16, height = 12, units = "cm", dpi = 180)
md(paste0("![e-bar non-compliance exposure rate by group and phase](", ebar_plot_file, ")"),
   "",
   "Each panel shows ē (% of machines below the compliance threshold) for one group across all phases; missing bars indicate phases where that group has no data.",
   "The Constant_Speed Phase\u2009B spike to ~83% dominates: almost the entire generator fleet was non-compliant when Stage\u2009V was first required.",
   "")

# =============================================================================
# 3.3  lambda_Policy and lambda_Proactive (unchanged from Trial 5)
# =============================================================================

warm_sc <- audits |>
  filter(cold_engaged == FALSE, init_mach_emissions_compliant == TRUE,
         group %in% c("Constant_Speed", "CAZ_Plus", "Rest_of_London")) |>
  mutate(stage_capped = pmin(initial_stage, MAX_STAGE[group]))

cs_wsc_annual <- warm_sc |>
  filter(group == "Constant_Speed",
         frac_year >= PHASE_BOUNDS$A1[1], frac_year < 2024.0) |>
  mutate(yr = floor(frac_year)) |>
  group_by(yr) |>
  summarise(mean_stage = mean(stage_capped, na.rm = TRUE), n = n(), .groups = "drop") |>
  mutate(mid = yr + 0.5)

lam_pol_cs <- fit_lambda(cs_wsc_annual)

vs_pol_lambda <- function(grp) {
  dat   <- warm_sc |> filter(group == grp)
  max_s <- MAX_STAGE[[grp]]
  a12_mid <- (PHASE_BOUNDS$A1[1] + PHASE_BOUNDS$A2[2]) / 2
  a12 <- dat |>
    filter(frac_year >= PHASE_BOUNDS$A1[1], frac_year <= PHASE_BOUNDS$A2[2]) |>
    summarise(mean_stage = mean(pmin(initial_stage, max_s), na.rm = TRUE),
              n = n(), .groups = "drop") |>
    mutate(mid = a12_mid)
  b_pts <- dat |>
    filter(frac_year >= PHASE_BOUNDS$B[1], frac_year < PHASE_BOUNDS$B[2]) |>
    mutate(stage_capped = pmin(initial_stage, max_s)) |>
    phase_b_pts()
  fit_lambda(bind_rows(select(a12, mid, mean_stage, n),
                       select(b_pts, mid, mean_stage, n)))
}

lam_pol_caz <- vs_pol_lambda("CAZ_Plus")
lam_pol_rol <- vs_pol_lambda("Rest_of_London")

proactive <- function(lam_pol, lam_cf) {
  if (is.na(lam_pol$lambda) || is.na(lam_cf$lambda)) return(NA_real_)
  max(0, lam_pol$lambda - lam_cf$lambda)
}

lambda_proactive_tbl <- tibble(
  group         = factor(GROUP_ORDER, levels = GROUP_ORDER),
  lam_policy    = c(lam_pol_cs$lambda, lam_pol_caz$lambda, lam_pol_rol$lambda, NA_real_),
  se_policy     = c(lam_pol_cs$se,     lam_pol_caz$se,     lam_pol_rol$se,     NA_real_),
  lam_cf        = c(lam_cf_cs$lambda,  lam_cf_caz$lambda,  lam_cf_rol$lambda,  NA_real_),
  lam_proactive = c(proactive(lam_pol_cs, lam_cf_cs),
                    proactive(lam_pol_caz, lam_cf_caz),
                    proactive(lam_pol_rol, lam_cf_rol),
                    NA_real_),
  n_warm_sc     = c(as.integer(sum(cs_wsc_annual$n, na.rm = TRUE)),
                    lam_pol_caz$n_obs, lam_pol_rol$n_obs, NA_integer_)
) |> arrange(group)

save_obj(lambda_proactive_tbl, "lambda_proactive", "tbl_df",
         paste0(nrow(lambda_proactive_tbl), " \u00d7 6"), "3",
         "lambda_Policy, lambda_CF, lambda_Proactive by group")

tbl_33 <- lambda_proactive_tbl |>
  mutate(
    Group         = as.character(group),
    lam_pol_str   = if_else(is.na(lam_policy),    "\u2014", sprintf("%.3f", lam_policy)),
    se_str        = if_else(is.na(se_policy),      "\u2014", sprintf("%.3f", se_policy)),
    lam_cf_str    = if_else(is.na(lam_cf),         "\u2014", sprintf("%.3f", lam_cf)),
    lam_pro_str   = case_when(
      is.na(lam_proactive) ~ "\u2014",
      lam_proactive == 0   ~ "0.000 (floored)",
      TRUE                 ~ sprintf("%.3f", lam_proactive)
    ),
    n_str         = if_else(is.na(n_warm_sc), "\u2014", format(n_warm_sc, big.mark = ","))
  ) |>
  select(Group, lam_pol_str, se_str, lam_cf_str, lam_pro_str, n_str)

md("## 3.3 lambda_Policy and lambda_Proactive", "")
write_kbl(
  tbl_33 |>
    kable(format = "html", align = "lrrrrr", escape = FALSE,
          col.names = c("Group", "\u03bb_Policy", "SE",
                        "\u03bb_CF", "\u03bb_Proactive", "N warm sc."),
          caption = "Table 3.3: \u03bb_Policy, \u03bb_CF, and \u03bb_Proactive by group (group-only dimension)") |>
    kable_styling(full_width = FALSE, bootstrap_options = "bordered", position = "left") |>
    add_header_above(c(" " = 1, "Warm self-compliant (WLS)" = 2,
                       "Cold (WLS)" = 1, "Derived" = 1, " " = 1))
)
md("",
   "\u03bb_Policy is the WLS slope of mean stage in warm self-compliant records; it combines natural turnover and proactive LEZ-driven replacement.",
   "\u03bb_Proactive = max(0, \u03bb_Policy \u2212 \u03bb_CF) isolates the LEZ-incremental rate; 0.000 (floored) indicates no detectable proactive response above the counterfactual.",
   "")

# =============================================================================
# 3.4  Enforcement success rate — Route 4/5 descriptive analysis
# =============================================================================
# One table per group: periods (A1, A2, B1, B2, B3, C) as columns;
# N total, n R4, n R5, Route 4 %, Route 5 % as rows.
# One faceted stacked bar-chart plot across all groups.
#
# Route 4 = init_mach_emissions_compliant == FALSE AND
#           final_mach_emissions_compliant == TRUE
# Route 5 = init_mach_emissions_compliant == FALSE AND
#           final_mach_emissions_compliant == FALSE
# Caveat: blank final_machinery_reasons → final_mach_emissions_compliant = TRUE;
# slight upward bias where auditors left final reasons blank for non-actioned
# machines.

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

routes45 <- audits_period |>
  filter(init_mach_emissions_compliant == FALSE)

enf_counts <- routes45 |>
  group_by(group, period) |>
  summarise(
    n_R4    = sum(final_mach_emissions_compliant == TRUE,  na.rm = TRUE),
    n_R5    = sum(final_mach_emissions_compliant == FALSE, na.rm = TRUE),
    n_total = n(),
    .groups = "drop"
  )

enf_long <- expand_grid(group = GROUP_ORDER, period = PERIOD_ORDER) |>
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

# Build per-group values for the enforcement table
enf_group_vals <- function(grp) {
  dat <- enf_long |> filter(group == grp)
  setNames(lapply(PERIOD_ORDER, function(per) {
    row <- dat |> filter(period == per)
    if (nrow(row) == 0 || row$n_total[[1]] == 0L)
      return(rep("\u2014", 5L))
    rt <- row$rate_pct[[1]]
    rate_str <- if (row$sparse[[1]]) sprintf("%.1f%%\u26a0", rt) else sprintf("%.1f%%", rt)
    c(format(row$n_total[[1]], big.mark = ","),
      format(row$n_R4[[1]]),
      format(row$n_R5[[1]]),
      rate_str,
      sprintf("%.1f%%", 100 - rt))
  }), PERIOD_ORDER)
}

ENF_STAT_NAMES <- c("N (R4+R5)", "n Route 4", "n Route 5",
                    "Route 4 % (success)", "Route 5 % (not actioned)")

ENF_TEXT <- list(
  Constant_Speed = c(
    "Constant_Speed shows low enforcement action counts in Phases A1/A2 and larger volumes in Phase B, reflecting the stricter Stage\u2009V requirement imposed in September 2020.",
    "Route 4 success rates and sparsity flags summarise how effectively non-compliant generators were driven compliant; \u26a0 marks periods with fewer than 30 enforcement records."
  ),
  CAZ_Plus = c(
    "CAZ_Plus has the highest absolute counts of emissions-non-compliant machines given its larger fleet size and stricter IIIB\u2192IV\u2192V requirement sequence.",
    "Phase\u2009C is blank because CAZ+ records merge into Variable_Speed from 1 January 2025; enforcement data for the merged fleet appears in the Variable_Speed table."
  ),
  Rest_of_London = c(
    "Rest_of_London has moderate enforcement counts spread across Phases A1\u2013B; the lower thresholds (IIIA\u2192IIIB) keep the non-compliant pool smaller than CAZ+.",
    "Phase\u2009C is blank for the same merger reason as CAZ+; Route 4 success rates reveal the fraction of enforcement visits that achieved compliance."
  ),
  Variable_Speed = c(
    "Variable_Speed exists only in Phase\u2009C (P24 zone post-2025); Phases A1, A2, and B1\u2013B3 are structurally blank.",
    "Phase\u2009C enforcement data captures the first year(s) of the merged CAZ+/RoL fleet under the uniform Stage\u2009V requirement."
  )
)

md("## 3.4 Enforcement success rate \u2014 Route 4/5 descriptive analysis", "")

for (grp in GROUP_ORDER) {
  md(paste0("### ", grp), "")
  tbl <- build_group_tbl(ENF_STAT_NAMES, enf_group_vals(grp), PERIOD_ORDER)
  write_kbl(render_group_kbl(tbl,
    caption = paste0("Table 3.4 (", grp,
                     "): Route 4/5 enforcement counts and success rate by time period.",
                     " \u26a0 = n < ", ENF_SPARSE_N, "."),
    cols = PERIOD_ORDER))
  txt <- ENF_TEXT[[grp]]
  md("", txt[1], txt[2], "")
}

# ── enforcement plot ───────────────────────────────────────────────────────────
enf_plot_dat <- enf_long |>
  filter(n_total > 0L) |>
  select(group, period, n_R4, n_R5) |>
  pivot_longer(c(n_R4, n_R5), names_to = "route", values_to = "n") |>
  mutate(
    route  = factor(route,
                    levels = c("n_R4", "n_R5"),
                    labels = c("Route 4 (driven compliant)", "Route 5 (not actioned)")),
    group  = factor(group, levels = GROUP_ORDER),
    period = factor(period, levels = PERIOD_ORDER)
  )

rate_labels <- enf_long |>
  filter(n_total > 0L) |>
  mutate(group   = factor(group,  levels = GROUP_ORDER),
         period  = factor(period, levels = PERIOD_ORDER),
         rate_lbl = sprintf("%.0f%%", rate_pct))

p_enf <- enf_plot_dat |>
  ggplot(aes(x = period, y = n, fill = route)) +
  geom_col(position = "stack", width = 0.7) +
  geom_text(data = rate_labels,
            aes(x = period, y = n_total, label = rate_lbl),
            inherit.aes = FALSE, vjust = -0.3, size = 2.4) +
  facet_wrap(~group, nrow = 2, scales = "free_y") +
  scale_fill_manual(values = c("Route 4 (driven compliant)" = "#2E8B57",
                                "Route 5 (not actioned)"    = "#CD5C5C")) +
  labs(title = "Enforcement outcomes (Routes 4+5) by group and time period",
       subtitle = "Labels = Route\u20094 success rate (%); y-axis free across groups",
       x = "Time period", y = "N machines", fill = NULL) +
  theme_minimal(base_size = 10) +
  theme(axis.text.x    = element_text(angle = 45, hjust = 1),
        strip.text     = element_text(face = "bold"),
        legend.position = "bottom",
        panel.grid.major.x = element_blank())

enf_plot_file <- paste0(SCRIPT_STEM, "_enforcement.png")
ggsave(file.path("outputs", enf_plot_file), p_enf,
       width = 16, height = 12, units = "cm", dpi = 180)
md(paste0("![Enforcement outcomes by group and time period](", enf_plot_file, ")"),
   "",
   "Stacked bars show absolute counts of Route\u20094 (green, driven compliant) and Route\u20095 (red, not actioned) machines per group and time period; y-axes are free across facets.",
   "Labels above each bar show the Route\u20094 success rate (%); higher values indicate more effective enforcement at that audit event.",
   "")

# =============================================================================
# 3.5  Bundle Step 3 parameter estimates
# =============================================================================

step3_params <- list(
  lambda_cf        = lambda_cf,
  ebar_results     = ebar_long,
  lambda_proactive = lambda_proactive_tbl
)
save_obj(step3_params, "step3_params", "list", "3 elements", "3",
         "All Step 3 model parameter estimates: lambda_CF, e-bar, lambda_Proactive")

# =============================================================================
# Glossary
# =============================================================================

md(
  "---", "## Glossary", "",
  "| Term | Definition |",
  "|------|------------|",
  paste0("| **\u03bb_CF** | Counterfactual fleet turnover rate (WLS slope, cold-engaged records). Units: stage integers/year. |"),
  paste0("| **\u03bb_Policy** | Combined improvement rate in warm self-compliant records: natural turnover + proactive LEZ response. |"),
  paste0("| **\u03bb_Proactive** | max(0, \u03bb_Policy \u2212 \u03bb_CF): incremental rate attributable to LEZ policy; floored at zero. |"),
  paste0("| **\u0113** (e-bar) | Non-compliance exposure rate: % of all records in a group\u2013phase cell with initial stage below the compliance threshold. |"),
  paste0("| **Route 4** | Initial emissions non-compliant; enforcement actioned; machine driven compliant (proxy: no E code in final machinery reasons). |"),
  paste0("| **Route 5** | Initial emissions non-compliant; enforcement not actioned; E code persists in final machinery reasons. |"),
  paste0("| **Enforcement success rate** | n(R4) / n(R4+R5): fraction of non-compliant audit records driven compliant. Descriptive only; not a matrix parameter. |"),
  paste0("| **WLS** | Weighted least squares via lm(); SE from vcov(). |"),
  paste0("| **Cold-engaged** | Machine on site not yet engaged with the LEZ process; basis for \u03bb_CF. |"),
  paste0("| **Warm self-compliant** | Machine emissions-OK on arrival (Route 1); basis for \u03bb_Policy. |"),
  paste0("| **MAX_STAGE** | Stage integer ceiling per group: CS\u20093 (I\u2013IIIA); CAZ+/RoL/VS\u20096 (up to Stage\u2009V). |"),
  "| **Phase A1** | 1 Jan 2016 \u2013 31 Dec 2018. |",
  "| **Phase A2** | 1 Jan 2019 \u2013 31 Aug 2020. |",
  paste0("| **Phase B** | 1 Sep 2020 \u2013 31 Dec 2024; COVID-exempt records removed;",
         " sub-segmented B1/B2/B3 (~527 days each) for enforcement and \u03bb estimation. |"),
  paste0("| **Phase C** | 1 Jan 2025 \u2013 31 Dec 2030; CAZ+ and RoL merged into Variable_Speed (P24 zone). |"),
  ""
)

# =============================================================================
# Console summary
# =============================================================================

cat("\n=== Step 3 Parameter Estimation v6: Objects saved ===\n")
cat(sprintf("  lambda_cf         : list [%d groups]\n",       length(lambda_cf)))
cat(sprintf("  ebar_results      : tibble [%d \u00d7 %d]\n",  nrow(ebar_long), ncol(ebar_long)))
cat(sprintf("  lambda_proactive  : tibble [%d \u00d7 %d]\n",  nrow(lambda_proactive_tbl), ncol(lambda_proactive_tbl)))
cat(sprintf("  enf_success_rate  : tibble [%d \u00d7 %d] (descriptive; not in step3_params)\n",
            nrow(enf_long), ncol(enf_long)))
cat(sprintf("  step3_params      : list [3 elements]\n"))

cat("\n  lambda_CF:\n")
for (g in c("Constant_Speed", "CAZ_Plus", "Rest_of_London")) {
  r   <- lambda_cf[[g]]
  ref <- REF_LAMBDA_CF[g]
  if (!is.na(r$lambda)) {
    cat(sprintf("    %-18s : %.3f (SE %.3f)  ref %.3f  \u0394 %+.3f\n",
                g, r$lambda, r$se, ref, r$lambda - ref))
  }
}

cat("\n  Enforcement success rate (n R4 / n tot):\n")
enf_summary <- enf_long |>
  filter(n_total > 0L) |>
  mutate(sparse_flag = if_else(sparse, " [SPARSE]", ""))
for (i in seq_len(nrow(enf_summary))) {
  r <- enf_summary[i, ]
  cat(sprintf("    %-18s %3s : n=%4d (R4=%4d R5=%4d) rate=%.1f%%%s\n",
              r$group, r$period, r$n_total, r$n_R4, r$n_R5,
              r$rate_pct, r$sparse_flag))
}

cat(sprintf("\n  Plots saved:\n"))
cat(sprintf("    outputs/%s\n", ebar_plot_file))
cat(sprintf("    outputs/%s\n", enf_plot_file))
cat(sprintf("\n  Output file: %s\n\n", OUT_FILE))

sessionInfo()
