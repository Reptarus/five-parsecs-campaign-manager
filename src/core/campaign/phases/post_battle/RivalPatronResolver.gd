class_name RivalPatronResolver
extends RefCounted

## Rival, Patron, and Quest resolution for Post-Battle Phase.
## Handles Steps 1-3: Rival Status, Patron Status, Quest Progress (Core Rules p.86, p.88, p.119)
## Extracted from PostBattlePhase.gd — orchestrator delegates here.

const ShipComponentQuery = preload("res://src/core/ship/ShipComponentQuery.gd")
const PostBattleContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const HouseRulesHelper = preload("res://src/core/systems/HouseRulesHelper.gd")
const DifficultyModifiers = preload("res://src/core/systems/DifficultyModifiers.gd")

func process_rival_status(ctx: PostBattleContextClass) -> Dictionary:
	## Step 1: Resolve Rival Status. Returns {rivals_removed, new_rivals}.
	var rivals_removed: Array[String] = []
	var new_rivals: Array[String] = []
	var held_field: bool = ctx.battle_result.get("held_field", false)

	var faction_sys = Engine.get_main_loop().root.get_node_or_null("/root/FactionSystem") if Engine.get_main_loop() else null
	var npc_tracker_node: Variant = null
	if Engine.get_main_loop():
		npc_tracker_node = Engine.get_main_loop().root.get_node_or_null("/root/NPCTracker")

	var fought_existing_rival: bool = false
	for enemy in ctx.defeated_enemies:
		if enemy.get("is_rival", false):
			fought_existing_rival = true
			var rival_id = enemy.get("rival_id", "")
			if rival_id != "" and held_field:
				var removal_roll = _roll_rival_removal(ctx, rival_id)
				if removal_roll >= 4:
					rivals_removed.append(rival_id)
					_remove_rival(ctx, rival_id)
				if faction_sys and faction_sys.has_method("update_rival_reputation"):
					var rep_change = 2 if removal_roll >= 4 else -1
					faction_sys.update_rival_reputation(rival_id, rep_change)
				if npc_tracker_node and npc_tracker_node.has_method("track_rival_encounter"):
					var result_str: String = "victory" if ctx.mission_successful else "defeat"
					npc_tracker_node.track_rival_encounter(rival_id, result_str, ctx.battle_result.get("turn", 0))

	if held_field and not fought_existing_rival:
		var new_rival_roll: int = randi_range(1, 6)
		if new_rival_roll == 1:
			var new_rival_id: String = _create_new_rival_from_battle(ctx)
			if new_rival_id != "":
				new_rivals.append(new_rival_id)

	if faction_sys and faction_sys.has_method("modify_faction_standing"):
		var faction_id: String = ctx.battle_result.get("faction_id", "")
		if faction_id != "":
			var standing_change: float = 5.0 if ctx.mission_successful else -3.0
			faction_sys.modify_faction_standing(faction_id, standing_change)

			# Loyalty gain on faction job win (Compendium p.114)
			if ctx.mission_successful and faction_sys.has_method("roll_loyalty_gain"):
				var is_affiliated: bool = ctx.battle_result.get(
					"is_affiliated_patron_job", false
				)
				faction_sys.roll_loyalty_gain(faction_id, is_affiliated)
				# Mark successful job for faction activity bonuses
				if faction_sys.has_method("has_faction") and faction_sys.has_faction(faction_id):
					var factions_dict: Dictionary = faction_sys.get(
						"active_factions"
					) if faction_sys.get("active_factions") is Dictionary else {}
					if factions_dict.has(faction_id):
						factions_dict[faction_id]["successful_job_this_turn"] = true

	return {"rivals_removed": rivals_removed, "new_rivals": new_rivals}

func process_patron_status(ctx: PostBattleContextClass) -> Array[String]:
	## Step 2: Resolve Patron Status. Returns patrons_added array.
	var patrons_added: Array[String] = []

	if ctx.mission_successful and ctx.battle_result.has("patron_id"):
		var patron_id = ctx.battle_result.patron_id
		if ctx.game_state and ctx.game_state.has_method("add_patron_contact"):
			ctx.game_state.add_patron_contact(patron_id)
			patrons_added.append(patron_id)

		var patron_sys = Engine.get_main_loop().root.get_node_or_null("/root/PatronSystem") if Engine.get_main_loop() else null
		if patron_sys and patron_sys.has_method("complete_job"):
			patron_sys.complete_job(true, ctx.battle_result)

		var npc_tracker = Engine.get_main_loop().root.get_node_or_null("/root/NPCTracker") if Engine.get_main_loop() else null
		if npc_tracker and npc_tracker.has_method("track_patron_interaction"):
			npc_tracker.track_patron_interaction(patron_id, "job_completed", {"turn": ctx.battle_result.get("turn", 0)})

		if HouseRulesHelper.is_enabled("expanded_rumors"):
			ctx.add_quest_rumor()

	elif not ctx.mission_successful and ctx.battle_result.has("patron_id"):
		var patron_sys = Engine.get_main_loop().root.get_node_or_null("/root/PatronSystem") if Engine.get_main_loop() else null
		if patron_sys and patron_sys.has_method("complete_job"):
			patron_sys.complete_job(false, ctx.battle_result)

		var npc_tracker = Engine.get_main_loop().root.get_node_or_null("/root/NPCTracker") if Engine.get_main_loop() else null
		if npc_tracker and npc_tracker.has_method("track_patron_interaction"):
			npc_tracker.track_patron_interaction(ctx.battle_result.patron_id, "job_failed", {"turn": ctx.battle_result.get("turn", 0)})

	return patrons_added

func process_quest_progress(ctx: PostBattleContextClass) -> int:
	## Step 3: Determine Quest Progress (Core Rules p.86). Returns 0/1/2.
	var quest_progress: int = 0

	if not ctx.game_state or not ctx.game_state.has_active_quest():
		return 0

	var base_roll: int = ctx.roll_d6("Quest progress roll")
	var quest_rumors: int = 0
	if ctx.game_state.has_method("get_quest_rumors"):
		quest_rumors = ctx.game_state.get_quest_rumors()
	elif ctx.game_state.has_method("get_quest_rumor_count"):
		quest_rumors = ctx.game_state.get_quest_rumor_count()

	var total_roll: int = base_roll + quest_rumors

	# Expanded Database: +1 to quest progress (Compendium p.28)
	if ShipComponentQuery.has_component("expanded_database"):
		total_roll += 1
		var journal: Variant = Engine.get_main_loop().root.get_node_or_null(
			"/root/CampaignJournal") if Engine.get_main_loop() else null
		if journal and journal.has_method("create_entry"):
			journal.create_entry({
				"type": "story",
				"title": "Database-Assisted Research",
				"description": "Expanded Database provided +1 to Quest progress roll.",
				"tags": ["ship_component", "expanded_database", "quest", "compendium"],
				"auto_generated": true,
				"mood": "neutral",
			})

	if not ctx.mission_successful:
		total_roll -= 2

	if total_roll <= 3:
		quest_progress = 0
	elif total_roll <= 6:
		quest_progress = 1
		if ctx.game_state.has_method("add_quest_rumor"):
			ctx.game_state.add_quest_rumor()
	else:
		quest_progress = 2
		if ctx.game_state.has_method("set_quest_finale_available"):
			ctx.game_state.set_quest_finale_available(true)
		var travel_roll: int = ctx.roll_d6("Quest finale travel requirement")
		if travel_roll >= 4:
			var requires_new_world: bool = travel_roll >= 5
			if ctx.game_state.has_method("set_quest_requires_travel"):
				ctx.game_state.set_quest_requires_travel(true, requires_new_world)

	return quest_progress

func _roll_rival_removal(ctx: PostBattleContextClass, rival_id: String) -> int:
	var base_roll: int = randi_range(1, 6)
	var modifiers: int = 0
	if ctx.game_state and ctx.game_state.current_campaign:
		var campaign = ctx.game_state.current_campaign
		var tracked_rivals: Array = []
		if "tracked_rivals" in campaign:
			tracked_rivals = campaign.tracked_rivals
		elif campaign is Dictionary:
			tracked_rivals = campaign.get("tracked_rivals", [])
		if rival_id in tracked_rivals:
			modifiers += 1
	for enemy in ctx.defeated_enemies:
		if enemy.get("rival_id", "") == rival_id and enemy.get("is_unique", false):
			modifiers += 1
			break
	return base_roll + modifiers

func _create_new_rival_from_battle(ctx: PostBattleContextClass) -> String:
	if not ctx.game_state or not ctx.game_state.current_campaign:
		return ""
	var campaign = ctx.game_state.current_campaign
	var enemy_type: String = ctx.battle_result.get("enemy_type", "Unknown")
	var planet_id: String = ctx.battle_result.get("planet_id", "")
	var new_rival: Dictionary = {
		"id": "rival_%s_%d" % [enemy_type.to_lower().replace(" ", "_"), randi()],
		"name": enemy_type + " Vendetta",
		"type": enemy_type,
		"planet_id": planet_id,
		"threat_level": 1,
		"created_turn": ctx.battle_result.get("turn", 0),
		"origin": "battle_grudge"
	}
	if "active_rivals" in campaign:
		campaign.active_rivals.append(new_rival)
	elif campaign is Dictionary:
		if not campaign.has("active_rivals"):
			campaign["active_rivals"] = []
		campaign["active_rivals"].append(new_rival)
	return new_rival.id

func _remove_rival(ctx: PostBattleContextClass, rival_id: String) -> void:
	if ctx.game_state and ctx.game_state.current_campaign and "active_rivals" in ctx.game_state.current_campaign:
		var rivals: Array = ctx.game_state.current_campaign.active_rivals
		for i in range(rivals.size() - 1, -1, -1):
			var rival = rivals[i]
			var rid = rival.get("id", rival) if rival is Dictionary else str(rival)
			if rid == rival_id:
				rivals.remove_at(i)
				return
