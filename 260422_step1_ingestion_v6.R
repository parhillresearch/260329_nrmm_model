library(tidyverse)
library(knitr)
library(kableExtra)
library(scales)

INPUT_FILE    <- "input_data/audits.txt"
OUT_DIR       <- "intermediate_data"
OUTPUTS_DIR   <- "outputs"
MANIFEST_FILE <- file.path(OUT_DIR, "manifest.md")
SCRIPT_STEM   <- "260422_step1_ingestion_v6"
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

STAGE_MAP    <- c(I = 1L, II = 2L, IIIA = 3L, IIIB = 4L, IV = 5L, V = 6L, ZE = 7L)
STAGE_LABELS <- c("1"="I","2"="II","3"="IIIA","4"="IIIB","5"="IV","6"="V","7"="ZE/other")

PHASE_A1_START <- as.Date("2016-01-01"); PHASE_A1_END <- as.Date("2018-12-31")
PHASE_A2_START <- as.Date("2019-01-01"); PHASE_A2_END <- as.Date("2020-08-31")
PHASE_B_START  <- as.Date("2020-09-01"); PHASE_B_END  <- as.Date("2024-12-31")
PHASE_C_START  <- as.Date("2025-01-01")
COVID_START    <- as.Date("2020-09-01"); COVID_END    <- as.Date("2021-03-31")

GROUP_ORDER <- c("Constant_Speed", "Variable_Speed", "CAZ_Plus", "Rest_of_London")
PHASE_ORDER <- c("A1", "A2", "B", "C") # possibly useless


# Do NOT toupper() before the fixed=TRUE 'E' check: toupper("None")="NONE" matches 'E',
# wrongly flagging compliant machines. NC codes are uppercase; "None" sentinel is not.
derive_compliance_flags <- function(reasons) {
  r_raw <- trimws(replace_na(as.character(reasons), ""))  # as.character() before replace_na: types must match
  list(
    emissions_compliant = !grepl("E", r_raw, fixed = TRUE),  # fixed=TRUE: literal string match, not regex
    admin_compliant     = !grepl("[ACPRX]", toupper(r_raw))   # toupper safe here: no 'E'-sentinel risk
  )
}

fractional_year <- function(d) {
  yr         <- as.integer(format(d, "%Y"))
  doy        <- as.integer(format(d, "%j"))                              # %j: day-of-year (1-366)
  leap       <- (yr %% 4 == 0 & yr %% 100 != 0) | yr %% 400 == 0       # Gregorian leap year rule
  days_in_yr <- ifelse(leap, 366L, 365L)
  yr + (doy - 1L) / days_in_yr
}


# ── Block 1: Data ─────────────────────────────────────────────────────────────────

raw <- read.delim(INPUT_FILE, stringsAsFactors = FALSE, check.names = TRUE) |>
  as_tibble()
names(raw) <- gsub("\\.", "_", tolower(names(raw)))  # check.names=TRUE converts e.g. "Audit num" -> "Audit.num"; gsub replaces dots with underscores
n_raw <- nrow(raw)

audits_work <- raw |>
  select(all_of(COLS_KEEP)) |>  # all_of(): strict — errors if any name in COLS_KEEP is absent from data
  mutate(date = as.Date(trimws(date), format = "%d/%m/%Y"),
         zone = trimws(zone))

excl_list <- list()

excl_list[["No NRMM / non-machinery"]] <- audits_work |>  # [[" "]] assigns into a named slot of the list
  filter(!tolower(trimws(initial_machinery_compliance)) %in% c("compliant", "non-compliant")) |>
  transmute(date, excl_reason = "No NRMM / non-machinery")  # transmute: like mutate but drops all other columns
audits_work <- audits_work |> filter(tolower(trimws(initial_machinery_compliance)) %in% c("compliant", "non-compliant"))

excl_list[["Zone out of scope"]] <- audits_work |>
  filter(!zone %in% ZONES_IN_SCOPE) |>
  transmute(date, excl_reason = "Zone out of scope (BCP/other)")
audits_work <- audits_work |> filter(zone %in% ZONES_IN_SCOPE)

audits_work <- audits_work |>
  mutate(
    machine_type      = trimws(machine_type),
    engine_type       = trimws(engine_type),
    engine_type_clean = engine_type
  )

excl_list[["Engine type unassignable"]] <- audits_work |>
  filter(!engine_type_clean %in% c("Constant", "Variable")) |>
  transmute(date, excl_reason = "Engine type unassignable")
audits_work <- audits_work |> filter(engine_type_clean %in% c("Constant", "Variable"))

audits_work <- audits_work |>
  mutate(
    initial_stage = unname(STAGE_MAP[toupper(trimws(initial_emissions_stage))]),  # bracket lookup on named integer vector: STAGE_MAP["IIIA"] -> 3L; unname() strips the label from the result
    final_stage   = unname(STAGE_MAP[toupper(trimws(final_emissions_stage))])
  )
excl_list[["Stage unresolvable"]] <- audits_work |>
  filter(is.na(initial_stage)) |>
  transmute(date, excl_reason = "Initial stage unresolvable")
audits_work <- audits_work |> filter(!is.na(initial_stage))

covid_flag <- audits_work$date >= COVID_START & audits_work$date <= COVID_END &
  (audits_work$initial_retrofit_or_exemption %in% "Covid Exemption" |  # %in% handles NA safely; == would propagate NA as TRUE
   audits_work$final_retrofit_or_exemption   %in% "Covid Exemption")
excl_list[["COVID exempt"]] <- audits_work |>
  filter(covid_flag) |>
  transmute(date, excl_reason = "COVID exempt")
audits_work <- audits_work |> filter(!covid_flag)

audits_work <- audits_work |>
  mutate(
    no_power_rating = trimws(kw_power) == "" |
                      toupper(trimws(kw_power)) == "UNIDENTIFIED" |
                      is.na(suppressWarnings(as.numeric(trimws(kw_power)))),  # suppressWarnings: silences "NAs introduced by coercion" when strings fail numeric conversion
    kw_power        = suppressWarnings(as.numeric(trimws(kw_power)))
  )

init_flags  <- derive_compliance_flags(audits_work$initial_machinery_reasons)
final_flags <- derive_compliance_flags(audits_work$final_machinery_reasons)
audits_work <- audits_work |>
  mutate(
    init_mach_emissions_compliant  = init_flags$emissions_compliant,   # $ selects named element from the list returned by derive_compliance_flags
    init_mach_admin_compliant      = init_flags$admin_compliant,
    final_mach_emissions_compliant = final_flags$emissions_compliant,
    final_mach_admin_compliant     = final_flags$admin_compliant
  )

audits_work <- audits_work |>
  mutate(
    year      = as.integer(format(date, "%Y")),
    date_frac = fractional_year(date),
    phase     = case_when(
      date >= PHASE_A1_START & date <= PHASE_A1_END ~ "A1",
      date >= PHASE_A2_START & date <= PHASE_A2_END ~ "A2",
      date >= PHASE_B_START  & date <= PHASE_B_END  ~ "B",
      date >= PHASE_C_START                         ~ "C",
      TRUE ~ NA_character_
    )
  )

audits_work <- audits_work |>
  mutate(cold_engaged = toupper(trimws(cold_engaged)) %in% c("YES", "Y", "V"))

n_records_pre_group <- nrow(audits_work)

audits_work <- audits_work |>
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

audits <- bind_rows(
  audits_work |> mutate(group = group_primary),
  audits_work |> filter(group_primary %in% c("CAZ_Plus", "Rest_of_London")) |> mutate(group = "Variable_Speed")
) |> arrange(date, group)

audits_uniq <- audits |> filter(group == group_primary)
audits_vs   <- audits |> filter(group == "Variable_Speed")
n_vs_dupes  <- nrow(audits) - nrow(audits_uniq)

exclusions <- bind_rows(excl_list) |>  # bind_rows() on a named list collapses each tibble slot into one frame
  mutate(year = as.integer(format(date, "%Y")))

stopifnot(
  "init_mach_emissions_compliant has NAs"  = !anyNA(audits$init_mach_emissions_compliant),
  "group_primary has unassigned records"   = !anyNA(audits_uniq$group_primary),
  "cold + warm != n_records_pre_group"     = (sum(audits_uniq$cold_engaged) +
                                               sum(!audits_uniq$cold_engaged)) == n_records_pre_group
)

# --- 5. Save outputs ---
saveRDS(audits,      file.path(OUT_DIR, "audits.rds"))
saveRDS(audits_uniq, file.path(OUT_DIR, "audits_uniq.rds"))
saveRDS(exclusions,  file.path(OUT_DIR, "exclusions.rds"))

# --- 6. Completion summary ---
cat(sprintf("%-15s  %s  [%s]\n", "audits",      paste(dim(audits),      collapse = " x "), class(audits)[1]))      # class()[1]: tibbles carry 3 classes; [1] gives "tbl_df"
cat(sprintf("%-15s  %s  [%s]\n", "audits_uniq", paste(dim(audits_uniq), collapse = " x "), class(audits_uniq)[1]))
cat(sprintf("%-15s  %s  [%s]\n", "exclusions",  paste(dim(exclusions),  collapse = " x "), class(exclusions)[1]))

# --- 7. Manifest ---
manifest_rows <- paste(
  "| step | object | file | class | dimensions | description |",
  "|------|--------|------|-------|------------|-------------|",
  sprintf("| 1 | audits | audits.rds | tbl_df | %s | All ingested audit records including Variable_Speed group duplication of CAZ_Plus and Rest_of_London rows. |",
          paste(dim(audits), collapse = " x ")),     # dim() returns c(rows, cols); paste() collapses to "N x P"
  sprintf("| 1 | audits_uniq | audits_uniq.rds | tbl_df | %s | Unique audit records after all exclusion filters applied, one row per audit with group == group_primary. |",
          paste(dim(audits_uniq), collapse = " x ")),
  sprintf("| 1 | exclusions | exclusions.rds | tbl_df | %s | Excluded records with date, year, and excl_reason documenting each filter applied during ingestion. |",
          paste(dim(exclusions), collapse = " x ")),
  sep = "\n"
)
writeLines(manifest_rows, MANIFEST_FILE)
