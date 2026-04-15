# Schema

version 2 | 13 April 2026

## Input file

**Name of tab-delimited input file:** `audits.txt`

## Emissions Stage encoding

**List 1: EU Emissions Stage values and integer encoding**

1-7: I=1, II=2, IIIA=3, IIIB=4, IV=5, V=6, {ZE|hybrid|any other} = 7

## Equipment groups

##### Table 1. Equipment groups, in and out of scope

| In Scope | **Group**          | **Description**                                              | **Derivation from raw data**                                 |
| -------- | ------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| Yes      | **Constant Speed** | Generators/constant-speed equipment. Direct IIIA-to-V pathway. | `Engine.Type.clean == "Constant"` (any Zone)                 |
| Yes      | **CAZ+**           | Variable-speed machinery in CAZ+. Merges with Rest of London on 1.1.2025. | `Engine.Type.clean == "Variable"` AND `Zone %in% c("CAZ", "OA")` |
| Yes      | **Rest of London** | Variable-speed machinery outside CAZ+.                       | `Engine.Type.clean == "Variable"` AND `Zone == "GL"`         |
| Yes      | **Variable_Speed** | Merged CAZ+ and Rest of London from 1.1.2025. P24 zone only. | `Engine.Type.clean == "Variable"` AND `Zone == "P24"`       |
| No       | **BCP**            | Beyond Construction Project                                  | `Zone == BCP`                                                |

## Binary emissions compliance requirements

##### Table 2. Emissions rating minimum requirements by policy era and machine group (used in e-bar calculation)

| **Policy era ending (columns)**<br />*Machine Groups (rows)* | **1.9.2015**[^1] | **2: 1.9.2020 (+6M)**[^2] | **3: 1.1.2025** | **4: 1.1.2030** | **5: 1.1.2040** |
| ------------------------------------------------------------ | ---------------- | ------------------------- | --------------- | --------------- | --------------- |
| *Constant speed*                                             | IIIA             | V                         | V               | V               | ZE              |
| *CAZ+*                                                       | IIIB             | IV                        | V               | V               | ZE              |
| *Rest of London*                                             | IIIA             | IIIB                      | IV              | V               | ZE              |

[^1]: Policy phase 1 spans 1.9.2015 onwards. 2015 excluded due to lack of audit data.
[^2]: Six-month COVID-19 compliance extension granted.

## Compliance outcome routing

##### Table 3. Rules for compliance outcomes

| Row | Site Reg? | NRMM in scope | Mach Reg? | Emissions OK?[^3] | Enforcement requested | Site mgmt action | Outcome           | Emissions reduced by audit? |
| --- | --------- | ------------- | --------- | ------------------ | --------------------- | ---------------- | ----------------- | --------------------------- |
| 1   | Y         | Y             | Y         | Y                  | None                  | None             | Self-compliant    | No                          |
| 2   | Y/N       | Y             | N         | Y                  | Register site/machine | Registered       | Driven compliant  | No                          |
| 3   | Y/N       | Y             | N         | Y                  | Register site/machine | Not registered   | Non-compliant (R) | No                          |
| 4   | Y/N       | Y             | Y/N       | N                  | Remove or replace     | Removed/replaced | Driven compliant  | Yes                         |
| 5   | Y/N       | Y             | Y/N       | N                  | Remove or replace     | Not actioned     | Non-compliant     | No                          |
| 6   | Y/N       | N             | --        | --                 | None                  | --               | No in-scope plant | No                          |

[^3]: A prior exemption permit satisfies the emissions compliance requirement, but equipment and site must still be registered.

## Non-compliance codes

**List 2: Non-Compliance Codes** used in `Initial Machinery Reasons`, `Final Machinery Reasons`, `Final Site Reasons`, `Initial Site Reasons`

| Code | Description                       |
| :--: | :-------------------------------: |
| A    | Actively Declined                 |
| C    | Cannot Evidence Compliance        |
| E    | Emissions Standard Not Met        |
| P    | Passively Declined                |
| R    | Registration Problem              |
| X    | [Not Specified]                   |
| None | Compliant or reasons not applicable |

**Rules:**

- These are multi-value strings (e.g. `ER`, `AR`, or single `A`), so two boolean flag features are derived: `emissions_compliant` and `admin_compliant`
- If no `E` code present: set `emissions_compliant = TRUE`, else `FALSE`
- If any other code present: set `admin_compliant = FALSE`, else `TRUE`

## Column catalogue

##### Table 4. Features retained from `audits.txt`, data type, and first ingestion task

| Feature                         | Type | First ingestion task                                         |
| ------------------------------- | ---- | ------------------------------------------------------------ |
| **Site level data**             | ---  | ---                                                          |
| `Cold-Engaged`                  | chr  | `Yes/No` convert to `TRUE/FALSE`                             |
| `Zone`                          |      | Include where `== {"CAZ", "OA", "GL"}`; exclude `"P24"`, `"BCP"` |
| `Date`                          | Date | yyyy-mm-dd; convert to fractional year float for temporal calculations |
| `Initial Site Compliance`       | chr  | `"compliant"`, `"non-compliant"`, `"No NRMM"`, check for others |
| `Initial Site Reasons`          | chr  | As List 2, check for other values                            |
| `Final Site Compliance`         | chr  | As List 2, check for other values                            |
| `Final Site Reasons`            | chr  | As List 2, check for other values                            |
| **Machine level data**          | ---  | ---                                                          |
| `Initial Machinery Compliance`  | chr  | `"emissions compliant"`, `"non-compliant"` based on E presence |
| `Initial Machinery Reasons`     | chr  | As List 2, check for other values                            |
| `Initial Emissions Stage`       | chr  | Encode to int {1-7} per List 1                               |
| `Initial Retrofit or Exemption` | chr  | Check for other values                                       |
| `Final Machinery Compliance`    | chr  | As List 2, check for other values                            |
| `Final Machinery Reasons`       |      | As List 2, check for other values                            |
| `Final Emissions Stage`         | chr  | Encode to int {1-7} per List 1                               |
| `Final Retrofit or Exemption`   |      | Check for other values                                       |
| `Machine Type`                  | chr  | If `No NRMM` exclude record                                  |
| `Engine Type`                   | chr  | Assign to one of `"Constant"`, `"Variable"`                  |
| `kw Power`                      | chr  | If number convert to float; if blank or `Unidentified` set boolean flag `no_power_rating` |

##### Table 5. Features to discard after import

Site Reference, Officer, Major/Minor, Audit #, Off-Scope, Audit Type, First Border, Supplier, Engine Manufacturer, Item Manufacturer, ID, TAN, TAN Proof, Second Border, Third Border, Fourth Border, Comments

## Phase boundaries

##### Table 7. Model phases and sub-phases

| **Phase** | Start    | End        | **Rationale & Adjustments**                                  |
| --------- | -------- | ---------- | ------------------------------------------------------------ |
| A1        | 1.1.2016 | 31.12.2018 | Pre-Stage V market availability.                             |
| A2        | 1.1.2019 | 31.8.2020  | Stage V equipment newly available.                           |
| B         | 1.9.2020 | 31.12.2024 | Tighter LEZ requirements. COVID exempt records (1.9.2020-31.3.2021) filtered out. Phase B subdivided into 3 equal segments (~527 days) for variable speed groups to stabilise variance. |
| C         | 1.1.2025 | 31.12.2030 | Forecast period. CAZ+ and Rest of London combined. Initialisation state derived from P24 records (Stage distribution snapshot), not projected from end-2024, using a merged dataset of Constant_Speed and Variable_Speed records. |

Phase B 3-segment midpoints (fractional years): 2021.389, 2022.832, 2024.278. Delta-t = 1.44 and 1.45 years.

## Previous parameter estimates 

##### Table 8. Previous trial lambda_CF values

| Parameter           | Value | Source                                  |
| ------------------- | ----- | --------------------------------------- |
| lambda_CF Constant_Speed | 0.358 | step3c, 2017-2023 pooled, max_stage=3   |
| lambda_CF CAZ+           | 0.363 | step3b, temporal 3-segment, max_stage=6 |
| lambda_CF Rest_of_London | 0.219 | step3b, temporal 3-segment, max_stage=6 |

## Active state spaces

- Constant_Speed: max_stage = 3 (active stages I, II, IIIA only; IIIB/IV never present in cold fleet)
- CAZ+: max_stage = 6 (active stages II–V; Stage I near-absent from cold fleet; 5 active stages, max integer = 6 = Stage V)
- Rest_of_London: max_stage = 6 (full stage range present)

## Key analytical notes from previous trials

| # | Decision                                                   | Rationale                                                    |
| - | ---------------------------------------------------------- | ------------------------------------------------------------ |
| 1 | Constant_Speed max_stage set to 3, not 6                   | IIIB/IV absent from cold fleet; uniform max_stage=6 dilutes signal into impossible states |
| 2 | Phase B CAZ+ uses 3-segment temporal split, not annual GLS | Annual sample sizes 37-83; annual GLS yields inflated lambda=0.638; temporal estimate 0.363 |
| 3 | 2024 CS cold data excluded from lambda_CF estimation       | Stage V spike 0% to 61% is anticipatory regulatory compliance, not natural turnover; use as Phase C initialisation state only |
| 4 | e-bar definition: Stage-threshold on all records           | Enforcement_Upgrade flag captures only 35 on-the-spot replacements; threshold-based definition yields 10-20% exposure rates consistent with raw data |
| 5 | lambda_Proactive estimated from warm self-compliant subset only | All-warm WLS confounds proactive and enforcement trajectories; self-compliant subset isolates pure LEZ policy response |
| 6 | e-bar not subtracted from lambda_Policy in lambda_Proactive calculation | Non-compliant machines excluded from estimation window by construction |

## Known limitations (flag in outputs)

1. Ecological inference: aggregate counts approximate individual transition hazards (Robinson, 1950)
2. Entry/exit bias: model absorbs fleet entry/exit; violates Markov time-homogeneity
3. lambda_CF not time-homogeneous within Phase B: segment 1-2 and 2-3 inconsistent across all groups; single lambda per phase is a simplification
4. lambda_CF overestimates true counterfactual due to second-hand market leakage; lambda_Proactive is conservative lower bound
5. Phase A1/A2 variable speed groups pooled due to sparsity (A1 n=139; A2 n=357)

## Emission factors

Applied per Stage in emissions estimation (Step 5). Store as named vector `EF_s` keyed on Stage integer. Operating hours default: 2,000 hr/annum for all groups and stages. User will supply figures at the right stage using  (EMEP/EEA Tier 3, Ntziachristos & Samaras 2019).

