class_name PostBattlePaymentProcessor
extends RefCounted

## Payment, Battlefield Finds, and Invasion checking for Post-Battle Phase.
## Handles Steps 4-6: Get Paid, Battlefield Finds, Check for Invasion (Core Rules p.85, p.88, p.121)
## Extracted from PostBattlePhase.gd — orchestrator delegates here.

const PostBattleContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const RedZoneSystemRef = preload("res://src/core/mission/RedZoneSystem.gd")
const BlackZoneSystemRef = preload("res://src/core/mission/BlackZoneSystem.gd")
const DifficultyModifiers = preload("res://src/core/systems/DifficultyModifiers.gd")

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
	var danger_pay: int = ctx.battle_result.get("danger_pay", 0)
	var total_payment: int = credit_roll + danger_pay

	# Failed missions get nothing (no post-battle rewards for losses)
	if not ctx.mission_successful:
		total_payment = 0

	if total_payment > 0 and ctx.game_state and ctx.game_state.has_method("add_credits"):
		ctx.game_state.add_credits(total_payment)

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
		# Clear all Rivals
		if ctx.game_state and ctx.game_state.current_campaign:
			var campaign: Resource = ctx.game_state.current_campaign
			if "crew_data" in campaign:
				var cd: Dictionary = campaign.crew_data
				if cd.has("rivals"):
					cd["rivals"] = []

		# Add 2 persistent Patrons
		if ctx.game_state and ctx.game_state.current_campaign:
			var campaign: Resource = ctx.game_state.current_campaign
			if "crew_data" in campaign:
				var cd: Dictionary = campaign.crew_data
				var patrons: Array = cd.get("patrons", [])
				for i in range(bz_rewards.get("add_patrons", 2)):
					patrons.append({
						"name": "Unity Contact %d" % (i + 1),
						"type": "persistent",
						"is_persistent": true,
					})
				cd["patrons"] = patrons

		# Bonus credits (5cr)
		var bonus_cr: int = bz_rewards.get("bonus_credits", 5)
		if bonus_cr > 0 and ctx.game_state:
			if ctx.game_state.has_method("add_credits"):
				ctx.game_state.add_credits(bonus_cr)

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
		if casualty_pay > 0 and ctx.game_state:
			if ctx.game_state.has_method("add_credits"):
				ctx.game_state.add_credits(casualty_pay)

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
