# 260329_step3c_cs_lambda.R
# λ_CF re-estimation for Constant_Speed with corrected max_stage = 3
#
# Motivation
# ----------
# Stages IIIB and IV are absent from the Constant_Speed cold-engaged fleet.
# The universal max_stage=6 used in step 2 produces 5 GLS rows per year-pair,
# with near-zero predictors for stages IIIB and IV diluting the regression.
# The correct state space is {I, II, IIIA} (max_stage=3), giving 2 GLS rows
# per year-pair and a well-identified fit against the observed II→IIIA trend.
#
# Stage V appears only in 2024, coinciding with the Phase C Stage V requirement
# (Jan 2025). This is anticipatory regulatory compliance, not natural turnover,
# and must be excluded from the λ_CF estimation window.
#
# Estimation windows tested
# -------------------------
# (a) 2017-2023  all Phase A1+A2+B excluding 2024 structural break
# (b) 2017-2020  Phase A1+A2 only (pre-Phase B)
# (c) 2021-2023  Phase B only (excluding 2020B straddle year and 2024)
# (d) Cross-check: pooled A1 vs A2 proportions (SWOT test, valid here
#     because IIIB is absent so the fatal-flaw stage-inversion cannot occur)
#
# Outputs: 260329_step3c_cs_lambda.txt
# Inputs:  260329_step2_exploratory.RData

library(tidyverse)

log_file <- "260329_step3c_cs_lambda.txt"
log_con  <- file(log_file, open = "wt")
sink(log_con, split = TRUE)

load("260329_step2_exploratory.RData")

stage_labels <- c("1"="I","2"="II","3"="IIIA","4"="IIIB","5"="IV","6"="V")
sep  <- paste0(strrep("═", 72), "\n")
dash <- paste0(strrep("─", 72), "\n")

# ── Constant_Speed cold records ───────────────────────────────────────────────
cs <- df_cold %>% filter(Group == "Constant_Speed")

cat(sep)
cat("CONSTANT_SPEED COLD-ENGAGED FLEET — STAGE COMPOSITION BY YEAR\n")
cat(dash)

annual_counts <- cs %>%
  count(year, Initial.Stage.raw, Initial.Stage, name = "n") %>%
  group_by(year) %>%
  mutate(prop = round(n / sum(n), 3),
         n_total = sum(n)) %>%
  ungroup() %>%
  arrange(year, Initial.Stage)

cat("Annual counts:\n")
print(as_tibble(annual_counts %>%
  select(year, stage = Initial.Stage.raw, n, prop, n_total)))

cat("\nStage proportions wide:\n")
prop_wide <- annual_counts %>%
  select(year, Initial.Stage.raw, prop) %>%
  pivot_wider(id_cols = year, names_from = Initial.Stage.raw,
              values_from = prop, values_fill = 0)
print(as_tibble(prop_wide))

cat("\nNote: Stage V first appears in 2024 — excluded from λ_CF estimation.\n")
cat("      Stages IIIB and IV never appear — max_stage = 3 is correct.\n\n")

# ── GLS helper (max_stage = 3) ────────────────────────────────────────────────
make_gls_cs <- function(counts_df) {
  # counts_df: rows with columns year, Initial.Stage (integer), n
  # max_stage fixed to 3; stages 4-6 ignored
  max_stage <- 3L
  years <- sort(unique(counts_df$year))

  bind_rows(lapply(seq_len(length(years) - 1), function(i) {
    t0 <- years[i]; t1 <- years[i + 1]
    get_r <- function(yr) {
      sub <- counts_df %>% filter(year == yr, Initial.Stage <= max_stage)
      x   <- setNames(sub$n, as.character(sub$Initial.Stage))
      raw <- sapply(as.character(seq_len(max_stage)),
                    function(s) if (s %in% names(x)) as.numeric(x[[s]]) else 0)
      total <- sum(raw)
      if (total == 0) return(list(raw = raw, prop = rep(NA_real_, max_stage)))
      list(raw = raw, prop = raw / total)
    }
    r0 <- get_r(t0); r1 <- get_r(t1)
    if (anyNA(r0$prop) || anyNA(r1$prop)) return(NULL)
    p0 <- r0$prop; p1 <- r1$prop; c0 <- r0$raw

    bind_rows(lapply(seq_len(max_stage - 1), function(s) {
      inflow    <- if (s == 1) 0 else
        sum(sapply(seq_len(s - 1), function(j) p0[j] / (max_stage - j)))
      predictor <- inflow - p0[s]
      delta     <- p1[s] - p0[s]
      data.frame(t0 = t0, t1 = t1, stage = s,
                 stage_label = stage_labels[as.character(s)],
                 predictor   = round(predictor, 5),
                 delta       = round(delta, 5),
                 weight      = pmax(c0[s], 1))
    }))
  }))
}

fit_lambda <- function(gls_data, label) {
  if (is.null(gls_data) || nrow(gls_data) == 0 ||
      anyNA(gls_data$predictor) || anyNA(gls_data$delta) ||
      sum(abs(gls_data$predictor) * gls_data$weight) < 1e-10) {
    cat(sprintf("  %-52s  SKIPPED (no signal)\n", label))
    return(invisible(NULL))
  }
  fit <- lm(delta ~ 0 + predictor, data = gls_data, weights = weight)
  lam <- coef(fit)[["predictor"]]
  se  <- sqrt(vcov(fit)["predictor", "predictor"])
  ci  <- lam + c(-1.96, 1.96) * se
  cat(sprintf("  %-52s  lambda = %6.4f  SE = %6.4f  95%% CI [%7.4f, %7.4f]\n",
              label, lam, se, ci[1], ci[2]))
  invisible(list(lambda = lam, se = se, ci = ci, data = gls_data))
}

# ── (a) Primary estimate: 2017-2023, max_stage = 3 ───────────────────────────
cat(sep)
cat("(a) PRIMARY ESTIMATE: years 2017-2023, max_stage = 3\n")
cat(dash)

cs_2017_2023 <- cs %>%
  filter(year >= 2017, year <= 2023) %>%
  count(year, Initial.Stage, Initial.Stage.raw, name = "n")

gls_a <- make_gls_cs(cs_2017_2023)
cat("GLS rows:\n")
print(as_tibble(gls_a))
cat("\nλ_CF estimates:\n")
fit_a_all  <- fit_lambda(gls_a, "CS 2017-2023 all year-pairs")
fit_a_II   <- fit_lambda(gls_a %>% filter(stage == 2), "CS 2017-2023 stage II rows only")

# ── (b) Phase A only: 2017-2020 ──────────────────────────────────────────────
cat(sep)
cat("(b) PHASE A ONLY: years 2017-2020, max_stage = 3\n")
cat(dash)

cs_2017_2020 <- cs %>%
  filter(year >= 2017, year <= 2020) %>%
  count(year, Initial.Stage, Initial.Stage.raw, name = "n")

gls_b <- make_gls_cs(cs_2017_2020)
cat("GLS rows:\n")
print(as_tibble(gls_b))
cat("\nλ_CF estimates:\n")
fit_b <- fit_lambda(gls_b, "CS 2017-2020")

# ── (c) Phase B only: 2021-2023 ──────────────────────────────────────────────
cat(sep)
cat("(c) PHASE B ONLY: years 2021-2023, max_stage = 3\n")
cat(dash)

cs_2021_2023 <- cs %>%
  filter(year >= 2021, year <= 2023) %>%
  count(year, Initial.Stage, Initial.Stage.raw, name = "n")

gls_c <- make_gls_cs(cs_2021_2023)
cat("GLS rows:\n")
print(as_tibble(gls_c))
cat("\nλ_CF estimates:\n")
fit_c <- fit_lambda(gls_c, "CS 2021-2023")

# ── (d) Cross-phase A1 vs A2 pooled proportions ───────────────────────────────
cat(sep)
cat("(d) CROSS-PHASE SWOT: pooled A1 (2017-2018) vs A2 (2019-Aug 2020)\n")
cat(dash)
cat("IIIB absent from CS cold fleet => stage-inversion fatal flaw does not apply.\n\n")

get_phase_props <- function(phase_label, year_min, year_max, month_max = 12) {
  sub <- cs %>%
    filter(Phase == phase_label |
             (year >= year_min & year <= year_max)) %>%
    filter(Initial.Stage <= 3L) %>%
    count(Initial.Stage, Initial.Stage.raw, name = "n")
  x   <- setNames(sub$n, as.character(sub$Initial.Stage))
  raw <- sapply(as.character(1:3),
                function(s) if (s %in% names(x)) as.numeric(x[[s]]) else 0)
  list(raw = raw, prop = raw / sum(raw), n_total = sum(raw))
}

# Use Phase column directly
phase_A1 <- cs %>%
  filter(Phase == "A1", Initial.Stage <= 3L) %>%
  count(Initial.Stage, Initial.Stage.raw, name = "n")
phase_A2 <- cs %>%
  filter(Phase == "A2", Initial.Stage <= 3L) %>%
  count(Initial.Stage, Initial.Stage.raw, name = "n")

to_vec <- function(df) {
  x <- setNames(df$n, as.character(df$Initial.Stage))
  raw <- sapply(as.character(1:3),
                function(s) if (s %in% names(x)) as.numeric(x[[s]]) else 0)
  list(raw = raw, prop = raw / sum(raw), n_total = sum(raw))
}

r_A1 <- to_vec(phase_A1)
r_A2 <- to_vec(phase_A2)

cat(sprintf("Phase A1 (n=%d): II=%.3f  IIIA=%.3f\n",
            r_A1$n_total, r_A1$prop[2], r_A1$prop[3]))
cat(sprintf("Phase A2 (n=%d): II=%.3f  IIIA=%.3f\n",
            r_A2$n_total, r_A2$prop[2], r_A2$prop[3]))
cat(sprintf("Delta (A2-A1):   II=%+.3f  IIIA=%+.3f\n\n",
            r_A2$prop[2] - r_A1$prop[2], r_A2$prop[3] - r_A1$prop[3]))

# Single-transition GLS: A1 mid (2017.5) → A2 mid (2019.75), dt ~ 2.25 years
dt_cross <- 2019.75 - 2017.5
max_stage <- 3L
p0 <- r_A1$prop; p1 <- r_A2$prop; c0 <- r_A1$raw
gls_d <- bind_rows(lapply(seq_len(max_stage - 1), function(s) {
  inflow    <- if (s == 1) 0 else
    sum(sapply(seq_len(s - 1), function(j) p0[j] / (max_stage - j)))
  predictor <- inflow - p0[s]
  delta     <- (p1[s] - p0[s]) / dt_cross
  data.frame(transition = "A1->A2", stage = s,
             stage_label = stage_labels[as.character(s)],
             predictor   = round(predictor, 5),
             delta       = round(delta, 5),
             weight      = pmax(c0[s], 1),
             dt          = round(dt_cross, 3))
}))
cat("GLS rows (delta annualised by dt_cross = 2.25 yr):\n")
print(as_tibble(gls_d))
cat("\nλ_CF estimate:\n")
fit_d <- fit_lambda(gls_d, "CS A1->A2 cross-phase")

# ── Comparison table ──────────────────────────────────────────────────────────
cat(sep)
cat("COMPARISON: current vs corrected estimates\n")
cat(dash)
cat("Current step-2 estimate (max_stage=6, Phase B 2021-2024):\n")
cat("  CS annual GLS (step 2):         lambda = 0.1760  SE = 0.0408\n")
cat("  CS temporal 3-seg (step 3b):    lambda = 0.1584  SE = 0.0248\n\n")
cat("Corrected estimates (max_stage=3):\n")
fit_lambda(gls_a, "CS 2017-2023 (primary)")
fit_lambda(gls_b, "CS 2017-2020 (Phase A)")
fit_lambda(gls_c, "CS 2021-2023 (Phase B excl 2024)")
fit_lambda(gls_d, "CS A1->A2 cross-phase")

sink()
close(log_con)
cat("Log written to:", log_file, "\n")
