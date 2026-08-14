class_name PostBattleInjuryProcessor
extends RefCounted

## Injury resolution for Post-Battle Phase.
## Handles Step 8: Determine Injuries and Recovery (Core Rules p.94-95)
## Extracted from PostBattlePhase.gd — orchestrator delegates here.

const PostBattleContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const InjuryConstants = preload("res://src/core/systems/InjurySystemConstants.gd")
const CompendiumTogglesRef = preload("res://src/data/compendium_difficulty_toggles.gd")
const OnboardItemServiceRef = preload("res://src/core/equipment/OnboardItemService.gd")

## Core Rules p.125 Advanced Training rerolls, resolved once per battle in
## process_injuries() and read by the roll sites below. Both courses were pure
## theatre before this: 20 XP for Medical school and 10 XP for Bot technician
## bought a line of text and no mechanical effect whatsoever.
var _medical_nominee_id: String = ""
var _bot_technician_active: bool = false

func process_injuries(ctx: PostBattleContextClass) -> Array[Dictionary]:
	## Process all injuries from battle. Returns array of processed injury dicts.
	var processed_injuries: Array[Dictionary] = []

	## Compendium p.34 Reduced Lethality, verbatim: "Before rolling for
	## post-battle injuries, If you have two or more injured characters you may
	## select one to be exempt from rolling. They simply have a complete recovery
	## with no Sick Bay time required. This option can be used for either a
	## biological character or a Soulless or Bot at your discretion. If only one
	## character is injured, you must suffer the result as normal."
	##
	## The choice is the PLAYER'S and it is made BEFORE the rolls, so this reads
	## an id the UI wrote beforehand rather than picking one itself. Offering the
	## exemption after the rolls were visible would make the option strictly
	## stronger than the book's — you would be voiding a known-bad result instead
	## of guessing. With no id supplied nothing is exempted; no default is
	## invented.
	var exempt_id: String = ""
	if CompendiumTogglesRef.is_toggle_active("reduced_lethality") \
			and ctx.injuries_sustained.size() >= 2:
		exempt_id = str(ctx.battle_result.get("reduced_lethality_exempt_crew_id", ""))

	_resolve_training_rerolls(ctx, exempt_id)

	for injury_data in ctx.injuries_sustained:
		var this_crew_id: String = str(injury_data.get("crew_id", ""))
		if not exempt_id.is_empty() and this_crew_id == exempt_id:
			# "They simply have a complete recovery with no Sick Bay time
			# required" — no roll is made at all, so there is no injury type.
			processed_injuries.append({
				"crew_id": this_crew_id,
				"type": "none",
				"name": "Complete Recovery",
				"description": "Exempted from the injury roll (Reduced Lethality,"
					+ " Compendium p.34). Full recovery, no Sick Bay time.",
				"recovery_turns": 0,
				"is_fatal": false,
				"reduced_lethality_exempt": true,
			})
			exempt_id = ""  # "select ONE to be exempt" — one figure, once.
			continue
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
		var turn_num: int = int(ctx.battle_result.get("turn", 0))
		for inj in processed_injuries:
			var crew_id: String = inj.get("crew_id", "")
			if crew_id.is_empty():
				continue
			ctx.campaign_journal.auto_create_character_event(crew_id, "injury", {
				"turn": turn_num,
				"description": "Sustained %s injury. Recovery: %d turns." % [inj.get("type", "unknown"), inj.get("recovery_turns", 0)],
			})

	return processed_injuries

## ── Core Rules p.125 Advanced Training rerolls ────────────────────────────────

func _resolve_training_rerolls(ctx: PostBattleContextClass, exempt_id: String) -> void:
	## Medical school (20 XP), verbatim: "After each battle, you may nominate a
	## casualty that will roll twice on the Injury Table, picking the better
	## result. This crew member must have been in the battle and must not have
	## become a casualty. If your ship has a Shuttle, you can evac fast enough
	## that this crew member can apply their skill even if they did not
	## participate in the battle."
	##
	## "This crew member" is the MEDIC, not the nominee — the Shuttle sentence
	## only parses that way ("apply their skill"), and a casualty has by
	## definition participated.
	##
	## Bot technician (10 XP), verbatim: "If a Bot or Soulless character must
	## roll for a post-battle injury, you may roll twice, picking the better
	## result." No participation clause and no per-battle limit, so unlike
	## Medical school it is not restricted to one figure.
	_medical_nominee_id = ""
	_bot_technician_active = false
	if ctx == null:
		return

	_bot_technician_active = _crew_has_training(ctx, "bot_technician")

	if not _medic_is_eligible(ctx):
		return

	# The nomination is made BEFORE the rolls (BattleResultsInputForm asks on the
	# played path, same moment and same reason as the Reduced Lethality exemption
	# above). On auto-resolve there is no player moment, so the first eligible
	# casualty is nominated rather than silently withholding a benefit the player
	# spent 20 XP on. Bots are skipped: they roll on the Bot Injury Table, and
	# Medical school names "the Injury Table".
	var nominated: String = str(ctx.battle_result.get("medical_school_nominee_crew_id", ""))
	for injury_data in ctx.injuries_sustained:
		var cid: String = str(injury_data.get("crew_id", ""))
		if cid.is_empty() or cid == exempt_id:
			continue
		if ctx.is_character_bot_or_soulless(cid):
			continue
		if nominated.is_empty():
			_medical_nominee_id = cid
			return
		if cid == nominated:
			_medical_nominee_id = cid
			return

func _medic_is_eligible(ctx: PostBattleContextClass) -> bool:
	## The medic must have been in the battle and not be a casualty themselves —
	## unless the ship has a Shuttle, which waives the participation half.
	var casualties: Dictionary = {}
	for injury_data in ctx.injuries_sustained:
		casualties[str(injury_data.get("crew_id", ""))] = true

	var has_shuttle: bool = _ship_has_shuttle(ctx)
	for member in ctx.get_crew_members():
		if member == null:
			continue
		if not _member_has_training(member, "medical"):
			continue
		var cid: String = _member_id(member)
		if casualties.has(cid):
			continue  # became a casualty — cannot apply their skill
		if has_shuttle or cid in ctx.crew_participants:
			return true
	return false

func _ship_has_shuttle(ctx: PostBattleContextClass) -> bool:
	var campaign = ctx.campaign
	if campaign == null or not ("ship_data" in campaign):
		return false
	var ship: Variant = campaign.ship_data
	if not (ship is Dictionary):
		return false
	for component in (ship as Dictionary).get("components", []):
		var nm: String = str(component.get("name", component) if component is Dictionary
			else component).to_lower()
		if nm.contains("shuttle"):
			return true
	return false

func _crew_has_training(ctx: PostBattleContextClass, course_id: String) -> bool:
	for member in ctx.get_crew_members():
		if member != null and _member_has_training(member, course_id):
			return true
	return false

func _member_has_training(member: Variant, course_id: String) -> bool:
	## Dictionary branch FIRST — has_method() on a Dictionary is an invalid call
	## that unwinds the caller (the trap documented at process_single_injury).
	if member is Dictionary:
		var list: Array = (member as Dictionary).get("acquired_training", [])
		if list.is_empty():
			list = (member as Dictionary).get("training", [])
		return course_id in list or _legacy_training_hit(course_id, list)
	if member.has_method("has_training"):
		return member.has_training(course_id)
	if "acquired_training" in member:
		return course_id in member.acquired_training \
			or _legacy_training_hit(course_id, member.acquired_training)
	return false

func _legacy_training_hit(course_id: String, list: Array) -> bool:
	## Mirrors Character._TRAINING_ID_ALIASES for crew held as plain dicts.
	return course_id == "bot_technician" and "bot_tech" in list

func _member_id(member: Variant) -> String:
	if member is Dictionary:
		return str((member as Dictionary).get("character_id",
			(member as Dictionary).get("id", "")))
	if "character_id" in member:
		return str(member.character_id)
	return ""

func _better_roll(roll_a: int, roll_b: int, is_bot_table: bool) -> int:
	## "Picking the better result" (p.125) resolved mechanically. Nothing here is
	## invented: every term is a consequence the book itself attaches to the row,
	## compared in the order a player would. Lower rank wins; a TIE keeps the
	## FIRST roll, so a reroll can never make an outcome worse.
	var rank_a: Array = _bot_severity_rank(roll_a) if is_bot_table \
		else _severity_rank(roll_a)
	var rank_b: Array = _bot_severity_rank(roll_b) if is_bot_table \
		else _severity_rank(roll_b)
	for i in rank_a.size():
		if rank_a[i] != rank_b[i]:
			return roll_a if rank_a[i] < rank_b[i] else roll_b
	return roll_a

func _severity_rank(roll: int) -> Array:
	var injury_type = InjuryConstants.get_injury_type_from_roll(roll)
	var props: Dictionary = InjuryConstants.INJURY_PROPERTIES.get(injury_type, {})
	var recovery: Dictionary = InjuryConstants.get_recovery_time(injury_type)
	var stat_loss: Dictionary = props.get("stat_reduction", {})
	return [
		1 if props.get("is_fatal", false) else 0,          # death first
		0 if stat_loss.is_empty() else 1,                  # permanent stat loss
		1 if props.get("equipment_permanently_lost", false) else 0,
		1 if props.get("equipment_lost", false) else 0,
		# Upper bound, not a fresh dice roll — the comparison must be
		# deterministic or the same pair of rolls could rank differently twice.
		int(recovery.get("max", 0)),
		-int(props.get("luck_bonus", 0)),                  # p.122 roll 16 upside
		-int(props.get("bonus_xp", 0)),
	]

func _bot_severity_rank(roll: int) -> Array:
	var bot_type = InjuryConstants.get_bot_injury_type_from_roll(roll)
	var props: Dictionary = InjuryConstants.BOT_INJURY_PROPERTIES.get(bot_type, {})
	var recovery: Dictionary = InjuryConstants.get_bot_recovery_time(bot_type)
	return [
		1 if props.get("is_fatal", false) else 0,
		1 if props.get("all_equipment", false) else 0,
		1 if props.get("equipment_lost", false) else 0,
		int(recovery.get("max", 0)),
	]

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

	# On-board item, Nano-doc (Core Rules p.58): "Prevent one roll on the
	# post-battle Injury Table, NO MATTER THE SOURCE of the injury. You must
	# decide before rolling the dice. Single-use."
	#
	# Placed here, above the bot routing and above BOTH injury tables, because
	# "no matter the source" is the whole point of the item — gating it inside
	# the organic branch would silently exclude Bots and Soulless, and gating it
	# after the detailed-injuries opt-in would make it depend on a DLC toggle.
	# One site, all paths: this is the recurring "guard applied to N-1 of N
	# sites" trap and the reason this sits where Feel Great sits.
	#
	# The player arms it from the On-board Items dialog, which is what satisfies
	# "you must decide before rolling the dice" — consuming it here on demand
	# would be deciding after seeing who got hurt.
	if OnboardItemServiceRef.consume_armed_nano_doc(ctx.campaign):
		return {
			"crew_id": crew_id,
			"type": "ignored",
			"description": "Injury roll prevented (Nano-doc, p.58)",
			"recovery_turns": 0,
			"is_fatal": false
		}

	var is_bot_character := false
	var crew_origin: String = injury_data.get("origin", "")
	if crew_origin.is_empty():
		var crew_member = ctx.get_crew_member(crew_id)
		if crew_member != null:
			# DICTIONARY BRANCH FIRST. Dictionary has no has_method(), so calling it
			# on one is an INVALID CALL, which aborts the whole enclosing function —
			# process_single_injury returned {} and NOTHING downstream ran: no
			# apply_crew_injury, no Sick Bay, no death. Crew members are canonically
			# Dictionaries (the data-ownership table), so this aborted on EVERY
			# post-battle injury in every campaign, not just auto-resolved ones. The
			# post-battle wizard still printed the rolled injury from the count, so it
			# looked like it was working.
			#
			# Same trap PostBattleContext.get_crew_members() already documents at :130.
			if crew_member is Dictionary:
				var d: Dictionary = crew_member
				if bool(d.get("is_bot", false)):
					is_bot_character = true
				else:
					crew_origin = str(d.get("origin", d.get("species_id", "")))
			elif crew_member is Object:
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

	# Compendium p.101 Detailed Post-Battle Injuries: this table "can be used in
	# place of the one in the core rules". Synthetic characters "continue using
	# the core rules Bot Injury table (core rules, p.122)" — already routed above,
	# so reaching here means the character is organic and eligible.
	#
	# roll_detailed_injury() returns {} unless the DETAILED_INJURIES flag is on,
	# so this is the whole opt-in check; no second gate needed.
	var detailed_row: Dictionary = CompendiumTogglesRef.roll_detailed_injury()
	if not detailed_row.is_empty():
		return _process_detailed_injury(ctx, detailed_row, crew_id)

	var injury_roll := randi_range(1, 100)
	# Medical school (p.125): the nominated casualty "will roll twice on the
	# Injury Table, picking the better result".
	var reroll_note: String = ""
	if not _medical_nominee_id.is_empty() and crew_id == _medical_nominee_id:
		var second_roll: int = randi_range(1, 100)
		var kept: int = _better_roll(injury_roll, second_roll, false)
		reroll_note = "Medical school (p.125): rolled %d and %d, kept %d." % [
			injury_roll, second_roll, kept]
		injury_roll = kept
		# One nominee per battle: "you may nominate A casualty".
		_medical_nominee_id = ""
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
		# The wizard prints injury.get("crew_name", "Unknown") and NOTHING has
		# ever written the key, so every post-battle injury line in every
		# campaign read "Unknown: MINOR_INJURY". The backend is the only layer
		# that already holds the member, so it is the right place to resolve it.
		"crew_name": _crew_name(ctx, crew_id),
		"type": injury_type_name,
		"severity": injury_type,
		"recovery_turns": recovery_time,
		"turn_sustained": int(ctx.battle_result.get("turn", 0)),
		"description": injury_description,
		"is_fatal": is_fatal,
		"equipment_lost": equipment_lost,
		"bonus_xp": bonus_xp,
		# Empty unless a p.125 course actually changed this roll. The wizard shows
		# it so a 20-XP purchase is visibly doing something.
		"training_reroll": reroll_note,
	}

	# Core Rules p.122 equipment consequences. `equipment_lost` and
	# `all_equipment` have been COMPUTED here and stored in this dict since the
	# file was written, and no consumer anywhere ever acted on either — so three
	# rows of the organic Injury Table (1-5 Gruesome fate, 16 Miraculous escape,
	# 17-30 Equipment loss = 20 of 100 results) left every item pristine.
	#
	# The knock-on is bigger than the rows: p.122's opening line is "If a result
	# on these tables indicates damaged equipment, such equipment cannot be used
	# until it has been Repaired (see p.78)", and Repair Your Kit is one of only
	# six crew tasks. With no producer, the single most common source of damaged
	# gear in the book never fired, so the repair task had nothing to repair in
	# any campaign outside the rare Character-Event item damage.
	#
	# Applied BEFORE the fatal branch: 1-5 is "Dead, AND all carried equipment is
	# damaged", so the gear clause must land whether or not the Luck death-save
	# below rescues the character.
	_apply_equipment_consequences(ctx, processed_injury, injury_type, crew_id)

	# Fatal injuries: return early. The "Dramatic Escape" mechanic previously
	# wired here was fabricated (NOT in Core Rules p.67) and has been removed.
	# Per the book, the only post-battle injury star is "Looked worse than it was!"
	# which is offered to the player via PostBattleSequence nudge UI for any
	# non-fatal injury (flagged via star_offer_available in process_injuries()).
	if is_fatal:
		# Core Rules p.121, BEFORE the death is applied: "If a character with Luck
		# would be slain through a roll on this table, they miraculously survive, but
		# immediately lose ALL Luck points."
		#
		# This was never implemented on the live path — a crew member holding Luck was
		# killed outright by a 1-15 roll, i.e. permanent character loss the book
		# explicitly prevents. (An older, non-live processor did implement it:
		# PostBattleProcessor.gd:186-202, reachable only from a comment + one test.)
		#
		# Organic table only. The Luck clause sits in the prose that introduces BOTH
		# tables and says "a roll on this table", so its application to the Bot Injury
		# Table is genuinely ambiguous; this matches the existing in-repo reading
		# (PostBattleProcessor.gd:189 gates on `not is_bot`) rather than inventing one.
		# _process_bot_injury handles the Bot table and does not call this branch.
		if ctx.apply_luck_death_save(crew_id):
			processed_injury["is_fatal"] = false
			processed_injury["luck_death_save"] = true
			processed_injury["recovery_turns"] = 0
			processed_injury["description"] = (
				"Miraculously survived %s — lost ALL Luck (Core Rules p.121)"
				% injury_type_name.to_lower())
			return processed_injury

		# MARK THEM DEAD. This used to just return, and nothing else wrote a death
		# either — `status == "DEAD"` was READ (PostBattleCompletion.gd:205) and never
		# WRITTEN, while PostBattleSequence only appended "(FATAL)" to a UI label.
		# So a crew member killed by the injury table stayed fully active: deployable,
		# task-eligible, counted for upkeep, and journalled as "survived".
		ctx.apply_crew_death(crew_id)
		return processed_injury

	# Core Rules p.122, Injury Table 96-100 "School of hard knocks — Earn 1 XP".
	# bonus_xp was computed here, stored in the result dict, and read by NOTHING
	# on the 5PFH path (only Planetfall's panel consumes it), so the book's
	# consolation prize for being downed was silently withheld every time.
	if bonus_xp > 0:
		ctx.add_character_xp(ctx.get_crew_member(crew_id), bonus_xp)

	# Core Rules p.122, Injury Table 16 "Miraculous escape — The character
	# survives and receives +1 Luck, but all items carried are permanently lost."
	# data/injury_results.json carries luck_bonus: 1 for this row and nothing ever
	# read it, so the single best non-fatal outcome in the game did literally
	# nothing: no Luck, and every item kept.
	var luck_bonus: int = InjuryConstants.get_luck_bonus(injury_type)
	if luck_bonus > 0:
		ctx.apply_luck_increase(ctx.get_crew_member(crew_id), luck_bonus)
		processed_injury["luck_bonus"] = luck_bonus

	# Core Rules p.122, Injury Table 31-45 Crippling wound: "Require 1D6 credits
	# of surgery immediately, or suffer -1 permanent reduction to highest of
	# Speed or Toughness."
	#
	# data/injury_results.json has carried surgery_cost_roll AND the full
	# stat_reduction block ({stats: [speed, toughness], pick: highest, amount:
	# -1}) since it was written, and NOTHING read either — so the worst
	# survivable result on the table was mechanically identical to a Serious
	# injury one row below it (both "no long-term effect", both a few turns in
	# Sick Bay). 15% of every injury roll.
	_apply_crippling_wound(ctx, processed_injury, injury_type, crew_id)

	# Apply injury to crew member
	ctx.apply_crew_injury(crew_id, processed_injury)

	return processed_injury


## Roll the "Campaign turns in Sick Bay" column of the Compendium p.102 table.
## Rows carry either a flat `sick_bay` int or a `sick_bay_roll` string in NdM+K
## form ("1D6+3", "1D3", "1D3+1", "1D6+1"). The two negative `sick_bay` values are
## sentinels from the data file: -1 = "NA" (the Death row), -2 = "Identical to
## medical cost" (Extensive injury), both handled by their own branches below.
func _roll_sick_bay(row: Dictionary) -> int:
	var spec: String = str(row.get("sick_bay_roll", "")).strip_edges().to_upper()
	if spec.is_empty():
		return maxi(int(row.get("sick_bay", 0)), 0)
	var bonus: int = 0
	var plus: int = spec.find("+")
	if plus != -1:
		bonus = int(spec.substr(plus + 1))
		spec = spec.substr(0, plus)
	var parts: PackedStringArray = spec.split("D")
	if parts.size() != 2:
		return bonus
	var count: int = maxi(int(parts[0]), 1)
	var sides: int = maxi(int(parts[1]), 1)
	var total: int = bonus
	for _i in range(count):
		total += randi_range(1, sides)
	return maxi(total, 0)


## Compendium p.102 Detailed Post-Battle Injuries — the D100 table used "in place
## of the one in the core rules" when the DETAILED_INJURIES option is on.
##
## Returns the same processed-injury contract as the Core Rules path so every
## downstream consumer (the post-battle wizard, the journal, Sick Bay) is
## unchanged. Bots never reach here; p.101 keeps them on the core Bot Injury
## table and process_single_injury routes them out first.
func _process_detailed_injury(ctx: PostBattleContextClass, row: Dictionary,
		crew_id: String) -> Dictionary:
	var row_id: String = str(row.get("id", ""))
	var recovery: int = _roll_sick_bay(row)

	var processed: Dictionary = {
		"crew_id": crew_id,
		"crew_name": _crew_name(ctx, crew_id),
		"type": row_id.to_upper(),
		"severity": 1,
		"recovery_turns": recovery,
		"turn_sustained": int(ctx.battle_result.get("turn", 0)),
		"description": str(row.get("effect", "")),
		"is_fatal": false,
		"equipment_lost": false,
		"bonus_xp": 0,
		"injury_source": "compendium_detailed",
		"injury_roll": int(row.get("roll", 0)),
		"table_name": str(row.get("name", row_id)),
	}

	match row_id:
		"death":
			# "The character is slain. A random item they carried is damaged."
			# The gear clause lands whether or not the Luck save rescues them,
			# exactly as the Core Rules Gruesome-fate row is handled above.
			var damaged: String = ctx.damage_random_equipment_for(
				crew_id, "Detailed Injury: Death")
			if not damaged.is_empty():
				processed["damaged_item"] = damaged
			processed["is_fatal"] = true
			return _resolve_fatal(ctx, processed, crew_id, "Death")

		"critical_strike":
			# "Is the character wearing Armor? If so, they survive, but the armor
			# is damaged. Otherwise, they are slain."
			var armor: String = ctx.damage_worn_armor_for(
				crew_id, "Detailed Injury: Critical Strike")
			if armor.is_empty():
				processed["is_fatal"] = true
				processed["description"] = "No armor worn — slain by a critical strike."
				return _resolve_fatal(ctx, processed, crew_id, "Critical Strike")
			processed["damaged_item"] = armor
			processed["description"] = (
				"Survived a critical strike — %s absorbed it and is damaged." % armor)

		"extensive_injury":
			# "Roll 1D6+1 to determine the cost in Credits. Until the cost has
			# been paid, the character cannot take crew tasks or fight. The Sick
			# Bay recovery time begins once they have received treatment."
			var cost: int = randi_range(1, 6) + 1
			processed["treatment_cost"] = cost
			# Sick Bay is "identical to medical cost" (the table's own wording) and
			# does not start ticking yet, so the recovery turns are STORED but the
			# character is held out by the two blocks below until treatment is paid.
			processed["recovery_turns"] = cost
			processed["treatment_pending"] = true
			for effect_type in ["skip_tasks", "skip_next_battle"]:
				ctx.apply_character_status_effect(ctx.get_crew_member(crew_id), {
					"type": effect_type,
					"name": "Untreated Injury (%dcr)" % cost,
					"description": ("Requires %d credits of specialized treatment."
						+ " Until paid they cannot take crew tasks or fight"
						+ " (Compendium p.102).") % cost,
					"treatment_cost": cost,
					"source_event": "Detailed Injury: Extensive injury",
				})

		"item_hit":
			# "Randomly select a carried item and roll 1D6. On a 1-4 it is
			# damaged. On a 5-6 it is destroyed."
			var item_roll: int = randi_range(1, 6)
			if item_roll <= 4:
				var hit: String = ctx.damage_random_equipment_for(
					crew_id, "Detailed Injury: Item hit")
				processed["damaged_item"] = hit
				processed["description"] = "Item hit (D6 %d): %s damaged." % [
					item_roll, hit if not hit.is_empty() else "nothing carried"]
			else:
				var gone: String = ctx.destroy_random_equipment_for(crew_id)
				processed["destroyed_item"] = gone
				processed["equipment_lost"] = not gone.is_empty()
				processed["description"] = "Item hit (D6 %d): %s destroyed." % [
					item_roll, gone if not gone.is_empty() else "nothing carried"]

		"school_of_hard_knocks":
			processed["bonus_xp"] = 1
			ctx.add_character_xp(ctx.get_crew_member(crew_id), 1)

	# Non-fatal outcomes all land in Sick Bay through the canonical writer, which
	# owns injuries[] / in_sick_bay / recovery_turns / status.
	ctx.apply_crew_injury(crew_id, processed)
	return processed


## Shared tail for the two rows that can slay the character (Death, and Critical
## Strike with no armor). Core Rules p.121's Luck clause is written about "a roll
## on this table" in the prose introducing the ORGANIC injury table, and the
## Compendium table explicitly replaces that table rather than adding to it — so
## the clause travels with it. Same reading already applied on the core path.
func _resolve_fatal(ctx: PostBattleContextClass, processed: Dictionary,
		crew_id: String, cause: String) -> Dictionary:
	if ctx.apply_luck_death_save(crew_id):
		processed["is_fatal"] = false
		processed["luck_death_save"] = true
		processed["recovery_turns"] = 0
		processed["description"] = (
			"Miraculously survived %s — lost ALL Luck (Core Rules p.121)"
			% cause.to_lower())
		return processed
	ctx.apply_crew_death(crew_id)
	return processed


func _crew_name(ctx: PostBattleContextClass, crew_id: String) -> String:
	var member: Variant = ctx.get_crew_member(crew_id)
	if member == null:
		return "Unknown"
	return ctx.get_char_name(member)


func _apply_equipment_consequences(ctx: PostBattleContextClass,
		processed_injury: Dictionary, injury_type: int, crew_id: String) -> void:
	## Core Rules p.122 organic Injury Table. Three mutually exclusive outcomes,
	## checked most-specific first because roll 16 and roll 1-5 both set the
	## "all equipment" flag but mean DIFFERENT things.
	var source: String = "Injury Table: %s" % str(processed_injury.get("type", ""))

	# 16 Miraculous escape: "all items carried are PERMANENTLY LOST."
	if InjuryConstants.equipment_is_permanently_lost(injury_type):
		var lost: Array = ctx.lose_all_equipment_for(crew_id)
		if not lost.is_empty():
			processed_injury["items_lost"] = lost
		return

	# 1-5 Gruesome fate: "all carried equipment is damaged" — repairable, p.78.
	if InjuryConstants.causes_all_equipment_damage(injury_type):
		var damaged: Array = ctx.damage_all_equipment_for(crew_id, source)
		if not damaged.is_empty():
			processed_injury["items_damaged"] = damaged
		return

	# 17-30 Equipment loss: "Random carried item is damaged."
	if InjuryConstants.causes_equipment_loss(injury_type):
		var one: String = ctx.damage_random_equipment_for(crew_id, source)
		if not one.is_empty():
			processed_injury["items_damaged"] = [one]


func _apply_crippling_wound(ctx: PostBattleContextClass,
		processed_injury: Dictionary, injury_type: int, crew_id: String) -> void:
	## The penalty is applied NOW and the surgery is offered as a BUY-OUT.
	##
	## That ordering is deliberate. The book presents this as a choice made
	## "immediately", but the backend resolves injuries before any UI exists to
	## ask — and a choice that waits for a prompt is a choice that silently never
	## happens, which is the exact defect this fix closes. Applying the default
	## outcome and letting the player pay to undo it means the rule ALWAYS fires,
	## the player keeps the decision, and ignoring the prompt leaves the book's
	## other branch standing. Same backend-flags / UI-offers split already used
	## for the "Looked worse than it was!" star in process_injuries().
	var spec: Dictionary = InjuryConstants.get_stat_reduction(injury_type)
	if spec.is_empty():
		return

	var reduced: Dictionary = ctx.apply_permanent_stat_reduction(
		crew_id, spec.get("stats", []), int(spec.get("amount", -1)))
	if not reduced.is_empty():
		processed_injury["stat_reduced"] = str(reduced.get("stat", ""))
		processed_injury["stat_reduced_from"] = int(reduced.get("from", 0))
		processed_injury["stat_reduced_to"] = int(reduced.get("to", 0))

	var cost: int = InjuryConstants.roll_surgery_cost_for(injury_type)
	if cost > 0:
		processed_injury["surgery_cost"] = cost
		# Only a real offer if there is something to undo; with every listed stat
		# already at 0 the surgery buys nothing and must not be sold.
		processed_injury["surgery_offer_available"] = not reduced.is_empty()

func _process_bot_injury(ctx: PostBattleContextClass, injury_data: Dictionary, crew_id: String) -> Dictionary:
	## Process injury for Bot/Soulless character (Core Rules p.94-95)
	var injury_roll := randi_range(1, 100)
	# Bot technician (p.125): "If a Bot or Soulless character must roll for a
	# post-battle injury, you may roll twice, picking the better result." The
	# book sets no per-battle limit here, so every such roll benefits.
	var reroll_note: String = ""
	if _bot_technician_active:
		var second_roll: int = randi_range(1, 100)
		var kept: int = _better_roll(injury_roll, second_roll, true)
		reroll_note = "Bot technician (p.125): rolled %d and %d, kept %d." % [
			injury_roll, second_roll, kept]
		injury_roll = kept
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
		"crew_name": _crew_name(ctx, crew_id),
		"type": injury_type_name,
		"severity": bot_injury_type,
		"recovery_turns": recovery_time,
		"turn_sustained": int(ctx.battle_result.get("turn", 0)),
		"description": injury_description,
		"is_fatal": is_fatal,
		"equipment_lost": equipment_damaged,
		"bonus_xp": 0,
		"is_bot_injury": true,
		"training_reroll": reroll_note,
	}

	var bot_props: Dictionary = InjuryConstants.BOT_INJURY_PROPERTIES.get(bot_injury_type, {})
	if bot_props.get("all_equipment", false):
		processed_injury["all_equipment_damaged"] = true

	# Core Rules p.122 Bot Injury Table, same dead-flag family as the organic
	# table above: 1-5 Obliterated is "Destroyed, and all carried equipment is
	# damaged" and 16-30 is "Random carried item is damaged" — 20 of 100 results
	# that set `equipment_lost`/`all_equipment_damaged` on this dict and touched
	# nothing. The Bot table has no permanent-loss row, so both outcomes are
	# damage and both stay repairable under p.78.
	var bot_source: String = "Bot Injury Table: %s" % injury_type_name
	if InjuryConstants.bot_causes_all_equipment_damage(bot_injury_type):
		var bot_damaged: Array = ctx.damage_all_equipment_for(crew_id, bot_source)
		if not bot_damaged.is_empty():
			processed_injury["items_damaged"] = bot_damaged
	elif InjuryConstants.bot_causes_equipment_loss(bot_injury_type):
		var bot_one: String = ctx.damage_random_equipment_for(crew_id, bot_source)
		if not bot_one.is_empty():
			processed_injury["items_damaged"] = [bot_one]

	# A DESTROYED bot is dead, not injured (Core Rules p.95 Bot Injury Table).
	# is_fatal was computed at :175 and recorded in the result dict, then ignored:
	# this called apply_crew_injury unconditionally, so a destroyed Bot/Soulless went
	# to Sick Bay and came back. Mirrors the organic fatal branch.
	if is_fatal:
		ctx.apply_crew_death(crew_id)
		return processed_injury

	ctx.apply_crew_injury(crew_id, processed_injury)

	return processed_injury
