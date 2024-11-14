class_name InitialCrewCreation
extends CampaignResponsiveLayout

const Character = preload("res://Resources/CrewAndCharacters/Character.gd")
const CharacterCreator = preload("res://Resources/CrewAndCharacters/CharacterCreator.gd")
const CrewManager = preload("res://Resources/CrewAndCharacters/CrewManager.gd")

signal crew_creation_completed(crew: Array[Character])
signal crew_creation_cancelled

const TOUCH_BUTTON_HEIGHT := 60
const PORTRAIT_PREVIEW_HEIGHT_RATIO := 0.4  # Preview takes 40% in portrait mode

@onready var crew_columns := $HBoxContainer/LeftPanel/Panel/VBoxContainer/CharacterColumns
@onready var crew_preview := $HBoxContainer/RightPanel/Panel/MarginContainer/VBoxContainer/ScrollContainer/CrewPreview

var character_creator: CharacterCreator
var crew_manager: CrewManager

func _ready() -> void:
	super._ready()
	character_creator = CharacterCreator.new()
	crew_manager = CrewManager.new()
	_setup_crew_creation()
	_connect_signals()

func _setup_crew_creation() -> void:
	_setup_crew_columns()
	_setup_crew_preview()
	_setup_buttons()

func _apply_portrait_layout() -> void:
	super._apply_portrait_layout()
	
	# Stack panels vertically
	main_container.set("orientation", BaseContainer.Orientation.VERTICAL)
	
	# Adjust panel sizes for portrait mode
	var viewport_height = get_viewport_rect().size.y
	crew_columns.custom_minimum_size.y = viewport_height * (1 - PORTRAIT_PREVIEW_HEIGHT_RATIO)
	crew_preview.custom_minimum_size.y = viewport_height * PORTRAIT_PREVIEW_HEIGHT_RATIO
	
	# Make controls touch-friendly
	_adjust_touch_sizes(true)

func _apply_landscape_layout() -> void:
	super._apply_landscape_layout()
	
	# Side by side layout
	main_container.set("orientation", BaseContainer.Orientation.HORIZONTAL)
	
	# Reset panel sizes
	crew_columns.custom_minimum_size = Vector2(600, 0)
	crew_preview.custom_minimum_size = Vector2(300, 0)
	
	# Reset control sizes
	_adjust_touch_sizes(false)

func _adjust_touch_sizes(is_portrait: bool) -> void:
	var button_height = TOUCH_BUTTON_HEIGHT if is_portrait else TOUCH_BUTTON_HEIGHT * 0.75
	
	# Adjust all buttons
	for button in get_tree().get_nodes_in_group("touch_buttons"):
		button.custom_minimum_size.y = button_height
	
	# Adjust character boxes
	for box in get_tree().get_nodes_in_group("character_boxes"):
		box.custom_minimum_size.y = button_height * 1.5

func _setup_crew_columns() -> void:
	for column in crew_columns.get_children():
		for character_box in column.get_children():
			character_box.add_to_group("character_boxes")
			character_box.pressed.connect(_on_character_box_pressed.bind(character_box))

func _setup_crew_preview() -> void:
	crew_preview.initialize(crew_manager.get_crew())

func _setup_buttons() -> void:
	var confirm_button = $HBoxContainer/LeftPanel/Panel/VBoxContainer/ConfirmButton
	confirm_button.add_to_group("touch_buttons")
	confirm_button.pressed.connect(_on_confirm_pressed)

func _on_character_box_pressed(box: Button) -> void:
	var character = crew_manager.get_character(box.get_index())
	if character:
		character_creator.edit_character(character)
	else:
		push_error("No character found at index: " + str(box.get_index()))

func _on_confirm_pressed() -> void:
	if crew_manager.validate_crew():
		crew_creation_completed.emit(crew_manager.get_crew())
	else:
		OS.alert("You need at least " + str(crew_manager.min_crew_size) + " crew members.")
