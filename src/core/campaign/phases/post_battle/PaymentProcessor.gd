class_name PostBattlePaymentProcessor
extends RefCounted

## Payment, Battlefield Finds, and Invasion checking for Post-Battle Phase.
## Handles Steps 4-6: Get Paid, Battlefield Finds, Check for Invasion (Core Rules p.85, p.88, p.121)
## Extracted from PostBattlePhase.gd — orchestrator delegates here.

const PostBattleContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const RedZoneSystemRef = preload("res://src/core/mission/RedZoneSystem.gd")
const BlackZoneSystemRef = preload("res://src/core/mission/BlackZoneSystem.gd")
const DifficultyModifiers = preload("res://src/core/systems/DifficultyModifiers.gd")

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

func _charge_credits(ctx: PostBattleContextClass, amount: int) -> void:
	## Credits are owned by the campaign core; GameState has no subtract API, so
	## this goes through the same manager chain process_payment() uses.
	if amount <= 0:
		return
	if ctx.game_state_manager and ctx.game_state_manager.has_method("set_credits") \
			and ctx.game_state_manager.has_method("get_credits"):
		var current: int = int(ctx.game_state_manager.get_credits())
		ctx.game_state_manager.set_credits(maxi(0, current - amount))
	elif ctx.campaign and "credits" in ctx.campaign:
		ctx.campaign.credits = maxi(0, int(ctx.campaign.credits) - amount)

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
	var text: String = "Lost %d credits" % amount if kind == "credits" \
		else "Ship took %d Hull Point damage" % amount
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
	var danger_pay: int = ctx.battle_result.get("danger_pay", 0)
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
		var pay_tags: Array = ["payment", "credits"]
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
	## Step 5: Battlefield Finds. Returns array of find dicts.
	var battlefield_finds: Array[Dictionary] = []
	var search_attempts = ctx.crew_participants.size()

	for i: int in range(search_attempts):
		var find = _roll_battlefield_find(ctx)
		if find:
			battlefield_finds.append(find)

	return battlefield_finds

func process_invasion_check(ctx: PostBattleContextClass) -> bool:
	## Step 6: Check for Invasion (Core Rules p.88). Returns invasion_pending.
	var enemy_is_threat: bool = ctx.battle_result.get("enemy_is_invasion_threat", false)
	if not enemy_is_threat:
		return false

	var invasion_roll: int = ctx.roll_2d6("Invasion check")
	var modifiers: int = 0

	if ctx.battle_result.get("invasion_evidence_found", false):
		modifiers += 1
	if ctx.battle_result.get("held_field", ctx.mission_successful):
		modifiers -= 1

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

	# Apply special effects based on find type
	match find_type:
		"CURIOUS_DATA_STICK", "VITAL_INFO":
			if ctx.has_method("add_quest_rumor"):
				ctx.add_quest_rumor()
		"DEBRIS":
			find["amount"] = randi_range(1, 3)
		"PERSONAL_TRINKET":
			find["amount"] = 0  # Resolved per-planet later

	return find

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
