class_name Rival
extends Resource

@export var name: String
@export var location: Location = null
@export var strength: int = 1  # Ranges from 1 (weakest) to 5 (strongest)
@export var hostility: int = 0  # Ranges from 0 (least hostile) to 100 (most hostile)
@export var economic_impact: float = 1.0  # Calculated based on strength
@export var faction: GlobalEnums.Faction = GlobalEnums.Faction.CORPORATE
@export var ai_type: GlobalEnums.AIType = GlobalEnums.AIType.TACTICAL

func _init(_name: String = "", _location: Location = null, _strength: int = 1, _faction: GlobalEnums.Faction = GlobalEnums.Faction.CORPORATE):
	name = _name
	location = _location
	set_strength(_strength)
	faction = _faction
	hostility = 0
	ai_type = GlobalEnums.AIType.values()[randi() % GlobalEnums.AIType.size()]
	calculate_economic_impact()

func set_strength(value: int) -> void:
	strength = clamp(value, 1, 5)
	calculate_economic_impact()

func increase_strength() -> void:
	set_strength(strength + 1)

func decrease_strength() -> void:
	set_strength(strength - 1)

func change_hostility(amount: int) -> void:
	hostility = clamp(hostility + amount, 0, 100)

func calculate_economic_impact() -> void:
	economic_impact = 1.0 + (strength * 0.1)

func get_ai_action(combat_manager: CombatManager) -> Dictionary:
	var optional_ai = OptionalEnemyAI.new(combat_manager)
	return optional_ai.determine_action(Character.new())

func serialize() -> Dictionary:
	return {
		"name": name,
		"location": location.serialize() if location else {},
		"strength": strength,
		"hostility": hostility,
		"economic_impact": economic_impact,
		"faction": GlobalEnums.Faction.keys()[faction],
		"ai_type": GlobalEnums.AIType.keys()[ai_type]
	}

static func deserialize(data: Dictionary) -> Rival:
	var rival = Rival.new(
		data.get("name", ""),
		data.get("location", null),
		data.get("strength", 1),
		GlobalEnums.Faction[data.get("faction", "CORPORATE")]
	)
	rival.hostility = data.get("hostility", 0)
	rival.economic_impact = data.get("economic_impact", 1.0)
	rival.ai_type = GlobalEnums.AIType[data.get("ai_type", "TACTICAL")]
	
	if data.get("location"):
		rival.location = Location.deserialize(data["location"])
	
	return rival
