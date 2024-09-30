# CrewSetup.gd
extends Control

@onready var size_slider: HSlider = $SizeSlider
@onready var size_label: Label = $SizeLabel
@onready var crew_visual: Control = $CrewVisual
@onready var character_creation = $CharacterCreation
@onready var crew_name_input: LineEdit = $CrewNameInput

var game_state_manager_node: GameStateManagerNode
var game_state: GameStateManager
var crew: Crew
var min_crew_size: int = 3
var max_crew_size: int = 8
var current_size: int = 5

func _ready() -> void:
	game_state_manager_node = get_node("/root/GameStateManagerNode")
	if not game_state_manager_node:
		push_error("GameStateManagerNode not found. Make sure it's properly set up as an AutoLoad.")
		return
	
	game_state = game_state_manager_node.get_game_state()
	if not game_state:
		push_error("GameState not found in GameStateManagerNode.")
		return
	
	size_slider.min_value = min_crew_size
	size_slider.max_value = max_crew_size
	size_slider.value = current_size
	update_ui()
	size_slider.value_changed.connect(_on_size_changed)
	
	# Hide character creation initially
	character_creation.hide()
	
	# Connect crew name input
	crew_name_input.text_changed.connect(_on_crew_name_changed)

func _on_size_changed(new_size: float) -> void:
	current_size = int(new_size)
	update_ui()

func update_ui() -> void:
	size_label.text = str(current_size) + " Members"
	update_crew_visual()

func update_crew_visual() -> void:
	for i in range(max_crew_size):
		var member_panel: TextureRect = crew_visual.get_child(i)
		member_panel.visible = i < current_size
		if member_panel.visible:
			member_panel.connect("gui_input", Callable(self, "_on_member_panel_clicked").bind(i))

func _on_member_panel_clicked(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		start_character_creation(index)

func start_character_creation(index: int) -> void:
	character_creation.show()
	character_creation.initialize(index)

func _on_character_created(character) -> void:
	if !crew:
		crew = Crew.new()
	crew.add_character(character)
	if crew.get_character_count() < current_size:
		character_creation.reset()
	else:
		finish_crew_creation()

func finish_crew_creation() -> void:
	game_state.set_current_crew(crew)
	game_state.set_crew_size(current_size)
	# Transition to the main game screen or campaign dashboard
	get_tree().change_scene_to_file("res://scenes/CampaignDashboard.tscn")

func set_crew_name(name: String) -> void:
	if not crew:
		crew = Crew.new()
	crew.name = name

func set_difficulty_settings(settings: DifficultySettings) -> void:
	game_state.difficulty_settings = settings

func set_optional_feature(feature_name: String, is_enabled: bool) -> void:
	if game_state.has("use_" + feature_name):
		game_state.set("use_" + feature_name, is_enabled)

func _on_crew_name_changed(new_name: String):
	set_crew_name(new_name)
