# Scripts/ShipAndCrew/WeaponsComponent.gd
class_name WeaponsComponent extends ShipComponent

@export var weapon_damage: int
@export var weapon_range: int
@export var accuracy: int
@export var weapon_type: GlobalEnums.WeaponType

func _init(p_name: String, p_description: String, p_power_usage: int, p_health: int, p_weight: float = 1.0, p_weapon_damage: int = 0, p_weapon_range: int = 0, p_accuracy: int = 0, p_weapon_type: GlobalEnums.WeaponType = GlobalEnums.WeaponType.PISTOL):
	super(p_name, p_description, GlobalEnums.ComponentType.WEAPONS, p_power_usage, p_health, p_weight)
	weapon_damage = p_weapon_damage
	weapon_range = p_weapon_range
	accuracy = p_accuracy
	weapon_type = p_weapon_type

func fire() -> int:
	if not is_damaged:
		var weapon_damage_amount = weapon_damage
		if GameStateManager.difficulty_mode == GlobalEnums.DifficultyMode.CHALLENGING:
			weapon_damage_amount = int(weapon_damage_amount * 0.9)
		elif GameStateManager.difficulty_mode == GlobalEnums.DifficultyMode.HARDCORE:
			weapon_damage_amount = int(weapon_damage_amount * 0.8)
		elif GameStateManager.difficulty_mode == GlobalEnums.DifficultyMode.INSANITY:
			weapon_damage_amount = int(weapon_damage_amount * 0.7)
		return weapon_damage_amount
	return 0

func get_hit_chance(distance: int) -> float:
	var base_chance = float(accuracy) / 100.0
	var range_penalty = max(0, distance - weapon_range) * 0.05
	return max(0, min(1, base_chance - range_penalty))

func serialize() -> Dictionary:
	var data = super.serialize()
	data["weapon_damage"] = weapon_damage
	data["weapon_range"] = weapon_range
	data["accuracy"] = accuracy
	data["weapon_type"] = GlobalEnums.WeaponType.keys()[weapon_type]
	return data

static func deserialize(data: Dictionary) -> WeaponsComponent:
	var component = WeaponsComponent.new(
		data["name"],
		data["description"],
		data["power_usage"],
		data["health"],
		data["weight"],
		data["weapon_damage"],
		data["weapon_range"],
		data["accuracy"],
		GlobalEnums.WeaponType[data["weapon_type"]]
	)
	component.max_health = data["max_health"]
	component.is_damaged = data["is_damaged"]
	return component

func _to_string() -> String:
	return "%s (%s, Damage: %d, Range: %d, Accuracy: %d)" % [name, GlobalEnums.WeaponType.keys()[weapon_type], weapon_damage, weapon_range, accuracy]
