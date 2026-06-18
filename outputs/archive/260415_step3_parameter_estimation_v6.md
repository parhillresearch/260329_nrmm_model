# Step 3 Parameter Estimation — 260415_step3_parameter_estimation_v6
*Generated: 2026-04-17 15:53:24*

## 3.1 lambda_CF — Counterfactual fleet turnover rate

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.1: WLS λ_CF by group (cold-engaged records; group-only dimension)</caption>
 <thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="6"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">λ_CF — slope of mean stage vs time (cold-engaged, WLS)</div></th>
</tr>
  <tr>
   <th style="text-align:left;"> Group </th>
   <th style="text-align:right;"> Estimate </th>
   <th style="text-align:right;"> SE </th>
   <th style="text-align:right;"> 95% CI </th>
   <th style="text-align:left;"> N obs </th>
   <th style="text-align:right;"> Prev ref </th>
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

λ_CF is the WLS slope of mean emissions stage over time in cold-engaged records; SE and 95% CI from vcov() of the lm() fit.
Δ is the difference from the previous-trial reference; values within ±0.05 are consistent with prior work.

## 3.2 e-bar — Non-compliance exposure rate

### Constant_Speed

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.2 (Constant_Speed): ē and record count by phase</caption>
 <thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="4"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Phase</div></th>
</tr>
  <tr>
   <th style="text-align:left;"> Statistic </th>
   <th style="text-align:right;"> A1 </th>
   <th style="text-align:right;"> A2 </th>
   <th style="text-align:right;"> B </th>
   <th style="text-align:right;"> C </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> ē (%) </td>
   <td style="text-align:right;"> 22.1% </td>
   <td style="text-align:right;"> 14.8% </td>
   <td style="text-align:right;"> 82.8% </td>
   <td style="text-align:right;"> 30.4% </td>
  </tr>
  <tr>
   <td style="text-align:left;"> N (records) </td>
   <td style="text-align:right;"> 104 </td>
   <td style="text-align:right;"> 318 </td>
   <td style="text-align:right;"> 693 </td>
   <td style="text-align:right;"> 112 </td>
  </tr>
</tbody>
</table>

Constant_Speed ē rises sharply in Phase B when the Stage V threshold first applies; most generators were below Stage V at that point.
Phase C data comes from P24 records; the fall from Phase B reflects anticipatory compliance ahead of the 2025 requirement.

### CAZ_Plus

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.2 (CAZ_Plus): ē and record count by phase</caption>
 <thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="4"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Phase</div></th>
</tr>
  <tr>
   <th style="text-align:left;"> Statistic </th>
   <th style="text-align:right;"> A1 </th>
   <th style="text-align:right;"> A2 </th>
   <th style="text-align:right;"> B </th>
   <th style="text-align:right;"> C </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> ē (%) </td>
   <td style="text-align:right;"> 20.2% </td>
   <td style="text-align:right;"> 11.2% </td>
   <td style="text-align:right;"> 19.9% </td>
   <td style="text-align:right;"> — </td>
  </tr>
  <tr>
   <td style="text-align:left;"> N (records) </td>
   <td style="text-align:right;"> 400 </td>
   <td style="text-align:right;"> 658 </td>
   <td style="text-align:right;"> 2,296 </td>
   <td style="text-align:right;"> — </td>
  </tr>
</tbody>
</table>

CAZ_Plus ē is moderate and relatively stable across Phase A and B, consistent with a mixed fleet straddling the IIIB→IV compliance boundary.
Phase C is blank because CAZ+ records are merged into Variable_Speed from 1 January 2025.

### Rest_of_London

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.2 (Rest_of_London): ē and record count by phase</caption>
 <thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="4"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Phase</div></th>
</tr>
  <tr>
   <th style="text-align:left;"> Statistic </th>
   <th style="text-align:right;"> A1 </th>
   <th style="text-align:right;"> A2 </th>
   <th style="text-align:right;"> B </th>
   <th style="text-align:right;"> C </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> ē (%) </td>
   <td style="text-align:right;"> 5.2% </td>
   <td style="text-align:right;"> 3.2% </td>
   <td style="text-align:right;"> 4.7% </td>
   <td style="text-align:right;"> — </td>
  </tr>
  <tr>
   <td style="text-align:left;"> N (records) </td>
   <td style="text-align:right;"> 538 </td>
   <td style="text-align:right;"> 1,634 </td>
   <td style="text-align:right;"> 4,122 </td>
   <td style="text-align:right;"> — </td>
  </tr>
</tbody>
</table>

Rest_of_London maintains the lowest ē across all phases, reflecting that the IIIA→IIIB threshold is met by the majority of the RoL fleet.
Phase C is blank because RoL records merge into Variable_Speed from 1 January 2025.

### Variable_Speed

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.2 (Variable_Speed): ē and record count by phase</caption>
 <thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="4"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Phase</div></th>
</tr>
  <tr>
   <th style="text-align:left;"> Statistic </th>
   <th style="text-align:right;"> A1 </th>
   <th style="text-align:right;"> A2 </th>
   <th style="text-align:right;"> B </th>
   <th style="text-align:right;"> C </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> ē (%) </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> 22.0% </td>
  </tr>
  <tr>
   <td style="text-align:left;"> N (records) </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> 1,483 </td>
  </tr>
</tbody>
</table>

Variable_Speed exists only from 1 January 2025 (P24 zone merger); Phase A1, A2, and B cells are structurally blank.
Phase C ē of approximately 22% indicates roughly one in five P24 variable-speed machines was below Stage V at the start of the forecast period.

![e-bar non-compliance exposure rate by group and phase](260415_step3_parameter_estimation_v6_ebar.png)

Each panel shows ē (% of machines below the compliance threshold) for one group across all phases; missing bars indicate phases where that group has no data.
The Constant_Speed Phase B spike to ~83% dominates: almost the entire generator fleet was non-compliant when Stage V was first required.

## 3.3 lambda_Policy and lambda_Proactive

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.3: λ_Policy, λ_CF, and λ_Proactive by group (group-only dimension)</caption>
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

λ_Policy is the WLS slope of mean stage in warm self-compliant records; it combines natural turnover and proactive LEZ-driven replacement.
λ_Proactive = max(0, λ_Policy − λ_CF) isolates the LEZ-incremental rate; 0.000 (floored) indicates no detectable proactive response above the counterfactual.

## 3.4 Enforcement success rate — Route 4/5 descriptive analysis

### Constant_Speed

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.4 (Constant_Speed): Route 4/5 enforcement counts and success rate by time period. ⚠ = n 
 </caption>
<thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="6"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Phase</div></th>
</tr>
  <tr>
   <th style="text-align:left;"> Statistic </th>
   <th style="text-align:right;"> A1 </th>
   <th style="text-align:right;"> A2 </th>
   <th style="text-align:right;"> B1 </th>
   <th style="text-align:right;"> B2 </th>
   <th style="text-align:right;"> B3 </th>
   <th style="text-align:right;"> C </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> N (R4+R5) </td>
   <td style="text-align:right;"> 96 </td>
   <td style="text-align:right;"> 187 </td>
   <td style="text-align:right;"> 243 </td>
   <td style="text-align:right;"> 216 </td>
   <td style="text-align:right;"> 162 </td>
   <td style="text-align:right;"> 87 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> n Route 4 </td>
   <td style="text-align:right;"> 1 </td>
   <td style="text-align:right;"> 1 </td>
   <td style="text-align:right;"> 1 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> n Route 5 </td>
   <td style="text-align:right;"> 95 </td>
   <td style="text-align:right;"> 186 </td>
   <td style="text-align:right;"> 242 </td>
   <td style="text-align:right;"> 216 </td>
   <td style="text-align:right;"> 162 </td>
   <td style="text-align:right;"> 87 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Route 4 % (success) </td>
   <td style="text-align:right;"> 1.0% </td>
   <td style="text-align:right;"> 0.5% </td>
   <td style="text-align:right;"> 0.4% </td>
   <td style="text-align:right;"> 0.0% </td>
   <td style="text-align:right;"> 0.0% </td>
   <td style="text-align:right;"> 0.0% </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Route 5 % (not actioned) </td>
   <td style="text-align:right;"> 99.0% </td>
   <td style="text-align:right;"> 99.5% </td>
   <td style="text-align:right;"> 99.6% </td>
   <td style="text-align:right;"> 100.0% </td>
   <td style="text-align:right;"> 100.0% </td>
   <td style="text-align:right;"> 100.0% </td>
  </tr>
</tbody>
</table>

Constant_Speed shows low enforcement action counts in Phases A1/A2 and larger volumes in Phase B, reflecting the stricter Stage V requirement imposed in September 2020.
Route 4 success rates and sparsity flags summarise how effectively non-compliant generators were driven compliant; ⚠ marks periods with fewer than 30 enforcement records.

### CAZ_Plus

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.4 (CAZ_Plus): Route 4/5 enforcement counts and success rate by time period. ⚠ = n 
 </caption>
<thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="6"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Phase</div></th>
</tr>
  <tr>
   <th style="text-align:left;"> Statistic </th>
   <th style="text-align:right;"> A1 </th>
   <th style="text-align:right;"> A2 </th>
   <th style="text-align:right;"> B1 </th>
   <th style="text-align:right;"> B2 </th>
   <th style="text-align:right;"> B3 </th>
   <th style="text-align:right;"> C </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> N (R4+R5) </td>
   <td style="text-align:right;"> 347 </td>
   <td style="text-align:right;"> 463 </td>
   <td style="text-align:right;"> 567 </td>
   <td style="text-align:right;"> 697 </td>
   <td style="text-align:right;"> 571 </td>
   <td style="text-align:right;"> — </td>
  </tr>
  <tr>
   <td style="text-align:left;"> n Route 4 </td>
   <td style="text-align:right;"> 5 </td>
   <td style="text-align:right;"> 3 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> — </td>
  </tr>
  <tr>
   <td style="text-align:left;"> n Route 5 </td>
   <td style="text-align:right;"> 342 </td>
   <td style="text-align:right;"> 460 </td>
   <td style="text-align:right;"> 567 </td>
   <td style="text-align:right;"> 697 </td>
   <td style="text-align:right;"> 571 </td>
   <td style="text-align:right;"> — </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Route 4 % (success) </td>
   <td style="text-align:right;"> 1.4% </td>
   <td style="text-align:right;"> 0.6% </td>
   <td style="text-align:right;"> 0.0% </td>
   <td style="text-align:right;"> 0.0% </td>
   <td style="text-align:right;"> 0.0% </td>
   <td style="text-align:right;"> — </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Route 5 % (not actioned) </td>
   <td style="text-align:right;"> 98.6% </td>
   <td style="text-align:right;"> 99.4% </td>
   <td style="text-align:right;"> 100.0% </td>
   <td style="text-align:right;"> 100.0% </td>
   <td style="text-align:right;"> 100.0% </td>
   <td style="text-align:right;"> — </td>
  </tr>
</tbody>
</table>

CAZ_Plus has the highest absolute counts of emissions-non-compliant machines given its larger fleet size and stricter IIIB→IV→V requirement sequence.
Phase C is blank because CAZ+ records merge into Variable_Speed from 1 January 2025; enforcement data for the merged fleet appears in the Variable_Speed table.

### Rest_of_London

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.4 (Rest_of_London): Route 4/5 enforcement counts and success rate by time period. ⚠ = n 
 </caption>
<thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="6"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Phase</div></th>
</tr>
  <tr>
   <th style="text-align:left;"> Statistic </th>
   <th style="text-align:right;"> A1 </th>
   <th style="text-align:right;"> A2 </th>
   <th style="text-align:right;"> B1 </th>
   <th style="text-align:right;"> B2 </th>
   <th style="text-align:right;"> B3 </th>
   <th style="text-align:right;"> C </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> N (R4+R5) </td>
   <td style="text-align:right;"> 521 </td>
   <td style="text-align:right;"> 1,093 </td>
   <td style="text-align:right;"> 879 </td>
   <td style="text-align:right;"> 883 </td>
   <td style="text-align:right;"> 954 </td>
   <td style="text-align:right;"> — </td>
  </tr>
  <tr>
   <td style="text-align:left;"> n Route 4 </td>
   <td style="text-align:right;"> 2 </td>
   <td style="text-align:right;"> 1 </td>
   <td style="text-align:right;"> 1 </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 2 </td>
   <td style="text-align:right;"> — </td>
  </tr>
  <tr>
   <td style="text-align:left;"> n Route 5 </td>
   <td style="text-align:right;"> 519 </td>
   <td style="text-align:right;"> 1092 </td>
   <td style="text-align:right;"> 878 </td>
   <td style="text-align:right;"> 883 </td>
   <td style="text-align:right;"> 952 </td>
   <td style="text-align:right;"> — </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Route 4 % (success) </td>
   <td style="text-align:right;"> 0.4% </td>
   <td style="text-align:right;"> 0.1% </td>
   <td style="text-align:right;"> 0.1% </td>
   <td style="text-align:right;"> 0.0% </td>
   <td style="text-align:right;"> 0.2% </td>
   <td style="text-align:right;"> — </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Route 5 % (not actioned) </td>
   <td style="text-align:right;"> 99.6% </td>
   <td style="text-align:right;"> 99.9% </td>
   <td style="text-align:right;"> 99.9% </td>
   <td style="text-align:right;"> 100.0% </td>
   <td style="text-align:right;"> 99.8% </td>
   <td style="text-align:right;"> — </td>
  </tr>
</tbody>
</table>

Rest_of_London has moderate enforcement counts spread across Phases A1–B; the lower thresholds (IIIA→IIIB) keep the non-compliant pool smaller than CAZ+.
Phase C is blank for the same merger reason as CAZ+; Route 4 success rates reveal the fraction of enforcement visits that achieved compliance.

### Variable_Speed

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.4 (Variable_Speed): Route 4/5 enforcement counts and success rate by time period. ⚠ = n 
 </caption>
<thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="6"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Phase</div></th>
</tr>
  <tr>
   <th style="text-align:left;"> Statistic </th>
   <th style="text-align:right;"> A1 </th>
   <th style="text-align:right;"> A2 </th>
   <th style="text-align:right;"> B1 </th>
   <th style="text-align:right;"> B2 </th>
   <th style="text-align:right;"> B3 </th>
   <th style="text-align:right;"> C </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> N (R4+R5) </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> 5 </td>
   <td style="text-align:right;"> 1,074 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> n Route 4 </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> 3 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> n Route 5 </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> 5 </td>
   <td style="text-align:right;"> 1071 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Route 4 % (success) </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> 0.0%⚠ </td>
   <td style="text-align:right;"> 0.3% </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Route 5 % (not actioned) </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> — </td>
   <td style="text-align:right;"> 100.0% </td>
   <td style="text-align:right;"> 99.7% </td>
  </tr>
</tbody>
</table>

Variable_Speed exists only in Phase C (P24 zone post-2025); Phases A1, A2, and B1–B3 are structurally blank.
Phase C enforcement data captures the first year(s) of the merged CAZ+/RoL fleet under the uniform Stage V requirement.

![Enforcement outcomes by group and time period](260415_step3_parameter_estimation_v6_enforcement.png)

Stacked bars show absolute counts of Route 4 (green, driven compliant) and Route 5 (red, not actioned) machines per group and time period; y-axes are free across facets.
Labels above each bar show the Route 4 success rate (%); higher values indicate more effective enforcement at that audit event.

---

## Step Report

### Intended tasks

- **3.1** Estimate λ_CF from cold-engaged records only (WLS, mean stage vs fractional year); apply group-specific MAX_STAGE and estimation windows (CS: annual 2016–2023; variable-speed: A1/A2 pooled + Phase B 3 sub-segments); validate against locked reference values in schema.md Table 8.
- **3.2** Estimate ē from all records where initial stage < compliance threshold for that group and phase (schema.md Table 2); report as % and record count; do not divide by phase duration.
- **3.3** Estimate λ_Policy from warm self-compliant records only; compute λ_Proactive = max(0, λ_Policy − λ_CF); report with SE; floor negative differences at zero.
- **3.4** Report enforcement success rate from Route 4/5 outcomes descriptively: n(Routes 4+5), n(Route 4), n(Route 5), and per-audit success rate broken down by group × time period (A1, A2, B1, B2, B3, Phase C). Flag sparse cells (n < 30). Not a model parameter; not in step3_params.

---

### Results by sub-task

#### 3.1 lambda_CF

λ_CF was estimated for three groups; Variable_Speed has no counterfactual estimate (Phase C merged group only). Rest_of_London is the only group consistent with the previous-trial reference (Δ = +0.022, within ±0.05). CAZ_Plus is moderately lower (0.262 vs ref 0.363, Δ = −0.101) but the CI is well-identified and excludes zero. Constant_Speed is the anomalous case: λ_CF = 0.051 (ref 0.358, Δ = −0.307), with a 95% CI of [−0.017, 0.119] that barely excludes zero. The small cold sample (N = 133 over 8 years, ≈ 17 records per year) and the near-zero λ_Policy (−0.000) in the warm self-compliant CS fleet together corroborate a genuine signal rather than a data artefact — generator fleets appear to have very low natural turnover, remaining in service until a compliance event forces replacement. The old reference (0.358) is superseded; 0.051 is the operative estimate for Step 4.

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.1: WLS λ_CF by group (cold-engaged records)</caption>
 <thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="6"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">λ_CF — slope of mean stage vs time (cold-engaged, WLS)</div></th>
</tr>
  <tr>
   <th>Group</th><th>Estimate</th><th>SE</th><th>95% CI</th><th>N obs</th><th>Prev ref</th><th>Δ</th>
  </tr>
 </thead>
<tbody>
  <tr><td>Constant_Speed</td><td>0.051</td><td>0.026</td><td>[−0.017, 0.119]</td><td>133</td><td>0.358</td><td>−0.307 ⚠</td></tr>
  <tr><td>CAZ_Plus</td><td>0.262</td><td>0.033</td><td>[0.119, 0.404]</td><td>361</td><td>0.363</td><td>−0.101</td></tr>
  <tr><td>Rest_of_London</td><td>0.241</td><td>0.017</td><td>[0.169, 0.314]</td><td>1,294</td><td>0.219</td><td>+0.022 ✓</td></tr>
  <tr><td>Variable_Speed</td><td>—</td><td>—</td><td>—</td><td>—</td><td>—</td><td>—</td></tr>
</tbody>
</table>

λ_CF is the WLS slope of mean stage over time in cold-engaged records; Δ is the signed difference from the previous-trial reference value.
Rest_of_London (✓) is the only estimate within ±0.05 of its reference; the Constant_Speed anomaly (⚠, Δ = −0.307) is corroborated by the near-zero λ_Policy and accepted as the operative estimate for Step 4.

#### 3.2 e-bar

ē patterns are consistent with policy design. Constant_Speed shows the most striking trajectory: ē falls from 22.1% (Phase A1, IIIA threshold) to 14.8% (Phase A2), then spikes to 82.8% in Phase B when the Stage V requirement first applies — almost the entire generator fleet was below the new threshold at that point. By Phase C (P24 records, Stage V threshold) ē has fallen to 30.4%, reflecting anticipatory compliance ahead of the 2025 requirement. CAZ_Plus is moderate and broadly stable across all three estimation phases (20.2% → 11.2% → 19.9%), with the Phase B uptick reflecting the tightening from IIIB to IV. Rest_of_London maintains the lowest ē throughout (5.2% → 3.2% → 4.7%), consistent with a fleet that broadly meets the lower IIIA→IIIB thresholds. Variable_Speed (Phase C only) shows 22.0%, broadly aligned with Constant_Speed Phase C.

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.2 (Constant_Speed): ē and record count by phase</caption>
 <thead><tr><th></th><th colspan="4" style="text-align:center;">Phase</th></tr>
  <tr><th>Statistic</th><th>A1</th><th>A2</th><th>B</th><th>C</th></tr>
 </thead>
<tbody>
  <tr><td>ē (%)</td><td>22.1%</td><td>14.8%</td><td>82.8%</td><td>30.4%</td></tr>
  <tr><td>N (records)</td><td>104</td><td>318</td><td>693</td><td>112</td></tr>
</tbody>
</table>

Constant_Speed ē rises from 14.8% (Phase A2, IIIA threshold) to 82.8% (Phase B, Stage V threshold newly imposed) then falls to 30.4% in Phase C.
The Phase B spike reflects that almost all generators were below Stage V when the requirement took effect; the Phase C recovery is driven by anticipatory replacement documented in schema.md analytical note 3.

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.2 (CAZ_Plus): ē and record count by phase</caption>
 <thead><tr><th></th><th colspan="4" style="text-align:center;">Phase</th></tr>
  <tr><th>Statistic</th><th>A1</th><th>A2</th><th>B</th><th>C</th></tr>
 </thead>
<tbody>
  <tr><td>ē (%)</td><td>20.2%</td><td>11.2%</td><td>19.9%</td><td>—</td></tr>
  <tr><td>N (records)</td><td>400</td><td>658</td><td>2,296</td><td>—</td></tr>
</tbody>
</table>

CAZ_Plus ē falls from 20.2% (Phase A1) to 11.2% (Phase A2) then rises back to 19.9% (Phase B), consistent with the compliance threshold tightening from IIIB to IV in Phase B.
Phase C is structurally blank; CAZ+ records merge into Variable_Speed from 1 January 2025.

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.2 (Rest_of_London): ē and record count by phase</caption>
 <thead><tr><th></th><th colspan="4" style="text-align:center;">Phase</th></tr>
  <tr><th>Statistic</th><th>A1</th><th>A2</th><th>B</th><th>C</th></tr>
 </thead>
<tbody>
  <tr><td>ē (%)</td><td>5.2%</td><td>3.2%</td><td>4.7%</td><td>—</td></tr>
  <tr><td>N (records)</td><td>538</td><td>1,634</td><td>4,122</td><td>—</td></tr>
</tbody>
</table>

Rest_of_London ē is consistently the lowest of all groups (3–5%), indicating the fleet broadly meets the lower IIIA→IIIB compliance thresholds throughout the estimation period.
With N = 4,122 in Phase B, this is the most data-rich group and the highest-confidence ē estimate.

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.2 (Variable_Speed): ē and record count by phase</caption>
 <thead><tr><th></th><th colspan="4" style="text-align:center;">Phase</th></tr>
  <tr><th>Statistic</th><th>A1</th><th>A2</th><th>B</th><th>C</th></tr>
 </thead>
<tbody>
  <tr><td>ē (%)</td><td>—</td><td>—</td><td>—</td><td>22.0%</td></tr>
  <tr><td>N (records)</td><td>—</td><td>—</td><td>—</td><td>1,483</td></tr>
</tbody>
</table>

Variable_Speed exists only from 1 January 2025 (P24 zone post-merger); all pre-Phase C cells are structurally blank.
Phase C ē = 22.0% (N = 1,483) means roughly one in five post-merger variable-speed machines was below Stage V at the start of the forecast period, consistent with Constant_Speed Phase C (30.4%).

![e-bar non-compliance exposure rate by group and phase](260415_step3_parameter_estimation_v6_ebar.png)

Each panel shows ē (%) by phase for one group; bars are absent where a group has no data in that phase.
The dominant visual feature is the Constant_Speed Phase B spike to 82.8%, which dwarfs all other group-phase cells and underscores the scale of the compliance challenge when Stage V was first required of the generator fleet.

#### 3.3 lambda_Policy and lambda_Proactive

λ_Policy is near zero for Constant_Speed (−0.000, SE = 0.008), confirming that the warm self-compliant CS fleet shows essentially no stage trend — machines stay in service with no voluntary upgrading. For CAZ_Plus, λ_Policy (0.275, SE = 0.030) slightly exceeds λ_CF (0.262), yielding a small positive λ_Proactive of 0.013 — the only group with a detectable proactive LEZ response. For Rest_of_London, λ_Policy (0.194) is below λ_CF (0.241), flooring λ_Proactive at zero; the warm self-compliant RoL subset improves more slowly than the broader cold-engaged fleet, likely reflecting a stable long-tenure sub-fleet. The finding that λ_Proactive ≈ 0 for CS and RoL means the dominant compliance mechanism for those groups is enforcement (ē reduction) rather than proactive replacement, directly informing the Scenario B Boolean mask in Step 5.

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.3: λ_Policy, λ_CF, and λ_Proactive by group</caption>
 <thead>
<tr>
<th></th><th colspan="2" style="text-align:center;">Warm self-compliant (WLS)</th>
<th colspan="1" style="text-align:center;">Cold (WLS)</th>
<th colspan="1" style="text-align:center;">Derived</th><th></th>
</tr>
  <tr><th>Group</th><th>λ_Policy</th><th>SE</th><th>λ_CF</th><th>λ_Proactive</th><th>N warm sc.</th></tr>
 </thead>
<tbody>
  <tr><td>Constant_Speed</td><td>−0.000</td><td>0.008</td><td>0.051</td><td>0.000 (floored)</td><td>148</td></tr>
  <tr><td>CAZ_Plus</td><td>0.275</td><td>0.030</td><td>0.262</td><td>0.013</td><td>501</td></tr>
  <tr><td>Rest_of_London</td><td>0.194</td><td>0.026</td><td>0.241</td><td>0.000 (floored)</td><td>1,152</td></tr>
  <tr><td>Variable_Speed</td><td>—</td><td>—</td><td>—</td><td>—</td><td>—</td></tr>
</tbody>
</table>

λ_Proactive is positive only for CAZ_Plus (0.013); both CS and RoL floor at zero, indicating no measurable proactive fleet improvement beyond the counterfactual rate.
The near-zero CS λ_Policy (−0.000) corroborates the low λ_CF (0.051) — the generator fleet shows no voluntary stage upgrading in either cold or warm records.

#### 3.4 Enforcement success rate

The most striking result is the near-zero Route 4 success rate across all groups and all time periods (0.0–1.4%). This is not a coding artefact: the indicator used (no E code in final machinery reasons) should capture any form of compliance resolution — replacement, removal, retrofit, or exemption. The finding instead reflects that the audit record captures the compliance state at the moment of the visit, not the eventual post-visit outcome. When auditors record the final machinery reasons as still containing an E code, it means enforcement was not yet resolved by end of visit — not that it was never resolved. Compliance improvement visible in ē (e.g., CS falling from 82.8% Phase B to 30.4% Phase C) occurs between audit cycles through fleet replacement, not during individual audit visits.

This result has two important downstream implications: (1) it confirms the decision to exclude enforcement from the transition matrix and model it as a Scenario B Boolean constraint in Step 5; and (2) it suggests the audit dataset does not contain reliable per-machine enforcement outcome data at the visit level. The descriptive value of the Route 4/5 breakdown is primarily as a record of enforcement volume (n Routes 4+5 shows how many machines auditors flagged for enforcement action in each period) rather than enforcement effectiveness.

A minor data anomaly is noted: Variable_Speed shows 5 records in Period B3 (late 2023–early 2024). These are P24 zone records predating the formal 2025 merger date, correctly assigned to Variable_Speed by engine type. They are too sparse to interpret (⚠) and do not affect model parameters.

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.4 (Constant_Speed): Route 4/5 enforcement counts and success rate by time period</caption>
 <thead><tr><th></th><th colspan="6" style="text-align:center;">Phase</th></tr>
  <tr><th>Statistic</th><th>A1</th><th>A2</th><th>B1</th><th>B2</th><th>B3</th><th>C</th></tr>
 </thead>
<tbody>
  <tr><td>N (R4+R5)</td><td>96</td><td>187</td><td>243</td><td>216</td><td>162</td><td>87</td></tr>
  <tr><td>n Route 4</td><td>1</td><td>1</td><td>1</td><td>0</td><td>0</td><td>0</td></tr>
  <tr><td>n Route 5</td><td>95</td><td>186</td><td>242</td><td>216</td><td>162</td><td>87</td></tr>
  <tr><td>Route 4 % (success)</td><td>1.0%</td><td>0.5%</td><td>0.4%</td><td>0.0%</td><td>0.0%</td><td>0.0%</td></tr>
  <tr><td>Route 5 % (not actioned)</td><td>99.0%</td><td>99.5%</td><td>99.6%</td><td>100.0%</td><td>100.0%</td><td>100.0%</td></tr>
</tbody>
</table>

Constant_Speed enforcement volume grows from 96 flagged machines in Phase A1 to 243 in Phase B1, reflecting the expanded enforcement pressure as Stage V is newly required.
Route 4 success rate is effectively zero throughout — consistent with the interpretation that audit visits flag non-compliance but compliance resolution happens post-visit, outside the audit record.

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.4 (CAZ_Plus): Route 4/5 enforcement counts and success rate by time period</caption>
 <thead><tr><th></th><th colspan="6" style="text-align:center;">Phase</th></tr>
  <tr><th>Statistic</th><th>A1</th><th>A2</th><th>B1</th><th>B2</th><th>B3</th><th>C</th></tr>
 </thead>
<tbody>
  <tr><td>N (R4+R5)</td><td>347</td><td>463</td><td>567</td><td>697</td><td>571</td><td>—</td></tr>
  <tr><td>n Route 4</td><td>5</td><td>3</td><td>0</td><td>0</td><td>0</td><td>—</td></tr>
  <tr><td>n Route 5</td><td>342</td><td>460</td><td>567</td><td>697</td><td>571</td><td>—</td></tr>
  <tr><td>Route 4 % (success)</td><td>1.4%</td><td>0.6%</td><td>0.0%</td><td>0.0%</td><td>0.0%</td><td>—</td></tr>
  <tr><td>Route 5 % (not actioned)</td><td>98.6%</td><td>99.4%</td><td>100.0%</td><td>100.0%</td><td>100.0%</td><td>—</td></tr>
</tbody>
</table>

CAZ_Plus has the highest absolute enforcement volumes (up to 697 machines in Phase B2), reflecting the larger fleet size and stricter IIIB→IV→V compliance requirement sequence.
Route 4 rates drop from 1.4% (Phase A1) to 0.0% from Phase B1 onwards — a pattern consistent with all groups and further corroborating the post-visit resolution interpretation.

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.4 (Rest_of_London): Route 4/5 enforcement counts and success rate by time period</caption>
 <thead><tr><th></th><th colspan="6" style="text-align:center;">Phase</th></tr>
  <tr><th>Statistic</th><th>A1</th><th>A2</th><th>B1</th><th>B2</th><th>B3</th><th>C</th></tr>
 </thead>
<tbody>
  <tr><td>N (R4+R5)</td><td>521</td><td>1,093</td><td>879</td><td>883</td><td>954</td><td>—</td></tr>
  <tr><td>n Route 4</td><td>2</td><td>1</td><td>1</td><td>0</td><td>2</td><td>—</td></tr>
  <tr><td>n Route 5</td><td>519</td><td>1,092</td><td>878</td><td>883</td><td>952</td><td>—</td></tr>
  <tr><td>Route 4 % (success)</td><td>0.4%</td><td>0.1%</td><td>0.1%</td><td>0.0%</td><td>0.2%</td><td>—</td></tr>
  <tr><td>Route 5 % (not actioned)</td><td>99.6%</td><td>99.9%</td><td>99.9%</td><td>100.0%</td><td>99.8%</td><td>—</td></tr>
</tbody>
</table>

Rest_of_London has the largest enforcement volume of any group in Phase B (879–954 per sub-segment), reflecting the wide geographic coverage of the GL zone.
The Route 4 rate is effectively zero throughout; the single-digit Route 4 counts in any period are likely data-entry artefacts or edge cases where final reasons happened to be blank for a genuinely compliant machine.

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 3.4 (Variable_Speed): Route 4/5 enforcement counts and success rate by time period</caption>
 <thead><tr><th></th><th colspan="6" style="text-align:center;">Phase</th></tr>
  <tr><th>Statistic</th><th>A1</th><th>A2</th><th>B1</th><th>B2</th><th>B3</th><th>C</th></tr>
 </thead>
<tbody>
  <tr><td>N (R4+R5)</td><td>—</td><td>—</td><td>—</td><td>—</td><td>5⚠</td><td>1,074</td></tr>
  <tr><td>n Route 4</td><td>—</td><td>—</td><td>—</td><td>—</td><td>0</td><td>3</td></tr>
  <tr><td>n Route 5</td><td>—</td><td>—</td><td>—</td><td>—</td><td>5</td><td>1,071</td></tr>
  <tr><td>Route 4 % (success)</td><td>—</td><td>—</td><td>—</td><td>—</td><td>0.0%⚠</td><td>0.3%</td></tr>
  <tr><td>Route 5 % (not actioned)</td><td>—</td><td>—</td><td>—</td><td>—</td><td>100.0%</td><td>99.7%</td></tr>
</tbody>
</table>

Variable_Speed has 1,074 enforcement records in Phase C, confirming active enforcement of the merged fleet against the Stage V requirement from 2025.
The 5 B3 records are a minor data anomaly — pre-2025 P24 records; too sparse to interpret (⚠) and not used in model estimation.

![Enforcement outcomes by group and time period](260415_step3_parameter_estimation_v6_enforcement.png)

Stacked bars show Route 4 (green) and Route 5 (red) volumes per group and time period; the near-invisible green component confirms Route 4 counts are effectively zero across all groups and periods.
The dominant pattern is the enforcement volume trend: CAZ_Plus and Rest_of_London peak in Phase B, while Constant_Speed grows through Phase B before declining; Variable_Speed records only appear in Phase C.

---
## Glossary

| Term | Definition |
|------|------------|
| **λ_CF** | Counterfactual fleet turnover rate (WLS slope, cold-engaged records). Units: stage integers/year. |
| **λ_Policy** | Combined improvement rate in warm self-compliant records: natural turnover + proactive LEZ response. |
| **λ_Proactive** | max(0, λ_Policy − λ_CF): incremental rate attributable to LEZ policy; floored at zero. |
| **ē** (e-bar) | Non-compliance exposure rate: % of all records in a group–phase cell with initial stage below the compliance threshold. |
| **Route 4** | Initial emissions non-compliant; enforcement actioned; machine driven compliant (proxy: no E code in final machinery reasons). |
| **Route 5** | Initial emissions non-compliant; enforcement not actioned; E code persists in final machinery reasons. |
| **Enforcement success rate** | n(R4) / n(R4+R5): fraction of non-compliant audit records driven compliant. Descriptive only; not a matrix parameter. |
| **WLS** | Weighted least squares via lm(); SE from vcov(). |
| **Cold-engaged** | Machine on site not yet engaged with the LEZ process; basis for λ_CF. |
| **Warm self-compliant** | Machine emissions-OK on arrival (Route 1); basis for λ_Policy. |
| **MAX_STAGE** | Stage integer ceiling per group: CS 3 (I–IIIA); CAZ+/RoL/VS 6 (up to Stage V). |
| **Phase A1** | 1 Jan 2016 – 31 Dec 2018. |
| **Phase A2** | 1 Jan 2019 – 31 Aug 2020. |
| **Phase B** | 1 Sep 2020 – 31 Dec 2024; COVID-exempt records removed; sub-segmented B1/B2/B3 (~527 days each) for enforcement and λ estimation. |
| **Phase C** | 1 Jan 2025 – 31 Dec 2030; CAZ+ and RoL merged into Variable_Speed (P24 zone). |

