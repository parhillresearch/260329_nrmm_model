# Step 3 v2 Error Checklist

Errors identified from Trial 1 (`260415_step3_parameter_estimation_v1.R`).
Each item must be resolved in v2.

---

## Error 1 — e-bar thresholds one policy era behind (Section 2)
- [ ] **Fix**

**Observed:** Phase A1/A2 threshold = IIIA / IIIB / IIIA; Phase B threshold = V / IV / IIIB.

**Schema.md Table 2** uses "Policy era **ending**" column headers, meaning each column
shows the minimum requirement *during the era that ends on that date*:

| Phase | Era-ending column | Correct thresholds | v1 coded | Error |
|---|---|---|---|---|
| A1, A2 | Col 2: 1.9.2020 | CS=V, CAZ+=IV, RoL=IIIB | CS=IIIA, CAZ+=IIIB, RoL=IIIA | One column behind |
| B | Col 3: 1.1.2025 | CS=V, CAZ+=V, RoL=IV | CS=V, CAZ+=IV, RoL=IIIB | One column behind (CS coincidentally correct) |

**Source:** Coding error. Both `V1_1-22/260330_step4_parameter_estimation.R` and v1 used
column-1 (pre-LEZ) thresholds for Phase A, and column-2 thresholds for Phase B.
Schema.md Table 2 is correctly written; no document amendment required.

**Fix:** Update `COMP_THRESH` in v2:
```r
COMP_THRESH <- list(
  A1 = c(Constant_Speed = 6L, CAZ_Plus = 5L, Rest_of_London = 4L),
  A2 = c(Constant_Speed = 6L, CAZ_Plus = 5L, Rest_of_London = 4L),
  B  = c(Constant_Speed = 6L, CAZ_Plus = 6L, Rest_of_London = 5L)
)
```

---

## Error 2 — CAZ+ max_stage=5 coded as INTEGER 5 (IV), not INTEGER 6 (V) (Section 1, lambda_CF)
- [ ] **Fix** (requires user to confirm correct implementation; document may also need amendment)

**Observed:** CAZ+ lambda_CF = −0.2762 (ref 0.363, delta −0.639).

**Diagnosis:** Schema.md and all baseline documents state `CAZ+ max_stage = 5`, with rationale
*"stages I–IV present"* — consistent with Stage I being absent or near-absent from the CAZ+ cold fleet
(per step 2 stage distribution: Stage I barely appears in Phase A and is essentially absent in Phase B/C).
Under this interpretation, max_stage=5 means **5 active stages: II, IIIA, IIIB, IV, V**.

However, `V1_1-22/260329_step3b_lambda_temporal.R` — the script that produced the locked value
0.363 — hardcodes `max_stage <- 6` (integer 6 = Stage V) for **all** groups including CAZ+.
Step 2 stage distribution confirms Stage V is real and dominant in B3 (48/83 = 58% of cold CAZ+ fleet).

The v1 script implemented max_stage=5 as **integer 5 = Stage IV**, which:
- Excludes all Stage V (integer 6) cold records from the GLS
- Leaves the B3 segment with most cold mass above the ceiling
- All GLS predictors collapse toward zero; noise drives the coefficient to −0.276

**Distinction from the Stage-I rationale:** Stage I absence (the schema's stated reason for max_stage=5)
would reduce dilution from near-zero rows — a minor improvement. Stage V exclusion (the actual effect
of implementing max_stage=5 as integer 5) is catastrophic: it amputates the dominant stage in B3.

**Source:** Ambiguity in how max_stage is defined for CAZ+:
- For CS (stages I–IIIA) and RoL (stages I–V): count of active stages = max stage integer. Consistent.
- For CAZ+ (Stage I absent, 5 active stages II–V): count = 5, but max integer = 6. These diverge.
Schema.md records the count (5), v1 coded the integer as 5 (= Stage IV). Document is ambiguous;
coding error flows from that ambiguity.

**Fix:** Use `MAX_STAGE["CAZ_Plus"] = 6L` in v2 to match the step3b implementation that produced
the locked 0.363. If a separate lower-bound filter (excluding Stage I rows from the GLS) is also
desired for signal quality, add explicit `MIN_STAGE` logic — but do not change the integer ceiling.
**Requires user confirmation of intended implementation.**

---

## Error 3 — lambda_Policy = NA for all groups (Section 3)
- [ ] **Fix** (two independent causes)

**Observed:** All three groups show `lambda_policy = NA`; `lambda_proactive = 0` by default.

**Cause A — Step 2 pre-flagged zero warm self-compliant records:**
Step 2 accepted report (line 1368) explicitly warns: *"Route 1 — zero records observed for this subset
in most phases; this is a known constraint flagged for Step 3 review."*
v1 passed these empty datasets to `fit_lambda_wls`, which returned NULL silently. No explicit handling
or report was written for this known constraint.

**Cause B — max_stage=5 for CAZ+/RoL:**
Secondary contributor: warm self-compliant machines at Stage V (6) are excluded from estimation when
max_stage=5 (integer). Even if some warm self-compliant Stage V records exist, they are silently dropped.

**Fix A:** Add explicit count table of warm self-compliant records by group × phase before
the GLS fits; flag groups with n < minimum viable threshold; do not silently return NA.
**Fix B:** Resolves automatically once Error 2 is corrected (max_stage INTEGER = 6 for CAZ+).

---

## Error 4 — e-bar shown as proportion only; no percentage displayed (Section 2)
- [ ] **Fix**

**Observed:** `e_bar` column shows raw proportion (e.g., 0.2212, 0.8283). No percentage form shown.

**Fix:** Add `e_bar_pct = round(e_bar * 100, 1)` column to the e-bar table; display alongside the
raw proportion or replace with percentage as the primary display column.

---

## Error 5 — Output tables not centred
- [ ] **Fix**

**Observed:** Tables render left-aligned in Typora/Positron.

**Fix:** Add `position = "center"` to all `kable_styling()` calls in `save_table_md()`.
```r
kable_styling(bootstrap_options = c("condensed", "bordered"),
              full_width = FALSE, font_size = 9, position = "center")
```

---

## Summary

| # | Section affected | Source | Document change needed? |
|---|---|---|---|
| 1 | Section 2 (e-bar) | Coding error (old + v1) | No — schema.md correct |
| 2 | Section 1 (lambda_CF CAZ+) | Schema ambiguity → coding error | Possibly: clarify max_stage definition |
| 3 | Section 3 (lambda_Proactive) | Known data constraint unhandled + Error 2 | No |
| 4 | Section 2 (e-bar display) | Coding omission | No |
| 5 | All tables | Coding omission | No |
