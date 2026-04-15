# 260329_step1_ingestion.R
# NRMM LEZ Analysis — Phase 1-2: Data Ingestion & Segmentation
# Outputs: df_raw, df, df_cold, df_warm, df_ze, n_ze -> 260329_step1_ingestion.RData

library(tidyverse)

# ── Tee output to console + TXT file ─────────────────────────────────────────
log_con <- file("260329_step1_console_output.txt", open = "wt")
sink(log_con, split = TRUE)

# ── 1. Load ───────────────────────────────────────────────────────────────────
df_raw <- read.delim("audits.txt", stringsAsFactors = FALSE)
names(df_raw) <- trimws(names(df_raw))
cat("Raw rows:", nrow(df_raw), "\n")

# ── 2. Parse date & filter analysis period ────────────────────────────────────
df_raw$Date <- as.Date(df_raw$Date, format = "%d/%m/%Y")
cat("Rows with unparseable Date:", sum(is.na(df_raw$Date)), "\n")

df <- df_raw %>% filter(Date >= as.Date("2016-01-01"), Date <= as.Date("2024-12-31"))
cat("After date filter:", nrow(df), "\n")

# ── 3. Machinery compliance filter ───────────────────────────────────────────
compliance_vals <- c("compliant", "non-compliant")
df$compliance_lower <- tolower(trimws(df$Initial.Machinery.Compliance))

filter_stats <- df %>%
  filter(!compliance_lower %in% compliance_vals) %>%
  count(Initial.Machinery.Compliance, name = "n") %>%
  arrange(desc(n))
cat("\nRows excluded by compliance filter:\n")
print(filter_stats)
cat("Total excluded:", sum(filter_stats$n), "\n")

df <- df %>% filter(compliance_lower %in% compliance_vals)
df$compliance_lower <- NULL
cat("After compliance filter:", nrow(df), "\n")

# ── 4. Zone filter ────────────────────────────────────────────────────────────
df$Zone.clean       <- trimws(df$Zone)
df$Engine.Type.clean <- trimws(df$Engine.Type)

zone_filter_stats <- df %>%
  filter(!Zone.clean %in% c("CAZ", "OA", "GL")) %>%
  count(Zone.clean, name = "n") %>%
  arrange(desc(n))
cat("\nRows excluded by zone filter:\n")
print(zone_filter_stats)
cat("Total excluded:", sum(zone_filter_stats$n), "\n")

df <- df %>% filter(Zone.clean %in% c("CAZ", "OA", "GL"))
cat("After zone filter:", nrow(df), "\n")

# ── 5. Group derivation ───────────────────────────────────────────────────────
# Override Engine Type for generator-family Machine Types unconditionally.
# Raw data contains ~360 Generator records mislabelled "Variable"; this corrects
# all blank, Unidentified, and mislabelled entries for known constant-speed types.
constant_speed_machine_types <- c("Generator", "Hybrid Generator",
                                  "Flywheel Generator", "Flybrid Generator")
df <- df %>% mutate(
  # Step 1: override generator-family to Constant unconditionally (fixes ~360
  #         Phase B generators mislabelled "Variable" in raw data)
  Engine.Type.clean = if_else(
    trimws(Machine.Type) %in% constant_speed_machine_types,
    "Constant",
    Engine.Type.clean
  ),
  # Step 2: fill remaining blanks with Variable (restores A1 variable-speed
  #         records where Engine Type column was unpopulated)
  Engine.Type.clean = if_else(Engine.Type.clean == "", "Variable", Engine.Type.clean)
)
cat("Engine Type overridden to Constant (generator-family Machine Types):",
    sum(trimws(df$Machine.Type) %in% constant_speed_machine_types), "\n")
cat("Engine Type filled blank → Variable (remaining blanks):",
    sum(trimws(df$Engine.Type) == "" & !trimws(df$Machine.Type) %in% constant_speed_machine_types), "\n")

df <- df %>% mutate(
  Group = case_when(
    Engine.Type.clean == "Constant"                                   ~ "Constant_Speed",
    Engine.Type.clean == "Variable" & Zone.clean %in% c("CAZ", "OA") ~ "CAZ_Plus",
    Engine.Type.clean == "Variable" & Zone.clean == "GL"              ~ "Rest_of_London",
    TRUE ~ NA_character_
  )
)

unassigned <- df %>%
  filter(is.na(Group)) %>%
  count(Engine.Type.clean, name = "n") %>%
  arrange(desc(n))
cat("\nRows excluded — unassignable Engine Type:\n")
print(unassigned)
cat("Total excluded:", sum(unassigned$n), "\n")

df <- df %>% filter(!is.na(Group))
cat("After group assignment:", nrow(df), "\n")

# ── 6. kW parsing & 37–560 kW scope filter ───────────────────────────────────
df$kW <- suppressWarnings(as.numeric(trimws(df$kW.Power)))
df$kW_missing <- is.na(df$kW)
cat("Rows with missing/non-numeric kW (kept, flagged):", sum(df$kW_missing), "\n")

out_of_scope_kw <- df %>% filter(!kW_missing, (kW < 37 | kW > 560)) %>% nrow()
cat("Rows excluded — numeric kW outside 37–560:", out_of_scope_kw, "\n")
df <- df %>% filter(kW_missing | (kW >= 37 & kW <= 560))
cat("After kW scope filter:", nrow(df), "\n")

# ── 7. Stage standardisation ──────────────────────────────────────────────────
stage_map <- c("I" = 1L, "II" = 2L, "IIIA" = 3L, "IIIB" = 4L, "IV" = 5L, "V" = 6L, "ZE" = 7L)

clean_stage <- function(x) {
  x <- trimws(x)
  x[x == "iIIB"] <- "IIIB"
  x[x == "iV"]   <- "IV"
  x
}

df$Initial.Stage.raw <- clean_stage(df$Initial.Emissions.Stage)
df$Final.Stage.raw   <- clean_stage(df$Final.Emissions.Stage)
df$Initial.Stage     <- stage_map[df$Initial.Stage.raw]
df$Final.Stage       <- stage_map[df$Final.Stage.raw]

# ── 8. Extract ZE / Electric; keep count; drop from main ─────────────────────
df_ze <- df %>% filter(Initial.Stage.raw == "ZE" | Engine.Type.clean == "Electric")
n_ze  <- nrow(df_ze)
cat("\nZE / Electric records extracted (n_ze):", n_ze, "\n")

df <- df %>% filter(Initial.Stage.raw != "ZE", Engine.Type.clean != "Electric")

n_na_stage <- sum(is.na(df$Initial.Stage))
cat("Rows with unresolvable Initial Stage (dropped):", n_na_stage, "\n")
df <- df %>% filter(!is.na(df$Initial.Stage))
cat("After ZE/stage filter:", nrow(df), "\n")

# ── 9. Cold-Engaged normalisation ─────────────────────────────────────────────
df <- df %>% mutate(Cold_Engaged = toupper(trimws(Cold.Engaged)) %in% c("YES", "V"))
cat("\nCold-Engaged: Yes =", sum(df$Cold_Engaged), "| No =", sum(!df$Cold_Engaged), "\n")

# ── 10. COVID filter ──────────────────────────────────────────────────────────
covid_window <- df$Date >= as.Date("2020-09-01") & df$Date <= as.Date("2021-03-31")
covid_flag   <- grepl("covid", tolower(df$Initial.Retrofit.or.Exemption)) |
                grepl("covid", tolower(df$Final.Retrofit.or.Exemption))
df$COVID_Exempt <- covid_window & covid_flag
cat("COVID-exempt records excluded:", sum(df$COVID_Exempt), "\n")
df <- df %>% filter(!COVID_Exempt)
cat("After COVID filter:", nrow(df), "\n")

# ── 11. Model Phase assignment ────────────────────────────────────────────────
df <- df %>% mutate(
  Phase = case_when(
    Date >= as.Date("2016-01-01") & Date <= as.Date("2018-12-31") ~ "A1",
    Date >= as.Date("2019-01-01") & Date <= as.Date("2020-08-31") ~ "A2",
    Date >= as.Date("2020-09-01") & Date <= as.Date("2024-12-31") ~ "B",
    TRUE ~ NA_character_
  )
)
cat("\nPhase distribution:\n")
print(table(df$Phase))

# ── 12. Enforcement flag ──────────────────────────────────────────────────────
df$Enforcement_Upgrade <- !is.na(df$Initial.Stage) & !is.na(df$Final.Stage) &
                          df$Final.Stage > df$Initial.Stage
cat("\nEnforcement upgrades observed:", sum(df$Enforcement_Upgrade), "\n")

# ── 13. Bifurcate cold / warm ─────────────────────────────────────────────────
df_cold <- df %>% filter(Cold_Engaged)
df_warm <- df %>% filter(!Cold_Engaged)
cat("\nFinal — Cold:", nrow(df_cold), "| Warm:", nrow(df_warm), "\n")

# ── 14. Group × Phase summaries ───────────────────────────────────────────────
cat("\nWarm fleet — Group × Phase:\n")
print(table(df_warm$Group, df_warm$Phase))
cat("\nCold fleet — Group × Phase:\n")
print(table(df_cold$Group, df_cold$Phase))

# ── 15. Save ──────────────────────────────────────────────────────────────────
save(df_raw, df, df_cold, df_warm, df_ze, n_ze, file = "260329_step1_ingestion.RData")
cat("\nSaved: 260329_step1_ingestion.RData\n")
cat("Objects: df_raw, df, df_cold, df_warm, df_ze, n_ze\n")

sink()
close(log_con)
cat("Log written to: 260329_step1_console_output.txt\n")
