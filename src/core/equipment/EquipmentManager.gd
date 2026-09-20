@tool
extends Node

const CharacterManager = preload("res://src/core/character/Management/CharacterManager.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const BattleResultsManager = preload("res://src/core/battle/BattleResultsManager.gd")

signal equipment_acquired(equipment_data: Dictionary)
signal equipment_assigned(character_id: String, equipment_id: String)
signal equipment_removed(character_id: String, equipment_id: String)
signal equipment_sold(equipment_id: String, credits: int)
signal equipment_list_updated()

var character_manager
var game_state: FiveParsecsGameState
var battle_results_manager: BattleResultsManager

# Equipment categories
enum EquipmentCategory {
	WEAPON,
	ARMOR,
	GEAR,
	CONSUMABLE,
	SPECIAL,
	CREDITS
}

# Equipment storage
var _equipment_storage: Array = []
var _character_equipment: Dictionary = {}

## When false, add_equipment() does NOT write through to GameState.current_campaign.
## Disabled for the duration of the campaign-creation wizard, where the "current"
## campaign is still the previously played one. See add_equipment().
var _campaign_write_through: bool = true


func set_campaign_write_through(enabled: bool) -> void:
	## Gate the campaign write-through. Callers MUST re-enable it — leaving it off
	## would silently stop the live campaign's ship stash from persisting.
	_campaign_write_through = enabled


func _remove_from_campaign_stash(equipment_id: String) -> void:
	## Mirror of add_equipment()'s write-through, for removals.
	##
	## THE BUG THIS FIXES: add_equipment() wrote BOTH the cache and the campaign, but
	## remove_equipment() only ever emptied the cache. So selling an item or using a
	## single-use consumable took it out of the runtime list while leaving it in
	## campaign.equipment_data["equipment"] — the canonical store — and the item
	## REAPPEARED on the next load. One item, one home (the tabletop invariant) was
	## broken on every removal.
	##
	## Gated the same way as the add: during campaign creation the "current" campaign
	## is still the previously played one, so we must not reach into its stash.
	if not _campaign_write_through:
		return
	var gs = get_node_or_null("/root/GameState")
	if not (gs and gs.get("current_campaign") and "equipment_data" in gs.current_campaign):
		return
	var stash = gs.current_campaign.equipment_data.get("equipment", null)
	if not (stash is Array):
		return
	var arr: Array = stash
	for i in range(arr.size() - 1, -1, -1):
		var it = arr[i]
		if it is Dictionary and str((it as Dictionary).get("id", "")) == equipment_id:
			arr.remove_at(i)
	gs.current_campaign.equipment_data["equipment"] = arr

# Equipment database loaded from JSON (Core Rules pp.49-58)
var _equipment_db: Dictionary = {}
var _db_weapons: Array = []
var _db_armor: Array = []
var _db_gear: Array = []
var _onboard_items: Array = []  # On-board items from Core Rules pp.57-58

func _init() -> void:
	pass

func _ready() -> void:
	_load_equipment_database()

func _load_equipment_database() -> void:
	## Reuse GameDataManager's already-parsed copy instead of re-reading the file.
	##
	## equipment_database.json (~20 KB) was being parsed THREE times at every cold
	## start: GameDataManager.load_equipment_database() (autoload #3),
	## DataManager._load_json_databases() (#4) and here (#20). That is pure
	## duplicated work on the main thread before the menu is interactive, and on a
	## mid-range Android phone JSON parsing plus the Dictionary/Array allocation it
	## causes is a measurable slice of boot.
	##
	## Ordering is safe: GameDataManager is autoload #3 and EquipmentManager is #20,
	## and _ready() runs in registration order, so its `equipment_database` is
	## already populated by the time this runs. The file fallback below stays for
	## unit tests and any context where the autoload is absent — it must not become
	## a hard dependency.
	var gdm: Node = null
	var loop := Engine.get_main_loop()
	if loop and loop is SceneTree:
		gdm = (loop as SceneTree).root.get_node_or_null("/root/GameDataManager")
	if gdm and gdm.get("equipment_database") is Dictionary \
			and not (gdm.equipment_database as Dictionary).is_empty():
		_equipment_db = gdm.equipment_database
		_db_weapons = _equipment_db.get("weapons", [])
		_db_armor = _equipment_db.get("armor", [])
		_db_gear = _equipment_db.get("gear", [])
		_load_onboard_items()
		return

	var path := "res://data/equipment_database.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("EquipmentManager: Cannot open equipment_database.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("EquipmentManager: Failed to parse equipment_database.json")
		return
	if json.data is Dictionary:
		_equipment_db = json.data
		_db_weapons = _equipment_db.get("weapons", [])
		_db_armor = _equipment_db.get("armor", [])
		_db_gear = _equipment_db.get("gear", [])

	# Load on-board items (Core Rules pp.57-58 — ship items not carried into battle)
	_load_onboard_items()

func _load_onboard_items() -> void:
	var path := "res://data/onboard_items.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("EquipmentManager: Failed to parse onboard_items.json")
		return
	file.close()
	if json.data is Dictionary:
		_onboard_items = json.data.get("onboard_items", [])


## Return basic weapons (always available, 1 credit each — Core Rules p.126)
func get_basic_weapons() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for w in _db_weapons:
		if w is Dictionary and w.get("basic", false):
			result.append({"name": w.get("name", ""), "type": "weapon", "value": int(w.get("cost", 1)), "_basic": true})
	if result.is_empty():
		push_warning("EquipmentManager: No basic weapons found in equipment_database.json")
	return result

func setup(state: FiveParsecsGameState, char_manager, battle_results_manager: BattleResultsManager) -> void:
	game_state = state
	character_manager = char_manager
	battle_results_manager = battle_results_manager
	
	# Connect to character signals
	if character_manager:
		if character_manager.is_connected("character_added", _on_character_added):
			character_manager.disconnect("character_added", _on_character_added)
		character_manager.connect("character_added", _on_character_added)
		
		if character_manager.is_connected("character_removed", _on_character_removed):
			character_manager.disconnect("character_removed", _on_character_removed)
		character_manager.connect("character_removed", _on_character_removed)

## Equipment Management Functions

## Add new equipment to storage
func add_equipment(equipment_data: Dictionary) -> bool:
	if equipment_data.is_empty() or not equipment_data.has("id"):
		push_error("Invalid equipment data")
		return false
	
	# Check for duplicate IDs
	for item in _equipment_storage:
		if item.get("id") == equipment_data.get("id"):
			push_error("Equipment with ID already exists: " + equipment_data.get("id"))
			return false
	
	_equipment_storage.append(equipment_data)

	# Write-through to campaign equipment_data for save/load persistence.
	# IDEMPOTENT BY ID: the ship stash is a set of unique physical item cards
	# (tabletop invariant "one item, one home"), so an id already present is
	# NEVER re-appended. Without this guard the restore pipeline — which calls
	# add_equipment() for items it just read OUT of this same stash, after
	# clear_all_equipment() emptied only the runtime cache and not the campaign
	# stash — re-appended a copy of every unique item on each load, growing the
	# persisted stash unboundedly across save/load cycles (8 -> 16 -> 24 -> ...).
	#
	# SUPPRESSED DURING CAMPAIGN CREATION. The write-through targets whatever
	# GameState currently holds, and during the creation wizard that is still the
	# PREVIOUS campaign — set_current_campaign() is not called until after
	# finalization (CampaignCreationUI.gd:335). So the new crew's starting gear,
	# loaded at creation step 4, was being appended to the OLD campaign's ship stash.
	# The new campaign does not need it: finalization builds equipment_data from the
	# wizard's own data (CampaignFinalizationService.gd:280).
	var gs = get_node_or_null("/root/GameState")
	if _campaign_write_through and gs and gs.get("current_campaign") \
			and "equipment_data" in gs.current_campaign:
		var stash: Array = gs.current_campaign.equipment_data.get("equipment", [])
		var new_id: String = str(equipment_data.get("id", ""))
		var already_present: bool = false
		for existing in stash:
			if existing is Dictionary and str(existing.get("id", "")) == new_id:
				already_present = true
				break
		if not already_present:
			stash.append(equipment_data)
			gs.current_campaign.equipment_data["equipment"] = stash

	equipment_acquired.emit(equipment_data)
	equipment_list_updated.emit()

	return true

## Get equipment by ID
func get_equipment(equipment_id: String) -> Dictionary:
	for item in _equipment_storage:
		if item.get("id") == equipment_id:
			return item
	
	return {}

## Remove equipment from storage
func remove_equipment(equipment_id: String) -> bool:
	for i in range(_equipment_storage.size() - 1, -1, -1):
		if _equipment_storage[i].get("id") == equipment_id:
			_equipment_storage.remove_at(i)
			_remove_from_campaign_stash(equipment_id)

			# Remove from any characters who might have it
			for character_id in _character_equipment:
				var equipment_list = _character_equipment[character_id]
				for j in range(equipment_list.size() - 1, -1, -1):
					if equipment_list[j] == equipment_id:
						equipment_list.remove_at(j)
						equipment_removed.emit(character_id, equipment_id)
			
			equipment_list_updated.emit()
			return true
	
	return false

## Assign equipment to a character
func assign_equipment_to_character(character_id: String, equipment_id: String) -> bool:
	if not character_manager.has_character(character_id):
		push_error("Character does not exist: " + character_id)
		return false
	
	var equipment_data = get_equipment(equipment_id)
	if equipment_data.is_empty():
		push_error("Equipment does not exist: " + equipment_id)
		return false
	
	# Initialize equipment list for character if needed
	if not character_id in _character_equipment:
		_character_equipment[character_id] = []
	
	# Check equipment type and compatibility
	var character = character_manager.get_character(character_id)
	if not can_character_use_equipment(character, equipment_data):
		push_warning("Character cannot use this equipment")
		return false
	
	# Check equipment slots. Core Rules p.54: "A character may wear no more
	# than one piece of armor and one screen." This enforced the armor half
	# via the same dead `category` enum the compatibility gate used, so it
	# never fired either; it now uses the tolerant test.
	if is_armor_item(equipment_data):
		# Remove existing armor first
		for eq_id in _character_equipment[character_id]:
			var eq = get_equipment(eq_id)
			if is_armor_item(eq):
				_character_equipment[character_id].erase(eq_id)
				equipment_removed.emit(character_id, eq_id)
				break
	
	# Add equipment to character
	_character_equipment[character_id].append(equipment_id)
	
	# Update the actual character object with equipment
	_update_character_with_equipment(character_id)
	
	equipment_assigned.emit(character_id, equipment_id)
	equipment_list_updated.emit()
	return true


## Get all equipment assigned to a character
func get_character_equipment(character_id: String) -> Array:
	if not character_id in _character_equipment:
		return []
	
	return _character_equipment[character_id].duplicate()

## Get all equipment in storage
func get_all_equipment() -> Array:
	## The flat registry of ALL known items — ship stash PLUS character-owned gear.
	## Cache-backed by design: character ownership only exists here, not on the
	## campaign Resource. Do NOT make this owner-backed; the ship stash is a SUBSET
	## of it and has its own accessor below.
	return _equipment_storage.duplicate()


## Ship-stash API — 8 call sites (ShipStashPanel, UpkeepPhaseComponent,
## PurchaseItemsComponent, PostBattleSequence) guard on these names, which never
## existed on this autoload, so the stash UI read empty and purchases were dropped.
## The ship stash IS this manager's equipment storage (campaign.equipment_data).
func get_ship_stash() -> Array:
	## Resolve from the OWNER, not the cache.
	##
	## campaign.equipment_data["equipment"] is canonical per the data-ownership table.
	## _equipment_storage is populated ONLY at campaign load
	## (GameState._restore_equipment_from_campaign), so mid-session it is a frozen
	## snapshot taken at load time.
	##
	## TradePhasePanel writes the owner directly at SIX sites (:436 ship component,
	## :445 buy, :492 sell, :611 the 3cr trade-table roll, :646/:665 Merchant reroll)
	## and never touches this manager. So anything bought or rolled during the TRADING
	## step — mandatory every campaign turn — was invisible to every stash reader:
	## ShipStashPanel showed "No items in ship stash", the p.76 sell-for-upkeep dialog
	## would not offer it, the in-battle consumable picker could not use it, and a Fake
	## ID bought in Trade granted no +1 on the licence roll (Core Rules p.57,
	## TravelPhase._fake_id_license_bonus). The dashboard reads equipment_data directly
	## and DID show it — hence "my gear vanished in Trade but not on the dashboard".
	##
	## Gated on _campaign_write_through, which already means "current_campaign is the
	## campaign we belong to". During the creation wizard it is FALSE (current_campaign
	## is still the previously played one), so the wizard correctly reads its own cache
	## rather than the old campaign's stash. Campaign-less modes fall through too.
	if _campaign_write_through:
		var gs = get_node_or_null("/root/GameState")
		if gs and gs.get("current_campaign") and "equipment_data" in gs.current_campaign:
			var stash = gs.current_campaign.equipment_data.get("equipment", null)
			if stash is Array:
				return (stash as Array).duplicate()
	return _equipment_storage.duplicate()

func get_ship_stash_count() -> int:
	## Owner-backed, same reason as get_ship_stash(): counting the cache reported a
	## stale total after any Trade purchase.
	return get_ship_stash().size()

func can_add_to_ship_stash() -> bool:
	return true  # no hard cap in the data model; panels enforce any display caps

func add_to_ship_stash(item: Dictionary) -> bool:
	var to_add: Dictionary = item.duplicate(true)
	if str(to_add.get("id", "")) == "":
		to_add["id"] = "item_%d_%d" % [Time.get_ticks_msec(), randi() % 100000]
	return add_equipment(to_add)  # campaign write-through, idempotent by id

## Consumables currently in the ship stash. (Core Rules p.54: consumables are not
## carried by a specific character — any crew member may use one from the Stash in battle.)
func get_stash_consumables() -> Array:
	## Owner-backed. Iterating the cache meant a consumable bought during Trade could
	## not be used in the next battle (TacticalBattleUI:3866).
	var out: Array = []
	for eq in get_ship_stash():
		if eq is Dictionary and (str(eq.get("type", "")).to_lower() == "consumable"
				or str(eq.get("category", "")).to_lower() == "consumable"):
			out.append(eq)
	return out

## Use a stash consumable (Core Rules p.54, a Free Action in battle). This is a TABLETOP
## COMPANION: it does not simulate the effect — it returns the effect text for the player
## to apply at the table — and tracks depletion (single-use items are removed from the
## Stash; multi-use items decrement via use_consumable). Returns {used, name, effect, depleted}.
func use_stash_consumable(item_id: String) -> Dictionary:
	## OWNER-BACKED, matching get_stash_consumables() one screen up.
	##
	## THE BUG THIS FIXES: the picker and the USE disagreed about where the stash
	## lives. `get_stash_consumables()` reads the owner (`get_ship_stash()` ->
	## `campaign.equipment_data["equipment"]`) while this iterated
	## `_equipment_storage`, the cache populated ONLY at campaign load. So any
	## consumable acquired mid-session — bought in the p.125 Purchase Items step,
	## rolled off the p.133 Consumables subtable, taken as Battlefield Finds —
	## appeared in the in-battle "Consumable" picker and returned `{"used": false}`
	## when tapped. Nothing happened, and nothing said why. The Stim-pack is 30%
	## of the Consumables subtable, so this was the single most likely item in the
	## game to fail.
	##
	## Resolve against the owner; keep the cache in sync where the item is also
	## cached, because `use_consumable()` decrements the dict it is handed.
	for eq in get_ship_stash():
		if not (eq is Dictionary) or str(eq.get("id", "")) != item_id:
			continue
		var effect: String = str(eq.get("description", eq.get("effect", "")))
		var item_name: String = str(eq.get("name", "Consumable"))
		var single_use: bool = bool(eq.get("single_use", true))  # book consumables are single-use
		var depleted: bool = single_use
		if not single_use and (eq.has("remaining_uses") or eq.has("uses")):
			depleted = bool(use_consumable(eq).get("depleted", false))
			# Mirror the decrement onto the cached copy, if there is one, so a
			# later cache-backed read does not resurrect the spent use.
			for cached in _equipment_storage:
				if cached is Dictionary and str(cached.get("id", "")) == item_id:
					for key in ["remaining_uses", "uses"]:
						if eq.has(key):
							cached[key] = eq[key]
					break
		if depleted:
			remove_equipment(item_id)
			_remove_from_campaign_stash(item_id)
		equipment_list_updated.emit()
		return {"used": true, "name": item_name, "effect": effect, "depleted": depleted}
	return {"used": false}

## Reset the manager to an empty state. Used by GameState.restore_equipment_from_campaign
## when rehydrating runtime state from a newly-loaded campaign Resource so leftover
## items from a previous session don't bleed into the new one.
func clear_all_equipment() -> void:
	## Clear the runtime caches AND the canonical owner.
	##
	## This used to clear only _equipment_storage / _character_equipment. But every
	## stash READ is owner-backed (get_ship_stash() resolves
	## campaign.equipment_data["equipment"], see its note), so clearing the caches
	## cleared nothing observable — get_ship_stash() kept returning the same items
	## and callers that use this to reset saw the previous state survive intact.
	## add_equipment()'s idempotency note at :245 already documents the asymmetry;
	## this closes it.
	##
	## Gated on _campaign_write_through for the same reason add_equipment() is:
	## during the creation wizard GameState still holds the PREVIOUS campaign, and
	## wiping that campaign's stash from here would destroy real data.
	_equipment_storage.clear()
	_character_equipment.clear()
	var gs = get_node_or_null("/root/GameState")
	if _campaign_write_through and gs and gs.get("current_campaign") \
			and "equipment_data" in gs.current_campaign:
		var ed: Dictionary = gs.current_campaign.equipment_data
		if ed.has("equipment") and ed["equipment"] is Array:
			ed["equipment"].clear()
	equipment_list_updated.emit()

## Bulk-set a character's owned equipment IDs, bypassing the normal compatibility
## and slot checks in assign_equipment_to_character(). Used by the restore pipeline
## after reconstructing ownership from persisted data — the items already existed
## in a prior session and went through those checks then. Do NOT use for runtime
## assignment; use assign_equipment_to_character() for that.
func set_character_equipment_ids(character_id: String, equipment_ids: Array) -> void:
	_character_equipment[character_id] = equipment_ids.duplicate()
	equipment_list_updated.emit()


## Sell equipment — Core Rules p.76: each item sold = 1 credit of Upkeep
func sell_equipment(equipment_id: String) -> int:
	var equipment_data = get_equipment(equipment_id)
	if equipment_data.is_empty():
		return 0

	var sell_value := 1  # Core Rules p.76: flat 1 credit per item

	if remove_equipment(equipment_id):
		if game_state:
			game_state.add_credits(sell_value)

		equipment_sold.emit(equipment_id, sell_value)
		return sell_value

	return 0

# NOTE (2026-06-01 rules-accuracy consolidation): the battle-loot generator
# (generate_battle_loot + _roll_on_loot_table + its subtable helpers) was REMOVED.
# It was dead — its only caller, GameSystemManager.process_battle_loot(), had no callers.
# The live post-battle loot path is PostBattlePhase -> LootProcessor, which now resolves
# loot through the single canonical LootTableResolver (src/core/equipment/LootTableResolver.gd,
# Core Rules p.130-133). It also carried a fabricated "difficulty >= 4" bonus roll with no
# rulebook basis (the book grants one roll per battle; 3 for a Quest final stage; 0 for Invasion).


## Create gear with the specified parameters (used by import/generation systems)
func create_gear_item(name: String, gear_type: String, effect: Dictionary) -> Dictionary:
	return {
		"id": "gear_" + str(randi() % 100000),
		"name": name,
		"category": EquipmentCategory.GEAR,
		"type": gear_type,
		"effect": effect,
		"condition": 100,
		"traits": [],
		"value": 3  # Default purchase cost (Core Rules p.125: 3 credits for a table roll)
	}


## Check if a character can use a piece of equipment.
##
## PUBLIC since 2026-09-10. It resolves two book rules (Compendium p.18
## Psionic weapons, p.13 Krag armor) and had no public form, which is part of
## why AssignEquipmentComponent re-implements the Krag half itself instead of
## asking. New callers should prefer this over a private copy of either rule.
##
## ⚠ SCOPE: this gates EquipmentManager's own per-character cache, NOT what a
## campaign persists. Its only caller is EquipmentPanel (campaign creation),
## and CampaignFinalizationService never consults this manager — it builds
## campaign.equipment_data and each member's equipment from the wizard's own
## dictionary via split_equipment_by_owner(), keyed on item["owner"]. Enforcing
## a rule at CAMPAIGN level means gating there, not here.
##
## Until 2026-09-10 this dispatched on equipment_data["category"], an enum that
## its only caller never writes — _create_equipment_item() stamps
## `type: "Weapon"/"Armor"/"Gear"` as a STRING. So category defaulted to GEAR
## for every item and the whole function returned true unconditionally: a
## permanently-TRUE gate, the mirror of the permanently-false has_method guards
## the dead-guard lint exists to catch. It now uses the same tolerant tests the
## live World-Phase path uses.
func can_character_use_equipment(character, equipment_data: Dictionary) -> bool:
	var is_weapon: bool = is_weapon_item(equipment_data)
	var is_armor: bool = is_armor_item(equipment_data)

	# For weapons, check psionic restrictions only
	# (Core Rules pp.50-51 has NO class-based gates on weapons; Sprint A Bug 3 /
	# Sprint C Item 7 deleted the fabricated SOLDIER/BRUTE/SECURITY Heavy
	# restriction along with the legacy FiveParsecsGameEnums enum.)
	if is_weapon:
		# Compendium p.18, verbatim: "Psionics can only ever use weapons that
		# have either the Pistol or Melee traits." (Cited p.20 until
		# 2026-09-10; p.18 is the Psionics Limitations page.) The rule is also
		# DELIVERED to the player on two reference surfaces:
		# TacticalBattleUI.gd:4479 and CharacterDetailsScreen.gd:1352.
		var char_psionic_powers: Array = character.get("psionic_powers", []) if character is Dictionary else []
		if char_psionic_powers.is_empty() and character is Dictionary:
			var pp: String = character.get("psionic_power", "")
			if pp != "":
				char_psionic_powers = [pp]
		elif not character is Dictionary and "psionic_powers" in character:
			char_psionic_powers = character.psionic_powers
		if not char_psionic_powers.is_empty():
			var traits: Array = equipment_data.get("traits", [])
			var has_pistol_or_melee: bool = false
			for t in traits:
				var t_lower: String = str(t).to_lower()
				if t_lower == "pistol" or t_lower == "melee":
					has_pistol_or_melee = true
					break
			if not has_pistol_or_melee:
				return false

	# For armor, check Krag compatibility.
	#
	# A "Heavy armor requires Toughness 3+" gate was removed here on
	# 2026-09-10 as FABRICATED. Core Rules pp.54-55 list all nine protective
	# devices and have no weight classes and no Toughness requirement; the
	# only constraint the book states is "A character may wear no more than
	# one piece of armor and one screen" (p.54), which is delivered on the
	# Cheat Sheet. `armor_type` as an enum appears in ZERO data files, and
	# the comparison was int-vs-String besides — BattleCalculations uses
	# "light"/"combat"/"heavy" STRINGS, a separate and live representation.
	if is_armor:
		# Compendium p.13: Krag armor compatibility. That page states BOTH
		# halves of what this gate enforces — "Armor found from other
		# sources will not fit Krag", and "Skulkers and Engineers can wear
		# both Krag and non-Krag armor without modification".
		#
		# Cited p.15 until 2026-09-10. p.15 is the SKULKER page, which
		# genuinely hosts the exemption this branch implements — which is
		# exactly why the wrong cite read as correct for so long.
		var char_species: String = str(character.get("species_id",
			character.get("species", ""))).to_lower()
		if char_species == "krag":
			# Krag can only wear armor marked as Krag-compatible
			if not equipment_data.get("is_krag_armor", false):
				return false
		elif equipment_data.get("is_krag_armor", false):
			# Non-Krag can't wear Krag-only armor unless Skulker or Engineer
			if char_species != "skulker":
				var char_class_str: String = str(
					character.get("character_class", "")).to_lower()
				if char_class_str != "engineer":
					return false

	# By default, equipment is usable
	return true


## True if an item dict is a weapon, tolerant of both representations, exactly as
## is_armor_item() is below. Data items use `{"type": "Weapon", ...}` while
## generated market items carry the EquipmentCategory.WEAPON enum.
func is_weapon_item(item: Dictionary) -> bool:
	if item.get("category", -1) == EquipmentCategory.WEAPON:
		return true
	return str(item.get("type", item.get("category", ""))).to_lower() == "weapon"


## True if an item dict is armor, tolerant of both representations in the codebase:
## the EquipmentCategory.ARMOR enum OR a string type/category "armor" (data items use
## `{"type": "armor", ...}`, e.g. "Combat Armor").
func is_armor_item(item: Dictionary) -> bool:
	if item.get("category", -1) == EquipmentCategory.ARMOR:
		return true
	return str(item.get("type", item.get("category", ""))).to_lower() == "armor"

## Compendium p.13, SECOND Krag armor clause, verbatim: "Armor found from
## other sources will not fit Krag. Armor can be modified to fit Krag for 2
## Credits (and reversed for the same cost), while doing your shopping during
## Post-battle Step 11: Purchase Items (core rulebook, p.125)."
##
## This is NOT the route for armor that came off a Trade table roll. That is
## the FIRST clause on the same page and it is FREE — see choose_krag_fit().
func modify_armor_for_krag(item: Dictionary) -> bool:
	if not is_armor_item(item):
		return false
	var gsm: Node = Engine.get_main_loop().root.get_node_or_null(
		"/root/GameStateManager") if Engine.get_main_loop() else null
	if not gsm or not gsm.has_method("get_credits"):
		return false
	var credits: int = gsm.get_credits() if gsm.has_method("get_credits") else 0
	if credits < 2:
		return false
	# Toggle Krag designation and deduct 2 credits
	item["is_krag_armor"] = not item.get("is_krag_armor", false)
	if gsm.has_method("set_credits"):
		gsm.set_credits(credits - 2)
	return true


## Compendium p.13, FIRST Krag armor clause, verbatim: "Armor acquired from a
## Trade table roll must be selected by the player to be Krag-armor or not."
##
## That selection is FREE and is made once. It went unimplemented until
## 2026-09-10: the ONLY writer of `is_krag_armor` anywhere in the codebase was
## the 2-credit toggle above, so every piece of armor in the game arrived
## non-Krag and a Krag was charged 2 Credits for all of it — including the
## one case the book gives away. The provenance flag this reads,
## `acquired_from_trade`, was stamped by a generation helper that had no callers
## and whose key had no readers, so the rule was half-built and inert.
##
## `krag_fit_chosen` is a SEPARATE key on purpose. `acquired_from_trade` records
## where the item came from and is never cleared; `krag_fit_chosen` records that
## the one free selection has been spent. Folding them into a single key would
## make a spent choice indistinguishable from loot that never came off the Trade
## table, and the player would get the free fit again on the same item.
func has_unspent_krag_choice(item: Dictionary) -> bool:
	if not is_armor_item(item):
		return false
	if not bool(item.get("acquired_from_trade", false)):
		return false
	return not bool(item.get("krag_fit_chosen", false))


## Spend the free p.13 selection. Returns false — charging nothing and
## changing nothing — when this item never had one, so no caller can obtain a
## free fit on armor from any other source. Reversing the choice afterwards costs
## 2 Credits through modify_armor_for_krag(), which is what the book's "reversed
## for the same cost" means.
func choose_krag_fit(item: Dictionary, fit_for_krag: bool) -> bool:
	if not has_unspent_krag_choice(item):
		return false
	item["is_krag_armor"] = fit_for_krag
	item["krag_fit_chosen"] = true
	return true

## Update character object with assigned equipment
func _update_character_with_equipment(character_id: String) -> void:
	if not character_manager.has_character(character_id):
		return
	
	var character = character_manager.get_character(character_id)
	var equipment_list = _character_equipment.get(character_id, [])
	
	# Collect weapons
	var weapons = []
	var armor = null
	var gear = []
	
	for equipment_id in equipment_list:
		var equipment = get_equipment(equipment_id)
		if equipment.is_empty():
			continue
			
		match equipment.get("category"):
			EquipmentCategory.WEAPON:
				weapons.append(equipment)
			EquipmentCategory.ARMOR:
				armor = equipment
			EquipmentCategory.GEAR:
				gear.append(equipment)
	
	# Update the character with equipment
	if character.has_method("set_weapons"):
		character.set_weapons(weapons)
	else:
		character["weapons"] = weapons
		
	if character.has_method("set_armor"):
		character.set_armor(armor)
	else:
		character["armor"] = armor
		
	if character.has_method("set_gear"):
		character.set_gear(gear)
	else:
		character["gear"] = gear
	
	# Update character in manager
	character_manager.update_character(character_id, character)

## Generate a random item from equipment database (used for loot generation)
func _generate_random_item(_difficulty: int) -> Dictionary:
	var item_type := randi() % 3
	match item_type:
		0:
			if not _db_weapons.is_empty():
				var w: Dictionary = _db_weapons[randi() % _db_weapons.size()].duplicate()
				w["category"] = EquipmentCategory.WEAPON
				w["value"] = w.get("cost", 3)  # Use listed cost from JSON
				return w
		1:
			if not _db_armor.is_empty():
				var a: Dictionary = _db_armor[randi() % _db_armor.size()].duplicate()
				a["category"] = EquipmentCategory.ARMOR
				a["value"] = a.get("cost", 3)
				return a
		_:
			if not _db_gear.is_empty():
				var g: Dictionary = _db_gear[randi() % _db_gear.size()].duplicate()
				g["category"] = EquipmentCategory.GEAR
				g["value"] = g.get("cost", 3)
				return g
	return create_gear_item("Basic Gear", "misc", {})

## Signal handlers

func _on_character_added(character) -> void:
	var char_id = character.get("id", "")
	if not char_id.is_empty() and not char_id in _character_equipment:
		_character_equipment[char_id] = []

func _on_character_removed(character_id: String) -> void:
	if character_id in _character_equipment:
		_character_equipment.erase(character_id)

## Generate available items for the TRADING-phase market/purchase UI.
## Core Rules p.125 (Purchase Items): pay 3 credits for a roll on the Military
## Weapon, Gear, or Gadget table, or buy Hand Guns, Blades, Colony Rifles, or
## Shotguns for 1 credit each. This returns candidate items priced at their listed
## JSON cost (no fabricated markup) for that market view.
## NOTE: This is NOT the Trade Table (Core Rules p.79) — that barter/roll mechanic
## is the World-Phase "Trade" crew task and is already implemented canonically at
## CrewTaskComponent._get_trade_table_result() (data/trade_table.json). Do NOT
## reimplement the Trade Table here; it would duplicate the single source of truth.
func generate_market_items(_location_type: int, item_count: int = 5) -> Array:
	var market_items: Array = []
	for i in range(item_count):
		var item: Dictionary = _generate_random_item(0)
		if not item.is_empty():
			# Use cost from JSON data — no fabricated markup or pricing formula
			item["value"] = item.get("cost", 3)
			market_items.append(item)
	return market_items

## Use a consumable item, decrementing its remaining uses.
## Returns a result dictionary with {success, remaining, depleted}.
## If depleted, the caller should remove the item from the owner.
func use_consumable(item_data: Dictionary) -> Dictionary:
	var uses: int = item_data.get("remaining_uses", -1)
	if uses < 0:
		# Not a consumable — check legacy "uses" key
		uses = item_data.get("uses", -1)
		if uses >= 0:
			item_data["remaining_uses"] = uses
		else:
			return {"success": false, "remaining": -1, "depleted": false, "reason": "not_consumable"}
	if uses <= 0:
		return {"success": false, "remaining": 0, "depleted": true, "reason": "already_depleted"}
	item_data["remaining_uses"] = uses - 1
	var depleted: bool = item_data["remaining_uses"] <= 0
	return {"success": true, "remaining": item_data["remaining_uses"], "depleted": depleted, "reason": ""}
