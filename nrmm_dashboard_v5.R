#!/usr/bin/env Rscript

# nrmm_dashboard_v5 — unified dashboard over nrmm_model_v5.rds.
#
# ***** PROVISIONAL BUILD FOR SHARING WITH THE AUDIT TEAM *****
# Carries a standing banner and a "Data queries" view showing the open
# classification question and what changes under the alternative reading.
# Constant Speed results are not to be cited until that question is answered.
#
# THIS IS THE AUTHORITATIVE DASHBOARD SCRIPT. It consumes the saved model
# object ONLY and never re-derives anything from audits.txt: the
# classification, emissions strata, replacement-rate fits and projections are
# all computed once in nrmm_model_v4.R. Anything shown here that is not in
# that object is a bug.
#
# v4 changes: consumes schema_version 4; surfaces the arrival emissions
# intensity by arm (the report's headline finding, new in model v4) in the
# emissions view; header and inline documentation corrected (v3 wrongly said
# it read nrmm_model_v2.R, and still described the pre-hours/day sliders).
#
# v3 changes: plain-English pass over every user-visible string; hover
# tooltips on category headers, arm rows and badges; Glossary view.
# v2 changes: hours/day usage sliders; Stage populations view.
#
# Views (all share the Group / Year / Phase controls in the bar):
#   Outcomes table  - warm and cold as rows, initial status and outcome
#                     mechanism as columns, with a gap row. Any Group or Year
#                     margin is a client-side sum over the year-keyed cells.
#   Outcomes tree   - the same numbers as a hierarchy, drawn in visNetwork.
#   EF              - fleet emissions intensity as a convex combination over
#                     machine types, with hours/day sliders for the two types
#                     the sensitivity analysis showed actually matter, plus
#                     the arrival intensity by arm.
#   Stage populations - observed and projected stage mix per year and arm.
#   Trends & projections - observed compliance per arm plus the 2025-2030
#                     projection fan, with a replacement-rate slider.
#   Glossary        - plain-English definitions of every term used.
#
# Self-check: the browser re-runs the projection recursion and asserts it
# matches the R model's central projections exactly; the result is the
# "checks" badge in the control bar. A failure there means the JS and R
# implementations have diverged and the projections must not be trusted.

library(dplyr)
library(tidyr)
library(visNetwork)
library(htmlwidgets)
library(htmltools)

CONTROL_BAR_HEIGHT_PX <- 118
MODEL_PATH  <- "intermediate_data/nrmm_model_v5.rds"
OUTPUT_FILE <- "nrmm_dashboard_v5.html"

# --- Load and check the model object ---

cat("Loading model object...\n")
model <- readRDS(MODEL_PATH)
if (is.null(model$schema_version) || model$schema_version != 5L) {
  stop("Model object schema_version != 5; rebuild with nrmm_model_v5.R")
}

# --- Payload verification (halt on inconsistency) ---

cells <- model$outcomes_cells
status_cols  <- paste0("status_", c("A", "B", "C", "D", "E", "X"))
outcome_cols <- paste0("outcome_", letters[1:9])
stopifnot(all(c("subgroup", "year", "arm", "n", status_cols, outcome_cols)
              %in% names(cells)))
stopifnot(all(rowSums(cells[status_cols]) == cells$n))
stopifnot(all(rowSums(cells[outcome_cols]) == cells$status_C))
stopifnot(all(model$ef_results$ef_env_low  <= model$ef_results$ef_central + 1e-9),
          all(model$ef_results$ef_env_high >= model$ef_results$ef_central - 1e-9))
stopifnot(is.data.frame(model$arrival_ef), nrow(model$arrival_ef) > 0,
          all(c("subgroup", "phase", "variant", "ef_warm", "ef_cold", "gap_pct")
              %in% names(model$arrival_ef)))

# p-bar defaults per Machine Group x arm (era 2; Constant_Speed pooled)
pbar_default <- bind_rows(lapply(
  c("Constant_Speed", "CAZ_Plus", "Rest_of_London"), function(group) {
    engine_v <- if (group == "Constant_Speed") "Constant" else "Variable"
    bind_rows(lapply(c("cold_CF", "warm_AT"), function(arm_v) {
      row <- model$pbar %>%
        filter(engine == engine_v, era == "era2",
               arm == if (engine_v == "Constant") "pooled" else arm_v)
      tibble(subgroup = group, arm = arm_v,
             p_fit = max(min(row$p_bar[1], 1), 0), se = row$se[1])
    }))
  }))

# unname() every value: named vectors would serialize as {name: value} objects
# rather than scalars, silently breaking the JS consumers
df_to_rowlist <- function(df) {
  lapply(seq_len(nrow(df)), function(i) lapply(as.list(df[i, , drop = FALSE]), unname))
}

payload <- list(
  cells        = df_to_rowlist(cells),
  ef_results   = df_to_rowlist(model$ef_results),
  strata       = df_to_rowlist(model$strata),
  trend        = df_to_rowlist(model$observed_trend),
  projections  = df_to_rowlist(model$projections),
  proj_init    = df_to_rowlist(model$proj_init),
  thresholds   = df_to_rowlist(model$threshold_schedule),
  pbar_default = df_to_rowlist(pbar_default),
  pbar_table   = df_to_rowlist(model$pbar %>% mutate(across(where(is.numeric), ~ round(.x, 4)))),
  stage_pop    = df_to_rowlist(model$stage_populations),
  arrival_ef   = df_to_rowlist(model$arrival_ef),
  sens_trend   = df_to_rowlist(model$classification_sensitivity_trend),
  sens_group   = df_to_rowlist(model$classification_sensitivity),
  removal_year = df_to_rowlist(model$removal_fate_by_year),
  flags        = df_to_rowlist(model$structural_flags),
  provisional  = model$provisional_note,
  ex_base      = model$excavator_energy_day
)

# --- Host widget (tree view lives in the visNetwork canvas) ---

init_nodes <- data.frame(id = 1, label = "loading", shape = "box")
init_edges <- data.frame(from = integer(0), to = integer(0))

graph <- visNetwork(init_nodes, init_edges, width = "100%", height = "100%") %>%
  visEdges(arrows = "to") %>%
  visHierarchicalLayout(direction = "UD", sortMethod = "directed",
                        nodeSpacing = 190, levelSeparation = 200,
                        shakeTowards = "roots") %>%
  visPhysics(solver = "hierarchicalRepulsion",
             hierarchicalRepulsion = list(nodeDistance = 110, avoidOverlap = 1)) %>%
  visExport(type = "pdf", name = "nrmm_dashboard_v5", label = "Export as PDF")

viewport_css <- sprintf("
  html, body { margin: 0; padding: 0; height: 100%%; }
  #htmlwidget_container { width: 100%% !important; }
  .visNetwork.html-widget {
    width: 100%% !important;
    height: calc(100vh - %dpx) !important;
  }
", CONTROL_BAR_HEIGHT_PX)
graph <- htmlwidgets::prependContent(graph, tags$style(HTML(viewport_css)))

js_code <- "function(el, x, data) {
  var WARM = '#1565C0', COLD = '#E65100';
  var STATUS_KEYS = ['A','B','C','D','E','X'];
  var STATUS_LABELS = {A:'Stage-Compliant at Start', B:'Dispensation Held at Start',
    C:'Emissions Non-Compliant at Start', D:'Admin Issue Only (no E code)', E:'Unresolvable',
    X:'No Determination Made'};
  var STATUS_COLOURS = {A:'#2E7D32', B:'#00695C', C:'#37474F', D:'#546E7A', E:'#424242', X:'#8D6E63'};
  var OUTCOME_KEYS = ['a','b','c','d','e','f','g','h','i'];
  var OUTCOME_LABELS = {a:'Replaced On the Spot', b:'Stage Upgraded', c:'Retrofitted In-Audit',
    d:'Removed: Reappears Elsewhere', e:'Removed: Not Seen Again', f:'Removed: No TAN',
    g:'Exemption Granted (paper)', h:'Compliant, Mechanism Unrecorded', i:'Not Remediated'};
  var OUTCOME_COLOURS = {a:'#2E7D32', b:'#2E7D32', c:'#2E7D32', d:'#B45309', e:'#B45309',
    f:'#B45309', g:'#616161', h:'#B45309', i:'#C62828'};
  var OUTCOME_GROUPS = {a:'Real reduction', b:'Real reduction', c:'Real reduction',
    d:'Removed - fate uncertain', e:'Removed - fate uncertain', f:'Removed - fate uncertain',
    g:'No reduction demonstrated', h:'No reduction demonstrated', i:'No reduction demonstrated'};
  var GROUP_COLOURS = {'Real reduction':'#2E7D32', 'Removed - fate uncertain':'#B45309',
    'No reduction demonstrated':'#455A64'};
  var CAT_TIPS = {
    A: 'Engine stage already meets the standard required at that place and date',
    B: 'Holds an approved retrofit or exemption, so counts as legally compliant',
    C: 'Engine stage below the required standard, with no retrofit or exemption',
    D: 'Paperwork problem only (such as not being registered); never shown to breach the emissions standard',
    E: 'Not enough information recorded to determine status',
    X: 'The visit logged a site-level status (baselining, site complete, no apparent works, declined audit) rather than a judgement about this machine, so no compliance determination was made. The stage is kept; the outcome is not counted.',
    a: 'Non-compliant machine swapped for a compliant one during the audit',
    b: 'Same machine recorded at a cleaner stage by the end of the audit',
    c: 'Exhaust clean-up equipment fitted during the audit',
    d: 'Left the site but audited again later elsewhere, so the pollution may have moved rather than stopped',
    e: 'Left the site and never appears in any later audit',
    f: 'Left the site with no serial number recorded, so its fate is unknown',
    g: 'Granted an exemption: counted compliant, but emissions unchanged',
    h: 'Officer recorded compliance but the data shows no visible mechanism',
    i: 'Still non-compliant at the end of the audit'};
  var GROUP_TIPS = {
    'Real reduction': 'Outcomes where emissions demonstrably fell',
    'Removed - fate uncertain': 'The machine left the site; whether emissions fell depends on where it went',
    'No reduction demonstrated': 'Compliant on paper or not fixed; no emissions change shown'};
  var ARM_TIPS = {
    warm: 'Machines registered with the NRMM scheme - the group the policy applies to (the treatment group)',
    cold: 'Machines found operating without registering (itself illegal) - used as the no-policy comparison (the counterfactual)'};
  var GROUPS = ['All_Groups','Constant_Speed','CAZ_Plus','Rest_of_London'];
  var TREND_GROUPS = ['Constant_Speed','CAZ_Plus','Rest_of_London'];

  // ---------- control bar ----------
  var bar = document.createElement('div');
  bar.style.cssText = 'padding:6px 10px;font:14px Arial,sans-serif;border-bottom:1px solid #ccc;line-height:1.7;';
  bar.innerHTML =
    'View: <select id=\"viewSel\">' +
      '<option value=\"table\">Outcomes table</option>' +
      '<option value=\"tree\">Outcomes tree</option>' +
      '<option value=\"ef\">EF</option>' +
      '<option value=\"stagepop\">Stage populations</option>' +
      '<option value=\"trend\">Trends &amp; projections</option>' +
      '<option value=\"gloss\">Glossary</option>' +
      '<option value=\"queries\">Data queries (open)</option>' +
    '</select>' +
    ' &nbsp; Group: <select id=\"grpSel\"></select>' +
    ' <span id=\"yrWrap\"> &nbsp; Year: <select id=\"yrSel\"></select></span>' +
    ' <span id=\"phWrap\" style=\"display:none;\"> &nbsp; Phase: <select id=\"phSel\"></select></span>' +
    ' &nbsp; <span id=\"parity\" style=\"font-weight:bold;\"></span>' +
    '<div id=\"summary\" style=\"color:#555;\"></div>' +
    '<div style=\"margin-top:4px;padding:6px 10px;background:#FFF4E5;' +
    'border-left:4px solid #B45309;font-size:12.5px;color:#5c3d00;\">' +
    '<b>Provisional.</b> Figures for the <b>Constant Speed</b> group are affected by an open ' +
    'question about how Engine Type is recorded for generators, and should not be quoted yet. ' +
    'See the <b>Data queries</b> view. All other groups are unaffected.</div>';
  el.parentNode.insertBefore(bar, el);

  var pane = document.createElement('div');
  pane.style.cssText = 'display:none;padding:12px 20px;font:13px Arial,sans-serif;' +
    'overflow:auto;height:calc(100vh - 138px);box-sizing:border-box;';
  el.parentNode.insertBefore(pane, el.nextSibling);

  var network = document.getElementById('graph' + el.id).chart;
  var viewSel = document.getElementById('viewSel');
  var grpSel  = document.getElementById('grpSel');
  var yrSel   = document.getElementById('yrSel');
  var phSel   = document.getElementById('phSel');

  // ---------- aggregation helpers ----------
  // Group and Year margins are sums over the year-keyed cells from the model
  // object; nothing is recomputed from raw audits. The All_Groups and All
  // Years selections simply widen the filter, which is valid because the
  // cells are disjoint counts.
  function cellsFor(group, year) {
    return data.cells.filter(function(c) {
      return (group === 'All_Groups' || c.subgroup === group) &&
             (year === 'All Years' || c.year === +year);
    });
  }
  function armSummary(rows, arm) {
    var s = {n: 0};
    STATUS_KEYS.forEach(function(k){ s['status_' + k] = 0; });
    OUTCOME_KEYS.forEach(function(k){ s['outcome_' + k] = 0; });
    rows.filter(function(r){ return r.arm === arm; }).forEach(function(r) {
      s.n += r.n;
      STATUS_KEYS.forEach(function(k){ s['status_' + k] += r['status_' + k]; });
      OUTCOME_KEYS.forEach(function(k){ s['outcome_' + k] += r['outcome_' + k]; });
    });
    var res = s.status_A + s.status_B + s.status_C;
    s.c_bar = res > 0 ? (s.status_A + s.status_B) / res : null;
    return s;
  }
  function pct(n, base) { return base > 0 ? (100 * n / base).toFixed(1) + '%' : 'n/a'; }
  function pctN(n, base) { return base > 0 ? +(100 * n / base).toFixed(1) : null; }

  // ---------- outcomes tree ----------
  function branchLabel(title, b, nAll) {
    return title + '\\n' + b.n + ' | ' + pct(b.n, nAll) +
      '\\ncompliant at arrival: ' + (b.c_bar === null ? 'n/a' : (100 * b.c_bar).toFixed(1) + '%');
  }
  function renderTree(warm, cold, nAll, rootTitle) {
    var nodes = [{id: 1, label: rootTitle + '\\n' + nAll + ' | 100%', color: '#263238'}];
    nodes.push({id: 2, label: branchLabel('Warm-Engaged (treatment)', warm, nAll), color: WARM});
    nodes.push({id: 3, label: branchLabel('Cold-Engaged (counterfactual)', cold, nAll), color: COLD});
    var edges = [{from: 1, to: 2}, {from: 1, to: 3}];
    var id = 4;
    [[warm, 2], [cold, 3]].forEach(function(pair) {
      var b = pair[0], parent = pair[1], cNode = null;
      STATUS_KEYS.forEach(function(k) {
        nodes.push({id: id, label: STATUS_LABELS[k] + '\\n' + b['status_' + k] + ' | ' +
          pct(b['status_' + k], b.n) + ' of branch', color: STATUS_COLOURS[k]});
        edges.push({from: parent, to: id});
        if (k === 'C') cNode = id;
        id++;
      });
      OUTCOME_KEYS.forEach(function(k) {
        nodes.push({id: id, label: OUTCOME_LABELS[k] + '\\n' + b['outcome_' + k] + ' | ' +
          pct(b['outcome_' + k], b.status_C) + ' of non-compliant', color: OUTCOME_COLOURS[k]});
        edges.push({from: cNode, to: id});
        id++;
      });
    });
    network.setData({
      nodes: new vis.DataSet(nodes.map(function(n) {
        return {id: n.id, label: n.label, color: n.color,
                font: {color: 'white', size: 16}, shape: 'box',
                widthConstraint: {maximum: 150}};
      })),
      edges: new vis.DataSet(edges)
    });
    network.fit();
  }

  // ---------- outcomes table ----------
  var CELL = 'border:1px solid #ccc;padding:6px 10px;text-align:center;';
  function hCell(label, colour, colspan, tip) {
    return '<th ' + (colspan ? 'colspan=\"' + colspan + '\" ' : '') +
      (tip ? 'title=\"' + tip + '\" ' : '') + 'style=\"' + CELL +
      'background:' + colour + ';color:white;font-size:12px;font-weight:normal;max-width:110px;' +
      (tip ? 'cursor:help;' : '') + '\">' + label + '</th>';
  }
  function bCell(label, colour, tip) {
    return '<th ' + (tip ? 'title=\"' + tip + '\" ' : '') + 'style=\"' + CELL +
      'background:' + colour + ';color:white;text-align:left;' +
      'font-weight:normal;min-width:170px;' + (tip ? 'cursor:help;' : '') + '\">' + label + '</th>';
  }
  function dCell(n, p) {
    if (p === null) return '<td style=\"' + CELL + 'color:#999;\">n/a</td>';
    return '<td style=\"' + CELL + '\"><b>' + p + '%</b><br><span style=\"color:#777;' +
      'font-size:11px;\">' + n + '</span></td>';
  }
  function gCell(gap) {
    if (gap === null) return '<td style=\"' + CELL + 'color:#999;\">n/a</td>';
    var colour = gap > 0 ? WARM : (gap < 0 ? COLD : '#666');
    return '<td style=\"' + CELL + 'color:' + colour + ';font-weight:bold;\">' +
      (gap > 0 ? '+' : '') + gap + ' pp</td>';
  }
  function outcomesTableRows(warm, cold, keys, labels, colours, base) {
    return keys.map(function(k) {
      var wp = pctN(warm[base + k], base === 'status_' ? warm.n : warm.status_C);
      var cp = pctN(cold[base + k], base === 'status_' ? cold.n : cold.status_C);
      return {label: labels[k], colour: colours[k], key: k,
              warm_n: warm[base + k], warm_pct: wp, cold_n: cold[base + k], cold_pct: cp,
              gap: (wp !== null && cp !== null) ? +(wp - cp).toFixed(1) : null};
    });
  }
  function buildTable(rows, hasGroups, warmLabel, coldLabel) {
    var html = '<table style=\"border-collapse:collapse;font:13px Arial,sans-serif;\">';
    if (hasGroups) {
      html += '<tr><th style=\"border:none;\"></th>';
      var i = 0;
      while (i < rows.length) {
        var g = OUTCOME_GROUPS[rows[i].key], span = 0;
        while (i + span < rows.length && OUTCOME_GROUPS[rows[i + span].key] === g) span++;
        html += hCell(g, GROUP_COLOURS[g], span, GROUP_TIPS[g]);
        i += span;
      }
      html += '</tr>';
    }
    html += '<tr><th style=\"border:none;\"></th>' +
      rows.map(function(r){ return hCell(r.label, r.colour, null, CAT_TIPS[r.key]); }).join('') + '</tr>';
    html += '<tr>' + bCell(warmLabel, WARM, ARM_TIPS.warm) +
      rows.map(function(r){ return dCell(r.warm_n, r.warm_pct); }).join('') + '</tr>';
    html += '<tr>' + bCell(coldLabel, COLD, ARM_TIPS.cold) +
      rows.map(function(r){ return dCell(r.cold_n, r.cold_pct); }).join('') + '</tr>';
    html += '<tr>' + bCell('Gap (warm - cold)', '#666',
      'Difference in percentage points; positive means the registered group is higher') +
      rows.map(function(r){ return gCell(r.gap); }).join('') + '</tr></table>';
    return html;
  }
  function renderTable(warm, cold, nAll) {
    var wl = 'Warm-Engaged (treatment)<br>n = ' + warm.n + ' (' + pct(warm.n, nAll) + ')' +
      '<br>compliant at arrival: ' + (warm.c_bar === null ? 'n/a' : (100 * warm.c_bar).toFixed(1) + '%');
    var cl = 'Cold-Engaged (counterfactual)<br>n = ' + cold.n + ' (' + pct(cold.n, nAll) + ')' +
      '<br>compliant at arrival: ' + (cold.c_bar === null ? 'n/a' : (100 * cold.c_bar).toFixed(1) + '%');
    pane.innerHTML =
      '<div style=\"font-weight:bold;padding:2px 0 8px;\">Initial emissions status ' +
      '<span style=\"font-weight:normal;color:#777;\">(% of branch, count beneath)</span></div>' +
      buildTable(outcomesTableRows(warm, cold, STATUS_KEYS, STATUS_LABELS, STATUS_COLOURS, 'status_'),
                 false, wl, cl) +
      '<div style=\"font-weight:bold;padding:18px 0 8px;\">Outcome of emissions non-compliant machines ' +
      '<span style=\"font-weight:normal;color:#777;\">(% of branch non-compliant, count beneath)</span></div>' +
      buildTable(outcomesTableRows(warm, cold, OUTCOME_KEYS, OUTCOME_LABELS, OUTCOME_COLOURS, 'outcome_'),
                 true, wl, cl) +
      '<div style=\"color:#888;padding-top:10px;max-width:900px;\">Colour coding: green = demonstrated ' +
      'emissions reduction, amber = uncertain fate, grey = compliant without demonstrated reduction, ' +
      'red = not remediated. Gap row: blue where warm higher, orange where cold higher.</div>';
  }

  // ---------- EF view ----------
  var efGroupMap = {All_Groups: 'All_NRMM', Constant_Speed: 'Constant_Speed',
                    CAZ_Plus: 'CAZ_Plus', Rest_of_London: 'Rest_of_London'};
  var sliderState = {GeneratorH: null, ExcavatorH: null, othersK: 1};
  function strataFor(group, phase) {
    return data.strata.filter(function(s) {
      return s.subgroup === efGroupMap[group] && s.phase === phase;
    });
  }
  function fleetEF(strata, uFn) {
    var num = 0, den = 0;
    strata.forEach(function(s) {
      var w = s.n_type * s.kw_mean * uFn(s);
      num += w * s.ef_type; den += w;
    });
    return den > 0 ? num / den : null;
  }
  function uFromHours(h, lf) { return h * lf / data.ex_base; }
  function currentU(s) {
    if (s.machine_type === 'Generator' && sliderState.GeneratorH !== null)
      return uFromHours(sliderState.GeneratorH, s.load_factor);
    if (s.machine_type === 'Excavator' && sliderState.ExcavatorH !== null)
      return uFromHours(sliderState.ExcavatorH, s.load_factor);
    if (s.machine_type !== 'Generator' && s.machine_type !== 'Excavator')
      return s.u_central * sliderState.othersK;
    return s.u_central;
  }
  function renderEF() {
    var group = grpSel.value, phase = phSel.value;
    var strata = strataFor(group, phase);
    var er = data.ef_results.filter(function(r) {
      return r.subgroup === efGroupMap[group] && r.phase === phase;
    })[0];
    if (!strata.length || !er) { pane.innerHTML = 'No EF cell for this selection.'; return; }
    var efNow = fleetEF(strata, currentU);
    var gen = strata.filter(function(s){ return s.machine_type === 'Generator'; })[0];
    var exc = strata.filter(function(s){ return s.machine_type === 'Excavator'; })[0];
    var html = '<div style=\"font-weight:bold;padding:2px 0 8px;\">Fleet emissions intensity - NOx grams per kWh of engine work (= kg per MWh) - ' +
      group + ', phase ' + phase + '</div>' +
      '<div style=\"font-size:26px;font-weight:bold;\">' + efNow.toFixed(2) +
      ' <span style=\"font-size:13px;font-weight:normal;color:#777;\">at slider settings</span></div>' +
      '<div style=\"color:#555;padding:4px 0 10px;\">Central estimate ' + er.ef_central.toFixed(2) +
      ' | uncertainty range [' + er.ef_env_low.toFixed(2) + ', ' + er.ef_env_high.toFixed(2) + ']' +
      ' (widest the answer can move within the stated hour ranges)' +
      ' | if every machine counted equally: ' + er.ef_count_ref.toFixed(2) +
      ' | if weighted by engine size only: ' + er.ef_kw_ref.toFixed(2) + '</div>';
    function slider(id, label, s, val) {
      if (!s) return '';
      return '<div style=\"padding:2px 0;\">' + label +
        ' <b><span id=\"' + id + 'Val\">' + val.toFixed(1) + '</span> h/day</b>' +
        ' <input type=\"range\" id=\"' + id + '\" min=\"' + s.hours_day_low + '\" max=\"' + s.hours_day_high +
        '\" step=\"0.1\" value=\"' + val + '\" style=\"width:260px;vertical-align:middle;\">' +
        ' <span style=\"color:#888;\">[' + s.hours_day_low + ', ' + s.hours_day_high + '] h/day, LF ' +
        s.load_factor + ', type rate (g/kWh) ' + s.ef_type.toFixed(2) + '</span></div>';
    }
    html += slider('genU', 'Generator', gen, gen ? (sliderState.GeneratorH !== null ? sliderState.GeneratorH : gen.hours_day_central) : 0);
    html += slider('excU', 'Excavator', exc, exc ? (sliderState.ExcavatorH !== null ? sliderState.ExcavatorH : exc.hours_day_central) : 0);
    html += '<div style=\"padding:2px 0;\">All other types, common multiplier x <b><span id=\"othKVal\">' +
      sliderState.othersK.toFixed(2) + '</span></b>' +
      ' <input type=\"range\" id=\"othK\" min=\"0.5\" max=\"1.5\" step=\"0.05\" value=\"' +
      sliderState.othersK + '\" style=\"width:260px;vertical-align:middle;\">' +
      ' <button id=\"resetU\">Reset to central</button></div>' +
      '<div style=\"color:#888;padding:4px 0 12px;max-width:820px;\">Usage = hours/day x load ' +
      'factor, normalised to the excavator (8 h/day x 0.40); only relative usage matters, and ' +
      'the envelope shows the widest the answer can move within the stated hour ranges (24 h ' +
      'physical cap). Slider positions are assumptions, not knowledge. PLACEHOLDER values ' +
      'pending sourced hours-per-day estimates.</div>';
    // Arrival intensity by arm: the proactive channel, independent of the
    // usage sliders because it is an unweighted per-machine mean.
    var arr = data.arrival_ef.filter(function(r) {
      return r.subgroup === efGroupMap[group] && r.phase === phase &&
             r.variant === 'excl_dispensation';
    })[0];
    if (arr) {
      html += '<div style=\"margin:6px 0 14px;padding:8px 10px;background:#f4f6f7;' +
        'border-left:4px solid ' + WARM + ';max-width:820px;\">' +
        '<b>How clean machines are when they arrive</b> (average machine, before any ' +
        'enforcement action; excludes machines already holding a retrofit or exemption)<br>' +
        '<span style=\"color:' + WARM + ';font-weight:bold;\">Registered ' +
        arr.ef_warm.toFixed(2) + ' g/kWh</span> (' + arr.n_warm + ' machines) &nbsp; vs &nbsp;' +
        '<span style=\"color:' + COLD + ';font-weight:bold;\">Unregistered ' +
        arr.ef_cold.toFixed(2) + ' g/kWh</span> (' + arr.n_cold + ' machines) &nbsp;&rarr;&nbsp; ' +
        '<b>registered fleets arrive ' + arr.gap_pct.toFixed(1) + '% cleaner</b>' +
        '<div style=\"color:#888;padding-top:4px;\">This is a per-machine average, so it ' +
        'is unaffected by the usage sliders above, which weight machines by size and hours.</div></div>';
    }
    html += '<table style=\"border-collapse:collapse;font:12px Arial;\">' +
      '<tr>' + ['Machine type','machines audited','average engine kW','type rate g/kWh','hours/day central','hours/day low','hours/day high','load factor'].map(function(h) {
        return '<th style=\"' + CELL + 'background:#455A64;color:white;font-weight:normal;\">' + h + '</th>';
      }).join('') + '</tr>' +
      strata.map(function(s) {
        return '<tr><td style=\"' + CELL + 'text-align:left;\">' + s.machine_type + '</td>' +
          [s.n_type, s.kw_mean.toFixed(0), s.ef_type.toFixed(2), s.hours_day_central,
           s.hours_day_low, s.hours_day_high, s.load_factor]
            .map(function(v){ return '<td style=\"' + CELL + '\">' + v + '</td>'; }).join('') + '</tr>';
      }).join('') + '</table>';
    pane.innerHTML = html;
    function wire(id, setter) {
      var elx = document.getElementById(id);
      if (!elx) return;
      elx.oninput = function() {
        setter(parseFloat(elx.value));
        var span = document.getElementById(id + 'Val');
        var efEl = fleetEF(strata, currentU);
        span.textContent = parseFloat(elx.value).toFixed(2);
        pane.querySelector('div[style*=\"font-size:26px\"]').childNodes[0].textContent = efEl.toFixed(2) + ' ';
      };
    }
    wire('genU', function(v){ sliderState.GeneratorH = v; });
    wire('excU', function(v){ sliderState.ExcavatorH = v; });
    wire('othK', function(v){ sliderState.othersK = v; });
    var rb = document.getElementById('resetU');
    if (rb) rb.onclick = function() {
      sliderState = {GeneratorH: null, ExcavatorH: null, othersK: 1};
      renderEF();
    };
  }

  // ---------- trends & projections ----------
  var pbarK = 1;
  function thresholdFor(group, year) {
    var row = data.thresholds.filter(function(t) {
      return t.subgroup === group && t.year === year;
    })[0];
    return row ? row.thr : null;
  }
  // Client-side copy of the R model's constrained transition matrix. Each
  // year, machines below the market-top stage (index 6 = Stage V) move there
  // with probability p; everything else stays put. Kept in JS only so the
  // slider can explore scenarios interactively; parityCheck() below proves it
  // reproduces the R results exactly at the fitted rate, so the two
  // implementations cannot silently diverge.
  function project(group, arm, p) {
    var init = data.proj_init.filter(function(r) {
      return r.subgroup === group && r.arm === arm;
    });
    if (!init.length) return [];
    var pi = [0, 0, 0, 0, 0, 0, 0, 0];   // index 1..7
    init.forEach(function(r){ pi[r.initial_stage] = r.pi; });
    var out = [];
    for (var yr = 2025; yr <= 2030; yr++) {
      var moved = 0;
      for (var s = 1; s < 6; s++) { moved += pi[s] * p; pi[s] *= (1 - p); }
      pi[6] += moved;
      var thr = thresholdFor(group, yr), cbar = 0, ms = 0;
      for (var s2 = 1; s2 <= 7; s2++) { if (s2 >= thr) cbar += pi[s2]; ms += s2 * pi[s2]; }
      out.push({year: yr, c_bar: cbar, mean_stage: ms, pi: pi.slice()});
    }
    return out;
  }
  // Self-check run once on load: re-derive every central projection in the
  // browser and compare with the values R computed. Any mismatch means the
  // two implementations disagree, which invalidates every projection shown,
  // so it is surfaced as a badge rather than logged silently.
  function parityCheck() {
    var ok = true, checked = 0;
    data.pbar_default.forEach(function(pd) {
      var js = project(pd.subgroup, pd.arm, pd.p_fit);
      data.projections.filter(function(r) {
        return r.subgroup === pd.subgroup && r.arm === pd.arm && r.scenario === 'central';
      }).forEach(function(r) {
        var jrow = js.filter(function(j){ return j.year === r.year; })[0];
        if (!jrow || Math.abs(jrow.c_bar - r.c_bar_proj) > 1e-9) ok = false;
        checked++;
      });
    });
    var pe = document.getElementById('parity');
    pe.textContent = ok ? 'checks \\u2713' : 'CHECKS FAILED';
    pe.title = ok ? 'Internal check passed: the dashboard recalculated the projections in the browser and matched the R model exactly'
                  : 'The browser calculations do not match the R model; do not trust the projections shown';
    pe.style.color = ok ? '#2E7D32' : '#C62828';
    if (!ok) console.error('JS projection recursion does not match R central projections');
    return ok;
  }
  function renderTrend() {
    var group = grpSel.value;
    if (group === 'All_Groups') group = 'Rest_of_London';
    var W = Math.max(pane.clientWidth - 40, 700), H = 430;
    var L = 55, R = 20, T = 24, B = 34;
    var x0 = 2015.5, x1 = 2030.5;
    function X(yr) { return L + (yr - x0) / (x1 - x0) * (W - L - R); }
    function Y(v) { return T + (1 - v) * (H - T - B); }
    var svg = ['<svg width=\"' + W + '\" height=\"' + H + '\" font-family=\"Arial\" font-size=\"11\">'];
    for (var gy = 0; gy <= 1.0001; gy += 0.2) {
      svg.push('<line x1=\"' + L + '\" y1=\"' + Y(gy) + '\" x2=\"' + (W - R) + '\" y2=\"' + Y(gy) +
        '\" stroke=\"#eee\"/><text x=\"' + (L - 8) + '\" y=\"' + (Y(gy) + 4) +
        '\" text-anchor=\"end\" fill=\"#888\">' + (100 * gy).toFixed(0) + '%</text>');
    }
    for (var yr = 2016; yr <= 2030; yr += 2) {
      svg.push('<text x=\"' + X(yr) + '\" y=\"' + (H - B + 16) +
        '\" text-anchor=\"middle\" fill=\"#888\">' + yr + '</text>');
    }
    // era break and threshold steps
    [[2020.667, 'era break (Sep 2020)'], [2025, 'phase C thresholds'], [2030, '2030 step (all V)']]
      .forEach(function(m) {
        svg.push('<line x1=\"' + X(m[0]) + '\" y1=\"' + T + '\" x2=\"' + X(m[0]) + '\" y2=\"' +
          (H - B) + '\" stroke=\"#bbb\" stroke-dasharray=\"4,3\"/>' +
          '<text x=\"' + (X(m[0]) + 4) + '\" y=\"' + (T + 10) + '\" fill=\"#999\">' + m[1] + '</text>');
      });
    function polyline(pts, colour, dash, width) {
      if (pts.length < 2) return '';
      return '<polyline fill=\"none\" stroke=\"' + colour + '\" stroke-width=\"' + (width || 2) +
        '\"' + (dash ? ' stroke-dasharray=\"' + dash + '\"' : '') + ' points=\"' +
        pts.map(function(p){ return X(p[0]) + ',' + Y(p[1]); }).join(' ') + '\"/>';
    }
    ['cold_CF', 'warm_AT'].forEach(function(arm) {
      var colour = arm === 'cold_CF' ? COLD : WARM;
      var obs = data.trend.filter(function(r){ return r.subgroup === group && r.arm === arm; })
        .sort(function(a, b){ return a.year - b.year; });
      svg.push(polyline(obs.map(function(r){ return [r.year, r.c_bar_obs]; }), colour));
      obs.forEach(function(r) {
        svg.push('<circle cx=\"' + X(r.year) + '\" cy=\"' + Y(r.c_bar_obs) + '\" r=\"' +
          (r.n >= 20 ? 4 : 2.5) + '\" fill=\"' + (r.n >= 20 ? colour : 'white') +
          '\" stroke=\"' + colour + '\"><title>' + arm + ' ' + r.year + ': ' +
          (100 * r.c_bar_obs).toFixed(1) + '% (n=' + r.n + ')</title></circle>');
      });
      // CI band from precomputed scenarios
      var lo = data.projections.filter(function(r) {
        return r.subgroup === group && r.arm === arm && r.scenario === 'ci_low';
      }).sort(function(a, b){ return a.year - b.year; });
      var hi = data.projections.filter(function(r) {
        return r.subgroup === group && r.arm === arm && r.scenario === 'ci_high';
      }).sort(function(a, b){ return a.year - b.year; });
      if (lo.length && hi.length) {
        var band = lo.map(function(r){ return X(r.year) + ',' + Y(r.c_bar_proj); })
          .concat(hi.slice().reverse().map(function(r){ return X(r.year) + ',' + Y(r.c_bar_proj); }));
        svg.push('<polygon points=\"' + band.join(' ') + '\" fill=\"' + colour +
          '\" opacity=\"0.12\"/>');
      }
      // slider-driven projection line
      var pd = data.pbar_default.filter(function(r) {
        return r.subgroup === group && r.arm === arm;
      })[0];
      if (pd) {
        var proj = project(group, arm, Math.min(Math.max(pd.p_fit * pbarK, 0), 1));
        svg.push(polyline(proj.map(function(r){ return [r.year, r.c_bar]; }), colour, '6,4', 2.5));
      }
    });
    svg.push('<circle cx=\"' + (L + 10) + '\" cy=\"12\" r=\"5\" fill=\"' + WARM + '\"/>' +
      '<text x=\"' + (L + 20) + '\" y=\"16\">Registered fleet (warm) - observed and projected</text>' +
      '<circle cx=\"' + (L + 210) + '\" cy=\"12\" r=\"5\" fill=\"' + COLD + '\"/>' +
      '<text x=\"' + (L + 220) + '\" y=\"16\">Unregistered fleet (cold) - observed and projected</text>');
    svg.push('</svg>');
    var pdw = data.pbar_default.filter(function(r){ return r.subgroup === group; });
    var badge = group === 'Constant_Speed' ?
      '<span style=\"background:#B45309;color:white;padding:2px 8px;border-radius:3px;\">' +
      'Note: too few unregistered constant-speed machines to measure separately, so both groups share one replacement-rate estimate</span> ' : '';
    pane.innerHTML =
      '<div style=\"font-weight:bold;padding:2px 0 6px;\">Share of machines meeting the required standard - observed and projected - ' +
      group + ' ' + badge + '</div>' + svg.join('') +
      '<div style=\"padding:8px 0;\">Replacement-rate scenario: x <b><span id=\"pkVal\">' +
      pbarK.toFixed(2) + '</span></b> <input type=\"range\" id=\"pkSlider\" min=\"0\" max=\"2\" ' +
      'step=\"0.05\" value=\"' + pbarK + '\" style=\"width:300px;vertical-align:middle;\"> ' +
      '<span style=\"color:#888;\">estimated share of older machines replaced each year: ' +
      pdw.map(function(r){ return (r.arm === 'warm_AT' ? 'registered ' : 'unregistered ') + (100 * r.p_fit).toFixed(1) + '%'; }).join(', ') +
      ' | shaded band: statistical uncertainty (95%) | dashed line: what happens at the slider setting</span></div>' +
      '<div style=\"color:#888;max-width:900px;\">Solid lines with dots: the observed share of audited machines meeting ' +
      'the standard each year (hollow dots: fewer than 20 machines audited, so less reliable). Projections 2025-2030 start ' +
      'from the 2023-24 fleet mix and assume a fixed share of older machines is replaced by the newest stage each year; ' +
      'after 2024 there are almost no audits (63), so those years are model projection, not measurement. The required ' +
      'standard steps up in 2025 and 2030, which is why projected compliance can dip at those dates.</div>';
    var sl = document.getElementById('pkSlider');
    sl.oninput = function() {
      pbarK = parseFloat(sl.value);
      renderTrend();
    };
  }

  // ---------- stage populations ----------
  var STAGE_COLOURS = {1:'#7f0000', 2:'#c62828', 3:'#e65100', 4:'#f9a825',
                       5:'#9e9d24', 6:'#2E7D32', 7:'#00695C'};
  var STAGE_NAMES = {1:'I', 2:'II', 3:'IIIA', 4:'IIIB', 5:'IV', 6:'V', 7:'ZE'};
  function stagePanel(group, arm) {
    var W = Math.max(pane.clientWidth - 40, 700), H = 220;
    var L = 48, R = 20, T = 22, B = 24;
    var years = [];
    for (var y = 2016; y <= 2030; y++) years.push(y);
    var slotW = (W - L - R) / years.length, barW = slotW * 0.72;
    var colour = arm === 'cold_CF' ? COLD : WARM;
    var svg = ['<svg width=\"' + W + '\" height=\"' + H + '\" font-family=\"Arial\" font-size=\"10\">'];
    svg.push('<text x=\"4\" y=\"14\" font-size=\"12\" font-weight=\"bold\" fill=\"' + colour + '\">' +
      (arm === 'warm_AT' ? 'Registered fleet (warm)' : 'Unregistered fleet (cold)') + '</text>');
    for (var gy = 0; gy <= 1.0001; gy += 0.25) {
      var yy = T + (1 - gy) * (H - T - B);
      svg.push('<line x1=\"' + L + '\" y1=\"' + yy + '\" x2=\"' + (W - R) + '\" y2=\"' + yy +
        '\" stroke=\"#eee\"/><text x=\"' + (L - 6) + '\" y=\"' + (yy + 3) +
        '\" text-anchor=\"end\" fill=\"#888\">' + (100 * gy).toFixed(0) + '%</text>');
    }
    // projected shares at slider setting
    var pd = data.pbar_default.filter(function(r) {
      return r.subgroup === group && r.arm === arm;
    })[0];
    var proj = pd ? project(group, arm, Math.min(Math.max(pd.p_fit * pbarK, 0), 1)) : [];
    years.forEach(function(yr, yi) {
      var xc = L + slotW * yi + (slotW - barW) / 2;
      var shares = null, total = 0, projected = false;
      if (yr <= 2024) {
        var rows = data.stage_pop.filter(function(r) {
          return r.subgroup === group && r.arm === arm && r.year === yr;
        });
        if (rows.length) {
          shares = [0, 0, 0, 0, 0, 0, 0, 0];
          rows.forEach(function(r){ shares[r.stage] = r.n; total += r.n; });
          for (var st = 1; st <= 7; st++) shares[st] /= total;
        }
      } else {
        var prow = proj.filter(function(r){ return r.year === yr; })[0];
        if (prow) { shares = prow.pi; projected = true; }
      }
      if (!shares) return;
      var yCursor = H - B;
      for (var st2 = 1; st2 <= 7; st2++) {
        if (shares[st2] <= 0) continue;
        var hgt = shares[st2] * (H - T - B);
        yCursor -= hgt;
        svg.push('<rect x=\"' + xc + '\" y=\"' + yCursor + '\" width=\"' + barW +
          '\" height=\"' + hgt + '\" fill=\"' + STAGE_COLOURS[st2] + '\" opacity=\"' +
          (projected ? 0.5 : 1) + '\"' + (projected ? ' stroke=\"' + STAGE_COLOURS[st2] +
          '\" stroke-dasharray=\"3,2\"' : '') + '><title>' + yr + ' ' + arm + ' Stage ' +
          STAGE_NAMES[st2] + ': ' + (100 * shares[st2]).toFixed(1) + '%' +
          (projected ? ' (projected)' : ' (n=' + total + ')') + '</title></rect>');
      }
      if (yr % 2 === 0) {
        svg.push('<text x=\"' + (xc + barW / 2) + '\" y=\"' + (H - B + 14) +
          '\" text-anchor=\"middle\" fill=\"#888\">' + yr + '</text>');
      }
    });
    svg.push('</svg>');
    return svg.join('');
  }
  function renderStagePop() {
    var group = grpSel.value;
    if (group === 'All_Groups') group = 'Rest_of_London';
    var legend = '<div style=\"padding:4px 0;\">' +
      [1, 2, 3, 4, 5, 6, 7].map(function(st) {
        return '<span style=\"display:inline-block;width:12px;height:12px;background:' +
          STAGE_COLOURS[st] + ';margin:0 4px 0 12px;\"></span>Stage ' + STAGE_NAMES[st];
      }).join('') + '</div>';
    var pdw = data.pbar_default.filter(function(r){ return r.subgroup === group; });
    var badge = group === 'Constant_Speed' ?
      ' <span style=\"background:#B45309;color:white;padding:2px 8px;border-radius:3px;\">' +
      'combined replacement-rate estimate: too few unregistered machines to measure separately</span>' : '';
    pane.innerHTML =
      '<div style=\"font-weight:bold;padding:2px 0 6px;\">Stage populations (shares) - ' + group +
      badge + ' <span style=\"font-weight:normal;color:#777;\">observed 2016-2024 solid, ' +
      'projected 2025-2030 faded (at the replacement-rate slider below)</span></div>' +
      legend + stagePanel(group, 'warm_AT') + stagePanel(group, 'cold_CF') +
      '<div style=\"padding:8px 0;\">Replacement-rate scenario: x <b><span id=\"pk2Val\">' +
      pbarK.toFixed(2) + '</span></b> <input type=\"range\" id=\"pk2Slider\" min=\"0\" max=\"2\" ' +
      'step=\"0.05\" value=\"' + pbarK + '\" style=\"width:300px;vertical-align:middle;\"> ' +
      '<span style=\"color:#888;\">estimated share of older machines replaced each year: ' +
      pdw.map(function(r){ return (r.arm === 'warm_AT' ? 'registered ' : 'unregistered ') + (100 * r.p_fit).toFixed(1) + '%'; }).join(', ') + '</span></div>' +
      '<div style=\"color:#888;max-width:900px;\">Shares within each year cell; audits support ' +
      'shares only, absolute machine populations require the NRMM registration database ' +
      'multiplier. Projected bars evolve the pooled 2023-24 distribution under the constrained ' +
      'one-parameter chain; hover any bar segment for values.</div>';
    var sl = document.getElementById('pk2Slider');
    sl.oninput = function() { pbarK = parseFloat(sl.value); renderStagePop(); };
  }

  // ---------- glossary ----------
  var GLOSSARY = [
    ['Stage (I, II, IIIA, IIIB, IV, V, ZE)', 'The European emissions standard the engine was built to. Stage I is the oldest and dirtiest; V is the newest diesel standard; ZE means zero-emission. The Low Emission Zone works by requiring newer stages over time.'],
    ['Machine Group', 'Which rule-set a machine falls under: Constant Speed (mainly generators), CAZ+ (central zone and opportunity areas), or Rest of London. Each has its own required stage per period.'],
    ['Registered / warm-engaged', ARM_TIPS.warm],
    ['Unregistered / cold-engaged', ARM_TIPS.cold],
    ['Compliance rate (c-bar)', 'The share of machines that met the required standard when first seen, counting approved retrofits and exemptions as compliant. This is legal compliance, not an emissions measurement: an exemption changes no emissions.'],
    ['Replacement rate (p-bar)', 'The estimated share of below-standard machines replaced with new ones each year, worked out from how fast the fleet mix improves between years. The scenario sliders scale this rate up or down.'],
    ['Era 1 / era 2', 'The two periods used to estimate replacement rates, split at 1 September 2020 when requirements stepped up. Replacement roughly doubled at that point.'],
    ['Phases A1, A2, B, C', 'The policy periods of the zone: A1 to the end of 2018, A2 to August 2020, B to the end of 2024, C from 2025. They set which stage is required where and when.'],
    ['Emissions intensity (EF)', 'Grams of NOx emitted per kWh of engine work, averaged over the fleet using each stage&#39;s legal limit as the practical value. The same number expressed as kg per MWh.'],
    ['Usage (hours/day and load factor)', 'How much each machine type works: hours per day, times how hard it runs relative to full power (the load factor). Only the differences between types matter for the fleet average, not the absolute level.'],
    ['Uncertainty range (envelope)', 'The widest the fleet emissions intensity can move if the usage assumptions are pushed to the edges of their plausible ranges. If a conclusion holds across the whole range, it does not depend on the assumptions.'],
    ['Dispensation / retrofit / exemption', 'Approvals that make a machine legally compliant without a newer engine: a retrofit is exhaust clean-up equipment (a real change); an exemption is permission to continue (no emissions change).'],
    ['E code and admin codes', 'Officer reason codes on an audit: E means the emissions standard was not met; other letters (A, C, P, R, X) are administrative issues such as registration paperwork. The dashboard keeps administrative problems separate from emissions problems.'],
    ['TAN', 'The machine&#39;s registration serial number, recorded for about half of machines. It lets the same machine be recognised across audits, which is how removed machines are traced.'],
    ['checks &#10003;', 'The dashboard recalculates the projections in the browser and compares them with the R model&#39;s results; the tick means they match exactly.'],
    ['Shares vs populations', 'The audits reveal the percentage mix of the fleet. Absolute machine counts require the total fleet size from the NRMM registration database, which is not yet wired in.']
  ];
  function renderGlossary() {
    pane.innerHTML =
      '<div style=\"font-weight:bold;padding:2px 0 8px;\">Glossary</div>' +
      '<table style=\"border-collapse:collapse;font:13px Arial,sans-serif;max-width:1000px;\">' +
      GLOSSARY.map(function(g) {
        return '<tr><td style=\"' + CELL + 'text-align:left;font-weight:bold;white-space:nowrap;' +
          'vertical-align:top;\">' + g[0] + '</td><td style=\"' + CELL + 'text-align:left;\">' +
          g[1] + '</td></tr>';
      }).join('') + '</table>' +
      '<div style=\"color:#888;padding-top:8px;\">Most coloured table headers and badges also explain themselves when you hover over them.</div>';
  }

  // ---------- data queries (open questions for the audit team) ----------
  function renderQueries() {
    var TB = 'border:1px solid #ccc;padding:5px 9px;text-align:center;';
    function tbl(rows, cols, hdrs) {
      return '<table style=\"border-collapse:collapse;font:12.5px Arial;margin:6px 0 14px;\">' +
        '<tr>' + hdrs.map(function(h){ return '<th style=\"' + TB +
          'background:#455A64;color:white;font-weight:normal;\">' + h + '</th>'; }).join('') + '</tr>' +
        rows.map(function(r){ return '<tr>' + cols.map(function(c){
          var v = r[c]; if (v === null || v === undefined) v = '-';
          return '<td style=\"' + TB + '\">' + v + '</td>'; }).join('') + '</tr>'; }).join('') +
        '</table>';
    }
    var st = data.sens_trend.filter(function(r){ return r.year >= 2020; });
    var html =
      '<div style=\"max-width:1000px;\">' +
      '<div style=\"font-weight:bold;font-size:15px;padding:2px 0 8px;\">Open questions on the audit data</div>' +
      '<p>These are things in the recorded data I can\\'t interpret on my own. Nothing here is a ' +
      'criticism of the recording; in most cases I expect there is a practice or piece of guidance ' +
      'I simply don\\'t know about. The full list is in the accompanying note.</p>' +

      '<div style=\"font-weight:bold;padding:10px 0 4px;\">1. Engine Type on generators ' +
      '<span style=\"font-weight:normal;color:#B45309;\">(affects the Constant Speed group)</span></div>' +
      '<p>All 218 generators recorded at Stage V carry Engine Type \"Variable\"; none carries \"Constant\". ' +
      'Stage IIIA generators audited in the same years are 80% \"Constant\". Because the Constant Speed ' +
      'group is defined by that field, generators leave the group at the moment they upgrade, so the ' +
      'group cannot show improvement. Below is the same group read both ways.</p>' +
      tbl(st, ['year','mode','n','mean_stage','pct_stage_v_plus'],
          ['Year','Reading of Engine Type','Machines','Average stage','% at Stage V or better']) +
      '<p style=\"color:#666;\">I don\\'t assume the second reading is right: hybrid, flywheel and ' +
      'flybrid units in your data split 37 \"Constant\" to 51 \"Variable\", which looks deliberate. ' +
      'That\\'s exactly why I\\'d like your view.</p>' +

      '<div style=\"font-weight:bold;padding:10px 0 4px;\">2. What the checks flagged automatically</div>' +
      tbl(data.flags, ['check','detail'], ['Check','What it found']) +

      '<div style=\"font-weight:bold;padding:10px 0 4px;\">3. Machines removed from site, by year</div>' +
      '<p>I use the TAN to see whether a machine removed from one site turns up at another. Usable ' +
      'TANs only appear from 2021, and a machine removed recently has had less time to reappear, so ' +
      'the later percentages are understated rather than genuinely lower.</p>' +
      tbl(data.removal_year, ['year','removals','traceable','displaced','displaced_pct','observation_window_yrs'],
          ['Year','Removals','Traceable','Seen again','% seen again','Years of follow-up']) +

      '<div style=\"font-weight:bold;padding:10px 0 4px;\">4. Also on the list</div>' +
      '<ul>' +
      '<li><b>Crushers:</b> 15 records are \"Constant\", all at Stage IIIA; all 76 at IIIB, IV and V are \"Variable\".</li>' +
      '<li><b>\"Electric\" in the stage field</b> (31 records, growing from 1 in 2022 to 15 in 2025): should this read as zero-emission?</li>' +
      '<li><b>\"Uncertified\" as a stage</b> (25 records): no approval at all, or approval not confirmed on the day?</li>' +
      '<li><b>\"Pending\" as a final outcome</b> (23 records, 2018-2020): still open at extract, or something more specific?</li>' +
      '<li><b>Same machine, different stage</b> across visits: 30 machines, two of them differing by four stages.</li>' +
      '<li><b>\"Inappropriate for Audit\"</b> (131 records): treat as out of scope, like \"No NRMM\"?</li>' +
      '</ul>' +

      '<div style=\"font-weight:bold;padding:10px 0 4px;\">5. What I\\'ve already handled</div>' +
      '<p>Where a visit logged a site-level status (baselining, site complete, no apparent works, ' +
      'declined audit) against a machine, I now keep the machine\\'s stage but don\\'t count it as a ' +
      'compliance judgement, since none was made. That affects 60 records, 34 of them in 2025.</p>' +
      '</div>';
    pane.innerHTML = html;
  }

  // ---------- summary strip + dispatch ----------
  function updateSummary(warm, cold, nAll) {
    var conf = ['a','b','c'].reduce(function(acc, k) {
      return acc + warm['outcome_' + k] + cold['outcome_' + k];
    }, 0);
    var gap = (warm.c_bar !== null && cold.c_bar !== null) ?
      '+' + (100 * (warm.c_bar - cold.c_bar)).toFixed(1) + ' pp' : 'n/a';
    document.getElementById('summary').innerHTML =
      'N = ' + nAll + ' machine audits &nbsp;|&nbsp; Confirmed emissions reductions (replaced, upgraded or retrofitted): ' + conf +
      ' &nbsp;|&nbsp; <span style=\"cursor:help;\" title=\"Registered fleets arrive cleaner than unregistered ones; this gap is the policy effect visible before any enforcement action\">' +
      'Compliance gap at arrival (registered minus unregistered): ' + gap + '</span>';
  }
  function redraw() {
    var view = viewSel.value;
    document.getElementById('yrWrap').style.display =
      (view === 'tree' || view === 'table') ? '' : 'none';
    document.getElementById('phWrap').style.display = (view === 'ef') ? '' : 'none';
    var rows = cellsFor(grpSel.value, yrSel.value);
    var warm = armSummary(rows, 'warm_AT'), cold = armSummary(rows, 'cold_CF');
    var nAll = warm.n + cold.n;
    if (view === 'tree' || view === 'table') updateSummary(warm, cold, nAll);
    if (view === 'ef') {
      var er = data.ef_results.filter(function(r) {
        return r.subgroup === efGroupMap[grpSel.value] && r.phase === phSel.value;
      })[0];
      document.getElementById('summary').innerHTML = er ?
        'Fleet emissions intensity: ' + er.ef_central.toFixed(2) + ' g NOx per kWh of work; uncertainty range [' +
        er.ef_env_low.toFixed(2) + ', ' + er.ef_env_high.toFixed(2) + '] from the usage assumptions (placeholders)' : '';
    }
    if (view === 'trend') {
      document.getElementById('summary').innerHTML =
        'How compliance has evolved and where the replacement model projects it, with the statistical uncertainty band.';
    }
    if (view === 'stagepop') {
      document.getElementById('summary').innerHTML =
        'The mix of engine stages in the audited fleet, year by year, and how it is projected to evolve; ' +
        'absolute machine counts need fleet totals from the registration database.';
    }
    if (view === 'gloss') {
      document.getElementById('summary').innerHTML = 'Plain-English guide to the terms used across the views.';
    }
    if (view === 'queries') {
      document.getElementById('summary').innerHTML =
        'Things in the recorded data I would like to check with the audit team before finalising.';
    }
    if (view === 'tree') {
      pane.style.display = 'none'; el.style.display = 'block';
      renderTree(warm, cold, nAll, grpSel.value.replace(/_/g, ' ') + ' - ' + yrSel.value);
    } else {
      el.style.display = 'none'; pane.style.display = 'block';
      if (view === 'table') renderTable(warm, cold, nAll);
      if (view === 'ef') renderEF();
      if (view === 'trend') renderTrend();
      if (view === 'stagepop') renderStagePop();
      if (view === 'gloss') renderGlossary();
      if (view === 'queries') renderQueries();
    }
  }

  function populateControls() {
    grpSel.innerHTML = GROUPS.map(function(g) {
      return '<option value=\"' + g + '\">' + g + '</option>';
    }).join('');
    var years = [];
    data.cells.forEach(function(c){ if (years.indexOf(c.year) < 0) years.push(c.year); });
    years.sort();
    yrSel.innerHTML = '<option>All Years</option>' + years.map(function(y) {
      return '<option>' + y + '</option>';
    }).join('');
    var phases = [];
    data.ef_results.forEach(function(r){ if (phases.indexOf(r.phase) < 0) phases.push(r.phase); });
    phases.sort();
    phSel.innerHTML = phases.map(function(p){ return '<option>' + p + '</option>'; }).join('');
    if (phases.indexOf('B') >= 0) phSel.value = 'B';
  }

  viewSel.onchange = redraw;
  grpSel.onchange = redraw;
  yrSel.onchange = redraw;
  phSel.onchange = redraw;

  populateControls();
  parityCheck();
  redraw();
}"

graph <- htmlwidgets::onRender(graph, js_code, data = payload)

htmlwidgets::saveWidget(graph, OUTPUT_FILE, selfcontained = TRUE,
                        title = "NRMM dashboard v5 (provisional - classification query open)")
cat("Saved:", normalizePath(OUTPUT_FILE), "\n")
