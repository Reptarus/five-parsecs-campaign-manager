@tool
extends GdUnitGameTest
class_name BattleTest

## Base class for battle system tests
##
## Provides functionality for testing combat scenarios, unit interactions,
## and battle state verification.

# Battle test configuration
const BATTLE_TEST_CONFIG := {
	"stabilize_time": 0.2 as float,
	"combat_timeout": 5.0 as float,
	"animation_timeout": 2.0 as float
}

# Battle system constants
const BASE_MOVEMENT: int = 6
const BASE_ACTION_POINTS: int = 2
const BASE_ATTACK_RANGE: int = 24
const BASE_HIT_CHANCE: float = 0.65
const BASE_DAMAGE: int = 3

# Combat modifiers
const COVER_MODIFIER: float = -0.25
const HEIGHT_MODIFIER: float = 0.15
const FLANK_MODIFIER: float = 0.2
const SUPPRESSION_MODIFIER: float = -0.2

# Range modifiers
const OPTIMAL_RANGE_BONUS: float = 0.1
const LONG_RANGE_PENALTY: float = -0.2
const EXTREME_RANGE_PENALTY: float = -0.4

# Status effect thresholds
const CRITICAL_THRESHOLD: float = 0.9
const GRAZE_THRESHOLD: float = 0.35
const MINIMUM_HIT_CHANCE: float = 0.05
const MAXIMUM_HIT_CHANCE: float = 0.95

# Action point costs
const MOVE_COST: int = 1
const ATTACK_COST: int = 1
const DEFEND_COST: int = 1

# Type-safe instance variables
var _battle_state: Node = null
var _combat_manager: Node = null
var _battlefield_manager: Node = null
var _active_units: Array[Node] = []
var _fps_samples: Array[float] = []

func before_test() -> void:
	await super.before_test()
	_setup_battle_environment()
	await stabilize_engine()

func after_test() -> void:
	_cleanup_battle_environment()
	await super.after_test()

func _setup_battle_environment() -> void:
	_battle_state = _create_battle_state()
	if _battle_state:
		add_child(_battle_state)
		track_node(_battle_state)
	
	_combat_manager = _create_combat_manager()
	if _combat_manager:
		add_child(_combat_manager)
		track_node(_combat_manager)
	
	_battlefield_manager = _create_battlefield_manager()
	if _battlefield_manager:
		add_child(_battlefield_manager)
		track_node(_battlefield_manager)

func _cleanup_battle_environment() -> void:
	_battle_state = null
	_combat_manager = null
	_battlefield_manager = null
	_active_units.clear()
	_fps_samples.clear()

# Battle system creation
func _create_battle_state() -> Node:
	return null # Override in derived classes

func _create_combat_manager() -> Node:
	return null # Override in derived classes

func _create_battlefield_manager() -> Node:
	return null # Override in derived classes

# Unit management
func create_test_unit(attack: int, defense: int, speed: int = 5) -> Node:
	var unit := Node.new()
	if not unit:
		push_error("Failed to create test unit")
		return null
	
	# Set properties using safe method calls
	if unit.has_method("set_attack"):
		unit.call("set_attack", attack)
	if unit.has_method("set_defense"):
		unit.call("set_defense", defense)
	if unit.has_method("set_speed"):
		unit.call("set_speed", speed)
	
	add_child(unit)
	track_node(unit)
	_active_units.append(unit)
	return unit

func create_test_squad(size: int) -> Array[Node]:
	var squad: Array[Node] = []
	for i in range(size):
		var unit := create_test_unit(10, 5, 5)
		if unit:
			squad.append(unit)
	return squad

# Combat resolution
func resolve_combat(attacker: Node, defender: Node) -> Dictionary:
	if not _combat_manager:
		push_error("Combat manager not initialized")
		return {}
	
	if _combat_manager.has_method("resolve_combat"):
		var result = _combat_manager.call("resolve_combat", attacker, defender)
		return result if result is Dictionary else {}
	return {}

func apply_damage(unit: Node, damage: int) -> void:
	if not unit:
		push_error("Cannot apply damage to null unit")
		return
	
	if unit.has_method("take_damage"):
		unit.call("take_damage", damage)

# Battle state assertions
func assert_battle_phase(expected_phase: int) -> void:
	if not _battle_state:
		push_error("Battle state not initialized")
		return
	
	var current_phase: int = 0
	if _battle_state.has_method("get_current_phase"):
		current_phase = _battle_state.call("get_current_phase")
	
	assert_that(current_phase).override_failure_message(
		"Battle should be in phase %d but was in phase %d" % [expected_phase, current_phase]
	).is_equal(expected_phase)

func assert_unit_state(unit: Node, expected_state: Dictionary) -> void:
	if not unit:
		push_error("Cannot assert state of null unit")
		return
	
	for property in expected_state:
		var actual_value = null
		if unit.has_method("get_" + property):
			actual_value = unit.call("get_" + property)
		var expected_value = expected_state[property]
		assert_that(actual_value).override_failure_message(
			"Unit property %s should be %s but was %s" % [property, expected_value, actual_value]
		).is_equal(expected_value)

# Combat calculations
func calculate_hit_chance(attacker: Node, defender: Node, modifiers: Dictionary = {}) -> float:
	if not _combat_manager:
		push_error("Combat manager not initialized")
		return 0.0
	
	if _combat_manager.has_method("calculate_hit_chance"):
		var result = _combat_manager.call("calculate_hit_chance", attacker, defender, modifiers)
		return float(result) if result != null else 0.0
	return 0.0

func calculate_damage(base_damage: int, armor: int) -> int:
	if not _combat_manager:
		push_error("Combat manager not initialized")
		return 0
	
	if _combat_manager.has_method("calculate_damage"):
		var result = _combat_manager.call("calculate_damage", base_damage, armor)
		return int(result) if result != null else 0
	return 0

# Status effects
func apply_status_effect(target: Node, effect: Dictionary) -> bool:
	if not target:
		push_error("Cannot apply effect to null target")
		return false
	
	if target.has_method("apply_status_effect"):
		return target.call("apply_status_effect", effect)
	return false

func get_active_effects(unit: Node) -> Array:
	if not unit:
		push_error("Cannot get effects from null unit")
		return []
	
	if unit.has_method("get_active_effects"):
		var result = unit.call("get_active_effects")
		return result if result is Array else []
	return []

# Turn order
func calculate_initiative(units: Array) -> Array:
	if not _battle_state:
		push_error("Battle state not initialized")
		return []
	
	if _battle_state.has_method("calculate_initiative"):
		var result = _battle_state.call("calculate_initiative", units)
		return result if result is Array else []
	return []

# Special abilities
func activate_ability(unit: Node, ability_id: String) -> Dictionary:
	if not unit:
		push_error("Cannot activate ability for null unit")
		return {}
	
	if unit.has_method("activate_ability"):
		var result = unit.call("activate_ability", ability_id)
		return result if result is Dictionary else {}
	return {}

# Performance testing
func measure_combat_performance(iterations: int = 100) -> Dictionary:
	# Clear performance samples
	_fps_samples.clear()
	var memory_before := Performance.get_monitor(Performance.MEMORY_STATIC)
	var draw_calls_before := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	
	var start_time := Time.get_ticks_msec()
	
	for i in range(iterations):
		var attacker := create_test_unit(10, 5)
		var defender := create_test_unit(5, 10)
		if attacker and defender:
			resolve_combat(attacker, defender)
		await get_tree().process_frame
		_fps_samples.append(Engine.get_frames_per_second())
	
	var end_time := Time.get_ticks_msec()
	var memory_after := Performance.get_monitor(Performance.MEMORY_STATIC)
	var draw_calls_after := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	
	# Calculate metrics
	var total_fps := 0.0
	var min_fps := 1000.0
	for fps in _fps_samples:
		total_fps += fps
		min_fps = min(min_fps, fps)
	
	return {
		"average_fps": total_fps / _fps_samples.size() if not _fps_samples.is_empty() else 0.0,
		"minimum_fps": min_fps if not _fps_samples.is_empty() else 0.0,
		"execution_time_ms": end_time - start_time,
		"memory_delta_kb": (memory_after - memory_before) / 1024.0,
		"draw_calls_delta": draw_calls_after - draw_calls_before
	}

# Helper methods
func wait_for_combat_resolution() -> void:
	await get_tree().create_timer(BATTLE_TEST_CONFIG.combat_timeout).timeout

func wait_for_animation() -> void:
	await get_tree().create_timer(BATTLE_TEST_CONFIG.animation_timeout).timeout