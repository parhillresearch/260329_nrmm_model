# Cleaner machines on London's construction sites: what 16,251 audits tell us about the NRMM Low Emission Zone

**Draft for policy and programme staff | 19 July 2026**

This report explains, in plain English, how we analysed nine years of machine audits from London's Non-Road Mobile Machinery (NRMM) Low Emission Zone, what we found, and how confident we can be. Technical detail sits in boxed notes for specialist readers; the main thread can be read without them. An interactive dashboard accompanies this report (`nrmm_dashboard_v4.html`), including a glossary of terms. Every figure quoted here is reproducible from the model object; section 12 maps each claim to the exact object and script that produces it.

---

## 1. Summary

- **The scheme's biggest effect happens before an inspector ever arrives.** Construction fleets that register with the scheme turn up with cleaner machines than fleets that never register: 89% of registered machines already met the required standard on first sight, against 81% of unregistered ones, and the average registered machine is about 14% cleaner on arrival.
- **On-site enforcement fixes far fewer machines than the records first suggested.** Of 11,643 machine audits, only 108 (about 1%) demonstrably ended in lower emissions: a machine replaced, upgraded, or fitted with clean-up equipment.
- **Most "resolved" non-compliant machines simply left the site, and many did not leave London.** Of the removals we can trace by serial number, 56% involve a machine that turns up again at another audited site later (40% counted per machine rather than per removal event). Removal often moves pollution rather than reducing it.
- **Fleet renewal roughly doubled when requirements stepped up in September 2020,** from about 11% of older machines replaced per year to about 23%. Strikingly, registered and unregistered fleets renew at the same pace; the difference between them is the machines they arrive with, not how fast they upgrade on site.
- **Generators are the stubborn problem.** The constant-speed fleet (mainly generators) shows essentially zero upgrading, and on current behaviour its compliance with the Stage V requirement stays near zero through 2030.
- **By 2030, around 90% of the variable-speed fleet is projected to meet the standard** under current replacement rates, with a visible dip each time the required standard steps up (2025 and 2030).

---

## 2. What we set out to answer

London's NRMM Low Emission Zone requires construction machinery to meet a minimum engine emissions standard that depends on where the machine works, when, and what kind of machine it is. Site operators must register their machines; inspectors then audit sites and record each machine's engine standard and what happened next.

The question for this analysis: **is the scheme reducing emissions, by how much, and through which routes?** Three routes matter, and they are often confused:

1. Machines arriving cleaner because operators anticipate the rules (the "proactive" route);
2. Machines being fixed, replaced or removed after an inspector finds them non-compliant (the "enforcement" route);
3. Machines becoming compliant on paper only, through registration fixes or exemptions (no emissions change at all).

A credible answer needs a comparison group. Usefully, the audits include machines found operating without ever registering, which is itself against the rules. These unregistered ("cold-engaged") machines behave like a fleet the policy never reached, so they serve as the comparison; the registered ("warm-engaged") fleet is the group the policy acts on.

> **For technical readers.** The dataset is 16,251 audit records, 2016-2025, of which 11,643 are in scope after excluding non-NRMM items and out-of-scope zones. Arms: warm_AT (treatment) n = 9,622; cold_CF (counterfactual) n = 2,021. Machine Groups follow the schema: Constant Speed (engine type), CAZ+ (central zone and opportunity areas), Rest of London; group thresholds step at 1 Sep 2015, 1 Sep 2020, 1 Jan 2025 and 1 Jan 2030 (stage IIIA/IIIB era 1 to Stage V era 4, per the EU stage system of Directive 97/68/EC and Regulation 2016/1628). The cold arm is a selected sample (found by inspectors), so its compliance likely overstates the true never-audited fleet; the arrival-gap estimate is therefore conservative.

## 3. How each audit was classified

Every audit record was sorted twice. First, what state was the machine in when the inspector first saw it? We use five categories: already meeting the standard; holding an approved retrofit or exemption; genuinely below the emissions standard; having only a paperwork problem (such as not being registered) with no evidence of an emissions problem; or unresolvable from the record. Second, for machines genuinely below the standard, what happened by the end of the audit? Nine outcomes, grouped into three classes: a real emissions reduction (replaced on the spot, upgraded, or retrofitted), a removal whose effect depends on where the machine went, or no demonstrated reduction (an exemption granted, an unexplained compliance record, or nothing).

The critical design choice is keeping paperwork problems separate from emissions problems throughout. A machine that becomes "compliant" by registering has changed nothing in the air.

> **For technical readers.** Initial status uses stage-vs-threshold at the exact audit date, then the retrofit/exemption field, then officer reason codes (E = emissions standard not met; A/C/P/R/X = administrative). The compliance rate over the status-resolvable machines counts dispensations as legally compliant:
>
> $$
> \bar c = \frac{n_A + n_B}{n_A + n_B + n_C}
> $$
>
> where A = stage-compliant, B = dispensation held, C = emissions non-compliant; the change in $\bar c$ between periods divided by elapsed time, $\Delta\bar c/\Delta t$, is the compliance improvement rate in percentage points per year. 640 records (5.5%) are administrative-only non-compliance and are quarantined from all emissions outcomes; 502 held pre-existing dispensations and are never counted as "improved". Outcome mechanisms come from the officer's final fields, not stage arithmetic, because stage fields are static within audits (of 4,564 repeat sightings of the same machine, stage changes are symmetric 43 up / 43 down, a ~1% recording-noise signature). Removal fate uses the machine serial number (TAN, usable for ~50% of records): a removed machine that reappears at any later audited date counts as displaced. Fleet-wide, the 497 emissions-non-compliant removals split 167 reappeared / 132 never seen again / 198 untraceable.

## 4. A correction that changed the conclusions

An earlier version of this analysis reported that about 5% of audits ended in an "improvement", and on that basis the programme's emissions effect looked too small to justify further analysis. Auditing that figure changed the picture in both directions.

The 5% was too generous in one way: nearly all of it was machines removed from site, counted as if their emissions had ended. Tracing serial numbers showed 56% of traceable removal events involved a machine working again at another audited site later (40% of distinct machines). It was too harsh in another way: it looked only at the enforcement route and completely missed the largest effect, the cleaner machines that registered fleets bring through the gate in the first place. It also mixed paperwork compliance into the emissions story: several hundred records became "compliant" through registration or exemptions with no emissions change at all.

The corrected accounting: 108 audits (0.9%) with a demonstrated emissions reduction; 132 more (1.1%) where the machine plausibly left the zone for good; 365 removals whose effect is unknowable with current data; and 362 exemptions plus 640 registration-only cases that should never be counted as emissions gains.

> **For technical readers.** Weighting by indicative NOx rather than counting audits (`enforcement_nox` in the model object): confirmed reductions are worth 0.10% of audited-fleet NOx, probable exits add 1.86% if counted as eliminated, and 5.59% hangs on the unresolved removals. The enforcement channel is therefore bounded between roughly 0.1% and 7.5% of fleet NOx depending entirely on removal fate, which argues for treating removal as displacement pending evidence, and for the registration database as the way to settle it. Retrofits are credited **zero** NOx here: the retrofits in this data are overwhelmingly diesel particulate filters, which abate PM rather than NOx, and crediting them as a stage change would be the largest single overstatement available in this dataset.
>
> Two definitions of the displacement rate are computed side by side in `removal_fate` because they answer different questions and earlier drafts of this report conflated them. Record-level (authoritative, and what the outcome taxonomy uses): 167 of 299 traceable removal *events* reappear, 55.9%. Machine-level: 98 of 243 distinct *machines* ever removed are seen after their first removal, 40.3%. Records exceed machines because repeatedly-removed machines contribute several records and are likelier to be seen again.

## 5. The policy's main effect: cleaner fleets arrive

Comparing the two arms at first sight of each machine, registered fleets arrive substantially cleaner. Over the whole period, 89.3% of registered machines were compliant at arrival against 80.8% of unregistered ones, a gap of 8.5 percentage points, and the gap holds within each policy phase (11% to 17% cleaner in emissions-intensity terms). Since registered and unregistered fleets turn out to renew their machines at the same rate once on site (section 6), this arrival gap is the clearest measurable footprint of the policy: operators sort their fleets before coming through the gate.

> **For technical readers.** Arrival emissions intensity (`arrival_ef` in the model object) is the unweighted per-machine mean of the stage limit at the machine's power band (9.2 g/kWh Stage I down to 0.4 at IV/V for 56-560 kW). It answers "how dirty is the average arriving machine", distinct from $EF_{\mathrm{fleet}}$ in section 7, which weights by engine size and usage. Excluding machines with pre-existing dispensations: 2.95 (warm) vs 3.44 (cold) g/kWh pooled, a 14.1% gap; by phase 10.9% (A1), 17.2% (A2), 13.8% (B). Including dispensation holders the pooled gap is 12.4%.
>
> These values supersede figures in earlier drafts (2.00 vs 2.38, phase gaps to 26%), which were produced with a stage-only emission factor vector that ignored engine power band. Band-resolved limits are the defensible basis and they compress the gap, because the EU standards are laxer for small engines: below 19 kW, Stages IIIA through V share the same NOx limit, so an upgrade buys nothing there. Selection effects cut the other way and remain conservative: cold machines were found by officers, so the true unregistered fleet is likely dirtier than measured.

## 6. How fast the fleet renews, and what changed in 2020

To project the future, we need the rate at which older machines get replaced by new ones. We estimate it from how much the fleet's engine-standard mix improves from one year to the next, assuming, as observed in practice, that a replaced machine is replaced by the newest standard on the market.

Two findings stand out. First, replacement roughly doubled when the requirements stepped up in September 2020: from about 10-12% of older machines replaced per year to about 23%. Second, the registered and unregistered fleets renew at statistically indistinguishable rates. The policy does not appear to make fleets upgrade faster on site; it changes which machines arrive (section 5).

The exception is generators. The constant-speed fleet shows no measurable upgrading at all: its estimated replacement rate is zero within measurement error, and its average engine standard has been flat since 2020.

> **For technical readers.** The model is a constrained Markov chain on stage states $s \in \{1,\dots,7\}$ with stage distribution $\pi_s(t)$ and fleet mean stage $m(t) = \sum_s s\,\pi_s(t)$. Each year a machine below the market-top stage $M(t)$ is replaced by $M(t)$ with probability $\bar p$, else unchanged ($M(t)$: variable-speed IV pre-2019 then V; constant-speed IIIA then V):
>
> $$
> \pi_s(t{+}1) =
> \begin{cases}
> (1-\bar p)\,\pi_s(t) & s < M(t) \\[4pt]
> \pi_s(t) + \bar p \displaystyle\sum_{r < M(t)} \pi_r(t) & s = M(t) \\[4pt]
> \pi_s(t) & s > M(t)
> \end{cases}
> $$
>
> This one-parameter matrix replaces the unidentifiable free 6x6 (36 parameters vs ~24 observations). Multiplying through by $s$ gives the mean-stage increment identity that links the observable yearly change to $\bar p$ via the below-target stage headroom $g(t)$:
>
> $$
> m(t{+}1) - m(t) = \bar p\, g(t), \qquad
> g(t) = \sum_{s < M(t)} \pi_s(t)\,\bigl(M(t) - s\bigr)
> $$
>
> $\bar p$ is then fitted by through-origin weighted least squares over adjacent calendar-year pairs $k = (t, t{+}1)$ within each era, with harmonic-mean weights reflecting the variance of a difference of two cell means:
>
> $$
> \hat{\bar p} = \frac{\sum_k w_k\, \Delta m_k\, g_k}{\sum_k w_k\, g_k^2},
> \qquad
> w_k = \frac{2}{1/n_t + 1/n_{t+1}},
> \qquad
> \operatorname{se}(\hat{\bar p}) = \sqrt{\frac{\sum_k w_k (\Delta m_k - \hat{\bar p}\, g_k)^2}{(K-1)\sum_k w_k g_k^2}}
> $$
>
> Two eras split at 1 Sep 2020. Fits: variable-speed era 1: 0.103 (se 0.029) cold, 0.116 (se 0.017) warm; era 2: 0.227 (se 0.024) vs 0.232 (se 0.040), arm difference z = 0.09; constant-speed era 2 pooled: -0.002 (se 0.004). Machine-level transitions could not be used: repeat sightings have a median gap of 15 days and symmetric stage flips (recording noise). Phase-stratified estimation was replaced by the two-era design after slope tests showed the apparent A1-to-A2 acceleration is explained mechanically by the jump of $M(t)$ from IV to V in 2019, which widens $g(t)$ at constant $\bar p$. Full derivation in `notes.md`; standard errors are unclustered (site-clustered bootstrap pending).

## 7. The fleet's emissions intensity

To express the fleet in emissions terms we compute an average emissions intensity: grams of NOx per kilowatt-hour of engine work (equivalently kg per MWh), which is the natural unit because engine standards are certified in exactly those terms. Each machine type contributes according to how many there are, how big their engines are, and how much they are used.

Usage is the honest weak point: hours-per-day estimates vary widely between sources. We therefore built the average so that only the *relative* usage between machine types matters, tested every assumption against its plausible range, and report the answer as a range. For the recent period the audited fleet averages about 2.5 g NOx per kWh, and cannot move outside roughly 2.0 to 3.0 whatever usage values are assumed. Only two assumptions materially move the answer: generator hours and excavator hours. Those two are worth sourcing properly; the other eleven types barely matter.

By group, the central-zone fleet (CAZ+) is cleanest at about 1.8 g/kWh, Rest of London about 2.2, and the constant-speed fleet (generators) worst at about 4.1, consistent with its stalled renewal.

> **For technical readers.** The fleet emissions intensity is a convex combination over machine types $\tau$:
>
> $$
> EF_{\mathrm{fleet}} = \sum_\tau s_\tau\, EF_\tau,
> \qquad
> s_\tau = \frac{N_\tau\, \overline{kW}_\tau\, u_\tau}{\sum_{\tau'} N_{\tau'}\, \overline{kW}_{\tau'}\, u_{\tau'}},
> \qquad
> u_\tau = \frac{h_\tau\, LF_\tau}{h_{\mathrm{exc}}\, LF_{\mathrm{exc}}}
> $$
>
> with $N_\tau$ the machine count, $\overline{kW}_\tau$ mean rated power, $h_\tau$ hours/day, $LF_\tau$ load factor (excavator base 8 h/day x 0.40), and $EF_\tau$ the power-weighted stage-limit NOx rate per type. Convexity bounds the result for any usage assumptions,
>
> $$
> \min_\tau EF_\tau \;\le\; EF_{\mathrm{fleet}} \;\le\; \max_\tau EF_\tau,
> $$
>
> and any common rescaling $u_\tau \to \lambda u_\tau$ cancels in $s_\tau$, so only relative usage between types matters. The 24 h/day physical cap tightens the generator bound and narrows the envelope to [2.00, 2.97] around a central 2.52 for phase B. One-at-a-time sensitivity: generator usage swings the answer by 0.49 g/kWh, excavator 0.26, all others under 0.1. Three placeholders are flagged in the code pending better inputs: stage limit values (verify against the EU regulation), machine counts N_t (audit counts pending the NRMM registration database), and usage hours (pending sourced estimates). The stage-limit EFs should ultimately be replaced by in-use emission factors from the EEA Guidebook 2023 (Tier 3, Ntziachristos & Samaras) for consistency with inventory practice such as LAEI 2022; retrofit credit additionally needs PM factors, since DPF retrofits abate particulates rather than NOx.

## 8. Looking ahead to 2030

Projecting the current replacement rates forward from the 2023-24 fleet mix: the variable-speed fleets reach roughly 90-93% compliance by 2030, with visible dips whenever the required standard steps up (January 2025 and January 2030), because the bar rises faster than fleets renew. The registered fleet stays a few points ahead of the unregistered fleet throughout, the same arrival gap carried forward.

The constant-speed fleet is the exception again: with a replacement rate of zero, its projected compliance against the Stage V requirement stays near zero through 2030. Under even the most optimistic statistical reading of its trend, it reaches only about 4%. On current behaviour, generator compliance will not happen by fleet turnover; it would need a targeted intervention (retrofit, exemption reform, or enforcement aimed specifically at generators).

These are projections, not measurements: after 2024 the data contains only 63 audits, so 2025-2030 is model behaviour under stated assumptions, shown in the dashboard with its uncertainty band and an adjustable replacement-rate slider.

> **For technical readers.** Projections evolve the pooled 2023-24 stage distribution per Machine Group x arm by iterating the transition matrix of section 6 annually with the era-2 $\hat{\bar p}$ (central and the 95% CI scenarios $\hat{\bar p} \pm 1.96\,\operatorname{se}$, clamped to $[0,1]$). Projected compliance evaluates the evolving distribution against the exact-date threshold schedule $\tau(G, t)$:
>
> $$
> \bar c(t) = \sum_{s \ge \tau(G,t)} \pi_s(t),
> \qquad
> EF(t) = \sum_s \pi_s(t)\, \overline{EF}(s)
> $$
>
> with $\overline{EF}(s)$ the observed power-weighted emissions rate of stage-$s$ machines (2023-24 band mix held fixed). The full projected stage vectors $\pi_1..\pi_7$ per year are in the model object and shown as stacked shares in the dashboard. The dashboard recomputes the projection recursion client-side and asserts exact agreement with the R results on load ("checks ✓"). Constant-speed projections use the pooled-arm p-bar, as the cold constant-speed cells (9-40 records/year) cannot support separate estimation; any treatment effect on generator replacement is structurally invisible at these sample sizes.

## 9. What we can and cannot say

**Can say:** the arrival gap between registered and unregistered fleets, with statistical support; the doubling of replacement after September 2020; the near-zero generator renewal; the small size of the demonstrated enforcement channel; and the fleet's emissions intensity within a defensible range.

**Cannot yet say:** how much removed machinery actually left London (about 40% of non-compliant removals are untraceable for lack of serial numbers); absolute emissions in tonnes (the audits reveal the fleet's percentage mix, not its total size, and multiplying uncertain hours, sizes and counts is exactly where such estimates go wrong); and anything fine-grained about the unregistered constant-speed fleet, which is too small a sample.

**Known assumptions that could shift results:** usage hours (bounded, see section 7); the choice to keep COVID-period records in the data (flagged as an open decision); and the audit-count stand-ins for true fleet composition, pending the registration database.

> **For technical readers.** The standing limitations register in `notes.md` also covers: ecological inference (aggregate cross-sections approximate individual replacement hazards, Robinson 1950); entry/exit bias (the chain absorbs fleet churn, violating time-homogeneity); unclustered standard errors (audits cluster within sites); and the definition change for compliance, which counts approved dispensations as legally compliant while the emissions layer keeps each machine's true stage EF, so legal compliance and emissions are never conflated.

## 10. What would strengthen this analysis most

In order of value: (1) machine counts by type from the NRMM registration database, which converts fleet shares into absolute populations and fixes the EF weights; (2) sourced hours-per-day for generators and excavators, the only two usage numbers that matter; (3) EEA Guidebook 2023 in-use emission factors to replace the stage-limit placeholders, plus PM factors to credit retrofits properly; (4) serial-number (TAN) capture at audit, which would settle the removal-displacement question that currently bounds the enforcement channel; and (5) a targeted look at generators, the one fleet segment the current policy demonstrably is not moving.

## 11. Where everything lives

- **Interactive dashboard:** `nrmm_dashboard_v4.html` (open in any browser; six views including a glossary), built by `nrmm_dashboard_v4.R`, which reads the model object only.
- **Model:** `nrmm_model_v4.R` builds everything from the raw audit file in one run; saved object `intermediate_data/nrmm_model_v4.rds`; results tables in `outputs/nrmm_model_v4.md`.
- **Superseded scripts** (`tree_dashboard_v2-v5.R`, `260717_ef_fleet_v1-v2.R`, `nrmm_model_v1-v3.R`, `nrmm_dashboard_v1-v3.R`) are retained as development history and carry a SUPERSEDED banner. They are not authoritative and some compute earlier definitions that give different numbers.
- **Methods documentation and decision log:** `notes.md` (parameter definitions, derivations, limitations, open decisions).
- **Sources referred to:** EU engine stage standards (Directive 97/68/EC; Regulation (EU) 2016/1628); EEA Guidebook 2023 emission factors (pending integration); LAEI 2022 as the inventory context; Robinson 1950 on ecological inference.

## 12. Cross-reference: where each figure comes from

Every quantity in this report is an object in `intermediate_data/nrmm_model_v4.rds`, produced by `nrmm_model_v4.R` and printed in `outputs/nrmm_model_v4.md`. To check a number, load the object in R and inspect the named element.

| Report claim | Section | Model object | Where computed |
|---|---|---|---|
| 11,643 in-scope audits; 9,622 warm / 2,021 cold | 1, 2 | `outcomes` | spine filter, "The classified spine" |
| Compliance at arrival 89.3% vs 80.8% | 1, 5 | `outcomes$c_bar` | Layer 1 |
| Arrival intensity 2.95 vs 3.44 g/kWh; gaps 10.9 / 17.2 / 13.8% | 1, 5 | `arrival_ef` | Layer 2b |
| 108 confirmed reductions; 132 exits; 365 unknowable; 362 exemptions; 640 admin-only | 1, 4 | `outcomes` (outcome_a..i, status_D) | Layer 1 |
| Displacement 55.9% of events / 40.3% of machines | 1, 4 | `removal_fate` | Layer 1d |
| Enforcement channel 0.10 / 1.86 / 5.59% of fleet NOx | 4 | `enforcement_nox` | Layer 1e |
| Replacement rates 0.103-0.116 (era 1), ~0.23 (era 2), ~0 constant-speed; z = 0.09 | 1, 6 | `pbar`, `pairs` | Layer 3 |
| Fleet intensity 2.52 g/kWh, range [2.00, 2.97]; CAZ+ 1.77, RoL 2.16, CS 4.12 | 1, 7 | `ef_results` | Layer 2 |
| Usage sensitivity: generator 0.49, excavator 0.26 g/kWh swing | 7 | `strata`, `usage_table` | Layer 2 (one-at-a-time analysis in `outputs/260717_ef_fleet_v2.md`) |
| 2030 compliance 0.90-0.93; constant-speed 0.000 (0.038 optimistic) | 1, 8 | `projections` | Layer 3 |
| Stage mix by year and arm | 8 | `stage_populations`, `projections` (pi_1..pi_7) | Layers 1c, 3 |
| Threshold schedule by group and year | 2, 8 | `threshold_schedule` | Layer 3 |

Two figures carried in the text come from analyses outside the model object and are labelled as such where they appear: the ~1% symmetric stage-flip rate that rules out machine-level transition estimation (section 3), and the one-at-a-time usage sensitivity (section 7, in `outputs/260717_ef_fleet_v2.md`).

**Figures that changed in this revision.** Earlier drafts quoted an arrival gap of 16% (now 14.1%), phase gaps up to 26% (now 10.9-17.2%), a displacement rate of 43% (now stated as 55.9% per event or 40.3% per machine), ~390 unknowable removals (now 365), and NOx shares of 0.2/2.6/7.4% (now 0.10/1.86/5.59%). The causes are documented in the technical boxes of sections 4 and 5: the arrival figures previously used a stage-only emission factor ignoring engine power band; the displacement figure previously mixed two counting units; and the NOx shares previously credited particulate retrofits as if they cut NOx.
