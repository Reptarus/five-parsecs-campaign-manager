class_name FPCM_BattleState
extends Resource

## Battle State Resource for Five Parsecs Campaign Manager
## Single source of truth for all battle data and progress
## Follows DiceSystem resource-based architecture for automatic cleanup
##
## Architecture: Resource-based design with comprehensive validation
## Performance: Optimized serialization and memory management
## Integration: Compatible with all battle UI components and core systems

# Dependencies
# GlobalEnums available as autoload singleton

# Battle progress tracking
@export var current_phase: int = 0 # FPCM_BattleManager.BattlePhase
@export var battle_id: String = ""
@export var battle_start_time: float = 0.0
@export var battle_end_time: float = 0.0
@export var is_complete: bool = false

# Mission and context data
@export var mission_data: Resource = null
@export var mission_type: String = ""
@export var difficulty_level: int = 1
@export var victory_conditions: Dictionary = {}

# Participant data
@export var crew_members: Array[Resource] = []
@export var enemy_forces: Array[Resource] = []
@export var crew_deployment: Dictionary = {} # positions, equipment, etc.
@export var enemy_deployment: Dictionary = {}

# Battlefield configuration
@export var battlefield_setup: Dictionary = {}
@export var terrain_features: Array[Dictionary] = []
@export var environmental_conditions: Dictionary = {}
@export var battlefield_size: Vector2i = Vector2i(20, 20)

# Combat tracking
@export var current_round: int = 0
@export var current_turn: int = 0
@export var initiative_order: Array[String] = []
@export var unit_positions: Dictionary = {}
@export var unit_status: Dictionary = {} # health, conditions, etc.

# Events and story integration
@export var triggered_events: Array[String] = []
@export var story_points_earned: int = 0
@export var special_circumstances: Array[String] = []

# Battle results and rewards
@export var battle_outcome: String = "" # "victory", "defeat", "fled"
@export var casualties: Array[Dictionary] = []
@export var injuries: Array[Dictionary] = []
@export var loot_found: Array[Resource] = []
@export var credits_earned: int = 0
@export var experience_gained: Dictionary = {}

# Advanced features
@export var save_checkpoints: Array[Dictionary] = []
@export var user_notes: String = ""
@export var replay_data: Array[Dictionary] = []

# Validation and integrity
var _validation_errors: Array[String] = []
var _last_update_time: float = 0.0
var _state_hash: String = ""

func _init() -> void:
	battle_id = "battle_" + str(randi()) + "_" + str(Time.get_ticks_msec())
	battle_start_time = Time.get_ticks_msec() / 1000.0
	_update_timestamp()

## Initialize battle state with mission data
func initialize_with_mission(p_mission_data: Resource, p_crew: Array[Resource], p_enemies: Array[Resource]) -> bool:
	if not p_mission_data:
		_add_validation_error("Mission data is required")
		return false
	
	if p_crew.is_empty():
		_add_validation_error("At least one crew member is required")
		return false
	
	if p_enemies.is_empty():
		_add_validation_error("At least one enemy is required")
		return false
	
	# Initialize core data
	mission_data = p_mission_data
	crew_members = p_crew.duplicate()
	enemy_forces = p_enemies.duplicate()
	
	# Extract mission properties safely
	mission_type = _safe_get_property(mission_data, "mission_type", "standard")
	difficulty_level = _safe_get_property(mission_data, "difficulty", 1)
	victory_conditions = _safe_get_property(mission_data, "victory_conditions", {})
	
	# Initialize tracking structures
	_initialize_unit_tracking()
	_initialize_battlefield()
	
	_update_timestamp()
	return validate_state()

## Initialize unit tracking for all participants
func _initialize_unit_tracking() -> void:
	unit_positions.clear()
	unit_status.clear()
	initiative_order.clear()
	
	# Initialize crew tracking
	for i: int in range(crew_members.size()):
		var crew_member: Resource = crew_members[i]
		var crew_id: String = _get_unit_id(crew_member, "crew_" + str(i))
		
		unit_status[crew_id] = {
			"type": "crew",
			"health": _safe_get_property(crew_member, "health", 3),
			"max_health": _safe_get_property(crew_member, "max_health", 3),
			"conditions": [],
			"equipment": _safe_get_property(crew_member, "equipment", []),
			"is_active": true
		}
		
		unit_positions[crew_id] = Vector2i(-1, -1) # Undeployed
	
	# Initialize enemy tracking
	for i: int in range(enemy_forces.size()):
		var enemy: Resource = enemy_forces[i]
		var enemy_id: String = _get_unit_id(enemy, "enemy_" + str(i))
		
		unit_status[enemy_id] = {
			"type": "enemy",
			"health": _safe_get_property(enemy, "health", 2),
			"max_health": _safe_get_property(enemy, "max_health", 2),
			"conditions": [],
			"equipment": _safe_get_property(enemy, "equipment", []),
			"is_active": true
		}
		
		unit_positions[enemy_id] = Vector2i(-1, -1) # Undeployed

## Initialize battlefield configuration
func _initialize_battlefield() -> void:
	battlefield_setup = {
		"size": battlefield_size,
		"terrain_type": "standard",
		"cover_density": "medium",
		"special_features": []
	}
	
	terrain_features.clear()
	environmental_conditions = {
		"lighting": "normal",
		"weather": "clear",
		"visibility": "unlimited"
	}

## Get safe unit ID from resource
func _get_unit_id(unit: Resource, fallback: String) -> String:
	if not unit:
		return fallback
	
	# Try various ID fields
	var id_candidates: Array[String] = ["id", "unit_id", "character_id", "name"]
	
	for field: String in id_candidates:
		var value: Variant = _safe_get_property(unit, field, "")
		if value != "" and value is String:
			return value as String
	
	return fallback

## Update unit position with validation
func update_unit_position(unit_id: String, new_position: Vector2i) -> bool:
	if not unit_id in unit_status:
		_add_validation_error("Unit ID not found: " + unit_id)
		return false
	
	if not _is_valid_position(new_position):
		_add_validation_error("Invalid position: " + str(new_position))
		return false
	
	# Check for position conflicts
	for existing_id: String in unit_positions:
		if existing_id != unit_id and unit_positions[existing_id] == new_position:
			_add_validation_error("Position occupied: " + str(new_position))
			return false
	
	unit_positions[unit_id] = new_position
	_update_timestamp()
	return true

## Update unit health with damage tracking
func update_unit_health(unit_id: String, new_health: int, damage_source: String = "") -> bool:
	if not unit_id in unit_status:
		_add_validation_error("Unit ID not found: " + unit_id)
		return false
	
	var unit_data: Dictionary = unit_status[unit_id]
	var old_health: int = unit_data.get("health", 0)
	var max_health: int = unit_data.get("max_health", 1)
	
	# Clamp health to valid range
	new_health = clampi(new_health, 0, max_health)
	unit_data["health"] = new_health
	
	# Track casualties
	if new_health <= 0 and old_health > 0:
		_record_casualty(unit_id, damage_source)
	
	# Track injuries (health loss but not death)
	if new_health < old_health and new_health > 0:
		_record_injury(unit_id, old_health - new_health, damage_source)
	
	_update_timestamp()
	return true

## Record casualty for post-battle processing
func _record_casualty(unit_id: String, source: String) -> void:
	var casualty_data: Dictionary = {
		"unit_id": unit_id,
		"round": current_round,
		"turn": current_turn,
		"source": source,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	
	casualties.append(casualty_data)
	
	# Mark unit as inactive
	if unit_id in unit_status:
		unit_status[unit_id]["is_active"] = false

## Record injury for post-battle processing
func _record_injury(unit_id: String, damage_amount: int, source: String) -> void:
	var injury_data: Dictionary = {
		"unit_id": unit_id,
		"damage": damage_amount,
		"round": current_round,
		"turn": current_turn,
		"source": source,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	
	injuries.append(injury_data)

## Add battle event to tracking
func add_battle_event(event_id: String, event_data: Dictionary = {}) -> void:
	if event_id in triggered_events:
		return # Don't duplicate events
	
	triggered_events.append(event_id)
	
	# Store detailed event data in special circumstances
	if not event_data.is_empty():
		var event_record: String = "%s: %s" % [event_id, str(event_data)]
		special_circumstances.append(event_record)
	
	_update_timestamp()

## Advance to next round
func advance_round() -> void:
	current_round += 1
	current_turn = 0
	_update_timestamp()

## Advance to next turn
func advance_turn() -> void:
	current_turn += 1
	_update_timestamp()

## Create save checkpoint for resume capability
func create_checkpoint(checkpoint_name: String = "") -> void:
	if checkpoint_name == "":
		checkpoint_name = "Round %d, Turn %d" % [current_round, current_turn]
	
	var checkpoint: Dictionary = {
		"name": checkpoint_name,
		"round": current_round,
		"turn": current_turn,
		"unit_positions": unit_positions.duplicate(true),
		"unit_status": unit_status.duplicate(true),
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	
	save_checkpoints.append(checkpoint)
	
	# Limit checkpoint history
	if save_checkpoints.size() > 10:
		save_checkpoints.pop_front()

## Restore from checkpoint
func restore_checkpoint(checkpoint_index: int) -> bool:
	if checkpoint_index < 0 or checkpoint_index >= save_checkpoints.size():
		_add_validation_error("Invalid checkpoint index: " + str(checkpoint_index))
		return false
	
	var checkpoint: Dictionary = save_checkpoints[checkpoint_index]
	
	current_round = checkpoint.get("round", 0)
	current_turn = checkpoint.get("turn", 0)
	unit_positions = checkpoint.get("unit_positions", {}).duplicate(true)
	unit_status = checkpoint.get("unit_status", {}).duplicate(true)
	
	_update_timestamp()
	return true

## Validate position is within battlefield bounds
func _is_valid_position(position: Vector2i) -> bool:
	return position.x >= 0 and position.x < battlefield_size.x and position.y >= 0 and position.y < battlefield_size.y

## Get battlefield status summary
func get_battlefield_status() -> Dictionary:
	var active_crew: int = 0
	var active_enemies: int = 0
	
	for unit_id: String in unit_status:
		var unit_data: Dictionary = unit_status[unit_id]
		if unit_data.get("is_active", false):
			if unit_data.get("type") == "crew":
				active_crew += 1
			elif unit_data.get("type") == "enemy":
				active_enemies += 1
	
	return {
		"round": current_round,
		"turn": current_turn,
		"active_crew": active_crew,
		"active_enemies": active_enemies,
		"total_casualties": casualties.size(),
		"total_injuries": injuries.size(),
		"events_triggered": triggered_events.size()
	}

## Complete battle with final results
func complete_battle(outcome: String, final_credits: int = 0, final_loot: Array[Resource] = []) -> void:
	battle_outcome = outcome
	credits_earned = final_credits
	loot_found = final_loot.duplicate()
	battle_end_time = Time.get_ticks_msec() / 1000.0
	is_complete = true
	
	_update_timestamp()

## Validate entire battle state
func validate_state() -> bool:
	_validation_errors.clear()
	
	# Validate core data
	if not mission_data:
		_add_validation_error("Missing mission data")
	
	if crew_members.is_empty():
		_add_validation_error("No crew members")
	
	if enemy_forces.is_empty():
		_add_validation_error("No enemy forces")
	
	# Validate tracking data consistency
	for unit_id: String in unit_positions:
		if not unit_id in unit_status:
			_add_validation_error("Position without status: " + unit_id)
	
	for unit_id: String in unit_status:
		if not unit_id in unit_positions:
			_add_validation_error("Status without position: " + unit_id)
	
	# Validate battlefield bounds
	for position: Vector2i in unit_positions.values():
		if position != Vector2i(-1, -1) and not _is_valid_position(position):
			_add_validation_error("Invalid unit position: " + str(position))
	
	return _validation_errors.is_empty()

## Get validation errors
func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()

## Add validation error to tracking
func _add_validation_error(error: String) -> void:
	if not error in _validation_errors:
		_validation_errors.append(error)

## Update timestamp for change tracking
func _update_timestamp() -> void:
	_last_update_time = Time.get_ticks_msec() / 1000.0
	_state_hash = str(hash(_get_state_summary()))

## Get state summary for hashing
func _get_state_summary() -> String:
	return "%d:%d:%s:%d:%d" % [
		current_round,
		current_turn,
		battle_outcome,
		unit_positions.size(),
		unit_status.size()
	]

## Safe property access helper
func _safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	
	if obj is Resource and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	
	return default_value

## Export for save game functionality
func export_save_data() -> Dictionary:
	return {
		"battle_id": battle_id,
		"battle_start_time": battle_start_time,
		"battle_end_time": battle_end_time,
		"current_phase": current_phase,
		"current_round": current_round,
		"current_turn": current_turn,
		"battle_outcome": battle_outcome,
		"mission_type": mission_type,
		"difficulty_level": difficulty_level,
		"unit_positions": unit_positions,
		"unit_status": unit_status,
		"casualties": casualties,
		"injuries": injuries,
		"triggered_events": triggered_events,
		"credits_earned": credits_earned,
		"story_points_earned": story_points_earned,
		"is_complete": is_complete,
		"user_notes": user_notes
	}

## Import from save data
func import_save_data(save_data: Dictionary) -> bool:
	if not save_data.has("battle_id"):
		_add_validation_error("Invalid save data format")
		return false
	
	battle_id = save_data.get("battle_id", "")
	battle_start_time = save_data.get("battle_start_time", 0.0)
	battle_end_time = save_data.get("battle_end_time", 0.0)
	current_phase = save_data.get("current_phase", 0)
	current_round = save_data.get("current_round", 0)
	current_turn = save_data.get("current_turn", 0)
	battle_outcome = save_data.get("battle_outcome", "")
	mission_type = save_data.get("mission_type", "")
	difficulty_level = save_data.get("difficulty_level", 1)
	unit_positions = save_data.get("unit_positions", {})
	unit_status = save_data.get("unit_status", {})
	casualties = save_data.get("casualties", [])
	injuries = save_data.get("injuries", [])
	triggered_events = save_data.get("triggered_events", [])
	credits_earned = save_data.get("credits_earned", 0)
	story_points_earned = save_data.get("story_points_earned", 0)
	is_complete = save_data.get("is_complete", false)
	user_notes = save_data.get("user_notes", "")
	
	_update_timestamp()
	return validate_state()