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
	# 5) context passthrough (faction_id / faction_job_id / rival_id / is_invasion).
	for key in ["faction_id", "faction_job_id", "rival_id", "is_invasion"]:
		if not results.has(key) and mission.has(key):
			results[key] = mission[key]
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
