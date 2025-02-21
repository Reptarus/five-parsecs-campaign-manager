extends GameTest

# Common test timeouts
const DEFAULT_TIMEOUT := 1.0
const SETUP_TIMEOUT := 2.0
const STABILIZE_TIME := 0.1

# Common test states
var _battlefield: Node2D = null
var _enemy_campaign_system: Node = null
var _combat_system: Node = null

# Test enemy states
const TEST_ENEMY_STATES := {
	"BASIC": {
		"health": 100.0 as float,
		"movement_range": 4.0 as float,
		"weapon_range": 1.0 as float,
		"behavior": GameEnums.AIBehavior.CAUTIOUS as int
	},
	"ELITE": {
		"health": 150.0 as float,
		"movement_range": 5.0 as float,
		"weapon_range": 2.0 as float,
		"behavior": GameEnums.AIBehavior.AGGRESSIVE as int
	},
	"BOSS": {
		"health": 200.0 as float,
		"movement_range": 3.0 as float,
		"weapon_range": 3.0 as float,
		"behavior": GameEnums.AIBehavior.TACTICAL as int
	}
}

# Test references
var _enemy: Node = null
var _enemy_data: Resource = null

# Setup methods
func before_each() -> void:
	await super.before_each()
	await setup_base_systems()

func after_each() -> void:
	_enemy = null
	_enemy_data = null
	cleanup_base_systems()
	await super.after_each()

# Base system setup
func setup_base_systems() -> void:
	# Setup battlefield
	_battlefield = Node2D.new()
	if not _battlefield:
		push_error("Failed to create battlefield instance")
		return
	_battlefield.name = "Battlefield"
	add_child_autofree(_battlefield)
	track_test_node(_battlefield)
	
	# Setup campaign system
	_enemy_campaign_system = Node.new()
	if not _enemy_campaign_system:
		push_error("Failed to create campaign system instance")
		return
	_enemy_campaign_system.name = "CampaignSystem"
	add_child_autofree(_enemy_campaign_system)
	track_test_node(_enemy_campaign_system)
	
	# Setup combat system
	_combat_system = Node.new()
	if not _combat_system:
		push_error("Failed to create combat system instance")
		return
	_combat_system.name = "CombatSystem"
	add_child_autofree(_combat_system)
	track_test_node(_combat_system)
	
	await stabilize_engine(STABILIZE_TIME)

func cleanup_base_systems() -> void:
	_battlefield = null
	_enemy_campaign_system = null
	_combat_system = null

# Common setup methods
func setup_campaign_test() -> void:
	await setup_base_systems()
	# Additional campaign-specific setup can be added here

func setup_combat_test() -> void:
	await setup_base_systems()
	# Additional combat-specific setup can be added here

func setup_mission_test() -> void:
	await setup_base_systems()
	# Additional mission-specific setup can be added here

# Common verification methods
func verify_campaign_state(campaign: Resource, expected_state: Dictionary) -> void:
	if not _enemy_campaign_system:
		push_error("Campaign system not initialized")
		return
		
	if expected_state.has("phase"):
		var phase: int = TypeSafeMixin._safe_method_call_int(_enemy_campaign_system, "get_phase", [])
		var expected_phase: int = TypeSafeMixin._safe_cast_int(expected_state.get("phase", 0))
		assert_eq(phase, expected_phase, "Campaign phase should match expected state")
	
	if expected_state.has("turn"):
		var turn: int = TypeSafeMixin._safe_method_call_int(_enemy_campaign_system, "get_turn", [])
		var expected_turn: int = TypeSafeMixin._safe_cast_int(expected_state.get("turn", 0))
		assert_eq(turn, expected_turn, "Campaign turn should match expected state")

func verify_combat_state(enemy: Node, expected_state: Dictionary) -> void:
	if not enemy:
		push_error("Enemy not initialized")
		return
		
	if expected_state.has("health"):
		var health: float = TypeSafeMixin._safe_method_call_float(enemy, "get_health", [])
		var expected_health: float = TypeSafeMixin._safe_cast_float(expected_state.get("health", 0.0))
		assert_eq(health, expected_health, "Enemy health should match expected state")
	
	if expected_state.has("position"):
		var position: Vector2 = TypeSafeMixin._safe_method_call_vector2(enemy, "get_position", [])
		var expected_position: Vector2 = expected_state.get("position", Vector2.ZERO)
		assert_eq(position, expected_position, "Enemy position should match expected state")

func verify_mission_state(mission: Resource, expected_state: Dictionary) -> void:
	# Add mission state verification logic here
	pass

# Common test data creation
func create_test_enemy(type: String = "BASIC") -> Node:
	var enemy: Node = Enemy.new()
	if not enemy:
		push_error("Failed to create enemy instance")
		return null
		
	add_child_autofree(enemy)
	track_test_node(enemy)
	
	# Setup enemy based on type
	var state: Dictionary = TEST_ENEMY_STATES.get(type, TEST_ENEMY_STATES["BASIC"])
	_setup_enemy_state(enemy, state)
	
	return enemy

# Signal verification helpers
func verify_signal_sequence(expected_signals: Array[String]) -> void:
	if not _enemy_campaign_system:
		push_error("Campaign system not initialized")
		return
		
	for signal_name in expected_signals:
		verify_signal_emitted(_enemy_campaign_system, signal_name)

func verify_missing_signals(emitter: Object, expected_signals: Array[String]) -> void:
	if not emitter:
		push_error("Signal emitter not initialized")
		return
		
	for signal_name in expected_signals:
		verify_signal_not_emitted(emitter, signal_name)

# Helper methods
func create_test_enemy_data(state_key: String = "BASIC") -> Resource:
	var data: Resource = FiveParsecsEnemyData.new()
	if not data:
		push_error("Failed to create enemy data instance")
		return null
		
	track_test_resource(data)
	
	var state: Dictionary = TEST_ENEMY_STATES.get(state_key, TEST_ENEMY_STATES["BASIC"])
	_setup_enemy_data(data, state)
	
	return data

# Verification methods
func verify_enemy_state(enemy: Node, expected_state: Dictionary) -> void:
	if not enemy:
		push_error("Enemy not initialized")
		return
		
	var health: float = TypeSafeMixin._safe_method_call_float(enemy, "get_health", [])
	var expected_health: float = TypeSafeMixin._safe_cast_float(expected_state.get("health", 100.0))
	assert_eq(health, expected_health, "Enemy health should match expected state")
	
	var movement_range: float = TypeSafeMixin._safe_method_call_float(enemy, "get_movement_range", [])
	var expected_movement: float = TypeSafeMixin._safe_cast_float(expected_state.get("movement_range", 4.0))
	assert_eq(movement_range, expected_movement, "Enemy movement range should match expected state")
	
	var weapon_range: float = TypeSafeMixin._safe_method_call_float(enemy, "get_weapon_range", [])
	var expected_weapon: float = TypeSafeMixin._safe_cast_float(expected_state.get("weapon_range", 1.0))
	assert_eq(weapon_range, expected_weapon, "Enemy weapon range should match expected state")
	
	var behavior: int = TypeSafeMixin._safe_method_call_int(enemy, "get_behavior", [])
	var expected_behavior: int = TypeSafeMixin._safe_cast_int(expected_state.get("behavior", GameEnums.AIBehavior.CAUTIOUS))
	assert_eq(behavior, expected_behavior, "Enemy behavior should match expected state")

func verify_enemy_signals(enemy: Node, expected_signals: Array[String]) -> void:
	if not enemy:
		push_error("Enemy not initialized")
		return
		
	_signal_watcher.watch_signals(enemy)
	
	for signal_name in expected_signals:
		verify_signal_emitted(enemy, signal_name)

func verify_enemy_movement(enemy: Node, start_pos: Vector2, end_pos: Vector2) -> void:
	if not enemy:
		push_error("Enemy not initialized")
		return
		
	var current_pos: Vector2 = TypeSafeMixin._safe_method_call_vector2(enemy, "get_position", [])
	assert_eq(current_pos, start_pos, "Enemy should start at correct position")
	
	_signal_watcher.watch_signals(enemy)
	var move_result: bool = TypeSafeMixin._safe_method_call_bool(enemy, "move_to", [end_pos])
	assert_true(move_result, "Enemy should successfully initiate movement")
	
	current_pos = TypeSafeMixin._safe_method_call_vector2(enemy, "get_position", [])
	assert_eq(current_pos, end_pos, "Enemy should move to target position")
	verify_signal_emitted(enemy, "movement_completed")

func verify_enemy_combat(enemy: Node, target: Node2D) -> void:
	if not enemy or not target:
		push_error("Enemy or target not initialized")
		return
		
	var can_attack: bool = TypeSafeMixin._safe_method_call_bool(enemy, "can_attack", [])
	assert_true(can_attack, "Enemy should be able to attack")
	
	_signal_watcher.watch_signals(enemy)
	var attack_result: bool = TypeSafeMixin._safe_method_call_bool(enemy, "attack", [target])
	assert_true(attack_result, "Enemy should successfully initiate attack")
	
	verify_signal_emitted(enemy, "attack_completed")
	can_attack = TypeSafeMixin._safe_method_call_bool(enemy, "can_attack", [])
	assert_false(can_attack, "Enemy should not be able to attack after attacking")

# Internal helper methods
func _setup_enemy_state(enemy: Node, state: Dictionary) -> void:
	if not enemy or not state:
		push_error("Enemy or state not initialized")
		return
		
	var enemy_data: Resource = create_test_enemy_data()
	if not enemy_data:
		push_error("Failed to create enemy data")
		return
		
	TypeSafeMixin._safe_method_call_bool(enemy, "set_enemy_data", [enemy_data])
	TypeSafeMixin._safe_method_call_bool(enemy, "set_max_health", [TypeSafeMixin._safe_cast_float(state.get("health", 100.0))])
	TypeSafeMixin._safe_method_call_bool(enemy, "set_current_health", [TypeSafeMixin._safe_method_call_float(enemy, "get_max_health", [])])
	TypeSafeMixin._safe_method_call_bool(enemy, "set_movement_range", [TypeSafeMixin._safe_cast_float(state.get("movement_range", 4.0))])
	TypeSafeMixin._safe_method_call_bool(enemy, "set_weapon_range", [TypeSafeMixin._safe_cast_float(state.get("weapon_range", 1.0))])
	TypeSafeMixin._safe_method_call_bool(enemy, "set_behavior", [TypeSafeMixin._safe_cast_int(state.get("behavior", GameEnums.AIBehavior.CAUTIOUS))])

func _setup_enemy_data(data: Resource, state: Dictionary) -> void:
	if not data or not state:
		push_error("Data or state not initialized")
		return
		
	if data.has_method("set_health"):
		TypeSafeMixin._safe_method_call_bool(data, "set_health", [TypeSafeMixin._safe_cast_float(state.get("health", 100.0))])
	if data.has_method("set_movement_range"):
		TypeSafeMixin._safe_method_call_bool(data, "set_movement_range", [TypeSafeMixin._safe_cast_float(state.get("movement_range", 4.0))])
	if data.has_method("set_weapon_range"):
		TypeSafeMixin._safe_method_call_bool(data, "set_weapon_range", [TypeSafeMixin._safe_cast_float(state.get("weapon_range", 1.0))])
	if data.has_method("set_behavior"):
		TypeSafeMixin._safe_method_call_bool(data, "set_behavior", [TypeSafeMixin._safe_cast_int(state.get("behavior", GameEnums.AIBehavior.CAUTIOUS))])