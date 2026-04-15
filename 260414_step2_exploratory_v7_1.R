# 260414_step2_exploratory_v7_1.R
# NRMM LEZ Trend Analysis — Step 2: Exploratory Analysis (Trial 7.1)
#
# Changes from v7:
#   - Table rendering switched from hand-crafted HTML to kableExtra
#     (kable format="html" + add_header_above for phase super-headers)
#   - htmltools dependency removed; kableExtra used instead
#   - Glossary of abbreviations appended to output .md and printed to console
#   - Data logic, make_wide(), fill_table_nas() unchanged from v7
#
# Inputs:  intermediate/audits.rds
# Outputs (intermediate/): stage_dist.rds, audits_step2.rds, sparsity_summary.rds
# Outputs (outputs/):      260414_step2_exploratory_v7_1.md (all tables + inline plots)

library(tidyverse)
library(kableExtra)

# ── Schema constants ──────────────────────────────────────────────────────────────

OUT_DIR       <- "intermediate"
OUTPUTS_DIR   <- "outputs"
MANIFEST_FILE <- file.path(OUT_DIR, "manifest.md")
SCRIPT_STEM   <- "260414_step2_exploratory_v7_1"
SPARSITY_THR  <- 30L

PHASE_B1_END <- as.Date("2022-02-09")
PHASE_B2_END <- as.Date("2023-07-21")

GROUP_ORDER  <- c("Constant_Speed", "CAZ_Plus", "Rest_of_London", "Variable_Speed")
PHASE_ORDER  <- c("A1", "A2", "B1", "B2", "B3", "C")
STAGE_LEVELS <- c("I", "II", "IIIA", "IIIB", "IV", "V")
STAGE_MAP    <- c("1"="I","2"="II","3"="IIIA","4"="IIIB","5"="IV","6"="V","7"="ZE")

ROUTE_ORDER <- c("1_self_compliant","2_driven_compliant_reg","3_non_compliant_R",
                 "4_driven_compliant_emissions","5_non_compliant","unknown")
ROUTE_SHORT <- c(
  "1_self_compliant"             = "Self-compl",
  "2_driven_compliant_reg"       = "Driv-reg",
  "3_non_compliant_R"            = "NC(R)",
  "4_driven_compliant_emissions" = "Driv-emis",
  "5_non_compliant"              = "NC",
  "unknown"                      = "Unknwn"
)

MAX_STAGE <- c(Constant_Speed=3L, CAZ_Plus=5L, Rest_of_London=6L, Variable_Speed=6L)

# Phases where each group has no data → structural blanks (rendered as —)
PHASE_NO_DATA <- list(
  Constant_Speed = character(0),
  CAZ_Plus       = "C",
  Rest_of_London = "C",
  Variable_Speed = c("A1","A2","B1","B2","B3")
)

# ── Helper functions ──────────────────────────────────────────────────────────────

#' Assign display phase: Phase B sub-divided for all groups.
assign_phase_display <- function(date, phase) {
  case_when(
    phase != "B"         ~ phase,
    date <= PHASE_B1_END ~ "B1",
    date <= PHASE_B2_END ~ "B2",
    TRUE                 ~ "B3"
  )
}

#' Assign analytical phase sub-segment: Constant_Speed keeps "B" unsplit.
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
#' expand.grid + left_join guarantees every phase × subcol combination is present.
#' @param df         long tibble with columns: group, phase_display, <subcol_var>, <val_col>
#' @param subcol_var name of the sub-column variable (string)
#' @param val_col    name of the value variable (string)
#' @param phases     ordered phase labels
#' @param subcols    ordered sub-column labels
make_wide <- function(df, subcol_var, val_col = "n",
                      phases  = PHASE_ORDER,
                      subcols = STAGE_LEVELS) {

  grid <- expand.grid(
    group         = GROUP_ORDER,
    phase_display = phases,
    subcol        = subcols,
    stringsAsFactors = FALSE
  )
  names(grid)[names(grid) == "subcol"] <- subcol_var

  df_clean <- df |>
    mutate(across(all_of(c("group", "phase_display", subcol_var)), as.character)) |>
    select(all_of(c("group", "phase_display", subcol_var, val_col))) |>
    group_by(across(all_of(c("group", "phase_display", subcol_var)))) |>
    summarise(across(all_of(val_col), sum, na.rm = TRUE), .groups = "drop")

  joined <- grid |>
    left_join(df_clean, by = c("group", "phase_display", subcol_var))

  wide <- joined |>
    mutate(col_key = paste(phase_display, .data[[subcol_var]], sep = "__")) |>
    pivot_wider(id_cols = "group", names_from = col_key, values_from = all_of(val_col))

  ordered_data_cols <- unlist(lapply(phases, function(ph) paste(ph, subcols, sep = "__")))
  ordered_data_cols <- intersect(ordered_data_cols, names(wide))

  wide |>
    select("group", all_of(ordered_data_cols)) |>
    arrange(match(group, GROUP_ORDER))
}

#' Post-process NAs in a make_wide() output:
#'   structural blanks (group not in scope for that phase) → NA (rendered as —)
#'   incidental zeros (group in scope, subcol absent)      → zero_val
#' @param wide     wide tibble; first column must be "group"; data cols "PHASE__*"
#' @param zero_val 0L for counts, 0.0 for percentages
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
        result[[col]][ri] <- NA_real_
      } else if (is.na(result[[col]][ri])) {
        result[[col]][ri] <- zero_val
      }
    }
  }
  result
}

#' Render a wide phase × subcol table using kableExtra with phase super-headers.
#' Column names must follow "PHASE__METRIC" convention.
#' @param wide    wide tibble; first n_id columns are row identifiers
#' @param n_id    number of row-id columns
#' @param caption table caption string
#' @param na_str  string for NA cells
make_kable <- function(wide, n_id = 1L, caption = "", na_str = "\u2014") {
  data_cols    <- names(wide)[-seq_len(n_id)]
  id_cols      <- names(wide)[seq_len(n_id)]
  phase_labels <- sub("__.*", "", data_cols)
  sub_labels   <- sub(".*__", "", data_cols)
  phase_runs   <- rle(phase_labels)

  # add_header_above vector: blank span for id cols, then phase:colspan pairs
  header_above <- c(setNames(n_id, " "),
                    setNames(phase_runs$lengths, phase_runs$values))

  # Column display names: id cols unchanged, data cols show sub-label only
  col_names <- c(id_cols, sub_labels)

  knitr::kable(
    wide,
    format    = "html",
    col.names = col_names,
    align     = c(rep("l", n_id), rep("r", length(data_cols))),
    na        = na_str,
    caption   = caption
  ) |>
    kable_styling(
      bootstrap_options = c("condensed","bordered"),
      full_width        = FALSE,
      font_size         = 9
    ) |>
    add_header_above(header_above) |>
    row_spec(0, bold = TRUE)
}

#' Write a wide table to .md as kableExtra HTML and print console summary.
save_table <- function(wide, n_id = 1L, caption = "") {
  tbl <- make_kable(wide, n_id = n_id, caption = caption)

  cat(paste0("\n### ", caption, "\n\n"), file = out_file, append = TRUE)
  cat(as.character(tbl), "\n",           file = out_file, append = TRUE)

  # Console: plain markdown, phase-prefixed column names for readability
  console_wide  <- wide
  data_idx      <- seq_len(ncol(wide))[-seq_len(n_id)]
  names(console_wide)[data_idx] <- gsub("__", ".", names(wide)[data_idx])
  cat("\n###", caption, "\n")
  print(knitr::kable(console_wide, format = "simple", na = "\u2014"))
  cat("\n")
  invisible(tbl)
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

stage_dist <- audits |>
  filter(!ze_flag) |>
  count(group, year, cold_engaged, initial_stage, stage_label, name = "n") |>
  group_by(group, year, cold_engaged) |>
  mutate(pct = round(100 * n / sum(n), 1)) |>
  ungroup()

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
           caption = "Compliance routing — counts by group \u00d7 phase (all records)")

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
           caption = "Compliance routing — % warm fleet by group \u00d7 phase")

# ── Sub-task 3: Sparsity, signal exhaustion, volatility ───────────────────────────

message("\n── Sub-task 3: Sparsity, signal exhaustion, volatility ──\n")

cold_cell_counts <- audits |>
  filter(cold_engaged, !ze_flag) |>
  count(group, phase_display, stage_label, name = "n")

cold_totals <- cold_cell_counts |>
  group_by(group, phase_display) |>
  summarise(total_cold = sum(n), .groups = "drop")

sparse_cells <- cold_cell_counts |>
  filter(n < SPARSITY_THR) |>
  left_join(cold_totals, by = c("group","phase_display")) |>
  arrange(group, match(phase_display, PHASE_ORDER), stage_label)

message("Sparse cold cells (n < ", SPARSITY_THR, "): ", nrow(sparse_cells))
if (nrow(sparse_cells) > 0) {
  # All NAs left as — (both structural blanks and non-sparse cells)
  sparse_wide <- sparse_cells |>
    select(group, phase_display, stage_label, n) |>
    make_wide(subcol_var = "stage_label", val_col = "n",
              phases = PHASE_ORDER, subcols = STAGE_LEVELS)
  save_table(sparse_wide, n_id = 1L,
             caption = paste0("Sparsity — cold cells n\u202f<\u202f", SPARSITY_THR,
                              " (blank = n\u202f\u2265\u202f", SPARSITY_THR, " or group absent)"))
} else {
  message("  No sparse cold cells.")
}

# Signal exhaustion
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

sig_ordered_cols <- unlist(lapply(PHASE_ORDER, function(ph)
  paste(ph, sig_metrics, sep = "__")))
sig_ordered_cols <- intersect(sig_ordered_cols, names(signal_wide))
signal_wide <- signal_wide |>
  select("group", all_of(sig_ordered_cols)) |>
  fill_table_nas(zero_val = 0.0)

save_table(signal_wide, n_id = 1L,
           caption = "Signal exhaustion — cold fleet n and pct_at_max by group \u00d7 phase")

# Volatility
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
    pct_min      = round(min(pct),      1),
    pct_max      = round(max(pct),      1),
    pct_mean     = round(mean(pct),     1),
    sd_pct       = round(sd(pct),       1),
    sd_yoy_delta = round(sd(diff(pct)), 1),
    .groups = "drop"
  )

volatility <- bind_rows(
  volatility,
  tibble(group = "Variable_Speed")
) |>
  arrange(match(group, GROUP_ORDER))

vol_caption <- "Volatility — SD of pct_at_max across years, Phase B cold fleet"
vol_tbl <- knitr::kable(volatility, format = "html",
                        caption = vol_caption, na = "\u2014",
                        align   = c("l", rep("r", ncol(volatility) - 1))) |>
  kable_styling(bootstrap_options = c("condensed","bordered"),
                full_width = FALSE, font_size = 9) |>
  row_spec(0, bold = TRUE)

cat(paste0("\n### ", vol_caption, "\n\n"), file = out_file, append = TRUE)
cat(as.character(vol_tbl), "\n",           file = out_file, append = TRUE)
cat("\n###", vol_caption, "\n")
print(knitr::kable(volatility, format = "simple", na = "\u2014"))
cat("\n")

sparsity_summary <- list(
  cold_cell_counts  = cold_cell_counts,
  cold_totals       = cold_totals,
  sparse_cells      = sparse_cells,
  signal_exhaustion = signal_exhaustion,
  volatility        = volatility
)

# ── Glossary ──────────────────────────────────────────────────────────────────────

glossary_md <- "
## Glossary of abbreviations

### Compliance route labels (Tables 2a–2b)

| Abbreviation | Full name | Definition (schema.md Table 3 route) |
|---|---|---|
| Self-compl | Self-compliant | Registered and emissions-compliant with no enforcement action (Route 1) |
| Driv-reg | Driven compliant — registration | Emissions-compliant but unregistered; brought into compliance by registering site/machine (Route 2) |
| NC(R) | Non-compliant — registration | Emissions-compliant but remained unregistered after enforcement request (Route 3) |
| Driv-emis | Driven compliant — emissions | Emissions non-compliant; machine removed or replaced following audit action (Route 4) |
| NC | Non-compliant | Emissions non-compliant; removal/replacement requested but not actioned (Route 5) |
| Unknwn | Unknown | Record not assignable to Routes 1–5 |

### Signal exhaustion table column labels

| Abbreviation | Definition |
|---|---|
| total_cold | Total count of cold-engaged machine audits in that group × phase cell |
| pct_at_max | Percentage of cold-engaged audits where the machine's stage equals the group's maximum active stage; high values indicate the cold fleet has saturated at the policy ceiling |

### Volatility table column labels

| Abbreviation | Definition |
|---|---|
| pct_min / pct_max / pct_mean | Minimum, maximum, and mean of pct_at_max across calendar years within Phase B |
| sd_pct | Standard deviation of pct_at_max across years (cross-sectional spread) |
| sd_yoy_delta | Standard deviation of year-on-year changes in pct_at_max (volatility of the annual trend; high values indicate erratic year-to-year movement) |
"

write(glossary_md, file = out_file, append = TRUE)
cat(glossary_md)

# ── Sub-task 4: Findings summary ──────────────────────────────────────────────────

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

message("\nSignal exhaustion — Phase B cold fleet:")
signal_exhaustion |> filter(grepl("^B", phase_display)) |> print()

message("\nSparse cells (n < ", SPARSITY_THR, "): ", nrow(sparse_cells))
if (nrow(sparse_cells) > 0) print(sparse_cells)

message("\nCompliance route anomalies (unknown): ", n_unknown)
message("ZE/Stage-7 records flagged (excluded from stage tables): ", n_ze)

message("\n[STOP] Tables and plots written to outputs/", SCRIPT_STEM, ".md")
message("Review tables, plots, and glossary; confirm analytical approach.")
message("Say 'step complete' when accepted.")

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
