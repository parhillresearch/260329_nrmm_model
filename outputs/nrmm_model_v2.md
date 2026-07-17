# nrmm_model_v2 — unified model: outcomes, EF, dynamics (260717)

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
|Variable |pooled  |era2 |  0.2312| 0.0317|       4|
|Variable |warm_AT |era1 |  0.1157| 0.0168|       4|
|Variable |warm_AT |era2 |  0.2315| 0.0404|       4|

## 2. Projections 2025-2030 (era-2 p-bar; thresholds at exact dates)

c_bar_proj is the projected stage-compliant share against the schedule
(2025-29: CS V, CAZ+ V, RoL IV; from 2030 all V). Scenarios are the p-bar
95% CI. Constant-speed uses the pooled-arm p-bar for both arms.

|subgroup       |arm     |scenario | year| c_bar_proj| mean_stage_proj| ef_proj|
|:--------------|:-------|:--------|----:|----------:|---------------:|-------:|
|CAZ_Plus       |cold_CF |central  | 2025|      0.663|           5.465|   1.904|
|CAZ_Plus       |cold_CF |central  | 2027|      0.799|           5.681|   1.843|
|CAZ_Plus       |cold_CF |central  | 2030|      0.907|           5.853|   1.793|
|CAZ_Plus       |cold_CF |ci_high  | 2025|      0.684|           5.498|   1.895|
|CAZ_Plus       |cold_CF |ci_high  | 2027|      0.834|           5.736|   1.827|
|CAZ_Plus       |cold_CF |ci_high  | 2030|      0.937|           5.899|   1.780|
|CAZ_Plus       |cold_CF |ci_low   | 2025|      0.642|           5.432|   1.914|
|CAZ_Plus       |cold_CF |ci_low   | 2027|      0.759|           5.618|   1.861|
|CAZ_Plus       |cold_CF |ci_low   | 2030|      0.867|           5.789|   1.812|
|CAZ_Plus       |warm_AT |central  | 2025|      0.747|           5.637|   1.733|
|CAZ_Plus       |warm_AT |central  | 2027|      0.850|           5.785|   1.741|
|CAZ_Plus       |warm_AT |central  | 2030|      0.932|           5.903|   1.746|
|CAZ_Plus       |warm_AT |ci_high  | 2025|      0.773|           5.674|   1.735|
|CAZ_Plus       |warm_AT |ci_high  | 2027|      0.892|           5.845|   1.744|
|CAZ_Plus       |warm_AT |ci_high  | 2030|      0.965|           5.949|   1.749|
|CAZ_Plus       |warm_AT |ci_low   | 2025|      0.721|           5.599|   1.731|
|CAZ_Plus       |warm_AT |ci_low   | 2027|      0.799|           5.712|   1.737|
|CAZ_Plus       |warm_AT |ci_low   | 2030|      0.878|           5.825|   1.743|
|Constant_Speed |cold_CF |central  | 2025|      0.000|           2.872|   4.307|
|Constant_Speed |cold_CF |central  | 2027|      0.000|           2.872|   4.307|
|Constant_Speed |cold_CF |central  | 2030|      0.000|           2.872|   4.307|
|Constant_Speed |cold_CF |ci_high  | 2025|      0.006|           2.892|   4.282|
|Constant_Speed |cold_CF |ci_high  | 2027|      0.019|           2.931|   4.233|
|Constant_Speed |cold_CF |ci_high  | 2030|      0.038|           2.990|   4.160|
|Constant_Speed |cold_CF |ci_low   | 2025|      0.000|           2.872|   4.307|
|Constant_Speed |cold_CF |ci_low   | 2027|      0.000|           2.872|   4.307|
|Constant_Speed |cold_CF |ci_low   | 2030|      0.000|           2.872|   4.307|
|Constant_Speed |warm_AT |central  | 2025|      0.000|           2.958|   4.123|
|Constant_Speed |warm_AT |central  | 2027|      0.000|           2.958|   4.123|
|Constant_Speed |warm_AT |central  | 2030|      0.000|           2.958|   4.123|
|Constant_Speed |warm_AT |ci_high  | 2025|      0.006|           2.977|   4.099|
|Constant_Speed |warm_AT |ci_high  | 2027|      0.019|           3.015|   4.052|
|Constant_Speed |warm_AT |ci_high  | 2030|      0.038|           3.072|   3.982|
|Constant_Speed |warm_AT |ci_low   | 2025|      0.000|           2.958|   4.123|
|Constant_Speed |warm_AT |ci_low   | 2027|      0.000|           2.958|   4.123|
|Constant_Speed |warm_AT |ci_low   | 2030|      0.000|           2.958|   4.123|
|Rest_of_London |cold_CF |central  | 2025|      0.770|           5.346|   2.133|
|Rest_of_London |cold_CF |central  | 2027|      0.863|           5.609|   1.991|
|Rest_of_London |cold_CF |central  | 2030|      0.898|           5.820|   1.878|
|Rest_of_London |cold_CF |ci_high  | 2025|      0.785|           5.386|   2.111|
|Rest_of_London |cold_CF |ci_high  | 2027|      0.887|           5.677|   1.955|
|Rest_of_London |cold_CF |ci_high  | 2030|      0.931|           5.877|   1.848|
|Rest_of_London |cold_CF |ci_low   | 2025|      0.756|           5.306|   2.154|
|Rest_of_London |cold_CF |ci_low   | 2027|      0.836|           5.533|   2.033|
|Rest_of_London |cold_CF |ci_low   | 2030|      0.854|           5.742|   1.920|
|Rest_of_London |warm_AT |central  | 2025|      0.842|           5.485|   1.926|
|Rest_of_London |warm_AT |central  | 2027|      0.907|           5.696|   1.867|
|Rest_of_London |warm_AT |central  | 2030|      0.913|           5.862|   1.820|
|Rest_of_London |warm_AT |ci_high  | 2025|      0.858|           5.539|   1.911|
|Rest_of_London |warm_AT |ci_high  | 2027|      0.933|           5.781|   1.843|
|Rest_of_London |warm_AT |ci_high  | 2030|      0.955|           5.928|   1.802|
|Rest_of_London |warm_AT |ci_low   | 2025|      0.825|           5.432|   1.941|
|Rest_of_London |warm_AT |ci_low   | 2027|      0.875|           5.592|   1.896|
|Rest_of_London |warm_AT |ci_low   | 2030|      0.844|           5.752|   1.851|

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
|Constant_Speed | 2024|        30|        29|             0.000|             0.414|
|Constant_Speed | 2025|        40|        23|             0.000|             0.261|
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
|All_NRMM       |A2    |      12|       3.21|      2.92|       2.70|        3.70|         3.41|
|All_NRMM       |B     |      13|       2.52|      2.24|       2.00|        3.08|         2.89|
|All_NRMM       |C     |       3|       4.27|      4.26|       4.26|        4.27|         4.57|
|CAZ_Plus       |A1    |      11|       2.88|      2.96|       2.68|        3.22|         3.59|
|CAZ_Plus       |A2    |      12|       2.58|      2.57|       2.23|        3.11|         3.20|
|CAZ_Plus       |B     |      13|       1.77|      1.77|       1.42|        2.28|         2.63|
|Constant_Speed |A2    |       3|       4.23|      4.23|       4.23|        4.24|         4.46|
|Constant_Speed |B     |       5|       4.12|      4.12|       4.12|        4.12|         4.25|
|Constant_Speed |C     |       3|       4.27|      4.26|       4.26|        4.27|         4.57|
|Rest_of_London |A1    |      12|       3.23|      3.23|       2.96|        3.53|         3.70|
|Rest_of_London |A2    |      12|       2.82|      2.77|       2.42|        3.32|         3.35|
|Rest_of_London |B     |      13|       2.16|      2.16|       1.77|        2.58|         2.90|

## 5. Assumptions and placeholders

- Stage NOx limits and usage indices: general-knowledge placeholders.
- N_t: audit counts pending NRMM registration database.
- Projections start from pooled 2023-24 distributions; phase C is
  projection, not estimation (n = 63).
- Constant-speed p-bar pooled across arms (cold too thin annually).
- EF projection holds each stage's 2023-24 power-band mix fixed.
- No bootstrap in v1; p-bar CIs are WLS standard errors, unclustered.

