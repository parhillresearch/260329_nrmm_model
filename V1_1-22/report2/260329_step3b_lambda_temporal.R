# 260329_step3b_lambda_temporal.R
# λ_CF estimation for Phase B using 3 equal-duration temporal segments
#
# Motivation
# ----------
# Annual year-by-year GLS for Phase B CAZ_Plus is unstable due to small
# annual cold-engaged counts (37–83) causing erratic year-on-year proportion
# swings. Pooling records into 3 equal-duration time segments raises effective
# sample sizes and removes sampling-driven annual noise while preserving the
# temporal trend across Phase B.
#
# Method
# ------
# Phase B (1 Sep 2020 – 31 Dec 2024 = 1582 days) is divided into 3 segments
# of equal duration (~527 days each) by exact date. For each segment, stage
# counts are aggregated across all records in that segment and converted to
# proportions. The GLS is then run on 2 transitions (seg1→seg2, seg2→seg3).
# Because segment midpoints are ~1.44 years apart rather than 1 year,
# Δp is divided by Δt (years between midpoints) to recover an annual λ.
# Midpoints are geometric centres of each segment (start + half duration).
#
# All three Phase B groups are run through the same procedure. Results are
# compared to the original annual estimates from step 2.
#
# Inputs:  260329_step2_exploratory.RData  (provides df_cold with Date column)
# Outputs: 260329_step3b_lambda_temporal.txt

library(tidyverse)

log_file <- "260329_step3b_lambda_temporal.txt"
log_con  <- file(log_file, open = "wt")
sink(log_con, split = TRUE)

load("260329_step2_exploratory.RData")

stage_labels <- c("1"="I","2"="II","3"="IIIA","4"="IIIB","5"="IV","6"="V")

sep  <- paste0(strrep("═", 72), "\n")
dash <- paste0(strrep("─", 72), "\n")

# ── Segment definitions ───────────────────────────────────────────────────────
phase_B_start <- as.Date("2020-09-01")
phase_B_end   <- as.Date("2024-12-31")
total_days    <- as.numeric(phase_B_end - phase_B_start)   # 1582
seg_days      <- total_days / 3

# Segment boundaries (start inclusive, end inclusive)
seg_bounds <- data.frame(
  seg   = 1:3,
  start = phase_B_start + round(c(0, 1, 2) * seg_days),
  end   = c(phase_B_start + round(c(1, 2) * seg_days) - 1, phase_B_end)
)
seg_bounds$mid      <- seg_bounds$start + round(seg_days / 2)
seg_bounds$mid_year <- as.numeric(seg_bounds$mid - as.Date("1970-01-01")) /
                       365.25 + 1970  # fractional year

cat(sep)
cat("SEGMENT DEFINITIONS\n")
cat(dash)
cat(sprintf("Phase B: %s to %s  (%d days)\n",
            phase_B_start, phase_B_end, total_days))
cat(sprintf("Segment duration: %.1f days (~%.2f years) each\n\n",
            seg_days, seg_days / 365.25))
print(seg_bounds %>%
        mutate(mid_year = round(mid_year, 3),
               duration = as.numeric(end - start) + 1))

# ── Helper: assign segment to each record ────────────────────────────────────
assign_segment <- function(dates) {
  case_when(
    dates >= seg_bounds$start[1] & dates <= seg_bounds$end[1] ~ 1L,
    dates >= seg_bounds$start[2] & dates <= seg_bounds$end[2] ~ 2L,
    dates >= seg_bounds$start[3] & dates <= seg_bounds$end[3] ~ 3L,
    TRUE ~ NA_integer_
  )
}

# ── Helper: build GLS data from segment proportions ──────────────────────────
make_gls_temporal <- function(seg_props, max_stage) {
  # seg_props: list of length 3, each with $raw, $prop, $mid_year
  bind_rows(lapply(1:2, function(i) {
    s0 <- seg_props[[i]]; s1 <- seg_props[[i + 1]]
    dt <- s1$mid_year - s0$mid_year
    p0 <- s0$prop; p1 <- s1$prop; c0 <- s0$raw
    bind_rows(lapply(seq_len(max_stage - 1), function(s) {
      inflow    <- if (s == 1) 0 else
        sum(sapply(seq_len(s - 1), function(j) p0[j] / (max_stage - j)))
      predictor <- inflow - p0[s]
      delta     <- (p1[s] - p0[s]) / dt   # annualised
      data.frame(seg_pair = paste0(i, "->", i + 1),
                 stage = s, stage_label = stage_labels[as.character(s)],
                 predictor = round(predictor, 4),
                 delta     = round(delta, 4),
                 weight    = pmax(c0[s], 1),
                 dt        = round(dt, 3))
    }))
  }))
}

fit_lambda <- function(gls_data, label) {
  if (nrow(gls_data) == 0 ||
      anyNA(gls_data$predictor) || anyNA(gls_data$delta) ||
      sum(abs(gls_data$predictor) * gls_data$weight) < 1e-10) {
    cat(sprintf("  %-52s  SKIPPED (no signal)\n", label))
    return(invisible(NULL))
  }
  fit <- lm(delta ~ 0 + predictor, data = gls_data, weights = weight)
  lam <- coef(fit)[["predictor"]]
  se  <- sqrt(vcov(fit)["predictor", "predictor"])
  ci  <- lam + c(-1.96, 1.96) * se
  cat(sprintf("  %-52s  λ = %6.4f  SE = %6.4f  95%% CI [%7.4f, %7.4f]\n",
              label, lam, se, ci[1], ci[2]))
  invisible(list(lambda = lam, se = se, ci = ci))
}

# ── Process each Phase B group ────────────────────────────────────────────────
groups <- c("CAZ_Plus", "Constant_Speed", "Rest_of_London")
max_stage <- 6   # Phase B: stages I–V (integers 1–6)

for (grp in groups) {

  cat(sep)
  cat(sprintf("GROUP: %s\n", grp))
  cat(dash)

  cold_B <- df_cold %>%
    filter(Phase == "B", Group == grp, Initial.Stage <= max_stage) %>%
    mutate(seg = assign_segment(Date))

  # ── Record counts per segment ──────────────────────────────────────────────
  cat("Records per segment (all stages combined):\n")
  seg_summary <- cold_B %>%
    filter(!is.na(seg)) %>%
    count(seg, name = "n_records") %>%
    left_join(seg_bounds %>% select(seg, start, end, mid, mid_year), by = "seg") %>%
    mutate(mid_year = round(mid_year, 3))
  print(seg_summary)

  # ── Stage counts per segment (wide) ───────────────────────────────────────
  cat("\nStage counts per segment:\n")
  stage_wide <- cold_B %>%
    filter(!is.na(seg)) %>%
    count(seg, Initial.Stage.raw, Initial.Stage, name = "n") %>%
    arrange(seg, Initial.Stage) %>%
    select(seg, Initial.Stage.raw, n) %>%
    pivot_wider(id_cols = seg, names_from = Initial.Stage.raw,
                values_from = n, values_fill = 0L)
  print(as_tibble(stage_wide))

  cat("\nStage proportions per segment:\n")
  prop_wide <- cold_B %>%
    filter(!is.na(seg)) %>%
    count(seg, Initial.Stage.raw, Initial.Stage, name = "n") %>%
    group_by(seg) %>%
    mutate(prop = round(n / sum(n), 3)) %>%
    ungroup() %>%
    arrange(seg, Initial.Stage) %>%
    select(seg, Initial.Stage.raw, prop) %>%
    pivot_wider(id_cols = seg, names_from = Initial.Stage.raw,
                values_from = prop, values_fill = 0)
  print(as_tibble(prop_wide))

  # ── Build segment proportion objects ──────────────────────────────────────
  seg_props <- lapply(1:3, function(i) {
    sub <- cold_B %>% filter(seg == i)
    agg <- sub %>% count(Initial.Stage, name = "n")
    x   <- setNames(agg$n, as.character(agg$Initial.Stage))
    raw <- sapply(as.character(seq_len(max_stage)),
                  function(s) if (s %in% names(x)) as.numeric(x[[s]]) else 0)
    total <- sum(raw)
    if (total == 0) {
      cat(sprintf("  WARNING: segment %d has zero records for %s — GLS skipped\n",
                  i, grp))
      return(list(raw = raw, prop = rep(NA_real_, max_stage),
                  mid_year = seg_bounds$mid_year[i]))
    }
    list(raw = raw, prop = raw / total, mid_year = seg_bounds$mid_year[i])
  })

  # ── GLS rows ──────────────────────────────────────────────────────────────
  gls_data <- make_gls_temporal(seg_props, max_stage)
  cat("\nGLS rows (delta is annualised by dividing by dt):\n")
  print(as_tibble(gls_data), n = 20)

  # ── λ_CF estimates ────────────────────────────────────────────────────────
  cat("\nλ_CF estimates:\n")
  fit_lambda(gls_data, paste0(grp, " temporal 3-seg (all pairs)"))
  fit_lambda(gls_data %>% filter(seg_pair == "1->2"),
             paste0(grp, " seg 1->2 only"))
  fit_lambda(gls_data %>% filter(seg_pair == "2->3"),
             paste0(grp, " seg 2->3 only"))
  cat("\n")
}

# ── Comparison with original annual estimates from step 2 ────────────────────
cat(sep)
cat("COMPARISON: temporal 3-segment vs original annual estimates (step 2)\n")
cat(dash)
cat("Original annual estimates (step 2, years 2021-2024, year >= 2021 filter):\n")
cat("  Constant_Speed:  λ = 0.1760  SE = 0.0408  CI [0.0960, 0.2560]\n")
cat("  CAZ_Plus:        λ = 0.6384  SE = 0.1021  CI [0.4384, 0.8385]\n")
cat("  Rest_of_London:  λ = 0.2499  SE = 0.0354  CI [0.1806, 0.3192]\n\n")
cat("Temporal estimates include 2020B records; use 3 equal segments across full\n")
cat("Phase B; Δp annualised by dividing by years between segment midpoints.\n")

sink()
close(log_con)
cat("Log written to:", log_file, "\n")
