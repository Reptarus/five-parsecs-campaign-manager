# Bug Hunt Specialist — Agent Memory

<!-- This file is loaded into your system prompt. Keep it under 200 lines. -->
<!-- Save: cross-mode isolation issues, data model mismatches, transfer bugs -->

## Critical Gotchas — Must Remember

### 1. Incompatible Data Models

Standard 5PFH and Bug Hunt use fundamentally different data structures:

| Aspect | Standard (FiveParsecsCampaignCore) | Bug Hunt (BugHuntCampaignCore) |
|--------|-----------------------------------|-------------------------------|
| Crew | `crew_data["members"]` (nested) | `main_characters[]` + `grunts[]` (flat, top-level) |
| Ship | `ship_data` | None |
| Patrons | `patrons[]`, `rivals[]` | None |

Detection pattern:
```gdscript
if "main_characters" in campaign:
    # Bug Hunt campaign
else:
    # Standard 5PFH campaign
```

### 2. Stat Key Mapping

| Bug Hunt | Standard 5PFH |
|----------|---------------|
| `combat_skill` | `combat` |
| `reactions` | `reaction` |

CharacterTransferService handles bidirectional mapping. Always use the transfer service — never manually remap stats.

### 3. Temp Data Namespacing

Bug Hunt keys use `"bug_hunt_*"` prefix to prevent collision:
- `"bug_hunt_battle_context"`, `"bug_hunt_battle_result"`, `"bug_hunt_mission"`

Standard keys: `"world_phase_results"`, `"return_screen"`, `"selected_character"`

Never use a Bug Hunt prefix on standard keys or vice versa.

### 4. TacticalBattleUI is Shared

`TacticalBattleUI.gd` (class_name `FPCM_TacticalBattleUI`) serves both Standard and Bug Hunt modes. Bug Hunt detection happens at a higher level (BugHuntBattleSetup, temp_data keys). Any changes to TacticalBattleUI must be tested in both modes.

### 5. Enlistment Roll

Bug Hunt recruitment: 2D6 + Combat >= 8. This is a Bug Hunt-specific mechanic that does not exist in Standard mode.

### 6. Godot 4.6 Type Inference

`var x := dict["key"]` will NOT compile — Dictionary values are always Variant.
Always use explicit type annotation: `var x: Type = dict["key"]`. Zero exceptions.
