# Output and reporting for Step 1, the data ingestion phase and basic reporting


# ── Block 2: Output ───────────────────────────────────────────────────────────────

make_count_table <- function(df) {
  raw <- df |>
    filter(!is.na(phase)) |>
    count(group, phase, name = "n")
  grid <- expand_grid(group = factor(GROUP_ORDER, levels = GROUP_ORDER), phase = PHASE_ORDER)
  tbl <- grid |>
    left_join(raw, by = c("group", "phase")) |>
    mutate(n = replace_na(n, 0L)) |>
    pivot_wider(names_from = phase, values_from = n) |>
    arrange(group)
  na_counts <- df |> filter(is.na(phase)) |> count(group, name = "NA_phase")
  tbl <- tbl |> left_join(na_counts, by = "group") |> mutate(NA_phase = replace_na(NA_phase, 0L))
  tbl |> mutate(Total = rowSums(across(where(is.integer))))
}

counts_uniq_all  <- make_count_table(audits_uniq)
counts_uniq_cold <- make_count_table(filter(audits_uniq,  cold_engaged))
counts_uniq_warm <- make_count_table(filter(audits_uniq, !cold_engaged))
counts_expanded  <- make_count_table(audits)

excl_yr <- exclusions |>
  count(year, excl_reason, name = "n") |>
  arrange(year)
excl_yr_wide <- excl_yr |>
  pivot_wider(names_from = excl_reason, values_from = n, values_fill = 0L)

stage_yr <- audits_uniq |>
  filter(!is.na(initial_stage)) |>
  count(year, initial_stage, name = "n") |>
  mutate(stage_label = factor(STAGE_LABELS[as.character(initial_stage)],
                               levels = STAGE_LABELS))

stage_yr_grp <- audits_uniq |>
  filter(!is.na(initial_stage)) |>
  count(group_primary, year, initial_stage, name = "n") |>
  rename(group = group_primary) |>
  mutate(
    group       = factor(group, levels = GROUP_ORDER),
    stage_label = factor(STAGE_LABELS[as.character(initial_stage)],
                          levels = STAGE_LABELS)
  )

NC_STATUS_LEVELS <- c(
  "E: Emissions (remained NC)",
  "R: Registration (remained NC)",
  "Other (remained NC)",
  "Became compliant",
  "Compliant"
)

# Direct lookup: classify_nc_sub() output → NC_STATUS_LEVELS name.
# Avoids sub()/paste0() reconstruction which breaks for "Other (A/C/P/X)"
# (no ': ' separator → second sub() returns the full string unchanged).
NC_SUB_TO_LEVEL <- c(
  "E: Emissions"    = "E: Emissions (remained NC)",
  "R: Registration" = "R: Registration (remained NC)",
  "Other (A/C/P/X)" = "Other (remained NC)",
  "Unknown NC"      = "Other (remained NC)"
)

classify_nc_sub <- function(reasons) {
  r_raw <- trimws(replace_na(as.character(reasons), ""))
  case_when(
    grepl("E", r_raw, fixed = TRUE) ~ "E: Emissions",
    grepl("R", r_raw, fixed = TRUE) ~ "R: Registration",
    grepl("[ACPXacpx]", r_raw)      ~ "Other (A/C/P/X)",
    TRUE                            ~ "Unknown NC"
  )
}

nc_status <- audits_uniq |>
  mutate(
    nc_status = case_when(
      init_mach_emissions_compliant                                   ~ "Compliant",
      !init_mach_emissions_compliant & final_mach_emissions_compliant ~ "Became compliant",
      !init_mach_emissions_compliant & !final_mach_emissions_compliant ~
        NC_SUB_TO_LEVEL[classify_nc_sub(initial_machinery_reasons)],
      TRUE ~ "Unknown"
    ),
    nc_status = factor(nc_status, levels = NC_STATUS_LEVELS)
  )

nc_yr        <- nc_status |> count(year, nc_status, name = "n")
compliant_yr <- nc_yr |> filter(nc_status == "Compliant") |> select(year, n_compliant = n)
nc_noncomp   <- nc_yr |> filter(nc_status != "Compliant") |> droplevels()

# Wide table for display — exclude year from rowSums (year is integer; must not be summed)
nc_wide <- nc_yr |>
  pivot_wider(names_from = nc_status, values_from = n, values_fill = 0L) |>
  mutate(Total = rowSums(across(!any_of("year"))))

grp_yr <- audits_uniq |>
  mutate(
    group      = factor(group, levels = GROUP_ORDER),
    engagement = if_else(cold_engaged, "Cold", "Warm")
  ) |>
  count(year, group, engagement, name = "n")

vs_yr <- audits_vs |>
  mutate(sub_group = factor(group_primary, levels = GROUP_ORDER)) |>
  count(year, sub_group, name = "n")

excl_by_reason <- exclusions |> count(excl_reason, name = "n")
n_excl_total   <- nrow(exclusions)

checksum_tbl <- bind_rows(
  tibble(item = "Raw records imported",    n = n_raw,            status = ""),
  excl_by_reason |> transmute(item = paste0("  Excluded — ", excl_reason), n, status = ""),
  tibble(item = "  Total excluded",        n = n_excl_total,     status = ""),
  tibble(item = "Unique records retained", n = n_unique_records, status = ""),
  tibble(item = "VS duplicate rows added", n = n_vs_dupes,       status = ""),
  tibble(item = "Total rows in audits.rds",n = nrow(audits),     status = ""),
  tibble(item = "Checksum (retained + excluded = raw)", n = n_unique_records + n_excl_total,
         status = if (n_raw == n_unique_records + n_excl_total) "PASS" else "FAIL")
)

phase_cs <- audits_uniq |>
  mutate(phase_label = coalesce(phase, "NA (between-boundary)")) |>
  count(phase_label, name = "n") |>
  bind_rows(tibble(phase_label = "TOTAL", n = n_unique_records))

amd <- function(...) cat(paste0(...), "\n", file = OUTPUT_MD, append = TRUE, sep = "")

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
  invisible(tbl)
}

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

if (!dir.exists(OUTPUTS_DIR)) dir.create(OUTPUTS_DIR, recursive = TRUE)
writeLines(c(
  paste0("# Step 1 Outputs — ", SCRIPT_STEM),
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  ""
), OUTPUT_MD)

amd("\n## Step 1.1–1.4 Record Counts\n")

amd("\n### Note on row structure\n")
amd(paste0(
  "audits.rds contains **", nrow(audits), " rows** representing **",
  n_unique_records, " unique audit records** plus **", n_vs_dupes,
  " duplicate rows** for the Variable_Speed continuous series. ",
  "Use `filter(group == group_primary)` to work with unique records only."
))
amd("")

amd("\n### Unique records by primary group × phase\n")
write_kable(counts_uniq_all, "Unique audit records by primary group × phase",
            add_phase_header = TRUE)
amd("One row per unique audit record; group_primary is the 4-way zone assignment. NA_phase = between-boundary records.\n")

amd("\n### Cold-engaged unique records by primary group × phase\n")
write_kable(counts_uniq_cold, "Cold-engaged unique records by group × phase",
            add_phase_header = TRUE)
amd("Cold-engaged records (cold_engaged == TRUE) by group and phase; used for λ_CF estimation.\n")

amd("\n### Warm-engaged unique records by primary group × phase\n")
write_kable(counts_uniq_warm, "Warm-engaged unique records by group × phase",
            add_phase_header = TRUE)
amd("Warm records (cold_engaged == FALSE) by group and phase; used for λ_Proactive estimation.\n")

amd("\n### Expanded record counts (includes Variable_Speed continuous rows)\n")
write_kable(counts_expanded, "Expanded audits row counts by group × phase",
            add_phase_header = TRUE)
amd("Variable_Speed row includes all variable-engine records (CAZ_Plus + Rest_of_London + P24) across all phases.\n")

knitr::kable(counts_uniq_all,  format = "markdown") |>
  writeLines(file.path(OUTPUTS_DIR, "260413_step1_counts_all.md"))
knitr::kable(counts_uniq_cold, format = "markdown") |>
  writeLines(file.path(OUTPUTS_DIR, "260413_step1_counts_cold.md"))
knitr::kable(counts_uniq_warm, format = "markdown") |>
  writeLines(file.path(OUTPUTS_DIR, "260413_step1_counts_warm.md"))

amd("\n## Step 1.4 Checksum Analysis\n")
write_kable(checksum_tbl, "Exclusion pipeline and record counts")
amd("")

amd("\n## Step 1.5 Statistics and Charts\n")

amd("\n### 8a. Excluded records by year and reason\n")
write_kable(excl_yr_wide, "Excluded records by year and exclusion reason")
p_excl <- ggplot(excl_yr, aes(x = year, y = n, fill = excl_reason)) +
  geom_col() +
  scale_fill_brewer(palette = "Set1", name = "Exclusion reason") +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(title = "Excluded records by year and reason", x = "Year", y = "Count") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        legend.text     = element_text(size = 8),
        legend.key.size = unit(0.4, "cm"))
fn_excl <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, "_excl_by_year.png"))
ggsave(fn_excl, p_excl, width = 16, height = 10, units = "cm", dpi = 180)
amd(paste0("![Excluded records by year and reason](", basename(fn_excl), ")\n"))

amd("\n### 8b. Stage distribution by year — unique records\n")
p_stage <- ggplot(stage_yr, aes(x = year, y = n, fill = stage_label)) +
  geom_col(position = "stack") +
  scale_fill_viridis_d(name = "Stage", option = "plasma", direction = -1) +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(title = "Stage distribution by year (unique retained records)", x = "Year", y = "Count") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")
fn_stage <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, "_stage_by_year.png"))
ggsave(fn_stage, p_stage, width = 16, height = 10, units = "cm", dpi = 180)
amd(paste0("![Stage distribution by year](", basename(fn_stage), ")\n"))

p_stage_grp <- ggplot(stage_yr_grp, aes(x = year, y = n, fill = stage_label)) +
  geom_col(position = "stack") +
  facet_wrap(~ group, nrow = 2, scales = "free_y") +
  scale_fill_viridis_d(name = "Stage", option = "plasma", direction = -1) +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(title = "Stage distribution by year and primary group (unique records)", x = "Year", y = "Count") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom", strip.text = element_text(face = "bold"))
fn_stage_grp <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, "_stage_by_year_group.png"))
ggsave(fn_stage_grp, p_stage_grp, width = 16, height = 12, units = "cm", dpi = 180)
amd(paste0("![Stage distribution by year and group](", basename(fn_stage_grp), ")\n"))

amd("\n### 8c. Non-compliance codes vs compliant machines by year\n")
write_kable(nc_wide, "Compliance status by year — pre-derived boolean flags")
amd("Columns: Compliant = init_mach_emissions_compliant TRUE; Became compliant = init FALSE & final TRUE; remainder by NC code hierarchy (E > R > Other).\n")

nc_colours <- c(
  "E: Emissions (remained NC)"    = "#E41A1C",
  "R: Registration (remained NC)" = "#FF7F00",
  "Other (remained NC)"           = "#984EA3",
  "Became compliant"              = "#4DAF4A"
)
p_nc <- ggplot(nc_noncomp, aes(x = year, y = n, fill = nc_status)) +
  geom_col(position = "stack") +
  geom_line(data = compliant_yr, aes(x = year, y = n_compliant),
            inherit.aes = FALSE, colour = "#4DAF4A", linewidth = 1.0, linetype = "dashed") +
  scale_fill_manual(name = "Status", values = nc_colours, drop = FALSE) +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(
    title    = "Non-compliant machines: became compliant vs remained non-compliant",
    subtitle = "Stacked bars = initially non-compliant; dashed green line = initially compliant (reference)",
    x = "Year", y = "Machines"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        legend.text     = element_text(size = 8),
        legend.key.size = unit(0.4, "cm"))
fn_nc <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, "_noncompliance_codes_year.png"))
ggsave(fn_nc, p_nc, width = 16, height = 10, units = "cm", dpi = 180)
amd(paste0("![Non-compliant machines by status category](", basename(fn_nc), ")"))
amd("Stacked bars = initially non-compliant machines by NC sub-category; dashed line = initially compliant machines (scale reference).\n")

p_nc_comp <- ggplot(nc_yr, aes(x = year, y = n, fill = nc_status)) +
  geom_col(position = "stack") +
  scale_fill_manual(
    name   = "Status",
    values = c(
      "Compliant"                      = "#AED6F1",
      "Became compliant"               = "#1A5276",
      "E: Emissions (remained NC)"     = "#E41A1C",
      "R: Registration (remained NC)"  = "#FF7F00",
      "Other (remained NC)"            = "#984EA3"
    ),
    drop = FALSE
  ) +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(
    title    = "Compliant vs non-compliant machines by year",
    subtitle = "Compliant (light blue) includes machines compliant at initial inspection; dark blue = enforcement uplift",
    x = "Year", y = "Machines"
  ) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom",
        legend.text     = element_text(size = 8),
        legend.key.size = unit(0.4, "cm"))
fn_nc_comp <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, "_compliance_vs_noncompliance_year.png"))
ggsave(fn_nc_comp, p_nc_comp, width = 16, height = 10, units = "cm", dpi = 180)
amd(paste0("![Compliant vs non-compliant by year](", basename(fn_nc_comp), ")"))
amd("All machines by year: compliant (light blue), became compliant (dark blue), remained non-compliant by NC sub-category (red/orange/purple).\n")

amd("\n### 8d. Primary group and engagement type by year (unique records)\n")
p_grp <- ggplot(grp_yr, aes(x = year, y = n, fill = group)) +
  geom_col(position = "stack") +
  facet_wrap(~ engagement, nrow = 1) +
  scale_fill_brewer(palette = "Set2", name = "Group") +
  scale_x_continuous(breaks = pretty_breaks()) +
  labs(title = "Records by primary group and engagement type by year", x = "Year", y = "Count") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")
fn_grp <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, "_group_engagement_year.png"))
ggsave(fn_grp, p_grp, width = 16, height = 10, units = "cm", dpi = 180)
amd(paste0("![Group and engagement type by year](", basename(fn_grp), ")"))
amd("Unique records by primary group and year, faceted by engagement type (cold/warm).\n")

amd("\n### 8e. Variable_Speed continuous by year — all variable-engine records\n")
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
amd("All variable-engine records (group == 'Variable_Speed') by year, coloured by zone sub-group (group_primary).\n")

amd("\n## Step 1.6 Records by Phase\n")
write_kable(phase_cs, "Unique records by phase (sum = n_unique_records)")
amd("Phase row sums must equal n_unique_records; NA = between-boundary records.\n")

saveRDS(audits,     file.path(OUT_DIR, "audits.rds"))
saveRDS(audits_vs,  file.path(OUT_DIR, "audits_vs.rds"))
saveRDS(exclusions, file.path(OUT_DIR, "exclusions.rds"))

manifest_entries <- tibble(
  object = c("audits", "audits_vs", "exclusions"),
  file   = c("intermediate/audits.rds", "intermediate/audits_vs.rds", "intermediate/exclusions.rds"),
  class  = "tbl_df",
  dim    = c(
    paste0(nrow(audits),     " x ", ncol(audits)),
    paste0(nrow(audits_vs),  " x ", ncol(audits_vs)),
    paste0(nrow(exclusions), " x ", ncol(exclusions))
  ),
  step  = "step1v6",
  description = c(
    paste0(
      "Expanded audit records: ", n_unique_records, " unique records + ",
      n_vs_dupes, " VS duplicate rows. group = active group for filtering; ",
      "group_primary = 4-way zone assignment; filter(group == group_primary) ",
      "recovers unique records. vs_member = TRUE for all variable-engine records. ",
      "init_mach_emissions_compliant derived with fixed=TRUE without toupper (v5 bug fix)."
    ),
    "Convenience subset: all variable-engine records (group == 'Variable_Speed'), including CAZ_Plus and Rest_of_London duplicates. Equivalent to filter(audits, group == 'Variable_Speed').",
    "Pipeline-excluded records with excl_reason label; for Step 1.5 exclusion analysis"
  )
)
update_manifest(manifest_entries)
