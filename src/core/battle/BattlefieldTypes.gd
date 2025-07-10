class_name FPCM_BattlefieldTypes
extends Resource

## Battlefield Companion Data Types
##
## Centralized type definitions for the streamlined battlefield companion system.
## These lightweight structures replace heavy object hierarchies for better performance
## and maintainability while maintaining Five Parsecs rule compliance.

# Dependencies
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

## Battle Phase enumeration for companion workflow
enum BattlePhase {
	SETUP_TERRAIN, ## Generate battlefield suggestions per rulebook
	SETUP_DEPLOYMENT, ## Show deployment zones and unit placement
	TRACK_BATTLE, ## Track units during tabletop play
	PREPARE_RESULTS ## Process battle end and transition to post-battle
}

## Terrain Feature Resource Class
class TerrainFeature extends Resource:
	@export var feature_id: String = ""
	@export var feature_type: StringName = &"" # Using StringName for performance
	@export var title: String = ""
	@export var description: String = ""
	@export var placement_suggestion: String = ""
	@export var positions: Array[Vector2i] = []
	@export var properties: Dictionary = {}
	@export var cover_value: int = 0
	@export var movement_modifier: float = 1.0
	@export var special_rules: Array[String] = []

	func setup_cover_feature() -> void:
		feature_type = &"cover"
		title = "Cover Feature"
		description = "Wall, rocks, or debris providing cover"
		placement_suggestion = "3-unit line or L-shape placement"
		cover_value = 2
		properties = {"blocks_los": true, "cover_bonus": 2}

	func setup_elevation_feature() -> void:
		feature_type = &"elevation"
		title = "Elevation"
		description = "Hill, platform, or raised area"
		placement_suggestion = "2x2 area, +1 height advantage"
		properties = {"height": 1, "los_bonus": true}

	func setup_difficult_terrain() -> void:
		feature_type = &"difficult"
		title = "Difficult Terrain"
		description = "Rough ground, debris, or mud"
		placement_suggestion = "2x2 area of rough terrain"
		movement_modifier = 0.5
		properties = {"movement_cost": 2}

	func setup_special_feature() -> void:
		feature_type = &"special"
		title = "Mission Feature"
		description = "Mission-specific terrain element"
		placement_suggestion = "See mission rules for placement"
		properties = {"mission_specific": true}

## FPCM Objective Marker Resource Class
class FPCM_ObjectiveMarker extends Resource:
	@export var objective_id: String = ""
	@export var objective_type: StringName = &""
	@export var node_position: Vector2i = Vector2i(-1, -1)
	@export var title: String = ""
	@export var description: String = ""
	@export var victory_points: int = 0
	@export var completion_requirements: Dictionary = {}
	@export var special_rules: Array[String] = []

	func setup_secure_objective() -> void:
		objective_type = &"secure"
		title = "Secure Position"
		description = "Control this position for victory"
		victory_points = 1
		completion_requirements = {"control_distance": 1, "turns_required": 1}

	func setup_destroy_objective() -> void:
		objective_type = &"destroy"
		title = "Destroy Target"
		description = "Eliminate this target"
		victory_points = 2
		completion_requirements = {"requires_action": true, "target_health": 1}

	func setup_investigate_objective() -> void:
		objective_type = &"investigate"
		title = "Investigation Point"
		description = "Search this location for clues"
		victory_points = 1
		completion_requirements = {"requires_action": true, "search_roll": 4}

## Unit Data Resource Class - Lightweight tracking for tabletop assistance
class UnitData extends Resource:
	@export var unit_id: String = ""
	@export var unit_name: String = ""
	@export var team: StringName = &"" # "crew" or "enemy"
	@export var max_health: int = 3
	@export var current_health: int = 3
	@export var node_position: Vector2i = Vector2i(-1, -1)
	@export var status_effects: Array[String] = []
	@export var activated_this_round: bool = false
	@export var equipment: Array[String] = []
	@export var notes: String = ""

	# Combat stats for reference (not used in companion tracking)
	@export var combat_skill: int = 0
	@export var toughness: int = 0
	@export var savvy: int = 0
	@export var reactions: int = 0

	# Reference to original character data
	@export var original_character: Resource = null

	func initialize_from_crew_member(crew_member: Resource) -> void:
		"""Initialize unit from crew member data"""
		if not crew_member:
			push_error("BattlefieldTypes: Invalid crew member data")
			return

		original_character = crew_member

		# Extract character name safely
		var name_value = null
		if crew_member and crew_member.has_method("get"):
			name_value = crew_member.get("character_name")
		unit_name = str(name_value) if name_value != null else "Unknown Crew"
		team = &"crew"

		# Extract stats safely with fallbacks
		var combat_value = null
		if crew_member and crew_member.has_method("get"):
			combat_value = crew_member.get("combat_skill")
		combat_skill = int(combat_value) if combat_value != null else 0

		var tough_value = null
		if crew_member and crew_member.has_method("get"):
			tough_value = crew_member.get("toughness")
		toughness = int(tough_value) if tough_value != null else 0

		var savvy_value = null
		if crew_member and crew_member.has_method("get"):
			savvy_value = crew_member.get("savvy")
		savvy = int(savvy_value) if savvy_value != null else 0

		var reactions_value = null
		if crew_member and crew_member.has_method("get"):
			reactions_value = crew_member.get("reactions")
		reactions = int(reactions_value) if reactions_value != null else 0

		# Set health based on toughness (Five Parsecs rule)
		max_health = max(1, toughness + 2)
		current_health = max_health

		# Generate unique ID
		unit_id = "crew_%s_%d" % [unit_name.replace(" ", "_"), Time.get_unix_time_from_system()]

	func initialize_from_enemy(enemy_data: Resource) -> void:
		"""Initialize unit from enemy data"""
		if not enemy_data:
			push_error("BattlefieldTypes: Invalid enemy data")
			return

		original_character = enemy_data

		# Extract enemy name safely
		var name_value = null
		if enemy_data and enemy_data.has_method("get"):
			name_value = enemy_data.get("name")
		unit_name = str(name_value) if name_value != null else "Unknown Enemy"
		team = &"enemy"

		# Extract enemy stats safely
		var combat_value = null
		if enemy_data and enemy_data.has_method("get"):
			combat_value = enemy_data.get("combat_skill")
		combat_skill = int(combat_value) if combat_value != null else 0

		var tough_value = null
		if enemy_data and enemy_data.has_method("get"):
			tough_value = enemy_data.get("toughness")
		toughness = int(tough_value) if tough_value != null else 0

		var reactions_value = null
		if enemy_data and enemy_data.has_method("get"):
			reactions_value = enemy_data.get("reactions")
		reactions = int(reactions_value) if reactions_value != null else 0

		# Set health safely
		var health_value = null
		if enemy_data and enemy_data.has_method("get"):
			health_value = enemy_data.get("health")
		var health_int = int(health_value) if health_value != null else toughness
		max_health = max(1, health_int)
		current_health = max_health

		# Generate unique ID
		unit_id = "enemy_%s_%d" % [unit_name.replace(" ", "_"), Time.get_unix_time_from_system()]

	func apply_damage(amount: int) -> bool:
		"""Apply damage and return true if unit is defeated"""
		current_health = max(0, current_health - amount)
		return current_health <= 0

	func heal_damage(amount: int) -> void:
		"""Heal damage up to maximum"""
		current_health = min(max_health, current_health + amount)

	func add_status_effect(effect: String) -> void:
		"""Add status effect if not already present"""
		if effect not in status_effects:
			status_effects.append(effect)

	func remove_status_effect(effect: String) -> void:
		"""Remove status effect"""
		status_effects.erase(effect)

	func is_alive() -> bool:
		"""Check if unit is still alive"""
		return current_health > 0

	func can_act() -> bool:
		"""Check if unit can take actions"""
		return is_alive() and not activated_this_round

	func to_dict() -> Dictionary:
		"""Convert to dictionary for serialization"""
		return {
			"unit_id": unit_id,
			"unit_name": unit_name,
			"team": String(team),
			"max_health": max_health,
			"current_health": current_health,
			"position": {"x": node_position.x, "y": node_position.y},
			"status_effects": status_effects.duplicate(),
			"activated_this_round": activated_this_round,
			"equipment": equipment.duplicate(),
			"notes": notes
		}

## Battlefield Data Resource Class - Complete battlefield state
class BattlefieldData extends Resource:
	@export var battlefield_id: String = ""
	@export var battlefield_size: Vector2i = Vector2i(20, 20)
	@export var terrain_features: Array[TerrainFeature] = []
	@export var objectives: Array[FPCM_ObjectiveMarker] = []
	@export var crew_deployment_zone: Array[Vector2i] = []
	@export var enemy_deployment_zone: Array[Vector2i] = []
	@export var special_rules: Array[String] = []
	@export var environmental_effects: Dictionary = {}
	@export var mission_data: Resource = null

	func generate_standard_deployment_zones() -> void:
		"""Generate standard deployment zones per Five Parsecs rules"""
		crew_deployment_zone.clear()
		enemy_deployment_zone.clear()

		# Crew deploys on western side (left 4 columns)
		for x: int in range(0, 4):
			for y: int in range(battlefield_size.y):
				crew_deployment_zone.append(Vector2i(x, y))

		# Enemies deploy on eastern side (right 4 columns)
		for x: int in range(battlefield_size.x - 4, battlefield_size.x):
			for y: int in range(battlefield_size.y):
				enemy_deployment_zone.append(Vector2i(x, y))

	func add_terrain_feature(feature: TerrainFeature) -> void:
		"""Add terrain feature with validation"""
		if not feature:
			push_error("BattlefieldData: Cannot add null terrain feature")
			return

		terrain_features.append(feature)

	func add_objective(objective: FPCM_BattlefieldTypes.FPCM_ObjectiveMarker) -> void:
		"""Add objective marker with validation"""
		if not objective:
			push_error("BattlefieldData: Cannot add null objective")
			return

		objectives.append(objective)

	func clear_battlefield() -> void:
		"""Clear all battlefield data"""
		terrain_features.clear()
		objectives.clear()
		crew_deployment_zone.clear()
		enemy_deployment_zone.clear()
		special_rules.clear()
		environmental_effects.clear()

## Battle Results Resource Class - Results processing for post-battle
class BattleResults extends Resource:
	@export var battle_id: String = ""
	@export var victory: bool = false
	@export var rounds_fought: int = 0
	@export var casualties: Array[Dictionary] = []
	@export var injuries: Array[Dictionary] = []
	@export var experience_gained: Dictionary = {}
	@export var loot_opportunities: Array[String] = []
	@export var battle_events: Array[String] = []
	@export var mission_objectives_completed: Array[String] = []
	@export var post_battle_notes: String = ""

	func add_casualty(unit_name: String, casualty_type: String = "killed_in_action") -> void:
		"""Add casualty record"""
		casualties.append({
			"name": unit_name,
			"type": casualty_type,
			"round": rounds_fought
		})

	func add_injury(unit_name: String, injury_type: String, recovery_time: int = 1) -> void:
		"""Add injury record"""
		injuries.append({
			"name": unit_name,
			"injury": injury_type,
			"recovery_rounds": recovery_time,
			"sustained_round": rounds_fought
		})

	func add_loot_opportunity(loot_description: String) -> void:
		"""Add loot opportunity"""
		if loot_description not in loot_opportunities:
			loot_opportunities.append(loot_description)

	func set_experience_gained(crew_member: String, amount: int) -> void:
		"""Set experience gained for crew member"""
		experience_gained[crew_member] = amount

	func to_dict() -> Dictionary:
		"""Convert to dictionary for serialization"""
		return {
			"battle_id": battle_id,
			"victory": victory,
			"rounds_fought": rounds_fought,
			"casualties": casualties.duplicate(),
			"injuries": injuries.duplicate(),
			"experience_gained": experience_gained.duplicate(),
			"loot_opportunities": loot_opportunities.duplicate(),
			"battle_events": battle_events.duplicate(),
			"mission_objectives_completed": mission_objectives_completed.duplicate(),
			"post_battle_notes": post_battle_notes
		}

## Battle Event Data Resource Class - For random events during battle
class BattleEventData extends Resource:
	@export var event_id: String = ""
	@export var event_text: String = ""
	@export var round_triggered: int = 0
	@export var affects_crew: bool = false
	@export var affects_enemies: bool = false
	@export var affects_battlefield: bool = false
	@export var duration_rounds: int = 0 # 0 = instant
	@export var special_instructions: String = ""

	func setup_environmental_event() -> void:
		"""Setup environmental hazard event"""
		affects_battlefield = true
		duration_rounds = 0
		special_instructions = "Check terrain effects immediately"

	func setup_reinforcement_event() -> void:
		"""Setup potential reinforcement event"""
		affects_enemies = true
		duration_rounds = 0
		special_instructions = "Roll for reinforcement arrival"

	func setup_morale_event() -> void:
		"""Setup morale check event"""
		affects_crew = true
		affects_enemies = true
		duration_rounds = 0
		special_instructions = "All units make morale check"

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_get_property(obj: Object, property: String, default_value: Variant = null) -> Variant:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(obj):
		return default_value

	if obj and obj.has_method("get"):
		var value = obj.get(property)
		return value if value != null else default_value
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null