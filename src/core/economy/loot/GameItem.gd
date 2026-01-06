@tool
extends Resource
class_name GameItem

# Import necessary classes
# Note: DataManager is an autoload - access via get_node("/root/DataManager")

# GlobalEnums available as autoload singleton

@export var item_id: String = ""
@export var item_name: String = ""
@export var item_type: int = 0  # GlobalEnums.ItemType - default to MISC (0)
@export var item_category: String = ""
@export var item_description: String = ""
@export var item_effects: Array[Dictionary] = []
@export var item_uses: int = 1
@export var item_cost: Dictionary = {"credits": 0, "rarity": "Common"}
@export var item_tags: Array[String] = []
@export var item_requirements: Dictionary = {}

var _data_manager: Object = null

func _init() -> void:
	if Engine.is_editor_hint():
		return

	# Try to get the DataManager autoload safely
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		_data_manager = tree.root.get_node_or_null("DataManager")
		if _data_manager:
			print("GameItem: DataManager available immediately")
		else:
			print("GameItem: DataManager not ready yet")
	else:
		print("GameItem: SceneTree not available yet")

func initialize_from_id(id: String) -> bool:
	# If we don't have data manager yet, try to get it with retry
	if _data_manager == null:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			_data_manager = tree.root.get_node_or_null("DataManager")
		if not _data_manager:
			push_error("GameItem: Failed to get DataManager")
			return false

	var item_data: Dictionary = _data_manager.get_gear_item(id)
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
			item_type = GlobalEnums.ItemType.CONSUMABLE
		"armor":
			item_type = GlobalEnums.ItemType.ARMOR
		"weapon":
			item_type = GlobalEnums.ItemType.WEAPON
		"gear":
			item_type = GlobalEnums.ItemType.GEAR
		"modification":
			item_type = GlobalEnums.ItemType.GEAR # Use GEAR as fallback
		"quest":
			item_type = GlobalEnums.ItemType.GEAR # Use GEAR as fallback
		"special":
			item_type = GlobalEnums.ItemType.GEAR
		_:
			item_type = GlobalEnums.ItemType.MISC

	# Handle effects data
	if data.has("effects") and data["effects"] is Array:
		# Convert to typed array
		item_effects.clear()
		for effect in data["effects"]:
			if effect is Dictionary:
				item_effects.append(effect)
	else:
		item_effects = []

		# If there's a single effect, convert it to our format
		if data.has("effect"):
			item_effects.append({
				"type": "basic",

				"description": data.get("effect", ""),

				"_value": data.get("_value", 0)
			})

	# Handle uses

	item_uses = data.get("uses", 1)

	# Handle cost data
	if data.has("cost") and data["cost"] is Dictionary:
		item_cost = data["cost"]
	else:
		item_cost = {"credits": data.get("cost", 0), "rarity": data.get("rarity", "Common")}

	# Handle tags (convert to typed array)
	var raw_tags = data.get("tags", [])
	item_tags.clear()
	for tag in raw_tags:
		if tag is String:
			item_tags.append(tag)

	return true

func get_id() -> String:
	return item_id

func get_item_name() -> String:
	return item_name

func get_type() -> GlobalEnums.ItemType:
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
	return item_type == GlobalEnums.ItemType.CONSUMABLE

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
	var item := GameItem.new()
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

			var _value = effect.get("_value", 0)

			var duration = effect.get("duration", 1)

			if stat and _value > 0:
				if character and character.has_method("add_stat_boost"): character.add_stat_boost(stat, _value, duration)
				return true

		"healing":
			var amount = effect.get("amount", 1)

			if amount > 0:
				if character and character.has_method("heal"): character.heal(amount)
				return true

		"status_removal":
			var status = effect.get("status", "")

			if status:
				if character and character.has_method("remove_status"): character.remove_status(status)
				return true

		"environmental_protection":
			var protection_type = effect.get("protection_type", "")

			var duration = effect.get("duration", 1)

			if protection_type:
				if character and character.has_method("add_environmental_protection"): character.add_environmental_protection(protection_type, duration)
				return true

		"special_ability":
			var ability = effect.get("ability", "")

			var duration = effect.get("duration", 1)

			if ability:
				if character and character.has_method("grant_special_ability"): character.grant_special_ability(ability, duration)
				return true

		_: # Basic effect or unknown type
			# Just use the item without a specific effect
			return true

	return false

func get_value() -> int:
	var _value := 10 # Base _value

	# Add _value based on rarity
	match get_rarity():
		"Common":
			_value += 0
		"Uncommon":
			_value += 20
		"Rare":
			_value += 50
		"Very Rare":
			_value += 100
		"Legendary":
			_value += 200

	# Add _value for effects
	_value += item_effects.size() * 15

	# Add _value for uses if consumable
	if is_consumable():
		_value += item_uses * 5

	return _value

