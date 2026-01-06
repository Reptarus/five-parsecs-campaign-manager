class_name FPCM_BattleHUDCoordinator
extends Control

## Battle HUD Coordinator - "Call Down, Signal Up" Pattern
##
## Coordinates all battle HUD components following Godot best practices:
## - Parent (this) calls down to child components (update methods)
## - Children signal up to parent (user actions, state changes)
## - BattleStateMachine owns battle state, HUD reflects it
##
## Architecture: Single coordinator owns all HUD components
## Performance: Batch UI updates with call_deferred(), 60fps target
## Integration: Clean signal flow between UI and BattleStateMachine

# =====================================================
# SIGNALS - Children signal UP to coordinator
# =====================================================

## Character action signals
signal character_action_requested(character_name: String, action_type: String)
signal character_damage_applied(character_name: String, amount: int)
signal character_stun_added(character_name: String)
signal character_selected(character_name: String)

## Objective tracking signals
signal objective_completed(objective_name: String)
signal objective_acknowledged()
signal objective_rerolled()

## Morale and enemy signals
signal morale_check_completed(result: Dictionary)
signal enemy_casualty_registered()
signal enemies_fled(count: int)

## HUD state signals
signal hud_ready()
signal hud_refresh_requested()

# =====================================================
# DEPENDENCIES
# =====================================================

const CharacterStatusCard = preload("res://src/ui/components/battle/CharacterStatusCard.gd")
const ObjectiveDisplay = preload("res://src/ui/components/battle/ObjectiveDisplay.gd")
const MoralePanicTracker = preload("res://src/ui/components/battle/MoralePanicTracker.gd")

# =====================================================
# CHILD COMPONENT REFERENCES
# =====================================================

## Character status cards (one per crew member)
var character_cards: Dictionary = {} # character_name -> CharacterStatusCard

## Objective display panel
@onready var objective_display: FPCM_ObjectiveDisplay = $ObjectiveDisplay

## Morale tracker
@onready var morale_tracker: FPCM_MoralePanicTracker = $MoraleTracker

## Container for character cards
@onready var crew_container: HBoxContainer = $CrewContainer

# =====================================================
# STATE REFERENCES (Read-only)
# =====================================================

## BattleStateMachine reference (signals up to this)
var battle_state_machine: FPCM_BattleStateMachine = null

## Current battle state (for display purposes only)
var current_battle_state: FPCM_BattleState = null

## Selected character (for UI highlighting)
var selected_character: String = ""

# =====================================================
# PERFORMANCE TRACKING
# =====================================================

var update_batch_queued: bool = false
var last_update_time: float = 0.0
const UPDATE_THROTTLE: float = 1.0 / 60.0 # 60 FPS target

# =====================================================
# INITIALIZATION
# =====================================================

func _ready() -> void:
	_setup_ui()
	_connect_child_signals()
	hud_ready.emit()

func _setup_ui() -> void:
	"""Setup HUD layout and styling"""
	# Ensure containers exist
	if not crew_container:
		crew_container = HBoxContainer.new()
		crew_container.name = "CrewContainer"
		add_child(crew_container)
	
	# Setup objective display
	if not objective_display:
		objective_display = FPCM_ObjectiveDisplay.new()
		objective_display.name = "ObjectiveDisplay"
		add_child(objective_display)
	
	# Setup morale tracker
	if not morale_tracker:
		morale_tracker = FPCM_MoralePanicTracker.new()
		morale_tracker.name = "MoraleTracker"
		add_child(morale_tracker)

func _connect_child_signals() -> void:
	"""Connect signals from child components (signal UP pattern)"""
	# Objective display signals
	if objective_display:
		if not objective_display.objective_acknowledged.is_connected(_on_objective_acknowledged):
			objective_display.objective_acknowledged.connect(_on_objective_acknowledged)
		if not objective_display.objective_rolled.is_connected(_on_objective_rolled):
			objective_display.objective_rolled.connect(_on_objective_rolled)
	
	# Morale tracker signals
	if morale_tracker:
		if not morale_tracker.morale_check_triggered.is_connected(_on_morale_check_triggered):
			morale_tracker.morale_check_triggered.connect(_on_morale_check_triggered)
		if not morale_tracker.enemy_fled.is_connected(_on_enemies_fled):
			morale_tracker.enemy_fled.connect(_on_enemies_fled)
		if not morale_tracker.panic_occurred.is_connected(_on_panic_occurred):
			morale_tracker.panic_occurred.connect(_on_panic_occurred)

# =====================================================
# BATTLE STATE MACHINE INTEGRATION (Call DOWN)
# =====================================================

## Initialize HUD with BattleStateMachine reference
func initialize_with_battle_state(p_battle_state_machine: FPCM_BattleStateMachine, p_battle_state: FPCM_BattleState) -> void:
	battle_state_machine = p_battle_state_machine
	current_battle_state = p_battle_state
	
	# Connect to BattleStateMachine signals (listen to state changes)
	if battle_state_machine:
		if not battle_state_machine.state_changed.is_connected(_on_battle_state_changed):
			battle_state_machine.state_changed.connect(_on_battle_state_changed)
		if not battle_state_machine.phase_changed.is_connected(_on_battle_phase_changed):
			battle_state_machine.phase_changed.connect(_on_battle_phase_changed)
		if not battle_state_machine.round_started.is_connected(_on_round_started):
			battle_state_machine.round_started.connect(_on_round_started)
		if not battle_state_machine.unit_action_completed.is_connected(_on_unit_action_completed):
			battle_state_machine.unit_action_completed.connect(_on_unit_action_completed)
	
	# Initial HUD setup
	_setup_crew_cards()
	_setup_objective_display()
	_setup_morale_tracker()
	
	_queue_batch_update()

## Setup character cards for all crew members (Call DOWN)
func _setup_crew_cards() -> void:
	if not current_battle_state:
		return
	
	# Clear existing cards
	_clear_crew_cards()
	
	# Create card for each crew member
	for crew_member in current_battle_state.crew_members:
		if not crew_member:
			continue
		
		var character_name: String = _get_character_name(crew_member)
		var card: FPCM_CharacterStatusCard = _create_character_card(crew_member)
		
		# Store reference
		character_cards[character_name] = card
		
		# Add to container
		crew_container.add_child(card)

func _create_character_card(crew_member: Resource) -> FPCM_CharacterStatusCard:
	"""Create and configure character status card"""
	var card: FPCM_CharacterStatusCard = CharacterStatusCard.new()
	
	# Setup character data (Call DOWN)
	var character_data: Dictionary = {
		"character_name": _get_character_name(crew_member),
		"combat": _safe_get_property(crew_member, "combat", 0),
		"toughness": _safe_get_property(crew_member, "toughness", 4),
		"speed": _safe_get_property(crew_member, "speed", 4),
		"savvy": _safe_get_property(crew_member, "savvy", 0),
		"reactions": _safe_get_property(crew_member, "reactions", 1),
		"health": _safe_get_property(crew_member, "health", 3),
		"max_health": _safe_get_property(crew_member, "max_health", 3),
		"actions_remaining": 2,
		"movement_remaining": 6,
		"stun_markers": 0
	}
	
	card.set_character_data(character_data)
	
	# Connect card signals (Signal UP)
	card.action_used.connect(_on_character_action_used)
	card.damage_taken.connect(_on_character_damage_taken)
	card.stun_marked.connect(_on_character_stun_marked)
	card.character_selected.connect(_on_character_selected_internal)
	
	return card

func _clear_crew_cards() -> void:
	"""Clear all character cards"""
	for card in character_cards.values():
		if is_instance_valid(card):
			card.queue_free()
	character_cards.clear()

## Setup objective display (Call DOWN)
func _setup_objective_display() -> void:
	if not current_battle_state or not objective_display:
		return
	
	# Get mission objective from battle state
	var mission_data: Resource = current_battle_state.mission_data
	if not mission_data:
		return
	
	var mission_type: String = _safe_get_property(mission_data, "mission_type", "opportunity")
	
	# Roll and display objective
	objective_display.roll_objective(mission_type)

## Setup morale tracker (Call DOWN)
func _setup_morale_tracker() -> void:
	if not current_battle_state or not morale_tracker:
		return
	
	# Set enemy count
	var enemy_count: int = current_battle_state.enemy_forces.size()
	morale_tracker.set_enemy_count(enemy_count)
	
	# Set base morale (default to 3, can be modified by deployment conditions)
	morale_tracker.set_base_morale(3)

# =====================================================
# CHILD SIGNAL HANDLERS (Signal UP from children)
# =====================================================

## Character card signals
func _on_character_action_used(character_name: String, action_type: String) -> void:
	"""Character used an action - signal up to game logic"""
	character_action_requested.emit(character_name, action_type)
	
	# If connected to BattleStateMachine, notify it
	if battle_state_machine:
		var character_node: Node = _find_character_node(character_name)
		if character_node:
			battle_state_machine.complete_unit_action()

func _on_character_damage_taken(character_name: String, amount: int) -> void:
	"""Character took damage - signal up"""
	character_damage_applied.emit(character_name, amount)
	
	# Check for casualty - trigger morale check if enemy killed
	var card: FPCM_CharacterStatusCard = character_cards.get(character_name)
	if card and card.is_casualty():
		# This is crew casualty - don't trigger morale check
		pass

func _on_character_stun_marked(character_name: String) -> void:
	"""Character stunned - signal up"""
	character_stun_added.emit(character_name)

func _on_character_selected_internal(character_name: String) -> void:
	"""Character selected - update UI highlighting"""
	selected_character = character_name
	_update_character_highlighting()
	character_selected.emit(character_name)

## Objective display signals
func _on_objective_acknowledged() -> void:
	"""Objective acknowledged - signal up"""
	objective_acknowledged.emit()

func _on_objective_rolled(objective: Variant) -> void:
	"""Objective rolled - log it"""
	if objective:
		print("Battle HUD: Objective rolled - ", objective)

## Morale tracker signals
func _on_morale_check_triggered(enemies_remaining: int, casualties: int) -> void:
	"""Morale check needed - auto-roll it"""
	if morale_tracker:
		var result: Dictionary = morale_tracker.roll_morale_check()
		morale_check_completed.emit(result)

func _on_enemies_fled(count: int) -> void:
	"""Enemies fled - signal up"""
	enemies_fled.emit(count)

func _on_panic_occurred(panic_type: String) -> void:
	"""Panic occurred - log it"""
	print("Battle HUD: Panic occurred - ", panic_type)

# =====================================================
# BATTLESTATEMACHINE SIGNAL HANDLERS (Listen to state)
# =====================================================

func _on_battle_state_changed(old_state: int, new_state: int) -> void:
	"""Battle state changed - update HUD"""
	print("Battle HUD: State changed from ", old_state, " to ", new_state)
	_queue_batch_update()

func _on_battle_phase_changed(old_phase: int, new_phase: int) -> void:
	"""Battle phase changed - update HUD"""
	print("Battle HUD: Phase changed from ", old_phase, " to ", new_phase)
	_queue_batch_update()

func _on_round_started(round_number: int) -> void:
	"""New round started - reset character actions"""
	print("Battle HUD: Round ", round_number, " started")
	
	# Reset all character cards (Call DOWN)
	for card in character_cards.values():
		if is_instance_valid(card):
			card.reset_round()
	
	# Reset morale tracker
	if morale_tracker:
		morale_tracker.new_round()

func _on_unit_action_completed(unit: Node, action: int) -> void:
	"""Unit completed action - update card"""
	if not unit:
		return
	
	var unit_name: String = _get_node_name(unit)
	var card: FPCM_CharacterStatusCard = character_cards.get(unit_name)
	
	if card:
		# Action already decremented by card itself
		_queue_batch_update()

# =====================================================
# PUBLIC UPDATE METHODS (Call DOWN from parent)
# =====================================================

## Update character health (called from external damage resolution)
func update_character_health(character_name: String, new_health: int) -> void:
	var card: FPCM_CharacterStatusCard = character_cards.get(character_name)
	if card:
		var current_health: int = card.current_health
		var damage: int = current_health - new_health
		if damage > 0:
			card.apply_damage(damage)
		elif damage < 0:
			card.heal(-damage)

## Update character stun
func add_character_stun(character_name: String) -> void:
	var card: FPCM_CharacterStatusCard = character_cards.get(character_name)
	if card:
		card.add_stun_marker()

## Register enemy casualty (triggers morale check)
func register_enemy_casualty() -> void:
	if morale_tracker:
		morale_tracker.add_casualty()
	enemy_casualty_registered.emit()

## Update morale modifier
func set_morale_modifier(modifier: int) -> void:
	if morale_tracker:
		morale_tracker.set_morale_modifier(modifier)

# =====================================================
# BATCH UPDATE SYSTEM (Performance optimization)
# =====================================================

func _queue_batch_update() -> void:
	"""Queue a batched UI update (60fps throttle)"""
	if update_batch_queued:
		return
	
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - last_update_time < UPDATE_THROTTLE:
		# Too soon, queue for next frame
		call_deferred("_execute_batch_update")
		update_batch_queued = true
	else:
		# Can update now
		_execute_batch_update()

func _execute_batch_update() -> void:
	"""Execute batched UI updates"""
	update_batch_queued = false
	last_update_time = Time.get_ticks_msec() / 1000.0
	
	# Update all components that need refresh
	_update_character_highlighting()

func _update_character_highlighting() -> void:
	"""Update character card highlighting based on selection"""
	for character_name in character_cards:
		var card: FPCM_CharacterStatusCard = character_cards[character_name]
		if not is_instance_valid(card):
			continue
		
		if character_name == selected_character:
			card.highlight()
		else:
			card.unhighlight()

# =====================================================
# HELPER METHODS
# =====================================================

func _get_character_name(character: Resource) -> String:
	"""Get character name from resource"""
	if not character:
		return "Unknown"
	
	# Try different property names
	for prop in ["character_name", "name", "crew_name"]:
		if prop in character:
			var value: Variant = character.get(prop)
			if value and value is String:
				return value
	
	return "Unknown"

func _get_node_name(node: Node) -> String:
	"""Get node name"""
	if not node:
		return ""
	return node.name

func _find_character_node(character_name: String) -> Node:
	"""Find character node (placeholder - depends on battle scene structure)"""
	# This would search the battle scene tree for the character node
	# For now, return null as we don't have battle scene integration yet
	return null

func _safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	"""Safe property access for Resources"""
	if obj == null:
		return default_value
	if obj is Object and property in obj:
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value

# =====================================================
# CLEANUP
# =====================================================

func _exit_tree() -> void:
	"""Cleanup on removal"""
	# Disconnect all signals
	if battle_state_machine:
		if battle_state_machine.state_changed.is_connected(_on_battle_state_changed):
			battle_state_machine.state_changed.disconnect(_on_battle_state_changed)
		if battle_state_machine.phase_changed.is_connected(_on_battle_phase_changed):
			battle_state_machine.phase_changed.disconnect(_on_battle_phase_changed)
		if battle_state_machine.round_started.is_connected(_on_round_started):
			battle_state_machine.round_started.disconnect(_on_round_started)
		if battle_state_machine.unit_action_completed.is_connected(_on_unit_action_completed):
			battle_state_machine.unit_action_completed.disconnect(_on_unit_action_completed)
	
	# Clear character cards
	_clear_crew_cards()
	
	# Null references
	battle_state_machine = null
	current_battle_state = null
