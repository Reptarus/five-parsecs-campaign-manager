# CrewSetup.gd
extends Control

@onready var size_slider: HSlider = $SizeSlider
@onready var size_label: Label = $SizeLabel
@onready var crew_visual: Control = $CrewVisual
@onready var character_creation: Control = $CharacterCreation
@onready var crew_name_input: LineEdit = $CrewNameInput

var game_state_manager: GameStateManagerNode
var game_state: GameState
var crew: Crew
var min_crew_size: int = 3
var max_crew_size: int = 8
var current_size: int = 5

func _ready() -> void:
	game_state_manager = get_node("/root/GameState")
	if not game_state_manager:
		push_error("GameStateManagerNode not found. Make sure it's properly set up as an AutoLoad.")
		return
	
	game_state = game_state_manager.game_state
	if not game_state:
		push_error("GameState not found in GameStateManagerNode.")
		return
	
	size_slider.min_value = min_crew_size
	size_slider.max_value = max_crew_size
	size_slider.value = current_size
	update_ui()
	size_slider.value_changed.connect(_on_size_changed)
	
	character_creation.hide()

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
			member_panel.gui_input.connect(_on_member_panel_clicked.bind(i))

func _on_member_panel_clicked(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		start_character_creation(index)

func start_character_creation(index: int) -> void:
	character_creation.show()
	character_creation.initialize(index)

func _on_character_created(character: Character) -> void:
	if !crew:
		crew = Crew.new()
	crew.add_member(character)
	if crew.get_member_count() < current_size:
		character_creation.reset()
	else:
		finish_crew_creation()

func finish_crew_creation() -> void:
	game_state.set_current_crew(crew)
	game_state.set_crew_size(current_size)
	game_state.transition_to_state(GameState.State.UPKEEP)
	get_tree().change_scene_to_file("res://Scenes/Management/CampaignDashboard.tscn")

# This function is no longer needed in CrewSetup.gd
# The crew name input has been moved to ShipCreation.tscn and ShipCreation.gd

func set_difficulty_settings(settings: DifficultySettings) -> void:
	game_state.difficulty_settings = settings

func set_optional_feature(feature_name: String, is_enabled: bool) -> void:
	if feature_name in GlobalEnums:
		game_state.set(feature_name, is_enabled)
