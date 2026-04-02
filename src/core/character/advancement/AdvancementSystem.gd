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
const Godot4Utils = preload("res://src/utils/Godot4Utils.gd")

# Signals
signal character_advanced(character: Resource, advancement_type: String, new_value: int)
signal experience_gained(character: Resource, amount: int, source: String)
signal training_completed(character: Resource, training_type: String)
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
	# Core Rules p.125 — 7 Advanced Training courses
	"pilot": 20,
	"medical": 20,
	"mechanic": 15,
	"broker": 15,
	"security": 10,
	"merchant": 10,
	"bot_tech": 10,
	# Compendium p.22 — Psionic advancement (XP cost, not credits)
	"psionics": 12, # Acquire new psionic power (Compendium p.22)
	"psionics_enhance": 6 # Enhance existing psionic power (Compendium p.22)
}

# Bot stat upgrades — Core Rules p.123:
# "Bot characters may install upgrades to any ability score by paying credits
#  equal to the XP cost. Each ability score can be upgraded only once."
# Cost in credits = stat_advancement_costs value for that stat.
# Compendium p.28 has separate functional upgrades (Built-in weapon, Jump module,
# etc.) — those are NOT stat boosts and should be implemented separately if needed.

# Experience gain rates — Core Rules p.123 XP table
# Characters that flee in the first 2 rounds receive 0 XP.
var experience_sources: Dictionary = {
	"casualty": 1,              # Became a casualty
	"survived_no_win": 2,       # Survived, but did not Win
	"survived_and_won": 3,      # Survived and Won
	"first_casualty": 1,        # First character to inflict a casualty
	"killed_unique_individual": 1, # Killed Unique Individual
	"easy_mode": 1,             # Campaign is on Easy mode
	"final_quest_stage": 1,     # Crew completed the final stage of a Quest
}

func _init() -> void:
	_initialize_dice_manager()

func _initialize_dice_manager() -> void:
	## Initialize dice manager reference
	# Will be injected by parent system
	pass

## Award experience to a character

func award_experience(character: Resource, amount: int, source: String) -> void:
	## Award experience points to a character
	if not character:
		return

	var current_xp = Godot4Utils.safe_get_property(character, "experience_points", 0)
	var new_xp = current_xp + amount

	if character and character.has_method("set"): character.set("experience_points", new_xp)

	# Track experience sources for stats
	var xp_sources = Godot4Utils.safe_get_property(character, "experience_sources", {})

	xp_sources[source] = xp_sources.get(source, 0) + amount
	if character and character.has_method("set"): character.set("experience_sources", xp_sources)

	experience_gained.emit(character, amount, source)

	pass # XP awarded

## Check if character can afford an advancement
func can_afford_advancement(character: Resource, advancement_type: String, advancement_target: String = "") -> bool:
	## Check if character has enough XP for advancement

	var current_xp = Godot4Utils.safe_get_property(character, "experience_points", 0)
	var cost = _get_advancement_cost(advancement_type, advancement_target)

	return current_xp >= cost

## Get the cost of an advancement
func _get_advancement_cost(advancement_type: String, target: String = "") -> int:
	## Get the XP cost for a specific advancement (Core Rules p.123-125)
	match advancement_type:
		"stat":
			return stat_advancement_costs.get(target, 0)
		"training":
			return training_costs.get(target, 0)
		_:
			return 0

## Attempt to advance a character stat
func advance_stat(character: Resource, stat_name: String) -> bool:
	## Attempt to advance a character stat using Five Parsecs rules
	if not character:
		return false

	var cost = stat_advancement_costs.get(stat_name, 0)
	var current_xp = Godot4Utils.safe_get_property(character, "experience_points", 0)
	var current_stat = Godot4Utils.safe_get_property(character, stat_name, 0)
	var max_stat = stat_max_values.get(stat_name, 5)

	# Engineer restriction: Cannot raise Toughness above 4 (Core Rules p.124)
	var char_class: String = Godot4Utils.safe_get_property(character, "character_class", "")
	if char_class.to_upper() == "ENGINEER" and stat_name == "toughness":
		max_stat = mini(max_stat, 4)

	# Psionic restriction: Cannot increase Combat Skill through XP (Compendium p.20)
	var psionic_power_val: String = Godot4Utils.safe_get_property(character, "psionic_power", "")
	if psionic_power_val != "" and stat_name == "combat_skill":
		return false

	# Check if advancement is possible
	if current_xp < cost:
		return false

	if current_stat >= max_stat:
		return false

	# Core Rules p.123: Direct spend — pay XP cost, increase stat by +1. No roll needed.
	var new_stat_value = current_stat + 1
	if character and character.has_method("set"): character.set(stat_name, new_stat_value)
	if character and character.has_method("set"): character.set("experience_points", current_xp - cost)

	character_advanced.emit(character, "stat_" + str(stat_name), new_stat_value)
	return true

## Purchase training for a character
func purchase_training(character: Resource, training_type: String) -> bool:
	## Purchase training for a character
	if not character:
		return false

	var cost = training_costs.get(training_type, 0)
	var current_xp = Godot4Utils.safe_get_property(character, "experience_points", 0)

	if current_xp < cost:
		return false

	# Check if character already has this training
	var current_training = Godot4Utils.safe_get_property(character, "training", [])
	if training_type in current_training:
		return false

	# Apply training
	current_training.append(training_type)
	if character and character.has_method("set"): character.set("training", current_training)
	if character and character.has_method("set"): character.set("experience_points", current_xp - cost)

	training_completed.emit(character, training_type)

	pass # Training completed

	# Apply training benefits
	_apply_training_benefits(character, training_type)

	return true

## Apply benefits from completed training
## Core Rules p.125: Training effects are rule modifications checked during
## specific game phases, NOT generic stat bonuses. We set boolean flags here;
## the actual effects are applied at the relevant game phases.
func _apply_training_benefits(character: Resource, training_type: String) -> void:
	if not character or not character.has_method("set"):
		return

	match training_type:
		"pilot":
			# Core Rules p.125: If Starship Travel event calls for Savvy test,
			# roll 2D6 pick better die + add +2 to score.
			character.set("has_pilot_training", true)

		"medical":
			# Core Rules p.125: After battle, nominate a casualty to roll twice
			# on Injury Table, pick better result. Crew member must have been in
			# battle and not become a casualty. Shuttle allows remote application.
			character.set("has_medical_training", true)

		"mechanic":
			# Core Rules p.125: Ship in need of Repairs: repair +1 Hull Point per
			# campaign turn (2 total per turn). Engineers count XP spent as double.
			character.set("has_mechanic_training", true)

		"broker":
			# Core Rules p.125: Add +1 when rolling for licenses, Advanced
			# Training applications, or searching for Patrons.
			character.set("has_broker_training", true)

		"security":
			# Core Rules p.125: If this crew member is in your squad, add +1 to
			# Seize the Initiative roll. Ferals obtain at -2 cost.
			character.set("has_security_training", true)

		"merchant":
			# Core Rules p.125: When this crew member Trades, reroll one Trade
			# roll per campaign turn. Must accept new roll.
			character.set("has_merchant_training", true)

		"bot_tech":
			# Core Rules p.125: All Bot upgrades cost 1 credit less. If Bot/Soulless
			# rolls for post-battle injury, roll twice pick better.
			character.set("has_bot_tech_training", true)

		"psionics":
			# Compendium p.22: Acquire Psionic Power (12 XP)
			# Roll D10 for power. If duplicate, modify roll ±1.
			var psionic_data: Dictionary = _load_psionic_powers_json()
			var power_ids: Array = psionic_data.keys()
			if power_ids.is_empty():
				return
			var roll_index: int = _roll_dice("Psionic Acquisition", "D10") - 1
			roll_index = clampi(roll_index, 0, power_ids.size() - 1)
			var new_power_id: String = power_ids[roll_index]
			var current_power: String = Godot4Utils.safe_get_property(character, "psionic_power", "")
			if new_power_id == current_power and power_ids.size() > 1:
				var alt_index: int = (roll_index + 1) % power_ids.size()
				new_power_id = power_ids[alt_index]
			character.set("psionic_power", new_power_id)

		"psionics_enhance":
			# Compendium p.22: Power Enhancement (6 XP)
			# +1D6 to projection roll for chosen power. One enhancement per power.
			var has_power: String = Godot4Utils.safe_get_property(character, "psionic_power", "")
			if has_power != "":
				character.set("psionic_power_enhanced", true)

## Get available advancements for a character

func get_available_advancements(character: Resource) -> Array[Dictionary]:
	## Get list of available advancements for a character
	var advancements: Array = []
	var current_xp = Godot4Utils.safe_get_property(character, "experience_points", 0)

	# Stat advancements
	for stat_name in stat_advancement_costs.keys():
		var current_stat = Godot4Utils.safe_get_property(character, stat_name, 0)
		var max_stat = stat_max_values.get(stat_name, 5)
		var cost = stat_advancement_costs[stat_name]

		# Engineer restriction: Cannot raise Toughness above 4 (Core Rules p.124)
		var adv_char_class: String = Godot4Utils.safe_get_property(character, "character_class", "")
		if adv_char_class.to_upper() == "ENGINEER" and stat_name == "toughness":
			max_stat = mini(max_stat, 4)

		# Psionic restriction: Cannot increase Combat Skill through XP (Compendium p.20)
		var adv_psionic: String = Godot4Utils.safe_get_property(character, "psionic_power", "")
		if adv_psionic != "" and stat_name == "combat_skill":
			continue

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
	var current_training = Godot4Utils.safe_get_property(character, "training", [])
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

## Calculate experience from battle results — Core Rules p.123 XP table
## Characters that flee in the first 2 rounds receive 0 XP.
func calculate_battle_experience(character: Resource, battle_result: Dictionary) -> int:
	var char_name: String = Godot4Utils.safe_get_property(character, "character_name", "")

	# Core Rules p.123: Characters that flee in first 2 rounds get nothing
	var fled_early: Array = battle_result.get("fled_early", [])
	if char_name in fled_early:
		return 0

	var xp_gained: int = 0
	var is_casualty: bool = char_name in battle_result.get("crew_casualties", [])
	var victory: bool = battle_result.get("victory", false)

	# Core Rules p.123 XP table:
	if is_casualty:
		xp_gained += experience_sources["casualty"]  # +1
	elif victory:
		xp_gained += experience_sources["survived_and_won"]  # +3
	else:
		xp_gained += experience_sources["survived_no_win"]  # +2

	# First character to inflict a casualty: +1
	if char_name == battle_result.get("first_to_inflict_casualty", ""):
		xp_gained += experience_sources["first_casualty"]

	# Killed Unique Individual: +1
	if char_name in battle_result.get("killed_unique_individual", []):
		xp_gained += experience_sources["killed_unique_individual"]

	# Easy mode bonus: +1 (campaign difficulty check)
	if battle_result.get("easy_mode", false):
		xp_gained += experience_sources["easy_mode"]

	# Completed final stage of a Quest: +1
	if battle_result.get("final_quest_stage", false):
		xp_gained += experience_sources["final_quest_stage"]

	return xp_gained

## Award post-battle experience to all crew
func award_post_battle_experience(crew_members: Array, battle_result: Dictionary) -> void:
	## Award experience to all crew members after battle
	for crew_member in crew_members:
		var xp_amount = calculate_battle_experience(crew_member, battle_result)
		if xp_amount > 0:
			var source: String = "victory" if battle_result.get("victory", false) else "mission"
			award_experience(crew_member, xp_amount, source)

## Get character advancement statistics

func get_advancement_stats(character: Resource) -> Dictionary:
	## Get advancement statistics for a character
	return {
		"experience_points": Godot4Utils.safe_get_property(character, "experience_points", 0),
		"total_stat_improvements": _count_stat_improvements(character),
		"training_completed": Godot4Utils.safe_get_property(character, "training", []).size(),
		"advancement_attempts": Godot4Utils.safe_get_property(character, "advancement_attempts", 0),
		"advancement_successes": Godot4Utils.safe_get_property(character, "advancement_successes", 0)
	}

func _count_stat_improvements(character: Resource) -> int:
	## Count total stat improvements above base values
	var improvements: int = 0
	var base_stats = {"reactions": 1, "combat_skill": 0, "toughness": 3, "savvy": 1, "speed": 4, "luck": 0}

	for stat_name in base_stats.keys():
		var current = Godot4Utils.safe_get_property(character, stat_name, base_stats[stat_name])
		var base = base_stats[stat_name]
		improvements += max(0, current - base)

	return improvements

## Roll dice for advancement
func _roll_dice(context: String, pattern: String) -> int:
	## Roll dice using the dice system
	if dice_manager and dice_manager.has_method("roll_dice"):
		return dice_manager.roll_dice(context, pattern)
	else:
		match pattern:
			"D6": return randi_range(1, 6)
			"D10": return randi_range(1, 10)
			_: return randi_range(1, 6)

## Bot Stat Upgrade System — Core Rules p.123:
## "Bot characters may install upgrades to any ability score by paying credits
##  equal to the XP cost. Each ability score can be upgraded only once."
## Bots do NOT receive XP. Soulless use the normal XP process and cannot buy
## Bot upgrades. Bot Tech training reduces all bot upgrade costs by 1 credit.

func get_available_bot_upgrades(bot: Resource) -> Array[Dictionary]:
	## Get list of available stat upgrades for a bot (Core Rules p.123)
	var available: Array[Dictionary] = []

	if not bot or not _is_bot(bot):
		return available

	var upgraded_stats: Array = Godot4Utils.safe_get_property(bot, "bot_upgraded_stats", [])

	for stat_name in stat_advancement_costs.keys():
		if stat_name in upgraded_stats:
			continue  # Each stat can only be upgraded once

		var cost: int = stat_advancement_costs[stat_name]
		var current_val: int = Godot4Utils.safe_get_property(bot, stat_name, 0)
		var max_val: int = stat_max_values.get(stat_name, 6)

		if current_val >= max_val:
			continue

		available.append({
			"id": stat_name,
			"name": "+1 %s" % stat_name.capitalize(),
			"cost": cost,
			"effects": {stat_name: 1},
			"description": "+1 %s (credits = XP cost)" % stat_name.capitalize()
		})

	return available

func can_install_bot_upgrade(bot: Resource, stat_name: String, campaign_credits: int) -> bool:
	## Check if bot can upgrade a stat (Core Rules p.123)
	if not bot or not _is_bot(bot):
		return false

	if not stat_advancement_costs.has(stat_name):
		return false

	var upgraded_stats: Array = Godot4Utils.safe_get_property(bot, "bot_upgraded_stats", [])
	if stat_name in upgraded_stats:
		return false

	var cost: int = stat_advancement_costs[stat_name]
	return campaign_credits >= cost

func install_bot_upgrade(bot: Resource, stat_name: String, game_state_ref: Resource) -> bool:
	## Install a bot stat upgrade by spending credits (Core Rules p.123)
	if not bot or not game_state_ref:
		return false

	if not _is_bot(bot):
		return false

	if not stat_advancement_costs.has(stat_name):
		return false

	var upgraded_stats: Array = Godot4Utils.safe_get_property(bot, "bot_upgraded_stats", [])
	if stat_name in upgraded_stats:
		return false

	var cost: int = stat_advancement_costs[stat_name]

	# Core Rules p.125 Bot Tech training: "All Bot upgrades cost 1 credit less."
	# Check if any crew member has bot_tech training (caller should pass this)
	# For now, cost is the base XP cost in credits.

	var current_credits: int = 0
	if game_state_ref.has_method("get_credits"):
		current_credits = game_state_ref.get_credits()
	else:
		current_credits = Godot4Utils.safe_get_property(game_state_ref, "credits", 0)

	if current_credits < cost:
		return false

	# Deduct credits
	if game_state_ref.has_method("remove_credits"):
		if not game_state_ref.remove_credits(cost):
			return false
	elif game_state_ref.has_method("set"):
		game_state_ref.set("credits", current_credits - cost)

	# Apply +1 to the stat
	var current_val: int = Godot4Utils.safe_get_property(bot, stat_name, 0)
	var max_val: int = stat_max_values.get(stat_name, 6)
	var new_val: int = mini(current_val + 1, max_val)

	if bot.has_method("set"):
		bot.set(stat_name, new_val)

	# Track that this stat has been upgraded (each stat only once)
	upgraded_stats.append(stat_name)
	if bot.has_method("set"):
		bot.set("bot_upgraded_stats", upgraded_stats)

	bot_upgrade_installed.emit(bot, stat_name, {"stat": stat_name, "cost": cost, "new_value": new_val})
	return true


func _is_bot(character: Resource) -> bool:
	## Check if character is a bot
	if not character:
		return false

	# First try is_bot() method
	if character.has_method("is_bot"):
		return character.is_bot()

	# Fallback: Check origin property
	var origin = Godot4Utils.safe_get_property(character, "origin", "")
	return origin == "BOT" or origin == "Bot"


func _load_psionic_powers_json() -> Dictionary:
	## Load psionic powers from JSON data file (same source as CharacterCreator)
	var path := "res://data/psionic_powers.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("AdvancementSystem: Could not open psionic_powers.json at %s" % path)
		return {}
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_warning("AdvancementSystem: Failed to parse psionic_powers.json")
		return {}
	if json.data is Dictionary:
		return json.data
	return {}
