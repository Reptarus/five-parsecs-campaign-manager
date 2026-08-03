extends RefCounted
## SSOT adapter: producer battle-result vocabulary -> post-battle consumer keys.
## ADD-ONLY + IDEMPOTENT: fills missing keys, never overwrites existing ones.
## Producers (pinned by tests, do NOT rename their keys):
##   TacticalBattleUI.gd (_resolve_battle / auto_result_dict), BattleResultsInputForm.gd (_on_submit)
## Consumers: PostBattlePhase.gd + src/core/campaign/phases/post_battle/*.
##
## Called from CampaignTurnController BEFORE game_state.set_battle_results() on
## EVERY battle path (played, LOG_ONLY manual record, in-battle auto-resolve,
## campaign-map auto-resolve). No `class_name` — the global class cache is stale
## until the editor reopens (project gotcha); preload by path.

static func normalize(results: Dictionary, mission: Dictionary, current_turn: int) -> Dictionary:
	# 1) "turn" — read by PostBattlePhase.gd (journal/entry stamps),
	#    PostBattleCompletion.gd, RivalPatronResolver.gd, CharacterEventEffects.gd.
	#    No producer writes it, so every auto-journal entry was stamped turn 0.
	if not results.has("turn"):
		results["turn"] = current_turn
	# 2) mission_source (PaymentProcessor patron logic). Producers set it from
	#    mission_data, but LOG_ONLY / legacy paths may not.
	if not results.has("mission_source") and not mission.is_empty():
		results["mission_source"] = str(mission.get("mission_source", mission.get("source", "opportunity")))
	# 3) danger_pay (PaymentProcessor Get Paid, Core Rules p.120) — from the
	#    accepted job. Dropped on the main tactical path before this normalizer.
	if not results.has("danger_pay"):
		var dp: Variant = mission.get("danger_pay", null)
		if dp is int or dp is float:
			results["danger_pay"] = int(dp)
	# 4) patron_id (RivalPatronResolver) — ONLY for patron jobs.
	if not results.has("patron_id") and str(results.get("mission_source", "")) == "patron":
		var pid: String = str(mission.get("patron_id", ""))
		if pid != "":
			results["patron_id"] = pid
			# Their display identity travels with the id so Step 2 can record the
			# Patron AS THEMSELVES rather than as a freshly invented contact.
			# The mission stores the name under "patron" (WorldPhaseController's
			# mission_dict), so it is renamed here rather than passed through.
			if not results.has("patron_name"):
				results["patron_name"] = str(mission.get("patron",
					mission.get("patron_name", pid)))
			if not results.has("patron_type"):
				results["patron_type"] = str(mission.get("patron_type", ""))
	# 5) context passthrough (faction_id / faction_job_id / rival_id / is_invasion,
	#    plus setup_rules and rival_attack_type). setup_rules is the scenario
	#    modifier bundle BattleSetupRules computed before deployment; the
	#    post-battle side reads its loss_penalties to charge the Rival Assault
	#    1D3 credits and the Rival Raid 1D6+1 Hull damage (Core Rules p.92). No
	#    producer carries either key, so without this passthrough both penalties
	#    would stay as unreachable as the attack type itself was.
	#
	# The invasion / zone / place keys were added 2026-08-01 after a funnel audit:
	# every one of them is READ by a post-battle consumer and NO producer wrote
	# any of them, so each gate they guard was unreachable.
	#   is_invasion               -> p.120 "you receive no payment", p.120 "cannot
	#                                roll on this table", p.121 "you receive no
	#                                Loot", and the p.119 Rival-status skip
	#   enemy_is_invasion_threat  -> p.121 Step 6, the Invasion check itself
	#   invasion_threat_modifier  -> p.101 "Invasion Threat. Test at +1."
	#   enemy_category            -> p.101 Roving Threats "never become Rivals"
	#   planet_id / location      -> p.119 a new Rival is noted "for this planet";
	#                                the journal joins battle entries by location
	# The story / intro keys were added 2026-08-01 for the same reason, one layer
	# out. PostBattleCompletion.gd:176-180 has read `is_story_battle` and
	# `story_event_id` off battle_result since the PostBattlePhase decomposition,
	# and no producer ever wrote them — the branch was permanently false. Now
	# CampaignTurnController._stamp_narrative_battle_config() writes them onto
	# mission_data, so they must cross this chokepoint or they die here instead.
	#   is_story_battle / story_event_id / story_event_number
	#                             -> p.153 Story Event battle identity + journal
	#   mercenary_captured        -> p.154 Event 2, sets up Event 3's Seize bonus
	#   captive_survived          -> p.159 Event 6, gates Event 7's companion roll
	#   is_intro_battle / is_training_battle
	#                             -> Compendium p.105, the no-consequences turn 0
	# `enemy_type` added 2026-08-01, same shape as the rest of this list: THREE
	# consumers read it off battle_result and no producer ever wrote it there.
	# The worst was RivalPatronResolver._create_new_rival_from_battle(), which
	# builds the new Rival's id, name and type from it — so every Rival a crew
	# ever gained was named "Unknown Vendetta". WorldPhaseController has always
	# put the real enemy on mission_dict; it simply never crossed this chokepoint.
	for key in ["faction_id", "faction_job_id", "rival_id", "is_invasion",
			"setup_rules", "rival_attack_type", "enemy_type",
			"enemy_is_invasion_threat", "invasion_threat_modifier",
			"enemy_category", "planet_id", "location",
			"is_red_zone", "is_black_zone",
			"is_story_battle", "story_event_id", "story_event_number",
			"mercenary_captured", "captive_survived", "story_evidence_found",
			"is_intro_battle", "is_training_battle",
			# is_quest_finale / quest_id added 2026-08-02. FOUR consumers read
			# is_quest_finale off battle_result — PaymentProcessor (p.120 "roll
			# the die twice, pick the better score, and add +1"), LootProcessor
			# (p.121 "roll three times and claim all the items"),
			# ExperienceTrainingProcessor (p.123 "+1 XP") and the +1-enemy rule at
			# setup — and it had no producer anywhere in the repo. The three
			# TacticalBattleUI hoists read it off mission_data, so the played path
			# now carries it; this passthrough covers LOG_ONLY and both
			# auto-resolves. quest_id lets the post-battle step close out THAT
			# Quest rather than whatever is active when the dust settles.
			"is_quest_finale", "quest_id"]:
		if not results.has(key) and mission.has(key):
			results[key] = mission[key]
	# 5b) is_invasion is DERIVED, not merely copied. The only marker an Invasion
	#     battle reliably carries is mission_source, and BattleSetupRules already
	#     treats the two as equivalent at setup time (is_invasion()). Deriving it
	#     here keeps the setup side and the post-battle side reading the same
	#     scenario, on every path including LOG_ONLY and the map auto-resolve.
	if not results.has("is_invasion"):
		results["is_invasion"] = str(
			results.get("mission_source", mission.get("mission_source", ""))
		).to_lower() == "invasion"
	# 6) is_rival_mission (PaymentProcessor rival-payment branch).
	if not results.has("is_rival_mission"):
		results["is_rival_mission"] = str(results.get("mission_source", "")) == "rival" \
			or str(results.get("rival_id", "")) != ""
	# 7) injuries_sustained <- crew_injuries_data (PostBattlePhase -> InjuryProcessor;
	#    element contract crew_id/name/origin/species_id).
	if not results.has("injuries_sustained"):
		var injuries: Array = []
		for character in results.get("crew_injuries_data", []):
			injuries.append(_to_crew_entry(character))
		results["injuries_sustained"] = injuries
	# 8) casualties <- crew_casualties_data, SHAPE transform (bitter-day + XP paths
	#    want type in ["killed","fatal"] with crew_id).
	if not results.has("casualties"):
		var casualties: Array = []
		for character in results.get("crew_casualties_data", []):
			var entry: Dictionary = _to_crew_entry(character)
			entry["type"] = "killed"
			casualties.append(entry)
		results["casualties"] = casualties
	# 8b) units_downed <- the crew who went Out of Action, which is exactly the
	#    union of the two arrays above. NO PRODUCER EVER WROTE THIS KEY, and two
	#    real mechanics read it:
	#      - Core Rules p.21 Hopeful Rookie: +1 XP if they were NOT downed
	#        (ExperienceTrainingProcessor) — so every Hopeful Rookie silently
	#        collected the bonus, downed or not.
	#      - battles_survived (PostBattleCompletion) — incremented for everyone,
	#        so the counter actually meant "battles participated".
	#    Derived here rather than asked of the player: going Out of Action is
	#    already recorded on both paths, so there is nothing new to observe.
	if not results.has("units_downed"):
		var downed: Array = []
		for entry in results.get("injuries_sustained", []):
			var cid: String = str((entry as Dictionary).get("crew_id", "")) \
				if entry is Dictionary else ""
			if cid != "" and cid not in downed:
				downed.append(cid)
		for entry in results.get("casualties", []):
			var cid2: String = str((entry as Dictionary).get("crew_id", "")) \
				if entry is Dictionary else ""
			if cid2 != "" and cid2 not in downed:
				downed.append(cid2)
		results["units_downed"] = downed
	# 9) rival stamp on defeated enemies (RivalPatronResolver reads is_rival/rival_id
	#    per element; produced elements only carry name/type/was_lieutenant).
	var rid: String = str(results.get("rival_id", ""))
	if rid != "":
		for enemy in results.get("defeated_enemies", []):
			if enemy is Dictionary and not enemy.has("is_rival"):
				enemy["is_rival"] = true
				enemy["rival_id"] = rid
	return results

static func casualty_count(results: Dictionary) -> int:
	## Casualty COUNT, tolerant of both shapes. EVERY numeric read of
	## `casualties` must route through this.
	##
	## normalize() step 8 guarantees `casualties` is an Array of dicts on every
	## 5PFH path, but consumers were written against an int and Bug Hunt /
	## Planetfall / legacy saves can still carry one. An Array reaching `int()`,
	## `%d`, a comparison, or a typed-int assignment is a RUNTIME ERROR that
	## aborts the enclosing function — verified against 4.6, all five of:
	##   Invalid operands 'Array' and 'int' in operator '=='  /  '>'
	##   Trying to assign value of type 'Array' to a variable of type 'int'
	##   Invalid call. Nonexistent 'int' constructor
	##   a number is required in operator '%'
	## Those aborts shipped: battle journal entries had no description and no
	## mood, the post-battle narrative screen never opened, and the summary
	## sheet stopped updating at the casualty label. Nothing errored visibly
	## because an abort unwinds only the callee.
	var raw: Variant = results.get("casualties", 0)
	if raw is Array:
		return (raw as Array).size()
	if raw is int or raw is float:
		return int(raw)
	return 0

static func _to_crew_entry(character: Variant) -> Dictionary:
	## Character dict/Resource -> fields post-battle consumers read. Mirrors the
	## PostBattleContext access patterns (get_char_name / get_character_origin).
	var entry: Dictionary = {"crew_id": "", "name": "", "origin": "", "species_id": ""}
	if character is Dictionary:
		entry["crew_id"] = str(character.get("character_id", character.get("id", "")))
		entry["name"] = str(character.get("character_name", character.get("name", "")))
		entry["origin"] = str(character.get("origin", character.get("species", "")))
		entry["species_id"] = str(character.get("species_id", ""))
	elif character != null:
		if "character_id" in character:
			entry["crew_id"] = str(character.character_id)
		if "character_name" in character:
			entry["name"] = str(character.character_name)
		if "origin" in character:
			entry["origin"] = str(character.origin)
		if "species_id" in character:
			entry["species_id"] = str(character.species_id)
	return entry
