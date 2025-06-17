@tool
extends "res://tests/performance/base/perf_test_base.gd"

# Type-safe script references
const BattleSystemScript: GDScript = preload("res://src/core/battle/state/BattleStateMachine.gd")
const CharacterScript: GDScript = preload("res://src/core/character/Base/Character.gd")
const WeaponScript: GDScript = preload("res://src/core/systems/items/GameWeapon.gd")

# Test variables with explicit types
var _battle_system: Node = null
var _characters: Array[Node] = []
var _weapons: Array[Resource] = []

# Battle-specific thresholds (using frame timing for headless compatibility)
const BATTLE_THRESHOLDS := {
	"small_battle": {
		"average_frame_time": 50.0, # 50ms = ~20 FPS (reasonable for headless tests)
		"maximum_frame_time": 100.0, # 100ms = ~10 FPS (max acceptable)
		"memory_delta_kb": 512.0,
		"frame_time_stability": 0.5
	},
	"medium_battle": {
		"average_frame_time": 75.0, # 75ms = ~13 FPS
		"maximum_frame_time": 150.0, # 150ms = ~6.7 FPS
		"memory_delta_kb": 1024.0,
		"frame_time_stability": 0.4
	},
	"large_battle": {
		"average_frame_time": 100.0, # 100ms = ~10 FPS
		"maximum_frame_time": 200.0, # 200ms = ~5 FPS
		"memory_delta_kb": 2048.0,
		"frame_time_stability": 0.3
	}
}

# Safe wrapper methods for dynamic method calls
func _safe_call_method_bool(node: Node, method_name: String, args: Array = []) -> bool:
	if node and node.has_method(method_name):
		var result = node.callv(method_name, args)
		return result if result is bool else false
	return false

func before_test() -> void:
	await super.before_test()
	
	# Clear any existing state
	_characters.clear()
	_weapons.clear()
	
	# Initialize battle system
	_battle_system = BattleSystemScript.new()
	if not _battle_system:
		push_error("Failed to create battle system")
		return
	
	# Use track_node for automatic cleanup
	track_node(_battle_system)
	_battle_system.name = "TestBattleSystem"
	add_child(_battle_system)
	
	await stabilize_engine(STABILIZE_TIME)

func after_test() -> void:
	# Explicitly clean up characters first
	for character in _characters:
		if is_instance_valid(character):
			if character.get_parent():
				character.get_parent().remove_child(character)
			character.queue_free()
	_characters.clear()
	
	# Resources are RefCounted - clear references
	_weapons.clear()
	
	# Explicitly clean up battle system
	if is_instance_valid(_battle_system):
		if _battle_system.get_parent():
			_battle_system.get_parent().remove_child(_battle_system)
		_battle_system.queue_free()
	_battle_system = null
	
	# Force garbage collection
	await get_tree().process_frame
	await get_tree().process_frame
	
	await super.after_test()

func test_small_battle_performance() -> void:
	print_debug("Testing small battle performance (5v5)...")
	await _setup_battle(5, 5)
	
	var metrics := await measure_performance(
		func() -> void:
			_safe_call_method_bool(_battle_system, "process_round", [])
			await get_tree().process_frame
	)
	
	verify_performance_metrics(metrics, BATTLE_THRESHOLDS.small_battle)

func test_medium_battle_performance() -> void:
	print_debug("Testing medium battle performance (10v10)...")
	await _setup_battle(10, 10)
	
	var metrics := await measure_performance(
		func() -> void:
			_safe_call_method_bool(_battle_system, "process_round", [])
			await get_tree().process_frame
	)
	
	verify_performance_metrics(metrics, BATTLE_THRESHOLDS.medium_battle)

func test_large_battle_performance() -> void:
	print_debug("Testing large battle performance (20v20)...")
	await _setup_battle(20, 20)
	
	var metrics := await measure_performance(
		func() -> void:
			_safe_call_method_bool(_battle_system, "process_round", [])
			await get_tree().process_frame
	)
	
	verify_performance_metrics(metrics, BATTLE_THRESHOLDS.large_battle)

func test_battle_memory_management() -> void:
	print_debug("Testing battle memory management...")
	
	var initial_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	
	# Run multiple battles of increasing size
	for battle_size in [5, 10, 20]:
		print_debug("Testing battle size: %d" % battle_size)
		await _setup_battle(battle_size, battle_size)
		
		# Run battle simulation
		for i in range(5):
			if is_instance_valid(_battle_system):
				_safe_call_method_bool(_battle_system, "process_round", [])
			await get_tree().process_frame
		
		# Clean up characters manually for this test
		for character in _characters:
			if is_instance_valid(character):
				if character.get_parent():
					character.get_parent().remove_child(character)
				character.queue_free()
		_characters.clear()
		_weapons.clear()
		
		# Force garbage collection between iterations
		await get_tree().process_frame
		await get_tree().process_frame
		
		# Allow some time for cleanup
		await get_tree().create_timer(0.1).timeout
	
	var final_memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	var memory_delta := (final_memory - initial_memory) / 1024.0 # KB
	
	print_debug("Memory delta: %.2f KB" % memory_delta)
	
	# Use a more lenient threshold for battle system tests (3MB instead of default)
	var memory_threshold := 3072.0 # 3MB in KB
	
	assert_that(memory_delta).override_failure_message(
		"Memory delta (%.2f KB) should be less than threshold (%.2f KB)" % [memory_delta, memory_threshold]
	).is_less(memory_threshold)

func test_battle_stress() -> void:
	print_debug("Running battle system stress test...")
	
	# Setup medium-sized battle
	await _setup_battle(10, 10)
	
	await stress_test(
		func() -> void:
			_safe_call_method_bool(_battle_system, "process_round", [])
			
			# Randomly add/remove combatants
			if randf() < 0.2: # 20% chance each frame
				var side := randi() % 2
				if side == 0:
					await _add_character_to_battle(true) # Add to player side
				else:
					await _add_character_to_battle(false) # Add to enemy side
			
			await get_tree().process_frame
	)

func test_mobile_battle_performance() -> void:
	if not _is_mobile:
		print_debug("Skipping mobile battle test on non-mobile platform")
		return
	
	print_debug("Testing mobile battle performance...")
	
	# Test under memory pressure
	await simulate_memory_pressure()
	
	# Setup small battle (mobile optimized)
	await _setup_battle(3, 3)
	
	var metrics := await measure_performance(
		func() -> void:
			_safe_call_method_bool(_battle_system, "process_round", [])
			await get_tree().process_frame
	)
	
	# Use mobile-specific thresholds (frame timing based)
	var mobile_thresholds := {
		"average_frame_time": PERFORMANCE_THRESHOLDS.time.mobile_frame_budget_ms,
		"maximum_frame_time": PERFORMANCE_THRESHOLDS.time.mobile_frame_budget_ms * 2.0,
		"memory_delta_kb": PERFORMANCE_THRESHOLDS.memory.mobile_max_delta_mb * 1024,
		"frame_time_stability": 0.3
	}
	
	verify_performance_metrics(metrics, mobile_thresholds)

# Helper methods
func _setup_battle(player_count: int, enemy_count: int) -> void:
	# Create player characters
	for i in range(player_count):
		await _add_character_to_battle(true)
	
	# Create enemy characters
	for i in range(enemy_count):
		await _add_character_to_battle(false)
	
	await stabilize_engine(STABILIZE_TIME)

func _add_character_to_battle(is_player: bool) -> void:
	# Add null safety check
	if not is_instance_valid(_battle_system):
		push_warning("Battle system is null, skipping character addition")
		return
	
	# Create a Node2D to represent the character in battle (since we need a Node)
	var character: Node2D = Node2D.new()
	if not character:
		push_error("Failed to create character")
		return
	
	# Set up character properties before adding to scene
	character.name = "TestCharacter_%d" % (_characters.size() + 1)
	character.set_meta("is_player", is_player)
	character.set_meta("health", 100)
	character.set_meta("max_health", 100)
	character.set_meta("armor", 2)
	character.set_meta("weapon_skill", 3)
	character.set_meta("movement", 6)
	character.position = Vector2(randf_range(-100, 100), randf_range(-100, 100))
	
	# Create and assign a weapon
	var weapon: Resource = Resource.new()
	weapon.set_meta("name", "Test Weapon")
	weapon.set_meta("damage", 2)
	weapon.set_meta("range", 12)
	weapon.set_meta("shots", 1)
	
	character.set_meta("weapon", weapon)
	
	# Track resources for cleanup
	track_node(character)
	track_resource(weapon)
	
	# Store references
	_weapons.append(weapon)
	_characters.append(character)
	
	# Add to scene tree
	add_child(character)
	
	await get_tree().process_frame