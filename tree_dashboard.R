#!/usr/bin/env Rscript

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

# ===== DATA LAYER =====

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
      date_numeric = as.numeric(as.Date(Date)),
      year         = as.integer(format(as.Date(Date), "%Y")),
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

  audits_grp
}

#' Subset a group's data to one year (or keep all years), then build the
#' tree nodes/edges and summary tables — mirrors the analysis-loop body of
#' tree_analysis_rol_outcome_focused.R, parameterised by year.
build_outputs <- function(audits_grp_full, year_filter) {
  audits_grp <- if (identical(year_filter, "All Years")) {
    audits_grp_full
  } else {
    filter(audits_grp_full, year == as.integer(year_filter))
  }

  N_all <- nrow(audits_grp)
  p     <- function(n) paste0(round(100 * n / N_all, 1), "%")
  lbl   <- function(title, row, n) paste0(title, "\n(", row, ")\n", n, " | ", p(n))

  audits_clean <- audits_grp %>%
    filter(!missing_initial_stage, `Machine Type` != "No NRMM")

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
      "grey70", "grey50", "steelblue", "#2ecc71", "steelblue",
      "#e67e22", "#3498db", "#27ae60", "#e74c3c", "#27ae60", "#e74c3c"
    ),
    stringsAsFactors = FALSE
  )

  edges <- data.frame(
    from = c(1, 1, 3, 3, 5, 5, 6, 6, 7,  7),
    to   = c(2, 3, 4, 5, 6, 7, 8, 9, 10, 11)
  )

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

# ===== UI =====

ui <- fluidPage(
  titlePanel("Item 7 Compliance Outcome Dashboard"),
  sidebarLayout(
    sidebarPanel(
      selectInput("group", "Group:", choices = names(results)),
      selectInput("year", "Year:", choices = c("All Years")),
      verbatimTextOutput("summary_text")
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("Compliance Tree", visNetworkOutput("tree", height = "600px")),
        tabPanel(
          "Enforcement Pathways",
          h4("Stage Upgrade Pathway"),
          tableOutput("upgrade_tbl_compliance"),
          tableOutput("upgrade_tbl_reasons"),
          h4("Removal Pathway"),
          tableOutput("removal_tbl_compliance"),
          tableOutput("removal_tbl_reasons")
        ),
        tabPanel("Cold vs Warm", tableOutput("cold_breakdown"))
      )
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
    build_outputs(results[[input$group]], input$year)
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
      mutate(color = fill, font = list(list(color = "white", size = 14)), shape = "box")
    visNetwork(vis_nodes, o$edges) %>%
      visEdges(arrows = "to") %>%
      visHierarchicalLayout(direction = "UD")
  })

  render_or_empty <- function(tbl) {
    if (is.null(tbl) || nrow(tbl) == 0) {
      data.frame(Message = "No data for this selection")
    } else {
      tbl
    }
  }

  output$upgrade_tbl_compliance <- renderTable(render_or_empty(outputs()$upgrade_tbl_compliance))
  output$upgrade_tbl_reasons    <- renderTable(render_or_empty(outputs()$upgrade_tbl_reasons))
  output$removal_tbl_compliance <- renderTable(render_or_empty(outputs()$removal_tbl_compliance))
  output$removal_tbl_reasons    <- renderTable(render_or_empty(outputs()$removal_tbl_reasons))
  output$cold_breakdown         <- renderTable(render_or_empty(outputs()$cold_breakdown))
}

shinyApp(ui, server)
