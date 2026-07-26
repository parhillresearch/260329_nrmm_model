#!/usr/bin/env Rscript

# =====================================================================
# SUPERSEDED - development history only, NOT authoritative.
# Superseded by: nrmm_model_v4.R (Layer 2)
# Retained so earlier results remain reproducible. Some definitions here
# differ from the current model (notably removal fate, retrofit NOx credit
# and the usage-index basis), so numbers from this script will not always
# match the current report. Do not cite it. See notes.md, "State of play".
# =====================================================================

# Effective Emissions Factor (EF) for the audited NRMM fleet — objective 6.
#
# Method: each machine is assigned the emissions limit value of its recorded
# initial stage at its engine power band ("Stage limits as the practical
# value"). The fleet-effective EF for a sub-group S is the weighted mean of
# those per-machine values. Because stage limits are certified in g per kWh
# of engine work, the natural fleet unit is g/kWh, numerically identical to
# kg/MWh, so "per MWh operated" is tested against alternatives below rather
# than assumed.
#
# Units test performed here:
#   (1) count weighting (assumes every machine delivers equal MWh);
#   (2) rated-power weighting (energy share proxied by kW, i.e. equal
#       operating hours and load factor across machines) — the practical
#       approximation to a true per-MWh figure absent hours data;
#   (3) per-litre-fuel and per-hour conversions are scalar transformations
#       of (2) requiring extra constants (BSFC, load factor), so they add
#       assumptions without adding information; shown in the output text.
#
# IMPORTANT — provenance of limit values: the stage limit tables below are
# taken from general knowledge of EU Directive 97/68/EC and Regulation (EU)
# 2016/1628 (NOx, or HC+NOx where the band/stage regulates the sum; PM).
# They are NOT sourced from project documents and must be verified against
# the EMEP/EEA guidebook / the Regulation before results are relied upon.
# Bands where a stage was never defined carry the nearest applicable limit.

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

# Stage limit values, g/kWh, diesel NRMM, by stage (rows) and band (columns).
# GENERAL KNOWLEDGE — VERIFY (see header). NOx column entries are NOx, or
# HC+NOx where that is what the stage regulates at that band.
NOX_LIMIT <- rbind(
  `1` = c(9.2, 9.2, 9.2, 9.2, 9.2, 9.2, 9.2),   # Stage I
  `2` = c(8.0, 8.0, 7.0, 7.0, 6.0, 6.0, 6.0),   # Stage II
  `3` = c(7.5, 7.5, 4.7, 4.7, 4.0, 4.0, 4.0),   # Stage IIIA (HC+NOx)
  `4` = c(7.5, 7.5, 4.7, 3.3, 3.3, 2.0, 2.0),   # Stage IIIB
  `5` = c(7.5, 7.5, 4.7, 0.4, 0.4, 0.4, 3.5),   # Stage IV
  `6` = c(7.5, 4.7, 4.7, 0.4, 0.4, 0.4, 3.5),   # Stage V
  `7` = c(0,   0,   0,   0,   0,   0,   0  )    # ZE
)
PM_LIMIT <- rbind(
  `1` = c(0.85, 0.85, 0.85, 0.85, 0.70, 0.54, 0.54),
  `2` = c(0.80, 0.80, 0.40, 0.40, 0.30, 0.20, 0.20),
  `3` = c(0.60, 0.60, 0.40, 0.40, 0.30, 0.20, 0.20),
  `4` = c(0.60, 0.60, 0.025, 0.025, 0.025, 0.025, 0.025),
  `5` = c(0.60, 0.60, 0.025, 0.025, 0.025, 0.025, 0.025),
  `6` = c(0.40, 0.015, 0.015, 0.015, 0.015, 0.015, 0.045),
  `7` = c(0,    0,    0,    0,    0,    0,    0)
)
colnames(NOX_LIMIT) <- BAND_LABELS
colnames(PM_LIMIT)  <- BAND_LABELS

# Conversion constants for the units discussion (indicative, diesel):
BSFC_KG_PER_KWH   <- 0.22   # brake-specific fuel consumption
DIESEL_KG_PER_L   <- 0.84

output_md <- "outputs/260717_ef_fleet_v1.md"

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

# --- Derive power, band, subgroup, phase ---

# kW parsing: numeric values pass through; range strings ("130-560") are
# replaced by their midpoint; everything else is NA.
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
    year  = as.integer(format(audit_date, "%Y")),
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
    cold_engaged = `Cold-Engaged` == "Yes"
  ) %>%
  filter(!is.na(subgroup), `Machine Type` != "No NRMM", !is.na(initial_stage))

# Band imputation for missing kW: machine-type median of parseable values.
machine_type_median_kw <- fleet %>%
  filter(!is.na(kw_parsed)) %>%
  group_by(`Machine Type`) %>%
  summarise(type_median_kw = median(kw_parsed), .groups = "drop")

# Fleet-median fallback covers machine types with no parseable kW at all
# (e.g. case-variant type labels with a single record).
overall_median_kw <- median(fleet$kw_parsed, na.rm = TRUE)

fleet <- fleet %>%
  left_join(machine_type_median_kw, by = "Machine Type") %>%
  mutate(
    kw_imputed  = is.na(kw_parsed),
    kw_effective = coalesce(kw_parsed, type_median_kw, overall_median_kw),
    band = cut(kw_effective, BAND_BREAKS, labels = BAND_LABELS, right = FALSE),
    ef_nox = NOX_LIMIT[cbind(as.character(initial_stage), as.character(band))],
    ef_pm  = PM_LIMIT [cbind(as.character(initial_stage), as.character(band))]
  )

# --- Fleet-effective EF by sub-group ---

# Weighted summary under both weighting schemes. g/kWh == kg/MWh numerically.
ef_summary <- function(records) {
  records %>%
    filter(!is.na(ef_nox), !is.na(kw_effective)) %>%
    summarise(
      n = n(),
      total_kw = sum(kw_effective),
      ef_nox_count = mean(ef_nox),
      ef_nox_power = weighted.mean(ef_nox, kw_effective),
      ef_pm_count  = mean(ef_pm),
      ef_pm_power  = weighted.mean(ef_pm, kw_effective),
      .groups = "drop"
    )
}

ef_by_subgroup_phase <- fleet %>%
  group_by(subgroup, phase) %>%
  ef_summary()

ef_whole_fleet_phase <- fleet %>%
  group_by(phase) %>%
  ef_summary() %>%
  mutate(subgroup = "All_NRMM", .before = 1)

ef_all <- bind_rows(ef_by_subgroup_phase, ef_whole_fleet_phase) %>%
  arrange(subgroup, phase)

ef_by_engagement <- fleet %>%
  mutate(engagement = if_else(cold_engaged, "Cold", "Warm")) %>%
  group_by(subgroup, phase, engagement) %>%
  ef_summary() %>%
  pivot_wider(id_cols = c(subgroup, phase),
              names_from = engagement,
              values_from = c(n, ef_nox_power)) %>%
  mutate(warm_minus_cold = ef_nox_power_Warm - ef_nox_power_Cold)

# Sensitivity: imputation-free (known-kW records only)
ef_known_kw_only <- fleet %>%
  filter(!kw_imputed) %>%
  group_by(subgroup, phase) %>%
  ef_summary() %>%
  select(subgroup, phase, ef_nox_power_known_kw = ef_nox_power)

ef_sensitivity <- ef_by_subgroup_phase %>%
  select(subgroup, phase, ef_nox_power) %>%
  left_join(ef_known_kw_only, by = c("subgroup", "phase")) %>%
  mutate(delta = round(ef_nox_power - ef_nox_power_known_kw, 3))

# --- Verification block ---

cat("Verification...\n")

# structural: every retained record must resolve to an EF value
n_unresolved_ef <- sum(is.na(fleet$ef_nox))
if (n_unresolved_ef > 0) {
  stop("EF lookup failed for ", n_unresolved_ef, " records; check stage/band coverage.")
}
stopifnot(all(fleet$ef_nox >= 0), all(fleet$ef_pm >= 0))
stopifnot(all(fleet$kw_effective > 0, na.rm = TRUE))

# referential: every subgroup x phase cell in the summary has n > 0
stopifnot(all(ef_all$n > 0))

# distribution fingerprints: warn, continue
share_imputed <- mean(fleet$kw_imputed)
if (share_imputed > 0.25) {
  warning(sprintf("kW imputed for %.1f%% of fleet records (machine-type medians).",
                  100 * share_imputed))
}
band_share <- prop.table(table(fleet$band))
if (sum(band_share[c("37-56", "56-75", "75-130", "130-560")]) < 0.9) {
  warning("Less than 90% of records fall in the four core EU power bands.")
}

# analytical: power-weighted EF should not exceed count-weighted EF by a large
# factor anywhere (both are convex combinations of the same limit values)
if (any(ef_all$ef_nox_power / ef_all$ef_nox_count > 2, na.rm = TRUE)) {
  warning("Power-weighted EF more than double count-weighted EF in some cell.")
}

cat(sprintf("  Fleet records with resolvable stage: %d\n", nrow(fleet)))
cat(sprintf("  kW known %.1f%% | imputed from machine-type median %.1f%%\n",
            100 * (1 - share_imputed), 100 * share_imputed))

# --- Units test (computed evidence) ---

# If rated power were uncorrelated with stage, count and power weighting would
# coincide and the units question would be moot; report the actual divergence.
weighting_divergence <- ef_all %>%
  mutate(divergence_pct = round(100 * (ef_nox_power - ef_nox_count) / ef_nox_count, 1)) %>%
  select(subgroup, phase, n, ef_nox_count, ef_nox_power, divergence_pct)

kw_stage_cor <- cor(fleet$kw_effective, fleet$initial_stage,
                    use = "complete.obs", method = "spearman")

# --- Write markdown output ---

fmt <- function(x, d = 2) formatC(round(x, d), format = "f", digits = d)

md <- c(
  "# Fleet-effective Emissions Factors (EF) — 260717 v1",
  "",
  "EF values are the stage limit taken as the practical emissions value,",
  "assigned per machine at its recorded initial stage and engine power band,",
  "then averaged over each sub-group. Units are g/kWh of engine work, which is",
  "numerically identical to kg/MWh.",
  "",
  "**Provenance warning:** stage limit values are drawn from general knowledge",
  "of Directive 97/68/EC and Regulation (EU) 2016/1628, not from project",
  "documents; verify before external use. NOx entries are HC+NOx where that is",
  "what the stage regulates at that band (Stage IIIA, and small bands at later",
  "stages).",
  "",
  "## 1. Units test: is 'per MWh operated' the right basis?",
  "",
  paste0("The limits are certified in g/kWh, so a fleet EF is a weighted mean of",
         " per-machine limit values and the only substantive choice is the weight."),
  "",
  "- **Count weighting** assumes every machine delivers the same energy.",
  paste0("- **Rated-power weighting** (used as the headline here) assumes equal",
         " operating hours and load factor, so energy share is proportional to kW.",
         " This is the closest practical approximation to per-MWh with no usage",
         " data in the audits."),
  paste0("- **Per litre of fuel** divides by BSFC x density (~",
         fmt(BSFC_KG_PER_KWH), " kg/kWh / ", fmt(DIESEL_KG_PER_L),
         " kg/L => ~", fmt(BSFC_KG_PER_KWH / DIESEL_KG_PER_L, 3), " L/kWh), a",
         " near-constant scalar: no additional discrimination between machines."),
  paste0("- **Per operating hour** multiplies back by kW x load factor, so it",
         " re-introduces the power weighting inside the unit itself and varies",
         " machine to machine; unsuitable as a single fleet metric."),
  "",
  paste0("Spearman correlation between rated kW and stage is ",
         fmt(kw_stage_cor, 3), ", i.e. large machines are not newer-staged",
         " than small ones. The count-vs-power divergence tabulated below is",
         " therefore driven by the band structure of the limits themselves:",
         " at the same stage, engines above 130 kW face stricter g/kWh limits",
         " than 37-130 kW engines, and the biggest machines contribute the",
         " most energy. Count weighting consequently overstates the fleet EF,",
         " and the per-MWh (power-weighted) basis is the defensible headline."),
  "",
  "### Count-weighted vs power-weighted EF NOx (g/kWh)",
  "",
  kable(weighting_divergence, format = "pipe",
        col.names = c("Sub-group", "Phase", "n", "EF count-wtd",
                      "EF power-wtd", "divergence %")),
  "",
  "## 2. Fleet-effective EF by sub-group and phase",
  "",
  "Power-weighted (per-MWh basis) and count-weighted, NOx and PM.",
  "",
  kable(ef_all %>%
          mutate(across(c(ef_nox_count, ef_nox_power), ~ round(.x, 2)),
                 across(c(ef_pm_count, ef_pm_power), ~ round(.x, 3)),
                 total_kw = round(total_kw)),
        format = "pipe",
        col.names = c("Sub-group", "Phase", "n", "Total kW",
                      "NOx count-wtd", "NOx power-wtd",
                      "PM count-wtd", "PM power-wtd")),
  "",
  "## 3. Warm vs cold engagement (EF NOx, power-weighted)",
  "",
  kable(ef_by_engagement %>%
          mutate(across(where(is.numeric), ~ round(.x, 2))),
        format = "pipe",
        col.names = c("Sub-group", "Phase", "n Cold", "n Warm",
                      "EF Cold", "EF Warm", "Warm - Cold")),
  "",
  "## 4. Sensitivity: kW imputation",
  "",
  paste0("kW was imputed from machine-type medians for ",
         fmt(100 * share_imputed, 1), "% of records. Power-weighted EF with and",
         " without those records:"),
  "",
  kable(ef_sensitivity %>% mutate(across(where(is.numeric), ~ round(.x, 3))),
        format = "pipe",
        col.names = c("Sub-group", "Phase", "EF (imputed incl.)",
                      "EF (known kW only)", "delta")),
  ""
)
writeLines(md, output_md)
cat("Markdown written:", output_md, "\n")

# --- Save outputs ---

ef_fleet <- list(
  by_subgroup_phase = ef_all,
  by_engagement     = ef_by_engagement,
  sensitivity       = ef_sensitivity,
  weighting_divergence = weighting_divergence,
  nox_limit_table = NOX_LIMIT,
  pm_limit_table  = PM_LIMIT
)
saveRDS(ef_fleet, "intermediate_data/ef_fleet_260717_v1.rds")

manifest_path <- "intermediate_data/manifest.md"
manifest_row <- paste0(
  "| EF | ef_fleet | ef_fleet_260717_v1.rds | list | ",
  nrow(ef_all), " subgroup-phase cells | ",
  "Fleet-effective EF (NOx, PM; count- and power-weighted g/kWh) by sub-group, ",
  "phase and engagement, from initial stage limits at engine power band; ",
  "records with unresolvable stage or subgroup excluded. |"
)
if (file.exists(manifest_path)) {
  cat(manifest_row, "\n", file = manifest_path, append = TRUE)
} else {
  writeLines(c("| step | object | file | class | dimensions | description |",
               "|---|---|---|---|---|---|", manifest_row), manifest_path)
}

cat("Completion summary: ef_fleet (list), ",
    length(ef_fleet), " elements; by_subgroup_phase ",
    nrow(ef_all), " x ", ncol(ef_all), "\n", sep = "")
