# Save/Load Persistence Reference

## GameState Save/Load

**Path**: `src/core/state/GameState.gd` (autoload)

### Signals
```
save_started
save_completed(success: bool, message: String)
load_started
load_completed(success: bool, message: String)
campaign_loaded(campaign)
campaign_saved
```

### Save Flow
```
GameState.save_campaign(campaign, path)
  → Serialize campaign to Dictionary
  → Write JSON to user://saves/{campaign_id}.json
  → save_completed.emit(true, "Saved successfully")
```

### Load Flow
```
GameState.load_campaign(path)
  → Read JSON from path
  → _detect_campaign_type() peeks JSON to determine Standard vs Bug Hunt
  → Route to correct deserializer
  → set_current_campaign(campaign)
  → campaign_loaded.emit(campaign)
  → load_completed.emit(true, "Loaded successfully")
```

### Campaign Type Detection
```gdscript
func _detect_campaign_type(data: Dictionary) -> String:
    if "main_characters" in data:
        return "bug_hunt"      # BugHuntCampaignCore
    return "standard"          # FiveParsecsCampaignCore
```

### Key Methods
```
save_campaign(campaign = null, path: String = "") → Dictionary
load_campaign(path: String) → Dictionary
import_campaign(external_path: String) → Dictionary
get_available_campaigns() → Array
get_campaign_info(path: String) → Dictionary
auto_save() → void
persist_game_state() → void
```

## FiveParsecsCampaignCore Gotchas

**FiveParsecsCampaignCore extends Resource** — this has critical implications:

1. **Dictionary-style access fails silently**: `campaign["key"] = val` does NOT work on Resource properties. Use `progress_data["key"]` for runtime state
2. **Use `"key" in campaign`** instead of `.has("key")` for property existence checks
3. **Crew data is nested**: `campaign.crew_data["members"]` (Array of character Dicts)
4. **Equipment data key**: `campaign.equipment_data["equipment"]` — NOT `"pool"`

## Difficulty Field (Phase 30 Fix — CRITICAL)

`difficulty` is stored as `int` using `GlobalEnums.DifficultyLevel` enum values:
- EASY=1, NORMAL=2, CHALLENGING=4, HARDCORE=6, INSANITY=8
- **NEVER use raw int comparisons** — use `DifficultyModifiers` static methods
- Old saves with values 3/4/5 (from pre-Phase 30 panel) will map incorrectly

## Phase 30 New Fields

```
"red_zone_licensed": bool    # Red Zone Jobs endgame access
"red_zone_turns_completed": int  # Turns in Red Zone
"has_ship": bool             # false = shipless state (Core Rules p.59)
"ship_debt": int             # Loan remaining (interest per turn)
```

## Save File Schema (Simplified)

```json
{
  "campaign_id": "uuid-string",
  "campaign_name": "My Campaign",
  "turn_number": 5,
  "difficulty": 2,
  "story_track_enabled": true,
  "victory_conditions": {},
  "crew_data": {
    "members": [
      { "id": "char_xxx", "character_id": "char_xxx", "name": "...", ... }
    ]
  },
  "equipment_data": {
    "equipment": [...]
  },
  "ship_data": {},
  "world_data": {},
  "progress_data": {},
  "qol_data": {
    "journal": {},
    "checklist": {}
  }
}
```

## Settings Persistence (Separate from Campaign)

```
GameState.save_settings() → user://settings.cfg
GameState.load_settings() → user://settings.cfg
GameState.save_options() → user://options.cfg
GameState.load_options() → user://options.cfg
```

Settings include: difficulty, last campaign, language
Options include: music volume, UI scale, auto_save toggle

## Save Directory

All campaign saves go to: `user://campaigns/`
- On Windows: `C:\Users\admin\AppData\Roaming\Godot\app_userdata\Five Parsecs Campaign Manager\campaigns\`
- **NOT** `user://saves/` — the QA script previously had this wrong

## Dual-Sync Pattern (Phase 30/31 Fix, Mar 16 2026)

### BUG-031 Resolution: progress_data Persistence

**Root cause**: `GameStateManager.game_state` field was never assigned to the autoload instance. `set_credits()` silently failed to write back to `campaign.credits`. Additionally, `progress_data` lacked default counters.

**Fix — Dual-Sync Setters**: All 4 campaign state setters now sync both the campaign resource property AND `progress_data`:

```gdscript
# In GameStateManager:
func set_credits(value: int) -> void:
    if campaign:
        campaign.credits = value
        campaign.progress_data["credits"] = value  # dual-sync
```

The 4 setters that dual-sync:
1. `set_credits()` — syncs to `progress_data["credits"]`
2. `set_missions_completed()` — syncs to `progress_data["missions_completed"]`
3. `set_battles_won()` — syncs to `progress_data["battles_won"]`
4. `set_battles_lost()` — syncs to `progress_data["battles_lost"]`

**`_on_campaign_loaded()` routes through setters**: When a campaign loads, the loaded values are set via the setter methods (not direct assignment) to ensure both the resource property and progress_data are consistent.

**Default counters in `_init()` and `from_dictionary()`**: `FiveParsecsCampaignCore` now initializes `progress_data` with default zero values for `credits`, `missions_completed`, `battles_won`, `battles_lost` to prevent null reads.

### BUG-035 Resolution: Equipment Restoration on Load (Phase 31)

Equipment in the ship stash was not restored to EquipmentManager on campaign load. Crew member dicts also lacked per-member equipment data.

**Fix**: Two new methods in GameState:
- `_restore_equipment_from_campaign()` — reads `equipment_data["equipment"]` and populates EquipmentManager
- `_enrich_crew_equipment()` — adds per-member equipment arrays to crew dicts for UI consumption

Both are called during `_on_campaign_loaded()` after the campaign resource is deserialized.

### Save File Format
Save files use `.fpcs` extension with `.backup` copy. Format is JSON with the schema in data-consistency.md reference.
