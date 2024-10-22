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
var class_type = null  # Using get("class") in the CharacterBox script

func _init() -> void:
	character = Character.new()
	weapon_system = WeaponSystem.new()
	set_default_stats()
	equip_default_weapons()

func set_default_stats() -> void:
	character.name = "Default Crew Member"
	character.initialize_default_stats()

func equip_default_weapons() -> void:
	var pistol = Weapon.new("Hand gun", GlobalEnums.WeaponType.PISTOL, 12, 1, 0)
	var knife = Weapon.new("Blade", GlobalEnums.WeaponType.MELEE, 0, 1, 0)
	character.inventory.append(pistol)
	character.inventory.append(knife)

func initialize(species: GlobalEnums.Species, background: GlobalEnums.Background, 
				motivation: GlobalEnums.Motivation, crew_class: GlobalEnums.Class) -> void:
	character.initialize(species, background, motivation, crew_class)

func set_weapons(weapon_data: Array) -> void:
	character.inventory.clear()
	for weapon_info in weapon_data:
		if weapon_info is Dictionary:
			var weapon = Weapon.new(
				weapon_info.get("name", ""),
				weapon_info.get("type", GlobalEnums.WeaponType.PISTOL),
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
	return {
		"character": character.serialize(),
		"role": role,
		"loyalty": loyalty,
		"special_ability": special_ability,
		"weapon_system": weapon_system.serialize()
	}

static func deserialize(data: Dictionary) -> CrewMember:
	var crew_member = CrewMember.new()
	crew_member.character = Character.deserialize(data["character"])
	crew_member.role = data["role"]
	crew_member.loyalty = data["loyalty"]
	crew_member.special_ability = data["special_ability"]
	crew_member.weapon_system.deserialize(data["weapon_system"])
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
