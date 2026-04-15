# 260330_step4_parameter_estimation.R
# Phase 4: Parameter Estimation — Stream A (binary λ_CF, λ_Total), ē, λ_Proactive, kW, EF
# Inputs:  260329_step2_exploratory.RData
# Outputs: 260330_step4_parameters.RData  +  260330_step4_console_output.txt

library(tidyverse)

load("260329_step2_exploratory.RData")

log_con <- file("260330_step4_console_output.txt", open = "wt")
sink(log_con, split = TRUE)

# ── 0. Confirmed Stream B λ_CF values (steps 3b / 3c; lambda_sensitivity_tests.md §31) ──
lambda_cf_B_granular <- list(
  Constant_Speed = list(lambda = 0.3579, se = 0.0671, ci = c(0.2264, 0.4895)),
  CAZ_Plus       = list(lambda = 0.3630, se = 0.0520, ci = c(0.2610, 0.4640)),
  Rest_of_London = list(lambda = 0.2190, se = 0.0480, ci = c(0.1250, 0.3130))
)

# ── 1. Compliance thresholds (Table 1) ───────────────────────────────────────
# Stage integers: I=1, II=2, IIIA=3, IIIB=4, IV=5, V=6, ZE=7
comp_thresh <- list(
  A1 = c(Constant_Speed = 3L, CAZ_Plus = 4L, Rest_of_London = 3L),
  A2 = c(Constant_Speed = 3L, CAZ_Plus = 4L, Rest_of_London = 3L),
  B  = c(Constant_Speed = 6L, CAZ_Plus = 5L, Rest_of_London = 4L)
)

# Phase calendar durations (years) for annualisation
phase_duration_yr <- c(A1 = 3.000, A2 = 1.667, B = 4.339)

groups_var <- c("CAZ_Plus", "Rest_of_London")
groups_all <- c("Constant_Speed", "CAZ_Plus", "Rest_of_London")

# ── 2. Phase B segment definitions (consistent with step3b) ──────────────────
# 1 Sep 2020 – 31 Dec 2024 = 1582 days; 3 equal segments ~527 days
seg_breaks_B <- as.Date(c("2020-09-01", "2022-01-10", "2023-05-22", "2024-12-31"))
seg_mids_B   <- c(2021.389, 2022.832, 2024.278)   # fractional years from step3b

assign_seg <- function(dates) {
  cut(dates, breaks = seg_breaks_B, labels = FALSE, include.lowest = TRUE)
}

# ── 3. Binary WLS helper ─────────────────────────────────────────────────────
# prop_df: time (numeric fractional year), p_c, n_total
# Model:  Δp_c / Δt = λ × (1 − p_c,t)
fit_lambda_binary <- function(prop_df, label) {
  prop_df <- prop_df[order(prop_df$time), ]
  if (nrow(prop_df) < 2) {
    cat(sprintf("  %-52s  SKIPPED (n < 2)\n", label)); return(NULL)
  }
  rows <- lapply(seq_len(nrow(prop_df) - 1), function(i) {
    dt        <- prop_df$time[i + 1] - prop_df$time[i]
    predictor <- 1 - prop_df$p_c[i]
    delta     <- (prop_df$p_c[i + 1] - prop_df$p_c[i]) / dt
    weight    <- prop_df$n_total[i]
    data.frame(predictor = predictor, delta = delta, weight = weight)
  })
  gls_df <- bind_rows(rows)
  if (all(gls_df$predictor == 0) || all(gls_df$delta == 0)) {
    cat(sprintf("  %-52s  λ = 0 (no variation)\n", label))
    return(list(lambda = 0, se = 0, ci = c(0, 0)))
  }
  fit <- lm(delta ~ 0 + predictor, data = gls_df, weights = weight)
  lam <- coef(fit)[["predictor"]]
  se  <- sqrt(vcov(fit)["predictor", "predictor"])
  ci  <- lam + c(-1.96, 1.96) * se
  cat(sprintf("  %-52s  λ = %7.4f  SE = %6.4f  95%% CI [%7.4f, %7.4f]\n",
              label, lam, se, ci[1], ci[2]))
  list(lambda = lam, se = se, ci = ci)
}

# ── Helper: annual proportions (for non-segmented groups) ────────────────────
annual_binary_props <- function(df_sub, thresh_int) {
  df_sub %>%
    mutate(compliant = Initial.Stage >= thresh_int) %>%
    group_by(year) %>%
    summarise(p_c = mean(compliant), n_total = n(), .groups = "drop") %>%
    rename(time = year) %>%
    mutate(time = as.numeric(time))
}

# ── Helper: segment proportions (Phase B, 3-segment) ─────────────────────────
seg_binary_props <- function(df_sub, thresh_int) {
  df_sub %>%
    mutate(seg = assign_seg(Date),
           compliant = Initial.Stage >= thresh_int) %>%
    filter(!is.na(seg)) %>%
    group_by(seg) %>%
    summarise(p_c = mean(compliant), n_total = n(), .groups = "drop") %>%
    mutate(time = seg_mids_B[seg])
}

# ════════════════════════════════════════════════════════════════════════════
# SECTION A: Stream A λ_CF  (binary compliance, cold fleet)
# ════════════════════════════════════════════════════════════════════════════
cat("\n══ STREAM A λ_CF — Binary compliance (cold fleet) ══\n")

## A1/A2 variable speed (CAZ+ + RoL pooled, group-specific thresholds applied) ──
cat("\n─ Phase A1/A2 — Variable Speed pooled (CAZ+ & RoL) ─\n")
cold_A1A2_var <- df_cold %>%
  filter(Phase %in% c("A1", "A2"), Group %in% groups_var) %>%
  mutate(thresh = comp_thresh$A1[Group],
         compliant = Initial.Stage >= thresh) %>%
  group_by(year) %>%
  summarise(p_c = mean(compliant), n_total = n(), .groups = "drop") %>%
  rename(time = year) %>% mutate(time = as.numeric(time))
print(cold_A1A2_var)
lambda_cf_A_A1 <- fit_lambda_binary(cold_A1A2_var, "A1 pooled var-speed")
lambda_cf_A_A2 <- lambda_cf_A_A1   # same estimate; A1/A2 pooled together

## CS Phase A (2017-2020, threshold = IIIA) ───────────────────────────────────
cat("\n─ Constant_Speed Phase A (2017-2020, threshold = IIIA) ─\n")
cold_cs_A <- df_cold %>%
  filter(Group == "Constant_Speed", Phase %in% c("A1", "A2"), year >= 2017) %>%
  annual_binary_props(thresh_int = comp_thresh$A1[["Constant_Speed"]])
print(cold_cs_A)
lambda_cf_A_cs_phA <- fit_lambda_binary(cold_cs_A, "CS Phase A (IIIA threshold)")

## CS Phase B (2021-2023, threshold = V) ──────────────────────────────────────
cat("\n─ Constant_Speed Phase B (2021-2023, threshold = V) ─\n")
cold_cs_B_ann <- df_cold %>%
  filter(Group == "Constant_Speed", Phase == "B", year >= 2021, year <= 2023) %>%
  annual_binary_props(thresh_int = comp_thresh$B[["Constant_Speed"]])
cat("  Cold CS Phase B compliance proportions (V threshold):\n")
print(cold_cs_B_ann)
# Stage V absent in cold CS 2021-2023 → λ_CF = 0 by inspection
lambda_cf_A_cs_phB <- list(lambda = 0, se = 0, ci = c(0, 0))
cat("  CS Phase B (V threshold): λ = 0.0000 (no Stage V in cold fleet 2021-2023)\n")

## CAZ+ Phase B (3-segment, threshold = IV) ───────────────────────────────────
cat("\n─ CAZ_Plus Phase B — 3-segment (threshold = IV) ─\n")
cold_caz_B_seg <- df_cold %>%
  filter(Group == "CAZ_Plus", Phase == "B") %>%
  seg_binary_props(thresh_int = comp_thresh$B[["CAZ_Plus"]])
print(cold_caz_B_seg)
lambda_cf_A_caz_phB <- fit_lambda_binary(cold_caz_B_seg, "CAZ+ Phase B 3-seg (IV threshold)")

## RoL Phase B (3-segment, threshold = IIIB) ──────────────────────────────────
cat("\n─ Rest_of_London Phase B — 3-segment (threshold = IIIB) ─\n")
cold_rol_B_seg <- df_cold %>%
  filter(Group == "Rest_of_London", Phase == "B") %>%
  seg_binary_props(thresh_int = comp_thresh$B[["Rest_of_London"]])
print(cold_rol_B_seg)
lambda_cf_A_rol_phB <- fit_lambda_binary(cold_rol_B_seg, "RoL Phase B 3-seg (IIIB threshold)")

# Collect Stream A λ_CF
lambda_cf_streamA <- list(
  A1_var_pooled  = lambda_cf_A_A1,
  A2_var_pooled  = lambda_cf_A_A2,
  CS_phaseA      = lambda_cf_A_cs_phA,
  CS_phaseB      = lambda_cf_A_cs_phB,
  CAZ_phaseB     = lambda_cf_A_caz_phB,
  RoL_phaseB     = lambda_cf_A_rol_phB
)

# ════════════════════════════════════════════════════════════════════════════
# SECTION B: Stream A λ_Total  (binary compliance WLS, warm fleet)
# ════════════════════════════════════════════════════════════════════════════
cat("\n══ STREAM A λ_Total — Binary compliance (warm fleet) ══\n")

## A1/A2 variable speed pooled ─────────────────────────────────────────────
cat("\n─ Phase A1/A2 — Variable Speed pooled ─\n")
warm_A1A2_var <- df_warm %>%
  filter(Phase %in% c("A1", "A2"), Group %in% groups_var) %>%
  mutate(thresh = comp_thresh$A1[Group],
         compliant = Initial.Stage >= thresh) %>%
  group_by(year) %>%
  summarise(p_c = mean(compliant), n_total = n(), .groups = "drop") %>%
  rename(time = year) %>% mutate(time = as.numeric(time))
print(warm_A1A2_var)
lambda_tot_A_A1 <- fit_lambda_binary(warm_A1A2_var, "A1/A2 warm var-speed pooled")
lambda_tot_A_A2 <- lambda_tot_A_A1

## CS Phase A (warm) ───────────────────────────────────────────────────────
cat("\n─ Constant_Speed Phase A (warm, threshold = IIIA) ─\n")
warm_cs_A <- df_warm %>%
  filter(Group == "Constant_Speed", Phase %in% c("A1", "A2"), year >= 2017) %>%
  annual_binary_props(thresh_int = comp_thresh$A1[["Constant_Speed"]])
print(warm_cs_A)
lambda_tot_A_cs_phA <- fit_lambda_binary(warm_cs_A, "CS Phase A warm (IIIA threshold)")

## CS Phase B (warm, threshold = V) ───────────────────────────────────────
cat("\n─ Constant_Speed Phase B (warm, threshold = V) ─\n")
warm_cs_B_ann <- df_warm %>%
  filter(Group == "Constant_Speed", Phase == "B", year >= 2021) %>%
  annual_binary_props(thresh_int = comp_thresh$B[["Constant_Speed"]])
print(warm_cs_B_ann)
lambda_tot_A_cs_phB <- fit_lambda_binary(warm_cs_B_ann, "CS Phase B warm (V threshold)")

## CAZ+ Phase B (warm, 3-segment, threshold = IV) ─────────────────────────
cat("\n─ CAZ_Plus Phase B warm — 3-segment (threshold = IV) ─\n")
warm_caz_B_seg <- df_warm %>%
  filter(Group == "CAZ_Plus", Phase == "B") %>%
  seg_binary_props(thresh_int = comp_thresh$B[["CAZ_Plus"]])
print(warm_caz_B_seg)
lambda_tot_A_caz_phB <- fit_lambda_binary(warm_caz_B_seg, "CAZ+ Phase B warm 3-seg (IV threshold)")

## RoL Phase B (warm, 3-segment, threshold = IIIB) ────────────────────────
cat("\n─ Rest_of_London Phase B warm — 3-segment (threshold = IIIB) ─\n")
warm_rol_B_seg <- df_warm %>%
  filter(Group == "Rest_of_London", Phase == "B") %>%
  seg_binary_props(thresh_int = comp_thresh$B[["Rest_of_London"]])
print(warm_rol_B_seg)
lambda_tot_A_rol_phB <- fit_lambda_binary(warm_rol_B_seg, "RoL Phase B warm 3-seg (IIIB threshold)")

lambda_total_streamA <- list(
  A1_var_pooled  = lambda_tot_A_A1,
  A2_var_pooled  = lambda_tot_A_A2,
  CS_phaseA      = lambda_tot_A_cs_phA,
  CS_phaseB      = lambda_tot_A_cs_phB,
  CAZ_phaseB     = lambda_tot_A_caz_phB,
  RoL_phaseB     = lambda_tot_A_rol_phB
)

# ════════════════════════════════════════════════════════════════════════════
# SECTION C: ē — Enforcement Rate
# ════════════════════════════════════════════════════════════════════════════
# Numerator:   warm records where Initial.Stage < threshold (non-compliant at audit)
#              AND Final.Stage is non-NA (audit record is complete).
#              These machines were under active LEZ enforcement obligation.
# Denominator: total warm fleet per group × phase
# Annualisation note: n_enf / n_tot is already an average annual proportion
#   (non-compliant visits / total visits across audit years in the phase).
#   Do NOT divide by phase duration — that would deflate a per-year rate.
cat("\n══ ENFORCEMENT RATE (ē) ══\n")

e_bar_rows <- bind_rows(lapply(groups_all, function(grp) {
  bind_rows(lapply(c("A1", "A2", "B"), function(ph) {
    thresh <- comp_thresh[[ph]][[grp]]
    sub    <- df_warm %>% filter(Group == grp, Phase == ph)
    n_tot  <- nrow(sub)
    if (n_tot == 0) return(NULL)
    n_enf  <- sub %>%
      filter(Initial.Stage < thresh, !is.na(Final.Stage)) %>%
      nrow()
    # Flag CS Phase B: near-universal non-compliance under Stage V mandate
    note <- if (grp == "Constant_Speed" && ph == "B")
      " [CS Phase B: ē≈1 expected — Stage V threshold; all compliance enforcement-driven]" else ""
    data.frame(Group = grp, Phase = ph,
               n_warm     = n_tot,
               n_enforced = n_enf,
               e_bar      = n_enf / n_tot,   # annual average proportion
               note       = note,
               stringsAsFactors = FALSE)
  }))
}))

print(e_bar_rows[, c("Group","Phase","n_warm","n_enforced","e_bar","note")])

e_bar <- e_bar_rows %>%
  mutate(key = paste(Group, Phase, sep = "_")) %>%
  { setNames(.$e_bar, .$key) }

# ════════════════════════════════════════════════════════════════════════════
# SECTION D: λ_Proactive  =  λ_Total − λ_CF − ē  (floored at 0)
# ════════════════════════════════════════════════════════════════════════════
cat("\n══ λ_PROACTIVE (Stream A binary) ══\n")

# Fleet-size-weighted ē for pooled cases
wt_e <- function(keys) {
  rows <- e_bar_rows[paste(e_bar_rows$Group, e_bar_rows$Phase, sep="_") %in% keys, ]
  sum(rows$e_bar * rows$n_warm) / sum(rows$n_warm)
}

proactive_cases <- list(
  list(key = "A1/A2 var-speed pooled", cf = lambda_cf_streamA$A1_var_pooled,
       tot = lambda_total_streamA$A1_var_pooled,
       e   = wt_e(c("CAZ_Plus_A1","CAZ_Plus_A2","Rest_of_London_A1","Rest_of_London_A2"))),
  list(key = "CS Phase A",    cf = lambda_cf_streamA$CS_phaseA,
       tot = lambda_total_streamA$CS_phaseA,
       e   = wt_e(c("Constant_Speed_A1","Constant_Speed_A2"))),
  list(key = "CS Phase B",    cf = lambda_cf_streamA$CS_phaseB,
       tot = lambda_total_streamA$CS_phaseB,
       e   = e_bar["Constant_Speed_B"]),
  list(key = "CAZ+ Phase B",  cf = lambda_cf_streamA$CAZ_phaseB,
       tot = lambda_total_streamA$CAZ_phaseB,
       e   = e_bar["CAZ_Plus_B"]),
  list(key = "RoL Phase B",   cf = lambda_cf_streamA$RoL_phaseB,
       tot = lambda_total_streamA$RoL_phaseB,
       e   = e_bar["Rest_of_London_B"])
)

lambda_proactive_streamA <- lapply(proactive_cases, function(x) {
  lam_tot <- if (is.null(x$tot)) NA_real_ else x$tot$lambda
  lam_cf  <- if (is.null(x$cf))  NA_real_ else x$cf$lambda
  e_val   <- if (is.null(x$e) || is.na(x$e)) 0 else unname(x$e)
  raw  <- lam_tot - lam_cf - e_val
  proc <- max(raw, 0)
  flag <- if (!is.na(raw) && raw < 0) " [floored]" else ""
  cat(sprintf("  %-28s  λ_Tot=%7.4f  λ_CF=%7.4f  ē=%7.4f  →  λ_Pro=%7.4f%s\n",
              x$key, lam_tot, lam_cf, e_val, proc, flag))
  list(key = x$key, lambda_total = lam_tot, lambda_cf = lam_cf,
       e_bar = e_val, lambda_proactive_raw = raw, lambda_proactive = proc)
})

# ════════════════════════════════════════════════════════════════════════════
# SECTION E: kW per Group × Stage  (warm fleet, missing kW excluded)
# ════════════════════════════════════════════════════════════════════════════
cat("\n══ kW MEAN PER GROUP × STAGE (warm fleet) ══\n")
kw_by_group_stage <- df_warm %>%
  filter(!kW_missing) %>%
  group_by(Group, Initial.Stage.raw) %>%
  summarise(kw_mean = round(mean(kW), 1),
            n       = n(),
            .groups = "drop") %>%
  arrange(Group, Initial.Stage.raw)
print(kw_by_group_stage, n = 30)

# ════════════════════════════════════════════════════════════════════════════
# SECTION F: Emission Factors  — PLACEHOLDER
# ════════════════════════════════════════════════════════════════════════════
# !!! PLACEHOLDER — EMEP/EEA Tier 3 NOx g/kWh estimates.
# !!! Source: Ntziachristos & Samaras (2019) Table 3-95 (non-road mobile machinery).
# !!! These values require expert review and replacement with project-specific
# !!! engine category and power-band weighted averages before final reporting.
ef_nox_gkwh <- c(I = 10.0, II = 7.0, IIIA = 5.0, IIIB = 3.5, IV = 2.0, V = 0.4, ZE = 0.0)
cat("\n══ EMISSION FACTORS (PLACEHOLDER — NOx g/kWh) ══\n")
cat("  Stage:  ", paste(names(ef_nox_gkwh), collapse = "    "), "\n")
cat("  EF:     ", paste(ef_nox_gkwh, collapse = "     "), "\n")
cat("  *** PLACEHOLDERS — require expert validation before use ***\n")

# ════════════════════════════════════════════════════════════════════════════
# SECTION G: Compliance proportion plots (cold & warm, per group, over time)
# ════════════════════════════════════════════════════════════════════════════
cat("\n══ COMPLIANCE PLOTS ══\n")

# Apply phase-appropriate compliance threshold to every record
make_compliance_ts <- function(df_sub) {
  df_sub %>%
    mutate(thresh    = unname(mapply(function(ph, grp) comp_thresh[[ph]][[grp]],
                                    Phase, Group)),
           compliant = Initial.Stage >= thresh,
           status    = if_else(compliant, "Compliant", "Non-Compliant")) %>%
    group_by(Group, year, status) %>%
    summarise(n = n(), .groups = "drop") %>%
    group_by(Group, year) %>%
    mutate(pct = 100 * n / sum(n)) %>%
    ungroup() %>%
    mutate(status = factor(status, levels = c("Non-Compliant", "Compliant")))
}

comp_ts_warm <- make_compliance_ts(df_warm)
comp_ts_cold <- make_compliance_ts(df_cold)

# Phase boundary x-intercepts for annotation
phase_bounds <- data.frame(x = c(2019, 2020.667))  # A1/A2: 2019; A2/B: Sep 2020

plot_compliance <- function(comp_ts, fleet_label) {
  ggplot(comp_ts, aes(x = year, y = pct, fill = status)) +
    geom_bar(stat = "identity", width = 0.85) +
    geom_vline(data = phase_bounds, aes(xintercept = x),
               linetype = "dashed", colour = "grey40", linewidth = 0.4) +
    facet_wrap(~Group, ncol = 3) +
    scale_fill_manual(values = c("Non-Compliant" = "#d73027",
                                 "Compliant"     = "#1a9850"),
                      name = NULL) +
    scale_x_continuous(breaks = 2016:2024,
                       labels = function(x) substr(x, 3, 4)) +
    scale_y_continuous(limits = c(0, 100), expand = c(0, 0)) +
    labs(title    = paste0("Binary compliance — ", fleet_label, " fleet"),
         subtitle = "Dashed lines: phase boundaries (A1/A2: Jan 2019; A2/B: Sep 2020)",
         x = "Year", y = "% of fleet") +
    theme_minimal(base_size = 11) +
    theme(legend.position   = "bottom",
          panel.grid.minor  = element_blank(),
          axis.text.x       = element_text(angle = 45, hjust = 1),
          strip.text        = element_text(face = "bold"))
}

p_comp_warm <- plot_compliance(comp_ts_warm, "warm")
p_comp_cold <- plot_compliance(comp_ts_cold, "cold")

ggsave("260330_compliance_warm.png", p_comp_warm, width = 11, height = 4, dpi = 150)
ggsave("260330_compliance_cold.png", p_comp_cold, width = 11, height = 4, dpi = 150)
cat("  Saved: 260330_compliance_warm.png\n")
cat("  Saved: 260330_compliance_cold.png\n")

# ════════════════════════════════════════════════════════════════════════════
# SAVE
# ════════════════════════════════════════════════════════════════════════════
save(lambda_cf_B_granular, lambda_cf_streamA, lambda_total_streamA,
     e_bar_rows, e_bar,
     lambda_proactive_streamA,
     comp_thresh, phase_duration_yr,
     seg_breaks_B, seg_mids_B,
     kw_by_group_stage, ef_nox_gkwh,
     comp_ts_warm, comp_ts_cold,
     file = "260330_step4_parameters.RData")

cat("\nSaved: 260330_step4_parameters.RData\n")
cat("Objects: lambda_cf_B_granular, lambda_cf_streamA, lambda_total_streamA,\n")
cat("         e_bar_rows, e_bar, lambda_proactive_streamA,\n")
cat("         comp_thresh, phase_duration_yr, seg_breaks_B, seg_mids_B,\n")
cat("         kw_by_group_stage, ef_nox_gkwh, comp_ts_warm, comp_ts_cold\n")

sink()
close(log_con)
cat("Log written to: 260330_step4_console_output.txt\n")
