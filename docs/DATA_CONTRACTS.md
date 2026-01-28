# Data Contracts - Campaign Wizard to Turn System

**Version**: 1.0
**Last Updated**: Sprint 27.4
**Purpose**: Define data structures for campaign creation → turn system handoff

---

## 1. Overview

This document defines the data contracts between:
- **Campaign Creation Wizard** (panels that produce data)
- **CampaignFinalizationService** (transforms and validates data)
- **Campaign Turn System** (consumes data during gameplay)

---

## 2. Canonical Property Names

### Character Properties

| Property | Type | Canonical Name | Legacy Names | Notes |
|----------|------|----------------|--------------|-------|
| Experience | `int` | `experience` | `xp` | Use `experience` for all new code |
| Reactions | `int` | `reactions` | `reaction` | Plural form is canonical |
| Character Name | `String` | `character_name` | `name` | Use full property name |
| Character ID | `String` | `character_id` | `id` | Use full property name |
| Combat Skill | `int` | `combat` | `combat_skill` | Short form is canonical |

### Campaign Properties

| Property | Type | Canonical Name | Legacy Names | Notes |
|----------|------|----------------|--------------|-------|
| Campaign Name | `String` | `campaign_name` | `name` | Use full property name |
| Crew Size | `int` | `crew_size` | `size` | Use full property name |
| Difficulty | `int` | `difficulty` | `difficulty_level` | Short form is canonical |

### Accessing Properties with Fallbacks

When reading data that may contain legacy keys:
```gdscript
# CORRECT: Check canonical first, then legacy fallback
var experience = data.get("experience", data.get("xp", 0))
var reactions = data.get("reactions", data.get("reaction", 0))
var char_name = data.get("character_name", data.get("name", "Unknown"))

# WRONG: Don't check legacy first
var xp = data.get("xp", data.get("experience", 0))  # Inverted order
```

---

## 3. Panel Data Contracts

### 3.1 CrewPanel.get_panel_data()

**Output Structure:**
```gdscript
{
    "members": Array[Character],  # Full Character objects
    "size": int,                  # Alias for crew_size
    "crew_size": int,             # Number of crew members
    "captain": Character,         # Captain Character object
    "has_captain": bool,          # True if captain designated
    "valid": bool                 # True if minimum crew requirements met
}
```

**Requirements:**
- Minimum 4 crew members for valid crew
- Captain must be designated before finalization
- All members must have unique `character_id`

### 3.2 CaptainPanel.get_panel_data()

**Output Structure:**
```gdscript
{
    "captain": Dictionary,        # Captain data as dictionary
    "captain_character": Character,  # Captain as Character object
    "valid": bool
}
```

**Captain Dictionary Fields:**
```gdscript
{
    "character_id": String,       # Unique identifier
    "character_name": String,     # Display name
    "combat": int,                # Combat skill (0-3)
    "reactions": int,             # Reaction score (1-3)
    "toughness": int,             # Toughness (3-5)
    "savvy": int,                 # Savvy score (0-3)
    "tech": int,                  # Tech score (0-2)
    "move": int,                  # Movement (4-6)
    "experience": int,            # Starting XP (default 0)
    "background": int/String,     # Background enum/string
    "motivation": int/String,     # Motivation enum/string
    "is_captain": true            # Always true for captain
}
```

### 3.3 EquipmentPanel.get_panel_data()

**Output Structure:**
```gdscript
{
    "equipment": Array[Dictionary],  # Equipment items
    "credits": int,                  # Starting credits
    "starting_credits": int,         # Alias for credits
    "valid": bool
}
```

**Equipment Item Structure:**
```gdscript
{
    "id": String,                 # Unique equipment ID
    "name": String,               # Display name
    "type": String,               # "weapon", "armor", "gear", etc.
    "description": String,        # Item description
    "assigned_to": String         # character_id or "" if unassigned
}
```

### 3.4 ShipPanel.get_panel_data()

**Output Structure:**
```gdscript
{
    "ship": Dictionary,           # Ship configuration
    "valid": bool
}
```

**Ship Dictionary Fields:**
```gdscript
{
    "name": String,               # Ship name
    "type": int,                  # Ship type enum
    "hull_points": int,           # Current hull
    "max_hull_points": int,       # Maximum hull
    "components": Array,          # Installed components
    "debt": int,                  # Ship debt amount
    "cargo_capacity": int         # Stash capacity
}
```

### 3.5 WorldInfoPanel.get_panel_data()

**Output Structure:**
```gdscript
{
    "world": Dictionary,          # Starting world
    "valid": bool
}
```

**World Dictionary Fields:**
```gdscript
{
    "name": String,               # World name
    "type": int,                  # World type enum
    "environment": int,           # Environment enum
    "traits": Array[String],      # World traits
    "current_area": String        # Starting area
}
```

### 3.6 ExpandedConfigPanel.get_panel_data()

**Output Structure:**
```gdscript
{
    "config": Dictionary,         # Campaign configuration
    "valid": bool
}
```

**Config Dictionary Fields:**
```gdscript
{
    "campaign_name": String,      # Campaign display name
    "difficulty": int,            # Difficulty level enum
    "ironman_mode": bool,         # Ironman enabled
    "story_track_enabled": bool,  # Story track enabled
    "victory_conditions": Dictionary,  # Victory config
    "house_rules": Array[int]     # Active house rules
}
```

---

## 4. Turn System Data Requirements

### 4.1 Campaign Resource Fields

The turn system expects these fields on the Campaign resource:

```gdscript
# Core data (REQUIRED)
crew_members: Array[Character]    # Must have at least 1 member
captain_data: Character           # Must have designated captain
ship_data: Dictionary             # Ship configuration
current_location: Dictionary      # Starting world

# Configuration
difficulty: int                   # Difficulty level
victory_conditions: Dictionary    # Victory configuration
house_rules: Array               # Active house rules

# State
game_phase: String               # "ready_for_turn_system" or "active"
turn_number: int                 # Current turn (0 before Turn 1)
```

### 4.2 Character Object Requirements

Each Character object must have:

```gdscript
# Identity (REQUIRED)
character_id: String              # Unique identifier
character_name: String            # Display name

# Stats (REQUIRED)
combat: int                       # 0-3
reactions: int                    # 1-3 (NOT "reaction")
toughness: int                    # 3-5
savvy: int                        # 0-3
tech: int                         # 0-2
move: int                         # 4-6
speed: int                        # 4-6

# State
experience: int                   # XP total (NOT "xp")
status: String                    # "ACTIVE", "INJURED", "DEAD", etc.
injuries: Array[Dictionary]       # Current injuries
equipment: Array[String]          # Equipment IDs

# Role
is_captain: bool                  # True for captain only
```

### 4.3 Equipment Assignment

Equipment is tracked in **EquipmentManager**, not directly on Character objects:

```gdscript
# Getting character equipment (correct way)
var equipment_manager = get_node("/root/EquipmentManager")
var equipment = equipment_manager.get_character_equipment(character_id)

# Character.equipment property may be empty - use EquipmentManager
```

---

## 5. Data Flow Diagram

```
[Wizard Panels] → get_panel_data()
        ↓
[CampaignCreationStateManager] → aggregate_all_panel_data()
        ↓
[CampaignFinalizationService] → finalize_campaign()
        ↓
    Transform crew to Array[Character]
    Transform captain to Character
    Transform equipment to Array[Dictionary]
    Set campaign.game_phase = "ready_for_turn_system"
        ↓
[Campaign Resource] → Saved to disk
        ↓
[GameStateManager] → load_campaign()
        ↓
[CampaignPhaseManager] → start_new_campaign_turn()
        ↓
    _verify_campaign_data_ready() → Check crew, captain, ship, credits
        ↓
[Turn System] → Travel → World → Battle → PostBattle
```

---

## 6. Validation Checklist

### Pre-Finalization (FinalPanel)

- [ ] Campaign name is not empty
- [ ] At least 4 crew members
- [ ] Captain is designated
- [ ] Ship is selected
- [ ] Starting world is selected

### Post-Finalization (CampaignPhaseManager)

- [ ] Campaign reference exists
- [ ] Crew members array is not empty
- [ ] Captain data exists
- [ ] Ship data exists
- [ ] Credits > 0
- [ ] game_phase == "ready_for_turn_system" or "active"
- [ ] Current location is set (for Turn 1)

---

## 7. Migration Notes

### From Legacy Save Files

When loading legacy saves that use old property names:

```gdscript
# In Character.from_dictionary():
character.reactions = data.get("reactions", data.get("reaction", 0))
character.experience = data.get("experience", data.get("xp", 0))
character.character_name = data.get("character_name", data.get("name", ""))
character.character_id = data.get("character_id", data.get("id", ""))
```

### Output Standardization

All NEW code should output canonical keys:

```gdscript
# CORRECT: Use canonical keys in output
var output = {
    "character_name": character.character_name,
    "character_id": character.character_id,
    "experience": character.experience,
    "reactions": character.reactions
}

# WRONG: Don't use legacy keys in new output
var output = {
    "name": character.character_name,   # Use character_name
    "id": character.character_id,       # Use character_id
    "xp": character.experience,         # Use experience
    "reaction": character.reactions     # Use reactions
}
```

---

## 8. Testing Data Contracts

### Test: Panel → Finalization

```gdscript
# Verify panel output meets contract
func test_crew_panel_output():
    var data = crew_panel.get_panel_data()
    assert_true(data.has("members"))
    assert_true(data.members is Array)
    for member in data.members:
        assert_true(member is Character or member is Dictionary)
        assert_true("character_id" in member or "id" in member)
```

### Test: Finalization → Turn System

```gdscript
# Verify campaign meets turn system requirements
func test_campaign_ready_for_turns():
    var campaign = finalization_service.finalize_campaign(wizard_data)
    assert_not_null(campaign)
    assert_false(campaign.crew_members.is_empty())
    assert_not_null(campaign.captain_data)
    assert_eq(campaign.game_phase, "ready_for_turn_system")
```

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Sprint 27.4 | Initial version - documented contracts from audit |
