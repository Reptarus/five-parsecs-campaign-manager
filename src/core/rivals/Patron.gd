class_name Patron
extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal relationship_changed(new_value: int)
signal missions_updated
signal patron_dismissed
signal patron_status_changed

# Core patron properties
@export var patron_name: String:
	get: return _patron_name
	set(value):
		if value.strip_edges().is_empty():
			push_error("Patron name cannot be empty")
			return
		_patron_name = value
		notify_property_list_changed()

@export var location: Location:
	get: return _location
	set(value):
		if not value:
			push_error("Location cannot be null")
			return
		_location = value
		notify_property_list_changed()

@export var relationship: int:
	get: return _relationship
	set(value):
		var old_value := _relationship
		_relationship = clamp(value, -100, 100)
		if old_value != _relationship:
			relationship_changed.emit(_relationship)
			_check_relationship_status()
			notify_property_list_changed()

@export var faction_type: GameEnums.FactionType:
	get: return _faction_type
	set(value):
		_faction_type = value
		notify_property_list_changed()

@export var economic_influence: float:
	get: return _economic_influence
	set(value):
		_economic_influence = clamp(value, 0.1, 5.0)
		notify_property_list_changed()

# Internal variables
var _patron_name: String = ""
var _location: Location
var _relationship: int = 0
var _faction_type: GameEnums.FactionType = GameEnums.FactionType.NEUTRAL
var _economic_influence: float = 1.0
var _missions: Array[Mission] = []
var _is_dismissed: bool = false
var _last_mission_turn: int = 0

# Core patron characteristics
var characteristics: Array[String] = []
var reputation_bonus: int = 0
var mission_bonus: int = 0

func _init(p_name: String = "",
		  p_location: Location = null,
		  p_faction: GameEnums.FactionType = GameEnums.FactionType.NEUTRAL) -> void:
	patron_name = p_name
	location = p_location
	faction_type = p_faction
	economic_influence = randf_range(0.8, 1.2)
	_setup_patron_characteristics()

func _setup_patron_characteristics() -> void:
	var possible_characteristics: Array[String] = [
		"Connected: +1 to finding new patrons in this location",
		"Wealthy: +2 credits to mission rewards",
		"Influential: +1 reputation from completed missions",
		"Demanding: -1 relationship for failed missions",
		"Generous: +1 relationship for completed missions",
		"Resourceful: Can offer special equipment as rewards",
		"Cautious: Prefers low-risk missions",
		"Bold: Offers high-risk, high-reward missions",
		"Professional: Always pays on time",
		"Shady: May try to avoid payment"
	]
	
	var num_characteristics := randi() % 2 + 1
	possible_characteristics.shuffle()
	
	for i in range(num_characteristics):
		var characteristic: String = possible_characteristics[i]
		characteristics.append(characteristic)
		_apply_characteristic_bonuses(characteristic)

func _apply_characteristic_bonuses(characteristic: String) -> void:
	if "Influential" in characteristic:
		reputation_bonus = 1
	elif "Wealthy" in characteristic:
		mission_bonus = 2

func add_mission(mission: Mission) -> void:
	if not mission:
		return
	_missions.append(mission)
	_last_mission_turn = mission.turn_offered
	missions_updated.emit()

func remove_mission(mission: Mission) -> void:
	if not mission:
		return
	_missions.erase(mission)
	missions_updated.emit()

func get_available_missions() -> Array[Mission]:
	return _missions.filter(func(m: Mission) -> bool: return not m.is_completed and not m.is_failed)

func get_mission_reward_modifier() -> float:
	var modifier := economic_influence
	
	if has_characteristic("Wealthy"):
		modifier *= 1.2
	if has_characteristic("Shady"):
		modifier *= 0.8
	
	return modifier

func complete_mission(mission: Mission) -> void:
	if not mission or not mission in _missions:
		return
		
	mission.complete(true)
	change_relationship(2) # Base relationship gain
	
	if has_characteristic("Generous"):
		change_relationship(1)

func fail_mission(mission: Mission) -> void:
	if not mission or not mission in _missions:
		return
		
	mission.fail(false)
	change_relationship(-1) # Base relationship loss
	
	if has_characteristic("Demanding"):
		change_relationship(-1)

func change_relationship(amount: int) -> void:
	relationship = _relationship + amount

func dismiss() -> void:
	if not _is_dismissed:
		_is_dismissed = true
		patron_dismissed.emit()

func can_offer_mission() -> bool:
	return not _is_dismissed and _missions.size() < 3

func has_characteristic(char_type: String) -> bool:
	return characteristics.any(func(c: String) -> bool: return char_type in c)

func get_status() -> String:
	if _is_dismissed:
		return "Dismissed"
	elif _relationship >= 75:
		return "Trusted Ally"
	elif _relationship >= 50:
		return "Friend"
	elif _relationship >= 25:
		return "Associate"
	elif _relationship >= 0:
		return "Neutral"
	elif _relationship >= -25:
		return "Wary"
	elif _relationship >= -50:
		return "Distrustful"
	else:
		return "Hostile"

func _check_relationship_status() -> void:
	if _relationship <= -75:
		dismiss()
	patron_status_changed.emit()

func serialize() -> Dictionary:
	return {
		"name": _patron_name,
		"location": _location.serialize() if _location else {} as Dictionary,
		"relationship": _relationship,
		"faction_type": GameEnums.FactionType.keys()[_faction_type],
		"economic_influence": _economic_influence,
		"missions": _missions.map(func(m): return m.serialize()),
		"is_dismissed": _is_dismissed,
		"last_mission_turn": _last_mission_turn,
		"characteristics": characteristics.duplicate(),
		"reputation_bonus": reputation_bonus,
		"mission_bonus": mission_bonus
	}

static func deserialize(data: Dictionary) -> Patron:
	var patron = Patron.new()
	patron._patron_name = data.get("name", "")
	
	var location_data = data.get("location", {})
	if not location_data.is_empty():
		var location = Location.new()
		location.deserialize(location_data)
		patron._location = location
	else:
		patron._location = null
	
	patron._relationship = data.get("relationship", 0)
	patron._faction_type = GameEnums.FactionType[data.get("faction_type", "NEUTRAL")]
	patron._economic_influence = data.get("economic_influence", 1.0)
	patron._is_dismissed = data.get("is_dismissed", false)
	patron._last_mission_turn = data.get("last_mission_turn", 0)
	patron.characteristics = data.get("characteristics", []).duplicate()
	patron.reputation_bonus = data.get("reputation_bonus", 0)
	patron.mission_bonus = data.get("mission_bonus", 0)
	
	for mission_data in data.get("missions", []):
		if mission_data is Dictionary:
			var mission = Mission.new()
			patron._missions.append(mission.deserialize(mission_data))
	
	return patron
