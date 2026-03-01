extends "res://src/ui/screens/campaign/phases/BasePhasePanel.gd"
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const ThisClass = preload("res://src/ui/screens/campaign/phases/TradePhasePanel.gd")
const CompendiumEquipmentRef = preload("res://src/data/compendium_equipment.gd")

signal item_purchased(item_data: Dictionary)
signal item_sold(item_data: Dictionary)
signal trading_completed

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var credits_label: Label = $VBoxContainer/CreditsLabel
@onready var market_label: Label = $VBoxContainer/MarketLabel
@onready var available_items: ItemList = $VBoxContainer/AvailableItems
@onready var inventory_label: Label = $VBoxContainer/InventoryLabel
@onready var inventory_items: ItemList = $VBoxContainer/InventoryItems
@onready var item_details: RichTextLabel = $VBoxContainer/ItemDetails
@onready var buy_button: Button = $VBoxContainer/ButtonContainer/BuyButton
@onready var sell_button: Button = $VBoxContainer/ButtonContainer/SellButton
@onready var complete_button: Button = $VBoxContainer/CompleteButton

var current_credits: int = 0
var available_market_items: Array[Dictionary] = []
var inventory: Array[Dictionary] = []
var selected_market_item: Dictionary
var selected_inventory_item: Dictionary
var purchased_items: Array[Dictionary] = []
var sold_items: Array[Dictionary] = []

func _ready() -> void:
	super._ready()
	_style_phase_title(title_label)
	_style_section_label(credits_label)
	_style_section_label(market_label)
	_style_item_list(available_items)
	_style_section_label(inventory_label)
	_style_item_list(inventory_items)
	_style_rich_text(item_details)
	_style_phase_button(buy_button)
	_style_phase_button(sell_button)
	_style_phase_button(complete_button, true)
	if buy_button:
		buy_button.pressed.connect(_on_buy_button_pressed)
		buy_button.disabled = true
	if sell_button:
		sell_button.pressed.connect(_on_sell_button_pressed)
		sell_button.disabled = true
	if complete_button:
		complete_button.pressed.connect(_on_complete_button_pressed)
	if available_items:
		available_items.item_selected.connect(_on_market_item_selected)
	if inventory_items:
		inventory_items.item_selected.connect(_on_inventory_item_selected)
	update_credits_display()

func _get_campaign_safe():
	return game_state.campaign if game_state else null

func setup_phase() -> void:
	super.setup_phase()
	purchased_items.clear()
	sold_items.clear()
	selected_market_item = {}
	selected_inventory_item = {}
	var campaign = _get_campaign_safe()
	if campaign and "credits" in campaign:
		current_credits = campaign.credits
	else:
		current_credits = 0
	load_market_items()
	load_inventory()
	update_credits_display()

func _get_world_trait() -> int:
	var campaign = _get_campaign_safe()
	if not campaign:
		return 0
	var wd: Dictionary = campaign.world_data if "world_data" in campaign else {}
	var traits: Array = wd.get("traits", [])
	if traits.is_empty():
		return 0
	# Return first trait as location type for market generation
	var first_trait = traits[0]
	if first_trait is int:
		return first_trait
	if first_trait is String:
		# Try to map string trait to WorldTrait enum value
		var trait_map: Dictionary = {
			"TRADE_CENTER": GameEnums.WorldTrait.TRADE_CENTER,
			"TECH_CENTER": GameEnums.WorldTrait.TECH_CENTER,
			"INDUSTRIAL_HUB": GameEnums.WorldTrait.INDUSTRIAL_HUB,
			"PIRATE_HAVEN": GameEnums.WorldTrait.PIRATE_HAVEN,
			"FRONTIER_WORLD": GameEnums.WorldTrait.FRONTIER_WORLD,
			"FREE_PORT": GameEnums.WorldTrait.FREE_PORT,
			"MINING_COLONY": GameEnums.WorldTrait.MINING_COLONY,
			"AGRICULTURAL_WORLD": GameEnums.WorldTrait.AGRICULTURAL_WORLD,
			"CORPORATE_CONTROLLED": GameEnums.WorldTrait.CORPORATE_CONTROLLED,
		}
		return trait_map.get(first_trait, 0)
	return 0

func load_market_items() -> void:
	if not available_items:
		return
	available_items.clear()
	available_market_items.clear()

	var eq_mgr = get_node_or_null("/root/EquipmentManager")
	if eq_mgr and eq_mgr.has_method("generate_market_items"):
		var location_type: int = _get_world_trait()
		var items: Array = eq_mgr.generate_market_items(location_type, 10)
		for item in items:
			if item is Dictionary:
				available_market_items.append(item)
				var item_name: String = item.get("name", "Unknown Item")
				var item_cost: int = item.get("value", 50)
				var uses: int = item.get("remaining_uses", -1)
				var uses_str: String = " [%d uses]" % uses if uses >= 0 else ""
				available_items.add_item("%s%s (%d cr)" % [item_name, uses_str, item_cost])
	else:
		# Fallback if EquipmentManager unavailable
		var fallback_items: Array = [
			{"name": "Medkit", "value": 100, "type": "medkit", "category": 2},
			{"name": "Ammo Pack", "value": 50, "type": "ammo", "category": 2},
			{"name": "Armor Plate", "value": 200, "type": "armor", "category": 1}
		]
		for item in fallback_items:
			available_market_items.append(item)
			available_items.add_item("%s (%d cr)" % [item.get("name", "?"), item.get("value", 0)])

	# Compendium DLC: Ship parts + Psionic equipment
	var compendium_items: Array[Dictionary] = CompendiumEquipmentRef.get_trade_phase_items()
	for item in compendium_items:
		# Normalize cost key to "value" to match existing market item format
		var normalized: Dictionary = item.duplicate()
		normalized["value"] = item.get("cost", 0)
		normalized["compendium_id"] = item.get("id", "")
		available_market_items.append(normalized)
		var item_name: String = item.get("name", "Unknown")
		var item_cost: int = item.get("cost", 0)
		var slot: String = item.get("slot", "")
		var slot_str: String = " [%s]" % slot if not slot.is_empty() else ""
		available_items.add_item("%s%s (%d cr)" % [item_name, slot_str, item_cost])

func load_inventory() -> void:
	if not inventory_items:
		return
	inventory_items.clear()
	inventory.clear()

	var campaign = _get_campaign_safe()
	if not campaign:
		return

	# Load crew member equipment
	var members: Array = []
	if campaign.has_method("get_crew_members"):
		members = campaign.get_crew_members()
	elif "crew_data" in campaign:
		members = campaign.crew_data.get("members", [])

	for member in members:
		if not member is Dictionary:
			continue
		var owner_name: String = member.get("character_name", member.get("name", "Unknown"))
		var equipment: Array = member.get("equipment", [])
		for eq_item in equipment:
			var inv_item: Dictionary = {}
			if eq_item is Dictionary:
				inv_item = eq_item.duplicate()
			elif eq_item is String:
				inv_item = {"name": eq_item, "value": 25}
			else:
				continue
			inv_item["_owner_name"] = owner_name
			inv_item["_source"] = "crew"
			inv_item["_member_ref"] = member
			var sell_val: int = _calculate_sell_value(inv_item)
			inv_item["_sell_value"] = sell_val
			inventory.append(inv_item)
			var item_name: String = inv_item.get("name", "Unknown")
			var inv_uses: int = inv_item.get("remaining_uses", -1)
			var inv_uses_str: String = " [%d uses]" % inv_uses if inv_uses >= 0 else ""
			inventory_items.add_item("%s%s [%s] (%d cr)" % [item_name, inv_uses_str, owner_name, sell_val])

	# Load ship stash (equipment pool)
	if "equipment_data" in campaign:
		var pool: Array = []
		if campaign.has_method("get_all_equipment"):
			pool = campaign.get_all_equipment()
		else:
			pool = campaign.equipment_data.get("equipment", [])
		for pool_item in pool:
			var inv_item: Dictionary = {}
			if pool_item is Dictionary:
				inv_item = pool_item.duplicate()
			elif pool_item is String:
				inv_item = {"name": pool_item, "value": 25}
			else:
				continue
			inv_item["_owner_name"] = "Ship Stash"
			inv_item["_source"] = "pool"
			var sell_val: int = _calculate_sell_value(inv_item)
			inv_item["_sell_value"] = sell_val
			inventory.append(inv_item)
			var item_name: String = inv_item.get("name", "Unknown")
			var pool_uses: int = inv_item.get("remaining_uses", -1)
			var pool_uses_str: String = " [%d uses]" % pool_uses if pool_uses >= 0 else ""
			inventory_items.add_item("%s%s [Ship Stash] (%d cr)" % [item_name, pool_uses_str, sell_val])

func _calculate_sell_value(item: Dictionary) -> int:
	var base_value: int = item.get("value", 50)
	var condition: int = item.get("condition", 100)
	return int(base_value * (condition / 100.0) * 0.5)

func update_credits_display() -> void:
	if credits_label:
		credits_label.text = "Credits: " + str(current_credits)

func _on_market_item_selected(index: int) -> void:
	if index >= 0 and index < available_market_items.size():
		selected_market_item = available_market_items[index]
		var cost: int = selected_market_item.get("value", 0)
		if buy_button:
			buy_button.disabled = cost > current_credits
		if item_details:
			var name_str: String = selected_market_item.get("name", "Unknown")
			var type_str: String = selected_market_item.get("type", "")
			var desc: String = name_str
			if not type_str.is_empty():
				desc += " (%s)" % type_str
			desc += "\nCost: %d credits" % cost
			var traits: Array = selected_market_item.get("traits", [])
			if not traits.is_empty():
				desc += "\nTraits: %s" % ", ".join(traits)
			var uses: int = selected_market_item.get("remaining_uses", -1)
			if uses >= 0:
				desc += "\nUses: %d" % uses
			item_details.text = desc

func _on_inventory_item_selected(index: int) -> void:
	if index >= 0 and index < inventory.size():
		selected_inventory_item = inventory[index]
		if sell_button:
			sell_button.disabled = false
		if item_details:
			var name_str: String = selected_inventory_item.get("name", "Unknown")
			var owner: String = selected_inventory_item.get("_owner_name", "Unknown")
			var sell_val: int = selected_inventory_item.get("_sell_value", 0)
			var type_str: String = selected_inventory_item.get("type", "")
			var desc: String = name_str
			if not type_str.is_empty():
				desc += " (%s)" % type_str
			desc += "\nOwner: %s" % owner
			desc += "\nSell Value: %d credits" % sell_val
			item_details.text = desc

func _on_buy_button_pressed() -> void:
	if selected_market_item.is_empty():
		return
	var cost: int = selected_market_item.get("value", 0)
	if cost > current_credits:
		return
	current_credits -= cost
	# Add to campaign equipment pool
	var campaign = _get_campaign_safe()
	if campaign and "equipment_data" in campaign:
		var pool: Array = []
		if campaign.has_method("get_all_equipment"):
			pool = campaign.get_all_equipment()
		else:
			pool = campaign.equipment_data.get("equipment", [])
		var item_copy: Dictionary = selected_market_item.duplicate()
		item_copy.erase("_owner_name")
		item_copy.erase("_source")
		item_copy.erase("_sell_value")
		item_copy.erase("_member_ref")
		pool.append(item_copy)
		campaign.equipment_data["equipment"] = pool
	purchased_items.append(selected_market_item.duplicate())
	item_purchased.emit(selected_market_item)
	# Remove purchased item from market
	var idx: int = available_market_items.find(selected_market_item)
	if idx >= 0:
		available_market_items.remove_at(idx)
	selected_market_item = {}
	if buy_button:
		buy_button.disabled = true
	_refresh_market_list()
	load_inventory()
	update_credits_display()

func _on_sell_button_pressed() -> void:
	if selected_inventory_item.is_empty():
		return
	var sell_val: int = selected_inventory_item.get("_sell_value", 0)
	current_credits += sell_val
	# Remove from source
	var campaign = _get_campaign_safe()
	if campaign:
		var source: String = selected_inventory_item.get("_source", "")
		if source == "pool" and "equipment_data" in campaign:
			var pool: Array = []
			if campaign.has_method("get_all_equipment"):
				pool = campaign.get_all_equipment()
			else:
				pool = campaign.equipment_data.get("equipment", [])
			# Find and remove matching item from pool
			for i in range(pool.size() - 1, -1, -1):
				var pool_item = pool[i]
				if pool_item is Dictionary and pool_item.get("id", "") == selected_inventory_item.get("id", "_no_match"):
					pool.remove_at(i)
					break
				elif pool_item is Dictionary and pool_item.get("name", "") == selected_inventory_item.get("name", "_no_match"):
					pool.remove_at(i)
					break
			campaign.equipment_data["equipment"] = pool
		elif source == "crew":
			var member_ref = selected_inventory_item.get("_member_ref")
			if member_ref is Dictionary:
				var equipment: Array = member_ref.get("equipment", [])
				var item_name: String = selected_inventory_item.get("name", "")
				var item_id: String = selected_inventory_item.get("id", "")
				for i in range(equipment.size() - 1, -1, -1):
					var eq = equipment[i]
					if eq is Dictionary and (eq.get("id", "") == item_id or eq.get("name", "") == item_name):
						equipment.remove_at(i)
						break
					elif eq is String and eq == item_name:
						equipment.remove_at(i)
						break
	sold_items.append(selected_inventory_item.duplicate())
	item_sold.emit(selected_inventory_item)
	selected_inventory_item = {}
	if sell_button:
		sell_button.disabled = true
	load_inventory()
	update_credits_display()

func _refresh_market_list() -> void:
	if not available_items:
		return
	available_items.clear()
	for item in available_market_items:
		var item_name: String = item.get("name", "Unknown Item")
		var item_cost: int = item.get("value", 50)
		available_items.add_item("%s (%d cr)" % [item_name, item_cost])

func _on_complete_button_pressed() -> void:
	var campaign = _get_campaign_safe()
	if campaign and "credits" in campaign:
		campaign.credits = current_credits
	trading_completed.emit()
	complete_phase()

func validate_phase_requirements() -> bool:
	return true

func get_phase_data() -> Dictionary:
	return {
		"credits": current_credits,
		"purchased_items": purchased_items.duplicate(),
		"sold_items": sold_items.duplicate()
	}
