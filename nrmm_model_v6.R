#!/usr/bin/env Rscript

# nrmm_model_v6 — unified NRMM model: one classified data spine, three layers.
#
# THIS IS THE AUTHORITATIVE MODEL SCRIPT. Every figure in
# 260719_nrmm_report.md traces to an object saved here; see the cross-
# reference table in that report (section 12) and in notes.md.
#
# ***** PROVISIONAL: CLASSIFICATION QUERY OPEN *****
# The Constant Speed group is defined by `Engine Type`, and every Stage V
# generator in the data is recorded "Variable". Generators therefore leave
# the group exactly when they improve, which drives that group's results to
# a structural zero. The classification intent is with the audit team
# (260726_audit_data_queries.md). Until it is answered, GENERATOR_MODE below
# stays at "as_recorded" and `classification_sensitivity` reports what
# changes under the alternative. Do not cite Constant Speed results.
#
# v5 changes (unblocked fixes from 260726_code_fix_checklist.md):
#   B2  stage strings normalised before mapping, so case typos ("iIIB",
#       "iV") resolve instead of silently becoming NA
#   B4  stage_inconsistency: machines recorded at different stages across
#       visits, with the size of each discrepancy
#   C2  site-level markers (Baselining, Site Complete, No Apparent Works,
#       DECLINED AUDIT) logged into machine compliance fields now take
#       status "X": the stage is kept, the compliance outcome is voided,
#       because no determination was made on that visit
#   C4  removal_fate_by_year: displacement by year of removal with the
#       observation window, since TAN capture begins in 2021 and recent
#       removals are right-censored
#   D1  TYPE_CANONICAL extended ("Mewp", "Drilling rig")
#   D2  machine type normalised once at ingestion, case- and
#       whitespace-insensitive thereafter
#   A3  GENERATOR_MODE exposed as an explicit switch with a sensitivity
#       table, restoring what tree_dashboard_v3-v5 had before unification
#   E1  structural implausibility checks (zero-compliance groups, zero
#       fitted rates, categories empty above a stage)
#   E2  unmapped_values: every distinct categorical input value is either
#       mapped or explicitly excluded with a count
#   E3  population stability check: cohorts that shrink as the fleet
#       improves are the signature shared by the generator and Electric
#       problems
#   schema_version = 5
#
# v6 change (query answered 28 July 2026):
#   B1  "Electric" in the stage field is confirmed by the project lead to mean
#       zero emission, so it now maps to stage 7 alongside "ZE" rather than
#       being dropped. These are the cleanest machines on site and they are
#       growing year on year, so dropping them was biasing the fleet
#       distribution downward in exactly the years it is improving fastest.
#   schema_version = 6
#
# v4 changes (review-readiness pass): three quantities that the report cited
# but no committed script computed are now derived here, so every reported
# number has a code path:
#   - arrival_ef: mean arrival emissions intensity per Machine Group x phase
#     x arm, with and without machines holding pre-existing dispensations.
#     This is the report's headline finding (registered fleets arrive cleaner)
#     and was previously computed only in an exploratory script.
#   - removal_fate: the removal-displacement rate under BOTH definitions
#     (record-level with a record-relative date, which the taxonomy uses and
#     which is authoritative; and distinct-machine with an any-removal-event
#     rule, which earlier drafts quoted). They answer different questions and
#     differ materially, so both are computed and labelled rather than one
#     being quietly dropped.
#   - enforcement_nox: the enforcement channel expressed as a share of
#     audited-fleet NOx, replacing figures that survived only in the
#     superseded tree_dashboard_v3-v5 scripts.
#   - schema_version = 4.
#
# v3 changes:
#   - Usage expressed in HOURS/DAY per machine type with a fixed load factor,
#     u_t = hours_day_t x load_factor_t (normalised to excavator); the 24 h/day
#     physical cap tightens the Generator and Pump upper bounds relative to the
#     old abstract index (u_high 5.0 -> 3.75), narrowing the EF envelope.
#   - stage_populations: observed stage counts per subgroup x arm x year
#     (shares are counts within cell; absolute machine populations require the
#     registration database multiplier).
#   - projections now carry the full projected stage vector pi_1..pi_7 per
#     year and scenario, not only its functionals (c-bar, mean stage, EF).
#   - schema_version = 3.
#
# v2 added the dashboard payloads (consumed by the dashboard scripts):
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
#            (normalised), where u_t = hours/day x load factor per type,
#            normalised to the excavator (placeholder values, see USAGE_TABLE).
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
# No stochastic code (closed-form WLS; no bootstrap in any version to
# date), so no set.seed() call is required.

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

# Stage assumed for a replacement machine when the audit records no final
# stage: operators buy current-generation equipment (schema, objective 4), so
# a replacement is credited at the market top rather than an intermediate.
REPLACEMENT_STAGE_ASSUMED <- 6L

NAMED_TYPES <- c("Excavator", "Generator", "Telehandler", "Dumper",
                 "Piling Rig", "Pump", "Mobile Crane", "Crusher",
                 "Crawler Crane", "Roller", "MEWP", "Compressor")
# D1/D2: machine type is free text. Normalise case and whitespace once, then
# map known variants onto a canonical label. Keys are lower case.
TYPE_CANONICAL <- c(
  "piling rig"    = "Piling Rig",
  "mewp"          = "MEWP",
  "drilling rig"  = "Drilling Rig"
)

# A3: how generators are assigned to a Machine Group. "as_recorded" trusts the
# Engine Type field; "generators_constant" assigns anything whose machine type
# names a generator to Constant Speed. The classification query is open, so the
# default trusts the data and the alternative is reported as a sensitivity.
GENERATOR_MODE <- "as_recorded"     # or "generators_constant"

# C2: site-level audit states that appear in machine-level compliance fields.
# These visits made no compliance determination about the machine.
SITE_LEVEL_STATES <- c("baselining", "site complete", "no apparent works",
                       "declined audit")

# Machine types that are not machines in scope.
OUT_OF_SCOPE_TYPES <- c("no nrmm")

# PLACEHOLDER usage: HOURS/DAY per type (central and bounds, capped at 24)
# with a fixed load factor; u_t = hours_day_t x load_factor_t normalised to
# the excavator central (8 h/day x 0.40). Values are general-knowledge
# placeholders pending sourced estimates (Generator and Excavator first).
USAGE_TABLE <- tribble(
  ~machine_type,   ~load_factor, ~hours_day_central, ~hours_day_low, ~hours_day_high,
  "Excavator",     0.40,  8.0,  5.6, 10.4,
  "Generator",     0.50, 19.2,  9.6, 24.0,
  "Telehandler",   0.40,  6.4,  4.0,  9.6,
  "Dumper",        0.40,  5.6,  3.2,  8.8,
  "Piling Rig",    0.40,  6.4,  4.0,  9.6,
  "Pump",          0.50, 16.0,  6.4, 24.0,
  "Mobile Crane",  0.40,  4.0,  2.4,  7.2,
  "Crusher",       0.60,  6.4,  3.7,  9.6,
  "Crawler Crane", 0.40,  4.8,  3.2,  8.0,
  "Roller",        0.40,  4.8,  2.4,  8.0,
  "MEWP",          0.40,  4.0,  2.4,  6.4,
  "Compressor",    0.50,  9.6,  5.1, 16.0,
  "Other",         0.40,  6.4,  3.2,  9.6
)
EXCAVATOR_ENERGY_DAY <- 8.0 * 0.40   # normalisation base (kWh/kW per day)
USAGE_INDEX <- USAGE_TABLE %>%
  mutate(
    u_central = hours_day_central * load_factor / EXCAVATOR_ENERGY_DAY,
    u_low     = hours_day_low     * load_factor / EXCAVATOR_ENERGY_DAY,
    u_high    = hours_day_high    * load_factor / EXCAVATOR_ENERGY_DAY
  )

NON_DISPENSATION_VALUES <- c("", "none", "rejected", "pending", "non",
                             "no nrmm", "unidentified")
UNUSABLE_TAN_VALUES <- c("", "unidentified", "none", "n/a", "na")

STATUS_KEYS  <- c("A", "B", "C", "D", "E", "X")
OUTCOME_KEYS <- letters[1:9]

YEAR_MIN_N    <- 20      # minimum year-cell n for trend estimation
PROJ_YEARS    <- 2025:2030
PROJ_BASE_YEARS <- c(2023, 2024)   # pooled initial distribution

output_md <- "outputs/nrmm_model_v6.md"

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

# B2: normalise case and whitespace before matching, so "iIIB" and "iV"
# resolve rather than silently becoming NA. Values that remain unmatched are
# counted and reported by the E2 check rather than dropped in silence.
stage_to_int <- function(x) {
  k <- toupper(trimws(ifelse(is.na(x), "", as.character(x))))
  case_when(
    k %in% c("I", "1") ~ 1L, k %in% c("II", "2") ~ 2L,
    k %in% c("IIIA", "3") ~ 3L, k %in% c("IIIB", "4") ~ 4L,
    k %in% c("IV", "5") ~ 5L, k %in% c("V", "6") ~ 6L,
    # "Electric" confirmed by the project lead (28 Jul 2026) to mean zero
    # emission, so it joins "ZE" at stage 7 rather than being dropped.
    k %in% c("ZE", "ELECTRIC") ~ 7L, TRUE ~ NA_integer_
  )
}

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
    # D2: normalise machine type once, then map known variants (D1)
    machine_type_key = tolower(trimws(ifelse(is.na(`Machine Type`), "",
                                             as.character(`Machine Type`)))),
    machine_type_clean = coalesce(TYPE_CANONICAL[machine_type_key],
                                  trimws(as.character(`Machine Type`))),
    is_generator = grepl("generator", machine_type_key, fixed = TRUE),
    # A3: engine type used for grouping, under the selected classification mode
    engine_effective = if (GENERATOR_MODE == "generators_constant") {
      if_else(is_generator, "Constant", `Engine Type`)
    } else {
      `Engine Type`
    },
    subgroup = case_when(
      engine_effective == "Constant"                              ~ "Constant_Speed",
      engine_effective == "Variable" & Zone %in% c("CAZ", "OA") ~ "CAZ_Plus",
      engine_effective == "Variable" & Zone == "GL"              ~ "Rest_of_London",
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
    # C2: a site-level state logged in a machine compliance field means the
    # visit made no determination about this machine. Keep its stage (fleet
    # composition is real data) but void the compliance outcome.
    no_determination = tolower(trimws(ifelse(is.na(`Initial Machinery Compliance`), "",
                                   as.character(`Initial Machinery Compliance`))))
                       %in% SITE_LEVEL_STATES,
    initial_status = case_when(
      no_determination      ~ "X",
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
    machine_type = if_else(machine_type_clean %in% NAMED_TYPES,
                           machine_type_clean, "Other")
  ) %>%
  filter(!is.na(subgroup), !machine_type_key %in% OUT_OF_SCOPE_TYPES)

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

# --- Layer 1c: observed stage populations per subgroup x arm x year ---
# Counts within cell; shares derive client-side. Absolute machine populations
# require the registration database multiplier (audits give shares only).

stage_populations <- spine %>%
  filter(!is.na(initial_stage)) %>%
  count(subgroup, arm, year, stage = initial_stage, name = "n")

# --- Layer 1d: removal fate under both definitions (reconciliation) ---
#
# "How often does a removed machine reappear elsewhere?" has two defensible
# answers, and earlier drafts of the report quoted one while the taxonomy used
# the other. Both are computed here so the difference is explicit.
#
#   record_level (AUTHORITATIVE, used by nc_outcome d/e/f): one row per audit
#     record of an emissions-non-compliant machine removed from site; the
#     machine counts as displaced if its serial number is seen at any STRICTLY
#     LATER date. Matches the rest of the taxonomy, which is record-level.
#   machine_level: one row per distinct serial number that was ever removed;
#     displaced if seen after its FIRST removal. Answers "what share of
#     machines get relocated", not "what share of removal events".
#
# They differ because machines removed repeatedly contribute several records,
# and repeat offenders are more likely to be seen again.

removal_records <- spine %>%
  filter(initial_status == "C", nc_outcome %in% c("d", "e", "f"))

removal_machines <- spine %>%
  filter(removed_plain, tan_usable) %>%
  group_by(TAN) %>%
  summarise(first_removed = min(audit_date), .groups = "drop") %>%
  left_join(
    spine %>% filter(tan_usable) %>% select(TAN, audit_date),
    by = "TAN", relationship = "one-to-many"
  ) %>%
  group_by(TAN, first_removed) %>%
  summarise(seen_after = any(audit_date > first_removed), .groups = "drop")

removal_fate <- tibble(
  definition = c("record_level (authoritative)", "machine_level"),
  traceable  = c(sum(removal_records$nc_outcome %in% c("d", "e")),
                 nrow(removal_machines)),
  displaced  = c(sum(removal_records$nc_outcome == "d"),
                 sum(removal_machines$seen_after)),
  untraceable = c(sum(removal_records$nc_outcome == "f"), NA_integer_)
) %>%
  mutate(displaced_pct = round(100 * displaced / traceable, 1))

# --- Layer 1e: enforcement channel in NOx terms ---
#
# Shares of audited-fleet NOx, so the enforcement channel can be compared with
# the arrival channel on one scale. Conventions, each chosen to avoid
# overstating the result:
#   - a (replaced on the spot): credited initial EF minus the replacement EF;
#     where the final stage is blank the replacement is assumed to be at the
#     market top (schema: operators buy current-generation equipment).
#   - b (stage upgraded): credited the observed initial-to-final EF difference.
#   - c (retrofitted): credited ZERO NOx. Retrofit here is overwhelmingly DPF,
#     which abates particulates, not NOx. Crediting it as a stage change would
#     be the single largest overstatement available in this data.
#   - e (removed, never seen again): full initial EF, i.e. treated as gone.
#   - d, f (reappears elsewhere / untraceable): full initial EF reported
#     separately as "at stake", NOT as a reduction.

nox_of <- function(records, mode) {
  records <- filter(records, !is.na(initial_stage), !is.na(ef_nox))
  if (nrow(records) == 0) return(0)
  final_ef <- NOX_LIMIT[cbind(
    as.character(pmin(coalesce(records$final_stage, REPLACEMENT_STAGE_ASSUMED), 7L)),
    as.character(records$band))]
  switch(mode,
    gone    = sum(records$ef_nox),
    upgrade = sum(pmax(records$ef_nox - final_ef, 0)),
    zero    = 0)
}

stage_known <- filter(spine, !is.na(ef_nox))
total_fleet_nox <- sum(stage_known$ef_nox)
nc <- filter(spine, initial_status == "C")

enforcement_nox <- tibble(
  channel = c("confirmed reduction (a+b, retrofit c credited zero)",
              "probable exit (e)",
              "removal fate unknown (d+f), at stake"),
  n = c(sum(nc$nc_outcome %in% c("a", "b", "c")),
        sum(nc$nc_outcome == "e"),
        sum(nc$nc_outcome %in% c("d", "f"))),
  nox_saved = c(
    nox_of(filter(nc, nc_outcome %in% c("a", "b")), "upgrade") +
      nox_of(filter(nc, nc_outcome == "c"), "zero"),
    nox_of(filter(nc, nc_outcome == "e"), "gone"),
    nox_of(filter(nc, nc_outcome %in% c("d", "f")), "gone"))
) %>%
  mutate(pct_of_fleet_nox = round(100 * nox_saved / total_fleet_nox, 2))


# --- Layer 1f: data-quality diagnostics (B4, C4, E2) ---

# B4: the same machine recorded at different stages on different visits. A
# machine may legitimately improve, so a spread of one stage is unremarkable;
# a spread of three or four is a recording error rather than an upgrade.
stage_inconsistency <- spine %>%
  filter(tan_usable, !is.na(initial_stage)) %>%
  group_by(TAN) %>%
  summarise(visits = n(), distinct_stages = n_distinct(initial_stage),
            stage_min = min(initial_stage), stage_max = max(initial_stage),
            .groups = "drop") %>%
  filter(visits > 1) %>%
  mutate(spread = stage_max - stage_min)

stage_inconsistency_summary <- stage_inconsistency %>%
  count(spread, name = "machines") %>%
  mutate(share_of_repeat_audited = round(machines / nrow(stage_inconsistency), 3))

# C4: TAN capture begins in 2021, so no removal before then can be traced, and
# a machine removed recently has had little opportunity to be seen again. Both
# effects push the measured displacement rate down, making it a lower bound.
removal_fate_by_year <- spine %>%
  filter(initial_status == "C", nc_outcome %in% c("d", "e", "f")) %>%
  group_by(year) %>%
  summarise(
    removals = n(),
    traceable = sum(nc_outcome %in% c("d", "e")),
    displaced = sum(nc_outcome == "d"),
    .groups = "drop"
  ) %>%
  mutate(
    displaced_pct = if_else(traceable > 0, round(100 * displaced / traceable, 1),
                            NA_real_),
    observation_window_yrs = round(as.numeric(max(spine$audit_date, na.rm = TRUE) -
                                     as.Date(paste0(year, "-07-01"))) / 365.25, 1)
  )

# E2: every distinct value of a categorical input must be either mapped or
# explicitly accounted for. Anything appearing here is silently lost unless
# it is listed as a deliberate exclusion.
tabulate_unmapped <- function(values, mapped_test, field) {
  tibble(field = field, value = as.character(values)) %>%
    filter(!mapped_test) %>%
    count(field, value, name = "n") %>%
    arrange(desc(n))
}
unmapped_values <- bind_rows(
  tabulate_unmapped(spine$`Initial Emissions Stage`,
                    !is.na(spine$initial_stage), "Initial Emissions Stage"),
  tabulate_unmapped(spine$`Final Emissions Stage`,
                    !is.na(spine$final_stage), "Final Emissions Stage"),
  tabulate_unmapped(spine$`Engine Type`,
                    spine$`Engine Type` %in% c("Constant", "Variable"), "Engine Type")
)

# --- Layer 1g: classification sensitivity (A3) ---
#
# What changes if generators are assigned to Constant Speed by machine type
# rather than by the recorded Engine Type. Deliberately a parallel, minimal
# re-derivation: it re-computes only group, stage, phase and threshold, so the
# comparison cannot drift from the main pipeline without this block failing.

sensitivity_frame <- function(generators_constant) {
  spine %>%
    mutate(
      eng = if (generators_constant) if_else(is_generator, "Constant", `Engine Type`)
            else `Engine Type`,
      sg = case_when(
        eng == "Constant"                              ~ "Constant_Speed",
        eng == "Variable" & Zone %in% c("CAZ", "OA") ~ "CAZ_Plus",
        eng == "Variable" & Zone == "GL"              ~ "Rest_of_London",
        TRUE ~ NA_character_),
      thr = case_when(
        sg == "Constant_Speed" ~ unlist(THRESHOLDS$Constant_Speed)[phase],
        sg == "CAZ_Plus"       ~ unlist(THRESHOLDS$CAZ_Plus)[phase],
        sg == "Rest_of_London" ~ unlist(THRESHOLDS$Rest_of_London)[phase],
        TRUE ~ NA_integer_)
    ) %>%
    filter(!is.na(sg), !is.na(initial_stage), initial_status != "X")
}

classification_sensitivity <- bind_rows(lapply(
  c(as_recorded = FALSE, generators_constant = TRUE), function(gc) {
    sensitivity_frame(gc) %>%
      group_by(subgroup = sg, phase) %>%
      summarise(n = n(), mean_stage = round(mean(initial_stage), 2),
                compliance_pct = round(100 * mean(initial_stage >= thr), 1),
                .groups = "drop") %>%
      mutate(mode = if (gc) "generators_constant" else "as_recorded")
  })) %>%
  select(mode, subgroup, phase, n, mean_stage, compliance_pct) %>%
  arrange(subgroup, phase, mode)

# Constant Speed mean stage by year under both modes: the clearest view of the
# artefact, since under "as_recorded" the series cannot rise.
classification_sensitivity_trend <- bind_rows(lapply(
  c(as_recorded = FALSE, generators_constant = TRUE), function(gc) {
    sensitivity_frame(gc) %>%
      filter(sg == "Constant_Speed") %>%
      group_by(year) %>%
      summarise(n = n(), mean_stage = round(mean(initial_stage), 2),
                pct_stage_v_plus = round(100 * mean(initial_stage >= 6), 1),
                .groups = "drop") %>%
      mutate(mode = if (gc) "generators_constant" else "as_recorded")
  })) %>%
  select(mode, year, n, mean_stage, pct_stage_v_plus) %>%
  arrange(year, mode)

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

# Adversarial usage envelope: the widest EF_fleet can move with each u_t at
# one of its box bounds. Solved by fixed-point iteration because the optimal
# assignment depends on the resulting mean (types above it go high, below go
# low). Method first developed in the superseded 260717_ef_fleet_v2.R.
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

# --- Layer 2b: arrival emissions intensity by arm (the report's headline) ---
#
# The proactive channel: how clean each arm's machines are when FIRST SEEN,
# before any enforcement action. Unweighted mean over machines of the stage-
# limit EF at the machine's power band, so it answers "how dirty is the
# average machine arriving on site", not "how much pollution does the fleet
# emit" (that is EF_fleet in ef_results, which weights by size and usage).
#
# Two variants, because dispensation holders are legally compliant but not
# necessarily clean:
#   all_machines            - every stage-resolvable record
#   excl_dispensation       - drops machines that already held a retrofit or
#                             exemption, isolating the stage distribution
#
# gap_pct is the percentage by which the warm (registered) arm's mean arrival
# EF sits BELOW the cold (counterfactual) arm's: positive means registered
# fleets arrive cleaner.

arrival_ef_cells <- function(records, group_label, phase_label) {
  by_arm <- function(subset_records, variant) {
    subset_records %>%
      group_by(arm) %>%
      summarise(n = n(), mean_ef = mean(ef_nox), .groups = "drop") %>%
      mutate(subgroup = group_label, phase = phase_label, variant = variant)
  }
  bind_rows(
    by_arm(records, "all_machines"),
    by_arm(filter(records, !dispensation_at_start), "excl_dispensation")
  )
}

arrival_ef_long <- bind_rows(
  # per Machine Group x phase
  stage_known %>% group_by(subgroup, phase) %>% group_split() %>%
    lapply(function(r) arrival_ef_cells(r, r$subgroup[1], r$phase[1])) %>% bind_rows(),
  # per Machine Group, all phases pooled
  stage_known %>% group_by(subgroup) %>% group_split() %>%
    lapply(function(r) arrival_ef_cells(r, r$subgroup[1], "All")) %>% bind_rows(),
  # whole fleet by phase, and whole fleet pooled
  stage_known %>% group_by(phase) %>% group_split() %>%
    lapply(function(r) arrival_ef_cells(r, "All_NRMM", r$phase[1])) %>% bind_rows(),
  arrival_ef_cells(stage_known, "All_NRMM", "All")
)

arrival_ef <- arrival_ef_long %>%
  pivot_wider(id_cols = c(subgroup, phase, variant), names_from = arm,
              values_from = c(n, mean_ef)) %>%
  rename(n_warm = n_warm_AT, n_cold = n_cold_CF,
         ef_warm = mean_ef_warm_AT, ef_cold = mean_ef_cold_CF) %>%
  mutate(gap_pct = round(100 * (1 - ef_warm / ef_cold), 1)) %>%
  arrange(subgroup, phase, variant)

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
    bind_cols(
      tibble(subgroup = group, arm = arm_v, scenario = scenario, year = yr,
             c_bar_proj = sum(pi_vec[as.integer(names(pi_vec)) >= thr]),
             mean_stage_proj = sum(pi_vec * as.integer(names(pi_vec))),
             ef_proj = sum(pi_vec * ef_map)),
      as_tibble(as.list(setNames(unname(pi_vec), paste0("pi_", 1:7))))
    )
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

# 2b-v3. referential (halt): stage populations and projected vectors
stopifnot(sum(stage_populations$n) == sum(!is.na(spine$initial_stage)))
if (nrow(projections) > 0) {
  pi_sums <- rowSums(projections[paste0("pi_", 1:7)])
  stopifnot(all(abs(pi_sums - 1) < 1e-9))
}
stopifnot(all(USAGE_TABLE$hours_day_high <= 24),
          all(USAGE_TABLE$hours_day_low > 0))

# 2b-v5. referential (halt): C2 status X voids the outcome but keeps the stage
stopifnot(all(spine$nc_outcome[spine$initial_status == "X"] %in% OUTCOME_KEYS))
stopifnot(!any(outcomes$status_X > 0 & rowSums(outcomes[paste0("outcome_", OUTCOME_KEYS)]) >
                 outcomes$status_C))
# status X must never enter a compliance rate
stopifnot(all(abs(outcomes$c_bar - (outcomes$status_A + outcomes$status_B) /
                    pmax(outcomes$status_A + outcomes$status_B + outcomes$status_C, 1)) < 1e-12))
stopifnot(nrow(removal_fate_by_year) > 0, nrow(stage_inconsistency) > 0)
stopifnot(all(c("as_recorded", "generators_constant") %in% classification_sensitivity$mode))

# 2b-v4. referential (halt): new v4 objects are internally consistent
stopifnot(nrow(arrival_ef) > 0, !any(is.na(arrival_ef$ef_warm)),
          !any(is.na(arrival_ef$ef_cold)))
# arrival EF must lie within the stage-limit range actually present
stopifnot(all(arrival_ef$ef_warm >= min(NOX_LIMIT)),
          all(arrival_ef$ef_warm <= max(NOX_LIMIT)))
# the enforcement channel cannot exceed the fleet total, nor be negative
stopifnot(all(enforcement_nox$nox_saved >= 0),
          sum(enforcement_nox$nox_saved) <= total_fleet_nox + 1e-9)
# the two removal-fate definitions must both be well formed
stopifnot(all(removal_fate$displaced <= removal_fate$traceable))
# record-level traceable + untraceable must equal the d+e+f outcome total
stopifnot(removal_fate$traceable[1] + removal_fate$untraceable[1] ==
            sum(spine$initial_status == "C" &
                spine$nc_outcome %in% c("d", "e", "f")))

# 2c. referential (halt): dashboard payload consistency
oc_sum <- outcomes_cells %>%
  summarise(across(starts_with(c("status_", "outcome_")), sum))
op_sum <- outcomes %>%
  summarise(across(starts_with(c("status_", "outcome_")), sum))
stopifnot(all(unlist(oc_sum) == unlist(op_sum[names(oc_sum)])))
stopifnot(all(ef_results$ef_env_low  <= ef_results$ef_central + 1e-9),
          all(ef_results$ef_env_high >= ef_results$ef_central - 1e-9))
stopifnot(all(threshold_schedule$thr %in% 3:6))

# E1: structural implausibility. These are not internal-consistency failures,
# so nothing above would catch them; they are the signature of a definition
# rather than the world doing the work. Recorded in the object AND warned, so
# a reader of the results cannot miss them.
structural_flags <- bind_rows(
  # a group with no compliant machines at all in a phase
  outcomes %>%
    group_by(subgroup, phase) %>%
    summarise(compliant = sum(status_A) + sum(status_B),
              resolvable = sum(status_A) + sum(status_B) + sum(status_C),
              .groups = "drop") %>%
    filter(resolvable >= 30, compliant == 0) %>%
    transmute(check = "zero-compliance group",
              detail = paste0(subgroup, " phase ", phase, ": 0 of ", resolvable,
                              " resolvable machines compliant")),
  # a fitted replacement rate indistinguishable from exactly zero
  pbar %>%
    filter(!is.na(p_bar), era == "era2", abs(p_bar) < 0.01) %>%
    transmute(check = "near-zero fitted replacement rate",
              detail = paste0(engine, " / ", arm, " era2: p-bar = ",
                              formatC(p_bar, format = "f", digits = 4))),
  # a group with no machines above a given stage across the whole record
  spine %>%
    filter(!is.na(initial_stage)) %>%
    group_by(subgroup) %>%
    summarise(n = n(), max_stage = max(initial_stage), .groups = "drop") %>%
    filter(n >= 100, max_stage < 6) %>%
    transmute(check = "group empty above stage",
              detail = paste0(subgroup, ": ", n, " machines, none above stage ",
                              max_stage))
)

# E3: population stability. A cohort that shrinks while the fleet improves is
# the signature shared by the generator and "Electric" problems: machines are
# leaving the measured population by getting cleaner.
population_stability <- spine %>%
  filter(!is.na(initial_stage), year >= 2019) %>%
  count(subgroup, year) %>%
  group_by(subgroup) %>%
  summarise(first_n = first(n[order(year)]), last_n = last(n[order(year)]),
            change_pct = round(100 * (last(n[order(year)]) /
                                      first(n[order(year)]) - 1)), .groups = "drop") %>%
  mutate(flag = change_pct <= -40)

if (nrow(structural_flags) > 0) {
  warning("STRUCTURAL IMPLAUSIBILITY (see structural_flags):\n  ",
          paste(structural_flags$check, "-", structural_flags$detail,
                collapse = "\n  "))
}
if (any(population_stability$flag)) {
  warning("Population(s) shrinking sharply since 2019, check whether machines ",
          "are leaving the group by improving: ",
          paste(population_stability$subgroup[population_stability$flag],
                collapse = ", "))
}
if (nrow(unmapped_values) > 0) {
  warning(nrow(unmapped_values), " unmapped categorical values are being ",
          "dropped (see unmapped_values); top: ",
          paste(utils::head(paste0(unmapped_values$field, "='",
                                   unmapped_values$value, "' n=",
                                   unmapped_values$n), 4), collapse = "; "))
}

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
  "# nrmm_model_v6 — unified model: outcomes, EF, dynamics (260717)",
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
  "## 3a. Arrival emissions intensity by arm (proactive channel)",
  "",
  "Mean stage-limit NOx (g/kWh) of machines at first sight, per arm.",
  "gap_pct is how far below the counterfactual the registered arm sits.",
  "",
  kable(arrival_ef %>%
          filter(subgroup == "All_NRMM" | phase == "All") %>%
          mutate(across(where(is.numeric), ~ round(.x, 2))),
        format = "pipe"),
  "",
  "## 3b. Removal fate under both definitions",
  "",
  "Record-level is authoritative (matches the outcome taxonomy); the",
  "machine-level figure answers a different question and is reported so the",
  "two are never confused.",
  "",
  kable(removal_fate, format = "pipe"),
  "",
  "## 3c. Enforcement channel in NOx terms",
  "",
  paste0("Shares of audited-fleet NOx (total ",
         formatC(round(total_fleet_nox), format = "d", big.mark = ","),
         " g/kWh-machines). Retrofits are credited zero NOx (DPFs abate PM)."),
  "",
  kable(enforcement_nox, format = "pipe"),
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
  "- No bootstrap; p-bar CIs are WLS standard errors, unclustered.",
  ""
)
writeLines(md, output_md)
cat("Markdown written:", output_md, "\n")

# --- Save model object and manifest ---

nrmm_model_v6 <- list(
  schema_version = 6L,
  generator_mode = GENERATOR_MODE,
  provisional = TRUE,
  provisional_note = paste(
    "Constant Speed results are provisional: every Stage V generator is",
    "recorded Engine Type 'Variable', so generators leave the group when they",
    "improve. Classification query is with the audit team. See",
    "classification_sensitivity for what changes under the alternative."),
  stage_inconsistency = stage_inconsistency,
  stage_inconsistency_summary = stage_inconsistency_summary,
  removal_fate_by_year = removal_fate_by_year,
  unmapped_values = unmapped_values,
  classification_sensitivity = classification_sensitivity,
  classification_sensitivity_trend = classification_sensitivity_trend,
  structural_flags = structural_flags,
  population_stability = population_stability,
  outcomes = outcomes, outcomes_cells = outcomes_cells,
  stage_populations = stage_populations,
  arrival_ef = arrival_ef, removal_fate = removal_fate,
  enforcement_nox = enforcement_nox, total_fleet_nox = total_fleet_nox,
  ef_results = ef_results, strata = strata,
  usage_index = USAGE_INDEX, usage_table = USAGE_TABLE,
  excavator_energy_day = EXCAVATOR_ENERGY_DAY,
  cell_summary = cell_summary, pairs = pairs, pbar = pbar,
  projections = projections, observed_trend = observed_trend,
  threshold_schedule = threshold_schedule,
  proj_init = proj_init, stage_ef = stage_ef, nox_limit = NOX_LIMIT
)
saveRDS(nrmm_model_v6, "intermediate_data/nrmm_model_v6.rds")

manifest_path <- "intermediate_data/manifest.md"
manifest_row <- paste0(
  "| Model | nrmm_model_v6 | nrmm_model_v6.rds | list | ",
  nrow(outcomes_cells), " year-cells; ", nrow(arrival_ef), " arrival-EF cells; ",
  nrow(projections), " projection rows | ",
  "Authoritative NRMM model: v3 plus arrival emissions intensity by arm, ",
  "removal fate under both definitions, and the enforcement channel in NOx ",
  "terms; every reported figure traces to this object. |"
)
if (file.exists(manifest_path)) {
  cat(manifest_row, "\n", file = manifest_path, append = TRUE)
} else {
  writeLines(c("| step | object | file | class | dimensions | description |",
               "|---|---|---|---|---|---|", manifest_row), manifest_path)
}

cat("Completion summary: nrmm_model_v6 (list), ", length(nrmm_model_v6),
    " elements; spine ", nrow(spine), " records\n", sep = "")
