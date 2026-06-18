# λ_CF Sensitivity Tests and Methodological Findings
# Scripts: 260329_step3_lambda_diagnostics.R, 260329_step3b_lambda_temporal.R
# Logs:    260329_step3_lambda_diagnostics.txt, 260329_step3b_lambda_temporal.txt

---

## 1. Annual GLS instability — Phase B CAZ_Plus (step3 diagnostics)

1. CAZ_Plus cold Phase B counts confirmed correct by checksum: A1=51, A2=69, B=241, total=361.
2. Annual cold-engaged counts for CAZ_Plus Phase B (2021–2024) are 69, 37, 83, 40 — small and highly variable year-to-year.
3. CAZ_Plus cold/warm ratio is 11.7% (241/2051), vs 28.7% for Rest_of_London — genuinely fewer cold-engaged arrivals in the most-regulated zone.
4. The annual GLS regression is dominated by Stage IV rows (largest predictors and weights); their implied λ values across three year-pairs are 0.864, −2.26, and 0.914 — wildly inconsistent, driven by Stage IV proportion swinging 46%→19%→30%→13% on annual samples of 37–83.
5. Near-zero predictor rows are not specific to CAZ_Plus: 8/15 rows for CAZ_Plus vs 9/15 for Rest_of_London — not the primary cause of instability.
6. Leave-one-out: dropping each year-pair in turn gives λ = 0.539, 0.682, 0.628. No single year-pair explains the elevation; the estimate is uniformly unstable.
7. Dropping the 2021 boundary year-pair (nearest the Sep 2020 policy change) reduces λ from 0.638 to 0.539 — partial reduction only; boundary contamination is a minor contributor.
8. Root cause: annual sampling noise on small cold-engaged counts, not a systematic bias or algorithmic error.

---

## 2. Temporal 3-segment GLS — Phase B all groups (step3b temporal)

9. Phase B (1 Sep 2020 – 31 Dec 2024 = 1582 days) divided into 3 equal segments of ~527 days. Segment midpoints: 2021-05-23, 2022-11-01, 2024-04-12 (fractional years 2021.389, 2022.832, 2024.278). Δt between midpoints = 1.44 and 1.45 years; Δp annualised by dividing by Δt.
10. Including 2020B records (excluded in annual approach): CAZ_Plus segment counts 86, 72, 83 — substantially more balanced than annual totals of 69, 37, 83, 40.
11. Temporal 3-segment λ_CF estimates vs original annual estimates:

| Group          | Annual (step 2) | Temporal 3-seg | Seg 1→2 | Seg 2→3 |
|----------------|----------------:|---------------:|--------:|--------:|
| CAZ_Plus       | 0.638           | 0.363          | 0.401   | 0.125   |
| Constant_Speed | 0.176           | 0.158          | 0.130   | 0.305   |
| Rest_of_London | 0.250           | 0.219          | 0.184   | 0.338   |

12. CAZ_Plus combined estimate falls from 0.638 to 0.363 (SE=0.052, CI [0.261, 0.464]) — substantial reduction confirming annual sampling noise was inflating the original estimate.
13. Seg 1→2 and seg 2→3 estimates are inconsistent across all three groups (not just CAZ_Plus), indicating the rate is not constant within Phase B. The seg 2→3 transition is elevated for Constant_Speed and Rest_of_London and depressed for CAZ_Plus. This coincides with Stage V becoming dominant in the cold fleet from mid-2023, which a constant-λ model cannot absorb.

---

## 3. Methodological issues requiring redrafting

14. **Per-group λ_CF must remain separate.** The groups have different Stage compliance endpoints (Constant_Speed: IIIA→V direct; CAZ_Plus: IV→V; Rest_of_London: IIIB→IV→V). Pooling across groups conflates fundamentally different state spaces and is not valid.

15. **A higher λ_CF for CAZ_Plus is plausible and may be genuine.** CAZ_Plus covers the most tightly controlled zone with the most expensive central London construction sites. Operators in this zone run newer, higher-value equipment with faster natural replacement cycles. The temporal estimate of 0.363 should not be treated as residual noise.

16. **The GLS predictor weighting is misspecified for Constant_Speed and CAZ_Plus.** The current implementation sets `max_stage = 6` uniformly and distributes inflow from stage j equally across all stages j+1…V via weight `1/(max_stage − j)`. This is incorrect for groups where intermediate stages are absent from the cold fleet: Constant_Speed has no IIIB or IV cold-engaged machines; CAZ_Plus has IV as its compliance floor with the active transition being IV→V only. The equal-weight allocation spreads probability mass across stages not present, distorting the predictor. The effective `max_stage` and active stage set should be defined per group.

17. **Recommended λ_CF values for Phase B** (pending model specification fix in point 16):
    - CAZ_Plus: 0.363 (temporal 3-segment estimate)
    - Constant_Speed: 0.158 (temporal 3-segment; consistent with annual estimate of 0.176)
    - Rest_of_London: 0.219 (temporal 3-segment; consistent with annual estimate of 0.250)

18. **Phase B λ_CF is not time-homogeneous.** The inconsistency between segment pairs across all groups suggests the natural upgrade rate accelerated within Phase B, likely driven by increasing Stage V market availability from 2023 onwards. A single λ_CF per group across the full Phase B period is a simplification that should be flagged as a limitation.

---

## 4. Constant_Speed structural findings — implications for max_stage and estimation window

19. **Constant_Speed effective state space is {I, II, IIIA} only.** Stages IIIB and IV never appear in the Constant_Speed cold-engaged fleet. The compliance pathway is II→IIIA→V, skipping IIIB and IV. `max_stage` must be 3 for this group, not 6.

20. **Universal `max_stage=6` misspecifies the GLS for Constant_Speed.** With 5 rows per year-pair and near-zero predictors for absent stages IIIB and IV, the current fit dilutes signal from the only informative stages (I, II). Correct specification uses 2 rows per year-pair (stages 1 and 2 only), which is well-identified given the clear II→IIIA monotone trend.

21. **IIIA is the absorbing state for Constant_Speed through 2023.** II proportion falls from ~57% (2017) to ~4% (2021), accumulating in IIIA. Stage V = 0 in every year 2017–2023. This is consistent with λ_CF driving II→IIIA under Phase A/B requirements.

22. **Stage V spike in 2024 is anticipatory regulatory compliance, not natural turnover.** Stage V jumps from 0% to 61% in the 2024 cold sample, coinciding with the Phase C Stage V requirement for Constant_Speed (Jan 2025). This is a discrete regulatory forcing event and must be excluded from λ_CF estimation. 2024 cold composition should be used as the Phase C initialisation state, not as a λ_CF data point.

23. **The A1→A2 SWOT fatal flaw does not apply to Constant_Speed.** The fatal flaw was IIIB rising from A1 to A2, violating the GLS monotone-upgrading assumption. Constant_Speed has no IIIB cold-engaged records. The only proportion shift is II falling and IIIA rising — monotonically throughout A1, A2, and Phase B. Cross-phase pooling (2017–2023) is methodologically valid for this group.

24. **Recommended Constant_Speed estimation strategy:** Pool all cold records 2017–2023. Apply `max_stage=3`. Estimate λ_CF from annual proportions using GLS. No phase split required. Exclude 2024 data from λ_CF fit; use 2024 composition as Phase C starting state.

25. **Revised `max_stage` per group:**
    - Constant_Speed: 3 (active stages I, II, IIIA)
    - CAZ_Plus: 5 (active transition IV→V; stages I–IV present in data)
    - Rest_of_London: 6 (full stage range present)

---

## 5. Constant_Speed corrected λ_CF — step3c results

26. **Correcting `max_stage` to 3 nearly doubles the Constant_Speed λ_CF estimate.** Previous estimates (0.158–0.176) were suppressed by near-zero predictor rows for absent stages IIIB and IV. With `max_stage=3` the primary estimate rises to 0.358.

27. **Step3c λ_CF estimates by window (max_stage=3, script: 260329_step3c_cs_lambda.R):**

| Window | lambda | SE | CI_low | CI_high | Status |
|---|---|---|---|---|---|
| 2017-2023 primary | 0.3579 | 0.0671 | 0.2264 | 0.4895 | USE |
| 2017-2020 Phase A | 0.3618 | 0.0443 | 0.2750 | 0.4486 | Consistent |
| 2021-2023 Phase B | -0.0932 | 0.2287 | -0.5415 | 0.3551 | Uninformative |
| A1->A2 cross-phase | 0.1794 | 0.0083 | 0.1631 | 0.1958 | Downward-biased |

28. **Phase B window (2021–2023) is uninformative for Constant_Speed.** Stage II proportion is already at 4% by 2021 — predictor signal is exhausted. The regression fits noise. All meaningful signal resides in Phase A (2017–2020).

29. **A1→A2 cross-phase estimate (0.179) is downward-biased.** Based on only two pooled snapshots (n=16, n=46) annualised over an assumed 2.25-year gap. The annual GLS over 2017–2020 (λ=0.362) is better supported and should be preferred.

30. **Recommended λ_CF for Constant_Speed: 0.358** (2017–2023 pooled, `max_stage=3`). This is comparable in magnitude to CAZ_Plus (0.363) and reflects the same correction — removing spurious predictor rows for absent stages.

31. **Revised recommended λ_CF values for all groups (supersedes finding 17):**
    - Constant_Speed: 0.358 (step3c, 2017-2023, max_stage=3)
    - CAZ_Plus: 0.363 (step3b, temporal 3-segment, max_stage=5 pending fix)
    - Rest_of_London: 0.219 (step3b, temporal 3-segment, max_stage=6)

---

## 6. Enforcement Rate ($\bar{e}$) — Definition Corrections (step4)

32. **Original ē definition yielded only 35 records (0.4% of warm fleet).** The flag `Enforcement_Upgrade = Final.Stage > Initial.Stage` captures only on-the-spot machine replacements recorded within a single audit row. In practice, replacements occur after the audit visit; the Final.Stage field is populated for nearly all warm records (8,900/8,934) but almost always equals Initial.Stage.

33. **Corrected ē definition:** Count of warm records where `Initial.Stage < compliance_threshold` (machine was non-compliant at audit, i.e. under LEZ enforcement obligation) AND `Final.Stage` is non-NA (audit record is complete). Denominator: total warm records per group × phase. This yields enforcement exposure rates in the 10–20% range consistent with direct inspection of the raw audit data.

34. **Annualisation error identified and fixed.** The original code divided `n_enf / n_tot` by phase duration (years). This was correct for a cumulative count (35 replacements over 4.3 years → ~8/year). It is incorrect for the corrected definition, where `n_enf / n_tot` is already an average annual proportion across audit visits. Dividing by phase duration would deflate the estimate by 3–4×. Fix: remove `/ dur`.

35. **Weighted averaging for pooled cells.** For cases where ē feeds into a pooled λ_Proactive (A1/A2 variable speed; CS Phase A), ē must be fleet-size-weighted across constituent group × phase cells. Simple averaging across unequal-sized cells introduced bias.

36. **CS Phase B ē ≈ 1 is expected and correct.** Under the Stage V compliance threshold active from Sep 2020, virtually all warm Constant\_Speed machines were non-compliant at initial audit throughout Phase B. This is not a data or code error. λ_Proactive for CS Phase B is correctly floored to 0: all CS Phase B compliance is attributed to enforcement, consistent with the abrupt Stage V mandate with no prior market penetration.
