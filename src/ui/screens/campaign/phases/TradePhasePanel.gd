extends "res://src/ui/screens/campaign/phases/BasePhasePanel.gd"
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const ThisClass = preload("res://src/ui/screens/campaign/phases/TradePhasePanel.gd")
const CompendiumEquipmentRef = preload("res://src/data/compendium_equipment.gd")
const CompendiumWorldOptions = preload("res://src/data/compendium_world_options.gd")

signal item_purchased(item_data: Dictionary)
signal item_sold(item_data: Dictionary)
signal trading_completed

const BASIC_WEAPONS: Array = [
	{"name": "Handgun", "type": "weapon", "value": 1, "_basic": true},
	{"name": "Blade", "type": "weapon", "value": 1, "_basic": true},
	{"name": "Colony Rifle", "type": "weapon", "value": 1, "_basic": true},
	{"name": "Shotgun", "type": "weapon", "value": 1, "_basic": true},
]
const MAX_SELL_PER_TURN: int = 3
const TABLE_ROLL_COST: int = 3

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
var roll_table_button: Button = null
var merchant_reroll_button: Button = null
var has_merchant_crew: bool = false
var merchant_reroll_used: bool = false
var last_rolled_item: Dictionary = {}
# Expanded Loans (Compendium DLC — self-gated via CompendiumWorldOptions)
var loan_container: VBoxContainer = null
var loan_status_label: RichTextLabel = null
var take_loan_button: Button = null
var current_loan: Dictionary = {}  # Active loan data (origin, rate, enforcement, debt)

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
		_style_button_disabled(buy_button)
	if sell_button:
		sell_button.pressed.connect(_on_sell_button_pressed)
		sell_button.disabled = true
		_style_button_disabled(sell_button)
	if complete_button:
		complete_button.pressed.connect(_on_complete_button_pressed)
	if available_items:
		available_items.item_selected.connect(_on_market_item_selected)
	if inventory_items:
		inventory_items.item_selected.connect(_on_inventory_item_selected)
	# Add "Roll on Table (3cr)" button
	var btn_container = buy_button.get_parent() if buy_button else null
	if btn_container:
		roll_table_button = Button.new()
		roll_table_button.text = "Roll Random Item (3cr)"
		roll_table_button.pressed.connect(_on_roll_table_pressed)
		btn_container.add_child(roll_table_button)
		_style_phase_button(roll_table_button)
		# Merchant reroll button (hidden by default)
		merchant_reroll_button = Button.new()
		merchant_reroll_button.text = "Merchant Reroll"
		merchant_reroll_button.pressed.connect(_on_merchant_reroll_pressed)
		merchant_reroll_button.visible = false
		btn_container.add_child(merchant_reroll_button)
		_style_phase_button(merchant_reroll_button)
	_setup_loan_ui()
	update_credits_display()

func _get_campaign_safe():
	return game_state.campaign if game_state else null

func setup_phase() -> void:
	super.setup_phase()
	purchased_items.clear()
	sold_items.clear()
	selected_market_item = {}
	selected_inventory_item = {}
	merchant_reroll_used = false
	last_rolled_item = {}
	var campaign = _get_campaign_safe()
	if campaign and "credits" in campaign:
		current_credits = campaign.credits
	else:
		current_credits = 0
	has_merchant_crew = _check_merchant_crew()
	load_market_items()
	load_inventory()
	update_credits_display()
	_update_sell_button_state()

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

	# Basic weapons — always available, 1 credit each, unlimited (p.126)
	for bw in BASIC_WEAPONS:
		var item: Dictionary = bw.duplicate()
		available_market_items.append(item)
		available_items.add_item("%s (1cr - Basic)" % item.get("name", "?"))

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
				available_items.add_item("%s%s (%s)" % [item_name, uses_str, _format_credits_short(item_cost)])
	else:
		# Fallback if EquipmentManager unavailable
		var fallback_items: Array = [
			{"name": "Medkit", "value": 100, "type": "medkit", "category": 2},
			{"name": "Ammo Pack", "value": 50, "type": "ammo", "category": 2},
			{"name": "Armor Plate", "value": 200, "type": "armor", "category": 1}
		]
		for item in fallback_items:
			available_market_items.append(item)
			available_items.add_item("%s (%s)" % [item.get("name", "?"), _format_credits_short(item.get("value", 0))])

	# Compendium DLC: Ship parts + Psionic equipment (with lock indicators)
	var compendium_items: Array[Dictionary] = CompendiumEquipmentRef.get_trade_phase_items_with_lock_status()
	for item in compendium_items:
		# Normalize cost key to "value" to match existing market item format
		var normalized: Dictionary = item.duplicate()
		normalized["value"] = item.get("cost", 0)
		normalized["compendium_id"] = item.get("id", "")
		var is_locked: bool = item.get("_dlc_locked", false)
		normalized["_dlc_locked"] = is_locked
		available_market_items.append(normalized)
		var item_name: String = item.get("name", "Unknown")
		var item_cost: int = item.get("cost", 0)
		var slot: String = item.get("slot", "")
		var slot_str: String = " [%s]" % slot if not slot.is_empty() else ""
		if is_locked:
			available_items.add_item("(DLC) %s%s" % [item_name, slot_str])
			var idx: int = available_items.item_count - 1
			available_items.set_item_disabled(idx, true)
			available_items.set_item_tooltip(idx, "Requires Compendium DLC to purchase")
		else:
			available_items.add_item("%s%s (%s)" % [item_name, slot_str, _format_credits_short(item_cost)])

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
			inventory_items.add_item("%s%s [%s] (%s)" % [item_name, inv_uses_str, owner_name, _format_credits_short(sell_val)])

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
			inventory_items.add_item("%s%s [Ship Stash] (%s)" % [item_name, pool_uses_str, _format_credits_short(sell_val)])

	# Empty state for inventory
	if inventory.is_empty():
		inventory_items.add_item("No items to sell")
		inventory_items.set_item_disabled(0, true)

func _calculate_sell_value(item: Dictionary) -> int:
	var base_value: int = int(item.get("value", 50))
	var raw_condition = item.get("condition", 100)
	var condition: int = 100
	if raw_condition is int or raw_condition is float:
		condition = int(raw_condition)
	elif raw_condition is String:
		match raw_condition.to_lower():
			"standard", "good", "new": condition = 100
			"worn": condition = 75
			"damaged": condition = 50
			"broken": condition = 25
			_: condition = 100
	return int(base_value * (condition / 100.0) * 0.5)

func update_credits_display() -> void:
	if credits_label:
		credits_label.text = "Credits: " + _format_credits(current_credits)

func _on_market_item_selected(index: int) -> void:
	if index >= 0 and index < available_market_items.size():
		selected_market_item = available_market_items[index]
		var cost: int = selected_market_item.get("value", 0)
		if buy_button:
			var too_expensive: bool = cost > current_credits
			buy_button.disabled = too_expensive
			if too_expensive:
				buy_button.tooltip_text = "Need %s, have %s" \
					% [_format_credits_long(cost), _format_credits_long(current_credits)]
			else:
				buy_button.tooltip_text = ""
		if item_details:
			var name_str: String = selected_market_item.get("name", "Unknown")
			var type_str: String = selected_market_item.get("type", "")
			var desc: String = name_str
			if not type_str.is_empty():
				desc += " (%s)" % type_str
			desc += "\nCost: %s" % _format_credits_long(cost)
			var traits: Array = selected_market_item.get("traits", [])
			if not traits.is_empty():
				desc += "\nTraits: %s" % ", ".join(traits)
			var uses: int = selected_market_item.get("remaining_uses", -1)
			if uses >= 0:
				desc += "\nUses: %d" % uses
			_set_keyword_text(item_details, desc)

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
			desc += "\nSell Value: %s" % _format_credits_long(sell_val)
			_set_keyword_text(item_details, desc)

func _on_buy_button_pressed() -> void:
	if selected_market_item.is_empty():
		return
	if selected_market_item.get("_dlc_locked", false):
		if item_details:
			_set_keyword_text(item_details,
				"[color=#D97706]This item requires Compendium DLC[/color]")
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
	# Remove purchased item from market (basic weapons stay — unlimited supply, p.126)
	var is_basic_weapon: bool = selected_market_item.get("_basic", false)
	if not is_basic_weapon:
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
	# Enforce sell cap: max 3 un-damaged items per turn (p.126)
	if sold_items.size() >= MAX_SELL_PER_TURN:
		if item_details:
			_set_keyword_text(item_details,
				"[color=#D97706]Sell limit reached (max %d per turn)[/color]"
				% MAX_SELL_PER_TURN)
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
	_update_sell_button_state()

func _refresh_market_list() -> void:
	if not available_items:
		return
	available_items.clear()
	for item in available_market_items:
		var item_name: String = item.get("name", "Unknown Item")
		var item_cost: int = item.get("value", 50)
		if item.get("_dlc_locked", false):
			var slot: String = item.get("slot", "")
			var slot_str: String = " [%s]" % slot if not slot.is_empty() else ""
			available_items.add_item("(DLC) %s%s" % [item_name, slot_str])
			var idx: int = available_items.item_count - 1
			available_items.set_item_disabled(idx, true)
			available_items.set_item_tooltip(idx, "Requires Compendium DLC to purchase")
		elif item.get("_basic", false):
			available_items.add_item("%s (1cr - Basic)" % item_name)
		else:
			var uses: int = item.get("remaining_uses", -1)
			var uses_str: String = " [%d uses]" % uses if uses >= 0 else ""
			available_items.add_item("%s%s (%s)" % [item_name, uses_str, _format_credits_short(item_cost)])

func _on_complete_button_pressed() -> void:
	var campaign = _get_campaign_safe()
	if campaign and "credits" in campaign:
		campaign.credits = current_credits
	# Log trading transactions to CampaignJournal
	if not purchased_items.is_empty() or not sold_items.is_empty():
		var journal = get_node_or_null("/root/CampaignJournal")
		if journal and journal.has_method("create_entry"):
			var turn_num: int = 0
			if campaign and "progress_data" in campaign:
				turn_num = campaign.progress_data.get("turns_played", 0)
			var desc_parts: Array[String] = []
			if not purchased_items.is_empty():
				desc_parts.append("Bought %d items" % purchased_items.size())
			if not sold_items.is_empty():
				desc_parts.append("Sold %d items" % sold_items.size())
			journal.create_entry({
				"turn_number": turn_num,
				"type": "purchase",
				"auto_generated": true,
				"title": "Trading Session",
				"description": ". ".join(desc_parts) + ".",
				"mood": "neutral",
				"tags": ["trading"],
				"stats": {"items_bought": purchased_items.size(), "items_sold": sold_items.size()},
			})
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

func _update_sell_button_state() -> void:
	## Disable sell button when sell cap reached
	if sell_button and sold_items.size() >= MAX_SELL_PER_TURN:
		sell_button.disabled = true
		sell_button.tooltip_text = "Sell limit reached (%d/%d)" \
			% [sold_items.size(), MAX_SELL_PER_TURN]

func _on_roll_table_pressed() -> void:
	## Purchase random item from Military/Gear/Gadget table (3cr, p.126)
	if current_credits < TABLE_ROLL_COST:
		if item_details:
			_set_keyword_text(item_details,
				"[color=#D97706]Need %s to roll on table[/color]"
				% _format_credits_long(TABLE_ROLL_COST))
		return
	current_credits -= TABLE_ROLL_COST
	var eq_mgr = get_node_or_null("/root/EquipmentManager")
	var rolled_item: Dictionary = {}
	if eq_mgr and eq_mgr.has_method("generate_market_items"):
		var items: Array = eq_mgr.generate_market_items(0, 1)
		if not items.is_empty() and items[0] is Dictionary:
			rolled_item = items[0]
	if rolled_item.is_empty():
		# Fallback random item
		rolled_item = {"name": "Field Supplies", "value": 15, "type": "gear"}
	last_rolled_item = rolled_item.duplicate()
	# Add to campaign equipment pool
	var campaign = _get_campaign_safe()
	if campaign and "equipment_data" in campaign:
		var pool: Array = campaign.equipment_data.get("equipment", [])
		pool.append(rolled_item.duplicate())
		campaign.equipment_data["equipment"] = pool
	purchased_items.append(rolled_item.duplicate())
	item_purchased.emit(rolled_item)
	if item_details:
		_set_keyword_text(item_details,
			"[color=#10B981]Rolled: %s[/color]\nAdded to Ship Stash"
			% rolled_item.get("name", "Unknown"))
	# Show merchant reroll option if available
	if has_merchant_crew and not merchant_reroll_used:
		if merchant_reroll_button:
			merchant_reroll_button.visible = true
	load_inventory()
	update_credits_display()

func _on_merchant_reroll_pressed() -> void:
	## Merchant school reroll — reroll last table purchase (1/turn, p.126)
	if merchant_reroll_used:
		if item_details:
			_set_keyword_text(item_details,
				"[color=#D97706]Merchant reroll already used this turn[/color]")
		return
	if last_rolled_item.is_empty():
		return
	merchant_reroll_used = true
	if merchant_reroll_button:
		merchant_reroll_button.visible = false
	# Remove last rolled item from pool
	var campaign = _get_campaign_safe()
	if campaign and "equipment_data" in campaign:
		var pool: Array = campaign.equipment_data.get("equipment", [])
		var old_name: String = last_rolled_item.get("name", "")
		for i in range(pool.size() - 1, -1, -1):
			if pool[i] is Dictionary and pool[i].get("name", "") == old_name:
				pool.remove_at(i)
				break
		campaign.equipment_data["equipment"] = pool
	# Remove from purchased list
	for i in range(purchased_items.size() - 1, -1, -1):
		if purchased_items[i].get("name", "") == last_rolled_item.get("name", ""):
			purchased_items.remove_at(i)
			break
	# Roll new item
	var eq_mgr = get_node_or_null("/root/EquipmentManager")
	var new_item: Dictionary = {}
	if eq_mgr and eq_mgr.has_method("generate_market_items"):
		var items: Array = eq_mgr.generate_market_items(0, 1)
		if not items.is_empty() and items[0] is Dictionary:
			new_item = items[0]
	if new_item.is_empty():
		new_item = {"name": "Repair Kit", "value": 20, "type": "gear"}
	# Add replacement to pool
	if campaign and "equipment_data" in campaign:
		var pool: Array = campaign.equipment_data.get("equipment", [])
		pool.append(new_item.duplicate())
		campaign.equipment_data["equipment"] = pool
	purchased_items.append(new_item.duplicate())
	var old_item_name: String = last_rolled_item.get("name", "?")
	last_rolled_item = new_item.duplicate()
	if item_details:
		_set_keyword_text(item_details,
			"[color=#4FC3F7]Merchant Reroll: %s[/color]\n(replaces %s)"
			% [new_item.get("name", "?"), old_item_name])
	load_inventory()

func _check_merchant_crew() -> bool:
	## Check if any crew member has Merchant school training
	var campaign = _get_campaign_safe()
	if not campaign:
		return false
	var members: Array = []
	if campaign.has_method("get_crew_members"):
		members = campaign.get_crew_members()
	elif "crew_data" in campaign:
		members = campaign.crew_data.get("members", [])
	for member in members:
		if not member is Dictionary:
			continue
		var training: Array = member.get("training", [])
		for t in training:
			var t_name: String = ""
			if t is Dictionary:
				t_name = t.get("name", "").to_lower()
			elif t is String:
				t_name = t.to_lower()
			if "merchant" in t_name:
				return true
	return false

## ── Expanded Loans (Compendium DLC, pp.152-158) ──

func _setup_loan_ui() -> void:
	## Add loan section between credits and market (only visible when DLC enabled)
	var root_vbox = credits_label.get_parent() if credits_label else null
	if not root_vbox:
		return
	# Probe: returns {} if EXPANDED_LOANS flag disabled
	var probe: Dictionary = CompendiumWorldOptions.roll_loan_origin()
	if probe.is_empty():
		return  # DLC not enabled — no loan UI

	loan_container = VBoxContainer.new()
	loan_container.name = "LoanSection"

	var loan_header: Label = Label.new()
	loan_header.text = "Loan Office"
	_style_section_label(loan_header)
	loan_container.add_child(loan_header)

	loan_status_label = RichTextLabel.new()
	loan_status_label.bbcode_enabled = true
	loan_status_label.fit_content = true
	loan_status_label.custom_minimum_size = Vector2(0, 40)
	loan_status_label.scroll_active = false
	_style_rich_text(loan_status_label)
	loan_container.add_child(loan_status_label)

	take_loan_button = Button.new()
	take_loan_button.text = "Take Out a Loan"
	take_loan_button.pressed.connect(_on_take_loan_pressed)
	_style_phase_button(take_loan_button)
	loan_container.add_child(take_loan_button)

	# Insert after credits_label
	var credits_idx: int = root_vbox.get_children().find(credits_label)
	root_vbox.add_child(loan_container)
	if credits_idx >= 0:
		root_vbox.move_child(loan_container, credits_idx + 1)

	_refresh_loan_display()

func _refresh_loan_display() -> void:
	## Update loan status text and button state
	if not loan_status_label:
		return
	_load_current_loan()
	if current_loan.is_empty():
		loan_status_label.text = "No active loan. Take one out if you need credits."
		if take_loan_button:
			take_loan_button.disabled = false
			take_loan_button.text = "Take Out a Loan"
	else:
		# Apply interest for this turn (Compendium loan lifecycle)
		_apply_loan_interest()
		# Check enforcement threshold
		var enforcement_text := _check_loan_enforcement()

		var debt: int = current_loan.get("debt", 0)
		var origin_name: String = current_loan.get("origin_name", "Unknown")
		var rate_name: String = current_loan.get("rate_name", "Standard")
		var turns: int = current_loan.get("turns_active", 0)
		var display := "[color=#D97706]Active Loan[/color] from %s\nDebt: [color=#DC2626]%dcr[/color] | Rate: %s | Turn %d" % [origin_name, debt, rate_name, turns]
		if not enforcement_text.is_empty():
			display += "\n[color=#DC2626]%s[/color]" % enforcement_text
		display += "\nPay debt from credits to clear."
		loan_status_label.text = display
		if take_loan_button:
			take_loan_button.disabled = true
			take_loan_button.text = "Already have a loan"


func _apply_loan_interest() -> void:
	## Calculate and apply interest using Compendium loan tables
	if current_loan.is_empty():
		return
	var rate_data := {
		"low": current_loan.get("rate_low", 1),
		"high": current_loan.get("rate_high", 2),
	}
	var interest: int = CompendiumWorldOptions.calculate_interest(
		current_loan.get("debt", 0), rate_data
	)
	if interest > 0:
		current_loan["debt"] = current_loan.get("debt", 0) + interest
		current_loan["turns_active"] = current_loan.get("turns_active", 0) + 1
		_save_current_loan()


func _check_loan_enforcement() -> String:
	## Check if debt has exceeded enforcement thresholds (Compendium loan rules)
	if current_loan.is_empty():
		return ""
	var debt: int = current_loan.get("debt", 0)
	var threshold_2: int = current_loan.get("enforcement_threshold_2", 0)
	var threshold_1: int = current_loan.get("enforcement_threshold_1", 0)
	var origin_id: String = current_loan.get("origin_id", "")

	if threshold_2 > 0 and debt >= threshold_2:
		var method: Dictionary = CompendiumWorldOptions.roll_enforcement_method(origin_id)
		if not method.is_empty():
			return "ENFORCEMENT (Tier 2): %s" % method.get("instruction", "Lender takes action")
	elif threshold_1 > 0 and debt >= threshold_1:
		var method: Dictionary = CompendiumWorldOptions.roll_enforcement_method(origin_id)
		if not method.is_empty():
			return "WARNING: %s" % method.get("instruction", "Lender is getting impatient")

func _load_current_loan() -> void:
	## Load active loan from campaign progress_data
	current_loan = {}
	var campaign = _get_campaign_safe()
	if not campaign:
		return
	if "progress_data" in campaign:
		current_loan = campaign.progress_data.get("active_loan", {})

func _save_current_loan() -> void:
	## Persist active loan to campaign progress_data
	var campaign = _get_campaign_safe()
	if not campaign or not "progress_data" in campaign:
		return
	if current_loan.is_empty():
		campaign.progress_data.erase("active_loan")
	else:
		campaign.progress_data["active_loan"] = current_loan.duplicate()

func _on_take_loan_pressed() -> void:
	## Roll loan terms using Compendium tables and offer to player
	var origin: Dictionary = CompendiumWorldOptions.roll_loan_origin()
	if origin.is_empty():
		return
	var rate: Dictionary = CompendiumWorldOptions.roll_interest_rate()
	var enforcement: Dictionary = CompendiumWorldOptions.roll_enforcement_threshold()

	# Loan amount: flat 20cr (Compendium standard starting loan)
	var loan_amount: int = 20

	current_loan = {
		"debt": loan_amount,
		"origin_id": origin.get("id", ""),
		"origin_name": origin.get("name", "Unknown"),
		"rate_id": rate.get("id", ""),
		"rate_name": rate.get("name", "Standard"),
		"rate_low": rate.get("low", 1),
		"rate_high": rate.get("high", 2),
		"enforcement_threshold_1": enforcement.get("threshold_1", 0),
		"enforcement_threshold_2": enforcement.get("threshold_2", 0),
		"turns_active": 0,
	}

	# Grant loan credits
	current_credits += loan_amount
	_save_current_loan()
	update_credits_display()
	_refresh_loan_display()

	if item_details:
		var desc: String = "[color=#10B981]Loan Taken: +%dcr[/color]\n" % loan_amount
		desc += "Origin: %s\n" % origin.get("name", "Unknown")
		desc += "Rate: %s\n" % rate.get("name", "Standard")
		desc += origin.get("instruction", "")
		_set_keyword_text(item_details, desc)
