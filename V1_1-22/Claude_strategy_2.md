Revised recommendations for Claude Code CLI:

![image-20260401181048100](/Users/iarla/Coding/260329_nrmm_model/image-20260401181048100.png)



**1. Use iterative sprints.** One sprint = one analytical question = one Claude Code session.

**2. Structure your project directory around Claude Code's memory architecture.** Claude Code supports a cascaded file layout -- use it deliberately:

```
project/
├── CLAUDE.md              # loaded every session automatically
├── CLAUDE.local.md        # personal prefs, gitignored
└── .claude/
    └── rules/
        ├── data.md        # dataset schema, variable codebook
        └── analysis.md    # current objectives, decisions log
```

**3. Keep `CLAUDE.md` minimal and stable.** Target under 200 lines; longer files consume more context and reduce adherence. Put only what is needed in every session: dataset path, R version, package conventions, and a pointer to the rules files. Do not put the evolving objectives here.

**4. Put the living project brief in `.claude/rules/`.** Rules files can be scoped to specific file paths so they only load into context when Claude works with matching files, reducing noise and saving context space. Keep `analysis.md` for objectives and decisions; update it after each sprint. This separates stable conventions (CLAUDE.md) from evolving research state (rules).

**5. Use `/clear` between sprints, not `/compact`.** `/compact` summarises the session but loses context fidelity; use it only when the context window is nearly full and you need to continue the same task. For new tasks, `/clear` is correct. Each new analytical question is a new task -- clear and start fresh.

**6. Let auto memory handle incidental learning.** Auto memory lets Claude accumulate knowledge across sessions without you writing anything -- build commands, debugging insights, code style preferences. Do not manually replicate what auto memory will capture (R idioms, your preferred plot style). Reserve your manual writing effort for research-specific content that Claude cannot infer.

**7. Put dataset schema in a referenced doc, not inline.** `CLAUDE.md` can reference other files using `@` notation; the referenced file is inserted into context as a separate entry. Store `str(df)` output and variable definitions in `docs/schema.md` and reference it with `@docs/schema.md` in `CLAUDE.md`. This keeps the main file short while the schema is always available.

**8. Scope each session with an explicit task statement at the prompt.** Even with CLAUDE.md loaded, open each sprint with one sentence: the analytical question, the relevant variables, the expected output (script only, or script plus interpretation). Claude Code's agentic behaviour benefits from an unambiguous entry point.

**9. Use `docs/` with checkboxes for the sprint backlog.** Track tasks with `[ ]` checkboxes in markdown files; Claude Code can check them off for you. Maintain `docs/sprint-log.md` with each sprint's question, result summary, and whether objectives were updated. This replaces the manual two-sentence log from the previous recommendations and integrates with the tooling.

**10. Monitor token usage with `/cost` mid-session.** Check `/cost` at regular intervals (every 30-45 minutes of work); if over 50k tokens, use `/compact` before finishing. For your workflow, a session approaching that size is a signal the sprint scope was too broad -- note it and split more aggressively next time.



## How to setup a sprint

`analysis.md` is loaded automatically by Claude Code at every session start because it sits in `.claude/rules/`. Its content is always in context without you doing anything. It provides standing state: locked parameters, decisions, limitations, phase boundaries.

The sprint prompt is what you type at the start of a session. It is not stored anywhere -- it is the question from the backlog in `sprint-log.md`, translated into the four-element format from the scoping guidance: question, relevant columns, expected output, constraints. For example:

> Construct P_Total for each group using locked λ_CF values from analysis.md. Enforce max_stage active dimensions per group (CS=3, CAZ+=5, RoL=6). Apply floor-and-rescale if any λ_Proactive row is negative. Verify all rows sum to 1. Output: print matrix per group to console. Script: 260401_step5_matrix.R.

You write that at the prompt. Claude Code then has both the standing context from `analysis.md` (locked values, group definitions, phase structure) and the specific task from your prompt. You do not need to repeat what is already in `analysis.md` -- that is the point of having it auto-loaded.

The `sprint-log.md` backlog entries are reminders to yourself of what each sprint needs to accomplish, not the prompts themselves. They are one level of abstraction above the actual prompt -- you read the backlog entry, then compose the scoped prompt from it.





## How to update

**`sprint-log.md`** -- let Claude Code do it. Ticking the checkbox and writing the two-sentence result entry is mechanical and low-stakes. At the end of a sprint, ask Claude Code to update the log:

> Update sprint-log.md: tick Sprint 7, result: [one sentence on what the matrices look like], [one sentence on any objective impact].

Claude Code will edit the file directly. You review and keep or adjust.

**`analysis.md`** -- you should draft the decision, Claude Code can write it. When a sprint produces something that changes the research state -- a revised parameter, a new constraint, a flagged limitation -- you know what needs to change, but you may not want to phrase it precisely. A good pattern:

> Add to the decisions log in analysis.md: we found X, consequence is Y, rationale is Z. Draft the entry for my review before writing.

Claude Code drafts it, you approve, then it writes. This keeps you in the decision loop. Parameters and decisions in `analysis.md` are load-bearing -- an error written there propagates into every subsequent sprint via auto-load. The extra review step is worth it.

The general principle: let Claude Code handle the mechanical writing (checkboxes, formatted log entries, schema updates when columns are confirmed), but stay in the loop on anything that affects downstream estimation or interpretation.