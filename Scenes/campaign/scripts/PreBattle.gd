class_name PreBattle
extends Control

var game_state: GameState
var battlefield_generator: BattlefieldGenerator

@onready var generate_terrain_button: Button = $MarginContainer/VBoxContainer/GenerateTerrainButton
@onready var place_characters_button: Button = $MarginContainer/VBoxContainer/PlaceCharactersButton
@onready var start_battle_button: Button = $MarginContainer/VBoxContainer/StartBattleButton
@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton

func _ready() -> void:
	generate_terrain_button.pressed.connect(_on_generate_terrain_pressed)
	place_characters_button.pressed.connect(_on_place_characters_pressed)
	start_battle_button.pressed.connect(_on_start_battle_pressed)
	back_button.pressed.connect(_on_back_pressed)

func initialize(state: GameState) -> void:
	game_state = state
	battlefield_generator = BattlefieldGenerator.new(game_state)

func _on_generate_terrain_pressed() -> void:
	var battlefield: Dictionary = battlefield_generator.generate_battlefield(game_state.current_mission.type)
	# TODO: Visualize the generated battlefield

func _on_place_characters_pressed() -> void:
	# TODO: Implement character placement logic

func _on_start_battle_pressed() -> void:
	var battle_scene: PackedScene = load("res://scenes/Battle.tscn")
	var battle: Battle = battle_scene.instantiate()
	battle.initialize(game_state)
	get_tree().root.add_child(battle)
	queue_free()

func _on_back_pressed() -> void:
	# TODO: Implement logic to return to the previous screen
	pass
