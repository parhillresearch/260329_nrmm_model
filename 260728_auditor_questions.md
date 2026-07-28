# Four quick questions about the audit data

**Should take about two minutes. Just tick a box for each one.**

---

Hello,

Thanks for asking for an update. The analysis of the audit records is going well, and most of it holds together nicely. Two things are already clear: sites that register their machines bring cleaner machines on site than those that don't, and machines got replaced about twice as fast after the rules tightened in September 2020.

Before I finish, there are four things in the data I can't work out on my own. In each case I think there's probably a rule or a habit that I don't know about. I'd rather ask than guess and get it wrong.

To be clear, I'm not saying anything has been recorded badly. I've found and fixed several mistakes of my own along the way. I just need to know what you meant, so I treat the records the way you intended.

For now I am treating anything logged as **Electric** as a **ZE**.

---

## Question 1: generators, and the "Engine Type" box

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

## Nothing needed from you on these

Three other things came up. I've sorted them out at my end and I'm not asking you to do anything about them. Listing them only so you know I've spotted them:

- **TAN numbers** only start appearing in the records from 2021. I use them to see if a machine removed from one site turns up on another, so I only look at 2021 onwards.
- **A few machines** show a different Stage on different visits. It's about 30 machines out of 600, so I've allowed for it.
- **23 older records** say **Pending** in the final box. I count those as *not put right*, which may be unfair to a couple of them.

---

## Things I am assuming

These are my own choices, not anything you told me. Tick any that are wrong and I will change them.

- [ ] Anything logged as **Electric** counts as **ZE**.
- [ ] Records saying **No NRMM** are left out altogether.
- [ ] **Removed from site** means the machine left that site, not that it was scrapped.
- [ ] If a **TAN** turns up later at a different site, that is the same machine having moved.
- [ ] Where the box says **Baselining**, **Site Complete**, **No Apparent Works** or **DECLINED AUDIT**, no judgement was being made about that machine, so I do not count it as a pass or a fail.
- [ ] **Mewp** and **MEWP** are the same thing, and likewise **Piling rig** and **Piling Rig**.
- [ ] Where **kW Power** is blank, I use the usual figure for that type of machine. Where it is a range, I use the middle.
- [ ] When a machine is swapped during an audit, the new one is the newest **Stage** on sale at the time.
- [ ] I am taking **Engine Type** exactly as recorded, until you tell me otherwise (Questions 1 and 2).
- [ ] I have left **2025** records out for now, because the zone rules changed.

---

That's everything. If it's easier to say it out loud than write it down, I'd happily take fifteen minutes on a call instead, and I can talk you through what the numbers are showing while I'm at it.

Thanks very much,

---

*If you'd like to look at the numbers yourself, there's an interactive summary attached (`nrmm_dashboard_v6.html`). Open it in any browser, nothing to install. The "Data queries" tab shows exactly what Question 1 is about. Please treat anything labelled "Constant Speed" as not settled yet, since that's what Question 1 decides.*
