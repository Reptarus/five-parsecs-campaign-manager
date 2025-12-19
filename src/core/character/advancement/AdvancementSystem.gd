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
# GlobalEnums available as autoload singleton

# Signals
signal character_advanced(character: Resource, advancement_type: String, new_value: int)
signal experience_gained(character: Resource, amount: int, source: String)
signal training_completed(character: Resource, training_type: String)
signal advancement_roll_made(character: Resource, stat: String, roll_result: int, success: bool)
signal bot_upgrade_installed(bot: Resource, upgrade_id: String, upgrade_data: Dictionary)

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

# Bot upgrades (credits-based, not XP) - Five Parsecs Core Rules p.98
var bot_upgrades: Dictionary = {
	"combat_module": {
		"name": "Combat Module",
		"cost": 15,
		"effects": {"combat_skill": 1},
		"description": "+1 Combat Skill"
	},
	"reflex_enhancer": {
		"name": "Reflex Enhancer",
		"cost": 12,
		"effects": {"reactions": 1},
		"description": "+1 Reactions"
	},
	"armor_plating": {
		"name": "Armor Plating",
		"cost": 18,
		"effects": {"toughness": 1},
		"description": "+1 Toughness"
	},
	"speed_actuator": {
		"name": "Speed Actuator",
		"cost": 10,
		"effects": {"speed": 1},
		"description": "+1 Speed"
	},
	"sensor_array": {
		"name": "Sensor Array",
		"cost": 14,
		"effects": {"savvy": 1},
		"description": "+1 Savvy"
	},
	"repair_module": {
		"name": "Self-Repair Module",
		"cost": 20,
		"effects": {"special": "self_repair"},
		"description": "Reduces recovery time by 1 turn"
	}
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

	var current_xp = safe_get_property(character, "experience_points", 0)
	var new_xp = current_xp + amount

	if character and character.has_method("set"): character.set("experience_points", new_xp)

	# Track experience sources for stats
	var xp_sources = safe_get_property(character, "experience_sources", {})

	xp_sources[source] = xp_sources.get(source, 0) + amount
	if character and character.has_method("set"): character.set("experience_sources", xp_sources)

	experience_gained.emit(character, amount, source)

	print("Character %s gained %d XP from %s (Total: %d)" % [
		safe_get_property(character, "character_name", "Unknown"),
		amount,
		source,
		new_xp
	])

## Check if character can afford an advancement
func can_afford_advancement(character: Resource, advancement_type: String, advancement_target: String = "") -> bool:
	"""Check if character has enough XP for advancement"""

	var current_xp = safe_get_property(character, "experience_points", 0)
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
	var current_xp = safe_get_property(character, "experience_points", 0)
	var current_stat = safe_get_property(character, stat_name, 0)
	var max_stat = stat_max_values.get(stat_name, 5)

	# Check if advancement is possible
	if current_xp < cost:
		print("Not enough XP: Need %d, have %d" % [cost, current_xp])
		return false

	if current_stat >= max_stat:
		print("Stat already at maximum: %d" % max_stat)
		return false

	# Make advancement roll (D6 + current stat vs 7+)
	var advancement_roll = _roll_dice("Advancement: " + str(stat_name), "D6")
	var total_roll = advancement_roll + current_stat
	var success = total_roll >= 7

	advancement_roll_made.emit(character, stat_name, advancement_roll, success)

	if success:
		# Successful advancement
		var new_stat_value = current_stat + 1
		if character and character.has_method("set"): character.set(stat_name, new_stat_value)
		if character and character.has_method("set"): character.set("experience_points", current_xp - cost)

		character_advanced.emit(character, "stat_" + str(stat_name), new_stat_value)

		print("Character %s advanced %s from %d to %d (Roll: %d+%d=%d)" % [
			safe_get_property(character, "character_name", "Unknown"),
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
		var xp_lost = cost / 2.0
		if character and character.has_method("set"): character.set("experience_points", current_xp - xp_lost)

		print("Character %s failed to advance %s (Roll: %d+%d=%d, lost %d XP)" % [
			safe_get_property(character, "character_name", "Unknown"),
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
	var current_xp = safe_get_property(character, "experience_points", 0)

	if current_xp < cost:
		print("Not enough XP for training: Need %d, have %d" % [cost, current_xp])
		return false

	# Check if character already has this training
	var current_training = safe_get_property(character, "training", [])
	if training_type in current_training:
		print("Character already has %s training" % training_type)
		return false

	# Apply training
	current_training.append(training_type)
	if character and character.has_method("set"): character.set("training", current_training)
	if character and character.has_method("set"): character.set("experience_points", current_xp - cost)

	training_completed.emit(character, training_type)

	print("Character %s completed %s training for %d XP" % [
		safe_get_property(character, "character_name", "Unknown"),
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
			var pilot_bonus = safe_get_property(character, "pilot_bonus", 0) + 1
			if character and character.has_method("set"): character.set("pilot_bonus", pilot_bonus)

		"medical":
			# Medical training allows healing actions
			if character and character.has_method("set"): character.set("can_heal", true)
			var medical_skill = safe_get_property(character, "medical_skill", 0) + 2
			if character and character.has_method("set"): character.set("medical_skill", medical_skill)

		"mechanic":
			# Mechanic training allows equipment repair
			if character and character.has_method("set"): character.set("can_repair", true)
			var repair_skill = safe_get_property(character, "repair_skill", 0) + 2
			if character and character.has_method("set"): character.set("repair_skill", repair_skill)

		"broker":
			# Broker training provides trade bonuses
			var trade_bonus = safe_get_property(character, "trade_bonus", 0) + 1
			if character and character.has_method("set"): character.set("trade_bonus", trade_bonus)

		"security":
			# Security training provides combat bonuses
			var security_bonus = safe_get_property(character, "security_bonus", 0) + 1
			if character and character.has_method("set"): character.set("security_bonus", security_bonus)

		"merchant":
			# Merchant training provides market bonuses
			var market_bonus = safe_get_property(character, "market_bonus", 0) + 1
			if character and character.has_method("set"): character.set("market_bonus", market_bonus)

		"bot_tech":
			# Bot tech training allows bot management
			if character and character.has_method("set"): character.set("can_manage_bots", true)
			var bot_skill = safe_get_property(character, "bot_skill", 0) + 2
			if character and character.has_method("set"): character.set("bot_skill", bot_skill)

		"engineer":
			# Engineer training provides ship upgrade bonuses
			var engineering_bonus = safe_get_property(character, "engineering_bonus", 0) + 1
			if character and character.has_method("set"): character.set("engineering_bonus", engineering_bonus)

## Get available advancements for a character

func get_available_advancements(character: Resource) -> Array[Dictionary]:
	"""Get list of available advancements for a character"""
	var advancements: Array = []
	var current_xp = safe_get_property(character, "experience_points", 0)

	# Stat advancements
	for stat_name in stat_advancement_costs.keys():
		var current_stat = safe_get_property(character, stat_name, 0)
		var max_stat = stat_max_values.get(stat_name, 5)
		var cost = stat_advancement_costs[stat_name]

		if current_stat < max_stat and current_xp >= cost:
			advancements.append({
				"type": "stat",
				"target": stat_name,
				"cost": cost,
				"current_value": current_stat,
				"max_value": max_stat,
				"description": "Advance %s from %d to %d" % [stat_name.capitalize(), current_stat, current_stat + 1]
			})

	# Training advancements
	var current_training = safe_get_property(character, "training", [])
	for training_type in training_costs.keys():
		var cost = training_costs[training_type]

		if training_type not in current_training and current_xp >= cost:
			advancements.append({
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
	if safe_get_property(character, "character_name", "") in battle_result.get("crew_injuries", []):
		xp_gained += experience_sources["injury_survival"]

	# Experience for enemies defeated (if tracked)
	var enemies_defeated = battle_result.get("enemies_defeated_by_character", {})
	var personal_kills = enemies_defeated.get(safe_get_property(character, "character_name", ""), 0)
	xp_gained += personal_kills * experience_sources["combat_kill"]

	return xp_gained

## Award post-battle experience to all crew
func award_post_battle_experience(crew_members: Array, battle_result: Dictionary) -> void:
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
		"experience_points": safe_get_property(character, "experience_points", 0),
		"total_stat_improvements": _count_stat_improvements(character),
		"training_completed": safe_get_property(character, "training", []).size(),
		"advancement_attempts": safe_get_property(character, "advancement_attempts", 0),
		"advancement_successes": safe_get_property(character, "advancement_successes", 0)
	}

func _count_stat_improvements(character: Resource) -> int:
	"""Count total stat improvements above base values"""
	var improvements: int = 0
	var base_stats = {"reactions": 1, "combat_skill": 0, "toughness": 3, "savvy": 1, "speed": 4, "luck": 0}

	for stat_name in base_stats.keys():
		var current = safe_get_property(character, stat_name, base_stats[stat_name])
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

## Bot Upgrade System (Five Parsecs Core Rules p.98)
## Bots don't gain XP - they purchase upgrades with credits instead

func get_available_bot_upgrades(bot: Resource) -> Array[Dictionary]:
	"""Get list of available bot upgrades for purchase"""
	var available: Array[Dictionary] = []
	
	if not bot or not _is_bot(bot):
		return available
	
	var installed_upgrades: Array = safe_get_property(bot, "bot_upgrades", [])
	
	# Return upgrades not yet installed
	for upgrade_id in bot_upgrades.keys():
		if upgrade_id not in installed_upgrades:
			var upgrade_data: Dictionary = bot_upgrades[upgrade_id].duplicate()
			upgrade_data["id"] = upgrade_id
			available.append(upgrade_data)
	
	return available

func can_install_bot_upgrade(bot: Resource, upgrade_id: String, campaign_credits: int) -> bool:
	"""Check if bot can install upgrade (has credits and doesn't already have it)"""
	if not bot or not _is_bot(bot):
		return false
	
	if not bot_upgrades.has(upgrade_id):
		return false
	
	var installed_upgrades: Array = safe_get_property(bot, "bot_upgrades", [])
	if upgrade_id in installed_upgrades:
		return false
	
	var cost: int = bot_upgrades[upgrade_id].get("cost", 0)
	return campaign_credits >= cost

func install_bot_upgrade(bot: Resource, upgrade_id: String, game_state: Resource) -> bool:
	"""Install a bot upgrade by spending credits (Five Parsecs Core Rules p.98)

	Bots don't gain XP like regular characters - they purchase upgrades with credits.

	Args:
		bot: The bot character Resource to upgrade
		upgrade_id: The ID of the upgrade from bot_upgrades dictionary
		game_state: GameState Resource to deduct credits from

	Returns:
		bool: True if upgrade was successfully installed, False otherwise
	"""
	if not bot or not game_state:
		push_error("AdvancementSystem: Cannot install bot upgrade - missing bot or game_state")
		return false

	if not _is_bot(bot):
		push_error("AdvancementSystem: Cannot install bot upgrade - character is not a bot")
		return false

	if not bot_upgrades.has(upgrade_id):
		push_error("AdvancementSystem: Unknown bot upgrade ID: %s" % upgrade_id)
		return false

	# Check if bot already has this upgrade
	var installed_upgrades: Array = safe_get_property(bot, "bot_upgrades", [])
	if upgrade_id in installed_upgrades:
		push_warning("AdvancementSystem: Bot already has upgrade: %s" % upgrade_id)
		return false

	# Get upgrade data and cost
	var upgrade_data: Dictionary = bot_upgrades[upgrade_id]
	var cost: int = upgrade_data.get("cost", 0)

	# Check if campaign can afford upgrade
	var current_credits: int = 0
	if game_state.has_method("get_credits"):
		current_credits = game_state.get_credits()
	else:
		current_credits = safe_get_property(game_state, "credits", 0)

	if current_credits < cost:
		push_warning("AdvancementSystem: Cannot afford bot upgrade. Cost: %d, Available: %d" % [cost, current_credits])
		return false

	# Deduct credits from campaign
	if game_state.has_method("remove_credits"):
		if not game_state.remove_credits(cost):
			push_error("AdvancementSystem: Failed to deduct credits for bot upgrade")
			return false
	else:
		# Fallback: direct property set
		if game_state.has_method("set"):
			game_state.set("credits", current_credits - cost)

	# Install the upgrade on the bot
	if bot.has_method("add_bot_upgrade"):
		bot.add_bot_upgrade(upgrade_id)
	else:
		# Fallback: direct array modification
		installed_upgrades.append(upgrade_id)
		if bot.has_method("set"):
			bot.set("bot_upgrades", installed_upgrades)

	# Apply stat effects immediately
	_apply_bot_upgrade_effects(bot, upgrade_data)

	# Emit signal for UI/logging
	bot_upgrade_installed.emit(bot, upgrade_id, upgrade_data)

	print("Bot %s installed upgrade: %s (Cost: %d credits)" % [
		safe_get_property(bot, "character_name", safe_get_property(bot, "name", "Unknown")),
		upgrade_data.get("name", upgrade_id),
		cost
	])

	return true


func _apply_bot_upgrade_effects(bot: Resource, upgrade_data: Dictionary) -> void:
	"""Apply the stat effects from a bot upgrade"""
	var effects: Dictionary = upgrade_data.get("effects", {})

	for stat_name in effects.keys():
		var bonus: Variant = effects[stat_name]

		if stat_name == "special":
			# Handle special abilities
			_apply_special_bot_ability(bot, bonus)
		else:
			# Apply stat bonuses
			var current_value: int = safe_get_property(bot, stat_name, 0)
			var new_value: int = current_value + int(bonus)

			# Respect stat maximums
			var max_value: int = stat_max_values.get(stat_name, 10)
			new_value = mini(new_value, max_value)

			if bot.has_method("set"):
				bot.set(stat_name, new_value)

			print("Bot %s: %s increased from %d to %d" % [
				safe_get_property(bot, "character_name", "Unknown"),
				stat_name,
				current_value,
				new_value
			])


func _apply_special_bot_ability(bot: Resource, ability_id: String) -> void:
	"""Apply special bot abilities that aren't simple stat bonuses"""
	match ability_id:
		"self_repair":
			# Self-repair reduces recovery time by 1 turn
			if bot.has_method("set"):
				bot.set("has_self_repair", true)
			print("Bot %s gained self-repair ability" % safe_get_property(bot, "character_name", "Unknown"))
		_:
			push_warning("Unknown special bot ability: %s" % ability_id)


func _is_bot(character: Resource) -> bool:
	"""Check if character is a bot"""
	if not character:
		return false

	# First try is_bot() method
	if character.has_method("is_bot"):
		return character.is_bot()

	# Fallback: Check origin property
	var origin = safe_get_property(character, "origin", "")
	return origin == "BOT" or origin == "Bot"


## Safe property access helper
func safe_get_property(resource: Resource, property_name: String, default_value: Variant) -> Variant:
	"""Safely get a property from a Resource with fallback default"""
	if not resource:
		return default_value

	if resource.has_method("get"):
		var value = resource.get(property_name)
		if value != null:
			return value

	# Try direct property access via get() method
	if property_name in resource:
		return resource.get(property_name)

	return default_value