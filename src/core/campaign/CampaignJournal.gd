extends Node
## CampaignJournal autoload - Narrative Tracking System
## Automatically tracks major events, allows manual notes, visualizes campaign timeline
## Singleton autoload: CampaignJournal

signal entry_created(entry: Dictionary)
signal entry_updated(entry_id: String)
signal entry_deleted(entry_id: String)
signal timeline_updated()

## Entry storage
var entries: Array[Dictionary] = []
var entries_by_id: Dictionary = {}  # entry_id -> entry
var milestones: Array[Dictionary] = []
var character_histories: Dictionary = {}  # character_id -> timeline

## Current campaign context
var current_campaign_id: String = ""
var campaign_created_at: int = 0
var last_updated: int = 0

## Entry ID generation
var next_entry_id: int = 1

## Configuration
const MAX_PHOTOS_PER_ENTRY: int = 5
const PHOTO_DIR: String = "user://campaign_photos/"

func _ready() -> void:
	_ensure_photo_directory()

## ===== ENTRY MANAGEMENT =====

func create_entry(data: Dictionary) -> String:
	## Create new journal entry - returns entry ID
	var entry_id: String = _generate_entry_id()

	var entry: Dictionary = {
		"id": entry_id,
		"turn_number": data.get("turn_number", 0),
		"timestamp": Time.get_unix_time_from_system(),
		"type": data.get("type", "custom"),  # battle, story, purchase, injury, milestone, custom
		"auto_generated": data.get("auto_generated", false),

		# Content
		"title": data.get("title", "Untitled Entry"),
		"description": data.get("description", ""),
		"mood": data.get("mood", "neutral"),  # triumph, defeat, neutral, somber, exciting

		# Metadata
		"tags": data.get("tags", []),
		"characters_involved": data.get("characters_involved", []),
		"location": data.get("location", ""),

		# Media
		"photos": data.get("photos", []),

		# Stats (optional, depends on entry type)
		"stats": data.get("stats", {}),

		# Player notes
		"player_notes": data.get("player_notes", "")
	}

	entries.append(entry)
	entries_by_id[entry_id] = entry
	_sort_entries_by_turn()

	last_updated = Time.get_unix_time_from_system()
	entry_created.emit(entry)
	return entry_id

func update_entry(entry_id: String, data: Dictionary) -> bool:
	## Update existing journal entry
	if not entries_by_id.has(entry_id):
		push_error("Entry not found: " + entry_id)
		return false

	var entry: Dictionary = entries_by_id[entry_id]

	# Update fields
	for key: String in data.keys():
		entry[key] = data[key]

	last_updated = Time.get_unix_time_from_system()
	entry_updated.emit(entry_id)
	return true

func delete_entry(entry_id: String) -> bool:
	## Delete journal entry
	if not entries_by_id.has(entry_id):
		return false

	var entry: Dictionary = entries_by_id[entry_id]
	entries.erase(entry)
	entries_by_id.erase(entry_id)

	# Delete associated photos
	for photo: Dictionary in entry.get("photos", []):
		_delete_photo(photo.get("path", ""))

	entry_deleted.emit(entry_id)
	return true

func get_entry(entry_id: String) -> Dictionary:
	## Get journal entry by ID
	return entries_by_id.get(entry_id, {})

func get_all_entries() -> Array[Dictionary]:
	## Get all journal entries (sorted by turn)
	return entries.duplicate()

## ===== AUTO-GENERATION =====

func auto_create_battle_entry(battle_result: Dictionary) -> void:
	## Auto-generate entry from battle results
	var zone_type: String = battle_result.get("zone_type", "")
	var title_prefix: String = (
		"[%s] " % zone_type if not zone_type.is_empty()
		else "")
	var title: String = "%sBattle: %s" % [
		title_prefix,
		battle_result.get("location", "Unknown Location")]
	var description: String = _generate_battle_description(
		battle_result)

	# Enrich description with zone details
	if not zone_type.is_empty():
		description += "\n\n%s Mission" % zone_type
	var threat: String = battle_result.get(
		"threat_condition", "")
	if not threat.is_empty():
		description += " | Threat: %s" % threat
	var time_c: String = battle_result.get(
		"time_constraint", "")
	if not time_c.is_empty():
		description += " | Time: %s" % time_c
	var bz_mission: String = battle_result.get(
		"black_zone_mission", "")
	if not bz_mission.is_empty():
		description += " | Objective: %s" % bz_mission

	# Build tags with zone tag
	var tags: Array = [
		"battle",
		battle_result.get("enemy_type", "").to_lower()]
	var zone_tag: String = battle_result.get("zone_tag", "")
	if not zone_tag.is_empty():
		tags.append(zone_tag)

	# Build stats with zone info
	var stats: Dictionary = {
		"battle_result": battle_result.get("outcome", "unknown"),
		"casualties": battle_result.get("casualties", 0),
		"loot_earned": battle_result.get("loot", 0),
		"xp_gained": battle_result.get("xp", 0),
	}
	if not zone_type.is_empty():
		stats["zone_type"] = zone_type

	create_entry({
		"turn_number": battle_result.get("turn", 0),
		"type": "battle",
		"auto_generated": true,
		"title": title,
		"description": description,
		"mood": _determine_battle_mood(battle_result),
		"tags": tags,
		"characters_involved": battle_result.get("crew_ids", []),
		"location": battle_result.get("location", ""),
		"stats": stats,
	})

func auto_create_milestone_entry(milestone_type: String, data: Dictionary) -> void:
	## Auto-generate milestone entry
	var title: String = _get_milestone_title(
		milestone_type, data)
	var description: String = _get_milestone_description(
		milestone_type, data)

	create_entry({
		"turn_number": data.get("turn", 0),
		"type": "milestone",
		"auto_generated": true,
		"title": title,
		"description": description,
		"mood": "triumph",
		"tags": ["milestone", milestone_type],
		"stats": data.get("stats", {})
	})

	# Add to milestones array
	milestones.append({
		"turn": data.get("turn", 0),
		"type": milestone_type,
		"title": title,
		"icon": _get_milestone_icon(milestone_type)
	})
	timeline_updated.emit()

func auto_create_character_event(
	character_id: String, event_type: String,
	details: Dictionary
) -> void:
	## Auto-generate character-specific event
	if not character_histories.has(character_id):
		character_histories[character_id] = {
			"character_id": character_id,
			"timeline": [],
			"statistics": {
				"battles_participated": 0,
				"kills": 0,
				"injuries_sustained": 0,
				"advancements": 0,
				"turns_active": 0
			}
		}

	var history = character_histories[character_id]
	var timeline_entry: Dictionary = {
		"turn": details.get("turn", 0),
		"event": event_type,
		"details": details.get("description", ""),
	}
	# Preserve zone context and battle details in timeline
	if details.has("zone_type"):
		timeline_entry["zone_type"] = details["zone_type"]
	if details.has("kills"):
		timeline_entry["kills"] = details["kills"]
	if details.has("outcome"):
		timeline_entry["outcome"] = details["outcome"]
	if details.has("mission_success"):
		timeline_entry["mission_success"] = details["mission_success"]
	history.timeline.append(timeline_entry)

	# Update statistics
	match event_type:
		"injury":
			history.statistics.injuries_sustained += 1
		"advancement":
			history.statistics.advancements += 1
		"kill":
			history.statistics.kills += 1
		"battle":
			history.statistics.battles_participated += 1

## ===== TIMELINE =====

func get_timeline_data() -> Dictionary:
	## Get complete timeline data
	return {
		"campaign_id": current_campaign_id,
		"created_at": campaign_created_at,
		"last_updated": last_updated,
		"entries": entries.duplicate(),
		"milestones": milestones.duplicate(),
		"statistics": {
			"total_entries": entries.size(),
			"auto_generated": _count_auto_generated(),
			"manual_entries": entries.size() - _count_auto_generated(),
			"photos_attached": _count_photos(),
			"battles_recorded": _count_by_type("battle")
		}
	}

func get_milestones() -> Array[Dictionary]:
	## Get all campaign milestones
	return milestones.duplicate()

func filter_entries(filter: Dictionary) -> Array[Dictionary]:
	## Filter entries by criteria
	var filtered: Array[Dictionary] = []

	for entry: Dictionary in entries:
		var matches: bool = true

		# Filter by type
		if filter.has("type"):
			if entry.get("type", "") != filter["type"]:
				matches = false

		# Filter by turn range
		if filter.has("turn_min"):
			if entry.get("turn_number", 0) < filter["turn_min"]:
				matches = false
		if filter.has("turn_max"):
			if entry.get("turn_number", 0) > filter["turn_max"]:
				matches = false

		# Filter by tags
		if filter.has("tags"):
			var has_tag: bool = false
			var entry_tags: Array = entry.get("tags", [])
			for tag: String in filter["tags"]:
				if entry_tags.has(tag):
					has_tag = true
					break
			if not has_tag:
				matches = false

		# Filter by character
		if filter.has("character_id"):
			var involved: Array = entry.get(
				"characters_involved", [])
			if not involved.has(filter["character_id"]):
				matches = false

		if matches:
			filtered.append(entry)

	return filtered

## ===== CHARACTER TRACKING =====

func get_character_history(character_id: String) -> Dictionary:
	## Get complete character history
	return character_histories.get(character_id, {})

func get_character_timeline(character_id: String) -> Array[Dictionary]:
	## Get character's timeline events
	var history = get_character_history(character_id)
	return history.get("timeline", [])

func get_character_entries(character_id: String) -> Array[Dictionary]:
	## Get all journal entries involving a character
	return filter_entries({"character_id": character_id})

func get_character_statistics(character_id: String) -> Dictionary:
	## Get aggregated statistics for character from journal
	if not character_histories.has(character_id):
		return {}

	return character_histories[character_id].get("statistics", {})

func get_top_performers(stat: String = "kills", limit: int = 5) -> Array:
	## Get top N characters by statistic
	## @param stat: Statistic to sort by
	## (kills, battles_participated, injuries, advancements)
	## @param limit: Maximum number of results to return
	## @return: Array of {character_id, value} sorted descending
	var performers: Array = []
	for char_id in character_histories.keys():
		var stats: Dictionary = character_histories[char_id].get("statistics", {})
		performers.append({
			"character_id": char_id,
			"value": stats.get(stat, 0)
		})

	performers.sort_custom(func(a, b): return a.value > b.value)
	return performers.slice(0, limit)

func filter_entries_by_character(character_id: String) -> Array[Dictionary]:
	## Get all journal entries involving a specific character
	var filtered: Array[Dictionary] = []
	for entry in entries:
		if character_id in entry.get("characters_involved", []):
			filtered.append(entry)
	return filtered

func get_all_character_ids() -> Array[String]:
	## Get list of all character IDs with history
	var ids: Array[String] = []
	for char_id in character_histories.keys():
		ids.append(char_id)
	return ids

func get_crew_stats_summary() -> Dictionary:
	## Get aggregate statistics for all crew members
	var total_kills: int = 0
	var total_battles: int = 0
	var total_injuries: int = 0
	var total_advancements: int = 0
	var character_count: int = character_histories.size()

	for char_id in character_histories.keys():
		var stats: Dictionary = character_histories[char_id].get("statistics", {})
		total_kills += stats.get("kills", 0)
		total_battles += stats.get("battles_participated", 0)
		total_injuries += stats.get("injuries_sustained", 0)
		total_advancements += stats.get("advancements", 0)

	return {
		"total_characters": character_count,
		"total_kills": total_kills,
		"total_battles": total_battles,
		"total_injuries": total_injuries,
		"total_advancements": total_advancements,
		"average_kills_per_character": float(total_kills) / float(max(character_count, 1)),
		"average_battles_per_character": float(total_battles) / float(max(character_count, 1))
	}

## ===== PHOTO MANAGEMENT =====

func attach_photo_to_entry(entry_id: String, image_data: Image, caption: String = "") -> bool:
	## Attach photo to journal entry
	var entry: Dictionary = get_entry(entry_id)
	if entry.is_empty():
		return false

	var photos: Array = entry.get("photos", [])
	if photos.size() >= MAX_PHOTOS_PER_ENTRY:
		push_error("Maximum photos reached for entry")
		return false

	var photo_path: String = _save_photo(entry_id, image_data)
	if photo_path.is_empty():
		return false

	photos.append({
		"path": photo_path,
		"caption": caption,
	})
	entry["photos"] = photos

	entry_updated.emit(entry_id)
	return true

func _save_photo(entry_id: String, image_data: Image) -> String:
	## Save photo to disk and return path
	_ensure_photo_directory()

	var timestamp = Time.get_unix_time_from_system()
	var photo_path = PHOTO_DIR + "entry_%s_%d.png" % [entry_id, timestamp]

	var err = image_data.save_png(photo_path)
	if err != OK:
		push_error("Failed to save photo: " + str(err))
		return ""

	return photo_path

func _delete_photo(photo_path: String) -> void:
	## Delete photo from disk
	if FileAccess.file_exists(photo_path):
		DirAccess.remove_absolute(photo_path)

func _ensure_photo_directory() -> void:
	## Ensure photo directory exists
	if not DirAccess.dir_exists_absolute(PHOTO_DIR):
		DirAccess.make_dir_absolute(PHOTO_DIR)

## ===== EXPORT =====

func export_to_pdf(_file_path: String) -> bool:
	## Export journal to PDF (placeholder - requires PDF library)
	push_warning("PDF export not yet implemented")
	return false

func export_to_markdown(file_path: String) -> bool:
	## Export journal to Markdown
	var markdown = _generate_markdown()

	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open file for writing: " + file_path)
		return false

	file.store_string(markdown)
	file.close()
	return true

func export_to_json(file_path: String) -> bool:
	## Export journal to JSON
	var data = get_timeline_data()

	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open file for writing: " + file_path)
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

func _generate_markdown() -> String:
	## Generate Markdown representation of journal
	var md: String = "# Five Parsecs Campaign Journal\n\n"
	md += "**Campaign ID**: %s\n" % current_campaign_id
	md += "**Created**: %s\n" % (
		Time.get_datetime_string_from_unix_time(
			campaign_created_at))
	md += "**Turns**: %d entries\n\n" % entries.size()
	md += "---\n\n"

	for entry: Dictionary in entries:
		var turn: int = entry.get("turn_number", 0)
		var title: String = entry.get("title", "Untitled")
		md += "## Turn %d - %s\n" % [turn, title]
		md += "**Type**: %s | **Mood**: %s\n\n" % [
			entry.get("type", ""), entry.get("mood", "")]
		md += entry.get("description", "") + "\n\n"

		var notes: String = entry.get("player_notes", "")
		if not notes.is_empty():
			md += "**Player Notes**: " + notes + "\n\n"

		var tags: Array = entry.get("tags", [])
		if tags.size() > 0:
			md += "**Tags**: " + ", ".join(tags) + "\n\n"

		md += "---\n\n"

	return md

## ===== HELPERS =====

func _generate_entry_id() -> String:
	## Generate unique entry ID
	var entry_id: String = "entry_%d" % next_entry_id
	next_entry_id += 1
	return entry_id

func _sort_entries_by_turn() -> void:
	## Sort entries by turn number
	entries.sort_custom(func(a: Dictionary, b: Dictionary):
		return a.get("turn_number", 0) < b.get(
			"turn_number", 0))

func _generate_battle_description(
	battle_result: Dictionary
) -> String:
	## Generate battle description from results
	var outcome: String = battle_result.get("outcome", "unknown")
	var casualties: int = battle_result.get("casualties", 0)
	var enemy_type: String = battle_result.get(
		"enemy_type", "Unknown")

	var desc: String = "Battle vs %s - %s\n" % [
		enemy_type, outcome.capitalize()]

	if casualties > 0:
		desc += "%d crew casualties. " % casualties

	var moments: String = battle_result.get(
		"notable_moments", "")
	if not moments.is_empty():
		desc += "\n" + moments

	return desc

func _determine_battle_mood(
	battle_result: Dictionary
) -> String:
	## Determine mood from battle result
	var outcome = battle_result.get("outcome", "unknown")
	var casualties = battle_result.get("casualties", 0)

	if outcome == "victory":
		if casualties == 0:
			return "triumph"
		return "neutral"
	if outcome == "defeat":
		return "defeat"
	return "neutral"

func _get_milestone_title(
	milestone_type: String, data: Dictionary
) -> String:
	## Get milestone title
	match milestone_type:
		"story_track":
			var desc: String = data.get("description", "")
			if desc.begins_with("The Story Track"):
				return "Story Track Activated"
			if desc.begins_with("Evidence"):
				return "Evidence Discovered"
			if "Victory" in desc or "Defeated" in desc:
				return "Story Track Complete"
			return "Story Milestone"
		"rival_established":
			return "New Rival: %s" % data.get(
				"rival_name", "Unknown")
		"patron_allied":
			return "Patron Alliance: %s" % data.get(
				"patron_name", "Unknown")
		"red_zone_license":
			return "Red Zone License Acquired"
		_:
			return "Campaign Milestone"

func _get_milestone_description(
	milestone_type: String, data: Dictionary
) -> String:
	## Get milestone description
	match milestone_type:
		"story_track":
			return data.get(
				"description",
				"Story Track milestone reached")
		"rival_established":
			return "Established rivalry with %s" % data.get(
				"rival_name", "Unknown")
		"red_zone_license":
			return (
				"Crew authorized for Red Zone operations. "
				+ "Extremely hazardous missions with "
				+ "improved rewards now available.")
		_:
			return ""

func _get_milestone_icon(milestone_type: String) -> String:
	## Get icon for milestone type
	var icons: Dictionary = {
		"story_track": "star",
		"rival_established": "skull",
		"patron_allied": "heart",
		"major_purchase": "coin",
		"crew_death": "cross",
		"red_zone_license": "shield",
	}
	return icons.get(milestone_type, "flag")

func _count_auto_generated() -> int:
	## Count auto-generated entries
	var count: int = 0
	for entry: Dictionary in entries:
		if entry.get("auto_generated", false):
			count += 1
	return count

func _count_photos() -> int:
	## Count total photos
	var count: int = 0
	for entry: Dictionary in entries:
		var photos: Array = entry.get("photos", [])
		count += photos.size()
	return count

func _count_by_type(entry_type: String) -> int:
	## Count entries of specific type
	var count: int = 0
	for entry: Dictionary in entries:
		if entry.get("type", "") == entry_type:
			count += 1
	return count

## ===== SAVE/LOAD =====

func load_from_save(save_data: Dictionary) -> void:
	## Load journal from campaign save
	var qol: Dictionary = save_data.get("qol_data", {})
	var journal_data: Dictionary = qol.get("journal", {})
	if journal_data.is_empty():
		return

	entries.clear()
	entries_by_id.clear()

	for entry: Dictionary in journal_data.get("entries", []):
		entries.append(entry)
		var eid: String = entry.get("id", "")
		if not eid.is_empty():
			entries_by_id[eid] = entry

	milestones.clear()
	for m in journal_data.get("milestones", []):
		milestones.append(m)
	character_histories = journal_data.get("character_histories", {})
	campaign_created_at = journal_data.get("created_at", 0)
	last_updated = journal_data.get("last_updated", 0)
	next_entry_id = journal_data.get("next_entry_id", 1)

func save_to_dict() -> Dictionary:
	## Save journal to dictionary for campaign save
	return {
		"entries": entries.duplicate(),
		"milestones": milestones.duplicate(),
		"character_histories": character_histories.duplicate(),
		"created_at": campaign_created_at,
		"last_updated": last_updated,
		"next_entry_id": next_entry_id
	}

func initialize_for_campaign(campaign_id: String) -> void:
	## Initialize journal for new campaign
	current_campaign_id = campaign_id
	campaign_created_at = Time.get_unix_time_from_system()
	entries.clear()
	entries_by_id.clear()
	milestones.clear()
	character_histories.clear()
	next_entry_id = 1
