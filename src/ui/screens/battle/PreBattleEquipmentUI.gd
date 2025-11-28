extends PanelContainer
class_name PreBattleEquipmentUI

## Pre-Battle Equipment Management UI
## PHASE 3: Allows crew to swap/reassign equipment before deployment
##
## Five Parsecs Core Rules p.115 - "Readying for Battle":
## - Crew can redistribute equipment from ship stash before deployment
## - Equipment assignments are "locked in" when deployment is confirmed

signal equipment_locked()
signal equipment_changed(character_id: String, equipment_id: String)
signal transfer_requested(from_char: String, to_char: String, equipment_id: String)

# UI References
var crew_panel: VBoxContainer
var stash_panel: VBoxContainer
var lock_button: Button
var status_label: Label

# Data
var selected_crew: Array = []
var ship_stash_items: Array = []
var equipment_manager: Node = null
var is_locked: bool = false

# UI state
var selected_source_character: String = ""
var selected_equipment_id: String = ""

func _ready() -> void:
	_setup_ui()
	_connect_to_managers()

func _setup_ui() -> void:
	"""Create the pre-battle equipment UI layout"""
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	
	# Title
	var title_bar = HBoxContainer.new()
	var title = Label.new()
	title.text = "Equipment Assignment"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	title_bar.add_child(title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(spacer)
	
	status_label = Label.new()
	status_label.text = "Ready to modify"
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	title_bar.add_child(status_label)
	
	main_vbox.add_child(title_bar)
	
	# Main split: Crew loadouts | Ship stash
	var split = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 350
	
	# Crew loadouts section
	var crew_section = VBoxContainer.new()
	crew_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var crew_header = Label.new()
	crew_header.text = "Crew Loadouts"
	crew_header.add_theme_font_size_override("font_size", 14)
	crew_section.add_child(crew_header)
	
	var crew_scroll = ScrollContainer.new()
	crew_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	crew_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	crew_panel = VBoxContainer.new()
	crew_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crew_panel.add_theme_constant_override("separation", 8)
	crew_scroll.add_child(crew_panel)
	
	crew_section.add_child(crew_scroll)
	split.add_child(crew_section)
	
	# Ship stash section
	var stash_section = VBoxContainer.new()
	stash_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var stash_header = HBoxContainer.new()
	var stash_title = Label.new()
	stash_title.text = "Ship Stash"
	stash_title.add_theme_font_size_override("font_size", 14)
	stash_header.add_child(stash_title)
	
	var stash_count = Label.new()
	stash_count.name = "StashCount"
	stash_count.text = "(0/10)"
	stash_count.add_theme_font_size_override("font_size", 12)
	stash_count.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	stash_header.add_child(stash_count)
	
	stash_section.add_child(stash_header)
	
	var stash_scroll = ScrollContainer.new()
	stash_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stash_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	stash_panel = VBoxContainer.new()
	stash_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stash_panel.add_theme_constant_override("separation", 4)
	stash_scroll.add_child(stash_panel)
	
	stash_section.add_child(stash_scroll)
	split.add_child(stash_section)
	
	main_vbox.add_child(split)
	
	# Lock button
	var button_bar = HBoxContainer.new()
	button_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	
	lock_button = Button.new()
	lock_button.text = "Lock Equipment"
	lock_button.custom_minimum_size = Vector2(200, 48)
	lock_button.tooltip_text = "Confirm equipment assignments - cannot be changed after deployment begins"
	lock_button.pressed.connect(_on_lock_pressed)
	button_bar.add_child(lock_button)
	
	main_vbox.add_child(button_bar)
	
	add_child(main_vbox)
	
	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	style.border_color = Color(0.3, 0.35, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	add_theme_stylebox_override("panel", style)

func _connect_to_managers() -> void:
	"""Connect to EquipmentManager autoload"""
	equipment_manager = get_node_or_null("/root/EquipmentManager")
	if equipment_manager:
		if equipment_manager.has_signal("equipment_list_updated"):
			if not equipment_manager.equipment_list_updated.is_connected(_on_equipment_updated):
				equipment_manager.equipment_list_updated.connect(_on_equipment_updated)
		print("PreBattleEquipmentUI: Connected to EquipmentManager")

## Public API

func setup_for_mission(crew: Array, stash: Array = []) -> void:
	"""Setup the UI with crew and stash data"""
	selected_crew = crew
	ship_stash_items = stash
	is_locked = false
	
	# If stash not provided, get from equipment manager
	if ship_stash_items.is_empty() and equipment_manager:
		if equipment_manager.has_method("get_ship_stash"):
			ship_stash_items = equipment_manager.get_ship_stash()
	
	_refresh_display()
	_update_status("Ready - Assign equipment before battle")

func lock_equipment() -> void:
	"""Lock equipment assignments - called when deployment is confirmed"""
	is_locked = true
	_update_lock_state()
	equipment_locked.emit()
	print("PreBattleEquipmentUI: Equipment locked for battle")

func is_equipment_locked() -> bool:
	"""Check if equipment is locked"""
	return is_locked

func unlock_equipment() -> void:
	"""Unlock equipment (for mission abort or restart)"""
	is_locked = false
	_update_lock_state()
	print("PreBattleEquipmentUI: Equipment unlocked")

## Internal methods

func _refresh_display() -> void:
	"""Refresh both crew and stash displays"""
	_refresh_crew_display()
	_refresh_stash_display()

func _refresh_crew_display() -> void:
	"""Refresh the crew loadout display"""
	if not crew_panel:
		return
	
	# Clear existing
	for child in crew_panel.get_children():
		child.queue_free()
	
	if selected_crew.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No crew selected for mission"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		crew_panel.add_child(empty_label)
		return
	
	# Create loadout card for each crew member
	for member in selected_crew:
		var card = _create_crew_loadout_card(member)
		crew_panel.add_child(card)

func _create_crew_loadout_card(member: Variant) -> PanelContainer:
	"""Create a loadout card for a crew member"""
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	
	# Get member info
	var char_name: String = ""
	var char_id: String = ""
	var equipment: Array = []
	
	if member is Dictionary:
		char_name = member.get("character_name", member.get("name", "Unknown"))
		char_id = member.get("id", char_name)
		equipment = member.get("equipment", [])
	elif member is Character:
		char_name = member.character_name if member.character_name else member.name
		char_id = member.id if member.id else char_name
		# Get equipment from equipment manager
		if equipment_manager and equipment_manager.has_method("get_character_equipment"):
			equipment = equipment_manager.get_character_equipment(char_id)
	
	# Header
	var header = HBoxContainer.new()
	var name_label = Label.new()
	name_label.text = char_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	
	# Transfer from stash button
	if not is_locked:
		var add_btn = Button.new()
		add_btn.text = "+ From Stash"
		add_btn.custom_minimum_size.y = 24
		add_btn.pressed.connect(_on_transfer_from_stash.bind(char_id))
		header.add_child(add_btn)
	
	vbox.add_child(header)
	
	# Equipment list
	if equipment.is_empty():
		var empty_label = Label.new()
		empty_label.text = "  No equipment"
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		vbox.add_child(empty_label)
	else:
		for item in equipment:
			var item_row = _create_equipment_row(item, char_id, true)
			vbox.add_child(item_row)
	
	panel.add_child(vbox)
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18)
	style.border_color = Color(0.25, 0.25, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	
	return panel

func _create_equipment_row(item: Variant, owner_id: String, is_on_character: bool) -> HBoxContainer:
	"""Create a row for an equipment item"""
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	
	# Get item info
	var item_name: String = ""
	var item_type: String = ""
	var item_id: String = ""
	
	if item is Dictionary:
		item_name = item.get("name", "Unknown")
		item_type = item.get("type", "")
		item_id = item.get("id", item_name)
	elif item is String:
		item_name = item
		item_id = item
	
	# Item name
	var name_label = Label.new()
	name_label.text = "  • " + item_name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if not item_type.is_empty():
		name_label.add_theme_color_override("font_color", _get_type_color(item_type))
	
	row.add_child(name_label)
	
	# Action buttons (only if not locked)
	if not is_locked:
		if is_on_character:
			# Transfer to stash button
			var to_stash_btn = Button.new()
			to_stash_btn.text = "→ Stash"
			to_stash_btn.custom_minimum_size = Vector2(60, 22)
			to_stash_btn.add_theme_font_size_override("font_size", 10)
			to_stash_btn.pressed.connect(_on_transfer_to_stash.bind(owner_id, item_id))
			row.add_child(to_stash_btn)
		else:
			# Transfer to crew button
			var to_crew_btn = Button.new()
			to_crew_btn.text = "→ Crew"
			to_crew_btn.custom_minimum_size = Vector2(60, 22)
			to_crew_btn.add_theme_font_size_override("font_size", 10)
			to_crew_btn.pressed.connect(_on_request_assign_to_crew.bind(item_id))
			row.add_child(to_crew_btn)
	
	return row

func _refresh_stash_display() -> void:
	"""Refresh the ship stash display"""
	if not stash_panel:
		return
	
	# Clear existing
	for child in stash_panel.get_children():
		child.queue_free()
	
	# Get fresh stash data
	if equipment_manager and equipment_manager.has_method("get_ship_stash"):
		ship_stash_items = equipment_manager.get_ship_stash()
	
	# Update count label
	var stash_count = get_node_or_null("StashCount")
	if stash_count:
		stash_count.text = "(%d/10)" % ship_stash_items.size()
	
	if ship_stash_items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Ship stash is empty"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		stash_panel.add_child(empty_label)
		return
	
	# Create row for each stash item
	for item in ship_stash_items:
		var row = _create_equipment_row(item, "ship_stash", false)
		stash_panel.add_child(row)

func _on_transfer_to_stash(character_id: String, equipment_id: String) -> void:
	"""Transfer equipment from character to ship stash"""
	if is_locked:
		return
	
	if equipment_manager and equipment_manager.has_method("transfer_to_ship_stash"):
		if equipment_manager.transfer_to_ship_stash(character_id, equipment_id):
			equipment_changed.emit(character_id, equipment_id)
			_refresh_display()
			_update_status("Transferred to ship stash")
		else:
			_update_status("Transfer failed - stash may be full", true)

func _on_transfer_from_stash(character_id: String) -> void:
	"""Open dialog to select item from stash to transfer to character"""
	if is_locked:
		return
	
	if ship_stash_items.is_empty():
		_update_status("Ship stash is empty", true)
		return
	
	# Create simple selection popup
	var popup = PopupMenu.new()
	popup.name = "StashSelectionPopup"
	
	for i in range(ship_stash_items.size()):
		var item = ship_stash_items[i]
		var item_name = item.get("name", "Unknown") if item is Dictionary else str(item)
		popup.add_item(item_name, i)
	
	popup.id_pressed.connect(_on_stash_item_selected.bind(character_id))
	
	add_child(popup)
	popup.popup_centered()

func _on_stash_item_selected(item_index: int, character_id: String) -> void:
	"""Handle stash item selection for transfer"""
	if item_index < 0 or item_index >= ship_stash_items.size():
		return
	
	var item = ship_stash_items[item_index]
	var equipment_id = item.get("id", "") if item is Dictionary else str(item)
	
	if equipment_manager and equipment_manager.has_method("transfer_from_ship_stash"):
		if equipment_manager.transfer_from_ship_stash(equipment_id, character_id):
			equipment_changed.emit(character_id, equipment_id)
			_refresh_display()
			_update_status("Transferred from ship stash")
		else:
			_update_status("Transfer failed", true)

func _on_request_assign_to_crew(equipment_id: String) -> void:
	"""Open dialog to select crew member to receive equipment"""
	if is_locked or selected_crew.is_empty():
		return
	
	# Create simple selection popup
	var popup = PopupMenu.new()
	popup.name = "CrewSelectionPopup"
	
	for i in range(selected_crew.size()):
		var member = selected_crew[i]
		var name: String = ""
		if member is Dictionary:
			name = member.get("character_name", member.get("name", "Unknown"))
		elif member is Character:
			name = member.character_name if member.character_name else member.name
		popup.add_item(name, i)
	
	popup.id_pressed.connect(_on_crew_selected_for_transfer.bind(equipment_id))
	
	add_child(popup)
	popup.popup_centered()

func _on_crew_selected_for_transfer(crew_index: int, equipment_id: String) -> void:
	"""Handle crew selection for equipment transfer"""
	if crew_index < 0 or crew_index >= selected_crew.size():
		return
	
	var member = selected_crew[crew_index]
	var character_id: String = ""
	
	if member is Dictionary:
		character_id = member.get("id", member.get("character_name", str(crew_index)))
	elif member is Character:
		character_id = member.id if member.id else member.character_name
	
	if equipment_manager and equipment_manager.has_method("transfer_from_ship_stash"):
		if equipment_manager.transfer_from_ship_stash(equipment_id, character_id):
			equipment_changed.emit(character_id, equipment_id)
			_refresh_display()
			_update_status("Equipment assigned")
		else:
			_update_status("Assignment failed", true)

func _on_lock_pressed() -> void:
	"""Handle lock button press"""
	if is_locked:
		return
	
	lock_equipment()
	_update_status("Equipment locked for battle!")

func _on_equipment_updated() -> void:
	"""Handle equipment list update from manager"""
	if not is_locked:
		_refresh_display()

func _update_status(message: String, is_error: bool = false) -> void:
	"""Update status label"""
	if status_label:
		status_label.text = message
		if is_error:
			status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		else:
			status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))

func _update_lock_state() -> void:
	"""Update UI based on locked state"""
	if lock_button:
		lock_button.disabled = is_locked
		lock_button.text = "Equipment Locked" if is_locked else "Lock Equipment"
	
	if status_label:
		if is_locked:
			status_label.text = "LOCKED - Ready for deployment"
			status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
		else:
			status_label.text = "Ready to modify"
			status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	
	# Refresh to show/hide action buttons
	_refresh_display()

func _get_type_color(item_type: String) -> Color:
	"""Get color for equipment type"""
	match item_type.to_lower():
		"weapon", "military weapon":
			return Color(1.0, 0.5, 0.5)
		"low-tech weapon":
			return Color(0.9, 0.7, 0.5)
		"gear":
			return Color(0.5, 0.9, 1.0)
		"gadget":
			return Color(0.9, 0.5, 1.0)
		"armor":
			return Color(0.5, 0.9, 0.5)
		_:
			return Color(0.8, 0.8, 0.8)


