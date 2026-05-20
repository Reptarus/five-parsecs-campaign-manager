class_name StarsOfTheStorySystem
extends RefCounted

## Stars of the Story System - Emergency Narrative Abilities
##
## Implements the FIVE one-time emergency options from Core Rules p.67:
## 1. "It's time to go!"            - End a battle, all crew escape (mid-battle)
## 2. "Looked worse than it was!"   - Ignore a roll on the Injury Table (post-battle)
## 3. "Did you ever meet my mate?"  - Add new character mid-battle within 6" of edge
## 4. "Lucky shot!"                 - Turn a missed shot into a hit (mid-battle)
## 5. "Rainy day fund!"             - Immediately add 1D6+5 credits (dashboard)
##
## Rules:
## - Each option usable ONCE per campaign by default (book: write each on an index card,
##   remove when used)
## - NOT available in Insanity difficulty (book p.67)
## - Every 5 Elite Ranks: at CAMPAIGN SETUP, the player picks ONE option that
##   can be used twice (book p.65: "You must pick when setting up the campaign")
## - Bonus picks do NOT accrue mid-campaign; they're a setup-time selection only
## - Bug Hunt explicitly does NOT carry over stars (Compendium p.214)

signal star_ability_used(ability: StarAbility, details: Dictionary)

enum StarAbility {
	ITS_TIME_TO_GO,        ## End battle, all crew escape (book order: 1st listed)
	LOOKED_WORSE,          ## Ignore a roll on the Injury Table
	DID_YOU_EVER_MEET,     ## Add new character mid-battle within 6" of edge
	LUCKY_SHOT,            ## Turn a missed shot into a hit (single shot only)
	RAINY_DAY_FUND         ## +1D6+5 credits
}

## Track uses remaining for each ability
var _uses_remaining: Dictionary = {
	StarAbility.ITS_TIME_TO_GO: 1,
	StarAbility.LOOKED_WORSE: 1,
	StarAbility.DID_YOU_EVER_MEET: 1,
	StarAbility.LUCKY_SHOT: 1,
	StarAbility.RAINY_DAY_FUND: 1
}

## Track maximum uses for each ability (doubled by Elite Rank pick at creation)
var _max_uses: Dictionary = {
	StarAbility.ITS_TIME_TO_GO: 1,
	StarAbility.LOOKED_WORSE: 1,
	StarAbility.DID_YOU_EVER_MEET: 1,
	StarAbility.LUCKY_SHOT: 1,
	StarAbility.RAINY_DAY_FUND: 1
}

## Is system active (false in Insanity mode)
var _is_active: bool = true

## Initialize the system for a new campaign
##
## Per Core Rules p.65: Elite Rank picks happen at campaign setup via FinalPanel,
## NOT here. Call apply_elite_rank_pick() separately for each pick the player makes.
##
## @param difficulty: Campaign difficulty (Insanity = no stars)
func initialize(difficulty: int) -> void:
	_is_active = not DifficultyModifiers.are_stars_of_story_disabled(difficulty)

	if not _is_active:
		# Insanity mode - all abilities unavailable
		for ability in StarAbility.values():
			_uses_remaining[ability] = 0
			_max_uses[ability] = 0


## Apply a single Elite Rank "double this ability" pick at campaign setup
##
## Per Core Rules p.65: "For every 5 Elite Ranks, you may pick one 'Stars of the
## Story' option that can be used twice. You must pick when setting up the campaign."
##
## Call once per pick (e.g., 10 Elite Ranks = call twice with two different abilities,
## OR the same ability twice for triple uses if the player wants).
##
## @param ability: The StarAbility to grant a bonus use to
func apply_elite_rank_pick(ability: StarAbility) -> void:
	if not _is_active:
		return  # Insanity: no picks
	_max_uses[ability] = _max_uses.get(ability, 1) + 1
	_uses_remaining[ability] = _uses_remaining.get(ability, 1) + 1


## Check if an ability can be used
func can_use(ability: StarAbility) -> bool:
	if not _is_active:
		return false
	return _uses_remaining.get(ability, 0) > 0


## Use a Stars of the Story ability
##
## @param ability: The StarAbility to use
## @param context: Contextual data the handler needs (injury_data, shot_result, etc.)
## @return: Result dictionary with success status and outcome data
func use_ability(ability: StarAbility, context: Dictionary) -> Dictionary:
	if not can_use(ability):
		return {
			"success": false,
			"error": "Ability not available or already used",
			"ability": ability
		}

	var result: Dictionary = {}

	match ability:
		StarAbility.ITS_TIME_TO_GO:
			result = _use_its_time_to_go(context)
		StarAbility.LOOKED_WORSE:
			result = _use_looked_worse(context)
		StarAbility.DID_YOU_EVER_MEET:
			result = _use_did_you_ever_meet(context)
		StarAbility.LUCKY_SHOT:
			result = _use_lucky_shot(context)
		StarAbility.RAINY_DAY_FUND:
			result = _use_rainy_day_fund(context)
		_:
			result = {
				"success": false,
				"error": "Unknown ability type",
				"ability": ability
			}

	if result.get("success", false):
		_uses_remaining[ability] -= 1
		star_ability_used.emit(ability, result)

	return result


## Get remaining uses for an ability
func get_uses_remaining(ability: StarAbility) -> int:
	return _uses_remaining.get(ability, 0)


## Get maximum uses for an ability (after Elite Rank picks applied at setup)
func get_max_uses(ability: StarAbility) -> int:
	return _max_uses.get(ability, 0)


## Check if system is active (false in Insanity mode)
func is_active() -> bool:
	return _is_active


## Get exact book-wording ability name (Core Rules p.67)
func get_ability_name(ability: StarAbility) -> String:
	match ability:
		StarAbility.ITS_TIME_TO_GO:
			return "It's time to go!"
		StarAbility.LOOKED_WORSE:
			return "Looked worse than it was!"
		StarAbility.DID_YOU_EVER_MEET:
			return "Did you ever meet my mate?"
		StarAbility.LUCKY_SHOT:
			return "Lucky shot!"
		StarAbility.RAINY_DAY_FUND:
			return "Rainy day fund!"
		_:
			return "Unknown Ability"


## Get book-wording ability description (Core Rules p.67)
func get_ability_description(ability: StarAbility) -> String:
	match ability:
		StarAbility.ITS_TIME_TO_GO:
			return ("The crew may immediately end a battle, with all"
				+ " remaining characters escaping from the fight.")
		StarAbility.LOOKED_WORSE:
			return ("Ignore a roll on the Injury Table."
				+ " The character recovers immediately.")
		StarAbility.DID_YOU_EVER_MEET:
			return ("Add a new character to your team immediately,"
				+ " even mid-battle. Place the model within 6\" of"
				+ " any battlefield edge. They can act immediately.")
		StarAbility.LUCKY_SHOT:
			return ("If a character just missed a shot, turn it into a hit."
				+ " Only applies to a single shot, even if the weapon"
				+ " rolls multiple attack dice.")
		StarAbility.RAINY_DAY_FUND:
			return "Immediately add 1D6+5 credits to your available funds."
		_:
			return ""


## Battle-only abilities (cannot be used from dashboard popover)
static func is_battle_only(ability: StarAbility) -> bool:
	return ability in [
		StarAbility.ITS_TIME_TO_GO,
		StarAbility.DID_YOU_EVER_MEET,
		StarAbility.LUCKY_SHOT
	]


## Serialize system state for saving
func serialize() -> Dictionary:
	return {
		"version": 2,  ## v2 = 5 book-accurate abilities (post-rebuild)
		"uses_remaining": _uses_remaining.duplicate(),
		"max_uses": _max_uses.duplicate(),
		"is_active": _is_active
	}


## Deserialize system state from save data
func deserialize(data: Dictionary) -> void:
	if data.has("uses_remaining"):
		_uses_remaining = data["uses_remaining"].duplicate()

	if data.has("max_uses"):
		_max_uses = data["max_uses"].duplicate()

	if data.has("is_active"):
		_is_active = data["is_active"]


## ============================================================================
## Ability handlers
## ============================================================================


## "It's time to go!" - End battle, all crew escape
##
## @param context: Optional "battle" dict to mutate with evacuation flags
## @return: Result dict with evacuation outcome
func _use_its_time_to_go(context: Dictionary) -> Dictionary:
	var battle: Dictionary = context.get("battle", {})
	if not battle.is_empty():
		battle["evacuated"] = true
		battle["held_field"] = false

	return {
		"success": true,
		"ability": StarAbility.ITS_TIME_TO_GO,
		"battle": battle,
		"evacuated": true,
		"held_field": false,
		"message": "Used 'It's time to go!' - All crew escape immediately (you do NOT hold the field)."
	}


## "Looked worse than it was!" - Ignore a roll on the Injury Table
##
## @param context: Must contain "injury_data" dict (PRE-table-roll)
## @return: Result with injury_data flagged as ignored
func _use_looked_worse(context: Dictionary) -> Dictionary:
	if not context.has("injury_data"):
		return {"success": false, "error": "Missing injury_data in context"}

	var injury_data: Dictionary = context["injury_data"]
	injury_data["ignored"] = true
	injury_data["star_used"] = "LOOKED_WORSE"

	var char_name: String = injury_data.get("character_name",
		injury_data.get("crew_name", "Character"))

	return {
		"success": true,
		"ability": StarAbility.LOOKED_WORSE,
		"injury_data": injury_data,
		"character_id": injury_data.get("character_id",
			injury_data.get("crew_id", "")),
		"character_name": char_name,
		"message": "%s ignored a roll on the Injury Table - recovered immediately." % char_name
	}


## "Did you ever meet my mate?" - Add new character mid-battle within 6" of edge
##
## @param context: Must contain "new_character" (Character or Dict) and
##                 "placement_tile" (Vector2i within 6 cells of battlefield edge)
## @return: Result with the new unit data
func _use_did_you_ever_meet(context: Dictionary) -> Dictionary:
	if not context.has("new_character"):
		return {"success": false, "error": "Missing new_character in context"}

	var new_char = context["new_character"]
	var placement_tile = context.get("placement_tile", Vector2i.ZERO)
	var char_name: String = ""
	var char_id: String = ""

	if new_char is Dictionary:
		char_name = new_char.get("character_name", new_char.get("name", "New Recruit"))
		char_id = new_char.get("character_id", new_char.get("id", ""))
	elif new_char and new_char.has_method("get"):
		char_name = new_char.get("character_name")
		if char_name == null or char_name == "":
			char_name = "New Recruit"
		char_id = new_char.get("character_id") if "character_id" in new_char else ""

	return {
		"success": true,
		"ability": StarAbility.DID_YOU_EVER_MEET,
		"new_character": new_char,
		"new_character_name": char_name,
		"character_id": char_id,
		"placement_tile": placement_tile,
		"acts_immediately": true,
		"message": ("'Did you ever meet my mate?' - %s joins"
			+ " the crew mid-battle!") % char_name
	}


## "Lucky shot!" - Turn a missed shot into a hit
##
## @param context: Must contain "shot_result" dict (just-resolved miss)
## @return: Result with shot_result mutated to a hit
func _use_lucky_shot(context: Dictionary) -> Dictionary:
	if not context.has("shot_result"):
		return {"success": false, "error": "Missing shot_result in context"}

	var shot_result: Dictionary = context["shot_result"]

	if shot_result.get("hit", false):
		return {"success": false, "error": "Shot was not a miss"}

	shot_result["hit"] = true
	shot_result["lucky"] = true
	shot_result["star_used"] = "LUCKY_SHOT"

	var shooter_name: String = shot_result.get("shooter_name", "Shooter")
	var target_name: String = shot_result.get("target_name", "target")

	return {
		"success": true,
		"ability": StarAbility.LUCKY_SHOT,
		"shot_result": shot_result,
		"character_id": shot_result.get("shooter_id", ""),
		"shooter_name": shooter_name,
		"target_name": target_name,
		"message": "Lucky shot! %s turned a miss into a hit against %s." % [shooter_name, target_name]
	}


## "Rainy day fund!" - Gain 1D6+5 credits
##
## @param context: Optional "dice_system" for injection (testing)
## @return: Result with credits_gained
func _use_rainy_day_fund(context: Dictionary) -> Dictionary:
	var dice_system = context.get("dice_system", null)

	var roll: int
	if dice_system != null and dice_system.has_method("roll"):
		roll = dice_system.roll(1, 6) + 5
	else:
		roll = (randi() % 6) + 1 + 5

	return {
		"success": true,
		"ability": StarAbility.RAINY_DAY_FUND,
		"credits_gained": roll,
		"message": "Rainy day fund! Discovered %d credits in a forgotten account." % roll
	}


## ============================================================================
## Centralized journal logger (single source of truth for star → journal)
## ============================================================================


## Log a star use to the campaign journal
##
## Called from PostBattleSequence, CampaignDashboard popover, and TacticalBattleUI.
## Centralizing the logger here means per-ability metadata travels with the data
## definition, so new abilities don't need scattered match arms in consumers.
##
## @param ability: Which star was used
## @param context: Context that was passed to use_ability() (carries character_id etc.)
## @param result: Result dict returned by use_ability()
## @param journal: The CampaignJournal autoload node
## @param turn_number: Current campaign turn
## @param source: "battle", "post_battle", or "dashboard" (drives tag + mood)
static func log_use_to_journal(
	ability: StarAbility,
	context: Dictionary,
	result: Dictionary,
	journal: Node,
	turn_number: int,
	source: String
) -> void:
	if not journal or not journal.has_method("create_entry"):
		return

	var entry: Dictionary = _build_journal_entry(
		ability, context, result, turn_number, source)
	journal.create_entry(entry)

	## Per-character event for abilities that target a specific crew member
	var char_id: String = result.get("character_id",
		context.get("character_id", ""))
	if not char_id.is_empty() and journal.has_method("auto_create_character_event"):
		var event_type: String = _character_event_type_for(ability)
		if not event_type.is_empty():
			journal.auto_create_character_event(char_id, event_type)


static func _build_journal_entry(
	ability: StarAbility,
	context: Dictionary,
	result: Dictionary,
	turn_number: int,
	source: String
) -> Dictionary:
	var title: String = ""
	var description: String = ""
	var mood: String = "neutral"
	var tags: Array = ["stars_of_the_story", "emergency", source]

	match ability:
		StarAbility.ITS_TIME_TO_GO:
			title = "It's time to go!"
			description = "Crew evacuated mid-battle — did not hold the field."
			mood = "desperate"
			tags.append("evacuation")
		StarAbility.LOOKED_WORSE:
			var ch_name: String = result.get("character_name", "Character")
			title = "Looked worse than it was!"
			description = "%s ignored a roll on the Injury Table and recovered immediately." % ch_name
			mood = "relieved"
			tags.append("injury")
		StarAbility.DID_YOU_EVER_MEET:
			var new_name: String = result.get("new_character_name", "A new recruit")
			title = "Did you ever meet my mate?"
			description = ("%s joined the crew mid-battle,"
				+ " arriving at the battlefield edge.") % new_name
			mood = "exciting"
			tags.append("recruitment")
		StarAbility.LUCKY_SHOT:
			var shooter: String = result.get("shooter_name", "Shooter")
			var target: String = result.get("target_name", "target")
			title = "Lucky shot!"
			description = "%s turned a missed shot into a hit against %s." % [shooter, target]
			mood = "triumphant"
			tags.append("combat")
		StarAbility.RAINY_DAY_FUND:
			var credits: int = int(result.get("credits_gained", 0))
			title = "Rainy day fund!"
			description = "Discovered %d credits in a forgotten account." % credits
			mood = "neutral"
			tags.append("finance")
		_:
			title = "Stars of the Story"
			description = "Used an emergency narrative ability."

	return {
		"turn_number": turn_number,
		"type": "story",
		"auto_generated": true,
		"title": title,
		"description": description,
		"mood": mood,
		"tags": tags
	}


static func _character_event_type_for(ability: StarAbility) -> String:
	match ability:
		StarAbility.LOOKED_WORSE:
			return "injury_skipped"
		StarAbility.DID_YOU_EVER_MEET:
			return "joined_via_star"
		StarAbility.LUCKY_SHOT:
			return "lucky_shot"
		_:
			return ""
