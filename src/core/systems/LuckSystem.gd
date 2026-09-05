class_name LuckSystem
extends RefCounted

## Luck System for Five Parsecs From Home
##
## Implements Luck mechanics from Core Rules p.91-92:
## - Luck can be spent to reroll any one die
## - Humans can have up to 3 Luck points
## - Non-humans are limited to 1 Luck point
## - Leaders get +1 Luck at campaign start (Core Rules p.24, NOT p.91-92;
##   a Bot Leader receives none)
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
static func get_luck_cap(character: Variant) -> int:
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
static func is_at_luck_cap(character: Variant) -> bool:
	if not character:
		return true

	var current_luck := _get_luck_value(character)
	var cap := get_luck_cap(character)

	return current_luck >= cap

## Apply Luck increase (clamped to species cap)
static func add_luck(character: Variant, amount: int = 1) -> int:
	if not character:
		return 0

	var current_luck := _get_luck_value(character)
	var cap := get_luck_cap(character)
	var new_luck := mini(current_luck + amount, cap)
	var actual_increase := new_luck - current_luck

	# Set the new luck value. Dictionary first - see _field() for why.
	if character is Dictionary:
		(character as Dictionary)["luck"] = new_luck
	elif "luck" in character:
		character.set("luck", new_luck)

	if actual_increase > 0:
		pass

	return actual_increase

## Apply the Leader's +1 Luck. **Core Rules p.24**, Crew Composition.
##
## BOOK, verbatim: "Once you have created all of your characters, pick one to be
## the Leader. This character receives 1 Luck point and will never leave the crew
## through random events, though they can certainly be slain. While you are free
## to select a Bot as your Leader, they do not receive Luck if you do."
##
## THREE THINGS WERE WRONG HERE (2026-09-04):
##  1. It had ZERO callers, and `add_luck()` had exactly one caller - this
##     function. No other site in src/ granted the Leader their Luck point, so
##     the rule was simply absent from play. (CharacterGeneration.gd:799 is the
##     HUMAN SPECIES Luck of p.15, granted to every Human; :329 is the creation
##     tables; Character.gd:337 is XP spend. None of them is this rule.)
##  2. The docblock cited p.92. The rule is on p.24 - the same page CLAUDE.md
##     already cites for the Leader's exemption from random-event departure.
##  3. The Bot exclusion was missing entirely, so a Bot Leader would have been
##     handed a Luck point the book explicitly denies.
##
## This is the SINGLE GRANT SITE for the rule, called once from
## CampaignFinalizationService._create_campaign_resource(). Do not add a second.
##
## Returns true only when a point was actually added, so the caller can log it.
## A non-Human Leader is capped at 1 Luck (p.15), so this can legitimately
## return false for a character who is already at their cap.
static func apply_leader_luck_bonus(character: Variant) -> bool:
	if character == null:
		return false
	if not is_leader(character):
		return false
	# p.24: selecting a Bot as Leader is legal, but it receives no Luck.
	if is_bot_character(character):
		return false
	return add_luck(character, 1) > 0

## True when this character is the crew's Leader (the app calls it the captain).
static func is_leader(character: Variant) -> bool:
	if character == null:
		return false
	# `is_captain` is an @export PROPERTY on Character (Character.gd:130), never
	# a method, so a has_method("is_captain") probe here is permanently false.
	return bool(_field(character, "is_captain", false)) \
		or bool(_field(character, "is_leader", false))

## True for a Bot. Mirrors AdvancementSystem._is_bot(): the authoritative marker
## is the `is_bot` property, with species_id/origin as legacy fallbacks, matched
## case-insensitively because species ids are spelled lowercase on disk.
static func is_bot_character(character: Variant) -> bool:
	if character == null:
		return false
	if bool(_field(character, "is_bot", false)):
		return true
	if str(_field(character, "species_id", "")).to_lower() == "bot":
		return true
	return str(_field(character, "origin", "")).to_lower() == "bot"

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

## Read one field off a crew member of EITHER shape.
##
## Crew are Character RESOURCES during creation and Dictionaries once
## CampaignFinalizationService._transform_crew_data_for_turn_system() has run
## (and on every loaded save). The Dictionary branch MUST come first:
## `has_method()` on a Dictionary is an invalid call that unwinds the caller, so
## a Resource-only helper does not merely return a wrong answer on a Dictionary
## - it silently aborts whatever called it. Same discipline as
## AdvancementSystem.member_has_training().
static func _field(character: Variant, key: String, default_value: Variant) -> Variant:
	if character == null:
		return default_value
	if character is Dictionary:
		var d: Dictionary = character
		var dv: Variant = d.get(key, default_value)
		return default_value if dv == null else dv
	if key in character:
		var v: Variant = character.get(key)
		return default_value if v == null else v
	return default_value

static func _get_luck_value(character: Variant) -> int:
	return int(_field(character, "luck", 0))

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

static func _get_species(character: Variant) -> String:
	var species: String = str(_field(character, "species", ""))
	if not species.is_empty():
		return species
	return str(_field(character, "origin", ""))

	return "HUMAN"

static func _get_species_id(character: Variant) -> String:
	## Get species_id for Strange Character checks
	return str(_field(character, "species_id", ""))

static func _is_human(character: Variant) -> bool:
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
