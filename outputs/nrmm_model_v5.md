# nrmm_model_v5 — unified model: outcomes, EF, dynamics (260717)

One classified spine; three layers. Arms: warm_AT (treatment), cold_CF
(counterfactual). Eras split at 1 Sep 2020. Constrained Markov: replacement
to market-top stage M(t) with annual probability p-bar; estimated from
adjacent-year mean-stage increments, E[dm] = p x g(t), through-origin WLS.

## 1. Fitted p-bar per engine x arm x era

|engine   |arm     |era  |   p_bar|     se| n_pairs|
|:--------|:-------|:----|-------:|------:|-------:|
|Constant |cold_CF |era1 |  0.0246|     NA|       1|
|Constant |cold_CF |era2 | -0.0031| 0.0265|       2|
|Constant |pooled  |era1 |  0.0390|     NA|       1|
|Constant |pooled  |era2 | -0.0022| 0.0044|       5|
|Constant |warm_AT |era1 |  0.0407|     NA|       1|
|Constant |warm_AT |era2 |  0.0010| 0.0024|       5|
|Variable |cold_CF |era1 |  0.1033| 0.0290|       4|
|Variable |cold_CF |era2 |  0.2272| 0.0244|       4|
|Variable |pooled  |era1 |  0.1094| 0.0154|       4|
|Variable |pooled  |era2 |  0.2311| 0.0318|       4|
|Variable |warm_AT |era1 |  0.1157| 0.0168|       4|
|Variable |warm_AT |era2 |  0.2314| 0.0405|       4|

## 2. Projections 2025-2030 (era-2 p-bar; thresholds at exact dates)

c_bar_proj is the projected stage-compliant share against the schedule
(2025-29: CS V, CAZ+ V, RoL IV; from 2030 all V). Scenarios are the p-bar
95% CI. Constant-speed uses the pooled-arm p-bar for both arms.

|subgroup       |arm     |scenario | year| c_bar_proj| mean_stage_proj| ef_proj|  pi_1|  pi_2|  pi_3|  pi_4|  pi_5|  pi_6| pi_7|
|:--------------|:-------|:--------|----:|----------:|---------------:|-------:|-----:|-----:|-----:|-----:|-----:|-----:|----:|
|CAZ_Plus       |cold_CF |central  | 2025|      0.663|           5.465|   1.904| 0.000| 0.000| 0.035| 0.128| 0.174| 0.663|    0|
|CAZ_Plus       |cold_CF |central  | 2027|      0.799|           5.681|   1.843| 0.000| 0.000| 0.021| 0.076| 0.104| 0.799|    0|
|CAZ_Plus       |cold_CF |central  | 2030|      0.907|           5.853|   1.793| 0.000| 0.000| 0.010| 0.035| 0.048| 0.907|    0|
|CAZ_Plus       |cold_CF |ci_high  | 2025|      0.684|           5.498|   1.895| 0.000| 0.000| 0.033| 0.120| 0.164| 0.684|    0|
|CAZ_Plus       |cold_CF |ci_high  | 2027|      0.834|           5.736|   1.827| 0.000| 0.000| 0.017| 0.063| 0.086| 0.834|    0|
|CAZ_Plus       |cold_CF |ci_high  | 2030|      0.937|           5.899|   1.780| 0.000| 0.000| 0.007| 0.024| 0.033| 0.937|    0|
|CAZ_Plus       |cold_CF |ci_low   | 2025|      0.642|           5.432|   1.914| 0.000| 0.000| 0.037| 0.136| 0.185| 0.642|    0|
|CAZ_Plus       |cold_CF |ci_low   | 2027|      0.759|           5.618|   1.861| 0.000| 0.000| 0.025| 0.091| 0.125| 0.759|    0|
|CAZ_Plus       |cold_CF |ci_low   | 2030|      0.867|           5.789|   1.812| 0.000| 0.000| 0.014| 0.050| 0.069| 0.867|    0|
|CAZ_Plus       |warm_AT |central  | 2025|      0.747|           5.637|   1.733| 0.001| 0.004| 0.017| 0.062| 0.170| 0.747|    0|
|CAZ_Plus       |warm_AT |central  | 2027|      0.850|           5.785|   1.741| 0.000| 0.002| 0.010| 0.036| 0.100| 0.850|    0|
|CAZ_Plus       |warm_AT |central  | 2030|      0.932|           5.903|   1.746| 0.000| 0.001| 0.005| 0.016| 0.046| 0.932|    0|
|CAZ_Plus       |warm_AT |ci_high  | 2025|      0.773|           5.674|   1.735| 0.001| 0.003| 0.016| 0.055| 0.153| 0.773|    0|
|CAZ_Plus       |warm_AT |ci_high  | 2027|      0.892|           5.845|   1.744| 0.000| 0.002| 0.007| 0.026| 0.072| 0.892|    0|
|CAZ_Plus       |warm_AT |ci_high  | 2030|      0.965|           5.949|   1.749| 0.000| 0.001| 0.002| 0.009| 0.024| 0.965|    0|
|CAZ_Plus       |warm_AT |ci_low   | 2025|      0.721|           5.599|   1.731| 0.001| 0.004| 0.019| 0.068| 0.188| 0.721|    0|
|CAZ_Plus       |warm_AT |ci_low   | 2027|      0.799|           5.712|   1.737| 0.001| 0.003| 0.014| 0.049| 0.135| 0.799|    0|
|CAZ_Plus       |warm_AT |ci_low   | 2030|      0.878|           5.824|   1.743| 0.000| 0.002| 0.008| 0.030| 0.082| 0.878|    0|
|Constant_Speed |cold_CF |central  | 2025|      0.000|           2.872|   4.307| 0.000| 0.128| 0.872| 0.000| 0.000| 0.000|    0|
|Constant_Speed |cold_CF |central  | 2027|      0.000|           2.872|   4.307| 0.000| 0.128| 0.872| 0.000| 0.000| 0.000|    0|
|Constant_Speed |cold_CF |central  | 2030|      0.000|           2.872|   4.307| 0.000| 0.128| 0.872| 0.000| 0.000| 0.000|    0|
|Constant_Speed |cold_CF |ci_high  | 2025|      0.006|           2.892|   4.282| 0.000| 0.127| 0.866| 0.000| 0.000| 0.006|    0|
|Constant_Speed |cold_CF |ci_high  | 2027|      0.019|           2.931|   4.233| 0.000| 0.126| 0.855| 0.000| 0.000| 0.019|    0|
|Constant_Speed |cold_CF |ci_high  | 2030|      0.038|           2.990|   4.160| 0.000| 0.123| 0.839| 0.000| 0.000| 0.038|    0|
|Constant_Speed |cold_CF |ci_low   | 2025|      0.000|           2.872|   4.307| 0.000| 0.128| 0.872| 0.000| 0.000| 0.000|    0|
|Constant_Speed |cold_CF |ci_low   | 2027|      0.000|           2.872|   4.307| 0.000| 0.128| 0.872| 0.000| 0.000| 0.000|    0|
|Constant_Speed |cold_CF |ci_low   | 2030|      0.000|           2.872|   4.307| 0.000| 0.128| 0.872| 0.000| 0.000| 0.000|    0|
|Constant_Speed |warm_AT |central  | 2025|      0.000|           2.958|   4.123| 0.000| 0.042| 0.958| 0.000| 0.000| 0.000|    0|
|Constant_Speed |warm_AT |central  | 2027|      0.000|           2.958|   4.123| 0.000| 0.042| 0.958| 0.000| 0.000| 0.000|    0|
|Constant_Speed |warm_AT |central  | 2030|      0.000|           2.958|   4.123| 0.000| 0.042| 0.958| 0.000| 0.000| 0.000|    0|
|Constant_Speed |warm_AT |ci_high  | 2025|      0.006|           2.977|   4.099| 0.000| 0.042| 0.952| 0.000| 0.000| 0.006|    0|
|Constant_Speed |warm_AT |ci_high  | 2027|      0.019|           3.015|   4.052| 0.000| 0.042| 0.939| 0.000| 0.000| 0.019|    0|
|Constant_Speed |warm_AT |ci_high  | 2030|      0.038|           3.072|   3.982| 0.000| 0.041| 0.922| 0.000| 0.000| 0.038|    0|
|Constant_Speed |warm_AT |ci_low   | 2025|      0.000|           2.958|   4.123| 0.000| 0.042| 0.958| 0.000| 0.000| 0.000|    0|
|Constant_Speed |warm_AT |ci_low   | 2027|      0.000|           2.958|   4.123| 0.000| 0.042| 0.958| 0.000| 0.000| 0.000|    0|
|Constant_Speed |warm_AT |ci_low   | 2030|      0.000|           2.958|   4.123| 0.000| 0.042| 0.958| 0.000| 0.000| 0.000|    0|
|Rest_of_London |cold_CF |central  | 2025|      0.770|           5.346|   2.133| 0.006| 0.004| 0.029| 0.191| 0.139| 0.631|    0|
|Rest_of_London |cold_CF |central  | 2027|      0.863|           5.609|   1.991| 0.004| 0.002| 0.017| 0.114| 0.083| 0.780|    0|
|Rest_of_London |cold_CF |central  | 2030|      0.898|           5.820|   1.878| 0.002| 0.001| 0.008| 0.053| 0.038| 0.898|    0|
|Rest_of_London |cold_CF |ci_high  | 2025|      0.785|           5.386|   2.111| 0.006| 0.004| 0.027| 0.179| 0.131| 0.654|    0|
|Rest_of_London |cold_CF |ci_high  | 2027|      0.887|           5.677|   1.955| 0.003| 0.002| 0.014| 0.094| 0.069| 0.818|    0|
|Rest_of_London |cold_CF |ci_high  | 2030|      0.931|           5.877|   1.847| 0.001| 0.001| 0.005| 0.036| 0.026| 0.931|    0|
|Rest_of_London |cold_CF |ci_low   | 2025|      0.756|           5.306|   2.154| 0.007| 0.004| 0.030| 0.202| 0.148| 0.608|    0|
|Rest_of_London |cold_CF |ci_low   | 2027|      0.836|           5.533|   2.032| 0.004| 0.003| 0.021| 0.136| 0.100| 0.736|    0|
|Rest_of_London |cold_CF |ci_low   | 2030|      0.854|           5.742|   1.920| 0.002| 0.002| 0.011| 0.075| 0.055| 0.854|    0|
|Rest_of_London |warm_AT |central  | 2025|      0.842|           5.485|   1.926| 0.001| 0.005| 0.020| 0.132| 0.165| 0.677|    0|
|Rest_of_London |warm_AT |central  | 2027|      0.907|           5.696|   1.867| 0.001| 0.003| 0.012| 0.078| 0.097| 0.809|    0|
|Rest_of_London |warm_AT |central  | 2030|      0.913|           5.862|   1.820| 0.000| 0.001| 0.005| 0.035| 0.044| 0.913|    0|
|Rest_of_London |warm_AT |ci_high  | 2025|      0.858|           5.539|   1.911| 0.001| 0.005| 0.018| 0.118| 0.148| 0.710|    0|
|Rest_of_London |warm_AT |ci_high  | 2027|      0.933|           5.781|   1.843| 0.000| 0.002| 0.009| 0.056| 0.070| 0.862|    0|
|Rest_of_London |warm_AT |ci_high  | 2030|      0.955|           5.928|   1.802| 0.000| 0.001| 0.003| 0.018| 0.023| 0.955|    0|
|Rest_of_London |warm_AT |ci_low   | 2025|      0.825|           5.432|   1.941| 0.001| 0.006| 0.022| 0.145| 0.182| 0.644|    0|
|Rest_of_London |warm_AT |ci_low   | 2027|      0.874|           5.592|   1.896| 0.001| 0.004| 0.016| 0.105| 0.131| 0.744|    0|
|Rest_of_London |warm_AT |ci_low   | 2030|      0.844|           5.751|   1.851| 0.000| 0.002| 0.010| 0.064| 0.080| 0.844|    0|

## 3a. Arrival emissions intensity by arm (proactive channel)

Mean stage-limit NOx (g/kWh) of machines at first sight, per arm.
gap_pct is how far below the counterfactual the registered arm sits.

|subgroup       |phase |variant           | n_cold| n_warm| ef_cold| ef_warm| gap_pct|
|:--------------|:-----|:-----------------|------:|------:|-------:|-------:|-------:|
|All_NRMM       |A1    |all_machines      |    140|    802|    3.96|    3.59|     9.2|
|All_NRMM       |A1    |excl_dispensation |    139|    750|    3.95|    3.52|    10.9|
|All_NRMM       |A2    |all_machines      |    394|   2190|    3.97|    3.31|    16.6|
|All_NRMM       |A2    |excl_dispensation |    394|   2159|    3.97|    3.29|    17.2|
|All_NRMM       |All   |all_machines      |   1876|   9037|    3.44|    3.02|    12.4|
|All_NRMM       |All   |excl_dispensation |   1860|   8564|    3.44|    2.95|    14.1|
|All_NRMM       |B     |all_machines      |   1302|   6022|    3.19|    2.83|    11.4|
|All_NRMM       |B     |excl_dispensation |   1287|   5638|    3.18|    2.74|    13.8|
|All_NRMM       |C     |all_machines      |     40|     23|    4.66|    4.40|     5.5|
|All_NRMM       |C     |excl_dispensation |     40|     17|    4.66|    4.46|     4.2|
|CAZ_Plus       |All   |all_machines      |    392|   3217|    2.91|    2.84|     2.4|
|CAZ_Plus       |All   |excl_dispensation |    392|   2989|    2.91|    2.72|     6.3|
|Constant_Speed |All   |all_machines      |    162|    616|    4.50|    4.30|     4.5|
|Constant_Speed |All   |excl_dispensation |    152|    448|    4.52|    4.35|     3.6|
|Rest_of_London |All   |all_machines      |   1322|   5204|    3.47|    2.98|    14.2|
|Rest_of_London |All   |excl_dispensation |   1316|   5127|    3.47|    2.96|    14.7|

## 3b. Removal fate under both definitions

Record-level is authoritative (matches the outcome taxonomy); the
machine-level figure answers a different question and is reported so the
two are never confused.

|definition                   | traceable| displaced| untraceable| displaced_pct|
|:----------------------------|---------:|---------:|-----------:|-------------:|
|record_level (authoritative) |       299|       167|         198|          55.9|
|machine_level                |       243|        98|          NA|          40.3|

## 3c. Enforcement channel in NOx terms

Shares of audited-fleet NOx (total 33,738 g/kWh-machines). Retrofits are credited zero NOx (DPFs abate PM).

|channel                                             |   n| nox_saved| pct_of_fleet_nox|
|:---------------------------------------------------|---:|---------:|----------------:|
|confirmed reduction (a+b, retrofit c credited zero) | 108|      32.2|             0.10|
|probable exit (e)                                   | 132|     627.9|             1.86|
|removal fate unknown (d+f), at stake                | 365|    1890.4|             5.60|

## 3. Observed yearly c-bar by Machine Group and arm (model target)

|subgroup       | year| n_cold_CF| n_warm_AT| c_bar_obs_cold_CF| c_bar_obs_warm_AT|
|:--------------|----:|---------:|---------:|-----------------:|-----------------:|
|CAZ_Plus       | 2017|        NA|       143|                NA|             0.867|
|CAZ_Plus       | 2018|        44|       218|             0.750|             0.931|
|CAZ_Plus       | 2019|        37|       359|             0.649|             0.911|
|CAZ_Plus       | 2020|        65|       500|             0.523|             0.794|
|CAZ_Plus       | 2021|        70|       491|             0.671|             0.741|
|CAZ_Plus       | 2022|        37|       462|             0.703|             0.810|
|CAZ_Plus       | 2023|        83|       665|             0.771|             0.892|
|CAZ_Plus       | 2024|        50|       399|             0.820|             0.917|
|Constant_Speed | 2019|        27|       133|             0.778|             0.827|
|Constant_Speed | 2020|        21|       137|             0.381|             0.708|
|Constant_Speed | 2021|        21|        94|             0.095|             0.500|
|Constant_Speed | 2022|        NA|       111|                NA|             0.360|
|Constant_Speed | 2023|        NA|        89|                NA|             0.371|
|Constant_Speed | 2024|        NA|        29|                NA|             0.414|
|Constant_Speed | 2025|        NA|        23|                NA|             0.261|
|Rest_of_London | 2016|        21|        21|             0.905|             1.000|
|Rest_of_London | 2017|        36|       197|             0.861|             0.990|
|Rest_of_London | 2018|        33|       240|             0.848|             0.946|
|Rest_of_London | 2019|       181|       976|             0.939|             0.970|
|Rest_of_London | 2020|       242|       701|             0.905|             0.974|
|Rest_of_London | 2021|       248|       751|             0.887|             0.917|
|Rest_of_London | 2022|       187|       672|             0.898|             0.938|
|Rest_of_London | 2023|       205|       782|             0.956|             0.957|
|Rest_of_London | 2024|       174|       881|             0.937|             0.983|

## 4. Fleet EF by Machine Group and phase (Layer 2, central usage indices)

|subgroup       |phase | n_types| ef_central| ef_kw_ref| ef_env_low| ef_env_high| ef_count_ref|
|:--------------|:-----|-------:|----------:|---------:|----------:|-----------:|------------:|
|All_NRMM       |A1    |      12|       3.06|      3.11|       2.88|        3.36|         3.65|
|All_NRMM       |A2    |      12|       3.21|      2.92|       2.70|        3.60|         3.41|
|All_NRMM       |B     |      13|       2.52|      2.24|       2.00|        2.97|         2.89|
|All_NRMM       |C     |       3|       4.27|      4.26|       4.26|        4.27|         4.57|
|CAZ_Plus       |A1    |      11|       2.88|      2.96|       2.68|        3.22|         3.59|
|CAZ_Plus       |A2    |      12|       2.58|      2.57|       2.24|        3.04|         3.20|
|CAZ_Plus       |B     |      13|       1.77|      1.77|       1.42|        2.24|         2.63|
|Constant_Speed |A2    |       3|       4.23|      4.23|       4.23|        4.23|         4.46|
|Constant_Speed |B     |       5|       4.12|      4.12|       4.12|        4.12|         4.25|
|Constant_Speed |C     |       3|       4.27|      4.26|       4.26|        4.27|         4.57|
|Rest_of_London |A1    |      12|       3.23|      3.23|       2.96|        3.52|         3.70|
|Rest_of_London |A2    |      12|       2.82|      2.77|       2.42|        3.26|         3.35|
|Rest_of_London |B     |      13|       2.16|      2.16|       1.77|        2.56|         2.90|

## 5. Assumptions and placeholders

- Stage NOx limits and usage indices: general-knowledge placeholders.
- N_t: audit counts pending NRMM registration database.
- Projections start from pooled 2023-24 distributions; phase C is
  projection, not estimation (n = 63).
- Constant-speed p-bar pooled across arms (cold too thin annually).
- EF projection holds each stage's 2023-24 power-band mix fixed.
- No bootstrap; p-bar CIs are WLS standard errors, unclustered.

