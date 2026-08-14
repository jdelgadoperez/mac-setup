---
allowed-tools: none
description: Shape a brief task description into a well-formed prompt using Anthropic's AI Fluency 4D framework — Delegation, Description, Discernment, Diligence — with mode-specific output (Automation / Augmentation / Agency).
argument-hint: "<brief description of what you want to do>"
---

# Shape Prompt (4D)

Turn a brief, informal task description into a well-formed prompt, using Anthropic's **AI Fluency Framework** (Delegation, Description, Discernment, Diligence — the "4Ds" — see https://www.anthropic.com/ai-fluency/conclusion). This is a single-shot reformatting utility: no fan-out, no external mutation, nothing to approve.

The brief description is passed as `$ARGUMENTS`. If empty, ask the user for one sentence describing what they want to do, then stop and wait — do not proceed on a guess.

## What the 4 D's mean here

- **Delegation** — deciding what work to do with AI vs. yourself, and *how* — this includes picking the mode of engagement (see below). Not every brief survives this check unchanged.
- **Description** — communicating clearly with the AI system: the actual prompt-writing.
- **Discernment** — evaluating AI outputs and behavior with a critical eye: what "good" looks like, what to check before trusting the result.
- **Diligence** — ensuring the interaction is responsible: transparency, sensitive-data handling, sign-off — scaled to how much autonomy was delegated.

## The three modes (Delegation decides which one applies)

| Mode | What it is | Output shape |
|------|-----------|--------------|
| **Automation** | AI executes a specific, well-defined task based on your instructions | One polished, ready-to-paste prompt |
| **Augmentation** | You and AI collaborate as thinking/task partners, back-and-forth | An *opening* prompt that invites iteration, not a final ask |
| **Agency** | AI works independently on your behalf across a class of future tasks, guided by behavior/knowledge you establish rather than one-off instructions | A behavior/scope spec — boundaries, autonomous-decision limits, escalation triggers |

Stakes rise from Automation → Augmentation → Agency: the same 4 competencies apply, but Diligence in particular gets harder as the human reviews less of the output individually.

## Procedure

Work through the brief in this order. Do not skip a D even if it seems trivially satisfied — write one line for it either way.

### 1. Delegation — decide what to hand off, and which mode

Read the brief and decide:
- **Is any part of this NOT AI-appropriate?** A decision only the user can make, an action with real-world consequences, authority/context the AI can't have. If the brief bundles something that shouldn't be delegated wholesale, say so and propose splitting it: the part safe to hand off vs. the part the user should keep or review before acting.
- **Which mode fits the delegated part?**
  - Is the task a single, well-defined, bounded action with a known process? → **Automation**.
  - Is the problem or solution ambiguous, benefiting from back-and-forth, challenge, and refinement over multiple turns? → **Augmentation**.
  - Is the user trying to configure AI to handle an ongoing *class* of future tasks autonomously, not just this one instance? → **Agency**.
- State the mode decision in one line, with the reason. If the brief is genuinely ambiguous between two modes, pick the lower-autonomy one (Automation over Augmentation, Augmentation over Agency) and say why — default to the mode that keeps more human review in the loop, don't default up.

The chosen mode determines which output template to use in step 2 and how much weight step 4 (Diligence) carries.

### 2. Description — draft the prompt, using the six foundational techniques

Prompt engineering here means designing clear instructions using these six techniques. Apply each one that's relevant — don't skip one just because it takes more thought; a missing example or missing constraint is usually why a first-draft prompt fails:

1. **Give context** — what you want, why, and relevant background, so the reader doesn't have to re-derive it
2. **Show examples** — demonstrate the desired output style/format if one exists or can be sketched
3. **Specify constraints** — format, length, tone, scope boundaries, what's explicitly out of scope
4. **Break complex tasks into steps** — if the task has multiple stages, guide the reasoning order explicitly
5. **Ask the AI to think first** — for non-trivial tasks, give explicit room to reason before producing the final output
6. **Define role or tone** — how the AI should communicate (e.g., "senior engineer voice," "terse," "explain like to a junior dev")

Now draft using the template for the mode chosen in step 1:

- **Automation template** — a single complete, ready-to-paste prompt: context, task, constraints, output format, examples/steps/think-first/role as applicable. This is the final ask, not a conversation starter.
- **Augmentation template** — an opening prompt for a multi-turn collaboration: state the goal and known context, but explicitly name what's still undecided, invite the AI to challenge assumptions or propose alternatives, and avoid over-specifying the output shape since it will change through iteration.
- **Agency template** — a scope/behavior spec, not a single-turn prompt: the objective, the boundaries of what the AI may decide autonomously, concrete triggers for when it must stop and escalate to a human, and the knowledge/context it should draw on for the whole class of tasks (not just one instance).

Keep it as short as it can be while still being unambiguous — don't pad with boilerplate the target model doesn't need.

**The "secret weapon" (offer, don't force):** after drafting, note to the user that they can hand this draft back to Claude with "how would you improve this prompt?" before using it — asking the AI itself to refine the prompt is a named technique, not just optional polish. Mention this as a one-line suggestion under the output; do not spend an extra turn doing it unless asked.

### 3. Discernment — how to evaluate the output

Add a short "how to check this" note: 2-4 concrete things to verify before trusting or using the result. Tie these to the mode:
- **Automation** — check against the success criteria/constraints named in step 2, directly.
- **Augmentation** — check whether the AI's pushback or alternatives in the first turn actually surfaced something useful, not just compliance; if it just agreed and executed, the ambiguity that justified Augmentation probably wasn't real.
- **Agency** — check whether the escalation triggers are concrete enough to actually fire (vague triggers like "if something seems wrong" don't work), and whether the scope boundaries are testable, not aspirational.

Don't invent generic QA checklist filler — every line here should trace back to something specific in the drafted prompt/spec.

### 4. Diligence — responsible-use flags, scaled to mode

Diligence gets more substantial as the mode moves toward more autonomy — don't apply the same two-line footnote regardless of mode:

- **Automation** (lightweight — one output, individually reviewed): does it need an "AI-assisted" disclosure when shared? Does it touch sensitive/confidential data that constrains where the prompt/output can go?
- **Augmentation** (moderate — ongoing collaboration, more surface area): same as above, plus — is there a point in the back-and-forth where the human needs to explicitly own a decision the AI proposed, rather than letting it pass by consensus?
- **Agency** (substantial — outputs won't be individually reviewed): same as above, plus — who is accountable for outputs produced autonomously under this spec? Is there a periodic human review point, not just escalation-on-trigger? Is the scope narrow enough that "vouching for it" is actually credible?

If none apply even after considering the mode, say "No diligence flags" — don't fabricate one to seem thorough.

## Output

Render exactly this structure back to the user:

```
## Shaped Prompt — [Automation | Augmentation | Agency]

<the drafted prompt/spec from step 2, using the template for the chosen mode>

---

**Delegation:** <mode + one-line reason from step 1>
**Discernment — check before trusting this:** <bullets from step 3>
**Diligence:** <line(s) from step 4, or "No diligence flags">

*Tip: hand this back to Claude with "how would you improve this prompt?" before using it.*
```

Nothing else — no preamble, no restating the brief, no closing summary. The shaped output block is the deliverable.
