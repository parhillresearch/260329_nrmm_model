# Step 4 Transition Matrices — 260417_step4_transition_matrices_v3
*Generated: 2026-04-17 16:35:05*

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
   <td style="text-align:right;"> 3.2180 </td>
   <td style="text-align:right;"> 0.0158 </td>
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

p_cf and p_pro are derived by dividing each locked lambda estimate by avg_stage_jump. avg_stage_jump = FORECAST_MAX_STAGE (6) minus the mean observed stage in the cold estimation window (capped at Stage V), so that p is denominated in the same 6-stage space as the forecast matrices.
Variable_Speed values are Phase B cold-N-weighted averages of CAZ+ and RoL. CS and RoL lambda_Proactive = 0 (floored), producing p_pro = 0 for those groups.

![Replacement probabilities by group](260417_step4_transition_matrices_v3_fig4_1_probabilities.png)

Each group shows p_cf (blue, natural counterfactual turnover) and p_pro (orange, proactive LEZ-driven replacement) as annual probabilities.
CS p_cf is low (~0.016) consistent with lambda_CF = 0.051 and a large avg_stage_jump (~3.2 stages to Stage V); CAZ+ and RoL p_cf are higher (~0.10–0.16) with smaller avg_stage_jumps.

## 4.2 Matrix construction

### Constant_Speed

<table class="table table-bordered" style="width: auto !important; ">
<caption>P_Natural — Constant_Speed (p_cf = 0.0158)</caption>
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
   <td style="text-align:right;"> 0.9842 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0158 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> II </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.9842 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0158 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IIIA </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.9842 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0158 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IIIB </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.9842 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0158 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IV </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.9842 </td>
   <td style="text-align:right;"> 0.0158 </td>
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

Rows = origin stage; columns = destination stage; all rows sum to 1. Each non-top stage stays with probability 0.9842 and upgrades directly to Stage V with probability 0.0158 (= p_cf).
The Stage V row is absorbing — machines at Stage V remain there. This is the counterfactual fleet turnover matrix with no LEZ policy effect.

<table class="table table-bordered" style="width: auto !important; ">
<caption>P_Total — Constant_Speed (p_cf + p_pro = 0.0158)</caption>
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
   <td style="text-align:right;"> 0.9842 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0158 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> II </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.9842 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0158 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IIIA </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.9842 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0158 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IIIB </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.9842 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0158 </td>
  </tr>
  <tr>
   <td style="text-align:left;font-weight: bold;"> IV </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.9842 </td>
   <td style="text-align:right;"> 0.0158 </td>
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

P_Total encodes both natural turnover and proactive LEZ replacement: combined annual upgrade probability = 0.0158 (p_cf 0.0158 + p_pro 0.0000).
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
The Stage V row is absorbing — machines at Stage V remain there. This is the counterfactual fleet turnover matrix with no LEZ policy effect.

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

![P_Total heatmap by group](260417_step4_transition_matrices_v3_fig4_2_ptotal_heatmap.png)

Heatmaps of P_Total for each Phase C group: darker blue = higher transition probability. The dominant pattern is a near-diagonal (machines stay) with a single off-diagonal column at Stage V (replacement destination).
CS diagonal values are higher (lower p_cf ≈ 0.016) than Variable_Speed (higher p_cf ≈ 0.16), reflecting the generator fleet's slow natural turnover relative to the merged variable-speed fleet.

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
   <td style="text-align:right;"> 0.0232 </td>
   <td style="text-align:right;"> 0.0000 </td>
   <td style="text-align:right;"> 0.0232 </td>
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

lambda(P_Natural) and lambda(P_Total) are the expected mean-stage change per year when P_Natural or P_Total is applied to the Phase C cold initialisation distribution (pi_0). These are distribution-weighted averages: each stage's upgrade probability multiplied by the proportion of the fleet at that stage.
Residual deviations from locked lambda values are expected when the Phase C stage mix differs from the estimation-window mean; a warning is issued if lambda(P_Natural) deviates more than 20% from lambda_CF (locked). The marginal proactive increment should equal lambda_Proactive (locked) for CAZ+ and be near zero for CS and RoL.

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
   <td style="text-align:right;"> 0.056 </td>
   <td style="text-align:right;"> 0.450 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.000 </td>
   <td style="text-align:right;"> 0.494 </td>
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
Systematic under-prediction of Stage V or over-prediction of lower stages would indicate that p_cf + p_pro underestimates the observed fleet transition rate between late Phase B and Phase C; discrepancies can also reflect genuine compositional shifts (e.g. anticipatory pre-2025 compliance) not captured by the constant annual-probability model.

![Validation B: one-step projection](260417_step4_transition_matrices_v3_fig4_3_validation_B.png)

Blue bars = Phase B3 actual cold distribution; orange = one-step P_Total projection; green = Phase C actual P24 cold distribution. Agreement between orange and green indicates P_Total captures the observed fleet transition.
Discrepancies reflect genuine fleet composition shifts (e.g. Stage V surge in CS machines before the 2025 compliance deadline), time-varying hazard not captured by the single annual-probability model, or P24 zone composition differing from B3 estimation-window zones.

---
## Glossary

| Term | Definition |
|------|------------|
| **P_Natural** | Right-stochastic 6×6 transition matrix encoding counterfactual fleet turnover (lambda_CF). Each non-top stage transitions to Stage V with probability p_cf per year. |
| **P_Proactive** | Same structure as P_Natural, encoding the proactive LEZ replacement rate (lambda_Proactive). Identity-like for CS and RoL where lambda_Proactive = 0. |
| **P_Total** | Combined matrix: P_Natural + P_Proactive channels. Used as Scenario A base matrix for Step 5 forecasting. Enforcement enters only as the Scenario B Boolean mask in Step 5. |
| **p_cf** | Annual replacement probability under counterfactual: lambda_CF / avg_stage_jump. Both lambda and avg_stage_jump are denominated in the 6-stage forecast space. |
| **p_pro** | Annual proactive LEZ replacement probability: lambda_Proactive / avg_stage_jump. |
| **avg_stage_jump** | Expected stage integers gained per replacement event: FORECAST_MAX_STAGE (6) minus the mean observed stage in the cold estimation-window records. Computed in the forecast stage space for all groups. |
| **lambda(P_Natural)** | Distribution-weighted implied lambda from P_Natural applied to Phase C pi_0; compared to locked lambda_CF to validate p_cf. |
| **lambda(P_Total)** | Distribution-weighted implied lambda from P_Total; difference from lambda(P_Natural) is the matrix-implied proactive increment. |
| **Right-stochastic** | Matrix where every row sums to 1 and all entries are ≥ 0; each row is a probability distribution over destination stages. |
| **Phase C initialisation (pi_0)** | Stage distribution of P24 cold-engaged records used as the starting state vector for Phase C forecasting. |


---

## Step Report

### Intended tasks

- 4.1 Derive avg_stage_jump from estimation-window cold records (all groups denominated in forecast 6-stage space); compute p_cf and p_pro per group; produce probability-decomposition table and bar chart.
- 4.2 Construct right-stochastic P_Natural and P_Proactive (6×6) for each Phase C group (Constant_Speed, Variable_Speed); combine into P_Total; display per-group matrices; validate row sums; produce P_Total heatmaps.
- 4.3 Validate matrices: two-way lambda decomposition λ(P_Natural) and λ(P_Total) against locked estimates using Phase C pi_0; one-step B3→C projection vs actual P24 cold distribution.

---

### Results by sub-task

#### 4.1 Replacement probabilities

The key correction in v3 was computing avg_stage_jump in the forecast 6-stage space for all groups (ceiling = Stage V = 6), not the estimation-window ceiling. For Constant_Speed this changed avg_stage_jump from 0.218 (3-stage ceiling) to 3.218 (6-stage ceiling), reducing p_cf from an erroneous 0.234 to the correct 0.016. For CAZ+ and Rest_of_London avg_stage_jump was unchanged (estimation ceiling was already 6).

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 4.1a: Replacement probabilities derived from locked lambda estimates</caption>
 <thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="3"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Natural turnover (lambda_CF → p_cf)</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="2"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Proactive LEZ (lambda_Pro → p_pro)</div></th>
</tr>
  <tr>
   <th>Group</th><th>lambda_CF</th><th>avg_stage_jump</th><th>p_cf</th><th>lambda_Proactive</th><th>p_pro</th>
  </tr>
 </thead>
<tbody>
  <tr><td>Constant_Speed</td><td>0.0510</td><td>3.2180</td><td>0.0158</td><td>0.0000</td><td>0.0000</td></tr>
  <tr><td>CAZ_Plus</td><td>0.2620</td><td>1.3019</td><td>0.2012</td><td>0.0130</td><td>0.0100</td></tr>
  <tr><td>Rest_of_London</td><td>0.2410</td><td>1.5008</td><td>0.1606</td><td>0.0000</td><td>0.0000</td></tr>
  <tr><td>Variable_Speed</td><td>0.2453</td><td>1.4601</td><td>0.1680</td><td>0.0027</td><td>0.0018</td></tr>
</tbody>
</table>

CS p_cf (0.016) is the lowest across all groups, consistent with lambda_CF = 0.051 and a large avg_stage_jump of 3.22 stages — most cold CS machines in the estimation window were at Stage IIIA (the historical ceiling), far from Stage V. CAZ+ p_cf (0.201) and RoL p_cf (0.161) are substantially higher with smaller avg_stage_jumps, reflecting fleets that were already closer to the compliance ceiling in their estimation windows. Only CAZ+ has a non-zero p_pro (0.010); CS and RoL lambda_Proactive = 0 (floored), so P_Total = P_Natural for those groups.

![Replacement probabilities by group](260417_step4_transition_matrices_v3_fig4_1_probabilities.png)

CS shows the lowest p_cf bar by a wide margin; Variable_Speed p_cf (0.168) reflects the N-weighted average of CAZ+ and RoL. The p_pro bars are near-invisible for all groups except CAZ+, where the proactive LEZ signal is small but present (0.010).

---

#### 4.2 Matrix construction

Both Phase C groups (Constant_Speed, Variable_Speed) produced 6×6 right-stochastic matrices. Row-stochastic checks passed for P_Natural, P_Proactive, and P_Total for both groups.

The structural form is identical for all groups: a near-identity matrix with a single off-diagonal column at Stage V (column 6). Each non-top stage retains with probability (1 − p_cf) and upgrades directly to Stage V with probability p_cf; Stage V is absorbing. For CS, P_Total = P_Natural (p_pro = 0, no LEZ proactive channel). For Variable_Speed, P_Total adds a small increment (p_up = 0.1698 vs 0.1680).

![P_Total heatmap by group](260417_step4_transition_matrices_v3_fig4_2_ptotal_heatmap.png)

The CS heatmap shows near-black diagonal with faint Stage V column (p_cf = 0.016); the Variable_Speed heatmap shows a stronger Stage V column (p_cf = 0.168). Both are structurally valid right-stochastic matrices with the expected absorption pattern.

---

#### 4.3 Validation

**Validation A — implied lambda:** lambda(P_Natural) is distribution-weighted over the Phase C pi_0. Because 53.8% of the CS Phase C fleet and 76.5% of the Variable_Speed Phase C fleet are already at Stage V (absorbing), the distribution-weighted signal is diluted relative to the estimation-window lambda. CS lambda(P_Natural) = 0.023 vs locked 0.051 (55% deviation); Variable_Speed lambda(P_Natural) = 0.062 vs locked 0.245 (75% deviation). Both warnings were expected: the Phase C fleet is substantially more advanced than the estimation-window fleet, so fewer machines are available to contribute to upward movement. This is not a matrix error; it confirms the model correctly propagates a slow signal through a near-compliant fleet.

<table class="table table-bordered" style="width: auto !important; ">
<caption>Table 4.3a: Implied lambda from matrices vs locked estimates (Phase C initialisation)</caption>
 <thead>
<tr>
<th style="empty-cells: hide;border-bottom:hidden;" colspan="1"></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="2"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Natural turnover</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="2"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Full model</div></th>
<th style="border-bottom:hidden;padding-bottom:0; padding-left:3px;padding-right:3px;text-align: center; " colspan="1"><div style="border-bottom: 1px solid #ddd; padding-bottom: 5px; ">Proactive increment</div></th>
</tr>
  <tr><th>Group</th><th>lambda_CF (locked)</th><th>lambda(P_Natural)</th><th>lambda_Pro (locked)</th><th>lambda(P_Total)</th><th>marginal lambda_Pro (P_Total - P_Natural)</th></tr>
 </thead>
<tbody>
  <tr><td>Constant_Speed</td><td>0.0510</td><td>0.0232</td><td>0.0000</td><td>0.0232</td><td>0.0000</td></tr>
  <tr><td>Variable_Speed</td><td>0.2453</td><td>0.0622</td><td>0.0027</td><td>0.0629</td><td>0.0007</td></tr>
</tbody>
</table>

Lambda(P_Natural) values are lower than locked lambda_CF for both groups because the Phase C fleet is heavily concentrated at Stage V; only the non-top-stage fraction contributes to mean-stage change. The marginal proactive increment (0.0000 CS, 0.0007 VS) is numerically small but structurally correct given that lambda_Proactive is near zero for both groups.

**Validation B — one-step projection:** The B3→C projection using P_Total is close to the actual Phase C distribution for CS (projected Stage V 0.494 vs actual 0.538, Δ = 0.044). For Variable_Speed the projection under-predicts Stage V (0.657 projected vs 0.765 actual, Δ = 0.108). This gap is consistent with known anticipatory pre-2025 compliance by variable-speed operators — a structural acceleration in 2024 that the constant-hazard model does not capture. The forecasts are initialised directly from the actual P24 cold distribution, so this discrepancy does not propagate into Step 5.

![Validation B: one-step projection](260417_step4_transition_matrices_v3_fig4_3_validation_B.png)

For CS, orange (projected) and green (actual) are close, confirming P_Total adequately characterises the slow-turnover generator fleet transition. For Variable_Speed, the actual Phase C distribution is more advanced than the projection, consistent with the anticipatory compliance effect documented in the sprint log and schema known limitations.
