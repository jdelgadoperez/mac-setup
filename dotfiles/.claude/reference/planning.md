## Planning Workflow

### Default Plan Storage

For repositories and projects, always store implementation plans in `.llm/plans/`:

1. **Create the directory**: If `.llm/plans/` doesn't exist in a repository, create it when starting complex tasks.
2. **Plan structure**: Store detailed markdown documents that outline:
   - Implementation approach
   - Architecture decisions
   - Task breakdowns
   - Technical considerations
   - Dependencies and prerequisites
   - Testing strategies

3. **Naming conventions**:
   - Feature plans: `feature-name-plan.md`
   - Refactoring: `refactor-component-plan.md`
   - Bug fixes: `bug-description-plan.md`
   - Date-stamped: `YYYY-MM-DD-task-description.md`

4. **Version control**: Plans should be committed to git to:
   - Track decision-making over time
   - Maintain project knowledge
   - Enable collaboration and review
   - Document reasoning for future reference

### When to Create Plans

Create a plan document when:
- Task involves multiple components or files
- Requires architectural decisions
- Has multiple implementation approaches to consider
- Benefits from step-by-step breakdown
- Needs to maintain context across sessions
- Involves complex refactoring or migrations

### Plan Content Guidelines

A good plan includes:
- **Objective**: Clear statement of what needs to be accomplished
- **Current State**: Analysis of existing code/architecture
- **Proposed Solution**: Detailed approach with alternatives considered
- **Implementation Steps**: Ordered list of tasks
- **Testing Strategy**: How to verify the changes work
- **Risks and Mitigations**: Potential issues and how to handle them
- **Success Criteria**: How to know when the task is complete
