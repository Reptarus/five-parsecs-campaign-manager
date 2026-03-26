class_name GalacticWarProcessor
extends RefCounted

## Galactic War resolution for Post-Battle Phase.
## Handles Step 14a: Galactic War Progress (Core Rules p.139-140)
## Extracted from PostBattlePhase.gd — orchestrator delegates here.

const PostBattleContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")

func process_galactic_war(ctx: PostBattleContextClass) -> Dictionary:
	## Update galactic war progression.
	## For each invaded planet, roll 2D6 + war_modifier:
	## - 4 or less: Planet lost to Unity (crew must flee if present)
	## - 5-7: Conflict continues (contested)
	## - 8-9: Making ground (+1 to future rolls)
	## - 10+: Victorious (planet liberated, -2 invasion chance)
	var progress: Dictionary = {
		"conflicts_active": 0,
		"major_events": [],
		"faction_changes": [],
		"planet_results": []
	}

	var invaded_planets: Array = _get_invaded_planets(ctx)
	if invaded_planets.is_empty():
		return progress

	progress["conflicts_active"] = invaded_planets.size()

	for planet in invaded_planets:
		var planet_id: String = ""
		var planet_name: String = "Unknown Planet"
		var war_modifier: int = 0

		if planet is Dictionary:
			planet_id = planet.get("id", planet.get("planet_id", ""))
			planet_name = planet.get("name", planet.get("planet_name", "Unknown"))
			war_modifier = planet.get("war_modifier", 0)
		elif planet is String:
			planet_id = planet
			planet_name = planet

		var roll: int = ctx.roll_2d6("Galactic War - %s" % planet_name)
		var modified_roll: int = roll + war_modifier

		var outcome: Dictionary = {
			"planet_id": planet_id,
			"planet_name": planet_name,
			"roll": roll,
			"modifier": war_modifier,
			"final_roll": modified_roll,
			"result": ""
		}

		if modified_roll <= 4:
			outcome["result"] = "lost_to_unity"
			outcome["description"] = "%s has fallen to Unity forces" % planet_name
			_mark_planet_lost(ctx, planet_id)
			progress["major_events"].append({
				"type": "planet_lost",
				"planet": planet_name,
				"message": "Planet %s conquered by Unity!" % planet_name
			})
		elif modified_roll <= 7:
			outcome["result"] = "contested"
			outcome["description"] = "%s remains contested" % planet_name
		elif modified_roll <= 9:
			outcome["result"] = "making_ground"
			outcome["description"] = "%s defenders making progress" % planet_name
			_add_planet_war_modifier(ctx, planet_id, 1)
			progress["faction_changes"].append({
				"type": "momentum_gained",
				"planet": planet_name,
				"bonus": 1
			})
		else:
			outcome["result"] = "victorious"
			outcome["description"] = "%s liberated from Unity forces" % planet_name
			_mark_planet_liberated(ctx, planet_id)
			_reduce_invasion_modifier(ctx, planet_id, 2)
			progress["major_events"].append({
				"type": "planet_liberated",
				"planet": planet_name,
				"message": "Planet %s liberated!" % planet_name
			})

		progress["planet_results"].append(outcome)

	# Delegate war track progression to GalacticWarManager autoload
	if ctx.galactic_war_manager and ctx.galactic_war_manager.has_method("process_turn_war_progression"):
		var war_events: Array = ctx.galactic_war_manager.process_turn_war_progression()
		progress["war_track_events"] = war_events

	# Journal: log galactic war progress
	if progress["planet_results"].size() > 0 and ctx.campaign_journal \
			and ctx.campaign_journal.has_method("create_entry"):
		var desc_parts: Array = []
		for result in progress["planet_results"]:
			desc_parts.append("%s: %s" % [
				result.get("planet_name", "?"),
				result.get("result", "contested")])
		ctx.campaign_journal.create_entry({
			"type": "galactic_war",
			"auto_generated": true,
			"title": "Galactic War: %d conflicts" % progress["conflicts_active"],
			"description": "; ".join(desc_parts),
			"tags": ["galactic_war", "post_battle"],
			"stats": progress,
		})

	return progress

func _get_invaded_planets(ctx: PostBattleContextClass) -> Array:
	if ctx.game_state and ctx.game_state.current_campaign and "invaded_planets" in ctx.game_state.current_campaign:
		return ctx.game_state.current_campaign.invaded_planets
	return []

func _mark_planet_lost(ctx: PostBattleContextClass, planet_id: String) -> void:
	if ctx.game_state and ctx.game_state.current_campaign:
		var campaign: Variant = ctx.game_state.current_campaign
		if "lost_planets" in campaign:
			if planet_id not in campaign.lost_planets:
				campaign.lost_planets.append(planet_id)
		if "invaded_planets" in campaign:
			campaign.invaded_planets = campaign.invaded_planets.filter(func(p: Variant) -> bool: return _get_planet_id(p) != planet_id)

func _mark_planet_liberated(ctx: PostBattleContextClass, planet_id: String) -> void:
	if ctx.game_state and ctx.game_state.current_campaign:
		var campaign: Variant = ctx.game_state.current_campaign
		if "liberated_planets" in campaign:
			if planet_id not in campaign.liberated_planets:
				campaign.liberated_planets.append(planet_id)
		if "invaded_planets" in campaign:
			campaign.invaded_planets = campaign.invaded_planets.filter(func(p: Variant) -> bool: return _get_planet_id(p) != planet_id)

func _add_planet_war_modifier(ctx: PostBattleContextClass, planet_id: String, amount: int) -> void:
	if ctx.game_state and ctx.game_state.current_campaign:
		var campaign: Variant = ctx.game_state.current_campaign
		if "invaded_planets" in campaign:
			for i in range(campaign.invaded_planets.size()):
				var planet: Variant = campaign.invaded_planets[i]
				if _get_planet_id(planet) == planet_id:
					if planet is Dictionary:
						planet["war_modifier"] = planet.get("war_modifier", 0) + amount
					else:
						campaign.invaded_planets[i] = {"id": planet_id, "war_modifier": amount}
					break

func _reduce_invasion_modifier(ctx: PostBattleContextClass, planet_id: String, amount: int) -> void:
	if ctx.game_state and ctx.game_state.current_campaign:
		var campaign: Variant = ctx.game_state.current_campaign
		if "invasion_modifiers" in campaign:
			campaign.invasion_modifiers[planet_id] = campaign.invasion_modifiers.get(planet_id, 0) - amount

func _get_planet_id(planet: Variant) -> String:
	if planet is String:
		return planet
	elif planet is Dictionary:
		return planet.get("id", planet.get("planet_id", ""))
	return ""
