Here are the recommendations:

**1. Use iterative sprints.** Each sprint: one clearly scoped analytical question, one R script, review, update objectives if needed, repeat. Do not write scripts for future analyses until the preceding one is reviewed.

**2. Maintain a living project brief (one plain text file).** Keep it outside Claude: dataset description (16k rows, 30 cols, key variable definitions), current research objectives (numbered, dated when revised), variable codebook, and decisions already made. Paste the relevant excerpt into every new Claude session rather than relying on context continuity.

**3. Treat each Claude conversation as stateless.** Context bloat is the main efficiency killer. Start a new conversation for each new script. Open with: the project brief excerpt, the specific analytical question, the relevant variables, and any output from the previous script that informs this one. Never carry a long session forward just to "preserve context."

**4. Scope script requests atomically.** One conversation = one script = one analytical question. "Analyse the relationship between X and Y, controlling for Z, produce a plot and a summary table" is the right granularity. "Do all the demographic analyses" is not.

**5. Provide schema and sample data, not prose descriptions.** Paste `str(df)` output and 5-10 rows of relevant columns. Claude will produce correct column names, appropriate data types, and idiomatic R on the first attempt. Prose descriptions of structure introduce ambiguity and require correction rounds.

**6. Separate EDA from confirmatory analysis.** Run two or three open-ended exploratory sessions first to stabilise your understanding of the data structure, distributions, and anomalies. Only then lock down the confirmatory objectives. Premature confirmatory scripting on poorly understood data is the root cause of the objective drift you have already experienced.

**7. Version the objective document after each sprint.** Date-stamp a brief note: what changed, why, what prior scripts are affected. This keeps the research defensible and tells you whether a prior script needs rerunning with new logic.

**8. Use Claude for script drafting and logic, not for iterative debugging.** Run the script locally. If it errors, paste the error and the relevant code section into a new focused conversation. Do not continue pasting errors into a long session; each error conversation becomes a large context with diminishing relevance.

**9. Plan the analysis sequence top-down before each sprint.** Spend 10-15 minutes sketching: what question, what method, what output is needed, what decisions depend on the result. Write this in the project brief. Then request the script. This prevents mid-script scope changes that force rewrites.

**10. At the end of each sprint, write two sentences in the project brief:** what the script found, and how it affected the next objective. This becomes the handoff context for the next Claude session and keeps the cumulative record compact and accurate.

![image-20260401180017795](/Users/iarla/Coding/260329_nrmm_model/image-20260401180017795.png)



The diagram shows the sprint loop. The living brief is the connective tissue across stateless Claude sessions; the sprint log closes each loop.