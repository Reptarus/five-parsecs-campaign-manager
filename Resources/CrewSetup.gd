# CrewSetup.gd
extends Control

@onready var size_slider: HSlider = $SizeSlider
@onready var size_label: Label = $SizeLabel
@onready var crew_visual: Control = $CrewVisual
@onready var character_creation = $CharacterCreation

var game_state: GameState
var crew: Crew
var min_crew_size: int = 3
var max_crew_size: int = 8
var current_size: int = 5

func _ready() -> void:
	game_state = get_node("/root/Main").game_state
	size_slider.min_value = min_crew_size
	size_slider.max_value = max_crew_size
	size_slider.value = current_size
	update_ui()
	size_slider.value_changed.connect(_on_size_changed)
	
	# Hide character creation initially
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
	# Transition to the main game screen or campaign dashboard
	get_tree().change_scene_to_file("res://scenes/CampaignDashboard.tscn")
