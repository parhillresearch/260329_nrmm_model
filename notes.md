# NRMM analysis notes

## State of play (17 July 2026)

> **⚠ FINDING UNDER QUERY (28 July 2026).** Headline finding 3 below, that constant-speed
> machines are not upgrading, is probably an artefact of how `Engine Type` is recorded for
> generators, not a real result. Every Stage V generator is recorded "Variable", so generators
> leave the Constant Speed group exactly when they improve. Corrected, the group's mean stage
> rises 2.96 → 4.57 (2021-24) and phase B compliance is 17%, not 0%. **Do not circulate
> `260719_nrmm_report.md`** until the audit team answers. See `260726_capture_issues_memo.md`,
> `260726_code_fix_checklist.md` and `260726_audit_data_queries.md`. Findings 1, 2 and 4 below
> were tested against the correction and hold.

Current model: **`nrmm_model_v5.R`** (authoritative), saved as `intermediate_data/nrmm_model_v5.rds`, results in `outputs/nrmm_model_v5.md`; current dashboard: **`nrmm_dashboard_v5.html`** (built by `nrmm_dashboard_v5.R`, reads the model object only; provisional build for sharing, carries a standing banner and a Data queries view). All earlier scripts carry a SUPERSEDED banner and must not be cited; several use earlier definitions that give different numbers. Report: `260719_nrmm_report.md`, whose section 12 maps every quoted figure to the model object that produces it. Full methodology in the next section. It supersedes the pre-audit lambda model (parameters archived below), the phase-stratified estimation design, and the separate derivations in `tree_dashboard_v3-v5.R` and `260717_ef_fleet_v1-v2.R`, which remain as development history.

Headline findings the model settles:

1. **The policy's measurable effect is the arrival-composition (proactive) channel.** Era-2 replacement probabilities are statistically indistinguishable between arms ($z = 0.09$); warm fleets arrive cleaner (compliance gap +8.5 pp; arrival NOx 14.1% lower per machine, excluding dispensation holders) rather than upgrading faster once on site.
2. **Replacement roughly doubled after September 2020** in both arms: variable-speed $\hat{\bar p}$ 0.10-0.12 (era 1) to ~0.23 (era 2).
3. **Constant-speed machines are not upgrading** ($\hat{\bar p} \approx 0$, se 0.004); projected compliance against a Stage V threshold stays near zero through 2030 under the central scenario.
4. **Within-audit enforcement outcomes are small and mostly removals**: 108 confirmed reductions (0.9% of audits), 95% of resolved outcomes are removals, and 55.9% of traceable removal events (40.3% of distinct machines) reappear at other sites.

Fitted $\hat{\bar p}$ (annual replacement probability, per engine type x arm x era):

| engine x era | cold_CF | warm_AT | pooled |
|---|---|---|---|
| Variable, era 1 (Oct 2016 - Aug 2020) | 0.103 (se 0.029) | 0.116 (se 0.017) | 0.109 (se 0.015) |
| Variable, era 2 (Sep 2020 - Dec 2024) | 0.227 (se 0.024) | 0.232 (se 0.040) | 0.231 (se 0.032) |
| Constant, era 2 | -0.003 (se 0.027) | 0.001 (se 0.002) | -0.002 (se 0.004) |

## Unified model documentation (current implementation: nrmm_model_v4.R)

One classified data spine, three layers, one saved object (`intermediate_data/nrmm_model_v4.rds`; results tables in `outputs/nrmm_model_v4.md`). The derivation below is unchanged since it was written for v1 on 17 July 2026; v2-v4 added payloads and quantities without altering the estimator. Supersedes the separate derivations in tree_dashboard_v3-v5 and 260717_ef_fleet_v1-v2, which remain as development history.

### 1. Notation and parameters

| Symbol | Name | Definition |
|---|---|---|
| $s$ | stage state | emissions stage coded $s \in \{1,\dots,7\}$: I=1, II=2, IIIA=3, IIIB=4, IV=5, V=6, ZE=7 |
| $G$ | Machine Group | Constant Speed, CAZ+ or Rest of London (schema Item 3a; BCP/P24 not implemented) |
| arm | engagement arm | `warm_AT` (registered, treatment) or `cold_CF` (unregistered, counterfactual), from `Cold-Engaged` |
| $\pi_s(t)$ | stage distribution | share of the audited fleet in stage $s$ in calendar-year cell $t$; $\sum_s \pi_s(t) = 1$ |
| $m(t)$ | fleet mean stage | $m(t) = \sum_s s\,\pi_s(t)$ |
| $M(t)$ | market-top stage | highest stage purchasable at time $t$, the replacement target: Variable IV before 2019 then V; Constant IIIA before 2019 then V |
| $\bar p$ | replacement probability | probability that a machine below $M(t)$ is replaced by a machine at $M(t)$ within one year (schema objective 4); one value per engine type $\times$ arm $\times$ era |
| $g(t)$ | stage headroom | $g(t) = \sum_{s < M(t)} \pi_s(t)\,\bigl(M(t) - s\bigr)$, the expected stage gain if every below-target machine were replaced |
| $\tau(G, d)$ | threshold | minimum compliant stage for Machine Group $G$ at exact date $d$ (schema Item 3b step function; two boundaries fall in September, two in January) |
| $\bar c$ | compliance rate | share of status-resolvable machines compliant at arrival: $\bar c = (n_A + n_B)/(n_A + n_B + n_C)$, statuses A stage-compliant, B dispensation held, C emissions non-compliant |
| $EF_\tau$ | type EF | power-weighted mean stage-limit NOx rate (g/kWh) of machine type $\tau$ in a cell |
| $N_\tau,\ \overline{kW}_\tau$ | type count, mean power | number of machines and mean rated power of type $\tau$ (placeholder $N_\tau$ = audit counts pending registration database) |
| $u_\tau$ | usage index | relative energy-use intensity of type $\tau$: hours/day $\times$ load factor, normalised to the excavator (8 h/day $\times$ 0.40); placeholder values, 24 h/day cap |
| $s_\tau$ | energy share | normalised weight $s_\tau = N_\tau \overline{kW}_\tau u_\tau \big/ \sum_{\tau'} N_{\tau'} \overline{kW}_{\tau'} u_{\tau'}$ |
| $EF_{\mathrm{fleet}}$ | fleet EF | $EF_{\mathrm{fleet}} = \sum_\tau s_\tau\, EF_\tau$ (g/kWh $=$ kg/MWh) |

### 2. Derivation, step by step

**Step 1 — stage distributions.** For each engine type $\times$ arm $\times$ calendar year with cell size $n \ge 20$, compute $\pi_s(t)$ and $m(t)$ from initial audit stages. Calendar years are the estimation axis; thresholds are never used at this step, so the September boundaries do not affect it.

**Step 2 — constrained transition matrix.** In one year a machine below target is replaced with probability $\bar p$ and jumps to $M(t)$; nothing else moves:

$$
\pi_s(t{+}1) =
\begin{cases}
(1-\bar p)\,\pi_s(t) & s < M(t) \\[4pt]
\pi_s(t) + \bar p \displaystyle\sum_{r < M(t)} \pi_r(t) & s = M(t) \\[4pt]
\pi_s(t) & s > M(t)
\end{cases}
$$

This replaces the unconstrained $6\times6$ matrix (36 free parameters, unidentifiable from 24 observations, per schema) with a single parameter per cell.

**Step 3 — mean-stage increment identity.** Multiplying the transition by $s$ and summing, each replaced machine gains $M(t) - s$, so

$$
m(t{+}1) - m(t) \;=\; \bar p \sum_{s < M(t)} \pi_s(t)\,\bigl(M(t)-s\bigr) \;=\; \bar p \, g(t)
$$

The observable yearly increment $\Delta m$ is proportional to $\bar p$ with a known, data-computed coefficient $g(t)$. This is why the mean-stage WLS slope (schema definition of $\bar p$) and the Markov chain agree: the slope equals $\bar p$ times average headroom. It also explains the apparent A1$\to$A2 acceleration mechanically: when $M(t)$ jumped from IV to V in 2019, $g(t)$ widened at constant $\bar p$.

**Step 4 — estimator.** Over adjacent-year pairs $k = (t, t{+}1)$ within an era, through-origin weighted least squares of $\Delta m_k$ on $g_k$:

$$
\hat{\bar p} \;=\; \frac{\sum_k w_k\, \Delta m_k\, g_k}{\sum_k w_k\, g_k^2},
\qquad
w_k = \frac{2}{1/n_t + 1/n_{t+1}}
$$

(harmonic-mean weights, since $\operatorname{Var}(\Delta m_k)$ scales with $1/n_t + 1/n_{t+1}$), with standard error

$$
\operatorname{se}(\hat{\bar p}) = \sqrt{\frac{\sum_k w_k (\Delta m_k - \hat{\bar p}\, g_k)^2}{(K-1) \sum_k w_k g_k^2}}
$$

for $K$ pairs; undefined at $K = 1$. Pairwise increments rather than propagation from an initial year make the estimator robust to slow composition drift between cross-sections.

**Step 5 — eras.** Two estimation eras split at 1 September 2020 (the in-year policy transition): the increment data reject a single $\bar p$ (slope roughly doubles in both arms) but do not support four phase-specific values once the $M(t)$ jump is inside the matrix (Step 3). Phases A1-C survive only in $\tau(G,d)$ and reporting.

**Step 6 — compliance.** Observed $\bar c$ uses exact audit dates against $\tau(G,d)$, so September boundaries need no cell adjustment. Projected compliance is the stage mass at or above threshold, $\bar c(t) = \sum_{s \ge \tau(G,t)} \pi_s(t)$ (dispensations not projected).

**Step 7 — fleet EF.** $EF_{\mathrm{fleet}} = \sum_\tau s_\tau EF_\tau$ is a convex combination, hence bounded by $\min_\tau EF_\tau \le EF_{\mathrm{fleet}} \le \max_\tau EF_\tau$ for any usage values, and invariant to common rescaling $u_\tau \to \lambda u_\tau$ (the $\lambda$ cancels in $s_\tau$), so only relative usage between types matters. Projected EF evolves the stage mix and holds each stage's 2023-24 power-band mix fixed: $EF(t) = \sum_s \pi_s(t)\, \overline{EF}(s)$ with $\overline{EF}(s)$ the observed power-weighted EF of stage-$s$ machines.

**Step 8 — projection.** From the pooled 2023-24 $\pi_s$ per Group $\times$ arm, apply Step 2 annually for 2025-2030 with era-2 $\hat{\bar p}$ under three scenarios (central, and the 95% CI ends $\hat{\bar p} \pm 1.96\,\operatorname{se}$, clamped to $[0,1]$), evaluating $\bar c(t)$ against the exact-date schedule (2025-29: CS V, CAZ+ V, RoL IV; from 1.1.2030 all V).

### 3. Fitted parameters

See the $\hat{\bar p}$ table in the State of play section. Replacement roughly doubled after September 2020. Era-2 arms are statistically indistinguishable ($z = 0.09$): the policy's measurable effect is the arrival-composition (proactive) channel, not differential replacement speed. Constant-speed $\hat{\bar p} \approx 0$: generators are not upgrading, and their central projected $\bar c$ against a Stage V threshold stays $\approx 0$ through 2030 (CI-high reaches 0.038). Central 2030 $\bar c$: CAZ+ 0.93 warm / 0.91 cold; RoL similar with a dip at the 1.1.2030 threshold step. Projected $EF_{\mathrm{fleet}}$ at 2030: CAZ+ $\approx$ 1.75-1.79, RoL 1.85-1.88, CS 4.1-4.3 g/kWh.

### 4. Limitations from sub-population sizes

- **Constant-speed cold arm (9-40 records/year).** Too thin for arm-specific annual fitting; $\bar p$ is fitted with arms pooled, so the model cannot detect a counterfactual difference in replacement behaviour for constant-speed machines, only for variable-speed. Any CS treatment effect on $\bar p$ is structurally invisible at these n.
- **Era-1 constant-speed ($K = 1$ pair).** Point indication only, no standard error; excluded from inference.
- **Excluded year-cells.** Cells below $n = 20$ (2 cells) are dropped from fitting; at $n = 20$ the standard error of $m(t)$ is roughly $\pm 0.3$ stages, which the harmonic weights $w_k$ down-weight but cannot repair.
- **Phase C ($n = 63$).** Projection only, never estimation; 2025+ results inherit era-2 behaviour by assumption.
- **Cold arm generally (17% of records).** CI widths for cold_CF are roughly double warm_AT at equal era counts; the era-2 arm comparison ($z = 0.09$) is genuinely null, not merely under-powered, because both SEs are small, but finer splits (by zone or year within era) would be under-powered in the cold arm.
- **TAN coverage (about 50% of records).** The removal fate split (reappears / not seen again / no TAN) leaves 198 of 497 emissions-non-compliant removals with unknown fate; reappearance rates are lower bounds.
- **Unclustered errors.** $\operatorname{se}(\hat{\bar p})$ treats machines as independent; audits cluster within sites, so true intervals are somewhat wider (site-clustered bootstrap deferred).

### 5. Placeholders carried in the model object

Stage NOx limit table and usage indices $u_\tau$ are general-knowledge values pending verification and sourced estimates; $N_\tau$ are audit counts pending the NRMM registration database; verification block enforces: exhaustive classification, $\sum_s \pi_s = 1$, probability conservation and monotone $m(t)$ in projections, admin-only node contains no E-coded records.

## Parameter and definitions register (current)

| Quantity | Type | Definition and role |
|---|---|---|
| $\bar c$ | stock | legal compliance at arrival, $(n_A+n_B)/(n_A+n_B+n_C)$. **Definition change (260717):** dispensations (status B) now count as legally compliant; the pre-audit definition was stage-threshold-only. $\bar c$ measures legal compliance, NOT emissions: a dispensation is not an emissions reduction, and emissions effects flow through the EF layer, where a dispensed machine keeps its true stage EF. |
| $\Delta\bar c/\Delta t$ | flow | compliance improvement rate, pp/year; the headline "is the LEZ working" metric, no ecological-inference assumptions |
| $\bar p$ | flow | annual replacement probability (see model documentation). Replaces $\lambda$: the old slope relates to it by $\lambda = \bar p \, g(t)$, so $\bar p$ is estimated directly and $\lambda$ is no longer carried |
| $EF_{\mathrm{fleet}}$ | intensity | fleet NOx per unit work, g/kWh = kg/MWh, convex combination over machine types |
| enforcement success rate | descriptive | of emissions-non-compliant machines (status C), the share with a real-reduction outcome (a replaced on the spot, b stage upgraded, c retrofitted) = 108/1,337 = 8.1% fleet-wide. Descriptive only; conditional on non-compliance and per audit event, so never a transition-matrix input |

Standing limitations (live): ecological inference (aggregate cross-sections approximate individual hazards, Robinson 1950); entry/exit bias (the chain absorbs fleet entry/exit, violating time-homogeneity); unclustered standard errors; ~50% TAN coverage bounds removal-fate attribution.

### Superseded: pre-audit lambda model (retained for provenance)

All items below are superseded by `nrmm_model_v1.R`; do not use in new work.

- **Table 8 accepted parameter estimates** — $\lambda_{CF}$ Constant_Speed 0.051 (se 0.026), CAZ+ 0.262 (se 0.033), Rest_of_London 0.241 (se 0.017). Superseded by the $\hat{\bar p}$ table; the Constant_Speed value was additionally corrupted by the Stage V generator engine-type recording issue (all 171 Stage V generators recorded as Variable, draining the compliant tail from the CS group).
- **$\lambda$ definition and illustrative conversion** ($p = \lambda / \text{avg stage jump}$, illustrative $\lambda_{CF}$ 0.358/0.363/0.219) — replaced by the increment identity $\Delta m = \bar p\, g(t)$, which makes the conversion exact and data-computed rather than assumed.
- **Active state spaces** (Constant_Speed max_stage = 3) — an artefact of the same generator recording issue; the current model uses $M(t)$ = IIIA pre-2019 then V for constant speed.
- **Operating hours default 2,000 hr/annum for all groups** — replaced by relative usage indices $u_\tau$, where only relative hours between types matter; a flat default is the one assumption the EF sensitivity analysis specifically rejected.
- **$\lambda$-era limitations 3-5** (within-phase inhomogeneity, second-hand leakage bounds on $\lambda_{CF}$, A1/A2 pooling for sparsity) — restated in current terms in the model documentation's limitations section.

## Open decisions and pending inputs

1. **COVID window.** Old verification criteria expected records in 1.9.2020-31.3.2021 to be excluded from phase B; the current model keeps them. Decide: exclude, keep, or sensitivity-test.
2. **Pre-2019 generators.** Default adopted (260717): keep generators, modal engine-type imputation for non-generators only; unset-engine generators enter only under the "Generators as Constant Speed" toggle. The 260619 proposal to exclude them as "p19" is superseded but the underlying concern (147 unresolvable rows) stands; revisit if registration data can resolve engine types.
3. **BCP and P24 Machine Groups** (schema Item 3a) are not implemented; current model keeps zone/engine groups through phase C. Reconcile schema or model.
4. **Registration counts $N_\tau$** from the NRMM database, replacing audit counts in the EF weights.
5. **Sourced usage estimates** for Generator and Excavator first (OAT swings 0.49 and 0.26 g/kWh; all other types < 0.1); hours/day is the natural unit.
6. **EMEP/EEA Tier 3 EF_s** (Ntziachristos & Samaras 2019) to replace the stage-limit NOx placeholder; PM factors needed to credit retrofits (DPFs abate PM, not NOx).
7. **Stage limit table verification** against Directive 97/68/EC / Regulation (EU) 2016/1628.
8. **Site-clustered bootstrap** for $\hat{\bar p}$ intervals.
9. **Add back removed-from-site machinery** excluded for unidentified engine type (end-of-project checklist item, carried).

## Decision log

- **260728 - unblocked fixes implemented (model v5, dashboard v5).** All 13 checklist items that did not need an auditor answer are in. New: stage strings normalised before mapping so case typos resolve (B2); `stage_inconsistency` reporting machines recorded at different stages across visits (B4); status **X, no determination made**, for visits that logged a site-level state against a machine, keeping the stage and voiding the outcome per the agreed C2 rule (60 records, 34 of them in phase C); `removal_fate_by_year` with the observation window, since TAN capture starts 2021 and recent removals are right-censored (C4); machine type normalised once and variants mapped (D1, D2); `GENERATOR_MODE` restored as an explicit switch with `classification_sensitivity` showing both readings (A3, E4).
  - **New verification class, and it works.** E1 structural-implausibility checks now fire on this data unprompted: "Constant_Speed: 778 machines, none above stage 4" plus three near-zero fitted rates. E3 flags Constant_Speed shrinking 61% since 2019. E2 lists every unmapped categorical value rather than dropping it silently. Had these existed at v1, the generator artefact would not have survived four versions.
  - **Provisional build for the audit team:** `nrmm_dashboard_v5.html` carries a standing banner and a **Data queries** view putting both readings of the generator classification side by side, so the auditors can see exactly what is being asked. Covering message drafted in `260728_message_to_auditors.md`.
  - Classification default remains `as_recorded`; no headline figure has been changed. Constant Speed results stay uncitable until the query is answered.
- **260728 - audit data capture review; report frozen.** A recheck of the constant-speed stage populations, prompted by the observation that Stage V generators exist but never appear in the group, found a survivorship artefact: the Constant Speed group is defined by `Engine Type`, and all 218 Stage V generators are recorded "Variable", so generators exit the group by improving. Corrected, era-2 replacement goes -0.002 → 0.107, phase B compliance 0% → 17%, intensity 4.12 → 3.66 g/kWh. Crushers show the same shape (15 "Constant" records, all Stage IIIA). A blanket "generators are constant speed" rule is *not* safe: hybrid, flywheel and flybrid units split 37/51, apparently deliberately.
  - **Robust to the issue:** variable-speed replacement rate (0.2312 → 0.2341), the era-2 null difference between arms, the arrival-composition finding (gap 12.4% → 13.4%, slightly larger corrected), and all enforcement-channel results.
  - **Further findings on the priority axes** (wrong year / stage / situation / group): year is clean (all dates parse, no day-month transposition); `"Electric"` (31 records, 1 in 2022 rising to 15 in 2025) maps to NA instead of stage 7, the same failure mode as the generators; 7% of repeat-audited machines appear at more than one stage, five differing by 3-4 stages; `"Pending"` (23) conflated with not-remediated; TAN capture starts 2021, making the untraceable-removal bucket a time artefact and the 55.9% displacement rate a right-censored lower bound (62% for 2021 removals, 45% for 2025).
  - **C2 rule adopted:** where site-level markers (Baselining, Site Complete, No Apparent Works, DECLINED AUDIT) are logged into machine compliance fields, keep the stage where usable but mark the compliance outcome undefined. Cross-check showed the machine data is often present elsewhere on the row (577 of 1,662 have a usable stage) but the E-flag fallback is unavailable: reason codes read "None" on 1,594 of 1,662 rows. Affects 60 rows in the spine, 34 of them in phase C, which holds only 63.
  - **P24 / BCP:** confirmed backlog, not now. Different timeframe and project; P24 collapses to a single group/zone so there is a structural discontinuity requiring everything to be regrouped onto a common basis.
  - **Verification gap that allowed this:** checks test internal consistency but not structural implausibility. A group at exactly 0% compliance, a fitted rate of exactly zero, or a category with no members above a stage all passed silently. The superseded `tree_dashboard_v3-v5.R` carried such a guard; it was dropped at unification into `nrmm_model_v1.R`. No model or report changes made pending auditor response.
- **260726 - review-readiness pass (model v4, dashboard v4).** Prompted by the question of whether the work could survive a line-by-line review cross-referenced with the report. It could not: three reported quantities had no code path (they came from exploratory scripts since deleted), and four figures were stale or conflicted with the model. Fixed by computing them in the model and correcting the report.
  - **New model objects.** `arrival_ef` (mean arrival emissions intensity per Machine Group x phase x arm, with and without pre-existing dispensations) - this is the report's headline finding and previously existed only in a scratchpad; `removal_fate` (displacement under both the record-level and machine-level definitions, computed side by side because earlier drafts conflated them); `enforcement_nox` (the enforcement channel as a share of audited-fleet NOx, previously surviving only in the superseded tree_dashboard scripts).
  - **Figures corrected in the report**, with causes documented in its technical boxes: arrival gap 16% -> 14.1%, phase gaps "12-26%" -> 10.9-17.2% (earlier values used a stage-only EF vector ignoring engine power band; band-resolved limits compress the gap because EU standards are laxer for small engines, where Stages IIIA-V share a NOx limit); displacement 43% -> 55.9% per removal event or 40.3% per machine, both now stated; unknowable removals ~390 -> 365; NOx shares 0.2/2.6/7.4% -> 0.10/1.86/5.59%.
  - **Retrofits now credited zero NOx** in `enforcement_nox`. The retrofits in this data are overwhelmingly DPFs, which abate PM, not NOx; crediting them as a stage change was the largest single overstatement available in the dataset.
  - **`REPLACEMENT_STAGE_ASSUMED` promoted to a named constant** in the model; it had been used implicitly via the EF scripts and was undefined in the model until now.
  - **Provenance hygiene.** All 13 superseded scripts carry a SUPERSEDED banner naming their successor; stale header comments fixed in the current scripts (dashboard v3 claimed to read `nrmm_model_v2.R`; model header still described relative usage indices after the hours/day change); the dashboard's client-side recursion, self-check and aggregation now carry explanatory comments; the report gained a cross-reference table (section 12).
- **260719 — plain-English dashboard pass.** `nrmm_dashboard_v3.R`: all arcane labels replaced with clear statements (the pooled-arm badge now reads "too few unregistered constant-speed machines to measure separately, so both groups share one replacement-rate estimate"; p-bar/c-bar/EF_t/parity/arm codes similarly reworded), hover tooltips added to every category header, arm row, gap row and badge, and a Glossary view added covering all sixteen terms. Technical terms remain in the model scripts and notes; the dashboard now speaks English.
- **260719 — hours/day usage unit and stage-population views.** Usage is now hours/day x fixed load factor per type, normalised to the excavator (8 h/day x 0.40), replacing the abstract index; the 24 h/day physical cap tightens the Generator and Pump upper bounds (u_high 5.0 to 3.75), narrowing the All-fleet phase B EF envelope from [1.99, 3.08] to [2.00, 2.97] with the central 2.52 unchanged. `nrmm_model_v3.R` also emits observed stage populations per subgroup x arm x year and the full projected stage vectors pi_1..pi_7 per scenario year (shares only; absolute populations need the registration multiplier). `nrmm_dashboard_v2.R` adds the Stage populations view (stacked shares, observed solid / projected faded, p-bar slider) and re-expresses the EF sliders in hours/day.
- **260717 — unified dashboard.** `nrmm_dashboard_v1.R` consumes `nrmm_model_v2.rds` only (no re-derivation): outcomes tree/table, EF view with usage sliders (Generator, Excavator, grouped others; envelope always shown), trends & projections with a p-bar multiplier slider running the constrained recursion in JS, parity-asserted against the R projections on load. `nrmm_model_v2.R` adds the payloads (year-keyed outcome cells, All_NRMM strata + envelopes, threshold schedule as data, schema_version = 2). Note: the removal fate split now computes reappearance strictly after each record's own date, correcting the v3-v5 any-removal-event logic (fleet-wide d/e split 167/132 vs 191/108; totals unchanged).
- **260717 — ē definition.** $\bar c$ counts dispensations as legally compliant (status B); emissions accounting stays in the EF layer. Supersedes the stage-threshold-only definition.
- **260717 — model unified.** `nrmm_model_v1.R` built; three layers on one spine; see State of play.
- **260717 — time subdivision.** Calendar-year estimation cells; exactly two eras split at 1 Sep 2020 (slope doubles in both arms; A1/A2 split not supported once the $M(t)$ jump is modelled); phases demoted to threshold schedule; no year convention aligns all four policy boundaries (two September, two January), so compliance is evaluated at exact dates and only the 2020 reporting cell splits at September (variable-speed only; n = 143/164 cold, 661/537 warm).
- **260717 — Markov feasibility.** Free phase-specific matrices rejected: TAN panel transitions are noise-dominated (median re-sighting gap 15 days; stage changes symmetric 43 up / 43 down, a recording-noise signature), and 7 of 18 subgroup x phase x arm cells have n < 100. Constrained one-parameter chain adopted; the ~1% symmetric flip rate simultaneously validates cross-sectional distributions.
- **260717 — EF weighting (option 2).** Type-stratified convex combination adopted; full derivation and sensitivity in `outputs/260717_ef_fleet_v2.md`. Phase B type-mean EFs span 0.98 (piling rig) to 4.60 (MEWP) g/kWh, so mix is first-order; normalised weights make absolute hours cancel.
- **260717 — EF units.** Per-MWh (g/kWh) confirmed as native unit of stage limits; weighting, not units, is the substantive choice; see `outputs/260717_ef_fleet_v1.md`.
- **260717 — audit corrections.** Within-audit "improved" is ~5% of audits and 95% removals; strict emissions-attributable count 600 (of which 108 confirmed reductions); ≥43% of removed TANs reappear elsewhere *(superseded 260726: 55.9% of removal events / 40.3% of machines, see that entry)*; admin-only non-compliance (640 records) quarantined from emissions outcomes.

### Key analytical decisions from previous trials (with current status)

| # | Decision | Status (260717) |
|---|---|---|
| 1 | Constant_Speed max_stage = 3 | **Superseded** — artefact of generator engine-type recording; model uses $M(t)$ schedule |
| 2 | Phase B CAZ+ 3-segment split, not annual GLS | **Superseded** — annual cells viable at n ≥ 20 with harmonic weighting; two-era WLS replaces segments |
| 3 | 2024 CS cold excluded from $\lambda_{CF}$ (anticipatory Stage V spike) | **Retained in spirit** — 2024 CS cells feed projection initialisation, not $\bar p$ fitting (era pairs only) |
| 4 | ē threshold-based on all records | **Amended** — dispensations now count as compliant; see decision log |
| 5 | $\lambda_{Proactive}$ from warm self-compliant subset | **Superseded** — proactive channel now measured directly as the warm-cold arrival gap |
| 6 | ē not subtracted from $\lambda_{Policy}$ | **Moot** — quantities no longer used |

## Relocated

Verification criteria for analysis scripts and analysis coding conventions moved to `plans/coding_rules.md` (260717). Two stale checks deleted in the move: "COVID-period records absent from Phase B" (now open decision 1 above) and "Final stage ≥ Initial stage within audit" (stage fields are static within audits; the check tests nothing).

---

# Archive (historical log, superseded or absorbed above)

## 260619 Closer breakdowns of the different pathways

- Issue found: `engine type` was not set before 2019, affecting 147 of 1,525 Generator rows (9.6%). So if these are excluded due to `engine type` being unset, we miss 10% of the generators. This is important for the constant speed zone analyses.

- Possible solutions for pre-2019 generators `machine type`:

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

- **Conclusion on definitions of `engine type` and `machine type`** *(superseded 260717: current model keeps generators, see Open decisions 2)*

  - Since engine type was unset pre-2019, we must exclude pre-2019 generators from the analysis.

  - Therefore `Machine groups` need to be defined by the following rules:

    - if `machine type` == `generator` and `date` < 2019, then `Machine Group` <- "p19" and exclude from analysis;
    - else if `zone` = BCP (Beyond Construction Project), then `Machine Group` <- "BCP" (not used in this analysis);
    - else if audit date after 31.12.2024, then `Machine Group` <- "P24" (post 2024);
    - else if engine type is Constant Speed then `Machine Group` <- "Constant Speed", (is used in this analysis;
    - else if `zone` == `CAZ` or `OA` `Machine Group` <- "CAZ+";
    - else Assign "GL" for Rest of London or Greater London. Propose options to (1) test if there are enough generators in the pre-2019 audits to justify further work, or can we just exclude them? (2) if we need them, infer engine type if a generator was audited pre 2019 for example based on compliance at Euro engine stage IIIa.

  - Stats

    - 147 of 1,525 Generator rows (9.6%) have unset Engine Type, all pre-2019. Among Generators with a valid Engine Type: Stage IIIA splits 80% Constant / 20% Variable (648/165); Stage II splits 84%/16% (68/13); Stage V is 100% Variable (171/171, zero Constant). Of the 147 unset rows: 81 are Stage IIIA, 25 are Stage II, 41 have no stage at all ("Unidentified") — none are Stage V.

## 260618 Tree analysis using the tree_analysis_rol_outcome_focused.R

Auditing the previous work all over again so we can restart the analysis.

- Script `tree_analysis_rol_outcome_focused.R` drafted to focus on what audit flags are linked to actual emissions reductions. This is actually an experiment to see if these are actual emissions reduction.

- **To check before proceeding** *(all items since resolved: taxonomy in nrmm_model_v1 answers flags/enforcement questions; time subdivision and transition-matrix rules decided 260717)*

  - [x] Data still needs cleansing as engine_type is not properly populated for pre 2019 data. Resolved in Iteration 9 of the data ingestion stage.
  - [x] What flag combinations in the audits are linked to actual emissions reductions
  - [x] Can the emissions reductions from enforcement (eg cold-engaged or not-self-compliant) vs self-compliant be distinguished.
  - [x] What EXACT flags indicate self-compliant, never compliant, warm engaged but not self compliant AND led to an emissions reduction, warm engaged but not self compliant that did not lead to an emissions reduction.
  - [x] What are the correct transition matrices to be used for each data subset, considering the actual populations.
  - [x] What is the best temporal breakdown of each subgroup of the data in each phase of the LEZ?

- **Actions taken today**

  1.  Dashboard code: Built `tree_dashboard.R` — Shiny + visNetwork interactive companion to `tree_analysis_rol_outcome_focused.R`. Group/year selectors drive a reactive Item 7 compliance tree and enforcement pathway tables. Fixed two bugs: visNetwork font spec (needed double `list()`), and `as.Date()` missing `format=` (misread DD/MM/YYYY, year showed as 1-31). Pushed to branch `add-item7-compliance-dashboard`.

  2.  Data cleanse steps available: v9 ingestion script (`260521_step1_ingestion_v9.R`) already implements modal engine_type imputation per machine_type, excluding Generators (near 50/50 split, no reliable mode). Porting this into the dashboard would recover ~1,150 of the 1,404 pre-2019 blank-Engine-Type records.

  3.  Other findings: Pre-2019 records (2016-2018) vanish from the dashboard's year dropdown because blank Engine Type fails the Constant/Variable filter *before* date derivation runs — not a date bug. 1,399 of 1,404 pre-2019 rows have blank Engine Type; only 5 don't.

## 2026-06-16 — Audit and exploratory tree analysis

Audited Steps 1-6 for overengineering. Created `AUDIT_STATE_OF_PLAY.md`: core model logic (Steps 3-5) is sound; Step 1 had fragile compliance-parsing bugs; Step 6 had multi-trial formatting churn. Reviewed existing `tree_analysis.R` and `tree_analysis_2.R`: they perform undirected dependency discovery (Chow-Liu tree) but don't target emissions improvement outcomes.

**Key insight:** Raw audit field values are inconsistent; cannot hard-code regex patterns for "enforcement" or "removal". Instead, built outcome-focused exploratory script (`tree_analysis_rol_outcome_focused.R`) for Rest of London: defines outcome (emissions_improved = initial stage < threshold AND final stage >= threshold), computes MI rooted at outcome, and discovers which feature combinations predict improvement **without assuming field values**.

## 250526

- Review of the logic of delivering improvements during operation and in machinery: a machine not compliant for emissions reasons is replaced with a compliant machine or removed from site; encoding traced through Initial/Final Machinery fields and E codes. *(Absorbed into the nine-way outcome taxonomy, 260717.)*

### Code review notes (mid-May)

1.  Code review found blocker (COVID constants used before definition); created tabulate_column helper function for frequency tallying.
2.  Moved initial/final machinery compliance analysis to line 64 (pre-filtering on audits_raw) and added parallel engine_type analysis with blank-handling.
3.  Updated constants to use dynamic Sys.Date()-based SCRIPT_STEM, added STEP and VERSION variables; clarified markdown headers. Open items: stage mapping; COVID exemption handling; TAN uniqueness analysis for machine-level vs usage-level analyses. *(TAN analysis done 260717: ~50% usable, 490 multi-sighting machines.)*

## 250521

At finish have tinkered with the table headers to make them clearer.

## 26-05-14

- [x] Adjusted the code using tolower() and trimws() at ingestion and the subsequent downstream code.
- [x] Walk through the filtering pipe step by step: audits_raw 16,251 records; compliant/non-compliant screen to 13,541; zones in scope unchanged (BCP still baselining); modal substitution unreliable for Generators (near 50/50) and dodgy for Crushers; ~1,350 unset-engine records end compliant, 370 removed from site — keep and reintroduce via summary statistics for the final emissions reduction calculation. *(Carried as Open decision 9.)*
