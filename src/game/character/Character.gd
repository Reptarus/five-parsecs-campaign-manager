@tool
extends "res://src/core/character/Base/Character.gd"
class_name FPCM_Character

## Game implementation of the Five Parsecs character
##
## Extends the core character with game-specific functionality
## for the Five Parsecs From Home implementation.

# Game-specific properties
var portrait_path: String = ""
var faction_relations: Dictionary = {}
var morale: int = 5
var kills: int = 0

# Note: credits_earned and missions_completed are inherited from CoreCharacter

func _init() -> void:
	super._init()

## Game-specific methods

## Track a kill for this character
func add_kill() -> void:
	kills += 1

	# Award experience for kills
	add_experience(10)

## Track mission completion
func complete_mission(credits: int = 0) -> void:
	missions_completed += 1

	if credits > 0:
		credits_earned += credits

	# Award experience for mission completion
	add_experience(50)

## Apply morale changes
func modify_morale(amount: int) -> void:
	morale = clampi(morale + amount, 0, 10)

	# Handle morale effects
	if morale <= 2:
		apply_status_effect({
			"id": "low_morale",
			"type": "debuff",
			"duration": 2,
			"effects": {
				"combat": - 1
			}
		})
	elif morale >= 8:
		apply_status_effect({
			"id": "high_morale",
			"type": "buff",
			"duration": 2,
			"effects": {
				"reaction": 1
			}
		})

## Set faction relations
func set_faction_relation(faction_id: String, _value: int) -> void:
	faction_relations[faction_id] = _value

## Get faction relation
func get_faction_relation(faction_id: String) -> int:
	return faction_relations.get(faction_id, 0)

## Get character portrait path
func get_portrait() -> String:
	if portrait_path.is_empty():
		# Return default portrait based on character class
		return "res://assets/portraits/default_%s.png" % GlobalEnums.CharacterClass.keys()[character_class].to_lower()
	return portrait_path

## Set character portrait
func set_portrait(path: String) -> void:
	portrait_path = path

## Get character experience summary
func get_experience_summary() -> String:
	var summary: String = "Level %d (%d/%d XP)" % [
		level,
		experience,
		level * 100 # XP needed for next level
	]
	return summary

## Get character's service record summary
func get_service_record() -> String:
	var record: String = "Missions: %d | Kills: %d | Credits: %d" % [
		missions_completed,
		kills,
		credits_earned
	]
	return record

## Get morale value
func get_morale() -> int:
	return morale

## Initialize managers (for compatibility)
func initialize_managers(_game_state_manager: Variant) -> void:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return # Game-specific initialization if needed
	pass

## Override serialize to include game-specific data
func serialize() -> Dictionary:
	var data = super.serialize()
	if data == null:
		data = {}
	data["portrait_path"] = portrait_path
	data["faction_relations"] = faction_relations
	data["morale"] = morale
	data["credits_earned"] = credits_earned
	data["missions_completed"] = missions_completed
	data["kills"] = kills
	return data

## Override deserialize to handle game-specific data
func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	portrait_path = data.get("portrait_path", "")
	faction_relations = data.get("faction_relations", {})
	morale = data.get("morale", 5)
	credits_earned = data.get("credits_earned", 0)
	missions_completed = data.get("missions_completed", 0)
	kills = data.get("kills", 0)

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null