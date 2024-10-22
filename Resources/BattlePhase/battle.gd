class_name Battle
extends Node2D

var game_state_manager: MockGameState
var current_mission: Mission
var combat_manager: CombatManager
var ai_controller: AIController
var battlefield_generator: BattlefieldGenerator
var active_character: Character

@onready var tilemap: TileMap = $Battlefield/TileMap
@onready var units_node: Node2D = $Battlefield/Units
@onready var terrain_node: Node2D = $Battlefield/Terrain
@onready var highlights_node: Node2D = $Battlefield/Highlights
@onready var move_button: Button = $UI/SidePanel/VBoxContainer/ActionButtons/MoveButton
@onready var attack_button: Button = $UI/SidePanel/VBoxContainer/ActionButtons/AttackButton
@onready var end_turn_button: Button = $UI/SidePanel/VBoxContainer/ActionButtons/EndTurnButton
@onready var turn_label: Label = $UI/SidePanel/VBoxContainer/TurnLabel
@onready var current_character_label: Label = $UI/SidePanel/VBoxContainer/CurrentCharacterLabel
@onready var battle_log: TextEdit = $UI/SidePanel/VBoxContainer/BattleLog
@onready var battle_grid: GridContainer = $Battlefield/BattleGrid

func _ready() -> void:
	if not game_state_manager:
		var potential_game_state = get_node("/root/GameStateManager")
		if potential_game_state is MockGameState:
			game_state_manager = potential_game_state
		else:
			push_error("Node at /root/GameStateManager is not of type MockGameState")
	if not game_state_manager:
		push_error("Failed to get MockGameState")
	if not game_state_manager or not game_state_manager is GameStateManager:
		push_error("Failed to get GameStateManager")
		return
	current_mission = game_state_manager.current_mission
	combat_manager = game_state_manager.combat_manager
	ai_controller = $AIController as AIController
	battlefield_generator = $BattlefieldGenerator as BattlefieldGenerator
	
	if not ai_controller or not battlefield_generator:
		push_error("Failed to get AIController or BattlefieldGenerator")
		return
	
	combat_manager.initialize(game_state_manager, current_mission, tilemap)
	ai_controller.initialize(combat_manager, game_state_manager)
	
	_initialize_battlefield()
	_connect_signals()

func _initialize_battlefield() -> void:
	var battlefield_data = battlefield_generator.generate_battlefield(current_mission)
	_create_terrain(battlefield_data.terrain)
	_create_units(battlefield_data.player_positions, battlefield_data.enemy_positions)

func _create_terrain(terrain_data: Array) -> void:
	for terrain in terrain_data:
		var terrain_shape = ColorRect.new()
		terrain_shape.color = Color(0.2, 0.2, 0.2, 0.5)
		terrain_shape.size = terrain.size
		terrain_shape.position = terrain.position
		terrain_node.add_child(terrain_shape)

func _create_units(player_positions: Array, enemy_positions: Array) -> void:
	for i in range(game_state_manager.current_ship.crew.size()):
		var _character = game_state_manager.current_ship.crew[i]
		var unit_shape = ColorRect.new()
		unit_shape.color = Color.BLUE
		unit_shape.size = Vector2(20, 20)
		unit_shape.position = player_positions[i]
		units_node.add_child(unit_shape)

	var enemies = current_mission.get_enemies()
	for i in range(min(enemy_positions.size(), enemies.size())):
		var enemy = enemies[i]
		var unit_shape = ColorRect.new()
		unit_shape.color = Color.RED
		unit_shape.size = Vector2(20, 20)
		unit_shape.position = enemy_positions[i]
		units_node.add_child(unit_shape)
		
		var name_label = Label.new()
		name_label.text = enemy.name
		name_label.position = enemy_positions[i] + Vector2(0, -20)
		units_node.add_child(name_label)

func _connect_signals() -> void:
	combat_manager.combat_started.connect(_on_combat_started)
	combat_manager.combat_ended.connect(_on_combat_ended)
	combat_manager.turn_started.connect(_on_turn_started)
	combat_manager.turn_ended.connect(_on_turn_ended)
	combat_manager.ui_update_needed.connect(_on_ui_update_needed)
	combat_manager.log_action.connect(_on_log_action)
	combat_manager.character_moved.connect(_on_character_moved)
	combat_manager.enable_player_controls.connect(_on_enable_player_controls)
	combat_manager.update_turn_label.connect(_on_update_turn_label)
	combat_manager.update_current_character_label.connect(_on_update_current_character_label)
	combat_manager.highlight_valid_positions.connect(_on_highlight_valid_positions)

func highlight_valid_positions(positions: Array) -> void:
	for pos in positions:
		var highlight = ColorRect.new()
		highlight.color = Color(0, 1, 0, 0.3)
		highlight.size = Vector2(20, 20)
		highlight.position = pos
		highlights_node.add_child(highlight)

func highlight_valid_targets(targets: Array) -> void:
	for target in targets:
		var highlight = ColorRect.new()
		highlight.color = Color(1, 0, 0, 0.3)
		highlight.size = Vector2(20, 20)
		highlight.position = target.position
		highlights_node.add_child(highlight)

func clear_highlights() -> void:
	for child in highlights_node.get_children():
		child.queue_free()

func wait_for_player_input() -> Vector2:
	while true:
		if Input.is_action_just_pressed("left_click"):
			return get_viewport().get_mouse_position()
		await get_tree().process_frame
	return Vector2.ZERO

func _get_move_input() -> Vector2:
	var valid_positions = combat_manager.get_valid_move_positions(active_character)
	highlight_valid_positions(valid_positions)
	
	var selected_position = await wait_for_player_input()
	
	clear_highlights()
	return selected_position

func _get_attack_target() -> Character:
	var valid_targets = combat_manager.get_valid_targets(active_character)
	highlight_valid_targets(valid_targets)
	
	var selected_position = await wait_for_player_input()
	var selected_target = combat_manager.get_character_at_position(selected_position)
	
	clear_highlights()
	return selected_target

func _on_move_button_pressed() -> void:
	if active_character:
		var new_position = await _get_move_input()
		if new_position:
			combat_manager.handle_move(active_character, new_position)

func _on_attack_button_pressed() -> void:
	if active_character:
		var target = await _get_attack_target()
		if target:
			combat_manager.handle_attack(active_character, target)

func _on_end_turn_button_pressed() -> void:
	combat_manager.handle_end_turn()

func _on_combat_started() -> void:
	print("Combat started")

func _on_combat_ended(player_victory: bool) -> void:
	print("Combat ended. Player victory: ", player_victory)
	game_state_manager.end_battle(player_victory, get_tree())

func _on_turn_started(character: Character) -> void:
	active_character = character
	print("Turn started for ", character.name)
	if character in game_state_manager.current_ship.crew:
		enable_player_controls()
	else:
		disable_player_controls()
		ai_controller.perform_ai_turn(character)

func _on_turn_ended(character: Character) -> void:
	print("Turn ended for ", character.name)
	active_character = null

func _on_ui_update_needed(current_round: int, phase: GlobalEnums.CampaignPhase, current_character: Character) -> void:
	print("UI update needed. Round: ", current_round, " Phase: ", phase, " Current character: ", current_character.name)

func _on_log_action(action: String) -> void:
	battle_log.text += action + "\n"

func _on_character_moved(character: Character, new_position: Vector2i) -> void:
	print("Character ", character.name, " moved to ", new_position)
	# Update the character's visual position on the battlefield

func _on_enable_player_controls(_character: Character) -> void:
	enable_player_controls()

func _on_update_turn_label(_round: int) -> void:
	turn_label.text = "Round: " + str(_round)

func _on_update_current_character_label(character_name: String) -> void:
	current_character_label.text = "Current Character: " + character_name

func _on_highlight_valid_positions(positions: Array[Vector2i]) -> void:
	highlight_valid_positions(positions)

func enable_player_controls() -> void:
	move_button.disabled = false
	attack_button.disabled = false
	end_turn_button.disabled = false

func disable_player_controls() -> void:
	move_button.disabled = true
	attack_button.disabled = true
	end_turn_button.disabled = true

func handle_character_damage(character: Character, damage: int) -> void:
	character.health -= damage
	if character.health <= 0:
		character.status = GlobalEnums.CharacterStatus.DEAD
		# Handle character defeat (remove from battlefield, etc.)

func handle_character_recovery() -> void:
	game_state_manager.handle_character_recovery()
