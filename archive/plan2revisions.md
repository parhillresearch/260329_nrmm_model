# Plan Revisions: Machine-Level TAN and Revisit Tracking

## SCHEMA.MD

- Add `Audit #` to COLS_KEEP (Table 4); currently absent from ingestion scripts.
- Define `visit_number` derivation: TAN + Date ascending, integer sequence per machine.
- Add `is_first_visit` boolean: TRUE for each machine's earliest audit record by Date.
- Add `machine_panel` object: one row per TAN, first/last stage, n_visits, intervention_flag.
- Clarify: Initial/Final fields capture within-visit change; between-visit requires TAN linkage.

## DRAFT_PLAN.MD — STEP 1

- Sub-task 1: add `Audit #` to retained columns; encode as integer visit sequence per site.
- Sub-task 3: derive `visit_number`, `is_first_visit`, `is_revisit` per TAN after group/phase assignment.
- Sub-task 3: save `machine_panel.rds` — one row per TAN, stage trajectory, n_visits, intervention_flag.
- Sub-task 4: report n_unique_machines, n_revisited, mean_visits_per_machine alongside group × phase counts.
- Sub-task 4: flag groups where revisit rate >20% — double-counting risk for lambda estimation.
- Sub-task 5: add revisit frequency distribution plot by group and phase.
- Sub-task 6 checksum: add machine-level check — unique TAN count × mean visits ≈ n_retained.

## DRAFT_PLAN.MD — STEP 2

- Add sub-task: characterise between-visit stage changes for re-audited machines by group and phase.
- Add sub-task: quantify within-visit stage changes (Initial→Final) as direct audit intervention effect.
- Add plot: stage progression for revisited vs. single-visit machines by group.

## DRAFT_PLAN.MD — STEP 3

- Add sensitivity check: re-estimate lambda_CF from first-visit records only; compare to full-records estimate.
- Note: if revisit rate >20%, first-visit-only is the preferred lambda_CF estimate (suppress double-counting).
- Add sub-task: tabulate observed TAN-linked stage transitions for empirical baseline comparison.

## DRAFT_PLAN.MD — STEP 4

- Add validation: compare lambda-derived transition matrix probabilities to empirical TAN-linked transition counts.
- Consider: supplement P_Natural rows with empirical first-to-second-visit transitions where sample size permits.

## DRAFT_PLAN.MD — STEP 5

- Phase C initialisation: use last-known stage per unique TAN, not all audit records.
- Add: report n_unique_machines at Phase C init; confirm no TAN is counted twice.

## DECISIONS.MD

- Add decision: unit of analysis is audit record; first-visit-only is the sensitivity check.
- Add decision: `Audit #` retained and `visit_number` derived to enable revisit identification.
- Add decision: within-visit intervention captured by Initial→Final stage delta, tracked separately from lambda.
