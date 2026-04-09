class_name CompendiumEquipment
extends RefCounted
## Compendium Equipment Data - Training, Bot Upgrades, Ship Parts, Psionic Gear
##
## Data-driven equipment definitions from the Compendium expansion.
## All items gated behind DLCManager ContentFlags.
## All output is TEXT INSTRUCTIONS for the tabletop companion model.
##
## Usage:
##   CompendiumEquipment.get_advanced_training()   # NEW_TRAINING flag
##   CompendiumEquipment.get_bot_upgrades()         # BOT_UPGRADES flag
##   CompendiumEquipment.get_ship_parts()           # NEW_SHIP_PARTS flag
##   CompendiumEquipment.get_psionic_equipment()    # PSIONIC_EQUIPMENT flag


## ============================================================================
## JSON DATA LOADING
## ============================================================================

static var _data: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded: return
	_loaded = true
	var file := FileAccess.open("res://data/compendium/compendium_equipment.json", FileAccess.READ)
	if not file:
		push_warning("CompendiumEquipment: Could not load compendium_equipment.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_data = json.data
	file.close()


## ============================================================================
## DLC GATING HELPER
## ============================================================================

static func _get_dlc_manager() -> Node:
	if not Engine.get_main_loop():
		return null
	return Engine.get_main_loop().root.get_node_or_null("/root/DLCManager")


static func _is_flag_enabled(flag_name: String) -> bool:
	var dlc_mgr := _get_dlc_manager()
	if not dlc_mgr:
		return false
	var flag_value: int = dlc_mgr.ContentFlag.get(flag_name, -1)
	if flag_value < 0:
		return false
	return dlc_mgr.is_feature_enabled(flag_value)


## ============================================================================
## ADVANCED TRAINING (Compendium pp.26-28)
## Purchased during Advancement Phase with credits (NOT XP).
## Character spends a crew action to attend training.
## ============================================================================

static var ADVANCED_TRAINING: Array:
	get:
		_ensure_loaded()
		return _data.get("advanced_training", [])


## ============================================================================
## COMPENDIUM BOT UPGRADES (Compendium p.28)
## Purchased during Post-Battle Step 11 (Purchase Items) with credits.
## Max 1 upgrade installed per campaign turn.
## One of each upgrade per Bot. Lost if Bot is permanently destroyed.
## Soulless cannot use these (different tech base).
## ============================================================================

static var COMPENDIUM_BOT_UPGRADES: Array:
	get:
		_ensure_loaded()
		return _data.get("compendium_bot_upgrades", [])


## ============================================================================
## NEW SHIP PARTS (Compendium p.29)
## Installed using normal ship component rules (Core Rules p.60).
## ============================================================================

static var NEW_SHIP_PARTS: Array:
	get:
		_ensure_loaded()
		return _data.get("new_ship_parts", [])


## ============================================================================
## PSIONIC EQUIPMENT (Compendium p.29)
## Purchased during Post-Battle Step 11 (Purchase Items) with credits.
## Requires PSIONIC_EQUIPMENT DLC flag.
## ============================================================================

static var PSIONIC_EQUIPMENT: Array:
	get:
		_ensure_loaded()
		return _data.get("psionic_equipment", [])


## ============================================================================
## QUERY METHODS (DLC-gated)
## ============================================================================

## Returns advanced training options. Empty array if DLC not enabled.
static func get_advanced_training() -> Array:
	if not _is_flag_enabled("NEW_TRAINING"):
		return []
	return ADVANCED_TRAINING.duplicate()


## Returns compendium bot upgrades. Empty array if DLC not enabled.
static func get_bot_upgrades() -> Array:
	if not _is_flag_enabled("BOT_UPGRADES"):
		return []
	return COMPENDIUM_BOT_UPGRADES.duplicate()


## Returns new ship parts. Empty array if DLC not enabled.
static func get_ship_parts() -> Array:
	if not _is_flag_enabled("NEW_SHIP_PARTS"):
		return []
	return NEW_SHIP_PARTS.duplicate()


## Returns psionic equipment. Empty array if DLC not enabled.
static func get_psionic_equipment() -> Array:
	if not _is_flag_enabled("PSIONIC_EQUIPMENT"):
		return []
	return PSIONIC_EQUIPMENT.duplicate()


## Returns ALL purchasable compendium items for the Trade Phase shop.
## Combines ship parts + psionic gear (training and bot upgrades are Advancement Phase).
static func get_trade_phase_items() -> Array:
	var items: Array = []
	items.append_array(get_ship_parts())
	items.append_array(get_psionic_equipment())
	return items


## Returns trade phase items with DLC lock status for UI display.
## Each item gets "_dlc_locked": bool. Locked items should be shown but not purchasable.
static func get_trade_phase_items_with_lock_status() -> Array:
	var items: Array = []
	var ship_unlocked: bool = _is_flag_enabled("NEW_SHIP_PARTS")
	for part in NEW_SHIP_PARTS:
		var entry: Dictionary = part.duplicate()
		entry["_dlc_locked"] = not ship_unlocked
		items.append(entry)
	var psi_unlocked: bool = _is_flag_enabled("PSIONIC_EQUIPMENT")
	for psi in PSIONIC_EQUIPMENT:
		var entry: Dictionary = psi.duplicate()
		entry["_dlc_locked"] = not psi_unlocked
		items.append(entry)
	return items


## Returns ALL advancement phase compendium options.
## Combines advanced training + compendium bot upgrades, tagged by category.
static func get_advancement_phase_items() -> Array:
	var items: Array = []
	for item in get_advanced_training():
		var tagged := item.duplicate()
		tagged["compendium_category"] = "training"
		items.append(tagged)
	for item in get_bot_upgrades():
		var tagged := item.duplicate()
		tagged["compendium_category"] = "bot_upgrade"
		items.append(tagged)
	return items


## Get a specific item by ID from any category.
static func get_item_by_id(item_id: String) -> Dictionary:
	for list in [ADVANCED_TRAINING, COMPENDIUM_BOT_UPGRADES, NEW_SHIP_PARTS, PSIONIC_EQUIPMENT]:
		for item in list:
			if item.get("id", "") == item_id:
				return item
	return {}


## Get instruction text for a specific item (for cheat sheet / battle log).
static func get_instruction_text(item_id: String) -> String:
	var item := get_item_by_id(item_id)
	return item.get("instruction", "")
