class_name RivalPatronResolver
extends RefCounted

## Rival, Patron, and Quest resolution for Post-Battle Phase.
## Handles Steps 1-3: Rival Status, Patron Status, Quest Progress (Core Rules p.86, p.88, p.119)
## Extracted from PostBattlePhase.gd — orchestrator delegates here.

const ShipComponentQuery = preload("res://src/core/ship/ShipComponentQuery.gd")
const PostBattleContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const HouseRulesHelper = preload("res://src/core/systems/HouseRulesHelper.gd")
const DifficultyModifiers = preload("res://src/core/systems/DifficultyModifiers.gd")
const WorldTraitEffects = preload("res://src/core/world/WorldTraitEffects.gd")
const PatronJobEffects = preload("res://src/core/patrons/PatronJobEffects.gd")
const LootTableResolver = preload("res://src/core/equipment/LootTableResolver.gd")
const EnemyTraitRules = preload("res://src/core/systems/EnemyTraitRules.gd")
const EquipmentTransferService = preload("res://src/core/equipment/EquipmentTransferService.gd")
const ExpandedQuestRef = preload("res://src/core/campaign/ExpandedQuestProgression.gd")

## The Compendium p.79 step this battle produced or discharged, for the
## orchestrator to emit. Subsystems return data and never emit, and the int
## contract of process_quest_progress() cannot carry a printed instruction —
## which for a tabletop companion IS the deliverable of the chapter.
var last_quest_step: Dictionary = {}

## Remember that a Patron job was completed here, for the p.84 "Reputation
## Required" Condition ("You must have completed a prior Patron job on this
## world"). Keyed by planet id, falling back to the location name for campaigns
## whose battle results predate a planet id.
func _record_patron_job_completed(ctx: PostBattleContextClass) -> void:
	var campaign = ctx.campaign
	if campaign == null or not "progress_data" in campaign:
		return
	var key: String = str(ctx.battle_result.get("planet_id", ""))
	if key.is_empty():
		key = str(ctx.battle_result.get("location", ""))
	if key.is_empty():
		return
	var log: Dictionary = campaign.progress_data.get("patron_jobs_completed_by_world", {})
	log[key] = int(log.get(key, 0)) + 1
	campaign.progress_data["patron_jobs_completed_by_world"] = log

## Bounty Hunters' Intrigue trait (Core Rules p.99). The book states no
## precondition beyond having fought them — no Hold the Field, no win — so the
## check runs on any battle against them.
func _roll_intrigue(ctx: PostBattleContextClass) -> void:
	if not EnemyTraitRules.has_intrigue(str(ctx.battle_result.get("enemy_type", ""))):
		return

	var killed_notable: bool = false
	for enemy in ctx.defeated_enemies:
		if bool(enemy.get("was_unique_individual", enemy.get("is_unique", false))) \
				or bool(enemy.get("was_lieutenant", false)):
			killed_notable = true
			break

	var roll: int = ctx.roll_2d6("Bounty Hunter Intrigue")
	if not EnemyTraitRules.intrigue_succeeds(roll, killed_notable):
		return

	ctx.add_quest_rumor()
	if ctx.campaign_journal and ctx.campaign_journal.has_method("create_entry"):
		ctx.campaign_journal.create_entry({
			"type": "event",
			"title": "Something the bounty hunters knew",
			"description": "Intrigue: rolled %d%s — a Quest Rumor (Core Rules p.99)."
				% [roll, " +1 for a Lieutenant or Unique" if killed_notable else ""],
			"turn": int(ctx.battle_result.get("turn", 0)),
			"tags": ["rumor", "quest"],
		})


## Pay out the p.83-84 Benefits earned by finishing the job. "Benefits are paid
## out ONLY if the mission is a success" (p.83), so this is only reached from the
## success branch of Step 2.
##
## The four payout rows: Fringe Benefit (a Loot Table roll, p.131), Connections
## (a Rumor), Company Store (a Trade Table roll, p.79) and Health Insurance (two
## campaign turns of injury recovery). The other three Benefits are structural —
## Security Team shapes the battle, Persistent and Negotiable shape the Patron
## relationship — and are applied at their own moments, not here.
func _pay_out_benefits(ctx: PostBattleContextClass) -> void:
	var rewards: Array = PatronJobEffects.success_rewards(ctx.battle_result)
	if rewards.is_empty():
		return

	var paid: Array[String] = []
	for reward in rewards:
		match str(reward.get("reward", "")):
			"loot_roll":
				# Routed through the sanctioned stash mutator rather than a second
				# copy of LootProcessor's private helper — one item, one home.
				if ctx.campaign != null:
					var transfer := EquipmentTransferService.new(ctx.campaign)
					for item in LootTableResolver.roll_loot():
						if item is Dictionary:
							transfer.add_loot_to_stash(item)
					paid.append("Fringe Benefit: a roll on the Loot Table")
			"rumor":
				ctx.add_quest_rumor()
				paid.append("Connections: a Rumor")
			"trade_roll":
				# Banked rather than resolved here: the Trade Table's 100 rows,
				# their runtime sub-rolls and the event-queue payout all live in
				# the World Phase pipeline, and that logic must not fork.
				# CrewTaskComponent._resolve_free_trade_rolls() spends it.
				if ctx.campaign and "progress_data" in ctx.campaign:
					var banked: int = int(ctx.campaign.progress_data.get(
						"pending_free_trade_rolls", 0))
					ctx.campaign.progress_data["pending_free_trade_rolls"] = banked + 1
				paid.append("Company Store: a free Trade Table roll next World Phase")
			"injury_recovery":
				var turns: int = int(reward.get("recovery_turns", 2))
				paid.append("Health Insurance: %d turns of injury recovery" % turns)
				_apply_recovery_credit(ctx, turns)

	if paid.is_empty():
		return
	if ctx.campaign_journal and ctx.campaign_journal.has_method("create_entry"):
		ctx.campaign_journal.create_entry({
			"type": "event",
			"title": "Patron benefits paid",
			"description": "The job came with more than the fee — %s (Core Rules p.83)."
				% ", ".join(paid),
			"turn": int(ctx.battle_result.get("turn", 0)),
			"tags": ["patron", "reward"],
		})


## "Health Insurance — Mark down 2 campaign turns of injury recovery, assigned as
## you see fit" (p.84). The book leaves the assignment to the player; spending
## the whole credit on the LONGEST current recovery is the choice that can never
## waste it, so it is applied there rather than inventing a picker the post-battle
## sequence has no concept of. Reported in the journal so the choice is visible.
func _apply_recovery_credit(ctx: PostBattleContextClass, turns: int) -> void:
	# Both the scan and the write go through the context, which owns the canonical
	# Sick Bay shape (injuries[] drives the countdown; recovery_turns /
	# in_sick_bay / status are what the task and upkeep gates read).
	#
	# This used to hand-roll the summary-field write and THEN delegate. Once the
	# context method was fixed to do the whole job, that manual write became a
	# double-subtract on any member whose Sick Bay time had no injuries[] entry.
	var worst: Variant = null
	var worst_turns: int = 0
	for member in ctx.get_crew_members():
		var remaining: int = ctx.get_member_recovery_turns(member)
		if remaining > worst_turns:
			worst_turns = remaining
			worst = member
	if worst == null:
		# Nobody is hurt. The book gives no banking rule, so the benefit simply
		# has nothing to buy — recorded by the caller's journal line either way.
		return
	ctx.reduce_member_recovery(worst, turns)


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
		# "Vendetta system — Opponents become your Rivals on a roll of 1 or 2."
		# (Core Rules p.74 World Trait; the default on p.119 is a 1.) The trait
		# was rolled, stored and displayed and doubled nothing.
		var rival_threshold: int = WorldTraitEffects.rival_conversion_threshold(
			1, ctx.battle_result.get("world_traits", []))
		# "Hot Job — After the job, you will earn an enemy on 1-2 instead of the
		# normal roll of a 1" (Core Rules p.84 Hazards Subtable). Composes onto the
		# world trait rather than replacing it: both widen the same p.119 roll, and
		# taking the wider of the two is the only reading that does not silently
		# cancel one of them.
		rival_threshold = PatronJobEffects.rival_conversion_threshold(
			rival_threshold, ctx.battle_result)
		if new_rival_roll <= rival_threshold:
			var new_rival_id: String = _create_new_rival_from_battle(ctx)
			if new_rival_id != "":
				new_rivals.append(new_rival_id)

	# "Intrigue: Roll 2D6 and add +1 if you killed a Lieutenant and/or Unique
	# Individual. On a 9+, you obtain a Quest Rumor" (Core Rules p.99, Bounty
	# Hunters). Quest Rumors are one of only two ways a Quest ever begins (p.85),
	# so leaving this unwired quietly closed a door into the whole Quest arc —
	# which mattered more once Quests became playable end to end.
	_roll_intrigue(ctx)

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
		# "If you succeeded in a Patron mission, you may add the Patron to your list
		# of contacts on this planet, UNLESS THE JOB WAS A ONE-TIME CONTRACT"
		# (Core Rules p.119 Step 2, naming the p.84 Condition as its exception).
		# The exception was unimplemented: a One-time Contract patron was retained
		# like any other, which is the entire content of that table row.
		var retainable: bool = PatronJobEffects.patron_is_retainable(ctx.battle_result)
		if retainable:
			ctx.add_patron({
				"id": str(patron_id),
				"name": str(ctx.battle_result.get("patron_name", patron_id)),
				"type": str(ctx.battle_result.get("patron_type", "")),
				"source": "completed_job",
				"planet_id": str(ctx.battle_result.get("planet_id", "")),
				# "Persistent — Patron remains available if you travel" (p.84
				# Benefits Subtable), the named exception to p.119 Step 2's "all
				# Patrons become unavailable". NewWorldArrival.is_persistent_patron
				# has read this flag since the arrival steps landed and NOTHING set
				# it — the consumer was live, the producer did not exist, so the
				# Benefit could never spare anyone from the travel purge.
				"is_persistent": PatronJobEffects.patron_persists_on_travel(
					ctx.battle_result),
			})
			patrons_added.append(str(patron_id))
		elif ctx.campaign_journal and ctx.campaign_journal.has_method("create_entry"):
			ctx.campaign_journal.create_entry({
				"type": "event",
				"title": "One-time contract closed",
				"description": "The job is done and the contact ends with it — a "
					+ "One-time Contract patron cannot be retained (Core Rules p.119).",
				"turn": int(ctx.battle_result.get("turn", 0)),
				"tags": ["patron"],
			})

		# "Reputation Required — You must have completed a prior Patron job on this
		# world" (p.84) needs somebody to REMEMBER that you did. Nothing recorded
		# it, so that Condition could never be satisfied by any play — it was a
		# permanent refusal rather than a requirement.
		_record_patron_job_completed(ctx)

		# "Benefits are paid out ONLY if the mission is a success" (p.83) — so
		# this is the moment, and it never happened.
		_pay_out_benefits(ctx)

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
		# "Vengeful — If the mission fails, the Patron becomes a Rival" (Core Rules
		# p.84 Conditions Subtable). Rolled, displayed in the offer summary and in
		# the battle screen's PATRON CONDITIONS block, and applied nowhere: a
		# Vengeful patron shrugged off a failed mission exactly like any other.
		if PatronJobEffects.patron_becomes_rival_on_failure(ctx.battle_result):
			var vengeful_name: String = str(ctx.battle_result.get(
				"patron_name", ctx.battle_result.get("patron", "Vengeful Patron")))
			ctx.add_rival(vengeful_name)
			if ctx.campaign_journal and ctx.campaign_journal.has_method("create_entry"):
				ctx.campaign_journal.create_entry({
					"type": "event",
					"title": "A patron turns on you",
					"description": "%s took the failure personally. Vengeful: they are now a Rival (Core Rules p.84)."
						% vengeful_name,
					"turn": int(ctx.battle_result.get("turn", 0)),
					"tags": ["patron", "rival", "defeat"],
				})

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
	## Step 3: Determine Quest Progress (Core Rules p.120).
	## Returns -1 step does not apply / 0 dead end / 1 step closer (+1 Rumor) /
	## 2 finale unlocked / 3 Quest concluded / 4 a Compendium p.79 step is now the
	## crew's standing obligation. -1 exists so the UI can stay silent instead of
	## reporting "Quest Dead End" after every battle in a campaign that has no
	## Quest at all; 4 exists because the expanded system's normal outcome is
	## neither progress nor a dead end but a task.
	var quest_progress: int = 0
	last_quest_step = {}

	if not ctx.game_state or not ctx.game_state.has_method("has_active_quest") \
			or not ctx.game_state.has_active_quest():
		return -1

	# p.120 opens with a condition this step never checked: "If you just fought a
	# battle THAT WAS PART OF A QUEST, roll a D6." It rolled after every battle a
	# Quest happened to be open for — an Opportunity mission, a Patron job, a
	# forced Rival showdown — so a crew could finish a Quest without ever going
	# on one, collecting Quest Rumors from fights that had nothing to do with it.
	var source: String = str(ctx.battle_result.get("mission_source", ""))
	if source != "quest" and source != "quest_finale":
		return -1

	# The finale IS the last stage: p.120's 7+ result says the next Quest mission
	# "will be the finale", and p.123 pays "+1 XP: Crew completed the final stage
	# of a Quest" for fighting it. So a finale battle ends the Quest instead of
	# rolling for further progress — there is no book branch that continues a
	# Quest past its finale, and no roll here could produce one.
	if bool(ctx.battle_result.get("is_quest_finale", false)):
		var completed: int = 0
		if ctx.game_state.has_method("complete_active_quest"):
			completed = ctx.game_state.complete_active_quest()
		# The Compendium's permanent modifiers are scoped to "all future battles
		# that are part of the Quest" (p.79) — this Quest. A new one must start
		# clean, and a discharged obligation must not outlive the Quest it
		# belonged to.
		ExpandedQuestRef.clear(ctx.campaign)
		var journal: Variant = Engine.get_main_loop().root.get_node_or_null(
			"/root/CampaignJournal") if Engine.get_main_loop() else null
		if journal and journal.has_method("create_entry"):
			journal.create_entry({
				"type": "story",
				"title": "Quest Concluded",
				"description": "The crew fought the final battle of their Quest."
					+ (" Quests completed: %d." % completed if completed > 0 else ""),
				"turn": int(ctx.battle_result.get("turn", 0)),
				"tags": ["quest", "milestone"],
				"auto_generated": true,
				"mood": "triumphant",
			})
		return 3

	var quest_rumors: int = 0
	if ctx.game_state.has_method("get_quest_rumors"):
		quest_rumors = ctx.game_state.get_quest_rumors()
	elif ctx.game_state.has_method("get_quest_rumor_count"):
		quest_rumors = ctx.game_state.get_quest_rumor_count()

	# Compendium p.78: "the system below is used IN PLACE OF the core rulebook
	# system." Branching before the D6 is rolled, not after, because the expanded
	# system does not always roll — a standing obligation suppresses the roll
	# entirely, and a die rolled and discarded would still reach the dice feed
	# and the journal.
	if ExpandedQuestRef.is_enabled():
		return _process_expanded_quest_progress(ctx, quest_rumors)

	var base_roll: int = ctx.roll_d6("Quest progress roll")
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


## Expanded Quest Progression (Compendium pp.78-80) — Post-Battle Step 3.
##
## Differences from the core system above, all of them the book's:
##   * the formula is 1D6 + Quest Rumors, full stop. No -2 for a lost battle —
##     that modifier belongs to the system this replaces.
##   * there is no p.119 travel roll. Same reason: it is part of the core Step 3,
##     and p.78 replaces Step 3 wholesale.
##   * the Expanded Database +1 (Compendium p.28) IS kept. It is a ship component
##     that modifies a Quest progress roll; which table the roll consults is not
##     its business.
##   * the ordinary outcome is neither progress nor a dead end. It is a task,
##     which stands until discharged and suppresses the next roll while it does.
func _process_expanded_quest_progress(ctx: PostBattleContextClass, quest_rumors: int) -> int:
	# A battle fought FOR the pending step discharges it first — by the time
	# Step 3 asks, the obligation the battle was taken on is settled.
	var discharge: Dictionary = ExpandedQuestRef.record_battle(ctx.campaign, ctx.battle_result)
	if not str(discharge.get("message", "")).is_empty():
		last_quest_step = discharge
	if bool(discharge.get("rumor_awarded", false)):
		ctx.add_quest_rumor()
		quest_rumors += 1
		_journal_quest_step("Quest step complete", str(discharge.get("message", "")), ctx)

	# Still owing something: no roll, and the UI says what is still owed rather
	# than reporting a dead end the book never rolled for.
	if ExpandedQuestRef.blocks_progress(ctx.campaign):
		var pending: Dictionary = ExpandedQuestRef.get_pending_step(ctx.campaign)
		last_quest_step = {
			"step_id": str(pending.get("id", "")),
			"message": str(pending.get("instruction", "")),
			"pending": true,
		}
		return 4

	var db_bonus: int = 0
	if ShipComponentQuery.has_component("expanded_database"):
		db_bonus = 1

	var d6: int = ctx.roll_d6("Quest progress (Compendium p.78)")
	# Only roll the progression table when the gate did not clear the Conclusion.
	# Reads the engine's threshold rather than repeating the 7.
	var d100: int = -1
	if d6 + maxi(0, quest_rumors) + db_bonus < ExpandedQuestRef.CONCLUSION_THRESHOLD:
		d100 = ctx.roll_d100("Quest Progression table (Compendium p.79)")

	# Two rows need one more D6 the moment they land — the 1D6 price of the
	# information (01-10) and the +1D6 on the first research tranche (11-20).
	# Rolled through ctx so it reaches the dice feed with its own label, and only
	# when the row that needs it actually came up: a die in the feed that changed
	# nothing is worse than no die at all for a player following along on paper.
	var aux_d6: int = -1
	if d100 > 0:
		match str(ExpandedQuestRef.step_for_roll(d100).get("completion", "")):
			"pay_credits":
				aux_d6 = ctx.roll_d6("Cost of the information (Compendium p.79)")
			"research_points":
				aux_d6 = ctx.roll_d6("Research points (Compendium p.79)")

	var outcome: Dictionary = ExpandedQuestRef.roll_progress(
		ctx.campaign, quest_rumors, _crew_savvy_total(ctx),
		int(ctx.battle_result.get("turn", 0)), db_bonus, d6, d100, aux_d6, aux_d6)

	if bool(outcome.get("conclusion", false)):
		if ctx.game_state.has_method("set_quest_finale_available"):
			ctx.game_state.set_quest_finale_available(true)
		last_quest_step = {"step_id": "conclusion",
			"message": str(outcome.get("message", "")), "pending": false}
		_journal_quest_step("Quest Conclusion unlocked", str(outcome.get("message", "")), ctx)
		return 2

	var step: Dictionary = outcome.get("step", {})
	if step.is_empty():
		return 0

	last_quest_step = {
		"step_id": str(step.get("id", "")),
		"message": str(step.get("instruction", "")),
		"pending": bool(step.get("blocks_progress", false)),
	}
	_journal_quest_step("Quest: next step", str(step.get("instruction", "")), ctx)

	if bool(outcome.get("rumor_awarded", false)):
		ctx.add_quest_rumor()
		return 1
	return 4


## Combined Savvy of the crew, for the p.79 Analyze Data row ("research points
## equal to the combined Savvy scores of your crew members, +1D6"). Handles both
## live shapes — a loaded campaign holds crew Dictionaries, a freshly created one
## can still hold Character Resources.
func _crew_savvy_total(ctx: PostBattleContextClass) -> int:
	var total: int = 0
	for member: Variant in ctx.get_crew_members():
		if member is Dictionary:
			total += int(member.get("savvy", 0))
		elif member != null and "savvy" in member:
			total += int(member.savvy)
	return total


func _journal_quest_step(title: String, body: String, ctx: PostBattleContextClass) -> void:
	if body.is_empty():
		return
	var journal: Variant = Engine.get_main_loop().root.get_node_or_null(
		"/root/CampaignJournal") if Engine.get_main_loop() else null
	if not journal or not journal.has_method("create_entry"):
		return
	journal.create_entry({
		"type": "story",
		"title": title,
		"description": body,
		"tags": ["quest", "compendium", "expanded_quests"],
		"auto_generated": true,
		"mood": "neutral",
	})

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
	# "Persistent: If encountered as Rivals, all rolls to remove them from Rival
	# status are at -1" (Core Rules p.99, Vigilantes). The removal roll succeeds
	# on a 4+, so this is the difference between 50% and 33% — the one enemy the
	# book designs to be a long-term nuisance was as easy to shake as any other.
	modifiers += EnemyTraitRules.rival_removal_modifier(
		str(ctx.battle_result.get("enemy_type", "")))
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
