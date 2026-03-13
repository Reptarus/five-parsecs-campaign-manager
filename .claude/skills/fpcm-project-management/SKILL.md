---
name: fpcm-project-management
description: "Use this skill for task decomposition, agent routing, cross-system coordination, project status reporting, roadmap planning, or when determining which agent should handle a complex or ambiguous task. Also use for architectural decisions that span multiple systems."
---

# FPCM Project Management

## Reference Files

| Reference | Contents |
|-----------|----------|
| `references/agent-roster.md` | All 7 agents: domain, model, color, files owned, routing rules, cross-domain flow examples |
| `references/task-decomposition.md` | Decomposition framework, execution order, dependency chains, 6 worked examples |
| `references/project-status.md` | Per-system implementation status, completed phases, roadmap, future work |

## Quick Decision Tree

- **Which agent handles X?** → Read `agent-roster.md`
- **How to break down a complex task?** → Read `task-decomposition.md`
- **What's the project status?** → Read `project-status.md`
- **Cross-system coordination needed?** → Read `agent-roster.md` (cross-domain flows section)
- **Enum change needed?** → Always route to `character-data-engineer` (three-enum sync rule)

## Agent Quick Reference

| Agent | Model | Domain | Trigger Keywords |
|-------|-------|--------|-----------------|
| `character-data-engineer` | sonnet | Data, enums, JSON, equipment, world | character, stats, enum, data, equipment, JSON, world |
| `campaign-systems-engineer` | sonnet | Campaign creation, turns, save/load | campaign, creation, turn, phase, save, load, state |
| `battle-systems-engineer` | opus | Battle state machine, combat, victory | battle, combat, fight, deploy, victory, tactical |
| `ui-panel-developer` | haiku | UI, theme, TweenFX, navigation | panel, UI, screen, theme, animation, TweenFX, style |
| `bug-hunt-specialist` | sonnet | Bug Hunt gamemode, cross-mode safety | bug hunt, grunt, regiment, cross-mode, transfer |
| `qa-specialist` | sonnet | Testing, QA, bugs, regression | test, QA, bug, verify, validate, audit, sweep |
