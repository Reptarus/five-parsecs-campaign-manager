# FPCM Project Manager — Agent Memory

<!-- This file is loaded into your system prompt. Keep it under 200 lines. -->
<!-- Save: routing decisions, cross-domain coordination patterns, project-level gotchas -->

## Critical Gotchas — Must Remember

### 1. Three-Enum Sync Rule

Any enum change MUST be routed exclusively to character-data-engineer. Three files must stay in perfect alignment:
- `src/core/systems/GlobalEnums.gd` (autoload)
- `src/core/enums/GameEnums.gd` (class_name)
- `src/game/campaign/crew/FiveParsecsGameEnums.gd` (CharacterClass)

Never let another agent modify enums independently.

### 2. Agent Dependency Order

When decomposing multi-domain tasks, route in this order:
```
data (character-data-engineer)
  → campaign (campaign-systems-engineer)
    → battle (battle-systems-engineer)
      → bug-hunt (bug-hunt-specialist)
        → UI (ui-panel-developer)
          → QA (qa-specialist)
```

### 3. Cross-Mode Review Required

Changes to shared files MUST get bug-hunt-specialist review:
- `TacticalBattleUI.gd` — shared between Standard and Bug Hunt
- `GameState.gd` — handles both campaign types
- `SceneRouter.gd` — routes to both mode UIs

### 4. FiveParsecsCampaignCore is Resource

`campaign["key"] = val` **silently fails**. Use `progress_data["key"]` for runtime state.
Route bugs about "lost state" or "data not persisting" to campaign-systems-engineer — this is usually the root cause.

### 5. Godot 4.6 Type Inference

`var x := dict["key"]` will NOT compile — Dictionary values are always Variant.
This is the root cause of "Cannot infer the type" errors project-wide. Always use explicit type annotation: `var x: Type = dict["key"]`.

---

## QA Documentation Suite (Mar 20, 2026)

Route all QA-related questions through the qa-specialist agent, which now has 4 master docs:

- `docs/QA_STATUS_DASHBOARD.md` — Start here for overall QA health, open bugs, next priorities
- `docs/QA_CORE_RULES_TEST_PLAN.md` — 170 mechanics → test status (47 NOT_TESTED, 63 MCP_VALIDATED, 0 RULES_VERIFIED)
- `docs/QA_INTEGRATION_SCENARIOS.md` — 9 E2E workflow scripts with MCP templates
- `docs/QA_UX_UI_TEST_PLAN.md` — Systematic UI testing (theme, responsive, TweenFX, accessibility)

After any sprint that fixes bugs or adds features, remind the assigned agent to update the dashboard and core rules plan.

## Project Status (Mar 21, 2026)

- **0 open bugs** — First time at zero. 4 deferred items remain (architectural).
- **Phase 33 runtime-validated**: PostBattlePhase (19/19 signals), WorldPhaseComponent (9/9), 3 runtime fixes applied
- **5-turn MCP playthrough PASS**: Turns 3-5, all counters consistent, 0 crashes, event bus cleanup working
- **~99 uncommitted files** — Phase 33 optimization + QA bug fixes + runtime fixes. Needs commit.
- **Next priorities**: Commit, 47 NOT_TESTED mechanics (focus: Compendium DLC), RULES_VERIFIED pass, character type shadowing fix
