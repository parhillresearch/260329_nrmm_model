# Step 3 Parameter Estimation

Script: 260415_step3_parameter_estimation_v2
Date: 2026-04-16

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
   <td style="text-align:right;"> -1e-04 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> CAZ_Plus </td>
   <td style="text-align:right;"> Phase B 3-segment temporal </td>
   <td style="text-align:right;"> 0.3627 </td>
   <td style="text-align:right;"> 0.0517 </td>
   <td style="text-align:right;"> 0.2614 </td>
   <td style="text-align:right;"> 0.4640 </td>
   <td style="text-align:right;"> 10 </td>
   <td style="text-align:right;"> 0.363 </td>
   <td style="text-align:right;"> -3e-04 </td>
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
   <td style="text-align:right;"> 6e-04 </td>
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
   <td style="text-align:right;"> 0.0319 </td>
   <td style="text-align:right;"> 0.0108 </td>
   <td style="text-align:right;"> 5 </td>
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

### e-bar — proportion (and %) of all records below compliance threshold (schema.md Table 2); all groups × historical phases

<table class="table table-condensed table-bordered" style="font-size: 9px; width: auto !important; margin-left: auto; margin-right: auto;">
<caption style="font-size: initial !important;">e-bar — proportion (and %) of all records below compliance threshold (schema.md Table 2); all groups × historical phases</caption>
 <thead>
  <tr>
   <th style="text-align:left;font-weight: bold;"> group </th>
   <th style="text-align:right;font-weight: bold;"> phase </th>
   <th style="text-align:right;font-weight: bold;"> threshold </th>
   <th style="text-align:right;font-weight: bold;"> n_all_records </th>
   <th style="text-align:right;font-weight: bold;"> n_below_thresh </th>
   <th style="text-align:right;font-weight: bold;"> e_bar </th>
   <th style="text-align:right;font-weight: bold;"> e_bar_pct </th>
  </tr>
 </thead>
<tbody>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:right;"> A1 </td>
   <td style="text-align:right;"> V </td>
   <td style="text-align:right;"> 104 </td>
   <td style="text-align:right;"> 104 </td>
   <td style="text-align:right;"> 1.0000 </td>
   <td style="text-align:right;"> 100.0 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:right;"> A2 </td>
   <td style="text-align:right;"> V </td>
   <td style="text-align:right;"> 318 </td>
   <td style="text-align:right;"> 318 </td>
   <td style="text-align:right;"> 1.0000 </td>
   <td style="text-align:right;"> 100.0 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Constant_Speed </td>
   <td style="text-align:right;"> B </td>
   <td style="text-align:right;"> V </td>
   <td style="text-align:right;"> 693 </td>
   <td style="text-align:right;"> 574 </td>
   <td style="text-align:right;"> 0.8283 </td>
   <td style="text-align:right;"> 82.8 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> CAZ_Plus </td>
   <td style="text-align:right;"> A1 </td>
   <td style="text-align:right;"> IV </td>
   <td style="text-align:right;"> 400 </td>
   <td style="text-align:right;"> 347 </td>
   <td style="text-align:right;"> 0.8675 </td>
   <td style="text-align:right;"> 86.8 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> CAZ_Plus </td>
   <td style="text-align:right;"> A2 </td>
   <td style="text-align:right;"> IV </td>
   <td style="text-align:right;"> 658 </td>
   <td style="text-align:right;"> 464 </td>
   <td style="text-align:right;"> 0.7052 </td>
   <td style="text-align:right;"> 70.5 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> CAZ_Plus </td>
   <td style="text-align:right;"> B </td>
   <td style="text-align:right;"> V </td>
   <td style="text-align:right;"> 2296 </td>
   <td style="text-align:right;"> 1144 </td>
   <td style="text-align:right;"> 0.4983 </td>
   <td style="text-align:right;"> 49.8 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Rest_of_London </td>
   <td style="text-align:right;"> A1 </td>
   <td style="text-align:right;"> IIIB </td>
   <td style="text-align:right;"> 538 </td>
   <td style="text-align:right;"> 153 </td>
   <td style="text-align:right;"> 0.2844 </td>
   <td style="text-align:right;"> 28.4 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Rest_of_London </td>
   <td style="text-align:right;"> A2 </td>
   <td style="text-align:right;"> IIIB </td>
   <td style="text-align:right;"> 1634 </td>
   <td style="text-align:right;"> 231 </td>
   <td style="text-align:right;"> 0.1414 </td>
   <td style="text-align:right;"> 14.1 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> Rest_of_London </td>
   <td style="text-align:right;"> B </td>
   <td style="text-align:right;"> IV </td>
   <td style="text-align:right;"> 4122 </td>
   <td style="text-align:right;"> 1526 </td>
   <td style="text-align:right;"> 0.3702 </td>
   <td style="text-align:right;"> 37.0 </td>
  </tr>
</tbody>
</table> 

## Section 3: lambda_Policy and lambda_Proactive

### Warm self-compliant record counts (Route 1)


### Warm self-compliant records by group × phase (Route 1; basis for lambda_Policy estimation). Known constraint: step 2 flagged near-zero Route 1 records in most phases.

<table class="table table-condensed table-bordered" style="font-size: 9px; width: auto !important; margin-left: auto; margin-right: auto;">
<caption style="font-size: initial !important;">Warm self-compliant records by group × phase (Route 1; basis for lambda_Policy estimation). Known constraint: step 2 flagged near-zero Route 1 records in most phases.</caption>
 <thead>
  <tr>
   <th style="text-align:left;font-weight: bold;"> group </th>
  </tr>
 </thead>
<tbody>
  <tr>

  </tr>
</tbody>
</table> 

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
   <th style="text-align:right;font-weight: bold;"> na_reason </th>
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
   <td style="text-align:right;"> lambda_Policy NA (insufficient warm self-compliant records) </td>
  </tr>
  <tr>
   <td style="text-align:left;"> CAZ_Plus </td>
   <td style="text-align:right;"> NA </td>
   <td style="text-align:right;"> NA </td>
   <td style="text-align:right;"> 0.3627 </td>
   <td style="text-align:right;"> 0.0517 </td>
   <td style="text-align:right;"> NA </td>
   <td style="text-align:right;"> 0 </td>
   <td style="text-align:right;"> FALSE </td>
   <td style="text-align:right;"> lambda_Policy NA (insufficient warm self-compliant records) </td>
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
   <td style="text-align:right;"> lambda_Policy NA (insufficient warm self-compliant records) </td>
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
   <th style="text-align:right;font-weight: bold;"> e_bar_A_pct </th>
   <th style="text-align:right;font-weight: bold;"> e_bar_B </th>
   <th style="text-align:right;font-weight: bold;"> e_bar_B_pct </th>
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
   <td style="text-align:right;"> -1e-04 </td>
   <td style="text-align:right;"> 1.0000 </td>
   <td style="text-align:right;"> 100.0 </td>
   <td style="text-align:right;"> 0.8283 </td>
   <td style="text-align:right;"> 82.8 </td>
   <td style="text-align:right;"> NA </td>
   <td style="text-align:right;"> 0 </td>
  </tr>
  <tr>
   <td style="text-align:left;"> CAZ_Plus </td>
   <td style="text-align:right;"> Phase B 3-segment temporal </td>
   <td style="text-align:right;"> 0.3627 </td>
   <td style="text-align:right;"> 0.0517 </td>
   <td style="text-align:right;"> 0.2614 </td>
   <td style="text-align:right;"> 0.4640 </td>
   <td style="text-align:right;"> 0.363 </td>
   <td style="text-align:right;"> -3e-04 </td>
   <td style="text-align:right;"> 0.7864 </td>
   <td style="text-align:right;"> 78.6 </td>
   <td style="text-align:right;"> 0.4983 </td>
   <td style="text-align:right;"> 49.8 </td>
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
   <td style="text-align:right;"> 6e-04 </td>
   <td style="text-align:right;"> 0.2129 </td>
   <td style="text-align:right;"> 21.3 </td>
   <td style="text-align:right;"> 0.3702 </td>
   <td style="text-align:right;"> 37.0 </td>
   <td style="text-align:right;"> NA </td>
   <td style="text-align:right;"> 0 </td>
  </tr>
</tbody>
</table> 

**Note:** 3 group(s) have lambda_Policy = NA (see Route 1 sparsity table above).
