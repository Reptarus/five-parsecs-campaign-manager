class_name StarsOfTheStorySystem
extends RefCounted

## Stars of the Story System - Emergency Abilities
##
## Implements the four one-time campaign abilities from core rules p.67:
## 1. "It Wasn't That Bad!" - Remove one injury post-battle
## 2. "Dramatic Escape" - Survive a killing blow with 1 HP
## 3. "It's Time To Go" - Emergency battle evacuation
## 4. "Rainy Day Fund" - Gain 1D6+5 credits
##
## Special Rules:
## - Each ability usable ONCE per campaign (default)
## - NOT available in Insanity difficulty
## - Every 5 Elite Ranks: One ability can be used TWICE

signal star_ability_used(ability: StarAbility, details: Dictionary)
signal star_ability_available(ability: StarAbility)
signal star_ability_recharged(ability: StarAbility, new_uses: int)

enum StarAbility {
	IT_WASNT_THAT_BAD,      ## Remove one injury from a character
	DRAMATIC_ESCAPE,        ## Survive a killing blow with 1 HP
	ITS_TIME_TO_GO,         ## Emergency evacuation from battle
	RAINY_DAY_FUND          ## Gain 1D6+5 credits immediately
}

## Difficulty constants (aligned with GameState.Difficulty enum)
const DIFFICULTY_INSANITY := 4

## Elite ranks required for bonus use
const ELITE_RANKS_PER_BONUS_USE := 5

## Track uses remaining for each ability
var _uses_remaining: Dictionary = {
	StarAbility.IT_WASNT_THAT_BAD: 1,
	StarAbility.DRAMATIC_ESCAPE: 1,
	StarAbility.ITS_TIME_TO_GO: 1,
	StarAbility.RAINY_DAY_FUND: 1
}

## Track original max uses (for Elite Ranks bonuses)
var _max_uses: Dictionary = {
	StarAbility.IT_WASNT_THAT_BAD: 1,
	StarAbility.DRAMATIC_ESCAPE: 1,
	StarAbility.ITS_TIME_TO_GO: 1,
	StarAbility.RAINY_DAY_FUND: 1
}

## Is system active (false in Insanity mode)
var _is_active: bool = true

## Current elite ranks (for bonus use calculation)
var _elite_ranks: int = 0


## Initialize the Stars of the Story system
##
## @param elite_ranks: Current elite ranks (every 5 = +1 use to one ability)
## @param difficulty: Campaign difficulty (Insanity = no stars)
func initialize(elite_ranks: int, difficulty: int) -> void:
	_elite_ranks = elite_ranks
	_is_active = (difficulty != DIFFICULTY_INSANITY)

	if not _is_active:
		# Insanity mode - no abilities available
		_uses_remaining[StarAbility.IT_WASNT_THAT_BAD] = 0
		_uses_remaining[StarAbility.DRAMATIC_ESCAPE] = 0
		_uses_remaining[StarAbility.ITS_TIME_TO_GO] = 0
		_uses_remaining[StarAbility.RAINY_DAY_FUND] = 0

		_max_uses[StarAbility.IT_WASNT_THAT_BAD] = 0
		_max_uses[StarAbility.DRAMATIC_ESCAPE] = 0
		_max_uses[StarAbility.ITS_TIME_TO_GO] = 0
		_max_uses[StarAbility.RAINY_DAY_FUND] = 0
	else:
		# Calculate bonus uses from Elite Ranks
		var bonus_uses: int = elite_ranks / ELITE_RANKS_PER_BONUS_USE

		# Each bonus use can be assigned to ONE ability
		# For now, distribute evenly (could be player choice in UI)
		_distribute_bonus_uses(bonus_uses)


## Check if an ability can be used
##
## @param ability: The StarAbility to check
## @return: true if ability has uses remaining and system is active
func can_use(ability: StarAbility) -> bool:
	if not _is_active:
		return false

	return _uses_remaining.get(ability, 0) > 0


## Use a Stars of the Story ability
##
## @param ability: The StarAbility to use
## @param context: Contextual data for the ability (character, battle state, etc.)
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
		StarAbility.IT_WASNT_THAT_BAD:
			result = _use_it_wasnt_that_bad(context)

		StarAbility.DRAMATIC_ESCAPE:
			result = _use_dramatic_escape(context)

		StarAbility.ITS_TIME_TO_GO:
			result = _use_its_time_to_go(context)

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
##
## @param ability: The StarAbility to check
## @return: Number of uses remaining (0 if Insanity mode)
func get_uses_remaining(ability: StarAbility) -> int:
	return _uses_remaining.get(ability, 0)


## Get maximum uses for an ability (including Elite Rank bonuses)
##
## @param ability: The StarAbility to check
## @return: Maximum uses available for this ability
func get_max_uses(ability: StarAbility) -> int:
	return _max_uses.get(ability, 0)


## Check if system is active (false in Insanity mode)
func is_active() -> bool:
	return _is_active


## Get ability name as string
##
## @param ability: The StarAbility enum value
## @return: Human-readable ability name
func get_ability_name(ability: StarAbility) -> String:
	match ability:
		StarAbility.IT_WASNT_THAT_BAD:
			return "It Wasn't That Bad!"
		StarAbility.DRAMATIC_ESCAPE:
			return "Dramatic Escape"
		StarAbility.ITS_TIME_TO_GO:
			return "It's Time To Go"
		StarAbility.RAINY_DAY_FUND:
			return "Rainy Day Fund"
		_:
			return "Unknown Ability"


## Get ability description
##
## @param ability: The StarAbility enum value
## @return: Description of what the ability does
func get_ability_description(ability: StarAbility) -> String:
	match ability:
		StarAbility.IT_WASNT_THAT_BAD:
			return "Remove one injury from a character after a battle."
		StarAbility.DRAMATIC_ESCAPE:
			return "A character that would have died instead survives with 1 HP."
		StarAbility.ITS_TIME_TO_GO:
			return "Escape a hopeless battle - all crew evacuate immediately. Do NOT hold the field."
		StarAbility.RAINY_DAY_FUND:
			return "Immediately gain 1D6+5 credits."
		_:
			return ""


## Serialize system state for saving
func serialize() -> Dictionary:
	return {
		"version": 1,
		"uses_remaining": _uses_remaining.duplicate(),
		"max_uses": _max_uses.duplicate(),
		"is_active": _is_active,
		"elite_ranks": _elite_ranks
	}


## Deserialize system state from save data
func deserialize(data: Dictionary) -> void:
	if data.has("uses_remaining"):
		_uses_remaining = data["uses_remaining"].duplicate()

	if data.has("max_uses"):
		_max_uses = data["max_uses"].duplicate()

	if data.has("is_active"):
		_is_active = data["is_active"]

	if data.has("elite_ranks"):
		_elite_ranks = data["elite_ranks"]


## Update elite ranks (called when crew gains ranks)
##
## @param new_elite_ranks: Updated elite rank count
func update_elite_ranks(new_elite_ranks: int) -> void:
	var old_bonus_uses: int = _elite_ranks / ELITE_RANKS_PER_BONUS_USE
	var new_bonus_uses: int = new_elite_ranks / ELITE_RANKS_PER_BONUS_USE

	_elite_ranks = new_elite_ranks

	if new_bonus_uses > old_bonus_uses:
		# Gained new bonus use(s)
		var additional_uses: int = new_bonus_uses - old_bonus_uses
		_distribute_bonus_uses(additional_uses)


## Distribute bonus uses from Elite Ranks
##
## Current implementation: Distribute evenly across all abilities
## Future: Could allow player choice via UI
##
## @param bonus_uses: Number of bonus uses to distribute
func _distribute_bonus_uses(bonus_uses: int) -> void:
	if bonus_uses <= 0:
		return

	# Strategy: Assign bonus uses to abilities that have been used first
	# If none used, distribute evenly
	var abilities_to_recharge: Array[StarAbility] = []

	# Find abilities with 0 uses remaining
	for ability in StarAbility.values():
		if _uses_remaining[ability] < _max_uses[ability]:
			abilities_to_recharge.append(ability)

	# If no abilities need recharging, increase max uses evenly
	if abilities_to_recharge.is_empty():
		for ability in StarAbility.values():
			abilities_to_recharge.append(ability)

	# Distribute bonus uses
	var uses_distributed: int = 0
	while uses_distributed < bonus_uses:
		for ability in abilities_to_recharge:
			_max_uses[ability] += 1
			_uses_remaining[ability] += 1
			star_ability_recharged.emit(ability, _uses_remaining[ability])
			uses_distributed += 1
			if uses_distributed >= bonus_uses:
				break


## "It Wasn't That Bad!" - Remove one injury
##
## @param context: Must contain "character" (Character resource) and "injury" (Injury type)
## @return: Result dictionary
func _use_it_wasnt_that_bad(context: Dictionary) -> Dictionary:
	if not context.has("character"):
		return {"success": false, "error": "Missing character in context"}

	if not context.has("injury"):
		return {"success": false, "error": "Missing injury to remove"}

	var character = context["character"]
	var injury = context["injury"]

	# Validation: Character should have the injury
	if not character.has("injuries") or injury not in character.injuries:
		return {
			"success": false,
			"error": "Character does not have this injury"
		}

	# Remove the injury
	character.injuries.erase(injury)

	return {
		"success": true,
		"ability": StarAbility.IT_WASNT_THAT_BAD,
		"character": character,
		"removed_injury": injury,
		"message": "%s used 'It Wasn't That Bad!' to remove injury: %s" % [character.name, injury]
	}


## "Dramatic Escape" - Survive death with 1 HP
##
## @param context: Must contain "character" (Character resource)
## @return: Result dictionary
func _use_dramatic_escape(context: Dictionary) -> Dictionary:
	if not context.has("character"):
		return {"success": false, "error": "Missing character in context"}

	var character = context["character"]

	# Set HP to 1 (minimum survivable)
	if character.has("current_hp"):
		character.current_hp = 1
	elif character.has("hp"):
		character.hp = 1

	return {
		"success": true,
		"ability": StarAbility.DRAMATIC_ESCAPE,
		"character": character,
		"message": "%s used 'Dramatic Escape' to survive a killing blow!" % character.name
	}


## "It's Time To Go" - Emergency evacuation
##
## @param context: Must contain "battle" (Battle state)
## @return: Result dictionary
func _use_its_time_to_go(context: Dictionary) -> Dictionary:
	if not context.has("battle"):
		return {"success": false, "error": "Missing battle context"}

	var battle = context["battle"]

	# Set battle outcome flags
	if battle.has("evacuated"):
		battle.evacuated = true

	if battle.has("held_field"):
		battle.held_field = false

	return {
		"success": true,
		"ability": StarAbility.ITS_TIME_TO_GO,
		"battle": battle,
		"message": "Used 'It's Time To Go' - All crew evacuate immediately! (Do NOT hold the field)"
	}


## "Rainy Day Fund" - Gain 1D6+5 credits
##
## @param context: Optional "dice_system" for injection (testing)
## @return: Result dictionary
func _use_rainy_day_fund(context: Dictionary) -> Dictionary:
	var dice_system = context.get("dice_system", null)

	# Roll 1D6+5 - use injected dice system if available, otherwise use randi
	var roll: int
	if dice_system != null and dice_system.has_method("roll"):
		roll = dice_system.roll(1, 6) + 5
	else:
		# Fallback to basic random roll
		roll = (randi() % 6) + 1 + 5

	return {
		"success": true,
		"ability": StarAbility.RAINY_DAY_FUND,
		"credits_gained": roll,
		"message": "Used 'Rainy Day Fund' - Gained %d credits! (rolled %d on 1D6+5)" % [roll, roll - 5]
	}
