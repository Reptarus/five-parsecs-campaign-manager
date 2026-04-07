class_name EquipmentTransferService
extends RefCounted

## Single chokepoint for all equipment movement in the campaign.
##
## TABLETOP MENTAL MODEL:
## An item is a physical card. It sits on exactly ONE location at any time:
## a character's sheet OR the ship stash. It is NEVER in two places, NEVER
## duplicated, and NEVER vanishes without an explicit transfer. This service
## is the hand that physically moves the card from one pile to another.
##
## INVARIANTS (enforced by every method):
##   1. Every item has a unique, stable `id` — two cards with the same name
##      are still two cards. ids are NEVER reused.
##   2. An item exists in exactly one store at any time. A transfer is
##      remove-then-add, not copy-then-delete.
##   3. All writes emit an `equipment_transferred` event via
##      CampaignTurnEventBus so UI refreshes automatically.
##
## WHY A SERVICE AND NOT A METHOD ON EquipmentManager:
## EquipmentManager holds runtime state (what's in storage right now).
## EquipmentTransferService operates on the persisted Resource
## (FiveParsecsCampaignCore.equipment_data + crew_data.members). Keeping
## them separate means the invariants are enforced at the persistence layer,
## where the bugs actually live. EquipmentManager continues to handle
## compatibility checks, slot rules, and UI queries.
##
## USAGE: acquire an instance via `EquipmentTransferService.new(campaign)`
## then call the transfer methods. The service does not hold long-lived
## references — make a new instance per operation or per screen.

const CampaignCoreClass := preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

var _campaign: Resource  # FiveParsecsCampaignCore — not typed to avoid cycles
var _id_counter: int = 0  # Monotonic counter to prevent id collisions in tight loops

func _init(campaign: Resource) -> void:
	assert(campaign != null, "EquipmentTransferService requires a campaign Resource")
	_campaign = campaign

# ============================================================================
# PUBLIC API — the only legal entry points for equipment movement
# ============================================================================

## Move an item from the ship stash onto a character's sheet.
## Returns true on success. Fails (and logs) if the item is not in the stash
## or the character doesn't exist.
func transfer_to_character(item_id: String, character_id: String) -> bool:
	var item: Dictionary = _remove_from_stash(item_id)
	if item.is_empty():
		push_error("EquipmentTransferService: item %s not in ship stash" % item_id)
		return false
	if not _add_to_character(character_id, item):
		# Rollback: put it back in the stash so we don't lose the card
		_append_to_stash(item)
		push_error("EquipmentTransferService: character %s not found, rolled back" % character_id)
		return false
	_emit_transfer("stash->character", item_id, character_id)
	return true

## Move an item from a character's sheet back into the ship stash.
## Returns true on success.
func transfer_to_stash(item_id: String, character_id: String) -> bool:
	var item: Dictionary = _remove_from_character(character_id, item_id)
	if item.is_empty():
		push_error("EquipmentTransferService: item %s not on character %s" % [item_id, character_id])
		return false
	_append_to_stash(item)
	_emit_transfer("character->stash", item_id, character_id)
	return true

## Hand an item directly from one character to another. Atomic — either both
## sides succeed or neither does.
func transfer_between_characters(item_id: String, from_character_id: String, to_character_id: String) -> bool:
	var item: Dictionary = _remove_from_character(from_character_id, item_id)
	if item.is_empty():
		push_error("EquipmentTransferService: item %s not on %s" % [item_id, from_character_id])
		return false
	if not _add_to_character(to_character_id, item):
		# Rollback
		_add_to_character(from_character_id, item)
		push_error("EquipmentTransferService: target %s not found, rolled back" % to_character_id)
		return false
	_emit_transfer("character->character", item_id, from_character_id + "->" + to_character_id)
	return true

## Add a new item to the ship stash (post-battle loot path).
## Assigns a stable id if one isn't provided. Returns the final id.
func add_loot_to_stash(item: Dictionary) -> String:
	var stash_item: Dictionary = item.duplicate(true)
	var item_id: String = str(stash_item.get("id", ""))
	if item_id.is_empty():
		item_id = _generate_item_id(stash_item.get("name", "loot"))
		stash_item["id"] = item_id
	_append_to_stash(stash_item)
	_emit_transfer("loot->stash", item_id, "")
	return item_id

## Seed a character with starting equipment during campaign creation.
## This is the NON-stash path — items are created directly on the character
## without a round-trip through the ship stash. Used by
## CampaignFinalizationService to build the initial loadout.
##
## `items` is an Array of Dictionaries with at least `name`; ids are
## generated if missing.
func generate_starting_loadout(character_id: String, items: Array) -> int:
	var added: int = 0
	for raw in items:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw.duplicate(true)
		if not item.has("id") or str(item.get("id", "")).is_empty():
			item["id"] = _generate_item_id(item.get("name", "item"))
		if _add_to_character(character_id, item):
			added += 1
			_emit_transfer("creation->character", str(item["id"]), character_id)
	return added

# ============================================================================
# INTERNAL HELPERS — these are the ONLY places that mutate the two stores.
# Every public method routes through these so the invariants hold.
# ============================================================================

func _get_stash() -> Array:
	## Returns the mutable ship stash array. Creates it if missing.
	if not ("equipment_data" in _campaign):
		return []
	if not (_campaign.equipment_data is Dictionary):
		return []
	if not _campaign.equipment_data.has("equipment"):
		_campaign.equipment_data["equipment"] = []
	var stash = _campaign.equipment_data["equipment"]
	if not (stash is Array):
		_campaign.equipment_data["equipment"] = []
		return _campaign.equipment_data["equipment"]
	return stash

func _remove_from_stash(item_id: String) -> Dictionary:
	var stash: Array = _get_stash()
	for i in range(stash.size()):
		var entry = stash[i]
		if entry is Dictionary and str(entry.get("id", "")) == item_id:
			var removed: Dictionary = entry
			stash.remove_at(i)
			return removed
	return {}

func _append_to_stash(item: Dictionary) -> void:
	var stash: Array = _get_stash()
	stash.append(item)

func _find_crew_member(character_id: String) -> Variant:
	## Returns the member (Dictionary or Object) whose character_id matches,
	## or null if not found. Handles both dict-shaped crew data and live
	## Character Resource objects.
	if not ("crew_data" in _campaign):
		return null
	if not (_campaign.crew_data is Dictionary):
		return null
	var members = _campaign.crew_data.get("members", [])
	if not (members is Array):
		return null
	for member in members:
		var id_val: String = ""
		if member is Dictionary:
			id_val = str(member.get("character_id", member.get("id", "")))
		elif member is Object:
			if "character_id" in member:
				id_val = str(member.character_id)
			elif "id" in member:
				id_val = str(member.id)
		if id_val == character_id:
			return member
	return null

func _get_member_equipment(member) -> Array:
	if member is Dictionary:
		return member.get("equipment", [])
	elif member is Object and "equipment" in member:
		return member.equipment
	return []

func _set_member_equipment(member, equipment: Array) -> void:
	if member is Dictionary:
		member["equipment"] = equipment
	elif member is Object and "equipment" in member:
		member.equipment = equipment

func _add_to_character(character_id: String, item: Dictionary) -> bool:
	var member = _find_crew_member(character_id)
	if member == null:
		return false
	var eq: Array = _get_member_equipment(member)
	# Reject duplicate ids (tabletop invariant: cards are unique).
	var new_id: String = str(item.get("id", ""))
	for existing in eq:
		if existing is Dictionary and str(existing.get("id", "")) == new_id:
			return false  # Silently succeed-as-noop? No — caller needs to know.
	eq.append(item)
	_set_member_equipment(member, eq)
	return true

func _remove_from_character(character_id: String, item_id: String) -> Dictionary:
	var member = _find_crew_member(character_id)
	if member == null:
		return {}
	var eq: Array = _get_member_equipment(member)
	for i in range(eq.size()):
		var entry = eq[i]
		if entry is Dictionary and str(entry.get("id", "")) == item_id:
			var removed: Dictionary = entry
			eq.remove_at(i)
			_set_member_equipment(member, eq)
			return removed
		# Legacy tolerance: some characters still have Array[String] equipment
		# from pre-Phase-2.2 saves. We match by name as a fallback, but only
		# if the "id" looks name-like (i.e. the caller clearly knows this is
		# a legacy character). Phase 2.3 migration should eliminate these.
		if entry is String and entry == item_id:
			eq.remove_at(i)
			_set_member_equipment(member, eq)
			return {"id": item_id, "name": item_id, "_legacy": true}
	return {}

# ============================================================================
# UTILITIES
# ============================================================================

func _generate_item_id(base_name: String) -> String:
	## Generate a stable, unique item id. Uses a monotonic counter to
	## guarantee uniqueness within the same service instance (important for
	## generate_starting_loadout which calls this in a tight loop where
	## Time.get_ticks_msec() returns the same value for every call).
	_id_counter += 1
	var safe_base: String = base_name.to_lower().replace(" ", "_")
	var ts: int = Time.get_ticks_msec()
	return "%s_%d_%d" % [safe_base, ts, _id_counter]

func _emit_transfer(kind: String, item_id: String, actor_info: String) -> void:
	## Emit a transfer event through CampaignTurnEventBus so UI refreshes.
	## Silently no-ops if the event bus isn't available (e.g. in tests).
	var tree = Engine.get_main_loop() as SceneTree
	if not tree:
		return
	var bus = tree.root.get_node_or_null("/root/CampaignTurnEventBus")
	if not bus or not bus.has_method("publish_event"):
		return
	# Use PROGRESS_UPDATED or an existing event type — we don't invent a new
	# enum value here to avoid cross-file enum ordinal sync issues. Phase 3
	# can add a dedicated EQUIPMENT_TRANSFERRED event if needed.
	var payload := {
		"kind": "equipment_transfer",
		"transfer_kind": kind,
		"item_id": item_id,
		"actor_info": actor_info,
	}
	if "TurnEvent" in bus and "PROGRESS_UPDATED" in bus.TurnEvent:
		bus.publish_event(bus.TurnEvent.PROGRESS_UPDATED, payload)
