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

	# Core Rules p.119, closing line of Step 1: "Skip this step for Invasion
	# battles, or after fighting opponents from the Roving Threats Subtable."
	# p.101 states the same rule from the other side, in the Roving Threats
	# header: "Enemies from this list never become Rivals."
	#
	# Neither skip existed, so an Invasion battle you survived could saddle you
	# with a Rival the rules say cannot exist, and so could a pack of Razor
	# Lizards — the whole point of the Roving Threats table being that they are
	# wildlife and hazards, not people who hold a grudge.
	if bool(ctx.battle_result.get("is_invasion", false)):
		return {"rivals_removed": rivals_removed, "new_rivals": new_rivals}
	if str(ctx.battle_result.get("enemy_category", "")).to_lower() == "roving_threats":
		return {"rivals_removed": rivals_removed, "new_rivals": new_rivals}

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

	# Story Track: Event 1 (p.153) and Event 4 (p.156) both end with "Do not
	# check for new Rivals after this battle." Stamped by StoryTrackProcessor.
	# Note this suppresses only the NEW-Rival roll — the p.119 removal roll above
	# still runs, because Event 4's hold-field reward is to REMOVE one.
	var story_blocks_new_rivals: bool = bool(
		ctx.battle_result.get("story_no_new_rival_check", false))

	if held_field and not fought_existing_rival and not story_blocks_new_rivals:
		var new_rival_roll: int = randi_range(1, 6)
		if new_rival_roll == 1:
			var new_rival_id: String = _create_new_rival_from_battle(ctx)
			if new_rival_id != "":
				new_rivals.append(new_rival_id)

	# Psi-hunters (Compendium p.21). The book places this exactly here: "If a
	# Psionic uses a power during combat, roll D6 during the post-game step
	# '1. Resolve Rival Status'... If the indicated result is rolled, a band of
	# Psi-hunters are now on your tail."
	#
	# The detection roll already ran (PostBattlePhase writes the outcome to
	# progress_data["psionic_enforcement"]) and NOTHING read it — so the roll
	# happened, the log said "DETECTED!", and no Rival was ever created. The
	# consequence half of the rule did not exist.
	var psi_rival_id: String = _create_psi_hunter_rival(ctx)
	if psi_rival_id != "":
		new_rivals.append(psi_rival_id)

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
		# add_patron_contact() does NOT exist on GameState (zero definitions
		# repo-wide), so completing a patron job recorded nothing. Route through the
		# context's canonical patron mutator, which writes campaign.patrons — the
		# owner per the data-ownership table (Core Rules p.79, patron becomes a
		# standing contact after a completed job).
		#
		# Pass THIS Patron. Core Rules p.119 is "add the Patron" — the one whose job
		# you just finished. The bare call generated a random stranger instead, so
		# the contact you earned was never the contact you got.
		ctx.add_patron({
			"id": str(patron_id),
			"name": str(ctx.battle_result.get("patron_name", patron_id)),
			"type": str(ctx.battle_result.get("patron_type", "")),
			"source": "completed_job",
			"planet_id": str(ctx.battle_result.get("planet_id", "")),
		})
		patrons_added.append(str(patron_id))

		var npc_tracker = Engine.get_main_loop().root.get_node_or_null("/root/NPCTracker") if Engine.get_main_loop() else null
		if npc_tracker and npc_tracker.has_method("track_patron_interaction"):
			npc_tracker.track_patron_interaction(patron_id, "job_completed", {"turn": ctx.battle_result.get("turn", 0)})

		if HouseRulesHelper.is_enabled("expanded_rumors"):
			ctx.add_quest_rumor()

	elif not ctx.mission_successful and ctx.battle_result.has("patron_id"):
		var npc_tracker = Engine.get_main_loop().root.get_node_or_null("/root/NPCTracker") if Engine.get_main_loop() else null
		if npc_tracker and npc_tracker.has_method("track_patron_interaction"):
			npc_tracker.track_patron_interaction(ctx.battle_result.patron_id, "job_failed", {"turn": ctx.battle_result.get("turn", 0)})

		# Errata v1.06 (Core Rules p.119): "Failing a job you have accepted from
		# a known Patron causes them to be removed from your list of known
		# Patrons." Failure previously only logged an NPCTracker interaction —
		# the Patron stayed on the list and kept offering work, so a failed job
		# cost the crew nothing in standing.
		#
		# Only the ACCEPTED job's Patron is dropped. The same errata is explicit
		# that turning a job down carries no consequence: "You can turn down a
		# job from a known Patron without any consequence. They remain a known
		# Patron."
		var failed_patron_id: String = str(ctx.battle_result.get("patron_id", ""))
		if ctx.remove_patron(failed_patron_id):
			if ctx.campaign_journal and ctx.campaign_journal.has_method("create_entry"):
				ctx.campaign_journal.create_entry({
					# "patron" is a canonical TAG but not a canonical TYPE
					# (JournalEntryTypes.STRING_TO_TYPE), and "failure" is neither.
					# validate_entry() only WARNS, so this shipped as a console
					# warning and an entry that rendered with the fallback colour.
					"type": "event",
					"title": "Patron contract failed",
					"description": "Failing an accepted job removed this Patron "
						+ "from your known contacts (Core Rules p.119, errata v1.06).",
					"turn": int(ctx.battle_result.get("turn", 0)),
					"tags": ["patron", "defeat"],
				})

	return patrons_added

func process_quest_progress(ctx: PostBattleContextClass) -> int:
	## Step 3: Determine Quest Progress (Core Rules p.86). Returns 0/1/2.
	var quest_progress: int = 0

	# Guard has_active_quest with has_method (matching the get_quest_rumors guards
	# below). GameState exposes no quest API today, so Step 3 safely no-ops instead
	# of crashing post-battle. Pre-existing unguarded call since f4346c39.
	if not ctx.game_state or not ctx.game_state.has_method("has_active_quest") \
			or not ctx.game_state.has_active_quest():
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

	# Core Rules p.119: "If the modified roll was a 4 or higher, roll another D6
	# with no modifiers. On a 5-6, the next step is on another world, and you must
	# travel before you are able to progress the Quest." This applies to BOTH the
	# 4-6 step-closer AND the 7+ finale (modified roll >= 4), so it lives outside
	# the 7+ branch. There is no "travel but same world" tier — the only travel
	# outcome is a 5-6 → another world ("Quests will wait for you"; not immediate).
	if total_roll >= 4:
		var travel_roll: int = ctx.roll_d6("Quest travel requirement")
		if travel_roll >= 5 and ctx.game_state.has_method("set_quest_requires_travel"):
			ctx.game_state.set_quest_requires_travel(true, true)

	return quest_progress

func _roll_rival_removal(ctx: PostBattleContextClass, rival_id: String) -> int:
	var base_roll: int = randi_range(1, 6)
	var modifiers: int = 0
	if ctx.game_state and ctx.game_state.current_campaign:
		var campaign = ctx.game_state.current_campaign
		# Core Rules p.119: "+1 if you Tracked them down during Assign and Resolve
		# Crew Tasks". The Track task's outcome lives in
		# progress_data["tracked_rivals"] (written by WorldPhaseController at the
		# same point it persists the mission). This read looked for a top-level
		# `tracked_rivals` PROPERTY, which FiveParsecsCampaignCore does not
		# declare — so `"tracked_rivals" in campaign` was permanently false, the
		# Dictionary branch never ran for a Resource campaign, and the modifier
		# could not apply no matter how the player played the World Phase.
		var tracked_rivals: Array = []
		if campaign is Dictionary:
			tracked_rivals = (campaign as Dictionary).get("progress_data", {}).get(
				"tracked_rivals", [])
		elif "progress_data" in campaign:
			tracked_rivals = campaign.progress_data.get("tracked_rivals", [])
		if rival_id in tracked_rivals:
			modifiers += 1
	# Core Rules p.119: "Add +1 if you killed a Unique Individual in the battle."
	# Errata v1.06 amends that line to "a Unique Individual OR LIEUTENANT".
	#
	# THE BUG THIS FIXES: this read enemy["is_unique"], a key NO producer writes.
	# Every path builds defeated_enemies with was_unique_individual /
	# was_lieutenant (see TacticalBattleUI._defeated_enemy_records), so the
	# modifier could never apply and killing the enemy Boss did nothing to help
	# you chase a Rival off. `is_unique` is still accepted for any older result
	# dict that used it.
	for enemy in ctx.defeated_enemies:
		if enemy.get("rival_id", "") != rival_id:
			continue
		if bool(enemy.get("was_unique_individual", enemy.get("is_unique", false))) \
				or bool(enemy.get("was_lieutenant", false)):
			modifiers += 1
			break
	return base_roll + modifiers

func _create_new_rival_from_battle(ctx: PostBattleContextClass) -> String:
	if not ctx.game_state or not ctx.game_state.current_campaign:
		return ""
	var campaign = ctx.game_state.current_campaign
	var enemy_type: String = ctx.battle_result.get("enemy_type", "Unknown")
	return _append_rival(campaign, ctx, enemy_type)

func _create_psi_hunter_rival(ctx) -> String:
	## Compendium p.21: on a successful detection roll, "a band of Psi-hunters are
	## now on your tail", typed on a D6 — 1-2 Bounty Hunters, 3 Vigilantes,
	## 4-5 Enforcers, 6 Colonial Militia. "Note on your record sheet that these
	## Rivals are Psi-hunters IN ADDITION TO their normal type", and they carry
	## three adjustments: Seize the Initiative against them at -2, one extra
	## Specialist added after generating their force, and +1 to their attack roll
	## when shooting at or Brawling with a Psionic character.
	##
	## PostBattlePhase performs the detection and stores the outcome in
	## progress_data["psionic_enforcement"]; nothing consumed it, so no Rival was
	## ever produced. The flag is CLEARED here so one detection cannot keep
	## spawning hunters on every later battle.
	if not ctx.game_state or not ctx.game_state.current_campaign:
		return ""
	var campaign = ctx.game_state.current_campaign
	if not ("progress_data" in campaign):
		return ""
	var pd: Dictionary = campaign.progress_data
	var enforcement: Variant = pd.get("psionic_enforcement", null)
	if not (enforcement is Dictionary):
		return ""
	pd.erase("psionic_enforcement")
	if not bool((enforcement as Dictionary).get("detected", false)):
		return ""
	var hunter_type: String = str(
		(enforcement as Dictionary).get("enforcement", {}).get("type", "Enforcers"))
	return _append_rival(campaign, ctx, hunter_type, true)

func _append_rival(campaign, ctx, enemy_type: String, is_psi_hunter: bool = false) -> String:
	var planet_id: String = ctx.battle_result.get("planet_id", "")
	var new_rival: Dictionary = {
		"id": "rival_%s_%d" % [enemy_type.to_lower().replace(" ", "_"), randi()],
		"name": (enemy_type + " Psi-hunters") if is_psi_hunter else (enemy_type + " Vendetta"),
		"type": enemy_type,
		"planet_id": planet_id,
		"threat_level": 1,
		"created_turn": ctx.battle_result.get("turn", 0),
		"origin": "psi_hunt" if is_psi_hunter else "battle_grudge"
	}
	if is_psi_hunter:
		# "Note on your record sheet that these Rivals are Psi-hunters in addition
		# to their normal type" — the tag rides along with the three adjustments
		# so battle setup can apply them without re-deriving anything.
		new_rival["is_psi_hunter"] = true
		new_rival["seize_initiative_modifier"] = -2
		new_rival["extra_specialists"] = 1
		new_rival["attack_bonus_vs_psionic"] = 1
	# The canonical rival list on FiveParsecsCampaignCore is `rivals`
	# (FiveParsecsCampaignCore.gd:44, serialised at :225 and :346). `active_rivals`
	# belongs to DIFFERENT classes — RivalManager, RivalSystem, FactionSystem and
	# the legacy Campaign — so this was written against the wrong type. Both
	# branches were permanently false for a real campaign: the Resource has no
	# `active_rivals` property, and it is not a Dictionary either. The rival was
	# built, silently discarded, and its id returned as though it had been recorded.
	# Core Rules p.86 rival acquisition therefore never happened.
	#
	# `rivals` is a mixed Array of Strings and Dictionaries (CharacterGeneration
	# appends names, CrewTaskComponent.gd:2320 and CharacterTransferService.gd:487
	# append dicts), which is why _remove_rival below reads both shapes.
	if "rivals" in campaign:
		campaign.rivals.append(new_rival)
	elif campaign is Dictionary:
		if not campaign.has("rivals"):
			campaign["rivals"] = []
		campaign["rivals"].append(new_rival)
	return new_rival.id

func _remove_rival(ctx: PostBattleContextClass, rival_id: String) -> void:
	## Same wrong-field bug as _create_new_rival_from_battle, and worse in effect:
	## the caller appends to `rivals_removed` BEFORE calling this (line 32), and
	## that array IS consumed — PostBattlePhase.gd:161 emits it, and
	## CampaignTurnController.gd:381 / PostBattleSequence.gd:649 render it. So with
	## the guard permanently false, the post-battle screen reported rivals as
	## removed while the canonical list still held them, and they reappeared next
	## turn. A silent no-op would have been better than a false success.
	if ctx.game_state and ctx.game_state.current_campaign and "rivals" in ctx.game_state.current_campaign:
		var rivals: Array = ctx.game_state.current_campaign.rivals
		for i in range(rivals.size() - 1, -1, -1):
			var rival = rivals[i]
			var rid = rival.get("id", rival) if rival is Dictionary else str(rival)
			if rid == rival_id:
				rivals.remove_at(i)
				return
