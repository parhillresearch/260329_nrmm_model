# Internal memo: audit data capture issues and their analytical impact

**26 July 2026 | For the analysis file. Companion to `260726_audit_data_queries.md` (auditor-facing).**

Following the generator classification problem, I swept the other fields for the same failure signature: a categorical field whose recorded value correlates with emissions stage or with time, such that machines change category as they improve. Findings below, ordered by impact on published figures. **No model or report changes have been made**; the model remains `nrmm_model_v4.R` as committed.

---

## 1. Engine Type on generators — CONFIRMED, invalidates a headline finding

**Observation.** All 218 Stage V generators are recorded "Variable" or "Unidentified"; none "Constant". Stage IIIA generators audited in the same years are 80% "Constant".

**Mechanism.** The Constant Speed Machine Group is defined by `Engine Type`. Generators leave the group exactly when they upgrade, so the group retains only the un-upgraded residue and cannot improve by construction. Survivorship artefact.

**Impact.** Reassigning generators by machine type:

| Quantity | As recorded | Reassigned |
|---|---|---|
| Constant Speed group size | 778 | 1,371 |
| Mean stage 2021 → 2024 | 2.97 → 2.93 | 2.96 → 4.57 |
| Stage V share of group, 2024 | 0% | 53% |
| Replacement rate, era 2 | −0.002 (se 0.004) | 0.107 (se 0.083) |
| Compliance, phase B / C | 0.0% / 0.0% | 17.0% / 46.2% |
| Emissions intensity, phase B | 4.12 g/kWh | 3.66 g/kWh |

**Caveat against a blanket fix.** Hybrid, flywheel and flybrid generators split 37 "Constant" to 51 "Variable", which looks like a real distinction, so "all generators are constant speed" is not safe either. Awaiting auditor guidance.

**Contamination of other groups.** CAZ+ phase B intensity 1.77 → 1.72 and compliance 74.4% → 75.5%; Rest of London 2.16 → 2.13 and 93.2% → 94.7%. Both groups are currently flattered by borrowed Stage V generators.

**Robust to the issue.** Variable-speed replacement rate (0.2312 → 0.2341), the era-2 null difference between arms, the arrival-composition finding (pooled gap 12.4% → 13.4%, slightly larger when corrected), and all enforcement-channel results.

## 2. Engine Type on crushers — same signature, small magnitude

Of 129 crusher records, 15 are "Constant" and all 15 are Stage IIIA; all 76 crushers at IIIB, IV and V are "Variable". Median engine size is similar either way (218 vs 202 kW), and "Constant" appears in ones and twos across years rather than in a block.

Those 15 records are about 2% of the Constant Speed group, and being all Stage IIIA they contribute marginally to the group appearing stuck. Impact is small in isolation but the pattern is the same, so both should be resolved by the same guidance.

## 3. TAN capture starts in 2021 — biases the removal-displacement figure

**Observation.** Usable TAN by year: 0% for 2016-2020, 41% (2021), 85-90% (2022-24), 77% (2025).

**Impact on the reported displacement rate.** All 345 removals in 2016-2020 are untraceable by construction; the 531 traceable removals are all 2021 or later. The "untraceable" bucket in the outcome taxonomy is therefore a **time artefact, not random missingness**, which the report does not currently say.

**Right-censoring on top.** Displacement rate falls monotonically with the remaining observation window:

| Year of removal | Traceable | Reappeared | Rate | Observation window |
|---|---|---|---|---|
| 2021 | 63 | 39 | 62% | 4.2 yrs |
| 2022 | 137 | 83 | 61% | 3.6 yrs |
| 2023 | 134 | 79 | 59% | 2.6 yrs |
| 2024 | 81 | 45 | 56% | 1.6 yrs |
| 2025 | 115 | 52 | 45% | 0.6 yrs |

The headline 55.9% is a blend across these windows and is therefore a **lower bound**: machines removed recently have had little opportunity to be re-audited. A machine with a full window shows roughly 62%. This strengthens rather than weakens the report's argument that removal often displaces rather than eliminates, but the report should state the measurable window and the censoring.

## 4. Machine Type free text — minor processing defect on our side

`Machine Type` is free text with near-duplicates. Our `TYPE_CANONICAL` map only handles "Piling rig" → "Piling Rig". Consequently **"Mewp" (13 records) is bucketed into "Other"** rather than MEWP (359), and "Drilling rig" likewise. Effect on the emissions-intensity strata is negligible at this scale but it is a straightforward defect to fix.

"Inappropriate for Audit" (131 records across two capitalisations) is not excluded, unlike "No NRMM" (891). None of the 131 carries a usable emissions stage, so they cannot affect stage-based results; whether they should be excluded from outcome counts is a question for the auditors.

## 5. Not pursued (per direction)

- **Zone unusable in all 2025 records.** Confirmed expected: these are the post-2024 "P24" Machine Group in the schema, which the model does not implement, so the 2025 variable-speed cohort is dropped and phase C holds 63 machines. Already carried as open decision 3 in `notes.md`; not a capture defect.
- **kW Power missing 11-39% by year**, currently imputed from machine-type medians.

## 6. Why the checks did not catch these

The verification block tests internal consistency (levels summing, distributions normalising, projections conserving probability) and would pass all of these. It does not test for *structural implausibility*: a group with exactly 0% compliance across two phases, a fitted rate of exactly zero, or a category with no members above a given stage are all signals that a definition rather than the world is doing the work. The superseded `tree_dashboard_v3-v5.R` did carry such a guard for the generator case and it was dropped at unification.

**Recommended once guidance arrives:** restore a structural-implausibility class of check, add the classification choice back as an explicit documented sensitivity rather than a hard-coded rule, state the TAN observation window in the report, and fix the `TYPE_CANONICAL` map.

---

## 7. Addendum (26 July): further issues on the four priority axes

Reframed against the axes that matter for this audit — wrong **year**, wrong **stage**, wrong **starting/ending situation**, wrong **zone/group**:

- **Year: clean.** All 16,251 dates parse, range 2016-06-17 to 2026-01-21, no day/month transposition (40% of dates fall on day ≤ 12 against ~39% expected), plausible seasonal profile. No action.
- **Stage: two new issues.** `"Electric"` (31 records: Battery Packs, forklifts, pumps, MEWPs) drops to NA instead of stage 7, and is growing fast (1 in 2022 to 15 in 2025) — **the same failure mode as the generators, where machines exit the measured population by improving**. Plus 7% of repeat-audited machines appear at more than one stage, five of them differing by 3-4 stages.
- **Situation: one gap.** Capitalisation variants and "Removed and Replaced - V/IIIB/IV" are already handled correctly by the lower-casing. `"Pending"` (23 records, 2018-2020) is conflated with "not remediated".
- **Zone/group: unchanged**, generators and crushers remain the largest issue.

**Reprioritisation.** The machine-type free-text defect drops down the list: it touches only emissions-intensity weighting, none of the four axes. The TAN finding is reclassified — it is not a misclassification but an observability limit on the ending situation for removed machines.

## 8. Is it safe to share outline statistics with the auditors?

Yes, with selection, and doing so is actively useful: the generator error was caught precisely because a reader recognised that Stage V generators exist. Auditors are the best available check on whether a figure matches the reality they see on site.

**Safe to share now:**

- Audit volumes by year, and the registered/unregistered split (9,622 / 2,021). The year axis is clean and the engagement field is not implicated.
- The arrival-composition finding: registered fleets arrive cleaner (compliance 89.3% against 80.8%). Tested against the generator correction and it moves in the safe direction (intensity gap 12.4% to 13.4%).
- Variable-speed replacement roughly doubling after September 2020 (0.10-0.12 to about 0.23 a year). Robust to the generator correction (0.2312 to 0.2341).
- The enforcement-outcome counts (108 confirmed reductions, 362 exemptions, 640 registration-only), which do not depend on group assignment.

**Share only with the caveat attached:**

- Removal displacement (55.9%): state that it is measurable only on 2021-onward removals and is a lower bound because recent removals have had little time to reappear.
- Fleet emissions intensity by group (CAZ+ 1.77, Rest of London 2.16): both shift slightly under the generator correction and rest on placeholder emission factors and usage hours.

**Do not share yet:**

- Anything about the Constant Speed group or generators: compliance, replacement rate, emissions intensity, or the 2030 projection. All are artefacts of the classification question until it is answered.
- Crusher-level figures, for the same reason.
- Anything for phase C / 2025 onward, where the P24 group is unimplemented and only 63 machines survive.

**Framing.** Present shared figures as provisional and invite correction explicitly. The purpose of sharing is to recruit the auditors' domain knowledge as a validation layer, not to publish conclusions — and the report itself should not circulate until the generator and Electric questions are resolved, since it currently states a generator conclusion that is probably backwards.
