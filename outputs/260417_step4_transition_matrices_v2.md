# Step 4 Transition Matrices — 260417_step4_transition_matrices_v2
*Generated: 2026-04-17 16:06:59*

## 4.1 Replacement probabilities

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 4.1a: Replacement probabilities derived from locked lambda estimates</caption>
 <thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="3"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Natural turnover (lambda_CF → p_cf)</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="2"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Proactive LEZ (lambda_Pro → p_pro)</div></th>
</tr>
  <tr>
   <th style="text-align:left;"> Group </th>
   <th style="text-align:right;"> lambda_CF </th>
   <th style="text-align:right;"> avg_stage_jump </th>
   <th style="text-align:right;"> p_cf </th>
   <th style="text-align:right;"> lambda_Proactive </th>
   <th style="text-align:right;"> p_pro </th>
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
  </tr>
  <tr>
   <td style="text-align:left;"> CAZ_Plus </td>
   <td style="text-align:right;"> 0.2620 </td>
   <td style="text-align:right;"> 1.3019 </td>
   <td style="text-align:right;"> 0.2012 </td>
   <td style="text-align:right;"> 0.0130 </td>
   <td style="text-align:right;"> 0.0100 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Rest_of_London </td>
   <td style="text-align:right;"> 0.2410 </td>
   <td style="text-align:right;"> 1.5008 </td>
   <td style="text-align:right;"> 0.1606 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Variable_Speed </td>
   <td style="text-align:right;"> 0.2453 </td>
   <td style="text-align:right;"> 1.4601 </td>
   <td style="text-align:right;"> 0.1680 </td>
   <td style="text-align:right;"> 0.0027 </td>
   <td style="text-align:right;"> 0.0018 </td>
  </tr>
</tbody>
</table>

p_cf and p_pro are derived by dividing each locked lambda estimate by avg_stage_jump (the gap between the estimation ceiling and the mean observed stage in the cold estimation window).
Variable_Speed values are Phase B cold-N-weighted averages of the CAZ+ and Rest_of_London estimates; CS lambda_Proactive = 0 (floored) and RoL lambda_Proactive = 0 (floored) produce p_pro = 0 for those groups.

![Replacement probabilities by group](260417_step4_transition_matrices_v2_fig4_1_probabilities.png)

Each group shows p_cf (blue, natural counterfactual turnover) and p_pro (orange, proactive LEZ-driven replacement) as annual probabilities.
CS and RoL have p_pro = 0 (lambda_Proactive floored); CAZ+ is the only group with a detectable proactive component (p_pro = 0.013 / avg_jump).

## 4.2 Matrix construction

### Constant_Speed

<table class="table table-bordered" style="width: auto !important; ">
<caption>P_Natural — Constant_Speed (p_cf = 0.2339)</caption>
 <thead>
<tr>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="1"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">From \ To stage</div></th>
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
   <td style="text-align:right;"> 0.7661 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.2339 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> II </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.7661 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.2339 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IIIA </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.7661 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.2339 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IIIB </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.7661 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.2339 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IV </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.7661 </td>
   <td style="text-align:right;"> 0.2339 </td>
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

Rows = origin stage; columns = destination stage; all rows sum to 1. Each non-top stage stays with probability 0.7661 and upgrades directly to Stage V with probability 0.2339 (= p_cf).
The top row (Stage V) is absorbing — machines at Stage V remain there. This is the counterfactual fleet turnover matrix with no LEZ policy effect.

<table class="table table-bordered" style="width: auto !important; ">
<caption>P_Total — Constant_Speed (p_cf + p_pro = 0.2339)</caption>
 <thead>
<tr>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="1"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">From \ To stage</div></th>
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
   <td style="text-align:right;"> 0.7661 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.2339 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> II </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.7661 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.2339 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IIIA </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.7661 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.2339 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IIIB </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.7661 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.2339 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IV </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.7661 </td>
   <td style="text-align:right;"> 0.2339 </td>
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

P_Total encodes both natural turnover and proactive LEZ replacement: combined annual upgrade probability = 0.2339 (p_cf 0.2339 + p_pro 0.0000).
p_pro = 0 for this group, so P_Total is identical to P_Natural; the LEZ proactive channel has no additional effect in the base model.

### Variable_Speed

<table class="table table-bordered" style="width: auto !important; ">
<caption>P_Natural — Variable_Speed (p_cf = 0.1680)</caption>
 <thead>
<tr>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="1"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">From \ To stage</div></th>
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
   <td style="text-align:right;"> 0.832 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.168 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> II </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.832 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.168 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IIIA </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.832 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.168 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IIIB </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.832 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.168 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IV </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.832 </td>
   <td style="text-align:right;"> 0.168 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> V </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 1.000 </td>
  </tr>
</tbody>
</table>

Rows = origin stage; columns = destination stage; all rows sum to 1. Each non-top stage stays with probability 0.8320 and upgrades directly to Stage V with probability 0.1680 (= p_cf).
The top row (Stage V) is absorbing — machines at Stage V remain there. This is the counterfactual fleet turnover matrix with no LEZ policy effect.

<table class="table table-bordered" style="width: auto !important; ">
<caption>P_Total — Variable_Speed (p_cf + p_pro = 0.1698)</caption>
 <thead>
<tr>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="1"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">From \ To stage</div></th>
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
   <td style="text-align:right;"> 0.8302 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.1698 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> II </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.8302 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.1698 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IIIA </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.8302 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.1698 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IIIB </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.8302 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.1698 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IV </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.8302 </td>
   <td style="text-align:right;"> 0.1698 </td>
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

P_Total encodes both natural turnover and proactive LEZ replacement: combined annual upgrade probability = 0.1698 (p_cf 0.1680 + p_pro 0.0018).
P_Total differs from P_Natural only in the off-diagonal upgrade probability; p_pro adds a measurable additional LEZ-driven acceleration.

![P_Total heatmap by group](260417_step4_transition_matrices_v2_fig4_2_ptotal_heatmap.png)

Heatmaps of P_Total for each Phase C group: darker blue = higher transition probability; lighter cells = near-zero. The dominant pattern is a near-diagonal (machines stay) with a single off-diagonal column at Stage V (replacement destination).
CS and Variable_Speed differ in their diagonal values (1 − p_cf − p_pro), reflecting the lower natural turnover rate of the constant-speed generator fleet versus the merged variable-speed fleet.

## 4.3 Validation

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 4.3a: Implied lambda from matrices vs locked estimates (Phase C initialisation)</caption>
 <thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="2"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Natural turnover</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="2"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Full model</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="1"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Proactive increment</div></th>
</tr>
  <tr>
   <th style="text-align:left;"> Group </th>
   <th style="text-align:right;"> lambda_CF (locked) </th>
   <th style="text-align:right;"> lambda(P_Natural) </th>
   <th style="text-align:right;"> lambda_Pro (locked) </th>
   <th style="text-align:right;"> lambda(P_Total) </th>
   <th style="text-align:right;"> marginal lambda_Pro (P_Total - P_Natural) </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:right;"> 0.0510 </td>
   <td style="text-align:right;"> 0.3418 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.3418 </td>
   <td style="text-align:right;"> 0.0000 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Variable_Speed </td>
   <td style="text-align:right;"> 0.2453 </td>
   <td style="text-align:right;"> 0.0622 </td>
   <td style="text-align:right;"> 0.0027 </td>
   <td style="text-align:right;"> 0.0629 </td>
   <td style="text-align:right;"> 0.0007 </td>
  </tr>
</tbody>
</table>

lambda(P_Natural) and lambda(P_Total) are computed by applying each matrix to the Phase C cold initialisation distribution (pi_0) and measuring expected mean stage change per year; deviations from locked values arise because the Phase C stage distribution differs from the estimation-window mean stage.
The marginal lambda_Pro column shows P_Total's additional contribution beyond P_Natural; this should be close to lambda_Proactive (locked) for CAZ+ and near zero for CS and RoL.

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 4.3b: One-step P_Total projection vs actual Phase C cold initialisation</caption>
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
   <td style="text-align:left;"> Phase B3 end (actual cold) </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.057 </td>
   <td style="text-align:right;"> 0.457 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.486 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:left;"> Phase C init projected (B3 × P_Total) </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.044 </td>
   <td style="text-align:right;"> 0.350 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.606 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:left;"> Phase C init actual (P24 cold) </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.077 </td>
   <td style="text-align:right;"> 0.385 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.538 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Variable_Speed </td>
   <td style="text-align:left;"> Phase B3 end (actual cold) </td>
   <td style="text-align:right;"> 0.006 </td>
   <td style="text-align:right;"> 0.006 </td>
   <td style="text-align:right;"> 0.022 </td>
   <td style="text-align:right;"> 0.205 </td>
   <td style="text-align:right;"> 0.174 </td>
   <td style="text-align:right;"> 0.587 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Variable_Speed </td>
   <td style="text-align:left;"> Phase C init projected (B3 × P_Total) </td>
   <td style="text-align:right;"> 0.005 </td>
   <td style="text-align:right;"> 0.005 </td>
   <td style="text-align:right;"> 0.018 </td>
   <td style="text-align:right;"> 0.170 </td>
   <td style="text-align:right;"> 0.144 </td>
   <td style="text-align:right;"> 0.657 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Variable_Speed </td>
   <td style="text-align:left;"> Phase C init actual (P24 cold) </td>
   <td style="text-align:right;"> 0.003 </td>
   <td style="text-align:right;"> 0.009 </td>
   <td style="text-align:right;"> 0.009 </td>
   <td style="text-align:right;"> 0.077 </td>
   <td style="text-align:right;"> 0.136 </td>
   <td style="text-align:right;"> 0.765 </td>
  </tr>
</tbody>
</table>

Each group shows three rows: Phase B3 cold distribution (input), one-step P_Total projection (= B3 × P_Total), and the actual Phase C cold distribution from P24 records.
Systematic under-prediction of Stage V or over-prediction of lower stages would indicate that the combined p_cf + p_pro underestimates the observed fleet transition rate between late Phase B and Phase C.

