extends PanelContainer
class_name ShipStashPanel

## Ship Stash Panel - Manages equipment stored on the ship
## PHASE 2: Ship stash integration with crew equipment system
##
## Five Parsecs Rules:
## - Ship can store up to 10 items in stash
## - Items can be transferred between crew and ship
## - Stash persists across missions

signal item_transferred_to_crew(equipment_id: String, character_id: String)
signal item_transferred_to_stash(equipment_id: String)
signal stash_updated()

# UI References
var stash_list: VBoxContainer
var stash_count_label: Label
var capacity_bar: ProgressBar
var transfer_button: Button
var crew_dropdown: OptionButton

# Data
var equipment_manager: Node = null
var current_crew: Array = []
var selected_item_index: int = -1

# Constants
const MAX_STASH_SIZE: int = 10

func _ready() -> void:
	_setup_ui()
	_connect_to_equipment_manager()
	call_deferred("_refresh_display")

func _setup_ui() -> void:
	## Create the ship stash UI layout
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	
	# Header
	var header = HBoxContainer.new()
	var title = Label.new()
	title.text = "Ship Stash"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	header.add_child(title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	stash_count_label = Label.new()
	stash_count_label.text = "0 / %d items" % MAX_STASH_SIZE
	stash_count_label.add_theme_font_size_override("font_size", 14)
	header.add_child(stash_count_label)
	
	main_vbox.add_child(header)
	
	# Capacity bar
	capacity_bar = ProgressBar.new()
	capacity_bar.min_value = 0
	capacity_bar.max_value = MAX_STASH_SIZE
	capacity_bar.value = 0
	capacity_bar.custom_minimum_size.y = 8
	capacity_bar.show_percentage = false
	main_vbox.add_child(capacity_bar)
	
	# Stash list in scroll container
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	stash_list = VBoxContainer.new()
	stash_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stash_list.add_theme_constant_override("separation", 4)
	scroll.add_child(stash_list)
	
	main_vbox.add_child(scroll)
	
	# Transfer controls
	var transfer_section = VBoxContainer.new()
	transfer_section.add_theme_constant_override("separation", 8)
	
	var transfer_label = Label.new()
	transfer_label.text = "Transfer Selected To:"
	transfer_label.add_theme_font_size_override("font_size", 12)
	transfer_section.add_child(transfer_label)
	
	var transfer_controls = HBoxContainer.new()
	transfer_controls.add_theme_constant_override("separation", 8)
	
	crew_dropdown = OptionButton.new()
	crew_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crew_dropdown.custom_minimum_size.x = 150
	transfer_controls.add_child(crew_dropdown)
	
	transfer_button = Button.new()
	transfer_button.text = "Transfer"
	transfer_button.custom_minimum_size = Vector2(100, 48)  # 48px touch target minimum
	transfer_button.disabled = true
	transfer_button.pressed.connect(_on_transfer_pressed)
	transfer_controls.add_child(transfer_button)
	
	transfer_section.add_child(transfer_controls)
	main_vbox.add_child(transfer_section)
	
	add_child(main_vbox)
	
	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)

func _connect_to_equipment_manager() -> void:
	## Connect to the EquipmentManager autoload
	equipment_manager = get_node_or_null("/root/EquipmentManager")
	if equipment_manager:
		if equipment_manager.has_signal("equipment_list_updated"):
			if not equipment_manager.equipment_list_updated.is_connected(_on_equipment_list_updated):
				equipment_manager.equipment_list_updated.connect(_on_equipment_list_updated)
		print("ShipStashPanel: Connected to EquipmentManager")
	else:
		push_warning("ShipStashPanel: EquipmentManager not found")

func set_crew_data(crew: Array) -> void:
	## Set the crew data for transfer dropdown
	current_crew = crew
	_update_crew_dropdown()

func _update_crew_dropdown() -> void:
	## Update the crew dropdown with current crew members
	if not crew_dropdown:
		return
	
	crew_dropdown.clear()
	crew_dropdown.add_item("Select Crew Member", -1)
	
	for i in range(current_crew.size()):
		var member = current_crew[i]
		# Sprint 26.3: Character-Everywhere - crew members are always Character objects
		var name: String = member.character_name if "character_name" in member else (member.name if "name" in member else str(member))

		crew_dropdown.add_item(name, i)
	
	crew_dropdown.select(0)

func _refresh_display() -> void:
	## Refresh the stash display
	if not stash_list:
		return
	
	# Clear existing items
	for child in stash_list.get_children():
		child.queue_free()
	
	# Get stash items from equipment manager
	var stash_items: Array = []
	if equipment_manager and equipment_manager.has_method("get_ship_stash"):
		stash_items = equipment_manager.get_ship_stash()
	
	# Update count and capacity
	var count = stash_items.size()
	if stash_count_label:
		stash_count_label.text = "%d / %d items" % [count, MAX_STASH_SIZE]
		
		# Color based on capacity
		if count >= MAX_STASH_SIZE:
			stash_count_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		elif count >= MAX_STASH_SIZE - 2:
			stash_count_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
		else:
			stash_count_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_PRIMARY)
	
	if capacity_bar:
		capacity_bar.value = count
	
	# Add stash items to display
	if stash_items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No items in ship stash"
		empty_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stash_list.add_child(empty_label)
	else:
		for i in range(stash_items.size()):
			var item = stash_items[i]
			var item_row = _create_stash_item_row(item, i)
			stash_list.add_child(item_row)
	
	# Update transfer button state
	_update_transfer_button_state()

func _create_stash_item_row(item: Dictionary, index: int) -> PanelContainer:
	## Create a UI row for a stash item
	var panel = PanelContainer.new()
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	
	# Selection checkbox/radio
	var select_btn = CheckBox.new()
	select_btn.button_group = _get_or_create_button_group()
	select_btn.toggled.connect(_on_item_selected.bind(index))
	hbox.add_child(select_btn)
	
	# Item name
	var name_label = Label.new()
	name_label.text = item.get("name", "Unknown Item")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 13)
	hbox.add_child(name_label)
	
	# Item type
	var type_label = Label.new()
	var item_type: String = item.get("type", "Misc")
	type_label.text = "[%s]" % item_type
	type_label.custom_minimum_size.x = 100
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.add_theme_color_override("font_color", _get_type_color(item_type))
	hbox.add_child(type_label)
	
	# Previous owner info
	var prev_owner = item.get("previous_owner", "")
	if not prev_owner.is_empty():
		var owner_label = Label.new()
		owner_label.text = "(from %s)" % prev_owner
		owner_label.add_theme_font_size_override("font_size", 11)
		owner_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
		hbox.add_child(owner_label)
	
	panel.add_child(hbox)
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	
	return panel

var _item_button_group: ButtonGroup = null

func _get_or_create_button_group() -> ButtonGroup:
	## Get or create the button group for item selection
	if not _item_button_group:
		_item_button_group = ButtonGroup.new()
	return _item_button_group

func _on_item_selected(selected: bool, index: int) -> void:
	## Handle item selection
	if selected:
		selected_item_index = index
	else:
		selected_item_index = -1
	
	_update_transfer_button_state()

func _update_transfer_button_state() -> void:
	## Update the transfer button enabled state
	if not transfer_button or not crew_dropdown:
		return
	
	var has_selection = selected_item_index >= 0
	var has_crew_selected = crew_dropdown.get_selected_id() >= 0
	
	transfer_button.disabled = not (has_selection and has_crew_selected)

func _on_transfer_pressed() -> void:
	## Handle transfer button press
	if selected_item_index < 0:
		return
	
	var crew_index = crew_dropdown.get_selected_id()
	if crew_index < 0 or crew_index >= current_crew.size():
		return
	
	# Get the selected item
	var stash_items: Array = []
	if equipment_manager and equipment_manager.has_method("get_ship_stash"):
		stash_items = equipment_manager.get_ship_stash()
	
	if selected_item_index >= stash_items.size():
		return
	
	var item = stash_items[selected_item_index]
	var equipment_id = item.get("id", "")
	
	# Get character ID
	# Sprint 26.3: Character-Everywhere - crew members are Character objects
	var character = current_crew[crew_index]
	var character_id: String = ""
	if "character_id" in character:
		character_id = character.character_id
	elif "character_name" in character:
		# Fallback to character_name as identifier
		character_id = character.character_name
	else:
		character_id = str(crew_index)
	
	# Transfer the item
	if equipment_manager and equipment_manager.has_method("transfer_from_ship_stash"):
		if equipment_manager.transfer_from_ship_stash(equipment_id, character_id):
			print("ShipStashPanel: Transferred %s to %s" % [item.get("name", "item"), character_id])
			item_transferred_to_crew.emit(equipment_id, character_id)
			selected_item_index = -1
			_refresh_display()
			stash_updated.emit()
			_show_transfer_feedback(true, item.get("name", "item"), character_id)
		else:
			push_warning("ShipStashPanel: Failed to transfer item")
			_show_transfer_feedback(false, item.get("name", "item"), character_id)
	else:
		_show_transfer_feedback(false, item.get("name", "item"), character_id)

func _on_equipment_list_updated() -> void:
	## Handle equipment list update from EquipmentManager
	_refresh_display()

func _get_type_color(item_type: String) -> Color:
	## Get color for equipment type
	match item_type.to_lower():
		"weapon", "military weapon":
			return Color(1.0, 0.4, 0.4)
		"low-tech weapon":
			return Color(0.8, 0.6, 0.4)
		"gear":
			return Color(0.4, 0.8, 1.0)
		"gadget":
			return Color(0.8, 0.4, 1.0)
		"armor":
			return Color(0.6, 0.8, 0.4)
		_:
			return Color(0.7, 0.7, 0.7)

## Public API

func refresh() -> void:
	## Public method to refresh the display
	_refresh_display()

func get_stash_count() -> int:
	## Get current stash item count
	if equipment_manager and equipment_manager.has_method("get_ship_stash_count"):
		return equipment_manager.get_ship_stash_count()
	return 0

func is_stash_full() -> bool:
	## Check if stash is at capacity
	return get_stash_count() >= MAX_STASH_SIZE

func add_item_to_stash(item: Dictionary) -> bool:
	## Add an item to ship stash
	if equipment_manager and equipment_manager.has_method("add_to_ship_stash"):
		var result = equipment_manager.add_to_ship_stash(item)
		if result:
			_refresh_display()
			stash_updated.emit()
		return result
	return false


## Transfer Feedback

var _feedback_label: Label = null

func _show_transfer_feedback(success: bool, item_name: String, character_id: String) -> void:
	## Show transfer success/failure feedback to user
	# Remove existing feedback
	if _feedback_label and is_instance_valid(_feedback_label):
		_feedback_label.queue_free()
		_feedback_label = null

	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if success:
		_feedback_label.text = "✅ Transferred %s to %s" % [item_name, character_id]
		_feedback_label.add_theme_color_override("font_color", Color("#10B981"))  # Green
	else:
		_feedback_label.text = "❌ Failed to transfer %s" % item_name
		_feedback_label.add_theme_color_override("font_color", Color("#DC2626"))  # Red

	_feedback_label.add_theme_font_size_override("font_size", 12)

	# Add after stash list
	if stash_list and stash_list.get_parent():
		var parent = stash_list.get_parent().get_parent()  # Get main_vbox
		if parent:
			parent.add_child(_feedback_label)
			parent.move_child(_feedback_label, parent.get_child_count() - 2)  # Before transfer controls

	# Auto-remove after 3 seconds
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(_clear_feedback)


func _clear_feedback() -> void:
	## Clear the feedback label
	if _feedback_label and is_instance_valid(_feedback_label):
		_feedback_label.queue_free()
		_feedback_label = null


## Serialization for persistence

func serialize() -> Dictionary:
	## Serialize panel state for save/load
	var stash_items: Array = []
	if equipment_manager and equipment_manager.has_method("get_ship_stash"):
		stash_items = equipment_manager.get_ship_stash()

	return {
		"stash_items": stash_items.duplicate(true),
		"selected_index": selected_item_index,
		"max_capacity": MAX_STASH_SIZE
	}


func deserialize(data: Dictionary) -> void:
	## Restore panel state from saved data
	if not data:
		return

	# Restore stash items if equipment manager supports it
	var saved_items: Array = data.get("stash_items", [])
	if equipment_manager and equipment_manager.has_method("set_ship_stash"):
		equipment_manager.set_ship_stash(saved_items)

	selected_item_index = data.get("selected_index", -1)

	# Refresh display
	call_deferred("_refresh_display")
