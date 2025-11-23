# Five Parsecs Campaign Manager - Data Contracts Specification

## Overview

This document defines the **strict data contracts** for all campaign creation phases. These contracts are enforced by `CampaignCreationStateManager` validation and **must be followed exactly** to ensure successful campaign creation.

**Last Updated:** Week 4 Day 1 (November 17, 2025)  
**Status:** Production Specification

---

## Core Principles

1. **Field Name Accuracy**: Use exact field names as specified (e.g., `character_name` NOT `name`)
2. **Required vs Optional**: Required fields must be present and valid
3. **Type Safety**: Follow specified types exactly (String, int, float, Array, Dictionary)
4. **Completion Flags**: All phases require `is_complete: true` for advancement
5. **Validation Thresholds**: Numeric thresholds (e.g., `completion_level >= 0.75`) are hard requirements

---

## Phase 1: CONFIG Contract

### Required Fields
```gdscript
{
	"campaign_name": String,          # Non-empty campaign name
	"difficulty": int,                # Optional - defaults to STANDARD if not set
	"crew_size": int,                 # Optional - defaults to 4 if not set
	"is_complete": bool               # Must be true to advance
}
```

### Validation Rules
- `campaign_name` must not be empty
- If provided, `difficulty` and `crew_size` will be used; otherwise defaults apply
- Config phase allows warnings (missing difficulty/crew_size) but still validates successfully

### Example
```gdscript
var config_data = {
	"campaign_name": "The Frontier Raiders",
	"difficulty": 1,
	"crew_size": 4,
	"is_complete": true
}
```

---

## Phase 2: CAPTAIN_CREATION Contract

### Required Fields
```gdscript
{
	"character_name": String,         # ⚠️ NOT "name"!
	"combat": int,                    # ⚠️ Direct field (>= 1), NOT in stats
	"toughness": int,                 # ⚠️ Direct field (>= 1), NOT in stats
	"background": int,                # Enum value
	"motivation": int,                # Enum value
	"class": int,                     # Enum value
	"xp": int,                        # Experience points
	"is_complete": bool               # Must be true
}
```

### Optional Fields
```gdscript
{
	"stats": {                        # Detailed stat breakdown (optional)
		"reactions": int,
		"speed": int,
		"combat_skill": int,
		"toughness": int,
		"savvy": int
	}
}
```

### Validation Rules
- `character_name` must not be empty
- `combat` must be >= 1 (direct field, not nested in stats)
- `toughness` must be >= 1 (direct field, not nested in stats)
- `customization_completeness` must be >= 0.6 (60% minimum) if present

### Common Mistakes ❌
```gdscript
# WRONG - "name" instead of "character_name"
captain_data = {"name": "John Doe"}  # ❌ FAILS!

# WRONG - combat/toughness in stats object
captain_data = {
	"character_name": "John Doe",
	"stats": {"combat": 2, "toughness": 4}  # ❌ FAILS!
}
```

### Correct Example ✅
```gdscript
var captain_data = {
	"character_name": "John Doe",
	"combat": 2,                      # ✅ Direct field
	"toughness": 4,                   # ✅ Direct field
	"background": 1,
	"motivation": 2,
	"class": 3,
	"stats": {                        # Optional detailed stats
		"reactions": 1,
		"speed": 5,
		"combat_skill": 2,
		"toughness": 4,
		"savvy": 1
	},
	"xp": 0,
	"is_complete": true
}
```

---

## Phase 3: CREW_SETUP Contract

### Required Fields
```gdscript
{
	"members": Array,                 # Array of crew member dictionaries
	"size": int,                      # Crew size (>= 1)
	"has_captain": bool,              # ⚠️ Must be true!
	"completion_level": float,        # ⚠️ Must be >= 0.75 (75%)
	"is_complete": bool               # Must be true
}
```

### Crew Member Structure
```gdscript
{
	"character_name": String,
	"background": int,
	"motivation": int,
	"class": int,
	"stats": Dictionary,              # Stats structure (optional for dict members)
	"xp": int
}
```

### Validation Rules
- `members` array must not be empty
- `members.size()` must be >= `size` value
- `has_captain` must be `true`
- `completion_level` must be >= 0.75 (75% completion minimum)
- Dictionary-based members skip customization checks (for testing)

### Common Mistakes ❌
```gdscript
# WRONG - Missing has_captain
crew_data = {
	"members": [...],
	"size": 2  # ❌ Missing has_captain!
}

# WRONG - completion_level too low
crew_data = {
	"members": [...],
	"size": 2,
	"has_captain": true,
	"completion_level": 0.5  # ❌ Must be >= 0.75!
}
```

### Correct Example ✅
```gdscript
var crew_data = {
	"members": [
		{
			"character_name": "Crew Member 1",
			"background": 2,
			"motivation": 1,
			"class": 2,
			"stats": {"reactions": 1, "speed": 4, "combat_skill": 1, "toughness": 3, "savvy": 0},
			"xp": 0
		},
		{
			"character_name": "Crew Member 2",
			"background": 3,
			"motivation": 3,
			"class": 1,
			"stats": {"reactions": 0, "speed": 5, "combat_skill": 2, "toughness": 3, "savvy": 1},
			"xp": 0
		}
	],
	"size": 2,
	"has_captain": true,              # ✅ Required!
	"completion_level": 0.85,         # ✅ >= 0.75
	"is_complete": true
}
```

---

## Phase 4: SHIP_ASSIGNMENT Contract

### Required Fields
```gdscript
{
	"name": String,                   # Ship name (non-empty)
	"type": String,                   # Ship type (non-empty)
	"is_configured": bool,            # ⚠️ Must be true!
	"hull_points": int,               # Current hull
	"max_hull_points": int,           # Maximum hull
	"is_complete": bool               # Must be true
}
```

### Optional Fields
```gdscript
{
	"upgrades": Array,                # Ship upgrades (can be empty)
	"cargo_capacity": int             # Cargo space
}
```

### Validation Rules
- `name` must not be empty
- `type` must not be empty
- `is_configured` must be `true`

### Common Mistakes ❌
```gdscript
# WRONG - Missing is_configured
ship_data = {
	"name": "Starship",
	"type": "freighter"  # ❌ Missing is_configured!
}
```

### Correct Example ✅
```gdscript
var ship_data = {
	"name": "Test Starship",
	"type": "light_freighter",
	"hull_points": 6,
	"max_hull_points": 6,
	"upgrades": [],
	"cargo_capacity": 10,
	"is_configured": true,            # ✅ Required!
	"is_complete": true
}
```

---

## Phase 5: EQUIPMENT_GENERATION Contract

### Required Fields
```gdscript
{
	"equipment": Array,               # ⚠️ Must be non-empty!
	"credits": int,                   # ⚠️ NOT "starting_credits"!
	"is_complete": bool               # Must be true
}
```

### Equipment Item Structure
```gdscript
{
	"name": String,
	"type": String,
	"quantity": int
}
```

### Validation Rules
- `equipment` array must not be empty
- `is_complete` must be `true`
- Use `credits` NOT `starting_credits`

### Common Mistakes ❌
```gdscript
# WRONG - Empty equipment array
equipment_data = {
	"equipment": [],  # ❌ Must have at least one item!
	"credits": 1000
}

# WRONG - "starting_credits" field name
equipment_data = {
	"equipment": [...],
	"starting_credits": 1000  # ❌ Should be "credits"!
}
```

### Correct Example ✅
```gdscript
var equipment_data = {
	"equipment": [
		{"name": "Blade", "type": "weapon", "quantity": 2},
		{"name": "Handgun", "type": "weapon", "quantity": 1}
	],
	"credits": 1000,                  # ✅ NOT "starting_credits"
	"is_complete": true
}
```

---

## Phase 6: WORLD_GENERATION Contract

### Required Fields
```gdscript
{
	"current_world": String,          # World name
	"is_complete": bool               # Must be true
}
```

### Optional Fields
```gdscript
{
	"traits": Array,                  # World traits (optional)
	"faction": String                 # Controlling faction (optional)
}
```

### Validation Rules
- **Highly permissive** - world data can be minimal or even empty
- Empty world will use defaults without blocking validation
- This is intentional to allow campaign creation to complete

### Example
```gdscript
var world_data = {
	"current_world": "Frontier Station Alpha",
	"traits": ["industrial", "high_tech"],
	"faction": "Unity",
	"is_complete": true
}
```

---

## Complete Campaign Data Contract

### Final Structure
When `complete_campaign_creation()` is called, the complete data structure includes all phases plus metadata:

```gdscript
{
	"config": {/* Config contract */},
	"captain": {/* Captain contract */},
	"crew": {/* Crew contract */},
	"ship": {/* Ship contract */},
	"equipment": {/* Equipment contract */},
	"world": {/* World contract */},
	"metadata": {
		"created_at": String,          # ISO datetime
		"completed_at": String,        # ISO datetime
		"is_complete": bool,           # true
		"total_crew_size": int,
		"starting_credits": int,
		"crew_statistics": Dictionary  # Calculated stats
	}
}
```

---

## Validation Error Messages

### Common Validation Failures

| Error Message | Cause | Fix |
|---------------|-------|-----|
| "Captain must have a name" | Missing `character_name` | Add `character_name` field |
| "Captain needs valid combat attribute" | Missing/invalid `combat` | Add `combat` >= 1 as direct field |
| "Captain needs valid toughness attribute" | Missing/invalid `toughness` | Add `toughness` >= 1 as direct field |
| "Crew must have an assigned captain" | `has_captain` is false/missing | Set `has_captain: true` |
| "Crew setup needs more completion" | `completion_level` < 0.75 | Set `completion_level` >= 0.75 |
| "Ship configuration incomplete" | `is_configured` is false/missing | Set `is_configured: true` |
| "Starting equipment must be generated" | Empty `equipment` array | Add at least one equipment item |

---

## Testing Best Practices

### Complete Test Data Template
```gdscript
# Use this as a reference for creating valid test data
var complete_campaign_data = {
	"config": {
		"campaign_name": "Test Campaign",
		"is_complete": true
	},
	"captain": {
		"character_name": "Test Captain",
		"combat": 2,
		"toughness": 4,
		"background": 1,
		"motivation": 2,
		"class": 3,
		"xp": 0,
		"is_complete": true
	},
	"crew": {
		"members": [/* at least one member */],
		"size": 2,
		"has_captain": true,
		"completion_level": 0.85,
		"is_complete": true
	},
	"ship": {
		"name": "Test Ship",
		"type": "freighter",
		"hull_points": 6,
		"max_hull_points": 6,
		"is_configured": true,
		"is_complete": true
	},
	"equipment": {
		"equipment": [{"name": "Blade", "type": "weapon", "quantity": 1}],
		"credits": 1000,
		"is_complete": true
	},
	"world": {
		"current_world": "Test World",
		"is_complete": true
	}
}
```

---

## Migration Notes

### Week 3 Data Contract Fixes
The following field names were corrected during Week 3 testing:

1. **Captain**: `"name"` → `"character_name"` (CaptainPanel.gd fixed)
2. **Equipment**: `"starting_credits"` → `"credits"` (EquipmentPanel.gd fixed)
3. **Crew**: Added `"has_captain"` and `"completion_level"` fields (CrewPanel.gd enhanced)
4. **Ship**: Added `"is_configured"` field (ShipPanel.tscn updated)

### Backward Compatibility
- Old save files using `"name"` for captain will need migration
- Equipment files using `"starting_credits"` will need field renaming
- Crew data without `completion_level` will default to 0.0 (failing validation)

---

## Enforcement

These contracts are enforced by:
- `CampaignCreationStateManager._validate_captain_phase()`
- `CampaignCreationStateManager._validate_crew_phase()`
- `CampaignCreationStateManager._validate_ship_phase()`
- `CampaignCreationStateManager._validate_equipment_phase()`
- `CampaignCreationStateManager._validate_world_phase()`
- `CampaignCreationStateManager._validate_final_phase()`

All validation occurs before campaign completion and phase advancement.

---

**✅ Following these contracts ensures 100% test pass rate and successful campaign creation!**
