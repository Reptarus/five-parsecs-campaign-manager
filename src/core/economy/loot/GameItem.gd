@tool
extends Resource
class_name GameItem

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

@export var item_id: String = ""
@export var item_name: String = ""
@export var item_type: GameEnums.ItemType = GameEnums.ItemType.MISC
@export var item_category: String = ""
@export var item_description: String = ""
@export var item_effects: Array[Dictionary] = []
@export var item_uses: int = 1
@export var item_cost: Dictionary = {"credits": 0, "rarity": "Common"}
@export var item_tags: Array[String] = []

var _data_manager: GameDataManager = null

func _init() -> void:
	if Engine.is_editor_hint():
		return
		
	# Create the data manager instance if needed
	if _data_manager == null:
		_data_manager = GameDataManager.new()
		_data_manager.load_gear_database()

func initialize_from_id(id: String) -> bool:
	if _data_manager == null:
		_data_manager = GameDataManager.new()
		_data_manager.load_gear_database()
		
	var item_data = _data_manager.get_gear_item(id)
	if item_data.is_empty():
		push_error("Failed to find item with ID: " + id)
		return false
		
	return initialize_from_data(item_data)

func initialize_from_data(data: Dictionary) -> bool:
	if data.is_empty():
		return false
		
	item_id = data.get("id", "")
	item_name = data.get("name", "")
	item_category = data.get("category", "")
	item_description = data.get("description", "")
	
	# Set item type based on category
	match item_category:
		"consumable":
			item_type = GameEnums.ItemType.CONSUMABLE
		"armor":
			item_type = GameEnums.ItemType.ARMOR
		"weapon":
			item_type = GameEnums.ItemType.WEAPON
		"gear":
			item_type = GameEnums.ItemType.GEAR
		"modification":
			item_type = GameEnums.ItemType.MODIFICATION
		"quest":
			item_type = GameEnums.ItemType.QUEST
		"special":
			item_type = GameEnums.ItemType.SPECIAL
		_:
			item_type = GameEnums.ItemType.MISC
	
	# Handle effects data
	if data.has("effects") and data.effects is Array:
		item_effects = data.effects
	else:
		item_effects = []
		
		# If there's a single effect, convert it to our format
		if data.has("effect"):
			item_effects.append({
				"type": "basic",
				"description": data.get("effect", ""),
				"value": data.get("value", 0)
			})
	
	# Handle uses
	item_uses = data.get("uses", 1)
	
	# Handle cost data
	if data.has("cost") and data.cost is Dictionary:
		item_cost = data.cost
	else:
		item_cost = {"credits": data.get("cost", 0), "rarity": data.get("rarity", "Common")}
	
	item_tags = data.get("tags", [])
	
	return true

func get_id() -> String:
	return item_id

func get_item_name() -> String:
	return item_name

func get_type() -> GameEnums.ItemType:
	return item_type

func get_category() -> String:
	return item_category

func get_description() -> String:
	return item_description

func get_effects() -> Array[Dictionary]:
	return item_effects

func get_uses() -> int:
	return item_uses

func use() -> bool:
	if item_uses <= 0:
		return false
		
	if item_uses > 0:
		item_uses -= 1
		
	return true

func is_consumable() -> bool:
	return item_type == GameEnums.ItemType.CONSUMABLE

func is_depleted() -> bool:
	return item_uses <= 0 and is_consumable()

func get_cost() -> int:
	return item_cost.get("credits", 0)

func get_rarity() -> String:
	return item_cost.get("rarity", "Common")

func get_tags() -> Array[String]:
	return item_tags

func has_tag(tag: String) -> bool:
	return item_tags.has(tag)

func get_item_profile() -> Dictionary:
	return {
		"id": item_id,
		"name": item_name,
		"type": item_type,
		"category": item_category,
		"description": item_description,
		"effects": item_effects,
		"uses": item_uses,
		"cost": item_cost,
		"tags": item_tags
	}

static func create_from_profile(profile: Dictionary) -> GameItem:
	var item = GameItem.new()
	item.initialize_from_data(profile)
	return item

func serialize() -> Dictionary:
	return get_item_profile()

func deserialize(data: Dictionary) -> void:
	initialize_from_data(data)

func apply_effect(character, effect_index: int = 0) -> bool:
	if effect_index < 0 or effect_index >= item_effects.size():
		return false
		
	var effect = item_effects[effect_index]
	var effect_type = effect.get("type", "basic")
	
	match effect_type:
		"stat_boost":
			var stat = effect.get("stat", "")
			var value = effect.get("value", 0)
			var duration = effect.get("duration", 1)
			
			if stat and value > 0:
				character.add_stat_boost(stat, value, duration)
				return true
				
		"healing":
			var amount = effect.get("amount", 1)
			
			if amount > 0:
				character.heal(amount)
				return true
				
		"status_removal":
			var status = effect.get("status", "")
			
			if status:
				character.remove_status(status)
				return true
				
		"environmental_protection":
			var protection_type = effect.get("protection_type", "")
			var duration = effect.get("duration", 1)
			
			if protection_type:
				character.add_environmental_protection(protection_type, duration)
				return true
				
		"special_ability":
			var ability = effect.get("ability", "")
			var duration = effect.get("duration", 1)
			
			if ability:
				character.grant_special_ability(ability, duration)
				return true
				
		_: # Basic effect or unknown type
			# Just use the item without a specific effect
			return true
			
	return false

func get_value() -> int:
	var value := 10 # Base value
	
	# Add value based on rarity
	match get_rarity():
		"Common":
			value += 0
		"Uncommon":
			value += 20
		"Rare":
			value += 50
		"Very Rare":
			value += 100
		"Legendary":
			value += 200
	
	# Add value for effects
	value += item_effects.size() * 15
	
	# Add value for uses if consumable
	if is_consumable():
		value += item_uses * 5
	
	return value