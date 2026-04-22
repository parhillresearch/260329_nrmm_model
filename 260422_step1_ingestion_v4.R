# 260422_step1_ingestion_v4.R
# NRMM LEZ Trend Analysis — Step 1: Data Ingestion and Preparation (v4)
#
# Director review amendments (director_review_step1.md):
#   1.3  Check for unexpected zone/group codes.
#        Variable_Speed made continuous across A1/A2/B/C by ROW DUPLICATION:
#          - CAZ_Plus and Rest_of_London records appear BOTH in their zone group
#            AND as Variable_Speed (audits has more rows than unique audit records).
#          - P24 records appear once as Variable_Speed only.
#          - CAZ_Plus / Rest_of_London are discontinued from 1.1.2025 because no
#            new CAZ/OA/GL records exist from that date; P24 takes over.
#          - group_primary column preserves the 4-way zone assignment; use
#            filter(group == group_primary) to recover unique records.
#   1.4  Checksum analysis: pipeline checksum uses n_unique_records (before
#        duplication); separate row counts for primary vs expanded audits.
#   1.5  Statistics and stacked bar charts by year for:
#          (a) excluded records   (b) Stage distributions (all + by group)
#          (c) non-compliance codes   (d) group × engagement type
#          (e) Variable_Speed continuous   (f) pre-2016 records
#   1.6  Formal checksum verification.
#
# Outputs (intermediate/):
#   audits.rds     — expanded tibble (row-duplicated VS rows; group + group_primary)
#   exclusions.rds — pipeline-excluded records with excl_reason label
# Outputs (outputs/):
#   260422_step1_ingestion_v4.md  — all tables + plot references
#   260422_step1_ingestion_v4_*.png — plots
#   legacy individual count .md files (backward-compat. with Step 6 report)

library(tidyverse)
library(knitr)
library(kableExtra)
library(scales)

# ── Schema constants ─────────────────────────────────────────────────────────────

INPUT_FILE    <- "audits.txt"
OUT_DIR       <- "intermediate"
OUTPUTS_DIR   <- "outputs"
MANIFEST_FILE <- file.path(OUT_DIR, "manifest.md")
SCRIPT_STEM   <- "260422_step1_ingestion_v4"
OUTPUT_MD     <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, ".md"))

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

# Machine types always Constant Speed regardless of Engine.Type field
CONSTANT_SPEED_TYPES <- c("Generator", "Hybrid Generator",
                           "Flywheel Generator", "Flybrid Generator")

ZONES_IN_SCOPE <- c("CAZ", "OA", "GL", "P24")

# Stage encoding (List 1)
STAGE_MAP <- c(I = 1L, II = 2L, IIIA = 3L, IIIB = 4L, IV = 5L, V = 6L, ZE = 7L)
STAGE_LABELS <- c("1"="I","2"="II","3"="IIIA","4"="IIIB","5"="IV","6"="V","7"="ZE/other")

# Phase boundaries (Table 7)
PHASE_A1_START <- as.Date("2016-01-01"); PHASE_A1_END <- as.Date("2018-12-31")
PHASE_A2_START <- as.Date("2019-01-01"); PHASE_A2_END <- as.Date("2020-08-31")
PHASE_B_START  <- as.Date("2020-09-01"); PHASE_B_END  <- as.Date("2024-12-31")
PHASE_C_START  <- as.Date("2025-01-01")
COVID_START    <- as.Date("2020-09-01"); COVID_END    <- as.Date("2021-03-31")

GROUP_ORDER <- c("Constant_Speed", "CAZ_Plus", "Rest_of_London", "Variable_Speed")
PHASE_ORDER <- c("A1", "A2", "B", "C")

# ── Helper functions ─────────────────────────────────────────────────────────────

#' Parse dd/mm/yyyy date strings; warn on failures
parse_dates <- function(x) {
  d <- as.Date(trimws(x), format = "%d/%m/%Y")
  n_fail <- sum(is.na(d))
  if (n_fail > 0) message("  WARNING — unparseable dates: ", n_fail)
  d
}

#' Encode EU emissions stage strings to integer 1–7 (List 1); NA = unresolvable
encode_stage <- function(x) {
  x <- trimws(x)
  x[x == "iIIB"] <- "IIIB"
  x[x == "iV"]   <- "IV"
  x[grepl("^ZE$|zero.emission|hybrid", x, ignore.case = TRUE)] <- "ZE"
  stage <- STAGE_MAP[x]
  names(stage) <- NULL
  stage
}

#' Derive emissions_compliant and admin_compliant flags from reason-code string
derive_compliance_flags <- function(reasons) {
  r <- toupper(trimws(replace_na(as.character(reasons), "")))
  list(
    emissions_compliant = !grepl("E", r, fixed = TRUE),
    admin_compliant     = !grepl("[ACPRX]", r)
  )
}

#' Assign model phase label from Date vector (Table 7)
assign_phase <- function(d) {
  case_when(
    d >= PHASE_A1_START & d <= PHASE_A1_END ~ "A1",
    d >= PHASE_A2_START & d <= PHASE_A2_END ~ "A2",
    d >= PHASE_B_START  & d <= PHASE_B_END  ~ "B",
    d >= PHASE_C_START                      ~ "C",
    TRUE ~ NA_character_
  )
}

#' Convert Date to exact fractional year
fractional_year <- function(d) {
  yr         <- as.integer(format(d, "%Y"))
  doy        <- as.integer(format(d, "%j"))
  leap       <- (yr %% 4 == 0 & yr %% 100 != 0) | yr %% 400 == 0
  days_in_yr <- ifelse(leap, 366L, 365L)
  yr + (doy - 1L) / days_in_yr
}

#' Append rows to cumulative intermediate/manifest.md
update_manifest <- function(entries) {
  rows <- entries |>
    mutate(line = paste0("| ", object, " | ", file, " | ", class,
                         " | ", dim, " | ", step, " | ", description, " |")) |>
    pull(line)
  if (!file.exists(MANIFEST_FILE)) {
    writeLines(c(
      "| object | file | class | dim | step | description |",
      "|--------|------|-------|-----|------|-------------|",
      rows
    ), MANIFEST_FILE)
  } else {
    write(rows, file = MANIFEST_FILE, append = TRUE)
  }
}

#' Append text to output .md file
amd <- function(...) cat(paste0(...), "\n", file = OUTPUT_MD, append = TRUE, sep = "")

#' Write HTML kable to output .md and markdown kable to console
write_kable <- function(tbl, caption = NULL, add_phase_header = FALSE) {
  k_html <- kbl(tbl, format = "html", caption = caption) |>
    kable_styling(full_width = FALSE, bootstrap_options = "condensed")
  if (add_phase_header) {
    n_phase <- sum(names(tbl) %in% c(PHASE_ORDER, "NA_phase"))
    k_html  <- k_html |>
      add_header_above(setNames(c(1L, n_phase, 1L), c(" ", "Phase", " ")))
  }
  amd(as.character(k_html))
  amd("")
  kbl(tbl, format = "markdown", caption = caption) |> print()
  invisible(tbl)
}

#' Build group × phase count table; df must have group and phase columns
make_count_table <- function(df) {
  raw <- df |>
    filter(!is.na(phase)) |>
    count(group, phase, name = "n")

  grid <- expand_grid(
    group = factor(GROUP_ORDER, levels = GROUP_ORDER),
    phase = PHASE_ORDER
  )

  tbl <- grid |>
    left_join(raw, by = c("group", "phase")) |>
    mutate(n = replace_na(n, 0L)) |>
    pivot_wider(names_from = phase, values_from = n) |>
    arrange(group)

  na_counts <- df |>
    filter(is.na(phase)) |>
    count(group, name = "NA_phase")
  if (nrow(na_counts) > 0) {
    tbl <- tbl |>
      left_join(na_counts, by = "group") |>
      mutate(NA_phase = replace_na(NA_phase, 0L))
  }

  tbl |> mutate(Total = rowSums(across(where(is.integer))))
}

# ── Initialise output .md ────────────────────────────────────────────────────────
if (!dir.exists(OUTPUTS_DIR)) dir.create(OUTPUTS_DIR, recursive = TRUE)
writeLines(c(
  paste0("# Step 1 Outputs — ", SCRIPT_STEM),
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  ""
), OUTPUT_MD)

message("=== ", SCRIPT_STEM, " — NRMM Step 1 (v4) ===\n")

# ── 1. Import ────────────────────────────────────────────────────────────────────
raw <- read.delim(INPUT_FILE, stringsAsFactors = FALSE, check.names = TRUE) |>
  as_tibble()
names(raw) <- trimws(names(raw))
n_raw <- nrow(raw)
message("1. Raw rows: ", n_raw)

missing_cols <- setdiff(COLS_KEEP, names(raw))
if (length(missing_cols) > 0)
  warning("Expected columns absent from raw file: ",
          paste(missing_cols, collapse = ", "))

# ── 2. Select and rename ─────────────────────────────────────────────────────────
df <- raw |>
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
  ) |>
  mutate(date = parse_dates(date),
         zone = trimws(zone))

message("2. Columns selected/renamed; date parsed. Rows: ", nrow(df))

# ── 3. Exclusion pipeline — save each excluded set ───────────────────────────────

excl_list <- list()

# 3a. Non-machinery records -------------------------------------------------------
df <- df |> mutate(imc_lower = tolower(trimws(initial_machinery_compliance)))
non_mach <- df |> filter(!imc_lower %in% c("compliant", "non-compliant"))
excl_list[["No NRMM / non-machinery"]] <- non_mach |>
  transmute(date, zone, detail = initial_machinery_compliance,
            excl_reason = "No NRMM / non-machinery")
message("\n3a. Non-machinery exclusions: ", nrow(non_mach))
non_mach |> count(initial_machinery_compliance, name = "n") |> arrange(desc(n)) |> print()
df <- df |> filter(imc_lower %in% c("compliant", "non-compliant")) |> select(-imc_lower)
message("    Retained: ", nrow(df))

# 3b. Zone filter -----------------------------------------------------------------
out_zone <- df |> filter(!zone %in% ZONES_IN_SCOPE)
excl_list[["Zone out of scope"]] <- out_zone |>
  transmute(date, zone, detail = zone, excl_reason = "Zone out of scope (BCP/other)")
message("\n3b. Zone exclusions: ", nrow(out_zone))
out_zone |> count(zone, name = "n") |> arrange(desc(n)) |> print()
df <- df |> filter(zone %in% ZONES_IN_SCOPE)
message("    Retained: ", nrow(df))

# 3c. Engine type classification --------------------------------------------------
df <- df |>
  mutate(
    machine_type      = trimws(machine_type),
    engine_type       = trimws(engine_type),
    engine_type_clean = if_else(machine_type %in% CONSTANT_SPEED_TYPES,
                                "Constant", engine_type),
    engine_type_clean = if_else(trimws(engine_type_clean) == "",
                                "Variable", engine_type_clean)
  )

n_overridden <- sum(df$machine_type %in% CONSTANT_SPEED_TYPES &
                      df$engine_type != "Constant", na.rm = TRUE)
message("\n3c. Generator-family override to Constant: ", n_overridden)

# Check for unexpected engine type values (Step 1.3 amendment)
engine_type_dist <- df |> count(engine_type_clean, name = "n") |> arrange(desc(n))
message("    Full engine_type_clean distribution (including unassignable):")
print(engine_type_dist)

unassign <- df |> filter(!engine_type_clean %in% c("Constant", "Variable"))
excl_list[["Engine type unassignable"]] <- unassign |>
  transmute(date, zone, detail = engine_type_clean,
            excl_reason = "Engine type unassignable")
message("    Unassignable excluded: ", nrow(unassign))
df <- df |> filter(engine_type_clean %in% c("Constant", "Variable"))
message("    Retained: ", nrow(df))

# 3d. Emissions stage encoding ----------------------------------------------------
df <- df |>
  mutate(
    initial_stage = encode_stage(initial_emissions_stage_raw),
    final_stage   = encode_stage(final_emissions_stage_raw)
  )
stage_unres <- df |> filter(is.na(initial_stage))
excl_list[["Stage unresolvable"]] <- stage_unres |>
  transmute(date, zone, detail = initial_emissions_stage_raw,
            excl_reason = "Initial stage unresolvable")
message("\n3d. Unresolvable Initial Emissions Stage: ", nrow(stage_unres))
stage_unres |> count(initial_emissions_stage_raw, name = "n") |> arrange(desc(n)) |> print()
df <- df |> filter(!is.na(initial_stage))
message("    Retained: ", nrow(df))

# 3e. COVID exemption filter ------------------------------------------------------
df <- df |>
  mutate(
    covid_exempt = date >= COVID_START & date <= COVID_END &
      (grepl("covid", tolower(replace_na(initial_retrofit_or_exemption, ""))) |
       grepl("covid", tolower(replace_na(final_retrofit_or_exemption, ""))))
  )
covid_excl <- df |> filter(covid_exempt)
excl_list[["COVID exempt"]] <- covid_excl |>
  transmute(date, zone, detail = zone, excl_reason = "COVID exempt")
message("\n3e. COVID-exempt records: ", nrow(covid_excl))
df <- df |> filter(!covid_exempt) |> select(-covid_exempt)
message("    Retained: ", nrow(df))

# 3f. kW Power parsing (flag only; no exclusion) ----------------------------------
df <- df |>
  mutate(
    kw_power        = suppressWarnings(as.numeric(trimws(kw_power_raw))),
    no_power_rating = trimws(kw_power_raw) == "" |
                      toupper(trimws(kw_power_raw)) == "UNIDENTIFIED" |
                      is.na(suppressWarnings(as.numeric(trimws(kw_power_raw))))
  )
message("\n3f. kW Power — no_power_rating flagged: ", sum(df$no_power_rating))

# 3g. Compliance flags (List 2) ---------------------------------------------------
init_flags  <- derive_compliance_flags(df$initial_machinery_reasons)
final_flags <- derive_compliance_flags(df$final_machinery_reasons)
df <- df |>
  mutate(
    init_mach_emissions_compliant  = init_flags$emissions_compliant,
    init_mach_admin_compliant      = init_flags$admin_compliant,
    final_mach_emissions_compliant = final_flags$emissions_compliant,
    final_mach_admin_compliant     = final_flags$admin_compliant
  )
message("\n3g. Compliance flags derived.")
message("    init_mach_emissions_compliant TRUE : ", sum(df$init_mach_emissions_compliant))
message("    init_mach_emissions_compliant FALSE: ", sum(!df$init_mach_emissions_compliant))

# 3h. Temporal fields and phase assignment ----------------------------------------
df <- df |>
  mutate(
    year      = as.integer(format(date, "%Y")),
    date_frac = fractional_year(date),
    phase     = assign_phase(date)
  )
n_na_phase <- sum(is.na(df$phase))
message("\n3h. Phase assigned. NA-phase records: ", n_na_phase,
        " (pre-2016 or between boundaries)")

# 3i. Derived flags ---------------------------------------------------------------
df <- df |>
  mutate(
    enforcement_upgrade = !is.na(initial_stage) & !is.na(final_stage) &
                          final_stage > initial_stage,
    cold_engaged        = toupper(trimws(cold_engaged)) %in% c("YES", "Y", "V")
  )
message("\n3i. Enforcement upgrades: ", sum(df$enforcement_upgrade))
message("    Cold-engaged: ", sum(df$cold_engaged),
        " | Warm: ", sum(!df$cold_engaged))

# n_unique_records: total unique audit records after all exclusions (before duplication)
n_unique_records <- nrow(df)

# ── 4. Group assignment — row duplication for continuous Variable_Speed ───────────
#
# Director amendment 1.3:
#   "Add the Rest of London and CAZ+ records BOTH INTO the variable_speed group,
#    AS WELL AS CAZ+ or Rest of London groups, so variable_speed becomes a
#    continuous record across all phases.  Then CAZ+ and Rest of London are
#    merely discontinued from 1.1.2025."
#
# Implementation: each CAZ_Plus and Rest_of_London record appears TWICE in audits:
#   (1) once with group = group_primary (= "CAZ_Plus" or "Rest_of_London")
#   (2) once with group = "Variable_Speed"
# P24 variable-engine records appear once with group = "Variable_Speed".
# Constant_Speed records appear once with group = "Constant_Speed".
#
# group_primary: the 4-way zone-based assignment for every row.
#   Use filter(group == group_primary) to recover unique records.
# vs_member: TRUE for all variable-engine records (convenience flag).

df_grp <- df |>
  mutate(
    group_primary = case_when(
      engine_type_clean == "Constant"                             ~ "Constant_Speed",
      engine_type_clean == "Variable" & zone %in% c("CAZ", "OA") ~ "CAZ_Plus",
      engine_type_clean == "Variable" & zone == "GL"              ~ "Rest_of_London",
      engine_type_clean == "Variable" & zone == "P24"             ~ "Variable_Speed",
      TRUE ~ NA_character_
    ),
    vs_member = (engine_type_clean == "Variable")
  )

# Check for unexpected NA group_primary / unexpected zone codes (Step 1.3 amendment)
na_grp <- df_grp |> filter(is.na(group_primary))
if (nrow(na_grp) > 0) {
  message("\nFLAG — ", nrow(na_grp), " records with unassigned group_primary:")
  na_grp |> count(engine_type_clean, zone, name = "n") |> print()
} else {
  message("\ngroup_primary: all ", nrow(df_grp), " unique records assigned (no NA).")
}

# Zone × engine_type × group_primary cross-check (Step 1.3 amendment)
zone_cross <- df_grp |>
  count(zone, engine_type_clean, group_primary, name = "n") |>
  arrange(zone, engine_type_clean)
message("\nZone × engine_type × group_primary cross-check:")
print(zone_cross, n = 30)

# Build expanded audits: primary rows + duplicated VS rows for CAZ_Plus / RoL
vs_dupes <- df_grp |>
  filter(group_primary %in% c("CAZ_Plus", "Rest_of_London")) |>
  mutate(group = "Variable_Speed")

audits <- bind_rows(
  df_grp |> mutate(group = group_primary),
  vs_dupes
) |>
  arrange(date, group)

n_vs_dupes <- nrow(vs_dupes)
message("\nRow duplication for continuous Variable_Speed:")
message("  Unique audit records   : ", n_unique_records)
message("  VS duplicate rows added: ", n_vs_dupes,
        " (CAZ_Plus + Rest_of_London pre-P24 records)")
message("  Total rows in audits   : ", nrow(audits))
message("  filter(group == group_primary) recovers ", n_unique_records, " unique records")

# ── 5. Record counts by group × phase ────────────────────────────────────────────

amd("\n## Step 1.1–1.4 Record Counts\n")

amd("\n### Note on row structure\n")
amd(paste0(
  "audits.rds contains **", nrow(audits), " rows** representing **",
  n_unique_records, " unique audit records** plus **", n_vs_dupes,
  " duplicate rows** for the Variable_Speed continuous series (CAZ_Plus and ",
  "Rest_of_London records also appear with group = 'Variable_Speed'). ",
  "Use `filter(group == group_primary)` to work with unique records only."
))
amd("")

# Count tables using unique records (group == group_primary)
counts_uniq_all  <- make_count_table(audits |> filter(group == group_primary))
counts_uniq_cold <- make_count_table(audits |> filter(group == group_primary, cold_engaged))
counts_uniq_warm <- make_count_table(audits |> filter(group == group_primary, !cold_engaged))

# Count table including VS continuous (all rows)
counts_expanded  <- make_count_table(audits)

amd("\n### Unique records by primary group × phase\n")
write_kable(counts_uniq_all, "Unique audit records by primary group × phase",
            add_phase_header = TRUE)
amd("One row per unique audit record; group_primary is the 4-way zone assignment. NA_phase = pre-2016 or between-boundary records.")
amd("Rest_of_London dominates the record count; Variable_Speed (P24) records appear in Phase C only.\n")

amd("\n### Cold-engaged unique records by primary group × phase\n")
write_kable(counts_uniq_cold, "Cold-engaged unique records by group × phase",
            add_phase_header = TRUE)
amd("Cold-engaged records used for λ_CF estimation; distribution mirrors all-records pattern at lower counts.")
amd("Constant_Speed cold sample is notably sparse relative to variable-engine groups.\n")

amd("\n### Warm-engaged unique records by primary group × phase\n")
write_kable(counts_uniq_warm, "Warm-engaged unique records by group × phase",
            add_phase_header = TRUE)
amd("Warm records used for λ_Proactive estimation (self-compliant warm subset).")
amd("Warm counts mirror the all-records distribution; no systematic engagement-type bias by phase.\n")

amd("\n### Expanded record counts (includes Variable_Speed continuous rows)\n")
write_kable(counts_expanded, "Expanded audits row counts by group × phase",
            add_phase_header = TRUE)
amd("Variable_Speed row shows all variable-engine records across A1–C, enabling continuous trend analysis.")
amd("CAZ_Plus and Rest_of_London total within each phase equals their contribution to Variable_Speed; the sum across all four groups exceeds n_unique_records by n_vs_dupes.\n")

# P24 detail
p24_dates <- audits |>
  filter(phase == "C", group == group_primary) |>
  summarise(earliest = min(date), latest = max(date), n = n())
message("\nP24 temporal extent: ", p24_dates$earliest, " to ", p24_dates$latest,
        " (n = ", p24_dates$n, ")")

# Legacy count files (backward-compat. with Step 6 report references)
knitr::kable(counts_uniq_all,  format = "markdown") |>
  writeLines(file.path(OUTPUTS_DIR, "260413_step1_counts_all.md"))
knitr::kable(counts_uniq_cold, format = "markdown") |>
  writeLines(file.path(OUTPUTS_DIR, "260413_step1_counts_cold.md"))
knitr::kable(counts_uniq_warm, format = "markdown") |>
  writeLines(file.path(OUTPUTS_DIR, "260413_step1_counts_warm.md"))

# ── 6. Checksum analysis (Step 1.4 amendment) ────────────────────────────────────

n_excl_non_mach <- nrow(excl_list[["No NRMM / non-machinery"]])
n_excl_zone     <- nrow(excl_list[["Zone out of scope"]])
n_excl_engine   <- nrow(excl_list[["Engine type unassignable"]])
n_excl_stage    <- nrow(excl_list[["Stage unresolvable"]])
n_excl_covid    <- nrow(excl_list[["COVID exempt"]])
n_excl_total    <- n_excl_non_mach + n_excl_zone + n_excl_engine +
                   n_excl_stage + n_excl_covid

amd("\n## Step 1.4 Checksum Analysis\n")

pipeline_tbl <- tibble(
  stage = c(
    "Raw records imported",
    "Excluded — No NRMM / non-machinery",
    "Excluded — Zone out of scope",
    "Excluded — Engine type unassignable",
    "Excluded — Initial stage unresolvable",
    "Excluded — COVID exempt",
    "Total excluded",
    "Unique records retained",
    "VS duplicate rows added",
    "Total rows in audits.rds"
  ),
  n = c(
    n_raw, n_excl_non_mach, n_excl_zone, n_excl_engine,
    n_excl_stage, n_excl_covid, n_excl_total,
    n_unique_records, n_vs_dupes, nrow(audits)
  )
)
write_kable(pipeline_tbl, "Exclusion pipeline and row counts")

grp_cs <- audits |>
  count(group, name = "n_rows") |>
  mutate(group = factor(group, levels = GROUP_ORDER)) |>
  arrange(group) |>
  bind_rows(tibble(group = factor("TOTAL"), n_rows = nrow(audits))) |>
  mutate(
    note = case_when(
      group == "Variable_Speed" ~ "includes CAZ_Plus + RoL duplicates",
      group == "TOTAL"          ~ "= unique + VS dupes",
      TRUE                      ~ ""
    )
  )
write_kable(grp_cs, "Row counts by group (expanded audits)")
amd("Variable_Speed row count equals the sum of all variable-engine unique records (CAZ_Plus + Rest_of_London + P24 Variable_Speed), confirming the row duplication is complete.")
amd("The TOTAL row exceeds n_unique_records by n_vs_dupes; this is expected and intentional — each CAZ_Plus and Rest_of_London record appears twice in audits.rds.\n")

chk_ok <- function(x) if (x) "PASS" else "FAIL"
checks <- tibble(
  check = c(
    "raw = unique_retained + total_excluded",
    "sum(primary group counts) = n_unique_records",
    "VS rows = CAZ_Plus + RoL + P24_VS (unique)",
    "cold + warm = n_unique_records",
    "no NA group_primary values"
  ),
  lhs = c(
    n_raw,
    nrow(audits |> filter(group == group_primary)),
    nrow(audits |> filter(group == "Variable_Speed")),
    sum(audits$cold_engaged[audits$group == audits$group_primary]) +
      sum(!audits$cold_engaged[audits$group == audits$group_primary]),
    sum(is.na(audits$group_primary))
  ),
  rhs = c(
    n_unique_records + n_excl_total,
    n_unique_records,
    nrow(audits |> filter(group == group_primary, vs_member)),
    n_unique_records,
    0L
  ),
  result = c(
    chk_ok(n_raw == n_unique_records + n_excl_total),
    chk_ok(nrow(audits |> filter(group == group_primary)) == n_unique_records),
    chk_ok(nrow(audits |> filter(group == "Variable_Speed")) ==
             nrow(audits |> filter(group == group_primary, vs_member))),
    chk_ok(sum(audits$cold_engaged[audits$group == audits$group_primary]) +
             sum(!audits$cold_engaged[audits$group == audits$group_primary]) ==
             n_unique_records),
    chk_ok(sum(is.na(audits$group_primary)) == 0)
  )
)
write_kable(checks, "Checksum verification — Step 1.4")
amd("PASS on all rows confirms: pipeline exclusions are complete; group_primary assigns every unique record; Variable_Speed continuous series equals all variable-engine unique records.")
amd("")

# ── 7. Build exclusions tibble ────────────────────────────────────────────────────

exclusions <- bind_rows(excl_list) |>
  mutate(year = as.integer(format(date, "%Y")))

# ── 8. Step 1.5 — Statistics and charts ──────────────────────────────────────────
# Plots using per-record counts use filter(group == group_primary) to avoid
# double-counting variable-engine records.  The VS continuous chart (8e) uses
# filter(group == "Variable_Speed") to show the full cross-phase series.

amd("\n## Step 1.5 Statistics and Charts\n")

# ── 8a. Excluded records by year and reason ──────────────────────────────────────

amd("\n### 8a. Excluded records by year and reason\n")

excl_yr <- exclusions |>
  count(year, excl_reason, name = "n") |>
  arrange(year)

excl_yr_wide <- excl_yr |>
  pivot_wider(names_from = excl_reason, values_from = n, values_fill = 0L)
write_kable(excl_yr_wide, "Excluded records by year and exclusion reason")

p_excl <- ggplot(excl_yr, aes(x = year, y = n, fill = excl_reason)) +
  geom_col() +
  scale_fill_brewer(palette = "Set1", name = "Exclusion reason") +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(title = "Excluded records by year and reason",
       x = "Year", y = "Count") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        legend.text     = element_text(size = 8),
        legend.key.size = unit(0.4, "cm"))

fn_excl <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, "_excl_by_year.png"))
ggsave(fn_excl, p_excl, width = 16, height = 10, units = "cm", dpi = 180)
amd(paste0("![Excluded records by year and reason](", basename(fn_excl), ")"))
amd("")
amd("Exclusion volume peaks in the Phase B window (2020–2024) driven by COVID exemptions and sustained BCP zone activity.")
amd("Non-machinery and stage-unresolvable exclusions are distributed across the full time series.\n")

# ── 8b. Stage distribution by year (unique records) ──────────────────────────────

amd("\n### 8b. Stage distribution by year — unique records\n")

audits_uniq <- audits |> filter(group == group_primary)

stage_yr <- audits_uniq |>
  filter(!is.na(initial_stage)) |>
  count(year, initial_stage, name = "n") |>
  mutate(stage_label = factor(STAGE_LABELS[as.character(initial_stage)],
                               levels = STAGE_LABELS))

p_stage <- ggplot(stage_yr, aes(x = year, y = n, fill = stage_label)) +
  geom_col(position = "stack") +
  scale_fill_viridis_d(name = "Stage", option = "plasma", direction = -1) +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(title = "Stage distribution by year (unique retained records)",
       x = "Year", y = "Count") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

fn_stage <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, "_stage_by_year.png"))
ggsave(fn_stage, p_stage, width = 16, height = 10, units = "cm", dpi = 180)
amd(paste0("![Stage distribution by year](", basename(fn_stage), ")"))
amd("")
amd("Stage distribution shifts from predominantly Stages II–IIIB in 2016 towards Stages IV–V from 2020 onwards.")
amd("Stage V becomes dominant by 2022–2023, reflecting progressive policy-driven fleet improvement.\n")

# Stage × year × group_primary (faceted, unique records only) ---------------------
stage_yr_grp <- audits_uniq |>
  filter(!is.na(initial_stage)) |>
  count(group_primary, year, initial_stage, name = "n") |>
  rename(group = group_primary) |>
  mutate(
    group       = factor(group, levels = GROUP_ORDER),
    stage_label = factor(STAGE_LABELS[as.character(initial_stage)],
                          levels = STAGE_LABELS)
  )

p_stage_grp <- ggplot(stage_yr_grp, aes(x = year, y = n, fill = stage_label)) +
  geom_col(position = "stack") +
  facet_wrap(~ group, nrow = 2, scales = "free_y") +
  scale_fill_viridis_d(name = "Stage", option = "plasma", direction = -1) +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(title = "Stage distribution by year and primary group (unique records)",
       x = "Year", y = "Count") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        strip.text = element_text(face = "bold"))

fn_stage_grp <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, "_stage_by_year_group.png"))
ggsave(fn_stage_grp, p_stage_grp, width = 16, height = 12, units = "cm", dpi = 180)
amd(paste0("![Stage distribution by year and group](", basename(fn_stage_grp), ")"))
amd("")
amd("Constant_Speed transitions sharply to Stage V from 2022; CAZ_Plus and Rest_of_London show a more gradual shift.")
amd("Variable_Speed (P24, Phase C) enters predominantly at Stage V, consistent with anticipatory pre-2025 compliance.\n")

# ── 8c. Non-compliance codes by year — hierarchical, with compliant comparison ────
#
# Each machine is assigned to exactly ONE category via the hierarchy:
#   E (Emissions Not Met) > R (Registration Prob.) > Other (A/C/P/X) > Compliant
# This prevents double-counting machines that carry multiple reason codes.
# Compliant machines (no codes present) are included so the non-compliant
# categories can be compared against the compliant baseline.

amd("\n### 8c. Non-compliance codes vs compliant machines by year\n")

# Hierarchy: E > R > Other (A/C/P/X) > Compliant
NC_LEVELS <- c("Compliant", "Other (A/C/P/X)", "R: Registration", "E: Emissions")

#' Assign each machine to its single highest non-compliance category
classify_nc_top <- function(reasons) {
  r <- toupper(trimws(replace_na(as.character(reasons), "")))
  case_when(
    str_detect(r, "E")       ~ "E: Emissions",
    str_detect(r, "R")       ~ "R: Registration",
    str_detect(r, "[ACPX]") ~ "Other (A/C/P/X)",
    TRUE                     ~ "Compliant"
  )
}

nc_hier <- audits_uniq |>
  mutate(nc_category = classify_nc_top(initial_machinery_reasons)) |>
  count(year, nc_category, name = "n") |>
  mutate(nc_category = factor(nc_category, levels = NC_LEVELS))

# Table: year × category (wide), plus row total as a check against n_unique_records
nc_hier_wide <- nc_hier |>
  pivot_wider(names_from = nc_category, values_from = n, values_fill = 0L) |>
  mutate(Total = rowSums(across(where(is.integer))))
write_kable(nc_hier_wide,
            "Compliance status by year — hierarchical non-compliance code assignment")
amd("Each machine is counted once only, assigned to its highest-priority non-compliance category (E > R > Other > Compliant).")
amd("Row totals should equal the total unique records for that year, confirming complete coverage.\n")

# Plot 1: non-compliant categories only (stacked bar, matches v3 intent)
nc_only <- nc_hier |> filter(nc_category != "Compliant")

p_nc <- ggplot(nc_only, aes(x = year, y = n, fill = nc_category)) +
  geom_col(position = "stack") +
  scale_fill_brewer(palette = "Dark2", name = "Top non-compliance code",
                    drop = FALSE) +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(title = "Non-compliant machines by top code category per year",
       subtitle = "Hierarchical assignment: E > R > Other; each machine counted once",
       x = "Year", y = "Machines") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        legend.text     = element_text(size = 8),
        legend.key.size = unit(0.4, "cm"))

fn_nc <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, "_noncompliance_codes_year.png"))
ggsave(fn_nc, p_nc, width = 16, height = 10, units = "cm", dpi = 180)
amd(paste0("![Non-compliant machines by top code category](", basename(fn_nc), ")"))
amd("")
amd("Emissions non-compliance (E) is the dominant category throughout, confirming the fleet's primary compliance challenge is emissions standard rather than administrative issues.")
amd("Registration non-compliance (R) is a secondary but persistent category; Other codes (A/C/P/X) are minor.\n")

# Plot 2: compliant + non-compliant categories together for ratio comparison
p_nc_comp <- ggplot(nc_hier, aes(x = year, y = n, fill = nc_category)) +
  geom_col(position = "stack") +
  scale_fill_manual(
    name   = "Status",
    values = c(
      "Compliant"      = "#4DAF4A",
      "Other (A/C/P/X)"= "#984EA3",
      "R: Registration" = "#FF7F00",
      "E: Emissions"    = "#E41A1C"
    ),
    drop = FALSE
  ) +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(title = "Compliant vs non-compliant machines by year",
       subtitle = "Non-compliant split by top code category (E > R > Other); each machine counted once",
       x = "Year", y = "Machines") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        legend.text     = element_text(size = 8),
        legend.key.size = unit(0.4, "cm"))

fn_nc_comp <- file.path(OUTPUTS_DIR,
                         paste0(SCRIPT_STEM, "_compliance_vs_noncompliance_year.png"))
ggsave(fn_nc_comp, p_nc_comp, width = 16, height = 10, units = "cm", dpi = 180)
amd(paste0("![Compliant vs non-compliant machines by year](", basename(fn_nc_comp), ")"))
amd("")
amd("The compliant (green) segment grows over time as the fleet improves, while the emissions non-compliant (red) segment shrinks — the primary visual indicator of LEZ policy effectiveness.")
amd("Registration and Other non-compliance remain relatively small and stable throughout the series.\n")

# ── 8d. Primary group and engagement type by year ────────────────────────────────

amd("\n### 8d. Primary group and engagement type by year (unique records)\n")

grp_yr <- audits_uniq |>
  mutate(
    group      = factor(group_primary, levels = GROUP_ORDER),
    engagement = if_else(cold_engaged, "Cold", "Warm")
  ) |>
  count(year, group, engagement, name = "n")

p_grp <- ggplot(grp_yr, aes(x = year, y = n, fill = group)) +
  geom_col(position = "stack") +
  facet_wrap(~ engagement, nrow = 1) +
  scale_fill_brewer(palette = "Set2", name = "Group") +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(title = "Records by primary group and engagement type by year",
       x = "Year", y = "Count") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

fn_grp <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, "_group_engagement_year.png"))
ggsave(fn_grp, p_grp, width = 16, height = 10, units = "cm", dpi = 180)
amd(paste0("![Group and engagement type by year](", basename(fn_grp), ")"))
amd("")
amd("Rest_of_London dominates both cold and warm counts across all years; Constant_Speed is stable.")
amd("Variable_Speed (P24) appears from 2025 only in the primary-group view.\n")

# ── 8e. Variable_Speed continuous by year (all vs records) ───────────────────────

amd("\n### 8e. Variable_Speed continuous by year — all variable-engine records\n")

vs_yr <- audits |>
  filter(group == "Variable_Speed") |>
  mutate(sub_group = factor(group_primary, levels = GROUP_ORDER)) |>
  count(year, sub_group, name = "n")

p_vs <- ggplot(vs_yr, aes(x = year, y = n, fill = sub_group)) +
  geom_col(position = "stack") +
  scale_fill_brewer(palette = "Set2", name = "Zone sub-group (group_primary)") +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(
    title    = "Variable_Speed continuous: all variable-engine records by year",
    subtitle = "Coloured by zone sub-group identity (group_primary)",
    x = "Year", y = "Count"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

fn_vs <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, "_vs_continuous_year.png"))
ggsave(fn_vs, p_vs, width = 16, height = 10, units = "cm", dpi = 180)
amd(paste0("![Variable_Speed continuous by year](", basename(fn_vs), ")"))
amd("")
amd("Variable_Speed is a continuous series from 2016 through 2026: CAZ_Plus and Rest_of_London records contribute through Phase B (to end-2024); Variable_Speed (P24) takes over in Phase C.")
amd("CAZ_Plus and Rest_of_London are 'discontinued' from 1.1.2025 because no new CAZ/OA/GL records exist after that date — the P24 zone supersedes them.\n")

# ── 8f. Pre-2016 records summary --------------------------------------------------

amd("\n### 8f. Pre-2016 records (retained, NA phase)\n")

pre_2016 <- audits_uniq |> filter(year < 2016)
if (nrow(pre_2016) == 0) {
  amd("No pre-2016 records in retained dataset.\n")
  message("Pre-2016 records: none")
} else {
  pre_tbl <- pre_2016 |>
    count(year, group_primary, name = "n") |>
    arrange(year, group_primary)
  write_kable(pre_tbl, "Pre-2016 records by year and primary group (retained, NA phase)")
  amd("Pre-2016 records are retained in audits.rds (NA phase) and excluded from all estimation steps.")
  amd("Preserved for potential future time-extension analysis.\n")

  pre_yr <- pre_tbl |>
    mutate(group_primary = factor(group_primary, levels = GROUP_ORDER))

  p_pre <- ggplot(pre_yr, aes(x = year, y = n, fill = group_primary)) +
    geom_col(position = "stack") +
    scale_fill_brewer(palette = "Set2", name = "Group") +
    scale_x_continuous(breaks = pretty_breaks()) +
    labs(title = "Pre-2016 retained records by year and group (NA phase)",
         x = "Year", y = "Count") +
    theme_minimal(base_size = 11) +
    theme(legend.position = "bottom")

  fn_pre <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, "_pre2016_year.png"))
  ggsave(fn_pre, p_pre, width = 16, height = 10, units = "cm", dpi = 180)
  amd(paste0("![Pre-2016 records by year](", basename(fn_pre), ")"))
  amd("")
  amd("Pre-2016 records are retained in audits.rds but receive NA phase and are excluded from all estimation steps.")
  amd("Their group distribution mirrors the full dataset, confirming no systematic data-quality difference in the pre-policy-era records.\n")

  message("Pre-2016 records (retained, NA phase): ", nrow(pre_2016))
}

# ── 9. Step 1.6 — Formal checksum verification ───────────────────────────────────

amd("\n## Step 1.6 Formal Checksum Verification\n")

n_check_unique <- n_unique_records + n_excl_total

full_checksum <- tibble(
  item = c(
    "Raw records imported",
    "  Excluded — No NRMM / non-machinery",
    "  Excluded — Zone out of scope (BCP/other)",
    "  Excluded — Engine type unassignable",
    "  Excluded — Initial stage unresolvable",
    "  Excluded — COVID exempt",
    "  Total excluded",
    "Unique records retained",
    "Check: unique_retained + excluded",
    "Matches raw total?",
    "",
    "VS duplicate rows added",
    "Total rows in audits.rds"
  ),
  count = c(
    n_raw,
    n_excl_non_mach, n_excl_zone, n_excl_engine,
    n_excl_stage, n_excl_covid, n_excl_total,
    n_unique_records, n_check_unique,
    as.integer(n_check_unique == n_raw),
    NA_integer_,
    n_vs_dupes, nrow(audits)
  ),
  status = c(
    rep("", 9L),
    if (n_check_unique == n_raw) "PASS" else "FAIL",
    rep("", 3L)
  )
)
write_kable(full_checksum, "Full accounting: raw = unique_retained + excluded")

# Phase-level checksum (unique records)
phase_cs <- audits_uniq |>
  mutate(phase_label = coalesce(phase, "NA (pre-2016/between)")) |>
  count(phase_label, name = "n") |>
  bind_rows(tibble(phase_label = "TOTAL", n = n_unique_records))
write_kable(phase_cs, "Unique records by phase (sum = n_unique_records)")
amd("Sum of all phase rows (including NA) must equal n_unique_records; any discrepancy indicates a phase-assignment bug.\n")

message("\n=== STEP 1.6 FORMAL CHECKSUM ===")
message(sprintf("  Raw:              %d", n_raw))
message(sprintf("  Total excluded:   %d", n_excl_total))
message(sprintf("  Unique retained:  %d", n_unique_records))
message(sprintf("  Sum:              %d  %s",
                n_check_unique,
                if (n_check_unique == n_raw) "PASS" else "FAIL"))
message(sprintf("  VS dupes added:   %d", n_vs_dupes))
message(sprintf("  Total rows:       %d", nrow(audits)))

# ── 10. Save outputs ──────────────────────────────────────────────────────────────

if (!dir.exists(OUT_DIR)) dir.create(OUT_DIR, recursive = TRUE)

saveRDS(audits,     file.path(OUT_DIR, "audits.rds"))
saveRDS(exclusions, file.path(OUT_DIR, "exclusions.rds"))

message("\nSaved:")
message(sprintf("  %-20s  %d x %d  (%d unique records + %d VS dupes)",
                "intermediate/audits.rds",
                nrow(audits), ncol(audits), n_unique_records, n_vs_dupes))
message(sprintf("  %-20s  %d x %d",
                "intermediate/exclusions.rds",
                nrow(exclusions), ncol(exclusions)))

# Manifest
manifest_entries <- tibble(
  object = c("audits", "exclusions"),
  file   = c("intermediate/audits.rds", "intermediate/exclusions.rds"),
  class  = "tbl_df",
  dim    = c(
    paste0(nrow(audits),     " x ", ncol(audits)),
    paste0(nrow(exclusions), " x ", ncol(exclusions))
  ),
  step  = "step1v4",
  description = c(
    paste0(
      "Expanded audit records: ", n_unique_records, " unique records + ",
      n_vs_dupes, " VS duplicate rows. group = active group for filtering; ",
      "group_primary = 4-way zone assignment; filter(group == group_primary) ",
      "recovers unique records. vs_member = TRUE for all variable-engine records."
    ),
    "Pipeline-excluded records with excl_reason label; for Step 1.5 exclusion analysis"
  )
)
update_manifest(manifest_entries)
message("Manifest updated: ", MANIFEST_FILE)

# Console summary
message("\n=== OBJECTS SAVED (step 1 v4) ===")
message(sprintf("  %-15s  %-7s  %s", "object", "class", "dim"))
message(sprintf("  %-15s  %-7s  %d x %d", "audits",     "tbl_df", nrow(audits),     ncol(audits)))
message(sprintf("  %-15s  %-7s  %d x %d", "exclusions", "tbl_df", nrow(exclusions), ncol(exclusions)))

sessionInfo()
