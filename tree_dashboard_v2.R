#!/usr/bin/env Rscript

# Item 7 compliance outcome dashboard — standalone self-contained HTML export.
# Precomputes every Group x Year combination then saves one shareable .html file
# with client-side Group/Year dropdown switching via vis.js setData().
# No Shiny or R installation needed to open the output.

library(readr)
library(dplyr)
library(visNetwork)
library(htmlwidgets)

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

classify_subgroup <- function(engine_type, zone) {
  case_when(
    engine_type == "Constant"                              ~ "Constant_Speed",
    engine_type == "Variable" & zone %in% c("CAZ", "OA") ~ "CAZ_Plus",
    engine_type == "Variable" & zone == "GL"              ~ "Rest_of_London",
    TRUE                                                   ~ NA_character_
  )
}

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

build_outputs <- function(audits_grp_full, year_filter, group_name) {
  audits_grp <- if (identical(year_filter, "All Years")) {
    audits_grp_full
  } else {
    filter(audits_grp_full, year == as.integer(year_filter))
  }
  audits_grp <- filter(audits_grp, `Machine Type` != "No NRMM")

  N_all <- nrow(audits_grp)
  p     <- function(n) paste0(round(100 * n / N_all, 1), "%")
  lbl   <- function(title, n) paste0(title, "\n", n, " | ", p(n))
  root_label <- paste0(gsub("_", " ", group_name), " - ", year_filter)

  audits_clean <- audits_grp %>% filter(!missing_initial_stage)

  n_stage_unresolvable <- sum(audits_grp$missing_initial_stage, na.rm = TRUE)

  stage_unresolved_records <- filter(audits_grp, missing_initial_stage)
  n_unresolved_final_ok    <- sum(!is.na(stage_unresolved_records$final_stage) &
                                     stage_unresolved_records$final_emissions_compliant,  na.rm = TRUE)
  n_unresolved_final_notok <- sum(!is.na(stage_unresolved_records$final_stage) &
                                     !stage_unresolved_records$final_emissions_compliant, na.rm = TRUE)
  n_unresolved_still       <- sum(is.na(stage_unresolved_records$final_stage), na.rm = TRUE)

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

  is_removed <- function(df) grepl("Removed", df$`Final Machinery Compliance`, ignore.case = TRUE)

  cold_improved_records <- filter(cold_nc, emissions_improved)
  n_cold_removed  <- sum(is_removed(cold_improved_records), na.rm = TRUE)
  n_cold_upgraded <- n_cold_improved - n_cold_removed

  warm_improved_records <- filter(warm_nc, emissions_improved)
  n_warm_removed  <- sum(is_removed(warm_improved_records), na.rm = TRUE)
  n_warm_upgraded <- n_warm_improved - n_warm_removed

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

  list(N_all = N_all, n_improved = sum(audits_clean$emissions_improved, na.rm = TRUE),
       nodes = nodes, edges = edges)
}

# ===== COMPUTE RESULTS =====

cat("Processing groups...\n")
results <- setNames(
  lapply(GROUPS, process_group, audits = audits),
  sapply(GROUPS, function(g) g$name)
)
results[["All_Groups"]] <- process_all_groups(audits, GROUPS)

# ===== PRECOMPUTE ALL GROUP x YEAR COMBINATIONS =====

# htmlwidgets:::toJSON2 defaults to dataframe="columns", so data.frames nested
# inside onRender's data= argument serialize as {id:[1,2,3]} not [{id:1},...].
# Converting to list-of-row-lists strips the data.frame class, producing the
# row-array-of-objects format vis.js expects.
df_to_rowlist <- function(df) lapply(seq_len(nrow(df)), function(i) as.list(df[i, , drop = FALSE]))

cat("Precomputing combinations...\n")
combos <- setNames(lapply(names(results), function(g) {
  years <- c("All Years", as.character(sort(unique(results[[g]]$year))))
  setNames(lapply(years, function(yk) {
    o <- build_outputs(results[[g]], yk, g)
    list(nodes = df_to_rowlist(o$nodes), edges = df_to_rowlist(o$edges),
         N_all = o$N_all, n_improved = o$n_improved)
  }), years)
}), names(results))

# ===== BUILD WIDGET =====

default_group <- names(results)[1]
default_year  <- "All Years"

o0 <- build_outputs(results[[default_group]], default_year, default_group)
vis_nodes0 <- o0$nodes %>%
  mutate(
    color           = fill,
    font            = list(list(color = "white", size = 18)),
    shape           = "box",
    widthConstraint = list(list(maximum = 160))
  )

graph <- visNetwork(vis_nodes0, o0$edges, height = "800px") %>%
  visEdges(arrows = "to") %>%
  visHierarchicalLayout(
    direction       = "UD",
    sortMethod      = "directed",
    nodeSpacing     = 250,
    levelSeparation = 180,
    shakeTowards    = "roots"
  ) %>%
  visPhysics(
    solver                = "hierarchicalRepulsion",
    hierarchicalRepulsion = list(nodeDistance = 100, avoidOverlap = 1)
  ) %>%
  visExport(type = "pdf", name = "item7_tree", label = "Export as PDF")

# ===== ATTACH INTERACTIVE CONTROLS VIA onRender =====

js_code <- "function(el, x, data) {
  var groups = Object.keys(data);

  var bar = document.createElement('div');
  bar.style.cssText = 'padding:6px 10px;font:14px Arial,sans-serif;border-bottom:1px solid #ccc;';
  bar.innerHTML =
    'Group: <select id=\"grpSel\">' +
      groups.map(function(g){ return '<option value=\"'+g+'\">'+g+'</option>'; }).join('') +
    '</select>' +
    ' &nbsp; Year: <select id=\"yrSel\"></select>' +
    ' &nbsp; <span id=\"summary\" style=\"color:#555;\"></span>';
  el.parentNode.insertBefore(bar, el);

  var network = document.getElementById('graph' + el.id).chart;
  var grpSel = document.getElementById('grpSel');
  var yrSel  = document.getElementById('yrSel');

  function redraw() {
    var combo = data[grpSel.value][yrSel.value];
    network.setData({
      nodes: new vis.DataSet(combo.nodes.map(function(n) {
        return { id: n.id, label: n.label, color: n.fill,
                 font: { color: 'white', size: 18 },
                 shape: 'box', widthConstraint: { maximum: 160 } };
      })),
      edges: new vis.DataSet(combo.edges)
    });
    var pct = combo.N_all > 0 ? (100 * combo.n_improved / combo.N_all).toFixed(1) : '0.0';
    document.getElementById('summary').textContent =
      'N = ' + combo.N_all + '   Improved = ' + combo.n_improved + ' (' + pct + '%%)';
  }

  grpSel.onchange = function() {
    var years = Object.keys(data[grpSel.value]).sort(function(a, b) {
      return a === 'All Years' ? -1 : (b === 'All Years' ? 1 : parseInt(a) - parseInt(b));
    });
    yrSel.innerHTML = years.map(function(y){ return '<option>' + y + '</option>'; }).join('');
    redraw();
  };
  yrSel.onchange = redraw;

  grpSel.value = '%s';
  grpSel.onchange();
}"

graph <- htmlwidgets::onRender(graph, sprintf(js_code, default_group), data = combos)

# ===== SAVE =====

output_file <- "tree_dashboard_v2.html"
htmlwidgets::saveWidget(
  graph,
  output_file,
  selfcontained = TRUE,
  title = "Emissions Compliance - initial state vs final outcome"
)
cat("Saved:", normalizePath(output_file), "\n")
