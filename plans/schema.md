# Schema

version 3 \| May 5 2026

### 1. Tab delimited Input file: input_data/`audits.txt`

### 2. Emissions Stage encoding - Stage values and integer encoding\*\*

1-7: I=1, II=2, IIIA=3, IIIB=4, IV=5, V=6, {ZE\|hybrid\|any other} = 7

### 3. Emissions rating minimum requirements by policy era and machine group (used in e-bar calculation)

| **Policy era ending (columns)**<br />*Machine Groups (rows)* | **1.9.2015**[^1] | **2: 1.9.2020 (+6M)**[^2] | **3: 1.1.2025** | **4: 1.1.2030** | **5: 1.1.2040** |
|------------|------------|------------|------------|------------|------------|
| *Constant speed* | IIIA | V | V | V | ZE |
| *CAZ+* | IIIB | IV | V | V | ZE |
| *Rest of London* | IIIA | IIIB | IV | V | ZE |

[^1]: Policy phase 1 spans 1.9.2015 onwards. 2015 excluded due to lack of audit data.

[^2]: Six-month COVID-19 compliance extension granted.

### 4. Non-compliance codes

**Non-Compliance Codes** come from the multi-values strings used in `Initial Machinery Reasons`, `Final Machinery Reasons`, `Final Site Reasons`, `Initial Site Reasons`

| Code |             Description             |
|:----:|:-----------------------------------:|
|  A   |          Actively Declined          |
|  C   |     Cannot Evidence Compliance      |
|  E   |     Emissions Standard Not Met      |
|  P   |         Passively Declined          |
|  R   |        Registration Problem         |
|  X   |          \[Not Specified\]          |
| None | Compliant or reasons not applicable |

**Rules:**

- These are multi-value strings (e.g. `ER`, `AR`, or single `A`), so two boolean flag features are derived: `emissions_compliant` and `admin_compliant`
- If no `E` code present: set `emissions_compliant = TRUE`, else `FALSE`
- If any other code present: set `admin_compliant = FALSE`, else `TRUE`

### 5. Features to retain from `audits.txt`, data type, and first ingestion task

| Feature | Type | First ingestion task |
|-------------------|-------------------|----------------------------------|
| **Site level data** | --- | --- |
| `Cold-Engaged` | chr | `Yes/No` convert to `TRUE/FALSE` |
| `Zone` |  | Include where `== {"CAZ", "OA", "GL"}`; exclude `"P24"`, `"BCP"` |
| `Date` | Date | yyyy-mm-dd; convert to fractional year float for temporal calculations |
| `Initial Site Compliance` | chr | `"compliant"`, `"non-compliant"`, `"No NRMM"`, check for others |
| `Initial Site Reasons` | chr | As List 2, check for other values |
| `Final Site Compliance` | chr | As List 2, check for other values |
| `Final Site Reasons` | chr | As List 2, check for other values |
| `Audit Num` | chr | Visit number to that site |
| **Machine level data** | --- | --- |
| `Initial Machinery Compliance` | chr | `"emissions compliant"`, `"non-compliant"` based on E presence |
| `Initial Machinery Reasons` | chr | As List 2, check for other values |
| `Initial Emissions Stage` | chr | Encode to int {1-7} per List 1 |
| `Initial Retrofit or Exemption` | chr | Check for other values |
| `Final Machinery Compliance` | chr | As List 2, check for other values |
| `Final Machinery Reasons` |  | As List 2, check for other values |
| `Final Emissions Stage` | chr | Encode to int {1-7} per List 1 |
| `Final Retrofit or Exemption` |  | Check for other values |
| `Machine Type` | chr | If `No NRMM` exclude record |
| `Engine Type` | chr | Assign to one of `"Constant"`, `"Variable"` |
| `kw Power` | chr | If number convert to float; if blank or `Unidentified` set boolean flag `no_power_rating` |
| `TAN` | chr | Unique identifier for the machine |

### 6. Equipment groups, in and out of scope

| In Scope | **Group** | **Description** | **Derivation from raw data** |
|------------------|------------------|------------------|------------------|
| Yes | **Constant Speed** | Generators/constant-speed equipment. Direct IIIA-to-V pathway. | `Engine.Type.clean == "Constant"` (any Zone) |
| Yes | **CAZ+** | Variable-speed machinery in CAZ+. Merges with Rest of London on 1.1.2025. | `Engine.Type.clean == "Variable"` AND `Zone %in% c("CAZ", "OA")` |
| Yes | **Rest of London** | Variable-speed machinery outside CAZ+. | `Engine.Type.clean == "Variable"` AND `Zone == "GL"` |
| Yes | **Variable_Speed** | Merged CAZ+ and Rest of London from 1.1.2025. P24 zone only. | `Engine.Type.clean == "Variable"` AND `Zone == "P24"` |
| No | **BCP** | Beyond Construction Project | `Zone == BCP` |

### 7. Rules for compliance outcomes

| Row | Site Reg? | NRMM in scope | Mach Reg? | Emissions OK?[^3] | Enforcement requested | Site mgmt action | Outcome | Emissions reduced by audit? |
|--------|--------|--------|--------|--------|--------|--------|--------|--------|
| 1 | Y | Y | Y | Y | None | None | Self-compliant | No |
| 2 | Y/N | Y | N | Y | Register site/machine | Registered | Driven compliant | No |
| 3 | Y/N | Y | N | Y | Register site/machine | Not registered | Non-compliant (R) | No |
| 4 | Y/N | Y | Y/N | N | Remove or replace | Removed/replaced | Driven compliant | Yes |
| 5 | Y/N | Y | Y/N | N | Remove or replace | Not actioned | Non-compliant | No |
| 6 | Y/N | N | -- | -- | None | -- | No in-scope plant | No |

[^3]: A prior exemption permit satisfies the emissions compliance requirement, but equipment and site must still be registered.

### 8. Model phases and sub-phases

| **Phase** | sub-phase | Start | End | **Notes** |
|---------------|---------------|---------------|---------------|---------------|
| A |  |  |  |  |
|  | A1 | 1.1.2016 | 31.12.2018 | Pre-Stage V market availability. |
|  | A2 | 1.1.2019 | 31.8.2020 | Stage V equipment newly available. Machines that received a COVID exemption in the period 1.9.2020-31.3.2021 are included here. |
| B |  | 1.9.2020 | 31.12.2024 | Tighter LEZ requirements, excluding COVID exempt machines. Phase B subdivided into 3 equal sub-phases of \~527 days to stabilise variance. |
|  | B1 | 1.9.2020 | 10.2.2022 |  |
|  | B2 | 11.2.2022 | 23.7.2023 |  |
|  | B3 | 24.7.2023 | 31.12.2024 |  |
| C |  | 1.1.2025 | 31.12.2030 | Forecast period. CAZ+ and Rest of London combined. Initialisation state derived from P24 records (Stage distribution snapshot), not projected from end-2024, using a merged dataset of Constant_Speed and Variable_Speed records. |

#### 9. Modelling approach

The modelling approach is based on Markov modelling,

$$\mathbf{N}^{t+1} = \mathbf{P} \times \mathbf{N}^t $$

where $\mathbf{P}$ is a constant 6x6 transition matrix whose non-zero values are $p$ and $\mathbf{N}^t$ is the vector of stage proportions at time t. This assumes stationary transition probabilities across the entire data period. In each sub-phase, different transition rules apply to give different $p$, as previous trials found the simple model failed, as the unconstrained 6x6 matrix has 36 free parameter but only 24 observations to constrain it because Stage V accumulates irreversibly.

To address this, separate matrices are estimated for each LEZ phase and sub-group, s:

$$\mathbf{N}^{t+1} = \begin{cases}
\mathbf{P}_1 \times \mathbf{N}^t & \text{for } t \in [2016, 2018](Upgrade\ to\ Stage\ IIIa/IIIb) \\
\mathbf{P}_2 \times \mathbf{N}^t & \text{for } t \in [2019, 2020](Upgrade\ to\ Stage\ IIIb/IV/V\ depending\ on\ group)
\\
\mathbf{P}_3 \times \mathbf{N}^t & \text{for } t \in [2021, 2025](Upgrade\ to\ Stage\ V)
\\
\mathbf{P}_4 \times \mathbf{N}^t & \text{for } t \in [2026, 2030](Forecast)
\end{cases}$$