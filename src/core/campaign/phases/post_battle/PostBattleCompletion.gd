class_name PostBattleCompletion
extends RefCounted

## Completion, statistics, and journal entries for Post-Battle Phase.
## Handles Step 14b: finalization after all 14 steps complete.
## Extracted from PostBattlePhase.gd — orchestrator delegates here.

const PostBattleContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
## Path-preloaded: BattleResultNormalizer deliberately declares NO class_name
## (see its header — the global class cache is stale), so it cannot be referenced
## as a global identifier. Reused here for _to_crew_entry(), which is the exact
## character-object -> crew_id resolution the journal harvest below needs.
const BattleResultNormalizerClass = preload("res://src/core/battle/BattleResultNormalizer.gd")

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

		var kills: Array = kills_by_character.get(char_id, [])
		# DICTIONARY BRANCH TOO. Crew members are canonically Dictionaries (the
		# data-ownership table), so gating on `member is Object` skipped every real
		# crew member: no lifetime counters ever moved, and the per-character battle
		# journal event was never created — which is why CharacterHistoryPanel showed
		# no battles for anyone.
		if member is Dictionary:
			var d: Dictionary = member
			d["battles_participated"] = int(d.get("battles_participated", 0)) + 1
			if char_id not in units_downed:
				d["battles_survived"] = int(d.get("battles_survived", 0)) + 1
			d["lifetime_kills"] = int(d.get("lifetime_kills", 0)) + kills.size()
			d["lifetime_damage_dealt"] = int(d.get("lifetime_damage_dealt", 0)) 				+ int(damage_dealt_per_unit.get(char_id, 0))
			d["lifetime_damage_taken"] = int(d.get("lifetime_damage_taken", 0)) 				+ int(damage_taken_per_unit.get(char_id, 0))
			_create_character_battle_journal_event(ctx, member, char_id, kills.size())
		elif member is Object and "battles_participated" in member:
			member.battles_participated += 1
			if char_id not in units_downed:
				member.battles_survived += 1
			member.lifetime_kills += kills.size()
			member.lifetime_damage_dealt += damage_dealt_per_unit.get(char_id, 0)
			member.lifetime_damage_taken += damage_taken_per_unit.get(char_id, 0)
			_create_character_battle_journal_event(ctx, member, char_id, kills.size())

func _resolve_participant_ids(participants: Array) -> Array:
	## Resolve battle participants to character IDS for journal attribution.
	##
	## The journal harvest used to keep only `participant is String`, but ALL THREE
	## live producers fill crew_participants with character OBJECTS:
	## TacticalBattleUI.gd:4194-4197 and :4428-4430 (both pass
	## unit.original_character) and BattleResultsInputForm.gd:373. So crew_ids was
	## deterministically [] and every battle entry landed with
	## characters_involved == [] — no battle was ever attributable to a crew member
	## in CharacterHistoryPanel's "Journal Entries" section, the journal screen's
	## per-character filter, or the entry detail pane.
	##
	## The contract is documented one file over, at PostBattleContext.gd:203-205:
	## "Producers fill crew_participants with character OBJECTS (not IDs). The old
	## loop treated them as IDs ... and always returned []." That fix landed on
	## get_participating_crew() and never reached this harvest.
	##
	## Only tests/fixtures/BattleTestFactory.gd:239 supplies Strings, which is
	## exactly why the suite never caught it: the fixture modelled the contract the
	## code EXPECTED rather than the one production produces. Strings are still
	## accepted so those fixtures keep working.
	var ids: Array = []
	for participant in participants:
		if participant is String:
			if not str(participant).is_empty():
				ids.append(str(participant))
			continue
		var entry: Dictionary = BattleResultNormalizerClass._to_crew_entry(participant)
		var cid: String = str(entry.get("crew_id", ""))
		if not cid.is_empty():
			ids.append(cid)
	return ids


func create_battle_journal_entry(ctx: PostBattleContextClass) -> void:
	## Create a journal entry for the completed battle
	if not ctx.campaign_journal or not ctx.campaign_journal.has_method("auto_create_battle_entry"):
		return
	var crew_ids: Array = _resolve_participant_ids(ctx.crew_participants)

	# Determine zone type for tagging and description enrichment
	var zone_type: String = ""
	var zone_tag: String = ""
	if ctx.battle_result.get("is_black_zone", false):
		zone_type = "BLACK ZONE"
		zone_tag = "black_zone"
	elif ctx.battle_result.get("is_red_zone", false):
		zone_type = "RED ZONE"
		zone_tag = "red_zone"

	# Audit B1 fix: ctx.battle_result has never actually carried a "location"
	# field, so the old default "Unknown" was always written. Resolve from the
	# PlanetDataManager autoload — that IS where the current planet name lives.
	# (Opus 4.8 audit B1 — Galaxy Log plan, 2026-06-01.)
	var resolved_location: String = ""
	var tree_for_loc = Engine.get_main_loop() if Engine.get_main_loop() else null
	var root_for_loc = tree_for_loc.root if tree_for_loc else null
	if root_for_loc:
		var pdm_for_loc = root_for_loc.get_node_or_null("/root/PlanetDataManager")
		if pdm_for_loc and pdm_for_loc.has_method("get_current_planet"):
			var current_planet = pdm_for_loc.get_current_planet()
			if current_planet and "name" in current_planet:
				resolved_location = String(current_planet.name)
	if resolved_location.is_empty():
		resolved_location = String(ctx.battle_result.get("location", "Unknown"))

	var entry_data: Dictionary = {
		"turn": ctx.battle_result.get("turn", 0),
		"location": resolved_location,
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

	# Add mission objective context (BattleObjectiveTracker). The result dict
	# carries objective_id/objective_met from TacticalBattleUI; record what the
	# crew was actually fighting for, not just victory/defeat.
	var obj_id: String = str(ctx.battle_result.get("objective_id", ""))
	if not obj_id.is_empty():
		entry_data["objective_id"] = obj_id
		entry_data["objective_met"] = bool(
			ctx.battle_result.get("objective_met", ctx.mission_successful))

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
	# Audit B1 fix: battle_result rarely carries world_id and never carries
	# location (see entry_data resolve above). Fall back to PDM's current
	# planet so complete_mission still records on the right world.
	if world_id.is_empty() and pdm.has_method("get_current_planet"):
		var current_for_mission = pdm.get_current_planet()
		if current_for_mission and "id" in current_for_mission:
			world_id = String(current_for_mission.id)
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


func apply_notable_sight_reward(ctx: PostBattleContextClass) -> Dictionary:
	## ⚠ NOT YET CALLED — one line away, and deliberately recorded rather than
	## hidden. The orchestrator (PostBattlePhase.gd) is the only site that calls
	## into this class, and it is held by a parallel Story Track branch; staging
	## it would sweep up that branch's uncommitted work. The producer (the results
	## form's "Reached the Notable Sight" check) and this reward logic are landed
	## so the unblock is a single insertion next to the other _completion calls:
	##
	##     _completion.apply_notable_sight_reward(_ctx)
	##
	## An uncalled rule is exactly the defect this audit exists to remove, so if
	## you are reading this and PostBattlePhase.gd is free, wire it now.
	##
	## Core Rules p.89 Notable Sights: the item "can be acquired by moving into
	## contact with it, and foregoing any other actions that round" — and its
	## listed reward is then gained.
	##
	## THE BUG THIS FIXES: the app rolled the sight, told the player it was
	## 2D6+2" from the centre and what it was worth, rendered its marker on the
	## battlefield map, and then had NO consumer for it. A crew member could spend
	## their whole round walking to a Person of Interest and the promised +1 story
	## point never arrived. The producer is the results form's "Reached the
	## Notable Sight" check (BattleResultsInputForm), asked rather than derived
	## because the fight happens on the player's table.
	##
	## Returns {applied: bool, type: String, description: String}.
	var result := {"applied": false, "type": "", "description": ""}
	if not bool(ctx.battle_result.get("notable_sight_claimed", false)):
		return result

	var sight: Dictionary = ctx.battle_result.get("notable_sight", {})
	if sight.is_empty():
		sight = ctx.battle_result.get("mission_data", {}).get("notable_sight", {})
	var sight_type: String = str(sight.get("type", "NOTHING"))
	result["type"] = sight_type
	if sight_type == "NOTHING" or sight_type.is_empty():
		return result

	match sight_type:
		"DOCUMENTATION":
			ctx.add_quest_rumor()
			result["description"] = "Documentation: gained a Quest Rumor"
		"SHINY_BITS":
			_grant_credits(ctx, 1)
			result["description"] = "Shiny bits: +1 credit"
		"REALLY_SHINY_BITS":
			_grant_credits(ctx, 2)
			result["description"] = "Really shiny bits: +2 credits"
		"PERSON_OF_INTEREST":
			ctx.add_story_points(1)
			result["description"] = "Person of interest: +1 story point"
		"PECULIAR_ITEM":
			ctx.award_xp_to_random_crew(2)
			result["description"] = "Peculiar item: +2 XP"
		"PRIORITY_TARGET":
			# "Add +1 to their Toughness. If they are SLAIN, gain 1D3 credits."
			# The +1 Toughness is a battlefield instruction the player applies on
			# the table; only the payout is a campaign mutation, and it is owed
			# only if that figure died.
			if bool(ctx.battle_result.get("priority_target_slain", false)):
				var credits: int = ctx.roll_d6()
				credits = int(ceil(credits / 2.0))  # 1D3
				_grant_credits(ctx, credits)
				result["description"] = "Priority target slain: +%d credits" % credits
			else:
				result["description"] = "Priority target survived: no reward"
		"LOOT_CACHE", "CURIOUS_ITEM":
			# Both resolve to a Loot Table roll, which Step 7 owns. Flag it so the
			# loot step grants the extra roll rather than duplicating that logic
			# here — one roller, one source of truth.
			ctx.battle_result["extra_loot_rolls"] = int(
				ctx.battle_result.get("extra_loot_rolls", 0)) + 1
			result["description"] = "%s: +1 Loot Table roll" % sight_type.capitalize()
		_:
			push_warning(
				"PostBattleCompletion: unknown Notable Sight type '%s'" % sight_type)
			return result

	result["applied"] = true
	if ctx.campaign_journal and ctx.campaign_journal.has_method("create_entry"):
		ctx.campaign_journal.create_entry({
			"type": "battle",
			"auto_generated": true,
			"title": "Notable Sight recovered",
			"description": str(result["description"]),
			"tags": ["notable_sight", "post_battle"],
		})
	return result


func _grant_credits(ctx: PostBattleContextClass, amount: int) -> void:
	if amount <= 0:
		return
	if ctx.game_state_manager and ctx.game_state_manager.has_method("get_credits") \
			and ctx.game_state_manager.has_method("set_credits"):
		ctx.game_state_manager.set_credits(ctx.game_state_manager.get_credits() + amount)
