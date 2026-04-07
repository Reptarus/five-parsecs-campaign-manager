class_name LuckSystem
extends RefCounted

## Luck System for Five Parsecs From Home
##
## Implements Luck mechanics from Core Rules p.91-92:
## - Luck can be spent to reroll any one die
## - Humans can have up to 3 Luck points
## - Non-humans are limited to 1 Luck point
## - Leaders get +1 Luck at campaign start
## - Luck refreshes at the start of each mission
##
## Usage:
##   var can_reroll = LuckSystem.can_spend_luck(character)
##   var new_roll = LuckSystem.spend_luck_reroll(character, original_roll, dice_roller)
##   LuckSystem.refresh_luck_for_mission(crew)

# Species Luck caps loaded from res://data/campaign_config.json (Core Rules p.91)
static var _luck_data: Dictionary = {}
static var _luck_loaded: bool = false

static func _ensure_luck_loaded() -> void:
	if _luck_loaded:
		return
	_luck_loaded = true
	var file := FileAccess.open("res://data/campaign_config.json", FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_luck_data = json.data.get("luck", {})
	file.close()

static var HUMAN_LUCK_CAP: int: # @no-lint:variable-name
	get:
		_ensure_luck_loaded()
		return int(_luck_data.get("human_cap", 3))
static var NONHUMAN_LUCK_CAP: int: # @no-lint:variable-name
	get:
		_ensure_luck_loaded()
		return int(_luck_data.get("nonhuman_cap", 1))

# Luck spent tracking (per-mission)
static var luck_spent_this_mission: Dictionary = {}  # character_id -> spent_count

#region Luck Spending

## Check if character can spend Luck for a reroll
static func can_spend_luck(character: Resource) -> bool:
	if not character:
		return false

	# Emo-suppressed can never spend Luck (Core Rules p.22)
	if _get_species_id(character).to_lower() == "emo_suppressed":
		return false

	var current_luck := _get_luck_value(character)
	var spent := _get_luck_spent(character)

	return current_luck > spent

## Spend Luck to reroll a die (Core Rules p.91)
## Returns the new roll result (takes the new result even if worse)
static func spend_luck_reroll(
	character: Resource,
	original_roll: int,
	dice_roller: Callable
) -> Dictionary:
	var result := {
		"success": false,
		"original_roll": original_roll,
		"new_roll": original_roll,
		"luck_spent": 0,
		"luck_remaining": 0
	}

	if not can_spend_luck(character):
		result["error"] = "No Luck available to spend"
		return result

	# Spend the Luck
	_spend_luck_point(character)

	# Roll new die
	var new_roll: int = dice_roller.call()

	result["success"] = true
	result["new_roll"] = new_roll
	result["luck_spent"] = 1
	result["luck_remaining"] = get_available_luck(character)
	result["improved"] = new_roll > original_roll


	return result

## Get available Luck points (total - spent this mission)
static func get_available_luck(character: Resource) -> int:
	if not character:
		return 0

	var current_luck := _get_luck_value(character)
	var spent := _get_luck_spent(character)

	return maxi(0, current_luck - spent)

## Get total Luck stat for character
static func get_total_luck(character: Resource) -> int:
	return _get_luck_value(character)

#endregion

#region Mission Management

## Refresh Luck for all crew at mission start (Core Rules p.91)
static func refresh_luck_for_mission(crew: Array) -> void:
	luck_spent_this_mission.clear()
	pass

## Reset Luck tracking for a single character (e.g., mid-mission join)
static func reset_character_luck(character: Resource) -> void:
	if character:
		var char_id := _get_character_id(character)
		luck_spent_this_mission.erase(char_id)

#endregion

#region Luck Caps

## Get maximum Luck for character based on species (Core Rules p.91)
static func get_luck_cap(character: Resource) -> int:
	if not character:
		return NONHUMAN_LUCK_CAP

	# Emo-suppressed can never receive Luck (Core Rules p.22)
	if _get_species_id(character).to_lower() == "emo_suppressed":
		return 0

	# Check if human
	if _is_human(character):
		return HUMAN_LUCK_CAP
	else:
		return NONHUMAN_LUCK_CAP

## Check if character is at their Luck cap
static func is_at_luck_cap(character: Resource) -> bool:
	if not character:
		return true

	var current_luck := _get_luck_value(character)
	var cap := get_luck_cap(character)

	return current_luck >= cap

## Apply Luck increase (clamped to species cap)
static func add_luck(character: Resource, amount: int = 1) -> int:
	if not character:
		return 0

	var current_luck := _get_luck_value(character)
	var cap := get_luck_cap(character)
	var new_luck := mini(current_luck + amount, cap)
	var actual_increase := new_luck - current_luck

	# Set the new luck value
	if character.has_method("set"):
		character.set("luck", new_luck)
	elif "luck" in character:
		character.luck = new_luck

	if actual_increase > 0:
		pass

	return actual_increase

## Apply Leader bonus (+1 Luck at campaign start) (Core Rules p.92)
static func apply_leader_luck_bonus(character: Resource) -> bool:
	if not character:
		return false

	var is_leader := false

	# Check for leader/captain status
	if character.has_method("is_captain"):
		is_leader = character.is_captain()
	elif character.has_method("get"):
		is_leader = character.get("is_leader") or character.get("is_captain") or character.get("captain")
	elif "is_leader" in character:
		is_leader = character.is_leader
	elif "is_captain" in character:
		is_leader = character.is_captain

	if is_leader:
		var added := add_luck(character, 1)
		if added > 0:
			return true

	return false

#endregion

#region Validation

## Enforce species Luck caps on character
static func enforce_luck_cap(character: Resource) -> void:
	if not character:
		return

	var current_luck := _get_luck_value(character)
	var cap := get_luck_cap(character)

	if current_luck > cap:
		if character.has_method("set"):
			character.set("luck", cap)
		elif "luck" in character:
			character.luck = cap

		pass

## Validate all crew Luck values against species caps
static func validate_crew_luck(crew: Array) -> Array:
	var violations: Array = []

	for character in crew:
		var current_luck := _get_luck_value(character)
		var cap := get_luck_cap(character)

		if current_luck > cap:
			violations.append({
				"character": _get_character_name(character),
				"current": current_luck,
				"cap": cap,
				"species": _get_species(character)
			})
			enforce_luck_cap(character)

	return violations

#endregion

#region Private Helpers

static func _get_luck_value(character: Resource) -> int:
	if not character:
		return 0

	if character.has_method("get"):
		return character.get("luck") if character.get("luck") != null else 0
	elif "luck" in character:
		return character.luck

	return 0

static func _get_character_id(character: Resource) -> String:
	if character.has_method("get"):
		var id = character.get("id")
		if id:
			return str(id)

	if "id" in character:
		return str(character.id)

	# Fallback to instance ID
	return str(character.get_instance_id())

static func _get_character_name(character: Resource) -> String:
	if character.has_method("get"):
		var name_val = character.get("character_name")
		if name_val:
			return str(name_val)
		name_val = character.get("name")
		if name_val:
			return str(name_val)

	if "character_name" in character:
		return str(character.character_name)
	if "name" in character:
		return str(character.name)

	return "Unknown"

static func _get_species(character: Resource) -> String:
	if character.has_method("get"):
		var species = character.get("species")
		if species:
			return str(species)
		species = character.get("origin")
		if species:
			return str(species)

	if "species" in character:
		return str(character.species)
	if "origin" in character:
		return str(character.origin)

	return "HUMAN"

static func _get_species_id(character: Resource) -> String:
	## Get species_id for Strange Character checks
	if character.has_method("get"):
		var sid = character.get("species_id")
		if sid:
			return str(sid)
	if "species_id" in character:
		return str(character.species_id)
	return ""

static func _is_human(character: Resource) -> bool:
	var species := _get_species(character).to_upper()
	return species == "HUMAN" or species == ""

static func _get_luck_spent(character: Resource) -> int:
	var char_id := _get_character_id(character)
	return luck_spent_this_mission.get(char_id, 0)

static func _spend_luck_point(character: Resource) -> void:
	var char_id := _get_character_id(character)
	luck_spent_this_mission[char_id] = luck_spent_this_mission.get(char_id, 0) + 1

#endregion

#region Integration Helpers

## Check if Luck should be offered (useful for UI)
static func should_offer_luck_reroll(character: Resource, roll: int, threshold: int) -> bool:
	# Only offer if character has Luck available
	if not can_spend_luck(character):
		return false

	# Offer if roll failed
	return roll < threshold

## Get Luck status summary for character (for UI display)
static func get_luck_status(character: Resource) -> Dictionary:
	return {
		"available": get_available_luck(character),
		"total": get_total_luck(character),
		"spent": _get_luck_spent(character),
		"cap": get_luck_cap(character),
		"is_human": _is_human(character),
		"can_spend": can_spend_luck(character)
	}

#endregion
