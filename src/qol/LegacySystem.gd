extends Node
## LegacySystem autoload - Campaign archival and Hall of Fame
## Singleton autoload: LegacySystem

signal campaign_archived(campaign_id: String)
signal hall_of_fame_updated()

## Archived campaigns
var archived_campaigns: Array[Dictionary] = []

func archive_campaign(campaign_id: String, campaign_data: Dictionary) -> bool:
	"""Archive a completed campaign"""
	var archive = {
		"campaign_id": campaign_id,
		"archived_at": Time.get_unix_time_from_system(),
		"turns_survived": campaign_data.get("turn_number", 0),
		"story_points": campaign_data.get("story_points", 0),
		"victory": campaign_data.get("story_points", 0) >= 5,
		"crew": campaign_data.get("crew", []),
		"achievements": _calculate_achievements(campaign_data),
		"stats": campaign_data.get("stats", {})
	}
	
	archived_campaigns.append(archive)
	_save_archives()
	
	campaign_archived.emit(campaign_id)
	hall_of_fame_updated.emit()
	return true

func get_hall_of_fame() -> Array[Dictionary]:
	"""Get all archived campaigns sorted by achievement"""
	var sorted = archived_campaigns.duplicate()
	sorted.sort_custom(func(a, b): return a.turns_survived > b.turns_survived)
	return sorted

func import_veteran_as_npc(character_id: String, campaign_id: String) -> Variant:
	"""Import a veteran character as NPC in new campaign"""
	# TODO: Find character in archived campaign and create NPC version
	return null

func calculate_legacy_bonus(archived_campaign: Dictionary) -> int:
	"""Calculate bonus for future campaigns based on achievements"""
	var bonus = 0
	if archived_campaign.victory:
		bonus += 1
	if archived_campaign.turns_survived > 50:
		bonus += 1
	return bonus

func _calculate_achievements(campaign_data: Dictionary) -> Array[String]:
	"""Calculate achievements earned"""
	var achievements: Array[String] = []
	
	if campaign_data.get("story_points", 0) >= 5:
		achievements.append("Victory")
	if campaign_data.get("battles_won", 0) > 20:
		achievements.append("Veteran Campaign")
	# Add more achievement checks
	
	return achievements

func _save_archives() -> void:
	"""Save archived campaigns to disk"""
	var file = FileAccess.open("user://legacy_archives.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"archives": archived_campaigns}, "\t"))
		file.close()

func _load_archives() -> void:
	"""Load archived campaigns from disk"""
	if not FileAccess.file_exists("user://legacy_archives.json"):
		return
	
	var file = FileAccess.open("user://legacy_archives.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.get_data()
			archived_campaigns = data.get("archives", [])
		file.close()

func _ready() -> void:
	_load_archives()
