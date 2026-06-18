library(tidyverse)
library(knitr)

# --- Constants ---

INPUT_FILE    <- "input_data/audits.txt"
INTERMEDIATE_DATA  <- "intermediate_data"
OUTPUTS_DIR   <- "outputs"
MANIFEST_FILE <- file.path(INTERMEDIATE_DATA, "manifest.md")
SCRIPT_STEM   <- "260511_step1_ingestion_v7"
OUTPUT_MD     <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, ".md"))

COLS_KEEP <- c(
  "cold_engaged", "zone", "date", "tan",
  "initial_machinery_compliance", "initial_machinery_reasons",
  "initial_emissions_stage",      "initial_retrofit_or_exemption",
  "final_machinery_compliance",   "final_machinery_reasons",
  "final_emissions_stage",        "final_retrofit_or_exemption",
  "machine_type", "engine_type", "kw_power", "audit_num"
)

ZONES_IN_SCOPE <- c("CAZ", "OA", "GL", "P24")

STAGE_MAP <- c(I = 1L, II = 2L, IIIA = 3L, IIIB = 4L, IV = 5L, V = 6L, ZE = 7L)

PHASE_A1_START <- as.Date("2016-01-01"); PHASE_A1_END <- as.Date("2018-12-31")
PHASE_A2_START <- as.Date("2019-01-01"); PHASE_A2_END <- as.Date("2020-08-31")
PHASE_B_START  <- as.Date("2020-09-01"); PHASE_B_END  <- as.Date("2024-12-31")
PHASE_C_START  <- as.Date("2025-01-01")
COVID_START    <- as.Date("2020-09-01"); COVID_END    <- as.Date("2021-03-31")


# --- Helper functions ---

# Log rows where is_excluded is TRUE into excl_list[[label]], return remaining rows.
apply_exclusion <- function(data, excl_list, is_excluded, label) {
  excl_list[[label]] <- data |>
    filter(is_excluded) |>
    transmute(date, excl_reason = label)
  list(data = filter(data, !is_excluded), excl_list = excl_list)
}

# Do NOT toupper() before the fixed=TRUE 'E' check: toupper("None")="NONE" matches 'E',
# wrongly flagging compliant machines. NC codes are uppercase; "None" sentinel is not.
derive_compliance_flags <- function(reasons) {
  r_raw <- trimws(replace_na(as.character(reasons), ""))
  list(
    emissions_compliant = !grepl("E", r_raw, fixed = TRUE),
    admin_compliant     = !grepl("[ACPRX]", toupper(r_raw))
  )
}

fractional_year <- function(d) {
  yr         <- as.integer(format(d, "%Y"))
  doy        <- as.integer(format(d, "%j"))                        # %j: day-of-year (1-366)
  leap       <- (yr %% 4 == 0 & yr %% 100 != 0) | yr %% 400 == 0
  days_in_yr <- ifelse(leap, 366L, 365L)
  yr + (doy - 1L) / days_in_yr
}


# --- Load and normalise raw data ---

raw <- read.delim(INPUT_FILE, stringsAsFactors = FALSE, check.names = TRUE) |>
  as_tibble()
names(raw) <- gsub("\\.", "_", tolower(names(raw)))

audits_raw <- raw |>
  select(all_of(COLS_KEEP)) |>
  mutate(
    date = as.Date(trimws(date), format = "%d/%m/%Y"),
    zone = trimws(zone)
  )


# --- Apply exclusion filters ---

excl_list <- list()

out <- apply_exclusion(
  data        = audits_raw,
  excl_list   = excl_list,
  is_excluded = !tolower(trimws(audits_raw$initial_machinery_compliance)) %in% 
    c("compliant", "non-compliant"),
  label       = "No NRMM / non-machinery"
)
audits_machinery <- out$data
excl_list        <- out$excl_list

out <- apply_exclusion(
  data        = audits_machinery,
  excl_list   = excl_list,
  is_excluded = !audits_machinery$zone %in% ZONES_IN_SCOPE,
  label       = "Zone out of scope"
)
audits_zoned <- out$data
excl_list    <- out$excl_list

# Frequency table: valid values only, so modal is always "Constant" or "Variable"
engine_type_freq <- audits_zoned |>
  mutate(machine_type = trimws(machine_type), engine_type = trimws(engine_type)) |>
  filter(engine_type %in% c("Constant", "Variable")) |>
  count(machine_type, engine_type, name = "freq")

# Wide version for human inspection: rows = machine_type, columns = engine_type values
engine_type_freq_wide <- engine_type_freq |>
  pivot_wider(names_from = engine_type, values_from = freq, values_fill = 0)

writeLines(c("## Engine type frequency by machine type\n",
             kable(engine_type_freq_wide, format = "markdown"), ""),
           OUTPUT_MD)

# Modal engine_type per machine_type: one row per machine_type, highest freq wins
engine_type_modal <- engine_type_freq |>
  slice_max(freq, by = machine_type, n = 1, with_ties = FALSE) |>
  select(machine_type, engine_type_modal = engine_type)

# Impute any non-valid engine_type from modal lookup; generators excluded
#   (near-even split means no reliable modal); unresolved rows caught by exclusion filter below
audits_zoned_joined <- audits_zoned |>
  mutate(machine_type = trimws(machine_type), engine_type = trimws(engine_type)) |>
  left_join(engine_type_modal, by = "machine_type")

audits_zoned <- audits_zoned_joined |>
  mutate(
    engine_type       = if_else(
      !engine_type %in% c("Constant", "Variable") & tolower(machine_type) != "generator",
      engine_type_modal,
      engine_type
    ),
    engine_type_clean = engine_type
  ) |>
  select(-engine_type_modal)

out <- apply_exclusion(
  data        = audits_zoned,
  excl_list   = excl_list,
  is_excluded = !audits_zoned$engine_type_clean %in% c("Constant", "Variable"),
  label       = "Engine type unassignable"
)
audits_typed <- out$data
excl_list    <- out$excl_list

audits_typed <- audits_typed |>
  mutate(
    initial_stage = unname(STAGE_MAP[toupper(trimws(initial_emissions_stage))]),
    final_stage   = unname(STAGE_MAP[toupper(trimws(final_emissions_stage))])
  )

out <- apply_exclusion(
  data        = audits_typed,
  excl_list   = excl_list,
  is_excluded = is.na(audits_typed$initial_stage),
  label       = "Stage unresolvable"
)
audits_staged <- out$data
excl_list     <- out$excl_list

covid_flag <- audits_staged$date >= COVID_START & audits_staged$date <= COVID_END &
  (audits_staged$initial_retrofit_or_exemption %in% "Covid Exemption" |
   audits_staged$final_retrofit_or_exemption   %in% "Covid Exemption")

out <- apply_exclusion(
  data        = audits_staged,
  excl_list   = excl_list,
  is_excluded = covid_flag,
  label       = "COVID exempt"
)
audits_in_scope <- out$data
excl_list       <- out$excl_list


# --- Derive analytical fields ---

flags_init  <- derive_compliance_flags(audits_in_scope$initial_machinery_reasons)
flags_final <- derive_compliance_flags(audits_in_scope$final_machinery_reasons)

audits_measured <- audits_in_scope |>
  mutate(
    kw_power_trimmed               = trimws(kw_power),
    no_power_rating                = kw_power_trimmed == "" |
                                     toupper(kw_power_trimmed) == "UNIDENTIFIED" |
                                     is.na(suppressWarnings(as.numeric(kw_power_trimmed))),
    kw_power                       = suppressWarnings(as.numeric(kw_power_trimmed)),
    init_mach_emissions_compliant  = flags_init$emissions_compliant,
    init_mach_admin_compliant      = flags_init$admin_compliant,
    final_mach_emissions_compliant = flags_final$emissions_compliant,
    final_mach_admin_compliant     = flags_final$admin_compliant,
    cold_engaged                   = toupper(trimws(cold_engaged)) %in% c("YES", "Y", "V"),
    year                           = as.integer(format(date, "%Y")),
    date_frac                      = fractional_year(date),
    phase                          = case_when(
      date >= PHASE_A1_START & date <= PHASE_A1_END ~ "A1",
      date >= PHASE_A2_START & date <= PHASE_A2_END ~ "A2",
      date >= PHASE_B_START  & date <= PHASE_B_END  ~ "B",
      date >= PHASE_C_START                         ~ "C",
      TRUE                                          ~ NA_character_
    )
  ) |>
  select(-kw_power_trimmed)


# --- Assign groups and expand Variable_Speed ---

n_records_pre_group <- nrow(audits_measured)

audits_grouped <- audits_measured |>
  mutate(
    group_primary = case_when(
      engine_type_clean == "Constant"                             ~ "Constant_Speed",
      engine_type_clean == "Variable" & zone %in% c("CAZ", "OA") ~ "CAZ_Plus",
      engine_type_clean == "Variable" & zone == "GL"              ~ "Rest_of_London",
      engine_type_clean == "Variable" & zone == "P24"             ~ "Variable_Speed",
      TRUE                                                        ~ NA_character_
    ),
    vs_member = (engine_type_clean == "Variable")
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

exclusions <- bind_rows(excl_list) |>
  mutate(year = as.integer(format(date, "%Y")))


# --- 4. Verification ---

stopifnot(
  "init_mach_emissions_compliant has NAs" = !anyNA(audits$init_mach_emissions_compliant),
  "group_primary has unassigned records"  = !anyNA(audits_uniq$group_primary),
  "cold + warm != n_records_pre_group"    = (sum(audits_uniq$cold_engaged) +
                                              sum(!audits_uniq$cold_engaged)) == n_records_pre_group
)

# --- 5. Save outputs ---

saveRDS(audits,      file.path(INTERMEDIATE_DATA, "audits.rds"))
saveRDS(audits_uniq, file.path(INTERMEDIATE_DATA, "audits_uniq.rds"))
saveRDS(exclusions,  file.path(INTERMEDIATE_DATA, "exclusions.rds"))

# --- 6. Completion summary ---

cat(sprintf("%-15s  %s  [%s]\n", "audits",      paste(dim(audits),      collapse = " x "), class(audits)[1]))
cat(sprintf("%-15s  %s  [%s]\n", "audits_uniq", paste(dim(audits_uniq), collapse = " x "), class(audits_uniq)[1]))
cat(sprintf("%-15s  %s  [%s]\n", "exclusions",  paste(dim(exclusions),  collapse = " x "), class(exclusions)[1]))

# --- 7. Manifest ---

manifest_rows <- paste(
  "| step | object | file | class | dimensions | description |",
  "|------|--------|------|-------|------------|-------------|",
  sprintf("| 1 | audits | audits.rds | tbl_df | %s | All ingested audit records including Variable_Speed group duplication of CAZ_Plus and Rest_of_London rows. |",
          paste(dim(audits), collapse = " x ")),
  sprintf("| 1 | audits_uniq | audits_uniq.rds | tbl_df | %s | Unique audit records after all exclusion filters applied, one row per audit with group == group_primary. |",
          paste(dim(audits_uniq), collapse = " x ")),
  sprintf("| 1 | exclusions | exclusions.rds | tbl_df | %s | Excluded records with date, year, and excl_reason documenting each filter applied during ingestion. |",
          paste(dim(exclusions), collapse = " x ")),
  sep = "\n"
)
writeLines(manifest_rows, MANIFEST_FILE)
