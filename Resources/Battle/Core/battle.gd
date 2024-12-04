extends Node2D

# Required classes
const Character = preload("res://Resources/CrewAndCharacters/Character.gd")
const Mission = preload("res://Resources/GameData/Mission.gd")
const AIController = preload("res://Resources/GameData/AIController.gd")

# Battle systems
@export_group("Battle Systems")
@export var battle_system: Node  # Will be set to BattleSystem at runtime
@export var combat_manager: Node  # Will be set to CombatManager at runtime
@export var ai_controller: Node  # Will be set to AIController at runtime

# UI elements
@export_group("UI Elements")
@export var ui_elements: Dictionary = {
	"turn_label": null,
	"phase_label": null,
	"character_info": null,
	"action_buttons": null,
	"battle_log": null,
	"end_turn_button": null,
	"attack_button": null,
	"move_button": null,
	"ability_button": null
}

# Battle state
var _is_initialized: bool = false
var game_state_manager: Node  # Will be set at runtime
var current_mission: Mission
var active_character: Character
var is_tutorial_battle: bool = false

signal ui_update_needed(current_round: int, phase: int, current_character: Character)
signal battlefield_generated(battlefield_data: Dictionary)
signal action_completed
signal tutorial_step_completed

func _ready() -> void:
	if not _validate_required_nodes():
		push_error("Required nodes not found in battle scene")
		return
		
	current_mission = game_state_manager.game_state.current_mission
	is_tutorial_battle = current_mission.mission_type == GlobalEnums.MissionType.TUTORIAL

func initialize(game_state_manager: Node, mission: Mission) -> void:
	if _is_initialized:
		push_warning("Battle already initialized")
		return
	
	self.game_state_manager = game_state_manager
	self.current_mission = mission
	
	battle_system.initialize(game_state_manager, mission)
	combat_manager.initialize(game_state_manager, mission, $Battlefield, battle_system)
	ai_controller.initialize(game_state_manager, mission, combat_manager)
	
	_connect_signals()
	_setup_ui()
	_is_initialized = true

func _validate_required_nodes() -> bool:
	for key in ui_elements:
		if not ui_elements[key]:
			push_error("Missing UI element: " + key)
			return false
	return true

func _connect_signals() -> void:
	if not _is_initialized:
		battle_system.connect("phase_changed", _on_phase_changed)
		battle_system.connect("turn_started", _on_turn_started)
		battle_system.connect("turn_ended", _on_turn_ended)
		
		combat_manager.connect("character_moved", _on_character_moved)
		combat_manager.connect("action_completed", _on_action_completed)
		combat_manager.connect("enable_player_controls", _on_enable_player_controls)
		
		ai_controller.connect("ai_turn_completed", _on_ai_turn_completed)

func _setup_ui() -> void:
	ui_elements["end_turn_button"].pressed.connect(_on_end_turn_pressed)
	ui_elements["attack_button"].pressed.connect(_on_attack_pressed)
	ui_elements["move_button"].pressed.connect(_on_move_pressed)
	ui_elements["ability_button"].pressed.connect(_on_ability_pressed)
	
	# Initially disable all action buttons
	_disable_action_buttons()

func update_character_ui(character: Character) -> void:
	if not character:
		_disable_action_buttons()
		return
		
	ui_elements["character_info"].text = _format_character_info(character)
	ui_elements["attack_button"].disabled = not character.can_attack()
	ui_elements["move_button"].disabled = not character.can_move()
	ui_elements["ability_button"].disabled = not character.has_available_abilities()

func update_phase_ui(phase: int) -> void:
	var phase_names = {
		GlobalEnums.BattlePhase.SETUP: "Setup",
		GlobalEnums.BattlePhase.DEPLOYMENT: "Deployment",
		GlobalEnums.BattlePhase.BATTLE: "Battle",
		GlobalEnums.BattlePhase.RESOLUTION: "Resolution",
		GlobalEnums.BattlePhase.CLEANUP: "Cleanup"
	}
	ui_elements["phase_label"].text = "Phase: " + phase_names.get(phase, "Unknown")

func add_battle_log_entry(text: String) -> void:
	var battle_log = ui_elements["battle_log"]
	battle_log.text += text + "\n"
	battle_log.scroll_vertical = battle_log.get_line_count()

func _format_character_info(character: Character) -> String:
	return """
	Name: %s
	Health: %d/%d
	Action Points: %d/%d
	Status: %s
	""" % [
		character.name,
		character.current_health,
		character.max_health,
		character.current_ap,
		character.max_ap,
		character.get_status_text()
	]

func _disable_action_buttons() -> void:
	ui_elements["attack_button"].disabled = true
	ui_elements["move_button"].disabled = true
	ui_elements["ability_button"].disabled = true
	ui_elements["end_turn_button"].disabled = true

# Signal handlers
func _on_phase_changed(new_phase: int) -> void:
	update_phase_ui(new_phase)
	ui_update_needed.emit(battle_system.combat_manager.current_round, new_phase, active_character)

func _on_turn_started(character: Character) -> void:
	active_character = character
	update_character_ui(character)
	if character.is_player_controlled:
		_enable_player_controls()
	else:
		_disable_action_buttons()
		ai_controller.start_ai_turn(character)

func _on_turn_ended(character: Character) -> void:
	if character == active_character:
		active_character = null
		update_character_ui(null)

func _on_character_moved(character: Character, new_position: Vector2i) -> void:
	if character == active_character:
		update_character_ui(character)

func _on_action_completed() -> void:
	if active_character and active_character.is_player_controlled:
		update_character_ui(active_character)
	action_completed.emit()

func _on_enable_player_controls(character: Character) -> void:
	if character == active_character and character.is_player_controlled:
		_enable_player_controls()

func _on_ai_turn_completed() -> void:
	battle_system.end_turn()

func _enable_player_controls() -> void:
	if not active_character or not active_character.is_player_controlled:
		return
		
	ui_elements["attack_button"].disabled = not active_character.can_attack()
	ui_elements["move_button"].disabled = not active_character.can_move()
	ui_elements["ability_button"].disabled = not active_character.has_available_abilities()
	ui_elements["end_turn_button"].disabled = false

# Button handlers
func _on_attack_pressed() -> void:
	if active_character and active_character.can_attack():
		combat_manager.start_attack(active_character)

func _on_move_pressed() -> void:
	if active_character and active_character.can_move():
		combat_manager.start_movement(active_character)

func _on_ability_pressed() -> void:
	if active_character and active_character.has_available_abilities():
		combat_manager.show_ability_menu(active_character)

func _on_end_turn_pressed() -> void:
	if active_character and active_character.is_player_controlled:
		battle_system.end_turn()
