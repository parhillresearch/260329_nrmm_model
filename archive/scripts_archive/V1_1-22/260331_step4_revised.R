# 260331_step4_revised.R
# Phase 4 REVISED: Parameter Estimation — v1.17 specification
#   - ē from MC-field, ALL records (cold + warm)
#   - λ_Policy from COMPLIANT-WARM subset only
#   - λ_Proactive = λ_Policy − λ_CF (ē not subtracted)
# Inputs:  260329_step1_ingestion.RData  (full columns required)
# Outputs: 260331_step4_revised_parameters.RData + 260331_step4_revised_console.txt

library(tidyverse)

load("260329_step1_ingestion.RData")   # df, df_warm, df_cold (full columns)

log_con <- file("260331_step4_revised_console.txt", open = "wt")
sink(log_con, split = TRUE)

# ── 0. Add year + normalise MC field ─────────────────────────────────────────
for (obj in c("df", "df_warm", "df_cold")) {
  x <- get(obj)
  x$year <- as.integer(format(x$Date, "%Y"))
  x$mc_compliant <- tolower(trimws(x$Initial.Machinery.Compliance)) == "compliant"
  assign(obj, x)
}

cat("MC field coverage:\n")
cat(sprintf("  df:      n=%d  compliant=%d  non-compliant=%d  other=%d\n",
            nrow(df),      sum(df$mc_compliant),      sum(!df$mc_compliant),
            sum(!tolower(trimws(df$Initial.Machinery.Compliance)) %in% c("compliant","non-compliant"))))
cat(sprintf("  df_warm: n=%d  compliant=%d  non-compliant=%d\n",
            nrow(df_warm), sum(df_warm$mc_compliant), sum(!df_warm$mc_compliant)))
cat(sprintf("  df_cold: n=%d  compliant=%d  non-compliant=%d\n",
            nrow(df_cold), sum(df_cold$mc_compliant), sum(!df_cold$mc_compliant)))

# ── 0. Confirmed Stream B λ_CF (steps 3b/3c) ─────────────────────────────────
lambda_cf_B_granular <- list(
  Constant_Speed = list(lambda = 0.3579, se = 0.0671, ci = c(0.2264, 0.4895)),
  CAZ_Plus       = list(lambda = 0.3630, se = 0.0520, ci = c(0.2610, 0.4640)),
  Rest_of_London = list(lambda = 0.2190, se = 0.0480, ci = c(0.1250, 0.3130))
)

# ── 1. Constants ──────────────────────────────────────────────────────────────
comp_thresh <- list(
  A1 = c(Constant_Speed = 3L, CAZ_Plus = 4L, Rest_of_London = 3L),
  A2 = c(Constant_Speed = 3L, CAZ_Plus = 4L, Rest_of_London = 3L),
  B  = c(Constant_Speed = 6L, CAZ_Plus = 5L, Rest_of_London = 4L)
)
phase_duration_yr <- c(A1 = 3.000, A2 = 1.667, B = 4.339)
groups_var <- c("CAZ_Plus", "Rest_of_London")
groups_all <- c("Constant_Speed", "CAZ_Plus", "Rest_of_London")

seg_breaks_B <- as.Date(c("2020-09-01", "2022-01-10", "2023-05-22", "2024-12-31"))
seg_mids_B   <- c(2021.389, 2022.832, 2024.278)

assign_seg <- function(dates) {
  cut(dates, breaks = seg_breaks_B, labels = FALSE, include.lowest = TRUE)
}

# ── 2. WLS helpers ────────────────────────────────────────────────────────────
fit_lambda_binary <- function(prop_df, label) {
  prop_df <- prop_df[order(prop_df$time), ]
  if (nrow(prop_df) < 2) {
    cat(sprintf("  %-60s  SKIPPED (n < 2)\n", label)); return(NULL)
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
    cat(sprintf("  %-60s  λ = 0 (no variation)\n", label))
    return(list(lambda = 0, se = 0, ci = c(0, 0)))
  }
  fit <- lm(delta ~ 0 + predictor, data = gls_df, weights = weight)
  lam <- coef(fit)[["predictor"]]
  se  <- sqrt(vcov(fit)["predictor", "predictor"])
  ci  <- lam + c(-1.96, 1.96) * se
  cat(sprintf("  %-60s  λ = %7.4f  SE = %6.4f  95%% CI [%7.4f, %7.4f]\n",
              label, lam, se, ci[1], ci[2]))
  list(lambda = lam, se = se, ci = ci)
}

annual_binary_props <- function(df_sub, thresh_int) {
  df_sub %>%
    mutate(compliant = Initial.Stage >= thresh_int) %>%
    group_by(year) %>%
    summarise(p_c = mean(compliant), n_total = n(), .groups = "drop") %>%
    rename(time = year) %>% mutate(time = as.numeric(time))
}

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
# SECTION A: λ_CF (binary, cold fleet) — UNCHANGED from v1.16
# ════════════════════════════════════════════════════════════════════════════
cat("\n══ STREAM A λ_CF — Binary compliance (cold fleet) ══\n")

cat("\n─ Phase A1/A2 — Variable Speed pooled ─\n")
cold_A1A2_var <- df_cold %>%
  filter(Phase %in% c("A1","A2"), Group %in% groups_var) %>%
  mutate(thresh = comp_thresh$A1[Group], compliant = Initial.Stage >= thresh) %>%
  group_by(year) %>%
  summarise(p_c = mean(compliant), n_total = n(), .groups = "drop") %>%
  rename(time = year) %>% mutate(time = as.numeric(time))
print(cold_A1A2_var)
lambda_cf_A_A1 <- fit_lambda_binary(cold_A1A2_var, "A1/A2 cold var-speed pooled")
lambda_cf_A_A2 <- lambda_cf_A_A1

cat("\n─ Constant_Speed Phase A (2017-2020, threshold = IIIA) ─\n")
cold_cs_A <- df_cold %>%
  filter(Group == "Constant_Speed", Phase %in% c("A1","A2"), year >= 2017) %>%
  annual_binary_props(thresh_int = comp_thresh$A1[["Constant_Speed"]])
print(cold_cs_A)
lambda_cf_A_cs_phA <- fit_lambda_binary(cold_cs_A, "CS Phase A cold (IIIA threshold)")

cat("\n─ Constant_Speed Phase B (2021-2023, threshold = V) ─\n")
cold_cs_B_ann <- df_cold %>%
  filter(Group == "Constant_Speed", Phase == "B", year >= 2021, year <= 2023) %>%
  annual_binary_props(thresh_int = comp_thresh$B[["Constant_Speed"]])
print(cold_cs_B_ann)
lambda_cf_A_cs_phB <- list(lambda = 0, se = 0, ci = c(0, 0))
cat("  CS Phase B (V threshold): λ = 0.0000 (no Stage V in cold CS 2021-2023)\n")

cat("\n─ CAZ+ Phase B — 3-segment (threshold = IV) ─\n")
cold_caz_B_seg <- df_cold %>%
  filter(Group == "CAZ_Plus", Phase == "B") %>%
  seg_binary_props(thresh_int = comp_thresh$B[["CAZ_Plus"]])
print(cold_caz_B_seg)
lambda_cf_A_caz_phB <- fit_lambda_binary(cold_caz_B_seg, "CAZ+ Phase B cold 3-seg (IV threshold)")

cat("\n─ Rest_of_London Phase B — 3-segment (threshold = IIIB) ─\n")
cold_rol_B_seg <- df_cold %>%
  filter(Group == "Rest_of_London", Phase == "B") %>%
  seg_binary_props(thresh_int = comp_thresh$B[["Rest_of_London"]])
print(cold_rol_B_seg)
lambda_cf_A_rol_phB <- fit_lambda_binary(cold_rol_B_seg, "RoL Phase B cold 3-seg (IIIB threshold)")

lambda_cf_streamA <- list(
  A1_var_pooled = lambda_cf_A_A1,
  A2_var_pooled = lambda_cf_A_A2,
  CS_phaseA     = lambda_cf_A_cs_phA,
  CS_phaseB     = lambda_cf_A_cs_phB,
  CAZ_phaseB    = lambda_cf_A_caz_phB,
  RoL_phaseB    = lambda_cf_A_rol_phB
)

# ════════════════════════════════════════════════════════════════════════════
# SECTION B: λ_Policy (binary WLS, COMPLIANT-WARM subset only)
# v1.17: Only warm records where mc_compliant == TRUE
# Rationale: isolates voluntary policy response; excludes enforcement track
# ════════════════════════════════════════════════════════════════════════════
cat("\n══ STREAM A λ_Policy — Binary compliance (compliant-warm subset) ══\n")
cat("   [Warm records where Initial.Machinery.Compliance == 'compliant' only]\n")

df_warm_pol <- df_warm %>% filter(mc_compliant)   # self-compliant at audit

cat(sprintf("\n  Compliant-warm subset: n = %d (of %d warm total, %.1f%%)\n",
            nrow(df_warm_pol), nrow(df_warm),
            100 * nrow(df_warm_pol) / nrow(df_warm)))

## A1/A2 variable speed pooled
cat("\n─ Phase A1/A2 — Variable Speed pooled (compliant-warm) ─\n")
pol_A1A2_var <- df_warm_pol %>%
  filter(Phase %in% c("A1","A2"), Group %in% groups_var) %>%
  mutate(thresh = comp_thresh$A1[Group], compliant = Initial.Stage >= thresh) %>%
  group_by(year) %>%
  summarise(p_c = mean(compliant), n_total = n(), .groups = "drop") %>%
  rename(time = year) %>% mutate(time = as.numeric(time))
print(pol_A1A2_var)
lambda_pol_A_A1 <- fit_lambda_binary(pol_A1A2_var, "A1/A2 compliant-warm var-speed pooled")
lambda_pol_A_A2 <- lambda_pol_A_A1

## CS Phase A
cat("\n─ Constant_Speed Phase A (compliant-warm, threshold = IIIA) ─\n")
pol_cs_A <- df_warm_pol %>%
  filter(Group == "Constant_Speed", Phase %in% c("A1","A2"), year >= 2017) %>%
  annual_binary_props(thresh_int = comp_thresh$A1[["Constant_Speed"]])
print(pol_cs_A)
lambda_pol_A_cs_phA <- fit_lambda_binary(pol_cs_A, "CS Phase A compliant-warm (IIIA threshold)")

## CS Phase B
cat("\n─ Constant_Speed Phase B (compliant-warm, threshold = V) ─\n")
pol_cs_B_ann <- df_warm_pol %>%
  filter(Group == "Constant_Speed", Phase == "B", year >= 2021) %>%
  annual_binary_props(thresh_int = comp_thresh$B[["Constant_Speed"]])
print(pol_cs_B_ann)
lambda_pol_A_cs_phB <- fit_lambda_binary(pol_cs_B_ann, "CS Phase B compliant-warm (V threshold)")

## CAZ+ Phase B
cat("\n─ CAZ+ Phase B (compliant-warm, 3-segment, threshold = IV) ─\n")
pol_caz_B_seg <- df_warm_pol %>%
  filter(Group == "CAZ_Plus", Phase == "B") %>%
  seg_binary_props(thresh_int = comp_thresh$B[["CAZ_Plus"]])
print(pol_caz_B_seg)
lambda_pol_A_caz_phB <- fit_lambda_binary(pol_caz_B_seg, "CAZ+ Phase B compliant-warm 3-seg (IV threshold)")

## RoL Phase B
cat("\n─ Rest_of_London Phase B (compliant-warm, 3-segment, threshold = IIIB) ─\n")
pol_rol_B_seg <- df_warm_pol %>%
  filter(Group == "Rest_of_London", Phase == "B") %>%
  seg_binary_props(thresh_int = comp_thresh$B[["Rest_of_London"]])
print(pol_rol_B_seg)
lambda_pol_A_rol_phB <- fit_lambda_binary(pol_rol_B_seg, "RoL Phase B compliant-warm 3-seg (IIIB threshold)")

lambda_policy_streamA <- list(
  A1_var_pooled = lambda_pol_A_A1,
  A2_var_pooled = lambda_pol_A_A2,
  CS_phaseA     = lambda_pol_A_cs_phA,
  CS_phaseB     = lambda_pol_A_cs_phB,
  CAZ_phaseB    = lambda_pol_A_caz_phB,
  RoL_phaseB    = lambda_pol_A_rol_phB
)

# ════════════════════════════════════════════════════════════════════════════
# SECTION C: ē — Enforcement Rate (v1.18)
# Numerator:   ALL records (cold + warm) where Initial.Stage < compliance threshold
# Denominator: ALL records per group × phase
# Rationale: only Stage < threshold (emissions not OK) drives Stage-transition
#   enforcement (removal/replacement). Cold non-compliance is largely structural
#   (unregistered site = first audit), which is a registration event producing
#   no Stage change. Stage-threshold filter correctly isolates emissions enforcement.
# ════════════════════════════════════════════════════════════════════════════
cat("\n══ ENFORCEMENT RATE (ē) — v1.18: Stage-threshold, all records ══\n")
cat("   [Initial.Stage < threshold / n_all per group × phase]\n\n")

e_bar_rows <- bind_rows(lapply(groups_all, function(grp) {
  bind_rows(lapply(c("A1","A2","B"), function(ph) {
    thresh   <- comp_thresh[[ph]][[grp]]
    sub_all  <- df %>% filter(Group == grp, Phase == ph)
    n_tot    <- nrow(sub_all)
    if (n_tot == 0) return(NULL)
    n_nc     <- sum(sub_all$Initial.Stage < thresh, na.rm = TRUE)
    n_cold   <- sum(sub_all$Cold_Engaged)
    n_warm   <- sum(!sub_all$Cold_Engaged)
    data.frame(Group = grp, Phase = ph,
               n_all      = n_tot,
               n_cold     = n_cold,
               n_warm     = n_warm,
               n_stage_nc = n_nc,
               e_bar      = n_nc / n_tot,
               stringsAsFactors = FALSE)
  }))
}))

print(e_bar_rows)

cat("\nStage non-compliance rate by fleet type (pooled across groups/phases):\n")
df_thresh <- df %>%
  mutate(thresh = unname(mapply(function(ph, grp) comp_thresh[[ph]][[grp]], Phase, Group)),
         stage_nc = Initial.Stage < thresh)
cat(sprintf("  All records:  %.1f%%\n", 100 * mean(df_thresh$stage_nc, na.rm = TRUE)))
cat(sprintf("  Warm only:    %.1f%%\n", 100 * mean(df_thresh$stage_nc[!df_thresh$Cold_Engaged], na.rm = TRUE)))
cat(sprintf("  Cold only:    %.1f%%\n", 100 * mean(df_thresh$stage_nc[df_thresh$Cold_Engaged],  na.rm = TRUE)))

e_bar <- e_bar_rows %>%
  mutate(key = paste(Group, Phase, sep = "_")) %>%
  { setNames(.$e_bar, .$key) }

# ════════════════════════════════════════════════════════════════════════════
# SECTION D: λ_Proactive = λ_Policy − λ_CF   (floored at 0)
# v1.17: ē NOT subtracted — excluded from estimation by construction
# ════════════════════════════════════════════════════════════════════════════
cat("\n══ λ_PROACTIVE = λ_Policy − λ_CF (floored at 0) ══\n")
cat("   [ē not subtracted: compliant-warm subset already excludes enforcement track]\n\n")

proactive_cases <- list(
  list(key = "A1/A2 var-speed pooled",
       cf  = lambda_cf_streamA$A1_var_pooled,
       pol = lambda_policy_streamA$A1_var_pooled),
  list(key = "CS Phase A",
       cf  = lambda_cf_streamA$CS_phaseA,
       pol = lambda_policy_streamA$CS_phaseA),
  list(key = "CS Phase B",
       cf  = lambda_cf_streamA$CS_phaseB,
       pol = lambda_policy_streamA$CS_phaseB),
  list(key = "CAZ+ Phase B",
       cf  = lambda_cf_streamA$CAZ_phaseB,
       pol = lambda_policy_streamA$CAZ_phaseB),
  list(key = "RoL Phase B",
       cf  = lambda_cf_streamA$RoL_phaseB,
       pol = lambda_policy_streamA$RoL_phaseB)
)

lambda_proactive_streamA <- lapply(proactive_cases, function(x) {
  lam_pol <- if (is.null(x$pol)) NA_real_ else x$pol$lambda
  lam_cf  <- if (is.null(x$cf))  NA_real_ else x$cf$lambda
  raw     <- lam_pol - lam_cf
  proc    <- max(raw, 0, na.rm = TRUE)
  flag    <- if (!is.na(raw) && raw < 0) " [floored]" else ""
  cat(sprintf("  %-28s  λ_Policy=%7.4f  λ_CF=%7.4f  →  λ_Proactive=%7.4f%s\n",
              x$key, lam_pol, lam_cf, proc, flag))
  list(key = x$key, lambda_policy = lam_pol, lambda_cf = lam_cf,
       lambda_proactive_raw = raw, lambda_proactive = proc)
})

# ── Summary table including ē for context ──────────────────────────────────
cat("\n── Summary: λ_Policy / λ_CF / ē / λ_Proactive ──\n")
wt_e <- function(keys) {
  rows <- e_bar_rows[paste(e_bar_rows$Group, e_bar_rows$Phase, sep="_") %in% keys, ]
  if (nrow(rows) == 0) return(NA_real_)
  sum(rows$e_bar * rows$n_all) / sum(rows$n_all)
}

e_summary <- c(
  wt_e(c("CAZ_Plus_A1","CAZ_Plus_A2","Rest_of_London_A1","Rest_of_London_A2")),
  wt_e(c("Constant_Speed_A1","Constant_Speed_A2")),
  unname(e_bar["Constant_Speed_B"]),
  unname(e_bar["CAZ_Plus_B"]),
  unname(e_bar["Rest_of_London_B"])
)

for (i in seq_along(lambda_proactive_streamA)) {
  x <- lambda_proactive_streamA[[i]]
  cat(sprintf("  %-28s  ē=%6.3f  λ_Pol=%6.3f  λ_CF=%6.3f  λ_Pro=%6.3f\n",
              x$key, e_summary[i], x$lambda_policy, x$lambda_cf, x$lambda_proactive))
}

# ════════════════════════════════════════════════════════════════════════════
# SECTION E: kW per Group × Stage (warm fleet)
# ════════════════════════════════════════════════════════════════════════════
cat("\n══ kW MEAN PER GROUP × STAGE (warm fleet) ══\n")
kw_by_group_stage <- df_warm %>%
  filter(!kW_missing) %>%
  group_by(Group, Initial.Stage.raw) %>%
  summarise(kw_mean = round(mean(kW), 1), n = n(), .groups = "drop") %>%
  arrange(Group, Initial.Stage.raw)
print(kw_by_group_stage, n = 30)

# ════════════════════════════════════════════════════════════════════════════
# SECTION F: Emission Factors — PLACEHOLDER
# ════════════════════════════════════════════════════════════════════════════
ef_nox_gkwh <- c(I = 10.0, II = 7.0, IIIA = 5.0, IIIB = 3.5, IV = 2.0, V = 0.4, ZE = 0.0)
cat("\n══ EMISSION FACTORS (PLACEHOLDER — NOx g/kWh) ══\n")
cat("  Stage:  ", paste(names(ef_nox_gkwh), collapse = "    "), "\n")
cat("  EF:     ", paste(ef_nox_gkwh, collapse = "     "), "\n")
cat("  *** PLACEHOLDERS — require expert validation ***\n")

# ════════════════════════════════════════════════════════════════════════════
# SECTION G: Compliance plots
# ════════════════════════════════════════════════════════════════════════════
cat("\n══ COMPLIANCE PLOTS ══\n")

make_compliance_ts <- function(df_sub) {
  df_sub %>%
    mutate(thresh    = unname(mapply(function(ph, grp) comp_thresh[[ph]][[grp]],
                                    Phase, Group)),
           compliant = Initial.Stage >= thresh,
           status    = if (TRUE) ifelse(compliant, "Compliant", "Non-Compliant") else NA) %>%
    group_by(Group, year, status) %>%
    summarise(n = n(), .groups = "drop") %>%
    group_by(Group, year) %>%
    mutate(pct = 100 * n / sum(n)) %>%
    ungroup() %>%
    mutate(status = factor(status, levels = c("Non-Compliant","Compliant")))
}

comp_ts_warm      <- make_compliance_ts(df_warm)
comp_ts_cold      <- make_compliance_ts(df_cold)
comp_ts_warm_pol  <- make_compliance_ts(df_warm_pol)

phase_bounds <- data.frame(x = c(2019, 2020.667))

plot_compliance <- function(comp_ts, fleet_label) {
  ggplot(comp_ts, aes(x = year, y = pct, fill = status)) +
    geom_bar(stat = "identity", width = 0.85) +
    geom_vline(data = phase_bounds, aes(xintercept = x),
               linetype = "dashed", colour = "grey40", linewidth = 0.4) +
    facet_wrap(~Group, ncol = 3) +
    scale_fill_manual(values = c("Non-Compliant" = "#d73027", "Compliant" = "#1a9850"),
                      name = NULL) +
    scale_x_continuous(breaks = 2016:2024, labels = function(x) substr(x, 3, 4)) +
    scale_y_continuous(limits = c(0, 100), expand = c(0, 0)) +
    labs(title    = paste0("Binary compliance — ", fleet_label),
         subtitle = "Dashed: phase boundaries (Jan 2019; Sep 2020)",
         x = "Year", y = "% of fleet") +
    theme_minimal(base_size = 11) +
    theme(legend.position = "bottom", panel.grid.minor = element_blank(),
          axis.text.x = element_text(angle = 45, hjust = 1),
          strip.text  = element_text(face = "bold"))
}

ggsave("260331_compliance_warm.png",
       plot_compliance(comp_ts_warm, "warm fleet (all)"), width = 11, height = 4, dpi = 150)
ggsave("260331_compliance_cold.png",
       plot_compliance(comp_ts_cold, "cold fleet"), width = 11, height = 4, dpi = 150)
ggsave("260331_compliance_warm_pol.png",
       plot_compliance(comp_ts_warm_pol, "warm fleet — compliant subset (λ_Policy estimation)"),
       width = 11, height = 4, dpi = 150)
cat("  Saved: 260331_compliance_warm.png\n")
cat("  Saved: 260331_compliance_cold.png\n")
cat("  Saved: 260331_compliance_warm_pol.png\n")

# ════════════════════════════════════════════════════════════════════════════
# SAVE
# ════════════════════════════════════════════════════════════════════════════
save(lambda_cf_B_granular, lambda_cf_streamA,
     lambda_policy_streamA, lambda_proactive_streamA,
     e_bar_rows, e_bar,
     comp_thresh, phase_duration_yr, seg_breaks_B, seg_mids_B,
     kw_by_group_stage, ef_nox_gkwh,
     comp_ts_warm, comp_ts_cold, comp_ts_warm_pol,
     file = "260331_step4_revised_parameters.RData")

cat("\nSaved: 260331_step4_revised_parameters.RData\n")
cat("Key objects: lambda_cf_streamA, lambda_policy_streamA, lambda_proactive_streamA,\n")
cat("             e_bar_rows, e_bar, kw_by_group_stage, ef_nox_gkwh\n")

sink(); close(log_con)
cat("Log written to: 260331_step4_revised_console.txt\n")
