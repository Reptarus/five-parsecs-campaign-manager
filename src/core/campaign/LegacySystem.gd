extends Node

## LegacySystem - Manages crew legacy, hall of fame archives, and veteran import
## Registered as autoload for global access
## Upgraded from stub to include persistence, search, and legacy bonus

signal hall_of_fame_updated()

var _hall_of_fame: Array[Dictionary] = []

## Get all hall of fame entries
func get_hall_of_fame() -> Array[Dictionary]:
	return _hall_of_fame

## Add a crew archive to the hall of fame (backward compat)
func add_to_hall_of_fame(archive: Dictionary) -> void:
	_hall_of_fame.append(archive)
	hall_of_fame_updated.emit()

## Archive a completed campaign with structured data
func archive_campaign(campaign_id: String, campaign_data: Dictionary = {}) -> void:
	var archive := {
		"campaign_id": campaign_id,
		"crew": campaign_data.get("crew", []),
		"story_points": campaign_data.get("story_points", 0),
		"turns_survived": campaign_data.get("turn_number", campaign_data.get("turns_survived", 0)),
		"victory": campaign_data.get("victory", campaign_data.get("campaign_won", false)),
		"achievements": campaign_data.get("achievements", []),
		"timestamp": Time.get_unix_time_from_system(),
		"reputation": campaign_data.get("reputation", 0),
		"credits_earned": campaign_data.get("credits_earned", 0),
	}
	_hall_of_fame.append(archive)
	hall_of_fame_updated.emit()

## Get the best archived campaign (highest story points)
func get_best_campaign() -> Dictionary:
	if _hall_of_fame.is_empty():
		return {}
	var best: Dictionary = _hall_of_fame[0]
	for archive in _hall_of_fame:
		if archive.get("story_points", 0) > best.get("story_points", 0):
			best = archive
	return best

## Calculate legacy bonus for a specific archive (0-3 story points)
func calculate_legacy_bonus(archive: Dictionary) -> int:
	var sp: int = archive.get("story_points", 0)
	var is_victory: bool = archive.get("victory", false)
	var bonus: int = 0
	if is_victory:
		bonus += 1
	if sp >= 10:
		bonus += 1
	if sp >= 25:
		bonus += 1
	return clampi(bonus, 0, 3)

## Get legacy bonus from best archived campaign (for turn 1 application)
func get_legacy_bonus() -> int:
	var best := get_best_campaign()
	if best.is_empty():
		return 0
	return calculate_legacy_bonus(best)

## Search archives for a character by name (for veteran import)
func find_character_in_archives(character_name: String) -> Dictionary:
	for archive in _hall_of_fame:
		var crew: Array = archive.get("crew", [])
		for member in crew:
			var name_val: String = ""
			if member is Dictionary:
				name_val = member.get("character_name", member.get("name", ""))
			elif "character_name" in member:
				name_val = member.character_name
			if name_val == character_name:
				return {
					"character": member,
					"campaign_id": archive.get("campaign_id", ""),
					"campaign_victory": archive.get("victory", false)
				}
	return {}

## Get total campaigns archived
func get_campaign_count() -> int:
	return _hall_of_fame.size()

## Get number of victories
func get_victory_count() -> int:
	var count: int = 0
	for archive in _hall_of_fame:
		if archive.get("victory", false):
			count += 1
	return count

## Save/Load for persistence pipeline
func serialize() -> Dictionary:
	return {
		"hall_of_fame": _hall_of_fame.duplicate(true)
	}

func deserialize(data: Dictionary) -> void:
	var entries = data.get("hall_of_fame", [])
	_hall_of_fame.clear()
	for entry in entries:
		if entry is Dictionary:
			_hall_of_fame.append(entry)

func reset() -> void:
	_hall_of_fame.clear()
	hall_of_fame_updated.emit()
