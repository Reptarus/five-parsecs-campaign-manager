class_name PostBattleInjuryProcessor
extends RefCounted

## Injury resolution for Post-Battle Phase.
## Handles Step 8: Determine Injuries and Recovery (Core Rules p.94-95)
## Extracted from PostBattlePhase.gd — orchestrator delegates here.

const PostBattleContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const InjuryConstants = preload("res://src/core/systems/InjurySystemConstants.gd")

func process_injuries(ctx: PostBattleContextClass) -> Array[Dictionary]:
	## Process all injuries from battle. Returns array of processed injury dicts.
	var processed_injuries: Array[Dictionary] = []

	for injury_data in ctx.injuries_sustained:
		var processed_injury = process_single_injury(ctx, injury_data)
		processed_injuries.append(processed_injury)

	# Stars of the Story: "Looked worse than it was!" (Core Rules p.67)
	# Flag eligible injuries so PostBattleSequence can surface a "ignore this roll"
	# nudge button to the player. The book says player CHOOSES which roll to ignore,
	# so we flag every non-fatal injury; the UI enforces single-use via the star.
	if processed_injuries.size() > 0 and ctx.campaign \
			and "stars_of_the_story" in ctx.campaign \
			and not ctx.campaign.stars_of_the_story.is_empty():
		var StarsSystem = preload("res://src/core/systems/StarsOfTheStorySystem.gd")
		var stars := StarsSystem.new()
		stars.deserialize(ctx.campaign.stars_of_the_story)
		if stars.can_use(StarsSystem.StarAbility.LOOKED_WORSE):
			for inj in processed_injuries:
				if not inj.get("is_fatal", false):
					inj["star_offer_available"] = "LOOKED_WORSE"

	# Log injuries to CampaignJournal
	if ctx.campaign_journal and ctx.campaign_journal.has_method("auto_create_character_event"):
		var turn_num: int = ctx.game_state_manager.turn_number if ctx.game_state_manager and "turn_number" in ctx.game_state_manager else 0
		for inj in processed_injuries:
			var crew_id: String = inj.get("crew_id", "")
			if crew_id.is_empty():
				continue
			ctx.campaign_journal.auto_create_character_event(crew_id, "injury", {
				"turn": turn_num,
				"description": "Sustained %s injury. Recovery: %d turns." % [inj.get("type", "unknown"), inj.get("recovery_turns", 0)],
			})

	return processed_injuries

func process_single_injury(ctx: PostBattleContextClass, injury_data: Dictionary) -> Dictionary:
	## Process a single injury (Core Rules p.94). Routes bots to separate table.
	var crew_id = injury_data.get("crew_id", "")

	# Feel Great: ignore next Injury Table roll (Core Rules p.130)
	var crew_member_check: Variant = null
	if ctx.has_method("get_crew_member"):
		crew_member_check = ctx.get_crew_member(crew_id)
	if crew_member_check:
		var has_ignore_injury := false
		if crew_member_check is Resource \
				and crew_member_check.has_method("has_status_effect"):
			has_ignore_injury = crew_member_check.has_status_effect(
				"ignore_next_injury")
			if has_ignore_injury:
				crew_member_check.remove_status_effects_of_type(
					"ignore_next_injury")
		elif crew_member_check is Dictionary:
			var effs: Array = crew_member_check.get("status_effects", [])
			for i in range(effs.size() - 1, -1, -1):
				if str(effs[i].get("type", "")) == "ignore_next_injury":
					has_ignore_injury = true
					effs.remove_at(i)
					break
		if has_ignore_injury:
			return {
				"crew_id": crew_id,
				"type": "ignored",
				"description": "Injury ignored (Feel Great effect)",
				"recovery_turns": 0,
				"is_fatal": false
			}

	var is_bot_character := false
	var crew_origin: String = injury_data.get("origin", "")
	if crew_origin.is_empty() and ctx.game_state_manager:
		var crew_member = ctx.game_state_manager.get_crew_member(crew_id) if ctx.game_state_manager.has_method("get_crew_member") else null
		if crew_member:
			if crew_member.has_method("_is_bot"):
				is_bot_character = crew_member._is_bot()
			elif "origin" in crew_member:
				crew_origin = str(crew_member.origin)
	if not is_bot_character and crew_origin in [
		"BOT", "SOULLESS", "ASSAULT BOT", "Assault Bot"]:
		is_bot_character = true
	# Also check species_id for Strange Characters
	if not is_bot_character:
		var sid: String = injury_data.get("species_id", "")
		if sid.to_lower() == "assault_bot":
			is_bot_character = true

	if is_bot_character:
		return _process_bot_injury(ctx, injury_data, crew_id)

	var injury_roll := randi_range(1, 100)
	var injury_type := InjuryConstants.get_injury_type_from_roll(injury_roll)
	var recovery_info := InjuryConstants.get_recovery_time(injury_type)

	var recovery_time: int = 0
	if recovery_info.has("dice"):
		var min_time: int = recovery_info.get("min", 0)
		var max_time: int = recovery_info.get("max", 0)
		recovery_time = randi_range(min_time, max_time) if max_time > 0 else min_time
	else:
		recovery_time = recovery_info.get("max", 0)

	var injury_type_name: String = InjuryConstants.INJURY_TYPE_NAMES.get(injury_type, "UNKNOWN")
	var injury_description := InjuryConstants.get_injury_description(injury_type)
	var is_fatal := InjuryConstants.is_fatal(injury_type)
	var equipment_lost := InjuryConstants.causes_equipment_loss(injury_type)
	var bonus_xp := InjuryConstants.get_bonus_xp(injury_type)

	var processed_injury := {
		"crew_id": crew_id,
		"type": injury_type_name,
		"severity": injury_type,
		"recovery_turns": recovery_time,
		"turn_sustained": ctx.game_state_manager.turn_number if ctx.game_state_manager and "turn_number" in ctx.game_state_manager else 0,
		"description": injury_description,
		"is_fatal": is_fatal,
		"equipment_lost": equipment_lost,
		"bonus_xp": bonus_xp
	}

	# Fatal injuries: return early. The "Dramatic Escape" mechanic previously
	# wired here was fabricated (NOT in Core Rules p.67) and has been removed.
	# Per the book, the only post-battle injury star is "Looked worse than it was!"
	# which is offered to the player via PostBattleSequence nudge UI for any
	# non-fatal injury (flagged via star_offer_available in process_injuries()).
	if is_fatal:
		return processed_injury

	# Apply injury to crew member
	if ctx.game_state_manager and ctx.game_state_manager.has_method("apply_crew_injury"):
		ctx.game_state_manager.apply_crew_injury(crew_id, processed_injury)

	return processed_injury

func _process_bot_injury(ctx: PostBattleContextClass, injury_data: Dictionary, crew_id: String) -> Dictionary:
	## Process injury for Bot/Soulless character (Core Rules p.94-95)
	var injury_roll := randi_range(1, 100)
	var bot_injury_type := InjuryConstants.get_bot_injury_type_from_roll(injury_roll)
	var recovery_info := InjuryConstants.get_bot_recovery_time(bot_injury_type)
	var injury_type_name: String = InjuryConstants.BOT_INJURY_TYPE_NAMES.get(bot_injury_type, "UNKNOWN")
	var injury_description := InjuryConstants.get_bot_injury_description(bot_injury_type)
	var is_fatal := InjuryConstants.is_bot_fatal_injury(bot_injury_type)
	var equipment_damaged := InjuryConstants.bot_causes_equipment_loss(bot_injury_type)

	var recovery_time: int = 0
	if recovery_info.has("dice"):
		var min_time: int = recovery_info.get("min", 0)
		var max_time: int = recovery_info.get("max", 0)
		recovery_time = randi_range(min_time, max_time) if max_time > 0 else min_time
	else:
		recovery_time = recovery_info.get("max", 0)

	var processed_injury := {
		"crew_id": crew_id,
		"type": injury_type_name,
		"severity": bot_injury_type,
		"recovery_turns": recovery_time,
		"turn_sustained": ctx.game_state_manager.turn_number if ctx.game_state_manager and "turn_number" in ctx.game_state_manager else 0,
		"description": injury_description,
		"is_fatal": is_fatal,
		"equipment_lost": equipment_damaged,
		"bonus_xp": 0,
		"is_bot_injury": true
	}

	var bot_props: Dictionary = InjuryConstants.BOT_INJURY_PROPERTIES.get(bot_injury_type, {})
	if bot_props.get("all_equipment", false):
		processed_injury["all_equipment_damaged"] = true

	if ctx.game_state_manager and ctx.game_state_manager.has_method("apply_crew_injury"):
		ctx.game_state_manager.apply_crew_injury(crew_id, processed_injury)

	return processed_injury
