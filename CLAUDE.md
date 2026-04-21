# Non-Road Mobile Machinery (NRMM) Low Emissions Zone (LEZ) Trend Analysis for policy evaluation and forecasting

## Project Objective

Evaluate the NRMM LEZ policy by analysing audit data that records the emissions Stage of 16,251 individual machines (2016-2026), whether each was emissions compliant and what enforcement outcomes were achieved. Statistics, trends and projections must be determined for 3 machine categories and multiple time sub-segments, so a well-evidence counterfactual be developed, and the effect of the policy on the rate of equipment replacement for each phase and each machinery group are characterised. Overall emissions reductions and a projection of the policy effects to 2030.

## Environment

- R version: 4.3.1
- Core packages: tidyverse, broom, emmeans, ggplot2, nlme, boot, kableExtra
- No data.table. Use set.seed(42) in any stochastic step.
- Script naming convention: YYMMDD_stepN_description_vM.R where M is the trial number (e.g. 260401_step5_forecast_v1.R for Trial 1, 260401_step5_forecast_v2.R for Trial 2). The date is the date the first version was written; it does not change on subsequent trials.
- Outputs saved to outputs/ with matching filename stem; the stem increments with M so each trial's outputs are preserved alongside its script.

## Key files

@schema.md @draft_plan.md @decisions.md @sprint_log.md

## Workflow

**Script authoring (by Claude)**

- Claude writes and saves R scripts based on schema.md draft_plan.md decisions.md and user prompts. Claude does not execute them.
- Every script must save all output objects to `intermediate/` as .rds files and append entries to `intermediate/manifest.md` (columns: `object`, `file`, `class`, `dim`, `step`, `description`). The manifest is cumulative: each script reads the existing manifest, appends its rows, and writes it back. Step 1 creates the file.
- Scripts must print a summary of saved objects to console on completion (object name, class, dimensions) so the user sees what was produced.

**Trial Loop (runtime by user)**

- The user examines the new script, runs a trial of each script in their own R session, inspects the results.
- Reports back to Claude on whether outputs are accepted and the step is complete, or whether adjustments are needed.
- If adjustments are needed, Claude writes a new script at the next version number (e.g. _v2.R), does not overwrite the previous version, amends relevant documents (draft_plan.md, schema.md, decisions.md) based on user instructions, updates sprint_log.md, and a new trial is run. Previous script versions are retained as an audit trail.
- **Trigger phrase: "step complete"** (or close equivalent such as "done", "accepted", "finish the step"). On receiving this, Claude must: (1) read the step's output .md file and the console output the user has pasted, (2) append the `## Step Report` section to the output .md file, (3) mark the trial complete in sprint_log.md.

## Coding conventions

- Use snake case for all object and feature names, e.g. where feature is named `admin compliant` then `admin_compliant`
- Write modular functions rather than repeated blocks or long procedural scripts; document arguments inline; save intermediate states in .rds files
- Use most modern Tidyverse functions available and aim for user readable R code
- All WLS fits via lm() with weights argument; extract SE from vcov()
- Transition matrices must be right-stochastic: rows sum to 1; enforce after every matrix operation
- Use exact fractional years for all temporal midpoints (see schema.md for phase boundaries)
- Never hardcode column names; derive from schema constants defined at script top

## Output conventions

- Intermediate objects: saveRDS() to intermediate/, with manifest update (see Workflow)
- Summary tables: knitr::kable() to console and to a single file `outputs/YYMMDD_stepN_description_vM.md` matching the script filename stem; all tables for the step written to that one file, overwriting on each run
- **Table layout convention (Steps 3–5):** For any table with a **group × phase** structure, output **one kable per group** in the fixed order {Constant_Speed, CAZ_Plus, Rest_of_London, Variable_Speed}. Each group's table has phases (A1, A2, B1/B2/B3 when Phase B is sub-segmented, C) as **columns** and statistics or parameters (counts, percentages, estimates, SEs, etc.) as **rows**; add a "Phase" super-header spanning all phase columns via `add_header_above`. Phase columns for which that group has no data show `—` throughout every row. For tables with a **group-only** dimension (no phase breakdown, e.g. λ_CF, λ_Proactive), use a single table with groups as rows and statistics as columns. All tables output as inline HTML (`kableExtra`, `format = "html"`); output is viewed in Typora and Positron.
- **Plots:** At every opportunity where data has a group × phase or group × time structure, produce an illustrative plot alongside the tables. Use stacked bar charts for count/composition breakdowns, grouped bars or lines for rate/estimate comparisons. Prefer one faceted figure per section (`facet_wrap(~group, nrow = 2)`) over multiple separate figures. Every table and every plot image must be followed by exactly two lines of plain-English explanatory text. Save with `ggsave()` to `outputs/`, 180 dpi, 16×12 cm for faceted plots or 16×10 cm for single-panel unless otherwise specified; immediately after each `ggsave()` call write a markdown image line `![<caption>](<relative_filename.png>)` to the output `.md` file so the plot renders inline.
- Each script ends with a sessionInfo() call

**Step Report (written by Claude, not the R script)**

When a trial is accepted, Claude appends a `## Step Report` section to the step's output .md file. Claude reads the output tables and console output before writing it. Structure:

```
## Step Report

### Intended tasks
<bullet list of draft_plan.md sub-tasks for this step>

### Results by sub-task
<for each sub-task: interpretive prose — what was found, key numbers, patterns,
anomalies — followed immediately by the relevant tables and plot images embedded inline
(each followed by exactly two lines of plain-English explanatory text per Output conventions).>
```

## Strict Instructions

- Ask MCQ clarifying questions only when schema.md and draft_plan.md do not resolve the ambiguity.
- No explanatory prose outside function documentation.