# DifficultySettings.gd
class_name DifficultySettings
extends Resource

enum DifficultyLevel { EASY, NORMAL, HARD, HARDCORE, INSANITY }

@export var level: DifficultyLevel = DifficultyLevel.NORMAL
@export var enemy_health_multiplier: float = 1.0
@export var enemy_damage_multiplier: float = 1.0
@export var loot_quantity_multiplier: float = 1.0
@export var event_frequency: float = 1.0

func set_difficulty(new_level: DifficultyLevel) -> void:
	level = new_level
	match level:
		DifficultyLevel.EASY:
			enemy_health_multiplier = 0.8
			enemy_damage_multiplier = 0.8
			loot_quantity_multiplier = 1.2
			event_frequency = 0.8
		DifficultyLevel.NORMAL:
			enemy_health_multiplier = 1.0
			enemy_damage_multiplier = 1.0
			loot_quantity_multiplier = 1.0
			event_frequency = 1.0
		DifficultyLevel.HARD:
			enemy_health_multiplier = 1.2
			enemy_damage_multiplier = 1.2
			loot_quantity_multiplier = 0.8
			event_frequency = 1.2

func apply_to_ship(ship: Ship) -> void:
	for component in ship.components:
		if component is WeaponsComponent:
			if component.get("damage") != null:
				component.set("damage", int(component.get("damage") * enemy_damage_multiplier))
		elif component is EngineComponent:
			if component.get("fuel_efficiency") != null:
				component.set("fuel_efficiency", component.get("fuel_efficiency") * loot_quantity_multiplier)

func apply_to_enemy(enemy: Character) -> void:
	enemy.health = int(enemy.health * enemy_health_multiplier)
	if enemy.get_component(ShipComponent.ComponentType.WEAPONS):
		var weapons = enemy.get_component(ShipComponent.ComponentType.WEAPONS) as WeaponsComponent
		weapons.damage = int(weapons.damage * enemy_damage_multiplier)

func to_dict() -> Dictionary:
	return {
		"level": DifficultyLevel.keys()[level],
		"enemy_health_multiplier": enemy_health_multiplier,
		"enemy_damage_multiplier": enemy_damage_multiplier,
		"loot_quantity_multiplier": loot_quantity_multiplier,
		"event_frequency": event_frequency
	}

static func from_dict(data: Dictionary) -> DifficultySettings:
	var settings := DifficultySettings.new()
	settings.level = DifficultyLevel[data["level"]]
	settings.enemy_health_multiplier = data["enemy_health_multiplier"]
	settings.enemy_damage_multiplier = data["enemy_damage_multiplier"]
	settings.loot_quantity_multiplier = data["loot_quantity_multiplier"]
	settings.event_frequency = data["event_frequency"]
	return settings
