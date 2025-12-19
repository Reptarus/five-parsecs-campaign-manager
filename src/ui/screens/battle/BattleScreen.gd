class_name FPCM_BattleScreen
extends Control

## Battle Screen - Main Battle UI Container
##
## Demonstrates proper "call down, signal up" integration:
## 1. BattleScreen owns BattleStateMachine (battle logic)
## 2. BattleScreen owns BattleHUDCoordinator (UI display)
## 3. BattleScreen calls DOWN to both components
## 4. Both components signal UP to BattleScreen
## 5. BattleScreen coordinates between logic and UI
##
## Architecture: Clean separation of logic (BattleStateMachine) and UI (HUD)
## Performance: 60fps with batched updates
## Integration: Signal-based communication following Godot best practices

# =====================================================
# SIGNALS - Screen signals up to parent (CampaignDashboard, etc.)
# =====================================================

signal battle_completed(results: Dictionary)
signal battle_cancelled()
signal battle_error(error_message: String)

# =====================================================
# CHILD COMPONENTS
# =====================================================

## Battle logic - owns battle state
var battle_state_machine: FPCM_BattleStateMachine = null

## Battle HUD - displays battle state
@onready var hud_coordinator: FPCM_BattleHUDCoordinator = $BattleHUDCoordinator

## Battle state data
var battle_state: FPCM_BattleState = null

# =====================================================
# INITIALIZATION
# =====================================================

func _ready() -> void:
	_create_battle_state_machine()
	_connect_signals()

func _create_battle_state_machine() -> void:
	"""Create BattleStateMachine instance"""
	battle_state_machine = FPCM_BattleStateMachine.new()
	add_child(battle_state_machine)

func _connect_signals() -> void:
	"""Connect signals from child components (signal UP)"""
	
	# BattleStateMachine signals (battle logic events)
	if battle_state_machine:
		battle_state_machine.battle_started.connect(_on_battle_started)
		battle_state_machine.battle_ended.connect(_on_battle_ended)
		battle_state_machine.state_changed.connect(_on_battle_state_changed)
		battle_state_machine.phase_changed.connect(_on_battle_phase_changed)
		battle_state_machine.round_started.connect(_on_round_started)
	
	# HUDCoordinator signals (user interactions)
	if hud_coordinator:
		hud_coordinator.character_action_requested.connect(_on_character_action_requested)
		hud_coordinator.character_damage_applied.connect(_on_character_damage_applied)
		hud_coordinator.enemy_casualty_registered.connect(_on_enemy_casualty_registered)
		hud_coordinator.morale_check_completed.connect(_on_morale_check_completed)
		hud_coordinator.objective_acknowledged.connect(_on_objective_acknowledged)

# =====================================================
# PUBLIC INTERFACE (Called DOWN from parent)
# =====================================================

## Start a new battle
func start_battle(mission_data: Resource, crew_members: Array, enemy_forces: Array) -> bool:
	"""Initialize and start battle - called from campaign phase"""
	
	# Create battle state
	battle_state = FPCM_BattleState.new()
	var initialized: bool = battle_state.initialize_with_mission(mission_data, crew_members, enemy_forces)
	
	if not initialized:
		battle_error.emit("Failed to initialize battle state")
		return false
	
	# Initialize BattleStateMachine (call DOWN)
	battle_state_machine.add_combatant # This would be properly implemented
	
	# Initialize HUD (call DOWN)
	if hud_coordinator:
		hud_coordinator.initialize_with_battle_state(battle_state_machine, battle_state)
	
	# Start battle (call DOWN to logic)
	var started: bool = battle_state_machine.start_battle()
	
	if not started:
		battle_error.emit("Failed to start battle")
		return false
	
	return true

## Pause battle
func pause_battle() -> void:
	"""Pause battle - save checkpoint"""
	if battle_state:
		battle_state.create_checkpoint("manual_pause")

## Resume battle
func resume_battle() -> void:
	"""Resume battle from pause"""
	# Battle continues from current state
	pass

## End battle manually
func end_battle() -> void:
	"""End battle manually (flee, surrender, etc.)"""
	if battle_state_machine:
		battle_state_machine.end_battle(0) # 0 = defeat/fled

# =====================================================
# BATTLESTATEMACHINE SIGNAL HANDLERS (Logic events)
# =====================================================

func _on_battle_started() -> void:
	"""Battle has started - update UI"""
	print("Battle Screen: Battle started")
	# HUD already initialized and showing

func _on_battle_ended(victory: bool) -> void:
	"""Battle has ended - collect results and signal up"""
	print("Battle Screen: Battle ended - Victory: ", victory)
	
	# Collect battle results
	var results: Dictionary = {
		"victory": victory,
		"battle_state": battle_state,
		"casualties": _collect_casualties(),
		"loot": _collect_loot(),
		"experience": _calculate_experience()
	}
	
	# Signal up to parent
	battle_completed.emit(results)

func _on_battle_state_changed(old_state: int, new_state: int) -> void:
	"""Battle state changed - HUD already listening"""
	print("Battle Screen: State changed from ", old_state, " to ", new_state)

func _on_battle_phase_changed(old_phase: int, new_phase: int) -> void:
	"""Battle phase changed - HUD already listening"""
	print("Battle Screen: Phase changed from ", old_phase, " to ", new_phase)

func _on_round_started(round_number: int) -> void:
	"""New round started - HUD already listening and resetting"""
	print("Battle Screen: Round ", round_number, " started")

# =====================================================
# HUD COORDINATOR SIGNAL HANDLERS (User interactions)
# =====================================================

func _on_character_action_requested(character_name: String, action_type: String) -> void:
	"""User requested character action - apply to battle logic"""
	print("Battle Screen: Action requested - ", character_name, " - ", action_type)
	
	# Find character in battle state
	var character_index: int = _find_character_index(character_name)
	if character_index < 0:
		return
	
	# Apply action through BattleStateMachine (call DOWN)
	# battle_state_machine.process_character_action(character_index, action_type)

func _on_character_damage_applied(character_name: String, amount: int) -> void:
	"""Character took damage - update battle state"""
	print("Battle Screen: Damage applied - ", character_name, " - ", amount)
	
	# Update battle state health tracking
	if battle_state:
		_update_character_health_in_state(character_name, amount)

func _on_enemy_casualty_registered() -> void:
	"""Enemy casualty - update battle state and check victory"""
	print("Battle Screen: Enemy casualty registered")
	
	# Check if battle is won
	if battle_state:
		var enemies_remaining: int = _count_active_enemies()
		if enemies_remaining == 0:
			# Victory!
			if battle_state_machine:
				battle_state_machine.end_battle(1) # 1 = elimination victory

func _on_morale_check_completed(result: Dictionary) -> void:
	"""Morale check completed - apply results to battle state"""
	print("Battle Screen: Morale check completed - ", result)
	
	# If enemies fled, reduce active enemy count
	if result.has("fled") and result.fled > 0:
		_remove_fled_enemies(result.fled)

func _on_objective_acknowledged() -> void:
	"""User acknowledged objective - continue to deployment"""
	print("Battle Screen: Objective acknowledged")
	
	# Transition to next phase (call DOWN)
	if battle_state_machine:
		battle_state_machine.advance_phase()

# =====================================================
# BATTLE STATE QUERIES
# =====================================================

func _find_character_index(character_name: String) -> int:
	"""Find character index in battle state"""
	if not battle_state:
		return -1
	
	for i in range(battle_state.crew_members.size()):
		var crew_member: Resource = battle_state.crew_members[i]
		var name: String = _get_character_name(crew_member)
		if name == character_name:
			return i
	
	return -1

func _count_active_enemies() -> int:
	"""Count enemies still active (not casualties or fled)"""
	if not battle_state:
		return 0
	
	var count: int = 0
	for unit_id in battle_state.unit_status:
		var status: Dictionary = battle_state.unit_status[unit_id]
		if status.get("type") == "enemy" and status.get("is_active", false):
			count += 1
	
	return count

func _update_character_health_in_state(character_name: String, damage: int) -> void:
	"""Update character health in battle state"""
	if not battle_state:
		return
	
	# Find unit in unit_status
	for unit_id in battle_state.unit_status:
		var status: Dictionary = battle_state.unit_status[unit_id]
		# Check if this is the right character (simplified)
		if unit_id.contains(character_name.to_lower()):
			status["health"] = max(0, status.get("health", 3) - damage)
			if status["health"] == 0:
				status["is_active"] = false
			break

func _remove_fled_enemies(count: int) -> void:
	"""Remove fled enemies from battle state"""
	if not battle_state:
		return
	
	var fled: int = 0
	for unit_id in battle_state.unit_status:
		if fled >= count:
			break
		
		var status: Dictionary = battle_state.unit_status[unit_id]
		if status.get("type") == "enemy" and status.get("is_active", false):
			status["is_active"] = false
			status["fled"] = true
			fled += 1

# =====================================================
# BATTLE RESULTS COLLECTION
# =====================================================

func _collect_casualties() -> Array[Dictionary]:
	"""Collect all casualties from battle"""
	var casualties: Array[Dictionary] = []
	
	if not battle_state:
		return casualties
	
	for unit_id in battle_state.unit_status:
		var status: Dictionary = battle_state.unit_status[unit_id]
		if status.get("type") == "crew" and status.get("health", 3) <= 0:
			casualties.append({
				"unit_id": unit_id,
				"character_name": unit_id.replace("crew_", "")
			})
	
	return casualties

func _collect_loot() -> Array[Resource]:
	"""Collect loot from battle"""
	# Placeholder - would integrate with loot system
	return []

func _calculate_experience() -> Dictionary:
	"""Calculate experience gains"""
	var experience: Dictionary = {}
	
	if not battle_state:
		return experience
	
	# Each surviving crew member gets base XP
	for unit_id in battle_state.unit_status:
		var status: Dictionary = battle_state.unit_status[unit_id]
		if status.get("type") == "crew" and status.get("health", 0) > 0:
			var character_name: String = unit_id.replace("crew_", "")
			experience[character_name] = 1 # Base XP
	
	return experience

# =====================================================
# HELPER METHODS
# =====================================================

func _get_character_name(character: Resource) -> String:
	"""Get character name from resource"""
	if not character:
		return "Unknown"
	
	# Try different property names
	for prop in ["character_name", "name", "crew_name"]:
		if "property" in character:
			var value: Variant = character.get(prop)
			if value and value is String:
				return value
	
	return "Unknown"

# =====================================================
# CLEANUP
# =====================================================

func _exit_tree() -> void:
	"""Cleanup on removal"""
	
	# Disconnect BattleStateMachine signals
	if battle_state_machine:
		if battle_state_machine.battle_started.is_connected(_on_battle_started):
			battle_state_machine.battle_started.disconnect(_on_battle_started)
		if battle_state_machine.battle_ended.is_connected(_on_battle_ended):
			battle_state_machine.battle_ended.disconnect(_on_battle_ended)
		if battle_state_machine.state_changed.is_connected(_on_battle_state_changed):
			battle_state_machine.state_changed.disconnect(_on_battle_state_changed)
		if battle_state_machine.phase_changed.is_connected(_on_battle_phase_changed):
			battle_state_machine.phase_changed.disconnect(_on_battle_phase_changed)
		if battle_state_machine.round_started.is_connected(_on_round_started):
			battle_state_machine.round_started.disconnect(_on_round_started)
		
		battle_state_machine.queue_free()
		battle_state_machine = null
	
	# HUD coordinator disconnects itself in its own _exit_tree()
	
	# Null references
	battle_state = null
