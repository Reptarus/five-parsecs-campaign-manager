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

	# Stars of the Story: "It Wasn't That Bad!" - remove worst non-fatal injury
	if processed_injuries.size() > 0 and ctx.campaign and "stars_of_story_data" in ctx.campaign and not ctx.campaign.stars_of_story_data.is_empty():
		var StarsSystem = preload("res://src/core/systems/StarsOfTheStorySystem.gd")
		var stars := StarsSystem.new()
		stars.deserialize(ctx.campaign.stars_of_story_data)
		if stars.can_use(StarsSystem.StarAbility.IT_WASNT_THAT_BAD):
			var worst_idx := -1
			var worst_recovery := 0
			for i in range(processed_injuries.size()):
				var inj = processed_injuries[i]
				if inj.get("is_fatal", false):
					continue
				var rec: int = inj.get("recovery_turns", 0)
				if rec > worst_recovery:
					worst_recovery = rec
					worst_idx = i
			if worst_idx >= 0:
				var removed_injury = processed_injuries[worst_idx]
				var context = {"character": {"name": removed_injury.get("crew_id", ""), "injuries": [removed_injury.get("type", "")]}, "injury": removed_injury.get("type", "")}
				var star_result = stars.use_ability(StarsSystem.StarAbility.IT_WASNT_THAT_BAD, context)
				if star_result.get("success", false):
					processed_injuries.remove_at(worst_idx)
					ctx.campaign.stars_of_story_data = stars.serialize()

	return processed_injuries

func process_single_injury(ctx: PostBattleContextClass, injury_data: Dictionary) -> Dictionary:
	## Process a single injury (Core Rules p.94). Routes bots to separate table.
	var crew_id = injury_data.get("crew_id", "")

	var is_bot_character := false
	var crew_origin: String = injury_data.get("origin", "")
	if crew_origin.is_empty() and ctx.game_state_manager:
		var crew_member = ctx.game_state_manager.get_crew_member(crew_id) if ctx.game_state_manager.has_method("get_crew_member") else null
		if crew_member:
			if crew_member.has_method("_is_bot"):
				is_bot_character = crew_member._is_bot()
			elif "origin" in crew_member:
				crew_origin = str(crew_member.origin)
	if not is_bot_character and (crew_origin == "BOT" or crew_origin == "SOULLESS"):
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
		"turn_sustained": ctx.game_state_manager.turn_number if ctx.game_state_manager else 0,
		"description": injury_description,
		"is_fatal": is_fatal,
		"equipment_lost": equipment_lost,
		"bonus_xp": bonus_xp
	}

	# Handle fatal injuries - check for Stars of the Story protection
	if is_fatal:
		var star_saved := false
		if ctx.campaign and "stars_of_story_data" in ctx.campaign and not ctx.campaign.stars_of_story_data.is_empty():
			var StarsSystem = preload("res://src/core/systems/StarsOfTheStorySystem.gd")
			var stars := StarsSystem.new()
			stars.deserialize(ctx.campaign.stars_of_story_data)
			if stars.can_use(StarsSystem.StarAbility.DRAMATIC_ESCAPE):
				var crew_name: String = injury_data.get("crew_name", crew_id)
				var star_result = stars.use_ability(StarsSystem.StarAbility.DRAMATIC_ESCAPE, {"character": {"name": crew_name, "current_hp": 0}})
				if star_result.get("success", false):
					star_saved = true
					processed_injury["is_fatal"] = false
					processed_injury["star_protected"] = true
					processed_injury["star_ability_used"] = "DRAMATIC_ESCAPE"
					processed_injury["recovery_turns"] = maxi(recovery_time, 3)
					ctx.campaign.stars_of_story_data = stars.serialize()
		if not star_saved:
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
		"turn_sustained": ctx.game_state_manager.turn_number if ctx.game_state_manager else 0,
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
