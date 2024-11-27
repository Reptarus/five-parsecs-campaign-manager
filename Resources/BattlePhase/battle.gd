class_name Battle
extends Node2D

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const Character = preload("res://Resources/CrewAndCharacters/Character.gd")
const Mission = preload("res://Resources/GameData/Mission.gd")
const BattleSystem = preload("res://Resources/BattlePhase/BattleSystem.gd")
const CombatManager = preload("res://Resources/BattlePhase/CombatManager.gd")
const AIController = preload("res://Resources/GameData/AIController.gd")

signal ui_update_needed(current_round: int, phase: GlobalEnums.BattlePhase, current_character: Character)
signal battlefield_generated(battlefield_data: Dictionary)
signal action_completed
signal tutorial_step_completed

@export_group("Grid Settings")
@export var GRID_SIZE: int = 32  # Size of each grid cell in pixels

@export_group("Battle Systems")
@export var battle_system: BattleSystem
@export var combat_manager: CombatManager
@export var ai_controller: AIController

@export_group("UI Elements")
@onready var tilemap: TileMap = $Battlefield/TileMap
@onready var units_node: Node2D = $Battlefield/Units
@onready var terrain_node: Node2D = $Battlefield/Terrain
@onready var highlights_node: Node2D = $Battlefield/Highlights
@onready var battle_grid: GridContainer = $Battlefield/BattleGrid

var ui_elements: Dictionary = {}
var game_state_manager: GameStateManager
var current_mission: Mission
var active_character: Character
var selected_action: String = ""
var valid_action_cells: Array[Vector2i] = []
var is_tutorial_battle: bool = false
var tutorial_step: int = 0
var tutorial_objectives: Array[String] = []

# Add resource management
var _battle_resources: Dictionary = {}
var _is_initialized: bool = false

func _ready() -> void:
	initialize_from_autoload()
	setup_signals()
	setup_ui()
	_setup_ui_elements()

func _setup_ui_elements() -> void:
	ui_elements = {
		"move_button": $UI/SidePanel/VBoxContainer/ActionButtons/MoveButton,
		"attack_button": $UI/SidePanel/VBoxContainer/ActionButtons/AttackButton,
		"end_turn_button": $UI/SidePanel/VBoxContainer/ActionButtons/EndTurnButton,
		"turn_label": $UI/SidePanel/VBoxContainer/TurnLabel,
		"current_character_label": $UI/SidePanel/VBoxContainer/CurrentCharacterLabel,
		"battle_log": $UI/SidePanel/VBoxContainer/BattleLog
	}

func initialize_from_autoload() -> void:
	game_state_manager = get_node("/root/GameStateManager") as GameStateManager
	if not game_state_manager:
		push_error("Failed to get GameStateManager")
		return
		
	current_mission = game_state_manager.game_state.current_mission
	is_tutorial_battle = current_mission.mission_type == GlobalEnums.MissionType.TUTORIAL

func initialize(game_state_manager: GameStateManager, mission: Mission) -> void:
	if _is_initialized:
		return
		
	self.game_state_manager = game_state_manager
	current_mission = mission
	
	_battle_resources = {
		"battle_system": BattleSystem.new(game_state_manager.game_state),
		"combat_manager": game_state_manager.combat_manager,
		"ai_controller": $AIController
	}
	
	if not _validate_resources():
		push_error("Failed to initialize battle resources")
		return
		
	setup_battle()
	_is_initialized = true

func cleanup() -> void:
	if _is_initialized:
		for resource in _battle_resources.values():
			if is_instance_valid(resource):
				resource.queue_free()
		_battle_resources.clear()
		_is_initialized = false

func _validate_resources() -> bool:
	return _battle_resources.values().all(func(resource): return is_instance_valid(resource))

# UI Setup and Management

func setup_ui() -> void:
	update_ui_state(false)  # Disable UI until battle starts
	setup_battle_grid()
	setup_action_buttons()

func setup_action_buttons() -> void:
	for button in ui_elements.values():
		if button is Button:
			button.disabled = true
			button.modulate = Color(1, 1, 1, 0.5)

func update_ui_state(enabled: bool) -> void:
	for element in ui_elements.values():
		if element is Control:
			element.visible = enabled
			if element is Button:
				element.disabled = not enabled

func update_character_ui(character: Character) -> void:
	ui_elements["current_character_label"].text = "Current Turn: " + character.name
	ui_elements["move_button"].disabled = not character.can_move()
	ui_elements["attack_button"].disabled = not character.can_attack()

func update_phase_ui(phase: GlobalEnums.BattlePhase) -> void:
	ui_elements["turn_label"].text = "Phase: " + GlobalEnums.BattlePhase.keys()[phase]

func add_battle_log_entry(text: String) -> void:
	var battle_log = ui_elements["battle_log"]
	battle_log.text += "\n" + text
	battle_log.scroll_vertical = battle_log.get_line_count()

# Battlefield Setup

func setup_battle() -> void:
	battle_system.start_battle(current_mission)
	setup_battlefield()
	if is_tutorial_battle:
		setup_tutorial()

func setup_battlefield() -> void:
	var battlefield_data = await battle_system.battlefield_generator.generate_battlefield(current_mission)
	create_terrain(battlefield_data.terrain)
	create_grid(battlefield_data.size)
	battlefield_generated.emit(battlefield_data)

func create_terrain(terrain_data: Array) -> void:
	for terrain in terrain_data:
		var terrain_node = create_terrain_node(terrain)
		self.terrain_node.add_child(terrain_node)

func create_terrain_node(terrain_data: Dictionary) -> Node2D:
	var node = Node2D.new()
	var sprite = Sprite2D.new()
	sprite.texture = load("res://Assets/Terrain/" + terrain_data.type.to_lower() + ".png")
	sprite.position = terrain_data.position * GRID_SIZE
	node.add_child(sprite)
	
	if terrain_data.has("collision"):
		var collision = CollisionShape2D.new()
		collision.shape = RectangleShape2D.new()
		collision.shape.size = Vector2(GRID_SIZE, GRID_SIZE)
		node.add_child(collision)
	
	return node

# Grid Management

func create_grid(size: Vector2) -> void:
	battle_grid.columns = int(size.x)
	for y in range(size.y):
		for x in range(size.x):
			var cell = create_grid_cell()
			battle_grid.add_child(cell)

func create_grid_cell() -> Control:
	var cell = Control.new()
	cell.custom_minimum_size = Vector2(GRID_SIZE, GRID_SIZE)
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.gui_input.connect(_on_grid_cell_input.bind(cell))
	return cell

func highlight_valid_actions(character: Character) -> void:
	clear_highlights()
	match selected_action:
		"move":
			valid_action_cells = combat_manager.get_valid_move_positions(character)
		"attack":
			valid_action_cells = combat_manager.get_valid_attack_positions(character)
	
	for pos in valid_action_cells:
		create_highlight(pos)

func create_highlight(_position: Vector2i) -> void:
	var highlight = Sprite2D.new()
	highlight.texture = load("res://Assets/UI/highlight.png")
	highlight.position = Vector2(position.x * GRID_SIZE, position.y * GRID_SIZE)
	highlights_node.add_child(highlight)

func clear_highlights() -> void:
	for child in highlights_node.get_children():
		child.queue_free()
	valid_action_cells.clear()

# Action Handling

func handle_move_action() -> void:
	selected_action = "move"
	highlight_valid_actions(active_character)

func handle_attack_action() -> void:
	selected_action = "attack"
	highlight_valid_actions(active_character)

func handle_end_turn() -> void:
	if active_character:
		combat_manager.end_turn(active_character)
		selected_action = ""
		clear_highlights()

func handle_grid_cell_clicked(cell: Control) -> void:
	if not active_character or selected_action.is_empty():
		return
		
	var grid_position = Vector2i(cell.get_index() % battle_grid.columns,
							   cell.get_index() / battle_grid.columns)
	
	if grid_position in valid_action_cells:
		match selected_action:
			"move":
				execute_move(grid_position)
			"attack":
				execute_attack(grid_position)

func execute_move(target_position: Vector2i) -> void:
	await combat_manager.move_character(active_character, target_position)
	selected_action = ""
	clear_highlights()
	action_completed.emit()

func execute_attack(target_position: Vector2i) -> void:
	var target = combat_manager.get_character_at_position(target_position)
	if target:
		await combat_manager.attack_character(active_character, target)
	selected_action = ""
	clear_highlights()
	action_completed.emit()

# Tutorial Management

func setup_tutorial() -> void:
	tutorial_step = 0
	tutorial_objectives = [
		"Move your character",
		"Attack an enemy",
		"End your turn"
	]
	show_tutorial_step()

func show_tutorial_step() -> void:
	if tutorial_step < tutorial_objectives.size():
		add_battle_log_entry("Tutorial: " + tutorial_objectives[tutorial_step])

func advance_tutorial() -> void:
	tutorial_step += 1
	if tutorial_step < tutorial_objectives.size():
		show_tutorial_step()
	tutorial_step_completed.emit()

# Signal Handlers

func _on_battle_started() -> void:
	update_ui_state(true)
	if is_tutorial_battle:
		show_tutorial_step()

func _on_battle_ended(victory: bool) -> void:
	update_ui_state(false)
	show_battle_results(victory)

func _on_turn_started(character: Character) -> void:
	active_character = character
	update_character_ui(character)
	highlight_valid_actions(character)

func _on_turn_ended(character: Character) -> void:
	clear_highlights()
	if character == active_character:
		active_character = null

func _on_phase_changed(new_phase: GlobalEnums.BattlePhase) -> void:
	update_phase_ui(new_phase)
	ui_update_needed.emit(battle_system.combat_manager.current_round, new_phase, active_character)

func _on_button_pressed(button: Button) -> void:
	match button.name:
		"MoveButton":
			handle_move_action()
		"AttackButton":
			handle_attack_action()
		"EndTurnButton":
			handle_end_turn()

func _on_grid_cell_input(event: InputEvent, cell: Control) -> void:
	if event is InputEventMouseButton and event.pressed:
		handle_grid_cell_clicked(cell)

func show_battle_results(victory: bool) -> void:
	var results_dialog = AcceptDialog.new()
	results_dialog.dialog_text = "Battle " + ("Won!" if victory else "Lost...")
	add_child(results_dialog)
	results_dialog.popup_centered()
	await results_dialog.confirmed
	results_dialog.queue_free()

func setup_signals() -> void:
	if not battle_system:
		return
		
	battle_system.battle_started.connect(_on_battle_started)
	battle_system.battle_ended.connect(_on_battle_ended)
	battle_system.turn_started.connect(_on_turn_started)
	battle_system.turn_ended.connect(_on_turn_ended)
	battle_system.phase_changed.connect(_on_phase_changed)
	
	for button in ui_elements.values():
		if button is Button:
			button.pressed.connect(_on_button_pressed.bind(button))

func setup_battle_grid() -> void:
	if not battle_grid:
		push_error("Battle grid not found")
		return
		
	battle_grid.custom_minimum_size = Vector2(GRID_SIZE * 10, GRID_SIZE * 10)  # Default size
	battle_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Clear existing cells
	for child in battle_grid.get_children():
		child.queue_free()
