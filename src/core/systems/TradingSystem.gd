class_name TradingSystem
extends Resource

## Trading System for Five Parsecs Campaign Manager
## Handles equipment trading, market generation, and trade opportunities

signal market_generated(items: Array[Resource])
signal trade_completed(item: Resource, transaction_type: String, credits: int)
signal trade_failed(reason: String)

# Trading categories from Five Parsecs rules
var equipment_categories = {
	"weapons": ["Handgun", "Shotgun", "Military Rifle", "Blade", "Auto Pistol", "Scrap Pistol"],
	"armor": ["Combat Armor", "Flak Screen", "Shield Belt", "Mesh Armor"],
	"gear": ["Scanner", "Comms", "Med Kit", "Stimm", "Boosters", "Bypass"],
	"supplies": ["Ration Pack", "Fuel Cell", "Spare Parts", "Ammunition"]
}

# Base prices from Five Parsecs rules (simplified)
var item_base_prices = {
	"Handgun": 6, "Shotgun": 8, "Military Rifle": 12, "Blade": 3, "Auto Pistol": 9,
	"Combat Armor": 15, "Flak Screen": 8, "Shield Belt": 10, "Mesh Armor": 6,
	"Scanner": 7, "Comms": 5, "Med Kit": 4, "Stimm": 3, "Boosters": 5,
	"Ration Pack": 1, "Fuel Cell": 2, "Spare Parts": 3, "Ammunition": 1
}

# Market conditions
var market_conditions = ["Poor", "Average", "Good", "Excellent"]

func generate_market(world_type: String = "frontier") -> Array[Resource]:
	"""Generate a market based on world type and Five Parsecs trading rules"""
	var market_items: Array[Resource] = []
	var market_condition = _determine_market_condition(world_type)
	var item_count = _calculate_market_size(market_condition)
	
	# Generate items for each category
	for category in equipment_categories.keys():
		var category_items = _generate_category_items(category, market_condition)
		market_items.append_array(category_items)
	
	# Limit total items
	if market_items.size() > item_count:
		market_items.shuffle()
		market_items = market_items.slice(0, item_count)
	
	market_generated.emit(market_items)
	return market_items

func _determine_market_condition(world_type: String) -> String:
	"""Determine market condition based on world type"""
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

func _generate_category_items(category: String, market_condition: String) -> Array[Resource]:
	"""Generate items for a specific category"""
	var items: Array[Resource] = []
	var category_items = equipment_categories.get(category, [])
	var items_to_generate = randi_range(1, 3) # 1-3 items per category
	
	for i in range(items_to_generate):
		var item_name = category_items.pick_random()
		var item = _create_market_item(item_name, category, market_condition)
		items.append(item)
	
	return items

func _create_market_item(item_name: String, category: String, market_condition: String) -> Resource:
	"""Create a market item with pricing and availability"""
	var item = Resource.new()
	
	# Basic item properties
	item.set_meta("name", item_name)
	item.set_meta("category", category)
	item.set_meta("base_price", item_base_prices.get(item_name, 5))
	
	# Apply market condition modifiers
	var market_price = _calculate_market_price(item.get_meta("base_price"), market_condition)
	item.set_meta("market_price", market_price)
	
	# Generate item condition
	var condition = _generate_item_condition()
	item.set_meta("condition", condition)
	item.set_meta("condition_modifier", _get_condition_modifier(condition))
	
	# Final price with condition modifier
	var final_price = int(market_price * item.get_meta("condition_modifier"))
	item.set_meta("final_price", final_price)
	
	# Generate item description
	item.set_meta("description", _generate_item_description(item))
	
	return item

func _calculate_market_price(base_price: int, condition: String) -> int:
	"""Calculate market price based on condition"""
	var modifier = 1.0
	
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
	
	var condition_text = ""
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
		
		trade_completed.emit(item, "purchase", price)
		return true
	else:
		trade_failed.emit("Insufficient credits")
		return false

func sell_item(item: Resource, campaign_data: Resource) -> bool:
	"""Sell an item for credits"""
	# Calculate sell price (typically 50% of market value)
	var base_price = item.get_meta("base_price") if item.has_method("get_meta") else 5
	var condition_modifier = item.get_meta("condition_modifier") if item.has_method("get_meta") else 1.0
	var sell_price = int(base_price * condition_modifier * 0.5)
	
	# Remove from inventory and add credits
	if _remove_item_from_inventory(campaign_data, item):
		var current_credits = _get_credits(campaign_data)
		_set_credits(campaign_data, current_credits + sell_price)
		
		trade_completed.emit(item, "sale", sell_price)
		return true
	else:
		trade_failed.emit("Item not found in inventory")
		return false

func generate_trade_opportunities(world_type: String) -> Array[Dictionary]:
	"""Generate special trade opportunities"""
	var opportunities = []
	
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
	"""Get availability modifier for item category on world type"""
	var availability_matrix = {
		"core": {"weapons": 0.8, "armor": 1.2, "gear": 1.5, "supplies": 1.2},
		"frontier": {"weapons": 1.3, "armor": 0.7, "gear": 0.8, "supplies": 1.0},
		"industrial": {"weapons": 1.0, "armor": 1.1, "gear": 1.3, "supplies": 1.4}
	}
	
	return availability_matrix.get(world_type, {}).get(category, 1.0)

func _get_credits(campaign_data: Resource) -> int:
	"""Get current credits from campaign"""
	if campaign_data and campaign_data.has_method("get_meta"):
		return campaign_data.get_meta("credits")
	return 0

func _set_credits(campaign_data: Resource, credits: int) -> void:
	"""Set current credits in campaign"""
	if campaign_data and campaign_data.has_method("set_meta"):
		campaign_data.set_meta("credits", credits)

func _add_item_to_inventory(campaign_data: Resource, item: Resource) -> void:
	"""Add item to campaign inventory"""
	if campaign_data and campaign_data.has_method("get_meta") and campaign_data.has_method("set_meta"):
		var inventory = campaign_data.get_meta("inventory")
		if inventory == null:
			inventory = []
		inventory.append(item)
		campaign_data.set_meta("inventory", inventory)

func _remove_item_from_inventory(campaign_data: Resource, item: Resource) -> bool:
	"""Remove item from campaign inventory"""
	if campaign_data and campaign_data.has_method("get_meta") and campaign_data.has_method("set_meta"):
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
	
	var condition_total = 0.0
	
	for item in items:
		var category = item.get_meta("category") if item.has_method("get_meta") else "unknown"
		var price = item.get_meta("final_price") if item.has_method("get_meta") else 0
		var condition_modifier = item.get_meta("condition_modifier") if item.has_method("get_meta") else 1.0
		
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