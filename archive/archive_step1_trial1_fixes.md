# Step 1 Fix Recommendations
# Reviewer: user | Status: DRAFT — awaiting review and approval before implementation

---

## Background

During logic review of `260413_step1_ingestion_v1.R` two problems were identified:

1. **Date filter upper bound is wrong.** The script removes all records with `date > 2024-12-31`. The audit file contains 2025–2026 records, which use zone label `P24` (the post-2024 merged zone replacing CAZ/OA/GL) or `BCP` (a separate project, out of scope). Since all post-2024 in-scope records already carry the `P24` zone label, the zone filter alone handles their inclusion or exclusion. The date upper bound is therefore both redundant and harmful: it prevents P24 records from being used.

2. **Phase C initialisation uses stale 2024 data.** The script initialises the Phase C forecast from the end-2024 Stage distribution. With P24 audit data available to April 2026, initialising from 2024 introduces ~16 months of unnecessary lag. The Phase C initialisation should be derived from the latest available P24 cold-engaged records.

**Confirmed facts from user:**
- All 2025–2026 records in `audits.txt` carry zone `P24` or `BCP`. No CAZ/OA/GL records exist after 1.1.2025.
- P24 is the administrative continuation of the merged CAZ+/Rest of London zone.
- BCP (Beyond Construction Project) is wholly out of scope.
- P24 records should be retained and used for Phase C initialisation only. Parameter re-estimation from P24 data is reserved for a later step.

---

## Fix 1 — schema.md

### 1a. Table 1 (Equipment groups)

**Problem:** P24 is listed as out-of-scope with derivation `Zone == P24 OR date >= 1.1.2025`. This prevents P24 records from being assigned to any group.

**Change:** Replace the P24 out-of-scope row with two in-scope derivation rules that assign P24 records to existing groups by engine type. The standalone "Post 2024" group row is removed.

Old row:
```
| No | Post 2024 | All machinery after 2024 | `Zone == P24` OR `date >= 1.1.2025` |
```

Replace with (additions to existing in-scope group derivation rules): **(user_edit updated to correct to Constant_Speed)**
```
| Yes | Constant_Speed | ... (existing description) | `Engine.Type.clean == "Constant"` (any Zone, including P24) |
| Yes | Variable_Speed | Merged CAZ+ and Rest of London from 1.1.2025. P24 zone only. | `Engine.Type.clean == "Variable"` AND `Zone == "P24"` |
```

Note for Claude: `Variable_Speed` is a new group name used exclusively for P24 records. `Constant_Speed` is unchanged — it already spans any zone. The existing CAZ_Plus and Rest_of_London group rows remain for pre-2025 records.

### 1b. Table 6 (Records to remove)(user_edit consider removing this entirely as there are no pre 2016 records)

**Problem:** `Dates outside 2016-2024` sets an upper bound of 2024 that removes all P24 records before the zone filter runs.

**Change:** Remove the upper bound. Keep only the lower bound.

Old row:
```
| Dates outside 2016-2024 |
```

New row:
```
| Dates before 1.1.2016 |
```

### 1c. Table 7 (Phase C note)

**Problem:** Phase C has no note about how the initialisation state is derived.

**Change:** Append to the Phase C rationale cell **(user_edit added "using a merged dataset of Constant_speed and Variable_speed records."):**

```
Initialisation state for forecasting derived from the P24 records (Stage distribution snapshot), not projected from end-2024, using a merged dataset of Constant_speed and Variable_speed records.
```

---

## Fix 2 — draft_plan.md (user_edit remove as made redundant by removal of Table 6 - consider implications)

### 2a. Step 1, sub-task 2 (Exclusion filter)

**Problem:** Refers to "schema.md Table 6" without qualification. After Fix 1b the table changes, but the prose should also be explicit about P24 retention.

**Change:** Replace:
```
2. Exclude out-of-scope records per schema.md Table 6
```
With:
```
2. Exclude out-of-scope records per schema.md Table 6. Zone filter retains CAZ, OA, GL, 
   and P24; excludes BCP only. Date filter lower bound is 1.1.2016; no upper bound.
```

### 2b. Step 1, sub-task 3 (Group and phase assignment)

**Problem:** Does not mention P24 group assignment or Phase C assignment for P24-dated records.

**Change:** Replace:
```
3. Assign every retained record to a machine group (schema.md Table 1) and model phase 
   (schema.md Table 7); store as tibble `audits`
```
With:
```
3. Assign every retained record to a machine group (schema.md Table 1) and model phase 
   (schema.md Table 7); store as tibble `audits`. P24 Variable Speed records → group 
   `Variable_Speed`; P24 Constant Speed records → group `Constant_Speed`. Records with 
   date >= 1.1.2025 → Phase C.
```

### 2c. Step 1, sub-task 4 (Record counts)

**Problem:** Does not mention reporting P24 counts or flagging the temporal extent of P24 data.

**Change:** Append to sub-task 4: **(user_edit added "categorise as Phase C")**

```
Report P24 record counts separately from Phase A1/A2/B counts. Flag the earliest and 
latest P24 audit date to confirm initialisation data availability, categorise as Phase C.
```

### 2d. Step 5, sub-task 1 (Forecast initialisation)

**Problem:** Implicitly initialises from end-2024 Stage distribution.

**Change:** Add explicit initialisation instruction. Append to sub-task 1:
```
Initialise Phase C from the Stage distribution of the latest available P24 cold-engaged 
records. Forecast horizon runs from that date to 31.12.2030.
```

### 2e. Step 5, sub-task 2 (CAZ+/RoL merge)(user_edit adjust to combine the constant_speed data into the pool with P24 variable_speed)

**Problem:** The merge instruction is redundant — P24 records are already assigned to the `Variable_Speed` group at ingestion. Keeping the instruction as written implies a merge operation is needed in Step 5, which it is not.

**Change:** Replace:
```
2. Merge CAZ+ and Rest of London into combined Variable Speed group from 1.1.2025 onward
```
With:
```
2. Use `Variable_Speed` group (P24 records) directly as the merged post-2025 variable-speed fleet. No merge operation required; group assignment at Step 1 handles this.
```

---

## Fix 3 — 260413_step1_ingestion_v1.R

### 3a. ZONES_IN_SCOPE constant

**Problem:** `P24` is absent from `ZONES_IN_SCOPE`, so all P24 records are removed by the zone filter.

**Old:**
```r
ZONES_IN_SCOPE <- c("CAZ", "OA", "GL")
```
**New:**
```r
ZONES_IN_SCOPE <- c("CAZ", "OA", "GL", "P24")
```

### 3b. Date filter upper bound (user_edit this filter step can be removed entirely as lower date bound not relevant)

**Problem:** `date <= as.Date("2024-12-31")` removes all P24 records.

**Old:**
```r
audits <- audits |> filter(date >= as.Date("2016-01-01"),
                            date <= as.Date("2024-12-31"))
```
**New:**
```r
audits <- audits |> filter(date >= as.Date("2016-01-01"))
```

Update the message line accordingly:
```r
message("3. Date filter >= 2016-01-01: removed ", n_before - nrow(audits),
        "; retained ", nrow(audits))
```

### 3c. Phase boundaries — add Phase C

**Problem:** `assign_phase()` returns `NA` for all P24 records (date >= 1.1.2025). The NA phase check then flags them as anomalies.

**Old:**
```r
PHASE_B_START  <- as.Date("2020-09-01"); PHASE_B_END  <- as.Date("2024-12-31")
```
**New:**
```r
PHASE_B_START  <- as.Date("2020-09-01"); PHASE_B_END  <- as.Date("2024-12-31")
PHASE_C_START  <- as.Date("2025-01-01")
```

Update `assign_phase()`:

**Old:**
```r
assign_phase <- function(d) {
  case_when(
    d >= PHASE_A1_START & d <= PHASE_A1_END ~ "A1",
    d >= PHASE_A2_START & d <= PHASE_A2_END ~ "A2",
    d >= PHASE_B_START  & d <= PHASE_B_END  ~ "B",
    TRUE ~ NA_character_
  )
}
```
**New:** **(user_edit PHASE_A1_START now redundant)**

```r
assign_phase <- function(d) {
  case_when(
    d >= PHASE_A1_START & d <= PHASE_A1_END ~ "A1",
    d >= PHASE_A2_START & d <= PHASE_A2_END ~ "A2",
    d >= PHASE_B_START  & d <= PHASE_B_END  ~ "B",
    d >= PHASE_C_START                      ~ "C",
    TRUE ~ NA_character_
  )
}
```

### 3d. Group assignment — add Variable_Speed for P24

**Problem:** The `group` case_when does not handle `zone == "P24"`, leaving all P24 records with `NA` group and discarding them via the unassignable filter.

**Old:**
```r
group = case_when(
  engine_type_clean == "Constant"                               ~ "Constant_Speed",
  engine_type_clean == "Variable" & zone %in% c("CAZ", "OA")   ~ "CAZ_Plus",
  engine_type_clean == "Variable" & zone == "GL"                ~ "Rest_of_London",
  TRUE ~ NA_character_
)
```
**New:**
```r
group = case_when(
  engine_type_clean == "Constant"                               ~ "Constant_Speed",
  engine_type_clean == "Variable" & zone %in% c("CAZ", "OA")   ~ "CAZ_Plus",
  engine_type_clean == "Variable" & zone == "GL"                ~ "Rest_of_London",
  engine_type_clean == "Variable" & zone == "P24"               ~ "Variable_Speed",
  TRUE ~ NA_character_
)
```

Note for Claude: `Constant_Speed` machines in P24 are already captured by the first arm (engine_type_clean == "Constant"), which is zone-agnostic. No additional arm is needed for them.

### 3e. Sub-task 4 reporting — add P24 / Phase C block

**Problem:** Record counts only pivot over phases A1/A2/B. Phase C (P24) counts are not reported separately, and temporal extent of P24 data is not flagged.

**Change:** After the existing `counts_warm` block, add a new reporting block:

```r
# P24 / Phase C records
counts_p24 <- audits |>
  filter(phase == "C") |>
  count(group, cold_engaged) |>
  pivot_wider(names_from = cold_engaged, values_from = n,
              values_fill = 0L, names_prefix = "cold_") |>
  arrange(group)

message("\nPhase C (P24) records by group and engagement:")
save_table(counts_p24, "260413_step1_counts_p24")

p24_dates <- audits |> filter(phase == "C") |> summarise(
  earliest = min(date), latest = max(date), n = n()
)
message("\nP24 temporal extent: ", p24_dates$earliest,
        " to ", p24_dates$latest,
        " (n = ", p24_dates$n, ")")
message("Latest P24 date will be used as Phase C initialisation point in Step 5.")
```

---

## Summary of all changes (user_edit update last to reflect changes)

| # | File | Section | Nature of change |
|---|------|---------|-----------------|
| 1a | schema.md | Table 1 | Add P24 group derivation rules; remove P24 out-of-scope row |
| 1b | schema.md | Table 6 | Remove date upper bound 2024 |
| 1c | schema.md | Table 7 | Add Phase C initialisation note |
| 2a | draft_plan.md | Step 1.2 | Explicit P24 retention in zone filter; no date upper bound |
| 2b | draft_plan.md | Step 1.3 | P24 group and Phase C assignment |
| 2c | draft_plan.md | Step 1.4 | Report P24 counts and temporal extent |
| 2d | draft_plan.md | Step 5.1 | Initialise from latest P24 data |
| 2e | draft_plan.md | Step 5.2 | Remove redundant merge instruction |
| 3a | step1 script | ZONES_IN_SCOPE | Add "P24" |
| 3b | step1 script | Date filter | Remove upper bound |
| 3c | step1 script | assign_phase() | Add Phase C arm |
| 3d | step1 script | group assignment | Add Variable_Speed arm for P24 |
| 3e | step1 script | Sub-task 4 | Report Phase C counts and temporal extent |
