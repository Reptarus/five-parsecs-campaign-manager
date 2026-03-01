class_name FPCM_MissionObjectiveSystem
extends Resource

## Mission Objective System implementing Five Parsecs Core Rules
##
## Generates and tracks battle objectives based on mission type.
## Each objective has specific victory conditions and placement rules.
##
## Reference: Core Rules Battle Objectives

# Objective data class
class Objective extends Resource:
	@export var objective_id: String = ""
	@export var name: String = ""
	@export var description: String = ""
	@export var victory_condition: String = ""
	@export var placement_rules: String = ""
	@export var optional_rewards: Array[String] = []
	@export var roll_ranges: Dictionary = {}  # mission_type -> [min, max]

	func applies_to_roll(roll: int, mission_type: String) -> bool:
		if not roll_ranges.has(mission_type):
			return false
		var range_arr: Array = roll_ranges[mission_type]
		return roll >= range_arr[0] and roll <= range_arr[1]

# Signals
signal objective_rolled(objective: Objective)
signal objective_completed(objective_id: String, success: bool)

# Objective registry
var objective_registry: Array[Objective] = []

# State
var current_objective: Objective
var objective_progress: Dictionary = {}

func _init() -> void:
	_initialize_objective_registry()

## Roll battle objective based on mission type
func roll_objective(mission_type: String) -> Objective:
	var roll := randi_range(1, 100)
	return get_objective_for_roll(roll, mission_type)

## Get objective for specific roll
func get_objective_for_roll(roll: int, mission_type: String) -> Objective:
	var type_key := mission_type.to_lower().replace(" ", "_")

	for objective in objective_registry:
		if objective.applies_to_roll(roll, type_key):
			current_objective = objective
			objective_rolled.emit(objective)
			return objective

	# Default to Fight Off
	return objective_registry[0] if objective_registry.size() > 0 else null

## Get all objectives
func get_all_objectives() -> Array[Objective]:
	return objective_registry

## Get objective by ID
func get_objective_by_id(objective_id: String) -> Objective:
	for objective in objective_registry:
		if objective.objective_id == objective_id:
			return objective
	return null

## Update objective progress
func update_progress(key: String, value: Variant) -> void:
	objective_progress[key] = value

## Check if current objective is complete
func check_completion() -> bool:
	if not current_objective:
		return false

	# Check based on objective type
	match current_objective.objective_id:
		"FIGHT_OFF":
			return objective_progress.get("enemies_remaining", 1) <= 0 or objective_progress.get("enemies_fled", false)
		"ACQUIRE":
			return objective_progress.get("item_secured", false) and objective_progress.get("exited_with_item", false)
		"MOVE_THROUGH":
			return objective_progress.get("crew_exited", 0) >= 3
		"PATROL":
			return objective_progress.get("markers_checked", 0) >= 4
		"DEFEND":
			return objective_progress.get("objective_intact", true) and objective_progress.get("rounds_survived", 0) >= 6
		"SEARCH":
			return objective_progress.get("item_found", false)
		"PROTECT":
			return objective_progress.get("vip_alive", true) and objective_progress.get("battle_won", false)
		"DELIVER":
			return objective_progress.get("delivered", false)

	return false

func _initialize_objective_registry() -> void:
	objective_registry.clear()

	# Try JSON first
	var dm = Engine.get_main_loop().root.get_node_or_null("/root/DataManager") if Engine.get_main_loop() else null
	if dm and dm.has_method("load_json_file"):
		var json_data: Dictionary = dm.load_json_file("res://data/mission_tables/mission_objectives.json")
		var entries: Array = json_data.get("entries", [])
		if not entries.is_empty():
			for entry in entries:
				var result: Dictionary = entry.get("result", {})
				var obj := Objective.new()
				obj.objective_id = result.get("type", "")
				obj.name = result.get("name", "")
				obj.description = result.get("description", "")
				obj.victory_condition = result.get("victory_condition", "")
				obj.placement_rules = result.get("placement_rules", "")
				obj.roll_ranges = {"default": entry.get("roll_range", [1, 100])}
				objective_registry.append(obj)
			print("MissionObjectiveSystem: Loaded %d objectives from JSON" % objective_registry.size())
			return

	# Fallback to hardcoded data (has richer per-mission-type roll ranges)
	_initialize_objective_registry_hardcoded()

func _initialize_objective_registry_hardcoded() -> void:
	# FIGHT OFF
	var fight_off := Objective.new()
	fight_off.objective_id = "FIGHT_OFF"
	fight_off.name = "Fight Off"
	fight_off.description = "Standard engagement. Drive off or eliminate all enemies."
	fight_off.victory_condition = "Win if all enemies are driven off the battlefield or eliminated. Lose if your crew must retreat."
	fight_off.placement_rules = "Standard deployment zones on opposite edges."
	fight_off.roll_ranges = {
		"opportunity": [1, 25], "patrol": [1, 30], "investigate": [1, 20],
		"hunt": [1, 15], "bounty": [1, 20], "guard": [1, 15],
		"defend": [1, 10], "deliver": [1, 25], "explore": [1, 20]
	}
	objective_registry.append(fight_off)

	# ACQUIRE
	var acquire := Objective.new()
	acquire.objective_id = "ACQUIRE"
	acquire.name = "Acquire"
	acquire.description = "Grab an item and escape with it."
	acquire.victory_condition = "A crew member must reach the item (center of table), pick it up (1 action), and exit from your table edge."
	acquire.placement_rules = "Place objective marker at table center. Standard deployment."
	acquire.optional_rewards = ["Bonus credits if no casualties"]
	acquire.roll_ranges = {
		"opportunity": [26, 40], "patrol": [31, 45], "investigate": [21, 45],
		"hunt": [16, 30], "bounty": [21, 35], "guard": [16, 25],
		"deliver": [26, 40], "explore": [21, 40]
	}
	objective_registry.append(acquire)

	# MOVE THROUGH
	var move_through := Objective.new()
	move_through.objective_id = "MOVE_THROUGH"
	move_through.name = "Move Through"
	move_through.description = "Push through enemy territory."
	move_through.victory_condition = "At least 3 crew members must exit from the opposite table edge."
	move_through.placement_rules = "Deploy on one edge, must reach opposite edge."
	move_through.roll_ranges = {
		"opportunity": [41, 55], "patrol": [46, 60], "investigate": [46, 55],
		"hunt": [31, 45], "bounty": [36, 50], "deliver": [41, 60],
		"explore": [41, 55]
	}
	objective_registry.append(move_through)

	# PATROL
	var patrol := Objective.new()
	patrol.objective_id = "PATROL"
	patrol.name = "Patrol"
	patrol.description = "Sweep the area and check all patrol markers."
	patrol.victory_condition = "Check all 4 patrol markers (move within 3\", spend 1 action). Can be done by any crew member."
	patrol.placement_rules = "Place 4 markers in each table quarter. Standard deployment."
	patrol.roll_ranges = {
		"opportunity": [56, 70], "patrol": [61, 80], "investigate": [56, 70],
		"explore": [56, 70]
	}
	objective_registry.append(patrol)

	# DEFEND
	var defend := Objective.new()
	defend.objective_id = "DEFEND"
	defend.name = "Defend"
	defend.description = "Hold your ground and protect a location."
	defend.victory_condition = "Survive 6 rounds with at least one crew within 6\" of the objective. Enemies must not hold it."
	defend.placement_rules = "Place objective 12\" from your edge. You deploy first within 6\" of objective."
	defend.roll_ranges = {
		"opportunity": [71, 80], "guard": [26, 50], "defend": [11, 60]
	}
	objective_registry.append(defend)

	# SEARCH
	var search := Objective.new()
	search.objective_id = "SEARCH"
	search.name = "Search"
	search.description = "Find a specific item among several possibilities."
	search.victory_condition = "Place 3 markers. Check each (1 action within 1\"). Roll D6: 1-2 nothing, 3-4 encounter, 5-6 item found. Must find and exit."
	search.placement_rules = "Place 3 search markers in enemy half of table."
	search.roll_ranges = {
		"investigate": [71, 85], "hunt": [46, 65], "explore": [71, 85]
	}
	objective_registry.append(search)

	# PROTECT
	var protect := Objective.new()
	protect.objective_id = "PROTECT"
	protect.name = "Protect"
	protect.description = "Keep a VIP alive during the battle."
	protect.victory_condition = "The VIP must survive. They follow a random crew member and cannot fight. If killed, mission fails."
	protect.placement_rules = "VIP deploys with your crew. Has Toughness 3, no combat ability."
	protect.roll_ranges = {
		"guard": [51, 80], "defend": [61, 85], "bounty": [51, 70]
	}
	objective_registry.append(protect)

	# DELIVER
	var deliver := Objective.new()
	deliver.objective_id = "DELIVER"
	deliver.name = "Deliver"
	deliver.description = "Transport an item to a drop point."
	deliver.victory_condition = "One crew member starts with the item. Must reach the drop point (opposite edge center) and spend 1 action to deliver."
	deliver.placement_rules = "Assign one crew the delivery item. Mark drop point on opposite edge center."
	deliver.roll_ranges = {
		"deliver": [61, 100], "hunt": [66, 80]
	}
	objective_registry.append(deliver)

	# AMBUSH
	var ambush := Objective.new()
	ambush.objective_id = "AMBUSH"
	ambush.name = "Ambush"
	ambush.description = "Enemy has sprung a trap!"
	ambush.victory_condition = "Survive and eliminate threats. You deploy in center, enemies on all edges."
	ambush.placement_rules = "Deploy your crew within 6\" of table center. Enemies deploy on all four edges."
	ambush.roll_ranges = {
		"opportunity": [81, 90], "hunt": [81, 90], "bounty": [71, 85]
	}
	objective_registry.append(ambush)

	# ESCAPE
	var escape := Objective.new()
	escape.objective_id = "ESCAPE"
	escape.name = "Escape"
	escape.description = "Get your crew off the battlefield!"
	escape.victory_condition = "At least half your crew must exit from your deployment edge. Anyone left behind is captured."
	escape.placement_rules = "You deploy first. Enemies deploy on opposite edge and flanks."
	escape.roll_ranges = {
		"opportunity": [91, 100], "patrol": [81, 100], "investigate": [86, 100],
		"hunt": [91, 100], "bounty": [86, 100], "guard": [81, 100],
		"defend": [86, 100], "explore": [86, 100]
	}
	objective_registry.append(escape)
