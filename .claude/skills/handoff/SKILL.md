---
name: handoff
description: "Session handoff skill. Use when a conversation is getting long (~400+ tool calls or context compression detected), OR when the user says /handoff. Saves all progress to memory, updates docs/skills, and generates a continuation prompt for the next session. Do NOT use during long-running unattended operations (MCP automated testing, overnight test suites) — see exceptions below."
user_invocable: true
---

# Session Handoff

Automate the end-of-session state preservation and continuation prompt generation.

## When to Trigger

**Proactively suggest** `/handoff` when:

- Context compression has occurred (system will warn you)
- You estimate ~400+ tool calls have been made in the session
- Response quality is noticeably degrading (repeating yourself, losing track of state)
- A major milestone was just completed (phase done, bug fix sprint complete, feature merged)

**Do NOT trigger** (or warn the user) when:

- A background task is still running (MCP automated UI test, headless test suite, batch operation)
- The user is away / unattended — a new session would stall on the first tool approval
- Mid-implementation with uncommitted changes that would be hard to describe out of context

When an exception applies, say so clearly:
> "I'd normally suggest a handoff here, but there's a background [task] still running. A new session would stall waiting for tool approvals. I'll suggest /handoff once it completes."

## Handoff Procedure

### Step 1: Identify What Changed This Session

Scan the conversation for:

- Decisions made (architectural, design, approach choices)
- Code written or modified (files, line counts, what changed)
- Tests added or modified
- Bugs found or fixed
- Phase/sprint progress
- New patterns or conventions established
- Blockers or open questions
- Background tasks still running

### Step 2: Update Memory Files

For each category of change, update or create the appropriate memory file:

| Change Type | Memory Type | Action |
|-------------|------------|--------|
| User preference learned | `feedback` | Create/update feedback memory |
| Project status changed | `project` | Update relevant project memory |
| New external reference discovered | `reference` | Create reference memory |
| User role/context learned | `user` | Create/update user memory |
| Sprint progress | `project` | Update sprint status in relevant memory |
| Skill gaps identified | — | Update skill reference files directly |

**Always update:**

- `MEMORY.md` index if new memory files were created
- Any project status memories that reflect completed work
- Sprint/task status in relevant memories

**Check before writing:**

- Don't duplicate existing memories — update them instead
- Don't save ephemeral details (temp file paths, mid-debug state)
- Convert relative dates to absolute dates

### Step 3: Update Agent Memories

Check each agent's MEMORY.md for discoveries made this session:

| Agent | Save When |
|-------|----------|
| `character-data-engineer` | Enum issues found, stat edge cases, serialization gotchas |
| `campaign-systems-engineer` | State sync bugs, creation flow changes, save/load issues |
| `battle-systems-engineer` | State machine fixes, combat resolution changes, UI tier issues |
| `bug-hunt-specialist` | Cross-mode isolation bugs, data model changes, transfer issues |
| `ui-panel-developer` | Theme fixes, TweenFX gotchas, responsive layout changes |
| `qa-specialist` | New bugs found/fixed, test infrastructure changes, MCP gotchas |
| `fpcm-project-manager` | Routing decisions, cross-domain coordination patterns |

### Step 4: Update Skills

Check each skill's reference files against what changed this session.

| Skill | When to Update | Key Reference Files |
|-------|---------------|---------------------|
| `battle-systems` | Battle state machine, combat, deployment, UI tier changes | `battle-state-machine.md`, `battle-ui-wiring.md`, `combat-resolution.md` |
| `campaign-systems` | Creation flow, turn phases, save/load, autoload API changes | `campaign-creation-flow.md`, `save-load-persistence.md`, `autoload-contracts.md` |
| `character-data` | Character model, enum, JSON data, equipment changes | `character-model.md`, `enum-systems.md`, `json-data-catalog.md` |
| `bug-hunt-gamemode` | Bug Hunt data model, turn flow, cross-mode changes | `bug-hunt-data-model.md`, `cross-mode-safety.md` |
| `qa-specialist` | New test patterns, bugs found/fixed, test infrastructure | `gdunit4-patterns.md`, `bug-notes.md`, `cross-system-verification.md` |
| `ui-development` | Theme changes, new patterns, TweenFX, SceneRouter routes | `deep-space-theme.md`, `panel-patterns.md`, `scene-router.md` |
| `fpcm-project-management` | Agent routing changes, project milestones, test counts | `project-status.md`, `agent-roster.md` |

**Always update `fpcm-project-management/references/project-status.md`** with:

- Any phases/tasks completed this session
- Current phase focus changes
- Test count changes (suites, test count, pass/fail)

### Step 5: Update Documentation

If this session changed anything that affects project docs:

- `CLAUDE.md` — project conventions, current phase status, test counts, gotchas
- `docs/PROJECT_STATUS_2026.md` — if phase/milestone status changed

### Step 6: Check for Uncommitted Work

Run `git status` and `git diff --stat` to identify any uncommitted changes.

- If there are staged/unstaged changes, note them in the continuation prompt
- Suggest committing before handoff if changes are substantial

### Step 7: Generate Continuation Prompt

Output a fenced code block containing a ready-to-paste prompt for the next session:

```
## Session Continuation — [Date]

### Context
[1-2 sentences: what we were working on and why]

### Completed This Session
- [Bullet list of what got done]

### Current State
- [Where things stand right now]
- [Any running background tasks and their expected completion]
- [Uncommitted changes, if any]

### Next Steps
1. [Immediate next action — be specific]
2. [Following action]
3. [etc.]

### Open Questions / Blockers
- [Anything unresolved that needs attention]

### Key Files Modified
- [filepath] — [what changed]
```

### Step 8: Confirm Handoff

Tell the user:

- How many memory files were updated/created
- Which skill reference files were updated (and why)
- Whether CLAUDE.md or project docs were updated
- Whether there are uncommitted changes to deal with
- That the continuation prompt is ready to copy

## Quality Checklist

Before finalizing handoff, verify:

- [ ] All session progress is captured in memory (not just the last task)
- [ ] Memory files have accurate dates (absolute, not relative)
- [ ] Skill reference files reflect any architecture/behavior changes from this session
- [ ] `project-status.md` has current phase status and test counts
- [ ] Continuation prompt has enough context for cold-start (no "as we discussed")
- [ ] No secrets, temp paths, or session-specific state leaked into memories
- [ ] Phase/task status numbers are accurate (test counts, coverage %, etc.)
- [ ] Background tasks are noted with expected completion if still running
