#!/usr/bin/env Rscript

# nrmm_dashboard_v1 — unified dashboard over nrmm_model_v2.rds.
#
# Consumes the model object ONLY (no re-derivation from audits.txt): the
# classification, EF strata, p-bar fits and projections are computed once in
# nrmm_model_v2.R and rendered here. Standalone self-contained HTML with
# client-side switching (v5 dashboard architecture, viewport fill fix).
#
# Views:
#   Outcomes tree / Outcomes table — the v5 taxonomy views, driven from
#     year-keyed outcome cells; Group and Year margins are client-side sums.
#   EF — type-stratified convex combination with usage-index sliders for
#     Generator and Excavator (the two OAT-dominant types) and a grouped
#     control for all other types; adversarial envelope always displayed.
#   Trends & projections — observed yearly c-bar (or mean stage) per arm with
#     era break and threshold steps, projection fan 2025-2030, and a p-bar
#     multiplier slider re-running the one-parameter recursion in JS.
#
# Parity check: at multiplier 1 the JS recursion must reproduce the R central
# projections; asserted on load, badge shown in the control bar.

library(dplyr)
library(tidyr)
library(visNetwork)
library(htmlwidgets)
library(htmltools)

CONTROL_BAR_HEIGHT_PX <- 118
MODEL_PATH  <- "intermediate_data/nrmm_model_v2.rds"
OUTPUT_FILE <- "nrmm_dashboard_v1.html"

# --- Load and check the model object ---

cat("Loading model object...\n")
model <- readRDS(MODEL_PATH)
if (is.null(model$schema_version) || model$schema_version != 2L) {
  stop("Model object schema_version != 2; rebuild with nrmm_model_v2.R")
}

# --- Payload verification (halt on inconsistency) ---

cells <- model$outcomes_cells
status_cols  <- paste0("status_", c("A", "B", "C", "D", "E"))
outcome_cols <- paste0("outcome_", letters[1:9])
stopifnot(all(c("subgroup", "year", "arm", "n", status_cols, outcome_cols)
              %in% names(cells)))
stopifnot(all(rowSums(cells[status_cols]) == cells$n))
stopifnot(all(rowSums(cells[outcome_cols]) == cells$status_C))
stopifnot(all(model$ef_results$ef_env_low  <= model$ef_results$ef_central + 1e-9),
          all(model$ef_results$ef_env_high >= model$ef_results$ef_central - 1e-9))

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
  pbar_table   = df_to_rowlist(model$pbar %>% mutate(across(where(is.numeric), ~ round(.x, 4))))
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
  visExport(type = "pdf", name = "nrmm_dashboard_v1", label = "Export as PDF")

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
  var STATUS_KEYS = ['A','B','C','D','E'];
  var STATUS_LABELS = {A:'Stage-Compliant at Start', B:'Dispensation Held at Start',
    C:'Emissions Non-Compliant at Start', D:'Admin Issue Only (no E code)', E:'Unresolvable'};
  var STATUS_COLOURS = {A:'#2E7D32', B:'#00695C', C:'#37474F', D:'#546E7A', E:'#424242'};
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
      '<option value=\"trend\">Trends &amp; projections</option>' +
    '</select>' +
    ' &nbsp; Group: <select id=\"grpSel\"></select>' +
    ' <span id=\"yrWrap\"> &nbsp; Year: <select id=\"yrSel\"></select></span>' +
    ' <span id=\"phWrap\" style=\"display:none;\"> &nbsp; Phase: <select id=\"phSel\"></select></span>' +
    ' &nbsp; <span id=\"parity\" style=\"font-weight:bold;\"></span>' +
    '<div id=\"summary\" style=\"color:#555;\"></div>';
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
      '\\nc-bar ' + (b.c_bar === null ? 'n/a' : (100 * b.c_bar).toFixed(1) + '%');
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
  function hCell(label, colour, colspan) {
    return '<th ' + (colspan ? 'colspan=\"' + colspan + '\" ' : '') + 'style=\"' + CELL +
      'background:' + colour + ';color:white;font-size:12px;font-weight:normal;max-width:110px;\">' +
      label + '</th>';
  }
  function bCell(label, colour) {
    return '<th style=\"' + CELL + 'background:' + colour + ';color:white;text-align:left;' +
      'font-weight:normal;min-width:170px;\">' + label + '</th>';
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
        html += hCell(g, GROUP_COLOURS[g], span);
        i += span;
      }
      html += '</tr>';
    }
    html += '<tr><th style=\"border:none;\"></th>' +
      rows.map(function(r){ return hCell(r.label, r.colour); }).join('') + '</tr>';
    html += '<tr>' + bCell(warmLabel, WARM) +
      rows.map(function(r){ return dCell(r.warm_n, r.warm_pct); }).join('') + '</tr>';
    html += '<tr>' + bCell(coldLabel, COLD) +
      rows.map(function(r){ return dCell(r.cold_n, r.cold_pct); }).join('') + '</tr>';
    html += '<tr>' + bCell('Gap (warm - cold)', '#666') +
      rows.map(function(r){ return gCell(r.gap); }).join('') + '</tr></table>';
    return html;
  }
  function renderTable(warm, cold, nAll) {
    var wl = 'Warm-Engaged (treatment)<br>n = ' + warm.n + ' (' + pct(warm.n, nAll) + ')' +
      '<br>c-bar ' + (warm.c_bar === null ? 'n/a' : (100 * warm.c_bar).toFixed(1) + '%');
    var cl = 'Cold-Engaged (counterfactual)<br>n = ' + cold.n + ' (' + pct(cold.n, nAll) + ')' +
      '<br>c-bar ' + (cold.c_bar === null ? 'n/a' : (100 * cold.c_bar).toFixed(1) + '%');
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
  var sliderState = {Generator: null, Excavator: null, othersK: 1};
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
  function currentU(s) {
    if (s.machine_type === 'Generator' && sliderState.Generator !== null) return sliderState.Generator;
    if (s.machine_type === 'Excavator' && sliderState.Excavator !== null) return sliderState.Excavator;
    if (s.machine_type !== 'Generator' && s.machine_type !== 'Excavator') return s.u_central * sliderState.othersK;
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
    var html = '<div style=\"font-weight:bold;padding:2px 0 8px;\">Fleet EF (NOx, g/kWh = kg/MWh) - ' +
      group + ', phase ' + phase + '</div>' +
      '<div style=\"font-size:26px;font-weight:bold;\">' + efNow.toFixed(2) +
      ' <span style=\"font-size:13px;font-weight:normal;color:#777;\">at slider settings</span></div>' +
      '<div style=\"color:#555;padding:4px 0 10px;\">Central ' + er.ef_central.toFixed(2) +
      ' | adversarial envelope [' + er.ef_env_low.toFixed(2) + ', ' + er.ef_env_high.toFixed(2) + ']' +
      ' | count-weighted ref ' + er.ef_count_ref.toFixed(2) +
      ' | kW-weighted ref ' + er.ef_kw_ref.toFixed(2) + '</div>';
    function slider(id, label, s, val) {
      if (!s) return '';
      return '<div style=\"padding:2px 0;\">' + label +
        ' u = <b><span id=\"' + id + 'Val\">' + val.toFixed(2) + '</span></b>' +
        ' <input type=\"range\" id=\"' + id + '\" min=\"' + s.u_low + '\" max=\"' + s.u_high +
        '\" step=\"0.05\" value=\"' + val + '\" style=\"width:260px;vertical-align:middle;\">' +
        ' <span style=\"color:#888;\">[' + s.u_low + ', ' + s.u_high + '] EF_t ' +
        s.ef_type.toFixed(2) + '</span></div>';
    }
    html += slider('genU', 'Generator', gen, gen ? (sliderState.Generator !== null ? sliderState.Generator : gen.u_central) : 0);
    html += slider('excU', 'Excavator', exc, exc ? (sliderState.Excavator !== null ? sliderState.Excavator : exc.u_central) : 0);
    html += '<div style=\"padding:2px 0;\">All other types, common multiplier x <b><span id=\"othKVal\">' +
      sliderState.othersK.toFixed(2) + '</span></b>' +
      ' <input type=\"range\" id=\"othK\" min=\"0.5\" max=\"1.5\" step=\"0.05\" value=\"' +
      sliderState.othersK + '\" style=\"width:260px;vertical-align:middle;\">' +
      ' <button id=\"resetU\">Reset to central</button></div>' +
      '<div style=\"color:#888;padding:4px 0 12px;max-width:820px;\">Usage indices are relative ' +
      '(excavator = 1); only relative usage matters, and the envelope shows the widest the answer ' +
      'can move within the stated ranges. Slider positions are assumptions, not knowledge. ' +
      'PLACEHOLDER values pending sourced hours-per-day estimates.</div>';
    html += '<table style=\"border-collapse:collapse;font:12px Arial;\">' +
      '<tr>' + ['Machine type','n','mean kW','EF_t','u central','u low','u high'].map(function(h) {
        return '<th style=\"' + CELL + 'background:#455A64;color:white;font-weight:normal;\">' + h + '</th>';
      }).join('') + '</tr>' +
      strata.map(function(s) {
        return '<tr><td style=\"' + CELL + 'text-align:left;\">' + s.machine_type + '</td>' +
          [s.n_type, s.kw_mean.toFixed(0), s.ef_type.toFixed(2), s.u_central, s.u_low, s.u_high]
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
    wire('genU', function(v){ sliderState.Generator = v; });
    wire('excU', function(v){ sliderState.Excavator = v; });
    wire('othK', function(v){ sliderState.othersK = v; });
    var rb = document.getElementById('resetU');
    if (rb) rb.onclick = function() {
      sliderState = {Generator: null, Excavator: null, othersK: 1};
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
      out.push({year: yr, c_bar: cbar, mean_stage: ms});
    }
    return out;
  }
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
    pe.textContent = ok ? 'parity \\u2713' : 'PARITY FAILED';
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
      '<text x=\"' + (L + 20) + '\" y=\"16\">warm_AT observed/projected</text>' +
      '<circle cx=\"' + (L + 210) + '\" cy=\"12\" r=\"5\" fill=\"' + COLD + '\"/>' +
      '<text x=\"' + (L + 220) + '\" y=\"16\">cold_CF observed/projected</text>');
    svg.push('</svg>');
    var pdw = data.pbar_default.filter(function(r){ return r.subgroup === group; });
    var badge = group === 'Constant_Speed' ?
      '<span style=\"background:#B45309;color:white;padding:2px 8px;border-radius:3px;\">' +
      'pooled-arm p-bar: cold arm not separately estimable</span> ' : '';
    pane.innerHTML =
      '<div style=\"font-weight:bold;padding:2px 0 6px;\">Observed c-bar and projections - ' +
      group + ' ' + badge + '</div>' + svg.join('') +
      '<div style=\"padding:8px 0;\">p-bar scenario multiplier x <b><span id=\"pkVal\">' +
      pbarK.toFixed(2) + '</span></b> <input type=\"range\" id=\"pkSlider\" min=\"0\" max=\"2\" ' +
      'step=\"0.05\" value=\"' + pbarK + '\" style=\"width:300px;vertical-align:middle;\"> ' +
      '<span style=\"color:#888;\">fitted p-bar: ' +
      pdw.map(function(r){ return r.arm + ' ' + r.p_fit.toFixed(3); }).join(', ') +
      ' | shaded band: 95% CI scenarios | dashed: projection at slider setting</span></div>' +
      '<div style=\"color:#888;max-width:900px;\">Solid lines with dots: observed yearly c-bar ' +
      '(hollow dots n &lt; 20). Projections 2025-2030 start from the pooled 2023-24 stage ' +
      'distribution and apply the constrained one-parameter chain; phase C is projection, not ' +
      'estimation (n = 63). Thresholds applied at mid-year per the schedule.</div>';
    var sl = document.getElementById('pkSlider');
    sl.oninput = function() {
      pbarK = parseFloat(sl.value);
      renderTrend();
    };
  }

  // ---------- summary strip + dispatch ----------
  function updateSummary(warm, cold, nAll) {
    var conf = ['a','b','c'].reduce(function(acc, k) {
      return acc + warm['outcome_' + k] + cold['outcome_' + k];
    }, 0);
    var gap = (warm.c_bar !== null && cold.c_bar !== null) ?
      '+' + (100 * (warm.c_bar - cold.c_bar)).toFixed(1) + ' pp' : 'n/a';
    document.getElementById('summary').innerHTML =
      'N = ' + nAll + ' &nbsp;|&nbsp; Confirmed reductions (replaced/upgraded/retrofit): ' + conf +
      ' &nbsp;|&nbsp; Proactive gap (warm - cold c-bar): ' + gap;
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
        'EF central ' + er.ef_central.toFixed(2) + ' g/kWh, envelope [' +
        er.ef_env_low.toFixed(2) + ', ' + er.ef_env_high.toFixed(2) + '] - placeholder usage indices' : '';
    }
    if (view === 'trend') {
      document.getElementById('summary').innerHTML =
        'Constrained Markov projections; era-2 fitted p-bar; parity-checked against the R model object.';
    }
    if (view === 'tree') {
      pane.style.display = 'none'; el.style.display = 'block';
      renderTree(warm, cold, nAll, grpSel.value.replace(/_/g, ' ') + ' - ' + yrSel.value);
    } else {
      el.style.display = 'none'; pane.style.display = 'block';
      if (view === 'table') renderTable(warm, cold, nAll);
      if (view === 'ef') renderEF();
      if (view === 'trend') renderTrend();
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
                        title = "NRMM unified dashboard v1")
cat("Saved:", normalizePath(OUTPUT_FILE), "\n")
