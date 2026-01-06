class_name FPCM_QuickStartDialog
extends Control

# GlobalEnums available as autoload singleton
const Character = preload("res://src/core/character/Character.gd")

# Dialog Types
enum DialogType {
	INFO,
	WARNING,
	ERROR,
	CONFIRMATION,
	INPUT
}

signal import_requested(data: Dictionary)
signal template_selected(template_name: String)
signal victory_achieved(victory: bool, message: String)

@onready var import_button := $VBoxContainer/ImportButton
@onready var template_list := $VBoxContainer/TemplateList
@onready var crew_size_dropdown := $VBoxContainer/CrewSizeDropdown

# Gesture management
var gesture_manager: Resource = null

# Crew size options
var crew_size_options: Array[int] = [1, 2, 3, 4, 5, 6]

var templates: Dictionary = {}

func _ready() -> void:
	setup_ui()
	load_default_settings()
	import_button.pressed.connect(_on_import_pressed)
	load_templates()

func setup_ui() -> void:
	# Setup crew size dropdown
	crew_size_dropdown.clear()
	for size in crew_size_options:
		crew_size_dropdown.add_item(str(size), size)
	crew_size_dropdown.select(2) # Default to 3 crew members

func load_default_settings() -> void:
	# Load default campaign settings
	pass

func _setup_gesture_support() -> void:
	if not Engine.is_editor_hint():
		gesture_manager = Resource.new()
		# Gesture manager setup would go here

func _setup_mobile_ui() -> void:
	# Mobile UI setup
	pass

func _get_crew_size_from_enum(crew_size_enum: int) -> int:
	match crew_size_enum:
		0: return 1 # SOLO
		1: return 2 # DUO
		2: return 3 # TRIO
		3: return 4 # QUARTET
		4: return 5 # QUINTET
		5: return 6 # SEXTET
		_: return 3 # Default to trio

func _get_crew_size_enum(size: int) -> int:
	match size:
		1: return 0 # SOLO
		2: return 1 # DUO
		3: return 2 # TRIO
		4: return 3 # QUARTET
		5: return 4 # QUINTET
		6: return 5 # SEXTET
		_: return 2 # Default to trio

func load_templates() -> void:
	templates = {
		"quick_start": {
			"name": "Quick Start",
			"description": "Begin with a basic crew and minimal resources",
			"crew_size": 3, # FOUR
			"starting_credits": 500,
			"difficulty": 1
		},
		"experienced": {
			"name": "Experienced Crew",
			"description": "Start with a larger, more experienced crew",
			"crew_size": 4, # FIVE
			"starting_credits": 1000,
			"difficulty": 2
		},
		"veteran": {
			"name": "Veteran Crew",
			"description": "Maximum crew size with veteran status",
			"crew_size": 5, # SIX
			"starting_credits": 1500,
			"difficulty": 3
		}
	}
	_populate_templates()

func _populate_templates() -> void:
	template_list.clear()
	for template_name in templates:
		if not OS.has_feature("mobile") or templates[template_name]["mobile_friendly"]:
			template_list.add_item(template_name)

func _on_swipe(direction: Vector2) -> void:
	if direction.y > 0.8: # Swipe down
		hide()
	elif direction.x != 0: # Horizontal swipe
		var current_index = template_list.get_selected_items()[0] if template_list.get_selected_items().size() > 0 else -1
		current_index += 1 if direction.x > 0 else -1
		current_index = clamp(current_index, 0, template_list.item_count - 1)
		template_list.select(current_index)
		_on_template_selected(current_index)

func _on_long_press(position: Vector2) -> void:
	var item_at_pos = template_list.get_item_at_position(position)
	if item_at_pos >= 0:
		var template_name = template_list.get_item_text(item_at_pos)
		_show_template_details(template_name)

func _on_import_pressed() -> void:
	var file_dialog := FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.json", "Campaign Data")
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)
	file_dialog.popup_centered()

func _on_file_selected(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	var parse_result = json.parse(file.get_as_text())
	file.close()
	if parse_result == OK:
		import_requested.emit(json.data)
	else:
		push_error("Failed to parse import file")

func _on_template_selected(index: int) -> void:
	var template_name = template_list.get_item_text(index)
	template_selected.emit(template_name)

func _show_template_details(template_name: String) -> void:
	if template_name in templates:
		var details = templates[template_name]
		# Show details implementation
		pass

func _on_campaign_victory_achieved(victory_type: int) -> void:
	var victory_message := ""
	match victory_type:
		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_50K:
			victory_message = "You've amassed great wealth!"
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_10:
			victory_message = "Your reputation precedes you!"
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_20:
			victory_message = "You've become a dominant force!"
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5:
			victory_message = "You've completed your epic journey!"

	victory_achieved.emit(true, victory_message)
