class_name Battle
extends Node2D

var game_state_manager: GameStateManager
var current_mission: Mission
var combat_manager: CombatManager
var ai_controller: AIController
var active_character: Character

var is_tutorial_battle: bool = false
var tutorial_step: int = 0
var tutorial_objectives: Array[String] = []

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

var battlefield_generator: BattlefieldGenerator

const TUTORIAL_ENEMY_TYPES = {
	"Basic": {
		"type": "Gangers",
		"numbers": 2,
		"panic": "1-2",
		"speed": 4,
		"combat_skill": 0,
		"toughness": 3,
		"ai": "A",
		"weapons": "1 A"
	},
	"Elite": {
		"type": "Black Ops Team",
		"numbers": 0,
		"panic": "1",
		"speed": 6,
		"combat_skill": 2,
		"toughness": 5,
		"ai": "T",
		"weapons": "3 A"
	}
}

func _ready() -> void:
	if not game_state_manager:
		var potential_game_state = get_node("/root/GameStateManager")
		if potential_game_state:
			game_state_manager = potential_game_state
		else:
			push_error("GameStateManager not found")
			return
		
	current_mission = game_state_manager.current_mission
	combat_manager = game_state_manager.combat_manager
	ai_controller = $AIController as AIController
	battlefield_generator = BattlefieldGenerator.new()
	
	if not ai_controller:
		push_error("Failed to get AIController")
		return
		
	combat_manager.initialize(game_state_manager, current_mission, game_state_manager.get_current_battlefield())
	ai_controller.initialize(combat_manager, game_state_manager)
	
	_initialize_battlefield()
	_connect_signals()

func _initialize_battlefield() -> void:
	if battlefield_generator:
		var battlefield_data = battlefield_generator.generate_battlefield(current_mission)
		_create_terrain(battlefield_data.terrain)
		_create_units(battlefield_data.player_positions, battlefield_data.enemy_positions)
	else:
		push_error("BattlefieldGenerator not initialized")

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
	combat_manager.end_combat(player_victory)  # Add victory parameter
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

func initialize_tutorial_battle() -> void:
	is_tutorial_battle = true
	tutorial_step = 0
	tutorial_objectives = [
		"Move your character",
		"Attack an enemy",
		"Use cover",
		"End your turn"
	]
	_setup_tutorial_scenario()

func _setup_tutorial_scenario() -> void:
	# Set up a simplified battle for tutorial
	var tutorial_enemies = [
		{"type": "Basic", "position": Vector2(10, 5)},
		{"type": "Basic", "position": Vector2(12, 7)}
	]
	
	var tutorial_terrain = [
		{"type": "Cover", "position": Vector2(5, 5)},
		{"type": "Cover", "position": Vector2(8, 8)}
	]
	
	_create_tutorial_battlefield(tutorial_enemies, tutorial_terrain)

func advance_tutorial_step() -> void:
	tutorial_step += 1
	if tutorial_step < tutorial_objectives.size():
		_highlight_tutorial_objective(tutorial_objectives[tutorial_step])
		
		# Check for special tutorial events from data
		var tutorial_data = load("res://data/Tutorials/quick_start_tutorial.json").get_data()
		var current_step = tutorial_data.steps[tutorial_step]
		
		if current_step.has("battle_setup"):
			_setup_tutorial_battle_step(current_step.battle_setup)
	else:
		complete_tutorial()

func _highlight_tutorial_objective(objective: String) -> void:
	# Update UI to show current objective
	if battle_log:
		battle_log.text += "\nTutorial: " + objective

func complete_tutorial() -> void:
	is_tutorial_battle = false
	# Notify tutorial system of completion
	if game_state_manager:
		game_state_manager.tutorial_manager.complete_battle_tutorial()

func _create_tutorial_battlefield(tutorial_enemies: Array, tutorial_terrain: Array) -> void:
	# Clear existing battlefield
	for child in terrain_node.get_children():
		child.queue_free()
	for child in units_node.get_children():
		child.queue_free()
	
	# Create tutorial terrain based on data
	for terrain in tutorial_terrain:
		var terrain_piece = _create_terrain_piece(terrain)
		terrain_node.add_child(terrain_piece)
	
	# Create tutorial enemies based on data
	for enemy in tutorial_enemies:
		var enemy_unit = _create_enemy_unit(enemy)
		units_node.add_child(enemy_unit)

func _create_terrain_piece(terrain_data: Dictionary) -> Node3D:
	var terrain_piece = Node3D.new()
	var collision_shape = CollisionShape3D.new()
	var mesh_instance = MeshInstance3D.new()
	
	# Set up based on terrain type from data
	match terrain_data.type:
		"Cover":
			mesh_instance.mesh = load("res://assets/meshes/cover_block.tres")
			collision_shape.shape = BoxShape3D.new()
		"Objective":
			mesh_instance.mesh = load("res://assets/meshes/objective_marker.tres")
			collision_shape.shape = CylinderShape3D.new()
		_:
			mesh_instance.mesh = load("res://assets/meshes/generic_terrain.tres")
			collision_shape.shape = BoxShape3D.new()
	
	terrain_piece.position = terrain_data.position
	terrain_piece.add_child(collision_shape)
	terrain_piece.add_child(mesh_instance)
	return terrain_piece

func _create_enemy_unit(enemy_data: Dictionary) -> Character:
	var enemy_type = TUTORIAL_ENEMY_TYPES[enemy_data.type]
	var enemy_unit = game_state_manager.character_factory.create_enemy(enemy_type.type)
	
	# Apply tutorial-specific modifications
	enemy_unit.position = enemy_data.position
	enemy_unit.combat_skill = enemy_type.combat_skill
	enemy_unit.toughness = enemy_type.toughness
	enemy_unit.speed = enemy_type.speed
	
	# Set up AI behavior based on data
	enemy_unit.ai_behavior = enemy_type.ai
	
	# Add weapons based on data
	var weapons = _parse_weapon_string(enemy_type.weapons)
	for weapon in weapons:
		enemy_unit.add_weapon(weapon)
	
	return enemy_unit

func _parse_weapon_string(weapon_string: String) -> Array:
	var parts = weapon_string.split(" ")
	var count = int(parts[0])
	var tier = parts[1]
	
	var weapons = []
	var weapon_data = load("res://data/equipment_database.json").get_data()
	
	for i in range(count):
		var available_weapons = weapon_data.weapons.filter(
			func(w): return w.type == tier
		)
		if available_weapons.size() > 0:
			weapons.append(available_weapons[randi() % available_weapons.size()])
	
	return weapons

func _setup_tutorial_battle_step(battle_setup: Dictionary) -> void:
	# Configure battle based on tutorial data
	var enemy_count = battle_setup.get("enemy_count", 2)
	var enemy_type = battle_setup.get("enemy_type", "Basic")
	var deployment = battle_setup.get("deployment", "basic")
	var _objective = battle_setup.get("objective", "fight_off")
	
	# Create enemies
	var enemies = []
	for i in range(enemy_count):
		var enemy_data = {
			"type": enemy_type,
			"position": _get_deployment_position(deployment, i)
		}
		enemies.append(enemy_data)
	
	# Set up battlefield
	_create_tutorial_battlefield(enemies, _generate_tutorial_terrain(deployment))

func _get_deployment_position(deployment_type: String, index: int) -> Vector2:
	match deployment_type:
		"basic":
			return Vector2(10 + (index * 3), 5)
		"line":
			return Vector2(15, 3 + (index * 2))
		"flank":
			return Vector2(5 + (index * 2), 10)
		_:
			return Vector2(10, 5)

func _generate_tutorial_terrain(deployment_type: String) -> Array:
	var terrain = []
	match deployment_type:
		"basic":
			terrain.append({"type": "Cover", "position": Vector2(5, 5)})
			terrain.append({"type": "Cover", "position": Vector2(8, 8)})
		"line":
			terrain.append({"type": "Cover", "position": Vector2(12, 4)})
			terrain.append({"type": "Cover", "position": Vector2(12, 8)})
		"flank":
			terrain.append({"type": "Cover", "position": Vector2(4, 8)})
			terrain.append({"type": "Cover", "position": Vector2(8, 8)})
		_:
			terrain.append({"type": "Cover", "position": Vector2(5, 5)})
	
	return terrain