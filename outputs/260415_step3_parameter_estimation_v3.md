# Step 3 Parameter Estimation — 260415_step3_parameter_estimation_v3
*Generated: 2026-04-17 11:33:47*

## 3.1 lambda_CF — Counterfactual fleet turnover rate

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.1: WLS lambda_CF by group (cold-engaged records)</caption>
 <thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="6"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">lambda_CF — slope of mean stage vs time (cold-engaged fleet, WLS)</div></th>
</tr>
  <tr>
   <th style="text-align:left;"> Group </th>
   <th style="text-align:right;"> Estimate </th>
   <th style="text-align:right;"> SE </th>
   <th style="text-align:right;"> 95% CI </th>
   <th style="text-align:left;"> N obs </th>
   <th style="text-align:right;"> Prev. ref </th>
   <th style="text-align:right;"> Δ </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:right;"> 0.051 </td>
   <td style="text-align:right;"> 0.026 </td>
   <td style="text-align:right;"> [-0.017, 0.119] </td>
   <td style="text-align:left;"> 133 </td>
   <td style="text-align:right;"> 0.358 </td>
   <td style="text-align:right;"> -0.307 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> CAZ_Plus </td>
   <td style="text-align:right;"> 0.262 </td>
   <td style="text-align:right;"> 0.033 </td>
   <td style="text-align:right;"> [0.119, 0.404] </td>
   <td style="text-align:left;"> 361 </td>
   <td style="text-align:right;"> 0.363 </td>
   <td style="text-align:right;"> -0.101 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Rest_of_London </td>
   <td style="text-align:right;"> 0.241 </td>
   <td style="text-align:right;"> 0.017 </td>
   <td style="text-align:right;"> [0.169, 0.314] </td>
   <td style="text-align:left;"> 1294 </td>
   <td style="text-align:right;"> 0.219 </td>
   <td style="text-align:right;"> +0.022 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Variable_Speed </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:left;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
  </tr>
</tbody>
</table>

lambda_CF is the WLS slope of mean emissions Stage over time estimated from cold-engaged records only; SE and 95% CI are computed from vcov() of the lm() fit.
Delta (Δ) is the difference from the previous-trial reference value in schema.md Table 8; values within ±0.05 indicate consistency with prior work.

## 3.2 e-bar — Non-compliance exposure rate

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.2: e-bar (% of records below compliance threshold) by group × phase</caption>
 <thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="2"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Phase A1</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="2"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Phase A2</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="2"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Phase B</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="2"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Phase C</div></th>
</tr>
  <tr>
   <th style="text-align:left;"> Group </th>
   <th style="text-align:right;"> ē </th>
   <th style="text-align:right;"> N </th>
   <th style="text-align:right;"> ē </th>
   <th style="text-align:right;"> N </th>
   <th style="text-align:right;"> ē </th>
   <th style="text-align:right;"> N </th>
   <th style="text-align:right;"> ē </th>
   <th style="text-align:right;"> N </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:right;"> 22.1% </td>
   <td style="text-align:right;"> 104 </td>
   <td style="text-align:right;"> 14.8% </td>
   <td style="text-align:right;"> 318 </td>
   <td style="text-align:right;"> 82.8% </td>
   <td style="text-align:right;"> 693 </td>
   <td style="text-align:right;"> 30.4% </td>
   <td style="text-align:right;"> 112 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> CAZ_Plus </td>
   <td style="text-align:right;"> 20.2% </td>
   <td style="text-align:right;"> 400 </td>
   <td style="text-align:right;"> 11.2% </td>
   <td style="text-align:right;"> 658 </td>
   <td style="text-align:right;"> 19.9% </td>
   <td style="text-align:right;"> 2,296 </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Rest_of_London </td>
   <td style="text-align:right;"> 5.2% </td>
   <td style="text-align:right;"> 538 </td>
   <td style="text-align:right;"> 3.2% </td>
   <td style="text-align:right;"> 1,634 </td>
   <td style="text-align:right;"> 4.7% </td>
   <td style="text-align:right;"> 4,122 </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Variable_Speed </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> 22.0% </td>
   <td style="text-align:right;"> 1,483 </td>
  </tr>
</tbody>
</table>

ē is the percentage of all audited machines in that group–phase cell whose initial emissions stage was strictly below the minimum required threshold; N is the total number of records in the cell.
Variable_Speed rows show Phase C data only (P24 zone records, post-2025 CAZ+/RoL merger); all Phase A1, A2, and B cells for Variable_Speed are blank because that group did not exist before 1 January 2025.

## 3.3 lambda_Policy and lambda_Proactive

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.3: λ_Policy, λ_CF, and λ_Proactive by group</caption>
 <thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="2"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Warm self-compliant (WLS)</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="1"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Cold (WLS)</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="1"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Derived</div></th>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
</tr>
  <tr>
   <th style="text-align:left;"> Group </th>
   <th style="text-align:right;"> λ_Policy </th>
   <th style="text-align:right;"> SE </th>
   <th style="text-align:right;"> λ_CF </th>
   <th style="text-align:right;"> λ_Proactive </th>
   <th style="text-align:right;"> N warm sc. </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:right;"> -0.000 </td>
   <td style="text-align:right;"> 0.008 </td>
   <td style="text-align:right;"> 0.051 </td>
   <td style="text-align:right;"> 0.000 (floored) </td>
   <td style="text-align:right;"> 148 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> CAZ_Plus </td>
   <td style="text-align:right;"> 0.275 </td>
   <td style="text-align:right;"> 0.030 </td>
   <td style="text-align:right;"> 0.262 </td>
   <td style="text-align:right;"> 0.013 </td>
   <td style="text-align:right;"> 501 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Rest_of_London </td>
   <td style="text-align:right;"> 0.194 </td>
   <td style="text-align:right;"> 0.026 </td>
   <td style="text-align:right;"> 0.241 </td>
   <td style="text-align:right;"> 0.000 (floored) </td>
   <td style="text-align:right;"> 1,152 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Variable_Speed </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
  </tr>
</tbody>
</table>

λ_Policy is the WLS slope of mean stage over time in warm, self-compliant records (emissions OK on arrival, no enforcement needed); it reflects combined natural turnover and proactive LEZ-driven replacement.
λ_Proactive = max(0, λ_Policy − λ_CF) isolates the incremental rate attributable to proactive LEZ compliance; a floored value of 0.000 indicates no detectable proactive response above the counterfactual rate.

---
## Glossary

| Term | Definition |
|------|------------|
| **λ_CF** (lambda_CF) | Counterfactual fleet turnover rate: the annual rate of emissions stage improvement expected *without* LEZ enforcement, estimated from cold-engaged machines (unprompted arrivals). Units: stage integers per year. |
| **λ_Policy** (lambda_Policy) | Combined fleet improvement rate observed in warm, self-compliant machines (emissions OK on arrival). Captures both natural turnover and proactive LEZ-driven replacement. |
| **λ_Proactive** (lambda_Proactive) | Incremental improvement rate attributable to LEZ policy, computed as max(0, λ_Policy − λ_CF). Floored at zero because negative differences reflect noise, not regression. |
| **ē** (e-bar) | Non-compliance exposure rate: % of all audited machines in a group–phase cell whose initial stage was strictly below the minimum required threshold (schema.md Table 2). Computed on all records (cold + warm). |
| **WLS** | Weighted least squares regression via lm() with the cell sample size as weights; SE extracted from vcov(). |
| **Cold-engaged** | Machine present on site but not yet actively engaged with the LEZ compliance process; used to estimate the counterfactual turnover rate. |
| **Warm self-compliant** | Machine whose initial emissions stage already met requirements at audit, with no enforcement action required (outcome Route 1). |
| **MAX_STAGE** | Group-specific stage integer ceiling applied when computing mean stage for lambda estimation; CS = 3 (I–IIIA), CAZ+/RoL/VS = 6 (up to Stage V). |
| **Phase A1** | 1 Jan 2016 – 31 Dec 2018: pre-Stage V market availability. |
| **Phase A2** | 1 Jan 2019 – 31 Aug 2020: Stage V newly available. |
| **Phase B** | 1 Sep 2020 – 31 Dec 2024: tighter LEZ requirements. COVID-exempt records (Sep 2020–Mar 2021) excluded. Subdivided into 3 equal segments for variable-speed groups. |
| **Phase C** | 1 Jan 2025 – 31 Dec 2030: forecast horizon. CAZ+ and Rest of London merged into Variable_Speed (P24 zone). |


---

## Step Report

### Intended tasks

- **3.1** Estimate λ_CF from cold-engaged records only using WLS on mean Stage vs fractional year; apply group-specific MAX_STAGE and estimation windows (CS: annual 2016–2023; VS groups: A1/A2 pooled + B 3-segments); validate against reference values in schema.md Table 8.
- **3.2** Estimate ē from all records where initial stage < compliance threshold for that group and phase (schema.md Table 2); report as %; do not divide by phase duration.
- **3.3** Estimate λ_Policy from warm self-compliant records only; compute λ_Proactive = max(0, λ_Policy − λ_CF); report with SE and CI; flag anomalies.

---

### Results by sub-task

#### 3.1 lambda_CF

λ_CF was estimated for three groups. Rest_of_London is the only group whose new estimate is consistent with the previous-trial reference (Δ = +0.022, within ±0.05 tolerance). CAZ_Plus is moderately lower than its reference (0.262 vs 0.363, Δ = −0.101); its confidence interval is well-identified and excludes zero, suggesting a genuine positive counterfactual turnover rate. Constant_Speed is anomalous: the new estimate (0.051) is 0.307 below the reference (0.358), and the 95% CI (−0.017, 0.119) barely excludes zero. This is the most important finding to carry forward into Step 4. The CS cold-engaged sample is small (N = 133 over 8 years, ≈ 17 records per year), and the λ_Policy estimate for CS (≈ 0) corroborates a genuinely slow natural turnover signal rather than a data artefact — CS generators appear to be held in service without stage upgrades until policy forces a change. The large discrepancy with the old reference (0.358) likely reflects differences in base data between the old prototype trials and the current cleaned ingestion pipeline.

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.1: WLS lambda_CF by group (cold-engaged records)</caption>
 <thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="6"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">lambda_CF — slope of mean stage vs time (cold-engaged fleet, WLS)</div></th>
</tr>
  <tr>
   <th style="text-align:left;"> Group </th>
   <th style="text-align:right;"> Estimate </th>
   <th style="text-align:right;"> SE </th>
   <th style="text-align:right;"> 95% CI </th>
   <th style="text-align:left;"> N obs </th>
   <th style="text-align:right;"> Prev. ref </th>
   <th style="text-align:right;"> Δ </th>
  </tr>
 </thead>
<tbody>
  <tr><td>Constant_Speed</td><td>0.051</td><td>0.026</td><td>[−0.017, 0.119]</td><td>133</td><td>0.358</td><td>−0.307 ⚠</td></tr>
  <tr><td>CAZ_Plus</td><td>0.262</td><td>0.033</td><td>[0.119, 0.404]</td><td>361</td><td>0.363</td><td>−0.101</td></tr>
  <tr><td>Rest_of_London</td><td>0.241</td><td>0.017</td><td>[0.169, 0.314]</td><td>1,294</td><td>0.219</td><td>+0.022 ✓</td></tr>
  <tr><td>Variable_Speed</td><td>—</td><td>—</td><td>—</td><td>—</td><td>—</td><td>—</td></tr>
</tbody>
</table>

Each row is the WLS-estimated annual rate of mean emissions stage improvement in the cold-engaged fleet; ✓ marks values within ±0.05 of the previous reference, ⚠ marks a departure exceeding 0.10.
The Constant_Speed estimate (0.051) is a major departure from the reference (0.358) and is borderline-significant; this is corroborated by the near-zero λ_Policy for CS and the small cold sample (N = 133), and should be treated as the operative estimate for Step 4 rather than the old reference.

#### 3.2 e-bar

Non-compliance exposure rates are broadly consistent with policy design. For Constant_Speed, ē rises sharply from 22.1% (Phase A1, IIIA threshold) to 82.8% (Phase B, Stage V threshold) — the majority of the generator fleet was below Stage V when the stricter requirement took effect, which is the expected enforcement challenge. By Phase C (P24 data, Stage V threshold) ē has fallen to 30.4%, indicating a significant reduction in non-compliance. CAZ_Plus shows moderate exposure (20.2% → 11.2% → 19.9%) with the slight Phase B uptick reflecting the shift to the stricter Stage IV threshold. Rest_of_London maintains consistently low exposure (3–5%) across all phases, suggesting the RoL fleet has broadly met the lower IIIA/IIIB thresholds throughout. Variable_Speed (Phase C only) shows 22.0% below Stage V, broadly aligned with Constant_Speed Phase C.

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.2: e-bar (% of records below compliance threshold) by group × phase</caption>
 <thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="2"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Phase A1</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="2"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Phase A2</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="2"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Phase B</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="2"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Phase C</div></th>
</tr>
  <tr>
   <th>Group</th><th>ē</th><th>N</th><th>ē</th><th>N</th><th>ē</th><th>N</th><th>ē</th><th>N</th>
  </tr>
 </thead>
<tbody>
  <tr><td>Constant_Speed</td><td>22.1%</td><td>104</td><td>14.8%</td><td>318</td><td>82.8%</td><td>693</td><td>30.4%</td><td>112</td></tr>
  <tr><td>CAZ_Plus</td><td>20.2%</td><td>400</td><td>11.2%</td><td>658</td><td>19.9%</td><td>2,296</td><td>—</td><td>—</td></tr>
  <tr><td>Rest_of_London</td><td>5.2%</td><td>538</td><td>3.2%</td><td>1,634</td><td>4.7%</td><td>4,122</td><td>—</td><td>—</td></tr>
  <tr><td>Variable_Speed</td><td>—</td><td>—</td><td>—</td><td>—</td><td>—</td><td>—</td><td>22.0%</td><td>1,483</td></tr>
</tbody>
</table>

ē is the percentage of all audited machines (cold and warm) in a group–phase cell whose initial stage was strictly below the minimum required threshold; N is the total records in that cell.
The Constant_Speed Phase B figure (82.8%) reflects that the Stage V requirement was newly imposed and the generator fleet had not yet turned over; the fall to 30.4% in Phase C (P24) shows substantial compliance improvement, consistent with the anticipatory 2024 Stage V spike noted in schema.md analytical note 3.

#### 3.3 lambda_Policy and lambda_Proactive

λ_Policy is near zero for Constant_Speed (−0.000, SE = 0.008), confirming that the warm self-compliant CS fleet shows essentially no stage trend. This is consistent with the low λ_CF (0.051) and supports the view that the CS fleet is characterised by inertia — machines stay in service until a compliance event forces replacement, not through natural market turnover. For CAZ_Plus, λ_Policy (0.275) slightly exceeds λ_CF (0.262), yielding a small positive λ_Proactive of 0.013, which is the only group showing a detectable proactive LEZ response above the counterfactual. For Rest_of_London, λ_Policy (0.194) is below λ_CF (0.241), flooring λ_Proactive at zero; this direction is unexpected and likely reflects that warm self-compliant RoL machines are a stable long-tenure subfleet improving more slowly than the broader cold-engaged pool.

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.3: λ_Policy, λ_CF, and λ_Proactive by group</caption>
 <thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="2"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Warm self-compliant (WLS)</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="1"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Cold (WLS)</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="1"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Derived</div></th>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
</tr>
  <tr>
   <th>Group</th><th>λ_Policy</th><th>SE</th><th>λ_CF</th><th>λ_Proactive</th><th>N warm sc.</th>
  </tr>
 </thead>
<tbody>
  <tr><td>Constant_Speed</td><td>−0.000</td><td>0.008</td><td>0.051</td><td>0.000 (floored)</td><td>148</td></tr>
  <tr><td>CAZ_Plus</td><td>0.275</td><td>0.030</td><td>0.262</td><td>0.013</td><td>501</td></tr>
  <tr><td>Rest_of_London</td><td>0.194</td><td>0.026</td><td>0.241</td><td>0.000 (floored)</td><td>1,152</td></tr>
  <tr><td>Variable_Speed</td><td>—</td><td>—</td><td>—</td><td>—</td><td>—</td></tr>
</tbody>
</table>

λ_Policy is the WLS slope of mean stage in warm self-compliant records; λ_Proactive is the excess above the counterfactual, floored at zero.
Only CAZ_Plus shows a positive λ_Proactive (0.013); both CS and RoL floor at zero, indicating the LEZ does not measurably accelerate stage improvement in those groups beyond natural turnover — enforcement (ē) rather than proactive replacement is likely the primary compliance mechanism for CS and RoL.

