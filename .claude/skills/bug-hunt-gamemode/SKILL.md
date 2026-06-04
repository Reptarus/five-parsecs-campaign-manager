---
name: bug-hunt-gamemode
description: "Use this skill when working with the Bug Hunt gamemode — creation wizard, dashboard, turn controller, phase manager, battle setup, character transfer, cross-mode safety, or any Bug Hunt-specific data files. Also use for cross-mode safety review when changes touch files shared between Standard 5PFH and Bug Hunt."
---

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
5. **Enlistment roll required** — 2D6 + Combat >= 8 to transfer 5PFH → Bug Hunt (verify in RulesReference)
6. **_bug_hunt_returning flag** — prevents double-navigation, must be cleared after use
