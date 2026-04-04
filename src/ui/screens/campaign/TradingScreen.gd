extends Control
class_name TradingScreen

## Trading Screen for Five Parsecs Campaign Manager
## PHASE 4: Connects to TradingSystem for market generation, buying, and selling
##
## Available during "World Steps" campaign phase (Core Rules p.XX)

const TradingSystemClass = preload("res://src/core/systems/TradingSystem.gd")

signal trade_completed(item_name: String, transaction_type: String, credits: int)
signal trading_closed()
signal credits_changed(new_amount: int)

# UI References
var market_panel: VBoxContainer
var inventory_panel: VBoxContainer
var credits_label: Label
var market_condition_label: Label
var refresh_button: Button
var close_button: Button
var buy_selected_button: Button
var sell_selected_button: Button

# Data
var trading_system: TradingSystemClass
var current_market_items: Array = []
var player_inventory: Array = []
var current_credits: int = 0
var world_type: String = "frontier"
var faction: String = ""

# Selection state
var selected_market_item: int = -1
var selected_inventory_item: int = -1

func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base

func _ready() -> void:
	_setup_ui()
	_initialize_trading_system()
	_connect_signals()

func _setup_ui() -> void:
	## Create the trading screen UI layout
	# Main container
	var main_margin = MarginContainer.new()
	main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_margin.add_theme_constant_override("margin_left", 20)
	main_margin.add_theme_constant_override("margin_right", 20)
	main_margin.add_theme_constant_override("margin_top", 20)
	main_margin.add_theme_constant_override("margin_bottom", 20)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 16)
	
	# Header
	var header = _create_header()
	main_vbox.add_child(header)
	
	# Main split: Market | Inventory
	var main_split = HSplitContainer.new()
	main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_split.split_offset = 0  # Equal split
	
	# Market section
	var market_section = _create_market_section()
	main_split.add_child(market_section)
	
	# Inventory section
	var inventory_section = _create_inventory_section()
	main_split.add_child(inventory_section)
	
	main_vbox.add_child(main_split)
	
	# Footer with action buttons
	var footer = _create_footer()
	main_vbox.add_child(footer)
	
	main_margin.add_child(main_vbox)
	add_child(main_margin)
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.1, 0.98)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -1
	add_child(bg)
	bg.move_to_front()
	main_margin.move_to_front()

func _create_header() -> HBoxContainer:
	## Create the header bar with title and credits
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	
	var title = Label.new()
	title.text = "Trading Post"
	title.add_theme_font_size_override("font_size", _scaled_font(24))
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	header.add_child(title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	# Market condition
	market_condition_label = Label.new()
	market_condition_label.text = "Market: Average"
	market_condition_label.add_theme_font_size_override("font_size", _scaled_font(14))
	market_condition_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)
	header.add_child(market_condition_label)
	
	# Credits display
	var credits_container = HBoxContainer.new()
	credits_container.add_theme_constant_override("separation", 8)
	
	var credits_icon = Label.new()
	credits_icon.text = "💰"
	credits_icon.add_theme_font_size_override("font_size", _scaled_font(18))
	credits_container.add_child(credits_icon)
	
	credits_label = Label.new()
	credits_label.text = "0 Credits"
	credits_label.add_theme_font_size_override("font_size", _scaled_font(18))
	credits_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	credits_container.add_child(credits_label)
	
	header.add_child(credits_container)
	
	# Refresh button
	refresh_button = Button.new()
	refresh_button.text = "Refresh Market"
	refresh_button.custom_minimum_size = Vector2(130, 48)
	refresh_button.tooltip_text = "Generate new market items (costs 1 credit)"
	refresh_button.pressed.connect(_on_refresh_pressed)
	header.add_child(refresh_button)
	
	return header

func _create_market_section() -> PanelContainer:
	## Create the market items panel
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	# Section header
	var section_header = HBoxContainer.new()
	var section_title = Label.new()
	section_title.text = "Available for Purchase"
	section_title.add_theme_font_size_override("font_size", _scaled_font(16))
	section_title.add_theme_color_override("font_color", UIColors.COLOR_CYAN)
	section_header.add_child(section_title)
	
	var section_spacer = Control.new()
	section_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_header.add_child(section_spacer)
	
	buy_selected_button = Button.new()
	buy_selected_button.text = "Buy Selected"
	buy_selected_button.custom_minimum_size = Vector2(100, 48)
	buy_selected_button.disabled = true
	buy_selected_button.pressed.connect(_on_buy_pressed)
	section_header.add_child(buy_selected_button)
	
	vbox.add_child(section_header)
	
	# Items scroll
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	market_panel = VBoxContainer.new()
	market_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_panel.add_theme_constant_override("separation", 4)
	scroll.add_child(market_panel)
	
	vbox.add_child(scroll)
	panel.add_child(vbox)
	
	# Panel style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15)
	style.border_color = Color(0.3, 0.4, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	
	return panel

func _create_inventory_section() -> PanelContainer:
	## Create the player inventory panel
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	# Section header
	var section_header = HBoxContainer.new()
	var section_title = Label.new()
	section_title.text = "Your Inventory"
	section_title.add_theme_font_size_override("font_size", _scaled_font(16))
	section_title.add_theme_color_override("font_color", UIColors.COLOR_EMERALD)
	section_header.add_child(section_title)
	
	var section_spacer = Control.new()
	section_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_header.add_child(section_spacer)
	
	sell_selected_button = Button.new()
	sell_selected_button.text = "Sell Selected"
	sell_selected_button.custom_minimum_size = Vector2(100, 48)
	sell_selected_button.disabled = true
	sell_selected_button.pressed.connect(_on_sell_pressed)
	section_header.add_child(sell_selected_button)
	
	vbox.add_child(section_header)
	
	# Items scroll
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	inventory_panel = VBoxContainer.new()
	inventory_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_panel.add_theme_constant_override("separation", 4)
	scroll.add_child(inventory_panel)
	
	vbox.add_child(scroll)
	panel.add_child(vbox)
	
	# Panel style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.12)
	style.border_color = Color(0.3, 0.5, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	
	return panel

func _create_footer() -> HBoxContainer:
	## Create the footer with close button
	var footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	
	close_button = Button.new()
	close_button.text = "Close Trading"
	close_button.custom_minimum_size = Vector2(150, 48)
	close_button.pressed.connect(_on_close_pressed)
	footer.add_child(close_button)
	
	return footer

func _initialize_trading_system() -> void:
	## Initialize the trading system
	trading_system = TradingSystemClass.new()
	
	# Connect trading system signals
	if trading_system.has_signal("trade_completed"):
		trading_system.trade_completed.connect(_on_trading_system_trade_completed)
	if trading_system.has_signal("trade_failed"):
		trading_system.trade_failed.connect(_on_trading_system_trade_failed)
	if trading_system.has_signal("rare_item_available"):
		trading_system.rare_item_available.connect(_on_rare_item_available)
	

func _connect_signals() -> void:
	## Connect UI signals
	pass  # Buttons connected in creation methods

## Public API

func open_trading(credits: int, inventory: Array, world: String = "frontier", current_faction: String = "") -> void:
	## Open the trading screen with current game state
	current_credits = credits
	player_inventory = inventory.duplicate()
	world_type = world
	faction = current_faction
	
	_update_credits_display()
	_generate_market()
	_refresh_inventory_display()
	
	visible = true

func close_trading() -> void:
	## Close the trading screen
	visible = false
	trading_closed.emit()

func get_current_credits() -> int:
	## Get current credits after trading
	return current_credits

func get_updated_inventory() -> Array:
	## Get updated inventory after trading
	return player_inventory

## Internal methods

func _generate_market() -> void:
	## Generate market items using TradingSystem
	current_market_items.clear()
	selected_market_item = -1
	
	if trading_system:
		var items = trading_system.generate_market(world_type, faction)
		
		# Convert Resource items to Dictionary for easier handling
		for item in items:
			var item_data = {}
			if item is Resource:
				item_data = {
					"name": item.get_meta("name") if item.has_meta("name") else "Unknown",
					"category": item.get_meta("category") if item.has_meta("category") else "misc",
					"base_price": item.get_meta("base_price") if item.has_meta("base_price") else 5,
					"final_price": item.get_meta("final_price") if item.has_meta("final_price") else 5,
					"condition": item.get_meta("condition") if item.has_meta("condition") else "standard",
					"description": item.get_meta("description") if item.has_meta("description") else "",
					"resource": item
				}
			elif item is Dictionary:
				item_data = item
			
			current_market_items.append(item_data)
		
		# Update market condition display
		if market_condition_label:
			market_condition_label.text = "Market: %s" % _get_market_condition_text()
	
	_refresh_market_display()

func _get_market_condition_text() -> String:
	## Get display text for current market condition
	match world_type:
		"core": return "Excellent (Core World)"
		"fringe": return "Good (Fringe World)"
		"frontier": return "Average (Frontier)"
		"remote": return "Poor (Remote)"
		_: return "Average"

func _refresh_market_display() -> void:
	## Refresh the market items display
	if not market_panel:
		return
	
	# Clear existing
	for child in market_panel.get_children():
		child.queue_free()
	
	if current_market_items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No items available"
		empty_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
		market_panel.add_child(empty_label)
		return
	
	# Create item rows
	for i in range(current_market_items.size()):
		var item = current_market_items[i]
		var row = _create_market_item_row(item, i)
		market_panel.add_child(row)

func _create_market_item_row(item: Dictionary, index: int) -> PanelContainer:
	## Create a market item row
	var panel = PanelContainer.new()
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	
	# Selection indicator
	var select_btn = CheckBox.new()
	select_btn.button_group = _get_market_button_group()
	select_btn.toggled.connect(_on_market_item_selected.bind(index))
	hbox.add_child(select_btn)
	
	# Item name
	var name_label = Label.new()
	name_label.text = item.get("name", "Unknown")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", _scaled_font(13))
	hbox.add_child(name_label)

	# Category
	var category_label = Label.new()
	var category = item.get("category", "misc")
	category_label.text = "[%s]" % category.capitalize()
	category_label.custom_minimum_size.x = 80
	category_label.add_theme_font_size_override("font_size", _scaled_font(11))
	category_label.add_theme_color_override("font_color", _get_category_color(category))
	hbox.add_child(category_label)
	
	# Condition
	var condition = item.get("condition", "standard")
	if condition != "standard":
		var condition_label = Label.new()
		condition_label.text = condition.capitalize()
		condition_label.add_theme_font_size_override("font_size", _scaled_font(11))
		condition_label.add_theme_color_override("font_color", _get_condition_color(condition))
		hbox.add_child(condition_label)
	
	# Price
	var price_label = Label.new()
	var price = item.get("final_price", item.get("base_price", 5))
	price_label.text = "%d cr" % price
	price_label.custom_minimum_size.x = 50
	price_label.add_theme_font_size_override("font_size", _scaled_font(13))
	
	# Color based on affordability
	if price <= current_credits:
		price_label.add_theme_color_override("font_color", UIColors.COLOR_EMERALD)
	else:
		price_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	
	hbox.add_child(price_label)
	
	panel.add_child(hbox)
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	
	return panel

func _refresh_inventory_display() -> void:
	## Refresh the inventory display
	if not inventory_panel:
		return
	
	# Clear existing
	for child in inventory_panel.get_children():
		child.queue_free()
	
	if player_inventory.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Inventory empty"
		empty_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
		inventory_panel.add_child(empty_label)
		return
	
	# Create item rows
	for i in range(player_inventory.size()):
		var item = player_inventory[i]
		var row = _create_inventory_item_row(item, i)
		inventory_panel.add_child(row)

func _create_inventory_item_row(item: Variant, index: int) -> PanelContainer:
	## Create an inventory item row
	var panel = PanelContainer.new()
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	
	# Selection indicator
	var select_btn = CheckBox.new()
	select_btn.button_group = _get_inventory_button_group()
	select_btn.toggled.connect(_on_inventory_item_selected.bind(index))
	hbox.add_child(select_btn)
	
	# Get item info
	var item_name: String = ""
	var item_category: String = "misc"
	var item_value: int = 5
	
	if item is Dictionary:
		item_name = item.get("name", "Unknown")
		item_category = item.get("category", item.get("type", "misc"))
		item_value = item.get("value", item.get("base_price", 5))
	elif item is Resource:
		item_name = item.get_meta("name") if item.has_meta("name") else "Unknown"
		item_category = item.get_meta("category") if item.has_meta("category") else "misc"
		item_value = item.get_meta("base_price") if item.has_meta("base_price") else 5
	else:
		item_name = str(item)
	
	# Item name
	var name_label = Label.new()
	name_label.text = item_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", _scaled_font(13))
	hbox.add_child(name_label)
	
	# Category
	var category_label = Label.new()
	category_label.text = "[%s]" % item_category.capitalize()
	category_label.custom_minimum_size.x = 80
	category_label.add_theme_font_size_override("font_size", _scaled_font(11))
	category_label.add_theme_color_override("font_color", _get_category_color(item_category))
	hbox.add_child(category_label)
	
	# Sell value (50% of base)
	var sell_price = int(item_value * 0.5)
	var value_label = Label.new()
	value_label.text = "Sell: %d cr" % sell_price
	value_label.custom_minimum_size.x = 70
	value_label.add_theme_font_size_override("font_size", _scaled_font(12))
	value_label.add_theme_color_override("font_color", UIColors.COLOR_AMBER)
	hbox.add_child(value_label)
	
	panel.add_child(hbox)
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	
	return panel

var _market_button_group: ButtonGroup = null
var _inventory_button_group: ButtonGroup = null

func _get_market_button_group() -> ButtonGroup:
	if not _market_button_group:
		_market_button_group = ButtonGroup.new()
	return _market_button_group

func _get_inventory_button_group() -> ButtonGroup:
	if not _inventory_button_group:
		_inventory_button_group = ButtonGroup.new()
	return _inventory_button_group

func _on_market_item_selected(selected: bool, index: int) -> void:
	## Handle market item selection
	if selected:
		selected_market_item = index
		buy_selected_button.disabled = false
		
		# Check if affordable
		var item = current_market_items[index]
		var price = item.get("final_price", item.get("base_price", 5))
		buy_selected_button.disabled = price > current_credits
	else:
		selected_market_item = -1
		buy_selected_button.disabled = true

func _on_inventory_item_selected(selected: bool, index: int) -> void:
	## Handle inventory item selection
	if selected:
		selected_inventory_item = index
		sell_selected_button.disabled = false
	else:
		selected_inventory_item = -1
		sell_selected_button.disabled = true

func _on_buy_pressed() -> void:
	## Handle buy button press
	if selected_market_item < 0 or selected_market_item >= current_market_items.size():
		return
	
	var item = current_market_items[selected_market_item]
	var price = item.get("final_price", item.get("base_price", 5))
	
	if price > current_credits:
		return
	
	# Complete purchase
	current_credits -= price
	player_inventory.append(item)
	current_market_items.remove_at(selected_market_item)
	selected_market_item = -1
	
	_update_credits_display()
	_refresh_market_display()
	_refresh_inventory_display()
	
	trade_completed.emit(item.get("name", "item"), "purchase", price)
	credits_changed.emit(current_credits)
	_sync_credits_to_game_state_manager()  # EQ-3: Persist credits

func _on_sell_pressed() -> void:
	## Handle sell button press
	if selected_inventory_item < 0 or selected_inventory_item >= player_inventory.size():
		return
	
	var item = player_inventory[selected_inventory_item]
	var item_value: int = 5
	
	if item is Dictionary:
		item_value = item.get("value", item.get("base_price", 5))
	elif item is Resource:
		item_value = item.get_meta("base_price") if item.has_meta("base_price") else 5
	
	var sell_price = int(item_value * 0.5)
	var item_name = item.get("name", "item") if item is Dictionary else str(item)
	
	# Complete sale
	current_credits += sell_price
	player_inventory.remove_at(selected_inventory_item)
	selected_inventory_item = -1
	
	_update_credits_display()
	_refresh_inventory_display()
	
	trade_completed.emit(item_name, "sale", sell_price)
	credits_changed.emit(current_credits)
	_sync_credits_to_game_state_manager()  # EQ-3: Persist credits

func _on_refresh_pressed() -> void:
	## Handle refresh market button press
	if current_credits < 1:
		return
	
	# Refreshing market costs 1 credit
	current_credits -= 1
	_update_credits_display()
	_generate_market()
	credits_changed.emit(current_credits)
	_sync_credits_to_game_state_manager()  # EQ-3: Persist credits

func _on_close_pressed() -> void:
	## Handle close button press
	close_trading()

func _update_credits_display() -> void:
	## Update the credits display
	if credits_label:
		credits_label.text = "%d Credits" % current_credits

func _on_trading_system_trade_completed(item: Resource, transaction_type: String, credits: int) -> void:
	## Handle trade completed from TradingSystem
	pass

func _on_trading_system_trade_failed(reason: String) -> void:
	## Handle trade failed from TradingSystem
	pass

func _on_rare_item_available(item: Resource) -> void:
	## Handle rare item available from TradingSystem
	pass

func _get_category_color(category: String) -> Color:
	## Get color for item category
	match category.to_lower():
		"weapons", "weapon":
			return Color(1.0, 0.5, 0.5)
		"armor":
			return Color(0.5, 0.8, 1.0)
		"gear":
			return Color(0.5, 1.0, 0.5)
		"supplies":
			return Color(0.8, 0.8, 0.5)
		_:
			return Color(0.7, 0.7, 0.7)

func _get_condition_color(condition: String) -> Color:
	## Get color for item condition
	match condition.to_lower():
		"pristine", "excellent":
			return Color(0.4, 1.0, 0.4)
		"good":
			return Color(0.8, 0.8, 0.8)
		"worn":
			return Color(1.0, 0.8, 0.4)
		"damaged":
			return Color(1.0, 0.4, 0.4)
		_:
			return Color(0.7, 0.7, 0.7)

## EQ-3: Sync credits to GameStateManager for persistence
func _sync_credits_to_game_state_manager() -> void:
	## Sync current_credits to GameStateManager so they persist across scenes and saves.
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("set_credits"):
		gsm.set_credits(current_credits)
	else:
		push_warning("TradingScreen: GameStateManager not available - credits may not persist")
