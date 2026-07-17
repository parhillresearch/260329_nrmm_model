## Coding rules

- Files: `YYMMDD_stepN_description_vM.R` date is todays, step number N defined by user, trial M derived from sprint_log.md.
- Snake case; descriptive names: `audit_table` not `df`, `audits_filtered` not `filt`
- In pipes `%>%`/`|>` keep to one logical operation per step; group mutate columns by purpose with inline comments to name group
- Named constants for all thresholds first use: `PHASE_B_START <- as.Date("2020-09-01")`
- Logical blocks separated by `# --- Derive compliance flags ---`
- Accepted short-form terms (zone codes and domain identifiers): `lez`, `caz`, `oa`, `gl`, `p24`, `tan`; spell all other terms out in full
- Functions only if logic repeats more than twice; arguments on separate lines beyond 80 chars
- Use current Tidyverse; save step output objects as `.rds`

### Script structure (implemented by Claude in every script)

1.  Load dependencies / set seed
2.  Load input data (intermediate_data/ .rds or raw audits.txt at Step 1)
3.  Analysis / transformation
4.  Verification block
    1.  Structural checks → halt with informative error if fail
    2.  Referential integrity → halt with informative error if fail
    3.  Distribution fingerprints → warn to console, continue
    4.  Analytical/domain checks → warn to console, continue
5.  Save outputs to intermediate_data/ as .rds
6.  Print completion summary (object name, class, dimensions)
7.  Append rows to intermediate_data/manifest.md

#### Object Manifest

The last step of every script appends rows to `intermediate_data/manifest.md` to describe objects created (columns: `step`, `object`, `file`, `class`, `dimensions`, `description`). Create the file in step 1, each subsequent script appends its rows to the existing file. `description` should be one sentence stating object content and filtering or transformation that produced it.

### Step Report (written by Claude, appended to the step's output `.md`)

Claude reads the step output tables and all console output before writing. Structure:

```         
## Step Report

### Intended tasks
<bullet list of plan document sub-tasks for this step>

### Results by sub-task
<for each sub-task: interpretive prose — what was found, key numbers,
patterns, anomalies — followed by relevant tables and plot images
embedded inline, each with exactly two lines of plain-English explanatory text>
```
## Verification criteria for analysis scripts (moved from notes.md, 260717)

Three categories: structural (halt on failure), analytical (domain sanity, warn), output (artefact usability, warn). Two checks from the original list were deleted in the move as inconsistent with audited findings: "COVID-period records absent from Phase B" (exclusion is an open decision, notes.md) and "Final Emissions Stage >= Initial Emissions Stage within an audit" (stage fields are static within audits, so the check tests nothing).

**Structural checks** (include in every ingestion script; halt on failure)

- Row count after filtering matches expectation: in-scope records substantially fewer than 16,251 (P24 and BCP excluded, `No NRMM` excluded). Flag if >16,000 survive filtering.
- No duplicate TANs within a single audit date.
- Zone values contain only {"CAZ", "OA", "GL"} after filtering.
- Date range falls within 2016-2030.
- Compliance determinations boolean with no NAs where a determination was possible.
- Total in-scope record count saved at ingestion and compared at the start of every subsequent script; any deviation halts with an explicit error.
- Phase record counts summed across A1, A2, B, C equal the total in-scope count.
- Transition matrices right-stochastic: rows sum to 1; enforce after every matrix operation.

**Analytical checks** (warn to console, continue)

- Compliance rate rises after 1.9.2020 and after 1.1.2025.
- Constant speed group shows no IIIB records (policy skips IIIB; any present signals a coding error).
- Mean encoded stage increases across phases A1 -> A2 -> B.
- CAZ+ shows higher compliance than Rest of London within the same phase (tighter threshold); the reverse is a red flag.
- Emissions stage frequency table and zone x equipment group cross-tabulation saved as reference fingerprints at ingestion; later scripts recompute on retained records and flag unexpected shifts.

**Output checks** (warn to console, continue)

- Each saved `.rds` loads in a fresh session and matches the dimensions printed on completion.
- Time series plots span the correct phase range with vertical lines at phase boundaries (1.9.2020, 1.1.2025).
- Compliance-rate plots bounded 0-1; values outside indicate a wrong denominator.
- Summary tables contain no all-NA columns and no infinite values.
- No plot saved with fewer than 30 data points in any displayed group; sparse groups flagged, not silently plotted.
- Manifest entry appended (not overwritten); row count in `manifest.md` increments after each step.

## Analysis coding conventions (moved from notes.md, 260717)

- All WLS fits via lm() with weights argument; extract SE from vcov()
- Transition matrices must be right-stochastic: rows sum to 1; enforce after every matrix operation
- Use exact fractional years for all temporal midpoints (see schema.md for phase boundaries)
- Never hardcode column names; derive from schema constants defined at script top
