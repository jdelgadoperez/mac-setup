---
name: review-verify-anchors
description: Verify inline PR comment line anchors before posting
---

# .claude/skills/review-verify-anchors/SKILL.md

---

name: review-verify-anchors
description: Verify inline PR comment line anchors before posting

---

1. For each pending inline comment sidecar, re-read the target file at the anchor line.
2. Confirm the line content matches the comment context AND the line is within the PR diff range.
3. If mismatched, re-snap to the correct file line (not diff line).
4. Report verification table before posting.
