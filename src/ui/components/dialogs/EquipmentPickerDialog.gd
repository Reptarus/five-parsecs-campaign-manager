class_name EquipmentPickerDialog
extends Window

## Equipment Picker Dialog
## Allows selecting equipment items from available inventory

signal equipment_selected(item_id: String)
signal selection_cancelled

# UI Elements
var item_list: ItemList
var confirm_button: Button
var cancel_button: Button
var filter_option: OptionButton
var search_input: LineEdit

# Data
var available_equipment: Array[Dictionary] = []
var filtered_equipment: Array[Dictionary] = []
var selected_item_id: String = ""
var current_filter: String = "all"

# Equipment categories
const EQUIPMENT_CATEGORIES = ["all", "weapons", "armor", "gear", "consumables"]

# Default equipment database — Core Rules items as fallback
const DEFAULT_EQUIPMENT = [
	{"id": "hand_gun", "name": "Hand Gun", "category": "weapons", "bonus": 0},
	{"id": "military_rifle", "name": "Military Rifle", "category": "weapons", "bonus": 1},
	{"id": "plasma_rifle", "name": "Plasma Rifle", "category": "weapons", "bonus": 2},
	{"id": "blade", "name": "Blade", "category": "weapons", "bonus": 0},
	{"id": "shotgun", "name": "Shotgun", "category": "weapons", "bonus": 1},
	{"id": "combat_armor", "name": "Combat Armor", "category": "armor", "bonus": 1},
	{"id": "frag_vest", "name": "Frag Vest", "category": "armor", "bonus": 0},
	{"id": "screen_generator", "name": "Screen Generator", "category": "armor", "bonus": 1},
	{"id": "booster_pills", "name": "Booster Pills", "category": "consumables", "bonus": 0},
	{"id": "stim_pack", "name": "Stim-pack", "category": "consumables", "bonus": 0},
	{"id": "motion_tracker", "name": "Motion Tracker", "category": "gear", "bonus": 1},
	{"id": "battle_visor", "name": "Battle Visor", "category": "gear", "bonus": 1},
	{"id": "jump_belt", "name": "Jump Belt", "category": "gear", "bonus": 1},
	{"id": "communicator", "name": "Communicator", "category": "gear", "bonus": 1}
]

func _init() -> void:
	title = "Select Equipment"
	size = Vector2i(400, 500)
	unresizable = false
	close_requested.connect(_on_cancel_pressed)

func _ready() -> void:
	_build_ui()
	_load_equipment()
	_apply_filter()

func _build_ui() -> void:
	## Build the dialog UI programmatically
	var main_container = VBoxContainer.new()
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 10)
	add_child(main_container)

	# Add margins
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	main_container.add_child(margin)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	# Search bar
	var search_container = HBoxContainer.new()
	content.add_child(search_container)

	var search_label = Label.new()
	search_label.text = "Search:"
	search_container.add_child(search_label)

	search_input = LineEdit.new()
	search_input.placeholder_text = "Type to search..."
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.text_changed.connect(_on_search_changed)
	search_container.add_child(search_input)

	# Filter dropdown
	var filter_container = HBoxContainer.new()
	content.add_child(filter_container)

	var filter_label = Label.new()
	filter_label.text = "Category:"
	filter_container.add_child(filter_label)

	filter_option = OptionButton.new()
	for category in EQUIPMENT_CATEGORIES:
		filter_option.add_item(category.capitalize())
	filter_option.item_selected.connect(_on_filter_changed)
	filter_container.add_child(filter_option)

	# Item list
	item_list = ItemList.new()
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.custom_minimum_size = Vector2(0, 300)
	item_list.item_selected.connect(_on_item_selected)
	item_list.item_activated.connect(_on_item_activated)
	content.add_child(item_list)

	# Button container
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_END
	button_container.add_theme_constant_override("separation", 10)
	content.add_child(button_container)

	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_container.add_child(cancel_button)

	confirm_button = Button.new()
	confirm_button.text = "Select"
	confirm_button.disabled = true
	confirm_button.pressed.connect(_on_confirm_pressed)
	button_container.add_child(confirm_button)

func _load_equipment() -> void:
	## Load equipment from database or use defaults
	available_equipment = DEFAULT_EQUIPMENT.duplicate(true)

func _apply_filter() -> void:
	## Apply current filter and search to equipment list
	filtered_equipment.clear()
	item_list.clear()

	var search_term = search_input.text.to_lower() if search_input else ""

	for item in available_equipment:
		# Apply category filter
		if current_filter != "all" and item.category != current_filter:
			continue

		# Apply search filter
		if not search_term.is_empty():
			var item_name = item.name.to_lower()
			if not item_name.contains(search_term):
				continue

		filtered_equipment.append(item)
		var display_text = "%s (%s)" % [item.name, item.category.capitalize()]
		if item.bonus > 0:
			display_text += " +%d" % item.bonus
		item_list.add_item(display_text)

func _on_filter_changed(index: int) -> void:
	current_filter = EQUIPMENT_CATEGORIES[index]
	_apply_filter()

func _on_search_changed(_new_text: String) -> void:
	_apply_filter()

func _on_item_selected(index: int) -> void:
	if index >= 0 and index < filtered_equipment.size():
		selected_item_id = filtered_equipment[index].id
		confirm_button.disabled = false

func _on_item_activated(index: int) -> void:
	## Double-click to select immediately
	_on_item_selected(index)
	_on_confirm_pressed()

func _on_confirm_pressed() -> void:
	if not selected_item_id.is_empty():
		equipment_selected.emit(selected_item_id)
		queue_free()

func _on_cancel_pressed() -> void:
	selection_cancelled.emit()
	queue_free()

## Get the display name for an equipment ID
static func get_equipment_name(item_id: String) -> String:
	for item in DEFAULT_EQUIPMENT:
		if item.id == item_id:
			return item.name
	return item_id.capitalize().replace("_", " ")
