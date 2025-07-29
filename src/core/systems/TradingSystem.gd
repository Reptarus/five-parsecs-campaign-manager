class_name TradingSystem
extends Resource

## Trading System for Five Parsecs Campaign Manager
## Enhanced with JSON data integration for comprehensive equipment trading
## Uses data/equipment_database.json and other data files for trading

const DataManager = preload("res://src/core/data/DataManager.gd")

signal market_generated(items: Array[Resource])
signal trade_completed(item: Resource, transaction_type: String, credits: int)
signal trade_failed(reason: String)
signal price_fluctuation_occurred(item_type: String, old_price: int, new_price: int)
signal rare_item_available(item: Resource)
signal trade_opportunity_discovered(opportunity: Dictionary)
signal equipment_data_loaded(items_count: int)

# JSON data loaded from files
var equipment_data: Dictionary = {}
var weapons_data: Dictionary = {}
var armor_data: Dictionary = {}
var gear_data: Dictionary = {}
var loot_tables: Dictionary = {}
var data_manager: DataManager = null

# Legacy compatibility - fallback data
var equipment_categories = {}
var item_base_prices = {}

# Market conditions
var market_conditions = ["Poor", "Average", "Good", "Excellent"]

func _init() -> void:
	"""Initialize trading system with JSON data"""
	_load_trading_data()

func _load_trading_data() -> void:
	"""Load trading data from JSON files"""
	data_manager = DataManager.new()
	
	# Load equipment database
	equipment_data = data_manager.load_json_file("res://data/equipment_database.json")
	if equipment_data.is_empty():
		push_warning("Equipment database not found, trying individual files")
		_load_individual_equipment_files()
	else:
		print("TradingSystem: Loaded equipment database with %d total items" % _count_total_items())
		_extract_equipment_categories()
		equipment_data_loaded.emit(_count_total_items())
	
	# Load loot tables if available
	loot_tables = data_manager.load_json_file("res://data/loot_tables.json")
	if loot_tables.is_empty():
		print("TradingSystem: No loot tables found, using defaults")
	
	# Build legacy compatibility
	_build_legacy_compatibility()

func _load_individual_equipment_files() -> void:
	"""Load equipment from individual JSON files as fallback"""
	weapons_data = data_manager.load_json_file("res://data/weapons.json")
	armor_data = data_manager.load_json_file("res://data/armor.json")
	gear_data = data_manager.load_json_file("res://data/gear_database.json")
	
	# Combine into equipment_data structure
	equipment_data = {
		"weapons": weapons_data.get("weapons", []),
		"armor": armor_data.get("armor", []),
		"gear": gear_data.get("gear", [])
	}
	
	if equipment_data.get("weapons", []).size() > 0 or equipment_data.get("armor", []).size() > 0:
		print("TradingSystem: Loaded equipment from individual files - %d total items" % _count_total_items())
		equipment_data_loaded.emit(_count_total_items())
	else:
		push_error("Failed to load equipment data from any JSON files")
		_load_fallback_trading_data()

func _load_fallback_trading_data() -> void:
	"""Load fallback trading data if JSON fails"""
	equipment_categories = {
		"weapons": ["Handgun", "Shotgun", "Military Rifle", "Blade", "Auto Pistol", "Scrap Pistol"],
		"armor": ["Combat Armor", "Flak Screen", "Shield Belt", "Mesh Armor"],
		"gear": ["Scanner", "Comms", "Med Kit", "Stimm", "Boosters", "Bypass"],
		"supplies": ["Ration Pack", "Fuel Cell", "Spare Parts", "Ammunition"]
	}
	
	item_base_prices = {
		"Handgun": 6, "Shotgun": 8, "Military Rifle": 12, "Blade": 3, "Auto Pistol": 9,
		"Combat Armor": 15, "Flak Screen": 8, "Shield Belt": 10, "Mesh Armor": 6,
		"Scanner": 7, "Comms": 5, "Med Kit": 4, "Stimm": 3, "Boosters": 5,
		"Ration Pack": 1, "Fuel Cell": 2, "Spare Parts": 3, "Ammunition": 1
	}

func _count_total_items() -> int:
	"""Count total items across all equipment categories"""
	var total = 0
	for category in ["weapons", "armor", "gear", "attachments"]:
		total += equipment_data.get(category, []).size()
	return total

func _extract_equipment_categories() -> void:
	"""Extract equipment categories from JSON data"""
	equipment_categories = {}
	
	for category in ["weapons", "armor", "gear", "attachments"]:
		var items = []
		for item in equipment_data.get(category, []):
			items.append(item.get("name", "Unknown Item"))
		equipment_categories[category] = items

func _build_legacy_compatibility() -> void:
	"""Build legacy item_base_prices from JSON data"""
	item_base_prices = {}
	
	for category in ["weapons", "armor", "gear", "attachments"]:
		for item in equipment_data.get(category, []):
			var name = item.get("name", "Unknown Item")
			var cost = item.get("cost", 5)
			item_base_prices[name] = cost

# Advanced market dynamics
var price_history: Dictionary = {} # Track price changes over time
var supply_demand: Dictionary = {} # Track supply/demand for each item
var faction_preferences: Dictionary = {
	"unity": {"gear": 1.3, "supplies": 1.2, "weapons": 0.8, "armor": 0.9},
	"corpo": {"gear": 1.5, "supplies": 1.1, "weapons": 1.0, "armor": 1.2},
	"freelancer": {"weapons": 1.4, "armor": 1.3, "gear": 1.1, "supplies": 1.0},
	"pirates": {"weapons": 1.5, "armor": 1.2, "gear": 0.8, "supplies": 0.9}
}
var current_faction_influence: String = "freelancer"
var market_volatility: float = 0.1 # 10% price variance
var turns_since_last_fluctuation: int = 0

# Rare and exotic items
var rare_items = {
	"exotic_weapons": ["Plasma Rifle", "Needle Rifle", "Razor Rifle"],
	"alien_tech": ["Precursor Scanner", "Unity Biomod", "Conversion Beam"],
	"corporate_gear": ["Military Bot", "Stasis Field", "Neural Interface"]
}

var rare_item_base_prices = {
	"Plasma Rifle": 25, "Needle Rifle": 20, "Razor Rifle": 18,
	"Precursor Scanner": 15, "Unity Biomod": 12, "Conversion Beam": 30,
	"Military Bot": 35, "Stasis Field": 22, "Neural Interface": 28
}

func generate_market(world_type: String = "frontier", faction: String = "") -> Array[Resource]:
	"""Generate a market based on world type and Five Parsecs trading rules"""
	var market_items: Array[Resource] = []
	var market_condition = _determine_market_condition(world_type)
	var item_count = _calculate_market_size(market_condition)

	# Set faction influence if provided
	if faction != "":
		current_faction_influence = faction

	# Apply price fluctuations
	_apply_market_fluctuations()

	# Generate items for each category
	for category in equipment_categories.keys():
		var category_items = _generate_category_items(category, market_condition, world_type)
		market_items.append_array(category_items)

	# Generate rare items (small chance)
	var rare_item_chance = _calculate_rare_item_chance(world_type, market_condition)
	if randf() < rare_item_chance:
		var rare_item = _generate_rare_item(world_type)
		if rare_item:
			market_items.append(rare_item)
			rare_item_available.emit(rare_item)

	# Generate trade opportunities
	var opportunities = _generate_advanced_trade_opportunities(world_type)
	for opportunity in opportunities:
		trade_opportunity_discovered.emit(opportunity)

	# Limit total items
	if market_items.size() > item_count:
		market_items.shuffle()
		market_items = market_items.slice(0, item_count)

	# Update supply/demand tracking
	_update_supply_demand_tracking(market_items)

	market_generated.emit(market_items) # warning: return value discarded (intentional)
	return market_items

func _determine_market_condition(world_type: String) -> String:
	"""Determine market condition based on world _type"""
	var condition_roll = randi_range(1, 6)

	match world_type:
		"core":
			return market_conditions[min(3, condition_roll - 1)] # Better markets
		"frontier":
			return market_conditions[max(0, condition_roll - 3)] # Worse markets
		"industrial":
			return market_conditions[condition_roll - 2] if condition_roll >= 2 else "Poor"
		_:
			return "Average"

func _calculate_market_size(condition: String) -> int:
	"""Calculate number of items available in market"""
	match condition:
		"Poor": return randi_range(3, 6)
		"Average": return randi_range(6, 10)
		"Good": return randi_range(10, 15)
		"Excellent": return randi_range(15, 20)
		_: return 8

func _generate_category_items(category: String, market_condition: String, world_type: String) -> Array[Resource]:
	"""Generate items for a specific category with faction and world influences using JSON data"""
	var items: Array[Resource] = []

	# Try to use JSON data first
	var json_items = equipment_data.get(category, [])
	if not json_items.is_empty():
		return _generate_json_category_items(category, market_condition, world_type, json_items)
	
	# Fallback to legacy system
	var category_items = equipment_categories.get(category, [])

	# Calculate items to generate based on availability and faction preferences
	var base_items = randi_range(1, 3)
	var availability_modifier = get_item_category_availability(category, world_type)

	var faction_modifier = faction_preferences.get(current_faction_influence, {}).get(category, 1.0)

	var items_to_generate = max(1, int(base_items * availability_modifier * faction_modifier))

	for i: int in range(items_to_generate):
		var item_name = category_items.pick_random()
		var item = _create_market_item(item_name, category, market_condition)

		items.append(item)

	return items

func _generate_json_category_items(category: String, market_condition: String, world_type: String, json_items: Array) -> Array[Resource]:
	"""Generate items from JSON data with enhanced filtering"""
	var items: Array[Resource] = []
	
	# Calculate items to generate based on availability and faction preferences
	var base_items = randi_range(1, 3)
	var availability_modifier = get_item_category_availability(category, world_type)
	var faction_modifier = faction_preferences.get(current_faction_influence, {}).get(category, 1.0)
	var items_to_generate = max(1, int(base_items * availability_modifier * faction_modifier))
	
	# Filter items by rarity and world type
	var suitable_items = _filter_items_by_availability(json_items, world_type, market_condition)
	
	for i: int in range(items_to_generate):
		if suitable_items.is_empty():
			break
			
		var item_template = suitable_items.pick_random()
		var item = _create_json_market_item(item_template, category, market_condition)
		items.append(item)
	
	return items

func _filter_items_by_availability(json_items: Array, world_type: String, market_condition: String) -> Array:
	"""Filter items based on world type and market condition"""
	var filtered_items = []
	
	for item in json_items:
		var rarity = item.get("rarity", "Common").to_lower()
		var should_include = false
		
		# Determine if item should be available based on world type and market condition
		match world_type:
			"core":
				should_include = true  # Core worlds have everything
			"industrial":
				should_include = rarity in ["common", "uncommon"] or (rarity == "rare" and market_condition == "Excellent")
			"frontier":
				should_include = rarity == "common" or (rarity == "uncommon" and market_condition in ["Good", "Excellent"])
			_:
				should_include = rarity in ["common", "uncommon"]
		
		# Additional rarity checks based on market condition
		if should_include:
			match rarity:
				"rare":
					should_include = randf() < _get_rare_item_chance(market_condition)
				"uncommon":
					should_include = randf() < _get_uncommon_item_chance(market_condition)
				"common":
					should_include = true
		
		if should_include:
			filtered_items.append(item)
	
	return filtered_items

func _get_rare_item_chance(market_condition: String) -> float:
	"""Get chance for rare items to appear"""
	match market_condition:
		"Poor": return 0.05
		"Average": return 0.15
		"Good": return 0.25
		"Excellent": return 0.40
		_: return 0.15

func _get_uncommon_item_chance(market_condition: String) -> float:
	"""Get chance for uncommon items to appear"""
	match market_condition:
		"Poor": return 0.30
		"Average": return 0.60
		"Good": return 0.80
		"Excellent": return 0.95
		_: return 0.60

func _create_json_market_item(item_template: Dictionary, category: String, market_condition: String) -> Resource:
	"""Create a market item from JSON template with enhanced pricing and properties"""
	var item := Resource.new()
	
	# Basic item properties from JSON
	item.set_meta("id", item_template.get("id", "unknown"))
	item.set_meta("name", item_template.get("name", "Unknown Item"))
	item.set_meta("category", category)
	item.set_meta("type", item_template.get("type", "Basic"))
	item.set_meta("description", item_template.get("description", ""))
	
	# Enhanced properties from JSON
	item.set_meta("rarity", item_template.get("rarity", "Common"))
	item.set_meta("traits", item_template.get("traits", []))
	item.set_meta("tags", item_template.get("tags", []))
	
	# Category-specific properties
	match category:
		"weapons":
			item.set_meta("damage", item_template.get("damage", 1))
			item.set_meta("range", item_template.get("range", 12))
			item.set_meta("shots", item_template.get("shots", 1))
		"armor":
			item.set_meta("protection", item_template.get("protection", 1))
			item.set_meta("mobility_penalty", item_template.get("mobility_penalty", 0))
		"gear":
			item.set_meta("effect", item_template.get("effect", "No effect"))
			item.set_meta("uses", item_template.get("uses", "Unlimited"))
		"attachments":
			item.set_meta("compatible_with", item_template.get("compatible_with", []))
			item.set_meta("effect", item_template.get("effect", "No effect"))
	
	# Pricing with JSON base cost
	var base_price = item_template.get("cost", 5)
	item.set_meta("base_price", base_price)
	
	# Apply market condition modifiers
	var market_price = _calculate_market_price(base_price, market_condition)
	item.set_meta("market_price", market_price)
	
	# Generate item condition
	var condition = _generate_item_condition()
	item.set_meta("condition", condition)
	item.set_meta("condition_modifier", _get_condition_modifier(condition))
	
	# Final price with condition modifier
	var final_price = int(market_price * item.get_meta("condition_modifier"))
	item.set_meta("final_price", final_price)
	
	# Enhanced description with JSON data
	item.set_meta("full_description", _generate_json_item_description(item))
	
	return item

func _generate_json_item_description(item: Resource) -> String:
	"""Generate enhanced description for JSON-based items"""
	var name = item.get_meta("name")
	var category = item.get_meta("category")
	var condition = item.get_meta("condition")
	var price = item.get_meta("final_price")
	var rarity = item.get_meta("rarity")
	var description = item.get_meta("description")
	
	var condition_text: String = ""
	match condition:
		"Damaged": condition_text = " (needs repair)"
		"Used": condition_text = " (well-worn)"
		"Good": condition_text = ""
		"Excellent": condition_text = " (pristine condition)"
	
	var rarity_prefix = ""
	if rarity != "Common":
		rarity_prefix = "[" + rarity.to_upper() + "] "
	
	var category_info = ""
	match category:
		"weapons":
			var damage = item.get_meta("damage", 1)
			var range_val = item.get_meta("range", 12)
			category_info = " (Damage: %d, Range: %d)" % [damage, range_val]
		"armor":
			var protection = item.get_meta("protection", 1)
			category_info = " (Protection: %d)" % protection
		"gear":
			var uses = item.get_meta("uses", "Unlimited")
			category_info = " (Uses: %s)" % uses
	
	return "%s%s%s%s - %d credits\n%s" % [rarity_prefix, name, condition_text, category_info, price, description]

func _create_market_item(item_name: String, category: String, market_condition: String) -> Resource:
	"""Create a market item with pricing and availability"""
	var item := Resource.new()

	# Basic item properties
	item.set_meta("name", item_name)
	item.set_meta("category", category)

	item.set_meta("base_price", item_base_prices.get(item_name, 5))

	# Apply market _condition modifiers
	var market_price = _calculate_market_price(item.get_meta("base_price"), market_condition)
	item.set_meta("market_price", market_price)

	# Generate item _condition
	var _condition = _generate_item_condition()
	item.set_meta("_condition", _condition)
	item.set_meta("condition_modifier", _get_condition_modifier(_condition))

	# Final price with _condition modifier
	var final_price = int(market_price * item.get_meta("condition_modifier"))
	item.set_meta("final_price", final_price)

	# Generate item description
	item.set_meta("description", _generate_item_description(item))

	return item

func _calculate_market_price(base_price: int, condition: String) -> int:
	"""Calculate market _price based on condition"""
	var modifier: int = 1

	match condition:
		"Poor": modifier = 0.7
		"Average": modifier = 1.0
		"Good": modifier = 1.2
		"Excellent": modifier = 1.5

	return int(base_price * modifier)

func _generate_item_condition() -> String:
	"""Generate random item condition"""
	var condition_roll = randi_range(1, 6)

	match condition_roll:
		1: return "Damaged"
		2, 3: return "Used"
		4, 5: return "Good"
		6: return "Excellent"
		_: return "Good"

func _get_condition_modifier(condition: String) -> float:
	"""Get price modifier for item condition"""
	match condition:
		"Damaged": return 0.5
		"Used": return 0.8
		"Good": return 1.0
		"Excellent": return 1.3
		_: return 1.0

func _generate_item_description(item: Resource) -> String:
	"""Generate descriptive text for item"""
	var name = item.get_meta("name")
	var category = item.get_meta("category")
	var condition = item.get_meta("condition")
	var price = item.get_meta("final_price")

	var condition_text: String = ""
	match condition:
		"Damaged": condition_text = " (needs repair)"
		"Used": condition_text = " (well-worn)"
		"Good": condition_text = ""
		"Excellent": condition_text = " (pristine condition)"

	return "%s%s - %d credits" % [name, condition_text, price]

func buy_item(item: Resource, campaign_data: Resource) -> bool:
	"""Attempt to buy an item"""
	var price = item.get_meta("final_price")
	var current_credits = _get_credits(campaign_data)

	if current_credits >= price:
		# Complete purchase
		_set_credits(campaign_data, current_credits - price)
		_add_item_to_inventory(campaign_data, item)

		# Update demand tracking
		var item_name = item.get_meta("name") if item and item.has_method("get_meta") else "unknown"
		update_demand_tracking(item_name, "purchase")

		trade_completed.emit(item, "purchase", price)
		return true
	else:
		trade_failed.emit("Insufficient credits")
		return false

func sell_item(item: Resource, campaign_data: Resource) -> bool:
	"""Sell an item for credits"""
	# Calculate sell price (typically 50% of market _value)
	var base_price = item.get_meta("base_price") if item and item.has_method("get_meta") else 5
	var condition_modifier = item.get_meta("condition_modifier") if item and item.has_method("get_meta") else 1.0
	var sell_price = int(base_price * condition_modifier * 0.5)

	# Remove from inventory and add credits
	if _remove_item_from_inventory(campaign_data, item):
		var current_credits = _get_credits(campaign_data)
		_set_credits(campaign_data, current_credits + sell_price)

		# Update demand tracking
		var item_name = item.get_meta("name") if item and item.has_method("get_meta") else "unknown"
		update_demand_tracking(item_name, "sale")

		trade_completed.emit(item, "sale", sell_price)
		return true
	else:
		trade_failed.emit("Item not found in inventory")
		return false

func generate_trade_opportunities(world_type: String) -> Array[Dictionary]:
	"""Generate special trade opportunities"""
	var opportunities: Array = []

	# Trade mission opportunities
	var trade_roll = randi_range(1, 6)
	if trade_roll >= 4: # 50% chance
		opportunities.append({
			"type": "bulk_trade",
			"description": "Bulk goods transport",
			"profit": randi_range(100, 300),
			"risk": "Low"
		})

	if trade_roll >= 5: # 33% chance
		opportunities.append({
			"type": "rare_goods",
			"description": "Rare artifact sale",
			"profit": randi_range(200, 500),
			"risk": "Medium"
		})

	return opportunities

func get_item_category_availability(category: String, world_type: String) -> float:
	"""Get availability modifier for item category on world _type"""
	var availability_matrix = {
		"core": {"weapons": 0.8, "armor": 1.2, "gear": 1.5, "supplies": 1.2},
		"frontier": {"weapons": 1.3, "armor": 0.7, "gear": 0.8, "supplies": 1.0},
		"industrial": {"weapons": 1.0, "armor": 1.1, "gear": 1.3, "supplies": 1.4}
	}

	return availability_matrix.get(world_type, {}).get(category, 1.0)

func _get_credits(campaign_data: Resource) -> int:
	"""Get current credits from campaign"""
	if campaign_data and campaign_data and campaign_data.has_method("get_meta"):
		return campaign_data.get_meta("credits")
	return 0

func _set_credits(campaign_data: Resource, credits: int) -> void:
	"""Set current credits in campaign"""
	if campaign_data and campaign_data and campaign_data.has_method("set_meta"):
		campaign_data.set_meta("credits", credits)
func _add_item_to_inventory(campaign_data: Resource, item: Resource) -> void:
	"""Add item to campaign inventory"""
	if campaign_data and campaign_data.has_method("get_meta") and campaign_data and campaign_data.has_method("set_meta"):
		var inventory = campaign_data.get_meta("inventory")
		if inventory == null:
			inventory = []

		inventory.append(item)
		campaign_data.set_meta("inventory", inventory)

func _remove_item_from_inventory(campaign_data: Resource, item: Resource) -> bool:
	"""Remove item from campaign inventory"""
	if campaign_data and campaign_data.has_method("get_meta") and campaign_data and campaign_data.has_method("set_meta"):
		var inventory = campaign_data.get_meta("inventory")
		if inventory and inventory.has(item):
			inventory.erase(item)
			campaign_data.set_meta("inventory", inventory)
			return true
	return false

func get_market_summary(items: Array[Resource]) -> Dictionary:
	"""Get summary of market for UI display"""
	var summary = {
		"total_items": items.size(),
		"categories": {},
		"price_range": {"min": 999, "max": 0},
		"average_condition": 0.0
	}

	var condition_total: int = 0

	for item in items:
		var category = item.get_meta("category") if item and item.has_method("get_meta") else "unknown"
		var price = item.get_meta("final_price") if item and item.has_method("get_meta") else 0
		var condition_modifier = item.get_meta("condition_modifier") if item and item.has_method("get_meta") else 1.0

		# Count categories
		if not summary.categories.has(category):
			summary.categories[category] = 0
		summary.categories[category] += 1

		# Track price range
		summary.price_range.min = min(summary.price_range.min, price)
		summary.price_range.max = max(summary.price_range.max, price)

		# Average condition
		condition_total += condition_modifier

	if items.size() > 0:
		summary.average_condition = condition_total / items.size()

	return summary

## ===== ADVANCED MARKET DYNAMICS =====

func _apply_market_fluctuations() -> void:
	"""Apply price fluctuations based on market volatility"""
	turns_since_last_fluctuation += 1

	# Chance of price fluctuation increases over time
	var fluctuation_chance = (turns_since_last_fluctuation * 0.1) + market_volatility

	if randf() < fluctuation_chance:
		_trigger_price_fluctuation()
		turns_since_last_fluctuation = 0
func _trigger_price_fluctuation() -> void:
	"""Trigger a market-wide price fluctuation"""
	for item_name in item_base_prices.keys():
		var old_price = item_base_prices[item_name]
		var fluctuation: int = 1 + (randf() - 0.5) * market_volatility * 2.0
		var new_price = max(1, int(old_price * fluctuation))

		if new_price != old_price:
			item_base_prices[item_name] = new_price
			price_fluctuation_occurred.emit(item_name, old_price, new_price) # warning: return value discarded (intentional)

			# Track price history
			if not price_history.has(item_name):
				price_history[item_name] = []
			price_history[item_name].append({"price": new_price, "turn": turns_since_last_fluctuation})

func _calculate_rare_item_chance(world_type: String, market_condition: String) -> float:
	"""Calculate chance of rare items appearing"""
	var base_chance: int = 0 # 5% base chance

	match world_type:
		"core": base_chance *= 2.0
		"industrial": base_chance *= 1.5
		"frontier": base_chance *= 0.5

	match market_condition:
		"Excellent": base_chance *= 2.0
		"Good": base_chance *= 1.5
		"Poor": base_chance *= 0.5

	return base_chance

func _generate_rare_item(world_type: String) -> Resource:
	"""Generate a rare/exotic item"""
	var rare_categories = rare_items.keys()
	var category = rare_categories.pick_random()
	var item_name = rare_items[category].pick_random()

	var item := Resource.new()
	item.set_meta("name", item_name)
	item.set_meta("category", "rare_" + category.split("_")[0])
	item.set_meta("rarity", "rare")

	item.set_meta("base_price", rare_item_base_prices.get(item_name, 25))

	# Rare items are typically in good condition
	var condition: String = "Good" if randf() < 0.7 else "Excellent"
	item.set_meta("condition", condition)
	item.set_meta("condition_modifier", _get_condition_modifier(condition))

	# Calculate final price with rarity bonus
	var market_price = item.get_meta("base_price") * 1.2 # Rare item markup
	var final_price = int(market_price * item.get_meta("condition_modifier"))
	item.set_meta("final_price", final_price)

	item.set_meta("description", _generate_rare_item_description(item))

	return item

func _generate_rare_item_description(item: Resource) -> String:
	"""Generate description for rare items"""
	var name = item.get_meta("name")
	var price = item.get_meta("final_price")
	var condition = item.get_meta("condition")

	var rarity_text: String = " ★ RARE ★ "
	var condition_text: String = " (%s condition)" % condition.to_lower()

	return "%s%s%s - %d credits" % [rarity_text, name, condition_text, price]

func _generate_advanced_trade_opportunities(world_type: String) -> Array[Dictionary]:
	"""Generate advanced trade opportunities with better mechanics"""
	var opportunities: Array = []

	# Faction-specific opportunities
	match current_faction_influence:
		"unity":
			if randf() < 0.3:
				opportunities.append({
					"type": "unity_contract",
					"title": "Unity Research Data",
					"description": "Transport sensitive research data to Unity facilities",
					"profit_range": [300, 600],
					"risk_level": "Medium",
					"requirements": ["Security Clearance", "Encrypted Storage"],
					"success_chance": 0.8
				})
		"corpo":
			if randf() < 0.35:
				opportunities.append({
					"type": "corporate_merger",
					"title": "Corporate Asset Transfer",
					"description": "Facilitate asset transfer between competing corporations",
					"profit_range": [500, 1000],
					"risk_level": "High",
					"requirements": ["Corporate Contacts", "Legal Documentation"],
					"success_chance": 0.6
				})
		"pirates":
			if randf() < 0.4:
				opportunities.append({
					"type": "salvage_rights",
					"title": "Exclusive Salvage Rights",
					"description": "Gain temporary exclusive access to a wreck site",
					"profit_range": [200, 800],
					"risk_level": "Variable",
					"requirements": ["Salvage Equipment", "Combat Readiness"],
					"success_chance": 0.7
				})

	# World-specific opportunities
	if world_type == "industrial" and randf() < 0.25:
		opportunities.append({
			"type": "industrial_surplus",
			"title": "Factory Surplus Sale",
			"description": "Purchase industrial surplus at bulk discount rates",
			"profit_range": [150, 400],
			"risk_level": "Low",
			"requirements": ["Cargo Space", "Industrial Contacts"],
			"success_chance": 0.9
		})

	return opportunities

func _update_supply_demand_tracking(market_items: Array[Resource]) -> void:
	"""Update supply and demand tracking for market analysis"""
	for item in market_items:

		var item_name = item.get_meta("name") if item and item.has_method("get_meta") else "unknown"

		# Initialize tracking if needed
		if not supply_demand.has(item_name):
			supply_demand[item_name] = {"supply": 0, "demand": 0, "transactions": 0}

		# Increase supply
		supply_demand[item_name]["supply"] += 1
func update_demand_tracking(item_name: String, transaction_type: String) -> void:
	"""Update demand tracking when items are bought/sold"""
	if not supply_demand.has(item_name):
		supply_demand[item_name] = {"supply": 0, "demand": 0, "transactions": 0}

	match transaction_type:
		"purchase":
			supply_demand[item_name]["demand"] += 1
			supply_demand[item_name]["supply"] = max(0, supply_demand[item_name]["supply"] - 1)
		"sale":
			supply_demand[item_name]["supply"] += 1

	supply_demand[item_name]["transactions"] += 1
func get_market_trends() -> Dictionary:
	"""Get current market trends for UI display"""
	var trends = {
		"hot_items": [],
		"declining_items": [],
		"stable_items": [],
		"faction_influence": current_faction_influence,
		"volatility": market_volatility
	}

	for item_name in supply_demand.keys():
		var data = supply_demand[item_name]
		var demand_ratio = float(data.demand) / max(1, data.supply)

		if demand_ratio > 1.5:
			trends.hot_items.append(item_name)
		elif demand_ratio < 0.5:
			trends.declining_items.append(item_name)
		elif demand_ratio > 0.5 and demand_ratio < 1.5:
			trends.stable_items.append(item_name)

	return trends

func set_faction_influence(faction: String) -> void:
	"""Set the current faction influence for markets"""
	if faction in faction_preferences.keys():
		current_faction_influence = faction
func get_price_history(item_name: String) -> Array:
	"""Get price history for a specific item"""

	return price_history.get(item_name, [])

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null