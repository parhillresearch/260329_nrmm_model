# 260330_step5_6_matrix_forecast.R
# Phase 5: Matrix Assembly  |  Phase 6: Forecast & Emissions
# Date: 30 March 2026
# Inputs:  260329_step2_exploratory.RData, 260330_step4_parameters.RData
# Outputs: 260330_step5_6_results.RData, 260330_plot1_transition_heatmap.png,
#          260330_plot2_forecast_stages.png, 260330_plot3_compliance_trajectory.png,
#          260330_plot4_nox_forecast.png

library(tidyverse)
sink("260330_step5_6_console_output.txt", split = TRUE)

# ── 0. Load ───────────────────────────────────────────────────────────────────
load("260329_step2_exploratory.RData")
load("260330_step4_parameters.RData")

# ── 1. Stage constants ────────────────────────────────────────────────────────
stage_int_map <- c(I = 1L, II = 2L, IIIA = 3L, IIIB = 4L, IV = 5L, V = 6L, ZE = 7L)
stage_lbl     <- names(stage_int_map)   # length 7; indices 1–7

# Active stage integer indices per group (into stage_lbl)
act <- list(
  Constant_Speed = c(2L, 3L, 6L),  # II, IIIA, V
  CAZ_Plus       = 1L:6L,           # I–V
  Rest_of_London = 1L:6L            # I–V
)

# λ_Total Phase B (from Step 4)
lam_B <- c(Constant_Speed = 0.2126, CAZ_Plus = 0.3109, Rest_of_London = 0.2649)

# ── 2. Analytical P_Total per group ──────────────────────────────────────────
# From stage i: P[i,i] = 1−λ; P[i,j>i] = λ/n_above; top stage absorbing.
build_P <- function(stage_ints, lam) {
  sl  <- stage_lbl[stage_ints]
  n   <- length(sl)
  mat <- diag(n)
  dimnames(mat) <- list(from = sl, to = sl)
  for (i in seq_len(n - 1)) {
    n_above   <- n - i
    mat[i, i] <- 1 - lam
    mat[i, (i + 1):n] <- lam / n_above
  }
  mat  # row[n] already = c(0,...,1) from diag()
}

P_grp <- lapply(names(act), function(g) build_P(act[[g]], lam_B[g]))
names(P_grp) <- names(act)

cat("══ P_TOTAL MATRICES (Phase B rates, Scenario A) ══\n")
for (g in names(P_grp)) {
  cat(sprintf("\n── %s  (λ=%.4f) ──\n", g, lam_B[g]))
  print(round(P_grp[[g]], 4))
}

# ── 3. Starting states: 2024 warm counts ─────────────────────────────────────
C0 <- list(
  Constant_Speed = c(II = 1,  IIIA = 38,  V = 72),
  CAZ_Plus       = c(I = 0,  II = 0,  IIIA = 4,  IIIB = 29,  IV = 91,  V = 252),
  Rest_of_London = c(I = 1,  II = 4,  IIIA = 4,  IIIB = 134, IV = 151, V = 519)
)
# Checksums: CS=111, CAZ+=376, RoL=813
cat("\n══ 2024 STARTING COUNTS ══\n")
for (g in names(C0)) cat(sprintf("  %-15s  n = %d\n", g, as.integer(sum(C0[[g]]))))

# ── 4. Merge CAZ+ + RoL → Variable_Speed (1.1.2025) ─────────────────────────
n_caz  <- sum(C0$CAZ_Plus)        # 376
n_rol  <- sum(C0$Rest_of_London)  # 813
lam_vs <- (n_caz * lam_B["CAZ_Plus"] + n_rol * lam_B["Rest_of_London"]) /
           (n_caz + n_rol)
C0_vs  <- C0$CAZ_Plus + C0$Rest_of_London   # stages I–V, n = 1189
P_vs   <- build_P(1L:6L, lam_vs)

cat(sprintf("\n  Variable_Speed (merged):  λ = %.4f  n = %d\n", lam_vs, n_caz + n_rol))
cat("\n── P_Total Variable_Speed (merged) ──\n")
print(round(P_vs, 4))

# ── 5. Scenario B: compliance mask ───────────────────────────────────────────
# Zero off-diagonal transitions to non-compliant stages (stage_int < thresh).
# Redistribute excised mass equally to compliant target stages.
apply_mask_B <- function(P_in, stage_ints, thresh) {
  P_out <- P_in
  n     <- length(stage_ints)
  for (i in seq_len(n)) {
    excised <- 0
    for (j in seq_len(n)) {
      if (j != i && stage_ints[j] < thresh) {
        excised      <- excised + P_out[i, j]
        P_out[i, j] <- 0
      }
    }
    if (excised > 0) {
      targets <- setdiff(which(stage_ints >= thresh), i)
      if (length(targets) > 0) {
        P_out[i, targets] <- P_out[i, targets] + excised / length(targets)
      } else {
        P_out[i, i] <- P_out[i, i] + excised   # absorb to self if no valid target
      }
    }
  }
  P_out
}

# CS Phase C: ≥V throughout
P_cs_B    <- apply_mask_B(P_grp$Constant_Speed, act$Constant_Speed, 6L)
# VS merged: ≥IV (2025–2029), ≥V (2030)
P_vs_B_IV <- apply_mask_B(P_vs, 1L:6L, 5L)
P_vs_B_V  <- apply_mask_B(P_vs, 1L:6L, 6L)

cat("\n══ SCENARIO B MATRICES ══\n")
cat("\n── CS (Phase C threshold = V) ──\n");              print(round(P_cs_B, 4))
cat("\n── Variable Speed 2025-2029 (threshold = IV) ──\n"); print(round(P_vs_B_IV, 4))
cat("\n── Variable Speed 2030 (threshold = V) ──\n");       print(round(P_vs_B_V, 4))

# ── 6. Forecast 2025–2030 ────────────────────────────────────────────────────
run_fc <- function(C0_counts, P_A, P_B_by_yr, years = 2025:2030) {
  n_tot  <- sum(C0_counts)
  prop_A <- C0_counts / n_tot
  prop_B <- C0_counts / n_tot
  rows   <- vector("list", length(years))
  for (k in seq_along(years)) {
    yr     <- years[k]
    prop_A <- drop(prop_A %*% P_A)
    prop_B <- drop(prop_B %*% P_B_by_yr[[as.character(yr)]])
    rows[[k]] <- data.frame(
      year  = yr, stage = names(C0_counts),
      prop_A = prop_A, prop_B = prop_B,
      n_A    = prop_A * n_tot, n_B = prop_B * n_tot,
      stringsAsFactors = FALSE
    )
  }
  bind_rows(rows)
}

cs_B_by_yr <- setNames(rep(list(P_cs_B), 6),    as.character(2025:2030))
vs_B_by_yr <- c(setNames(rep(list(P_vs_B_IV), 5), as.character(2025:2029)),
                list("2030" = P_vs_B_V))

fc_cs  <- run_fc(C0$Constant_Speed, P_grp$Constant_Speed, cs_B_by_yr) %>% mutate(group = "Constant_Speed")
fc_vs  <- run_fc(C0_vs,             P_vs,                 vs_B_by_yr)  %>% mutate(group = "Variable_Speed")
fc_all <- bind_rows(fc_cs, fc_vs)

cat("\n══ FORECAST STAGE PROPORTIONS ══\n")
cat("\n── Constant Speed ──\n")
print(fc_cs %>% filter(prop_A > 1e-4 | prop_B > 1e-4) %>%
        select(year, stage, prop_A, prop_B) %>% mutate(across(c(prop_A,prop_B), ~round(.,4))))
cat("\n── Variable Speed (merged) ──\n")
print(fc_vs %>% filter(prop_A > 1e-4 | prop_B > 1e-4) %>%
        select(year, stage, prop_A, prop_B) %>% mutate(across(c(prop_A,prop_B), ~round(.,4))))

# ── 7. Compliance % from forecast ────────────────────────────────────────────
# Phase C thresholds: CS ≥ V; VS ≥ IV (2025-2029), ≥ V (2030)
thresh_fc <- data.frame(
  year = 2025:2030, cs = 6L, vs = c(5L,5L,5L,5L,5L,6L), stringsAsFactors = FALSE
)

fc_comp <- fc_all %>%
  left_join(thresh_fc, by = "year") %>%
  mutate(
    thresh    = if_else(group == "Constant_Speed", cs, vs),
    stg_int   = stage_int_map[stage],
    compliant = stg_int >= thresh
  ) %>%
  group_by(group, year) %>%
  summarise(pct_A = 100 * sum(prop_A[compliant]),
            pct_B = 100 * sum(prop_B[compliant]),
            .groups = "drop")

cat("\n══ FORECAST COMPLIANCE % ══\n")
print(fc_comp %>% mutate(across(c(pct_A, pct_B), ~round(., 1))))

# ── 8. Emissions ─────────────────────────────────────────────────────────────
H <- 2000  # operating hours/yr

# kW table with CS IIIB/IV group-mean substitution
kw_df <- kw_by_group_stage %>%
  rename(stage = Initial.Stage.raw) %>%
  mutate(kw_use = case_when(
    Group == "Constant_Speed" & stage %in% c("IIIB", "IV") ~ 172,
    TRUE ~ kw_mean
  ))

# Merged VS kW: fleet-size weighted average of CAZ+ and RoL by stage
kw_vs_df <- kw_df %>%
  filter(Group %in% c("CAZ_Plus", "Rest_of_London")) %>%
  group_by(stage) %>%
  summarise(kw_use = weighted.mean(kw_use, n), .groups = "drop") %>%
  mutate(group = "Variable_Speed")

kw_cs_df <- kw_df %>%
  filter(Group == "Constant_Speed") %>%
  select(stage, kw_use) %>%
  mutate(group = "Constant_Speed")

kw_all <- bind_rows(kw_vs_df, kw_cs_df)

ef_df <- tibble(stage = names(ef_nox_gkwh), ef = unname(ef_nox_gkwh))

calc_em <- function(fc_df, scen) {
  fc_df %>%
    mutate(n_sc = if (scen == "A") n_A else n_B) %>%
    left_join(kw_all, by = c("group", "stage")) %>%
    left_join(ef_df,  by = "stage") %>%
    filter(!is.na(kw_use), !is.na(ef)) %>%
    mutate(nox_kg = n_sc * kw_use * H * ef / 1e3) %>%
    group_by(group, year) %>%
    summarise(nox_kg = sum(nox_kg), .groups = "drop") %>%
    mutate(scenario = scen)
}

em_all <- bind_rows(calc_em(fc_all, "A"), calc_em(fc_all, "B"))

cat("\n══ NOx EMISSIONS  [kg/yr — ⚠ PLACEHOLDER EFs] ══\n")
print(em_all %>%
        mutate(nox_t = round(nox_kg / 1000, 2)) %>%
        select(-nox_kg) %>%
        pivot_wider(names_from = scenario, values_from = nox_t, names_prefix = "tonnes_Scen"))

# ── 9. Plots ──────────────────────────────────────────────────────────────────
stage_col <- c(I="#d73027", II="#f46d43", IIIA="#fdae61", IIIB="#fee090",
               IV="#abd9e9", V="#4575b4", ZE="#313695")
stage_ord <- c("I","II","IIIA","IIIB","IV","V","ZE")

## Plot 1: Transition matrix heatmaps ─────────────────────────────────────────
mat_long <- function(mat, label) {
  sl <- rownames(mat)
  as.data.frame(mat) %>%
    mutate(from = factor(sl, levels = rev(sl))) %>%
    pivot_longer(-from, names_to = "to", values_to = "prob") %>%
    mutate(to    = factor(to, levels = sl),
           group = label)
}

hm <- bind_rows(
  mat_long(P_grp$Constant_Speed, "Constant Speed"),
  mat_long(P_vs,                 "Variable Speed (merged)")
)

p1 <- ggplot(hm, aes(to, from, fill = prob)) +
  geom_tile(colour = "white", linewidth = 0.5) +
  geom_text(aes(label = ifelse(prob > 0.001, sprintf("%.3f", prob), "")),
            size = 2.8, colour = "grey20") +
  facet_wrap(~group, scales = "free") +
  scale_fill_gradient(low = "white", high = "#1f78b4", limits = c(0, 1), name = "P(i→j)") +
  labs(title = "Annual Transition Matrices — Scenario A (Phase B rates)",
       x = "To Stage", y = "From Stage") +
  theme_minimal(base_size = 11) +
  theme(panel.grid = element_blank(), strip.text = element_text(face = "bold"))

ggsave("260330_plot1_transition_heatmap.png", p1, width = 10, height = 4.5, dpi = 150)
cat("\n  Saved: 260330_plot1_transition_heatmap.png\n")

## Plot 2: Forecast stage distributions (A vs B) ───────────────────────────────
p2_data <- fc_all %>%
  pivot_longer(c(prop_A, prop_B), names_to = "scen", values_to = "prop") %>%
  mutate(
    scen  = recode(scen,
                   prop_A = "Scenario A\n(Status Quo)",
                   prop_B = "Scenario B\n(Strict Enforcement)"),
    stage = factor(stage, levels = stage_ord),
    group = recode(group,
                   Constant_Speed = "Constant Speed",
                   Variable_Speed = "Variable Speed (merged)")
  )

p2 <- ggplot(p2_data, aes(x = factor(year), y = prop * 100, fill = stage)) +
  geom_bar(stat = "identity", width = 0.8) +
  facet_grid(group ~ scen) +
  scale_fill_manual(values = stage_col, name = "Emission Stage",
                    drop = FALSE) +
  labs(title = "Forecast Stage Distribution 2025–2030",
       x = "Year", y = "Fleet Share (%)") +
  theme_minimal(base_size = 11) +
  theme(strip.text = element_text(face = "bold"))

ggsave("260330_plot2_forecast_stages.png", p2, width = 11, height = 6, dpi = 150)
cat("  Saved: 260330_plot2_forecast_stages.png\n")

## Plot 3: Historical + forecast compliance trajectory ─────────────────────────
hist_warm <- comp_ts_warm %>%
  filter(status == "Compliant") %>%
  transmute(group = Group, year, pct, src = "Historical (warm)")

hist_cold <- comp_ts_cold %>%
  filter(status == "Compliant") %>%
  transmute(group = Group, year, pct, src = "Historical (cold)")

fc_comp_long <- fc_comp %>%
  pivot_longer(c(pct_A, pct_B), names_to = "scen", values_to = "pct") %>%
  transmute(group, year,  pct,
            src = recode(scen, pct_A = "Scenario A (forecast)", pct_B = "Scenario B (forecast)"))

combo <- bind_rows(hist_warm, hist_cold, fc_comp_long)

grp_col <- c(
  Constant_Speed = "#e41a1c",
  CAZ_Plus       = "#377eb8",
  Rest_of_London = "#4daf4a",
  Variable_Speed = "#984ea3"
)
grp_lbl <- c(
  Constant_Speed = "Constant Speed",
  CAZ_Plus       = "CAZ+",
  Rest_of_London = "Rest of London",
  Variable_Speed = "Variable Speed\n(CAZ+ + RoL merged)"
)
lt_map <- c(
  "Historical (warm)"       = "solid",
  "Historical (cold)"       = "dotted",
  "Scenario A (forecast)"   = "dashed",
  "Scenario B (forecast)"   = "longdash"
)

p3 <- ggplot(combo,
             aes(x = year, y = pct, colour = group, linetype = src,
                 group = interaction(group, src))) +
  geom_vline(xintercept = 2024.5, linetype = "dotted", colour = "grey60", linewidth = 0.7) +
  geom_line(linewidth = 0.9) +
  geom_point(data = combo %>% filter(grepl("Historical", src)), size = 2) +
  scale_colour_manual(values = grp_col, labels = grp_lbl, name = "Group") +
  scale_linetype_manual(values = lt_map, name = "Series") +
  scale_x_continuous(breaks = 2016:2030) +
  scale_y_continuous(limits = c(0, 105), breaks = seq(0, 100, 20)) +
  labs(title = "LEZ Compliance Trajectory 2016–2030",
       subtitle = "Solid = historical warm  |  Dotted = historical cold  |  Dashed = Scen A  |  Longdash = Scen B",
       x = "Year", y = "Compliant Fleet (%)") +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "right")

ggsave("260330_plot3_compliance_trajectory.png", p3, width = 12, height = 5.5, dpi = 150)
cat("  Saved: 260330_plot3_compliance_trajectory.png\n")

## Plot 4: NOx emissions forecast ──────────────────────────────────────────────
p4 <- em_all %>%
  mutate(
    group    = recode(group,
                      Constant_Speed = "Constant Speed",
                      Variable_Speed = "Variable Speed"),
    scenario = recode(scenario,
                      A = "Scenario A (Status Quo)",
                      B = "Scenario B (Strict Enforcement)")
  ) %>%
  ggplot(aes(x = year, y = nox_kg / 1000, colour = group, linetype = scenario)) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2.5) +
  scale_linetype_manual(values = c("Scenario A (Status Quo)"       = "dashed",
                                   "Scenario B (Strict Enforcement)" = "solid")) +
  scale_x_continuous(breaks = 2025:2030) +
  labs(
    title    = "Projected NOx Emissions 2025–2030",
    subtitle = "⚠ PLACEHOLDER emission factors (EMEP/EEA Tier 3) — require expert validation before use",
    x        = "Year",
    y        = "NOx (tonnes / year)",
    colour   = "Group",
    linetype = "Scenario"
  ) +
  theme_minimal(base_size = 11)

ggsave("260330_plot4_nox_forecast.png", p4, width = 10, height = 5, dpi = 150)
cat("  Saved: 260330_plot4_nox_forecast.png\n")

# ── 10. Save ──────────────────────────────────────────────────────────────────
save(
  P_grp, P_vs, P_cs_B, P_vs_B_IV, P_vs_B_V,
  C0, C0_vs, lam_vs,
  fc_cs, fc_vs, fc_all, fc_comp, em_all,
  file = "260330_step5_6_results.RData"
)

cat("\nSaved: 260330_step5_6_results.RData\n")
cat("Objects: P_grp, P_vs, P_cs_B, P_vs_B_IV, P_vs_B_V\n")
cat("         C0, C0_vs, lam_vs\n")
cat("         fc_cs, fc_vs, fc_all, fc_comp, em_all\n")

sink()
