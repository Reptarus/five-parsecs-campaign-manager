class_name FPCM_AdvancementSystem
extends RefCounted

## Five Parsecs Character Advancement System
##
## Implements complete Five Parsecs advancement rules:
## - Experience point tracking and spending
## - Stat improvements with dice rolling
## - Training and specialization paths
## - Experience-based benefits and abilities
## - Integration with dice system for advancement rolls

# Dependencies
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Signals
signal character_advanced(character: Resource, advancement_type: String, new_value: int)
signal experience_gained(character: Resource, amount: int, source: String)
signal training_completed(character: Resource, training_type: String)
signal advancement_roll_made(character: Resource, stat: String, roll_result: int, success: bool)

# Manager references
var dice_manager: Node = null
var _campaign_manager: Resource = null

# Advancement rules from Five Parsecs Core Rules
var stat_advancement_costs: Dictionary = {
	"reactions": 7,
	"combat_skill": 7,
	"toughness": 6,
	"savvy": 5,
	"speed": 5,
	"luck": 10
}

var stat_max_values: Dictionary = {
	"reactions": 6,
	"combat_skill": 5,
	"toughness": 6,
	"savvy": 5,
	"speed": 8,
	"luck": 1 # Base humans, some species can go higher
}

var training_costs: Dictionary = {
	"pilot": 20,
	"medical": 20,
	"mechanic": 15,
	"broker": 15,
	"security": 10,
	"merchant": 10,
	"bot_tech": 10,
	"engineer": 15,
	"psionics": 25 # If using psionics rules
}

# Experience gain rates
var experience_sources: Dictionary = {
	"mission_victory": 3,
	"mission_failure": 1,
	"injury_survival": 1,
	"story_event": 2,
	"rival_encounter": 2,
	"patron_mission": 4,
	"discovery": 1,
	"combat_kill": 1
}

func _init() -> void:
	_initialize_dice_manager()

func _initialize_dice_manager() -> void:
	"""Initialize dice manager reference"""
	# Will be injected by parent system
	pass

## Award experience to a character
	
func award_experience(character: Resource, amount: int, source: String) -> void:
	"""Award experience points to a character"""
	if not character:
		return
	
	var current_xp = character.get("experience_points") if character.has("experience_points") else 0
	var new_xp = current_xp + amount
	
	character.set("experience_points", new_xp)
	
	# Track experience sources for stats
	var xp_sources = character.get("experience_sources") if character.has("experience_sources") else {}
	
	xp_sources[source] = xp_sources.get(source, 0) + amount
	character.set("experience_sources", xp_sources)
	
	experience_gained.emit(character, amount, source) # warning: return value discarded (intentional)
	
	print("Character %s gained %d XP from %s (Total: %d)" % [
		character.get("character_name") if character.has("character_name") else "Unknown",
		amount,
		source,
		new_xp
	])

## Check if character can afford an advancement
func can_afford_advancement(character: Resource, advancement_type: String, advancement_target: String = "") -> bool:
	"""Check if character has enough XP for advancement"""
	
	var current_xp = character.get("experience_points") if character.has("experience_points") else 0
	var cost = _get_advancement_cost(advancement_type, advancement_target)
	
	return current_xp >= cost

## Get the cost of an advancement
func _get_advancement_cost(advancement_type: String, target: String = "") -> int:
	"""Get the XP cost for a specific advancement"""
	match advancement_type:
		"stat":
			return stat_advancement_costs.get(target, 0)
		"training":
			return training_costs.get(target, 0)
		"equipment_training":
			return 5 # General equipment proficiency
		"ability":
			return 15 # Special abilities
		_:
			return 0

## Attempt to advance a character stat
func advance_stat(character: Resource, stat_name: String) -> bool:
	"""Attempt to advance a character stat using Five Parsecs rules"""
	if not character:
		return false
	
	var cost = stat_advancement_costs.get(stat_name, 0)
	var current_xp = character.get("experience_points") if character.has("experience_points") else 0
	var current_stat = character.get(stat_name) if character.has(stat_name) else 0
	var max_stat = stat_max_values.get(stat_name, 5)
	
	# Check if advancement is possible
	if current_xp < cost:
		print("Not enough XP: Need %d, have %d" % [cost, current_xp])
		return false
	
	if current_stat >= max_stat:
		print("Stat already at maximum: %d" % max_stat)
		return false
	
	# Make advancement roll (D6 + current stat vs 7+)
	var advancement_roll = _roll_dice("Advancement: " + stat_name, "D6")
	var total_roll = advancement_roll + current_stat
	var success = total_roll >= 7
	
	advancement_roll_made.emit(character, stat_name, advancement_roll, success) # warning: return value discarded (intentional)
	
	if success:
		# Successful advancement
		var new_stat_value = current_stat + 1
		character.set(stat_name, new_stat_value)
		character.set("experience_points", current_xp - cost)
		
		character_advanced.emit(character, "stat_" + stat_name, new_stat_value) # warning: return value discarded (intentional)
		
		print("Character %s advanced %s from %d to %d (Roll: %d+%d=%d)" % [
			character.get("character_name") if character.has("character_name") else "Unknown",
			stat_name,
			current_stat,
			new_stat_value,
			advancement_roll,
			current_stat,
			total_roll
		])
		
		return true
	else:
		# Failed advancement - half XP cost is still consumed
		var xp_lost = cost / 2
		character.set("experience_points", current_xp - xp_lost)
		
		print("Character %s failed to advance %s (Roll: %d+%d=%d, lost %d XP)" % [
			character.get("character_name") if character.has("character_name") else "Unknown",
			stat_name,
			advancement_roll,
			current_stat,
			total_roll,
			xp_lost
		])
		
		return false

## Purchase training for a character
func purchase_training(character: Resource, training_type: String) -> bool:
	"""Purchase training for a character"""
	if not character:
		return false
	
	var cost = training_costs.get(training_type, 0)
	var current_xp = character.get("experience_points") if character.has("experience_points") else 0
	
	if current_xp < cost:
		print("Not enough XP for training: Need %d, have %d" % [cost, current_xp])
		return false
	
	# Check if character already has this training
	var current_training = character.get("training") if character.has("training") else []
	if training_type in current_training:
		print("Character already has %s training" % training_type)
		return false
	
	# Apply training
	current_training.append(training_type) # warning: return value discarded (intentional)
	character.set("training", current_training)
	character.set("experience_points", current_xp - cost)
	
	training_completed.emit(character, training_type) # warning: return value discarded (intentional)
	
	print("Character %s completed %s training for %d XP" % [
		character.get("character_name") if character.has("character_name") else "Unknown",
		training_type,
		cost
	])
	
	# Apply training benefits
	_apply_training_benefits(character, training_type)
	
	return true

## Apply benefits from completed training
func _apply_training_benefits(character: Resource, training_type: String) -> void:
	"""Apply the benefits of completed training"""
	match training_type:
		"pilot":
			# Pilot training provides bonuses to ship operations
			var pilot_bonus = (character.get("pilot_bonus") if character.has("pilot_bonus") else 0) + 1
			character.set("pilot_bonus", pilot_bonus)
		
		"medical":
			# Medical training allows healing actions
			character.set("can_heal", true)
			var medical_skill = (character.get("medical_skill") if character.has("medical_skill") else 0) + 2
			character.set("medical_skill", medical_skill)
		
		"mechanic":
			# Mechanic training allows equipment repair
			character.set("can_repair", true)
			var repair_skill = (character.get("repair_skill") if character.has("repair_skill") else 0) + 2
			character.set("repair_skill", repair_skill)
		
		"broker":
			# Broker training provides trade bonuses
			var trade_bonus = (character.get("trade_bonus") if character.has("trade_bonus") else 0) + 1
			character.set("trade_bonus", trade_bonus)
		
		"security":
			# Security training provides combat bonuses
			var security_bonus = (character.get("security_bonus") if character.has("security_bonus") else 0) + 1
			character.set("security_bonus", security_bonus)
		
		"merchant":
			# Merchant training provides market bonuses
			var market_bonus = (character.get("market_bonus") if character.has("market_bonus") else 0) + 1
			character.set("market_bonus", market_bonus)
		
		"bot_tech":
			# Bot tech training allows bot management
			character.set("can_manage_bots", true)
			var bot_skill = (character.get("bot_skill") if character.has("bot_skill") else 0) + 2
			character.set("bot_skill", bot_skill)
		
		"engineer":
			# Engineer training provides ship upgrade bonuses
			var engineering_bonus = (character.get("engineering_bonus") if character.has("engineering_bonus") else 0) + 1
			character.set("engineering_bonus", engineering_bonus)

## Get available advancements for a character
	
func get_available_advancements(character: Resource) -> Array[Dictionary]:
	"""Get list of available advancements for a character"""
	var advancements: Array = []
	var current_xp = character.get("experience_points") if character.has("experience_points") else 0
	
	# Stat advancements
	for stat_name in stat_advancement_costs.keys():
		var current_stat = character.get(stat_name) if character.has(stat_name) else 0
		var max_stat = stat_max_values.get(stat_name, 5)
		var cost = stat_advancement_costs[stat_name]
		
		if current_stat < max_stat and current_xp >= cost:
			advancements.append({ # warning: return value discarded (intentional)
				"type": "stat",
				"target": stat_name,
				"cost": cost,
				"current_value": current_stat,
				"max_value": max_stat,
				"description": "Advance %s from %d to %d" % [stat_name.capitalize(), current_stat, current_stat + 1]
			})
	
	# Training advancements
	var current_training = character.get("training") if character.has("training") else []
	for training_type in training_costs.keys():
		var cost = training_costs[training_type]
		
		if training_type not in current_training and current_xp >= cost:
			advancements.append({ # warning: return value discarded (intentional)
				"type": "training",
				"target": training_type,
				"cost": cost,
				"description": "Learn %s training" % training_type.capitalize()
			})
	
	return advancements

## Calculate experience from battle results
func calculate_battle_experience(character: Resource, battle_result: Dictionary) -> int:
	"""Calculate experience gained from battle results"""
	var xp_gained: int = 0
	
	# Base experience for participating in battle
	if battle_result.get("victory", false):
		xp_gained += experience_sources["mission_victory"]
	else:
		xp_gained += experience_sources["mission_failure"]
	
	# Experience for injuries survived
	if (character.get("character_name") if character.has("character_name") else "") in battle_result.get("crew_injuries", []):
		xp_gained += experience_sources["injury_survival"]
	
	# Experience for enemies defeated (if tracked)
	var enemies_defeated = battle_result.get("enemies_defeated_by_character", {})
	var personal_kills = enemies_defeated.get((character.get("character_name") if character.has("character_name") else ""), 0)
	xp_gained += personal_kills * experience_sources["combat_kill"]
	
	return xp_gained

## Award post-battle experience to all crew
func award_post_battle_experience(crew_members: Array[Resource], battle_result: Dictionary) -> void:
	"""Award experience to all crew members after battle"""
	for crew_member in crew_members:
		var xp_amount = calculate_battle_experience(crew_member, battle_result)
		if xp_amount > 0:
			var source: String = "victory" if battle_result.get("victory", false) else "mission"
			award_experience(crew_member, xp_amount, source)

## Get character advancement statistics
	
func get_advancement_stats(character: Resource) -> Dictionary:
	"""Get advancement statistics for a character"""
	return {
		"experience_points": character.get("experience_points") if character.has("experience_points") else 0,
		"total_stat_improvements": _count_stat_improvements(character),
		"training_completed": (character.get("training") if character.has("training") else []).size(),
		"advancement_attempts": character.get("advancement_attempts") if character.has("advancement_attempts") else 0,
		"advancement_successes": character.get("advancement_successes") if character.has("advancement_successes") else 0
	}

func _count_stat_improvements(character: Resource) -> int:
	"""Count total stat improvements above base values"""
	var improvements: int = 0
	var base_stats = {"reactions": 1, "combat_skill": 0, "toughness": 3, "savvy": 1, "speed": 4, "luck": 0}
	
	for stat_name in base_stats.keys():
		var current = character.get(stat_name) if character.has(stat_name) else base_stats[stat_name]
		var base = base_stats[stat_name]
		improvements += max(0, current - base)
	
	return improvements

## Roll dice for advancement
func _roll_dice(context: String, pattern: String) -> int:
	"""Roll dice using the dice system"""
	if dice_manager and dice_manager.has_method("roll_dice"):
		return dice_manager.roll_dice(context, pattern)
	else:
		match pattern:
			"D6": return randi_range(1, 6)
			"D10": return randi_range(1, 10)
			_: return randi_range(1, 6)

## Serialization for save/load
func serialize() -> Dictionary:
	"""Serialize advancement system data"""
	return {
		"stat_advancement_costs": stat_advancement_costs,
		"training_costs": training_costs,
		"experience_sources": experience_sources
	}

func deserialize(data: Dictionary) -> void:
	"""Deserialize advancement system data"""
	if data.has("stat_advancement_costs"):
		stat_advancement_costs = data["stat_advancement_costs"]
	if data.has("training_costs"):
		training_costs = data["training_costs"]
	if data.has("experience_sources"):
		experience_sources = data["experience_sources"]