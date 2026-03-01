# Ship Stash Management Implementation

**Status**: ✅ COMPLETE
**Date**: 2025-11-29
**Task**: Gap 1.1 - Ship Stash Management

## Problem Statement

ShipStashPanel.gd called EquipmentManager methods that didn't exist, and ship stash transfers didn't persist across save/load cycles.

## Root Cause

EquipmentManager was not registered as an autoload, so calls to `/root/EquipmentManager` were failing. While the ship stash methods existed in the core EquipmentManager, they weren't accessible to UI components.

## Solution

### 1. Registered EquipmentManager as Autoload

**File**: `project.godot`

Added EquipmentManager to the autoload list after DiceManager:

```gdscript
EquipmentManager="*res://src/core/equipment/EquipmentManager.gd"
```

### 2. Integrated Ship Stash Persistence into GameState

**File**: `src/core/state/GameState.gd`

#### Serialize Method (Line ~815)

Added ship stash serialization to `serialize()` method:

```gdscript
# Serialize ship stash from EquipmentManager
var equipment_manager = get_node_or_null("/root/EquipmentManager")
if equipment_manager and equipment_manager.has_method("serialize_ship_stash"):
	data["ship_stash"] = equipment_manager.serialize_ship_stash()
else:
	data["ship_stash"] = []
```

#### Deserialize Method (Line ~870)

Added ship stash deserialization to `deserialize()` method:

```gdscript
# Deserialize ship stash into EquipmentManager
if data.has("ship_stash"):
	var equipment_manager = get_node_or_null("/root/EquipmentManager")
	if equipment_manager and equipment_manager.has_method("deserialize_ship_stash"):
		var ship_stash_data = data.get("ship_stash", [])
		if ship_stash_data is Array:
			equipment_manager.deserialize_ship_stash(ship_stash_data)
			print("GameState: Loaded %d items into ship stash" % ship_stash_data.size())
		else:
			push_warning("Invalid ship stash data format in save file")
	else:
		push_warning("EquipmentManager not available - ship stash not loaded")
```

#### _gather_save_data Method (Line ~545)

Added ship stash to `_gather_save_data()` for the save_game flow:

```gdscript
# Add ship stash from EquipmentManager
var equipment_manager = get_node_or_null("/root/EquipmentManager")
if equipment_manager and equipment_manager.has_method("serialize_ship_stash"):
	save_data["ship_stash"] = equipment_manager.serialize_ship_stash()
else:
	save_data["ship_stash"] = []
```

## Existing EquipmentManager Methods (Already Implemented)

The following methods were already implemented in `src/core/equipment/EquipmentManager.gd`:

- `get_ship_stash() -> Array[Dictionary]` (Line 332)
- `get_ship_stash_count() -> int` (Line 337)
- `can_add_to_ship_stash() -> bool` (Line 341)
- `transfer_to_ship_stash(character_id: String, equipment_id: String) -> bool` (Line 346)
- `transfer_from_ship_stash(equipment_id: String, character_id: String) -> bool` (Line 378)
- `add_to_ship_stash(equipment_data: Dictionary) -> bool` (Line 415)
- `remove_from_ship_stash(equipment_id: String) -> Dictionary` (Line 428)
- `serialize_ship_stash() -> Array[Dictionary]` (Line 433)
- `deserialize_ship_stash(data: Array) -> void` (Line 437)

## Files Modified

1. `project.godot` - Added EquipmentManager autoload registration
2. `src/core/state/GameState.gd` - Added ship stash persistence (3 locations)

## Files NOT Modified (Already Working)

1. `src/core/equipment/EquipmentManager.gd` - All methods already exist
2. `src/ui/components/inventory/ShipStashPanel.gd` - Already correctly calls EquipmentManager methods
3. `src/ui/screens/world/components/AssignEquipmentComponent.gd` - Already correctly integrated

## Testing

Created comprehensive integration test suite:

**File**: `tests/integration/test_ship_stash_persistence.gd`

Test cases:
1. ✅ `test_ship_stash_persistence_basic()` - Basic save/load cycle
2. ✅ `test_transfer_to_stash_and_save()` - Transfer from character to stash
3. ✅ `test_stash_capacity_limit()` - 10-item capacity enforcement
4. ✅ `test_transfer_from_stash_to_character()` - Transfer from stash to character
5. ✅ `test_empty_stash_persistence()` - Empty stash save/load

## Success Criteria

✅ **All criteria met:**

1. Transfer item to stash → reload game → item still in stash
2. World phase equipment assignment includes stash
3. Follows signal wrapper pattern with connection checks
4. Dictionary-based equipment storage
5. Emits signals after state changes

## How to Test Manually

1. Start a new campaign
2. Create a character and assign equipment
3. Navigate to World Phase → Assign Equipment
4. Transfer an item from character to ship stash
5. Save the game
6. Reload the save file
7. Navigate back to Assign Equipment
8. Verify the item is still in the ship stash

## Performance Notes

- Ship stash is limited to 10 items (Five Parsecs rulebook compliance)
- Ship stash data is serialized/deserialized with every save/load
- EquipmentManager is an autoload singleton (single instance, always available)

## Integration Points

### ShipStashPanel → EquipmentManager
```gdscript
var stash_items = equipment_manager.get_ship_stash()
equipment_manager.transfer_from_ship_stash(equipment_id, character_id)
```

### AssignEquipmentComponent → EquipmentManager
```gdscript
equipment_manager.transfer_to_ship_stash(character_id, equipment_id)
equipment_manager.transfer_from_ship_stash(equipment_id, character_id)
```

### GameState → EquipmentManager
```gdscript
# On save:
data["ship_stash"] = equipment_manager.serialize_ship_stash()

# On load:
equipment_manager.deserialize_ship_stash(ship_stash_data)
```

## Known Limitations

None. The implementation is complete and follows all Godot 4.5 best practices.

## Future Enhancements

Potential improvements (not required for current implementation):

1. Add ship stash UI to Campaign Dashboard for quick access
2. Add sorting/filtering to ship stash display
3. Add bulk transfer operations (move all items at once)
4. Add ship component upgrades to increase stash capacity beyond 10 items

## References

- Five Parsecs Rulebook: Ship stash mechanics (p.45-46)
- EquipmentManager: `src/core/equipment/EquipmentManager.gd`
- ShipStashPanel: `src/ui/components/inventory/ShipStashPanel.gd`
- GameState persistence: `src/core/state/GameState.gd`
