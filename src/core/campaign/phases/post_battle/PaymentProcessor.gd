class_name PostBattlePaymentProcessor
extends RefCounted

## Payment, Battlefield Finds, and Invasion checking for Post-Battle Phase.
## Handles Steps 4-6: Get Paid, Battlefield Finds, Check for Invasion (Core Rules p.85, p.88, p.121)
## Extracted from PostBattlePhase.gd — orchestrator delegates here.

const PostBattleContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const WorldTraitEffectsRef = preload("res://src/core/world/WorldTraitEffects.gd")
const RedZoneSystemRef = preload("res://src/core/mission/RedZoneSystem.gd")
const BlackZoneSystemRef = preload("res://src/core/mission/BlackZoneSystem.gd")
const DifficultyModifiers = preload("res://src/core/systems/DifficultyModifiers.gd")
const PatronJobEffects = preload("res://src/core/patrons/PatronJobEffects.gd")
const EnemyTraitRules = preload("res://src/core/systems/EnemyTraitRules.gd")

## Core Rules p.121, Battlefield Finds 36-45: "Starship part — Redeemable as
## equivalent to 2 credits only when installing a Starship Component."
const STARSHIP_PART_VALUE := 2

func process_scenario_loss_penalties(
	ctx: PostBattleContextClass
) -> Array[Dictionary]:
	## Core Rules p.92 — the two Rival attack types that cost you something when
	## you fail to Hold the Field:
	##   Assault: "If you fail to Hold the Field, you will lose 1D3 credits."
	##   Raid:    "If you fail to Hold the Field, your ship will take 1D6+1
	##            points of Hull Point damage."
	##
	## THE GAP THIS FILLS: `rival_attack_type` was rolled, stored on mission_data
	## and read by exactly one label. Neither consequence existed anywhere, so an
	## Assault and a Showdown were mechanically identical.
	##
	## The penalties ride in on battle_result["setup_rules"]["loss_penalties"],
	## built at scenario setup by BattleSetupRules so the reason and the page
	## citation travel with the charge.
	var applied: Array[Dictionary] = []
	var setup_rules: Dictionary = ctx.battle_result.get("setup_rules", {})
	var penalties: Array = setup_rules.get("loss_penalties", [])
	if penalties.is_empty():
		return applied

	# "Hold the Field" is the trigger, not mission success — you can lose the
	# objective and still hold the table, and the book charges on the field.
	if bool(ctx.battle_result.get("held_field", false)):
		return applied

	# p.91, every Rival attack type: "If you flee from the battle before 4 rounds
	# are up, a random crew member will lose a random item of equipment carried in
	# your flight."
	#
	# This is a DIFFERENT window from the p.123 XP rule ("flees in the first 2
	# rounds receives no XP"), which is what battle_result["fled_early"] means.
	# Conflating the two would deny XP for a round-3 withdrawal the book pays for.
	var flee_before: int = int(setup_rules.get("flee_before_round", 0))
	var rounds: int = int(ctx.battle_result.get("rounds",
		ctx.battle_result.get("rounds_fought", 0)))
	if flee_before > 0 and rounds > 0 and rounds < flee_before:
		var lost: Dictionary = _lose_random_item_from_random_crew(ctx)
		if not lost.is_empty():
			applied.append(lost)
			_log_penalty(ctx, "item", 1, str(lost.get("reason", "")))

	for penalty in penalties:
		var kind: String = str(penalty.get("type", ""))
		var reason: String = str(penalty.get("reason", ""))
		var amount: int = 0
		match kind:
			"credits":
				# 1D3: the book's D3 is a D6 halved up.
				amount = int(ceil(ctx.roll_d6() / 2.0))
				_charge_credits(ctx, amount)
			"hull":
				amount = ctx.roll_d6() + 1
				amount = _damage_ship(ctx, amount)
			_:
				continue
		applied.append({"type": kind, "amount": amount, "reason": reason})
		_log_penalty(ctx, kind, amount, reason)
	return applied

func _lose_random_item_from_random_crew(
	ctx: PostBattleContextClass
) -> Dictionary:
	## p.91: "a random crew member will lose a random item of equipment carried
	## in your flight." Per-character equipment is owned by Character.equipment
	## (the data-ownership table), so the item is dropped from the figure that
	## carried it, not from the ship stash.
	var crew: Array = ctx.get_crew_members()
	if crew.is_empty():
		return {}
	var candidates: Array = []
	for member in crew:
		var gear: Array = _equipment_of(member)
		if not gear.is_empty():
			candidates.append(member)
	if candidates.is_empty():
		return {}
	var victim: Variant = candidates[randi() % candidates.size()]
	var gear: Array = _equipment_of(victim)
	var idx: int = randi() % gear.size()
	var item_name: String = _item_name(gear[idx])
	gear.remove_at(idx)
	return {
		"type": "item",
		"amount": 1,
		"item": item_name,
		"crew_name": _crew_name(victim),
		"reason": "Fled a Rival battle before round 4 — %s lost %s (Core Rules p.91)"
			% [_crew_name(victim), item_name],
	}

func _equipment_of(member: Variant) -> Array:
	## Crew are Dictionaries on a loaded save and Character Resources on a fresh
	## campaign, and a 2-arg .get() silently ABORTS the whole function on a
	## Resource — so the two shapes must be branched, never merged.
	if member is Dictionary:
		var d: Dictionary = member
		if d.has("equipment") and d["equipment"] is Array:
			return d["equipment"]
		return []
	if member and "equipment" in member and member.equipment is Array:
		return member.equipment
	return []

func _crew_name(member: Variant) -> String:
	if member is Dictionary:
		var d: Dictionary = member
		return str(d.get("character_name", d.get("name", "A crew member")))
	if member and "character_name" in member:
		return str(member.character_name)
	return "A crew member"

func _item_name(item: Variant) -> String:
	if item is Dictionary:
		var d: Dictionary = item
		return str(d.get("name", d.get("id", "an item")))
	if item and "name" in item:
		return str(item.name)
	return str(item)

func _charge_credits(ctx: PostBattleContextClass, amount: int) -> void:
	## Credits are owned by the campaign core, and `GameStateManager.set_credits()`
	## is their ONLY sanctioned mutator (data-ownership table) — it writes the
	## campaign through AND emits credits_changed, which the resource bar and
	## dashboard listen to.
	##
	## The previous fallback wrote `ctx.campaign.credits` directly when the injected
	## manager reference was missing. That bypassed the owner (lint_data_ownership
	## flagged it) and, worse, moved credits without the signal — so the Rival
	## Assault fine (Core Rules p.92) could debit the campaign while every UI
	## showing credits kept the old number until something unrelated refreshed it.
	## Resolve the autoload instead, exactly as _log_penalty does below.
	if amount <= 0:
		return
	var gsm: Variant = ctx.game_state_manager
	if gsm == null and Engine.get_main_loop():
		gsm = Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("modify_credits"):
		gsm.modify_credits(-amount)  # clamps at 0 and routes through set_credits
	elif gsm and gsm.has_method("set_credits") and gsm.has_method("get_credits"):
		gsm.set_credits(maxi(0, int(gsm.get_credits()) - amount))
	else:
		push_warning("PaymentProcessor: no GameStateManager — %d credit charge dropped" % amount)

func _damage_ship(ctx: PostBattleContextClass, amount: int) -> int:
	## apply_ship_damage() returns the damage actually dealt after ship traits
	## (Armored -1, Improved Shielding -1, Dodgy Drive +2), so the reported
	## number matches what the player writes on their ship sheet.
	if amount <= 0:
		return 0
	if ctx.game_state_manager and ctx.game_state_manager.has_method("apply_ship_damage"):
		return int(ctx.game_state_manager.apply_ship_damage(amount))
	if ctx.campaign and "ship_data" in ctx.campaign:
		var ship: Dictionary = ctx.campaign.ship_data
		ship["hull_points"] = maxi(0, int(ship.get("hull_points", 0)) - amount)
		return amount
	return 0

func _log_penalty(
	ctx: PostBattleContextClass, kind: String, amount: int, reason: String
) -> void:
	var journal: Node = Engine.get_main_loop().root.get_node_or_null(
		"/root/CampaignJournal") if Engine.get_main_loop() else null
	if not journal or not journal.has_method("create_entry"):
		return
	var text: String = ""
	match kind:
		"credits": text = "Lost %d credits" % amount
		"hull": text = "Ship took %d Hull Point damage" % amount
		_: text = "Lost equipment in the retreat"
	journal.create_entry({
		"type": "battle",
		"title": text,
		"description": reason,
		"turn": int(ctx.battle_result.get("turn", 0)),
		"tags": ["rival", "penalty", kind],
	})

func process_payment(ctx: PostBattleContextClass) -> int:
	## Step 4: Get Paid (Core Rules p.120)
	## You earn 1D6 credits in pay, loot, bounty or salvage.
	## - Invasion battles: no payment
	## - Quest finale: roll twice pick better, +1
	## - Easy mode: +1
	## - Won objective (non-Rival): treat 1-2 as 3
	## - Patron job: add Danger Pay (1-3 credits from D10 table)
	if ctx.battle_result.get("is_invasion", false):
		return 0

	# Story Track Event 5 (Core Rules p.157): "You do not get paid after this
	# mission, and obtain no Loot". Stamped by StoryTrackProcessor before step 4.
	if ctx.battle_result.get("story_no_payment", false):
		return 0

	# Roll 1D6 for base payment (Core Rules p.120)
	var credit_roll: int = ctx.roll_d6("Payment credit roll")

	# Red Zone: roll twice, pick better (Compendium)
	if ctx.battle_result.get("is_red_zone", false):
		var red_second_roll: int = ctx.roll_d6("Red Zone second credit roll")
		credit_roll = maxi(credit_roll, red_second_roll)

	# Quest finale: roll twice, pick better, +1 (Core Rules p.120)
	# Red Zone quest: roll THREE dice, pick best, +1 (Appendix III)
	if ctx.battle_result.get("is_quest_finale", false):
		var second_roll: int = ctx.roll_d6(
			"Quest finale second roll")
		credit_roll = maxi(credit_roll, second_roll)
		if ctx.battle_result.get("is_red_zone", false):
			var third_roll: int = ctx.roll_d6(
				"Red Zone quest third roll")
			credit_roll = maxi(credit_roll, third_roll)
		credit_roll += 1

	# Danger Pay 10+ (Core Rules p.83): "+3 credits and roll twice, picking the
	# higher die when rolling for mission pay after the battle." JobOfferComponent
	# has always rolled this and stamped `double_roll_bonus` on the offer, and the
	# offer summary advertised "Roll twice for mission pay, keep higher" — but the
	# flag never crossed into the post-battle step, so those jobs paid a single
	# 1D6 like every other. Average mission pay on them was ~3.5 instead of ~4.5.
	if ctx.battle_result.get("double_roll_bonus", false):
		var danger_second_roll: int = ctx.roll_d6("Danger Pay 10+ second roll")
		credit_roll = maxi(credit_roll, danger_second_roll)

	# Easy mode: +1 credit (Core Rules p.64)
	var difficulty: int = ctx.get_campaign_difficulty()
	if difficulty == GlobalEnums.DifficultyLevel.EASY:
		credit_roll += 1

	# Won objective: treat 1-2 as 3 (except Rival missions) (Core Rules p.120)
	var is_rival_mission: bool = ctx.battle_result.get("is_rival_mission", false)
	if ctx.mission_successful and not is_rival_mission and credit_roll < 3:
		credit_roll = 3

	# Total payment = credit roll + Danger Pay for patron jobs (Core Rules p.120)
	# Note: failed non-Invasion missions still pay (Core Rules p.120 unconditional;
	# Invasion-only denial handled at line 31). Compendium p.151 confirms Black Zone
	# failures still receive normal post-battle rewards.
	# Danger Pay is a PATRON-job payment and nothing else. Core Rules p.120
	# Step 4: "If you did a Patron job, add the Pay bonus to the Danger Pay",
	# and the p.83 Danger Pay Table itself sits under "3. Determine Job Offers —
	# If you received a job offer from a Patron".
	#
	# JobOfferComponent rolls the p.83 tables for every offer including the Open
	# Market ones, so an Opportunity mission — the default "nothing else
	# presented itself" battle — arrived carrying 1 to 3 credits of Danger Pay it
	# is not entitled to. On a single-digit credit economy where Upkeep is 1, that
	# is a real distortion, and it applied to the most common battle in the game.
	var danger_pay: int = ctx.battle_result.get("danger_pay", 0)
	var pay_source: String = str(ctx.battle_result.get("mission_source", ""))
	if danger_pay > 0 and pay_source != "patron" and pay_source != "faction":
		danger_pay = 0
	# "Demanding — Danger Pay is only upon success" (Core Rules p.84 Conditions
	# Subtable), the named exception to p.83's default that Danger Pay "is paid
	# even if the mission fails, but only if the mission is attempted". The
	# Condition was rolled and displayed and never withheld a credit.
	if danger_pay > 0 and not ctx.mission_successful \
			and PatronJobEffects.danger_pay_on_success_only(ctx.battle_result):
		danger_pay = 0
	var total_payment: int = credit_roll + danger_pay

	# GameState has NO add_credits (credits are owned by GameStateManager) — so
	# `ctx.game_state.add_credits()` silently no-ops on the backend orchestrator path,
	# which was DROPPING the entire mission payment (the interactive Get Paid UI uses
	# GameStateManager and worked). Fall back to game_state_manager, mirroring
	# LootProcessor._apply_loot_reward.
	if total_payment > 0:
		if ctx.game_state and ctx.game_state.has_method("add_credits"):
			ctx.game_state.add_credits(total_payment)
		elif ctx.game_state_manager and ctx.game_state_manager.has_method("add_credits"):
			ctx.game_state_manager.add_credits(total_payment)

	# Journal: log payment earned
	if total_payment > 0 and ctx.campaign_journal and ctx.campaign_journal.has_method("create_entry"):
		var pay_desc: String = (
			"Earned %d credits (base %d + danger pay %d)"
			% [total_payment, credit_roll, danger_pay])
		# "finance", not "credits" — the canonical tag set is JournalEntryTypes
		# .TAGS and it has no "credits" entry. validate_entry() only warns, so
		# this shipped as a push_warning on every paying battle plus a chip
		# rendered in DEFAULT_TAG_COLOR that no finance filter would match.
		var pay_tags: Array = ["payment", "finance"]
		# Enrich with zone context
		if ctx.battle_result.get("is_red_zone", false):
			pay_desc += " [Red Zone: double roll]"
			pay_tags.append("red_zone")
		if ctx.battle_result.get("is_quest_finale", false):
			if ctx.battle_result.get("is_red_zone", false):
				pay_desc += " [Quest: triple roll +1]"
			else:
				pay_desc += " [Quest finale: double +1]"
		ctx.campaign_journal.create_entry({
			"type": "payment",
			"auto_generated": true,
			"title": "Mission Pay: %d credits" % total_payment,
			"description": pay_desc,
			"mood": "triumph" if total_payment >= 5 else "neutral",
			"tags": pay_tags,
		})

	return total_payment

func process_battlefield_finds(ctx: PostBattleContextClass) -> Array[Dictionary]:
	## Step 5: Battlefield Finds (Core Rules pp.120-121).
	##
	## Three separate book rules were missing here, all in the player's favour:
	##
	## 1. COUNT. p.121: "Roll D100 ONCE on the table below, and add the resulting
	##    find to your inventory." This rolled once PER CREW PARTICIPANT, so a
	##    six-person crew took six finds off a table meant to give one.
	## 2. HOLD THE FIELD. p.120: "If you Held the Field after the battle, you had
	##    an opportunity afterwards to search the battlefield." There was no gate,
	##    so a crew that fled the table still looted it. (The book is explicit that
	##    the objective does NOT matter — "You may do so even if you failed to
	##    achieve or did not have an objective" — only the field does.)
	## 3. INVASION. p.120: "You cannot roll on this table after an Invasion battle."
	## 4. STORY TRACK. Event 5 (p.157) denies pay and Loot but explicitly re-grants
	##    this roll — "You may make a Battlefield Finds roll as normal (p.121)" —
	##    so `story_force_battlefield_finds` satisfies the Hold the Field
	##    precondition (the crew resolved every marker; the field is theirs) and
	##    the rest of p.121 still applies. Event 4 hold-field (p.156) and Event 7
	##    win (p.160) instead say "roll twice on the Battlefield Finds Table",
	##    which arrives as `story_battlefield_finds_rolls`.
	var story_forced: bool = bool(
		ctx.battle_result.get("story_force_battlefield_finds", false))
	if not story_forced and not bool(ctx.battle_result.get("held_field", false)):
		return [] as Array[Dictionary]
	if bool(ctx.battle_result.get("is_invasion", false)):
		return [] as Array[Dictionary]

	# 5. SCAVENGERS. "Roll twice on the Battlefield Finds Table" (Core Rules p.97
	#    Salvage Team, p.100 Black Ops Team). Zero consumers anywhere: the trait
	#    was printed in the briefing and paid a single find like everyone else.
	#    Taken as the LARGER of the two sources rather than multiplied — the book
	#    gives no rule for stacking a Story Track double-roll with this one, and
	#    inventing four rolls would be our arithmetic, not the book's.
	var roll_count: int = maxi(
		int(ctx.battle_result.get("story_battlefield_finds_rolls", 1)),
		EnemyTraitRules.battlefield_finds_rolls(
			str(ctx.battle_result.get("enemy_type", ""))))
	roll_count = maxi(1, roll_count)

	var battlefield_finds: Array[Dictionary] = []
	for _i in range(roll_count):
		var find: Dictionary = _roll_battlefield_find(ctx)
		if not find.is_empty():
			battlefield_finds.append(find)
	return battlefield_finds

func process_invasion_check(ctx: PostBattleContextClass) -> bool:
	## Step 6: Check for Invasion (Core Rules p.88). Returns invasion_pending.
	var enemy_is_threat: bool = ctx.battle_result.get("enemy_is_invasion_threat", false)
	if not enemy_is_threat:
		return false

	# World Traits, Core Rules pp.73-74. All four were flavour text:
	#   "Unity safe sector — The world cannot be Invaded."
	#   "Invasion risk — Add +1 to all Invasion rolls."
	#   "Imminent invasion — Add +2 to all Invasion rolls..."
	#   "Military outpost — Add +2 to Invasion rolls..."
	# The safe sector is checked FIRST because it is absolute: no roll is made
	# at all, so no other modifier can drag the world into an Invasion.
	var world_traits: Array = ctx.battle_result.get("world_traits", [])
	if WorldTraitEffectsRef.invasion_immune(world_traits):
		return false

	var invasion_roll: int = ctx.roll_2d6("Invasion check")
	var modifiers: int = WorldTraitEffectsRef.invasion_roll_modifier(world_traits)

	if ctx.battle_result.get("invasion_evidence_found", false):
		modifiers += 1
	if ctx.battle_result.get("held_field", ctx.mission_successful):
		modifiers -= 1

	# Per-profile modifier. Core Rules p.101, Converted Acquisition, verbatim:
	# "Invasion Threat. Test at +1." Every other Invasion Threat profile on that
	# page carries a bare "Invasion Threat", so this is a genuine per-enemy value
	# and not a blanket one — it rides in from the enemy's own special rules.
	modifiers += int(ctx.battle_result.get("invasion_threat_modifier", 0))

	# Campaign Event 82-84, Rumors of War (Core Rules p.127): "While you remain
	# on this planet, any roll for Invasion is at +2." Scoped to the planet the
	# event fired on, because the clause ends the moment the crew travels — a
	# global flag would follow them across the sector forever.
	modifiers += _rumors_of_war_modifier(ctx)

	var difficulty: int = ctx.get_campaign_difficulty()
	var invasion_difficulty_mod: int = DifficultyModifiers.get_invasion_roll_modifier(difficulty)
	if invasion_difficulty_mod != 0:
		modifiers += invasion_difficulty_mod

	if ctx.battle_result.get("is_red_zone", false):
		var rz_mods: Dictionary = RedZoneSystemRef.get_invasion_modifiers()
		var rz_invasion_mod: int = rz_mods.get("invasion_roll_modifier", 2)
		modifiers += rz_invasion_mod

	# Per-world aftermath of a liberated planet: "Due to increased troop
	# presence, all future Invasion Threat rolls on this world are at -2"
	# (Core Rules p.126, Unity Victorious). GalacticWarProcessor wrote this into
	# campaign.invasion_modifiers and NOTHING read it, so a world you liberated
	# stayed exactly as invasion-prone as before you freed it.
	var campaign_for_world: Variant = ctx.campaign
	if campaign_for_world != null and campaign_for_world.has_method("get_invasion_threat_modifier"):
		var pdm: Node = Engine.get_main_loop().root.get_node_or_null("/root/PlanetDataManager") \
			if Engine.get_main_loop() else null
		if pdm != null:
			modifiers += campaign_for_world.get_invasion_threat_modifier(
				str(pdm.current_planet_id))

	var final_roll: int = invasion_roll + modifiers
	var invasion_pending: bool = final_roll >= 9

	if invasion_pending:
		if ctx.game_state and ctx.game_state.has_method("set_invasion_pending"):
			ctx.game_state.set_invasion_pending(true)

	return invasion_pending

func _roll_battlefield_find(ctx: PostBattleContextClass) -> Dictionary:
	## Roll for battlefield finds using D100 table
	## from mission_rewards.json (Core Rules pp.120-121).
	var table_mgr := MissionTableManager.new()
	var find: Dictionary = table_mgr.roll_battlefield_find()
	var find_type: String = find.get("type", "NOTHING")

	# Two entries on the table BRANCH on whether the enemy is an Invasion Threat
	# (Core Rules p.121, rolls 26-35 and 76-90): "You obtain a Quest Rumor. If the
	# enemy is an Invasion Threat, you instead find Invasion Evidence. Earn +1
	# credit, and add +1 when checking for Invasion in the next step."
	#
	# The branch did not exist — both entries always granted the Quest Rumor — so
	# `invasion_evidence_found`, which Step 6 reads on the very next line of the
	# sequence, had no producer anywhere in the codebase. Note "INSTEAD": the
	# Rumor and the Evidence are alternatives, never both.
	var enemy_is_threat: bool = bool(
		ctx.battle_result.get("enemy_is_invasion_threat", false))

	# Apply special effects based on find type
	match find_type:
		"CURIOUS_DATA_STICK":
			# p.121, 26-35: a Quest Rumor, or Invasion Evidence vs a threat.
			if enemy_is_threat:
				find["invasion_evidence"] = true
				find["amount"] = 1  # "Earn +1 credit"
				ctx.battle_result["invasion_evidence_found"] = true
				if ctx.game_state and ctx.game_state.has_method("add_credits"):
					ctx.game_state.add_credits(1)
				elif ctx.game_state_manager \
						and ctx.game_state_manager.has_method("add_credits"):
					ctx.game_state_manager.add_credits(1)
			elif ctx.has_method("add_quest_rumor"):
				ctx.add_quest_rumor()
		"VITAL_INFO":
			# p.121, 76-90, verbatim: "Turn in this information to get a
			# Corporate Patron automatically on this world. If the enemy is an
			# Invasion Threat, you instead find Invasion Evidence."
			#
			# This shared the arm above, so against a NORMAL enemy it paid a
			# Quest Rumor — which belongs only to 26-35. The player lost a
			# standing job source on the world and got progress on a Quest they
			# might not even be running. data/mission_tables/mission_rewards.json
			# has carried the correct text the whole time.
			if enemy_is_threat:
				find["invasion_evidence"] = true
				find["amount"] = 1
				ctx.battle_result["invasion_evidence_found"] = true
				if ctx.game_state and ctx.game_state.has_method("add_credits"):
					ctx.game_state.add_credits(1)
				elif ctx.game_state_manager \
						and ctx.game_state_manager.has_method("add_credits"):
					ctx.game_state_manager.add_credits(1)
			else:
				find["patron_opportunity"] = true
				if ctx.has_method("add_patron"):
					ctx.add_patron({
						"name": "Corporate Contact",
						"type": "Corporate",
						"source": "vital_info",
					})
		"DEBRIS":
			# p.121, 61-75: "Debris: 1D3 credits' worth on the scrap market."
			# The amount was rolled and never paid — nothing added the credits.
			var scrap: int = randi_range(1, 3)
			find["amount"] = scrap
			_grant_find_credits(ctx, scrap)
		"STARSHIP_PART":
			# p.121, 36-45: "Redeemable as equivalent to 2 credits only when
			# installing a Starship Component." Banked separately from cash so it
			# cannot be spent on anything else. No branch existed at all.
			find["amount"] = 0
			find["starship_part_credits"] = STARSHIP_PART_VALUE
			if ctx.game_state and ctx.game_state.current_campaign:
				var camp = ctx.game_state.current_campaign
				if "progress_data" in camp:
					var banked: int = int(camp.progress_data.get(
						"starship_part_credits", 0))
					camp.progress_data["starship_part_credits"] = \
						banked + STARSHIP_PART_VALUE
		"WEAPON":
			# p.121, 1-15: "Randomly select a slain (but not Bailed) enemy from
			# the battle. You may keep any weapons they were carrying." The choice
			# of weapon is the player's, so this reports the entitlement rather
			# than picking for them — but it used to have no branch at all and
			# said nothing.
			find["amount"] = 0
			find["claim_enemy_weapon"] = true
		"USABLE_GOODS":
			# p.121, 16-25: "Roll on the Consumables Table ... You receive 1
			# dosage of the item indicated."
			find["amount"] = 0
			find["consumable_roll_owed"] = 1
		"PERSONAL_TRINKET":
			# p.121, 46-60: "On each planet you visit in the future, roll 2D6. On
			# a 9+ you find the owner and receive a Loot roll as payment."
			# Recorded on the campaign so world arrival can check it; previously
			# the comment said "Resolved per-planet later" and no per-planet check
			# existed anywhere.
			find["amount"] = 0
			if ctx.game_state and ctx.game_state.current_campaign:
				var camp_t = ctx.game_state.current_campaign
				if "progress_data" in camp_t:
					var trinkets: int = int(camp_t.progress_data.get(
						"personal_trinkets", 0))
					camp_t.progress_data["personal_trinkets"] = trinkets + 1

	# The only consumer reads find["credits"]; this function has always written
	# find["amount"], so every credit value on the table displayed as 0.
	find["credits"] = int(find.get("amount", 0))
	return find


func _grant_find_credits(ctx: PostBattleContextClass, amount: int) -> void:
	if amount <= 0:
		return
	if ctx.game_state and ctx.game_state.has_method("add_credits"):
		ctx.game_state.add_credits(amount)
	elif ctx.game_state_manager and ctx.game_state_manager.has_method("add_credits"):
		ctx.game_state_manager.add_credits(amount)

func process_black_zone_rewards(
		ctx: PostBattleContextClass) -> Dictionary:
	## Black Zone victory/failure rewards (Core Rules Appendix III pp.150-151)
	if not ctx.battle_result.get("is_black_zone", false):
		return {}

	var bz_rewards: Dictionary = BlackZoneSystemRef.calculate_rewards(
		ctx.battle_result)

	if bz_rewards.get("is_victory", false):
		# CANONICAL OWNERS ARE campaign.rivals / campaign.patrons (top-level @vars,
		# per the data-ownership table and RivalPatronResolver._remove_rival).
		# Both writes used to target campaign.crew_data["rivals"] / ["patrons"] —
		# a location NOTHING reads — and the rival clear was additionally gated on
		# `cd.has("rivals")`, a key crew_data never carries. So the entire Black
		# Zone victory payout ("Clear ALL Rivals, +2 Patrons", Core Rules
		# Appendix III) applied to neither rivals nor patrons, while the journal
		# entry below dutifully reported both as done.
		if ctx.game_state and ctx.game_state.current_campaign:
			var campaign: Resource = ctx.game_state.current_campaign

			# Clear all Rivals
			if "rivals" in campaign and campaign.rivals is Array:
				campaign.rivals.clear()

			# Add 2 persistent Patrons
			if "patrons" in campaign and campaign.patrons is Array:
				for i in range(bz_rewards.get("add_patrons", 2)):
					campaign.patrons.append({
						"id": "bz_unity_contact_%d_%d" % [Time.get_ticks_msec(), i],
						"name": "Unity Contact %d" % (i + 1),
						"type": "persistent",
						"is_persistent": true,
						"persistent": true,
						"source": "black_zone",
					})

		# Bonus credits (5cr)
		var bonus_cr: int = bz_rewards.get("bonus_credits", 5)
		if bonus_cr > 0:
			if ctx.game_state and ctx.game_state.has_method("add_credits"):
				ctx.game_state.add_credits(bonus_cr)
			elif ctx.game_state_manager and ctx.game_state_manager.has_method("add_credits"):
				ctx.game_state_manager.add_credits(bonus_cr)

		# Ship loan payoff (5cr)
		if ctx.game_state and ctx.game_state.current_campaign:
			var campaign: Resource = ctx.game_state.current_campaign
			if "ship_debt" in campaign:
				var payoff: int = bz_rewards.get(
					"ship_loan_payoff", 5)
				campaign.ship_debt = maxi(
					0, campaign.ship_debt - payoff)

		# 3 Loot rolls and +1 XP all crew handled by
		# LootProcessor and ExperienceTrainingProcessor

		# Journal: Black Zone victory summary
		if ctx.campaign_journal and ctx.campaign_journal.has_method("create_entry"):
			var desc_parts: Array = [
				"All Rivals cleared",
				"2 persistent Unity Patrons added",
				"+%d credits" % bonus_cr,
			]
			if ctx.game_state and ctx.game_state.current_campaign:
				if "ship_debt" in ctx.game_state.current_campaign:
					desc_parts.append(
						"Ship loan reduced by %d"
						% bz_rewards.get("ship_loan_payoff", 5))
			desc_parts.append("+1 XP all crew")
			desc_parts.append("3 Loot Table rolls")
			ctx.campaign_journal.create_entry({
				"type": "milestone",
				"auto_generated": true,
				"title": "Black Zone Victory!",
				"description": "\n".join(desc_parts),
				"mood": "triumph",
				"tags": [
					"black_zone", "victory",
					"milestone", "rewards"],
			})

	else:
		# Failure: standard rewards + 1cr per casualty
		var casualty_pay: int = bz_rewards.get(
			"unity_casualty_pay", 0)
		if casualty_pay > 0:
			if ctx.game_state and ctx.game_state.has_method("add_credits"):
				ctx.game_state.add_credits(casualty_pay)
			elif ctx.game_state_manager and ctx.game_state_manager.has_method("add_credits"):
				ctx.game_state_manager.add_credits(casualty_pay)

		# Journal: Black Zone failure
		if ctx.campaign_journal and ctx.campaign_journal.has_method("create_entry"):
			ctx.campaign_journal.create_entry({
				"type": "battle",
				"auto_generated": true,
				"title": "Black Zone Mission Failed",
				"description": (
					"Unity pays %d credits for crew "
					+ "casualties. Standard failed "
					+ "mission rewards apply."
				) % casualty_pay,
				"mood": "somber",
				"tags": [
					"black_zone", "defeat",
					"payment"],
			})

	return bz_rewards


func _rumors_of_war_modifier(ctx: PostBattleContextClass) -> int:
	## +2 while the crew remains on the planet where Rumors of War fired
	## (Core Rules p.127, Campaign Event 82-84). Written by
	## CampaignEventEffects as progress_data["rumors_of_war_planet"].
	var campaign: Variant = ctx.campaign
	if campaign == null or not ("progress_data" in campaign):
		return 0
	var flagged: String = str(campaign.progress_data.get("rumors_of_war_planet", ""))
	if flagged.is_empty():
		return 0

	var pdm: Node = ctx.planet_data_manager
	if pdm == null:
		return 0
	var here: String = ""
	if "current_planet_id" in pdm and str(pdm.current_planet_id) != "":
		here = str(pdm.current_planet_id)
	elif pdm.has_method("get_current_planet"):
		var planet: Variant = pdm.get_current_planet()
		if planet is Dictionary:
			here = str(planet.get("name", ""))
		elif planet != null and "name" in planet:
			here = str(planet.name)

	if here.is_empty() or here != flagged:
		# Travelled on. The clause is spent, so clear it rather than leave a
		# stale planet id to be compared forever.
		campaign.progress_data.erase("rumors_of_war_planet")
		return 0
	return 2
