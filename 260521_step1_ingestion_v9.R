# --- Load packages (Constants are defined just before first use) ---

library(tidyverse)
library(knitr)

# --- Helper functions ---

# Log rows where is_excluded is TRUE into exclusions_list[[label]], return remaining rows.
apply_exclusion <- function(data, exclusions_list, is_excluded, label) {
  exclusions_list[[label]] <- data |>
    filter(is_excluded) |>
    transmute(date, exclusion_reason = label)
  list(data = filter(data, !is_excluded), exclusions_list = exclusions_list)
}

# NC codes and "none" sentinel are lowercased at ingestion; "none" is replaced with NA
# before tolower so "none" -> "e" false positive is eliminated at the boundary.
derive_compliance_flags <- function(reasons) {
  r_raw <- trimws(replace_na(as.character(reasons), ""))
  list(
    emissions_compliant = !grepl("e", r_raw, fixed = TRUE),
    admin_compliant     = !grepl("[acprx]", r_raw)
  )
}

fractional_year <- function(d) {
  yr         <- as.integer(format(d, "%Y"))
  doy        <- as.integer(format(d, "%j"))                        # %j: day-of-year (1-366)
  leap       <- (yr %% 4 == 0 & yr %% 100 != 0) | yr %% 400 == 0
  days_in_yr <- ifelse(leap, 366L, 365L)
  yr + (doy - 1L) / days_in_yr
}

# Tally unique values in column_selected; store named frequency table in exclusion_stats under that key.
tabulate_column <- function(exclusion_stats, input_tibble, column_selected) {
  exclusion_stats[[column_selected]] <- table(input_tibble[[column_selected]])
  exclusion_stats
}

# --- Load and normalise raw data ---

INPUT_FILE         <- "input_data/audits.txt"

raw <- read.delim(INPUT_FILE, stringsAsFactors = FALSE, check.names = TRUE) |>
  as_tibble()
names(raw) <- gsub("\\.", "_", tolower(names(raw)))

COLS_KEEP <- c(
  "cold_engaged", "zone", "date", "tan",
  "initial_machinery_compliance", "initial_machinery_reasons",
  "initial_emissions_stage",      "initial_retrofit_or_exemption",
  "final_machinery_compliance",   "final_machinery_reasons",
  "final_emissions_stage",        "final_retrofit_or_exemption",
  "machine_type", "engine_type", "kw_power", "audit_num"
)

audits_raw <- raw |>
  select(all_of(COLS_KEEP)) |>
  mutate(across(where(is.character), trimws)) |>
  mutate(across(c(initial_machinery_reasons, final_machinery_reasons),
                ~if_else(tolower(.x) %in% c("none", "non"), NA_character_, .x))) |>
  mutate(across(where(is.character), tolower)) |>
  mutate(date = as.Date(date, format = "%d/%m/%Y"))

OUTPUTS_DIR        <- "outputs"
STEP               <- 1L
VERSION            <- 9L
SCRIPT_STEM        <- paste0(format(Sys.Date(), "%y%m%d"), "_step", STEP, "_ingestion_v", VERSION)
OUTPUT_MD          <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, ".md"))

init_comp_freq <- audits_raw |>
  count(initial_machinery_compliance, name = "freq")

final_by_init <- audits_raw |>
  filter(final_machinery_compliance != "", !is.na(final_machinery_compliance)) |>
  count(initial_machinery_compliance, final_machinery_compliance, name = "freq") |>
  pivot_wider(names_from = final_machinery_compliance, values_from = freq, values_fill = 0)

cat(
  "## rows = initial_machinery_compliance, columns = freq (all raw audits)\n\n",
  paste(kable(init_comp_freq, format = "markdown"), collapse = "\n"),
  "\n\n## rows = initial_machinery_compliance, columns = final_machinery_compliance (all raw audits)\n\n",
  paste(kable(final_by_init, format = "markdown"), collapse = "\n"),
  "\n",
  file = OUTPUT_MD, append = FALSE, sep = ""
)

engine_type_freq_raw <- audits_raw |>
  count(engine_type, name = "freq")

engine_type_by_final <- audits_raw |>
  mutate(
    engine_type                = if_else(engine_type == "" | is.na(engine_type), "(blank)", engine_type),
    final_machinery_compliance = if_else(final_machinery_compliance == "" | is.na(final_machinery_compliance), "(blank)", final_machinery_compliance)
  ) |>
  count(engine_type, final_machinery_compliance, name = "freq") |>
  pivot_wider(names_from = final_machinery_compliance, values_from = freq, values_fill = 0)

cat(
  "\n## engine_type (all raw audits)\n\n",
  paste(kable(engine_type_freq_raw, format = "markdown"), collapse = "\n"),
  "\n\n## final_machinery_compliance by engine_type (all raw audits)\n\n",
  paste(kable(engine_type_by_final, format = "markdown"), collapse = "\n"),
  "\n",
  file = OUTPUT_MD, append = TRUE, sep = ""
)

# --- Apply exclusion filters ---

exclusions_list <- list()
exclusions_stats <- list()

exclusions_stats <- tabulate_column(exclusions_stats, audits_raw, "initial_machinery_compliance")
exclusion_result <- apply_exclusion(
  data            = audits_raw,
  exclusions_list = exclusions_list,
  is_excluded     = !audits_raw$initial_machinery_compliance %in% c("compliant", "non-compliant"),
  label           = "No NRMM / non-machinery"
)
audits_machinery <- exclusion_result$data
exclusions_list  <- exclusion_result$exclusions_list

ZONES_IN_SCOPE <- c("caz", "oa", "gl", "p24")

exclusions_stats <- tabulate_column(exclusions_stats, audits_raw, "zone")
exclusion_result <- apply_exclusion(
  data            = audits_machinery,
  exclusions_list = exclusions_list,
  is_excluded     = !audits_machinery$zone %in% ZONES_IN_SCOPE,
  label           = "Zone out of scope"
)
audits_zoned    <- exclusion_result$data
exclusions_list <- exclusion_result$exclusions_list

# Many machine_types lack an engine type value (e.g. constant or variable). To fill this gap, we
# find the model value of engine type, to substitute for empty data. This won't work for generators 
# as these are 2/3rds-1/3rd of each. For generators we'll try a more sophisticated pattern matching 
# based on whether they were marked as compliant, what their Stage number was, etc. 
engine_type_freq <- audits_zoned |>
  filter(engine_type %in% c("constant", "variable")) |>
  count(machine_type, engine_type, name = "freq")

# Wide version for human inspection: rows = machine_type, columns = engine_type values
engine_type_freq_wide <- engine_type_freq |>
  pivot_wider(names_from = engine_type, values_from = freq, values_fill = 0)

cat(
  "## Engine type frequency by machine type\n\n",
  paste(kable(engine_type_freq_wide, format = "markdown"), collapse = "\n"),
  "\n",
  file = OUTPUT_MD, append = TRUE, sep = ""
)

# Modal engine_type per machine_type: one row per machine_type, highest freq wins
engine_type_modal <- engine_type_freq |>
  slice_max(freq, by = machine_type, n = 1, with_ties = FALSE) |>
  select(machine_type, engine_type_modal = engine_type)

# Impute any non-valid engine_type from modal lookup; generators excluded
#   (near-even split means no reliable modal); unresolved rows caught by exclusion filter below
audits_zoned_joined <- audits_zoned |>
  left_join(engine_type_modal, by = "machine_type")

audits_zoned <- audits_zoned_joined |>
  mutate(
    engine_type       = if_else(
      !engine_type %in% c("constant", "variable") & machine_type != "generator",
      engine_type_modal,
      engine_type
    ),
    engine_type_clean = engine_type
  ) |>
  select(-engine_type_modal)

exclusion_result <- apply_exclusion(
  data            = audits_zoned,
  exclusions_list = exclusions_list,
  is_excluded     = !audits_zoned$engine_type_clean %in% c("constant", "variable"),
  label           = "Engine type unassignable"
)
audits_typed    <- exclusion_result$data
exclusions_list <- exclusion_result$exclusions_list

STAGE_MAP <- c(i = 1L, ii = 2L, iiia = 3L, iiib = 4L, iv = 5L, v = 6L, ze = 7L)

audits_typed <- audits_typed |>
  mutate(
    initial_stage = unname(STAGE_MAP[initial_emissions_stage]),
    final_stage   = unname(STAGE_MAP[final_emissions_stage])
  )

exclusion_result <- apply_exclusion(
  data            = audits_typed,
  exclusions_list = exclusions_list,
  is_excluded     = is.na(audits_typed$initial_stage),
  label           = "Stage unresolvable"
)
audits_staged   <- exclusion_result$data
exclusions_list <- exclusion_result$exclusions_list


COVID_START    <- as.Date("2020-09-01"); COVID_END    <- as.Date("2021-03-31")

covid_flag <- audits_staged$date >= COVID_START & audits_staged$date <= COVID_END &
  (audits_staged$initial_retrofit_or_exemption %in% "covid exemption" |
   audits_staged$final_retrofit_or_exemption   %in% "covid exemption")

exclusion_result <- apply_exclusion(
  data            = audits_staged,
  exclusions_list = exclusions_list,
  is_excluded     = covid_flag,
  label           = "COVID exempt"
)
audits_in_scope <- exclusion_result$data
exclusions_list <- exclusion_result$exclusions_list


# --- Derive analytical fields ---

flags_init  <- derive_compliance_flags(audits_in_scope$initial_machinery_reasons)
flags_final <- derive_compliance_flags(audits_in_scope$final_machinery_reasons)

PHASE_A1_START <- as.Date("2016-01-01"); PHASE_A1_END <- as.Date("2018-12-31")
PHASE_A2_START <- as.Date("2019-01-01"); PHASE_A2_END <- as.Date("2020-08-31")
PHASE_B_START  <- as.Date("2020-09-01"); PHASE_B_END  <- as.Date("2024-12-31")
PHASE_C_START  <- as.Date("2025-01-01")

audits_measured <- audits_in_scope |>
  mutate(
    # power rating
    kw_power_raw    = kw_power,
    no_power_rating = kw_power_raw == "" | kw_power_raw == "unidentified" |
                      is.na(suppressWarnings(as.numeric(kw_power_raw))),
    kw_power        = suppressWarnings(as.numeric(kw_power_raw)),
    # compliance flags
    init_mach_emissions_compliant  = flags_init$emissions_compliant,
    init_mach_admin_compliant      = flags_init$admin_compliant,
    final_mach_emissions_compliant = flags_final$emissions_compliant,
    final_mach_admin_compliant     = flags_final$admin_compliant,
    # time and engagement
    cold_engaged = cold_engaged %in% c("yes", "y", "v"),
    year         = as.integer(format(date, "%Y")),
    date_frac    = fractional_year(date),
    phase        = case_when(
      date >= PHASE_A1_START & date <= PHASE_A1_END ~ "A1",
      date >= PHASE_A2_START & date <= PHASE_A2_END ~ "A2",
      date >= PHASE_B_START  & date <= PHASE_B_END  ~ "B",
      date >= PHASE_C_START                         ~ "C",
      TRUE                                          ~ NA_character_
    )
  ) |>
  select(-kw_power_raw)


# --- Assign groups and expand Variable_Speed ---

n_records_pre_group <- nrow(audits_measured)

audits_grouped <- audits_measured |>
  mutate(
    group_primary = case_when(
      engine_type_clean == "constant"                             ~ "Constant_Speed",
      engine_type_clean == "variable" & zone %in% c("caz", "oa") ~ "CAZ_Plus",
      engine_type_clean == "variable" & zone == "gl"              ~ "Rest_of_London",
      engine_type_clean == "variable" & zone == "p24"             ~ "Variable_Speed",
      TRUE                                                        ~ NA_character_
    ),
    vs_member = (engine_type_clean == "variable")
  )

# CAZ_Plus and Rest_of_London are also members of the pooled Variable_Speed group;
# duplicate those rows with group = "Variable_Speed" for pooled and sub-group analysis.
audits <- bind_rows(
  audits_grouped |> mutate(group = group_primary),
  audits_grouped |>
    filter(group_primary %in% c("CAZ_Plus", "Rest_of_London")) |>
    mutate(group = "Variable_Speed")
) |> arrange(date, group)

audits_uniq <- audits |> filter(group == group_primary)

exclusions <- bind_rows(exclusions_list) |>
  mutate(year = as.integer(format(date, "%Y")))


# --- Verification ---

stopifnot(
  "init_mach_emissions_compliant has NAs" = !anyNA(audits$init_mach_emissions_compliant),
  "group_primary has unassigned records"  = !anyNA(audits_uniq$group_primary),
  "cold + warm != n_records_pre_group"    = (sum(audits_uniq$cold_engaged) +
                                              sum(!audits_uniq$cold_engaged)) == n_records_pre_group
)

# --- Save outputs ---
INTERMEDIATE_DATA  <- "intermediate_data"

saveRDS(audits,      file.path(INTERMEDIATE_DATA, "audits.rds"))
saveRDS(audits_uniq, file.path(INTERMEDIATE_DATA, "audits_uniq.rds"))
saveRDS(exclusions,  file.path(INTERMEDIATE_DATA, "exclusions.rds"))

# --- Completion summary ---

cat(sprintf("%-15s  %s  [%s]\n", "audits",      paste(dim(audits),      collapse = " x "), class(audits)[1]))
cat(sprintf("%-15s  %s  [%s]\n", "audits_uniq", paste(dim(audits_uniq), collapse = " x "), class(audits_uniq)[1]))
cat(sprintf("%-15s  %s  [%s]\n", "exclusions",  paste(dim(exclusions),  collapse = " x "), class(exclusions)[1]))

# --- Manifest ---

manifest_rows <- paste(
  "| step | object | file | class | dimensions | description |",
  "|------|--------|------|-------|------------|-------------|",
  sprintf("| 1 | audits | audits.rds | tbl_df | %s | All ingested audit records including Variable_Speed group duplication of CAZ_Plus and Rest_of_London rows. |",
          paste(dim(audits), collapse = " x ")),
  sprintf("| 1 | audits_uniq | audits_uniq.rds | tbl_df | %s | Unique audit records after all exclusion filters applied, one row per audit with group == group_primary. |",
          paste(dim(audits_uniq), collapse = " x ")),
  sprintf("| 1 | exclusions | exclusions.rds | tbl_df | %s | Excluded records with date, year, and exclusion_reason documenting each filter applied during ingestion. |",
          paste(dim(exclusions), collapse = " x ")),
  sep = "\n"
)

MANIFEST_FILE      <- file.path(INTERMEDIATE_DATA, "manifest.md")
writeLines(manifest_rows, MANIFEST_FILE)
