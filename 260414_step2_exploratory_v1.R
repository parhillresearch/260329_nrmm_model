# 260414_step2_exploratory_v1.R
# NRMM LEZ Trend Analysis — Step 2: Exploratory Analysis
# Inputs:  intermediate/audits.rds
# Outputs (intermediate/): stage_dist.rds, audits_step2.rds, sparsity_summary.rds
# Outputs (outputs/):      260414_step2_exploratory_v1.md (all tables + inline plots)

library(tidyverse)
library(htmltools)   # htmlEscape() for safe cell values in HTML tables

# ── Schema constants ──────────────────────────────────────────────────────────────

OUT_DIR       <- "intermediate"
OUTPUTS_DIR   <- "outputs"
MANIFEST_FILE <- file.path(OUT_DIR, "manifest.md")
SCRIPT_STEM   <- "260414_step2_exploratory_v1"
SPARSITY_THR  <- 30L

# Phase B sub-segment end dates (equal thirds; applied to ALL groups for display)
# Midpoints (fractional years): B1=2021.389, B2=2022.832, B3=2024.278
PHASE_B1_END <- as.Date("2022-02-09")
PHASE_B2_END <- as.Date("2023-07-21")

# Table layout constants
GROUP_ORDER  <- c("Constant_Speed", "CAZ_Plus", "Rest_of_London", "Variable_Speed")
PHASE_ORDER  <- c("A1", "A2", "B1", "B2", "B3", "C")
STAGE_LEVELS <- c("I", "II", "IIIA", "IIIB", "IV", "V")   # ZE flagged separately
STAGE_MAP    <- c("1"="I","2"="II","3"="IIIA","4"="IIIB","5"="IV","6"="V","7"="ZE")

# Compliance route short labels (preserves ordering)
ROUTE_ORDER <- c("1_self_compliant","2_driven_compliant_reg","3_non_compliant_R",
                 "4_driven_compliant_emissions","5_non_compliant","unknown")
ROUTE_SHORT <- c("1_self_compliant"            = "Self-compl",
                 "2_driven_compliant_reg"       = "Driv-reg",
                 "3_non_compliant_R"            = "NC(R)",
                 "4_driven_compliant_emissions" = "Driv-emis",
                 "5_non_compliant"              = "NC",
                 "unknown"                      = "Unknwn")

# Max active stage per group (schema: Active state spaces)
MAX_STAGE <- c(Constant_Speed=3L, CAZ_Plus=5L, Rest_of_London=6L, Variable_Speed=6L)

# ── Helper functions ──────────────────────────────────────────────────────────────

#' phase_display: B sub-segments applied to all groups (for display only).
#' phase_sub (analytical) keeps "B" for Constant_Speed; this does not.
#' @param date   Date vector
#' @param phase  character phase vector
assign_phase_display <- function(date, phase) {
  case_when(
    phase != "B"         ~ phase,
    date <= PHASE_B1_END ~ "B1",
    date <= PHASE_B2_END ~ "B2",
    TRUE                 ~ "B3"
  )
}

#' Analytical phase_sub: Constant_Speed Phase B stays "B"; variable speed sub-divided.
#' @param date   Date vector
#' @param phase  character phase vector
#' @param group  character group vector
assign_phase_sub <- function(date, phase, group) {
  case_when(
    phase != "B"              ~ phase,
    group == "Constant_Speed" ~ "B",
    date  <= PHASE_B1_END     ~ "B1",
    date  <= PHASE_B2_END     ~ "B2",
    TRUE                      ~ "B3"
  )
}

#' Classify compliance route per Table 3.
classify_route <- function(df) {
  df |> mutate(
    route = case_when(
      !init_mach_emissions_compliant &  enforcement_upgrade  ~ "4_driven_compliant_emissions",
      !init_mach_emissions_compliant & !enforcement_upgrade  ~ "5_non_compliant",
       init_mach_emissions_compliant &  init_mach_admin_compliant              ~ "1_self_compliant",
       init_mach_emissions_compliant & !init_mach_admin_compliant &
         final_mach_admin_compliant                                             ~ "2_driven_compliant_reg",
       init_mach_emissions_compliant & !init_mach_admin_compliant &
        !final_mach_admin_compliant                                             ~ "3_non_compliant_R",
      TRUE ~ "unknown"
    )
  )
}

#' Pivot long data to wide phase × sub_col columns with group rows.
#' Completes all group × phase × sub_col combinations (NA where absent).
#' Returns a tibble with column names "PHASE__SUBCOL" ready for render_kable().
#' @param df        long tibble; must have columns: group, phase_display, <subcol_var>, <val_col>
#' @param subcol_var  name of the sub-column variable (string)
#' @param val_col     name of the value variable (string)
#' @param phases      ordered phase labels
#' @param subcols     ordered sub-column labels
#' @param id_extra    additional row-id column names beyond "group" (e.g. "engagement")
make_wide <- function(df, subcol_var, val_col = "n",
                       phases  = PHASE_ORDER,
                       subcols = STAGE_LEVELS,
                       id_extra = character(0)) {

  id_cols <- c("group", id_extra)

  expanded <- df |>
    tidyr::complete(
      group         = factor(GROUP_ORDER, levels = GROUP_ORDER),
      phase_display = phases,
      !!subcol_var  := subcols,
      fill = setNames(list(NA_integer_), val_col)
    ) |>
    dplyr::filter(phase_display %in% phases,
                  .data[[subcol_var]] %in% subcols)

  if (length(id_extra) > 0) {
    for (col in id_extra) {
      expanded <- tidyr::complete(expanded,
                                  !!col := unique(df[[col]]))
    }
  }

  wide <- expanded |>
    dplyr::mutate(col_key = paste(phase_display, .data[[subcol_var]], sep = "__")) |>
    tidyr::pivot_wider(id_cols     = all_of(id_cols),
                       names_from  = col_key,
                       values_from = all_of(val_col)) |>
    dplyr::arrange(match(as.character(group), GROUP_ORDER))

  wide
}

#' Build an HTML table string with phase super-header using colspan.
#' Avoids kableExtra entirely — works reliably from a sourced R script.
#' Data column names must follow "PHASE__METRIC" convention.
#' @param wide    wide tibble; id columns first, then "PHASE__METRIC" data columns
#' @param n_id    number of row-id columns (group + any inner breakdown)
#' @param na_str  HTML string shown for NA cells
make_html_table <- function(wide, n_id = 1L, na_str = "&mdash;") {
  id_cols      <- names(wide)[seq_len(n_id)]
  data_cols    <- names(wide)[-seq_len(n_id)]
  phase_labels <- sub("__.*", "", data_cols)
  sub_labels   <- sub(".*__", "", data_cols)
  phase_runs   <- rle(phase_labels)

  cell <- function(tag, content, extra = "")
    sprintf("<%s%s>%s</%s>", tag, extra, content, tag)

  # Header row 1: blank id cells + phase cells with colspan
  h1_id    <- paste(rep(cell("th", ""), n_id), collapse = "")
  h1_phase <- paste(mapply(
    function(ph, sp) cell("th", ph, sprintf(' colspan="%d" style="text-align:center"', sp)),
    phase_runs$values, phase_runs$lengths
  ), collapse = "")
  header1 <- paste0("<tr>", h1_id, h1_phase, "</tr>")

  # Header row 2: id column names + sub-labels
  h2_id  <- paste(vapply(id_cols,  function(x) cell("th", x), character(1)), collapse = "")
  h2_sub <- paste(vapply(sub_labels, function(x) cell("th", x), character(1)), collapse = "")
  header2 <- paste0("<tr>", h2_id, h2_sub, "</tr>")

  # Data rows
  body_rows <- apply(wide, 1, function(row) {
    cells <- vapply(seq_along(row), function(i) {
      v <- if (is.na(row[[i]])) na_str else htmltools::htmlEscape(as.character(row[[i]]))
      cell("td", v)
    }, character(1))
    paste0("<tr>", paste(cells, collapse = ""), "</tr>")
  })

  paste0(
    '<table style="font-size:9pt;border-collapse:collapse;margin-bottom:1em;">',
    "<thead style=\"background:#f2f2f2\">", header1, header2, "</thead>",
    "<tbody>", paste(body_rows, collapse = ""), "</tbody>",
    "</table>"
  )
}

#' Write table to .md file as inline HTML (colspan headers render in Typora/Positron)
#' and print a phase-prefixed plain markdown version to console.
#' @param wide     wide tibble (data column names in "PHASE__METRIC" format)
#' @param n_id     number of row-id columns
#' @param caption  section heading written above the table
save_table <- function(wide, n_id = 1L, caption = "") {
  html <- make_html_table(wide, n_id = n_id)
  cat(paste0("\n### ", caption, "\n"), file = out_file, append = TRUE)
  cat(html, "\n",                      file = out_file, append = TRUE)
  # Console: phase-prefixed markdown for plain-text readability
  console_tbl <- wide
  data_cols   <- names(wide)[-seq_len(n_id)]
  names(console_tbl)[-seq_len(n_id)] <- gsub("__", ".", data_cols)
  cat("\n###", caption, "\n")
  cat(knitr::kable(console_tbl, format = "markdown", na = "\u2014"), sep = "\n")
  cat("\n")
  invisible(html)
}

#' Write a markdown image link to the output .md file (renders plot inline).
#' @param filename  bare filename (no directory prefix) in outputs/
#' @param caption   alt-text / caption
embed_plot <- function(filename, caption = "") {
  write(paste0("\n![", caption, "](", filename, ")\n"),
        file = out_file, append = TRUE)
}

#' Append rows to the cumulative manifest.md
update_manifest <- function(entries) {
  rows <- entries |>
    mutate(line = paste0("| ", object, " | ", file, " | ", class,
                         " | ", dim, " | ", step, " | ", description, " |")) |>
    pull(line)
  write(rows, file = MANIFEST_FILE, append = TRUE)
}

# ── Load ──────────────────────────────────────────────────────────────────────────

message("=== ", SCRIPT_STEM, " — NRMM Step 2 ===\n")

audits <- readRDS(file.path(OUT_DIR, "audits.rds"))
message("Loaded audits.rds: ", nrow(audits), " x ", ncol(audits), " cols")

if (!dir.exists(OUTPUTS_DIR)) dir.create(OUTPUTS_DIR, recursive = TRUE)
out_file <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, ".md"))
writeLines(paste0("# Step 2 Exploratory Analysis\n\nDate: ", Sys.Date()), out_file)

# ── 1. Enrich: phase_sub, phase_display, stage_label, ZE flag ────────────────────

audits <- audits |>
  mutate(
    phase_sub     = assign_phase_sub(date, phase, group),
    phase_display = assign_phase_display(date, phase),
    stage_label   = factor(STAGE_MAP[as.character(initial_stage)], levels = c(STAGE_LEVELS, "ZE")),
    ze_flag       = initial_stage == 7L
  )

message("Phase sub-segment counts (analytical):")
count(audits, group, phase_sub) |>
  pivot_wider(names_from = phase_sub, values_from = n, values_fill = 0L) |>
  print()

n_ze <- sum(audits$ze_flag, na.rm = TRUE)
message("ZE/Stage-7 records (excluded from stage tables, flagged): ", n_ze)

# ── Sub-task 1: Stage distributions ──────────────────────────────────────────────

message("\n── Sub-task 1: Stage distributions ──\n")

# Long counts: group × year × cold_engaged × stage (stored; used for plots + saving)
stage_dist <- audits |>
  filter(!ze_flag) |>
  count(group, year, cold_engaged, initial_stage, stage_label, name = "n") |>
  group_by(group, year, cold_engaged) |>
  mutate(pct = round(100 * n / sum(n), 1)) |>
  ungroup()

# Aggregated by phase_display for tables
stage_by_phase <- audits |>
  filter(!ze_flag) |>
  mutate(engagement = if_else(cold_engaged, "cold", "warm")) |>
  count(group, engagement, phase_display, stage_label, name = "n")

# Table 1a: cold fleet
cold_wide <- stage_by_phase |>
  filter(engagement == "cold") |>
  make_wide(subcol_var = "stage_label", val_col = "n",
            phases = PHASE_ORDER, subcols = STAGE_LEVELS)

message("Cold fleet stage counts:")
save_table(cold_wide, n_id = 1L, caption = "Stage distribution — cold-engaged fleet (counts)")

# Table 1b: warm fleet
warm_wide <- stage_by_phase |>
  filter(engagement == "warm") |>
  make_wide(subcol_var = "stage_label", val_col = "n",
            phases = PHASE_ORDER, subcols = STAGE_LEVELS)

message("Warm fleet stage counts:")
save_table(warm_wide, n_id = 1L, caption = "Stage distribution — warm fleet (counts)")

# ── Plots ─────────────────────────────────────────────────────────────────────────

stage_fill <- scale_fill_brewer(palette = "RdYlGn", direction = 1, name = "Stage")
plot_theme <- theme_minimal(base_size = 9) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Plot 1: cold fleet by year
p_cold_year <- stage_dist |>
  filter(cold_engaged, group %in% c("Constant_Speed", "CAZ_Plus", "Rest_of_London")) |>
  ggplot(aes(x = year, y = pct, fill = stage_label)) +
  geom_col(width = 0.8) +
  facet_wrap(~group, nrow = 1, labeller = label_wrap_gen(15)) +
  stage_fill +
  scale_x_continuous(breaks = 2016:2025) +
  labs(title = "Cold-engaged fleet: Stage distribution by group and year",
       x = "Year", y = "% of cold-engaged audits") +
  plot_theme

fn_cold <- paste0(SCRIPT_STEM, "_stage_cold_year.png")
ggsave(file.path(OUTPUTS_DIR, fn_cold),
       p_cold_year, width = 16, height = 10, units = "cm", dpi = 180)
embed_plot(fn_cold, "Cold-engaged fleet: Stage distribution by group and year")
message("Saved: ", fn_cold)

# Plot 2: warm fleet by year
p_warm_year <- stage_dist |>
  filter(!cold_engaged, group %in% c("Constant_Speed", "CAZ_Plus", "Rest_of_London")) |>
  ggplot(aes(x = year, y = pct, fill = stage_label)) +
  geom_col(width = 0.8) +
  facet_wrap(~group, nrow = 1, labeller = label_wrap_gen(15)) +
  stage_fill +
  scale_x_continuous(breaks = 2016:2025) +
  labs(title = "Warm fleet: Stage distribution by group and year",
       x = "Year", y = "% of warm audits") +
  plot_theme

fn_warm <- paste0(SCRIPT_STEM, "_stage_warm_year.png")
ggsave(file.path(OUTPUTS_DIR, fn_warm),
       p_warm_year, width = 16, height = 10, units = "cm", dpi = 180)
embed_plot(fn_warm, "Warm fleet: Stage distribution by group and year")
message("Saved: ", fn_warm)

# Plot 3: Phase B sub-segments, cold, variable speed
Bsub_stage <- audits |>
  filter(cold_engaged, phase == "B",
         group %in% c("CAZ_Plus", "Rest_of_London"),
         !ze_flag) |>
  count(group, phase_sub, stage_label, name = "n") |>
  group_by(group, phase_sub) |>
  mutate(pct = round(100 * n / sum(n), 1)) |>
  ungroup()

p_Bsub <- Bsub_stage |>
  ggplot(aes(x = phase_sub, y = pct, fill = stage_label)) +
  geom_col(width = 0.7) +
  facet_wrap(~group, nrow = 1) +
  stage_fill +
  labs(title = "Cold fleet: Phase B sub-segments (variable speed groups)",
       x = "Phase B sub-segment", y = "% of cold-engaged audits") +
  plot_theme

fn_bsub <- paste0(SCRIPT_STEM, "_stage_cold_Bsub.png")
ggsave(file.path(OUTPUTS_DIR, fn_bsub),
       p_Bsub, width = 16, height = 10, units = "cm", dpi = 180)
embed_plot(fn_bsub, "Cold fleet: Phase B sub-segments (variable speed groups)")
message("Saved: ", fn_bsub)

# Plot 4: Variable_Speed Phase C
p_vs <- stage_dist |>
  filter(group == "Variable_Speed") |>
  mutate(engagement = if_else(cold_engaged, "Cold", "Warm")) |>
  ggplot(aes(x = year, y = pct, fill = stage_label)) +
  geom_col(width = 0.8) +
  facet_wrap(~engagement, nrow = 1) +
  stage_fill +
  scale_x_continuous(breaks = 2025:2026) +
  labs(title = "Variable_Speed (Phase C, P24): Stage distribution by engagement type",
       x = "Year", y = "% of audits") +
  plot_theme

fn_vs <- paste0(SCRIPT_STEM, "_stage_variable_speed.png")
ggsave(file.path(OUTPUTS_DIR, fn_vs),
       p_vs, width = 16, height = 10, units = "cm", dpi = 180)
embed_plot(fn_vs, "Variable_Speed (Phase C, P24): Stage distribution by engagement type")
message("Saved: ", fn_vs)

# ── Sub-task 2: Compliance routing (Table 3) ──────────────────────────────────────

message("\n── Sub-task 2: Compliance routing ──\n")

audits_routed <- classify_route(audits)

n_unknown <- sum(audits_routed$route == "unknown")
if (n_unknown > 0) {
  message("FLAG — Unknown route records: ", n_unknown)
  audits_routed |>
    filter(route == "unknown") |>
    count(init_mach_emissions_compliant, init_mach_admin_compliant,
          final_mach_admin_compliant, enforcement_upgrade, name = "n") |>
    print()
} else {
  message("All records assigned to a route (no unknowns).")
}

# Count by group × phase_display × route
route_long <- audits_routed |>
  count(group, phase_display, route, name = "n")

route_wide <- route_long |>
  mutate(route_label = ROUTE_SHORT[route]) |>
  make_wide(subcol_var = "route_label", val_col = "n",
            phases  = PHASE_ORDER,
            subcols = unname(ROUTE_SHORT[ROUTE_ORDER]))

message("Compliance route counts:")
save_table(route_wide, n_id = 1L, caption = "Compliance routing — counts by group × phase (Table 3)")

# Route % for warm fleet
route_warm_long <- audits_routed |>
  filter(!cold_engaged) |>
  count(group, phase_display, route, name = "n") |>
  group_by(group, phase_display) |>
  mutate(pct = round(100 * n / sum(n), 1)) |>
  ungroup() |>
  mutate(route_label = ROUTE_SHORT[route]) |>
  select(group, phase_display, route_label, pct)

route_warm_wide <- route_warm_long |>
  make_wide(subcol_var = "route_label", val_col = "pct",
            phases  = PHASE_ORDER,
            subcols = unname(ROUTE_SHORT[ROUTE_ORDER]))

message("Compliance route % (warm fleet):")
save_table(route_warm_wide, n_id = 1L,
           caption = "Compliance routing — % warm fleet by group × phase")

# ── Sub-task 3: Sparsity, signal exhaustion, volatility ───────────────────────────

message("\n── Sub-task 3: Sparsity, signal exhaustion, volatility ──\n")

# 3a. Cold cell counts by group × phase_display × stage
cold_cell_counts <- audits |>
  filter(cold_engaged, !ze_flag) |>
  count(group, phase_display, stage_label, name = "n")

cold_totals <- cold_cell_counts |>
  group_by(group, phase_display) |>
  summarise(total_cold = sum(n), .groups = "drop")

# Sparse cells
sparse_cells <- cold_cell_counts |>
  filter(n < SPARSITY_THR) |>
  left_join(cold_totals, by = c("group", "phase_display")) |>
  arrange(group, match(phase_display, PHASE_ORDER), stage_label)

message("Sparse cold cells (n < ", SPARSITY_THR, "):")
if (nrow(sparse_cells) > 0) {
  sparse_wide <- sparse_cells |>
    make_wide(subcol_var = "stage_label", val_col = "n",
              phases = PHASE_ORDER, subcols = STAGE_LEVELS)
  save_table(sparse_wide, n_id = 1L,
             caption = paste0("Sparsity — cold cells n < ", SPARSITY_THR))
} else {
  message("  None.")
}

# 3b. Signal exhaustion: % cold fleet at group max_stage by phase_display
signal_exhaustion <- cold_totals |>
  left_join(
    cold_cell_counts |>
      filter(as.integer(factor(stage_label, levels = STAGE_LEVELS)) ==
               MAX_STAGE[as.character(group)]) |>
      select(group, phase_display, n_at_max = n),
    by = c("group", "phase_display")
  ) |>
  replace_na(list(n_at_max = 0L)) |>
  mutate(pct_at_max = round(100 * n_at_max / total_cold, 1))

# Table: total_cold and pct_at_max as sub-columns under phase super-header.
# Built with pivot_wider + names_glue to avoid make_wide() name conflict
# (phase_display cannot be both the row variable and the subcol_var).
signal_wide <- signal_exhaustion |>
  select(group, phase_display, total_cold, pct_at_max) |>
  pivot_wider(
    names_from  = phase_display,
    values_from = c(total_cold, pct_at_max),
    names_glue  = "{phase_display}__{.value}"
  ) |>
  # Reorder columns: interleave by phase (A1__total_cold, A1__pct_at_max, A2__..., ...)
  (\(w) {
    id_col    <- "group"
    data_cols <- setdiff(names(w), id_col)
    ordered   <- unlist(lapply(PHASE_ORDER,
                               function(ph) grep(paste0("^", ph, "__"), data_cols, value = TRUE)))
    select(w, all_of(c(id_col, ordered)))
  })() |>
  complete(group = factor(GROUP_ORDER, levels = GROUP_ORDER)) |>
  arrange(match(as.character(group), GROUP_ORDER))

message("Signal exhaustion (% cold at max_stage):")
save_table(signal_wide, n_id = 1L,
           caption = "Signal exhaustion — % cold fleet at max_stage by group × phase")

# 3c. Volatility: year-to-year SD at max_stage (cold, Phase B)
volatility <- audits |>
  filter(cold_engaged, phase == "B",
         group %in% c("Constant_Speed", "CAZ_Plus", "Rest_of_London"),
         !ze_flag) |>
  count(group, year, initial_stage, name = "n") |>
  group_by(group, year) |>
  mutate(pct = 100 * n / sum(n)) |>
  ungroup() |>
  filter(initial_stage == MAX_STAGE[as.character(group)]) |>
  arrange(group, year) |>
  group_by(group) |>
  summarise(
    years_obs    = n(),
    pct_min      = round(min(pct), 1),
    pct_max      = round(max(pct), 1),
    pct_mean     = round(mean(pct), 1),
    sd_pct       = round(sd(pct), 1),
    sd_yoy_delta = round(sd(diff(pct)), 1),
    .groups = "drop"
  ) |>
  tidyr::complete(group = factor(GROUP_ORDER, levels = GROUP_ORDER)) |>
  dplyr::arrange(match(as.character(group), GROUP_ORDER))

# Volatility has no phase dimension — plain HTML table, no spanning header needed
message("Volatility (cold Phase B):")
vol_caption <- "Volatility — SD of % cold fleet at max_stage in Phase B"
vol_html <- make_html_table(volatility, n_id = 1L)
cat(paste0("\n### ", vol_caption, "\n"), file = out_file, append = TRUE)
cat(vol_html, "\n",                      file = out_file, append = TRUE)
cat("\n###", vol_caption, "\n")
cat(knitr::kable(volatility, format = "markdown", na = "\u2014"), sep = "\n")
cat("\n")

# Bundle for saving
sparsity_summary <- list(
  cold_cell_counts  = cold_cell_counts,
  cold_totals       = cold_totals,
  sparse_cells      = sparse_cells,
  signal_exhaustion = signal_exhaustion,
  volatility        = volatility
)

# ── Sub-task 4: Findings summary — stop and confirm before Step 3 ─────────────────

message("\n══════════════════════════════════════════════════════════════")
message("Sub-task 4: FINDINGS SUMMARY — confirm before proceeding to Step 3")
message("══════════════════════════════════════════════════════════════\n")

message("Total retained records by group × phase:")
audits |>
  count(group, phase) |>
  pivot_wider(names_from = phase, values_from = n, values_fill = 0L) |>
  print()

message("\nCold totals by group × phase_display:")
cold_totals |>
  pivot_wider(names_from = phase_display, values_from = total_cold, values_fill = 0L) |>
  print()

message("\nSignal exhaustion — Phase B cold:")
signal_exhaustion |> filter(grepl("^B", phase_display)) |> print()

message("\nSparse cells (n < ", SPARSITY_THR, "): ", nrow(sparse_cells))
if (nrow(sparse_cells) > 0) print(sparse_cells)

message("\nCompliance route anomalies (unknown): ", n_unknown)
message("\nZE/Stage-7 records flagged: ", n_ze)

message("\n[STOP] Outputs written to outputs/", SCRIPT_STEM, ".md and plots.")
message("Say 'step complete' to trigger the Step Report.")

# ── Save intermediate objects ─────────────────────────────────────────────────────

saveRDS(stage_dist,       file.path(OUT_DIR, "stage_dist.rds"))
saveRDS(audits_routed,    file.path(OUT_DIR, "audits_step2.rds"))
saveRDS(sparsity_summary, file.path(OUT_DIR, "sparsity_summary.rds"))

manifest_entries <- tibble(
  object = c("stage_dist", "audits_step2", "sparsity_summary"),
  file   = file.path("intermediate",
                     c("stage_dist.rds", "audits_step2.rds", "sparsity_summary.rds")),
  class  = c("tbl_df", "tbl_df", "list"),
  dim    = c(
    paste0(nrow(stage_dist),    " x ", ncol(stage_dist)),
    paste0(nrow(audits_routed), " x ", ncol(audits_routed)),
    paste0(length(sparsity_summary), " elements")
  ),
  step        = "step2",
  description = c(
    "Stage counts with pct by group × year × cold_engaged × initial_stage (ZE excluded)",
    "audits enriched with phase_sub, phase_display, stage_label, ze_flag, compliance route",
    "Sparsity: cold cell counts, signal exhaustion, volatility by group × phase_display"
  )
)
update_manifest(manifest_entries)
message("Manifest updated: ", MANIFEST_FILE)

message("\n=== OBJECTS SAVED (step 2) ===")
message(sprintf("  %-22s  %-7s  %s", "object", "class", "dim"))
for (i in seq_len(nrow(manifest_entries))) {
  message(sprintf("  %-22s  %-7s  %s",
                  manifest_entries$object[i], "tbl_df", manifest_entries$dim[i]))
}

sessionInfo()
