# 260329_step3_lambda_diagnostics.R
# Diagnostic tests for λ_CF estimation stability
#
# Background
# ----------
# Phase B CAZ_Plus yielded λ_CF = 0.638, approximately 2.5× the estimates for
# Constant_Speed (0.176) and Rest_of_London (0.250). Two hypotheses:
#   H1 (algorithmic): near-zero GLS predictor rows dominate the fit because
#        the CAZ_Plus cold fleet is already concentrated at high stages,
#        leaving little signal in the regression.
#   H2 (boundary contamination): the first year-pair (2021→2022) reflects
#        the compositional shock of the Sep 2020 policy step-change (CAZ_Plus
#        compliance raised to Stage IV), not a genuine steady-state turnover
#        signal — inflating δp in the first pair and biasing λ upward.
#
# Five tests are run in sequence:
#   Test 1  Year-by-year stage proportions — CAZ_Plus cold Phase B
#   Test 2  GLS row inspection — predictor, delta, weight for all Phase B groups
#   Test 3  Pooled variable-speed Phase B (CAZ_Plus + Rest_of_London combined)
#   Test 4  Leave-one-out sensitivity — Phase B CAZ_Plus (drop each year-pair)
#   Test 5  Boundary contamination test — refit with 2022–2024 only
#
# Inputs:  260329_step2_exploratory.RData
# Outputs: 260329_step3_lambda_diagnostics.txt

library(tidyverse)

log_file <- "260329_step3_lambda_diagnostics.txt"
log_con  <- file(log_file, open = "wt")
sink(log_con, split = TRUE)

load("260329_step2_exploratory.RData")

stage_labels <- c("1" = "I", "2" = "II", "3" = "IIIA",
                  "4" = "IIIB", "5" = "IV", "6" = "V")

# ── Helper functions (reproduced from step 2) ─────────────────────────────────
make_gls_data <- function(counts_df, max_stage) {
  years <- sort(unique(counts_df$year))
  bind_rows(lapply(seq_len(length(years) - 1), function(i) {
    t0 <- years[i]; t1 <- years[i + 1]
    get_c <- function(yr) {
      sub <- counts_df[counts_df$year == yr, ]
      x   <- setNames(sub$n, as.character(sub$Initial.Stage))
      raw <- sapply(as.character(seq_len(max_stage)),
                    function(s) if (s %in% names(x)) as.numeric(x[[s]]) else 0)
      list(raw = raw, prop = raw / sum(raw))
    }
    r0 <- get_c(t0); r1 <- get_c(t1)
    p0 <- r0$prop; p1 <- r1$prop; c0 <- r0$raw
    bind_rows(lapply(seq_len(max_stage - 1), function(s) {
      inflow    <- if (s == 1) 0 else
        sum(sapply(seq_len(s - 1), function(j) p0[j] / (max_stage - j)))
      predictor <- inflow - p0[s]
      delta     <- p1[s] - p0[s]
      data.frame(t0 = t0, stage = s, stage_label = stage_labels[as.character(s)],
                 predictor = predictor, delta = delta, weight = pmax(c0[s], 1))
    }))
  }))
}

fit_lambda <- function(gls_data, label = "") {
  # Guard: skip if no rows or all predictors are zero (no signal)
  if (nrow(gls_data) == 0 ||
      sum(abs(gls_data$predictor) * gls_data$weight) < 1e-10) {
    cat(sprintf("  %-55s  SKIPPED (no signal)\n", label))
    return(invisible(NULL))
  }
  fit <- lm(delta ~ 0 + predictor, data = gls_data, weights = weight)
  lam <- coef(fit)[["predictor"]]
  se  <- sqrt(vcov(fit)["predictor", "predictor"])
  ci  <- lam + c(-1.96, 1.96) * se
  cat(sprintf("  %-55s  λ = %6.4f  SE = %6.4f  95%% CI [%7.4f, %7.4f]  n = %d\n",
              label, lam, se, ci[1], ci[2], nrow(gls_data)))
  invisible(list(lambda = lam, se = se, ci = ci))
}

sep  <- paste0(strrep("═", 72), "\n")
dash <- paste0(strrep("─", 72), "\n")

# ═══════════════════════════════════════════════════════════════════════════════
# TEST 1: Phase B CAZ_Plus cold fleet — stage proportions by year
# ═══════════════════════════════════════════════════════════════════════════════
cat(sep)
cat("TEST 1: Phase B CAZ_Plus cold fleet — stage proportions by year\n")
cat(dash)
cat("Purpose: Establish whether the cold-engaged CAZ_Plus fleet shows stable\n")
cat("year-on-year progression (consistent with a steady-state turnover rate)\n")
cat("or erratic swings driven by small sample sizes. In Phase B the CAZ_Plus\n")
cat("LEZ requirement is Stage IV, so the incoming cold fleet should already\n")
cat("be concentrated at IV/V, leaving little signal in lower-stage GLS rows.\n")
cat("Year 2021 is the first full year of Phase B; it is included in the\n")
cat("current λ_CF fit and is tested for boundary contamination in Test 5.\n\n")

cold_caz_B <- df_cold %>%
  filter(Phase == "B", Group == "CAZ_Plus", year >= 2021)

counts_by_year <- cold_caz_B %>%
  count(year, Initial.Stage, Initial.Stage.raw, name = "n") %>%
  group_by(year) %>%
  mutate(total = sum(n), prop = round(n / total, 3)) %>%
  ungroup() %>%
  arrange(year, Initial.Stage)

cat("Raw counts:\n")
print(
  counts_by_year %>%
    select(year, Initial.Stage.raw, n) %>%
    pivot_wider(names_from = Initial.Stage.raw, values_from = n, values_fill = 0L),
  n = 20
)

cat("\nProportions (each row sums to 1.0):\n")
print(
  counts_by_year %>%
    select(year, Initial.Stage.raw, prop, total) %>%
    pivot_wider(names_from = Initial.Stage.raw, values_from = prop, values_fill = 0),
  n = 20
)

cat("\nInterpretation guidance:\n")
cat("  - Look for I, II, IIIA, IIIB proportions near zero in 2021 onward.\n")
cat("    These stages generate near-zero GLS predictors (Test 2 reveals this).\n")
cat("  - Large swings in Stage IV or V proportions between consecutive years\n")
cat("    signal cross-sectional noise, not fleet-level progression.\n")
cat("  - Compare 2021 composition to 2022+: if 2021 is compositionally\n")
cat("    distinct (boundary shock), Test 5 should show a different λ.\n\n")

# ═══════════════════════════════════════════════════════════════════════════════
# TEST 2: GLS row inspection — predictor, delta, weight for all Phase B groups
# ═══════════════════════════════════════════════════════════════════════════════
cat(sep)
cat("TEST 2: GLS row inspection — Phase B, all groups\n")
cat(dash)
cat("Purpose: Expose the raw inputs to the WLS regression for each group.\n")
cat("Each row represents one stage in one year-pair transition.\n\n")
cat("Columns:\n")
cat("  t0          start year of the year-pair\n")
cat("  stage_label emissions stage (I–V)\n")
cat("  predictor   = (weighted inflow from lower stages) − (proportion at s)\n")
cat("                The regression coefficient λ_CF scales this to predict δp.\n")
cat("                Near-zero predictor → row contributes little signal.\n")
cat("                Negative predictor (outflow > inflow) → λ predicts decline.\n")
cat("  delta       observed change in proportion: p_{s,t+1} − p_{s,t}\n")
cat("  weight      absolute count at stage s in year t0 (floor 1);\n")
cat("              low-count rows are down-weighted in the regression.\n\n")
cat("Diagnosis: if CAZ_Plus has many rows with |predictor| < 0.05 and weight = 1,\n")
cat("those rows are near-noise and inflate the standard error.\n")
cat("If δ / predictor ratios vary wildly across rows, the model is a poor fit.\n\n")

for (grp in c("Constant_Speed", "CAZ_Plus", "Rest_of_London")) {
  cat(sprintf("--- %s ---\n", grp))
  d <- lambda_cf$B[[grp]]$data
  d$stage_label    <- stage_labels[as.character(d$stage)]
  d$implied_lambda <- round(d$delta / ifelse(abs(d$predictor) < 1e-6, NA, d$predictor), 3)
  print(
    d %>%
      as_tibble() %>%
      select(t0, stage_label, predictor, delta, weight, implied_lambda) %>%
      mutate(predictor = round(predictor, 4), delta = round(delta, 4)) %>%
      rename(year = t0, stage = stage_label, pred = predictor,
             d.prop = delta, wt = weight, d.prop.per.pred = implied_lambda),
    n = 30
  )
  cat(sprintf("  Rows with |predictor| < 0.05: %d of %d\n",
              sum(abs(d$predictor) < 0.05), nrow(d)))
  cat(sprintf("  Rows with weight = 1 (zero count, floored): %d of %d\n\n",
              sum(d$weight == 1), nrow(d)))
}

# ═══════════════════════════════════════════════════════════════════════════════
# TEST 3: Pooled variable-speed Phase B (CAZ_Plus + Rest_of_London combined)
# ═══════════════════════════════════════════════════════════════════════════════
cat(sep)
cat("TEST 3: Pooled variable-speed Phase B — CAZ_Plus + Rest_of_London\n")
cat(dash)
cat("Purpose: Test whether a single λ_CF fits both variable-speed groups.\n")
cat("If the pooled estimate is close to Rest_of_London (0.250) and the\n")
cat("residuals are well-behaved, pooling is the appropriate specification\n")
cat("and the elevated CAZ_Plus estimate is a small-sample artefact.\n")
cat("If the pooled estimate is materially above 0.250, CAZ_Plus introduces\n")
cat("genuine upward pressure that pooling cannot eliminate.\n\n")

cat("Reference values from step 2:\n")
cat("  B Constant_Speed:  λ = 0.1760  SE = 0.0408  CI [0.0960, 0.2560]\n")
cat("  B CAZ_Plus:        λ = 0.6384  SE = 0.1021  CI [0.4384, 0.8385]\n")
cat("  B Rest_of_London:  λ = 0.2499  SE = 0.0354  CI [0.1806, 0.3192]\n\n")

cat("New fits:\n")
cold_B_rol <- df_cold %>%
  filter(Phase == "B", Group == "Rest_of_London", year >= 2021, Initial.Stage <= 6) %>%
  count(year, Initial.Stage, name = "n")
fit_lambda(make_gls_data(cold_B_rol, max_stage = 6),
           "B Rest_of_London (refit, confirmation)")

cold_B_var <- df_cold %>%
  filter(Phase == "B", Group %in% c("CAZ_Plus", "Rest_of_London"),
         year >= 2021, Initial.Stage <= 6) %>%
  count(year, Initial.Stage, name = "n")
fit_lambda(make_gls_data(cold_B_var, max_stage = 6),
           "B CAZ_Plus + Rest_of_London (pooled)")

cat("\nInterpretation guidance:\n")
cat("  - Pooled estimate close to Rest_of_London → CAZ_Plus rows are diluted\n")
cat("    by the larger ROL dataset; pooling is valid and recommended.\n")
cat("  - Pooled estimate materially above ROL → CAZ_Plus data is pulling the\n")
cat("    estimate up even when outweighed; structural difference, not noise.\n\n")

# ═══════════════════════════════════════════════════════════════════════════════
# TEST 4: Leave-one-out sensitivity — Phase B CAZ_Plus
# ═══════════════════════════════════════════════════════════════════════════════
cat(sep)
cat("TEST 4: Leave-one-out sensitivity — Phase B CAZ_Plus\n")
cat(dash)
cat("Purpose: Quantify how much each individual year-pair drives the elevated\n")
cat("CAZ_Plus estimate. The full fit uses three year-pairs (2021→2022,\n")
cat("2022→2023, 2023→2024), giving 15 GLS rows. Dropping one pair at a time\n")
cat("leaves 10 rows. Large swings in λ when a single pair is removed confirm\n")
cat("instability driven by sparse individual years, not a consistent signal.\n\n")

cat("Full fit (baseline):\n")
cold_caz_all <- df_cold %>%
  filter(Phase == "B", Group == "CAZ_Plus", year >= 2021, Initial.Stage <= 6) %>%
  count(year, Initial.Stage, name = "n")
full_gls_caz <- make_gls_data(cold_caz_all, max_stage = 6)
fit_lambda(full_gls_caz, "B CAZ_Plus full (2021→2022, 2022→2023, 2023→2024)")

cat("\nLeave-one-out fits (each row is a pair dropped):\n")
for (drop_t0 in c(2021L, 2022L, 2023L)) {
  d_loo <- full_gls_caz %>% filter(t0 != drop_t0)
  fit_lambda(d_loo, sprintf("drop %d→%d, retain other 2 pairs", drop_t0, drop_t0 + 1L))
}

cat("\nInterpretation guidance:\n")
cat("  - If λ is stable across all LOO fits: the estimate is consistent\n")
cat("    across years; instability is not year-specific.\n")
cat("  - If dropping the 2021→2022 pair produces a large drop in λ:\n")
cat("    this directly supports H2 (boundary contamination); Test 5 follows.\n")
cat("  - If dropping any single pair produces large swings: all pairs are\n")
cat("    high-leverage, confirming H1 (insufficient signal throughout).\n\n")

# ═══════════════════════════════════════════════════════════════════════════════
# TEST 5: Boundary contamination test — Phase B CAZ_Plus, 2022–2024 only
# ═══════════════════════════════════════════════════════════════════════════════
cat(sep)
cat("TEST 5: Boundary contamination test — Phase B CAZ_Plus, 2022–2024 only\n")
cat(dash)
cat("Purpose: The Sep 2020 policy step-change raised the CAZ_Plus compliance\n")
cat("requirement to Stage IV immediately. Machines arriving in the cold-engaged\n")
cat("fleet in 2020–2021 were subject to this new requirement from day one, so\n")
cat("their stage composition may reflect the shock of the policy change rather\n")
cat("than steady-state natural turnover. The 2021→2022 year-pair captures the\n")
cat("earliest post-step-change transition and is most susceptible to this bias.\n\n")
cat("This test refits Phase B CAZ_Plus using 2022–2024 only (dropping the\n")
cat("2021→2022 pair). If λ falls toward Constant_Speed / Rest_of_London levels,\n")
cat("the 2021 boundary year is identified as the contaminating factor.\n\n")

cat("Fits:\n")
cold_caz_2021plus <- df_cold %>%
  filter(Phase == "B", Group == "CAZ_Plus", year >= 2021, Initial.Stage <= 6) %>%
  count(year, Initial.Stage, name = "n")
fit_lambda(make_gls_data(cold_caz_2021plus, max_stage = 6),
           "B CAZ_Plus, 2021–2024 (current estimate, reference)")

cold_caz_2022plus <- df_cold %>%
  filter(Phase == "B", Group == "CAZ_Plus", year >= 2022, Initial.Stage <= 6) %>%
  count(year, Initial.Stage, name = "n")
fit_lambda(make_gls_data(cold_caz_2022plus, max_stage = 6),
           "B CAZ_Plus, 2022–2024 only (boundary pair excluded)")

cat("\nInterpretation guidance:\n")
cat("  - λ drops to ~0.25–0.35 → H2 confirmed; recommend using 2022–2024\n")
cat("    or pooling CAZ_Plus with Rest_of_London as the Phase B estimate.\n")
cat("  - λ remains near 0.64 → the elevated rate is present throughout\n")
cat("    Phase B, not just the boundary year; H1 (signal sparsity) is the\n")
cat("    dominant explanation and pooling with ROL is still recommended.\n")
cat("  - Wide CI in the 2022–2024 fit (only 2 year-pairs, 10 rows) is\n")
cat("    expected and does not invalidate the directional conclusion.\n\n")

# ═══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
cat(sep)
cat("SUMMARY — interpretation checklist\n")
cat(dash)
cat("The five tests together address the two hypotheses as follows:\n\n")
cat("H1 (algorithmic — near-zero predictor rows dominate the fit):\n")
cat("  Evidence FOR H1 if Test 2 shows CAZ_Plus has many rows with\n")
cat("  |predictor| < 0.05 and/or weight = 1, while ROL does not.\n\n")
cat("H2 (boundary contamination — 2021→2022 pair inflates λ):\n")
cat("  Evidence FOR H2 if:\n")
cat("    Test 1: 2021 composition is notably different from 2022–2024.\n")
cat("    Test 4: dropping the 2021→2022 pair produces the largest λ decrease.\n")
cat("    Test 5: 2022–2024-only estimate is substantially lower than full fit.\n\n")
cat("Recommended action depending on outcome:\n")
cat("  H1 only     → pool CAZ_Plus + Rest_of_London for Phase B (Test 3 value).\n")
cat("  H2 only     → use 2022–2024-only fit for CAZ_Plus, OR pool with ROL.\n")
cat("  H1 and H2   → pool with ROL; note both limitations in results.\n")
cat("  Neither     → CAZ_Plus λ is genuinely elevated; investigate whether\n")
cat("                LEZ-driven demand is contaminating the cold-engaged proxy.\n\n")

sink()
close(log_con)
cat("Log written to:", log_file, "\n")
