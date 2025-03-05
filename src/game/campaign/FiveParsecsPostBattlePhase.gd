@tool
extends BasePostBattlePhase
class_name FiveParsecsPostBattlePhase

const BasePostBattlePhase = preload("res://src/base/campaign/BasePostBattlePhase.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsCrewMember = preload("res://src/game/campaign/crew/FiveParsecsCrewMember.gd")
const GameDataManager = preload("res://src/core/managers/GameDataManager.gd")

# Battle outcome constants
enum BattleOutcome {
	VICTORY,
	DEFEAT,
	DRAW
}

# Reward tables
var loot_table = {
	"common": [
		"Credits (1d6 x 10)",
		"Ammunition (1d3)",
		"Medical Supplies (1d3)",
		"Food Rations (1d6)",
		"Basic Equipment"
	],
	"uncommon": [
		"Credits (2d6 x 10)",
		"Rare Ammunition (1d3)",
		"Advanced Medical Kit",
		"Weapon Attachment",
		"Armor Upgrade"
	],
	"rare": [
		"Credits (3d6 x 10)",
		"Experimental Weapon",
		"Rare Armor",
		"Valuable Artifact",
		"Advanced Technology"
	]
}

# Data manager for JSON data
var data_manager

# Experience point values
var xp_values = {
	"enemy_defeated": 1,
	"objective_completed": 2,
	"mission_completed": 5,
	"crew_member_saved": 3
}

var battle_outcome: int = BattleOutcome.DRAW
var enemy_count_defeated: int = 0
var objectives_completed: int = 0
var casualties_list: Array = []
var crew_casualties: Array = []
var crew_injuries: Dictionary = {}
var loot_found: Array = []
var story_points_earned: int = 0
var reputation_change: int = 0
var battle_data: Dictionary = {}

func _init() -> void:
	super()
	# Use the global GameDataManager singleton
	data_manager = load("res://src/core/managers/GameDataManager.gd").get_instance()
	GameDataManager.ensure_data_loaded()

func start_post_battle_phase(battle_data_param: Dictionary) -> void:
	super.start_post_battle_phase(battle_data_param)
	
	# Store the battle data for later use
	battle_data = battle_data_param
	
	# Process battle outcome
	if battle_data.has("outcome"):
		battle_outcome = battle_data.outcome
	else:
		battle_outcome = BattleOutcome.DRAW
	
	# Process enemy defeats
	if battle_data.has("enemies_defeated"):
		enemy_count_defeated = battle_data.enemies_defeated
	
	# Process objectives
	if battle_data.has("objectives_completed"):
		objectives_completed = battle_data.objectives_completed
	
	# Process casualties
	if battle_data.has("casualties"):
		_process_casualties(battle_data.casualties)
	
	# Calculate rewards
	_calculate_rewards()
	
	# Apply reputation changes
	if battle_outcome == BattleOutcome.VICTORY:
		reputation_change = 1
	elif battle_outcome == BattleOutcome.DEFEAT:
		reputation_change = -1
	
	# Emit signal that post-battle phase has started
	emit_signal("post_battle_phase_started")

func _calculate_rewards() -> void:
	# Calculate experience points
	var total_xp = 0
	
	# XP for defeated enemies
	total_xp += enemy_count_defeated * xp_values["enemy_defeated"]
	
	# XP for completed objectives
	total_xp += objectives_completed * xp_values["objective_completed"]
	
	# XP for mission completion
	if battle_outcome == BattleOutcome.VICTORY:
		total_xp += xp_values["mission_completed"]
	
	# Set the calculated rewards
	rewards = {
		"loot": loot_found,
		"experience": total_xp,
		"story_points": story_points_earned
	}

func _process_casualties(casualties: Array) -> void:
	for casualty in casualties:
		if not casualty is FiveParsecsCrewMember:
			continue
		
		var character = casualty as FiveParsecsCrewMember
		
		# Roll for casualty severity
		var severity_roll = randi() % 100 + 1
		
		if severity_roll < 10: # 10% chance of death
			crew_casualties.append(character)
		else:
			# Roll on the appropriate injury table
			var injury_roll = randi() % 100 + 1
			var table_name = "human_injury_table"
			
			if character.is_bot():
				table_name = "bot_injury_table"
			
			var injury_result = data_manager.get_injury_result(table_name, injury_roll)
			
			if injury_result.empty():
				push_error("Failed to get injury result for roll " + str(injury_roll))
				continue
			
			# Store the injury
			crew_injuries[character.get_instance_id()] = {
				"character": character,
				"injury": injury_result.name,
				"effects": injury_result.effects,
				"recovery_time": injury_result.recovery_time
			}
			
			# Apply injury effects
			_apply_injury_effects(character, injury_result)
	
	# Update the casualties list in the base class
	casualties_list = crew_casualties

func _apply_injury_effects(character: FiveParsecsCrewMember, injury_result: Dictionary) -> void:
	var injury_name = injury_result.name
	var effects = injury_result.effects
	var recovery_time = injury_result.get("recovery_time", injury_result.get("repair_time", 1))
	
	# Parse recovery time if it's a string like "1D3" campaign turns
	var recovery_days = 1
	if recovery_time is String:
		var regex = RegEx.new()
		regex.compile("(\\d+)D(\\d+)")
		var result = regex.search(recovery_time)
		if result:
			var dice_count = int(result.get_string(1))
			var dice_sides = int(result.get_string(2))
			
			# Roll the dice
			recovery_days = 0
			for i in range(dice_count):
				recovery_days += randi() % dice_sides + 1
	elif recovery_time is int:
		recovery_days = recovery_time
	
	# Apply status effect based on injury name and effects
	var status_effect = {
		"effect": "wounded",
		"duration": recovery_days
	}
	
	if "Character is dead" in str(effects) or "Bot is destroyed beyond repair" in str(effects):
		crew_casualties.append(character)
		crew_injuries.erase(character.get_instance_id())
		return
	
	if "Crippling wound" in injury_name or "Severe damage" in injury_name:
		status_effect.effect = "seriously_wounded"
	elif "Critical" in injury_name:
		status_effect.effect = "critically_wounded"
		
		# Apply permanent stat reduction if specified
		if "permanent reduction" in str(effects):
			var stats = ["speed", "combat", "toughness", "savvy"]
			var stat_to_reduce = stats[randi() % stats.size()]
			
			var current_value = character.get_stat(stat_to_reduce)
			if current_value > 1:
				character.set_stat(stat_to_reduce, current_value - 1)
	
	character.apply_status_effect(status_effect)

func complete_post_battle_phase() -> void:
	# Apply any final effects before completing the phase
	# Apply reputation changes if applicable
	if battle_data.has("crew") and battle_data.crew.size() > 0:
		var crew = battle_data.crew[0]
		if crew.has_method("adjust_reputation"):
			crew.adjust_reputation(reputation_change)
	
	# Emit signal that post-battle phase has completed
	emit_signal("post_battle_phase_completed", get_battle_summary())

func get_battle_summary() -> Dictionary:
	var summary = super.get_battle_summary()
	
	# Add Five Parsecs specific summary data
	summary["outcome"] = battle_outcome
	summary["enemies_defeated"] = enemy_count_defeated
	summary["objectives_completed"] = objectives_completed
	summary["casualties"] = crew_casualties.size()
	summary["injuries"] = crew_injuries.size()
	summary["loot"] = loot_found
	summary["story_points"] = story_points_earned
	summary["reputation_change"] = reputation_change
	
	return summary

func serialize() -> Dictionary:
	var data = super.serialize()
	
	# Add Five Parsecs specific data
	data["battle_outcome"] = battle_outcome
	data["enemy_count_defeated"] = enemy_count_defeated
	data["objectives_completed"] = objectives_completed
	data["story_points_earned"] = story_points_earned
	data["reputation_change"] = reputation_change
	
	# Serialize loot
	data["loot_found"] = loot_found
	
	# Serialize casualties (just IDs)
	var casualty_ids = []
	for casualty in crew_casualties:
		casualty_ids.append(casualty.get_instance_id())
	data["crew_casualties"] = casualty_ids
	
	# Serialize injuries (simplified)
	var injury_data = {}
	for id in crew_injuries:
		injury_data[id] = {
			"injury": crew_injuries[id].injury,
			"recovery_time": crew_injuries[id].recovery_time
		}
	data["crew_injuries"] = injury_data
	
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	
	# Restore Five Parsecs specific data
	battle_outcome = data.get("battle_outcome", BattleOutcome.DRAW)
	enemy_count_defeated = data.get("enemy_count_defeated", 0)
	objectives_completed = data.get("objectives_completed", 0)
	story_points_earned = data.get("story_points_earned", 0)
	reputation_change = data.get("reputation_change", 0)
	
	# Restore loot
	loot_found = data.get("loot_found", [])
	
	# Note: Casualties and injuries would need to be restored by the system
	# that manages the crew members, as we need the actual references to the
	# crew member objects, not just their IDs 