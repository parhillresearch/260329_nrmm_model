#!/usr/bin/env Rscript

# Item 7 compliance outcome tree — all analytical groups
# Validates emissions compliance improvement against schema.md Item 7 (Rules for compliance outcomes)
# Produces one tree graphic per group saved to outputs/

library(readr)
library(dplyr)
library(igraph)
library(ggraph)
library(ggplot2)

# ===== GROUP CONFIGURATION (schema.md Items 3 and 6) =====

GROUPS <- list(
  list(
    name        = "Constant_Speed",
    engine_type = "Constant",
    zones       = c("CAZ", "OA", "GL"),
    thresholds  = list(A1A2 = 3, B = 6, C = 6)   # IIIA → V → V
  ),
  list(
    name        = "CAZ_Plus",
    engine_type = "Variable",
    zones       = c("CAZ", "OA"),
    thresholds  = list(A1A2 = 4, B = 5, C = 6)   # IIIB → IV → V
  ),
  list(
    name        = "Rest_of_London",
    engine_type = "Variable",
    zones       = c("GL"),
    thresholds  = list(A1A2 = 3, B = 4, C = 5)   # IIIA → IIIB → IV
  )
)

# ===== LOAD DATA =====

cat("Loading audit data...\n")
audits <- read_delim("input_data/audits.txt", delim = "\t", show_col_types = FALSE)

if (nrow(problems(audits)) > 0) {
  cat("WARNING: Parsing issues in audits.txt:\n")
  print(problems(audits))
  cat("\n")
}

essential_cols <- c(
  "Zone", "Engine Type", "Date", "Cold-Engaged", "Machine Type",
  "Initial Emissions Stage", "Final Emissions Stage",
  "Initial Machinery Compliance", "Final Machinery Compliance",
  "Initial Site Reasons", "Final Site Reasons"
)
missing_cols <- setdiff(essential_cols, names(audits))
if (length(missing_cols) > 0) {
  stop("Missing columns: ", paste(missing_cols, collapse = ", "))
}

cat("✓ All essential columns present\n\n")

# ===== ANALYSIS LOOP =====

for (grp in GROUPS) {

  cat(rep("=", 60), "\n", sep = "")
  cat("GROUP:", grp$name, "\n")
  cat(rep("=", 60), "\n", sep = "")

  # Filter to this group
  audits_grp <- audits %>%
    filter(`Engine Type` == grp$engine_type, Zone %in% grp$zones) %>%
    mutate(across(everything(), ~ ifelse(is.na(.), "NA", as.character(.))))

  cat("Records:", nrow(audits_grp), "\n\n")

  # Phase and threshold assignment
  audits_grp <- audits_grp %>%
    mutate(
      date_numeric = as.numeric(as.Date(Date)),
      phase = case_when(
        date_numeric < as.numeric(as.Date("2019-01-01")) ~ "A1",
        date_numeric < as.numeric(as.Date("2020-09-01")) ~ "A2",
        date_numeric < as.numeric(as.Date("2025-01-01")) ~ "B",
        TRUE ~ "C"
      ),
      threshold = case_when(
        phase %in% c("A1", "A2") ~ grp$thresholds$A1A2,
        phase == "B"             ~ grp$thresholds$B,
        phase == "C"             ~ grp$thresholds$C,
        TRUE                     ~ NA_integer_
      )
    )

  # Stage encoding and outcome derivation
  audits_grp <- audits_grp %>%
    mutate(
      initial_stage = case_when(
        `Initial Emissions Stage` %in% c("I",    "1") ~ 1L,
        `Initial Emissions Stage` %in% c("II",   "2") ~ 2L,
        `Initial Emissions Stage` %in% c("IIIA", "3") ~ 3L,
        `Initial Emissions Stage` %in% c("IIIB", "4") ~ 4L,
        `Initial Emissions Stage` %in% c("IV",   "5") ~ 5L,
        `Initial Emissions Stage` %in% c("V",    "6") ~ 6L,
        `Initial Emissions Stage` == "ZE"             ~ 7L,
        TRUE ~ NA_integer_
      ),
      final_stage = case_when(
        `Final Emissions Stage` %in% c("I",    "1") ~ 1L,
        `Final Emissions Stage` %in% c("II",   "2") ~ 2L,
        `Final Emissions Stage` %in% c("IIIA", "3") ~ 3L,
        `Final Emissions Stage` %in% c("IIIB", "4") ~ 4L,
        `Final Emissions Stage` %in% c("IV",   "5") ~ 5L,
        `Final Emissions Stage` %in% c("V",    "6") ~ 6L,
        `Final Emissions Stage` == "ZE"             ~ 7L,
        TRUE ~ NA_integer_
      ),
      initial_emissions_compliant  = (initial_stage >= threshold),
      final_emissions_compliant    = (final_stage   >= threshold),
      emissions_improved_by_upgrade = (!initial_emissions_compliant & final_emissions_compliant),
      emissions_improved_by_removal = (!initial_emissions_compliant &
                                       grepl("Removed", `Final Machinery Compliance`, ignore.case = TRUE)),
      emissions_improved = (emissions_improved_by_upgrade | emissions_improved_by_removal),
      missing_initial_stage = is.na(initial_stage)
    )

  # Clean set: initial stage present, NRMM in-scope
  audits_clean <- audits_grp %>%
    filter(!missing_initial_stage, `Machine Type` != "No NRMM")

  N_all <- nrow(audits_grp)
  p     <- function(n) paste0(round(100 * n / N_all, 1), "%")
  lbl   <- function(title, row, n) paste0(title, "\n(", row, ")\n", n, " | ", p(n))

  # Brief console summary
  cat("Improved by upgrade:", sum(audits_clean$emissions_improved_by_upgrade, na.rm = TRUE),
      "(", p(sum(audits_clean$emissions_improved_by_upgrade, na.rm = TRUE)), ")\n")
  cat("Improved by removal:", sum(audits_clean$emissions_improved_by_removal, na.rm = TRUE),
      "(", p(sum(audits_clean$emissions_improved_by_removal, na.rm = TRUE)), ")\n")
  cat("Total improved:     ", sum(audits_clean$emissions_improved, na.rm = TRUE),
      "(", p(sum(audits_clean$emissions_improved, na.rm = TRUE)), ")\n\n")

  # ===== ENFORCEMENT PATHWAYS =====

  improved_records <- filter(audits_clean, emissions_improved)
  upgraded_records <- filter(audits_clean, emissions_improved_by_upgrade)
  removed_records  <- filter(audits_clean, emissions_improved_by_removal)

  if (nrow(improved_records) > 0) {
    if (nrow(upgraded_records) > 0) {
      cat("Stage upgrade — Final Machinery Compliance (% of sample):\n")
      print(round(100 * table(upgraded_records$`Final Machinery Compliance`) / N_all, 1))
      cat("Stage upgrade — Final Site Reasons (% of sample):\n")
      print(round(100 * table(upgraded_records$`Final Site Reasons`) / N_all, 1))
      cat("\n")
    }
    if (nrow(removed_records) > 0) {
      cat("Removal — Final Machinery Compliance (% of sample):\n")
      print(round(100 * table(removed_records$`Final Machinery Compliance`) / N_all, 1))
      cat("Removal — Final Site Reasons (% of sample):\n")
      print(round(100 * table(removed_records$`Final Site Reasons`) / N_all, 1))
      cat("\n")
    }
    cat("By Cold-Engaged (% of sample):\n")
    print(
      audits_clean %>%
        group_by(`Cold-Engaged`) %>%
        summarise(
          pct_of_sample = round(100 * n() / N_all, 1),
          pct_improved  = round(100 * sum(emissions_improved, na.rm = TRUE) / N_all, 1)
        )
    )
    cat("\n")
  } else {
    cat("WARNING: No emissions improvements found for", grp$name, "\n\n")
  }

  # ===== ITEM 7 TREE GRAPHIC =====

  n_no_nrmm        <- sum(audits_grp$`Machine Type` == "No NRMM", na.rm = TRUE)
  n_in_scope       <- N_all - n_no_nrmm
  n_init_compliant <- sum(audits_clean$initial_emissions_compliant == TRUE,  na.rm = TRUE)
  n_init_noncomp   <- sum(audits_clean$initial_emissions_compliant == FALSE, na.rm = TRUE)

  noncomp <- filter(audits_clean, !initial_emissions_compliant)
  cold_nc <- filter(noncomp, `Cold-Engaged` == "Yes")
  warm_nc <- filter(noncomp, `Cold-Engaged` == "No")

  n_cold_nc       <- nrow(cold_nc)
  n_warm_nc       <- nrow(warm_nc)
  n_cold_improved <- sum(cold_nc$emissions_improved, na.rm = TRUE)
  n_cold_not      <- n_cold_nc - n_cold_improved
  n_warm_improved <- sum(warm_nc$emissions_improved, na.rm = TRUE)
  n_warm_not      <- n_warm_nc - n_warm_improved

  nodes <- data.frame(
    id = 1:11,
    label = c(
      paste0("All Records\n", N_all, " | 100%"),
      lbl("No In-Scope Plant",       "Row 6", n_no_nrmm),
      lbl("In-Scope NRMM",           "–",     n_in_scope),
      lbl("Initially Compliant",     "Row 1", n_init_compliant),
      lbl("Initially Non-Compliant", "–",     n_init_noncomp),
      lbl("Cold-Engaged",            "–",     n_cold_nc),
      lbl("Warm-Engaged",            "–",     n_warm_nc),
      lbl("Driven Compliant",        "Row 4", n_cold_improved),
      lbl("Not Actioned",            "Row 5", n_cold_not),
      lbl("Driven Compliant",        "Row 4", n_warm_improved),
      lbl("Not Actioned",            "Row 5", n_warm_not)
    ),
    fill = c(
      "grey70",    # All Records
      "grey50",    # Row 6
      "steelblue", # In-Scope
      "#2ecc71",   # Row 1 – compliant
      "steelblue", # Non-compliant intermediate
      "#e67e22",   # Cold-engaged
      "#3498db",   # Warm-engaged
      "#27ae60",   # Row 4 cold – improved
      "#e74c3c",   # Row 5 cold – not actioned
      "#27ae60",   # Row 4 warm – improved
      "#e74c3c"    # Row 5 warm – not actioned
    ),
    stringsAsFactors = FALSE
  )

  edges <- data.frame(
    from = c(1, 1, 3, 3, 5, 5, 6, 6, 7,  7),
    to   = c(2, 3, 4, 5, 6, 7, 8, 9, 10, 11)
  )

  g_tree <- graph_from_data_frame(edges, directed = TRUE, vertices = nodes)
  V(g_tree)$fill  <- nodes$fill
  V(g_tree)$label <- nodes$label

  tree_plot <- ggraph(g_tree, layout = "tree") +
    geom_edge_link(
      arrow   = arrow(length = unit(3, "mm"), type = "closed"),
      end_cap = circle(12, "mm"),
      colour  = "grey40"
    ) +
    geom_node_label(
      aes(label = label, fill = fill),
      colour        = "white",
      fontface      = "bold",
      size          = 3,
      label.padding = unit(0.4, "lines")
    ) +
    scale_fill_identity() +
    theme_graph(base_family = "sans") +
    labs(
      title    = paste0("Item 7 Compliance Outcome Tree — ", grp$name),
      subtitle = paste0("N = ", N_all,
                        "  |  Green = emissions reduced (Row 4)",
                        "  |  Red = not actioned (Row 5)")
    )

  out_file <- paste0("outputs/item7_tree_", grp$name, ".png")
  ggsave(out_file, tree_plot, width = 18, height = 10, dpi = 300, units = "in")
  cat("Tree saved to", out_file, "\n\n")
}

cat("Done.\n")
