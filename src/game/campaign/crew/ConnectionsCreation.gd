extends Control

signal connections_completed(connections: Array)
signal connections_cancelled

const TOUCH_BUTTON_HEIGHT = 64
const PORTRAIT_LIST_HEIGHT_RATIO = 0.5 # List takes 50% in portrait mode

@onready var name_input := $VBoxContainer/HBoxContainer/NameInput
@onready var relationship_dropdown := $VBoxContainer/HBoxContainer/RelationshipDropdown
@onready var connections_list := $VBoxContainer/ConnectionsList
@onready var extended_toggle := $VBoxContainer/ExtendedConnectionsToggle
@onready var tutorial_label := $TutorialLabel

var current_connections := []

func _ready() -> void:
	_setup_connections_ui()
	_connect_signals()

func _setup_connections_ui() -> void:
	_setup_input_fields()
	_setup_buttons()
	_populate_relationship_types()

func _apply_portrait_layout() -> void:
	# Stack elements vertically
	$VBoxContainer.set("vertical", true)
	
	# Adjust list size for portrait mode
	var viewport_height = get_viewport_rect().size.y
	connections_list.custom_minimum_size.y = viewport_height * PORTRAIT_LIST_HEIGHT_RATIO
	
	# Make controls touch-friendly
	_adjust_touch_sizes(true)
	
	# Adjust margins for mobile
	$VBoxContainer.add_theme_constant_override("margin_left", 10)
	$VBoxContainer.add_theme_constant_override("margin_right", 10)

func _apply_landscape_layout() -> void:
	# Reset to default layout
	$VBoxContainer.set("vertical", false)
	
	# Reset list size
	connections_list.custom_minimum_size = Vector2(0, 300)
	
	# Reset control sizes
	_adjust_touch_sizes(false)
	
	# Reset margins
	$VBoxContainer.add_theme_constant_override("margin_left", 20)
	$VBoxContainer.add_theme_constant_override("margin_right", 20)

func _adjust_touch_sizes(is_portrait: bool) -> void:
	var button_height = TOUCH_BUTTON_HEIGHT if is_portrait else TOUCH_BUTTON_HEIGHT * 0.75
	
	# Adjust all buttons
	for button in get_tree().get_nodes_in_group("touch_buttons"):
		button.custom_minimum_size.y = button_height
	
	# Adjust input fields
	name_input.custom_minimum_size.y = button_height
	relationship_dropdown.custom_minimum_size.y = button_height

func _setup_input_fields() -> void:
	name_input.add_to_group("touch_controls")
	relationship_dropdown.add_to_group("touch_controls")

func _setup_buttons() -> void:
	var add_button = $VBoxContainer/AddConnectionButton
	var finalize_button = $VBoxContainer/FinalizeButton
	
	for button in [add_button, finalize_button]:
		button.add_to_group("touch_buttons")
		button.custom_minimum_size = Vector2(200, TOUCH_BUTTON_HEIGHT)

func _populate_relationship_types() -> void:
	var relationships = [
		"Friend",
		"Rival",
		"Mentor",
		"Student",
		"Family",
		"Business Partner"
	]
	
	for type in relationships:
		relationship_dropdown.add_item(type)

func _connect_signals() -> void:
	var add_button = $VBoxContainer/AddConnectionButton
	var finalize_button = $VBoxContainer/FinalizeButton
	
	add_button.pressed.connect(_on_add_connection)
	finalize_button.pressed.connect(_on_finalize)
	extended_toggle.toggled.connect(_on_extended_toggled)

func _on_add_connection() -> void:
	var connection = {
		"name": name_input.text,
		"relationship": relationship_dropdown.get_item_text(relationship_dropdown.selected)
	}
	
	current_connections.append(connection)
	_update_connections_list()
	name_input.text = ""

func _on_finalize() -> void:
	connections_completed.emit(current_connections)

func _on_extended_toggled(enabled: bool) -> void:
	# Add or remove extended relationship types
	if enabled:
		_add_extended_relationships()
	else:
		_remove_extended_relationships()

func _update_connections_list() -> void:
	# Update the visual list of connections
	pass

func _add_extended_relationships() -> void:
	# Add additional relationship types
	pass

func _remove_extended_relationships() -> void:
	# Remove extended relationship types
	pass
