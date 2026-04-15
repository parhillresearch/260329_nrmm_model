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
- **Table layout convention (all steps):** phases or time periods form a super-header across columns, with stages (I, II, IIIA, …) or other sub-metrics as sub-columns beneath each phase header. Rows follow a fixed two-level index: outer = group in order {Constant_Speed, CAZ_Plus, Rest_of_London, Variable_Speed}; inner = any further breakdown (cold/warm, compliance route, etc.). Variable_Speed rows appear in every table; cells are left blank (`—`) for phases where that group has no data. Tables in the output `.md` file must render with visible phase super-headers spanning their sub-columns (output is viewed in Typora and Positron, both of which render inline HTML).
- Plots: ggsave() to outputs/, 180dpi, 16x10cm unless specified; immediately after each ggsave() call write a markdown image line to the output .md file: `![<caption>](<filename.png>)` so the plot renders inline
- Each script ends with a sessionInfo() call

**Step Report (written by Claude, not the R script)**

When a trial is accepted, Claude appends a `## Step Report` section to the step's output .md file. Claude reads the output tables and console output before writing it. Structure:

```
## Step Report

### Intended tasks
<bullet list of draft_plan.md sub-tasks for this step>

### Results by sub-task
<for each sub-task: interpretive prose — what was found, key numbers, patterns,
anomalies — followed immediately by the relevant tables and plot images embedded inline.
Every table and every plot image must be followed by exactly two lines of plain-English
explanatory text describing what the reader is looking at and what the key takeaway is.>
```

## Strict Instructions

- Ask MCQ clarifying questions only when schema.md and draft_plan.md do not resolve the ambiguity.
- No explanatory prose outside function documentation.