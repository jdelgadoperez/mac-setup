# Check Mode Before Mutating

**Always confirm the current execution mode before any externally-visible mutation, regardless of prior approvals.**

## The rule

Before any of the following actions, stop and confirm the current mode (plan mode? auto mode? normal?) AND that the user has given an explicit go-ahead for *this specific action* — not just for "the plan":

### Externally-visible mutations
- Posting GitHub reviews, PR comments, issue comments (`gh pr review`, `gh api POST .../reviews`, `gh api PATCH .../pulls/...`)
- Editing PR descriptions or titles
- Creating/transitioning issue tracker tickets (Jira, Linear, etc.)
- Posting Slack messages or other chat platform messages
- Creating/editing Notion pages or other wiki writes
- Pushing to remote (`git push`)
- Merging PRs (`gh pr merge`)
- Creating/dismissing reviews
- Triggering deploys or other CI/CD mutations

### Local mutations that need mode awareness
- Writing/editing files outside the plan file (in plan mode this is forbidden)
- Running tests, builds, lint, format that modify files
- `git commit`, `git rebase`, `git reset`

## Why

`ExitPlanMode` approval means "the plan is approved." It does NOT mean "post / push / create everything in the plan unattended." Externally-visible mutations need a separate, explicit go-ahead immediately before they happen — show the dry-run + payload + target, then wait for "post it" / "send it" / "go" / explicit confirmation.

Plan mode existing alongside auto mode adds confusion: auto mode says "execute autonomously," but plan mode (when active) overrides that. Always check which is active right now, not which was active when the conversation started.

## Pre-mutation checklist

Run this sequence in your head every time:

1. **What mode am I in?** Plan mode? Auto mode? Normal?
   - Plan mode: I cannot mutate anything outside the plan file. Period.
   - Auto mode: I can take low-risk actions, but externally-visible ones still need explicit opt-in.
   - Normal: Same as auto for risky actions — confirm before externally-visible mutations.
2. **Did the user explicitly approve THIS action, in this turn, with full visibility into what I'm about to do?**
   - "Approved the plan" ≠ "post the PR review now"
   - "Looks good" on a draft ≠ "send it to Slack now"
   - "Yes" to a clarifying question ≠ blanket authorization for all subsequent mutations
3. **Have I shown the exact dry-run / payload / target?**
   - The user should see what I'm about to send, where, and as whom.
4. **Is there a fresher state I should re-check first?**
   - Has HEAD moved? Is the PR still open? Did the user push fixes since?

If any answer is "no" or "unsure" — stop and ask before mutating.

## Anti-patterns

| Anti-pattern | Correct behavior |
|--------------|------------------|
| Treat ExitPlanMode approval as authorization to post/push | ExitPlanMode = plan approved. Posting needs a separate explicit "post it." |
| Treat auto mode as "post anything that fits the plan" | Auto mode is for autonomous low-risk work. Externally-visible = always confirm. |
| "The user said yes 5 messages ago, that covers this post" | Authorization stands for the scope specified, not beyond. Re-confirm for each mutation event. |
| Skip the dry-run because the payload was shown earlier in the plan | Show again right before posting — content may have shifted. |
| "I already exited plan mode, now anything goes" | Mode transitions don't grant blanket mutation rights. |

## When in doubt

Ask. The cost of a one-line confirmation prompt is near-zero; the cost of an unwanted PR comment / Slack message / dismissed review / accidental push is high (visible to others, hard to fully undo, sometimes embarrassing).
