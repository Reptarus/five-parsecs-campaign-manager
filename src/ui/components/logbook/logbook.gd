# Logbook.gd
extends SmartLogbook

# Responsive layout constants
const TOUCH_BUTTON_HEIGHT := 60.0 # Height for touch-friendly buttons
const PORTRAIT_LIST_HEIGHT_RATIO := 0.4 # Crew list takes 40% in portrait mode

@onready var crew_select := $MarginContainer/VBoxContainer/HBoxContainer/Sidebar/CrewSelect
@onready var entry_list := $MarginContainer/VBoxContainer/HBoxContainer/Sidebar/EntryList
@onready var entry_content := $MarginContainer/VBoxContainer/HBoxContainer/MainContent/EntryContent
@onready var notes_edit := $MarginContainer/VBoxContainer/HBoxContainer/MainContent/NotesEdit

# Responsive layout variables
var main_container: Control
var sidebar: Control

func _ready() -> void:
	super._ready()
	_setup_logbook()
	_connect_signals()
	_initialize_responsive_variables()

func _initialize_responsive_variables() -> void:
	# Initialize responsive layout variables
	main_container = $MarginContainer/VBoxContainer/HBoxContainer
	sidebar = $MarginContainer/VBoxContainer/HBoxContainer/Sidebar

func _setup_logbook() -> void:
	_setup_crew_selector()
	_setup_buttons()
	entry_list.add_to_group("touch_lists")

func _apply_portrait_layout() -> void:
	super._apply_portrait_layout()

	# Stack panels vertically
	if main_container:
		main_container.set("vertical", true)

	# Adjust panel sizes for portrait mode
	var viewport_height = get_viewport_rect().size.y
	if sidebar:
		sidebar.custom_minimum_size.y = viewport_height * PORTRAIT_LIST_HEIGHT_RATIO

	# Make controls touch-friendly
	_adjust_touch_sizes(true)

func _apply_landscape_layout() -> void:
	super._apply_landscape_layout()

	# Side by side layout
	if main_container:
		main_container.set("vertical", false)

	# Reset panel sizes
	if sidebar:
		sidebar.custom_minimum_size = Vector2(300, 0)

	# Reset control sizes
	_adjust_touch_sizes(false)

func _adjust_touch_sizes(is_portrait: bool) -> void:
	var button_height: float = TOUCH_BUTTON_HEIGHT if is_portrait else TOUCH_BUTTON_HEIGHT * 0.75

	# Adjust all buttons
	for button in get_tree().get_nodes_in_group("touch_buttons"):
		button.custom_minimum_size.y = button_height

	# Adjust crew selector
	crew_select.custom_minimum_size.y = button_height

	# Adjust list items
	entry_list.fixed_item_height = button_height

func _setup_crew_selector() -> void:
	crew_select.add_to_group("touch_controls")
	# Add crew members to selector
	pass

func _setup_buttons() -> void:
	var new_entry_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/Sidebar/ButtonsContainer/NewEntryButton
	var delete_entry_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/Sidebar/ButtonsContainer/DeleteEntryButton
	var export_button = $MarginContainer/VBoxContainer/HBoxContainer/Sidebar/ExportButton
	var back_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/Sidebar/BackButton
	var save_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/MainContent/SaveButton

	for button in [new_entry_button, delete_entry_button, export_button, back_button, save_button]:
		button.add_to_group("touch_buttons")
		button.custom_minimum_size.x = 150

func _connect_signals() -> void:
	# Connect existing signals
	pass

# Signal handlers for the original logbook functionality
func _on_crew_selected(index: int) -> void:
	# Handle crew selection
	pass

func _on_entry_selected(index: int) -> void:
	# Handle entry selection
	pass

func _on_new_entry_pressed() -> void:
	# Handle new entry creation
	pass

func _on_delete_entry_pressed() -> void:
	# Handle entry deletion
	pass

func _on_export_pressed() -> void:
	# Handle logbook export
	pass

func _on_back_pressed() -> void:
	# Handle back navigation
	pass

func _on_save_notes_pressed() -> void:
	# Handle notes saving
	pass