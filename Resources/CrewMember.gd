extends Node2D
class_name CrewMember

var character: Character
var role: String = ""
var loyalty: int = 0
var special_ability: String = ""

var weapon_system: WeaponSystem

func _init() -> void:
	character = Character.new()
	weapon_system = WeaponSystem.new()
	set_default_stats()
	equip_default_weapons()

func set_default_stats() -> void:
	character.name = "Default Crew Member"
	character.initialize_default_stats()
	# Additional crew-specific stats can be set here

func equip_default_weapons() -> void:
	var pistol = Weapon.new("Hand gun", GlobalEnums.WeaponType.PISTOL, 12, 1, 0)
	var knife = Weapon.new("Blade", GlobalEnums.WeaponType.MELEE, 0, 1, 0)
	character.inventory = [pistol.serialize(), knife.serialize()]

func initialize(species: GlobalEnums.Species, background: GlobalEnums.Background, 
				motivation: GlobalEnums.Motivation, crew_class: GlobalEnums.Class) -> void:
	character.initialize(species, background, motivation, crew_class)
	# Additional crew-specific initialization

func set_weapons(weapon_data: Array) -> void:
	character.inventory.clear()
	for weapon_info in weapon_data:
		var weapon = Weapon.new(weapon_info.name, weapon_info.type, weapon_info.range, weapon_info.shots, weapon_info.damage)
		character.inventory.append(weapon.serialize())

func assign_role(new_role: String) -> void:
	role = new_role
	# Implement role-specific logic

func increase_loyalty(amount: int) -> void:
	loyalty += amount
	# Implement loyalty effects

func get_crew_member_data() -> Dictionary:
	var char_data = character.serialize()
	var crew_specific_data = {
		"role": self.role,
		"loyalty": self.loyalty,
		"special_ability": self.special_ability,
	}
	var merged_data = char_data.duplicate()
	merged_data.merge(crew_specific_data)
	return merged_data

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
