class_name GalacticWarProcessor
extends RefCounted

## Galactic War resolution for Post-Battle Phase.
## Handles Step 14a: Galactic War Progress (Core Rules p.139-140)
## Extracted from PostBattlePhase.gd — orchestrator delegates here.

const PostBattleContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const RedZoneSystemRef = preload("res://src/core/mission/RedZoneSystem.gd")
## Core Rules pp.73-74 — "Imminent invasion" (-1) and "Military outpost" (+2) both
## modify THIS table and had no call site.
const WorldTraitEffectsRef = preload("res://src/core/world/WorldTraitEffects.gd")
## Compendium p.151 Civil War is recorded as a persistent strife effect on the
## campaign; this file resolves its ENDING (see _resolve_civil_war).
const FringeWorldStrifeRef = preload("res://src/core/world/FringeWorldStrife.gd")

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

	# ⚠ NO EARLY RETURN ON AN EMPTY LIST. This used to `return progress` when no
	# planet was invaded, which ALSO skipped the p.151 Civil War resolution added
	# below — and a civil-war world is not an invaded one, so the commonest case
	# (a civil war while nothing is invaded) could never reach its ending. An
	# empty loop is a no-op, and the journal block further down already guards on
	# its own result count, so dropping the return changes nothing else.
	var invaded_planets: Array = _get_invaded_planets(ctx)
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

		var roll: int = ctx.roll_2d6(
			"Galactic War - %s" % planet_name)
		# Red Zone: -1 to Galactic War Progress
		# (Core Rules Appendix III p.149)
		if ctx.battle_result.get("is_red_zone", false):
			var rz_mods: Dictionary = (
				RedZoneSystemRef.get_invasion_modifiers())
			war_modifier += rz_mods.get(
				"galactic_war_modifier", -1)

		# Core Rules pp.73-74, verbatim: "Imminent invasion — ...if the world is
		# invaded, rolls for war progress are at -1" and "Military outpost — Add +2
		# when checking for war progress."
		#
		# `WorldTraitEffects.war_progress_modifier()` implemented both and had ZERO
		# callers, so the two traits that speak directly to this table did nothing
		# at it. The traits are read off the BATTLE RESULT — carried there from the
		# mission by the normalizer — for the same reason the Invasion check reads
		# them there: the crew may have travelled since, and the world that was
		# invaded is the world that scores it.
		war_modifier += WorldTraitEffectsRef.war_progress_modifier(
			ctx.battle_result.get("world_traits", []))

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
			# Compendium p.114, the third clause of "Invasion!?": "If the world is
			# reclaimed, such Factions suffer -2 Power but gain +1 Influence.
			# Generate two new Factions when the war ends."
			#
			# "Reclaimed" is exactly this branch — Unity Victorious on the p.126
			# table. "Such Factions" are the Power 5+ defenders who stayed to fight,
			# whose ids UpkeepPhaseComponent banked on the tracked planet in the same
			# write as the +1-each war modifier they earned. So the +1 the crew has
			# been rolling with all along and the recovery they are now owed come
			# from one record and cannot disagree.
			_apply_invasion_recovery(planet)

		progress["planet_results"].append(outcome)

	# Compendium p.151 Civil War. Appends its own row to planet_results, so the
	# journal block below picks it up with everything else.
	_resolve_civil_war(ctx, progress)

	# NO GalacticWarManager DELEGATION HERE. That autoload implements a "war
	# track" system — D6 5+ advancement, dormant-track activation chance,
	# data/galactic_war/war_progress_tracks.json — and the phrase "war track"
	# appears in NEITHER the Core Rulebook NOR the Compendium (checked with
	# PyPDF2 across both PDFs). It is fabricated content, so per the data
	# integrity rules it must not be wired in. The book mechanic is the 2D6
	# table above, verbatim from Core Rules p.126 step 14, and this file already
	# implements it exactly. The old delegation was also unreachable: it sat
	# BELOW the invaded_planets.is_empty() early return.

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

## Compendium p.151 Civil War — the END of the war, which had NO call site.
##
## The war itself is deliberately not auto-resolved: siding with a faction and
## fighting Opportunity Missions is the player's table, and `FringeWorldStrife`
## records that decision at its own PERSISTENT EFFECTS block. What IS ours is the
## ending, because p.151 settles it with a die this file already rolls:
##
##   "During the Check for Galactic War Progress step, roll on the table normally
##    (core rules, p.126). A result of 'Unity Victorious' indicates your faction
##    has won the war. You receive 1D6 Credits in bonus pay (not to exceed the
##    number of missions you have done) and due to your war-hero status, you may
##    immediately remove 1 random Rival from your list.
##    A result of 'Lost to Unity' indicates your side lost. You must immediately
##    try to leave next campaign turn, similar to if the world had fallen to
##    invasion."
##
## ⚠ THE ROLL IS THE PLAIN 2D6. p.151 says "roll on the table normally", and every
## modifier the invaded-planet loop above applies (Red Zone -1, Imminent invasion
## -1, Military outpost +2) is invasion-specific and keyed off an invaded-planet
## record a civil-war world does not have. The ONE modifier that carries is the
## table's own 8-9 row ("+1 to future rolls"), banked on the effect payload so it
## survives a reload like every other strife fact.
##
## ⚠ Contested (5-7) and Making ground (8-9) are NOT endings — the war continues,
## the factions stay to ground, and nothing is paid out.
func _resolve_civil_war(ctx: PostBattleContextClass, progress: Dictionary) -> void:
	var planet_id: String = FringeWorldStrifeRef.world_with_effect(
		ctx.campaign, "civil_war")
	if planet_id.is_empty():
		return

	# ⚠ p.151: "You may leave at any time before the war is over (i.e. you are not
	# conscripted into service)." A crew that has travelled on is OUT of the war,
	# so it must not keep rolling for a faction it no longer fights for — and, more
	# importantly, the p.114 suppression has to lift with them or the factions stay
	# to ground for the rest of the campaign on a world the crew will never see
	# again. Departure is not an ENDING, so it pays nothing and generates no new
	# Factions; it just releases the crew and the faction layer.
	if _current_planet_id() != planet_id:
		_lift_civil_war(ctx, planet_id)
		progress["major_events"].append({
			"type": "civil_war_left",
			"planet": planet_id,
			"message": "Left %s before the civil war ended" % planet_id,
		})
		return

	var banked: int = 0
	for entry: Variant in FringeWorldStrifeRef.active_effects(ctx.campaign, planet_id):
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == "civil_war":
			banked = int((entry as Dictionary).get("war_modifier", 0))
			break

	var roll: int = ctx.roll_2d6("Galactic War - Civil War")
	var final_roll: int = roll + banked
	var outcome: Dictionary = {
		"planet_id": planet_id,
		"planet_name": planet_id,
		"civil_war": true,
		"roll": roll,
		"modifier": banked,
		"final_roll": final_roll,
		"result": "",
	}

	if final_roll <= 4:
		outcome["result"] = "lost_to_unity"
		outcome["description"] = "Your side lost the civil war"
		_end_civil_war(ctx, planet_id, false, progress)
	elif final_roll <= 7:
		outcome["result"] = "contested"
		outcome["description"] = "The civil war grinds on"
	elif final_roll <= 9:
		outcome["result"] = "making_ground"
		outcome["description"] = "Your side is making ground in the civil war"
		FringeWorldStrifeRef.update_effect_payload(
			ctx.campaign, planet_id, "civil_war", {"war_modifier": banked + 1})
	else:
		outcome["result"] = "victorious"
		outcome["description"] = "Your side won the civil war"
		_end_civil_war(ctx, planet_id, true, progress)

	progress["planet_results"].append(outcome)


## The shared ending. Both outcomes end the war, so the one thing that keys on
## "the war is over" — p.114's faction suppression — belongs here rather than in
## one branch, or the factions stay gone to ground forever.
##
## ⚠ THIS USED TO ALSO GENERATE TWO NEW FACTIONS, CITING p.114, AND THAT WAS A
## FABRICATED RULE (corrected 2026-09-10). Compendium p.114 carries two
## INDEPENDENT blocks in two columns. The left/middle one is "Invasion!?" and
## ends "Generate two new Factions when the war ends" — "the war" there is the
## INVASION, settled by the p.126 roll in the victorious branch above, which is
## where that call now lives. The right-hand block is "Fringe World Strife" and
## says of a Civil War only: "Factions will go to ground until the war is over."
## p.151's Civil War row says nothing about Factions at all. Two new Factions on
## a civil-war ending was a rule read out of the neighbouring column.
func _end_civil_war(ctx: PostBattleContextClass, planet_id: String, won: bool,
		progress: Dictionary) -> void:
	_lift_civil_war(ctx, planet_id)

	if won:
		# "1D6 Credits in bonus pay (not to exceed the number of missions you
		# have done)" — the cap is the reason this reads missions_completed
		# rather than just paying the die.
		var missions: int = int(_progress_data(ctx).get("missions_completed", 0))
		var bonus: int = mini(ctx.roll_d6("Civil War - war hero bonus pay"), missions)
		if bonus > 0 and ctx.game_state_manager \
				and ctx.game_state_manager.has_method("add_credits"):
			ctx.game_state_manager.add_credits(bonus)
		# "you may immediately remove 1 random Rival from your list"
		var removed: bool = false
		if ctx.game_state_manager \
				and ctx.game_state_manager.has_method("remove_random_rival"):
			removed = bool(ctx.game_state_manager.remove_random_rival())
		progress["major_events"].append({
			"type": "civil_war_won",
			"planet": planet_id,
			"credits": bonus,
			"rival_removed": removed,
			"message": "Your faction won the civil war on %s" % planet_id,
		})
	else:
		# "You must immediately try to leave next campaign turn, similar to if the
		# world had fallen to invasion. If you are unable to leave, your ship and
		# all Credits are confiscated." `invasion_flight_pending` is the flag the
		# Upkeep travel step ALREADY reads (UpkeepPhaseComponent:1133) to force
		# the flight and run the p.69 consequences, so this reuses the enforcement
		# rather than adding a second notion of "must flee".
		_progress_data(ctx)["invasion_flight_pending"] = true
		progress["major_events"].append({
			"type": "civil_war_lost",
			"planet": planet_id,
			"message": "Your side lost the civil war on %s — leave or lose everything" % planet_id,
		})


## Release the crew and the faction layer from a civil war, without paying out.
## Shared by both endings AND by departure, because all three stop the war being
## the crew's problem — and the p.114 suppression must lift in every one of them.
func _lift_civil_war(ctx: PostBattleContextClass, planet_id: String) -> void:
	FringeWorldStrifeRef.clear_active_effect(ctx.campaign, planet_id, "civil_war")
	# Compendium p.114: "If a Civil War breaks out, Factions will go to ground
	# until the war is over." THIS is the call that never existed — the flag was
	# set by process_strife_by_name() and cleared by nobody, so the factions went
	# to ground and stayed there for the rest of the campaign.
	var faction_sys: Node = _faction_system()
	if faction_sys and faction_sys.has_method("end_civil_war"):
		faction_sys.end_civil_war()


## The campaign's `progress_data`, for either campaign shape.
##
## ⚠ Product passes a `FiveParsecsCampaignCore` (a Resource, dot access) while the
## strife suites build a plain `{"progress_data": {}}` Dictionary. Mirrors
## `FringeWorldStrife._progress_data()` rather than assuming one shape — a
## Dictionary is a reference type, so writes through the returned value land on
## the campaign. Returns a throwaway `{}` when there is no campaign, so callers
## never null-check the container.
func _progress_data(ctx: PostBattleContextClass) -> Dictionary:
	var campaign: Variant = ctx.campaign
	if campaign == null:
		return {}
	if campaign is Dictionary:
		if not (campaign as Dictionary).has("progress_data"):
			(campaign as Dictionary)["progress_data"] = {}
		var d: Variant = (campaign as Dictionary)["progress_data"]
		return d if d is Dictionary else {}
	if "progress_data" in campaign and campaign.progress_data is Dictionary:
		return campaign.progress_data
	return {}


func _faction_system() -> Node:
	if Engine.get_main_loop() == null:
		return null
	return Engine.get_main_loop().root.get_node_or_null("/root/FactionSystem")


## The world the crew are on right now. Mirrors PaymentProcessor._current_planet_id()
## — PlanetDataManager is the owner, and reading it through the autoload keeps the
## two strife consumers answering from the same source.
## Compendium p.114 "Invasion!?", third clause. Runs when a tracked planet comes
## up Victorious on the p.126 table, i.e. the world is reclaimed.
##
## The Power 5+ defenders are read off the planet record rather than recomputed
## from `active_factions`: a faction that was Power 5 when the invasion landed may
## be Power 3 by the time the war ends (the p.115 event table moves both stats
## every turn), so recomputing "who is Power 5+" NOW would pay the wrong factions.
## The book means the ones who stayed to fight, which is what was recorded then.
##
## Silent no-op when the record has no defenders — a world nobody defended is
## reclaimed by Unity alone, and there is nothing to pay.
func _apply_invasion_recovery(planet: Variant) -> void:
	if not (planet is Dictionary):
		return
	var ids: Variant = (planet as Dictionary).get("defending_faction_ids", [])
	if not (ids is Array) or (ids as Array).is_empty():
		return
	var faction_sys: Node = _faction_system()
	if faction_sys == null \
			or not faction_sys.has_method("process_invasion_recovery"):
		return
	faction_sys.process_invasion_recovery(ids)


func _current_planet_id() -> String:
	if Engine.get_main_loop() == null:
		return ""
	var pdm: Node = Engine.get_main_loop().root.get_node_or_null("/root/PlanetDataManager")
	if pdm == null or not ("current_planet_id" in pdm):
		return ""
	return str(pdm.current_planet_id)


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
