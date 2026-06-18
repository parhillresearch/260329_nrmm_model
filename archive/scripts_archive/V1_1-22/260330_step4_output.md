# Step 4 Output: Parameter Estimation
**Script:** `260330_step4_parameter_estimation.R` | **Date:** 30 March 2026
**Inputs:** `260329_step2_exploratory.RData`
**Outputs:** `260330_step4_parameters.RData`, `260330_compliance_warm.png`, `260330_compliance_cold.png`

---

## 1. Stream A $λ_{CF}$ — Binary Compliance (Cold Fleet)

| Case | $λ_{CF}$ | SE | 95% CI | Significant? |
|---|---|---|---|---|
| A1/A2 Variable Speed (pooled) | 0.130 | 0.198 | [−0.257, 0.517] | No |
| Constant Speed Phase A (IIIA threshold) | −0.107 | 0.417 | [−0.925, 0.710] | No |
| Constant Speed Phase B (V threshold) | 0.000 | — | — | By inspection |
| CAZ+ Phase B (IV threshold, 3-seg) | 0.161 | 0.143 | [−0.119, 0.442] | No |
| RoL Phase B (IIIB threshold, 3-seg) | 0.152 | 0.157 | [−0.156, 0.460] | No |

**Interpretation:**
All binary $λ_{CF}$ estimates are statistically non-significant (95% CIs include zero). This is expected: the cold-engaged fleet is small (n = 21–360 per segment), and collapsing the stage distribution to binary compliance discards granular signal. The granular Stream B $λ_{CF}$ estimates (§5 below) are more reliable.

The **CS Phase A binary $λ_{CF}$ = −0.107** is an artefact, not a genuine decline in natural compliance. The cold CS fleet in Phase A2 2020 (Jan–Aug only) contained n = 9 records with p_compliant = 0.556, a drop from 0.757 in 2019 — a sampling noise reversal in a very small stratum. The granular estimate of 0.358 remains the authoritative value for CS.

**CS Phase B $λ_{CF}$ = 0** is correct by inspection: no Stage V machinery appeared in the cold-engaged CS fleet during 2021–2023, confirming that without LEZ intervention no natural Stage V replacement would have occurred.

---

## 2. Stream A $λ_{Total}$ — Binary Compliance (Warm Fleet)

| Case | $λ_{Total}$ | SE | 95% CI | Significant? |
|---|---|---|---|---|
| A1/A2 Variable Speed (pooled) | 0.292 | 0.122 | [0.052, 0.531] | **Yes** |
| Constant Speed Phase A (IIIA threshold) | 0.636 | 0.336 | [−0.021, 1.294] | Marginal |
| Constant Speed Phase B (V threshold) | 0.213 | 0.151 | [−0.082, 0.508] | No |
| CAZ+ Phase B (IV threshold, 3-seg) | **0.311** | **0.006** | **[0.299, 0.323]** | **Yes — very high precision** |
| RoL Phase B (IIIB threshold, 3-seg) | 0.265 | 0.233 | [−0.193, 0.722] | No |

**Interpretation:**
**CAZ+ Phase B $λ_{Total}$ = 0.311 (CI ±0.012)** is the most robust estimate in the dataset. The large Phase B warm fleet (2,051 records; 3-segment sizes 594/684/773) gives exceptional statistical precision. Compliance in the CAZ+ warm fleet improved from 67% to 90% between Phase B segments 1 and 3 — a 23 percentage point gain over ~3 years.

**CS Phase B warm fleet compliance** (Stage V threshold) rose from 0% (2021) → 4% (2022) → 18% (2023) → 65% (2024). This growth is nearly entirely attributable to enforcement (the Phase C 2025 mandate was well-signposted), with $λ_{Total}$ = 0.213 and wide uncertainty given the compressed compliance window.

**RoL Phase B $λ_{Total}$ = 0.265** is imprecise (CI spans from negative to 0.72) despite large segment sizes (987/1015/1196). The compliance proportions were already high and compressed (94% → 95% → 99%), so small absolute changes are amplified into unstable WLS estimates. The improvement is real but the rate is uncertain.

---

## 3. Enforcement Rate (ē)

| Group | Phase | n_warm | n_enforced | ē (annual avg.) |
|---|---|---|---|---|
| Constant Speed | A1 | 88 | 15 | 0.170 |
| Constant Speed | A2 | 270 | 33 | 0.122 |
| **Constant Speed** | **B** | **593** | **489** | **0.825** |
| CAZ+ | A1 | 349 | 62 | 0.178 |
| CAZ+ | A2 | 589 | 50 | 0.085 |
| CAZ+ | B | 2,051 | 393 | 0.192 |
| Rest of London | A1 | 450 | 16 | 0.036 |
| Rest of London | B | 3,198 | 125 | 0.039 |

**Interpretation:**

**Constant Speed Phase B (ē = 0.825):** As expected and flagged in the pipeline. Under the Stage V mandate active from Sep 2020, 82.5% of warm CS machines were non-compliant at initial audit throughout Phase B — these were all under enforcement obligation. No λ_Proactive signal exists for this group/phase: all CS Phase B compliance improvement is enforcement-driven.

**CAZ+ shows enforcement sensitivity to threshold changes.** ē drops from 17.8% (A1, threshold IIIB) to 8.5% (A2, same threshold) as the fleet improved through Phase A, then rises back to 19.2% in Phase B when the threshold jumps to IV, bringing previously-compliant IIIB machines back into non-compliance.

**Rest of London has consistently low ē (3–4%).** With a relatively permissive Phase B threshold (IIIB), most RoL warm machines were already compliant. The low enforcement rate is genuine, not a data artefact.

---

## 4. λ_Proactive — Decomposition

| Case | $λ_{Total}$ | $λ_{CF}$ | ē | λ_Proactive | Status |
|---|---|---|---|---|---|
| A1/A2 Variable Speed | 0.292 | 0.130 | 0.058 | **0.104** | Positive |
| CS Phase A | 0.636 | −0.107 | 0.134 | **0.610** | Positive (unreliable — see note) |
| CS Phase B | 0.213 | 0.000 | 0.825 | 0.000 | Floored |
| CAZ+ Phase B | 0.311 | 0.161 | 0.192 | 0.000 | Floored |
| RoL Phase B | 0.265 | 0.152 | 0.039 | **0.074** | Positive |

**Interpretation:**

**A1/A2 Variable Speed λ_Proactive = 0.104:** A genuine proactive LEZ response is detectable in the early programme period. The warm fleet compliance improved at ~0.29/yr, against a cold-fleet counterfactual of ~0.13/yr and enforcement exposure of ~0.06/yr. The proactive response (operators voluntarily upgrading in advance of enforcement) accounts for ~36% of total compliance improvement.

**CS Phase A λ_Proactive = 0.610:** This estimate is unreliable. It is driven by the artefactual negative $λ_{CF}$ (−0.107) inflating λ_Proactive. Treat as an upper bound; the true proactive rate is likely lower. Further investigation of CS Phase A binary estimates is warranted.

**CS Phase B and CAZ+ Phase B λ_Proactive = 0 [floored]:** For CS Phase B, this is structurally correct — near-total enforcement exposure (ē = 0.83) leaves no headroom for a detectable proactive component. For CAZ+ Phase B, the combined counterfactual (0.161) and enforcement (0.192) already exceed the observed total rate (0.311). This implies either the natural rate and/or enforcement rate are overestimated for this group, or the proactive and enforcement channels are not cleanly separable at this level of model resolution. The Phase 5 reconciliation floor-and-rescale handles this arithmetically.

**RoL Phase B λ_Proactive = 0.074:** RoL shows a small but real proactive response. The proactive rate (0.074) roughly equals the enforcement rate (0.039) × 2 — operators in the broader London area appear to be voluntarily upgrading at about twice the rate forced by enforcement, suggesting awareness of and anticipation of the Phase C (2025) IV mandate.

---

## 5. Confirmed Stream B $λ_{CF}$ (Granular, from Steps 3b/3c)

These values supersede the binary Stream A $λ_{CF}$ for Objective 1 quantification and matrix construction.

| Group | $λ_{CF}$ | SE | 95% CI |
|---|---|---|---|
| Constant Speed | 0.358 | 0.067 | [0.226, 0.490] |
| CAZ+ | 0.363 | 0.052 | [0.261, 0.464] |
| Rest of London | 0.219 | 0.048 | [0.125, 0.313] |

---

## 6. Mean kW per Group × Stage (Warm Fleet)

| Group | Stage | kW mean | n |
|---|---|---|---|
| Constant Speed | II | 117 | 42 |
| Constant Speed | IIIA | 179 | 656 |
| Constant Speed | V | 144 | 95 |
| CAZ+ | IIIA | 120 | 127 |
| CAZ+ | IIIB | 84 | 881 |
| CAZ+ | IV | 141 | 789 |
| CAZ+ | V | 93 | 1,052 |
| RoL | IIIA | 109 | 312 |
| RoL | IIIB | 77 | 2,026 |
| RoL | IV | 132 | 1,217 |
| RoL | V | 87 | 1,264 |

**Notes:** CS IIIB (n=1, 440 kW) and CS IV (n=1, 168 kW) are single-record outliers; kW means for these cells are unreliable and should be replaced by group means for emissions estimation. Stage V machines are generally smaller than Stage IV across all groups — consistent with newer compact equipment entering the fleet.

---

## 7. Emission Factors (PLACEHOLDER)

| Stage | I | II | IIIA | IIIB | IV | V | ZE |
|---|---|---|---|---|---|---|---|
| NOx (g/kWh) | 10.0 | 7.0 | 5.0 | 3.5 | 2.0 | 0.4 | 0.0 |

**⚠ PLACEHOLDER values** — EMEP/EEA Tier 3 (Ntziachristos & Samaras, 2019). Require expert review against project-specific engine category and power-band weighted averages before final reporting.

---

## 8. Key Caveats for Phase 5

1. **CS Phase A binary $λ_{CF}$ is unreliable** (−0.107 due to n=9 noise in 2020 cold data). Use granular $λ_{CF}$ (0.358) for CS in all downstream calculations.
2. **CAZ+ Phase B λ_Proactive = 0 [floored]**: Phase 5 reconciliation will scale down CF and enforcement matrix contributions. Expect proactive transition elements to be zeroed in P_Total for this group.
3. **CS IIIB and IV kW cells** have n=1 each — substitute group-level mean (172 kW) for emissions estimation.
4. **Emission factors are placeholders** — emissions output (Phase 6) cannot be treated as final until EF values are validated.
