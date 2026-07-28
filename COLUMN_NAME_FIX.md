> **SUPERSEDED — historical record only, not current.**
> Superseded by: outputs/260728_data_dictionary.md (field-level issues now catalogued there).
> Retained for provenance. Do not cite; figures and definitions here may
> predate the data-quality corrections of July 2026.

# Column Name Fixes — tree_analysis_rol_outcome_focused.R

## Error Encountered

```
Error in `filter()`:
ℹ In argument: `Engine_Type == ENGINE_TYPE`.
Caused by error:
! object 'Engine_Type' not found
```

## Root Cause

Script used `Engine_Type` (underscore) but the actual column in `audits.txt` is `Engine Type` (space).

Per **schema.md Item 5**, column names in `audits.txt` are:
- `Engine Type` (space, not underscore)
- `Cold-Engaged` (hyphen, not underscore)
- `Initial Emissions Stage` (spaces)
- `Final Emissions Stage` (spaces)
- `Initial Machinery Compliance` (spaces)
- `Final Machinery Compliance` (spaces)
- `Initial Site Compliance` (spaces)
- `Final Site Compliance` (spaces)
- `Initial Site Reasons` (spaces)
- `Final Site Reasons` (spaces)
- `Initial Retrofit or Exemption` (spaces)
- `Final Retrofit or Exemption` (spaces)
- `Machine Type` (space)

## Fixes Applied

### 1. Backtick Quoting (Lines 40)
Changed:
```r
filter(Zone == ZONE, Engine_Type == ENGINE_TYPE)
```

To:
```r
filter(Zone == ZONE, `Engine Type` == ENGINE_TYPE)
```

Backticks allow R to treat column names with spaces/hyphens as valid identifiers.

### 2. Parsing Diagnostics (Lines 38-44)
Added code to detect and report parsing issues in audits.txt:
```r
if (nrow(problems(audits)) > 0) {
  cat("WARNING: Parsing issues detected in audits.txt:\n")
  print(problems(audits))
}
```

**Why:** The parsing warning suggests data quality issues that might prevent columns from loading correctly.

### 3. Column Name Validation (Lines 46-58)
Added explicit check for all essential columns:
```r
essential_cols <- c(
  "Zone", "Engine Type", "Date", "Cold-Engaged", "Machine Type",
  "Initial Emissions Stage", "Final Emissions Stage", ...
)

missing_cols <- setdiff(essential_cols, names(audits))
if (length(missing_cols) > 0) {
  stop("ERROR: Missing required columns in audits.txt:\n  ",
       paste(missing_cols, collapse=", "))
}
```

**Why:** Catches column name mismatches early with clear error messages.

### 4. Column Names Throughout Script
All column references use proper names with correct spacing/hyphenation:
- Dollar sign (`$`) access uses backticks for names with spaces: `audits$`Engine Type``
- Double-bracket (`[[`) access uses string values (which can contain spaces): `audits[["Engine Type"]]`
- Feature vector contains bare strings: `"Engine Type"` (used with `[[` access)

## If You Still Get Errors

When you run the script, you'll see:
1. **Parsing issues table** — shows which lines have problems
2. **Actual column names** — prints full list of columns in audits.txt
3. **Column validation** — reports missing columns if any

If any columns are missing or named differently, it will halt with a clear message showing which columns are missing. This tells you exactly what column names exist in your data file.

### Troubleshooting Steps

1. Check the parsing issues table — fix data if needed
2. Look at the printed column names — compare to schema.md Item 5
3. If names differ from schema (e.g., `Engine_Type` instead of `Engine Type`):
   - Update the `essential_cols` vector in the script with actual names
   - Update filter lines and feature vector to match actual names

## Parsing Warnings

The initial warning "One or more parsing issues" suggests:
- Some rows may have misaligned fields (wrong number of columns)
- Some cells may have embedded tabs or quotes
- Data type conversion failures

Run `problems(audits)` to see details. You may need to:
- Check the input file for malformed rows
- Verify tab-delimited format is correct
- Look for embedded special characters

The script will still proceed (parsing issues don't halt execution), but data may be incomplete in affected rows.
