---
name: bug-hunt-gamemode
description: "Use this skill when working with the Bug Hunt gamemode — creation wizard, dashboard, turn controller, phase manager, battle setup, character transfer, cross-mode safety, or any Bug Hunt-specific data files. Also use for cross-mode safety review when changes touch files shared between Standard 5PFH and Bug Hunt."
---

> 🛑 **RULE 0 applies — read the actual code AND scenes before any plan, edit, or structural claim.** Canonical text: `CLAUDE.md` → "Agent Verification Protocol" → "RULE 0". The `.tscn`/`.tres` wiring is the authority on what is actually instantiated and live; memory, docblocks, SOPs and relayed sub-agent summaries are leads to verify, never facts. Cite `file:line`.

# Bug Hunt Gamemode

## Reference Files

| Reference | Contents |
|-----------|----------|
| `references/bug-hunt-data-model.md` | BugHuntCampaignCore vs FiveParsecsCampaignCore diff, main_characters/grunts, movie_magic, serialization |
| `references/bug-hunt-turn-flow.md` | 3-stage turn, BugHuntPhaseManager signals/methods, BugHuntDashboard, BugHuntCreationUI 4-step wizard |
| `references/cross-mode-safety.md` | Isolation protocols, temp_data namespacing, signal guards, CharacterTransferService canonical-hub framework + generic pickup, stat key mapping |

## Quick Decision Tree

- **Bug Hunt data model questions** → Read `bug-hunt-data-model.md`
- **Turn/phase transitions** → Read `bug-hunt-turn-flow.md`
- **Character transfer** → Read `cross-mode-safety.md`
- **Cross-mode safety review** → Read `cross-mode-safety.md`
- **Creation wizard changes** → Read `bug-hunt-turn-flow.md` (BugHuntCreationUI section)
- **Dashboard UI changes** → Read `bug-hunt-turn-flow.md` (BugHuntDashboard section)

## Key Source Files

| File | Class/Role | Purpose |
|------|-----------|---------|
| `BugHuntCampaignCore` | Resource | Bug Hunt campaign data (NOT FiveParsecsCampaignCore) |
| `src/core/campaign/BugHuntPhaseManager.gd` | `BugHuntPhaseManager` | 3-stage turn orchestration |
| `src/ui/screens/bug_hunt/BugHuntDashboard.gd` | Control | Bug Hunt main UI |
| `src/ui/screens/bug_hunt/BugHuntCreationUI.gd` | Control | 4-step creation wizard |
| `src/core/character/CharacterTransferService.gd` | `CharacterTransferService` | Canonical-hub transfer for all 4 modes (any-to-any via 5PFH canonical); Bug Hunt ↔ 5PFH legs shipped |
| `src/ui/screens/campaign/CampaignScreenBase.gd` | `CampaignScreenBase` | Generic pending-transfer pickup (`_check_pending_transfers`, `_add_character_to_mode` → `add_main_character` for Bug Hunt) |
| `data/bug_hunt/` | 15 JSON files | Bug Hunt-specific data |

## Rules Data Authority

Bug Hunt data — missions, enemies, spawn rules, character creation, enlistment mechanics — MUST be verified against `data/RulesReference/` Compendium files and `data/bug_hunt/*.json` (15 files). Never invent Bug Hunt values.

## Critical Gotchas

1. **Incompatible data models** — `main_characters[]` (BH) vs `crew_data["members"]` (5PFH)
2. **Validate campaign type** — `"main_characters" in campaign` before Bug Hunt code
3. **Temp data namespacing** — Bug Hunt keys use `"bug_hunt_*"` prefix
4. **Stat key differences** — `reactions`/`combat_skill` (BH) vs `reaction`/`combat` (5PFH)
5. **Enlistment roll required** — 2D6 + Combat Skill >= **7** to transfer 5PFH → Bug Hunt (Compendium p.212; `CharacterTransferService.ENLISTMENT_TARGET`). ⚠ This line said **8** until 2026-09-10 and was wrong against both the book and the code. A failed roll can be bypassed with 1 Story Point (p.214) — the service returns `story_point_rescue_available`, which currently has no reader.
6. **Battle return is via temp data**, not a flag — `BugHuntTurnController` reads `bug_hunt_battle_result` and nulls the key after use. ⚠ This line described a `_bug_hunt_returning` flag until 2026-09-10; that identifier has **zero matches repo-wide** and never existed.
