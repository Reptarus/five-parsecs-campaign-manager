class_name FPCM_DeploymentConditionsSystem
extends Resource

## Deployment Conditions System implementing Five Parsecs Core Rules
##
## Handles pre-battle deployment conditions that affect how battles start.
## Different conditions apply based on mission type (Opportunity, Patron, Rival, Quest).
##
## Reference: Core Rules p.94 "Determine Deployment Conditions"

# Signals
signal condition_rolled(condition: DeploymentCondition)
signal condition_applied(condition_id: String, effects: Dictionary)

# Deployment Condition Resource Class
class DeploymentCondition extends Resource:
	@export var condition_id: String = ""
	@export var title: String = ""
	@export var description: String = ""
	@export var effects: Dictionary = {}
	@export var roll_ranges: Dictionary = {} # mission_type -> [min, max]

	func applies_to_roll(roll: int, mission_type: String) -> bool:
		if not roll_ranges.has(mission_type):
			return false
		var range_arr: Array = roll_ranges[mission_type]
		return roll >= range_arr[0] and roll <= range_arr[1]

# Mission types for condition lookup
enum MissionType {
	OPPORTUNITY,
	PATRON,
	RIVAL,
	QUEST
}

# Condition registry
var condition_registry: Array[DeploymentCondition] = []

func _init() -> void:
	_initialize_condition_registry()

## Roll for deployment condition based on mission type
func roll_deployment_condition(mission_type: MissionType) -> DeploymentCondition:
	var roll := randi_range(1, 100)
	var type_key := _mission_type_to_key(mission_type)

	for condition in condition_registry:
		if condition.applies_to_roll(roll, type_key):
			condition_rolled.emit(condition)
			return condition

	# Default to no condition
	return condition_registry[0] if condition_registry.size() > 0 else null

## Get condition for specific roll and mission type
func get_condition_for_roll(roll: int, mission_type: MissionType) -> DeploymentCondition:
	var type_key := _mission_type_to_key(mission_type)

	for condition in condition_registry:
		if condition.applies_to_roll(roll, type_key):
			return condition

	return null

## Apply condition effects to battle state
func apply_condition(condition: DeploymentCondition, battle_state: Dictionary) -> Dictionary:
	if not condition:
		return battle_state

	var modified_state := battle_state.duplicate(true)

	match condition.condition_id:
		"NO_CONDITION":
			pass # No modifications

		"SMALL_ENCOUNTER":
			# Random crew sits out, reduce enemy numbers
			modified_state["crew_sits_out"] = 1
			var enemy_count: int = modified_state.get("enemy_count", 0)
			var crew_count: int = modified_state.get("crew_count", 0)
			if enemy_count > crew_count:
				modified_state["enemy_count"] = enemy_count - 2
			else:
				modified_state["enemy_count"] = enemy_count - 1

		"POOR_VISIBILITY":
			# Maximum visibility 1D6+8", reroll each round
			modified_state["visibility_limit"] = randi_range(1, 6) + 8
			modified_state["visibility_reroll"] = true

		"BRIEF_ENGAGEMENT":
			# End check: 2D6 <= round number
			modified_state["brief_engagement"] = true

		"TOXIC_ENVIRONMENT":
			# Stun -> casualty on failed 4+ save
			modified_state["toxic_environment"] = true
			modified_state["stun_save_required"] = 4

		"SURPRISE_ENCOUNTER":
			# Enemy can't act round 1
			modified_state["enemy_skip_round_1"] = true

		"DELAYED":
			# 2 crew start off table, arrive on roll <= round
			modified_state["delayed_crew"] = 2

		"SLIPPERY_GROUND":
			# -1 Speed at ground level
			modified_state["speed_modifier"] = -1
			modified_state["ground_level_only"] = true

		"BITTER_STRUGGLE":
			# Enemy Morale +1
			modified_state["enemy_morale_bonus"] = 1

		"CAUGHT_OFF_GUARD":
			# All crew act Slow in round 1
			modified_state["crew_slow_round_1"] = true

		"GLOOMY":
			# Max visibility 9", but firers can be targeted at any range
			modified_state["visibility_limit"] = 9
			modified_state["firers_targetable_any_range"] = true

	condition_applied.emit(condition.condition_id, modified_state)
	return modified_state

## Get all conditions for display
func get_all_conditions() -> Array[DeploymentCondition]:
	return condition_registry

## Get condition by ID
func get_condition_by_id(condition_id: String) -> DeploymentCondition:
	for condition in condition_registry:
		if condition.condition_id == condition_id:
			return condition
	return null

func _mission_type_to_key(mission_type: MissionType) -> String:
	match mission_type:
		MissionType.OPPORTUNITY: return "opportunity"
		MissionType.PATRON: return "patron"
		MissionType.RIVAL: return "rival"
		MissionType.QUEST: return "quest"
		_: return "opportunity"

## Initialize the complete deployment conditions registry
func _initialize_condition_registry() -> void:
	condition_registry.clear()

	# Try loading from JSON first
	var dm = Engine.get_main_loop().root.get_node_or_null("/root/DataManager") if Engine.get_main_loop() else null
	var json_data: Dictionary = {}
	if dm and dm.has_method("load_json_file"):
		json_data = dm.load_json_file("res://data/deployment_conditions.json")

	var conditions_arr: Array = json_data.get("conditions", [])
	if not conditions_arr.is_empty():
		for cond_data in conditions_arr:
			var condition := DeploymentCondition.new()
			condition.condition_id = cond_data.get("id", "")
			condition.title = cond_data.get("name", "")
			condition.description = cond_data.get("description", "")
			condition.effects = cond_data.get("effects", {})
			condition.roll_ranges = cond_data.get("roll_ranges", {})
			condition_registry.append(condition)
		return

	# Fallback to hardcoded data
	push_warning("DeploymentConditionsSystem: Failed to load JSON, using hardcoded fallback")
	_initialize_condition_registry_fallback()

func _initialize_condition_registry_fallback() -> void:
	# No Condition
	var no_condition := DeploymentCondition.new()
	no_condition.condition_id = "NO_CONDITION"
	no_condition.title = "No Condition"
	no_condition.description = "Normal deployment with no special conditions."
	no_condition.roll_ranges = {
		"opportunity": [1, 40],
		"patron": [1, 40],
		"rival": [1, 10],
		"quest": [1, 5]
	}
	condition_registry.append(no_condition)

	# Small Encounter
	var small_encounter := DeploymentCondition.new()
	small_encounter.condition_id = "SMALL_ENCOUNTER"
	small_encounter.title = "Small Encounter"
	small_encounter.description = "A random crew member must sit out this fight. Reduce enemy numbers by -1 (-2 if they initially outnumber you)."
	small_encounter.roll_ranges = {
		"opportunity": [41, 45],
		"patron": [41, 45],
		"rival": [11, 15],
		"quest": [6, 10]
	}
	small_encounter.effects = {"crew_sits_out": 1, "enemy_reduction": -1, "enemy_reduction_if_outnumbered": -2}
	condition_registry.append(small_encounter)

	# Poor Visibility
	var poor_visibility := DeploymentCondition.new()
	poor_visibility.condition_id = "POOR_VISIBILITY"
	poor_visibility.title = "Poor Visibility"
	poor_visibility.description = "Maximum visibility is 1D6+8\". Reroll at the start of each round."
	poor_visibility.roll_ranges = {
		"opportunity": [46, 50],
		"patron": [46, 50],
		"rival": [16, 20],
		"quest": [11, 25]
	}
	poor_visibility.effects = {"visibility_formula": "1d6+8", "reroll_each_round": true}
	condition_registry.append(poor_visibility)

	# Brief Engagement
	var brief_engagement := DeploymentCondition.new()
	brief_engagement.condition_id = "BRIEF_ENGAGEMENT"
	brief_engagement.title = "Brief Engagement"
	brief_engagement.description = "At the end of each round, roll 2D6. If the roll is equal or below the round number, the game ends inconclusively."
	brief_engagement.roll_ranges = {
		"opportunity": [51, 55],
		"patron": [51, 55],
		"rival": [21, 25],
		"quest": [26, 30]
	}
	brief_engagement.effects = {"end_check": "2d6_vs_round", "inconclusive_end": true}
	condition_registry.append(brief_engagement)

	# Toxic Environment
	var toxic_environment := DeploymentCondition.new()
	toxic_environment.condition_id = "TOXIC_ENVIRONMENT"
	toxic_environment.title = "Toxic Environment"
	toxic_environment.description = "Whenever a combatant is Stunned, roll 1D6+Savvy skill (0 for enemies). Failure to roll a 4+ becomes a casualty."
	toxic_environment.roll_ranges = {
		"opportunity": [56, 60],
		"patron": [56, 60],
		"rival": [26, 30],
		"quest": [31, 40]
	}
	toxic_environment.effects = {"stun_save": "1d6+savvy", "save_target": 4, "failure_result": "casualty"}
	condition_registry.append(toxic_environment)

	# Surprise Encounter
	var surprise_encounter := DeploymentCondition.new()
	surprise_encounter.condition_id = "SURPRISE_ENCOUNTER"
	surprise_encounter.title = "Surprise Encounter"
	surprise_encounter.description = "The enemy can't act in the first round."
	surprise_encounter.roll_ranges = {
		"opportunity": [61, 65],
		"patron": [61, 65],
		"rival": [31, 45],
		"quest": [41, 50]
	}
	surprise_encounter.effects = {"enemy_skip_round": 1}
	condition_registry.append(surprise_encounter)

	# Delayed
	var delayed := DeploymentCondition.new()
	delayed.condition_id = "DELAYED"
	delayed.title = "Delayed"
	delayed.description = "2 random crew members won't start on the table. At the end of each round, roll 1D6: If the roll is equal or below the round number, they may be placed at any point of your own battlefield edge."
	delayed.roll_ranges = {
		"opportunity": [66, 75],
		"patron": [66, 75],
		"rival": [46, 50],
		"quest": [51, 60]
	}
	delayed.effects = {"delayed_crew": 2, "arrival_check": "1d6_vs_round", "arrival_location": "own_edge"}
	condition_registry.append(delayed)

	# Slippery Ground
	var slippery_ground := DeploymentCondition.new()
	slippery_ground.condition_id = "SLIPPERY_GROUND"
	slippery_ground.title = "Slippery Ground"
	slippery_ground.description = "All movement at ground level is -1 Speed."
	slippery_ground.roll_ranges = {
		"opportunity": [76, 80],
		"patron": [76, 80],
		"rival": [51, 60],
		"quest": [61, 65]
	}
	slippery_ground.effects = {"speed_modifier": -1, "affects": "ground_level"}
	condition_registry.append(slippery_ground)

	# Bitter Struggle
	var bitter_struggle := DeploymentCondition.new()
	bitter_struggle.condition_id = "BITTER_STRUGGLE"
	bitter_struggle.title = "Bitter Struggle"
	bitter_struggle.description = "Enemy Morale is +1."
	bitter_struggle.roll_ranges = {
		"opportunity": [81, 85],
		"patron": [81, 85],
		"rival": [61, 75],
		"quest": [66, 80]
	}
	bitter_struggle.effects = {"enemy_morale_modifier": 1}
	condition_registry.append(bitter_struggle)

	# Caught Off Guard
	var caught_off_guard := DeploymentCondition.new()
	caught_off_guard.condition_id = "CAUGHT_OFF_GUARD"
	caught_off_guard.title = "Caught Off Guard"
	caught_off_guard.description = "Your squad all act in the Slow Actions phase in Round 1."
	caught_off_guard.roll_ranges = {
		"opportunity": [86, 90],
		"patron": [86, 90],
		"rival": [76, 90],
		"quest": [81, 90]
	}
	caught_off_guard.effects = {"crew_phase_round_1": "slow"}
	condition_registry.append(caught_off_guard)

	# Gloomy
	var gloomy := DeploymentCondition.new()
	gloomy.condition_id = "GLOOMY"
	gloomy.title = "Gloomy"
	gloomy.description = "Maximum visibility is 9\". Characters that fire can be fired upon at any range, however."
	gloomy.roll_ranges = {
		"opportunity": [91, 100],
		"patron": [91, 100],
		"rival": [91, 100],
		"quest": [91, 100]
	}
	gloomy.effects = {"visibility_limit": 9, "firers_targetable_any_range": true}
	condition_registry.append(gloomy)

## Get human-readable description of condition effects for UI
func get_condition_effects_summary(condition: DeploymentCondition) -> String:
	if not condition:
		return ""

	var summary_parts: Array[String] = []

	match condition.condition_id:
		"NO_CONDITION":
			return "No special effects"
		"SMALL_ENCOUNTER":
			summary_parts.append("• 1 random crew member sits out")
			summary_parts.append("• Enemy count -1 (or -2 if outnumbered)")
		"POOR_VISIBILITY":
			summary_parts.append("• Max visibility: 1D6+8\"")
			summary_parts.append("• Reroll each round")
		"BRIEF_ENGAGEMENT":
			summary_parts.append("• End of round: Roll 2D6")
			summary_parts.append("• Game ends if roll ≤ round number")
		"TOXIC_ENVIRONMENT":
			summary_parts.append("• Stunned units roll 1D6+Savvy")
			summary_parts.append("• Fail 4+ = casualty")
		"SURPRISE_ENCOUNTER":
			summary_parts.append("• Enemy cannot act in Round 1")
		"DELAYED":
			summary_parts.append("• 2 crew start off-table")
			summary_parts.append("• Arrive when 1D6 ≤ round number")
		"SLIPPERY_GROUND":
			summary_parts.append("• -1 Speed at ground level")
		"BITTER_STRUGGLE":
			summary_parts.append("• Enemy Morale +1")
		"CAUGHT_OFF_GUARD":
			summary_parts.append("• All crew act Slow in Round 1")
		"GLOOMY":
			summary_parts.append("• Max visibility: 9\"")
			summary_parts.append("• Firers targetable at any range")

	return "\n".join(summary_parts)
