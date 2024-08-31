# CrewSetup.gd
extends Control

signal crew_size_selected(size: int)

@onready var character_creation = $CharacterCreation
@onready var ship_creation = $ShipCreation
@onready var gear_selection = $GearSelection
@onready var finish_button = $FinishButton
@onready var size_slider: HSlider = $SizeSlider
@onready var size_label: Label = $SizeLabel
@onready var crew_visual: Control = $CrewVisualwVisual

var game_state: GameState
var crew: Crew
var ship: Ship
var min_crew_size: int = 3
var max_crew_size: int = 8
var current_size: int = 5

func _ready() -> void:
	game_state = get_node("/root/Main").game_state
	character_creation.connect("character_created", Callable(self, "_on_character_created"))
	ship_creation.connect("ship_created", Callable(self, "_on_ship_created"))
	gear_selection.connect("gear_selected", Callable(self, "_on_gear_selected"))
	finish_button.connect("pressed", Callable(self, "_on_finish_button_pressed"))
	size_slider.min_value = min_crew_size
	size_slider.max_value = max_crew_size
	size_slider.value = current_size
	update_ui()
	size_slider.value_changed.connect(_on_size_changed)

func _on_size_changed(new_size: float) -> void:
	current_size = int(new_size)
	update_ui()

func update_ui() -> void:
	size_label.text = str(current_size) + " Members"
	update_crew_visual()

func update_crew_visual() -> void:
	for i in range(max_crew_size):
		var member_icon: TextureRect = crew_visual.get_child(i)
		member_icon.visible = i < current_size

func _on_confirm_pressed() -> void:
	crew_size_selected.emit(current_size)

func start_crew_setup():
	crew = Crew.new()
	character_creation.show()
	ship_creation.hide()
	gear_selection.hide()
	finish_button.hide()

func _on_character_created(character: Character):
	crew.add_member(character)
	if crew.get_member_count() < 6:
		character_creation.reset()
	else:
		character_creation.hide()
		ship_creation.show()

func _on_ship_created(new_ship: Ship):
	ship = new_ship
	ship_creation.hide()
	gear_selection.show()

func _on_gear_selected(gear: Array):
	for item in gear:
		crew.add_equipment(item)
	gear_selection.hide()
	finish_button.show()

func _on_finish_button_pressed():
	game_state.set_current_crew(crew)
	game_state.set_ship(ship)
	# Transition to the main game screen or campaign dashboard
	get_tree().change_scene_to_file("res://scenes/CampaignDashboard.tscn")
