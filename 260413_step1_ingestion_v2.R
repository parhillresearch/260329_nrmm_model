# 260413_step1_ingestion_v2.R
# NRMM LEZ Trend Analysis — Step 1: Data Ingestion and Preparation (v2)
#
# Director review amendments (director_review_step1.md):
#   1.3  Check for unexpected zone/group codes; add vs_member flag so Variable_Speed
#        is continuous across A1/A2/B/C phases; save audits_vs.rds (all variable-
#        engine records with group = "Variable_Speed").  CAZ_Plus and Rest_of_London
#        retain their primary group assignments but are also accessible via vs_member.
#   1.4  Checksum analysis confirming group coding is internally consistent.
#   1.5  Statistics and stacked bar charts by year for:
#          (a) excluded records by exclusion reason
#          (b) Stage distributions (all-records and faceted by group)
#          (c) non-compliance codes
#          (d) group + engagement type
#          (e) Variable_Speed continuous (vs_member)
#          (f) pre-2016 records characterisation
#   1.6  Formal checksum verification: all subsets sum to raw total.
#
# Outputs (intermediate/):
#   audits.rds        — main tibble (4-group + vs_member flag)
#   audits_vs.rds     — all variable-engine records re-labelled as Variable_Speed
#   exclusions.rds    — pipeline-excluded records with excl_reason label
# Outputs (outputs/):
#   260413_step1_ingestion_v2.md  — all tables + plot references (single file)
#   260413_step1_ingestion_v2_*.png — plots
#   (legacy individual count .md files also written for Step 6 backward-compat.)

library(tidyverse)
library(knitr)
library(kableExtra)
library(scales)

# ── Schema constants ─────────────────────────────────────────────────────────────

INPUT_FILE    <- "audits.txt"
OUT_DIR       <- "intermediate"
OUTPUTS_DIR   <- "outputs"
MANIFEST_FILE <- file.path(OUT_DIR, "manifest.md")
SCRIPT_STEM   <- "260413_step1_ingestion_v2"
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

STAGE_LABELS <- c("1" = "I", "2" = "II", "3" = "IIIA", "4" = "IIIB",
                  "5" = "IV", "6" = "V", "7" = "ZE/other")

# Phase boundaries (Table 7)
PHASE_A1_START <- as.Date("2016-01-01"); PHASE_A1_END <- as.Date("2018-12-31")
PHASE_A2_START <- as.Date("2019-01-01"); PHASE_A2_END <- as.Date("2020-08-31")
PHASE_B_START  <- as.Date("2020-09-01"); PHASE_B_END  <- as.Date("2024-12-31")
PHASE_C_START  <- as.Date("2025-01-01")
COVID_START    <- as.Date("2020-09-01"); COVID_END    <- as.Date("2021-03-31")

GROUP_ORDER  <- c("Constant_Speed", "CAZ_Plus", "Rest_of_London", "Variable_Speed")
PHASE_ORDER  <- c("A1", "A2", "B", "C")

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

#' Append text to the output .md file
amd <- function(...) cat(paste0(...), "\n", file = OUTPUT_MD, append = TRUE, sep = "")

#' Write an HTML kable to output .md and a markdown kable to console; return tbl
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

#' Build a group × phase count table from a filtered tibble
make_count_table <- function(df) {
  phases_present <- PHASE_ORDER

  raw <- df |>
    filter(!is.na(phase)) |>
    count(group, phase, name = "n")

  grid <- expand_grid(
    group = factor(GROUP_ORDER, levels = GROUP_ORDER),
    phase = phases_present
  )

  tbl <- grid |>
    left_join(raw, by = c("group", "phase")) |>
    mutate(n = replace_na(n, 0L)) |>
    pivot_wider(names_from = phase, values_from = n) |>
    arrange(group)

  # NA-phase column (pre-2016 / between boundaries)
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

message("=== ", SCRIPT_STEM, " — NRMM Step 1 (v2) ===\n")

# ── 1. Import ────────────────────────────────────────────────────────────────────
raw <- read.delim(INPUT_FILE, stringsAsFactors = FALSE, check.names = TRUE) |>
  as_tibble()
names(raw) <- trimws(names(raw))
n_raw <- nrow(raw)
message("1. Raw rows: ", n_raw)

missing_cols <- setdiff(COLS_KEEP, names(raw))
if (length(missing_cols) > 0)
  warning("Expected columns absent from raw file: ", paste(missing_cols, collapse = ", "))

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
# Each stage saves the excluded records before filtering, ensuring
# raw total = sum(excluded at each stage) + final retained count.

excl_list <- list()  # list of small tibbles; each has date, zone, excl_reason

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
message("    Full engine_type_clean distribution:")
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

# 3f. kW Power parsing (non-exclusion; flag only) ---------------------------------
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

# ── 4. Group assignment (Step 1.3 director amendment) ────────────────────────────
# PRIMARY group: 4-way zone × engine assignment per schema.md Table 1.
# vs_member: TRUE for every variable-engine record, enabling continuous
#   Variable_Speed analysis across A1/A2/B/C (director amendment 1.3).

audits <- df |>
  mutate(
    group = case_when(
      engine_type_clean == "Constant"                             ~ "Constant_Speed",
      engine_type_clean == "Variable" & zone %in% c("CAZ", "OA") ~ "CAZ_Plus",
      engine_type_clean == "Variable" & zone == "GL"              ~ "Rest_of_London",
      engine_type_clean == "Variable" & zone == "P24"             ~ "Variable_Speed",
      TRUE ~ NA_character_
    ),
    vs_member = (engine_type_clean == "Variable")
  )

# Check for unexpected NA groups or zone codes (Step 1.3 amendment)
na_group <- audits |> filter(is.na(group))
if (nrow(na_group) > 0) {
  message("\nFLAG — ", nrow(na_group), " records with unassigned group:")
  na_group |> count(engine_type_clean, zone, name = "n") |> print()
} else {
  message("\nGroup assignment: all ", nrow(audits), " records assigned (no NA groups).")
}

# Zone × group × engine_type cross-check (Step 1.3 amendment)
zone_cross <- audits |>
  count(zone, engine_type_clean, group, name = "n") |>
  arrange(zone, engine_type_clean)
message("\nZone × engine_type × group cross-check:")
print(zone_cross, n = 30)

# ── 5. Record counts by group × phase (Step 1.4) ─────────────────────────────────

amd("\n## Step 1.1–1.4 Record Counts\n")

counts_all  <- make_count_table(audits)
counts_cold <- make_count_table(audits |> filter(cold_engaged))
counts_warm <- make_count_table(audits |> filter(!cold_engaged))

amd("\n### All records (cold + warm) by group × phase\n")
write_kable(counts_all,  "All records by group × phase",  add_phase_header = TRUE)
amd("Total retained records distributed across four groups and four model phases. NA_phase entries are pre-2016 or between-boundary records retained in audits.rds but excluded from estimation.")
amd("Rest of London dominates the record count; Variable Speed records appear in Phase C only under the primary group assignment.\n")

amd("\n### Cold-engaged records by group × phase\n")
write_kable(counts_cold, "Cold-engaged by group × phase", add_phase_header = TRUE)
amd("Cold-engaged records are used for λ_CF estimation; their distribution follows the all-records pattern with smaller absolute counts.")
amd("Constant Speed cold records are notably sparse compared to variable-engine groups.\n")

amd("\n### Warm-engaged records by group × phase\n")
write_kable(counts_warm, "Warm-engaged by group × phase", add_phase_header = TRUE)
amd("Warm records are used for λ_Proactive estimation (self-compliant warm subset).")
amd("Warm counts mirror the all-records distribution, confirming no systematic engagement-type bias by phase.\n")

# Phase C / P24 detail
p24_dates <- audits |> filter(phase == "C") |>
  summarise(earliest = min(date), latest = max(date), n = n())
message("\nP24 temporal extent: ", p24_dates$earliest, " to ", p24_dates$latest,
        " (n = ", p24_dates$n, ")")

# Variable_Speed vs_member continuous counts by phase
vs_cont <- audits |>
  filter(vs_member) |>
  count(zone, phase, name = "n") |>
  pivot_wider(names_from = phase, values_from = n, values_fill = 0L) |>
  mutate(Total = rowSums(across(where(is.integer))))

amd("\n### Variable_Speed continuous (vs_member): records by zone and phase\n")
write_kable(vs_cont, "vs_member records by zone × phase (all variable-engine records)")
amd("vs_member = TRUE for all variable-engine records. This table shows how CAZ_Plus (CAZ/OA) and Rest_of_London (GL) contribute to the continuous Variable_Speed series across phases A1–C.")
amd("P24 records are solely Phase C; prior phases draw from CAZ/OA/GL zones.\n")

# Legacy count files (backward-compat. with Step 6 report references)
knitr::kable(counts_all, format = "markdown") |>
  writeLines(file.path(OUTPUTS_DIR, "260413_step1_counts_all.md"))
knitr::kable(counts_cold, format = "markdown") |>
  writeLines(file.path(OUTPUTS_DIR, "260413_step1_counts_cold.md"))
knitr::kable(counts_warm, format = "markdown") |>
  writeLines(file.path(OUTPUTS_DIR, "260413_step1_counts_warm.md"))

# ── 6. Checksum analysis (Step 1.4 amendment) ────────────────────────────────────

n_retained       <- nrow(audits)
n_excl_non_mach  <- nrow(excl_list[["No NRMM / non-machinery"]])
n_excl_zone      <- nrow(excl_list[["Zone out of scope"]])
n_excl_engine    <- nrow(excl_list[["Engine type unassignable"]])
n_excl_stage     <- nrow(excl_list[["Stage unresolvable"]])
n_excl_covid     <- nrow(excl_list[["COVID exempt"]])
n_excl_total     <- n_excl_non_mach + n_excl_zone + n_excl_engine +
                    n_excl_stage + n_excl_covid

amd("\n## Step 1.4 Checksum Analysis\n")

# Pipeline exclusion table
pipeline_tbl <- tibble(
  stage = c(
    "Raw records imported",
    "Excluded — No NRMM / non-machinery",
    "Excluded — Zone out of scope",
    "Excluded — Engine type unassignable",
    "Excluded — Initial stage unresolvable",
    "Excluded — COVID exempt",
    "Total excluded",
    "Retained in audits.rds"
  ),
  n = c(
    n_raw, n_excl_non_mach, n_excl_zone, n_excl_engine,
    n_excl_stage, n_excl_covid, n_excl_total, n_retained
  )
)
write_kable(pipeline_tbl, "Exclusion pipeline record counts")

# Group-level checksum
grp_cs <- audits |>
  count(group, name = "n") |>
  bind_rows(tibble(group = "TOTAL", n = n_retained)) |>
  mutate(pct = round(100 * n / n_retained, 1),
         pct = if_else(group == "TOTAL", 100.0, pct))
write_kable(grp_cs, "Records by primary group")

# Summary checksum table
chk_ok <- function(x) if (x) "PASS" else "FAIL"
checks <- tibble(
  check = c(
    "raw = retained + excluded",
    "sum(group counts) = n_retained",
    "sum(vs_member) = CAZ_Plus + RoL + VS_P24",
    "cold + warm = n_retained",
    "no NA group values"
  ),
  lhs = c(
    n_raw,
    sum(audits |> count(group) |> pull(n)),
    sum(audits$vs_member),
    sum(audits$cold_engaged) + sum(!audits$cold_engaged),
    sum(is.na(audits$group))
  ),
  rhs = c(
    n_retained + n_excl_total,
    n_retained,
    sum(audits$group %in% c("CAZ_Plus", "Rest_of_London", "Variable_Speed"), na.rm = TRUE),
    n_retained,
    0L
  ),
  result = c(
    chk_ok(n_raw == n_retained + n_excl_total),
    chk_ok(sum(audits |> count(group) |> pull(n)) == n_retained),
    chk_ok(sum(audits$vs_member) ==
             sum(audits$group %in% c("CAZ_Plus", "Rest_of_London", "Variable_Speed"), na.rm = TRUE)),
    chk_ok(sum(audits$cold_engaged) + sum(!audits$cold_engaged) == n_retained),
    chk_ok(sum(is.na(audits$group)) == 0)
  )
)
write_kable(checks, "Checksum verification — Step 1.4")
amd("Each row tests a key accounting identity. PASS confirms the group assignment and exclusion pipeline are internally consistent.")
amd("Any FAIL would indicate double-counting, missed exclusions, or NA group assignment; none expected.\n")

# ── 7. Build exclusions tibble ────────────────────────────────────────────────────

exclusions <- bind_rows(excl_list) |>
  mutate(year = as.integer(format(date, "%Y")))

# ── 8. Step 1.5 — Statistics and stacked bar charts ──────────────────────────────

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
amd("Non-machinery exclusions (No NRMM) and stage-unresolvable records are present throughout the time series.\n")

# ── 8b. Stage distributions by year (all retained records) ───────────────────────

amd("\n### 8b. Stage distribution by year — all retained records\n")

stage_yr <- audits |>
  filter(!is.na(initial_stage)) |>
  count(year, initial_stage, name = "n") |>
  mutate(stage_label = factor(STAGE_LABELS[as.character(initial_stage)],
                               levels = STAGE_LABELS))

p_stage <- ggplot(stage_yr, aes(x = year, y = n, fill = stage_label)) +
  geom_col(position = "stack") +
  scale_fill_viridis_d(name = "Stage", option = "plasma", direction = -1) +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(title = "Stage distribution by year (all retained records)",
       x = "Year", y = "Count") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

fn_stage <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, "_stage_by_year.png"))
ggsave(fn_stage, p_stage, width = 16, height = 10, units = "cm", dpi = 180)
amd(paste0("![Stage distribution by year — all records](", basename(fn_stage), ")"))
amd("")
amd("Stage distribution shifts from predominantly Stages II–IIIB in 2016 towards Stages IV–V from 2020 onwards.")
amd("Stage V becomes the dominant category by 2022–2023, reflecting progressive policy-driven fleet improvement.\n")

# Stage × year × group (faceted) --------------------------------------------------
stage_yr_grp <- audits |>
  filter(!is.na(initial_stage), !is.na(group)) |>
  count(group, year, initial_stage, name = "n") |>
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
  labs(title = "Stage distribution by year and group",
       x = "Year", y = "Count") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        strip.text = element_text(face = "bold"))

fn_stage_grp <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, "_stage_by_year_group.png"))
ggsave(fn_stage_grp, p_stage_grp, width = 16, height = 12, units = "cm", dpi = 180)
amd(paste0("![Stage distribution by year and group](", basename(fn_stage_grp), ")"))
amd("")
amd("Constant Speed transitions sharply from Stage IIIA to Stage V from 2022 onwards; CAZ_Plus and Rest_of_London show a more gradual shift.")
amd("Variable_Speed (Phase C, P24) enters at predominantly Stage V, consistent with anticipatory compliance before the 2025 threshold uplift.\n")

# ── 8c. Non-compliance codes by year ─────────────────────────────────────────────

amd("\n### 8c. Non-compliance codes by year (initial machinery reasons)\n")

code_labels <- c(
  A = "A: Actively Declined", C = "C: Cannot Evidence",
  E = "E: Emissions Not Met",  P = "P: Passively Declined",
  R = "R: Registration Prob.", X = "X: Not Specified"
)

nc_codes <- audits |>
  filter(!is.na(initial_machinery_reasons),
         trimws(initial_machinery_reasons) != "") |>
  select(year, initial_machinery_reasons) |>
  mutate(reasons_up = toupper(trimws(initial_machinery_reasons))) |>
  mutate(
    A = str_detect(reasons_up, "A"),
    C = str_detect(reasons_up, "C"),
    E = str_detect(reasons_up, "E"),
    P = str_detect(reasons_up, "P"),
    R = str_detect(reasons_up, "R"),
    X = str_detect(reasons_up, "X")
  ) |>
  pivot_longer(c(A, C, E, P, R, X), names_to = "code", values_to = "present") |>
  filter(present) |>
  count(year, code, name = "n") |>
  mutate(code_label = factor(code_labels[code], levels = code_labels))

nc_wide <- nc_codes |>
  select(year, code_label, n) |>
  pivot_wider(names_from = code_label, values_from = n, values_fill = 0L)
write_kable(nc_wide, "Non-compliance codes by year")

p_nc <- ggplot(nc_codes, aes(x = year, y = n, fill = code_label)) +
  geom_col(position = "stack") +
  scale_fill_brewer(palette = "Dark2", name = "Code") +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(title = "Non-compliance codes by year (initial machinery reasons)",
       x = "Year", y = "Records flagged") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        legend.text     = element_text(size = 8),
        legend.key.size = unit(0.4, "cm"))

fn_nc <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, "_noncompliance_codes_year.png"))
ggsave(fn_nc, p_nc, width = 16, height = 10, units = "cm", dpi = 180)
amd(paste0("![Non-compliance codes by year](", basename(fn_nc), ")"))
amd("")
amd("Code E (Emissions Not Met) dominates throughout; code R (Registration Problem) is the next most frequent.")
amd("Note: one record may carry multiple codes; the y-axis counts code occurrences, not unique records.\n")

# ── 8d. Group and engagement type by year ────────────────────────────────────────

amd("\n### 8d. Group and engagement type by year\n")

grp_yr <- audits |>
  filter(!is.na(group)) |>
  mutate(
    group      = factor(group, levels = GROUP_ORDER),
    engagement = if_else(cold_engaged, "Cold", "Warm")
  ) |>
  count(year, group, engagement, name = "n")

p_grp <- ggplot(grp_yr, aes(x = year, y = n, fill = group)) +
  geom_col(position = "stack") +
  facet_wrap(~ engagement, nrow = 1) +
  scale_fill_brewer(palette = "Set2", name = "Group") +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(title = "Records by group and engagement type by year",
       x = "Year", y = "Count") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

fn_grp <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, "_group_engagement_year.png"))
ggsave(fn_grp, p_grp, width = 16, height = 10, units = "cm", dpi = 180)
amd(paste0("![Group and engagement type by year](", basename(fn_grp), ")"))
amd("")
amd("Rest_of_London dominates both cold and warm counts across all years; Constant_Speed records are stable in volume.")
amd("Variable_Speed records (P24) appear from 2025 only under the primary group assignment.\n")

# ── 8e. Variable_Speed continuous (vs_member) by year ────────────────────────────

amd("\n### 8e. Variable_Speed continuous (vs_member) by year\n")

vs_yr <- audits |>
  filter(vs_member) |>
  mutate(group = factor(group, levels = GROUP_ORDER)) |>
  count(year, group, name = "n")

p_vs <- ggplot(vs_yr, aes(x = year, y = n, fill = group)) +
  geom_col(position = "stack") +
  scale_fill_brewer(palette = "Set2", name = "Zone sub-group") +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(
    title    = "Variable Speed continuous record count by year (vs_member = TRUE)",
    subtitle = "Zone sub-group shows original CAZ_Plus / Rest_of_London identity pre-2025",
    x = "Year", y = "Count"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

fn_vs <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, "_vs_continuous_year.png"))
ggsave(fn_vs, p_vs, width = 16, height = 10, units = "cm", dpi = 180)
amd(paste0("![Variable_Speed continuous by year](", basename(fn_vs), ")"))
amd("")
amd("When all variable-engine records are pooled (vs_member = TRUE), Variable_Speed forms a continuous series from 2016 through 2026.")
amd("CAZ_Plus and Rest_of_London records contribute through Phase B (to end-2024); Variable_Speed (P24) takes over in Phase C.\n")

# ── 8f. Pre-2016 records summary --------------------------------------------------

amd("\n### 8f. Pre-2016 records summary (retained, NA phase)\n")

pre_2016 <- audits |> filter(year < 2016)
if (nrow(pre_2016) == 0) {
  amd("No pre-2016 records in retained dataset.\n")
  message("Pre-2016 records: none")
} else {
  pre_tbl <- pre_2016 |>
    count(year, group, name = "n") |>
    arrange(year, group)
  write_kable(pre_tbl, "Pre-2016 records by year and group (retained, NA phase)")
  message("Pre-2016 records (retained, NA phase): ", nrow(pre_2016))
  amd("Pre-2016 records are retained in audits.rds but assigned NA phase and excluded from all estimation steps.")
  amd("They are preserved for potential use in future time-extension analysis.\n")
}

# ── 9. Step 1.6 — Formal checksum verification ───────────────────────────────────

amd("\n## Step 1.6 Formal Checksum Verification\n")

n_check_total <- n_retained + n_excl_total

full_checksum <- tibble(
  item = c(
    "Raw records imported",
    "  Excluded — No NRMM / non-machinery",
    "  Excluded — Zone out of scope (BCP/other)",
    "  Excluded — Engine type unassignable",
    "  Excluded — Initial stage unresolvable",
    "  Excluded — COVID exempt",
    "  Total excluded",
    "Retained (audits.rds)",
    "Check: retained + excluded",
    "Matches raw total?"
  ),
  count = c(
    n_raw,
    n_excl_non_mach, n_excl_zone, n_excl_engine,
    n_excl_stage, n_excl_covid,
    n_excl_total,
    n_retained,
    n_check_total,
    as.integer(n_check_total == n_raw)
  ),
  status = c(
    rep("", 9L),
    if (n_check_total == n_raw) "PASS" else "FAIL"
  )
)
write_kable(full_checksum, "Full accounting: raw records = retained + excluded")

# Phase-level checksum
phase_cs <- audits |>
  mutate(phase_label = coalesce(phase, "NA (pre-2016/between)")) |>
  count(phase_label, name = "n") |>
  bind_rows(tibble(phase_label = "TOTAL", n = n_retained))
write_kable(phase_cs, "Records by phase (sum = n_retained)")
amd("The sum of all phase rows (including NA) must equal n_retained. Any discrepancy indicates a phase-assignment bug.")
amd("")

message("\n=== STEP 1.6 FORMAL CHECKSUM ===")
message(sprintf("  Raw:      %d", n_raw))
message(sprintf("  Excluded: %d", n_excl_total))
message(sprintf("  Retained: %d", n_retained))
message(sprintf("  Sum:      %d  %s",
                n_check_total,
                if (n_check_total == n_raw) "PASS" else "FAIL"))

# ── 10. Save outputs ──────────────────────────────────────────────────────────────

if (!dir.exists(OUT_DIR)) dir.create(OUT_DIR, recursive = TRUE)

# audits_vs: all variable-engine records re-labelled as Variable_Speed
audits_vs <- audits |>
  filter(vs_member) |>
  mutate(group = "Variable_Speed")

saveRDS(audits,     file.path(OUT_DIR, "audits.rds"))
saveRDS(audits_vs,  file.path(OUT_DIR, "audits_vs.rds"))
saveRDS(exclusions, file.path(OUT_DIR, "exclusions.rds"))

message("\nSaved:")
message(sprintf("  %-20s  %d x %d", "intermediate/audits.rds",
                nrow(audits), ncol(audits)))
message(sprintf("  %-20s  %d x %d", "intermediate/audits_vs.rds",
                nrow(audits_vs), ncol(audits_vs)))
message(sprintf("  %-20s  %d x %d", "intermediate/exclusions.rds",
                nrow(exclusions), ncol(exclusions)))

# Manifest
manifest_entries <- tibble(
  object = c("audits", "audits_vs", "exclusions"),
  file   = c("intermediate/audits.rds",
             "intermediate/audits_vs.rds",
             "intermediate/exclusions.rds"),
  class  = "tbl_df",
  dim    = c(
    paste0(nrow(audits),     " x ", ncol(audits)),
    paste0(nrow(audits_vs),  " x ", ncol(audits_vs)),
    paste0(nrow(exclusions), " x ", ncol(exclusions))
  ),
  step  = "step1v2",
  description = c(
    paste0("Clean filtered audits: in-scope zones (CAZ/OA/GL/P24), machinery only, ",
           "stages encoded, COVID removed; group (4-way primary) + phase + vs_member flag"),
    paste0("All variable-engine records with group = 'Variable_Speed'; ",
           "enables continuous Variable_Speed trend analysis across A1/A2/B/C"),
    "Pipeline-excluded records with excl_reason label; for Step 1.5 exclusion analysis"
  )
)
update_manifest(manifest_entries)
message("Manifest updated: ", MANIFEST_FILE)

# Console summary
message("\n=== OBJECTS SAVED (step 1 v2) ===")
message(sprintf("  %-15s  %-7s  %s", "object", "class", "dim"))
message(sprintf("  %-15s  %-7s  %d x %d", "audits",     "tbl_df", nrow(audits),     ncol(audits)))
message(sprintf("  %-15s  %-7s  %d x %d", "audits_vs",  "tbl_df", nrow(audits_vs),  ncol(audits_vs)))
message(sprintf("  %-15s  %-7s  %d x %d", "exclusions", "tbl_df", nrow(exclusions), ncol(exclusions)))

sessionInfo()
