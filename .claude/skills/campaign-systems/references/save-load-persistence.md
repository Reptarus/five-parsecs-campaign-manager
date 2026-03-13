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

## Save File Schema (Simplified)

```json
{
  "campaign_id": "uuid-string",
  "campaign_name": "My Campaign",
  "turn_number": 5,
  "difficulty": 1,
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

All campaign saves go to: `user://saves/`
- On Windows: `C:\Users\admin\AppData\Roaming\Godot\app_userdata\Five Parsecs Campaign Manager\saves\`
