#!/usr/bin/env Rscript

# =====================================================================
# SUPERSEDED - development history only, NOT authoritative.
# Superseded by: nrmm_dashboard_v4.R
# Retained so earlier results remain reproducible. Some definitions here
# differ from the current model (notably removal fate, retrofit NOx credit
# and the usage-index basis), so numbers from this script will not always
# match the current report. Do not cite it. See notes.md, "State of play".
# =====================================================================

# Item 7 compliance outcome dashboard v4 — standalone self-contained HTML export.
#
# Revisions over v3:
#   View switcher: the v3 outcome tree is retained as "Tree view"; a new
#     "Dot-pair comparison" view (Cleveland dot plot) shows every status and
#     outcome category as a warm dot and a cold dot on a common percentage
#     scale, joined by a line whose length is the warm-cold gap, rows sorted
#     by absolute gap. Rendered as inline SVG so the file stays dependency-free.
#   Viewport fix: the widget fills the browser window below the control bar
#     (CSS override of the fixed 850px canvas), so zooming uses the whole page.
#
# Carried over from v3: engagement-first tree (warm = treatment, cold =
# counterfactual), five-way initial status separating admin-only cases,
# nine-way outcome mechanism with TAN-based removal fate split, NOx-weighted
# summary strip with the proactive gap, generator classification toggle.
#
# Precomputes every GeneratorMode x Group x Year combination then saves one
# shareable .html file with client-side dropdown switching. No Shiny or R
# installation needed to open the output.

library(readr)
library(dplyr)
library(tidyr)
library(visNetwork)
library(htmlwidgets)
library(htmltools)

# --- Named constants ---

PHASE_A2_START <- as.Date("2019-01-01")
PHASE_B_START  <- as.Date("2020-09-01")
PHASE_C_START  <- as.Date("2025-01-01")

# Stage thresholds by subgroup and phase (schema.md Items 3 and 6); stages coded
# I=1, II=2, IIIA=3, IIIB=4, IV=5, V=6, ZE=7.
THRESHOLDS <- list(
  Constant_Speed = list(A1 = 3L, A2 = 3L, B = 6L, C = 6L),
  CAZ_Plus       = list(A1 = 4L, A2 = 4L, B = 5L, C = 6L),
  Rest_of_London = list(A1 = 3L, A2 = 3L, B = 4L, C = 5L)
)

# Indicative NOx emission factors by stage code, g/kWh. PLACEHOLDER pending the
# EMEP/EEA EF_s derivation (analytical objective 6); replace this vector only.
EF_NOX <- c(`1` = 9.2, `2` = 6.0, `3` = 4.0, `4` = 3.3, `5` = 0.4, `6` = 0.4, `7` = 0)

# Stage assumed for a replacement machine when the final stage field is blank
# (schema: replacements use the highest stage on the market).
REPLACEMENT_STAGE_ASSUMED <- 6L

# Values of `Initial Retrofit or Exemption` that do NOT constitute a live
# dispensation at the start of the audit (normalised to lower case).
NON_DISPENSATION_VALUES <- c("", "none", "rejected", "pending", "non",
                             "no nrmm", "unidentified")

# TAN values that cannot identify a machine (normalised to lower case).
UNUSABLE_TAN_VALUES <- c("", "unidentified", "none", "n/a", "na")

GENERATOR_MODES <- c("As recorded", "Generators as Constant Speed")

STATUS_LABELS <- c(
  A = "Stage-Compliant at Start",
  B = "Dispensation Held at Start",
  C = "Emissions Non-Compliant at Start",
  D = "Admin Issue Only (no E code)",
  E = "Unresolvable"
)
STATUS_COLOURS <- c(A = "#2E7D32", B = "#00695C", C = "#37474F",
                    D = "#546E7A", E = "#424242")

OUTCOME_LABELS <- c(
  a = "Replaced On the Spot",
  b = "Stage Upgraded",
  c = "Retrofitted In-Audit",
  d = "Removed: Reappears Elsewhere",
  e = "Removed: Not Seen Again",
  f = "Removed: No TAN",
  g = "Exemption Granted (paper)",
  h = "Compliant, Mechanism Unrecorded",
  i = "Not Remediated"
)
# Colour = evidence class: green real reduction, amber unresolved, grey paper, red none.
OUTCOME_COLOURS <- c(a = "#2E7D32", b = "#2E7D32", c = "#2E7D32",
                     d = "#B45309", e = "#B45309", f = "#B45309",
                     g = "#616161", h = "#B45309", i = "#C62828")

ROOT_COLOUR <- "#263238"
WARM_COLOUR <- "#1565C0"
COLD_COLOUR <- "#E65100"

CONTROL_BAR_HEIGHT_PX <- 110   # reserved for the control bar + summary strip

# --- Load input data ---

cat("Loading audit data...\n")
audits <- read_delim("input_data/audits.txt", delim = "\t", show_col_types = FALSE)

essential_cols <- c(
  "Zone", "Engine Type", "Date", "Cold-Engaged", "Machine Type", "TAN",
  "Initial Emissions Stage", "Final Emissions Stage",
  "Initial Machinery Compliance", "Final Machinery Compliance",
  "Initial Machinery Reasons",
  "Initial Retrofit or Exemption", "Final Retrofit or Exemption"
)
missing_cols <- setdiff(essential_cols, names(audits))
if (length(missing_cols) > 0) {
  stop("Missing columns: ", paste(missing_cols, collapse = ", "))
}

normalise_text <- function(x) trimws(tolower(ifelse(is.na(x), "", as.character(x))))

stage_to_int <- function(x) case_when(
  x %in% c("I",    "1") ~ 1L,
  x %in% c("II",   "2") ~ 2L,
  x %in% c("IIIA", "3") ~ 3L,
  x %in% c("IIIB", "4") ~ 4L,
  x %in% c("IV",   "5") ~ 5L,
  x %in% c("V",    "6") ~ 6L,
  x == "ZE"             ~ 7L,
  TRUE ~ NA_integer_
)

# --- Engine type imputation (per Step 1 v9 modal logic) ---

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

# --- TAN fate lookup (whole dataset, BEFORE any subgroup/year filtering) ---
# A removed machine "reappears" if its TAN is sighted at any strictly later date
# anywhere in the data. Computed globally so single-year views do not miss
# reappearances that fall in other years.

audits <- audits %>%
  mutate(
    audit_date = as.Date(Date, format = "%d/%m/%Y"),
    tan_usable = !is.na(TAN) & !normalise_text(TAN) %in% UNUSABLE_TAN_VALUES
  )

tan_last_seen <- audits %>%
  filter(tan_usable) %>%
  group_by(TAN) %>%
  summarise(tan_last_date = max(audit_date, na.rm = TRUE), .groups = "drop")

audits <- audits %>%
  left_join(tan_last_seen, by = "TAN") %>%
  mutate(tan_reappears_later = tan_usable & !is.na(tan_last_date) &
                               !is.na(audit_date) & tan_last_date > audit_date)

# --- Derive status and outcome classification ---

derive_classification <- function(audits_raw, generators_constant) {

  audits_raw %>%
    mutate(
      # engagement (Level 1)
      cold_engaged = `Cold-Engaged` == "Yes",

      # subgroup assignment; the sensitivity toggle reassigns all generators
      # to Constant_Speed regardless of recorded engine type
      engine_effective = if_else(generators_constant & `Machine Type` == "Generator",
                                 "Constant", `Engine Type`),
      subgroup = case_when(
        engine_effective == "Constant"                              ~ "Constant_Speed",
        engine_effective == "Variable" & Zone %in% c("CAZ", "OA") ~ "CAZ_Plus",
        engine_effective == "Variable" & Zone == "GL"              ~ "Rest_of_London",
        TRUE ~ NA_character_
      ),

      # phase and threshold
      year  = as.integer(format(audit_date, "%Y")),
      phase = case_when(
        audit_date < PHASE_A2_START ~ "A1",
        audit_date < PHASE_B_START  ~ "A2",
        audit_date < PHASE_C_START  ~ "B",
        TRUE                        ~ "C"
      ),
      threshold = case_when(
        subgroup == "Constant_Speed" ~ unlist(THRESHOLDS$Constant_Speed)[phase],
        subgroup == "CAZ_Plus"       ~ unlist(THRESHOLDS$CAZ_Plus)[phase],
        subgroup == "Rest_of_London" ~ unlist(THRESHOLDS$Rest_of_London)[phase],
        TRUE ~ NA_integer_
      ),

      # normalised officer fields
      initial_stage = stage_to_int(`Initial Emissions Stage`),
      final_stage   = stage_to_int(`Final Emissions Stage`),
      final_compliance_norm  = normalise_text(`Final Machinery Compliance`),
      initial_retrofit_norm  = normalise_text(`Initial Retrofit or Exemption`),
      final_retrofit_norm    = normalise_text(`Final Retrofit or Exemption`),

      # officer reason codes: E = emissions standard not met; A/C/P/R/X = admin
      initial_reason_e     = grepl("E", `Initial Machinery Reasons`, fixed = TRUE) &
                             !is.na(`Initial Machinery Reasons`),
      initial_reason_admin = grepl("[ACPRX]",
        ifelse(normalise_text(`Initial Machinery Reasons`) %in% c("none", ""),
               "", `Initial Machinery Reasons`)),

      # compliance and mechanism flags
      dispensation_at_start = !initial_retrofit_norm %in% NON_DISPENSATION_VALUES,
      initial_stage_ok = !is.na(initial_stage) & initial_stage >= threshold,
      final_stage_ok   = !is.na(final_stage)   & final_stage   >= threshold,
      removed_plain    = final_compliance_norm == "removed from site",
      replaced_onspot  = grepl("removed and replaced|removed & replaced|replaced with",
                               final_compliance_norm) |
                         grepl("removed and replaced|removed & replaced|replaced with",
                               final_retrofit_norm),
      new_retrofit  = !grepl("retrofit|dpf", initial_retrofit_norm) &
                       grepl("retrofit|dpf", final_retrofit_norm),
      new_exemption = !dispensation_at_start &
                       grepl("viab|covid|emerg|short|exempt|other|block",
                             final_retrofit_norm),
      officer_final_compliant = final_compliance_norm == "compliant",

      # Level 2: initial emissions status (strict; quarantines admin-only cases)
      initial_status = case_when(
        initial_stage_ok      ~ "A",
        dispensation_at_start ~ "B",
        !is.na(initial_stage) ~ "C",
        initial_reason_e      ~ "C",   # stage unknown but officer E-coded
        initial_reason_admin  ~ "D",
        TRUE                  ~ "E"
      ),

      # Level 3: outcome mechanism (evaluated in priority order; counted only
      # within status C nodes)
      nc_outcome = case_when(
        replaced_onspot                        ~ "a",
        final_stage_ok                         ~ "b",
        new_retrofit                           ~ "c",
        removed_plain & tan_reappears_later    ~ "d",
        removed_plain & tan_usable             ~ "e",
        removed_plain                          ~ "f",
        new_exemption                          ~ "g",
        officer_final_compliant                ~ "h",
        TRUE                                   ~ "i"
      )
    ) %>%
    filter(!is.na(subgroup), `Machine Type` != "No NRMM")
}

# --- Tree and dot-pair construction for one Group x Year selection ---

count_by_key <- function(records, column, keys) {
  counts <- table(factor(records[[column]], levels = keys))
  as.integer(counts)
}

format_pct <- function(n, base) {
  if (base > 0) paste0(round(100 * n / base, 1), "%") else "n/a"
}

pct_num <- function(n, base) {
  if (base > 0) round(100 * n / base, 1) else NA_real_
}

# Indicative NOx saved by a set of status-C records, by outcome class.
# Removals count the machine's full initial EF (elimination assumption; that is
# exactly what the fate split qualifies). Retrofit NOx benefit is indicative
# only (retrofits mainly abate PM); revisit when EF_s lands.
nox_saved <- function(records) {
  records <- filter(records, !is.na(initial_stage))
  if (nrow(records) == 0) return(0)
  initial_ef <- EF_NOX[as.character(records$initial_stage)]
  final_ef <- EF_NOX[as.character(
    pmin(ifelse(is.na(records$final_stage), REPLACEMENT_STAGE_ASSUMED,
                records$final_stage), 7L))]
  sum(ifelse(records$nc_outcome %in% c("d", "e", "f"), initial_ef,
             pmax(initial_ef - final_ef, 0)))
}

branch_summary <- function(records) {
  status_n  <- count_by_key(records, "initial_status", names(STATUS_LABELS))
  nc_records <- filter(records, initial_status == "C")
  outcome_n <- count_by_key(nc_records, "nc_outcome", names(OUTCOME_LABELS))
  resolvable <- sum(status_n[1:3])
  stage_known <- filter(records, !is.na(initial_stage))
  list(
    n = nrow(records),
    status_n = setNames(status_n, names(STATUS_LABELS)),
    outcome_n = setNames(outcome_n, names(OUTCOME_LABELS)),
    c_bar = if (resolvable > 0) sum(status_n[1:2]) / resolvable else NA_real_,
    mean_ef = if (nrow(stage_known) > 0) {
      mean(EF_NOX[as.character(stage_known$initial_stage)])
    } else NA_real_
  )
}

# Dot-pair rows: one per status and outcome category, within-branch percentages,
# sorted by absolute warm-cold gap within each section.
build_dotpair <- function(warm, cold) {
  sort_by_gap <- function(df) df[order(-abs(df$gap), na.last = TRUE), ]

  status_rows <- data.frame(
    label = unname(STATUS_LABELS),
    section = "Initial status (% of branch)",
    warm_pct = vapply(names(STATUS_LABELS),
                      function(k) pct_num(warm$status_n[k], warm$n), numeric(1)),
    cold_pct = vapply(names(STATUS_LABELS),
                      function(k) pct_num(cold$status_n[k], cold$n), numeric(1)),
    warm_n = as.integer(warm$status_n),
    cold_n = as.integer(cold$status_n),
    stringsAsFactors = FALSE
  )
  outcome_rows <- data.frame(
    label = unname(OUTCOME_LABELS),
    section = "Outcome mechanism (% of branch emissions non-compliant)",
    warm_pct = vapply(names(OUTCOME_LABELS),
                      function(k) pct_num(warm$outcome_n[k], warm$status_n["C"]),
                      numeric(1)),
    cold_pct = vapply(names(OUTCOME_LABELS),
                      function(k) pct_num(cold$outcome_n[k], cold$status_n["C"]),
                      numeric(1)),
    warm_n = as.integer(warm$outcome_n),
    cold_n = as.integer(cold$outcome_n),
    stringsAsFactors = FALSE
  )
  rows <- rbind(status_rows, outcome_rows)
  rows$gap <- round(rows$warm_pct - rows$cold_pct, 1)
  rbind(sort_by_gap(rows[rows$section == status_rows$section[1], ]),
        sort_by_gap(rows[rows$section == outcome_rows$section[1], ]))
}

build_outputs <- function(records_full, year_filter, group_name) {

  records <- if (identical(year_filter, "All Years")) {
    records_full
  } else {
    filter(records_full, year == as.integer(year_filter))
  }

  n_all <- nrow(records)
  warm <- branch_summary(filter(records, !cold_engaged))
  cold <- branch_summary(filter(records,  cold_engaged))

  fmt_rate <- function(x) if (is.na(x)) "n/a" else paste0(round(100 * x, 1), "%")
  fmt_ef   <- function(x) if (is.na(x)) "n/a" else format(round(x, 2), nsmall = 2)

  branch_label <- function(title, b) paste0(
    title, "\n", b$n, " | ", format_pct(b$n, n_all),
    "\nc-bar ", fmt_rate(b$c_bar), " | EF ", fmt_ef(b$mean_ef)
  )
  status_label <- function(key, b) paste0(
    STATUS_LABELS[key], "\n", b$status_n[key], " | ",
    format_pct(b$status_n[key], b$n), " of branch"
  )
  outcome_label <- function(key, b) paste0(
    OUTCOME_LABELS[key], "\n", b$outcome_n[key], " | ",
    format_pct(b$outcome_n[key], b$status_n["C"]), " of non-compliant"
  )

  status_keys  <- names(STATUS_LABELS)
  outcome_keys <- names(OUTCOME_LABELS)

  # node ids: 1 root; 2 warm, 3 cold; 4-8 warm status A-E; 9-13 cold status A-E;
  # 14-22 warm outcomes a-i; 23-31 cold outcomes a-i
  nodes <- data.frame(
    id = 1:31,
    label = c(
      paste0(gsub("_", " ", group_name), " - ", year_filter, "\n", n_all, " | 100%"),
      branch_label("Warm-Engaged (treatment)",       warm),
      branch_label("Cold-Engaged (counterfactual)",  cold),
      vapply(status_keys,  status_label,  character(1), b = warm),
      vapply(status_keys,  status_label,  character(1), b = cold),
      vapply(outcome_keys, outcome_label, character(1), b = warm),
      vapply(outcome_keys, outcome_label, character(1), b = cold)
    ),
    fill = c(
      ROOT_COLOUR, WARM_COLOUR, COLD_COLOUR,
      STATUS_COLOURS[status_keys], STATUS_COLOURS[status_keys],
      OUTCOME_COLOURS[outcome_keys], OUTCOME_COLOURS[outcome_keys]
    ),
    stringsAsFactors = FALSE
  )

  warm_c_node <- 4 + which(status_keys == "C") - 1   # id 6
  cold_c_node <- 9 + which(status_keys == "C") - 1   # id 11
  edges <- data.frame(
    from = c(1, 1, rep(2, 5), rep(3, 5), rep(warm_c_node, 9), rep(cold_c_node, 9)),
    to   = c(2, 3, 4:8, 9:13, 14:22, 23:31)
  )

  # summary strip: enforcement channel in NOx terms, plus the proactive gap
  nc_records <- filter(records, initial_status == "C")
  stage_known <- filter(records, !is.na(initial_stage))
  total_nox <- if (nrow(stage_known) > 0) {
    sum(EF_NOX[as.character(stage_known$initial_stage)])
  } else 0
  nox_pct <- function(x) if (total_nox > 0) paste0(round(100 * x / total_nox, 1), "%") else "n/a"

  confirmed <- filter(nc_records, nc_outcome %in% c("a", "b", "c"))
  exits     <- filter(nc_records, nc_outcome == "e")
  unknowns  <- filter(nc_records, nc_outcome %in% c("d", "f"))

  gap_c_bar <- if (!is.na(warm$c_bar) && !is.na(cold$c_bar)) {
    paste0("+", round(100 * (warm$c_bar - cold$c_bar), 1), " pp")
  } else "n/a"
  gap_ef <- if (!is.na(warm$mean_ef) && !is.na(cold$mean_ef) && cold$mean_ef > 0) {
    paste0(round(100 * (1 - warm$mean_ef / cold$mean_ef), 1), "% lower")
  } else "n/a"

  summary_html <- paste0(
    "N = ", n_all,
    " &nbsp;|&nbsp; Confirmed reductions: ", nrow(confirmed),
    " (", nox_pct(nox_saved(confirmed)), " of fleet NOx)",
    " &nbsp;|&nbsp; Probable exits: ", nrow(exits),
    " (+", nox_pct(nox_saved(exits)), ")",
    " &nbsp;|&nbsp; Removal fate unknown: ", nrow(unknowns),
    " (", nox_pct(nox_saved(unknowns)), " at stake)",
    "<br>Proactive gap, warm vs cold: c-bar ", gap_c_bar,
    " &nbsp;|&nbsp; arrival NOx ", gap_ef,
    " &nbsp; <i>(indicative EF weights, pending EF_s)</i>"
  )

  list(nodes = nodes, edges = edges, n_all = n_all, summary = summary_html,
       dotpair = build_dotpair(warm, cold))
}

# --- Compute classification per generator mode ---

cat("Classifying audits...\n")
classified <- setNames(
  lapply(GENERATOR_MODES, function(mode) {
    derive_classification(audits, generators_constant =
                          (mode == "Generators as Constant Speed"))
  }),
  GENERATOR_MODES
)

# --- Verification block ---

cat("Verification...\n")
for (mode in GENERATOR_MODES) {
  d <- classified[[mode]]

  # structural: classification exhaustive, levels sum to parent
  stopifnot(!any(is.na(d$initial_status)), !any(is.na(d$nc_outcome)))
  stopifnot(sum(d$cold_engaged) + sum(!d$cold_engaged) == nrow(d))
  stopifnot(sum(table(d$initial_status)) == nrow(d))
  stopifnot(sum(d$initial_status == "C") ==
              sum(table(d$nc_outcome[d$initial_status == "C"])))

  # referential: the admin-only node must contain no emissions-coded records
  stopifnot(!any(d$initial_status == "D" & d$initial_reason_e))

  # domain: Constant_Speed phase B compliance
  cs_b <- d %>% filter(subgroup == "Constant_Speed", phase == "B",
                       initial_status %in% c("A", "B", "C"))
  cs_b_compliant <- sum(cs_b$initial_status %in% c("A", "B"))
  if (mode == "Generators as Constant Speed") {
    if (cs_b_compliant == 0) {
      stop("Constant_Speed phase B compliance is zero even with generators ",
           "reassigned; the classification fix has not taken effect.")
    }
  } else if (cs_b_compliant == 0) {
    warning("Constant_Speed phase B compliance is 0% under 'As recorded' ",
            "(known Stage V generator engine-type recording issue; ",
            "use the generator toggle for sensitivity).")
  }
  cat(sprintf("  [%s] N = %d, warm = %d, cold = %d, CS phase B compliant = %d\n",
              mode, nrow(d), sum(!d$cold_engaged), sum(d$cold_engaged),
              cs_b_compliant))
}

# --- Precompute all GeneratorMode x Group x Year combinations ---

# htmlwidgets:::toJSON2 defaults to dataframe="columns", so data.frames nested
# inside onRender's data= argument serialize as {id:[1,2,3]} not [{id:1},...].
# Converting to list-of-row-lists strips the data.frame class, producing the
# row-array-of-objects format vis.js expects.
df_to_rowlist <- function(df) lapply(seq_len(nrow(df)), function(i) as.list(df[i, , drop = FALSE]))

GROUP_NAMES <- c("All_Groups", names(THRESHOLDS))

cat("Precomputing combinations...\n")
combos <- setNames(lapply(GENERATOR_MODES, function(mode) {
  d <- classified[[mode]]
  setNames(lapply(GROUP_NAMES, function(g) {
    records_full <- if (g == "All_Groups") d else filter(d, subgroup == g)
    years <- c("All Years", as.character(sort(unique(records_full$year))))
    setNames(lapply(years, function(yk) {
      o <- build_outputs(records_full, yk, g)
      list(nodes = df_to_rowlist(o$nodes), edges = df_to_rowlist(o$edges),
           summary = o$summary, dotpair = df_to_rowlist(o$dotpair))
    }), years)
  }), GROUP_NAMES)
}), GENERATOR_MODES)

# --- Build widget ---

default_mode  <- GENERATOR_MODES[1]
default_group <- "All_Groups"
default_year  <- "All Years"

o0 <- build_outputs(classified[[default_mode]], default_year, default_group)
vis_nodes0 <- o0$nodes %>%
  mutate(
    color           = fill,
    font            = list(list(color = "white", size = 16)),
    shape           = "box",
    widthConstraint = list(list(maximum = 150))
  )

graph <- visNetwork(vis_nodes0, o0$edges, width = "100%", height = "100%") %>%
  visEdges(arrows = "to") %>%
  visHierarchicalLayout(
    direction       = "UD",
    sortMethod      = "directed",
    nodeSpacing     = 190,
    levelSeparation = 200,
    shakeTowards    = "roots"
  ) %>%
  visPhysics(
    solver                = "hierarchicalRepulsion",
    hierarchicalRepulsion = list(nodeDistance = 110, avoidOverlap = 1)
  ) %>%
  visExport(type = "pdf", name = "item7_tree_v4", label = "Export as PDF")

# Viewport fix: override the fixed-size canvas so the active view fills the
# window below the control bar. !important is required to beat the inline
# style htmlwidgets writes on the widget div.
viewport_css <- sprintf("
  html, body { margin: 0; padding: 0; height: 100%%; }
  #htmlwidget_container { width: 100%% !important; }
  .visNetwork.html-widget {
    width: 100%% !important;
    height: calc(100vh - %dpx) !important;
  }
", CONTROL_BAR_HEIGHT_PX)

graph <- htmlwidgets::prependContent(graph, tags$style(HTML(viewport_css)))

# --- Attach interactive controls and dot-pair renderer via onRender ---

js_code <- "function(el, x, data) {
  var combos = data.combos;
  var defaults = data.defaults;
  var genModes = Object.keys(combos);
  var groups = Object.keys(combos[genModes[0]]);
  var WARM = '#1565C0', COLD = '#E65100';

  var bar = document.createElement('div');
  bar.style.cssText = 'padding:6px 10px;font:14px Arial,sans-serif;border-bottom:1px solid #ccc;line-height:1.7;';
  bar.innerHTML =
    'View: <select id=\"viewSel\">' +
      '<option value=\"tree\">Tree</option>' +
      '<option value=\"dotpair\">Dot-pair comparison</option>' +
    '</select>' +
    ' &nbsp; Group: <select id=\"grpSel\">' +
      groups.map(function(g){ return '<option value=\"'+g+'\">'+g+'</option>'; }).join('') +
    '</select>' +
    ' &nbsp; Year: <select id=\"yrSel\"></select>' +
    ' &nbsp; Generators: <select id=\"genSel\">' +
      genModes.map(function(m){ return '<option value=\"'+m+'\">'+m+'</option>'; }).join('') +
    '</select>' +
    '<div id=\"summary\" style=\"color:#555;\"></div>';
  el.parentNode.insertBefore(bar, el);

  var chartDiv = document.createElement('div');
  chartDiv.style.cssText = 'display:none;padding:10px 20px;font:13px Arial,sans-serif;' +
    'overflow:auto;height:calc(100vh - 130px);box-sizing:border-box;';
  el.parentNode.insertBefore(chartDiv, el.nextSibling);

  var network = document.getElementById('graph' + el.id).chart;
  var viewSel = document.getElementById('viewSel');
  var genSel  = document.getElementById('genSel');
  var grpSel  = document.getElementById('grpSel');
  var yrSel   = document.getElementById('yrSel');

  function currentCombo() { return combos[genSel.value][grpSel.value][yrSel.value]; }

  function renderDotPair(rows) {
    var width = Math.max(chartDiv.clientWidth - 40, 700);
    var labelW = 250, rightW = 90, plotW = width - labelW - rightW;
    var rowH = 30, headerH = 30, topPad = 46;
    var sections = [];
    rows.forEach(function(r){ if (sections.indexOf(r.section) < 0) sections.push(r.section); });
    var totalH = topPad + rows.length * rowH + sections.length * headerH + 24;
    function xpos(p) { return labelW + p / 100 * plotW; }

    var svg = ['<svg width=\"' + width + '\" height=\"' + totalH +
               '\" xmlns=\"http://www.w3.org/2000/svg\" font-family=\"Arial\" font-size=\"12\">'];

    // legend
    svg.push('<circle cx=\"' + (labelW + 6) + '\" cy=\"14\" r=\"6\" fill=\"' + WARM + '\"/>');
    svg.push('<text x=\"' + (labelW + 18) + '\" y=\"18\" fill=\"#333\">Warm-engaged (treatment)</text>');
    svg.push('<circle cx=\"' + (labelW + 196) + '\" cy=\"14\" r=\"6\" fill=\"' + COLD + '\"/>');
    svg.push('<text x=\"' + (labelW + 208) + '\" y=\"18\" fill=\"#333\">Cold-engaged (counterfactual)</text>');
    svg.push('<text x=\"' + (labelW + plotW + 10) + '\" y=\"18\" fill=\"#888\">gap (warm-cold)</text>');

    // gridlines
    for (var g = 0; g <= 100; g += 20) {
      svg.push('<line x1=\"' + xpos(g) + '\" y1=\"' + topPad + '\" x2=\"' + xpos(g) +
               '\" y2=\"' + (totalH - 20) + '\" stroke=\"#e5e5e5\"/>');
      svg.push('<text x=\"' + xpos(g) + '\" y=\"' + (topPad - 6) +
               '\" text-anchor=\"middle\" fill=\"#999\" font-size=\"11\">' + g + '%</text>');
    }

    var y = topPad, currentSection = null;
    rows.forEach(function(r) {
      if (r.section !== currentSection) {
        currentSection = r.section;
        y += headerH;
        svg.push('<text x=\"4\" y=\"' + (y - 10) + '\" font-weight=\"bold\" fill=\"#333\">' +
                 r.section + '</text>');
      }
      var cy = y + rowH / 2;
      y += rowH;
      svg.push('<text x=\"' + (labelW - 10) + '\" y=\"' + (cy + 4) +
               '\" text-anchor=\"end\" fill=\"#333\">' + r.label + '</text>');
      if (r.warm_pct !== null && r.cold_pct !== null) {
        svg.push('<line x1=\"' + xpos(Math.min(r.warm_pct, r.cold_pct)) + '\" y1=\"' + cy +
                 '\" x2=\"' + xpos(Math.max(r.warm_pct, r.cold_pct)) + '\" y2=\"' + cy +
                 '\" stroke=\"#bbb\" stroke-width=\"2\"/>');
      }
      if (r.warm_pct !== null) {
        svg.push('<circle cx=\"' + xpos(r.warm_pct) + '\" cy=\"' + cy + '\" r=\"6\" fill=\"' +
                 WARM + '\"><title>Warm: ' + r.warm_n + ' (' + r.warm_pct + '%)</title></circle>');
      }
      if (r.cold_pct !== null) {
        svg.push('<circle cx=\"' + xpos(r.cold_pct) + '\" cy=\"' + cy + '\" r=\"6\" fill=\"' +
                 COLD + '\"><title>Cold: ' + r.cold_n + ' (' + r.cold_pct + '%)</title></circle>');
      }
      var gapText = (r.gap === null) ? 'n/a' : ((r.gap > 0 ? '+' : '') + r.gap + ' pp');
      svg.push('<text x=\"' + (labelW + plotW + 10) + '\" y=\"' + (cy + 4) +
               '\" fill=\"#555\">' + gapText + '</text>');
    });
    svg.push('</svg>');
    chartDiv.innerHTML = svg.join('') +
      '<div style=\"color:#888;padding-top:4px;\">Hover a dot for counts. Rows sorted by ' +
      'absolute gap within each section. Percentages are within-branch, so the two ' +
      'engagement populations are compared like for like.</div>';
  }

  function redraw() {
    var combo = currentCombo();
    document.getElementById('summary').innerHTML = combo.summary;
    if (viewSel.value === 'tree') {
      chartDiv.style.display = 'none';
      el.style.display = 'block';
      network.setData({
        nodes: new vis.DataSet(combo.nodes.map(function(n) {
          return { id: n.id, label: n.label, color: n.fill,
                   font: { color: 'white', size: 16 },
                   shape: 'box', widthConstraint: { maximum: 150 } };
        })),
        edges: new vis.DataSet(combo.edges)
      });
      network.fit();
    } else {
      el.style.display = 'none';
      chartDiv.style.display = 'block';
      renderDotPair(combo.dotpair);
    }
  }

  function refreshYears() {
    var previous = yrSel.value;
    var years = Object.keys(combos[genSel.value][grpSel.value]).sort(function(a, b) {
      return a === 'All Years' ? -1 : (b === 'All Years' ? 1 : parseInt(a) - parseInt(b));
    });
    yrSel.innerHTML = years.map(function(y){ return '<option>' + y + '</option>'; }).join('');
    yrSel.value = years.indexOf(previous) >= 0 ? previous : 'All Years';
    redraw();
  }

  viewSel.onchange = redraw;
  genSel.onchange  = refreshYears;
  grpSel.onchange  = refreshYears;
  yrSel.onchange   = redraw;

  window.addEventListener('resize', function() {
    if (viewSel.value === 'dotpair') renderDotPair(currentCombo().dotpair);
  });

  genSel.value = defaults.mode;
  grpSel.value = defaults.group;
  refreshYears();
}"

graph <- htmlwidgets::onRender(
  graph,
  js_code,
  data = list(combos = combos,
              defaults = list(mode = default_mode, group = default_group))
)

# --- Save ---

output_file <- "tree_dashboard_v4.html"
htmlwidgets::saveWidget(
  graph,
  output_file,
  selfcontained = TRUE,
  title = "Emissions compliance v4 - counterfactual vs treatment outcomes"
)
cat("Saved:", normalizePath(output_file), "\n")
