#!/usr/bin/env Rscript

# Generates outputs/260728_data_dictionary.md: a field-by-field record of what
# audits.txt actually contains, how each value is treated by the model, and
# every data-quality fact established to date.
#
# Written as a generator rather than a hand-maintained document so it cannot
# drift from the data. Re-run it whenever the input file is refreshed.
#
# Two parts:
#   1. MECHANICAL - derived from the file: completeness, distinct values,
#      value frequencies, and each value's disposition under the current model.
#   2. CURATED - the knowledge that cannot be derived: what fields mean, which
#      quirks are known bad data, which questions are open. Held in the
#      constants below so it lives with the code and is reviewed alongside it.

library(readr)
library(dplyr)
library(tidyr)
library(knitr)

INPUT       <- "input_data/audits.txt"
OUTPUT_MD   <- "outputs/260728_data_dictionary.md"
MODEL_RDS   <- "intermediate_data/nrmm_model_v6.rds"
MAX_VALUES  <- 25     # per field, before truncating the value list

# --- CURATED: what each field is for, and how the model uses it ---

FIELD_NOTES <- tribble(
  ~field, ~role, ~note,
  "Date", "Key input",
  "Audit date, DD/MM/YYYY. Drives phase, era and the threshold that applies. Verified clean: all 16,251 parse, range 2016-06-17 to 2026-01-21, no day/month transposition.",
  "Zone", "Key input",
  "CAZ, OA or GL. With Engine Type, determines Machine Group. Unusable in 2025 records because those fall under the post-2024 P24 group, which the model does not implement.",
  "Engine Type", "Key input, UNRELIABLE",
  "Constant or Variable. Determines whether a machine is in the Constant Speed group. Known to be unreliable for generators and crushers, see quality facts Q1 and Q2.",
  "Machine Type", "Key input",
  "Free text. Normalised to lower case and mapped through TYPE_CANONICAL before use, so capitalisation variants no longer create separate categories.",
  "Cold-Engaged", "Key input",
  "Yes or No. Yes = found operating without registering, used as the counterfactual arm. No known quality issues.",
  "kW Power", "Key input",
  "Rated power, used for the power band that sets the emission limit and for the emissions-intensity weights. Missing or non-numeric for 11-39% of records depending on year; imputed from the machine-type median.",
  "TAN", "Key input, TIME-LIMITED",
  "Machine serial number, used to follow a machine between sites. Capture begins in 2021, see quality fact Q5.",
  "Initial Emissions Stage", "Key input",
  "Stage at first sight. Mapped by stage_to_int() after case normalisation. Drives compliance, the stage distribution and the replacement-rate estimate.",
  "Final Emissions Stage", "Key input",
  "Stage at the end of the audit. Static within an audit in almost all records, so outcomes are read from the compliance fields rather than from stage arithmetic.",
  "Initial Machinery Compliance", "Key input",
  "Officer determination at first sight. Also carries site-level states that are not machine determinations, see quality fact Q4.",
  "Final Machinery Compliance", "Key input",
  "Officer determination at the end. Source of the outcome taxonomy: removals, replacements, exemptions.",
  "Initial Machinery Reasons", "Key input",
  "Reason codes. E = emissions standard not met; A, C, P, R, X = administrative. The E code is what separates emissions non-compliance from paperwork problems.",
  "Initial Retrofit or Exemption", "Key input",
  "A live dispensation here means the machine is legally compliant without a newer engine. Counted as compliant, never as an emissions reduction.",
  "Final Retrofit or Exemption", "Key input",
  "Used to detect retrofits fitted during the audit and exemptions granted during the audit.",
  "EU Stage", "Unused",
  "Empty on every record inspected. Not used.",
  "Site Reference", "Context", "Site identifier. Used only to note that audits cluster within sites, which standard errors do not currently reflect.",
  "Officer", "Not used", "Not used in the analysis.",
  "Borough", "Not used", "Not used in the analysis; Zone carries the geography that matters.",
  "Major/Minor", "Not used", "Not used in the analysis.",
  "Principal Contractor", "Not used", "Not used in the analysis.",
  "Supplier", "Not used", "Not used in the analysis.",
  "Engine Manufacturer", "Not used", "Not used in the analysis.",
  "Item Manufacturer", "Not used", "Not used in the analysis."
)

# --- CURATED: data-quality facts established to date ---
# status: OPEN = question with the audit team; BAD DATA = catalogued defect we
# work around; RESOLVED = answered or fixed.

QUALITY_FACTS <- tribble(
  ~id, ~field, ~status, ~fact, ~handling,
  "Q1", "Engine Type", "OPEN",
  "All 218 generators recorded at Stage V carry Engine Type 'Variable'; none carries 'Constant'. Stage IIIA generators audited in the same years are 80% 'Constant'. Because the Constant Speed group is defined by this field, generators leave the group at the moment they upgrade, so the group cannot show improvement. 17 of ~85 repeat-audited generators carry both labels at different visits. Hybrid, flywheel and flybrid units split 37 'Constant' to 51 'Variable', which looks deliberate, so a blanket rule would be unsafe.",
  "Default remains as recorded. GENERATOR_MODE exposes the alternative and classification_sensitivity reports both readings. Constant Speed results are flagged provisional and must not be cited.",

  "Q2", "Engine Type", "OPEN",
  "Crushers show the same shape on smaller numbers: 15 records 'Constant', all at Stage IIIA; all 76 at IIIB, IV and V are 'Variable'. Median engine size is similar either way (218 vs 202 kW).",
  "Same handling as Q1; one answer resolves both.",

  "Q3", "Initial/Final Emissions Stage", "RESOLVED",
  "'Electric' appears as a stage value on 31 records (Battery Packs, forklifts, pumps, MEWPs), growing from 1 in 2022 to 15 in 2025. Audit team confirmed 28 July 2026 that this means zero emission.",
  "Mapped to stage 7 alongside 'ZE' from model v6. Previously dropped, which removed the cleanest machines from the distribution in the years it is improving fastest.",

  "Q4", "Initial/Final Machinery Compliance", "RESOLVED",
  "Site-level audit states (Baselining, Site Complete, No Apparent Works, DECLINED AUDIT) are logged into machine-level compliance fields on 1,662 records, and into the stage fields on 883. The machine data is often still present: 577 of the 1,662 carry a usable stage. Reason codes read 'None' on 1,594 of them, so no E-flag inference is possible.",
  "Status X, no determination made: the stage is kept, the compliance outcome is voided. Affects 60 records that reach the model, 34 of them in phase C which holds only 63.",

  "Q5", "TAN", "BAD DATA",
  "Serial number capture begins part-way through the programme: none usable in 2016-2020, 41% in 2021, 85-90% in 2022-2024, 77% in 2025. All 345 removals before 2021 are therefore untraceable by construction, and a machine removed recently has had less time to reappear.",
  "Catalogued, not a question. The untraceable bucket is reported as a time artefact rather than random missingness, and displacement is reported by year of removal with the observation window attached. The headline 55.9% is a right-censored lower bound: 62% for 2021 removals falling to 45% for 2025.",

  "Q6", "Initial Emissions Stage", "BAD DATA",
  "The same machine is recorded at different stages on different visits: 30 of 598 repeat-audited machines, 20 differing by one stage, 8 by two and 2 by four. A four-stage difference on one machine is a recording error, not an upgrade. At record level the noise is ~1% and symmetric (43 up, 43 down).",
  "Catalogued, not a question. Detected and reported by stage_inconsistency. Cross-sectional distributions remain reliable because the noise is symmetric; machine-level transitions are not, which is why the Markov model is fitted from cross-sections rather than individual histories.",

  "Q7", "Final Machinery Compliance", "BAD DATA",
  "'Pending' appears as a final outcome on 23 records, all 2018-2020, meaning the case was unresolved when the data was extracted.",
  "Catalogued, not a question. Currently falls into 'not remediated', which slightly overstates non-remediation on 23 of 11,643 records. Immaterial at this scale; revisit if a refreshed extract resolves them.",

  "Q8", "Initial/Final Emissions Stage", "OPEN",
  "'Uncertified' appears as a stage value on 25 initial and 26 final records. Unclear whether the engine carries no type approval at all, or approval could not be confirmed on the day.",
  "Currently unmapped and excluded, but counted and reported in unmapped_values rather than dropped silently.",

  "Q9", "Machine Type", "OPEN",
  "'Inappropriate for Audit' appears on 131 records across two capitalisations. None carries a usable emissions stage.",
  "Currently retained, unlike 'No NRMM' (891 records) which is excluded. Cannot affect stage-based results; may affect record counts.",

  "Q10", "Machine Type", "RESOLVED",
  "Free text with near-duplicates: 'MEWP' (359) alongside 'Mewp' (13); 'Piling Rig' (392) alongside 'Piling rig' (1); 'Drilling Rig' (2) alongside 'Drilling rig' (1).",
  "Normalised to lower case at ingestion and mapped through TYPE_CANONICAL from model v6. Previously 'Mewp' fell into the 'Other' bucket.",

  "Q11", "Initial/Final Emissions Stage", "RESOLVED",
  "Case typos 'iIIB' (1 record) and 'iV' (3 records).",
  "Stage strings are upper-cased and trimmed before matching from model v5, so these now resolve.",

  "Q12", "Zone", "BAD DATA",
  "Zone is unusable on all 2025 records. This is expected rather than a defect: those machines fall under the post-2024 P24 group, which is a single zone and a structurally different problem.",
  "Catalogued. P24 is not implemented, so the 2025 variable-speed cohort is dropped and phase C holds 63 machines. Backlog item: comparison across the discontinuity would require regrouping everything onto a common basis.",

  "Q13", "kW Power", "BAD DATA",
  "Missing or non-numeric on 11-39% of records depending on year, worst in the early years. Some values are ranges rather than numbers.",
  "Ranges are read as their midpoint; the rest are imputed from the machine-type median. Affects the power band and therefore the emission limit applied, and the emissions-intensity weights."
)

# --- Load and derive ---

cat("Reading", INPUT, "...\n")
audits <- read_delim(INPUT, delim = "\t", show_col_types = FALSE)

normalise <- function(x) trimws(tolower(ifelse(is.na(x), "", as.character(x))))

audit_date <- as.Date(audits$Date, format = "%d/%m/%Y")
audits$.year <- as.integer(format(audit_date, "%Y"))

# fields treated as categorical for the value inventory
CATEGORICAL <- c("Zone", "Engine Type", "Cold-Engaged", "Machine Type",
                 "Initial Emissions Stage", "Final Emissions Stage",
                 "Initial Machinery Compliance", "Final Machinery Compliance",
                 "Initial Machinery Reasons", "Final Machinery Reasons",
                 "Initial Retrofit or Exemption", "Final Retrofit or Exemption",
                 "Initial Site Compliance", "Final Site Compliance", "Audit Type")
CATEGORICAL <- intersect(CATEGORICAL, names(audits))

# disposition of a value under the current model
STAGE_MAPPED <- c("I", "II", "IIIA", "IIIB", "IV", "V", "ZE", "ELECTRIC",
                  "1", "2", "3", "4", "5", "6")
SITE_STATES  <- c("baselining", "site complete", "no apparent works", "declined audit")

disposition <- function(field, value) {
  v <- toupper(trimws(ifelse(is.na(value), "", value)))
  vl <- tolower(trimws(ifelse(is.na(value), "", value)))
  if (grepl("Emissions Stage", field)) {
    if (v %in% STAGE_MAPPED) return("mapped to a stage")
    if (vl %in% SITE_STATES) return("site-level state, stage not read")
    if (vl %in% c("no nrmm", "inappropriate for audit")) return("out of scope / not a machine")
    return("UNMAPPED - excluded, counted in unmapped_values")
  }
  if (field == "Engine Type") {
    if (v %in% c("CONSTANT", "VARIABLE")) return("used for Machine Group")
    return("no group assignable - record dropped")
  }
  if (grepl("Machinery Compliance", field)) {
    if (vl %in% SITE_STATES) return("status X - no determination made")
    return("used in the outcome taxonomy")
  }
  "carried through"
}

field_summary <- bind_rows(lapply(names(audits)[!startsWith(names(audits), ".")], function(f) {
  col <- audits[[f]]
  tibble(field = f,
         type = class(col)[1],
         n_missing = sum(is.na(col) | trimws(as.character(col)) == ""),
         pct_missing = round(100 * sum(is.na(col) | trimws(as.character(col)) == "") / nrow(audits)),
         n_distinct = n_distinct(col))
}))

value_inventory <- bind_rows(lapply(CATEGORICAL, function(f) {
  audits %>%
    count(.data[[f]], name = "n") %>%
    rename(value = 1) %>%
    arrange(desc(n)) %>%
    mutate(field = f,
           value = ifelse(is.na(value), "(missing)", as.character(value)),
           share = paste0(round(100 * n / nrow(audits), 2), "%"),
           disposition = vapply(value, function(v) disposition(f, v), character(1))) %>%
    slice_head(n = MAX_VALUES) %>%
    select(field, value, n, share, disposition)
}))

completeness_by_year <- audits %>%
  group_by(year = .year) %>%
  summarise(
    records = n(),
    `Engine Type` = paste0(round(100 * mean(!`Engine Type` %in% c("Constant", "Variable"))), "%"),
    `kW Power` = paste0(round(100 * mean(is.na(suppressWarnings(as.numeric(`kW Power`))))), "%"),
    TAN = paste0(round(100 * mean(is.na(TAN) | normalise(TAN) %in%
                          c("", "unidentified", "none", "n/a", "na"))), "%"),
    `Initial Stage` = paste0(round(100 * mean(!`Initial Emissions Stage` %in%
                          c("I", "II", "IIIA", "IIIB", "IV", "V", "ZE", "Electric"))), "%"),
    Zone = paste0(round(100 * mean(!Zone %in% c("CAZ", "OA", "GL"))), "%"),
    .groups = "drop"
  )

# --- Verification ---

stopifnot(nrow(field_summary) > 0, nrow(value_inventory) > 0)
unmapped_now <- value_inventory %>% filter(grepl("^UNMAPPED", disposition))
cat("  fields:", nrow(field_summary), "| categorical values listed:", nrow(value_inventory),
    "| still unmapped:", nrow(unmapped_now), "\n")

# --- Write ---

md <- c(
  "# Data dictionary: `input_data/audits.txt`",
  "",
  paste0("*Generated by `260728_data_dictionary.R` from ", nrow(audits),
         " records. Re-run after any refresh of the input file rather than editing by hand.*"),
  "",
  "This is the canonical record of what the audit file contains, how each value is",
  "treated by the model, and every data-quality fact established to date. It exists",
  "because the absence of exactly this document allowed three classification errors",
  "to go unnoticed through four model versions.",
  "",
  "---",
  "",
  "## 1. Data-quality facts",
  "",
  "**OPEN** = question with the audit team. **BAD DATA** = catalogued defect we work",
  "around and report. **RESOLVED** = answered or fixed.",
  "",
  kable(QUALITY_FACTS %>% select(id, field, status, fact), format = "pipe",
        col.names = c("#", "Field", "Status", "What the data shows")),
  "",
  "### How each is handled",
  "",
  kable(QUALITY_FACTS %>% select(id, handling), format = "pipe",
        col.names = c("#", "Handling in the model")),
  "",
  "## 2. Fields: role and meaning",
  "",
  kable(FIELD_NOTES, format = "pipe", col.names = c("Field", "Role", "Notes")),
  "",
  "## 3. Field completeness",
  "",
  kable(field_summary, format = "pipe",
        col.names = c("Field", "Type", "Missing", "% missing", "Distinct values")),
  "",
  "## 4. Unusable share by year, key fields",
  "",
  "Share of records where the field cannot be used as recorded.",
  "",
  kable(completeness_by_year, format = "pipe"),
  "",
  "## 5. Value inventory and disposition",
  "",
  paste0("Every distinct value of each categorical field, up to the ", MAX_VALUES,
         " most frequent, with how the current model treats it. Anything marked",
         " UNMAPPED is excluded from stage-based analysis but counted in the model's",
         " `unmapped_values` object rather than dropped silently."),
  "",
  kable(value_inventory, format = "pipe",
        col.names = c("Field", "Value", "n", "Share", "Disposition")),
  ""
)

writeLines(md, OUTPUT_MD)
cat("Written:", OUTPUT_MD, "\n")
