# Step 4 Transition Matrices — 260417_step4_transition_matrices_v1
*Generated: 2026-04-17 12:16:51*

## 4.1 Replacement probabilities

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 4.1: Replacement probabilities derived from locked lambda estimates</caption>
 <thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="3"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Natural turnover (lambda_CF → p_cf)</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="2"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Proactive LEZ (lambda_Proactive → p_pro)</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="1"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Enforcement (Phase B)</div></th>
</tr>
  <tr>
   <th style="text-align:left;"> Group </th>
   <th style="text-align:right;"> lambda_CF </th>
   <th style="text-align:right;"> avg_jump </th>
   <th style="text-align:right;"> p_cf </th>
   <th style="text-align:right;"> lambda_Proactive </th>
   <th style="text-align:right;"> p_pro </th>
   <th style="text-align:right;"> p_enf (Phase B) </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:right;"> 0.0510 </td>
   <td style="text-align:right;"> 0.2180 </td>
   <td style="text-align:right;"> 0.2339 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0007 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> CAZ_Plus </td>
   <td style="text-align:right;"> 0.2620 </td>
   <td style="text-align:right;"> 1.3019 </td>
   <td style="text-align:right;"> 0.2012 </td>
   <td style="text-align:right;"> 0.0130 </td>
   <td style="text-align:right;"> 0.0100 </td>
   <td style="text-align:right;"> 0.0009 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Rest_of_London </td>
   <td style="text-align:right;"> 0.2410 </td>
   <td style="text-align:right;"> 1.5008 </td>
   <td style="text-align:right;"> 0.1606 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0008 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Variable_Speed </td>
   <td style="text-align:right;"> 0.2453 </td>
   <td style="text-align:right;"> 1.4601 </td>
   <td style="text-align:right;"> 0.1680 </td>
   <td style="text-align:right;"> 0.0027 </td>
   <td style="text-align:right;"> 0.0018 </td>
   <td style="text-align:right;"> 0.0008 </td>
  </tr>
</tbody>
</table>

p_cf and p_pro are derived by dividing each locked lambda estimate by avg_stage_jump, which is the gap between the estimation-window stage ceiling and the weighted mean observed stage in the cold estimation records.
p_enf is the proportion of Phase B enforcement events (Routes 4 and 5) that resulted in a compliance upgrade (Route 4), annualised by dividing by the Phase B duration (≈4.33 years).

## 4.2 Matrix construction

### P_Total — Constant_Speed

<table class="table table-bordered" style="width: auto !important; ">
<caption>P_Total (Constant_Speed): right-stochastic transition matrix (6×6)</caption>
 <thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="6"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">To stage</div></th>
</tr>
  <tr>
   <th style="text-align:left;">   </th>
   <th style="text-align:right;"> I </th>
   <th style="text-align:right;"> II </th>
   <th style="text-align:right;"> IIIA </th>
   <th style="text-align:right;"> IIIB </th>
   <th style="text-align:right;"> IV </th>
   <th style="text-align:right;"> V </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;font-weight: bold;"> I </td>
   <td style="text-align:right;"> 0.7654 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.2346 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> II </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.7654 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.2346 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IIIA </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.7654 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.2346 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IIIB </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.7654 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.2346 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IV </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.7654 </td>
   <td style="text-align:right;"> 0.2346 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> V </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 1.0000 </td>
  </tr>
</tbody>
</table>

Rows = 'from stage'; columns = 'to stage'. Each row sums to 1 (right-stochastic). p_cf = 0.2339, p_pro = 0.0000, p_enf = 0.0007; P_Total diagonal = 1 − (p_cf + p_pro + p_enf) for non-compliant stages.
Only two columns carry non-zero probability mass: the diagonal (stay) and column VI (Stage V, replacement destination), because all three channels target Stage V in Phase C.

### P_Total — Variable_Speed

<table class="table table-bordered" style="width: auto !important; ">
<caption>P_Total (Variable_Speed): right-stochastic transition matrix (6×6)</caption>
 <thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="6"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">To stage</div></th>
</tr>
  <tr>
   <th style="text-align:left;">   </th>
   <th style="text-align:right;"> I </th>
   <th style="text-align:right;"> II </th>
   <th style="text-align:right;"> IIIA </th>
   <th style="text-align:right;"> IIIB </th>
   <th style="text-align:right;"> IV </th>
   <th style="text-align:right;"> V </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;font-weight: bold;"> I </td>
   <td style="text-align:right;"> 0.8294 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.1706 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> II </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.8294 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.1706 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IIIA </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.8294 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.1706 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IIIB </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.8294 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.1706 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IV </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.8294 </td>
   <td style="text-align:right;"> 0.1706 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> V </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 1.0000 </td>
  </tr>
</tbody>
</table>

Rows = 'from stage'; columns = 'to stage'. Each row sums to 1 (right-stochastic). p_cf = 0.1680, p_pro = 0.0018, p_enf = 0.0008; P_Total diagonal = 1 − (p_cf + p_pro + p_enf) for non-compliant stages.
Only two columns carry non-zero probability mass: the diagonal (stay) and column VI (Stage V, replacement destination), because all three channels target Stage V in Phase C.

## 4.3 Validation

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 4.3a: Implied lambda from matrices vs locked estimates</caption>
 <thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="2"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Natural turnover check</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="2"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Full model check</div></th>
</tr>
  <tr>
   <th style="text-align:left;"> Group </th>
   <th style="text-align:right;"> lambda_CF (locked) </th>
   <th style="text-align:right;"> lambda implied by P_Natural </th>
   <th style="text-align:right;"> lambda_Proactive (locked) </th>
   <th style="text-align:right;"> lambda implied by P_Total </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:right;"> 0.0510 </td>
   <td style="text-align:right;"> 0.3418 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.3429 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Variable_Speed </td>
   <td style="text-align:right;"> 0.2453 </td>
   <td style="text-align:right;"> 0.0622 </td>
   <td style="text-align:right;"> 0.0027 </td>
   <td style="text-align:right;"> 0.0632 </td>
  </tr>
</tbody>
</table>

lambda_implied is computed by applying the matrix to the Phase C cold initialisation distribution and measuring the expected mean stage change per year; it will deviate from the locked lambda if the Phase C stage distribution differs from the estimation-window mean stage.
Close agreement (within ±0.05) confirms that p_cf faithfully encodes the locked lambda in the Phase C fleet context; larger deviations reflect a fleet composition shift between the estimation window and Phase C initialisation.

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 4.3b: One-step P_Total projection vs actual Phase C initialisation distribution</caption>
 <thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="2"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="6"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Stage proportion</div></th>
</tr>
  <tr>
   <th style="text-align:left;"> Group </th>
   <th style="text-align:left;"> Distribution </th>
   <th style="text-align:right;"> I </th>
   <th style="text-align:right;"> II </th>
   <th style="text-align:right;"> IIIA </th>
   <th style="text-align:right;"> IIIB </th>
   <th style="text-align:right;"> IV </th>
   <th style="text-align:right;"> V </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:left;"> Phase B3 end (actual) </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.057 </td>
   <td style="text-align:right;"> 0.457 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.486 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:left;"> Phase C init (projected) </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.044 </td>
   <td style="text-align:right;"> 0.350 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.606 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:left;"> Phase C init (actual P24) </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.077 </td>
   <td style="text-align:right;"> 0.385 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.538 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Variable_Speed </td>
   <td style="text-align:left;"> Phase B3 end (actual) </td>
   <td style="text-align:right;"> 0.006 </td>
   <td style="text-align:right;"> 0.006 </td>
   <td style="text-align:right;"> 0.022 </td>
   <td style="text-align:right;"> 0.205 </td>
   <td style="text-align:right;"> 0.174 </td>
   <td style="text-align:right;"> 0.587 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Variable_Speed </td>
   <td style="text-align:left;"> Phase C init (projected) </td>
   <td style="text-align:right;"> 0.005 </td>
   <td style="text-align:right;"> 0.005 </td>
   <td style="text-align:right;"> 0.018 </td>
   <td style="text-align:right;"> 0.170 </td>
   <td style="text-align:right;"> 0.144 </td>
   <td style="text-align:right;"> 0.657 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Variable_Speed </td>
   <td style="text-align:left;"> Phase C init (actual P24) </td>
   <td style="text-align:right;"> 0.003 </td>
   <td style="text-align:right;"> 0.009 </td>
   <td style="text-align:right;"> 0.009 </td>
   <td style="text-align:right;"> 0.077 </td>
   <td style="text-align:right;"> 0.136 </td>
   <td style="text-align:right;"> 0.765 </td>
  </tr>
</tbody>
</table>

Each group shows three rows: the Phase B3 cold distribution used as input, the one-step P_Total projection (= Phase B3 × P_Total), and the actual Phase C initialisation distribution from P24 cold records.
Close alignment between projected and actual Phase C rows validates that P_Total captures the observed fleet evolution; systematic under-prediction of Stage V or over-prediction of lower stages would indicate that the combined p parameters understate the actual transition rate.

---
## Glossary

| Term | Definition |
|------|------------|
| **P_Natural** | Right-stochastic transition matrix encoding the counterfactual fleet turnover rate (lambda_CF). Each non-top stage transitions to Stage V with probability p_cf per year. |
| **P_Proactive** | Same structure as P_Natural but encodes the proactive LEZ replacement rate (lambda_Proactive). Zero-probability matrix for CS and RoL where lambda_Proactive = 0 (floored). |
| **P_Enforcement** | Right-stochastic matrix encoding enforcement-driven upgrades. Non-compliant stages (i < threshold) transition to the compliance threshold (Stage V = 6 in Phase C) with probability p_enf per year. |
| **P_Total** | Combined matrix: P_Natural + P_Proactive + P_Enforcement channels, combined additively. Row-stochasticity enforced by capping and rescaling. Used for Scenario A and as base for Scenario B Boolean mask in Step 5. |
| **p_cf** | Annual replacement probability under counterfactual: lambda_CF / avg_stage_jump. |
| **p_pro** | Annual proactive replacement probability: lambda_Proactive / avg_stage_jump. |
| **p_enf** | Annual enforcement-driven compliance probability: (n Route 4 / n Routes 4+5) / Phase B years. |
| **avg_stage_jump** | Mean number of stage integers gained per replacement event, computed from the estimation-window cold records as (estimation ceiling) − (weighted mean observed stage). |
| **Right-stochastic** | Matrix where every row sums to 1 and all entries are ≥ 0; each row is a probability distribution over destination stages. |
| **Phase C initialisation (pi_0)** | Stage distribution of P24 cold-engaged records used as the starting state vector for Phase C forecasting. |

