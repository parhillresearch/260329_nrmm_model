#!/usr/bin/env Rscript

# =====================================================================
# SUPERSEDED - development history only, NOT authoritative.
# Superseded by: nrmm_model_v4.R
# Retained so earlier results remain reproducible. Some definitions here
# differ from the current model (notably removal fate, retrofit NOx credit
# and the usage-index basis), so numbers from this script will not always
# match the current report. Do not cite it. See notes.md, "State of play".
# =====================================================================

# nrmm_model_v2 — unified NRMM model: one classified data spine, three layers.
#
# v2 adds the dashboard payloads (consumed by nrmm_dashboard_v1.R):
#   - outcomes_cells: status/outcome counts keyed subgroup x YEAR x arm, so the
#     dashboard can aggregate any year/group margin client-side by summation
#   - All_NRMM pooled EF strata, and per-cell adversarial usage envelopes
#     precomputed in R (the browser only does weighted means)
#   - threshold_schedule as data (subgroup x year), replacing R functions
#   - mean_stage added to observed_trend
#   - schema_version = 2 stamp so consumers can refuse a stale object
#
#   Layer 1  OUTCOMES: engagement arm (warm = AT treatment, cold = CF
#            counterfactual), five-way initial emissions status (quarantining
#            admin-only non-compliance), nine-way outcome mechanism with
#            TAN-based removal fate. Aggregated per Machine Group x phase x arm
#            for the tree/table dashboard views.
#   Layer 2  EF: type-stratified convex-combination fleet EF per Machine Group
#            x phase, EF_fleet = sum_t s_t EF_t, s_t = N_t kWbar_t u_t
#            (normalised), with placeholder relative usage indices u_t.
#   Layer 3  DYNAMICS: constrained Markov chain on stages 1..7. Per year, a
#            machine below the market-top stage M(t) is replaced by M(t) with
#            probability p-bar, else keeps its stage. p-bar estimated per arm x
#            engine type x era from adjacent calendar-year mean-stage
#            increments: E[dm] = p x g(t), g(t) = sum_{s<M} pi_s (M - s),
#            fitted by through-origin WLS. Two eras split at 1 Sep 2020
#            (established empirically: the slope roughly doubles there in both
#            arms; A1/A2 are NOT separate estimation eras). Phases survive
#            only as the threshold schedule. Projection 2025-2030 applies the
#            era-2 p-bar under central / CI-low / CI-high scenarios and the
#            exact-date threshold schedule.
#
# Estimation design decisions (tested 260717, see notes.md):
#   calendar-year cells; variable-speed supports both arms annually from 2016;
#   constant-speed cold is too thin for arm-specific annual fitting, so
#   constant-speed p-bar is also fitted with arms pooled; projections start
#   from the pooled 2023-24 stage distribution per Machine Group x arm.
#
# PLACEHOLDERS: stage NOx limits and usage indices are general-knowledge
# values pending verification / sourced estimates; N_t are audit counts
# pending the NRMM registration database.
#
# No stochastic code (closed-form WLS; no bootstrap in v1), so no seed.

library(readr)
library(dplyr)
library(tidyr)
library(knitr)

# --- Named constants ---

PHASE_A2_START <- as.Date("2019-01-01")
PHASE_B_START  <- as.Date("2020-09-01")   # September policy transition
PHASE_C_START  <- as.Date("2025-01-01")
ERA_SPLIT      <- as.Date("2020-09-01")   # era 1 < split <= era 2
ERA_SPLIT_FRAC <- 2020 + 244 / 365        # fractional-year form of 1 Sep 2020

# Threshold schedule (stage codes 1..7; I=1 .. V=6, ZE=7), schema Item 3b.
THRESHOLDS <- list(
  Constant_Speed = list(A1 = 3L, A2 = 3L, B = 6L, C = 6L),
  CAZ_Plus       = list(A1 = 4L, A2 = 4L, B = 5L, C = 6L),
  Rest_of_London = list(A1 = 3L, A2 = 3L, B = 4L, C = 5L)
)
# Projection-horizon thresholds: 2025-2029 = schema column 3; from 2030 col 4.
PROJ_THRESHOLD <- function(group, year) {
  if (year >= 2030) return(6L)
  switch(group, Constant_Speed = 6L, CAZ_Plus = 6L, Rest_of_London = 5L)
}

# Market-top replacement stage M(t) by engine type (constrained matrix target).
# Variable speed: Stage IV until Stage V engines available (2019), then V.
# Constant speed: Stage IIIA (last constant-speed stage pre-Regulation), then V.
MARKET_TOP <- function(engine, frac_year) {
  if (engine == "Variable") { if (frac_year < 2019) 5L else 6L }
  else                      { if (frac_year < 2019) 3L else 6L }
}

BAND_BREAKS <- c(0, 19, 37, 56, 75, 130, 560, Inf)
BAND_LABELS <- c("<19", "19-37", "37-56", "56-75", "75-130", "130-560", ">=560")
NOX_LIMIT <- rbind(   # g/kWh by stage x power band; PLACEHOLDER, verify
  `1` = c(9.2, 9.2, 9.2, 9.2, 9.2, 9.2, 9.2),
  `2` = c(8.0, 8.0, 7.0, 7.0, 6.0, 6.0, 6.0),
  `3` = c(7.5, 7.5, 4.7, 4.7, 4.0, 4.0, 4.0),
  `4` = c(7.5, 7.5, 4.7, 3.3, 3.3, 2.0, 2.0),
  `5` = c(7.5, 7.5, 4.7, 0.4, 0.4, 0.4, 3.5),
  `6` = c(7.5, 4.7, 4.7, 0.4, 0.4, 0.4, 3.5),
  `7` = c(0,   0,   0,   0,   0,   0,   0  )
)
colnames(NOX_LIMIT) <- BAND_LABELS

NAMED_TYPES <- c("Excavator", "Generator", "Telehandler", "Dumper",
                 "Piling Rig", "Pump", "Mobile Crane", "Crusher",
                 "Crawler Crane", "Roller", "MEWP", "Compressor")
TYPE_CANONICAL <- c("Piling rig" = "Piling Rig")

USAGE_INDEX <- tribble(   # PLACEHOLDER relative usage (excavator = 1)
  ~machine_type,   ~u_central, ~u_low, ~u_high,
  "Excavator",     1.0, 0.7, 1.3,   "Generator",     3.0, 1.5, 5.0,
  "Telehandler",   0.8, 0.5, 1.2,   "Dumper",        0.7, 0.4, 1.1,
  "Piling Rig",    0.8, 0.5, 1.2,   "Pump",          2.5, 1.0, 4.0,
  "Mobile Crane",  0.5, 0.3, 0.9,   "Crusher",       1.2, 0.7, 1.8,
  "Crawler Crane", 0.6, 0.4, 1.0,   "Roller",        0.6, 0.3, 1.0,
  "MEWP",          0.5, 0.3, 0.8,   "Compressor",    1.5, 0.8, 2.5,
  "Other",         0.8, 0.4, 1.2
)

NON_DISPENSATION_VALUES <- c("", "none", "rejected", "pending", "non",
                             "no nrmm", "unidentified")
UNUSABLE_TAN_VALUES <- c("", "unidentified", "none", "n/a", "na")

STATUS_KEYS  <- c("A", "B", "C", "D", "E")
OUTCOME_KEYS <- letters[1:9]

YEAR_MIN_N    <- 20      # minimum year-cell n for trend estimation
PROJ_YEARS    <- 2025:2030
PROJ_BASE_YEARS <- c(2023, 2024)   # pooled initial distribution

output_md <- "outputs/nrmm_model_v2.md"

# --- Load input data ---

cat("Loading audit data...\n")
audits <- read_delim("input_data/audits.txt", delim = "\t", show_col_types = FALSE)

essential_cols <- c("Zone", "Engine Type", "Date", "Cold-Engaged", "Machine Type",
                    "kW Power", "TAN", "Initial Emissions Stage",
                    "Final Emissions Stage", "Initial Machinery Compliance",
                    "Final Machinery Compliance", "Initial Machinery Reasons",
                    "Initial Retrofit or Exemption", "Final Retrofit or Exemption")
missing_cols <- setdiff(essential_cols, names(audits))
if (length(missing_cols) > 0) {
  stop("Missing columns: ", paste(missing_cols, collapse = ", "))
}

normalise_text <- function(x) trimws(tolower(ifelse(is.na(x), "", as.character(x))))

stage_to_int <- function(x) case_when(
  x %in% c("I", "1") ~ 1L, x %in% c("II", "2") ~ 2L,
  x %in% c("IIIA", "3") ~ 3L, x %in% c("IIIB", "4") ~ 4L,
  x %in% c("IV", "5") ~ 5L, x %in% c("V", "6") ~ 6L,
  x == "ZE" ~ 7L, TRUE ~ NA_integer_
)

parse_kw <- function(x) {
  numeric_kw <- suppressWarnings(as.numeric(x))
  range_match <- grepl("^\\s*\\d+\\s*-\\s*\\d+\\s*$", x)
  low  <- suppressWarnings(as.numeric(sub("-.*", "", x)))
  high <- suppressWarnings(as.numeric(sub(".*-", "", x)))
  ifelse(!is.na(numeric_kw), numeric_kw,
         ifelse(range_match, (low + high) / 2, NA_real_))
}

# --- Engine type imputation (per Step 1 v9 modal logic) ---

engine_type_modal <- audits %>%
  filter(`Engine Type` %in% c("Constant", "Variable")) %>%
  count(`Machine Type`, `Engine Type`, name = "freq") %>%
  slice_max(freq, by = `Machine Type`, n = 1, with_ties = FALSE) %>%
  select(`Machine Type`, engine_type_modal = `Engine Type`)

audits <- audits %>%
  left_join(engine_type_modal, by = "Machine Type") %>%
  mutate(`Engine Type` = if_else(
    !`Engine Type` %in% c("Constant", "Variable") & `Machine Type` != "Generator",
    engine_type_modal, `Engine Type`)) %>%
  select(-engine_type_modal)

# --- TAN fate lookup (whole dataset, before any filtering) ---

audits <- audits %>%
  mutate(
    audit_date = as.Date(Date, format = "%d/%m/%Y"),
    tan_usable = !is.na(TAN) & !normalise_text(TAN) %in% UNUSABLE_TAN_VALUES
  )

tan_last_seen <- audits %>%
  filter(tan_usable) %>%
  group_by(TAN) %>%
  summarise(tan_last_date = max(audit_date, na.rm = TRUE), .groups = "drop")

audits <- audits %>%
  left_join(tan_last_seen, by = "TAN") %>%
  mutate(tan_reappears_later = tan_usable & !is.na(tan_last_date) &
                               !is.na(audit_date) & tan_last_date > audit_date)

# --- The classified spine (Layer 0) ---

spine <- audits %>%
  mutate(
    cold_engaged = `Cold-Engaged` == "Yes",
    arm = if_else(cold_engaged, "cold_CF", "warm_AT"),
    subgroup = case_when(
      `Engine Type` == "Constant"                              ~ "Constant_Speed",
      `Engine Type` == "Variable" & Zone %in% c("CAZ", "OA") ~ "CAZ_Plus",
      `Engine Type` == "Variable" & Zone == "GL"              ~ "Rest_of_London",
      TRUE ~ NA_character_
    ),
    engine = if_else(subgroup == "Constant_Speed", "Constant", "Variable"),
    year = as.integer(format(audit_date, "%Y")),
    frac_year = year + (as.numeric(format(audit_date, "%j")) - 1) / 365,
    phase = case_when(
      audit_date < PHASE_A2_START ~ "A1",
      audit_date < PHASE_B_START  ~ "A2",
      audit_date < PHASE_C_START  ~ "B",
      TRUE                        ~ "C"
    ),
    era = if_else(audit_date < ERA_SPLIT, "era1", "era2"),
    threshold = case_when(
      subgroup == "Constant_Speed" ~ unlist(THRESHOLDS$Constant_Speed)[phase],
      subgroup == "CAZ_Plus"       ~ unlist(THRESHOLDS$CAZ_Plus)[phase],
      subgroup == "Rest_of_London" ~ unlist(THRESHOLDS$Rest_of_London)[phase],
      TRUE ~ NA_integer_
    ),
    initial_stage = stage_to_int(`Initial Emissions Stage`),
    final_stage   = stage_to_int(`Final Emissions Stage`),
    final_compliance_norm = normalise_text(`Final Machinery Compliance`),
    initial_retrofit_norm = normalise_text(`Initial Retrofit or Exemption`),
    final_retrofit_norm   = normalise_text(`Final Retrofit or Exemption`),
    initial_reason_e = grepl("E", `Initial Machinery Reasons`, fixed = TRUE) &
                       !is.na(`Initial Machinery Reasons`),
    initial_reason_admin = grepl("[ACPRX]",
      ifelse(normalise_text(`Initial Machinery Reasons`) %in% c("none", ""),
             "", `Initial Machinery Reasons`)),
    dispensation_at_start = !initial_retrofit_norm %in% NON_DISPENSATION_VALUES,
    initial_stage_ok = !is.na(initial_stage) & initial_stage >= threshold,
    final_stage_ok   = !is.na(final_stage)   & final_stage   >= threshold,
    removed_plain    = final_compliance_norm == "removed from site",
    replaced_onspot  = grepl("removed and replaced|removed & replaced|replaced with",
                             final_compliance_norm) |
                       grepl("removed and replaced|removed & replaced|replaced with",
                             final_retrofit_norm),
    new_retrofit  = !grepl("retrofit|dpf", initial_retrofit_norm) &
                     grepl("retrofit|dpf", final_retrofit_norm),
    new_exemption = !dispensation_at_start &
                     grepl("viab|covid|emerg|short|exempt|other|block",
                           final_retrofit_norm),
    officer_final_compliant = final_compliance_norm == "compliant",
    initial_status = case_when(
      initial_stage_ok      ~ "A",
      dispensation_at_start ~ "B",
      !is.na(initial_stage) ~ "C",
      initial_reason_e      ~ "C",
      initial_reason_admin  ~ "D",
      TRUE                  ~ "E"
    ),
    nc_outcome = case_when(
      replaced_onspot                     ~ "a",
      final_stage_ok                      ~ "b",
      new_retrofit                        ~ "c",
      removed_plain & tan_reappears_later ~ "d",
      removed_plain & tan_usable          ~ "e",
      removed_plain                       ~ "f",
      new_exemption                       ~ "g",
      officer_final_compliant             ~ "h",
      TRUE                                ~ "i"
    ),
    kw_parsed = parse_kw(`kW Power`),
    machine_type_raw = trimws(`Machine Type`),
    machine_type = coalesce(TYPE_CANONICAL[machine_type_raw], machine_type_raw),
    machine_type = if_else(machine_type %in% NAMED_TYPES, machine_type, "Other")
  ) %>%
  filter(!is.na(subgroup), machine_type_raw != "No NRMM")

machine_type_median_kw <- spine %>%
  filter(!is.na(kw_parsed)) %>%
  group_by(machine_type) %>%
  summarise(type_median_kw = median(kw_parsed), .groups = "drop")

spine <- spine %>%
  left_join(machine_type_median_kw, by = "machine_type") %>%
  mutate(
    kw_effective = coalesce(kw_parsed, type_median_kw,
                            median(kw_parsed, na.rm = TRUE)),
    band = cut(kw_effective, BAND_BREAKS, labels = BAND_LABELS, right = FALSE),
    ef_nox = if_else(is.na(initial_stage), NA_real_,
                     NOX_LIMIT[cbind(as.character(initial_stage),
                                     as.character(band))])
  )

# --- Layer 1: outcome aggregates per Machine Group x phase x arm ---

outcomes <- spine %>%
  group_by(subgroup, phase, arm) %>%
  summarise(
    n = n(),
    across(all_of("initial_status"),
           list(), .names = "drop_{.col}"),   # placeholder to keep grouping
    .groups = "drop"
  ) %>% select(-starts_with("drop_"))

status_counts <- spine %>%
  count(subgroup, phase, arm, initial_status) %>%
  pivot_wider(names_from = initial_status, values_from = n,
              values_fill = 0L, names_prefix = "status_")
outcome_counts <- spine %>%
  filter(initial_status == "C") %>%
  count(subgroup, phase, arm, nc_outcome) %>%
  pivot_wider(names_from = nc_outcome, values_from = n,
              values_fill = 0L, names_prefix = "outcome_")
outcomes <- outcomes %>%
  left_join(status_counts,  by = c("subgroup", "phase", "arm")) %>%
  left_join(outcome_counts, by = c("subgroup", "phase", "arm")) %>%
  mutate(across(starts_with(c("status_", "outcome_")), ~ coalesce(.x, 0L)),
         c_bar = (status_A + status_B) /
                 pmax(status_A + status_B + status_C, 1))

# --- Layer 1b: year-keyed outcome cells (dashboard margin source) ---

outcomes_cells <- spine %>%
  count(subgroup, year, arm, name = "n_rows") %>%
  select(subgroup, year, arm) %>%
  left_join(spine %>% count(subgroup, year, arm, initial_status) %>%
              pivot_wider(names_from = initial_status, values_from = n,
                          values_fill = 0L, names_prefix = "status_"),
            by = c("subgroup", "year", "arm")) %>%
  left_join(spine %>% filter(initial_status == "C") %>%
              count(subgroup, year, arm, nc_outcome) %>%
              pivot_wider(names_from = nc_outcome, values_from = n,
                          values_fill = 0L, names_prefix = "outcome_"),
            by = c("subgroup", "year", "arm")) %>%
  mutate(across(starts_with(c("status_", "outcome_")), ~ coalesce(.x, 0L)))
for (col in c(paste0("status_", STATUS_KEYS), paste0("outcome_", OUTCOME_KEYS))) {
  if (!col %in% names(outcomes_cells)) outcomes_cells[[col]] <- 0L
}
outcomes_cells <- outcomes_cells %>%
  mutate(n = rowSums(across(starts_with("status_")))) %>%
  select(subgroup, year, arm, n, all_of(paste0("status_", STATUS_KEYS)),
         all_of(paste0("outcome_", OUTCOME_KEYS)))

# --- Layer 2: EF strata per Machine Group x phase (plus All_NRMM pool) ---

make_strata <- function(records, label) {
  records %>%
    filter(!is.na(ef_nox)) %>%
    group_by(subgroup = label, phase, machine_type) %>%
    summarise(n_type = n(), kw_mean = mean(kw_effective),
              ef_type = weighted.mean(ef_nox, kw_effective), .groups = "drop") %>%
    left_join(USAGE_INDEX, by = "machine_type")
}

strata <- bind_rows(
  spine %>% filter(!is.na(ef_nox)) %>%
    group_by(subgroup, phase, machine_type) %>%
    summarise(n_type = n(), kw_mean = mean(kw_effective),
              ef_type = weighted.mean(ef_nox, kw_effective), .groups = "drop") %>%
    left_join(USAGE_INDEX, by = "machine_type"),
  make_strata(spine, "All_NRMM")
)

fleet_ef <- function(strata_cell, u) {
  w <- strata_cell$n_type * strata_cell$kw_mean * u
  sum(w * strata_cell$ef_type) / sum(w)
}

# adversarial usage envelope (fixed point, as 260717_ef_fleet_v2.R)
ENVELOPE_MAX_ITER <- 20
envelope_ef <- function(strata_cell, maximise) {
  u <- strata_cell$u_central
  for (iteration in seq_len(ENVELOPE_MAX_ITER)) {
    current <- fleet_ef(strata_cell, u)
    u_next <- if (maximise) {
      if_else(strata_cell$ef_type >= current, strata_cell$u_high, strata_cell$u_low)
    } else {
      if_else(strata_cell$ef_type <= current, strata_cell$u_high, strata_cell$u_low)
    }
    if (all(u_next == u)) break
    u <- u_next
  }
  fleet_ef(strata_cell, u)
}

count_refs <- bind_rows(
  spine %>% filter(!is.na(ef_nox)) %>% group_by(subgroup, phase) %>%
    summarise(ef_count_ref = mean(ef_nox), .groups = "drop"),
  spine %>% filter(!is.na(ef_nox)) %>% group_by(phase) %>%
    summarise(ef_count_ref = mean(ef_nox), .groups = "drop") %>%
    mutate(subgroup = "All_NRMM")
)

ef_results <- strata %>%
  group_by(subgroup, phase) %>%
  group_modify(function(s, key) {
    tibble(n_types = nrow(s),
           ef_central  = fleet_ef(s, s$u_central),
           ef_kw_ref   = fleet_ef(s, rep(1, nrow(s))),
           ef_env_low  = envelope_ef(s, maximise = FALSE),
           ef_env_high = envelope_ef(s, maximise = TRUE))
  }) %>% ungroup() %>%
  left_join(count_refs, by = c("subgroup", "phase"))

# --- Layer 3: dynamics — year cells, p-bar, projections ---

year_cells <- spine %>%
  filter(!is.na(initial_stage)) %>%
  count(engine, arm, year, initial_stage) %>%
  group_by(engine, arm, year) %>%
  mutate(n_cell = sum(n), pi = n / n_cell) %>%
  ungroup()

# pooled-arm cells for constant speed (cold too thin for arm-specific fit)
year_cells_pooled <- spine %>%
  filter(!is.na(initial_stage)) %>%
  count(engine, year, initial_stage) %>%
  group_by(engine, year) %>%
  mutate(n_cell = sum(n), pi = n / n_cell) %>%
  ungroup() %>%
  mutate(arm = "pooled")

all_cells <- bind_rows(year_cells, year_cells_pooled)

cell_summary <- all_cells %>%
  group_by(engine, arm, year) %>%
  summarise(n = first(n_cell), mean_stage = sum(pi * initial_stage),
            .groups = "drop")

# below-target gap g for a year cell, target M at interval midpoint (t+1.0)
gap_for <- function(engine, arm_v, yr) {
  cell <- all_cells %>% filter(engine == !!engine, arm == arm_v, year == yr)
  m_top <- MARKET_TOP(engine, yr + 1.0)
  below <- cell %>% filter(initial_stage < m_top)
  sum(below$pi * (m_top - below$initial_stage))
}

pairs <- cell_summary %>%
  filter(n >= YEAR_MIN_N) %>%
  arrange(engine, arm, year) %>%
  group_by(engine, arm) %>%
  mutate(next_year = lead(year), dm = lead(mean_stage) - mean_stage,
         n_next = lead(n)) %>%
  ungroup() %>%
  filter(!is.na(dm), next_year == year + 1) %>%
  rowwise() %>%
  mutate(g = gap_for(engine, arm, year),
         w = 2 / (1 / n + 1 / n_next),
         era = if_else(year + 1.0 >= ERA_SPLIT_FRAC, "era2", "era1")) %>%
  ungroup()

fit_pbar <- function(df) {
  if (nrow(df) == 0 || sum(df$g^2) == 0) {
    return(tibble(p_bar = NA_real_, se = NA_real_, n_pairs = nrow(df)))
  }
  p <- sum(df$w * df$dm * df$g) / sum(df$w * df$g^2)
  df_resid <- nrow(df) - 1
  se <- if (df_resid >= 1) {
    sqrt(sum(df$w * (df$dm - p * df$g)^2) / (df_resid * sum(df$w * df$g^2)))
  } else NA_real_
  tibble(p_bar = p, se = se, n_pairs = nrow(df))
}

pbar <- pairs %>%
  group_by(engine, arm, era) %>%
  group_modify(~ fit_pbar(.x)) %>%
  ungroup()

# projections: initial distribution = pooled 2023-24 per Machine Group x arm
proj_init <- spine %>%
  filter(!is.na(initial_stage), year %in% PROJ_BASE_YEARS) %>%
  count(subgroup, arm, initial_stage) %>%
  group_by(subgroup, arm) %>%
  mutate(n_cell = sum(n), pi = n / n_cell) %>%
  ungroup()

# stage-conditional EF per Machine Group (band mix held at 2023-24 observed)
stage_ef <- spine %>%
  filter(!is.na(ef_nox), year %in% PROJ_BASE_YEARS) %>%
  group_by(subgroup, initial_stage) %>%
  summarise(ef_stage = weighted.mean(ef_nox, kw_effective), .groups = "drop")

project_cell <- function(group, arm_v, p_use, scenario) {
  init <- proj_init %>% filter(subgroup == group, arm == arm_v)
  if (nrow(init) == 0 || is.na(p_use)) return(NULL)
  pi_vec <- setNames(rep(0, 7), 1:7)
  pi_vec[as.character(init$initial_stage)] <- init$pi
  engine <- if (group == "Constant_Speed") "Constant" else "Variable"
  bind_rows(lapply(PROJ_YEARS, function(yr) {
    m_top <- MARKET_TOP(engine, yr + 0.5)
    below <- as.integer(names(pi_vec)) < m_top
    moved <- sum(pi_vec[below]) * p_use
    pi_vec[below]              <<- pi_vec[below] * (1 - p_use)
    pi_vec[as.character(m_top)] <<- pi_vec[as.character(m_top)] + moved
    thr <- PROJ_THRESHOLD(group, yr)
    efs <- stage_ef %>% filter(subgroup == group)
    ef_map <- setNames(rep(NA_real_, 7), 1:7)
    ef_map[as.character(efs$initial_stage)] <- efs$ef_stage
    ef_map[is.na(ef_map)] <- NOX_LIMIT[cbind(names(ef_map)[is.na(ef_map)],
                                             "75-130")]
    tibble(subgroup = group, arm = arm_v, scenario = scenario, year = yr,
           c_bar_proj = sum(pi_vec[as.integer(names(pi_vec)) >= thr]),
           mean_stage_proj = sum(pi_vec * as.integer(names(pi_vec))),
           ef_proj = sum(pi_vec * ef_map))
  }))
}

get_pbar <- function(engine_v, arm_v) {
  row <- pbar %>% filter(engine == engine_v, era == "era2",
                         arm == if (engine_v == "Constant") "pooled" else arm_v)
  list(central = row$p_bar[1], se = row$se[1])
}

projections <- bind_rows(lapply(
  c("Constant_Speed", "CAZ_Plus", "Rest_of_London"), function(group) {
    engine_v <- if (group == "Constant_Speed") "Constant" else "Variable"
    bind_rows(lapply(c("cold_CF", "warm_AT"), function(arm_v) {
      pb <- get_pbar(engine_v, arm_v)
      if (is.na(pb$central)) return(NULL)
      central <- min(max(pb$central, 0), 1)   # a slightly negative fit (flat
                                              # constant-speed trend) projects as 0
      lo <- max(pb$central - 1.96 * coalesce(pb$se, 0), 0)
      hi <- min(pb$central + 1.96 * coalesce(pb$se, 0), 1)
      bind_rows(project_cell(group, arm_v, central, "central"),
                project_cell(group, arm_v, lo, "ci_low"),
                project_cell(group, arm_v, hi, "ci_high"))
    }))
  }))

# observed yearly c-bar and mean stage per Machine Group x arm
observed_trend <- spine %>%
  filter(initial_status %in% c("A", "B", "C")) %>%
  group_by(subgroup, arm, year) %>%
  summarise(n = n(), c_bar_obs = mean(initial_status %in% c("A", "B")),
            mean_stage = mean(initial_stage, na.rm = TRUE), .groups = "drop")

# threshold schedule as data: applicable stage threshold at MID-YEAR (1 July),
# per subgroup, over the observed and projection horizon. Mid-year 2020 falls
# before the 1 Sep boundary, so 2020 carries the A2 threshold; the September
# step is annotated separately in the dashboard.
threshold_at_midyear <- function(group, yr) {
  if (yr >= 2025) return(PROJ_THRESHOLD(group, yr))
  ph <- if (yr <= 2018) "A1" else if (yr <= 2020) "A2" else "B"
  unlist(THRESHOLDS[[group]])[[ph]]
}
threshold_schedule <- expand_grid(
  subgroup = c("Constant_Speed", "CAZ_Plus", "Rest_of_London"),
  year = 2016:2030
) %>%
  rowwise() %>%
  mutate(thr = threshold_at_midyear(subgroup, year)) %>%
  ungroup()

# --- Verification block ---

cat("Verification...\n")

# 1. structural (halt)
stopifnot(!any(is.na(spine$initial_status)), !any(is.na(spine$nc_outcome)))
pi_check <- all_cells %>% group_by(engine, arm, year) %>%
  summarise(s = sum(pi), .groups = "drop")
stopifnot(all(abs(pi_check$s - 1) < 1e-9))
est <- pbar %>% filter(!is.na(p_bar))
stopifnot(all(est$p_bar > -0.05), all(est$p_bar < 1))

# 2. referential (halt): projections conserve probability; c_bar in [0,1]
if (nrow(projections) > 0) {
  stopifnot(all(projections$c_bar_proj >= -1e-9),
            all(projections$c_bar_proj <= 1 + 1e-9))
  stopifnot(all(diff_ok <- projections %>% group_by(subgroup, arm, scenario) %>%
                  summarise(mono = all(diff(mean_stage_proj) >= -1e-9),
                            .groups = "drop") %>% pull(mono)))
}
stopifnot(!any(is.na(outcomes$c_bar)))

# 2b. referential (halt): v2 payload consistency
oc_sum <- outcomes_cells %>%
  summarise(across(starts_with(c("status_", "outcome_")), sum))
op_sum <- outcomes %>%
  summarise(across(starts_with(c("status_", "outcome_")), sum))
stopifnot(all(unlist(oc_sum) == unlist(op_sum[names(oc_sum)])))
stopifnot(all(ef_results$ef_env_low  <= ef_results$ef_central + 1e-9),
          all(ef_results$ef_env_high >= ef_results$ef_central - 1e-9))
stopifnot(all(threshold_schedule$thr %in% 3:6))

# 3. distribution fingerprints (warn)
thin <- cell_summary %>% filter(n < YEAR_MIN_N, arm != "pooled")
if (nrow(thin) > 0) {
  warning(sprintf("%d year-cells below n=%d excluded from trend fitting.",
                  nrow(thin), YEAR_MIN_N))
}
if (any(is.na(pbar$se))) {
  warning("Some p-bar fits have too few pairs for a standard error ",
          "(constant-speed era 1); treat those as point indications only.")
}

# 4. domain (warn): era-2 slopes similar across arms; CS p-bar near zero
pv <- pbar %>% filter(engine == "Variable", era == "era2", arm != "pooled")
if (nrow(pv) == 2 && all(!is.na(pv$se))) {
  z <- abs(diff(pv$p_bar)) / sqrt(sum(pv$se^2))
  cat(sprintf("  era-2 warm vs cold p-bar difference: z = %.2f %s\n", z,
              if (z > 2) "(WARN: arms differ)" else "(arms statistically similar)"))
}
cs2 <- pbar %>% filter(engine == "Constant", era == "era2", arm == "pooled")
cat(sprintf("  constant-speed era-2 p-bar (pooled arms): %.3f (se %s)\n",
            cs2$p_bar[1], formatC(cs2$se[1], format = "f", digits = 3)))

cat("\nFitted p-bar (annual replacement probability):\n")
print(as.data.frame(pbar %>% mutate(across(where(is.numeric), ~ round(.x, 4)))))

# --- Write markdown output ---

fmt <- function(x, d = 3) formatC(round(x, d), format = "f", digits = d)

md <- c(
  "# nrmm_model_v2 — unified model: outcomes, EF, dynamics (260717)",
  "",
  "One classified spine; three layers. Arms: warm_AT (treatment), cold_CF",
  "(counterfactual). Eras split at 1 Sep 2020. Constrained Markov: replacement",
  "to market-top stage M(t) with annual probability p-bar; estimated from",
  "adjacent-year mean-stage increments, E[dm] = p x g(t), through-origin WLS.",
  "",
  "## 1. Fitted p-bar per engine x arm x era",
  "",
  kable(pbar %>% mutate(across(where(is.numeric), ~ round(.x, 4))),
        format = "pipe"),
  "",
  "## 2. Projections 2025-2030 (era-2 p-bar; thresholds at exact dates)",
  "",
  "c_bar_proj is the projected stage-compliant share against the schedule",
  "(2025-29: CS V, CAZ+ V, RoL IV; from 2030 all V). Scenarios are the p-bar",
  "95% CI. Constant-speed uses the pooled-arm p-bar for both arms.",
  "",
  kable(projections %>%
          filter(year %in% c(2025, 2027, 2030)) %>%
          mutate(across(where(is.numeric) & !year, ~ round(.x, 3))) %>%
          arrange(subgroup, arm, scenario, year),
        format = "pipe"),
  "",
  "## 3. Observed yearly c-bar by Machine Group and arm (model target)",
  "",
  kable(observed_trend %>% filter(n >= YEAR_MIN_N) %>%
          mutate(c_bar_obs = round(c_bar_obs, 3)) %>%
          pivot_wider(id_cols = c(subgroup, year), names_from = arm,
                      values_from = c(n, c_bar_obs)) %>%
          arrange(subgroup, year),
        format = "pipe"),
  "",
  "## 4. Fleet EF by Machine Group and phase (Layer 2, central usage indices)",
  "",
  kable(ef_results %>% mutate(across(where(is.numeric), ~ round(.x, 2))),
        format = "pipe"),
  "",
  "## 5. Assumptions and placeholders",
  "",
  "- Stage NOx limits and usage indices: general-knowledge placeholders.",
  "- N_t: audit counts pending NRMM registration database.",
  "- Projections start from pooled 2023-24 distributions; phase C is",
  "  projection, not estimation (n = 63).",
  "- Constant-speed p-bar pooled across arms (cold too thin annually).",
  "- EF projection holds each stage's 2023-24 power-band mix fixed.",
  "- No bootstrap in v1; p-bar CIs are WLS standard errors, unclustered.",
  ""
)
writeLines(md, output_md)
cat("Markdown written:", output_md, "\n")

# --- Save model object and manifest ---

nrmm_model_v2 <- list(
  schema_version = 2L,
  outcomes = outcomes, outcomes_cells = outcomes_cells,
  ef_results = ef_results, strata = strata, usage_index = USAGE_INDEX,
  cell_summary = cell_summary, pairs = pairs, pbar = pbar,
  projections = projections, observed_trend = observed_trend,
  threshold_schedule = threshold_schedule,
  proj_init = proj_init, stage_ef = stage_ef, nox_limit = NOX_LIMIT
)
saveRDS(nrmm_model_v2, "intermediate_data/nrmm_model_v2.rds")

manifest_path <- "intermediate_data/manifest.md"
manifest_row <- paste0(
  "| Model | nrmm_model_v2 | nrmm_model_v2.rds | list | ",
  nrow(outcomes_cells), " year-cells; ", nrow(pbar), " p-bar fits; ",
  nrow(projections), " projection rows | ",
  "Unified NRMM model v2: v1 plus dashboard payloads (year-keyed outcome ",
  "cells, All_NRMM EF strata with adversarial envelopes, threshold schedule ",
  "as data, schema_version stamp). |"
)
if (file.exists(manifest_path)) {
  cat(manifest_row, "\n", file = manifest_path, append = TRUE)
} else {
  writeLines(c("| step | object | file | class | dimensions | description |",
               "|---|---|---|---|---|---|", manifest_row), manifest_path)
}

cat("Completion summary: nrmm_model_v2 (list), ", length(nrmm_model_v2),
    " elements; spine ", nrow(spine), " records\n", sep = "")
