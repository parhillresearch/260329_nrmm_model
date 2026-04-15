# 260329_step2_exploratory.R
# M1 completion + M2 exploratory analysis + RT-01 λ_CF estimation
# Inputs:  260329_step1_ingestion.RData
# Outputs: stage_counts_warm/cold, kw_summary, audit_by_year,
#          transitions, lambda_cf, plot → 260329_step2_exploratory.RData

library(tidyverse)

load("260329_step1_ingestion.RData")

# ── Tee output to console + TXT file ─────────────────────────────────────────
log_file <- "260329_step2_console_output.txt"
log_con  <- file(log_file, open = "wt")
sink(log_con, split = TRUE)  # split=TRUE mirrors to console simultaneously

# ── A. Slim columns ───────────────────────────────────────────────────────────
keep_cols <- c("Date", "Phase", "Group", "Cold_Engaged",
               "Initial.Stage", "Final.Stage",
               "Initial.Stage.raw", "Final.Stage.raw",
               "kW", "kW_missing", "Enforcement_Upgrade",
               "Zone.clean", "Engine.Type.clean")

df      <- as_tibble(df[, keep_cols])
df_cold <- as_tibble(df_cold[, keep_cols])
df_warm <- as_tibble(df_warm[, keep_cols])

df$year      <- as.integer(format(df$Date, "%Y"))
df_cold$year <- as.integer(format(df_cold$Date, "%Y"))
df_warm$year <- as.integer(format(df_warm$Date, "%Y"))

cat("Columns retained:", ncol(df), "\n")

# ── B1. Stage counts per Group × Year — warm ─────────────────────────────────
stage_counts_warm <- df_warm %>%
  count(Group, Phase, year, Initial.Stage, Initial.Stage.raw, name = "n") %>%
  arrange(Group, year, Initial.Stage)

cat("\nWarm fleet — Stage × Year (wide):\n")
print(
  stage_counts_warm %>%
    group_by(Group, year, Initial.Stage.raw) %>%
    summarise(n = sum(n), .groups = "drop") %>%
    pivot_wider(id_cols = c(Group, year),
                names_from = Initial.Stage.raw, values_from = n, values_fill = 0),
  n = 50L
)

# ── B2. Stage counts — cold ───────────────────────────────────────────────────
# Non-pooled: per Group × year (all phases)
stage_counts_cold_nonpooled <- df_cold %>%
  count(Group, Phase, year, Initial.Stage, Initial.Stage.raw, name = "n") %>%
  arrange(Group, year, Initial.Stage)

# Pooled (methodology): A1/A2 across groups; B per group
stage_counts_cold_pooled <- df_cold %>%
  filter(Phase %in% c("A1", "A2")) %>%
  count(Phase, year, Initial.Stage, Initial.Stage.raw, name = "n") %>%
  arrange(Phase, year, Initial.Stage)

stage_counts_cold_B <- df_cold %>%
  filter(Phase == "B") %>%
  count(Group, year, Initial.Stage, Initial.Stage.raw, name = "n") %>%
  arrange(Group, year, Initial.Stage)

cat("\nCold fleet — non-pooled per Group × Year (wide):\n")
print(
  stage_counts_cold_nonpooled %>%
    group_by(Group, year, Initial.Stage.raw) %>%
    summarise(n = sum(n), .groups = "drop") %>%
    pivot_wider(id_cols = c(Group, year),
                names_from = Initial.Stage.raw, values_from = n, values_fill = 0),
  n = 50L
)
cat("\nCold fleet — pooled A1/A2 (wide):\n")
print(
  stage_counts_cold_pooled %>%
    group_by(Phase, year, Initial.Stage.raw) %>%
    summarise(n = sum(n), .groups = "drop") %>%
    pivot_wider(id_cols = c(Phase, year),
                names_from = Initial.Stage.raw, values_from = n, values_fill = 0)
)
cat("\nCold fleet — pooled B per group (wide):\n")
print(
  stage_counts_cold_B %>%
    group_by(Group, year, Initial.Stage.raw) %>%
    summarise(n = sum(n), .groups = "drop") %>%
    pivot_wider(id_cols = c(Group, year),
                names_from = Initial.Stage.raw, values_from = n, values_fill = 0)
)

# ── B3. kW summary per Group — warm ──────────────────────────────────────────
kw_summary <- df_warm %>%
  group_by(Group) %>%
  summarise(n = n(),
            n_kw_missing  = sum(kW_missing),
            pct_missing   = round(100 * mean(kW_missing), 1),
            kw_mean       = round(mean(kW, na.rm = TRUE), 1),
            kw_median     = median(kW, na.rm = TRUE),
            kw_p25        = quantile(kW, 0.25, na.rm = TRUE),
            kw_p75        = quantile(kW, 0.75, na.rm = TRUE),
            .groups = "drop")
cat("\nkW summary by Group (warm fleet):\n")
print(kw_summary)

# ── B4. RT-04 Audit frequency QA ─────────────────────────────────────────────
audit_by_year <- df_warm %>%
  count(year, Phase, name = "n_audits") %>%
  arrange(year)
cat("\nRT-04 — Warm audit counts per year:\n")
print(audit_by_year)

# ── C1. Stage distribution charts — warm fleet ───────────────────────────────
stage_pct_warm <- df_warm %>%
  count(Group, year, Initial.Stage.raw, name = "n") %>%
  group_by(Group, year) %>%
  mutate(pct = 100 * n / sum(n)) %>%
  ungroup() %>%
  mutate(Initial.Stage.raw = factor(Initial.Stage.raw,
           levels = c("I", "II", "IIIA", "IIIB", "IV", "V")))

p_stage <- ggplot(stage_pct_warm, aes(x = year, y = pct, fill = Initial.Stage.raw)) +
  geom_bar(stat = "identity") +
  facet_wrap(~Group) +
  scale_fill_brewer(palette = "RdYlGn", direction = 1, name = "Stage") +
  scale_x_continuous(breaks = 2016:2024) +
  labs(title = "Warm fleet Stage distribution by Group and Year",
       x = "Year", y = "% of audited fleet") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("260329_stage_distribution_warm.png", p_stage, width = 11, height = 4, dpi = 150)
cat("\nSaved: 260329_stage_distribution_warm.png\n")

# ── C1b. Cold fleet — non-pooled (Group × Year, same format as warm) ─────────
stage_pct_cold_nonpooled <- df_cold %>%
  count(Group, year, Initial.Stage.raw, name = "n") %>%
  group_by(Group, year) %>%
  mutate(pct = 100 * n / sum(n)) %>%
  ungroup() %>%
  mutate(Initial.Stage.raw = factor(Initial.Stage.raw,
           levels = c("I", "II", "IIIA", "IIIB", "IV", "V")))

p_cold_nonpooled <- ggplot(stage_pct_cold_nonpooled,
                            aes(x = year, y = pct, fill = Initial.Stage.raw)) +
  geom_bar(stat = "identity") +
  facet_wrap(~Group) +
  scale_fill_brewer(palette = "RdYlGn", direction = 1, name = "Stage") +
  scale_x_continuous(breaks = 2016:2024) +
  labs(title = "Cold-engaged fleet Stage distribution by Group and Year",
       x = "Year", y = "% of cold-engaged fleet") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("260329_stage_distribution_cold_nonpooled.png",
       p_cold_nonpooled, width = 11, height = 4, dpi = 150)
cat("\nSaved: 260329_stage_distribution_cold_nonpooled.png\n")

# ── C1c. Cold fleet — pooled plots (panel A: by year; panel B: by phase) ──────
stage_pct_cold_by_year <- df_cold %>%
  count(year, Initial.Stage.raw, name = "n") %>%
  group_by(year) %>%
  mutate(pct = 100 * n / sum(n), panel = "All groups × Year") %>%
  ungroup()

stage_pct_cold_by_phase <- df_cold %>%
  count(Phase, Initial.Stage.raw, name = "n") %>%
  group_by(Phase) %>%
  mutate(pct = 100 * n / sum(n), panel = "All groups × Phase") %>%
  ungroup() %>%
  rename(year = Phase)  # unified x aesthetic

stage_pct_cold_pooled_plot <- bind_rows(
  stage_pct_cold_by_year %>% mutate(year = as.character(year)),
  stage_pct_cold_by_phase
) %>%
  mutate(
    Initial.Stage.raw = factor(Initial.Stage.raw,
                               levels = c("I", "II", "IIIA", "IIIB", "IV", "V")),
    panel = factor(panel, levels = c("All groups × Year", "All groups × Phase"))
  )

p_cold_pooled <- ggplot(stage_pct_cold_pooled_plot,
                         aes(x = year, y = pct, fill = Initial.Stage.raw)) +
  geom_bar(stat = "identity") +
  facet_wrap(~panel, scales = "free_x") +
  scale_fill_brewer(palette = "RdYlGn", direction = 1, name = "Stage") +
  labs(title = "Cold-engaged fleet Stage distribution — pooled",
       x = NULL, y = "% of cold-engaged fleet") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("260329_stage_distribution_cold_pooled.png",
       p_cold_pooled, width = 10, height = 4, dpi = 150)
cat("\nSaved: 260329_stage_distribution_cold_pooled.png\n")

# ── C2. RT-07 Upgrade pathway validation ─────────────────────────────────────
transitions <- df_warm %>%
  filter(!is.na(Initial.Stage), !is.na(Final.Stage)) %>%
  count(Initial.Stage.raw, Final.Stage.raw, name = "n") %>%
  arrange(Initial.Stage.raw, Final.Stage.raw)

cat("\nRT-07 — All observed transitions (warm fleet):\n")
print(transitions, n = nrow(transitions))

stage_order <- c("I", "II", "IIIA", "IIIB", "IV", "V")
non_permitted <- transitions %>%
  filter(
    match(Final.Stage.raw, stage_order) < match(Initial.Stage.raw, stage_order)
  )
cat("\nNon-permitted (downgrade) transitions:\n")
print(non_permitted)

# ── C3. RT-05 Minimum cell counts ────────────────────────────────────────────
cat("\nRT-05 — Min/max cell count per Phase × Group (warm, by Stage):\n")
min_cells_warm <- stage_counts_warm %>%
  group_by(Phase, Group) %>%
  summarise(min_n = min(n), max_n = max(n),
            n_stage_cells = n(), .groups = "drop")
print(min_cells_warm)

cat("\nRT-05 — Min cell count per Phase (cold pooled):\n")
print(stage_counts_cold_pooled %>% group_by(Phase) %>%
        summarise(min_n = min(n), max_n = max(n), .groups = "drop"))

# ── D. RT-01 λ_CF estimation ──────────────────────────────────────────────────
# Model: Δp_s = λ_CF × (Σ_{j<s} p_{j,t}/k_j − p_{s,t})
# where p_{s,t} = proportion of cold fleet in stage s at year t.
# Proportions used (not raw counts) to remove annual audit volume variation.
# WLS with weight = absolute stage count; SE from vcov().

make_gls_data <- function(counts_df, max_stage) {
  # counts_df: year, Initial.Stage (integer), n
  # Normalises counts to proportions within each year before computing delta
  # and predictor, to remove the effect of changing annual audit volumes.
  # Absolute counts are retained as weights (larger samples → lower variance).
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
    p0 <- r0$prop;   p1 <- r1$prop
    c0 <- r0$raw                        # absolute counts used for weights only

    bind_rows(lapply(seq_len(max_stage - 1), function(s) {
      inflow <- if (s == 1) 0 else
        sum(sapply(seq_len(s - 1), function(j)
          p0[j] / (max_stage - j)))
      outflow   <- p0[s]
      predictor <- inflow - outflow
      delta     <- p1[s] - p0[s]
      data.frame(t0 = t0, stage = s, delta = delta,
                 predictor = predictor, weight = pmax(c0[s], 1))
    }))
  }))
}

fit_lambda_cf <- function(gls_data, label) {
  if (nrow(gls_data) == 0) {
    cat(sprintf("\n%s: insufficient data — skipped\n", label))
    return(list(lambda = NA_real_, se = NA_real_, ci = c(NA_real_, NA_real_),
                fit = NULL, data = gls_data))
  }
  fit <- lm(delta ~ 0 + predictor, data = gls_data, weights = weight)
  lam <- coef(fit)[["predictor"]]
  se  <- sqrt(vcov(fit)["predictor", "predictor"])
  ci  <- lam + c(-1.96, 1.96) * se
  cat(sprintf("\n%s: λ_CF = %.4f  SE = %.4f  95%% CI [%.4f, %.4f]\n",
              label, lam, se, ci[1], ci[2]))
  list(lambda = lam, se = se, ci = ci, fit = fit, data = gls_data)
}

# A1: pooled, 5-state (I–IV = integers 1–5); exclude Stage V (absent)
cold_A1 <- df_cold %>%
  filter(Phase == "A1", Initial.Stage <= 5) %>%
  count(year, Initial.Stage, name = "n")
lambda_A1 <- fit_lambda_cf(make_gls_data(cold_A1, max_stage = 5), "A1 pooled")

# A2: pooled, 5-state (I–IV); note 2020 is partial year (Jan–Aug only)
cold_A2 <- df_cold %>%
  filter(Phase == "A2", Initial.Stage <= 5) %>%
  count(year, Initial.Stage, name = "n")
lambda_A2 <- fit_lambda_cf(make_gls_data(cold_A2, max_stage = 5), "A2 pooled [2020 partial]")

# B: per group, 6-state (I–V = integers 1–6); use years 2021–2024 (avoid partial 2020)
lambda_B <- setNames(
  lapply(c("Constant_Speed", "CAZ_Plus", "Rest_of_London"), function(grp) {
    cold_B <- df_cold %>%
      filter(Phase == "B", Group == grp, year >= 2021, Initial.Stage <= 6) %>%
      count(year, Initial.Stage, name = "n")
    fit_lambda_cf(make_gls_data(cold_B, max_stage = 6), paste0("B ", grp))
  }),
  c("Constant_Speed", "CAZ_Plus", "Rest_of_London")
)

lambda_cf <- list(A1 = lambda_A1, A2 = lambda_A2, B = lambda_B)

# ── Save ──────────────────────────────────────────────────────────────────────
save(df, df_cold, df_warm,
     stage_counts_warm, stage_counts_cold_nonpooled,
     stage_counts_cold_pooled, stage_counts_cold_B,
     kw_summary, audit_by_year, transitions, lambda_cf,
     file = "260329_step2_exploratory.RData")
cat("\nSaved: 260329_step2_exploratory.RData\n")
cat("Objects: df, df_cold, df_warm, stage_counts_warm, stage_counts_cold_nonpooled,\n")
cat("         stage_counts_cold_pooled, stage_counts_cold_B,\n")
cat("         kw_summary, audit_by_year, transitions, lambda_cf\n")
cat("Plots:   260329_stage_distribution_warm.png\n")
cat("         260329_stage_distribution_cold_nonpooled.png\n")
cat("         260329_stage_distribution_cold_pooled.png\n")

sink()
close(log_con)
cat("Log written to:", log_file, "\n")
