# 260330_diagnostic_enforcement.R
# Diagnostic: Enforcement pathways, compliance definition gap, cold/warm flag scope
# Loads full pre-slimmed df from step 1 to access dropped columns
# Date: 30 March 2026

library(tidyverse)
sink("260330_diagnostic_enforcement.txt", split = TRUE)

load("260329_step1_ingestion.RData")   # full df, df_warm, df_cold
df$yr      <- as.integer(format(df$Date, "%Y"))
df_warm$yr <- as.integer(format(df_warm$Date, "%Y"))
df_cold$yr <- as.integer(format(df_cold$Date, "%Y"))

# Step 1 saves df with all original columns still attached (slimming happens in step 2)
# Confirm presence of key columns
cat("Columns available in df:\n")
print(names(df))

# ── 1. Compliance definition mismatch ─────────────────────────────────────────
# Compare: actual Initial.Machinery.Compliance vs Stage-threshold-based compliance
# Re-apply compliance thresholds
comp_thresh <- list(
  A1 = c(Constant_Speed = 3L, CAZ_Plus = 4L, Rest_of_London = 3L),
  A2 = c(Constant_Speed = 3L, CAZ_Plus = 4L, Rest_of_London = 3L),
  B  = c(Constant_Speed = 6L, CAZ_Plus = 5L, Rest_of_London = 4L)
)

df2 <- df %>%
  mutate(
    thresh         = mapply(function(ph, grp) comp_thresh[[ph]][[grp]], Phase, Group),
    stage_compliant = Initial.Stage >= thresh,
    mc_lower        = tolower(trimws(Initial.Machinery.Compliance)),
    mc_compliant    = mc_lower == "compliant"
  )

cat("\n══ 1. COMPLIANCE DEFINITION COMPARISON (warm fleet) ══\n")
cat("\nCross-tab: Stage-based compliance vs Initial.Machinery.Compliance\n")
df_warm2 <- df2 %>% filter(!Cold_Engaged)
print(table(
  Stage_compliant = df_warm2$stage_compliant,
  MC_compliant    = df_warm2$mc_compliant
))

cat("\nRecords where Stage says non-compliant but MC says compliant (retrofits/exemptions):\n")
mismatch_nc_stage <- df_warm2 %>% filter(!stage_compliant, mc_compliant)
cat(sprintf("  n = %d  (%.1f%% of warm fleet)\n", nrow(mismatch_nc_stage),
            100 * nrow(mismatch_nc_stage) / nrow(df_warm2)))
cat("  Initial.Retrofit.or.Exemption breakdown:\n")
count(mismatch_nc_stage, Initial.Retrofit.or.Exemption, sort = TRUE) %>% head(20) %>% print()

cat("\nRecords where MC says non-compliant but Stage says compliant (data/threshold mismatch):\n")
mismatch_mc_nc <- df_warm2 %>% filter(stage_compliant, !mc_compliant)
cat(sprintf("  n = %d  (%.1f%% of warm fleet)\n", nrow(mismatch_mc_nc),
            100 * nrow(mismatch_mc_nc) / nrow(df_warm2)))

# ── 2. True enforcement exposure using Initial.Machinery.Compliance ─────────────
cat("\n══ 2. ē USING Initial.Machinery.Compliance (vs Stage-threshold) ══\n")

ebar_mc <- df_warm2 %>%
  group_by(Group, Phase) %>%
  summarise(
    n_warm           = n(),
    n_nc_stage       = sum(!stage_compliant,   na.rm = TRUE),
    n_nc_mc          = sum(!mc_compliant,       na.rm = TRUE),
    e_bar_stage      = n_nc_stage / n_warm,
    e_bar_mc         = n_nc_mc    / n_warm,
    .groups = "drop"
  )
print(ebar_mc)

cat("\nOverall warm fleet non-compliance rate:\n")
cat(sprintf("  Stage-threshold: %.1f%%\n",
            100 * sum(ebar_mc$n_nc_stage) / sum(ebar_mc$n_warm)))
cat(sprintf("  MC field:        %.1f%%\n",
            100 * sum(ebar_mc$n_nc_mc)    / sum(ebar_mc$n_warm)))

# ── 3. Final compliance outcomes for initially non-compliant machines ──────────
cat("\n══ 3. ENFORCEMENT RESOLUTION OUTCOMES (warm fleet, non-compliant at initial) ══\n")

outcomes <- df_warm2 %>%
  filter(!mc_compliant) %>%
  mutate(final_mc = trimws(Final.Machinery.Compliance)) %>%
  count(Group, Phase, final_mc) %>%
  arrange(Group, Phase, desc(n))

cat("\nBy Group × Phase × Final outcome:\n")
outcomes %>% head(60) %>% print()

# Summary across all groups
cat("\nOverall final outcome distribution for initially non-compliant warm records:\n")
df_warm2 %>%
  filter(!mc_compliant) %>%
  mutate(final_mc = trimws(Final.Machinery.Compliance)) %>%
  count(final_mc, sort = TRUE) %>%
  mutate(pct = 100 * n / sum(n)) %>%
  print()

# ── 4. Retrofit / exemption pathways ──────────────────────────────────────────
cat("\n══ 4. RETROFIT / EXEMPTION PATHWAYS ══\n")
cat("\nInitial.Retrofit.or.Exemption — warm fleet breakdown:\n")
df_warm2 %>%
  count(Initial.Retrofit.or.Exemption, sort = TRUE) %>%
  mutate(pct = 100 * n / sum(n)) %>%
  head(20) %>% print()

cat("\nFinal.Retrofit.or.Exemption — warm fleet breakdown:\n")
df_warm2 %>%
  count(Final.Retrofit.or.Exemption, sort = TRUE) %>%
  mutate(pct = 100 * n / sum(n)) %>%
  head(20) %>% print()

# ── 5. Cold/Warm flag: Machine-level or Site-level? ───────────────────────────
cat("\n══ 5. COLD/WARM FLAG SCOPE: MACHINE vs SITE ══\n")

# Check if Site.Reference is available
site_col <- grep("site.ref|site ref", names(df), ignore.case = TRUE, value = TRUE)
cat("Site reference column(s) found:", paste(site_col, collapse = ", "), "\n")

if (length(site_col) > 0) {
  sc <- site_col[1]

  # For each site, count number of unique audit visits and machines
  site_summary <- df %>%
    group_by(site = .data[[sc]]) %>%
    summarise(
      n_records      = n(),
      n_cold         = sum(Cold_Engaged),
      n_warm         = sum(!Cold_Engaged),
      n_years        = n_distinct(yr),
      has_both       = any(Cold_Engaged) & any(!Cold_Engaged),
      .groups = "drop"
    )

  cat(sprintf("\nTotal unique sites: %d\n", nrow(site_summary)))
  cat(sprintf("Sites with BOTH cold and warm records: %d (%.1f%%)\n",
              sum(site_summary$has_both),
              100 * mean(site_summary$has_both)))
  cat(sprintf("Sites with ONLY cold records:  %d\n", sum(!site_summary$has_both & site_summary$n_cold > 0)))
  cat(sprintf("Sites with ONLY warm records:  %d\n", sum(!site_summary$has_both & site_summary$n_warm > 0)))

  cat("\nDistribution of n_cold per site (sites with both cold+warm):\n")
  print(table(site_summary$n_cold[site_summary$has_both]))

  # Key test: if cold/warm is SITE-level, sites should have cold records only on first visit
  # and warm on subsequent visits. Check if any site has cold records on a later year
  # than its warm records.
  cold_warm_timing <- suppressWarnings(df %>%
    filter(.data[[sc]] != "") %>%
    group_by(site = .data[[sc]]) %>%
    summarise(
      first_cold_year = min(yr[Cold_Engaged],  na.rm = TRUE),
      first_warm_year = min(yr[!Cold_Engaged], na.rm = TRUE),
      last_cold_year  = max(yr[Cold_Engaged],  na.rm = TRUE),
      has_both        = any(Cold_Engaged) & any(!Cold_Engaged),
      .groups = "drop"
    )) %>%
    filter(has_both, is.finite(first_cold_year), is.finite(first_warm_year))

  cat("\nFor sites with both cold+warm records:\n")
  cat(sprintf("  Cold always before warm (site-level flag): %d / %d (%.1f%%)\n",
              sum(cold_warm_timing$last_cold_year <= cold_warm_timing$first_warm_year),
              nrow(cold_warm_timing),
              100 * mean(cold_warm_timing$last_cold_year <= cold_warm_timing$first_warm_year)))
  cat(sprintf("  Cold records appearing in SAME year as warm: %d\n",
              sum(cold_warm_timing$first_cold_year == cold_warm_timing$first_warm_year)))
  cat(sprintf("  Cold records appearing AFTER warm: %d\n",
              sum(cold_warm_timing$last_cold_year > cold_warm_timing$first_warm_year)))
}

# ── 6. ID column — machine-level tracking ─────────────────────────────────────
cat("\n══ 6. MACHINE ID TRACKING ══\n")
id_col <- grep("^ID$|machine.id|equipment.id", names(df), ignore.case = TRUE, value = TRUE)
cat("Machine ID column(s):", paste(id_col, collapse = ", "), "\n")

if (length(id_col) > 0) {
  mid <- id_col[1]
  id_clean <- trimws(iconv(df[[mid]], to = "UTF-8", sub = ""))
  id_clean[id_clean == ""] <- NA
  n_nonempty <- sum(!is.na(id_clean))
  n_unique   <- n_distinct(id_clean, na.rm = TRUE)
  cat(sprintf("  Records with non-empty ID: %d / %d\n", n_nonempty, nrow(df)))
  cat(sprintf("  Unique IDs: %d\n", n_unique))

  # Check if machines appear multiple times
  multi <- df %>%
    mutate(id_clean = trimws(iconv(.data[[mid]], to = "UTF-8", sub = ""))) %>%
    filter(!is.na(id_clean), id_clean != "") %>%
    group_by(id_clean) %>%
    summarise(n_records = n(), n_cold = sum(Cold_Engaged), n_warm = sum(!Cold_Engaged), .groups="drop") %>%
    filter(n_records > 1)

  cat(sprintf("  Machines (ID) appearing multiple times: %d\n", nrow(multi)))
  cat("  Distribution of appearances per machine:\n")
  print(table(multi$n_records))
  cat("  Of multi-record machines, those with both cold+warm flags:\n")
  print(table(both = multi$n_cold > 0 & multi$n_warm > 0))
}

sink()
