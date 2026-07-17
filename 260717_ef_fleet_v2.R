#!/usr/bin/env Rscript

# Fleet-effective EF v2 — option 2: type-stratified convex-combination model.
#
# Model: for each sub-group S and phase, the fleet EF is
#     EF_fleet = sum_t s_t * EF_t,    s_t = N_t * kWbar_t * u_t / sum(...)
# where t indexes machine types, EF_t is the power-weighted mean stage-limit
# EF of type t within that cell (from the audits), N_t the number of machines
# of type t (PLACEHOLDER: audit counts; to be replaced by NRMM registration
# database counts), kWbar_t the mean rated power, and u_t a RELATIVE usage
# index (load factor x annual hours, scaled to excavator = 1).
#
# Because s_t are normalised shares, EF_fleet is a convex combination of the
# EF_t: it is mathematically bounded by the cleanest and dirtiest type mean
# regardless of usage assumptions, and only RELATIVE usage between types
# matters (any common scaling of u cancels). Sensitivity therefore turns the
# u dials: an adversarial envelope (u pushed to box bounds to maximise or
# minimise EF) and one-at-a-time perturbations.
#
# PLACEHOLDERS to replace when data arrives:
#   - USAGE_INDEX (u central/low/high per type): indicative values from
#     general knowledge of typical construction plant duty cycles; NOT from
#     project documents. Replace with sourced estimates.
#   - N_t: audit counts stand in for NRMM registration database counts.
#   - Stage limit tables: as v1 (Directive 97/68/EC / Regulation 2016/1628
#     from general knowledge; verify).

library(readr)
library(dplyr)
library(tidyr)
library(knitr)

# --- Named constants ---

PHASE_A2_START <- as.Date("2019-01-01")
PHASE_B_START  <- as.Date("2020-09-01")
PHASE_C_START  <- as.Date("2025-01-01")

BAND_BREAKS <- c(0, 19, 37, 56, 75, 130, 560, Inf)
BAND_LABELS <- c("<19", "19-37", "37-56", "56-75", "75-130", "130-560", ">=560")

NOX_LIMIT <- rbind(
  `1` = c(9.2, 9.2, 9.2, 9.2, 9.2, 9.2, 9.2),
  `2` = c(8.0, 8.0, 7.0, 7.0, 6.0, 6.0, 6.0),
  `3` = c(7.5, 7.5, 4.7, 4.7, 4.0, 4.0, 4.0),
  `4` = c(7.5, 7.5, 4.7, 3.3, 3.3, 2.0, 2.0),
  `5` = c(7.5, 7.5, 4.7, 0.4, 0.4, 0.4, 3.5),
  `6` = c(7.5, 4.7, 4.7, 0.4, 0.4, 0.4, 3.5),
  `7` = c(0,   0,   0,   0,   0,   0,   0  )
)
colnames(NOX_LIMIT) <- BAND_LABELS

# Named machine types get their own stratum; everything else pools as "Other".
NAMED_TYPES <- c("Excavator", "Generator", "Telehandler", "Dumper",
                 "Piling Rig", "Pump", "Mobile Crane", "Crusher",
                 "Crawler Crane", "Roller", "MEWP", "Compressor")
TYPE_CANONICAL <- c("Piling rig" = "Piling Rig")   # case-variant labels

# PLACEHOLDER usage indices, relative to excavator = 1 (load factor x hours).
# Indicative values from general knowledge of plant duty cycles — REPLACE.
USAGE_INDEX <- tribble(
  ~machine_type,   ~u_central, ~u_low, ~u_high,
  "Excavator",     1.0,        0.7,    1.3,
  "Generator",     3.0,        1.5,    5.0,
  "Telehandler",   0.8,        0.5,    1.2,
  "Dumper",        0.7,        0.4,    1.1,
  "Piling Rig",    0.8,        0.5,    1.2,
  "Pump",          2.5,        1.0,    4.0,
  "Mobile Crane",  0.5,        0.3,    0.9,
  "Crusher",       1.2,        0.7,    1.8,
  "Crawler Crane", 0.6,        0.4,    1.0,
  "Roller",        0.6,        0.3,    1.0,
  "MEWP",          0.5,        0.3,    0.8,
  "Compressor",    1.5,        0.8,    2.5,
  "Other",         0.8,        0.4,    1.2
)

ENVELOPE_MAX_ITER <- 20

output_md <- "outputs/260717_ef_fleet_v2.md"

# --- Load input data ---

cat("Loading audit data...\n")
audits <- read_delim("input_data/audits.txt", delim = "\t", show_col_types = FALSE)

essential_cols <- c("Zone", "Engine Type", "Date", "Cold-Engaged", "Machine Type",
                    "kW Power", "Initial Emissions Stage")
missing_cols <- setdiff(essential_cols, names(audits))
if (length(missing_cols) > 0) {
  stop("Missing columns: ", paste(missing_cols, collapse = ", "))
}

stage_to_int <- function(x) case_when(
  x %in% c("I",    "1") ~ 1L,
  x %in% c("II",   "2") ~ 2L,
  x %in% c("IIIA", "3") ~ 3L,
  x %in% c("IIIB", "4") ~ 4L,
  x %in% c("IV",   "5") ~ 5L,
  x %in% c("V",    "6") ~ 6L,
  x == "ZE"             ~ 7L,
  TRUE ~ NA_integer_
)

# --- Engine type imputation (per Step 1 v9 modal logic) ---

engine_type_modal <- audits %>%
  filter(`Engine Type` %in% c("Constant", "Variable")) %>%
  count(`Machine Type`, `Engine Type`, name = "freq") %>%
  slice_max(freq, by = `Machine Type`, n = 1, with_ties = FALSE) %>%
  select(`Machine Type`, engine_type_modal = `Engine Type`)

audits <- audits %>%
  left_join(engine_type_modal, by = "Machine Type") %>%
  mutate(
    `Engine Type` = if_else(
      !`Engine Type` %in% c("Constant", "Variable") & `Machine Type` != "Generator",
      engine_type_modal,
      `Engine Type`
    )
  ) %>%
  select(-engine_type_modal)

# --- Derive fleet records (as v1, plus canonical machine type) ---

parse_kw <- function(x) {
  numeric_kw <- suppressWarnings(as.numeric(x))
  range_match <- grepl("^\\s*\\d+\\s*-\\s*\\d+\\s*$", x)
  low  <- suppressWarnings(as.numeric(sub("-.*", "", x)))
  high <- suppressWarnings(as.numeric(sub(".*-", "", x)))
  ifelse(!is.na(numeric_kw), numeric_kw,
         ifelse(range_match, (low + high) / 2, NA_real_))
}

fleet <- audits %>%
  mutate(
    audit_date = as.Date(Date, format = "%d/%m/%Y"),
    phase = case_when(
      audit_date < PHASE_A2_START ~ "A1",
      audit_date < PHASE_B_START  ~ "A2",
      audit_date < PHASE_C_START  ~ "B",
      TRUE                        ~ "C"
    ),
    subgroup = case_when(
      `Engine Type` == "Constant"                              ~ "Constant_Speed",
      `Engine Type` == "Variable" & Zone %in% c("CAZ", "OA") ~ "CAZ_Plus",
      `Engine Type` == "Variable" & Zone == "GL"              ~ "Rest_of_London",
      TRUE ~ NA_character_
    ),
    initial_stage = stage_to_int(`Initial Emissions Stage`),
    kw_parsed = parse_kw(`kW Power`),
    machine_type_raw = trimws(`Machine Type`),
    machine_type = coalesce(TYPE_CANONICAL[machine_type_raw], machine_type_raw),
    machine_type = if_else(machine_type %in% NAMED_TYPES, machine_type, "Other")
  ) %>%
  filter(!is.na(subgroup), machine_type_raw != "No NRMM", !is.na(initial_stage))

machine_type_median_kw <- fleet %>%
  filter(!is.na(kw_parsed)) %>%
  group_by(machine_type) %>%
  summarise(type_median_kw = median(kw_parsed), .groups = "drop")

overall_median_kw <- median(fleet$kw_parsed, na.rm = TRUE)

fleet <- fleet %>%
  left_join(machine_type_median_kw, by = "machine_type") %>%
  mutate(
    kw_imputed   = is.na(kw_parsed),
    kw_effective = coalesce(kw_parsed, type_median_kw, overall_median_kw),
    band = cut(kw_effective, BAND_BREAKS, labels = BAND_LABELS, right = FALSE),
    ef_nox = NOX_LIMIT[cbind(as.character(initial_stage), as.character(band))]
  )

# --- Type strata: EF_t, N_t (placeholder), kWbar_t per subgroup x phase ---

make_strata <- function(records) {
  records %>%
    group_by(machine_type) %>%
    summarise(
      n_type    = n(),                        # PLACEHOLDER for registration N_t
      kw_mean   = mean(kw_effective),
      ef_type   = weighted.mean(ef_nox, kw_effective),
      .groups = "drop"
    ) %>%
    left_join(USAGE_INDEX, by = c("machine_type" = "machine_type"))
}

# Convex-combination fleet EF for a strata table under usage vector u.
fleet_ef <- function(strata, u) {
  w <- strata$n_type * strata$kw_mean * u
  sum(w * strata$ef_type) / sum(w)
}

# Adversarial envelope: with box-constrained u, the extremum places u at
# u_high for types whose EF_t is above the resulting mean and u_low below
# (reversed for the minimum). Solved by fixed-point iteration.
envelope_ef <- function(strata, maximise) {
  u <- strata$u_central
  for (iteration in seq_len(ENVELOPE_MAX_ITER)) {
    current <- fleet_ef(strata, u)
    u_next <- if (maximise) {
      if_else(strata$ef_type >= current, strata$u_high, strata$u_low)
    } else {
      if_else(strata$ef_type <= current, strata$u_high, strata$u_low)
    }
    if (all(u_next == u)) break
    u <- u_next
  }
  fleet_ef(strata, u)
}

cells <- fleet %>%
  group_by(subgroup, phase) %>%
  group_split()

cell_results <- bind_rows(lapply(cells, function(records) {
  strata <- make_strata(records)
  tibble(
    subgroup = records$subgroup[1],
    phase    = records$phase[1],
    n        = nrow(records),
    n_types  = nrow(strata),
    ef_central     = fleet_ef(strata, strata$u_central),
    ef_env_low     = envelope_ef(strata, maximise = FALSE),
    ef_env_high    = envelope_ef(strata, maximise = TRUE),
    ef_count_ref   = mean(records$ef_nox),
    ef_kw_ref      = weighted.mean(records$ef_nox, records$kw_effective),
    ef_uniform_low = fleet_ef(strata, strata$u_low),
    ef_uniform_high = fleet_ef(strata, strata$u_high),
    ef_type_min    = min(strata$ef_type),
    ef_type_max    = max(strata$ef_type)
  )
}))

whole_fleet_results <- bind_rows(lapply(split(fleet, fleet$phase), function(records) {
  strata <- make_strata(records)
  tibble(
    subgroup = "All_NRMM", phase = records$phase[1],
    n = nrow(records), n_types = nrow(strata),
    ef_central   = fleet_ef(strata, strata$u_central),
    ef_env_low   = envelope_ef(strata, maximise = FALSE),
    ef_env_high  = envelope_ef(strata, maximise = TRUE),
    ef_count_ref = mean(records$ef_nox),
    ef_kw_ref    = weighted.mean(records$ef_nox, records$kw_effective),
    ef_uniform_low = fleet_ef(strata, strata$u_low),
    ef_uniform_high = fleet_ef(strata, strata$u_high),
    ef_type_min  = min(strata$ef_type),
    ef_type_max  = max(strata$ef_type)
  )
}))

results <- bind_rows(cell_results, whole_fleet_results) %>%
  arrange(subgroup, phase)

# --- One-at-a-time sensitivity (whole fleet, phase B) ---

fleet_b <- filter(fleet, phase == "B")
strata_b <- make_strata(fleet_b)
central_b <- fleet_ef(strata_b, strata_b$u_central)

oat <- bind_rows(lapply(seq_len(nrow(strata_b)), function(i) {
  u_low_vec  <- strata_b$u_central; u_low_vec[i]  <- strata_b$u_low[i]
  u_high_vec <- strata_b$u_central; u_high_vec[i] <- strata_b$u_high[i]
  tibble(
    machine_type = strata_b$machine_type[i],
    ef_type = strata_b$ef_type[i],
    u_central = strata_b$u_central[i],
    ef_at_u_low  = fleet_ef(strata_b, u_low_vec),
    ef_at_u_high = fleet_ef(strata_b, u_high_vec)
  )
})) %>%
  mutate(swing = abs(ef_at_u_high - ef_at_u_low)) %>%
  arrange(desc(swing))

# --- Verification block ---

cat("Verification...\n")

# structural: EF resolvable everywhere; convexity bounds honoured
stopifnot(!any(is.na(fleet$ef_nox)))
stopifnot(all(results$ef_central >= results$ef_type_min - 1e-9),
          all(results$ef_central <= results$ef_type_max + 1e-9))
stopifnot(all(results$ef_env_low  <= results$ef_central + 1e-9),
          all(results$ef_env_high >= results$ef_central - 1e-9))

# referential: kW-weighted reference must equal the model with u = 1 for all
# (both reduce to power weighting); tolerance for stratification rounding
u_unit_check <- vapply(cells, function(records) {
  strata <- make_strata(records)
  abs(fleet_ef(strata, rep(1, nrow(strata))) -
        weighted.mean(records$ef_nox, records$kw_effective))
}, numeric(1))
stopifnot(all(u_unit_check < 1e-9))

# distribution fingerprints: warn, continue
if (any(results$n_types < 5)) {
  warning("Some subgroup x phase cells have fewer than 5 type strata; ",
          "envelope may be narrow there for lack of mix, not certainty.")
}
uniform_gap <- max(abs(results$ef_uniform_low - results$ef_uniform_high))
cat(sprintf("  Normalisation check: max |uniform-low - uniform-high| = %.3f g/kWh\n",
            uniform_gap))
cat(sprintf("  Whole-fleet phase B: central %.2f, envelope [%.2f, %.2f]\n",
            central_b,
            results$ef_env_low[results$subgroup == "All_NRMM" & results$phase == "B"],
            results$ef_env_high[results$subgroup == "All_NRMM" & results$phase == "B"]))

# --- Write markdown output ---

md <- c(
  "# Fleet-effective EF v2 — type-stratified convex-combination model (260717)",
  "",
  "EF_fleet = sum_t s_t x EF_t with s_t = N_t x kWbar_t x u_t (normalised).",
  "EF_t is the power-weighted stage-limit EF of machine type t in the cell;",
  "u_t is a RELATIVE usage index (load factor x hours, excavator = 1).",
  "Units g/kWh = kg/MWh. The result is a convex combination, so it is bounded",
  "by the cleanest and dirtiest type mean whatever usage values are assumed,",
  "and any common scaling of u cancels in the normalisation.",
  "",
  "**PLACEHOLDERS:** usage indices are indicative general-knowledge values,",
  "not sourced estimates; N_t are audit counts pending the NRMM registration",
  "database; stage limits as v1 (verify against the Regulation).",
  "",
  "## 1. Placeholder usage indices (relative, excavator = 1)",
  "",
  kable(USAGE_INDEX, format = "pipe",
        col.names = c("Machine type", "u central", "u low", "u high")),
  "",
  "## 2. Fleet EF NOx by sub-group and phase (g/kWh)",
  "",
  "Central = placeholder usage indices; envelope = adversarial box bounds on",
  "u (the widest the answer can move within the stated ranges); count and kW",
  "references are the v1 special cases (u equal per machine / per kW).",
  "",
  kable(results %>%
          select(subgroup, phase, n, ef_central, ef_env_low, ef_env_high,
                 ef_count_ref, ef_kw_ref) %>%
          mutate(across(where(is.numeric) & !c(n), ~ round(.x, 2))),
        format = "pipe",
        col.names = c("Sub-group", "Phase", "n", "EF central",
                      "Env low", "Env high", "Count ref", "kW ref")),
  "",
  paste0("Normalisation property, computed: moving every u jointly to its low",
         " bound versus jointly to its high bound shifts the answer by only ",
         formatC(round(uniform_gap, 3), format = "f", digits = 3),
         " g/kWh (a pure common scaling would shift it by exactly zero; the",
         " residual reflects bounds not proportional to the central values).",
         " Near-common changes in usage cancel; only relative usage between",
         " types moves the result, which is what the adversarial envelope",
         " above measures."),
  "",
  "## 3. One-at-a-time usage sensitivity (whole fleet, phase B)",
  "",
  paste0("Central EF ", formatC(round(central_b, 2), format = "f", digits = 2),
         " g/kWh. Each row perturbs one type's u to its bounds, others central."),
  "",
  kable(oat %>% mutate(across(where(is.numeric), ~ round(.x, 3))),
        format = "pipe",
        col.names = c("Machine type", "EF_t", "u central",
                      "EF at u low", "EF at u high", "swing")),
  "",
  "## 4. Reading the sensitivity",
  "",
  paste0("The envelope quantifies how much the usage assumptions can matter;",
         " the OAT table shows which single dials move the answer. Types with",
         " large swing combine a big energy share with an EF_t far from the",
         " fleet mean, so those are the usage estimates worth sourcing well",
         " (and the registration N_t worth checking first)."),
  ""
)
writeLines(md, output_md)
cat("Markdown written:", output_md, "\n")

# --- Save outputs ---

ef_fleet_v2 <- list(
  results      = results,
  oat_phase_b  = oat,
  usage_index  = USAGE_INDEX,
  strata_phase_b = strata_b,
  nox_limit_table = NOX_LIMIT
)
saveRDS(ef_fleet_v2, "intermediate_data/ef_fleet_260717_v2.rds")

manifest_path <- "intermediate_data/manifest.md"
manifest_row <- paste0(
  "| EF | ef_fleet_v2 | ef_fleet_260717_v2.rds | list | ",
  nrow(results), " subgroup-phase cells | ",
  "Type-stratified convex-combination fleet EF (NOx g/kWh) with placeholder ",
  "usage indices, adversarial envelopes and OAT sensitivity; N_t placeholder ",
  "is audit counts pending registration database. |"
)
if (file.exists(manifest_path)) {
  cat(manifest_row, "\n", file = manifest_path, append = TRUE)
} else {
  writeLines(c("| step | object | file | class | dimensions | description |",
               "|---|---|---|---|---|---|", manifest_row), manifest_path)
}

cat("Completion summary: ef_fleet_v2 (list), ", length(ef_fleet_v2),
    " elements; results ", nrow(results), " x ", ncol(results), "\n", sep = "")
