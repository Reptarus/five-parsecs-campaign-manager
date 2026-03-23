class_name PostBattlePaymentProcessor
extends RefCounted

## Payment, Battlefield Finds, and Invasion checking for Post-Battle Phase.
## Handles Steps 4-6: Get Paid, Battlefield Finds, Check for Invasion (Core Rules p.85, p.88, p.121)
## Extracted from PostBattlePhase.gd — orchestrator delegates here.

const PostBattleContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const RedZoneSystemRef = preload("res://src/core/mission/RedZoneSystem.gd")
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
	if ctx.battle_result.get("is_quest_finale", false):
		var second_roll: int = ctx.roll_d6("Quest finale second roll")
		credit_roll = maxi(credit_roll, second_roll) + 1

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
	## Roll for battlefield finds using D100 table (Core Rules p.121)
	var find_roll: int = randi_range(1, 100)

	var LootConstants: Variant = null
	if ClassDB.class_exists(&"LootSystemConstants"):
		LootConstants = ClassDB.instantiate(&"LootSystemConstants")
	elif ResourceLoader.exists("res://src/core/systems/LootSystemConstants.gd"):
		var script = load("res://src/core/systems/LootSystemConstants.gd")
		if script:
			LootConstants = script

	if LootConstants and LootConstants.has_method("get_battlefield_finds_category"):
		var category: int = LootConstants.get_battlefield_finds_category(find_roll)
		match category:
			0:
				return {"type": "weapon", "roll": find_roll, "description": "Weapon found on battlefield", "subtable": "weapon"}
			1:
				return {"type": "consumable", "roll": find_roll, "description": "Consumable supplies found"}
			2:
				ctx.add_quest_rumor()
				return {"type": "quest_rumor", "roll": find_roll, "description": "Quest rumor discovered"}
			3:
				return {"type": "ship_part", "roll": find_roll, "description": "Useful ship component found"}
			4:
				var credits: int = randi_range(1, 3)
				return {"type": "trinket", "roll": find_roll, "amount": credits, "description": "Trinket worth %d credits" % credits}
			5:
				return {"type": "debris", "roll": find_roll, "description": "Worthless debris"}
			6:
				return {"type": "vital_info", "roll": find_roll, "description": "Vital information discovered"}
			7:
				return {"type": "nothing", "roll": find_roll, "description": "Nothing of value found"}

	# Fallback D100 ranges
	if find_roll <= 15:
		return {"type": "weapon", "roll": find_roll, "description": "Weapon found on battlefield", "subtable": "weapon"}
	elif find_roll <= 25:
		return {"type": "consumable", "roll": find_roll, "description": "Consumable supplies found"}
	elif find_roll <= 35:
		ctx.add_quest_rumor()
		return {"type": "quest_rumor", "roll": find_roll, "description": "Quest rumor discovered"}
	elif find_roll <= 45:
		return {"type": "ship_part", "roll": find_roll, "description": "Useful ship component found"}
	elif find_roll <= 60:
		var credits: int = randi_range(1, 3)
		return {"type": "trinket", "roll": find_roll, "amount": credits, "description": "Trinket worth %d credits" % credits}
	elif find_roll <= 75:
		return {"type": "debris", "roll": find_roll, "description": "Worthless debris"}
	elif find_roll <= 90:
		return {"type": "vital_info", "roll": find_roll, "description": "Vital information discovered"}
	else:
		return {"type": "nothing", "roll": find_roll, "description": "Nothing of value found"}
