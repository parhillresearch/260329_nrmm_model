**The cleaner solution:** Split by *content type*, not analysis step:

- `schema.md` retains only the permanent reference material: Stage encoding, group definitions, compliance thresholds, phase boundaries, emission factors
- A second file `docs/ingestion.md` holds the column catalogue, discard list, encoding tasks, and filter counts -- referenced with `@` in `CLAUDE.md` during step 1, then removed from the `@` reference once ingestion is complete and `audits` is saved as `.rds`



**Name of tab delimited input file:** `audits.txt`

**List 1: EU Emissions Stage values, other values, and encoding**

1–7: I=1, II=2, IIIA=3, IIIB=4, IV=5, V=6, {ZE|hybrid|any other} = 7



**List 2: Non-Compliance Codes (can be multiple together) and rules** used in `Initial Machinery Reasons`, `Final Machinery Reasons`,`Final Site Reasons`, `Initial Site  Reasons`

| Non-Compliance Code |             Description             |
| :-----------------: | :---------------------------------: |
|          A          |          Actively Declined          |
|          C          |     Cannot Evidence Compliance      |
|          E          |     Emissions Standard Not Met      |
|          P          |         Passively Declined          |
|          R          |        Registration Problem         |
|          X          |           [Not Specified]           |
|        None         | Compliant or reasons not applicable |

**Rules:**

- These are multi-value strings, e.g. can be `ER` or `AR` as well as e.g. `A`, so two boolean lfag features are used, `emissions_compliant`,`admin_compliant`
- If no `E`code then then set boolean feature `"emissions_compliant"` as True, else as False
- If other code then set boolean feature: `"admin_compliant"`as False, else as True



**List 3: Features to discard after import:** 

Site Reference, Officer, Borough, Major/Minor, Principal Contractor, Audit #, Off-Scope, Audit Type, First Border, Supplier, Engine Manufacturer, Item Manufacturer, ID, TAN, TAN Proof, Second Border, Third Border, Fourth Border, Comments



##### Table 1: `audits.txt` features to retain for model, data type, first ingestion task, categorised as Site level or Machine level data

| Feature                         | Type | First ingestion task                                         |
| ------------------------------- | ---- | ------------------------------------------------------------ |
| **Site level data**             | ---  | ---                                                          |
| `Cold-Engaged`                  | chr  | `Yes/no` convert to `True/False`                             |
| `Zone`                          |      | include record `where == {"CAZ"`, `"OA"`, `"GL"}` ; exclude records == `"P24"`, `"BCP"` |
| `Date`                          | Date | yyyy-mm-dd; converted to fractional year for temporal calculations, a float value |
| `Initial Site Compliance`       | chr  | `"compliant"`, `"non-compliant"`, `"No NRMM"`, check for others |
| `Initial Site Reasons`          | chr  | As List 2, check for other values                            |
| `Final Site Compliance `        | chr  | As List 2, check for other values                            |
| `Final Site Reasons`            | chr  | As List 2, check for other values                            |
| **Machine  level data**         | ---  | ---                                                          |
| `Initial Machinery Compliance`  | chr  | `"emissions compliant"`, `"non-compliant"` based on whether E present |
| `Initial Machinery Reasons`     | chr  | As List 2, check for other values                            |
| `Initial Emissions Stage`       | chr  | Encode to int:{1-7] as per List 1.                           |
| `Initial Retrofit or Exemption` | chr  | Check for other values                                       |
| `Final Machinery Compliance`    | chr  | As List 2, check for other values                            |
| `Final Machinery  Reasons`      |      | As List 2, check for other values                            |
| `Final Emissions Stage`         | chr  | Encode to int:{1-7] as per List 1.                           |
| `Final Retrofit or Exemption`   |      | Check for other values                                       |
| `Machine Type`                  | chr  | if `No NRMM`exclude record                                   |
| `Engine Type`                   | chr  | Assign to  one of set `"Constant"`, `"Variable"`             |
| `kw Power`                      | chr  | If number convert to float, if blank or `Unidentified` then set boolen flag in tibble feature `No.power.rating` |



##### Table 4: Audit record to remove as they are out of scope

| Filter                            |
| --------------------------------- |
| Dates outside 2016–2024           |
| Non-machinery                     |
| Zone out of scope (P24, BCP)      |
| Unassignable engine types         |
| Unresolvable emissions Stages     |
| COVID-exempt (1.9.2020–31.3.2021) |



## 