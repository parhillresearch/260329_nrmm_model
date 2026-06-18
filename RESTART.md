# Restart Instructions for 2026-06-17

**Context:** You audited Steps 1–6 of the LEZ analysis on 2026-06-16 and identified overengineering + data interpretation issues. A new exploratory approach for Rest of London has been drafted.

---

## Read first (10 min)

**In this order:**

1. `AUDIT_STATE_OF_PLAY.md` — Executive Summary section only
   - What was audited and why
   - Core finding: model logic sound, but Step 1 fragile and Step 6 had iteration overhead
   - Three options presented (reuse, simplify, restart)

2. `notes.md` (now in reverse chronological order — start at top)
   - Read the 2026-06-16 entry
   - Understand: why tree analysis matters (data field values inconsistent; can't hard-code assumptions)
   - See: what outcome-focused approach was built

---

## Execute (20–30 min)

Run the exploratory tree analysis for Rest of London:

```bash
cd /Users/iarla/Coding/260329_nrmm_model
Rscript tree_analysis_rol_outcome_focused.R
```

**What to expect:**
- Data quality report (missing stages, suspect records)
- Unique values in key fields **when emissions improve**
- Improvement rates per feature combination
- MI rankings (most predictive features)

---

## Interpret the output

**Key questions the script answers:**

1. **What does enforcement look like in the raw data?**
   - When emissions improve, what values appear in Final_Site_Reasons, Final_Retrofit_or_Exemption, etc.?
   - Are "Removed", "Replaced" explicitly encoded, or implied?

2. **Does the data support the officer claim?**
   - Among improved records: what % involve Cold_Engaged=TRUE?
   - Does cold-engaged show higher improvement rates than warm-engaged?

3. **What feature combinations predict emissions improvement?**
   - Sort output by improvement_rate DESC
   - Top rows show high-signal pathways

---

## Then decide (5 min)

Based on tree output, choose a path forward:

| If tree shows... | Then... |
|-----------------|---------|
| Clear enforcement signal in raw data + cold > warm improvement rates | **Option 2:** Simplify & rebuild Step 1 with clearer compliance logic |
| Enforcement signal is weak/missing (like the ~1% naive finding) | **Option 2:** Rebuild to disaggregate enforcement from other compliance drivers; test by zone separately |
| Data quality too messy; field values contradict each other | **Option 3:** Restart from scratch with zone-by-zone approach; validate data first |
| Enforcement is actually much higher than ~1% (officers correct) | **Option 1:** Reuse current pipeline; data interpretation was the blocker, not the model |

---

## Document findings

After running the script and interpreting output:
- Add brief entry to `notes.md` with key findings
- If proceeding with Option 2 or 3, update this file with next steps

---

**Notes on `notes.md`:** Now organized newest-first (reverse chronological). Most recent work is at top; reference sections at bottom.
