# Staff-Eng Anti-Pattern Catalog (template)

Your personal review bar — the patterns you'd reject manually that AI-generated changes have slipped past you. Read by the `staff-eng-pre-flight` skill (dimension 0) and the standing AI-diff self-review rule.

**Copy this to `~/.claude/staff-eng-antipatterns.md` and seed it from real misses.** Every time one slips through and gets caught later, add it here — the same class should never slip twice.

How to use: for each diff, ask the **Check** question for any entry whose **Tell** matches the change shape. A hit is a `FIX` in the pre-flight lens.

---

## AP-1 — <short name>

**Lesson:** <the generalizable rule, in your own words>

**Concrete:** <the real change that slipped past you, with a source link (PR/commit)>

**Tell:** <the diff shape that should make you ask the Check question>

**Check:** <the question to ask — phrased so a "no" is a FIX>

---
<!-- Add entries as AP-2, AP-3, … Keep the same fields: Lesson / Concrete (source) / Tell / Check. -->
