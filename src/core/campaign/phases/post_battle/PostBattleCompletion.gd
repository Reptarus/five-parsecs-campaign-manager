class_name PostBattleCompletion
extends RefCounted

## Completion, statistics, and journal entries for Post-Battle Phase.
## Handles Step 14b: finalization after all 14 steps complete.
## Extracted from PostBattlePhase.gd — orchestrator delegates here.

const PostBattleContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")

func update_character_lifetime_statistics(ctx: PostBattleContextClass) -> void:
	## Update character lifetime statistics from battle results (kills, damage, participation)
	var crew: Array = ctx.get_participating_crew()
	if crew.is_empty():
		return

	var kills_by_character: Dictionary = ctx.battle_result.get("kills_by_character", {})
	var damage_dealt_per_unit: Dictionary = ctx.battle_result.get("damage_dealt_per_unit", {})
	var damage_taken_per_unit: Dictionary = ctx.battle_result.get("damage_taken_per_unit", {})
	var units_downed: Array = ctx.battle_result.get("units_downed", [])

	for member in crew:
		if not member:
			continue

		var char_id: String = ""
		if member is Object and member.has_method("get"):
			char_id = member.get("character_id") if member.get("character_id") else ""
		elif member is Dictionary:
			char_id = member.get("character_id", "")

		if char_id.is_empty():
			continue

		if member is Object and "battles_participated" in member:
			member.battles_participated += 1
			if char_id not in units_downed:
				member.battles_survived += 1
			var kills: Array = kills_by_character.get(char_id, [])
			member.lifetime_kills += kills.size()
			member.lifetime_damage_dealt += damage_dealt_per_unit.get(char_id, 0)
			member.lifetime_damage_taken += damage_taken_per_unit.get(char_id, 0)
			_create_character_battle_journal_event(ctx, member, char_id, kills.size())

func create_battle_journal_entry(ctx: PostBattleContextClass) -> void:
	## Create a journal entry for the completed battle
	if not ctx.campaign_journal or not ctx.campaign_journal.has_method("auto_create_battle_entry"):
		return
	var crew_ids: Array = []
	for participant in ctx.crew_participants:
		if participant is String:
			crew_ids.append(participant)

	# Determine zone type for tagging and description enrichment
	var zone_type: String = ""
	var zone_tag: String = ""
	if ctx.battle_result.get("is_black_zone", false):
		zone_type = "BLACK ZONE"
		zone_tag = "black_zone"
	elif ctx.battle_result.get("is_red_zone", false):
		zone_type = "RED ZONE"
		zone_tag = "red_zone"

	var entry_data: Dictionary = {
		"turn": ctx.battle_result.get("turn", 0),
		"location": ctx.battle_result.get("location", "Unknown"),
		"outcome": "victory" if ctx.mission_successful else "defeat",
		"casualties": ctx.injuries_sustained.size(),
		"loot": ctx.loot_earned.size(),
		"xp": ctx.battle_result.get("xp_earned", 0),
		"crew_ids": crew_ids,
		"enemy_type": ctx.battle_result.get("enemy_type", "Unknown"),
	}

	# Enrich with zone context
	if not zone_type.is_empty():
		entry_data["zone_type"] = zone_type
		entry_data["zone_tag"] = zone_tag

	# Add Red Zone threat/time constraint details
	if ctx.battle_result.get("is_red_zone", false):
		var threat: Dictionary = ctx.battle_result.get(
			"red_zone_threat", {})
		var time_c: Dictionary = ctx.battle_result.get(
			"red_zone_time_constraint", {})
		if not threat.is_empty():
			entry_data["threat_condition"] = threat.get(
				"name", "None")
		if not time_c.is_empty():
			entry_data["time_constraint"] = time_c.get(
				"name", "None")

	# Add Black Zone mission type details
	if ctx.battle_result.get("is_black_zone", false):
		var bz_mission: Dictionary = ctx.battle_result.get(
			"black_zone_mission", {})
		if not bz_mission.is_empty():
			entry_data["black_zone_mission"] = bz_mission.get(
				"name", "Unknown")

	# Add Story Track event context (Core Rules Appendix V)
	if ctx.battle_result.get("is_story_battle", false):
		entry_data["story_event_id"] = ctx.battle_result.get(
			"story_event_id", "")
		entry_data["story_event_number"] = ctx.battle_result.get(
			"story_event_number", 0)
		entry_data["zone_type"] = "STORY EVENT"
		entry_data["zone_tag"] = "story_track"

	ctx.campaign_journal.auto_create_battle_entry(entry_data)

func record_planet_mission(ctx: PostBattleContextClass) -> void:
	## Record mission completion on current planet (PlanetDataManager)
	var tree = Engine.get_main_loop() if Engine.get_main_loop() else null
	var root = tree.root if tree else null
	if not root:
		return
	var pdm = root.get_node_or_null("/root/PlanetDataManager")
	if not pdm or not pdm.has_method("complete_mission"):
		return
	var world_id: String = ctx.battle_result.get(
		"world_id", ctx.battle_result.get("location", "")
	)
	if not world_id.is_empty():
		pdm.complete_mission(world_id, ctx.battle_result)

## Morale system removed — Core Rules has no campaign-level morale mechanic.
## Combat morale (Panic checks) is a separate in-battle mechanic handled by
## BattleCalculations, not a post-battle campaign stat.

func _create_character_battle_journal_event(ctx: PostBattleContextClass, member: Variant, char_id: String, kills: int) -> void:
	if not ctx.campaign_journal or not ctx.campaign_journal.has_method("auto_create_character_event"):
		return

	var outcome: String = "survived"
	if member is Object and member.has_method("get"):
		var status: String = member.get("status") if member.get("status") else "ACTIVE"
		if status == "DEAD":
			outcome = "killed"
		elif status == "INJURED" or status == "RECOVERING":
			outcome = "injured"
		elif status == "MISSING":
			outcome = "missing"

	var event_details: Dictionary = {
		"kills": kills,
		"outcome": outcome,
		"mission_success": ctx.mission_successful,
		"turn": ctx.battle_result.get("turn", 0),
	}
	# Enrich with zone context for character timeline
	if ctx.battle_result.get("is_black_zone", false):
		event_details["zone_type"] = "BLACK ZONE"
	elif ctx.battle_result.get("is_red_zone", false):
		event_details["zone_type"] = "RED ZONE"
	ctx.campaign_journal.auto_create_character_event(
		char_id, "battle", event_details
	)

func check_traveler_disappearance(
	ctx: PostBattleContextClass
) -> Array[Dictionary]:
	## Core Rules p.22: After every battle, Traveler rolls 2D6.
	## On 2: disappear permanently (crew gains 2 story points).
	## On 11-12: crew receives a Quest.
	var results: Array[Dictionary] = []
	var crew: Array = ctx.get_participating_crew()
	for member in crew:
		if not member:
			continue
		var sid: String = ""
		if member is Dictionary:
			sid = member.get("species_id", "").to_lower()
		elif "species_id" in member:
			sid = str(member.species_id).to_lower()
		if sid != "traveler":
			continue

		var roll: int = (randi() % 6 + 1) + (randi() % 6 + 1)
		var char_name: String = ""
		if member is Dictionary:
			char_name = member.get(
				"character_name", "Traveler")
		elif member is Object and member.has_method("get"):
			char_name = str(member.get("character_name"))
			if char_name.is_empty():
				char_name = "Traveler"

		if roll == 2:
			results.append({
				"type": "disappear",
				"character": char_name, "roll": roll})
			if ctx.has_method("add_story_points"):
				ctx.add_story_points(2)
		elif roll >= 11:
			results.append({
				"type": "quest",
				"character": char_name, "roll": roll})
			if ctx.has_method("add_quest_rumor"):
				ctx.add_quest_rumor()
	return results

func check_manipulator_bonus(
	ctx: PostBattleContextClass
) -> int:
	## Core Rules p.22: When crew earns story points,
	## roll 1D6 per Manipulator in crew. On 6 = +1 bonus.
	var bonus: int = 0
	for member in ctx.get_participating_crew():
		if not member:
			continue
		var sid: String = ""
		if member is Dictionary:
			sid = member.get("species_id", "").to_lower()
		elif "species_id" in member:
			sid = str(member.species_id).to_lower()
		if sid == "manipulator":
			if (randi() % 6 + 1) == 6:
				bonus += 1
	return bonus

func process_consumed_items(ctx: PostBattleContextClass) -> Array:
	## Phase 3: Remove single-use items consumed during battle
	## Core Rules p.51: Single use weapons are used once then deducted
	## Returns array of removal result dicts for UI notification
	var consumed: Array = ctx.battle_result.get("consumed_items", [])
	if consumed.is_empty():
		return []

	var results: Array = []
	var crew: Array = ctx.get_participating_crew()

	for item in consumed:
		var char_id: String = str(item.get("character_id", ""))
		var weapon_name: String = str(item.get("weapon_name", ""))
		if char_id.is_empty() or weapon_name.is_empty():
			continue

		# Find the character and remove the item
		var removed := false
		for member in crew:
			if member == null:
				continue
			var mid: String = ""
			if member is Dictionary:
				mid = str(member.get("character_id",
					member.get("id", "")))
			elif member is Object and "character_id" in member:
				mid = str(member.character_id)
			if mid != char_id:
				continue

			# Remove from character equipment (Array[String])
			if member is Object and "equipment" in member:
				var eq: Array = member.equipment
				var idx: int = -1
				for i in eq.size():
					if str(eq[i]).to_lower() == weapon_name.to_lower():
						idx = i
						break
				if idx >= 0:
					eq.remove_at(idx)
					removed = true
			elif member is Dictionary:
				var eq: Array = member.get("equipment", [])
				var idx: int = -1
				for i in eq.size():
					if str(eq[i]).to_lower() == weapon_name.to_lower():
						idx = i
						break
				if idx >= 0:
					eq.remove_at(idx)
					removed = true
			break

		results.append({
			"character_id": char_id,
			"weapon_name": weapon_name,
			"character_name": str(item.get("character_name", "")),
			"removed": removed
		})

		if removed:
			# Journal entry for consumed item
			if ctx.campaign_journal and ctx.campaign_journal.has_method("auto_create_character_event"):
				ctx.campaign_journal.auto_create_character_event(
					char_id, "equipment_consumed",
					{"item": weapon_name, "turn": ctx.battle_result.get("turn", 0)})
		else:
			push_warning("PostBattleCompletion: Could not remove consumed item '%s' from character '%s'" % [weapon_name, char_id])

	return results
