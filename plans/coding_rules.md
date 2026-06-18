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