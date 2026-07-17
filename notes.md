## 260619 Closer breakdowns of the different pathways

- Issue found: `engine type` was not set before 2019, affecting 147 of 1,525 Generator rows (9.6%). So if these are excluded due to `engine type` being unset, we miss 10% of the generators. This is important for the constant speed zone analsyes.

- Possible solutions for pre-2019 generators `machine type` :

  - assign `engine type` based on `zone` where it is set? No, zone for them is not set pre-2019;

  - assign `engine type` based on compliance? No, only 27 can unambiguously be assigned based on compliance

  - **Pre-2019 generator Engine Type inference test** whether Stage + Compliance + Zone can infer Constant vs Variable (Constant Speed group threshold = IIIA at era 1; CAZ+ = IIIB; Rest of London = IIIA — same as Constant Speed).

    | Stage | Compliance | Zone | Count | Inference |
    |----------|----------|----------|----------|--------------------------------|
    | IIIA | Compliant | CAZ | 27 | **Constant Speed** (unambiguous — a Variable generator in CAZ+ needed IIIB to pass; IIIA-only pass rules that out) |
    | IIIA | Compliant | GL | 47 | Ambiguous — Rest of London also has an IIIA threshold at era 1, so this is consistent with either Constant Speed or genuine Variable/RoL |
    | IIIA | Non-compliant | any | 7 | Unresolved |
    | II | Non-compliant | any | 23 | Unresolved (below universal IIIA floor in every zone/group) |
    | II | Removed from site | any | 2 | Unresolved |
    | Unidentified | Non-compliant | any | 38 | Unresolved (no stage data) |
    | Unidentified | Removed from site | any | 3 | Unresolved |
    | **Total** |  |  | **147** | **27 resolved (18.4%), 120 unresolved (81.6%)** |

    Stage IIIB contributed nothing — zero pre-2019 unset-Engine-Type generators were ever recorded at IIIB. Conclusion: stage/compliance/zone inference only cleanly resolves the CAZ-zoned IIIA-compliant subset (27 records); the bulk (120) cannot be disambiguated this way.

- ** Conclusion on definitions of `engine type` and `machine type` **

  - Since engine type was unset pre-2019, we must exclude pre-2019 generators from the analysis.

  - Therefore `Machine groups` need to be defined by the following rules:

    - if `machine type` == `generator` and `date` < 2019, then `Machine Group` <- "p19" and exclude from analysis; 
    - else if `zone` = BCP (Beyond Construction Project), then `Machine Group` <- "BCP" (not used in this analysis); 
    - else if audit date after 31.12.2024, then `Machine Group` <- "P24" (post 2024);
    - else if engine type is Constant Speed then `Machine Group` <- "Constant Speed", (is used in this analysis;
    - else if `zone` == `CAZ` or `OA`  `Machine Group` <- "CAZ+";
    - else Assign "GL" for Rest of London or Greater London. Propose optioms to (1) test if there are enough generators in the pre-2019 audits to justify further work, or can we just exclude them? (2) if we need them, infer engine type if a generator was audited pre 2019 for example based on compliance at Euro engine stage IIIa.

  - Stats

    - 147 of 1,525 Generator rows (9.6%) have unset Engine Type, all pre-2019. Among Generators with a valid Engine Type: Stage IIIA splits 80% Constant / 20% Variable (648/165); Stage II splits 84%/16% (68/13); Stage V is 100% Variable (171/171, zero Constant). Of the 147 unset rows: 81 are Stage IIIA, 25 are Stage II, 41 have no stage at all ("Unidentified") — none are Stage V.

- 

## 260618 Tree analysis using the tree_analysis_rol_outcome_focused.R

Auditing the previous work all over again so we can restart the analyis.

- Script `tree_analysis_rol_outcome_focused.R`\` drafted to focus on what audit flags are linked to actual emissions reductions. This is actually an experiment to see if these are actual emissions reduction.

- **To check before proceeding**

  - [ ] Data still needs cleansing as engine_type is not properly populated for pre 2019 data. Test which features have the data for those rows. This was resolved in Iteration 9 of the data ingestion stage.

  - [ ] What flag combinations in the audits are linked to actual emissions reductions

  - [ ] Can the emissions reductions from enforcement (eg cold-engaged or not-self-compliant) vs self-compliant be distinguished.

  - [ ] What EXACT flags indicate self-compliant, never compliant, warm engaged but not self compliant AND led to an emissions reduction, warm engaged but not self compliant that did not lead to an emissions reduction. IS the Item 8 in the Schema the complete description?

  - [ ] What are the correct transition matrices to be used for each data subset, considering the actual propulations (e.g. cases where some numbers are such a small proportion compared to the others that they can be left out of the transition matrix). Are there enough data to calculated the transition matrix values with high certainty. What rules are required for each subset?

  - [ ] What is the best temporal breakdown of each subgroup of the data in each phase of the LEZ?

- **Actions taken today**

  1.  Dashboard code: Built `tree_dashboard.R` — Shiny + visNetwork interactive companion to `tree_analysis_rol_outcome_focused.R`. Group/year selectors drive a reactive Item 7 compliance tree and enforcement pathway tables. Fixed two bugs: visNetwork font spec (needed double `list()`), and `as.Date()` missing `format=` (misread DD/MM/YYYY, year showed as 1–31). Pushed to branch `add-item7-compliance-dashboard`.

  2.  Data cleanse steps available: v9 ingestion script (`260521_step1_ingestion_v9.R`) already implements modal engine_type imputation per machine_type, excluding Generators (near 50/50 split, no reliable mode). Porting this into the dashboard would recover \~1,150 of the 1,404 pre-2019 blank-Engine-Type records.

  3.  Other findings: Pre-2019 records (2016–2018) vanish from the dashboard's year dropdown because blank Engine Type fails the Constant/Variable filter *before* date derivation runs — not a date bug. 1,399 of 1,404 pre-2019 rows have blank Engine Type; only 5 don't.

## 2026-06-16 — Audit and exploratory tree analysis

Audited Steps 1–6 for overengineering. Created `AUDIT_STATE_OF_PLAY.md`: core model logic (Steps 3–5) is sound; Step 1 had fragile compliance-parsing bugs; Step 6 had multi-trial formatting churn. Reviewed existing `tree_analysis.R` and `tree_analysis_2.R`: they perform undirected dependency discovery (Chow-Liu tree) but don't target emissions improvement outcomes.

**Key insight:** Raw audit field values are inconsistent; cannot hard-code regex patterns for "enforcement" or "removal". Instead, built outcome-focused exploratory script (`tree_analysis_rol_outcome_focused.R`) for Rest of London: defines outcome (emissions_improved = initial stage \< threshold AND final stage \>= threshold), computes MI rooted at outcome, and discovers which feature combinations predict improvement **without assuming field values**. Prints observed values and improvement rates per combination. Next: run script, examine which feature combinations show high improvement rates, then infer what those fields actually encode as enforcement/removal/retrofit.

------------------------------------------------------------------------

## End of project checklist

\[ \] Add back in the removed from site machinery which were excluded due to engine_type being unidentified.

------------------------------------------------------------------------

## 250526

- Lets review the logic of delivering improvements during operation and delivering improvements in machinery

- **Emissions reductions in operation occurs when**

  - For Warm Engaged or Cold-engaged
    - A machine that is not compliant for Emissions reasons is
      - replaced with a compliant machine
      - removed from the site

- **How is this encoded in the audit data?**

  - Either by
    - Initial Machinery == {"Removed from Site"} (23 records) \| Initial Machinery == {"non-compliant"} &&\
    - A code showing non-compliant, a record of the initial Stage, a record of the final Stage
    - A code showing non-compliant, an initial code showing E non-compliant, and a final code showing E compliant -\> change can be inferred from (average initial for that type of machine) - final Stage from {record \| what is permitted \| average value for this type of machine}

- **Next tasks**

  - Extract audit files that are neither (initially compliant not excluded for some other reason)
  - **LAST NOTE**
    - Asked Claude to draft a tree diagram of the results. Really made a bit of a mess of it, much better if I select the features to explore.
  - Work through the correct logic and finalise.
  - Develop some stats on each subset of the data

### Code review notes (mid-May)

1.  Code review found blocker (COVID constants used before definition); created tabulate_column helper function for frequency tallying.
2.  Moved initial/final machinery compliance analysis to line 64 (pre-filtering on audits_raw) and added parallel engine_type analysis with blank-handling.
3.  Updated constants to use dynamic Sys.Date()-based SCRIPT_STEM, added STEP and VERSION variables; clarified markdown headers with explicit "rows = X, columns = Y" notation. -- \[ \] stage mapping -- \[ \] remove COVID exemptions (is this the correct choice? otherwise may need to assign these a date of some sort) -- \[ \] Inspect the TANs to see how many unique machines. Analyse whether there is some way in which we can do two analyses, one by machines, the other by usage.

------------------------------------------------------------------------

## 250521

At finish have tinkered with the table headers to make them clearer.

------------------------------------------------------------------------

## 26-05-14

- [x] Adjusted the code using tolower() and trimws() at ingestion and the subsequent downstream code.
- [ ] Walk through the filtering pipe step by step, check each table generated by each filter, assure that the logic is correct, then once intermediates are created and tested, collapse the code into a simpler solution without logging.
  - [x] audits_raw reduces from 16,251 records
  - [x] compliant/non-complaint - check for screening of other options first; reduced to 13,541 records
  - [x] zones in scope; no change from 13,541 records, as all of the BCP zone audits are still baselining
  - [x] frequency table for modal substitution. note this does not work for Generators, and is a bit of a dodgy substitution for Crushers. Generators where the engine_type value is unset are always problematic, often removed or other. These need to be kept in as they contribute to emissions reductions, but we will need to guess their contributions somehow. So that means take them out and store them, then add them back into the final emissions reduction calculation based on summary statistics. To do this we need to track final_machinery_compliance values, which can be "removed from site", "non-compliant", or "compliant". For now we'll just pull them out of the data for the trends analysis.
  - [x] constant/variable. This has required some serious rethinking, because of those where the engine_type was something other than constant or variable, e.g. unidentified or blank, about 1350 end up being compliant, and 370 are removed from site. So maybe we need to do this a different way, instead of filtering by compliant/noncomp or const/var, instead filtering by final result, then using different data subsets for different purposes.

------------------------------------------------------------------------

## Emission factors

Applied per Stage in emissions estimation (Step 5). Store as named vector `EF_s` keyed on Stage integer. Operating hours default: 2,000 hr/annum for all groups and stages. User will supply figures at the right stage using (EMEP/EEA Tier 3, Ntziachristos & Samaras 2019).

------------------------------------------------------------------------

## Known limitations (flag in outputs)

1.  Ecological inference: aggregate counts approximate individual transition hazards (Robinson, 1950)
2.  Entry/exit bias: model absorbs fleet entry/exit; violates Markov time-homogeneity
3.  lambda_CF not time-homogeneous within Phase B: segment 1-2 and 2-3 inconsistent across all groups; single lambda per phase is a simplification
4.  lambda_CF overestimates true counterfactual due to second-hand market leakage; lambda_Proactive is conservative lower bound
5.  Phase A1/A2 variable speed groups pooled due to sparsity (A1 n=139; A2 n=357)

------------------------------------------------------------------------

## Key analytical notes from previous trials

| \# | Decision | Rationale |
|-------------------|---------------------------|---------------------------|
| 1 | Constant_Speed max_stage set to 3, not 6 | IIIB/IV absent from cold fleet; uniform max_stage=6 dilutes signal into impossible states |
| 2 | Phase B CAZ+ uses 3-segment temporal split, not annual GLS | Annual sample sizes 37-83; annual GLS yields inflated lambda=0.638; temporal estimate 0.363 |
| 3 | 2024 CS cold data excluded from lambda_CF estimation | Stage V spike 0% to 61% is anticipatory regulatory compliance, not natural turnover; use as Phase C initialisation state only |
| 4 | e-bar definition: Stage-threshold on all records | Enforcement_Upgrade flag captures only 35 on-the-spot replacements; threshold-based definition yields 10-20% exposure rates consistent with raw data |
| 5 | lambda_Proactive estimated from warm self-compliant subset only | All-warm WLS confounds proactive and enforcement trajectories; self-compliant subset isolates pure LEZ policy response |
| 6 | e-bar not subtracted from lambda_Policy in lambda_Proactive calculation | Non-compliant machines excluded from estimation window by construction |

------------------------------------------------------------------------

## Active state spaces

- Constant_Speed: max_stage = 3 (active stages I, II, IIIA only; IIIB/IV never present in cold fleet)
- CAZ+: max_stage = 6 (active stages II–V; Stage I near-absent from cold fleet; 5 active stages, max integer = 6 = Stage V)
- Rest_of_London: max_stage = 6 (full stage range present)

------------------------------------------------------------------------

## Table 8. Accepted parameter estimates

| Parameter | Value | SE | 95% CI | N | Source |
|------------|------------|------------|------------|------------|------------|
| lambda_CF Constant_Speed | 0.051 ⚠ | 0.026 | \[−0.017, 0.119\] | 133 | step3 v3, annual 2016–2023, max_stage=3 |
| lambda_CF CAZ+ | 0.262 | 0.033 | \[0.119, 0.404\] | 361 | step3 v3, A1/A2 pooled + B 3-seg, max_stage=6 |
| lambda_CF Rest_of_London | 0.241 | 0.017 | \[0.169, 0.314\] | 1,294 | step3 v3, A1/A2 pooled + B 3-seg, max_stage=6 |

⚠ Constant_Speed λ_CF (0.051) is a large departure from the prototype reference (0.358). The 95% CI barely excludes zero. This is corroborated by λ_Policy ≈ 0 in the warm self-compliant CS fleet (N=148) and the small cold sample (N=133). Likely reflects that the generator fleet has genuine low natural turnover and inertia — machines remain in service until a compliance event forces replacement. Treat 0.051 as the operative estimate for Step 4; the old reference is superseded.

------------------------------------------------------------------------

## Comparing ē and λ

ē and lambda are complementary, not interchangeable:

| Quantity | Type | Lay-person framing |
|------------------------|------------------------|------------------------|
| ē | Stock: non-compliance at audit | "X% of machines on site are below standard" |
| Δē/Δt | Flow: rate of stock change | "Non-compliance is falling by X pp per year" |
| λ → p_cf | Flow: fleet renewal rate (counterfactual) | "\~1 in N machines replaced per year without LEZ" |
| λ_Proactive → p_pro | Flow: proactive LEZ replacement rate | "\~1 in N machines additionally replaced per year due to LEZ" |

For policy evaluation audiences, **Δē/Δt** is the most intuitive headline metric — it directly answers "is the LEZ working, and how fast?" without ecological inference assumptions. Lambda is required internally for transition matrix construction and forecasting.

------------------------------------------------------------------------

## Enforcement success rate (descriptive metric)

The Route 4/5 audit outcome data characterises enforcement intensity and effectiveness but does not yield a model parameter comparable to lambda or p. The enforcement success rate per audit event is:

```         
enforcement_success_rate = n(Route 4, emissions) / n(Routes 4 + 5, emissions)
```

This is reported descriptively in Step 3 by group × phase. It answers "of non-compliant machines that were audited, what fraction were forced to comply?" — a direct policy evaluation metric. It is NOT used in transition matrix construction because it is conditional on non-compliance and expressed per audit event rather than per machine per year, making it incommensurable with p_cf and p_pro.

Enforcement enters the forecast model only as the **Scenario B Boolean mask** in Step 5, which zeroes transitions that would leave a machine in a non-compliant state and rescales the remaining row probabilities. This is a structural upper-bound assumption (full enforcement effectiveness) rather than a calibrated probability.

------------------------------------------------------------------------

## Lambda (λ)

Lambda is the **slope of mean emissions Stage over time** from a WLS regression of fleet mean stage against fractional year, weighted by cell sample size. Units: **stage integers per year**.

To convert to an approximate annual machine replacement probability *p*, one additional assumption is required: that when a machine is replaced it jumps directly to the highest stage in the estimation window (the dominant real-world behaviour — operators typically buy current-generation equipment rather than second-hand intermediates).

Under that assumption:

```         
p = λ / avg_stage_jump
```

where `avg_stage_jump` is the difference between the replacement stage and the typical starting stage for that group.

**Illustrative values from previous trials:**

| Group | λ_CF | avg_stage_jump (approx.) | Implied p (% p.a.) | Implied mean machine life |
|---------------|---------------|---------------|---------------|---------------|
| Constant_Speed | 0.358 | 2 (I → IIIA) | \~18% | \~5–6 years |
| CAZ+ | 0.363 | 3–4 (II → V) | \~10% | \~10 years |
| Rest_of_London | 0.219 | 3–4 (I/II → IV/V) | \~6% | \~15–18 years |

**Caveat:** the stage-jump assumption drives the conversion. If machines are more often traded second-hand one step at a time rather than bought new, the replacement rate is higher and implied machine lives are shorter. Lambda measures the *net fleet improvement signal*; converting it to an individual replacement probability is an ecological inference.

------------------------------------------------------------------------

## e-bar (ē)

ē is a **stock** measure: the percentage of all audited machines in a group–phase cell whose initial emissions stage was strictly below the minimum required threshold. It requires no conversion assumptions and is directly legible — "28% of CAZ+ machines were below the Stage IV threshold in Phase B."

The *change* in ē between phases divided by elapsed time gives a compliance improvement rate in percentage points per year:

```         
Δē / Δt = (ē_later − ē_earlier) / years between phase midpoints
```

This is a flow measure expressing how fast non-compliance is declining, directly answering whether the LEZ is working and at what pace.

------------------------------------------------------------------------

## Parameter interpretation

### Verification criteria

Verification criteria for exploratory/trends analysis fall into three categories: structural checks (did the data load correctly), analytical checks (do the numbers make sense given domain knowledge), and output checks (did the script produce what was requested).

**Structural checks** — include these in every ingestion script: - Row count after filtering matches expectation: in-scope records should be substantially fewer than 16,251 (P24 and BCP excluded, `No NRMM` machine records excluded). Flag if \>16,000 survive filtering. - No duplicate TANs within a single audit date. - Zone values contain only `{"CAZ", "OA", "GL"}` after filtering. - Date range falls within 2016–2030; no dates outside this window. - `emissions_compliant` and `admin_compliant` are boolean with no NAs where a compliance determination was possible.

**Analytical checks** — domain-grounded sanity tests for trends work:

- Compliance rate at phase boundaries moves in the expected direction: rate should rise after 1.9.2020 (tighter enforcement) and after 1.1.2025.
- Constant speed group shows no IIIB records (policy skips IIIB; any present signals a coding error).
- Emissions stage distribution shifts upward over time: mean encoded stage should increase across phases A1 → A2 → B.
- COVID-period records (1.9.2020–31.3.2021) are absent from Phase B after filtering; confirm with a row count of zero for that window.
- CAZ+ and Rest of London records cease as separate zones after 1.1.2025; only `Variable_Speed` (P24) appears from that date.

**Output checks** — confirm the script produced usable artefacts:

- Each saved `.rds` object loads without error in a fresh R session and matches the dimensions printed to console on completion.
- Trend plots show a visible x-axis spanning the correct phase range with phase boundaries marked.
- Summary tables contain no all-NA columns and no infinite values in computed rates or proportions.
- The manifest entry for each saved object is appended (not overwritten) and the row count in `manifest.md` increments correctly after each step.

These can be added to CLAUDE.md as a short "Verification criteria" section, with the instruction that every script must print a pass/fail against the structural checks before saving output.

**Checksums and counts**

- Total in-scope record count after ingestion is saved and compared at the start of every subsequent script. Any deviation halts execution with an explicit error, not a silent continuation.
- Machine-level and site-level record counts saved separately; their ratio should be stable (roughly constant machines-per-site distribution) across scripts that don't change scope.
- Phase record counts summed across A1, A2, B, C equal the total in-scope count.

**Distribution fingerprints**

- Emissions stage frequency table saved as a reference object at ingestion. Later scripts that reshape or filter data recompute it on the retained records and flag unexpected shifts (e.g. stage V proportion dropping, which would suggest accidental record loss rather than a real trend).
- Zone × equipment group cross-tabulation saved at ingestion as a reference. Any script producing a zone-level summary can cross-check its marginals against this.

**Compliance rates against known graphical patterns**

- Compliance rate should show a step-change upward at 1.9.2020 visible in any time series plot. If the plotted line is flat or declining across that boundary, the phase filter or date conversion is wrong.
- Within Phase B, the three sub-segments should show monotonically increasing compliance for variable speed groups. A non-monotonic result is a signal worth flagging, not silently plotting.
- CAZ+ should consistently show higher compliance than Rest of London within the same phase, reflecting the tighter IIIB requirement. A script that produces the reverse is a red flag.

**Referential integrity checks**

- Every TAN appearing in a final-stage record also appears in an initial-stage record. Orphaned final records indicate a join or filter error.
- `Final Emissions Stage` encoding is always ≥ `Initial Emissions Stage` encoding within an audit (machines don't downgrade during an audit). Violations flagged to console with a count.

**Output appearance checks**

- Time series plots include vertical lines at phase boundaries (1.9.2020, 1.1.2025); absence indicates the plotting code lacks the annotation layer.
- Any plot of compliance rate has a y-axis bounded 0–1; values outside this range indicate a rate was computed on the wrong denominator.
- No plot is saved with fewer than 30 data points in any displayed group; sparse-group plots are flagged rather than silently produced, since they would misrepresent trends.

These are worth codifying as a short checklist in CLAUDE.md so Claude applies them systematically rather than only when reminded in a step prompt.

------------------------------------------------------------------------

## Coding conventions

- All WLS fits via lm() with weights argument; extract SE from vcov()
- Transition matrices must be right-stochastic: rows sum to 1; enforce after every matrix operation
- Use exact fractional years for all temporal midpoints (see schema.md for phase boundaries)
- Never hardcode column names; derive from schema constants defined at script top