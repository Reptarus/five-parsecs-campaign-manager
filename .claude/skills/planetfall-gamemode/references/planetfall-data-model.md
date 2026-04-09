# Planetfall Data Model Reference

## PlanetfallCampaignCore (Resource)
- **class_name**: PlanetfallCampaignCore
- **extends**: Resource
- **File**: `src/game/campaign/PlanetfallCampaignCore.gd` (538 lines)
- **SEPARATE from FiveParsecsCampaignCore and BugHuntCampaignCore**

## Data Model Comparison

| Aspect | Planetfall | Standard 5PFH | Bug Hunt |
|--------|-----------|---------------|----------|
| Core class | `PlanetfallCampaignCore` | `FiveParsecsCampaignCore` | `BugHuntCampaignCore` |
| Characters | `roster: Array` (Dict) | `crew_data["members"]` (nested Dict) | `main_characters: Array` (Dict) |
| Expendables | `grunts: int` (count only) | None | `grunts: Array` (Dict) |
| Equipment | `equipment_pool: Array` (central) | Per-character + ship stash | Per-character |
| Colony | Full system (Integrity/Morale/Buildings/Research) | None | None |
| Ship | None | Full ship system | None |
| Resources | `raw_materials`, `story_points`, `augmentation_points` | Credits, story_points | Reputation |
| Turn structure | 18-step | 9-phase | 3-stage |
| Classes | Scientist/Scout/Trooper | Classless | Same as 5PFH |
| Luck | None (Story Points at campaign level) | Per-character | None |

## Key Properties

### Meta
```gdscript
@export var schema_version: int = 1
@export var campaign_name: String = ""
@export var campaign_id: String = ""
@export var campaign_type: String = "planetfall"
@export var game_phase: String = "creation"  # "creation", "tutorial", "active", "endgame", "completed"
@export var campaign_turn: int = 0
```

### Colony Info
```gdscript
@export var colony_name: String = ""
@export var expedition_type: String = ""
@export var difficulty: String = "normal"
```

### Colony Statistics (Planetfall p.55, Colony Tracking Sheet p.190)
```gdscript
@export var colony_morale: int = 0
@export var colony_integrity: int = 0
@export var build_points_per_turn: int = 1
@export var research_points_per_turn: int = 1
@export var repair_capacity: int = 1
@export var colony_defenses: int = 0
@export var raw_materials: int = 0
@export var story_points: int = 5
@export var augmentation_points: int = 0
```

### Grunts & Bot
```gdscript
@export var grunts: int = 12          # Count only, NOT individual tracking (p.16)
@export var bot_operational: bool = true  # 1 per campaign (p.17)
```

### Progression
```gdscript
@export var milestones_completed: int = 0   # 7 needed for End Game (p.156)
@export var calamity_points: int = 0
@export var mission_data: int = 0           # 4 breakthroughs (p.169)
@export var mission_data_breakthroughs: int = 0
```

### Complex Data (non-@export — plain var)
```gdscript
var roster: Array = []                  # Array of character Dictionaries
var equipment_pool: Array = []          # Central colony armory
var grunt_upgrades: Array = []          # Unlocked upgrade IDs (p.79)
var map_data: Dictionary = {}           # {grid_size, home_sector, sectors}
var research_data: Dictionary = {}      # {unlocked_theories, unlocked_applications, current_research}
var buildings_data: Dictionary = {}     # {constructed, in_progress}
var lifeform_table: Array = []          # 10-slot persistent (p.146)
var lifeform_evolutions: Array = []     # Evolution IDs applied
var condition_table: Array = []         # 10-slot persistent (p.110)
var tactical_enemies: Array = []        # 3 total, milestones 1, 2, 5 (p.50)
var enemy_info: Dictionary = {}         # Per-enemy info keyed by index
var ancient_signs: Array = []           # Sector coordinates
var active_calamities: Array = []
var tutorial_missions: Dictionary = {"beacons": false, "analysis": false, "perimeter": false}
var tutorial_bonuses: Dictionary = {}
var sick_bay: Dictionary = {}           # character_id → turns_remaining
var stashed_equipment: Dictionary = {}  # From imported characters
var original_character_snapshots: Dictionary = {}  # For lossless export
```

## Roster Character Dict Keys
```
id, name, class, subspecies, reactions, speed, combat_skill,
toughness, savvy, xp, kp, loyalty, motivation, prior_experience,
notable_event, abilities, is_imported, source_campaign
```

## Character Classes (Planetfall pp.13-15)

| Class | Reactions | Speed | Combat | Toughness | Savvy | Special |
|-------|-----------|-------|--------|-----------|-------|---------|
| Scientist | 1 | 4" | +0 | 3 | +1 | Scientific Mind (reroll Savvy), Problem Solving (+1 Reaction die) |
| Scout | 1 | 5" | +0 | 3 | +0 | Flexible Combat Training, Jump Jets |
| Trooper | 2 | 4" | +1 | 3 | +0 | Trooper Armor (5+ Save), Intense Combat Training (2 actions) |
| Grunt | 2 | 4" | +0 | 3 | +0 | No progression, simplified casualty (D6: 1-2 dead, 3-6 ok) |
| Bot | 2 | 4" | +0 | 4 | +0 | 6+ Save, immune to psionic, no XP |

## Equipment Pool Model
Central colony store — characters do NOT own items individually. Equipment is:
- Initialized at campaign creation (`initialize_equipment_pool()`)
- Assigned at Lock & Load step (Step 7 of 18-step turn)
- Returned to pool after missions
- Unique among all game modes

## Map Data Structure
```json
{
  "grid_size": [rows, cols],      // 6x6 to 10x10
  "home_sector": [r, c],
  "sectors": {
    "r_c": {
      "explored": false,
      "terrain": "plains",
      "features": [],
      "enemy_present": false,
      "investigation_site": false
    }
  }
}
```

## Serialization

### to_dictionary() Structure
```
{
  "campaign_id": "...",
  "campaign_type": "planetfall",      # ROOT level — required for _detect_campaign_type()
  "meta": { campaign_id, campaign_name, campaign_type, schema_version, ... },
  "config": { name, colony_name, expedition_type, difficulty },
  "roster": [...],                    # .duplicate(true)
  "colony": { colony_morale, colony_integrity, build_points_per_turn, ... },
  "progression": { campaign_turn, milestones_completed, calamity_points, ... },
  "map_data": {...},                  # .duplicate(true)
  "research_data": {...},
  "buildings_data": {...},
  "equipment_pool": [...],
  ... (all complex data with .duplicate(true))
}
```

### from_dictionary() Pattern
```gdscript
if data.has("meta"):
    var meta: Dictionary = data.meta
    campaign_id = meta.get("campaign_id", "")
    # ... safe defaults for every field
roster = data.get("roster", []).duplicate(true)
# ... .duplicate(true) on all complex data
```

## Campaign Type Detection

`GameState._detect_campaign_type(path)` at line 427:
```gdscript
return data.get("campaign_type", "five_parsecs")
# Returns "planetfall" for Planetfall saves
```

Runtime validation in UI screens:
```gdscript
if not _campaign or not "roster" in _campaign:
    # Show empty state
    return
```
