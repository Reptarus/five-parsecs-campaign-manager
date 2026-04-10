class_name FPCM_BattlefieldData
extends Resource

## Battlefield Data Management System
##
## Centralized data management for battlefield companion functionality.
## Handles terrain generation, unit tracking, and state persistence
## following Five Parsecs from Home rulebook specifications.
##
## Dependencies:
	## - BattlefieldTypes.gd for data structures
## - DiceManager for random generation
## - GlobalEnums for game constants

# Dependencies
const BattlefieldTypes = preload("res://src/core/battle/BattlefieldTypes.gd")
const Godot4Utils = preload("res://src/utils/Godot4Utils.gd")
# GlobalEnums available as autoload singleton

# Signals for system communication
signal battlefield_generated(battlefield_data: BattlefieldTypes.BattlefieldData)
signal unit_added(unit_data: BattlefieldTypes.UnitData)
signal unit_removed(unit_id: String)
signal unit_status_changed(unit_id: String, new_status: Dictionary)
signal battle_state_changed(new_state: Dictionary)

# Core data storage
@export var current_battlefield: BattlefieldTypes.BattlefieldData = null
@export var tracked_units: Dictionary = {} # unit_id -> UnitData
@export var battle_state: Dictionary = {}
@export var generation_seed: int = 0

# Manager references
var dice_manager: Node = null
var campaign_manager: Node = null

func _init() -> void:
	## Initialize battlefield data system
	_initialize_managers()
	_setup_default_state()

func _initialize_managers() -> void:
	## Initialize manager references with error handling
	# Get dice manager reference - Resources cannot use scene tree methods
	# Use Engine singleton or wait for explicit injection
	if Engine.has_singleton("DiceManager"):
		dice_manager = Engine.get_singleton("DiceManager")
	if not dice_manager:
		push_warning("BattlefieldData: DiceManager not found, using fallback")

	# Get campaign manager reference
	if Engine.has_singleton("CampaignManager"):
		campaign_manager = Engine.get_singleton("CampaignManager")

func _setup_default_state() -> void:
	## Setup default battle state
	battle_state = {
		"phase": BattlefieldTypes.BattlePhase.SETUP_TERRAIN,
		"current_round": 0,
		"battle_active": false,
		"victory_conditions": {},
		"special_rules": [],
		"environmental_effects": {},
		"last_updated": Time.get_unix_time_from_system()
	}

# =====================================================
# BATTLEFIELD GENERATION
# =====================================================

func generate_battlefield(mission_data: Resource = null, custom_seed: int = -1) -> BattlefieldTypes.BattlefieldData:
	## Generate complete battlefield following Five Parsecs rules

	# Set generation seed for reproducible results
	if custom_seed > 0:
		generation_seed = custom_seed
	else:
		generation_seed = randi()

	var rng := RandomNumberGenerator.new()
	rng.seed = generation_seed

	# Create new battlefield data
	current_battlefield = BattlefieldTypes.BattlefieldData.new()
	current_battlefield.battlefield_id = "battlefield_%d" % Time.get_unix_time_from_system()
	current_battlefield.mission_data = mission_data

	# Generate terrain features (Five Parsecs Core Rules p.67-69)
	_generate_terrain_features(rng)

	# Generate objectives based on mission
	if mission_data:
		_generate_mission_objectives(mission_data, rng)
	else:
		_generate_default_objectives(rng)

	# Setup deployment zones
	current_battlefield.generate_standard_deployment_zones()

	# Apply environmental effects
	_apply_environmental_effects(rng)

	battlefield_generated.emit(current_battlefield)
	return current_battlefield

func _generate_terrain_features(rng: RandomNumberGenerator) -> void:
	## Generate terrain features per Five Parsecs rules
	if not current_battlefield:
		push_error("BattlefieldData: No battlefield to generate features for")
		return

	# Roll for number of terrain features (2d6 + 2 = 4-14 features)
	var num_features := _safe_dice_roll("2d6", rng) + 2

	for i in num_features:
		var feature := _create_terrain_feature(rng)
		if feature:
			current_battlefield.add_terrain_feature(feature)

func _create_terrain_feature(rng: RandomNumberGenerator) -> BattlefieldTypes.TerrainFeature:
	## Create individual terrain feature
	var feature := BattlefieldTypes.TerrainFeature.new()
	feature.feature_id = "terrain_%d_%d" % [current_battlefield.terrain_features.size(), rng.randi()]

	# Roll for terrain type (Five Parsecs Core Rules p.68)
	var terrain_roll := _safe_dice_roll("d6", rng)

	match terrain_roll:
		1, 2: # Cover features (40% chance)
			feature.setup_cover_feature()
			feature.positions = _generate_cover_positions(rng)
		3, 4: # Elevation features (30% chance)
			feature.setup_elevation_feature()
			feature.positions = _generate_elevation_positions(rng)
		5: # Difficult terrain (15% chance)
			feature.setup_difficult_terrain()
			feature.positions = _generate_area_positions(rng, 2)
		6: # Special/Mission feature (15% chance)
			feature.setup_special_feature()
			feature.positions = _generate_special_positions(rng)

	return feature

func _generate_cover_positions(rng: RandomNumberGenerator) -> Array[Vector2i]:
	## Generate positions for cover features
	var positions: Array[Vector2i] = []
	var center := Vector2i(
		rng.randi_range(3, current_battlefield.battlefield_size.x - 4),
		rng.randi_range(3, current_battlefield.battlefield_size.y - 4)
	)

	# Determine cover shape (Five Parsecs rules suggest lines and L-shapes)
	var shape_roll := _safe_dice_roll("d6", rng)

	match shape_roll:
		1, 2, 3: # Horizontal line
			for i: int in range(3):
				var pos := Vector2i(center.x + i, center.y)
				if _is_valid_position(pos):
					positions.append(pos)
		4, 5: # Vertical line
			for i: int in range(3):
				var pos := Vector2i(center.x, center.y + i)
				if _is_valid_position(pos):
					positions.append(pos)
		6: # L-shape
			var l_positions := [
				center,
				Vector2i(center.x + 1, center.y),
				Vector2i(center.x, center.y + 1)
			]
			for pos in l_positions:
				if _is_valid_position(pos):
					positions.append(pos)

	return positions

func _generate_elevation_positions(rng: RandomNumberGenerator) -> Array[Vector2i]:
	## Generate positions for elevation features
	var positions: Array[Vector2i] = []
	var center := Vector2i(
		rng.randi_range(2, current_battlefield.battlefield_size.x - 3),
		rng.randi_range(2, current_battlefield.battlefield_size.y - 3)
	)

	# Create 2x2 or 3x3 elevated area
	var size := 2 if _safe_dice_roll("d6", rng) <= 4 else 3

	for x: int in range(size):
		for y: int in range(size):
			var pos := Vector2i(center.x + x, center.y + y)
			if _is_valid_position(pos):
				positions.append(pos)

	return positions

func _generate_area_positions(rng: RandomNumberGenerator, area_size: int) -> Array[Vector2i]:
	## Generate positions for area-based features
	var positions: Array[Vector2i] = []
	var center := Vector2i(
		rng.randi_range(area_size, current_battlefield.battlefield_size.x - area_size - 1),
		rng.randi_range(area_size, current_battlefield.battlefield_size.y - area_size - 1)
	)

	for x: int in range(area_size):
		for y: int in range(area_size):
			var pos := Vector2i(center.x + x, center.y + y)
			if _is_valid_position(pos):
				positions.append(pos)

	return positions

func _generate_special_positions(rng: RandomNumberGenerator) -> Array[Vector2i]:
	## Generate positions for special mission features
	var positions: Array[Vector2i] = []
	var center := Vector2i(
		rng.randi_range(5, current_battlefield.battlefield_size.x - 6),
		rng.randi_range(5, current_battlefield.battlefield_size.y - 6)
	)

	positions.append(center)
	return positions

func _generate_mission_objectives(mission_data: Resource, rng: RandomNumberGenerator) -> void:
	## Generate objectives based on mission type
	if not mission_data or not current_battlefield:
		return

	var mission_type: String = "patrol"
	if mission_data and mission_data.has_method("get"):
		var type_value = Godot4Utils.safe_get_property(mission_data, "mission_type")
		if type_value != null:
			mission_type = str(type_value)
	var num_objectives := _get_objective_count_for_mission(mission_type)

	for i in num_objectives:
		var objective := _create_mission_objective(mission_type, i, rng)
		if objective:
			current_battlefield.add_objective(objective)

func _generate_default_objectives(rng: RandomNumberGenerator) -> void:
	## Generate default objectives for standard battles
	var objective_count := _safe_dice_roll("d3", rng) # 1-3 objectives

	for i in objective_count:
		var objective := BattlefieldTypes.FPCM_ObjectiveMarker.new()
		objective.objective_id = "obj_%d" % i

		# Random objective type
		var type_roll := _safe_dice_roll("d6", rng)
		match type_roll:
			1, 2, 3: objective.setup_secure_objective()
			4, 5: objective.setup_investigate_objective()
			6: objective.setup_destroy_objective()

		# Random position (avoid deployment zones)
		objective.position = Vector2i(
			rng.randi_range(6, current_battlefield.battlefield_size.x - 7),
			rng.randi_range(3, current_battlefield.battlefield_size.y - 4)
		)

		current_battlefield.add_objective(objective)

func _create_mission_objective(mission_type: String, index: int, rng: RandomNumberGenerator) -> BattlefieldTypes.FPCM_ObjectiveMarker:
	## Create objective based on mission type
	var objective := BattlefieldTypes.FPCM_ObjectiveMarker.new()
	objective.objective_id = "%s_obj_%d" % [mission_type, index]

	match mission_type.to_lower():
		"patrol":
			objective.setup_investigate_objective()
			objective.title = "Investigation Point %d" % (index + 1)
		"assault":
			objective.setup_destroy_objective()
			objective.title = "Target Structure %d" % (index + 1)
		"defense":
			objective.setup_secure_objective()
			objective.title = "Defense Position %d" % (index + 1)
		_:
			objective.setup_investigate_objective()

	# Position objectives appropriately
	objective.position = _get_objective_position_for_mission(mission_type, index, rng)

	return objective

# =====================================================
# UNIT MANAGEMENT
# =====================================================

func add_crew_member(crew_data: Resource) -> String:
	## Add crew member to tracking
	if not crew_data:
		push_error("BattlefieldData: Invalid crew data provided")
		return ""

	var unit := BattlefieldTypes.UnitData.new()
	unit.initialize_from_crew_member(crew_data)

	tracked_units[unit.unit_id] = unit
	unit_added.emit(unit)

	return unit.unit_id

func add_enemy(enemy_data: Resource) -> String:
	## Add enemy to tracking
	if not enemy_data:
		push_error("BattlefieldData: Invalid enemy data provided")
		return ""

	var unit := BattlefieldTypes.UnitData.new()
	unit.initialize_from_enemy(enemy_data)

	tracked_units[unit.unit_id] = unit
	unit_added.emit(unit)

	return unit.unit_id

func remove_unit(unit_id: String) -> bool:
	## Remove unit from tracking
	if not tracked_units.has(unit_id):
		push_warning("BattlefieldData: Unit not found: %s" % unit_id)
		return false

	tracked_units.erase(unit_id)
	unit_removed.emit(unit_id)
	return true

func update_unit_health(unit_id: String, new_health: int) -> bool:
	## Update unit health with validation
	var unit := tracked_units.get(unit_id) as BattlefieldTypes.UnitData
	if not unit:
		push_warning("BattlefieldData: Unit not found for health update: %s" % unit_id)
		return false

	var old_health := unit.current_health
	unit.current_health = clampi(new_health, 0, unit.max_health)

	if old_health != unit.current_health:
		unit_status_changed.emit(unit_id, {"health": unit.current_health, "was_defeated": unit.current_health <= 0})
		return true

	return false

func get_unit(unit_id: String) -> BattlefieldTypes.UnitData:
	## Get unit data by ID
	return tracked_units.get(unit_id) as BattlefieldTypes.UnitData

func get_units_by_team(team: String) -> Array[BattlefieldTypes.UnitData]:
	## Get all units of specified team
	var team_units: Array[BattlefieldTypes.UnitData] = []

	for unit in tracked_units.values():
		if unit.team == team:
			team_units.append(unit)

	return team_units

func get_alive_units() -> Array[BattlefieldTypes.UnitData]:
	## Get all living units
	var alive_units: Array[BattlefieldTypes.UnitData] = []

	for unit in tracked_units.values():
		if unit.is_alive():
			alive_units.append(unit)

	return alive_units

# =====================================================
# BATTLE STATE MANAGEMENT
# =====================================================

func start_battle() -> void:
	## Initialize battle state
	battle_state.battle_active = true
	battle_state.current_round = 1
	battle_state.phase = BattlefieldTypes.BattlePhase.TRACK_BATTLE
	battle_state.last_updated = Time.get_unix_time_from_system()

	# Reset all unit activations
	for unit in tracked_units.values():
		unit.activated_this_round = false

	battle_state_changed.emit(battle_state.duplicate())

func end_round() -> void:
	## End current round and reset activations
	if not battle_state.battle_active:
		return

	battle_state.current_round += 1
	battle_state.last_updated = Time.get_unix_time_from_system()

	# Reset unit activations
	for unit in tracked_units.values():
		unit.activated_this_round = false

	battle_state_changed.emit(battle_state.duplicate())

func end_battle(victory: bool) -> BattlefieldTypes.BattleResults:
	## End battle and generate results
	battle_state.battle_active = false
	battle_state.phase = BattlefieldTypes.BattlePhase.PREPARE_RESULTS
	battle_state.last_updated = Time.get_unix_time_from_system()

	var results := BattlefieldTypes.BattleResults.new()
	results.battle_id = current_battlefield.battlefield_id if current_battlefield else "unknown"
	results.victory = victory
	results.rounds_fought = battle_state.current_round

	# Process casualties and injuries for crew
	for unit in get_units_by_team("crew"):
		if not unit.is_alive():
			_process_crew_casualty(unit, results)

	battle_state_changed.emit(battle_state.duplicate())
	return results

func _process_crew_casualty(unit: BattlefieldTypes.UnitData, results: BattlefieldTypes.BattleResults) -> void:
	## Process crew casualty/injury per Five Parsecs rules
	var casualty_roll := _safe_dice_roll("d6")

	if casualty_roll <= 2: # Killed in action
		results.add_casualty(unit.unit_name, "killed_in_action")
	else: # Injured
		var injury_type := _roll_injury_type()
		var recovery_time := _calculate_recovery_time(injury_type)
		results.add_injury(unit.unit_name, injury_type, 1, recovery_time)

# =====================================================
# UTILITY FUNCTIONS
# =====================================================

func _safe_dice_roll(pattern: String, rng: RandomNumberGenerator = null) -> int:
	## Safe dice rolling with fallback
	if dice_manager and dice_manager.has_method("roll_dice"):
		return dice_manager.roll_dice("BattlefieldData", pattern)
	else:
		return _fallback_dice_roll(pattern, rng)

func _fallback_dice_roll(pattern: String, rng: RandomNumberGenerator = null) -> int:
	## Fallback dice rolling implementation
	var local_rng: RandomNumberGenerator = rng if rng else RandomNumberGenerator.new()

	match pattern.to_lower():
		"d3": return local_rng.randi_range(1, 3)
		"d6": return local_rng.randi_range(1, 6)
		"2d6": return local_rng.randi_range(1, 6) + local_rng.randi_range(1, 6)
		"d10": return local_rng.randi_range(1, 10)
		_: return local_rng.randi_range(1, 6)

func _is_valid_position(pos: Vector2i) -> bool:
	## Check if position is valid on battlefield
	if not current_battlefield:
		return false

	return pos.x >= 0 and pos.x < current_battlefield.battlefield_size.x and \
		   pos.y >= 0 and pos.y < current_battlefield.battlefield_size.y

func _get_objective_count_for_mission(mission_type: String) -> int:
	## Get number of objectives for mission type
	match mission_type.to_lower():
		"patrol": return 2
		"assault": return 1
		"defense": return 3
		"investigation": return _safe_dice_roll("d3")
		_: return 1

func _get_objective_position_for_mission(mission_type: String, index: int, rng: RandomNumberGenerator) -> Vector2i:
	## Get appropriate objective position for mission type
	match mission_type.to_lower():
		"defense": # Place in crew side
			return Vector2i(
				rng.randi_range(1, 5),
				rng.randi_range(2, current_battlefield.battlefield_size.y - 3)
			)
		"assault": # Place in enemy side
			return Vector2i(
				rng.randi_range(current_battlefield.battlefield_size.x - 6, current_battlefield.battlefield_size.x - 2),
				rng.randi_range(2, current_battlefield.battlefield_size.y - 3)
			)
		_: # Place in center
			return Vector2i(
				rng.randi_range(6, current_battlefield.battlefield_size.x - 7),
				rng.randi_range(3, current_battlefield.battlefield_size.y - 4)
			)

func _apply_environmental_effects(rng: RandomNumberGenerator) -> void:
	## Apply environmental effects to battlefield
	if not current_battlefield:
		return

	var effect_roll := _safe_dice_roll("d6", rng)
	if effect_roll == 6: # Special environmental condition
		var effect_types: Array[String] = ["fog", "rain", "wind", "heat", "cold"]
		var effect_type: String = effect_types[rng.randi_range(0, 4)]
		current_battlefield.environmental_effects[effect_type] = true

func _roll_injury_type() -> String:
	## Roll for injury type per Five Parsecs rules
	var injury_roll := _safe_dice_roll("d6")

	match injury_roll:
		1: return "Light wound"
		2: return "Serious injury"
		3: return "Knocked unconscious"
		4: return "Equipment damaged"
		5: return "Shaken"
		6: return "Critical injury"
		_: return "Light wound"

func _calculate_recovery_time(injury_type: String) -> int:
	## Calculate recovery time for injury
	match injury_type:
		"Light wound": return 1
		"Serious injury": return _safe_dice_roll("d3") + 1
		"Knocked unconscious": return 1
		"Equipment damaged": return 0 # No recovery time, just replace equipment
		"Shaken": return 1
		"Critical injury": return _safe_dice_roll("d6") + 2
		_: return 1

func cleanup() -> void:
	## Clean up battlefield data
	if current_battlefield:
		current_battlefield.clear_battlefield()

	tracked_units.clear()
	battle_state.clear()

