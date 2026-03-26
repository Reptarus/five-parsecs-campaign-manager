class_name ExperienceTrainingProcessor
extends RefCounted

## Experience, Training, and Purchase processing for Post-Battle Phase.
## Handles Steps 9-11: Experience & Upgrades, Advanced Training, Purchase Items
## (Core Rules p.89-91, p.121, p.125)
## Extracted from PostBattlePhase.gd — orchestrator delegates here.

const PostBattleContextClass = preload("res://src/core/campaign/phases/post_battle/PostBattleContext.gd")
const DifficultyModifiers = preload("res://src/core/systems/DifficultyModifiers.gd")

# Training course definitions (Core Rules p.125)
const TRAINING_COURSES: Dictionary = {
	"pilot": {"cost": 20, "effect": "savvy_roll_bonus", "description": "Piloting certification"},
	"mechanic": {"cost": 15, "effect": "hull_repair_bonus", "description": "Ship repair training"},
	"medical": {"cost": 20, "effect": "injury_reroll", "description": "Medical certification"},
	"merchant": {"cost": 10, "effect": "trade_reroll", "description": "Trade negotiation"},
	"security": {"cost": 10, "effect": "seize_initiative_bonus", "description": "Combat tactics"},
	"broker": {"cost": 15, "effect": "search_bonus", "description": "Information broker"},
	"bot_technician": {"cost": 10, "effect": "bot_upgrade_discount", "description": "Bot maintenance"},
	"basic": {"cost": 1, "effect": "xp_bonus", "description": "Basic training (+1 XP)"},
}

func process_experience(ctx: PostBattleContextClass) -> Array[Dictionary]:
	## Step 9: Award XP to participating crew. Returns xp_awards array.
	var xp_awards: Array[Dictionary] = []

	for participant in ctx.crew_participants:
		var crew_id: String = ""
		var is_bot: bool = false

		if participant is String:
			crew_id = participant
			is_bot = ctx.is_crew_member_bot(crew_id)
		elif participant is Dictionary:
			crew_id = participant.get("id", participant.get("character_id", ""))
			is_bot = participant.get("is_bot", false) or ctx.is_crew_member_bot(crew_id)

		if crew_id.is_empty():
			continue

		# Bots don't gain XP (Core Rules p.94)
		if is_bot:
			continue

		var xp_earned: int = _calculate_crew_xp(ctx, crew_id)
		if xp_earned > 0:
			xp_awards.append({"crew_id": crew_id, "xp": xp_earned})
			if ctx.game_state and ctx.game_state.has_method("add_crew_experience"):
				ctx.game_state.add_crew_experience(crew_id, xp_earned)

	# Journal: log XP awards
	if xp_awards.size() > 0 and ctx.campaign_journal \
			and ctx.campaign_journal.has_method("create_entry"):
		var total_xp: int = 0
		for award in xp_awards:
			total_xp += award.get("xp", 0)
		ctx.campaign_journal.create_entry({
			"type": "experience",
			"auto_generated": true,
			"title": "XP Awarded: %d total" % total_xp,
			"description": "%d crew members gained experience" % xp_awards.size(),
			"tags": ["experience", "post_battle"],
			"stats": {"total_xp": total_xp, "crew_count": xp_awards.size()},
		})

	return xp_awards

func process_training(ctx: PostBattleContextClass) -> Array[Dictionary]:
	## Step 10: Process training applications. Returns training_completed array.
	var training_completed: Array[Dictionary] = []
	var application_fee: int = 1
	var max_trainees: int = 2
	var trainees_this_turn: int = 0

	var training_candidates: Array = []
	for participant in ctx.crew_participants:
		var crew_id: String = ""
		if participant is Dictionary:
			crew_id = participant.get("id", participant.get("character_id", ""))
		elif participant is String:
			crew_id = participant

		if crew_id.is_empty():
			continue

		var is_injured: bool = false
		for injury in ctx.injuries_sustained:
			if injury.get("crew_id", "") == crew_id:
				is_injured = true
				break

		if ctx.is_crew_member_bot(crew_id):
			continue

		if not is_injured:
			training_candidates.append(crew_id)

	var current_credits: int = 0
	if ctx.game_state_manager and ctx.game_state_manager.has_method("get_credits"):
		current_credits = ctx.game_state_manager.get_credits()

	for crew_id in training_candidates:
		if trainees_this_turn >= max_trainees:
			break
		var result: Dictionary = attempt_training_enrollment(ctx, crew_id, "basic", current_credits)
		if result.get("success", false):
			training_completed.append(result)
			trainees_this_turn += 1
			current_credits = result.get("credits_remaining", current_credits)
		elif result.get("reason", "") == "insufficient_credits":
			break

	return training_completed

func process_purchases(ctx: PostBattleContextClass) -> Array[Dictionary]:
	## Step 11: Process queued purchases. Returns purchases_made array.
	var purchases_made: Array[Dictionary] = []

	if ctx.game_state_manager:
		var gs: Variant = null
		if ctx.game_state_manager.has_method("get_game_state"):
			gs = ctx.game_state_manager.get_game_state()

		var purchase_queue: Array = []
		if gs and "purchase_queue" in gs:
			purchase_queue = gs.purchase_queue
		elif ctx.game_state_manager.has_method("get_pending_purchases"):
			purchase_queue = ctx.game_state_manager.get_pending_purchases()

		if not purchase_queue.is_empty():
			var credits: int = 0
			if ctx.game_state_manager.has_method("get_credits"):
				credits = ctx.game_state_manager.get_credits()

			for item in purchase_queue:
				var cost: int = item.get("cost", 0)
				if credits >= cost:
					if ctx.game_state_manager.has_method("remove_credits"):
						ctx.game_state_manager.remove_credits(cost)
						credits -= cost
					if ctx.game_state_manager.has_method("add_to_ship_inventory"):
						ctx.game_state_manager.add_to_ship_inventory(item)
					purchases_made.append(item)

			if gs and "purchase_queue" in gs:
				gs.purchase_queue = []
			elif ctx.game_state_manager.has_method("clear_pending_purchases"):
				ctx.game_state_manager.clear_pending_purchases()

	return purchases_made

func attempt_training_enrollment(ctx: PostBattleContextClass, crew_id: String, course: String, available_credits: int) -> Dictionary:
	## Attempt to enroll crew member in training (Core Rules p.125).
	## 1. Pay 1 credit application fee (non-refundable)
	## 2. Roll 2D6, 4+ to get approved
	## 3. If approved, pay course cost and apply benefits
	var application_fee: int = 1

	if available_credits < application_fee:
		return {"success": false, "reason": "insufficient_credits", "crew_id": crew_id}

	if ctx.game_state_manager and ctx.game_state_manager.has_method("remove_credits"):
		ctx.game_state_manager.remove_credits(application_fee)
	available_credits -= application_fee

	var approval_roll: int = ctx.roll_2d6("Training approval for %s" % crew_id)

	if approval_roll < 4:
		return {
			"success": false, "reason": "not_approved", "crew_id": crew_id,
			"roll": approval_roll, "application_fee_paid": application_fee,
			"credits_remaining": available_credits
		}

	var course_data: Dictionary = TRAINING_COURSES.get(course, {"cost": 1, "effect": "xp_bonus", "description": "Basic training"})
	var course_cost: int = course_data.get("cost", 1)

	if available_credits < course_cost:
		return {
			"success": false, "reason": "cannot_afford_course", "crew_id": crew_id,
			"roll": approval_roll, "application_fee_paid": application_fee,
			"course_cost": course_cost, "credits_remaining": available_credits
		}

	if ctx.game_state_manager and ctx.game_state_manager.has_method("remove_credits"):
		ctx.game_state_manager.remove_credits(course_cost)
	available_credits -= course_cost

	var xp_awarded: int = 1
	if ctx.game_state_manager and ctx.game_state_manager.has_method("add_crew_experience"):
		ctx.game_state_manager.add_crew_experience(crew_id, xp_awarded)

	if ctx.game_state and ctx.game_state.has_method("set_crew_training"):
		ctx.game_state.set_crew_training(crew_id, course)

	return {
		"success": true, "crew_id": crew_id, "course": course,
		"course_description": course_data.get("description", "Training"),
		"effect": course_data.get("effect", ""), "roll": approval_roll,
		"application_fee_paid": application_fee, "course_cost": course_cost,
		"total_cost": application_fee + course_cost, "xp_awarded": xp_awarded,
		"credits_remaining": available_credits
	}

# --- Internal XP Calculation ---

func _calculate_crew_xp(ctx: PostBattleContextClass, crew_id: String) -> int:
	## Core Rules p.89-90 XP calculation.
	var xp: int = 0

	if ctx.battle_result.get("fled_early", false):
		return 0

	var was_casualty: bool = _was_crew_casualty_in_battle(ctx, crew_id)

	if was_casualty:
		xp += 1
		return _apply_xp_multiplier(ctx, xp)

	if ctx.mission_successful:
		xp += 3
	else:
		xp += 2

	if ctx.battle_result.get("first_casualty_by", "") == crew_id:
		xp += 1

	var unique_kills: Array = ctx.battle_result.get("unique_kills", [])
	if crew_id in unique_kills:
		xp += 1

	var difficulty: int = ctx.get_campaign_difficulty()
	var xp_bonus: int = DifficultyModifiers.get_xp_bonus(difficulty)
	if xp_bonus > 0:
		xp += xp_bonus

	if ctx.battle_result.get("is_red_zone", false) and ctx.battle_result.get("held_field", false):
		xp += 1

	if ctx.battle_result.get("is_quest_finale", false):
		xp += 1

	return _apply_xp_multiplier(ctx, xp)

func _apply_xp_multiplier(ctx: PostBattleContextClass, base_xp: int) -> int:
	var difficulty: int = ctx.get_campaign_difficulty()
	var multiplier: float = 1.0
	if difficulty == GlobalEnums.DifficultyLevel.EASY:
		multiplier = 0.75
	elif difficulty == GlobalEnums.DifficultyLevel.HARDCORE:
		multiplier = 1.25
	elif difficulty == GlobalEnums.DifficultyLevel.INSANITY:
		multiplier = 1.5
	return maxi(1, int(base_xp * multiplier))

func _was_crew_casualty_in_battle(ctx: PostBattleContextClass, crew_id: String) -> bool:
	if crew_id.is_empty():
		return false
	if ctx.battle_result.has("casualties"):
		for casualty in ctx.battle_result.get("casualties", []):
			if casualty is Dictionary:
				if str(casualty.get("crew_id", "")) == crew_id:
					if casualty.get("type", "") in ["killed", "critically_wounded", "missing", "fatal"]:
						return true
	if ctx.battle_result.has("injuries_sustained"):
		for injury in ctx.battle_result.get("injuries_sustained", []):
			if injury is Dictionary:
				if str(injury.get("crew_id", "")) == crew_id and injury.get("is_fatal", false):
					return true
	return false
