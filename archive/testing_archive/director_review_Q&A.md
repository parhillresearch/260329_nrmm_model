## Q1 — Why does Constant Speed use annual WLS resolution despite having the fewest cold records?

**Question:** The report states that Constant Speed uses annual midpoints 2016–2023 for λ_CF estimation, while CAZ+ and Rest of London use only 4 points (A1/A2 pooled + Phase B 3 segments). Given that CAZ+ and Rest of London have far more records, shouldn't the proportions be the other way around?

**Answer:**

The apparent paradox resolves through signal quality rather than record count. The operative constraint is not total N — it is annual WLS stability at each temporal point, which is determined by within-cell stage variance, not cell size alone.

**CAZ+ and Rest of London (max_stage = 6):** Stage V penetration reaches approximately 60% of cold records in Phase B3. As the fleet bunches at the ceiling, year-to-year variance in mean stage increases sharply — small fluctuations in Stage V fraction produce large swings in the annual mean. Annual GLS attempted for CAZ+ produced λ = 0.638 (more than twice the accepted 0.262). The inflation is a ceiling-saturation artefact, not a genuine fleet signal. Widening the temporal window to ~527-day Phase B segments averages out this within-period noise and recovers a stable slope.

**Constant Speed (max_stage = 3):** Stage V is absent from the CS cold estimation window (2024 excluded). The fleet moves within a bounded three-integer space (Stages I–IIIA) with no ceiling in range. Annual CS cold n (~16–17 records/year) is in fact lower than annual CAZ+ cold n (37–83/year), yet the signal is cleaner and annual resolution is stable precisely because there is no saturation compressing and distorting the slope.

**A1/A2 pooling** for variable-speed groups creates a pre-Phase-B anchor point. It is partly motivated by thin annual A1 cells, but principally by the decision to use Phase B sub-segments as the time-varying signal rather than mixing annual and segmented granularities within the same regression.

**Conclusion:** More records per time point does not help when ceiling saturation is the noise source. The correct remedy is wider temporal bins, not larger samples.

---

## Q2 — Do the Section 2.1 graphs contradict the key CF findings on the first page?

**Question:** The cold fleet stage distribution graphs appear to show some modest switching to CS Stage IIIA and then Stage V. Does this contradict λ_CF = 0.051 and the characterisation of generators as having near-zero natural turnover?

**Answer:**

The graphs contain two distinct transitions for CS that must be read separately.

### Transition 1 — Stage I/II → IIIA (approximately 2016–2021)

This is captured in λ_CF = 0.051 and is not contradictory. Step 2 data shows the cold CS fleet was already 56% Stage IIIA in Phase A1, rising to 96% by Phase B1. The improvement is real but was already well underway before 2016, meaning only the tail end of this transition runs through the estimation window. The rate is genuinely slow — roughly 40 percentage points of fleet conversion over five years. λ = 0.051 stage integers per year is a plausible, if imprecise, characterisation of this signal. No contradiction here.

### Transition 2 — Stage IIIA → Stage V (approximately 2022–2025)

This is where the instinct is correct. Step 2 records that 49% of the cold CS fleet was at Stage V by Phase B3, and Phase C initialisation shows 53.8% Stage V. Nearly half the fleet turned over to Stage V within roughly two to three years. The λ_CF estimation treats this entire transition as outside scope — either excluded (2024 data, the formal "anticipatory spike") or capped to IIIA (Stage V machines in B3 receive stage_capped = 3, contributing zero slope to the regression). The consequence is that the WLS annual points for 2021, 2022, and 2023 all cluster near mean stage = 3.0 within the capped space — a near-flat plateau — which actively suppresses the estimated slope. The visible fleet improvement in the B3 portion of the graph is real but arithmetically invisible to the estimator.

**Whether the exclusion is justified is a genuine analytical question.** The 2024 CS Stage V spike is clearly a regulatory deadline response and correctly excluded. But the B3 Stage V appearance (pre-2024, 49% of cold fleet) is more ambiguous: it may be anticipatory compliance beginning early, or it may reflect genuine market-driven turnover as Stage V became the standard new-build specification from around 2020. The current model assigns all of it to anticipatory compliance. If any of it is natural turnover, λ_CF = 0.051 understates the true rate.

### Discrepancy between Step 2 recommendation and Step 3 implementation

Step 2's sparsity analysis explicitly concluded: "High; pooled estimation required" for CS, with sd_yoy_delta = 18.4 (cf. Rest of London: 4.5). The text states: "pervasive CS sparsity reconfirms that CS lambda_CF estimation must pool across years within phases rather than using annual WLS." Step 3 used annual midpoints regardless. Annual WLS on cells of n ≈ 13–17 with sd_yoy_delta of 18 is likely what produced the near-zero estimate and the wide CI [-0.017, 0.119]. Had Phase A been pooled as a single point and Phase B as a single point (as Step 2 recommended), the implied slope would be approximately (3.0 − ~2.5) / 4 years ≈ 0.12/year — considerably higher than 0.051 and more consistent with the visible graph trend.

### Verdict

The hypothesis is substantially correct on the second transition. The graphs show visible Stage V adoption in the cold CS fleet from Phase B3 onward. This adoption is real, occurs before the formal 2024 exclusion window, and is invisible to the estimator because of the max_stage = 3 cap. Combined with the Step 2 sparsity warning that was not followed through in Step 3, there is a credible case that λ_CF = 0.051 underestimates CS natural turnover, and the "near-zero" characterisation in the report may be too strong. The appropriate caveat is that the distinction between anticipatory and natural Stage V adoption in 2022–2024 cannot be resolved from the audit data alone — but it should be flagged as a known limitation, not assumed resolved in favour of near-zero.

---

_End of director review record._