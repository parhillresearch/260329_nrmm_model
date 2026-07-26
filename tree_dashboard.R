#!/usr/bin/env Rscript

# =====================================================================
# SUPERSEDED - development history only, NOT authoritative.
# Superseded by: nrmm_dashboard_v4.R
# Retained so earlier results remain reproducible. Some definitions here
# differ from the current model (notably removal fate, retrofit NOx credit
# and the usage-index basis), so numbers from this script will not always
# match the current report. Do not cite it. See notes.md, "State of play".
# =====================================================================

# Item 7 compliance outcome dashboard — interactive group + year selection
# Reactive companion to tree_analysis_rol_outcome_focused.R; same derivation
# logic, rendered with visNetwork instead of static ggraph PNGs.

library(readr)
library(dplyr)
library(igraph)
library(shiny)
library(visNetwork)

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

# ===== ENGINE TYPE IMPUTATION (per Step 1 v9 modal logic) =====
# Most pre-2019 audits have blank Engine Type. Impute via modal Engine Type
# per Machine Type, computed from rows where Engine Type is already valid.
# Generators excluded: near 50/50 Constant/Variable split, no reliable mode.

engine_type_modal <- audits %>%
  filter(`Engine Type` %in% c("Constant", "Variable")) %>%
  count(`Machine Type`, `Engine Type`, name = "freq") %>%
  slice_max(freq, by = `Machine Type`, n = 1, with_ties = FALSE) %>%
  select(`Machine Type`, engine_type_modal = `Engine Type`)

audits <- audits %>%
  left_join(engine_type_modal, by = "Machine Type") %>%
  mutate(
    `Engine Type` = if_else(
      !`Engine Type` %in% c("Constant", "Variable") & `Machine Type` != "Generator",
      engine_type_modal,
      `Engine Type`
    )
  ) %>%
  select(-engine_type_modal)

# ===== DATA LAYER =====

#' Shared stage/outcome derivation, applied once Engine Type/Zone filtering
#' and per-row threshold assignment are already done.
derive_outcomes <- function(audits_grp) {
  audits_grp %>%
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
}

#' Filter audits to one group and derive phase/threshold/stage/outcome/year
#' columns. Returns the group's full date range, unfiltered by year — year
#' filtering happens later in build_outputs() so the year dropdown can
#' offer every year actually present in each group's data.
process_group <- function(grp, audits) {
  audits_grp <- audits %>%
    filter(`Engine Type` == grp$engine_type, Zone %in% grp$zones) %>%
    mutate(across(everything(), ~ ifelse(is.na(.), "NA", as.character(.))))

  audits_grp <- audits_grp %>%
    mutate(
      date_numeric = as.numeric(as.Date(Date, format = "%d/%m/%Y")),
      year         = as.integer(format(as.Date(Date, format = "%d/%m/%Y"), "%Y")),
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

  derive_outcomes(audits_grp)
}

#' Classify each row into one of the three in-scope groups by Engine Type
#' and Zone (schema.md Item 6), for the pooled "All_Groups" category.
classify_subgroup <- function(engine_type, zone) {
  case_when(
    engine_type == "Constant"                            ~ "Constant_Speed",
    engine_type == "Variable" & zone %in% c("CAZ", "OA")  ~ "CAZ_Plus",
    engine_type == "Variable" & zone == "GL"              ~ "Rest_of_London",
    TRUE                                                  ~ NA_character_
  )
}

#' Pooled view across all three groups. Each row keeps its own group's
#' threshold (looked up by subgroup + phase) so compliance is evaluated
#' against the correct standard even though groups are combined.
process_all_groups <- function(audits, groups) {
  g <- setNames(groups, sapply(groups, `[[`, "name"))

  audits_grp <- audits %>%
    mutate(subgroup = classify_subgroup(`Engine Type`, Zone)) %>%
    filter(!is.na(subgroup)) %>%
    mutate(across(everything(), ~ ifelse(is.na(.), "NA", as.character(.))))

  audits_grp <- audits_grp %>%
    mutate(
      date_numeric = as.numeric(as.Date(Date, format = "%d/%m/%Y")),
      year         = as.integer(format(as.Date(Date, format = "%d/%m/%Y"), "%Y")),
      phase = case_when(
        date_numeric < as.numeric(as.Date("2019-01-01")) ~ "A1",
        date_numeric < as.numeric(as.Date("2020-09-01")) ~ "A2",
        date_numeric < as.numeric(as.Date("2025-01-01")) ~ "B",
        TRUE ~ "C"
      ),
      threshold = case_when(
        subgroup == "Constant_Speed" & phase %in% c("A1", "A2") ~ g$Constant_Speed$thresholds$A1A2,
        subgroup == "Constant_Speed" & phase == "B"              ~ g$Constant_Speed$thresholds$B,
        subgroup == "Constant_Speed" & phase == "C"              ~ g$Constant_Speed$thresholds$C,
        subgroup == "CAZ_Plus"       & phase %in% c("A1", "A2") ~ g$CAZ_Plus$thresholds$A1A2,
        subgroup == "CAZ_Plus"       & phase == "B"              ~ g$CAZ_Plus$thresholds$B,
        subgroup == "CAZ_Plus"       & phase == "C"              ~ g$CAZ_Plus$thresholds$C,
        subgroup == "Rest_of_London" & phase %in% c("A1", "A2") ~ g$Rest_of_London$thresholds$A1A2,
        subgroup == "Rest_of_London" & phase == "B"              ~ g$Rest_of_London$thresholds$B,
        subgroup == "Rest_of_London" & phase == "C"              ~ g$Rest_of_London$thresholds$C,
        TRUE                                                     ~ NA_integer_
      )
    )

  derive_outcomes(audits_grp)
}

#' Subset a group's data to one year (or keep all years), then build the
#' tree nodes/edges and summary tables — mirrors the analysis-loop body of
#' tree_analysis_rol_outcome_focused.R, parameterised by year.
build_outputs <- function(audits_grp_full, year_filter, group_name) {
  audits_grp <- if (identical(year_filter, "All Years")) {
    audits_grp_full
  } else {
    filter(audits_grp_full, year == as.integer(year_filter))
  }
  # "No NRMM" rows are always dropped upstream already (blank Engine Type
  # never survives process_group()'s Engine Type filter), but excluded here
  # too so N_all unambiguously means "in-scope NRMM" with no separate node.
  audits_grp <- filter(audits_grp, `Machine Type` != "No NRMM")

  N_all <- nrow(audits_grp)
  p     <- function(n) paste0(round(100 * n / N_all, 1), "%")
  lbl   <- function(title, n) paste0(title, "\n", n, " | ", p(n))
  root_label <- paste0(gsub("_", " ", group_name), " - ", year_filter)

  audits_clean <- audits_grp %>%
    filter(!missing_initial_stage)

  improved_records <- filter(audits_clean, emissions_improved)
  upgraded_records <- filter(audits_clean, emissions_improved_by_upgrade)
  removed_records  <- filter(audits_clean, emissions_improved_by_removal)

  upgrade_tbl_compliance <- if (nrow(upgraded_records) > 0) {
    as.data.frame(round(100 * table(upgraded_records$`Final Machinery Compliance`) / N_all, 1))
  } else NULL
  upgrade_tbl_reasons <- if (nrow(upgraded_records) > 0) {
    as.data.frame(round(100 * table(upgraded_records$`Final Site Reasons`) / N_all, 1))
  } else NULL
  removal_tbl_compliance <- if (nrow(removed_records) > 0) {
    as.data.frame(round(100 * table(removed_records$`Final Machinery Compliance`) / N_all, 1))
  } else NULL
  removal_tbl_reasons <- if (nrow(removed_records) > 0) {
    as.data.frame(round(100 * table(removed_records$`Final Site Reasons`) / N_all, 1))
  } else NULL

  cold_breakdown <- if (nrow(improved_records) > 0) {
    audits_clean %>%
      group_by(`Cold-Engaged`) %>%
      summarise(
        pct_of_sample = round(100 * n() / N_all, 1),
        pct_improved  = round(100 * sum(emissions_improved, na.rm = TRUE) / N_all, 1)
      )
  } else NULL

  # ===== ITEM 7 TREE =====

  n_stage_unresolvable <- sum(audits_grp$missing_initial_stage, na.rm = TRUE)

  # Check final outcomes for Stage Unresolvable audits: even though the
  # initial stage couldn't be read, the final audit may still resolve a
  # stage. Split by whether Final Emissions Stage resolves, and if so,
  # whether it clears that row's threshold. Mutually exclusive and
  # exhaustive, so the three always sum to n_stage_unresolvable.
  stage_unresolved_records  <- filter(audits_grp, missing_initial_stage)
  n_unresolved_final_ok     <- sum(!is.na(stage_unresolved_records$final_stage) &
                                      stage_unresolved_records$final_emissions_compliant,  na.rm = TRUE)
  n_unresolved_final_notok  <- sum(!is.na(stage_unresolved_records$final_stage) &
                                      !stage_unresolved_records$final_emissions_compliant, na.rm = TRUE)
  n_unresolved_still        <- sum(is.na(stage_unresolved_records$final_stage), na.rm = TRUE)

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

  # Disaggregate Driven Compliant by enforcement outcome (schema Item 7 Row 4:
  # "Removed/replaced"). Classified from the raw Final Machinery Compliance
  # text, not the emissions_improved_by_* flags, so the two are mutually
  # exclusive and always sum to n_cold_improved / n_warm_improved.
  is_removed <- function(df) grepl("Removed", df$`Final Machinery Compliance`, ignore.case = TRUE)

  cold_improved_records <- filter(cold_nc, emissions_improved)
  n_cold_removed  <- sum(is_removed(cold_improved_records), na.rm = TRUE)
  n_cold_upgraded <- n_cold_improved - n_cold_removed

  warm_improved_records <- filter(warm_nc, emissions_improved)
  n_warm_removed  <- sum(is_removed(warm_improved_records), na.rm = TRUE)
  n_warm_upgraded <- n_warm_improved - n_warm_removed

  # Disaggregate Not Actioned by Final Site Reasons (schema Item 4 codes,
  # e.g. CER = Cannot Evidence Compliance + Emissions Standard Not Met +
  # Registration Problem). Number of distinct codes present varies by
  # group/year, so these nodes are appended dynamically below.
  # DISABLED — see commented-out block below build_outputs()'s edges.
  # cold_reasons <- count(filter(cold_nc, !emissions_improved), `Final Site Reasons`, name = "n")
  # warm_reasons <- count(filter(warm_nc, !emissions_improved), `Final Site Reasons`, name = "n")

  nodes <- data.frame(
    id = 1:17,
    label = c(
      paste0(root_label, "\n", N_all, " | 100%"),
      lbl("Emissions-Compliant at Start",       n_init_compliant),
      lbl("Emissions Non-Compliant at Start",   n_init_noncomp),
      lbl("Stage Unresolvable",                 n_stage_unresolvable),
      lbl("Cold-Engaged",                       n_cold_nc),
      lbl("Warm-Engaged",                       n_warm_nc),
      lbl("Driven Compliant",                   n_cold_improved),
      lbl("Not Actioned",                       n_cold_not),
      lbl("Driven Compliant",                   n_warm_improved),
      lbl("Not Actioned",                       n_warm_not),
      lbl("Upgraded",                           n_cold_upgraded),
      lbl("Removed/Replaced",                   n_cold_removed),
      lbl("Upgraded",                           n_warm_upgraded),
      lbl("Removed/Replaced",                   n_warm_removed),
      lbl("Final Stage Compliant",              n_unresolved_final_ok),
      lbl("Final Stage Non-Compliant",          n_unresolved_final_notok),
      lbl("Final Stage Also Unresolved",        n_unresolved_still)
    ),
    fill = c(
      "#263238", "#2E7D32", "#37474F", "#424242",
      "#E65100", "#1565C0", "#2E7D32", "#C62828", "#2E7D32", "#C62828",
      "#2E7D32", "#6A1B9A", "#2E7D32", "#6A1B9A",
      "#2E7D32", "#C62828", "#424242"
    ),
    stringsAsFactors = FALSE
  )

  edges <- data.frame(
    from = c(1, 1, 1, 3, 3, 5, 5, 6, 6, 7,  7,  9,  9,  4,  4,  4),
    to   = c(2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17)
  )

  # next_id <- 18L
  # build_reason_nodes <- function(reason_tbl, parent_id) {
  #   if (nrow(reason_tbl) == 0) return(list(nodes = NULL, edges = NULL))
  #   ids <- seq.int(next_id, next_id + nrow(reason_tbl) - 1L)
  #   next_id <<- next_id + nrow(reason_tbl)
  #   list(
  #     nodes = data.frame(
  #       id    = ids,
  #       label = lbl(paste0("Reason: ", reason_tbl$`Final Site Reasons`), "–", reason_tbl$n),
  #       fill  = "#B71C1C",
  #       stringsAsFactors = FALSE
  #     ),
  #     edges = data.frame(from = parent_id, to = ids)
  #   )
  # }
  #
  # cold_reason_out <- build_reason_nodes(cold_reasons, 8)
  # warm_reason_out <- build_reason_nodes(warm_reasons, 10)
  #
  # nodes <- bind_rows(nodes, cold_reason_out$nodes, warm_reason_out$nodes)
  # edges <- bind_rows(edges, cold_reason_out$edges, warm_reason_out$edges)

  list(
    N_all = N_all,
    n_improved = sum(audits_clean$emissions_improved, na.rm = TRUE),
    nodes = nodes,
    edges = edges,
    cold_breakdown = cold_breakdown,
    upgrade_tbl_compliance = upgrade_tbl_compliance,
    upgrade_tbl_reasons = upgrade_tbl_reasons,
    removal_tbl_compliance = removal_tbl_compliance,
    removal_tbl_reasons = removal_tbl_reasons
  )
}

# Compute once per group at startup.
results <- setNames(
  lapply(GROUPS, process_group, audits = audits),
  sapply(GROUPS, function(g) g$name)
)
results[["All_Groups"]] <- process_all_groups(audits, GROUPS)

# ===== UI =====

APP_LOADED_AT <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      html, body { height: 100%; margin: 0; }
      .container-fluid { height: 100vh; display: flex; flex-direction: column; padding-bottom: 0; }
      .container-fluid > h2:first-child {
        flex: 0 0 auto; margin: 6px 0; font-size: 18px; white-space: nowrap;
      }
      .container-fluid > .row { flex: 1 1 auto; min-height: 0; display: flex; }
      .container-fluid > .row > div[class*='col-'] { height: 100%; }
      #tree { height: 100% !important; border: 1px solid #ccc; }
    "))
  ),
  titlePanel(
    tags$div(
      style = "display: flex; align-items: baseline; gap: 12px;",
      tags$span("Emissions Compliance - initial state vs final outcome"),
      tags$small(style = "color: grey;", paste("Instance loaded:", APP_LOADED_AT))
    )
  ),
  sidebarLayout(
    sidebarPanel(
      selectInput("group", "Group:", choices = names(results)),
      selectInput("year", "Year:", choices = c("All Years")),
      verbatimTextOutput("summary_text")
    ),
    mainPanel(
      visNetworkOutput("tree", height = "100%")
    )
  )
)

# ===== SERVER =====

server <- function(input, output, session) {

  observeEvent(input$group, {
    yrs <- sort(unique(results[[input$group]]$year))
    updateSelectInput(session, "year", choices = c("All Years", yrs), selected = "All Years")
  })

  outputs <- reactive({
    build_outputs(results[[input$group]], input$year, input$group)
  })

  output$summary_text <- renderText({
    o <- outputs()
    paste0(
      "N = ", o$N_all, "\n",
      "Improved = ", o$n_improved,
      " (", round(100 * o$n_improved / o$N_all, 1), "%)"
    )
  })

  output$tree <- renderVisNetwork({
    o <- outputs()
    vis_nodes <- o$nodes %>%
      mutate(
        color = fill,
        font = list(list(color = "white", size = 18)),
        shape = "box",
        widthConstraint = list(list(maximum = 160))
      )
    visNetwork(vis_nodes, o$edges) %>%
      visEdges(arrows = "to") %>%
      visHierarchicalLayout(
        direction     = "UD",
        sortMethod    = "directed",
        nodeSpacing   = 250,
        levelSeparation = 180,
        shakeTowards  = "roots"
      ) %>%
      # nodeSpacing/levelSeparation above only set the initial layout; once
      # physics stabilises, actual rest spacing is governed by
      # hierarchicalRepulsion below. avoidOverlap = 1 accounts for each
      # node's real rendered box size (not just its center point), which is
      # what prevents wrapped-text boxes from overlapping.
      visPhysics(
        solver = "hierarchicalRepulsion",
        hierarchicalRepulsion = list(nodeDistance = 100, avoidOverlap = 1)
      ) %>%
      visExport(type = "pdf", name = "item7_tree", label = "Export as PDF")
  })

}

shinyApp(ui, server)
