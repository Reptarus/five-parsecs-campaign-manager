# FPCM Project Manager — Agent Memory

<!-- This file is loaded into your system prompt. Keep it under 200 lines. -->
<!-- Save: routing decisions, cross-domain coordination patterns, project-level gotchas -->

## ABSOLUTE RULE: Core Rules & Compendium Are Word of God

The Core Rules and Compendium PDFs at `docs/rules/` are the canonical authority for ALL game mechanics. When routing data tasks, ensure agents verify values against the PDFs, not just code. Any agent can extract data using `py -c "import fitz; ..."`.

---

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

## Session 18: Rules Audit Complete + Schema Unification (Mar 30, 2026)

QA_RULES_ACCURACY_AUDIT.md: **0 UNVERIFIED entries** (was 308). 925/925 data values verified.

Fixes: Rival following (campaign-systems-engineer domain, TravelPhase.gd), license costs (same), 3 generator schema unifications (cross-domain: mission generators now delegate to Compendium canonical data classes instead of maintaining duplicate const tables). StreetFightPanel UI updated for new schema.

**Routing note**: Stealth/Street/Salvage generators (`src/core/mission/`) now depend on Compendium data classes (`src/data/compendium_*.gd`). Any data table changes go to `compendium_*.gd` files — generators are thin orchestration wrappers.

---

## Session 11-12: Hardcoded Data Cleanup (Mar 26, 2026)

Major cross-system data integrity pass completed:
- **KeywordDB** (character-data domain): Wired to 89-keyword JSON, 14 weapon traits corrected to Core Rules p.51
- **BattlePhase.gd** (battle/campaign domain): Fabricated payment formula removed. PostBattlePaymentProcessor handles real 1D6 payment.
- **BattleEventsSystem.gd** (battle domain): Wired to event_tables.json (24 events data-driven)
- **Audit verified**: PatronJobGenerator already wired, CharacterCreator already wired, BattleCalculations constants correct
- **Cut (cosmetic/dead data)**: CharacterNameGenerator (cosmetic, no gameplay impact), patron_missions.json (dead data, not wired)
- **Project version**: v0.9.4

---

## PDF Rulebooks & Python Extraction Tools

All agents can now extract data directly from source PDFs — route data verification tasks accordingly:
- **Core Rules PDF**: `docs/rules/pdfcoffee_com_muh052042_five_parsecs_from_home_3e_rulebook_2021.pdf`
- **Compendium PDF**: `docs/rules/Five Parsecs From Home-Compendium.pdf`
- **Text extractions**: `docs/rules/core_rulebook.txt` and `docs/rules/compendium_source.txt`
- **Python**: `py` launcher (NOT `python`), PyMuPDF 1.27.1 (fitz) installed
- **Example**: `py -c "import fitz; doc = fitz.open('path'); print(doc[PAGE].get_text())"`

---

## QA Documentation Suite (Mar 20, 2026)

Route all QA-related questions through the qa-specialist agent, which now has 4 master docs:

- `docs/QA_STATUS_DASHBOARD.md` — Start here for overall QA health, open bugs, next priorities
- `docs/QA_CORE_RULES_TEST_PLAN.md` — 170 mechanics → test status (47 NOT_TESTED, 63 MCP_VALIDATED, 0 RULES_VERIFIED)
- `docs/QA_INTEGRATION_SCENARIOS.md` — 9 E2E workflow scripts with MCP templates
- `docs/QA_UX_UI_TEST_PLAN.md` — Systematic UI testing (theme, responsive, TweenFX, accessibility)

After any sprint that fixes bugs or adds features, remind the assigned agent to update the dashboard and core rules plan.

## Project Status (Mar 26, 2026) — v0.9.3

- **Zero compile errors, zero runtime errors** (MCP-verified)
- **Battle Simulator**: Standalone battle mode — 5 files, wired to MainMenu, runtime-verified
- **CombatResolver interface**: 22 combat methods + 13 properties added to BaseCharacterResource (Session 10)
- **Bug Hunt wizard fix**: Equipment step auto-complete — unblocked 4-step creation flow
- **Bug Hunt**: Fully wired, 4-step wizard runtime-verified via MCP
- **TacticalBattleUI**: Now serves 3 modes (Standard, Bug Hunt, Battle Simulator)
- **7 uncommitted files**, 1 unpushed commit. Ready to commit + push.
- **Next priorities**: Commit all, push, DLC gating for Battle Simulator + Bug Hunt, crew customization enhancements
