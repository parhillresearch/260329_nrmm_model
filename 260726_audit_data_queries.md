> **SUPERSEDED — do not send.**
> merged into 260728_auditor_questions.md, which combines the covering note and the
> questions into one document with no duplication, written as tick-box choices.
> Retained as drafting history.

# A few things I'd like to check with you about the audit data

**26 July 2026 | NRMM LEZ data analysis**

Hello,

I've made some solid progress on the analysis of the NRMM audit records, and it's going well — there's a clear story emerging about how the fleet has changed since 2016. Along the way I've noticed a few recording patterns I can't interpret from the data alone, and I'd rather ask than guess, because in most cases I suspect there's a practice or piece of guidance I simply don't know about.

Nothing below is a criticism of the recording. The figures are just what I'm seeing, and where a pattern has an obvious explanation from your side it would save me a lot of second-guessing. I've put the ones that most affect my results first.

---

## 1. Engine Type on generators

This is the one I'd most value your view on, because it decides which Machine Group a generator falls into, and therefore which standard applies.

Among the 218 generators recorded at Stage V, none carries Engine Type "Constant". Among Stage IIIA generators audited in the same years, 80% do (303 of 379). I do realise not every generator runs at constant speed — hybrid, flywheel and flybrid units in your data split 37 "Constant" to 51 "Variable", which looks deliberate. But 17 of roughly 85 repeat-audited generators carry both labels at different visits, and median engine size is nearly identical either way (132 kW against 137 kW).

- Is there written guidance on setting `Engine Type` for a generator, and did it or its interpretation change around 2022, when Stage V units started appearing?
- Does the Stage V type-approval paperwork state constant or variable speed, and is that wording what gets transcribed?
- Should a genset running at fixed rpm for mains-frequency power be "Constant" regardless of how the certificate is worded?
- For hybrid, inverter or flywheel units, which label do you intend?
- On a repeat visit, is `Engine Type` re-read from the plate or carried forward from the previous record?
- Is the field used on site to decide which standard applies, or recorded for reference?

## 2. Engine Type on crushers

A similar shape, on smaller numbers. Of 129 crusher records, 15 are "Constant" and all 15 are Stage IIIA; all 76 crushers at IIIB, IV and V are "Variable". Median engine size is again close (218 kW against 202 kW), and the "Constant" label turns up in ones and twos across most years rather than in a block.

- Would you expect any crusher to be constant speed, or is "Variable" right for all of them?
- If some genuinely are, what would distinguish them on site?

## 3. "Electric" in the emissions stage field — ANSWERED, thank you

*Confirmed 28 July 2026: "Electric" means zero emission. These 31 records are now counted as
stage ZE rather than dropped, which is how they should have been treated all along. Left here
so the trail is complete.*

## 4. "Uncertified" as an emissions stage

Twenty-five records have "Uncertified" in the initial stage field and 26 in the final stage field.

- Does "Uncertified" mean the engine carries no type approval at all, or that approval couldn't be confirmed at the time of the audit?
- Should I treat these as below the lowest stage, or as unknown?
- Is there a compliance consequence on site for an uncertified engine that I should be reflecting?

## 5. Machine Type wording

I've handled the capitalisation variants at my end ("Mewp" and "MEWP" are now the same thing). One question remains: I see "Inappropriate for Audit" on 131 records, and "No NRMM" on 891.

- Should "Inappropriate for Audit" be treated as out of scope, the way I exclude "No NRMM"?
- Is `Machine Type` picked from a list, or typed? If it's typed, are there other labels you'd expect me to treat as the same thing?

---

A few other things I noticed I've simply catalogued as known quirks rather than bothering you with: serial numbers only being captured from 2021, a handful of machines recorded at different stages on different visits, and 23 older records left as "Pending". They're written up in my data dictionary and I've allowed for them.

I'm very happy to work to whatever convention you intend — I just want to apply it consistently rather than invent my own. A quick reply on any of these, or a pointer to existing guidance, would be a big help. And if it's easier to talk it through, I'd welcome half an hour whenever suits.

Thanks very much,
