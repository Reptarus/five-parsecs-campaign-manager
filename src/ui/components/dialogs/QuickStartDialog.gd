@tool
extends Control
class_name QuickStartDialog

## A dialog for quickly starting a new campaign with templates or importing data
## Provides template selection, mobile-friendly UI, and gesture support

const Self = preload("res://src/ui/components/dialogs/QuickStartDialog.gd")
const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const GestureManager = preload("res://src/ui/components/gesture/GestureManager.gd")

## Emitted when campaign data is imported
signal import_requested(data: Dictionary)
## Emitted when a template is selected
signal template_selected(template_name: String)
## Emitted when a victory condition is achieved
signal victory_achieved(victory: bool, message: String)

## UI Components
@onready var import_button: Button = $VBoxContainer/ImportButton if has_node("VBoxContainer/ImportButton") else null
@onready var template_list: ItemList = $VBoxContainer/TemplateList if has_node("VBoxContainer/TemplateList") else null
@onready var gesture_manager: Object = null

## Available campaign templates
var templates: Dictionary = {}

## Initializes the dialog with default options and connects signals
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_ensure_ui_components()
		
	if not is_properly_initialized():
		push_error("QuickStartDialog: Failed to initialize - UI components not found")
		return
		
	_setup_gesture_support()
	_setup_mobile_ui()
	
	if import_button:
		if import_button.pressed.is_connected(_on_import_pressed):
			import_button.pressed.disconnect(_on_import_pressed)
		import_button.pressed.connect(_on_import_pressed)
	
	load_templates()

## Ensures that all required UI components exist
func _ensure_ui_components() -> void:
	if not has_node("VBoxContainer"):
		var vbox = VBoxContainer.new()
		vbox.name = "VBoxContainer"
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(vbox)
		
		if not import_button:
			import_button = Button.new()
			import_button.name = "ImportButton"
			import_button.text = "Import Campaign"
			import_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vbox.add_child(import_button)
		
		if not template_list:
			template_list = ItemList.new()
			template_list.name = "TemplateList"
			template_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			template_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
			template_list.select_mode = ItemList.SELECT_SINGLE
			template_list.allow_reselect = true
			template_list.auto_height = true
			template_list.item_clicked.connect(_on_template_clicked)
			vbox.add_child(template_list)

## Handles template clicked event
func _on_template_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	_on_template_selected(index)

## Sets up gesture support for mobile devices
func _setup_gesture_support() -> void:
	if Engine.is_editor_hint():
		return
		
	if GestureManager:
		gesture_manager = GestureManager.new()
		add_child(gesture_manager)
		
		if gesture_manager:
			if gesture_manager.has_signal("swipe_detected") and not gesture_manager.swipe_detected.is_connected(_on_swipe):
				gesture_manager.swipe_detected.connect(_on_swipe)
			if gesture_manager.has_signal("long_press_detected") and not gesture_manager.long_press_detected.is_connected(_on_long_press):
				gesture_manager.long_press_detected.connect(_on_long_press)

## Sets up UI adjustments for mobile devices
func _setup_mobile_ui() -> void:
	if not OS.has_feature("mobile"):
		return
		
	var viewport = get_viewport()
	if not viewport:
		push_warning("QuickStartDialog: Viewport not available for mobile UI setup")
		return
		
	var viewport_size = viewport.get_visible_rect().size
	custom_minimum_size = Vector2(0, viewport_size.y * 0.8)
	position = Vector2(0, viewport_size.y * 0.2)
	
	if template_list:
		template_list.add_theme_constant_override("v_separation", 20)
		template_list.add_theme_constant_override("h_separation", 20)

## Loads available campaign templates
func load_templates() -> void:
	templates = {
		"Solo Campaign": {
			"crew_size": GameEnums.CrewSize.FOUR,
			"difficulty": GameEnums.DifficultyLevel.NORMAL,
			"victory_condition": GameEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL,
			"mobile_friendly": true
		},
		"Standard Campaign": {
			"crew_size": GameEnums.CrewSize.FIVE,
			"difficulty": GameEnums.DifficultyLevel.NORMAL,
			"victory_condition": GameEnums.FiveParcsecsCampaignVictoryType.REPUTATION_GOAL,
			"mobile_friendly": true
		},
		"Challenge Campaign": {
			"crew_size": GameEnums.CrewSize.SIX,
			"difficulty": GameEnums.DifficultyLevel.HARDCORE,
			"victory_condition": GameEnums.FiveParcsecsCampaignVictoryType.FACTION_DOMINANCE,
			"mobile_friendly": false
		}
	}
	_populate_templates()

## Populates the template list with available templates
func _populate_templates() -> void:
	if not template_list:
		push_warning("QuickStartDialog: template_list is null, cannot populate templates")
		return
		
	template_list.clear()
	for template_name in templates:
		if not OS.has_feature("mobile") or templates[template_name]["mobile_friendly"]:
			template_list.add_item(template_name)

## Handles swipe gestures
## @param direction: The direction vector of the swipe
func _on_swipe(direction: Vector2) -> void:
	if not template_list:
		return
		
	if direction.y > 0.8: # Swipe down
		hide()
	elif direction.x != 0: # Horizontal swipe
		var current_index = template_list.get_selected_items()[0] if template_list.get_selected_items().size() > 0 else -1
		current_index += 1 if direction.x > 0 else -1
		current_index = clamp(current_index, 0, template_list.item_count - 1)
		template_list.select(current_index)
		_on_template_selected(current_index)

## Handles long press gestures
## @param position: The position of the long press
func _on_long_press(position: Vector2) -> void:
	if not template_list:
		return
		
	var item_at_pos = template_list.get_item_at_position(position)
	if item_at_pos >= 0:
		var template_name = template_list.get_item_text(item_at_pos)
		_show_template_details(template_name)

## Handles import button press
func _on_import_pressed() -> void:
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.json", "Campaign Data")
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)
	file_dialog.popup_centered()

## Handles file selection from the file dialog
## @param path: The selected file path
func _on_file_selected(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("QuickStartDialog: Failed to open file: " + path)
		return
		
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	if parse_result == OK:
		import_requested.emit(json.data)
	else:
		push_error("QuickStartDialog: Failed to parse import file: " + json.get_error_message())

## Handles template selection
## @param index: The index of the selected template
func _on_template_selected(index: int) -> void:
	if not template_list:
		push_warning("QuickStartDialog: template_list is null, cannot select template")
		return
		
	if index < 0 or index >= template_list.item_count:
		push_warning("QuickStartDialog: Invalid template index: " + str(index))
		return
		
	var template_name = template_list.get_item_text(index)
	template_selected.emit(template_name)

## Shows details for a selected template
## @param template_name: The name of the template to show details for
func _show_template_details(template_name: String) -> void:
	if not templates.has(template_name):
		push_warning("QuickStartDialog: Unknown template: " + template_name)
		return
		
	var details = templates[template_name]
	# Show details implementation
	# This could be implemented with a popup or details panel
	pass

## Handles campaign victory achievement
## @param victory_type: The type of victory achieved
func _on_campaign_victory_achieved(victory_type: int) -> void:
	var victory_message := ""
	match victory_type:
		GameEnums.FiveParcsecsCampaignVictoryType.WEALTH_GOAL:
			victory_message = "You've amassed great wealth!"
		GameEnums.FiveParcsecsCampaignVictoryType.REPUTATION_GOAL:
			victory_message = "Your reputation precedes you!"
		GameEnums.FiveParcsecsCampaignVictoryType.FACTION_DOMINANCE:
			victory_message = "You've become a dominant force!"
		GameEnums.FiveParcsecsCampaignVictoryType.STORY_COMPLETE:
			victory_message = "You've completed your epic journey!"
	
	victory_achieved.emit(true, victory_message)

## Checks if the component is properly initialized
## @return: True if all required components are valid
func is_properly_initialized() -> bool:
	return import_button != null and template_list != null
