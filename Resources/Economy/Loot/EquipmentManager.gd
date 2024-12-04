class_name EquipmentManager
extends Resource

signal equipment_updated(crew_member_id: String, equipment: Dictionary)
signal equipment_removed(crew_member_id: String, equipment_id: String)

# Equipment Data Classes
class EquipmentData extends Resource:
	var name: String
	var description: String
	var type: int  # Using GlobalEnums.ItemType
	var level: int
	var value: int
	
	func _init(item_name: String = "", item_desc: String = "", item_type: int = 0, item_level: int = 1) -> void:
		name = item_name
		description = item_desc
		type = item_type
		level = item_level
		value = 0
	
	static func from_json(json_data: Dictionary) -> EquipmentData:
		if not json_data:
			return null
		var data = EquipmentData.new(
			json_data.get("name", ""),
			json_data.get("description", ""),
			json_data.get("type", GlobalEnums.ItemType.GEAR),
			json_data.get("level", 1)
		)
		data.value = json_data.get("value", 0)
		return data

class WeaponData extends EquipmentData:
	var damage: int = 0
	var range: int = 1
	
	func _init(weapon_name: String = "", weapon_desc: String = "", weapon_damage: int = 1, weapon_range: int = 1) -> void:
		super._init(weapon_name, weapon_desc, GlobalEnums.ItemType.WEAPON, 1)
		damage = weapon_damage
		range = weapon_range

class ArmorData extends EquipmentData:
	var defense: int = 0
	var traits: Array[int] = []
	
	func _init(armor_name: String = "", armor_desc: String = "", armor_defense: int = 1) -> void:
		super._init(armor_name, armor_desc, GlobalEnums.ItemType.ARMOR, 1)
		defense = armor_defense

# Main Manager Variables
var game_state: GameState
var equipped_items: Dictionary = {}
var equipment_database: Dictionary = {}

func _init(_game_state: GameState) -> void:
	game_state = _game_state

# Equipment Management Functions
func equip_item(item: Dictionary, crew_member) -> bool:
	if not _validate_equipment_requirements(item, crew_member):
		return false
		
	if not _has_available_slot(item, crew_member):
		return false
		
	var crew_id = crew_member.id
	if not equipped_items.has(crew_id):
		equipped_items[crew_id] = {}
		
	equipped_items[crew_id][item.id] = item
	equipment_updated.emit(crew_id, item)
	return true

func remove_item(item_id: String, crew_member) -> void:
	var crew_id = crew_member.id
	if equipped_items.has(crew_id) and equipped_items[crew_id].has(item_id):
		equipped_items[crew_id].erase(item_id)
		equipment_removed.emit(crew_id, item_id)

func get_equipped_items(crew_member) -> Array:
	var crew_id = crew_member.id
	if not equipped_items.has(crew_id):
		return []
	return equipped_items[crew_id].values()

func get_equipped_item_by_type(crew_member, item_type: int) -> Dictionary:
	var items = get_equipped_items(crew_member)
	for item in items:
		if item.type == item_type:
			return item
	return {}

func has_equipped_item(crew_member, item_id: String) -> bool:
	var crew_id = crew_member.id
	return equipped_items.has(crew_id) and equipped_items[crew_id].has(item_id)

# Equipment Generation Functions
func create_equipment_from_json(equipment_name: String, json_data: Dictionary) -> EquipmentData:
	if not json_data:
		return null
		
	match json_data.get("type", GlobalEnums.ItemType.GEAR):
		GlobalEnums.ItemType.WEAPON:
			return WeaponData.new(
				equipment_name,
				json_data.get("description", ""),
				json_data.get("damage", 1),
				json_data.get("range", 1)
			)
		GlobalEnums.ItemType.ARMOR:
			var armor = ArmorData.new(
				equipment_name,
				json_data.get("description", ""),
				json_data.get("defense", 1)
			)
			if json_data.has("traits"):
				armor.traits = json_data.traits
			return armor
		_:
			var equipment = EquipmentData.new(
				equipment_name,
				json_data.get("description", ""),
				json_data.get("type", GlobalEnums.ItemType.GEAR),
				json_data.get("level", 1)
			)
			equipment.value = json_data.get("value", 0)
			return equipment

func generate_equipment_from_background(background: int) -> Array:
	var equipment = []
	var background_data = game_state.background_data.get(background, {})
	if background_data.has("starting_gear"):
		for gear_name in background_data.starting_gear:
			var gear = create_equipment_from_json(gear_name, background_data.starting_gear[gear_name])
			if gear:
				equipment.append(gear)
	return equipment

func generate_equipment_from_motivation(motivation: int) -> Array:
	var equipment = []
	var motivation_data = game_state.motivation_data.get(motivation, {})
	if motivation_data.has("starting_gear"):
		for gear_name in motivation_data.starting_gear:
			var gear = create_equipment_from_json(gear_name, motivation_data.starting_gear[gear_name])
			if gear:
				equipment.append(gear)
	return equipment

func get_equipment_bonus(crew_member, stat: String) -> int:
	var total_bonus = 0
	var items = get_equipped_items(crew_member)
	
	for item in items:
		if item.has("bonuses") and item.bonuses.has(stat):
			total_bonus += item.bonuses[stat]
			
	return total_bonus

# Private Helper Functions
func _validate_equipment_requirements(item: Dictionary, crew_member) -> bool:
	if not item.has("requirements"):
		return true
		
	var requirements = item.requirements
	
	# Check stat requirements
	if requirements.has("stats"):
		for stat_name in requirements.stats:
			var required_value = requirements.stats[stat_name]
			if crew_member.get_stat(stat_name) < required_value:
				return false
	
	# Check skill requirements
	if requirements.has("skills"):
		for skill_name in requirements.skills:
			var required_level = requirements.skills[skill_name]
			if crew_member.get_skill_level(skill_name) < required_level:
				return false
	
	# Check trait requirements
	if requirements.has("traits"):
		for trait_name in requirements.traits:
			if not crew_member.has_trait(trait_name):
				return false
	
	return true

func _has_available_slot(item: Dictionary, crew_member) -> bool:
	if not crew_member.id in equipped_items:
		return true
		
	var equipped = equipped_items[crew_member.id]
	var max_slots = _get_max_slots_for_type(item.type)
	
	var used_slots = 0
	for equipped_item in equipped.values():
		if equipped_item.type == item.type:
			used_slots += 1
			
	return used_slots < max_slots

func _get_max_slots_for_type(item_type: int) -> int:
	# Returns the maximum number of equipment slots available for each item type
	# These values can be adjusted for game balance
	match item_type:
		GlobalEnums.ItemType.WEAPON:
			return 2  # Primary and secondary weapons
		GlobalEnums.ItemType.ARMOR:
			return 1  # Single armor piece
		GlobalEnums.ItemType.TOOL:
			return 3  # Multiple tools allowed
		GlobalEnums.ItemType.DEVICE:
			return 2  # Two device slots
		GlobalEnums.ItemType.CONSUMABLE:
			return 4  # Multiple consumables
		GlobalEnums.ItemType.GEAR:
			return 2  # Basic gear slots
		_:
			return 1  # Default to 1 slot for unknown types