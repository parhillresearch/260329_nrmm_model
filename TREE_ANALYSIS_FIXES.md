# tree_analysis_rol_outcome_focused.R — Item 7 Compliance Fixes

## Applied Fixes (2026-06-18)

Script updated to fully comply with **schema.md Item 7: Rules for compliance outcomes**.

### 1. Outcome Definition Separation

**Before:** Single outcome `emissions_improved = (initial_non_compliant & final_compliant)`

**After:** Two separate pathways per Item 7 Row 4:
- `emissions_improved_by_upgrade`: Initial non-compliant → Final stage ≥ threshold (stage improvement)
- `emissions_improved_by_removal`: Initial non-compliant → Final Machinery Compliance contains "Removed"

Combined: `emissions_improved = (upgraded | removed)`

**Impact:** Now captures both pathways: machines that are replaced with compliant equipment (stage upgrade) AND machines that are removed entirely (no further emissions from site).

---

### 2. NRMM In-Scope Filtering (Item 7 requirement)

**Before:** No explicit "No NRMM" filter; only Zone/Engine Type filtered

**After:** Added explicit check:
```r
filter(`Machine Type` != "No NRMM")
```

Data quality report now shows:
- Total records with each Machine Type value
- Count of "No NRMM" records excluded
- Count of NRMM in-scope records retained

**Impact:** Ensures only in-scope machinery analyzed, per Item 7 requirement.

---

### 3. Enforcement Pathway Validation

**Before:** No examination of enforcement-related fields

**After:** Separate analysis of both pathways with field inspection:

**Stage Upgrade Pathway:**
- Initial Site Compliance (baseline)
- Final Site Compliance (post-action)
- Initial Machinery Compliance (baseline)
- Final Machinery Compliance (should be "Compliant" or "Removed")
- Final Site Reasons (enforcement action codes per Item 4)
- Final Retrofit or Exemption status

**Removal Pathway:**
- Same fields as above
- Final Machinery Compliance (should contain "Removed")
- Final Site Reasons (should show removal action)

**Impact:** User can now manually inspect these fields to verify Item 7 Row 4 pathway encoding in raw data.

---

### 4. Data Quality Report Enhancement

**Before:** Generic "missing stage data" and "suspect records"

**After:** Item 7-specific quality checks:
- Unique Machine Type values and counts
- "No NRMM" exclusion count (Item 7 requirement)
- Outcomes separated: upgrade vs. removal counts
- Clear summary of filter operation

---

### 5. Enforcement Effectiveness Breakdown

**Before:** Only cold-engaged count and rate

**After:** Breakdown by Cold-Engaged status WITH pathway separation:
- Total records, by engagement status
- Upgrades, removals, total improvements (per status)
- Improvement rate (%) per engagement status
- Ratio of cold-to-warm effectiveness

**Impact:** Tests Item 7 implication that enforcement (officers' claim) is more effective on cold-engaged sites.

---

### 6. Script Header and Summary

**Before:** Generic outcome-focused tree analysis description

**After:** Explicit Item 7 Row 4 validation checklist:
```
Item 7 Row 4: "Emissions reduced = Yes" requires:
  ✓ NRMM in scope (checked)
  ✓ Initial emissions non-compliant (checked)
  ? Enforcement requested: "Remove or replace" (discovered via exploration)
  ? Site mgmt action: "Removed/replaced" (discovered via exploration)
  ✓ Outcome: "Driven compliant" (stage >= threshold OR removed)
```

Final summary now prompts:
- "Review enforcement pathways above to verify Item 7 Row 4 compliance"
- "Check whether Final Site Reasons and Final Machinery Compliance match Item 7 expectations"

---

## Validation Checklist

When you run this script, verify:

1. **NRMM filtering works:** "No NRMM" count should be > 0; only in-scope records in analysis set
2. **Pathways detected:** Both `emissions_improved_by_upgrade` and `emissions_improved_by_removal` should have counts ≥ 0
3. **Enforcement fields populate:** Final Site Reasons and Final Machinery Compliance tables should show unique values
4. **Removal pathway exists:** If `emissions_improved_by_removal > 0`, Final Machinery Compliance table should include "Removed" entries
5. **Cold > Warm hypothesis:** Check if cold-engaged improvement rate > warm-engaged rate

---

## Usage

```bash
Rscript tree_analysis_rol_outcome_focused.R
```

Review output against Item 7 Row 4 requirements. The script now provides the raw field values for human interpretation, allowing you to determine if the enforcement pathway encoding matches schema.md expectations.
