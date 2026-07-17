# Fleet-effective Emissions Factors (EF) — 260717 v1

EF values are the stage limit taken as the practical emissions value,
assigned per machine at its recorded initial stage and engine power band,
then averaged over each sub-group. Units are g/kWh of engine work, which is
numerically identical to kg/MWh.

**Provenance warning:** stage limit values are drawn from general knowledge
of Directive 97/68/EC and Regulation (EU) 2016/1628, not from project
documents; verify before external use. NOx entries are HC+NOx where that is
what the stage regulates at that band (Stage IIIA, and small bands at later
stages).

## 1. Units test: is 'per MWh operated' the right basis?

The limits are certified in g/kWh, so a fleet EF is a weighted mean of per-machine limit values and the only substantive choice is the weight.

- **Count weighting** assumes every machine delivers the same energy.
- **Rated-power weighting** (used as the headline here) assumes equal operating hours and load factor, so energy share is proportional to kW. This is the closest practical approximation to per-MWh with no usage data in the audits.
- **Per litre of fuel** divides by BSFC x density (~0.22 kg/kWh / 0.84 kg/L => ~0.262 L/kWh), a near-constant scalar: no additional discrimination between machines.
- **Per operating hour** multiplies back by kW x load factor, so it re-introduces the power weighting inside the unit itself and varies machine to machine; unsuitable as a single fleet metric.

Spearman correlation between rated kW and stage is -0.038, i.e. large machines are not newer-staged than small ones. The count-vs-power divergence tabulated below is therefore driven by the band structure of the limits themselves: at the same stage, engines above 130 kW face stricter g/kWh limits than 37-130 kW engines, and the biggest machines contribute the most energy. Count weighting consequently overstates the fleet EF, and the per-MWh (power-weighted) basis is the defensible headline.

### Count-weighted vs power-weighted EF NOx (g/kWh)

|Sub-group      |Phase |    n| EF count-wtd| EF power-wtd| divergence %|
|:--------------|:-----|----:|------------:|------------:|------------:|
|All_NRMM       |A1    |  942|     3.650425|     3.104172|        -15.0|
|All_NRMM       |A2    | 2584|     3.413700|     2.923767|        -14.4|
|All_NRMM       |B     | 7323|     2.895166|     2.239242|        -22.7|
|All_NRMM       |C     |   63|     4.566667|     4.263643|         -6.6|
|CAZ_Plus       |A1    |  402|     3.586816|     2.954154|        -17.6|
|CAZ_Plus       |A2    |  674|     3.197181|     2.565840|        -19.7|
|CAZ_Plus       |B     | 2532|     2.633017|     1.773157|        -32.7|
|Constant_Speed |A2    |  235|     4.461277|     4.229396|         -5.2|
|Constant_Speed |B     |  480|     4.248750|     4.118311|         -3.1|
|Constant_Speed |C     |   63|     4.566667|     4.263643|         -6.6|
|Rest_of_London |A1    |  540|     3.697778|     3.225144|        -12.8|
|Rest_of_London |A2    | 1675|     3.353851|     2.770403|        -17.4|
|Rest_of_London |B     | 4311|     2.898423|     2.156763|        -25.6|

## 2. Fleet-effective EF by sub-group and phase

Power-weighted (per-MWh basis) and count-weighted, NOx and PM.

|Sub-group      |Phase |    n| Total kW| NOx count-wtd| NOx power-wtd| PM count-wtd| PM power-wtd|
|:--------------|:-----|----:|--------:|-------------:|-------------:|------------:|------------:|
|All_NRMM       |A1    |  942|    96351|          3.65|          3.10|        0.105|        0.092|
|All_NRMM       |A2    | 2584|   267759|          3.41|          2.92|        0.090|        0.093|
|All_NRMM       |B     | 7323|   755899|          2.90|          2.24|        0.054|        0.060|
|All_NRMM       |C     |   63|    10284|          4.57|          4.26|        0.275|        0.226|
|CAZ_Plus       |A1    |  402|    43012|          3.59|          2.95|        0.090|        0.078|
|CAZ_Plus       |A2    |  674|    71099|          3.20|          2.57|        0.063|        0.063|
|CAZ_Plus       |B     | 2532|   262055|          2.63|          1.77|        0.037|        0.037|
|Constant_Speed |A2    |  235|    38114|          4.46|          4.23|        0.270|        0.230|
|Constant_Speed |B     |  480|    83032|          4.25|          4.12|        0.257|        0.224|
|Constant_Speed |C     |   63|    10284|          4.57|          4.26|        0.275|        0.226|
|Rest_of_London |A1    |  540|    53339|          3.70|          3.23|        0.115|        0.103|
|Rest_of_London |A2    | 1675|   158546|          3.35|          2.77|        0.075|        0.074|
|Rest_of_London |B     | 4311|   410811|          2.90|          2.16|        0.041|        0.043|

## 3. Warm vs cold engagement (EF NOx, power-weighted)

|Sub-group      |Phase | n Cold| n Warm| EF Cold| EF Warm| Warm - Cold|
|:--------------|:-----|------:|------:|-------:|-------:|-----------:|
|CAZ_Plus       |A1    |     51|    351|    3.07|    2.94|       -0.13|
|CAZ_Plus       |A2    |     72|    602|    2.93|    2.53|       -0.40|
|CAZ_Plus       |B     |    269|   2263|    1.77|    1.77|        0.01|
|Constant_Speed |A2    |     33|    202|    4.51|    4.19|       -0.31|
|Constant_Speed |B     |     89|    391|    4.16|    4.11|       -0.05|
|Constant_Speed |C     |     40|     23|    4.30|    4.17|       -0.14|
|Rest_of_London |A1    |     89|    451|    3.81|    3.13|       -0.68|
|Rest_of_London |A2    |    289|   1386|    3.59|    2.62|       -0.97|
|Rest_of_London |B     |    944|   3367|    2.58|    2.06|       -0.52|

## 4. Sensitivity: kW imputation

kW was imputed from machine-type medians for 3.1% of records. Power-weighted EF with and without those records:

|Sub-group      |Phase | EF (imputed incl.)| EF (known kW only)|  delta|
|:--------------|:-----|------------------:|------------------:|------:|
|CAZ_Plus       |A1    |              2.954|              2.909|  0.046|
|CAZ_Plus       |A2    |              2.566|              2.567| -0.001|
|CAZ_Plus       |B     |              1.773|              1.776| -0.002|
|Constant_Speed |A2    |              4.229|              4.183|  0.046|
|Constant_Speed |B     |              4.118|              4.109|  0.009|
|Constant_Speed |C     |              4.264|              4.272| -0.008|
|Rest_of_London |A1    |              3.225|              3.199|  0.026|
|Rest_of_London |A2    |              2.770|              2.739|  0.031|
|Rest_of_London |B     |              2.157|              2.145|  0.012|

