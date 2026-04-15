# 260414_step2_exploratory_v7.R
# NRMM LEZ Trend Analysis — Step 2: Exploratory Analysis (Trial 7)
#
# v7 fixes:
#   - make_wide() rewritten: expand.grid + left_join guarantees full phase × subcol
#     grid (v1–v6 bug: !!subcol_var in complete() did not unquote to a symbol,
#     so stage/route dimension was never expanded → 1 column per phase instead of N)
#   - Structural blanks (group not in scope for that phase) → "—" via NA
#   - Incidental zeros (group in scope, stage/route absent) → 0 for counts, 0.0 for %
#   - Signal exhaustion table built via explicit grid (same approach)
#
# Inputs:  intermediate/audits.rds
# Outputs (intermediate/): stage_dist.rds, audits_step2.rds, sparsity_summary.rds
# Outputs (outputs/):      260414_step2_exploratory_v7.md (all tables + inline plots)

library(tidyverse)
library(htmltools)   # htmlEscape()

# ── Schema constants ──────────────────────────────────────────────────────────────

OUT_DIR       <- "intermediate"
OUTPUTS_DIR   <- "outputs"
MANIFEST_FILE <- file.path(OUT_DIR, "manifest.md")
SCRIPT_STEM   <- "260414_step2_exploratory_v7"
SPARSITY_THR  <- 30L

# Phase B sub-segment boundaries (equal thirds of B)
PHASE_B1_END <- as.Date("2022-02-09")
PHASE_B2_END <- as.Date("2023-07-21")

GROUP_ORDER  <- c("Constant_Speed", "CAZ_Plus", "Rest_of_London", "Variable_Speed")
PHASE_ORDER  <- c("A1", "A2", "B1", "B2", "B3", "C")
STAGE_LEVELS <- c("I", "II", "IIIA", "IIIB", "IV", "V")   # ZE handled separately
STAGE_MAP    <- c("1"="I","2"="II","3"="IIIA","4"="IIIB","5"="IV","6"="V","7"="ZE")

ROUTE_ORDER <- c("1_self_compliant","2_driven_compliant_reg","3_non_compliant_R",
                 "4_driven_compliant_emissions","5_non_compliant","unknown")
ROUTE_SHORT <- c(
  "1_self_compliant"            = "Self-compl",
  "2_driven_compliant_reg"      = "Driv-reg",
  "3_non_compliant_R"           = "NC(R)",
  "4_driven_compliant_emissions"= "Driv-emis",
  "5_non_compliant"             = "NC",
  "unknown"                     = "Unknwn"
)

MAX_STAGE <- c(Constant_Speed=3L, CAZ_Plus=5L, Rest_of_London=6L, Variable_Speed=6L)

# Phases where each group has no data → all cells "—" (structural blanks)
PHASE_NO_DATA <- list(
  Constant_Speed = character(0),                       # present A1–C
  CAZ_Plus       = "C",
  Rest_of_London = "C",
  Variable_Speed = c("A1","A2","B1","B2","B3")
)

# ── Helper functions ──────────────────────────────────────────────────────────────

#' Assign display phase (B sub-divided for all groups for display purposes).
assign_phase_display <- function(date, phase) {
  case_when(
    phase != "B"         ~ phase,
    date <= PHASE_B1_END ~ "B1",
    date <= PHASE_B2_END ~ "B2",
    TRUE                 ~ "B3"
  )
}

#' Assign analytical phase sub-segment (Constant_Speed Phase B kept as "B").
assign_phase_sub <- function(date, phase, group) {
  case_when(
    phase != "B"              ~ phase,
    group == "Constant_Speed" ~ "B",
    date  <= PHASE_B1_END     ~ "B1",
    date  <= PHASE_B2_END     ~ "B2",
    TRUE                      ~ "B3"
  )
}

#' Classify each record into a Table 3 compliance route.
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

#' Build a wide table with column names "PHASE__SUBCOL".
#' Uses expand.grid + left_join to guarantee all phase × subcol combinations exist.
#' @param df         long tibble with columns: group, phase_display, <subcol_var>, <val_col>
#' @param subcol_var name of the sub-column variable (string)
#' @param val_col    name of the value variable (string)
#' @param phases     ordered phase labels
#' @param subcols    ordered sub-column labels
make_wide <- function(df, subcol_var, val_col = "n",
                      phases  = PHASE_ORDER,
                      subcols = STAGE_LEVELS) {

  # Complete grid: every group × phase × subcol combination
  grid <- expand.grid(
    group         = GROUP_ORDER,
    phase_display = phases,
    subcol        = subcols,
    stringsAsFactors = FALSE
  )
  names(grid)[names(grid) == "subcol"] <- subcol_var   # rename to match df column

  # Coerce join keys to character in df; keep only needed columns
  df_clean <- df |>
    mutate(across(all_of(c("group", "phase_display", subcol_var)), as.character)) |>
    select(all_of(c("group", "phase_display", subcol_var, val_col))) |>
    group_by(across(all_of(c("group", "phase_display", subcol_var)))) |>
    summarise(across(all_of(val_col), sum, na.rm = TRUE), .groups = "drop")

  # Left join: unmatched cells get NA in val_col
  joined <- grid |>
    left_join(df_clean, by = c("group", "phase_display", subcol_var))

  # Pivot to wide; column names become "PHASE__SUBCOL"
  wide <- joined |>
    mutate(col_key = paste(phase_display, .data[[subcol_var]], sep = "__")) |>
    pivot_wider(
      id_cols     = "group",
      names_from  = col_key,
      values_from = all_of(val_col)
    )

  # Enforce column order: phases in PHASE_ORDER, subcols in original order
  ordered_data_cols <- unlist(lapply(phases, function(ph) paste(ph, subcols, sep = "__")))
  ordered_data_cols <- intersect(ordered_data_cols, names(wide))

  wide |>
    select("group", all_of(ordered_data_cols)) |>
    arrange(match(group, GROUP_ORDER))
}

#' Post-process NA values in a wide table built by make_wide():
#'   structural blanks (group not in scope for that phase) → NA (rendered as "—")
#'   incidental zeros (group in scope, subcol absent)      → zero_val
#' @param wide     wide tibble (first column = group; data columns = "PHASE__*")
#' @param zero_val value for incidental zeros: 0L for counts, 0.0 for percentages
fill_table_nas <- function(wide, zero_val = 0L) {
  data_cols <- names(wide)[-1]
  phases    <- sub("__.*", "", data_cols)

  result <- wide
  for (g in GROUP_ORDER) {
    ri <- which(result$group == g)
    if (length(ri) == 0) next
    no_data_ph <- PHASE_NO_DATA[[g]]
    for (j in seq_along(data_cols)) {
      col <- data_cols[j]
      ph  <- phases[j]
      if (ph %in% no_data_ph) {
        result[[col]][ri] <- NA_real_          # structural blank → "—"
      } else if (is.na(result[[col]][ri])) {
        result[[col]][ri] <- zero_val          # incidental zero
      }
    }
  }
  result
}

#' Build HTML table string with phase super-headers (colspan) and stage sub-headers.
#' Column names must follow "PHASE__METRIC" convention.
#' @param wide   wide tibble; id columns first, then data columns "PHASE__METRIC"
#' @param n_id   number of row-id columns
#' @param na_str HTML string for NA cells
make_html_table <- function(wide, n_id = 1L, na_str = "&mdash;") {
  id_cols      <- names(wide)[seq_len(n_id)]
  data_cols    <- names(wide)[-seq_len(n_id)]
  phase_labels <- sub("__.*", "", data_cols)
  sub_labels   <- sub(".*__", "", data_cols)
  phase_runs   <- rle(phase_labels)

  cell <- function(tag, content, extra = "")
    sprintf("<%s%s>%s</%s>", tag, extra, content, tag)

  th_style_ph  <- ' colspan="%d" style="text-align:center;border:1px solid #bbb;background:#dde;padding:3px 6px"'
  th_style_id  <- ' style="border:1px solid #bbb;padding:3px 6px"'
  th_style_sub <- ' style="text-align:center;border:1px solid #bbb;padding:3px 4px"'
  td_style_id  <- ' style="border:1px solid #bbb;padding:2px 6px"'
  td_style_val <- ' style="border:1px solid #bbb;text-align:right;padding:2px 6px"'

  # Header row 1: blank id cells + phase super-headers with colspan
  h1_id    <- paste(rep(cell("th", "", th_style_id), n_id), collapse = "")
  h1_phase <- paste(mapply(
    function(ph, sp) cell("th", ph, sprintf(th_style_ph, sp)),
    phase_runs$values, phase_runs$lengths
  ), collapse = "")
  header1 <- paste0("<tr>", h1_id, h1_phase, "</tr>")

  # Header row 2: id column names + sub-column labels
  h2_id  <- paste(vapply(id_cols,   function(x) cell("th", x,  th_style_id),  character(1)), collapse="")
  h2_sub <- paste(vapply(sub_labels, function(x) cell("th", x, th_style_sub), character(1)), collapse="")
  header2 <- paste0("<tr>", h2_id, h2_sub, "</tr>")

  # Data rows
  body_rows <- apply(wide, 1, function(row) {
    cells <- vapply(seq_along(row), function(i) {
      v <- if (is.na(row[[i]])) na_str
           else htmltools::htmlEscape(as.character(row[[i]]))
      cell("td", v, if (i <= n_id) td_style_id else td_style_val)
    }, character(1))
    paste0("<tr>", paste(cells, collapse=""), "</tr>")
  })

  paste0(
    '<table style="font-size:9pt;border-collapse:collapse;margin-bottom:1.5em;">',
    '<thead style="background:#f2f2f2">', header1, header2, "</thead>",
    "<tbody>", paste(body_rows, collapse=""), "</tbody>",
    "</table>"
  )
}

#' Write table to .md file as inline HTML and print readable summary to console.
save_table <- function(wide, n_id = 1L, caption = "") {
  html <- make_html_table(wide, n_id = n_id)
  cat(paste0("\n### ", caption, "\n\n"), file = out_file, append = TRUE)
  cat(html, "\n",                        file = out_file, append = TRUE)
  # Console: replace __ with . in column names for readability
  console_tbl              <- wide
  dn                       <- names(wide)[-seq_len(n_id)]
  names(console_tbl)[-seq_len(n_id)] <- gsub("__", ".", dn)
  cat("\n###", caption, "\n")
  print(knitr::kable(console_tbl, format = "simple", na = "\u2014"))
  cat("\n")
  invisible(html)
}

#' Write markdown image line to .md file for inline plot rendering.
embed_plot <- function(filename, caption = "") {
  write(paste0("\n![", caption, "](", filename, ")\n"),
        file = out_file, append = TRUE)
}

#' Append new rows to the cumulative manifest.md.
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
message("Loaded audits.rds: ", nrow(audits), " rows x ", ncol(audits), " cols")

if (!dir.exists(OUTPUTS_DIR)) dir.create(OUTPUTS_DIR, recursive = TRUE)
out_file <- file.path(OUTPUTS_DIR, paste0(SCRIPT_STEM, ".md"))
writeLines(paste0("# Step 2 Exploratory Analysis\n\nScript: ",
                  SCRIPT_STEM, "\nDate: ", Sys.Date()), out_file)

# ── Enrich: add phase sub-segments, display phases, stage labels ──────────────────

audits <- audits |>
  mutate(
    phase_sub     = assign_phase_sub(date, phase, group),
    phase_display = assign_phase_display(date, phase),
    stage_label   = unname(STAGE_MAP[as.character(initial_stage)]),
    ze_flag       = initial_stage == 7L
  )

message("Phase sub-segment counts (analytical):")
count(audits, group, phase_sub) |>
  pivot_wider(names_from = phase_sub, values_from = n, values_fill = 0L) |>
  print()

n_ze <- sum(audits$ze_flag, na.rm = TRUE)
message("ZE/Stage-7 records flagged (excluded from stage tables): ", n_ze)

# ── Sub-task 1: Stage distributions ──────────────────────────────────────────────

message("\n── Sub-task 1: Stage distributions ──\n")

# Long counts by group × year × engagement × stage (for plots and downstream use)
stage_dist <- audits |>
  filter(!ze_flag) |>
  count(group, year, cold_engaged, initial_stage, stage_label, name = "n") |>
  group_by(group, year, cold_engaged) |>
  mutate(pct = round(100 * n / sum(n), 1)) |>
  ungroup()

# Aggregate by phase_display for tables
stage_by_phase <- audits |>
  filter(!ze_flag) |>
  count(group, phase_display, stage_label, cold_engaged, name = "n")

# Table 1a: cold fleet stage counts
cold_wide <- stage_by_phase |>
  filter(cold_engaged) |>
  select(group, phase_display, stage_label, n) |>
  make_wide(subcol_var = "stage_label", val_col = "n",
            phases = PHASE_ORDER, subcols = STAGE_LEVELS) |>
  fill_table_nas(zero_val = 0L)

save_table(cold_wide, n_id = 1L,
           caption = "Stage distribution — cold-engaged fleet (counts)")

# Table 1b: warm fleet stage counts
warm_wide <- stage_by_phase |>
  filter(!cold_engaged) |>
  select(group, phase_display, stage_label, n) |>
  make_wide(subcol_var = "stage_label", val_col = "n",
            phases = PHASE_ORDER, subcols = STAGE_LEVELS) |>
  fill_table_nas(zero_val = 0L)

save_table(warm_wide, n_id = 1L,
           caption = "Stage distribution — warm fleet (counts)")

# ── Plots ─────────────────────────────────────────────────────────────────────────

stage_fill <- scale_fill_brewer(palette = "RdYlGn", direction = 1, name = "Stage")
plot_theme <- theme_minimal(base_size = 9) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Plot 1: cold fleet stage distribution by year (A1–B3 groups)
p_cold_year <- stage_dist |>
  filter(cold_engaged, group %in% c("Constant_Speed","CAZ_Plus","Rest_of_London")) |>
  mutate(stage_label = factor(stage_label, levels = STAGE_LEVELS)) |>
  ggplot(aes(x = year, y = pct, fill = stage_label)) +
  geom_col(width = 0.8) +
  facet_wrap(~group, nrow = 1, labeller = label_wrap_gen(15)) +
  stage_fill +
  scale_x_continuous(breaks = 2016:2025) +
  labs(title = "Cold-engaged fleet: Stage distribution by group and year",
       x = "Year", y = "% of cold-engaged audits") +
  plot_theme

fn_cold <- paste0(SCRIPT_STEM, "_stage_cold_year.png")
ggsave(file.path(OUTPUTS_DIR, fn_cold), p_cold_year,
       width = 16, height = 10, units = "cm", dpi = 180)
embed_plot(fn_cold, "Cold-engaged fleet: Stage distribution by group and year")
message("Saved: ", fn_cold)

# Plot 2: warm fleet stage distribution by year
p_warm_year <- stage_dist |>
  filter(!cold_engaged, group %in% c("Constant_Speed","CAZ_Plus","Rest_of_London")) |>
  mutate(stage_label = factor(stage_label, levels = STAGE_LEVELS)) |>
  ggplot(aes(x = year, y = pct, fill = stage_label)) +
  geom_col(width = 0.8) +
  facet_wrap(~group, nrow = 1, labeller = label_wrap_gen(15)) +
  stage_fill +
  scale_x_continuous(breaks = 2016:2025) +
  labs(title = "Warm fleet: Stage distribution by group and year",
       x = "Year", y = "% of warm audits") +
  plot_theme

fn_warm <- paste0(SCRIPT_STEM, "_stage_warm_year.png")
ggsave(file.path(OUTPUTS_DIR, fn_warm), p_warm_year,
       width = 16, height = 10, units = "cm", dpi = 180)
embed_plot(fn_warm, "Warm fleet: Stage distribution by group and year")
message("Saved: ", fn_warm)

# Plot 3: Phase B sub-segments, cold, variable-speed groups
Bsub_stage <- audits |>
  filter(cold_engaged, phase == "B",
         group %in% c("CAZ_Plus","Rest_of_London"),
         !ze_flag) |>
  count(group, phase_sub, stage_label, name = "n") |>
  group_by(group, phase_sub) |>
  mutate(pct = round(100 * n / sum(n), 1)) |>
  ungroup() |>
  mutate(stage_label = factor(stage_label, levels = STAGE_LEVELS))

p_Bsub <- Bsub_stage |>
  ggplot(aes(x = phase_sub, y = pct, fill = stage_label)) +
  geom_col(width = 0.7) +
  facet_wrap(~group, nrow = 1) +
  stage_fill +
  labs(title = "Cold fleet: Phase B sub-segments (variable speed groups)",
       x = "Phase B sub-segment", y = "% of cold-engaged audits") +
  plot_theme

fn_bsub <- paste0(SCRIPT_STEM, "_stage_cold_Bsub.png")
ggsave(file.path(OUTPUTS_DIR, fn_bsub), p_Bsub,
       width = 16, height = 10, units = "cm", dpi = 180)
embed_plot(fn_bsub, "Cold fleet: Phase B sub-segments (variable speed groups)")
message("Saved: ", fn_bsub)

# Plot 4: Variable_Speed Phase C (P24)
p_vs <- stage_dist |>
  filter(group == "Variable_Speed") |>
  mutate(engagement  = if_else(cold_engaged, "Cold", "Warm"),
         stage_label = factor(stage_label, levels = STAGE_LEVELS)) |>
  ggplot(aes(x = year, y = pct, fill = stage_label)) +
  geom_col(width = 0.8) +
  facet_wrap(~engagement, nrow = 1) +
  stage_fill +
  scale_x_continuous(breaks = 2025:2026) +
  labs(title = "Variable_Speed (Phase C, P24): Stage distribution by engagement type",
       x = "Year", y = "% of audits") +
  plot_theme

fn_vs <- paste0(SCRIPT_STEM, "_stage_variable_speed.png")
ggsave(file.path(OUTPUTS_DIR, fn_vs), p_vs,
       width = 16, height = 10, units = "cm", dpi = 180)
embed_plot(fn_vs, "Variable_Speed (Phase C, P24): Stage distribution by engagement type")
message("Saved: ", fn_vs)

# ── Sub-task 2: Compliance routing ────────────────────────────────────────────────

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
  message("All records assigned to a compliance route.")
}

# Table 2a: all-record counts by group × phase × route
route_long <- audits_routed |>
  count(group, phase_display, route, name = "n") |>
  mutate(route_label = unname(ROUTE_SHORT[route]))

route_wide <- route_long |>
  select(group, phase_display, route_label, n) |>
  make_wide(subcol_var = "route_label", val_col = "n",
            phases  = PHASE_ORDER,
            subcols = unname(ROUTE_SHORT[ROUTE_ORDER])) |>
  fill_table_nas(zero_val = 0L)

save_table(route_wide, n_id = 1L,
           caption = "Compliance routing — counts by group × phase (all records)")

# Table 2b: warm fleet route percentages
route_warm_long <- audits_routed |>
  filter(!cold_engaged) |>
  count(group, phase_display, route, name = "n") |>
  group_by(group, phase_display) |>
  mutate(pct = round(100 * n / sum(n), 1)) |>
  ungroup() |>
  mutate(route_label = unname(ROUTE_SHORT[route])) |>
  select(group, phase_display, route_label, pct)

route_warm_wide <- route_warm_long |>
  make_wide(subcol_var = "route_label", val_col = "pct",
            phases  = PHASE_ORDER,
            subcols = unname(ROUTE_SHORT[ROUTE_ORDER])) |>
  fill_table_nas(zero_val = 0.0)

save_table(route_warm_wide, n_id = 1L,
           caption = "Compliance routing — % warm fleet by group × phase")

# ── Sub-task 3: Sparsity, signal exhaustion, volatility ───────────────────────────

message("\n── Sub-task 3: Sparsity, signal exhaustion, volatility ──\n")

# Cold cell counts (group × phase_display × stage)
cold_cell_counts <- audits |>
  filter(cold_engaged, !ze_flag) |>
  count(group, phase_display, stage_label, name = "n")

cold_totals <- cold_cell_counts |>
  group_by(group, phase_display) |>
  summarise(total_cold = sum(n), .groups = "drop")

# Sparse cells
sparse_cells <- cold_cell_counts |>
  filter(n < SPARSITY_THR) |>
  left_join(cold_totals, by = c("group","phase_display")) |>
  arrange(group, match(phase_display, PHASE_ORDER), stage_label)

message("Sparse cold cells (n < ", SPARSITY_THR, "): ", nrow(sparse_cells))
if (nrow(sparse_cells) > 0) {
  # Sparsity table: show count only where sparse; all other cells blank (NA → "—")
  sparse_wide <- sparse_cells |>
    select(group, phase_display, stage_label, n) |>
    make_wide(subcol_var = "stage_label", val_col = "n",
              phases = PHASE_ORDER, subcols = STAGE_LEVELS)
  # Do NOT fill_table_nas here: non-sparse cells should also show "—" (NA)
  # Only structural blanks need to be preserved; incidental NAs mean "not sparse"
  save_table(sparse_wide, n_id = 1L,
             caption = paste0("Sparsity — cold cells n < ", SPARSITY_THR,
                              " (blank = n \u2265 ", SPARSITY_THR, " or group absent)"))
} else {
  message("  No sparse cold cells found.")
}

# Signal exhaustion: % cold fleet at group max_stage by phase
signal_exhaustion <- cold_totals |>
  left_join(
    cold_cell_counts |>
      mutate(stage_int = match(stage_label, STAGE_LEVELS)) |>
      filter(stage_int == MAX_STAGE[as.character(group)]) |>
      select(group, phase_display, n_at_max = n),
    by = c("group","phase_display")
  ) |>
  replace_na(list(n_at_max = 0L)) |>
  mutate(pct_at_max = round(100 * n_at_max / total_cold, 1))

# Build signal_wide via explicit grid (two sub-columns per phase)
sig_metrics <- c("total_cold","pct_at_max")
sig_long <- signal_exhaustion |>
  pivot_longer(all_of(sig_metrics), names_to = "metric", values_to = "val") |>
  mutate(col_key = paste(phase_display, metric, sep = "__"))

sig_grid <- expand.grid(
  group  = GROUP_ORDER,
  phase  = PHASE_ORDER,
  metric = sig_metrics,
  stringsAsFactors = FALSE
) |>
  mutate(col_key = paste(phase, metric, sep = "__"))

signal_wide <- sig_grid |>
  left_join(sig_long |> select(group, col_key, val),
            by = c("group","col_key")) |>
  pivot_wider(id_cols = "group", names_from = "col_key", values_from = "val") |>
  arrange(match(group, GROUP_ORDER))

# Reorder: interleave total_cold, pct_at_max within each phase
sig_ordered_cols <- unlist(lapply(PHASE_ORDER, function(ph)
  paste(ph, sig_metrics, sep = "__")))
sig_ordered_cols <- intersect(sig_ordered_cols, names(signal_wide))
signal_wide <- signal_wide |>
  select("group", all_of(sig_ordered_cols)) |>
  fill_table_nas(zero_val = 0.0)

save_table(signal_wide, n_id = 1L,
           caption = "Signal exhaustion — cold fleet n and % at max_stage by group × phase")

# Volatility: year-to-year SD of % cold fleet at max_stage within Phase B
volatility <- audits |>
  filter(cold_engaged, phase == "B",
         group %in% c("Constant_Speed","CAZ_Plus","Rest_of_London"),
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
    pct_min      = round(min(pct),    1),
    pct_max      = round(max(pct),    1),
    pct_mean     = round(mean(pct),   1),
    sd_pct       = round(sd(pct),     1),
    sd_yoy_delta = round(sd(diff(pct)), 1),
    .groups = "drop"
  )

# Add Variable_Speed row with all NAs (no Phase B data)
volatility <- bind_rows(
  volatility,
  tibble(group = "Variable_Speed")
) |>
  arrange(match(group, GROUP_ORDER))

vol_caption <- "Volatility — SD of % cold fleet at max_stage in Phase B"
vol_html    <- make_html_table(volatility, n_id = 1L)
cat(paste0("\n### ", vol_caption, "\n\n"), file = out_file, append = TRUE)
cat(vol_html, "\n",                        file = out_file, append = TRUE)
cat("\n###", vol_caption, "\n")
print(knitr::kable(volatility, format = "simple", na = "\u2014"))
cat("\n")

# Bundle sparsity objects for saving
sparsity_summary <- list(
  cold_cell_counts  = cold_cell_counts,
  cold_totals       = cold_totals,
  sparse_cells      = sparse_cells,
  signal_exhaustion = signal_exhaustion,
  volatility        = volatility
)

# ── Sub-task 4: Findings summary — stop here and confirm before Step 3 ────────────

message("\n══════════════════════════════════════════════════════════════")
message("Sub-task 4: FINDINGS SUMMARY — review outputs before proceeding to Step 3")
message("══════════════════════════════════════════════════════════════\n")

message("Total retained records by group × phase:")
audits |>
  count(group, phase) |>
  pivot_wider(names_from = phase, values_from = n, values_fill = 0L) |>
  print()

message("\nCold-engaged totals by group × phase_display:")
cold_totals |>
  pivot_wider(names_from = phase_display, values_from = total_cold, values_fill = 0L) |>
  print()

message("\nSignal exhaustion summary — Phase B cold fleet:")
signal_exhaustion |>
  filter(grepl("^B", phase_display)) |>
  print()

message("\nSparse cells (n < ", SPARSITY_THR, "): ", nrow(sparse_cells))
if (nrow(sparse_cells) > 0) print(sparse_cells)

message("\nCompliance route anomalies (unknown): ", n_unknown)
message("ZE/Stage-7 records flagged (excluded from tables): ", n_ze)

message("\n[STOP] Tables and plots written to outputs/", SCRIPT_STEM, ".md")
message("Report findings; confirm analytical approach is acceptable before Step 3.")
message("Say 'step complete' when outputs are accepted.")

# ── Save intermediate objects ─────────────────────────────────────────────────────

saveRDS(stage_dist,       file.path(OUT_DIR, "stage_dist.rds"))
saveRDS(audits_routed,    file.path(OUT_DIR, "audits_step2.rds"))
saveRDS(sparsity_summary, file.path(OUT_DIR, "sparsity_summary.rds"))

manifest_entries <- tibble(
  object = c("stage_dist","audits_step2","sparsity_summary"),
  file   = file.path("intermediate",
                     c("stage_dist.rds","audits_step2.rds","sparsity_summary.rds")),
  class  = c("tbl_df","tbl_df","list"),
  dim    = c(
    paste0(nrow(stage_dist),    " x ", ncol(stage_dist)),
    paste0(nrow(audits_routed), " x ", ncol(audits_routed)),
    paste0(length(sparsity_summary), " elements")
  ),
  step        = "step2",
  description = c(
    "Stage counts with pct by group x year x cold_engaged x initial_stage (ZE excluded)",
    "audits enriched with phase_sub, phase_display, stage_label, ze_flag, compliance route",
    "Sparsity: cold cell counts, signal exhaustion, volatility by group x phase_display"
  )
)
update_manifest(manifest_entries)
message("Manifest updated: ", MANIFEST_FILE)

message("\n=== OBJECTS SAVED (step 2) ===")
message(sprintf("  %-22s  %-9s  %s", "object", "class", "dim"))
for (i in seq_len(nrow(manifest_entries))) {
  message(sprintf("  %-22s  %-9s  %s",
                  manifest_entries$object[i],
                  manifest_entries$class[i],
                  manifest_entries$dim[i]))
}

sessionInfo()
