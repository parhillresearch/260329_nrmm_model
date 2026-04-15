# 260413_step1_ingestion_v1.R
# NRMM LEZ Trend Analysis — Step 1: Data Ingestion and Preparation
# Produces: audits (tbl_df) -> intermediate/audits.rds
# Manifest: intermediate/manifest.md (created; cumulative thereafter)

library(tidyverse)

# ── Schema constants ────────────────────────────────────────────────────────────

INPUT_FILE    <- "audits.txt"
OUT_DIR       <- "intermediate"
OUTPUTS_DIR   <- "outputs"
MANIFEST_FILE <- file.path(OUT_DIR, "manifest.md")

# Columns to retain from raw file (Table 4); R converts spaces/special chars → dots
COLS_KEEP <- c(
  "Cold.Engaged", "Zone", "Date",
  "Initial.Site.Compliance", "Initial.Site.Reasons",
  "Final.Site.Compliance",   "Final.Site.Reasons",
  "Initial.Machinery.Compliance", "Initial.Machinery.Reasons",
  "Initial.Emissions.Stage",      "Initial.Retrofit.or.Exemption",
  "Final.Machinery.Compliance",   "Final.Machinery.Reasons",
  "Final.Emissions.Stage",        "Final.Retrofit.or.Exemption",
  "Machine.Type", "Engine.Type", "kW.Power"
)

# Machine types that are always Constant Speed (fixes mislabelled raw records)
CONSTANT_SPEED_TYPES <- c("Generator", "Hybrid Generator",
                           "Flywheel Generator", "Flybrid Generator")

ZONES_IN_SCOPE <- c("CAZ", "OA", "GL", "P24")

# Stage encoding (List 1): ZE/hybrid/other → 7
STAGE_MAP <- c(I = 1L, II = 2L, IIIA = 3L, IIIB = 4L, IV = 5L, V = 6L, ZE = 7L)

# Phase boundaries (Table 7)
PHASE_A1_START <- as.Date("2016-01-01"); PHASE_A1_END <- as.Date("2018-12-31")
PHASE_A2_START <- as.Date("2019-01-01"); PHASE_A2_END <- as.Date("2020-08-31")
PHASE_B_START  <- as.Date("2020-09-01"); PHASE_B_END  <- as.Date("2024-12-31")
PHASE_C_START  <- as.Date("2025-01-01")

COVID_START <- as.Date("2020-09-01"); COVID_END <- as.Date("2021-03-31")

# ── Helper functions ────────────────────────────────────────────────────────────

#' Parse date strings; emit message if any fail
#' @param x   character vector in dd/mm/yyyy format
parse_dates <- function(x) {
  d <- as.Date(trimws(x), format = "%d/%m/%Y")
  n_fail <- sum(is.na(d))
  if (n_fail > 0) message("  WARNING — unparseable dates: ", n_fail)
  d
}

#' Encode EU emissions stage strings to integer 1–7 (List 1)
#' Fixes known raw-data typos; any unrecognised value → NA (unresolvable)
#' @param x  character vector of stage labels
encode_stage <- function(x) {
  x <- trimws(x)
  x[x == "iIIB"] <- "IIIB"    # known raw typo
  x[x == "iV"]   <- "IV"      # known raw typo
  # ZE, hybrid, or any non-standard string that signals zero/alternative
  x[grepl("^ZE$|zero.emission|hybrid", x, ignore.case = TRUE)] <- "ZE"
  # Map; unmatched entries return NA
  stage <- STAGE_MAP[x]
  names(stage) <- NULL
  stage
}

#' Derive emissions_compliant and admin_compliant flags from reason-code string (List 2)
#' emissions_compliant = TRUE if no "E" present
#' admin_compliant     = TRUE if no codes other than E present (A/C/P/R/X absent)
#' @param reasons  character vector (may contain NA)
derive_compliance_flags <- function(reasons) {
  r <- toupper(trimws(replace_na(as.character(reasons), "")))
  list(
    emissions_compliant = !grepl("E", r, fixed = TRUE),
    admin_compliant     = !grepl("[ACPRX]", r)
  )
}

#' Assign model phase label from Date vector (Table 7)
#' @param d  Date vector
assign_phase <- function(d) {
  case_when(
    d >= PHASE_A1_START & d <= PHASE_A1_END ~ "A1",
    d >= PHASE_A2_START & d <= PHASE_A2_END ~ "A2",
    d >= PHASE_B_START  & d <= PHASE_B_END  ~ "B",
    d >= PHASE_C_START                      ~ "C",
    TRUE ~ NA_character_
  )
}

#' Convert Date to fractional year (exact day-of-year basis)
#' @param d  Date vector
fractional_year <- function(d) {
  yr          <- as.integer(format(d, "%Y"))
  doy         <- as.integer(format(d, "%j"))
  leap        <- (yr %% 4 == 0 & yr %% 100 != 0) | yr %% 400 == 0
  days_in_yr  <- ifelse(leap, 366L, 365L)
  yr + (doy - 1L) / days_in_yr
}

#' Append rows to intermediate/manifest.md (cumulative; creates file if absent)
#' @param entries  data.frame with columns object, file, class, dim, step, description
update_manifest <- function(entries) {
  rows <- entries |>
    mutate(line = paste0("| ", object, " | ", file, " | ", class,
                         " | ", dim, " | ", step, " | ", description, " |")) |>
    pull(line)

  if (!file.exists(MANIFEST_FILE)) {
    header <- c(
      "| object | file | class | dim | step | description |",
      "|--------|------|-------|-----|------|-------------|"
    )
    writeLines(c(header, rows), MANIFEST_FILE)
  } else {
    write(rows, file = MANIFEST_FILE, append = TRUE)
  }
}

#' Save a kable table to outputs/ and print to console
#' @param tbl   data frame / tibble
#' @param stem  filename stem (no extension)
save_table <- function(tbl, stem) {
  if (!dir.exists(OUTPUTS_DIR)) dir.create(OUTPUTS_DIR, recursive = TRUE)
  k <- knitr::kable(tbl, format = "markdown")
  cat(k, sep = "\n")
  writeLines(k, file.path(OUTPUTS_DIR, paste0(stem, ".md")))
  invisible(k)
}

# ── Ingestion pipeline ──────────────────────────────────────────────────────────

message("=== 260413_step1_ingestion_v1.R — NRMM Step 1 ===\n")

# ── 1. Import ───────────────────────────────────────────────────────────────────
raw <- read.delim(INPUT_FILE, stringsAsFactors = FALSE, check.names = TRUE) |>
  as_tibble()
names(raw) <- trimws(names(raw))
message("1. Raw rows: ", nrow(raw))

missing_cols <- setdiff(COLS_KEEP, names(raw))
if (length(missing_cols) > 0)
  warning("Expected columns absent from raw file: ", paste(missing_cols, collapse = ", "))

# ── 2. Select and rename to snake_case (Table 4) ────────────────────────────────
audits <- raw |>
  select(all_of(intersect(COLS_KEEP, names(raw)))) |>
  rename(
    cold_engaged                  = Cold.Engaged,
    zone                          = Zone,
    date                          = Date,
    initial_site_compliance       = Initial.Site.Compliance,
    initial_site_reasons          = Initial.Site.Reasons,
    final_site_compliance         = Final.Site.Compliance,
    final_site_reasons            = Final.Site.Reasons,
    initial_machinery_compliance  = Initial.Machinery.Compliance,
    initial_machinery_reasons     = Initial.Machinery.Reasons,
    initial_emissions_stage_raw   = Initial.Emissions.Stage,
    initial_retrofit_or_exemption = Initial.Retrofit.or.Exemption,
    final_machinery_compliance    = Final.Machinery.Compliance,
    final_machinery_reasons       = Final.Machinery.Reasons,
    final_emissions_stage_raw     = Final.Emissions.Stage,
    final_retrofit_or_exemption   = Final.Retrofit.or.Exemption,
    machine_type                  = Machine.Type,
    engine_type                   = Engine.Type,
    kw_power_raw                  = kW.Power
  )

message("2. Columns selected and renamed: ", ncol(audits))

# ── 3. Parse Date ────────────────────────────────────────────────────────────────
audits <- audits |> mutate(date = parse_dates(date))
message("3. Date parsed. Rows: ", nrow(audits))

# ── 4. Non-machinery exclusion ──────────────────────────────────────────────────
# Valid machinery records have Initial.Machinery.Compliance == "compliant" or
# "non-compliant" (case-insensitive). Everything else ("No NRMM", "Site Complete",
# "Baselining", "DECLINED AUDIT", etc.) is non-machinery and excluded.
audits <- audits |>
  mutate(imc_lower = tolower(trimws(initial_machinery_compliance)))

non_machinery <- audits |>
  filter(!imc_lower %in% c("compliant", "non-compliant")) |>
  count(initial_machinery_compliance, name = "n") |>
  arrange(desc(n))
message("\n4. Non-machinery exclusions (Initial.Machinery.Compliance not compliant/non-compliant):")
print(non_machinery)
message("   Total excluded: ", sum(non_machinery$n))

audits <- audits |>
  filter(imc_lower %in% c("compliant", "non-compliant")) |>
  select(-imc_lower)
message("   Retained: ", nrow(audits))

# ── 5. Zone filter ──────────────────────────────────────────────────────────────
audits <- audits |> mutate(zone = trimws(zone))

n_before  <- nrow(audits)
zone_excl <- audits |>
  filter(!zone %in% ZONES_IN_SCOPE) |>
  count(zone, name = "n") |>
  arrange(desc(n))
message("\n5. Zone exclusions (BCP, other):")
print(zone_excl)
audits <- audits |> filter(zone %in% ZONES_IN_SCOPE)
message("   Removed ", n_before - nrow(audits), "; retained ", nrow(audits))

# ── 6. Engine type classification and group assignment (Table 1) ─────────────────
audits <- audits |>
  mutate(
    machine_type = trimws(machine_type),
    engine_type  = trimws(engine_type),
    # Override generator-family machine types to Constant unconditionally
    engine_type_clean = if_else(
      machine_type %in% CONSTANT_SPEED_TYPES, "Constant", engine_type
    ),
    # Fill remaining blanks with Variable (restores A1 records with empty field)
    engine_type_clean = if_else(
      trimws(engine_type_clean) == "", "Variable", engine_type_clean
    )
  )

n_overridden <- sum(audits$machine_type %in% CONSTANT_SPEED_TYPES &
                      audits$engine_type != "Constant", na.rm = TRUE)
message("\n6. Engine type → Constant override (generator-family types): ", n_overridden)

unassign_excl <- audits |>
  filter(!engine_type_clean %in% c("Constant", "Variable")) |>
  count(engine_type_clean, name = "n") |>
  arrange(desc(n))
message("   Unassignable engine types excluded:")
print(unassign_excl)

n_before <- nrow(audits)
audits   <- audits |> filter(engine_type_clean %in% c("Constant", "Variable"))
message("   Removed ", n_before - nrow(audits), "; retained ", nrow(audits))

# Assign machine group (Table 1)
audits <- audits |>
  mutate(
    group = case_when(
      engine_type_clean == "Constant"                               ~ "Constant_Speed",
      engine_type_clean == "Variable" & zone %in% c("CAZ", "OA")   ~ "CAZ_Plus",
      engine_type_clean == "Variable" & zone == "GL"                ~ "Rest_of_London",
      engine_type_clean == "Variable" & zone == "P24"               ~ "Variable_Speed",
      TRUE ~ NA_character_
    )
  )

# ── 7. kW Power parsing (Table 4) ───────────────────────────────────────────────
audits <- audits |>
  mutate(
    kw_power        = suppressWarnings(as.numeric(trimws(kw_power_raw))),
    no_power_rating = trimws(kw_power_raw) == "" |
                      toupper(trimws(kw_power_raw)) == "UNIDENTIFIED" |
                      is.na(suppressWarnings(as.numeric(trimws(kw_power_raw))))
  )
message("\n7. kW Power — no_power_rating flagged: ", sum(audits$no_power_rating))

# ── 8. Emissions stage encoding (List 1) ────────────────────────────────────────
audits <- audits |>
  mutate(
    initial_stage = encode_stage(initial_emissions_stage_raw),
    final_stage   = encode_stage(final_emissions_stage_raw)
  )

n_before       <- nrow(audits)
unresolvable   <- audits |>
  filter(is.na(initial_stage)) |>
  count(initial_emissions_stage_raw, name = "n") |>
  arrange(desc(n))
message("\n8. Unresolvable Initial Emissions Stage (excluded):")
print(unresolvable)
audits <- audits |> filter(!is.na(initial_stage))
message("   Removed ", n_before - nrow(audits), "; retained ", nrow(audits))

# ── 9. Compliance flags (List 2) ────────────────────────────────────────────────
# Derive for initial/final machinery reasons (site reasons available in columns)
init_mach_flags  <- derive_compliance_flags(audits$initial_machinery_reasons)
final_mach_flags <- derive_compliance_flags(audits$final_machinery_reasons)

audits <- audits |>
  mutate(
    init_mach_emissions_compliant  = init_mach_flags$emissions_compliant,
    init_mach_admin_compliant      = init_mach_flags$admin_compliant,
    final_mach_emissions_compliant = final_mach_flags$emissions_compliant,
    final_mach_admin_compliant     = final_mach_flags$admin_compliant
  )
message("\n9. Compliance flags derived from reason codes (List 2).")
message("   init_mach_emissions_compliant TRUE : ", sum(audits$init_mach_emissions_compliant))
message("   init_mach_emissions_compliant FALSE: ", sum(!audits$init_mach_emissions_compliant))

# ── 10. COVID exemption filter ──────────────────────────────────────────────────
audits <- audits |>
  mutate(
    covid_exempt = date >= COVID_START & date <= COVID_END &
      (grepl("covid", tolower(replace_na(initial_retrofit_or_exemption, ""))) |
       grepl("covid", tolower(replace_na(final_retrofit_or_exemption,   ""))))
  )

n_before <- nrow(audits)
message("\n10. COVID-exempt records (window 1.9.2020–31.3.2021, exemption field): ",
        sum(audits$covid_exempt))
audits <- audits |> filter(!covid_exempt) |> select(-covid_exempt)
message("    Retained: ", nrow(audits))

# ── 11. Temporal fields and phase assignment (Table 7) ──────────────────────────
audits <- audits |>
  mutate(
    year      = as.integer(format(date, "%Y")),
    date_frac = fractional_year(date),
    phase     = assign_phase(date)
  )

n_na_phase <- sum(is.na(audits$phase))
if (n_na_phase > 0)
  message("\nFLAG: ", n_na_phase,
          " records have NA phase (outside A1/A2/B/C boundaries) — inspect before Step 2.")

# ── 12. Enforcement upgrade flag ────────────────────────────────────────────────
audits <- audits |>
  mutate(
    enforcement_upgrade = !is.na(initial_stage) & !is.na(final_stage) &
                          final_stage > initial_stage
  )
message("\n11. Enforcement upgrades (final_stage > initial_stage): ",
        sum(audits$enforcement_upgrade))

# ── 13. cold_engaged boolean ────────────────────────────────────────────────────
audits <- audits |>
  mutate(cold_engaged = toupper(trimws(cold_engaged)) %in% c("YES", "Y", "V"))

message("12. Cold-engaged: ", sum(audits$cold_engaged),
        " | Warm: ", sum(!audits$cold_engaged))

# ── Sub-task 4: Record counts by group and phase ─────────────────────────────────

message("\n=== RECORD COUNTS BY GROUP AND PHASE (stop-and-report) ===\n")

# All records
counts_all <- audits |>
  count(group, phase) |>
  pivot_wider(names_from = phase, values_from = n, values_fill = 0L) |>
  mutate(total = rowSums(across(where(is.integer)))) |>
  arrange(group)

message("All records (cold + warm):")
save_table(counts_all, "260413_step1_counts_all")

# Cold-engaged
counts_cold <- audits |>
  filter(cold_engaged) |>
  count(group, phase) |>
  pivot_wider(names_from = phase, values_from = n, values_fill = 0L) |>
  mutate(total = rowSums(across(where(is.integer)))) |>
  arrange(group)

message("\nCold-engaged only:")
save_table(counts_cold, "260413_step1_counts_cold")

# Warm
counts_warm <- audits |>
  filter(!cold_engaged) |>
  count(group, phase) |>
  pivot_wider(names_from = phase, values_from = n, values_fill = 0L) |>
  mutate(total = rowSums(across(where(is.integer)))) |>
  arrange(group)

message("\nWarm-engaged only:")
save_table(counts_warm, "260413_step1_counts_warm")

# Phase C / P24 records
counts_p24 <- audits |>
  filter(phase == "C") |>
  count(group, cold_engaged) |>
  pivot_wider(names_from = cold_engaged, values_from = n,
              values_fill = 0L, names_prefix = "cold_") |>
  arrange(group)

message("\nPhase C (P24) records by group and engagement:")
save_table(counts_p24, "260413_step1_counts_p24")

p24_dates <- audits |> filter(phase == "C") |> summarise(
  earliest = min(date), latest = max(date), n = n()
)
message("\nP24 temporal extent: ", p24_dates$earliest,
        " to ", p24_dates$latest, " (n = ", p24_dates$n, ")")
message("Latest P24 date will be used as Phase C initialisation point in Step 5.")

# Anomaly flags
message("\nANOMALY CHECK — cells with n < 30 (all records, cold + warm):")
small_cells <- audits |> count(group, phase) |> filter(n < 30)
if (nrow(small_cells) == 0) {
  message("  None.")
} else {
  print(small_cells)
}

message("\nANOMALY CHECK — NA phase records: ", n_na_phase)

# ── Save outputs ─────────────────────────────────────────────────────────────────

if (!dir.exists(OUT_DIR)) dir.create(OUT_DIR, recursive = TRUE)

saveRDS(audits, file.path(OUT_DIR, "audits.rds"))
message("\nSaved: ", file.path(OUT_DIR, "audits.rds"))

# Manifest update
manifest_entry <- tibble(
  object      = "audits",
  file        = "intermediate/audits.rds",
  class       = "tbl_df",
  dim         = paste0(nrow(audits), " x ", ncol(audits)),
  step        = "step1",
  description = paste0(
    "Clean filtered audit records 2016+: in-scope zones (CAZ/OA/GL/P24), machinery only, ",
    "engine-type classified, stages encoded, COVID exempt removed, group + phase assigned (A1/A2/B/C)"
  )
)
update_manifest(manifest_entry)
message("Manifest updated: ", MANIFEST_FILE)

# Console summary of saved objects
message("\n=== OBJECTS SAVED (step 1) ===")
message(sprintf("  %-10s  %-7s  %s", "object", "class", "dim"))
message(sprintf("  %-10s  %-7s  %d x %d", "audits", "tbl_df", nrow(audits), ncol(audits)))

sessionInfo()
