# Fleet-effective EF v2 — type-stratified convex-combination model (260717)

EF_fleet = sum_t s_t x EF_t with s_t = N_t x kWbar_t x u_t (normalised).
EF_t is the power-weighted stage-limit EF of machine type t in the cell;
u_t is a RELATIVE usage index (load factor x hours, excavator = 1).
Units g/kWh = kg/MWh. The result is a convex combination, so it is bounded
by the cleanest and dirtiest type mean whatever usage values are assumed,
and any common scaling of u cancels in the normalisation.

**PLACEHOLDERS:** usage indices are indicative general-knowledge values,
not sourced estimates; N_t are audit counts pending the NRMM registration
database; stage limits as v1 (verify against the Regulation).

## 1. Placeholder usage indices (relative, excavator = 1)

|Machine type  | u central| u low| u high|
|:-------------|---------:|-----:|------:|
|Excavator     |       1.0|   0.7|    1.3|
|Generator     |       3.0|   1.5|    5.0|
|Telehandler   |       0.8|   0.5|    1.2|
|Dumper        |       0.7|   0.4|    1.1|
|Piling Rig    |       0.8|   0.5|    1.2|
|Pump          |       2.5|   1.0|    4.0|
|Mobile Crane  |       0.5|   0.3|    0.9|
|Crusher       |       1.2|   0.7|    1.8|
|Crawler Crane |       0.6|   0.4|    1.0|
|Roller        |       0.6|   0.3|    1.0|
|MEWP          |       0.5|   0.3|    0.8|
|Compressor    |       1.5|   0.8|    2.5|
|Other         |       0.8|   0.4|    1.2|

## 2. Fleet EF NOx by sub-group and phase (g/kWh)

Central = placeholder usage indices; envelope = adversarial box bounds on
u (the widest the answer can move within the stated ranges); count and kW
references are the v1 special cases (u equal per machine / per kW).

|Sub-group      |Phase |    n| EF central| Env low| Env high| Count ref| kW ref|
|:--------------|:-----|----:|----------:|-------:|--------:|---------:|------:|
|All_NRMM       |A1    |  942|       3.06|    2.88|     3.36|      3.65|   3.11|
|All_NRMM       |A2    | 2584|       3.21|    2.70|     3.70|      3.41|   2.92|
|All_NRMM       |B     | 7323|       2.52|    1.99|     3.08|      2.89|   2.24|
|All_NRMM       |C     |   63|       4.27|    4.26|     4.27|      4.57|   4.26|
|CAZ_Plus       |A1    |  402|       2.87|    2.67|     3.21|      3.59|   2.95|
|CAZ_Plus       |A2    |  674|       2.58|    2.23|     3.11|      3.20|   2.57|
|CAZ_Plus       |B     | 2532|       1.77|    1.42|     2.28|      2.63|   1.77|
|Constant_Speed |A2    |  235|       4.23|    4.23|     4.24|      4.46|   4.23|
|Constant_Speed |B     |  480|       4.12|    4.12|     4.12|      4.25|   4.12|
|Constant_Speed |C     |   63|       4.27|    4.26|     4.27|      4.57|   4.26|
|Rest_of_London |A1    |  540|       3.23|    2.96|     3.53|      3.70|   3.23|
|Rest_of_London |A2    | 1675|       2.82|    2.42|     3.32|      3.35|   2.77|
|Rest_of_London |B     | 4311|       2.16|    1.77|     2.58|      2.90|   2.16|

Normalisation property, computed: moving every u jointly to its low bound versus jointly to its high bound shifts the answer by only 0.231 g/kWh (a pure common scaling would shift it by exactly zero; the residual reflects bounds not proportional to the central values). Near-common changes in usage cancel; only relative usage between types moves the result, which is what the adversarial envelope above measures.

## 3. One-at-a-time usage sensitivity (whole fleet, phase B)

Central EF 2.52 g/kWh. Each row perturbs one type's u to its bounds, others central.

|Machine type  |  EF_t| u central| EF at u low| EF at u high| swing|
|:-------------|-----:|---------:|-----------:|------------:|-----:|
|Generator     | 3.746|       3.0|       2.263|        2.748| 0.485|
|Excavator     | 1.141|       1.0|       2.663|        2.399| 0.264|
|Telehandler   | 4.342|       0.8|       2.481|        2.567| 0.086|
|Dumper        | 4.288|       0.7|       2.482|        2.565| 0.083|
|Pump          | 1.959|       2.5|       2.556|        2.486| 0.069|
|Piling Rig    | 0.968|       0.8|       2.542|        2.489| 0.053|
|Other         | 1.982|       0.8|       2.528|        2.510| 0.017|
|Crusher       | 1.538|       1.2|       2.526|        2.510| 0.017|
|Mobile Crane  | 1.517|       0.5|       2.524|        2.509| 0.015|
|Crawler Crane | 1.109|       0.6|       2.523|        2.511| 0.012|
|MEWP          | 4.603|       0.5|       2.515|        2.524| 0.009|
|Compressor    | 2.823|       1.5|       2.517|        2.521| 0.004|
|Roller        | 1.861|       0.6|       2.521|        2.516| 0.004|

## 4. Reading the sensitivity

The envelope quantifies how much the usage assumptions can matter; the OAT table shows which single dials move the answer. Types with large swing combine a big energy share with an EF_t far from the fleet mean, so those are the usage estimates worth sourcing well (and the registration N_t worth checking first).

