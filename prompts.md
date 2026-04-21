- Execute first trial of draft_plan.md Step 2. Using audits.rds as main input. Stop after sub-task 4, report and await user feedback before proceeding.

- 

- Execute first trial of draft_plan.md Step 3. Use output from Step 2 as main input. Stop after sub-task 4, report and await user feedback before proceeding.

- "Step 3 Trial 2. Script: 260415_step3_parameter_estimation_v2.R. Run it, paste console output, report results and await feedback."

## Tips for step 3 trial 2

1\. State the trial: "Step 3 Trial 2. Script: 260415_step3_parameter_estimation_v2.R."

2\. Tell it to read sprint_log.md first — confirms it picks up current state rather than inferring from CLAUDE.md alone

3\. Paste console output in full — don't summarise; Claude needs raw numbers to cross-check against locked references

4\. If lambda_Policy is still NA for some groups, say so explicitly rather than letting Claude treat it as an anomaly — it's an expected known constraint

5\. Use the trigger phrase "step complete" only when all 4 sub-tasks are accepted, not after lambda_CF alone looks good

6\. If a new error is found, ask for a diagnosis before asking for v3 — avoids writing a fix for the wrong root cause

7\. Commit after documents are amended and v3 is written, before running Trial 3 — same cadence as this session