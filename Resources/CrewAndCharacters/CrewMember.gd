extends Node2D
class_name CrewMember

signal loyalty_changed(new_loyalty: int)
signal role_changed(new_role: String)

const MAX_LOYALTY = 100

var character: Character
var role: String = ""
var loyalty: int = 0:
	set(value):
		loyalty = clampi(value, 0, MAX_LOYALTY)
		loyalty_changed.emit(loyalty)
var special_ability: String = ""
var weapon_system: WeaponSystem
var combat: int = 0
var technical: int = 0
var social: int = 0
var survival: int = 0
var health: int = 10
var max_health: int = 10
var class_type: GlobalEnums.Class = GlobalEnums.Class.WARRIOR  # Default class type

var experience: int = 0
var specialization: String = ""
var traits: Array[String] = []
var relationships: Dictionary = {}

func _init() -> void:
	character = Character.new()
	weapon_system = WeaponSystem.new()
	set_default_stats()
	equip_default_weapons()

func set_default_stats() -> void:
	character.name = "Default Crew Member"
	character.initialize_default_stats()

func equip_default_weapons() -> void:
	var pistol = Weapon.new("Hand gun", GlobalEnums.WeaponType.HAND_GUN, 12, 1, 0)
	var knife = Weapon.new("Blade", GlobalEnums.WeaponType.BLADE, 0, 1, 0)
	character.inventory.append(pistol)
	character.inventory.append(knife)

func initialize(data: Dictionary) -> void:
	character.initialize(data)

func set_weapons(weapon_data: Array) -> void:
	character.inventory.clear()
	for weapon_info in weapon_data:
		if weapon_info is Dictionary:
			var weapon = Weapon.new(
				weapon_info.get("name", ""),
				weapon_info.get("type", GlobalEnums.WeaponType.HAND_GUN),
				weapon_info.get("range", 0),
				weapon_info.get("shots", 1),
				weapon_info.get("damage", 0)
			)
			character.inventory.append(weapon)

func assign_role(new_role: String) -> void:
	role = new_role
	role_changed.emit(role)

func increase_loyalty(amount: int) -> void:
	loyalty += amount

func get_crew_member_data() -> Dictionary:
	var char_data = character.serialize()
	char_data.merge({
		"role": role,
		"loyalty": loyalty,
		"special_ability": special_ability,
	})
	return char_data

func use_special_ability() -> void:
	print("Using special ability: ", special_ability)
	# Implement special ability logic here

# Delegate methods to character resource
func add_xp(amount: int) -> void:
	character.add_xp(amount)

func get_xp_for_next_level() -> int:
	return character.get_xp_for_next_level()

func get_available_upgrades() -> Array:
	return character.get_available_upgrades()

# Add any additional crew-specific methods here

func serialize() -> Dictionary:
	var base_data = character.serialize()
	var crew_data = {
		"experience": experience,
		"specialization": specialization,
		"traits": traits,
		"relationships": relationships,
		"role": role,
		"loyalty": loyalty,
		"special_ability": special_ability,
		"combat": combat,
		"technical": technical,
		"social": social,
		"survival": survival,
		"health": health,
		"max_health": max_health,
		"class_type": class_type
	}
	base_data.merge(crew_data)
	return base_data

static func deserialize(data: Dictionary) -> CrewMember:
	var crew_member = CrewMember.new()
	# First deserialize base Character data
	var character_data = Character.deserialize(data)
	crew_member.role = character_data.role
	crew_member.character_name = character_data.character_name
	crew_member.level = character_data.level
	crew_member.health = character_data.health
	crew_member.max_health = character_data.max_health
	crew_member.status = character_data.status
	crew_member.equipment_slots = character_data.equipment_slots
	crew_member.skills = character_data.skills
	crew_member.tutorial_progress = character_data.tutorial_progress
	
	# Then deserialize CrewMember specific data
	crew_member.experience = data.get("experience", 0)
	crew_member.specialization = data.get("specialization", "")
	crew_member.traits = data.get("traits", [])
	crew_member.relationships = data.get("relationships", {})
	
	return crew_member

# Optional: Add a method to set all stats at once
func set_stats(stats: Dictionary) -> void:
	for key in stats:
		if has_property(key):
			set(key, stats[key])

# Helper method to check if property exists
func has_property(property: String) -> bool:
	return property in ["name", "combat", "technical", "social", 
					   "survival", "health", "max_health", "class_type"]
