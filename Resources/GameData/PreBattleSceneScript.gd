class_name PreBattleSceneScript
extends Control

@onready var game_state: GameStateManager = get_node("/root/GameState")
var terrain_generator: TerrainGenerator

# Declare current_mission as a class variable
var current_mission: Mission

@onready var generate_terrain_button: Button = $GenerateTerrainButton
@onready var place_characters_button: Button = $PlaceCharactersButton
@onready var start_battle_button: Button = $StartBattleButton
@onready var back_button: Button = $BackButton

func _ready() -> void:
	generate_terrain_button.pressed.connect(_on_generate_terrain_pressed)
	place_characters_button.pressed.connect(_on_place_characters_pressed)
	start_battle_button.pressed.connect(_on_start_battle_pressed)
	back_button.pressed.connect(_on_back_pressed)

func initialize() -> void:
	terrain_generator = TerrainGenerator.new()
	terrain_generator.initialize(game_state)

func _on_generate_terrain_pressed() -> void:
	var battlefield_size := GlobalEnums.TerrainSize.MEDIUM  # 24" x 24" battlefield as per rules
	var terrain_type := GlobalEnums.TerrainGenerationType.INDUSTRIAL  # Assuming a default terrain type for generation
	terrain_generator.generate_terrain(battlefield_size, terrain_type)
	terrain_generator.generate_features([GlobalEnums.TerrainFeature.AREA], current_mission)
	terrain_generator.generate_cover()
	terrain_generator.generate_cover()
	terrain_generator.generate_loot()
	terrain_generator.generate_enemies()
	terrain_generator.generate_npcs()
	game_state.combat_manager.place_objectives()
	_visualize_battlefield()

func _on_place_characters_pressed() -> void:
	_place_characters()

func _on_start_battle_pressed() -> void:
	GameManager.new().start_battle(get_tree())
	queue_free()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Management/CampaignDashboard.tscn")

func _visualize_battlefield() -> void:
	var battlefield_generator = preload("res://Scenes/Management/Scenes/BattlefieldGenerator.tscn").instantiate()
	add_child(battlefield_generator)
	
	battlefield_generator.mission = current_mission
	battlefield_generator.terrain_generator = terrain_generator
	battlefield_generator.initialize()
	
	# Update labels with mission information
	battlefield_generator.mission_name_label.text = "Mission: %s" % current_mission.title
	battlefield_generator.mission_objective_label.text = "Objective: %s" % GlobalEnums.MissionObjective.keys()[current_mission.objective]
	
	var enemies_text := "Enemies:\n"
	for enemy in current_mission.get_enemies():
		enemies_text += "- %s x%d\n" % [enemy.name, enemy.count]
	battlefield_generator.mission_enemies_label.text = enemies_text
	
	var conditions_text := "Conditions:\n"
	for condition in current_mission.environmental_factors:
		conditions_text += "- %s\n" % condition
	battlefield_generator.battlefield_conditions_label.text = conditions_text
	
	# Generate and display the battlefield grid
	var battlefield_data = battlefield_generator.generate_battlefield(current_mission)
	battlefield_generator._generate_battlefield_grid(battlefield_data)

func _place_characters() -> void:
	var deployment_zone = _get_deployment_zone()
	var characters = game_state.current_crew.characters
	var placed_characters = []

	for character in characters:
		var valid_positions = _get_valid_positions(deployment_zone, placed_characters)
		if valid_positions.is_empty():
			print("Warning: No valid positions left for character deployment")
			break

		var char_position = _select_position(valid_positions)
		_place_character(character, char_position)
		placed_characters.append({"character": character, "position": char_position})

	_update_battlefield_display(placed_characters)

func _get_deployment_zone() -> Rect2:
	# Define deployment zone based on mission type and battlefield size
	# For now, we'll use a simple 6" deployment zone on one edge
	var battlefield_size = Vector2(24, 24)  # 24" x 24" as per Core Rules
	return Rect2(Vector2.ZERO, Vector2(6, battlefield_size.y))

func _get_valid_positions(deployment_zone: Rect2, placed_characters: Array) -> Array:
	var valid_positions = []
	for x in range(int(deployment_zone.size.x)):
		for y in range(int(deployment_zone.size.y)):
			var grid_pos = Vector2(x, y)
			if _is_position_valid(grid_pos, placed_characters):
				valid_positions.append(grid_pos)
	return valid_positions

func _is_position_valid(pos: Vector2, placed_characters: Array) -> bool:
	for placed in placed_characters:
		if placed.position.distance_to(pos) < 1:  # Ensure 1" spacing between characters
			return false
	return true

func _select_position(valid_positions: Array) -> Vector2:
	# For now, we'll just select a random valid position
	# In the future, this could be replaced with player input
	return valid_positions[randi() % valid_positions.size()]

func _place_character(character: Character, char_position: Vector2) -> void:
	character.position = char_position
	print("Placed %s at position %s" % [character.name, char_position])

func _update_battlefield_display(placed_characters: Array) -> void:
	# Update the visual representation of the battlefield
	# This involves updating the UI to show character positions
	var battlefield_grid = $MarginContainer/VBoxContainer/HBoxContainer2/VBoxContainer2/AspectRatioContainer/BattlefieldGrid
	var cell_size = Vector2(32, 32)  # CELL_SIZE from BattlefieldGenerator

	for placed in placed_characters:
		var character_node = ColorRect.new()
		character_node.color = Color.BLUE
		character_node.size = cell_size
		character_node.position = placed.position * cell_size
		battlefield_grid.add_child(character_node)

	print("Updated battlefield display with %d characters" % placed_characters.size())

# Additional helper functions can be added here as needed

func load_current_mission() -> Mission:
	var mission_manager = MissionManager.new(game_state)
	var available_missions = mission_manager.get_available_missions()
	
	if available_missions.is_empty():
		# If no missions are available, generate a new one
		var new_missions = mission_manager.generate_missions()
		if new_missions.is_empty():
			push_error("Failed to generate any missions")
			return null
		return new_missions[0]
	else:
		# Return the first available mission
		return available_missions[0]
