class_name EquipmentManagerUI
extends Control

signal equipment_assigned(equipment_item: Dictionary, crew_member: Dictionary)
signal equipment_unassigned(equipment_item: Dictionary, crew_member: Dictionary)

@onready var equipment_grid: GridContainer = %EquipmentGrid
@onready var crew_list: VBoxContainer = %CrewList
@onready var details_container: VBoxContainer = %DetailsContainer

var selected_equipment: Dictionary = {}
var selected_crew_member: Dictionary = {}
var equipment_database: Array[Dictionary] = []
var crew_roster: Array[Dictionary] = []

var is_initialized: bool = false
var initialization_attempts: int = 0
const MAX_INITIALIZATION_ATTEMPTS: int = 3

func _scaled_font(base: int) -> int:
	var rm := get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("get_responsive_font_size"):
		return rm.get_responsive_font_size(base)
	return base

func _ready() -> void:
	
	# Node structure initialized
	
	# Wait for scene to be fully ready if nodes are null
	if equipment_grid == null or crew_list == null or details_container == null:
		call_deferred("_deferred_initialization")
		return
	
	_initialize_systems()

func _deferred_initialization():
	## Initialize after scene is fully ready
	initialization_attempts += 1
	pass # Attempting deferred initialization
	
	# Try multiple node finding strategies
	_find_nodes_with_fallbacks()
	
	if equipment_grid != null and crew_list != null and details_container != null:
		_initialize_systems()
	elif initialization_attempts < MAX_INITIALIZATION_ATTEMPTS:
		call_deferred("_deferred_initialization")
	else:
		push_error("EquipmentManager: Critical nodes still not found after %d attempts - cannot initialize" % MAX_INITIALIZATION_ATTEMPTS)

func _find_nodes_with_fallbacks():
	## Try multiple strategies to find required nodes
	
	# Strategy 1: @onready should have worked
	if equipment_grid != null and crew_list != null and details_container != null:
		return
	
	# Strategy 2: Find by unique name
	if equipment_grid == null:
		equipment_grid = find_child("EquipmentGrid", true, false)
		if equipment_grid == null:
			# Strategy 3: Find by path
			equipment_grid = get_node_or_null("MarginContainer/VBoxContainer/MainContent/EquipmentList/VBoxContainer/ScrollContainer/EquipmentGrid")
		pass # equipment_grid lookup complete
	
	if crew_list == null:
		crew_list = find_child("CrewList", true, false)
		if crew_list == null:
			# Strategy 3: Find by path
			crew_list = get_node_or_null("MarginContainer/VBoxContainer/MainContent/CrewAssignment/VBoxContainer/ScrollContainer/CrewList")
		pass # crew_list lookup complete
	
	if details_container == null:
		details_container = find_child("DetailsContainer", true, false)
		if details_container == null:
			# Strategy 3: Find by path
			details_container = get_node_or_null("MarginContainer/VBoxContainer/MainContent/EquipmentDetails/VBoxContainer/DetailsContainer")
		pass # details_container lookup complete

func _initialize_systems():
	## Initialize all systems once nodes are confirmed available
	is_initialized = true
	_load_equipment_database()
	_load_crew_roster()
	_refresh_equipment_display()
	_refresh_crew_display()

func _load_equipment_database() -> void:
	## Load equipment from data systems
	# Connect to equipment database
	var data_manager = get_node_or_null("/root/DataManagerAutoload")
	if data_manager and data_manager.has_method("load_equipment_data"):
		equipment_database = data_manager.load_equipment_data()
		return
	
	# Fallback to hardcoded data if database not available
	equipment_database = [
		{"name": "Military Rifle", "type": "weapon", "range": 24, "shots": 1, "damage": 1, "traits": ["Military"]},
		{"name": "Scrap Pistol", "type": "weapon", "range": 12, "shots": 1, "damage": 1, "traits": ["Pistol"]},
		{"name": "Combat Armor", "type": "armor", "save": 5, "traits": ["Heavy"]},
		{"name": "Analyzer", "type": "gadget", "traits": ["Tech"]},
		{"name": "Medkit", "type": "gear", "traits": ["Medical"]},
	]

func _load_crew_roster() -> void:
	## Load current crew from campaign data
	# Connect to campaign manager
	var campaign_mgr = get_node_or_null("/root/CampaignManager")
	if campaign_mgr and campaign_mgr.has_method("get_crew_roster"):
		crew_roster = campaign_mgr.get_crew_roster()
		return
	
	# Fallback to default crew if campaign manager not available
	crew_roster = [
		{"name": "Captain Reynolds", "class": "Soldier", "equipment": []},
		{"name": "Dr. Chen", "class": "Scientist", "equipment": []},
		{"name": "Sgt. Martinez", "class": "Military", "equipment": []},
		{"name": "Tech Walker", "class": "Engineer", "equipment": []},
	]

func set_crew_data(crew_data: Array) -> void:
	## Set crew data from external source (EquipmentPanel coordinator)
	pass # Receiving crew data
	
	crew_roster.clear()
	for member in crew_data:
		# Validate each crew member data
		var validated_member = DataValidator.validate_crew_member(member)
		crew_roster.append(validated_member)
		pass # Crew member added
	
	# Refresh display with new crew data
	_refresh_crew_display()
	pass # Crew roster updated

func _refresh_equipment_display() -> void:
	## Refresh the equipment grid display
	
	# Check if we're initialized and nodes are available
	if not is_initialized or equipment_grid == null:
		if equipment_grid == null:
			_find_nodes_with_fallbacks()
		
		if equipment_grid == null:
			return
	
	pass # Clearing equipment items
	
	# Clear existing items safely
	for child in equipment_grid.get_children():
		child.queue_free()

	# Add equipment items
	pass # Adding equipment items to display
	for equipment in equipment_database:
		var validated_equipment = DataValidator.validate_equipment(equipment)
		var item_button: Button = Button.new()
		item_button.text = DataValidator.safe_get_name(validated_equipment)
		item_button.custom_minimum_size = Vector2(150, 60)
		item_button.pressed.connect(_on_equipment_selected.bind(validated_equipment))
		equipment_grid.add_child(item_button)

func _refresh_crew_display() -> void:
	## Refresh the crew assignment display
	
	# Check if we're initialized and nodes are available
	if not is_initialized or crew_list == null:
		if crew_list == null:
			_find_nodes_with_fallbacks()
		
		if crew_list == null:
			return
	
	pass # Clearing crew items
	
	# Clear existing items safely
	for child in crew_list.get_children():
		child.queue_free()

	# Add crew members
	pass # Adding crew members to display
	for crew_member in crew_roster:
		var crew_panel: Control = _create_crew_panel(crew_member)
		crew_list.add_child(crew_panel)
		var member_name = DataValidator.safe_get_name(crew_member)

func _create_crew_panel(crew_member: Dictionary) -> Control:
	## Create a panel for crew _member equipment assignment
	var panel: PanelContainer = PanelContainer.new()
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	# Validate and normalize crew member data
	var validated_member = DataValidator.validate_crew_member(crew_member)
	
	# Crew member name
	var name_label: Label = Label.new()
	var member_name = DataValidator.safe_get_name(validated_member)
	var member_class = DataValidator.safe_get_class(validated_member)
	name_label.text = "%s (%s)" % [member_name, member_class]
	vbox.add_child(name_label)

	# Equipment list
	var equipment_list = VBoxContainer.new()
	for equipment_item in validated_member.get("equipment", []):
		var validated_equipment = DataValidator.validate_equipment(equipment_item)
		var equipment_label: Label = Label.new()
		equipment_label.text = "- " + DataValidator.safe_get_name(validated_equipment)
		equipment_list.add_child(equipment_label)
	vbox.add_child(equipment_list)

	# Assign button
	var assign_button: Button = Button.new()
	assign_button.text = "Assign Equipment"
	assign_button.pressed.connect(_on_crew_selected.bind(crew_member))
	vbox.add_child(assign_button)

	return panel

func _update_equipment_details(equipment: Dictionary) -> void:
	## Update the equipment details panel
	
	# Safety check for details_container
	if details_container == null:
		push_error("EquipmentManager: details_container is null, cannot update details")
		return
	
	# Clear existing details safely
	for child in details_container.get_children():
		child.queue_free()

	if equipment.is_empty():
		return

	# Validate equipment data
	var validated_equipment = DataValidator.validate_equipment(equipment)
	pass # Displaying equipment details

	# Equipment name
	var name_label: Label = Label.new()
	name_label.text = DataValidator.safe_get_name(validated_equipment)
	name_label.add_theme_font_size_override("font_size", _scaled_font(18))
	details_container.add_child(name_label)

	# Equipment type
	var type_label: Label = Label.new()
	type_label.text = "Type: " + validated_equipment.get("type", "unknown").capitalize()
	details_container.add_child(type_label)

	# Equipment stats
	match validated_equipment.get("type", ""):
		"weapon":
			var range_label: Label = Label.new()
			range_label.text = "Range: " + str(validated_equipment.get("range", 0)) + "\""
			details_container.add_child(range_label)

			var shots_label: Label = Label.new()
			shots_label.text = "Shots: " + str(validated_equipment.get("shots", 0))
			details_container.add_child(shots_label)

			var damage_label: Label = Label.new()
			damage_label.text = "Damage: +" + str(validated_equipment.get("damage", 0))
			details_container.add_child(damage_label)

		"armor":
			var save_label: Label = Label.new()
			save_label.text = "Saving Throw: " + str(validated_equipment.get("save", 0)) + "+"
			details_container.add_child(save_label)

	# Traits
	if validated_equipment.has("traits"):
		var traits_label: Label = Label.new()
		var traits = validated_equipment.get("traits", [])
		if traits is Array and traits.size() > 0:
			traits_label.text = "Traits: " + ", ".join(traits)
			details_container.add_child(traits_label)

func _on_equipment_selected(equipment: Dictionary) -> void:
	## Handle equipment selection
	selected_equipment = equipment
	_update_equipment_details(equipment)
	pass # Equipment selected

func _on_crew_selected(crew_member: Dictionary) -> void:
	## Handle crew _member selection for equipment assignment
	selected_crew_member = crew_member

	if not selected_equipment.is_empty():
		_assign_equipment_to_crew()

func _assign_equipment_to_crew() -> void:
	## Assign selected equipment to selected crew member
	if selected_equipment.is_empty() or selected_crew_member.is_empty():
		return

	# Add equipment to crew member
	if not selected_crew_member.has("equipment"):
		selected_crew_member["equipment"] = []

	selected_crew_member["equipment"].append(selected_equipment.duplicate())

	# Emit signal
	equipment_assigned.emit(selected_equipment, selected_crew_member)

	# Refresh displays
	_refresh_crew_display()

	# Clear selections
	selected_equipment = {}
	selected_crew_member = {}
	_update_equipment_details({})

	pass # Equipment assigned

func _on_back_pressed() -> void:
	## Handle back button press
	SceneRouter.navigate_back()

func _on_generate_equipment_pressed() -> void:
	## Generate new equipment using tables
	# Implement equipment generation tables
	var dice_mgr = get_node_or_null("/root/DiceManager")
	var new_equipment = _generate_random_equipment(dice_mgr)
	equipment_database.append(new_equipment)
	_refresh_equipment_display()
	pass # New equipment generated

func _generate_random_equipment(dice_mgr) -> Dictionary:
	## Generate random equipment based on tables
	var roll = 0
	if dice_mgr and dice_mgr.has_method("roll_dice"):
		roll = dice_mgr.roll_dice(1, 6)
	else:
		roll = randi_range(1, 6)
	
	match roll:
		1, 2:
			return {"name": "Basic Weapon", "type": "weapon", "range": 12, "shots": 1, "damage": 1, "traits": []}
		3, 4:
			return {"name": "Light Armor", "type": "armor", "save": 6, "traits": []}
		5:
			return {"name": "Tech Gadget", "type": "gadget", "traits": ["Tech"]}
		6:
			return {"name": "Survival Gear", "type": "gear", "traits": ["Utility"]}
		_:
			return {"name": "Mystery Item", "type": "gear", "traits": []}

func _on_trade_pressed() -> void:
	## Open trade/market interface
	_open_trade_interface()

func _on_repair_pressed() -> void:
	## Open equipment repair interface
	_open_repair_interface()

func _open_trade_interface() -> void:
	## Open equipment trading interface with market functionality
	# Create trade dialog
	var trade_dialog = _create_trade_dialog()
	
	if trade_dialog:
		# Add to scene tree and display
		get_tree().current_scene.add_child(trade_dialog)
		trade_dialog.popup_centered_ratio(0.9)
		
		# Connect trade signals
		if not trade_dialog.equipment_traded.is_connected(_on_equipment_traded):
			trade_dialog.equipment_traded.connect(_on_equipment_traded)
		
	else:
		push_error("EquipmentManager: Failed to create trade dialog")

func _open_repair_interface() -> void:
	## Open equipment repair interface for damaged equipment
	# Create repair dialog
	var repair_dialog = _create_repair_dialog()
	
	if repair_dialog:
		# Add to scene tree and display
		get_tree().current_scene.add_child(repair_dialog)
		repair_dialog.popup_centered_ratio(0.8)
		
		# Connect repair signals
		if not repair_dialog.equipment_repaired.is_connected(_on_equipment_repaired):
			repair_dialog.equipment_repaired.connect(_on_equipment_repaired)
		
	else:
		push_error("EquipmentManager: Failed to create repair dialog")

func _create_trade_dialog() -> AcceptDialog:
	## Create equipment trading dialog with buy/sell functionality
	var dialog = AcceptDialog.new()
	dialog.title = "Equipment Trade Market"
	dialog.set_flag(Window.FLAG_RESIZE_DISABLED, false)
	
	# Create main container with split layout
	var hsplit = HSplitContainer.new()
	dialog.add_child(hsplit)
	
	# Create inventory section (left side)
	var inventory_section = _create_inventory_trade_section()
	hsplit.add_child(inventory_section)
	
	# Create market section (right side)
	var market_section = _create_market_section()
	hsplit.add_child(market_section)
	
	# Create trade status section
	var status_section = _create_trade_status_section()
	dialog.add_child(status_section)
	
	# Create action buttons
	var button_container = HBoxContainer.new()
	dialog.add_child(button_container)
	
	var buy_button = Button.new()
	buy_button.text = "Buy Selected"
	buy_button.pressed.connect(_on_buy_equipment_pressed.bind(dialog))
	button_container.add_child(buy_button)
	
	var sell_button = Button.new()
	sell_button.text = "Sell Selected"
	sell_button.pressed.connect(_on_sell_equipment_pressed.bind(dialog))
	button_container.add_child(sell_button)
	
	var close_button = Button.new()
	close_button.text = "Close Market"
	close_button.pressed.connect(dialog.queue_free)
	button_container.add_child(close_button)
	
	# Add custom signal for equipment trading
	dialog.add_user_signal("equipment_traded", [ {"name": "action", "type": TYPE_STRING}, {"name": "equipment", "type": TYPE_DICTIONARY}, {"name": "credits", "type": TYPE_INT}])
	
	return dialog

func _create_inventory_trade_section() -> Control:
	## Create inventory section for trading
	var section = VBoxContainer.new()
	section.custom_minimum_size = Vector2(300, 400)
	
	var label = Label.new()
	label.text = "Your Equipment (Sell):"
	section.add_child(label)
	
	var inventory_list = ItemList.new()
	inventory_list.name = "InventoryList"
	inventory_list.custom_minimum_size = Vector2(280, 300)
	
	# Populate with current equipment
	for i in range(equipment_database.size()):
		var equipment = equipment_database[i]
		var price = _calculate_sell_price(equipment)
		var item_text = "%s - %d credits" % [equipment.get("name", "Unknown"), price]
		inventory_list.add_item(item_text)
		inventory_list.set_item_metadata(i, equipment)
	
	section.add_child(inventory_list)
	
	# Add credits display
	var credits_label = Label.new()
	credits_label.name = "CreditsLabel"
	credits_label.text = "Credits: %d" % _get_current_credits()
	section.add_child(credits_label)
	
	return section

func _create_market_section() -> Control:
	## Create market section for buying equipment
	var section = VBoxContainer.new()
	section.custom_minimum_size = Vector2(300, 400)
	
	var label = Label.new()
	label.text = "Market Equipment (Buy):"
	section.add_child(label)
	
	var market_list = ItemList.new()
	market_list.name = "MarketList"
	market_list.custom_minimum_size = Vector2(280, 300)
	
	# Generate market equipment
	var market_equipment = _generate_market_equipment()
	for i in range(market_equipment.size()):
		var equipment = market_equipment[i]
		var price = _calculate_buy_price(equipment)
		var item_text = "%s - %d credits" % [equipment.get("name", "Unknown"), price]
		market_list.add_item(item_text)
		market_list.set_item_metadata(i, equipment)
	
	section.add_child(market_list)
	
	# Add market refresh button
	var refresh_button = Button.new()
	refresh_button.text = "Refresh Market"
	refresh_button.pressed.connect(_on_refresh_market_pressed.bind(market_list))
	section.add_child(refresh_button)
	
	return section

func _create_trade_status_section() -> Control:
	## Create trade status section
	var section = HBoxContainer.new()
	
	var status_label = Label.new()
	status_label.name = "TradeStatusLabel"
	status_label.text = "Select equipment to buy or sell"
	section.add_child(status_label)
	
	return section

func _create_repair_dialog() -> AcceptDialog:
	## Create equipment repair dialog
	var dialog = AcceptDialog.new()
	dialog.title = "Equipment Repair Station"
	dialog.set_flag(Window.FLAG_RESIZE_DISABLED, false)
	
	# Create main container
	var main_container = VBoxContainer.new()
	dialog.add_child(main_container)
	
	# Create damaged equipment section
	var damaged_section = _create_damaged_equipment_section()
	main_container.add_child(damaged_section)
	
	# Create repair options section
	var repair_options_section = _create_repair_options_section()
	main_container.add_child(repair_options_section)
	
	# Create repair status section
	var status_section = _create_repair_status_section()
	main_container.add_child(status_section)
	
	# Create action buttons
	var button_container = HBoxContainer.new()
	main_container.add_child(button_container)
	
	var repair_button = Button.new()
	repair_button.text = "Repair Selected"
	repair_button.pressed.connect(_on_repair_equipment_pressed.bind(dialog))
	button_container.add_child(repair_button)
	
	var repair_all_button = Button.new()
	repair_all_button.text = "Repair All"
	repair_all_button.pressed.connect(_on_repair_all_pressed.bind(dialog))
	button_container.add_child(repair_all_button)
	
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(dialog.queue_free)
	button_container.add_child(close_button)
	
	# Add custom signal for equipment repair
	dialog.add_user_signal("equipment_repaired", [ {"name": "equipment", "type": TYPE_DICTIONARY}, {"name": "cost", "type": TYPE_INT}])
	
	return dialog

func _create_damaged_equipment_section() -> Control:
	## Create damaged equipment section
	var section = VBoxContainer.new()
	
	var label = Label.new()
	label.text = "Damaged Equipment:"
	section.add_child(label)
	
	var damaged_list = ItemList.new()
	damaged_list.name = "DamagedList"
	damaged_list.custom_minimum_size = Vector2(400, 200)
	
	# Find damaged equipment
	var damaged_equipment = _get_damaged_equipment()
	for i in range(damaged_equipment.size()):
		var equipment = damaged_equipment[i]
		var repair_cost = _calculate_repair_cost(equipment)
		var item_text = "%s - %d credits to repair" % [equipment.get("name", "Unknown"), repair_cost]
		damaged_list.add_item(item_text)
		damaged_list.set_item_metadata(i, equipment)
	
	if damaged_equipment.is_empty():
		damaged_list.add_item("No damaged equipment found")
	
	section.add_child(damaged_list)
	
	return section

func _create_repair_options_section() -> Control:
	## Create repair options section
	var section = VBoxContainer.new()
	
	var label = Label.new()
	label.text = "Repair Options:"
	section.add_child(label)
	
	var options_container = VBoxContainer.new()
	section.add_child(options_container)
	
	var quick_repair = CheckBox.new()
	quick_repair.name = "QuickRepair"
	quick_repair.text = "Quick Repair (+50% cost, immediate)"
	options_container.add_child(quick_repair)
	
	var quality_repair = CheckBox.new()
	quality_repair.name = "QualityRepair"
	quality_repair.text = "Quality Repair (+100% cost, improved durability)"
	options_container.add_child(quality_repair)
	
	return section

func _create_repair_status_section() -> Control:
	## Create repair status section
	var section = HBoxContainer.new()
	
	var status_label = Label.new()
	status_label.name = "RepairStatusLabel"
	status_label.text = "Credits available: %d" % _get_current_credits()
	section.add_child(status_label)
	
	return section

# Supporting functions for trade system
func _generate_market_equipment() -> Array[Dictionary]:
	## Generate equipment available in market
	var market_equipment: Array[Dictionary] = [
		{"name": "Pulse Rifle", "type": "weapon", "range": 30, "shots": 1, "damage": 2, "traits": ["Energy", "Military"], "rarity": "uncommon"},
		{"name": "Boarding Saber", "type": "weapon", "range": 0, "shots": 0, "damage": 2, "traits": ["Melee", "Blade"], "rarity": "common"},
		{"name": "Shield Generator", "type": "gadget", "traits": ["Tech", "Defensive"], "rarity": "rare"},
		{"name": "Stims", "type": "consumable", "traits": ["Medical", "Enhancement"], "rarity": "common"},
		{"name": "Camo Cloak", "type": "gear", "traits": ["Stealth", "Utility"], "rarity": "uncommon"}
	]
	
	# Add some random equipment
	for i in range(randi_range(2, 5)):
		market_equipment.append(_generate_random_market_equipment())
	
	return market_equipment

func _generate_random_market_equipment() -> Dictionary:
	## Generate random equipment for market
	var equipment_types = ["weapon", "armor", "gadget", "gear"]
	var type = equipment_types[randi() % equipment_types.size()]
	
	match type:
		"weapon":
			return {
				"name": "Random Weapon %d" % randi_range(100, 999),
				"type": "weapon",
				"range": randi_range(12, 36),
				"damage": randi_range(1, 3),
				"traits": ["Random"],
				"rarity": "common"
			}
		"armor":
			return {
				"name": "Random Armor %d" % randi_range(100, 999),
				"type": "armor",
				"save": randi_range(4, 6),
				"traits": ["Protection"],
				"rarity": "common"
			}
		_:
			return {
				"name": "Random Gear %d" % randi_range(100, 999),
				"type": type,
				"traits": ["Utility"],
				"rarity": "common"
			}

func _calculate_buy_price(equipment: Dictionary) -> int:
	## Calculate buy price for equipment
	var base_price = 500
	var rarity_multiplier = 1.0
	
	match equipment.get("rarity", "common"):
		"common": rarity_multiplier = 1.0
		"uncommon": rarity_multiplier = 1.5
		"rare": rarity_multiplier = 2.5
		"legendary": rarity_multiplier = 5.0
	
	return int(base_price * rarity_multiplier)

func _calculate_sell_price(equipment: Dictionary) -> int:
	## Calculate sell price for equipment (60% of buy price)
	return int(_calculate_buy_price(equipment) * 0.6)

func _calculate_repair_cost(equipment: Dictionary) -> int:
	## Calculate repair cost for damaged equipment
	var base_cost = _calculate_buy_price(equipment) * 0.3
	var damage_severity = equipment.get("damage_level", 1)
	return int(base_cost * damage_severity)

func _get_current_credits() -> int:
	## Get current credits from campaign data
	# Try to get from campaign manager
	var campaign_mgr = get_node_or_null("/root/CampaignManager")
	if campaign_mgr and campaign_mgr.has_method("get_credits"):
		return campaign_mgr.get_credits()
	
	# Fallback amount
	return 2500

func _get_damaged_equipment() -> Array[Dictionary]:
	## Get list of damaged equipment
	var damaged: Array[Dictionary] = []
	
	for equipment in equipment_database:
		if equipment.get("damaged", false) or equipment.get("damage_level", 0) > 0:
			damaged.append(equipment)
	
	# Add some sample damaged equipment if none found
	if damaged.is_empty():
		damaged = [
			{"name": "Damaged Rifle", "type": "weapon", "damaged": true, "damage_level": 2},
			{"name": "Cracked Armor", "type": "armor", "damaged": true, "damage_level": 1}
		]
	
	return damaged

# Event handlers for trade system
func _on_buy_equipment_pressed(dialog: Control) -> void:
	## Handle buy equipment button press
	var market_list = dialog.find_child("MarketList")
	var credits_label = dialog.find_child("CreditsLabel")
	
	if market_list:
		var selected_items = market_list.get_selected_items()
		if selected_items.size() > 0:
			var equipment = market_list.get_item_metadata(selected_items[0])
			var price = _calculate_buy_price(equipment)
			var current_credits = _get_current_credits()
			
			if current_credits >= price:
				# Process purchase
				equipment_database.append(equipment)
				dialog.emit_signal("equipment_traded", "buy", equipment, price)
				
				# Update UI
				if credits_label:
					credits_label.text = "Credits: %d" % (current_credits - price)
				
				pass # Equipment bought
			else:
				_show_trade_error("Insufficient credits to purchase this item.")
		else:
			_show_trade_error("Please select an item to purchase.")

func _on_sell_equipment_pressed(dialog: Control) -> void:
	## Handle sell equipment button press
	var inventory_list = dialog.find_child("InventoryList")
	var credits_label = dialog.find_child("CreditsLabel")
	
	if inventory_list:
		var selected_items = inventory_list.get_selected_items()
		if selected_items.size() > 0:
			var equipment = inventory_list.get_item_metadata(selected_items[0])
			var price = _calculate_sell_price(equipment)
			
			# Remove from inventory
			equipment_database.erase(equipment)
			inventory_list.remove_item(selected_items[0])
			
			# Process sale
			dialog.emit_signal("equipment_traded", "sell", equipment, price)
			
			# Update UI
			if credits_label:
				var current_credits = _get_current_credits()
				credits_label.text = "Credits: %d" % (current_credits + price)
			
			pass # Equipment sold
		else:
			_show_trade_error("Please select an item to sell.")

func _on_refresh_market_pressed(market_list: ItemList) -> void:
	## Handle market refresh button press
	market_list.clear()
	
	var market_equipment = _generate_market_equipment()
	for i in range(market_equipment.size()):
		var equipment = market_equipment[i]
		var price = _calculate_buy_price(equipment)
		var item_text = "%s - %d credits" % [equipment.get("name", "Unknown"), price]
		market_list.add_item(item_text)
		market_list.set_item_metadata(i, equipment)
	
	pass # Market refreshed

func _on_repair_equipment_pressed(dialog: Control) -> void:
	## Handle repair equipment button press
	var damaged_list = dialog.find_child("DamagedList")
	var quick_repair = dialog.find_child("QuickRepair")
	var quality_repair = dialog.find_child("QualityRepair")
	
	if damaged_list:
		var selected_items = damaged_list.get_selected_items()
		if selected_items.size() > 0:
			var equipment = damaged_list.get_item_metadata(selected_items[0])
			var repair_cost = _calculate_repair_cost(equipment)
			
			# Apply repair modifiers
			if quick_repair and quick_repair.button_pressed:
				repair_cost = int(repair_cost * 1.5)
			elif quality_repair and quality_repair.button_pressed:
				repair_cost = int(repair_cost * 2.0)
			
			var current_credits = _get_current_credits()
			if current_credits >= repair_cost:
				# Process repair
				equipment["damaged"] = false
				equipment["damage_level"] = 0
				
				if quality_repair and quality_repair.button_pressed:
					equipment["enhanced_durability"] = true
				
				dialog.emit_signal("equipment_repaired", equipment, repair_cost)
				
				# Remove from damaged list
				damaged_list.remove_item(selected_items[0])
				
				pass # Equipment repaired
			else:
				_show_trade_error("Insufficient credits for repair.")
		else:
			_show_trade_error("Please select equipment to repair.")

func _on_repair_all_pressed(dialog: Control) -> void:
	## Handle repair all button press
	var damaged_equipment = _get_damaged_equipment()
	var total_cost = 0
	
	for equipment in damaged_equipment:
		total_cost += _calculate_repair_cost(equipment)
	
	var current_credits = _get_current_credits()
	if current_credits >= total_cost:
		# Repair all equipment
		for equipment in damaged_equipment:
			equipment["damaged"] = false
			equipment["damage_level"] = 0
		
		# Clear damaged list
		var damaged_list = dialog.find_child("DamagedList")
		if damaged_list:
			damaged_list.clear()
			damaged_list.add_item("No damaged equipment found")
		
	else:
		_show_trade_error("Insufficient credits to repair all equipment.")

func _on_equipment_traded(action: String, equipment: Dictionary, credits: int) -> void:
	## Handle equipment trade completion
	pass # Trade completed
	_refresh_equipment_display()

func _on_equipment_repaired(equipment: Dictionary, cost: int) -> void:
	## Handle equipment repair completion
	pass # Repair completed
	_refresh_equipment_display()

func _show_trade_error(message: String) -> void:
	## Show error message for trade operations
	var error_dialog = AcceptDialog.new()
	error_dialog.dialog_text = message
	error_dialog.title = "Trade Error"
	
	get_tree().current_scene.add_child(error_dialog)
	error_dialog.popup_centered()
	
	# Auto-remove after user closes
	error_dialog.confirmed.connect(error_dialog.queue_free)
	error_dialog.canceled.connect(error_dialog.queue_free)
