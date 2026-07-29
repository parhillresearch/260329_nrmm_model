# Six quick questions about the audit data

**Should take about two minutes. Just tick a box for each one.**

---

Hello,

A quick update on the NRMM data analysis, which I've been quietly running in the background with help of an AI. The analysis of the audit records is going pretty well, and most of it holds together nicely and is demonstrating the value of the auditing and the programme. But I need your hekp with a few simple questions (I think simple!!).

**Two things are already clear: sites that register their machines bring cleaner machines on site than those that don't, and machines got replaced about twice as fast after the rules tightened in September 2020.** If you'd like to look at the numbers yourself, there's an interactive summary attached (`nrmm_dashboard_v6.html`). Open it in any browser, nothing to install. The "Data queries" tab shows exactly what Question 1 is about. Please treat anything labelled "Constant Speed" as not settled yet, since that's what Question 1 is about.

---

## Question 1: generators, and the "Engine Type" box

This is an area where I'm struggling the most, in terms of exactly how to handle gernators and other sometimes constant speed things. I've tried being clever, but the risks of polluting the data by trying to guess whether a machine is

**What I see:** 218 generators are at **Stage V**. Not one has "Engine Type" set to **Constant** (215 say **Variable**, 3 say **Unidentified**). Older generators at **Stage IIIA** mostly say **Constant**, about 8 in 10.

**Why I'm asking:** the "Engine Type" box decides which group a machine goes into, and each group has a different Stage it has to meet.

**For a generator, what should the "Engine Type" box say?**

- [ ] **A.** Always **Constant**. If a generator says Variable, that's a slip.
- [ ] **B.** It depends on the machine. Some generators really are Variable.
- [ ] **C.** We put whatever the engine plate or paperwork says, so it varies.
- [ ] **D.** The way we fill this box changed at some point. Roughly when? `______`
- [ ] **E.** Something else: `________________________________`

**One extra tick if you can:** for a **Hybrid Generator** or **Flywheel Generator**, should the box say Constant or Variable?

- [ ] Constant  - [ ] Variable  - [ ] Either, depends on the unit

---

## Question 2: crushers, and the same box

**What I see:** 15 crushers have "Engine Type" set to **Constant**, and all 15 are older machines. Every newer crusher says **Variable**.

**Should a crusher ever be Constant?**

- [ ] **A.** No. Crushers are always **Variable**.
- [ ] **B.** Yes, some crushers are **Constant**. What makes the difference? `______________`
- [ ] **C.** Not sure, it probably varies between auditors.

---

## Question 3: the word "Uncertified" in the Stage box

**What I see:** 25 machines have **Uncertified** written where the Stage would normally go.

**What does Uncertified mean when you write it?**

- [ ] **A.** The engine has no emissions certificate at all.
- [ ] **B.** It probably has one, but we couldn't see or check it on the day.
- [ ] **C.** Both happen, and you can't tell which from the record.
- [ ] **D.** Something else: `________________________________`

---

## Question 4: "Inappropriate for Audit"

**What I see:** 131 records say **Inappropriate for Audit** in the Machine Type box. I already leave out the ones that say **No NRMM**.

**Should I leave the "Inappropriate for Audit" ones out too?**

- [ ] **A.** Yes, leave them out. They shouldn't be counted as machines.
- [ ] **B.** No, keep them. They are real machines.
- [ ] **C.** Depends: `________________________________`

---

## Question 5: "Baselining"

**What I see:** 710 records say **Baselining** in the compliance box, where I would normally see Compliant or Non-compliant. They only appear in 2024 (254) and 2025 (456), never before.

**What is a Baselining visit?**

- [ ] **A.** A first visit to a new site, to record what is there before the rules are applied.
- [ ] **B.** A survey of machines that are outside the scheme, for information only.
- [ ] **C.** A new way of recording something we were already doing before 2024.
- [ ] **D.** Something else: `________________________________`

**And should these machines count in the compliance figures?**

- [ ] Yes, count them  - [ ] No, leave them out



---

## Question 6: does a TAN always mean the same machine?

**What I see:** I tried filling in blank boxes by looking up the same **TAN** on another visit. It works, but the answers often disagree. Where a machine's **kW Power** was blank and another visit had it, the other visits gave *different* kW figures for the same TAN in 161 cases out of 196. Stage disagreed on 35 out of 138.

**Which of these is closest to the truth?**

- [ ] **A.** A TAN belongs to one machine for life. If the figures differ, someone mistyped one.
- [ ] **B.** A TAN can be reused, moved to another machine, or re-issued.
- [ ] **C.** The TAN is right, but kW and Stage are often estimated rather than read off the plate.
- [ ] **D.** Something else: `________________________________`

**If a machine's details are blank on one visit, is it safe for me to copy them from another visit of the same TAN?**

- [ ] Yes  - [ ] No  - [ ] Only for some fields: `______________________`

---

## Things I am assuming

These are my own choices, not anything you told me. Tick any that are wrong and I will change them.

- [ ] Records saying **No NRMM** are left out altogether.
- [ ] **Removed from site** means the machine left that site, not that it was scrapped.
- [ ] If a **TAN** turns up later at a different site, that is the same machine having moved.
- [ ] Where the box says **Site Complete**, **No Apparent Works** or **DECLINED AUDIT**, no machine was assessed, so I count it as neither a pass nor a fail.
- [ ] Where **kW Power** is blank, I use the usual figure for that type of machine. Where it is a range, I use the middle.
- [ ] When a machine is swapped during an audit, the new one is the newest **Stage** on sale at the time.
- [ ] I am taking **Engine Type** exactly as recorded, until you tell me otherwise (Questions 1 and 2).
- [ ] I have left **2025** records out for now, because the zone rules changed.

---

That's everything. If it's easier to say it out loud than write it down, I'd happily take fifteen minutes on a call instead, and I can talk you through what the numbers are showing while I'm at it.

Thanks very much,



Iarla



## Nothing needed from you on these

Three other things came up. I've sorted them out at my end and I'm not asking you to do anything about them. Listing them only so you know I've spotted them:

- For now I am treating anything logged as **Electric** as a **ZE**.
- **TAN numbers** only start appearing in the records from 2021. I use them to see if a machine removed from one site turns up on another, so I only look at 2021 onwards.
- **A few machines** show a different Stage on different visits. It's about 30 machines out of 600, so I've allowed for it.
- **23 older records** say **Pending** in the final box. I count those as *not put right*, which may be unfair to a couple of them.
- **952 visits** ended as **Site Complete**, **No Apparent Works** or **DECLINED AUDIT**, so no machine was actually assessed. I don't count those as passes or failures. They do look worth counting in their own right, as a measure of visits that didn't get anywhere, so I plan to report them separately. They peaked in 2020 and 2021 (274 and 257) and again in 2025 (187).
