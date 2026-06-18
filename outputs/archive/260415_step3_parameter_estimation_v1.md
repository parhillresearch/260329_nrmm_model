# Step 3 Parameter Estimation

Script: 260415_step3_parameter_estimation_v1
Date: 2026-04-15

## Section 1: lambda_CF

### lambda_CF — primary estimates vs locked reference values (schema.md Table 8; |delta| > 0.05 flagged)

<table class="table table-condensed table-bordered" style="font-size: 9px; width: auto !important; margin-left: auto; margin-right: auto;">
<caption style="font-size: initial !important;">lambda_CF — primary estimates vs locked reference values (schema.md Table 8; |delta| &gt; 0.05 flagged)</caption>
 <thead>
  <tr>
   <th style="text-align:left;font-weight: bold;"> group </th>
   <th style="text-align:right;font-weight: bold;"> window </th>
   <th style="text-align:right;font-weight: bold;"> lambda_CF </th>
   <th style="text-align:right;font-weight: bold;"> se </th>
   <th style="text-align:right;font-weight: bold;"> ci_95_lo </th>
   <th style="text-align:right;font-weight: bold;"> ci_95_hi </th>
   <th style="text-align:right;font-weight: bold;"> n_gls_rows </th>
   <th style="text-align:right;font-weight: bold;"> ref_locked </th>
   <th style="text-align:right;font-weight: bold;"> delta_vs_ref </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:right;"> 2017–2023 annual (all phases) </td>
   <td style="text-align:right;"> 0.3579 </td>
   <td style="text-align:right;"> 0.0671 </td>
   <td style="text-align:right;"> 0.2264 </td>
   <td style="text-align:right;"> 0.4895 </td>
   <td style="text-align:right;"> 12 </td>
   <td style="text-align:right;"> 0.358 </td>
   <td style="text-align:right;"> -0.0001 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> CAZ_Plus </td>
   <td style="text-align:right;"> Phase B 3-segment temporal </td>
   <td style="text-align:right;"> -0.2762 </td>
   <td style="text-align:right;"> 0.0682 </td>
   <td style="text-align:right;"> -0.4099 </td>
   <td style="text-align:right;"> -0.1426 </td>
   <td style="text-align:right;"> 8 </td>
   <td style="text-align:right;"> 0.363 </td>
   <td style="text-align:right;"> -0.6392 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Rest_of_London </td>
   <td style="text-align:right;"> Phase B 3-segment temporal </td>
   <td style="text-align:right;"> 0.2196 </td>
   <td style="text-align:right;"> 0.0291 </td>
   <td style="text-align:right;"> 0.1625 </td>
   <td style="text-align:right;"> 0.2767 </td>
   <td style="text-align:right;"> 10 </td>
   <td style="text-align:right;"> 0.219 </td>
   <td style="text-align:right;"> 0.0006 </td>
  </tr>
</tbody>
</table> 

### lambda_CF — sensitivity estimates by phase window

<table class="table table-condensed table-bordered" style="font-size: 9px; width: auto !important; margin-left: auto; margin-right: auto;">
<caption style="font-size: initial !important;">lambda_CF — sensitivity estimates by phase window</caption>
 <thead>
  <tr>
   <th style="text-align:left;font-weight: bold;"> group </th>
   <th style="text-align:right;font-weight: bold;"> window </th>
   <th style="text-align:right;font-weight: bold;"> lambda_CF </th>
   <th style="text-align:right;font-weight: bold;"> se </th>
   <th style="text-align:right;font-weight: bold;"> n_rows </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:right;"> Phase A sensitivity </td>
   <td style="text-align:right;"> 0.3618 </td>
   <td style="text-align:right;"> 0.0443 </td>
   <td style="text-align:right;"> 6 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:right;"> Phase B only </td>
   <td style="text-align:right;"> -0.0932 </td>
   <td style="text-align:right;"> 0.2287 </td>
   <td style="text-align:right;"> 4 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> CAZ_Plus </td>
   <td style="text-align:right;"> Phase A sensitivity </td>
   <td style="text-align:right;"> 0.0156 </td>
   <td style="text-align:right;"> 0.0104 </td>
   <td style="text-align:right;"> 4 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Rest_of_London </td>
   <td style="text-align:right;"> Phase A sensitivity </td>
   <td style="text-align:right;"> 0.0005 </td>
   <td style="text-align:right;"> 0.0216 </td>
   <td style="text-align:right;"> 5 </td>
  </tr>
</tbody>
</table> 

## Section 2: e-bar

### e-bar — proportion of all records below compliance threshold (schema.md Table 2); all groups × historical phases

<table class="table table-condensed table-bordered" style="font-size: 9px; width: auto !important; margin-left: auto; margin-right: auto;">
<caption style="font-size: initial !important;">e-bar — proportion of all records below compliance threshold (schema.md Table 2); all groups × historical phases</caption>
 <thead>
  <tr>
   <th style="text-align:left;font-weight: bold;"> group </th>
   <th style="text-align:right;font-weight: bold;"> phase </th>
   <th style="text-align:right;font-weight: bold;"> threshold </th>
   <th style="text-align:right;font-weight: bold;"> n_all_records </th>
   <th style="text-align:right;font-weight: bold;"> n_below_thresh </th>
   <th style="text-align:right;font-weight: bold;"> e_bar </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:right;"> A1 </td>
   <td style="text-align:right;"> IIIA </td>
   <td style="text-align:right;"> 104 </td>
   <td style="text-align:right;"> 23 </td>
   <td style="text-align:right;"> 0.2212 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:right;"> A2 </td>
   <td style="text-align:right;"> IIIA </td>
   <td style="text-align:right;"> 318 </td>
   <td style="text-align:right;"> 47 </td>
   <td style="text-align:right;"> 0.1478 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:right;"> B </td>
   <td style="text-align:right;"> V </td>
   <td style="text-align:right;"> 693 </td>
   <td style="text-align:right;"> 574 </td>
   <td style="text-align:right;"> 0.8283 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> CAZ_Plus </td>
   <td style="text-align:right;"> A1 </td>
   <td style="text-align:right;"> IIIB </td>
   <td style="text-align:right;"> 400 </td>
   <td style="text-align:right;"> 81 </td>
   <td style="text-align:right;"> 0.2025 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> CAZ_Plus </td>
   <td style="text-align:right;"> A2 </td>
   <td style="text-align:right;"> IIIB </td>
   <td style="text-align:right;"> 658 </td>
   <td style="text-align:right;"> 74 </td>
   <td style="text-align:right;"> 0.1125 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> CAZ_Plus </td>
   <td style="text-align:right;"> B </td>
   <td style="text-align:right;"> IV </td>
   <td style="text-align:right;"> 2296 </td>
   <td style="text-align:right;"> 457 </td>
   <td style="text-align:right;"> 0.1990 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Rest_of_London </td>
   <td style="text-align:right;"> A1 </td>
   <td style="text-align:right;"> IIIA </td>
   <td style="text-align:right;"> 538 </td>
   <td style="text-align:right;"> 28 </td>
   <td style="text-align:right;"> 0.0520 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Rest_of_London </td>
   <td style="text-align:right;"> A2 </td>
   <td style="text-align:right;"> IIIA </td>
   <td style="text-align:right;"> 1634 </td>
   <td style="text-align:right;"> 53 </td>
   <td style="text-align:right;"> 0.0324 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Rest_of_London </td>
   <td style="text-align:right;"> B </td>
   <td style="text-align:right;"> IIIB </td>
   <td style="text-align:right;"> 4122 </td>
   <td style="text-align:right;"> 192 </td>
   <td style="text-align:right;"> 0.0466 </td>
  </tr>
</tbody>
</table> 

## Section 3: lambda_Policy and lambda_Proactive

### lambda_Proactive = lambda_Policy − lambda_CF (warm self-compliant fleet, Phase B primary; floored at 0; e-bar not subtracted per decisions.md #6)

<table class="table table-condensed table-bordered" style="font-size: 9px; width: auto !important; margin-left: auto; margin-right: auto;">
<caption style="font-size: initial !important;">lambda_Proactive = lambda_Policy − lambda_CF (warm self-compliant fleet, Phase B primary; floored at 0; e-bar not subtracted per decisions.md #6)</caption>
 <thead>
  <tr>
   <th style="text-align:left;font-weight: bold;"> group </th>
   <th style="text-align:right;font-weight: bold;"> lambda_policy </th>
   <th style="text-align:right;font-weight: bold;"> se_policy </th>
   <th style="text-align:right;font-weight: bold;"> lambda_cf </th>
   <th style="text-align:right;font-weight: bold;"> se_cf </th>
   <th style="text-align:right;font-weight: bold;"> lambda_proactive_raw </th>
   <th style="text-align:right;font-weight: bold;"> lambda_proactive </th>
   <th style="text-align:right;font-weight: bold;"> floored </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:right;"> NA </td>
   <td style="text-align:right;"> NA </td>
   <td style="text-align:right;"> 0.3579 </td>
   <td style="text-align:right;"> 0.0671 </td>
   <td style="text-align:right;"> NA </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> FALSE </td>
  </tr>
  <tr>
   <td style="text-align:left;"> CAZ_Plus </td>
   <td style="text-align:right;"> NA </td>
   <td style="text-align:right;"> NA </td>
   <td style="text-align:right;"> -0.2762 </td>
   <td style="text-align:right;"> 0.0682 </td>
   <td style="text-align:right;"> NA </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> FALSE </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Rest_of_London </td>
   <td style="text-align:right;"> NA </td>
   <td style="text-align:right;"> NA </td>
   <td style="text-align:right;"> 0.2196 </td>
   <td style="text-align:right;"> 0.0291 </td>
   <td style="text-align:right;"> NA </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> FALSE </td>
  </tr>
</tbody>
</table> 

## Section 4: Summary and cross-check

### Step 3 full parameter summary (Phase B primary estimates)

<table class="table table-condensed table-bordered" style="font-size: 9px; width: auto !important; margin-left: auto; margin-right: auto;">
<caption style="font-size: initial !important;">Step 3 full parameter summary (Phase B primary estimates)</caption>
 <thead>
  <tr>
   <th style="text-align:left;font-weight: bold;"> group </th>
   <th style="text-align:right;font-weight: bold;"> window </th>
   <th style="text-align:right;font-weight: bold;"> lambda_CF </th>
   <th style="text-align:right;font-weight: bold;"> se </th>
   <th style="text-align:right;font-weight: bold;"> ci_95_lo </th>
   <th style="text-align:right;font-weight: bold;"> ci_95_hi </th>
   <th style="text-align:right;font-weight: bold;"> ref_locked </th>
   <th style="text-align:right;font-weight: bold;"> delta_vs_ref </th>
   <th style="text-align:right;font-weight: bold;"> e_bar_A </th>
   <th style="text-align:right;font-weight: bold;"> e_bar_B </th>
   <th style="text-align:right;font-weight: bold;"> lambda_policy </th>
   <th style="text-align:right;font-weight: bold;"> lambda_proactive </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:right;"> 2017–2023 annual (all phases) </td>
   <td style="text-align:right;"> 0.3579 </td>
   <td style="text-align:right;"> 0.0671 </td>
   <td style="text-align:right;"> 0.2264 </td>
   <td style="text-align:right;"> 0.4895 </td>
   <td style="text-align:right;"> 0.358 </td>
   <td style="text-align:right;"> -0.0001 </td>
   <td style="text-align:right;"> 0.1845 </td>
   <td style="text-align:right;"> 0.8283 </td>
   <td style="text-align:right;"> NA </td>
   <td style="text-align:right;"> 0 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> CAZ_Plus </td>
   <td style="text-align:right;"> Phase B 3-segment temporal </td>
   <td style="text-align:right;"> -0.2762 </td>
   <td style="text-align:right;"> 0.0682 </td>
   <td style="text-align:right;"> -0.4099 </td>
   <td style="text-align:right;"> -0.1426 </td>
   <td style="text-align:right;"> 0.363 </td>
   <td style="text-align:right;"> -0.6392 </td>
   <td style="text-align:right;"> 0.1575 </td>
   <td style="text-align:right;"> 0.1990 </td>
   <td style="text-align:right;"> NA </td>
   <td style="text-align:right;"> 0 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Rest_of_London </td>
   <td style="text-align:right;"> Phase B 3-segment temporal </td>
   <td style="text-align:right;"> 0.2196 </td>
   <td style="text-align:right;"> 0.0291 </td>
   <td style="text-align:right;"> 0.1625 </td>
   <td style="text-align:right;"> 0.2767 </td>
   <td style="text-align:right;"> 0.219 </td>
   <td style="text-align:right;"> 0.0006 </td>
   <td style="text-align:right;"> 0.0422 </td>
   <td style="text-align:right;"> 0.0466 </td>
   <td style="text-align:right;"> NA </td>
   <td style="text-align:right;"> 0 </td>
  </tr>
</tbody>
</table> 
