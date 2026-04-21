# Step 3 Parameter Estimation — 260415_step3_parameter_estimation_v4
*Generated: 2026-04-17 13:18:25*

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

## 3.4 Enforcement success rate — Route 4/5 descriptive analysis

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.4: Route 4/5 enforcement success rate by group × time period. ⚠ = n(Routes 4+5) 
 </caption>
<thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="4"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Phase A1</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="4"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Phase A2</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="4"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Phase B1</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="4"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Phase B2</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="4"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Phase B3</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="4"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Phase C</div></th>
</tr>
  <tr>
   <th style="text-align:left;"> Group </th>
   <th style="text-align:right;"> n R4 </th>
   <th style="text-align:right;"> n R5 </th>
   <th style="text-align:right;"> n tot </th>
   <th style="text-align:right;"> Rate% </th>
   <th style="text-align:right;"> n R4 </th>
   <th style="text-align:right;"> n R5 </th>
   <th style="text-align:right;"> n tot </th>
   <th style="text-align:right;"> Rate% </th>
   <th style="text-align:right;"> n R4 </th>
   <th style="text-align:right;"> n R5 </th>
   <th style="text-align:right;"> n tot </th>
   <th style="text-align:right;"> Rate% </th>
   <th style="text-align:right;"> n R4 </th>
   <th style="text-align:right;"> n R5 </th>
   <th style="text-align:right;"> n tot </th>
   <th style="text-align:right;"> Rate% </th>
   <th style="text-align:right;"> n R4 </th>
   <th style="text-align:right;"> n R5 </th>
   <th style="text-align:right;"> n tot </th>
   <th style="text-align:right;"> Rate% </th>
   <th style="text-align:right;"> n R4 </th>
   <th style="text-align:right;"> n R5 </th>
   <th style="text-align:right;"> n tot </th>
   <th style="text-align:right;"> Rate% </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 96 </td>
   <td style="text-align:right;"> 96 </td>
   <td style="text-align:right;"> 0.0% </td>
   <td style="text-align:right;"> 1 </td>
   <td style="text-align:right;"> 186 </td>
   <td style="text-align:right;"> 187 </td>
   <td style="text-align:right;"> 0.5% </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 243 </td>
   <td style="text-align:right;"> 243 </td>
   <td style="text-align:right;"> 0.0% </td>
   <td style="text-align:right;"> 1 </td>
   <td style="text-align:right;"> 215 </td>
   <td style="text-align:right;"> 216 </td>
   <td style="text-align:right;"> 0.5% </td>
   <td style="text-align:right;"> 1 </td>
   <td style="text-align:right;"> 161 </td>
   <td style="text-align:right;"> 162 </td>
   <td style="text-align:right;"> 0.6% </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 87 </td>
   <td style="text-align:right;"> 87 </td>
   <td style="text-align:right;"> 0.0% </td>
  </tr>
  <tr>
   <td style="text-align:left;"> CAZ_Plus </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 347 </td>
   <td style="text-align:right;"> 347 </td>
   <td style="text-align:right;"> 0.0% </td>
   <td style="text-align:right;"> 1 </td>
   <td style="text-align:right;"> 462 </td>
   <td style="text-align:right;"> 463 </td>
   <td style="text-align:right;"> 0.2% </td>
   <td style="text-align:right;"> 3 </td>
   <td style="text-align:right;"> 564 </td>
   <td style="text-align:right;"> 567 </td>
   <td style="text-align:right;"> 0.5% </td>
   <td style="text-align:right;"> 2 </td>
   <td style="text-align:right;"> 695 </td>
   <td style="text-align:right;"> 697 </td>
   <td style="text-align:right;"> 0.3% </td>
   <td style="text-align:right;"> 2 </td>
   <td style="text-align:right;"> 569 </td>
   <td style="text-align:right;"> 571 </td>
   <td style="text-align:right;"> 0.4% </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Rest_of_London </td>
   <td style="text-align:right;"> 1 </td>
   <td style="text-align:right;"> 520 </td>
   <td style="text-align:right;"> 521 </td>
   <td style="text-align:right;"> 0.2% </td>
   <td style="text-align:right;"> 1 </td>
   <td style="text-align:right;"> 1092 </td>
   <td style="text-align:right;"> 1093 </td>
   <td style="text-align:right;"> 0.1% </td>
   <td style="text-align:right;"> 3 </td>
   <td style="text-align:right;"> 876 </td>
   <td style="text-align:right;"> 879 </td>
   <td style="text-align:right;"> 0.3% </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 883 </td>
   <td style="text-align:right;"> 883 </td>
   <td style="text-align:right;"> 0.0% </td>
   <td style="text-align:right;"> 6 </td>
   <td style="text-align:right;"> 948 </td>
   <td style="text-align:right;"> 954 </td>
   <td style="text-align:right;"> 0.6% </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
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
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 5 </td>
   <td style="text-align:right;"> 5 </td>
   <td style="text-align:right;"> 0.0%⚠ </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 1074 </td>
   <td style="text-align:right;"> 1074 </td>
   <td style="text-align:right;"> 0.0% </td>
  </tr>
</tbody>
</table>

n R4 = machines driven compliant via emissions upgrade (Route 4; proxy: final_stage > initial_stage); n R5 = emissions non-compliant at final audit (Route 5; includes removals without replacement stage); Rate% = n R4 / n tot, the per-audit enforcement success rate; ⚠ marks cells where n tot < 30 (too sparse to interpret reliably).
Variable_Speed appears only in Phase C (P24 zone post-2025 merger); CAZ_Plus and Rest_of_London have no Phase C records; all such cells show —. Route 4 proxy is conservative: machine removals without a replacement stage logged are counted as Route 5.

---
## Glossary

| Term | Definition |
|------|------------|
| **λ_CF** (lambda_CF) | Counterfactual fleet turnover rate: the annual rate of emissions stage improvement expected *without* LEZ enforcement, estimated from cold-engaged machines (unprompted arrivals). Units: stage integers per year. |
| **λ_Policy** (lambda_Policy) | Combined fleet improvement rate observed in warm, self-compliant machines (emissions OK on arrival). Captures both natural turnover and proactive LEZ-driven replacement. |
| **λ_Proactive** (lambda_Proactive) | Incremental improvement rate attributable to LEZ policy, computed as max(0, λ_Policy − λ_CF). Floored at zero because negative differences reflect noise, not regression. |
| **ē** (e-bar) | Non-compliance exposure rate: % of all audited machines in a group–phase cell whose initial stage was strictly below the minimum required threshold (schema.md Table 2). Computed on all records (cold + warm). |
| **Route 4** | Audit outcome: initial emissions non-compliant; enforcement actioned; machine replaced or upgraded to a higher emissions stage (final_stage > initial_stage). Proxied here by the enforcement_upgrade flag. |
| **Route 5** | Audit outcome: initial emissions non-compliant; enforcement requested but not actioned; machine remains at original stage. Also captures removals where no replacement stage is recorded (conservative lower bound). |
| **Enforcement success rate** | n(Route 4) / n(Routes 4+5): the fraction of emissions-non-compliant audit records where enforcement resulted in an emissions stage upgrade. Descriptive policy metric only; not used in transition matrices. |
| **WLS** | Weighted least squares regression via lm() with the cell sample size as weights; SE extracted from vcov(). |
| **Cold-engaged** | Machine present on site but not yet actively engaged with the LEZ compliance process; used to estimate the counterfactual turnover rate. |
| **Warm self-compliant** | Machine whose initial emissions stage already met requirements at audit, with no enforcement action required (outcome Route 1). |
| **MAX_STAGE** | Group-specific stage integer ceiling applied when computing mean stage for lambda estimation; CS = 3 (I–IIIA), CAZ+/RoL/VS = 6 (up to Stage V). |
| **Phase A1** | 1 Jan 2016 – 31 Dec 2018: pre-Stage V market availability. |
| **Phase A2** | 1 Jan 2019 – 31 Aug 2020: Stage V newly available. |
| **Phase B** | 1 Sep 2020 – 31 Dec 2024: tighter LEZ requirements. COVID-exempt records (Sep 2020–Mar 2021) excluded. Subdivided into 3 equal-interval segments (B1/B2/B3) for variable-speed groups. |
| **Phase C** | 1 Jan 2025 – 31 Dec 2030: forecast horizon. CAZ+ and Rest of London merged into Variable_Speed (P24 zone). |

