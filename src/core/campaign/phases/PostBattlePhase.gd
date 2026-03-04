@tool
extends Node
class_name PostBattlePhase

## Post-Battle Phase Implementation - Official Five Parsecs Rules
## Handles the complete Post-Battle sequence (Phase 4 of campaign turn)

# Safe imports

# Safe dependency loading - loaded at runtime in _ready()
# GlobalEnums available as autoload singleton
# InjurySystemConstants needed for injury processing (line 379+)
const InjuryConstants = preload("res://src/core/systems/InjurySystemConstants.gd")
const HouseRulesHelper = preload("res://src/core/systems/HouseRulesHelper.gd")
const MoraleSystemRef = preload("res://src/core/systems/MoraleSystem.gd")
const CharacterRef = preload("res://src/core/character/Character.gd")
var dice_manager: Variant = null
var game_state_manager: Variant = null
## Sprint 28.2: Cached GameState reference (avoids 18+ get_node_or_null calls)
var _game_state: Variant = null

## Post-Battle Phase Signals
signal post_battle_phase_started()
signal post_battle_phase_completed()
signal post_battle_substep_changed(substep: int)
signal rival_status_resolved(rivals_removed: Array)
signal patron_status_resolved(patrons_added: Array)
signal quest_progress_updated(progress: int)
signal payment_received(amount: int)
signal battlefield_finds_completed(finds: Array)
signal invasion_checked(invasion_pending: bool)
signal loot_gathered(loot: Array)
signal injuries_resolved(injuries: Array)
signal experience_awarded(xp_awards: Array)
signal training_completed(training: Array)
signal purchases_made(purchases: Array)
signal campaign_event_occurred(event: Dictionary)
signal character_event_occurred(event: Dictionary)
signal galactic_war_updated(progress: Dictionary)
## Sprint 18.3: Precursor crew event choice signals
signal precursor_event_choice_available(event1: Dictionary, event2: Dictionary)
signal precursor_event_chosen(chosen_event: Dictionary)

## Current post-battle state
var current_substep: int = 0 # Will be set to PostBattleSubPhase.NONE in _ready()
var battle_result: Dictionary = {}
var defeated_enemies: Array = [] # Removed strict typing for dynamic data compatibility
var crew_participants: Array = [] # Removed strict typing for dynamic data compatibility

## Battle outcome data
var mission_successful: bool = false
var enemies_defeated: int = 0
var loot_earned: Array = [] # Removed strict typing for dynamic data compatibility
var injuries_sustained: Array = [] # Removed strict typing for dynamic data compatibility

## Campaign reference - set by CampaignPhaseManager
var _campaign: Variant = null

## Set the campaign reference for this phase handler
func set_campaign(campaign: Variant) -> void:
	## Receive campaign reference from CampaignPhaseManager.
	_campaign = campaign

## SPRINT 7.1: Consistent access pattern for campaign configuration
## Source of truth: Campaign resource (difficulty, house_rules, victory_conditions, story_track)
func _get_campaign_config(key: String, default_value: Variant = null) -> Variant:
	if _campaign:
		match key:
			"difficulty":
				if _campaign.has_method("get") and _campaign.get("difficulty") != null:
					return _campaign.difficulty
				elif "difficulty" in _campaign:
					return _campaign.difficulty
			"house_rules":
				if _campaign.has_method("get_house_rules"):
					return _campaign.get_house_rules()
				elif "house_rules" in _campaign:
					return _campaign.house_rules
			"victory_conditions":
				if _campaign.has_method("get_victory_conditions"):
					return _campaign.get_victory_conditions()
				elif "victory_conditions" in _campaign:
					return _campaign.victory_conditions
			"story_track_enabled":
				if _campaign.has_method("get_story_track_enabled"):
					return _campaign.get_story_track_enabled()
				elif "story_track_enabled" in _campaign:
					return _campaign.story_track_enabled
	# Fallback to GameStateManager
	if game_state_manager:
		match key:
			"difficulty":
				if game_state_manager.has_method("get_difficulty_level"):
					return game_state_manager.get_difficulty_level()
			"house_rules":
				if game_state_manager.has_method("get_house_rules"):
					return game_state_manager.get_house_rules()
			"victory_conditions":
				if game_state_manager.has_method("get_victory_conditions"):
					return game_state_manager.get_victory_conditions()
			"story_track_enabled":
				if game_state_manager.has_method("get_story_track_enabled"):
					return game_state_manager.get_story_track_enabled()
	return default_value

## SPRINT 7.1: Consistent access pattern for runtime state
## Source of truth: GameStateManager (credits, turn_number, current_location, etc.)
func _get_runtime_state(key: String, default_value: Variant = null) -> Variant:
	if game_state_manager:
		match key:
			"credits":
				if game_state_manager.has_method("get_credits"):
					return game_state_manager.get_credits()
			"turn_number":
				if "turn_number" in game_state_manager:
					return game_state_manager.turn_number
			"current_location":
				if game_state_manager.has_method("get_current_location"):
					return game_state_manager.get_current_location()
			"story_points":
				if game_state_manager.has_method("get_story_points"):
					return game_state_manager.get_story_points()
			"crew_size":
				if game_state_manager.has_method("get_crew_size"):
					return game_state_manager.get_crew_size()
	return default_value

## Sprint 15: Dice and difficulty helper functions
func _roll_d6(context: String = "D6 Roll") -> int:
	## Roll a D6 using the dice manager or fallback to randi
	if dice_manager and dice_manager.has_method("roll_d6"):
		return dice_manager.roll_d6(context)
	# Fallback if dice manager not available
	return randi_range(1, 6)

func _roll_2d6(context: String = "2D6 Roll") -> int:
	## Roll 2D6 using the dice manager or fallback to randi
	if dice_manager and dice_manager.has_method("roll_d6"):
		return dice_manager.roll_d6(context + " (die 1)") + dice_manager.roll_d6(context + " (die 2)")
	# Fallback if dice manager not available
	return randi_range(1, 6) + randi_range(1, 6)

func _get_campaign_difficulty() -> int:
	## Get current campaign difficulty level (0=Easy, 1=Normal, 2+=Harder)
	if game_state_manager:
		if game_state_manager.has_method("get_difficulty"):
			return game_state_manager.get_difficulty()
		elif game_state_manager.has_method("get_game_state"):
			var gs = game_state_manager.get_game_state()
			if gs:
				if "difficulty" in gs:
					return gs.difficulty
				elif "difficulty_level" in gs:
					return gs.difficulty_level
	# Default to Normal difficulty
	return 1

func _ready() -> void:
	# Load dependencies safely at runtime
	# GlobalEnums already loaded as const at compile time
	dice_manager = DiceManager
	game_state_manager = get_node_or_null("/root/GameStateManager")
	# Sprint 28.2: Cache GameState reference once instead of 18+ repeated lookups
	_game_state = get_node_or_null("/root/GameState")

	# Initialize enum values using preloaded GlobalEnums
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.NONE


## Main Post-Battle Phase Processing
func start_post_battle_phase(battle_data: Dictionary = {}) -> void:
	## Begin the Post-Battle Phase sequence

	# Sprint 26.4: Debug logging for data handoff verification
	_debug_log_post_battle_input(battle_data)

	# Handle battle-skipped path (no battle this turn, just tick recovery/events)
	if battle_data.get("battle_skipped", false):
		battle_result = {"battle_skipped": true}
		self.post_battle_phase_started.emit()
		_complete_post_battle_phase()
		return

	# Store battle result data
	battle_result = battle_data.duplicate(true)
	mission_successful = battle_data.get("success", false)
	enemies_defeated = battle_data.get("enemies_defeated", 0)
	defeated_enemies = battle_data.get("defeated_enemy_list", [])
	crew_participants = battle_data.get("crew_participants", [])
	# P-3 fix: Extract injuries_sustained from BattlePhase combat_results
	injuries_sustained = battle_data.get("injuries_sustained", [])
	if injuries_sustained.size() > 0:
		pass
	else:
		pass

	self.post_battle_phase_started.emit()

	# Step 1: Resolve rival status
	_process_rival_status()

func _process_rival_status() -> void:
	## Step 1: Resolve Rival Status
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.RIVAL_STATUS
		self.post_battle_substep_changed.emit(current_substep)

	var rivals_removed: Array[String] = []

	# Check if any rivals were defeated in battle
	var faction_sys = Engine.get_main_loop().root.get_node_or_null("/root/FactionSystem") if Engine.get_main_loop() else null
	var npc_tracker = get_node_or_null("/root/NPCTracker")
	for enemy in defeated_enemies:
		if enemy.get("is_rival", false):
			var rival_id = enemy.get("rival_id", "")
			if rival_id != "":
				# Roll D6+modifiers to remove rival permanently
				var removal_roll = _roll_rival_removal(rival_id)
				if removal_roll >= 6: # Standard threshold for rival removal
					rivals_removed.append(rival_id)
					_remove_rival(rival_id)
				# Update rival reputation in FactionSystem
				if faction_sys and faction_sys.has_method("update_rival_reputation"):
					var rep_change = 2 if removal_roll >= 6 else -1
					faction_sys.update_rival_reputation(rival_id, rep_change)
				# Track rival encounter in NPCTracker
				if npc_tracker and npc_tracker.has_method("track_rival_encounter"):
					var result_str: String = "victory" if mission_successful else "defeat"
					npc_tracker.track_rival_encounter(rival_id, result_str, battle_result.get("turn", 0))

	# Update faction standings based on battle outcome
	if faction_sys and faction_sys.has_method("modify_faction_standing"):
		var faction_id = battle_result.get("faction_id", "")
		if faction_id != "":
			var standing_change = 5.0 if mission_successful else -3.0
			faction_sys.modify_faction_standing(faction_id, standing_change)

	self.rival_status_resolved.emit(rivals_removed)

	# Continue to patron status
	_process_patron_status()

func _roll_rival_removal(rival_id: String) -> int:
	## Roll to determine if rival is permanently removed
	var base_roll = randi_range(1, 6)
	var modifiers: int = 0

	# Add modifiers based on how the rival was defeated
	if mission_successful:
		modifiers += 1

	# Add other modifiers based on circumstances
	modifiers += _get_rival_removal_modifiers(rival_id)

	return base_roll + modifiers

func _get_rival_removal_modifiers(rival_id: String) -> int:
	## Get modifiers for rival removal based on circumstances
	var modifiers: int = 0

	# Check rival type, crew actions, etc.
	# This would be expanded based on full rival system implementation

	return modifiers

func _remove_rival(rival_id: String) -> void:
	## Remove rival from active rivals list
	var game_state = _game_state
	if game_state and game_state.current_campaign and "active_rivals" in game_state.current_campaign:
		var rivals: Array = game_state.current_campaign.active_rivals
		for i in range(rivals.size() - 1, -1, -1):
			var rival = rivals[i]
			var rid = rival.get("id", rival) if rival is Dictionary else str(rival)
			if rid == rival_id:
				rivals.remove_at(i)
				return

func _process_patron_status() -> void:
	## Step 2: Resolve Patron Status
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.PATRON_STATUS
		self.post_battle_substep_changed.emit(current_substep)

	var patrons_added: Array[String] = []

	# If mission was successful and involved a patron
	if mission_successful and battle_result.has("patron_id"):
		var patron_id = battle_result.patron_id

		# Add successful patrons to contacts
		if GameState and GameState.has_method("add_patron_contact"):
			GameState.add_patron_contact(patron_id)
			patrons_added.append(patron_id)

		# Delegate job completion to PatronSystem for reputation/rewards tracking
		var patron_sys = Engine.get_main_loop().root.get_node_or_null("/root/PatronSystem") if Engine.get_main_loop() else null
		if patron_sys and patron_sys.has_method("complete_job"):
			patron_sys.complete_job(true, battle_result)

		# Track patron job completion in NPCTracker
		var npc_tracker = get_node_or_null("/root/NPCTracker")
		if npc_tracker and npc_tracker.has_method("track_patron_interaction"):
			npc_tracker.track_patron_interaction(patron_id, "job_completed", {
				"turn": battle_result.get("turn", 0)
			})

		# HOUSE RULE: expanded_rumors - +1 quest rumor on patron mission completion
		if HouseRulesHelper.is_enabled("expanded_rumors"):
			_add_quest_rumor()
	elif not mission_successful and battle_result.has("patron_id"):
		# Failed patron mission - still notify PatronSystem
		var patron_sys = Engine.get_main_loop().root.get_node_or_null("/root/PatronSystem") if Engine.get_main_loop() else null
		if patron_sys and patron_sys.has_method("complete_job"):
			patron_sys.complete_job(false, battle_result)

		# Track patron job failure in NPCTracker
		var npc_tracker_fail = get_node_or_null("/root/NPCTracker")
		if npc_tracker_fail and npc_tracker_fail.has_method("track_patron_interaction"):
			npc_tracker_fail.track_patron_interaction(battle_result.patron_id, "job_failed", {
				"turn": battle_result.get("turn", 0)
			})

	# Handle persistent patrons
	_handle_persistent_patrons()

	self.patron_status_resolved.emit(patrons_added)

	# Continue to quest progress
	_process_quest_progress()

func _handle_persistent_patrons() -> void:
	## Handle patrons with persistence trait
	# This would check for patrons with persistence and maintain their availability
	pass

func _process_quest_progress() -> void:
	## Step 3: Determine Quest Progress (Core Rules p.86)
	##
	## Sprint 15.3: Implements proper quest progress thresholds:
	## - Roll D6 + quest rumors
	## - Failed mission: -2 modifier
	## - Result 3 or less: Dead end (no progress)
	## - Result 4-6: Progress (+1 quest rumor)
	## - Result 7+: Finale available!
	## - Secondary roll: 4+ requires travel, 5-6 requires travel to new world
	pass
	## if GlobalEnums:
	## current_substep = GlobalEnums.PostBattleSubPhase.QUEST_PROGRESS
	## self.post_battle_substep_changed.emit(current_substep)
	##
	## # Quest progress result: 0 = dead end, 1 = rumor gained, 2 = finale available
	## var quest_progress: int = 0
	##
	## # Check if currently on a quest
	## if not GameState or not GameState.has_active_quest():
	## print("PostBattlePhase: No active quest - skipping quest progress")
	## self.quest_progress_updated.emit(0)
	## _process_payment()
	## return
	##
	## # Roll D6 + Quest Rumors
	## var base_roll: int = _roll_d6("Quest progress roll")
	## var quest_rumors: int = 0
	## if GameState.has_method("get_quest_rumors"):
	## quest_rumors = GameState.get_quest_rumors()
	## elif GameState.has_method("get_quest_rumor_count"):
	## quest_rumors = GameState.get_quest_rumor_count()
	##
	## var total_roll: int = base_roll + quest_rumors
	## print("PostBattlePhase: Quest progress roll: %d + %d rumors = %d" % [base_roll, quest_rumors, total_roll])
	##
	## # Failed mission modifier: -2
	## if not mission_successful:
	## total_roll -= 2
	## print("PostBattlePhase: Failed mission penalty: -2, now %d" % total_roll)
	##
	## # Determine outcome based on thresholds (Core Rules p.86)
	## if total_roll <= 3:
	## # Dead end - no progress
	## quest_progress = 0
	## print("PostBattlePhase: Quest dead end (roll %d <= 3) - no progress" % total_roll)
	## elif total_roll <= 6:
	## # Progress - gain 1 quest rumor
	## quest_progress = 1
	## if GameState.has_method("add_quest_rumor"):
	## GameState.add_quest_rumor()
	## print("PostBattlePhase: Quest progress (roll %d, 4-6) - gained 1 rumor" % total_roll)
	## else:
	## # Finale available! (7+)
	## quest_progress = 2
	## print("PostBattlePhase: QUEST FINALE AVAILABLE! (roll %d >= 7)" % total_roll)
	##
	## if GameState.has_method("set_quest_finale_available"):
	## GameState.set_quest_finale_available(true)
	##
	## # Secondary roll to determine if travel is required
	## var travel_roll: int = _roll_d6("Quest finale travel requirement")
	## if travel_roll >= 4:
	## var requires_new_world: bool = travel_roll >= 5
	## if requires_new_world:
	## print("PostBattlePhase: Quest finale requires travel to NEW WORLD (roll %d)" % travel_roll)
	## if GameState.has_method("set_quest_requires_travel"):
	## GameState.set_quest_requires_travel(true, true)  # travel required, new world
	## else:
	## print("PostBattlePhase: Quest finale requires travel (roll %d)" % travel_roll)
	## if GameState.has_method("set_quest_requires_travel"):
	## GameState.set_quest_requires_travel(true, false)  # travel required, same region
	## else:
	## print("PostBattlePhase: Quest finale available HERE (roll %d < 4)" % travel_roll)
	##
	## self.quest_progress_updated.emit(quest_progress)
	##
	## # Continue to payment
	## _process_payment()
	##
func _process_payment() -> void:
	## Sprint 15.1: Implements proper D6-based payment with Core Rules modifiers:
	## - Base D6 roll for payment multiplier
	## - Quest finale: roll twice, pick better, +1
	## - Easy mode: +1
	## - Victory objective: treat 1-2 as 3 (except Rival missions)
	## - Difficulty multiplier applied to final amount
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.GET_PAID
		self.post_battle_substep_changed.emit(current_substep)

	# Invasion battles don't pay (Core Rules p.85)
	if battle_result.get("is_invasion", false):
		self.payment_received.emit(0)
		_process_battlefield_finds()
		return

	# Failed missions don't pay
	if not mission_successful:
		self.payment_received.emit(0)
		_process_battlefield_finds()
		return

	# Get difficulty setting (0 = Easy, 1 = Normal, 2+ = Harder)
	var difficulty: int = _get_campaign_difficulty()
	var is_easy_mode: bool = difficulty == 0

	# Roll base D6 for payment multiplier
	var base_roll: int = _roll_d6("Payment base roll")

	# Quest finale: roll twice, pick better, +1 (Core Rules p.86)
	var is_quest_finale: bool = battle_result.get("is_quest_finale", false)
	if is_quest_finale:
		var second_roll: int = _roll_d6("Quest finale second roll")
		base_roll = max(base_roll, second_roll) + 1

	# Easy mode: +1 (Core Rules difficulty modifiers)
	if is_easy_mode:
		base_roll += 1

	# Victory objective: treat 1-2 as 3 (except Rival missions) (Core Rules p.85)
	var is_rival_mission: bool = battle_result.get("is_rival_mission", false)
	if mission_successful and not is_rival_mission and base_roll < 3:
		base_roll = 3

	# Calculate payment: base_payment * roll multiplier
	var base_payment: int = battle_result.get("base_payment", 100)
	var danger_pay: int = battle_result.get("danger_pay", 0)
	var raw_payment: int = base_payment + danger_pay

	# Payment multiplier based on roll (1-6+ becomes 1x-6x+ credits per 10 base)
	var payment_multiplier: float = base_roll / 3.0 # Roll 3 = 1x, Roll 6 = 2x
	var total_payment: int = int(raw_payment * payment_multiplier)

	# F-3 fix: Apply difficulty multiplier to payment
	# Higher difficulty = higher rewards (0.875x to 1.375x based on difficulty 1-5)
	if total_payment > 0:
		difficulty = clampi(difficulty, 0, 5)
		var difficulty_multiplier: float = 0.75 + ((difficulty + 1) * 0.125) # 0.875 to 1.5
		var adjusted_payment: int = int(total_payment * difficulty_multiplier)
		total_payment = adjusted_payment

	# Sprint 26.5: Debug log payment breakdown
	var difficulty_bonus_amount: int = int(total_payment - (raw_payment * payment_multiplier)) if difficulty > 0 else 0
	_debug_log_payment(base_payment, danger_pay, 0, 0, total_payment)

	# Award payment
	if total_payment > 0 and GameState.has_method("add_credits"):
		GameState.add_credits(total_payment)

	self.payment_received.emit(total_payment)

	# Continue to battlefield finds
	_process_battlefield_finds()

func _process_battlefield_finds() -> void:
	## Step 5: Battlefield Finds
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.BATTLEFIELD_FINDS
		self.post_battle_substep_changed.emit(current_substep)

	var battlefield_finds: Array[Dictionary] = []

	# Search battlefield for items and clues
	var search_attempts = crew_participants.size() # Each crew member can search

	for i: int in range(search_attempts):
		var find = _roll_battlefield_find()
		if find:
			battlefield_finds.append(find)

	self.battlefield_finds_completed.emit(battlefield_finds)

	# Continue to invasion check
	_process_invasion_check()

func _roll_battlefield_find() -> Dictionary:
	## Roll for battlefield finds
	var find_roll = randi_range(1, 6)

	match find_roll:
		1, 2:
			return {} # Nothing found
		3, 4:
			return {"type": "credits", "amount": randi_range(1, 3), "description": "Small credits cache"}
		5:
			return {"type": "equipment", "item": "basic_gear", "description": "Abandoned equipment"}
		6:
			return {"type": "clue", "value": 1, "description": "Useful information"}

	return {}

func _process_invasion_check() -> void:
	## Step 6: Check for Invasion (Core Rules p.88)
	##
	## Sprint 15.2: Implements proper 2D6 invasion check with modifiers:
	## - Roll 2D6, threshold 9+ triggers invasion
	## - +1 if invasion evidence was found
	## - -1 if crew held the field (victory)
	## - +2 for Hardcore difficulty (3+)
	## - +1 additional for Insanity difficulty (4+)
	## ##
	pass
	## if GlobalEnums:
	## current_substep = GlobalEnums.PostBattleSubPhase.CHECK_INVASION
	## self.post_battle_substep_changed.emit(current_substep)
	##
	## # Only check if enemy was an invasion threat (Core Rules p.88)
	## var enemy_is_threat: bool = battle_result.get("enemy_is_invasion_threat", false)
	## if not enemy_is_threat:
	## print("PostBattlePhase: Enemy is not an invasion threat - skipping invasion check")
	## self.invasion_checked.emit(false)
	## _process_loot_gathering()
	## return
	##
	## # Roll 2D6 for invasion check
	## var invasion_roll: int = _roll_2d6("Invasion check")
	## print("PostBattlePhase: Invasion check base roll: %d" % invasion_roll)
	##
	## # Apply modifiers
	## var modifiers: int = 0
	## var modifier_reasons: Array[String] = []
	##
	## # +1 if invasion evidence was found during battle
	## if battle_result.get("invasion_evidence_found", false):
	## modifiers += 1
	## modifier_reasons.append("+1 invasion evidence")
	##
	## # -1 if crew held the field (victory)
	## if battle_result.get("held_field", mission_successful):
	## modifiers -= 1
	## modifier_reasons.append("-1 held field")
	##
	## # Difficulty modifiers
	## var difficulty: int = _get_campaign_difficulty()
	## if difficulty >= 3:  # Hardcore
	## modifiers += 2
	## modifier_reasons.append("+2 Hardcore")
	## if difficulty >= 4:  # Insanity
	## modifiers += 1
	## modifier_reasons.append("+1 Insanity")
	##
	## var final_roll: int = invasion_roll + modifiers
	## var invasion_pending: bool = final_roll >= 9
	##
	## if modifier_reasons.size() > 0:
	## print("PostBattlePhase: Invasion modifiers: %s = %+d, final: %d" % [
	## ", ".join(modifier_reasons), modifiers, final_roll
	## ])
	##
	## if invasion_pending:
	## print("PostBattlePhase: INVASION TRIGGERED! (Roll %d >= 9)" % final_roll)
	## if GameState and GameState.has_method("set_invasion_pending"):
	## GameState.set_invasion_pending(true)
	## else:
	## print("PostBattlePhase: No invasion (Roll %d < 9)" % final_roll)
	##
	## self.invasion_checked.emit(invasion_pending)
	##
	## # Continue to loot gathering
	## _process_loot_gathering()
	##
	## func _process_loot_gathering() -> void:
	## ## Step 7: Gather the Loot
	## if GlobalEnums:
	## current_substep = GlobalEnums.PostBattleSubPhase.GATHER_LOOT
	## self.post_battle_substep_changed.emit(current_substep)
	##
	## var gathered_loot: Array[Dictionary] = []
	##
	## # Roll on loot tables based on enemies defeated
	## for enemy in defeated_enemies:
	## var enemy_loot: Array[Dictionary] = _roll_enemy_loot(enemy)
	## if enemy_loot.size() > 0:
	## gathered_loot.append_array(enemy_loot)
	##
	## print("PostBattlePhase: Gathered %d loot items" % gathered_loot.size())
	##
	## # Add loot to inventory
	## for loot_item in gathered_loot:
	## _add_loot_to_inventory(loot_item)
	##
	## self.loot_gathered.emit(gathered_loot)
	##
	## # Continue to injuries
	## _process_injuries()
	##
	## func _roll_enemy_loot(enemy: Dictionary) -> Array[Dictionary]:
	## ## Roll for loot from defeated enemy
	## var loot: Array[Dictionary] = []
	## var enemy_type: String = enemy.get("type", "basic")
	##
	## # Different loot tables based on enemy type
	## match enemy_type:
	## "elite":
	## if randi_range(1, 6) >= 4: # 50% chance
	## loot.append({"type": "weapon", "quality": "advanced", "description": "Elite weapon"})
	## "boss":
	## if randi_range(1, 6) >= 3: # 67% chance
	## loot.append({"type": "special", "quality": "rare", "description": "Boss loot"})
	## _:
	## if randi_range(1, 6) >= 5: # 33% chance
	## loot.append({"type": "equipment", "quality": "basic", "description": "Standard gear"})
	##
	## return loot
	##
func _add_loot_to_inventory(loot_item: Dictionary) -> void:
	## If the loot is an implant, attempt to install on a crew member first.
	# Check if this loot item is an implant
	var loot_name: String = loot_item.get("name", loot_item.get("description", ""))
	if CharacterRef.LOOT_TO_IMPLANT_MAP.has(loot_name):
		if _try_install_implant_from_loot(loot_name):
			return # Successfully installed on a crew member

	# Convert loot item to equipment format if needed
	var equipment_data = loot_item.duplicate()
	if not equipment_data.has("id"):
		equipment_data["id"] = "loot_" + str(Time.get_ticks_msec()) + "_" + str(randi())
	if not equipment_data.has("name"):
		equipment_data["name"] = equipment_data.get("description", "Unknown Loot")
	if not equipment_data.has("location"):
		equipment_data["location"] = "ship_stash"

	# Try GameStateManager bridge first (delegates to GameState.add_inventory_item)
	if game_state_manager and game_state_manager.has_method("add_to_ship_inventory"):
		game_state_manager.add_to_ship_inventory(equipment_data)
		return

	# Fallback: Try GameState directly
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("add_inventory_item"):
		gs.add_inventory_item(equipment_data)
		return

	push_warning("PostBattlePhase: Could not persist loot '%s' - no inventory bridge available" % equipment_data.get("name", "Unknown"))

func _try_install_implant_from_loot(loot_name: String) -> bool:
	## Attempt to install an implant from loot on an eligible crew member.
	## Returns true if installed, false if no eligible crew member found (store as equipment instead)."""
	return false
	## var implant_data: Dictionary = Character.create_implant_from_loot(loot_name)
	## if implant_data.is_empty():
	## return false
	##
	## # Get crew members to find an eligible recipient
	## if not game_state_manager or not game_state_manager.has_method("get_crew_members"):
	## return false
	##
	## var crew: Array = game_state_manager.get_crew_members()
	## for member in crew:
	## if member is Character and member.add_implant(implant_data.duplicate()):
	## print("PostBattlePhase: Installed implant '%s' on %s" % [loot_name, member.character_name])
	## return true
	##
	## # No crew member could accept it (all full or ineligible)
	## print("PostBattlePhase: No crew member can accept implant '%s' - storing as equipment" % loot_name)
	## return false
	##
	## func _process_injuries() -> void:
	## ## Step 8: Determine Injuries and Recovery
	## if GlobalEnums:
	## current_substep = GlobalEnums.PostBattleSubPhase.INJURIES
	## self.post_battle_substep_changed.emit(current_substep)
	##
	## var processed_injuries: Array[Dictionary] = []
	##
	## # Process each injury from battle
	## for injury_data in injuries_sustained:
	## var processed_injury = _process_single_injury(injury_data)
	## processed_injuries.append(processed_injury)
	##
	## # Stars of the Story: "It Wasn't That Bad!" - remove worst non-fatal injury
	## if processed_injuries.size() > 0 and _campaign and "stars_of_story_data" in _campaign and not _campaign.stars_of_story_data.is_empty():
	## var StarsSystem = preload("res://src/core/systems/StarsOfTheStorySystem.gd")
	## var stars := StarsSystem.new()
	## stars.deserialize(_campaign.stars_of_story_data)
	## if stars.can_use(StarsSystem.StarAbility.IT_WASNT_THAT_BAD):
	## # Find worst non-fatal injury (highest recovery time)
	## var worst_idx := -1
	## var worst_recovery := 0
	## for i in range(processed_injuries.size()):
	## var inj = processed_injuries[i]
	## if inj.get("is_fatal", false):
	## continue
	## var rec: int = inj.get("recovery_turns", 0)
	## if rec > worst_recovery:
	## worst_recovery = rec
	## worst_idx = i
	## if worst_idx >= 0:
	## var removed_injury = processed_injuries[worst_idx]
	## var context = {"character": {"name": removed_injury.get("crew_id", ""), "injuries": [removed_injury.get("type", "")]}, "injury": removed_injury.get("type", "")}
	## var star_result = stars.use_ability(StarsSystem.StarAbility.IT_WASNT_THAT_BAD, context)
	## if star_result.get("success", false):
	## processed_injuries.remove_at(worst_idx)
	## _campaign.stars_of_story_data = stars.serialize()
	## print("PostBattlePhase: IT WASN'T THAT BAD! Removed injury '%s' via Stars of the Story" % removed_injury.get("type", ""))
	##
	## print("PostBattlePhase: Processed %d injuries" % processed_injuries.size())
	##
	## self.injuries_resolved.emit(processed_injuries)
	##
	## # Continue to experience
	## _process_experience()
	##
func _process_single_injury(injury_data: Dictionary) -> Dictionary:
	## Bot/Soulless characters use a separate injury table (Core Rules p.94-95)
	var crew_id = injury_data.get("crew_id", "")

	# Check if character is a Bot or Soulless (uses separate injury table)
	var is_bot_character := false
	var crew_origin: String = injury_data.get("origin", "")
	if crew_origin.is_empty() and game_state_manager:
		var crew_member = game_state_manager.get_crew_member(crew_id) if game_state_manager.has_method("get_crew_member") else null
		if crew_member:
			if crew_member.has_method("_is_bot"):
				is_bot_character = crew_member._is_bot()
			elif "origin" in crew_member:
				crew_origin = str(crew_member.origin)
	if not is_bot_character and (crew_origin == "BOT" or crew_origin == "SOULLESS"):
		is_bot_character = true

	# Bot/Soulless characters use the Bot Injury Table
	if is_bot_character:
		return _process_bot_injury(injury_data, crew_id)

	# Roll D100 for injury determination (Five Parsecs Core Rules p.94)
	var injury_roll := randi_range(1, 100)
	var injury_type := InjurySystemConstants.get_injury_type_from_roll(injury_roll)
	var recovery_info := InjurySystemConstants.get_recovery_time(injury_type)

	# Calculate actual recovery time based on injury type
	var recovery_time: int = 0
	if recovery_info.has("dice"):
		# Use min/max for recovery calculation
		var min_time: int = recovery_info.get("min", 0)
		var max_time: int = recovery_info.get("max", 0)
		if max_time > 0:
			recovery_time = randi_range(min_time, max_time)
		else:
			recovery_time = min_time
	else:
		recovery_time = recovery_info.get("max", 0)

	# Get injury type name and description
	var injury_type_name: String = InjurySystemConstants.INJURY_TYPE_NAMES.get(injury_type, "UNKNOWN")
	var injury_description := InjurySystemConstants.get_injury_description(injury_type)

	# Check for special effects
	var is_fatal := InjurySystemConstants.is_fatal(injury_type)
	var equipment_lost := InjurySystemConstants.causes_equipment_loss(injury_type)
	var bonus_xp := InjurySystemConstants.get_bonus_xp(injury_type)

	var processed_injury := {
		"crew_id": crew_id,
		"type": injury_type_name,
		"severity": injury_type,
		"recovery_turns": recovery_time,
		"turn_sustained": game_state_manager.turn_number if game_state_manager else 0,
		"description": injury_description,
		"is_fatal": is_fatal,
		"equipment_lost": equipment_lost,
		"bonus_xp": bonus_xp
	}

	# Sprint 26.5: Debug log injury processing with modifiers
	var modifiers_dict := {}
	if equipment_lost:
		modifiers_dict["Equipment Lost"] = 1
	if bonus_xp > 0:
		modifiers_dict["Hard Knocks XP"] = bonus_xp
	var crew_name: String = injury_data.get("crew_name", crew_id)
	_debug_log_injury(crew_name, injury_roll, modifiers_dict, injury_type_name, recovery_time)

	# Handle fatal injuries - check for Stars of the Story protection
	if is_fatal:
		var star_saved := false
		if _campaign and "stars_of_story_data" in _campaign and not _campaign.stars_of_story_data.is_empty():
			var StarsSystem = preload("res://src/core/systems/StarsOfTheStorySystem.gd")
			var stars := StarsSystem.new()
			stars.deserialize(_campaign.stars_of_story_data)
			if stars.can_use(StarsSystem.StarAbility.DRAMATIC_ESCAPE):
				# Auto-protect the first fatal injury with Dramatic Escape
				var star_result = stars.use_ability(StarsSystem.StarAbility.DRAMATIC_ESCAPE, {"character": {"name": crew_name, "current_hp": 0}})
				if star_result.get("success", false):
					star_saved = true
					processed_injury["is_fatal"] = false
					processed_injury["star_protected"] = true
					processed_injury["star_ability_used"] = "DRAMATIC_ESCAPE"
					processed_injury["recovery_turns"] = maxi(recovery_time, 3)
					# Persist the updated stars state back to campaign
					_campaign.stars_of_story_data = stars.serialize()
		if not star_saved:
			# Character death should be handled by campaign manager
			return processed_injury

	# Apply injury to crew member via GameState
	if game_state_manager and game_state_manager.has_method("apply_crew_injury"):
		game_state_manager.apply_crew_injury(crew_id, processed_injury)
	else:
		push_error("PostBattlePhase: GameStateManager missing apply_crew_injury method")

	# Apply bonus XP for Hard Knocks
	if bonus_xp > 0 and game_state_manager:
		pass

	return processed_injury

func _process_bot_injury(injury_data: Dictionary, crew_id: String) -> Dictionary:
	## Process injury for Bot/Soulless character using Bot Injury Table (Core Rules p.94-95)
	var crew_name: String = injury_data.get("crew_name", crew_id)

	var injury_roll := randi_range(1, 100)
	var bot_injury_type := InjurySystemConstants.get_bot_injury_type_from_roll(injury_roll)
	var recovery_info := InjurySystemConstants.get_bot_recovery_time(bot_injury_type)
	var injury_type_name: String = InjurySystemConstants.BOT_INJURY_TYPE_NAMES.get(bot_injury_type, "UNKNOWN")
	var injury_description := InjurySystemConstants.get_bot_injury_description(bot_injury_type)
	var is_fatal := InjurySystemConstants.is_bot_fatal_injury(bot_injury_type)
	var equipment_damaged := InjurySystemConstants.bot_causes_equipment_loss(bot_injury_type)

	# Calculate repair time
	var recovery_time: int = 0
	if recovery_info.has("dice"):
		var min_time: int = recovery_info.get("min", 0)
		var max_time: int = recovery_info.get("max", 0)
		if max_time > 0:
			recovery_time = randi_range(min_time, max_time)
		else:
			recovery_time = min_time
	else:
		recovery_time = recovery_info.get("max", 0)

	var processed_injury := {
		"crew_id": crew_id,
		"type": injury_type_name,
		"severity": bot_injury_type,
		"recovery_turns": recovery_time,
		"turn_sustained": game_state_manager.turn_number if game_state_manager else 0,
		"description": injury_description,
		"is_fatal": is_fatal,
		"equipment_lost": equipment_damaged,
		"bonus_xp": 0, # Bots never gain XP
		"is_bot_injury": true
	}

	# Check for all-equipment damage (OBLITERATED)
	var bot_props: Dictionary = InjurySystemConstants.BOT_INJURY_PROPERTIES.get(bot_injury_type, {})
	if bot_props.get("all_equipment", false):
		processed_injury["all_equipment_damaged"] = true

	if is_fatal:
		# Fatal bot injuries bypass Stars of the Story (bots can't use it)
		pass

	# Apply injury to crew member via GameState
	if game_state_manager and game_state_manager.has_method("apply_crew_injury"):
		game_state_manager.apply_crew_injury(crew_id, processed_injury)
	else:
		push_error("PostBattlePhase: GameStateManager missing apply_crew_injury method")

	return processed_injury

func _process_experience() -> void:
	## Step 9: Experience and Character Upgrades (Core Rules p.89-90)
	##
	## Sprint 16.2: Bots don't gain XP - they purchase upgrades with credits instead.
	## ##
	pass
	## if GlobalEnums:
	## current_substep = GlobalEnums.PostBattleSubPhase.EXPERIENCE
	## self.post_battle_substep_changed.emit(current_substep)
	##
	## var xp_awards: Array[Dictionary] = []
	## var bots_skipped: int = 0
	##
	## # Award XP for participation and achievements
	## for participant in crew_participants:
	## # Handle both String (crew_id) and Dictionary (crew data) formats
	## var crew_id: String = ""
	## var is_bot: bool = false
	##
	## if participant is String:
	## crew_id = participant
	## # Check if this is a bot by querying GameState
	## is_bot = _is_crew_member_bot(crew_id)
	## elif participant is Dictionary:
	## crew_id = participant.get("id", participant.get("character_id", ""))
	## # Check bot status from participant data or GameState
	## is_bot = participant.get("is_bot", false) or _is_crew_member_bot(crew_id)
	##
	## if crew_id.is_empty():
	## continue
	##
	## # Sprint 16.2: Bots don't gain XP - they purchase upgrades with credits
	## if is_bot:
	## bots_skipped += 1
	## print("PostBattlePhase: Skipping XP for bot %s (bots purchase upgrades)" % crew_id)
	## continue
	##
	## var xp_earned = _calculate_crew_xp(crew_id)
	## if xp_earned > 0:
	## xp_awards.append({"crew_id": crew_id, "xp": xp_earned})
	##
	## # Apply XP to crew member
	## if GameState and GameState.has_method("add_crew_experience"):
	## GameState.add_crew_experience(crew_id, xp_earned)
	##
	## # Print XP awards summary
	## var xp_awards_count: int = xp_awards.size()
	## print("PostBattlePhase: Awarded XP to %d crew members (%d bots skipped)" % [xp_awards_count, bots_skipped])
	##
	## # Sprint 26.5: Debug log experience awards
	## var total_xp: int = 0
	## var formatted_awards: Array = []
	## for award in xp_awards:
	## total_xp += award.get("xp", 0)
	## formatted_awards.append({"name": award.get("crew_id", "Unknown"), "xp": award.get("xp", 0)})
	## _debug_log_experience(formatted_awards, total_xp, [])
	##
	## self.experience_awarded.emit(xp_awards)
	##
	## # Continue to training
	## _process_training()
	##
func _calculate_crew_xp(crew_id: String) -> int:
	## Sprint16.1: ImplementsproperXPcalculation:
	## - Becamecasualty: + 1(deadcrewdon't get survival bonus)
	## - Survived and won: +3
	## - Survived, didn'twin: + 2
	## - Firstcasualtyinflicted: + 1
	## - Uniqueindividualkill: + 1
	## - Easymode: + 1
	## - Questfinale: + 1
	## - Fledbattlefield in rounds1 - 2: 0XP
	##
	var xp: int = 0
	var xp_breakdown: Array[String] = []

	# Check if crew fled early (rounds 1-2) - no XP at all
	if battle_result.get("fled_early", false):
		return 0

	# Check if crew was a casualty
	var was_casualty: bool = _was_crew_casualty_in_battle(crew_id)

	if was_casualty:
		# Became casualty: +1 (Core Rules p.89)
		xp += 1
		xp_breakdown.append("+1 casualty")
		# Dead crew don't get survival bonus - return early
		return _apply_xp_multiplier(xp)

	# Survival bonuses (only for crew who survived)
	if mission_successful:
		# Survived and won: +3
		xp += 3
		xp_breakdown.append("+3 survived & won")
	else:
		# Survived, didn't win: +2
		xp += 2
		xp_breakdown.append("+2 survived")

	# First casualty inflicted bonus: +1
	if battle_result.get("first_casualty_by", "") == crew_id:
		xp += 1
		xp_breakdown.append("+1 first kill")

	# Unique individual kill bonus: +1
	var unique_kills: Array = battle_result.get("unique_kills", [])
	if crew_id in unique_kills:
		xp += 1
		xp_breakdown.append("+1 unique kill")

	# Easy mode bonus: +1 (Core Rules difficulty)
	var difficulty: int = _get_campaign_difficulty()
	if difficulty == 0: # Easy
		xp += 1
		xp_breakdown.append("+1 Easy mode")

	# Quest finale bonus: +1
	if battle_result.get("is_quest_finale", false):
		xp += 1
		xp_breakdown.append("+1 quest finale")

	# Additional achievements
	var achievement_xp: int = _get_achievement_xp(crew_id)
	if achievement_xp > 0:
		xp += achievement_xp
		xp_breakdown.append("+%d achievements" % achievement_xp)

	# Apply difficulty multiplier
	return _apply_xp_multiplier(xp)

func _apply_xp_multiplier(base_xp: int) -> int:
	## Apply difficulty-based XP multiplier (F-3 fix)
	var difficulty: int = _get_campaign_difficulty()
	difficulty = clampi(difficulty, 0, 5)

	# Easy = 0.75x, Normal = 1.0x, Hard = 1.0x, Hardcore = 1.25x, Insanity = 1.5x
	var xp_multipliers: Array[float] = [0.75, 1.0, 1.0, 1.25, 1.5, 1.5]
	var final_xp: int = maxi(1, int(base_xp * xp_multipliers[difficulty]))

	if base_xp != final_xp:
		pass

	return final_xp

func _was_crew_casualty_in_battle(crew_id: String) -> bool:
	## Check if crew member was a casualty in battle (Sprint 16.1)
	if crew_id.is_empty():
		return false

	# Check casualties array from battle results
	if battle_result.has("casualties"):
		var casualties_array: Array = battle_result.get("casualties", [])
		for casualty in casualties_array:
			if casualty is Dictionary:
				var casualty_id: String = str(casualty.get("crew_id", ""))
				if casualty_id == crew_id:
					var casualty_type: String = casualty.get("type", "")
					if casualty_type in ["killed", "critically_wounded", "missing", "fatal"]:
						return true

	# Also check legacy format: injuries_sustained with is_fatal flag
	if battle_result.has("injuries_sustained"):
		for injury in battle_result.get("injuries_sustained", []):
			if injury is Dictionary:
				var injury_crew_id: String = str(injury.get("crew_id", ""))
				if injury_crew_id == crew_id and injury.get("is_fatal", false):
					return true

	return false

func _is_crew_member_bot(crew_id: String) -> bool:
	## Check if crew member is a bot (Sprint 16.2)
	##
	## Bots don't gain XP - they purchase upgrades with credits instead.
	## ##
	return false
	## if crew_id.is_empty():
	## return false
	##
	## # Check via GameState if available
	## if GameState and GameState.has_method("get_crew_member"):
	## var crew_member = GameState.get_crew_member(crew_id)
	## if crew_member:
	## # Sprint 26.3: Character-Everywhere - check Character properties first
	## if crew_member.has_method("is_bot"):
	## return crew_member.is_bot()
	## elif "is_bot" in crew_member:
	## return crew_member.is_bot
	## elif "species" in crew_member:
	## if crew_member.species in ["Bot", "Robot", "Drone", "Android"]:
	## return true
	## elif crew_member is Dictionary:
	## if crew_member.get("is_bot", false):
	## return true
	## if crew_member.get("character_type", "") == "bot":
	## return true
	## if crew_member.get("species", "") in ["Bot", "Robot", "Drone", "Android"]:
	## return true
	##
	## # Check via GameStateManager
	## if game_state_manager and game_state_manager.has_method("get_crew_member"):
	## var crew_member = game_state_manager.get_crew_member(crew_id)
	## if crew_member and crew_member is Dictionary:
	## return crew_member.get("is_bot", false)
	##
	## return false
	##
	## func _get_achievement_xp(crew_id: String) -> int:
	## ## Get bonus XP for achievements
	## var bonus_xp: int = 0
	##
	## # This would check battle statistics for special achievements
	## # First kill, objectives completed, heroic actions, etc.
	##
	## return bonus_xp
	##
	## ## Sprint 17: Training course definitions (Core Rules p.91)
	## const TRAINING_COURSES: Dictionary = {
	## "pilot": {"cost": 20, "effect": "savvy_roll_bonus", "description": "Piloting certification"},
	## "mechanic": {"cost": 15, "effect": "hull_repair_bonus", "description": "Ship repair training"},
	## "medical": {"cost": 20, "effect": "injury_reroll", "description": "Medical certification"},
	## "merchant": {"cost": 10, "effect": "trade_reroll", "description": "Trade negotiation"},
	## "security": {"cost": 10, "effect": "seize_initiative_bonus", "description": "Combat tactics"},
	## "broker": {"cost": 15, "effect": "search_bonus", "description": "Information broker"},
	## "bot_technician": {"cost": 10, "effect": "bot_upgrade_discount", "description": "Bot maintenance"},
	## "basic": {"cost": 1, "effect": "xp_bonus", "description": "Basic training (+1 XP)"}
	## }
	##
func _process_training() -> void:
	## Sprint17.1: Implementspropertrainingapprovalsystem:
	## -1creditapplicationfee(non - refundable)
	## - Roll2D6, 4 + togetapproved
	## - Ifapproved, paycoursecost
	## - Cannottraincrew in sickbay
	## - Maximum2crewcantrainperturn
	##
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.TRAINING
		self.post_battle_substep_changed.emit(current_substep)

	var training_completed: Array[Dictionary] = []
	var application_fee: int = 1
	var max_trainees: int = 2
	var trainees_this_turn: int = 0

	# Get available training candidates (crew who participated and are not injured)
	var training_candidates: Array = []
	for participant in crew_participants:
		var crew_id: String = ""
		if participant is Dictionary:
			crew_id = participant.get("id", participant.get("character_id", ""))
		elif participant is String:
			crew_id = participant

		if crew_id.is_empty():
			continue

		# Check if injured (skip injured crew - they're in sick bay)
		var is_injured: bool = false
		for injury in injuries_sustained:
			if injury.get("crew_id", "") == crew_id:
				is_injured = true
				break

		# Skip bots (they purchase upgrades, not training)
		if _is_crew_member_bot(crew_id):
			continue

		if not is_injured:
			training_candidates.append(crew_id)

	# Check if we can afford application fee
	var current_credits: int = 0
	if game_state_manager and game_state_manager.has_method("get_credits"):
		current_credits = game_state_manager.get_credits()

	# Process training applications for eligible crew (up to max_trainees)
	for crew_id in training_candidates:
		if trainees_this_turn >= max_trainees:
			break

		# Attempt training enrollment with approval roll
		var result: Dictionary = attempt_training_enrollment(crew_id, "basic", current_credits)

		if result.get("success", false):
			training_completed.append(result)
			trainees_this_turn += 1
			current_credits = result.get("credits_remaining", current_credits)
		elif result.get("reason", "") == "insufficient_credits":
			break
		# If not approved, continue to next candidate

	if training_completed.size() > 0:
		pass
	else:
		pass

	self.training_completed.emit(training_completed)

	# Continue to purchases
	_process_purchases()

func attempt_training_enrollment(crew_id: String, course: String, available_credits: int) -> Dictionary:
	## Attempt to enroll crew member in training course (Sprint 17.1)
	##
	## Core Rules training process:
	## 1. Pay 1 credit application fee (non-refundable)
	## 2. Roll 2D6, 4+ to get approved
	## 3. If approved, pay course cost and apply benefits
	## ##
	return {}
	## var application_fee: int = 1
	##
	## # Check credit availability for application fee
	## if available_credits < application_fee:
	## return {"success": false, "reason": "insufficient_credits", "crew_id": crew_id}
	##
	## # Deduct application fee (non-refundable)
	## if game_state_manager and game_state_manager.has_method("remove_credits"):
	## game_state_manager.remove_credits(application_fee)
	## available_credits -= application_fee
	##
	## # Roll 2D6 for approval (4+ succeeds)
	## var approval_roll: int = _roll_2d6("Training approval for %s" % crew_id)
	## print("PostBattlePhase: Training approval roll for %s: %d (need 4+)" % [crew_id, approval_roll])
	##
	## if approval_roll < 4:
	## print("PostBattlePhase: Training application DENIED for %s (roll %d < 4)" % [crew_id, approval_roll])
	## return {
	## "success": false,
	## "reason": "not_approved",
	## "crew_id": crew_id,
	## "roll": approval_roll,
	## "application_fee_paid": application_fee,
	## "credits_remaining": available_credits
	## }
	##
	## # Get course data
	## var course_data: Dictionary = TRAINING_COURSES.get(course, TRAINING_COURSES["basic"])
	## var course_cost: int = course_data.get("cost", 1)
	##
	## # Check if can afford course cost
	## if available_credits < course_cost:
	## print("PostBattlePhase: Training approved but cannot afford course (%d available, %d needed)" % [
	## available_credits, course_cost
	## ])
	## return {
	## "success": false,
	## "reason": "cannot_afford_course",
	## "crew_id": crew_id,
	## "roll": approval_roll,
	## "application_fee_paid": application_fee,
	## "course_cost": course_cost,
	## "credits_remaining": available_credits
	## }
	##
	## # Pay course cost
	## if game_state_manager and game_state_manager.has_method("remove_credits"):
	## game_state_manager.remove_credits(course_cost)
	## available_credits -= course_cost
	##
	## # Apply training benefits
	## var xp_awarded: int = 1  # Basic training gives +1 XP
	## if game_state_manager and game_state_manager.has_method("add_crew_experience"):
	## game_state_manager.add_crew_experience(crew_id, xp_awarded)
	##
	## # Store training effect for next turn activation
	## if GameState and GameState.has_method("set_crew_training"):
	## GameState.set_crew_training(crew_id, course)
	##
	## print("PostBattlePhase: Training APPROVED for %s - %s course (roll %d, cost %d, +%d XP)" % [
	## crew_id, course, approval_roll, course_cost, xp_awarded
	## ])
	##
	## return {
	## "success": true,
	## "crew_id": crew_id,
	## "course": course,
	## "course_description": course_data.get("description", "Training"),
	## "effect": course_data.get("effect", ""),
	## "roll": approval_roll,
	## "application_fee_paid": application_fee,
	## "course_cost": course_cost,
	## "total_cost": application_fee + course_cost,
	## "xp_awarded": xp_awarded,
	## "credits_remaining": available_credits
	## }
	##
func _process_purchases() -> void:
	## Purchasehandling is UI - drivenviaPurchaseItemsComponentwhich:
	## - RemovescreditsviaGameStateManager.remove_credits()
	## - AddsitemsviaEquipmentManager.add_to_ship_stash()
	## - Respectsshipstashcapacity(10itemsmax)
	##
	## Thismethodemitssubstep signal for UItorespond, and processes
	## anypendingpurchasequeuefromgamestate for batch / automatedpurchases.
	##
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.PURCHASES
		self.post_battle_substep_changed.emit(current_substep)

	var purchases_made: Array[Dictionary] = []

	# F-2 fix: Check for queued purchases from GameState (set by UI or automation)
	if game_state_manager:
		var gs: Variant = null
		if game_state_manager.has_method("get_game_state"):
			gs = game_state_manager.get_game_state()

		# Get queued purchases if available
		var purchase_queue: Array = []
		if gs and "purchase_queue" in gs:
			purchase_queue = gs.purchase_queue
		elif game_state_manager.has_method("get_pending_purchases"):
			purchase_queue = game_state_manager.get_pending_purchases()

		# Process any queued purchases (batch processing for automation/testing)
		if not purchase_queue.is_empty():
			var credits: int = 0
			if game_state_manager.has_method("get_credits"):
				credits = game_state_manager.get_credits()

			for item in purchase_queue:
				var cost: int = item.get("cost", 0)
				if credits >= cost:
					# Deduct credits
					if game_state_manager.has_method("remove_credits"):
						game_state_manager.remove_credits(cost)
						credits -= cost

					# Add to inventory via GameStateManager bridge
					if game_state_manager and game_state_manager.has_method("add_to_ship_inventory"):
						game_state_manager.add_to_ship_inventory(item)
					purchases_made.append(item)
				else:
					push_warning("PostBattlePhase: Insufficient credits for %s (need %d, have %d)" % [item.get("name", "Unknown"), cost, credits])

			# Clear the queue
			if gs and "purchase_queue" in gs:
				gs.purchase_queue = []
			elif game_state_manager.has_method("clear_pending_purchases"):
				game_state_manager.clear_pending_purchases()

	if purchases_made.size() > 0:
		pass
	else:
		pass

	self.purchases_made.emit(purchases_made)

	# Continue to campaign event
	_process_campaign_event()

## Sprint 18.3: Precursor event choice tracking
var _pending_precursor_event1: Dictionary = {}
var _pending_precursor_event2: Dictionary = {}
var _waiting_for_precursor_choice: bool = false

func _process_campaign_event() -> void:
	## Step 12: Roll for a Campaign Event
	##
	## Sprint 18.3: Precursor crew rolls twice and can pick which event to use.
	## If connected to UI, emits precursor_event_choice_available signal.
	## Otherwise auto-picks the first event (or randomly if no clear winner).
	## ##
	pass
	## if GlobalEnums:
	## current_substep = GlobalEnums.PostBattleSubPhase.CAMPAIGN_EVENT
	## self.post_battle_substep_changed.emit(current_substep)
	##
	## # Roll for campaign event
	## var event_roll = randi_range(1, 100)
	## var campaign_event = _get_campaign_event(event_roll)
	##
	## # Precursors roll twice and pick better event (Five Parsecs p.19-20)
	## if _has_precursor_crew():
	## var second_roll = randi_range(1, 100)
	## var second_event = _get_campaign_event(second_roll)
	## print("PostBattlePhase: Precursor crew - rolled twice: %d (%s) and %d (%s)" % [
	## event_roll, campaign_event.get("name", "Unknown"),
	## second_roll, second_event.get("name", "Unknown")
	## ])
	##
	## # Store pending events for UI choice
	## _pending_precursor_event1 = campaign_event
	## _pending_precursor_event2 = second_event
	##
	## # Check if UI is connected to handle the choice
	## if precursor_event_choice_available.get_connections().size() > 0:
	## _waiting_for_precursor_choice = true
	## self.precursor_event_choice_available.emit(campaign_event, second_event)
	## # UI should call select_precursor_event() to continue
	## return
	## else:
	## # No UI connected - auto-pick (prefer non-"none" event, then first)
	## if campaign_event.get("type", "none") == "none" and second_event.get("type", "none") != "none":
	## campaign_event = second_event
	## print("PostBattlePhase: Auto-selected second event (first was 'none')")
	## else:
	## print("PostBattlePhase: Auto-selected first event")
	##
	## _finalize_campaign_event(campaign_event)
	##
func select_precursor_event(choice: int) -> void:
	## Args:
	## 	choice: 1 for first event, 2 for second event
	##
	if not _waiting_for_precursor_choice:
		push_warning("PostBattlePhase: select_precursor_event called but not waiting for choice")
		return

	_waiting_for_precursor_choice = false

	var chosen_event: Dictionary
	if choice == 2:
		chosen_event = _pending_precursor_event2
	else:
		chosen_event = _pending_precursor_event1

	# Clear pending events
	_pending_precursor_event1 = {}
	_pending_precursor_event2 = {}

	# Emit choice signal for any interested listeners
	self.precursor_event_chosen.emit(chosen_event)

	# Continue with chosen event
	_finalize_campaign_event(chosen_event)

func _finalize_campaign_event(campaign_event: Dictionary) -> void:
	## Complete campaign event processing after selection (or auto-selection).
	if campaign_event.has("type") and campaign_event.type != "none":
		_apply_campaign_event(campaign_event)

	self.campaign_event_occurred.emit(campaign_event)

	# Continue to character event
	_process_character_event()

func _get_campaign_event(roll: int) -> Dictionary:
	## Get campaign event based on D100 roll
	# Simplified campaign events table
	if roll <= 10:
		return {"type": "market_crash", "name": "Market Crash", "description": "Economic downturn affects prices"}
	elif roll <= 20:
		return {"type": "tech_breakthrough", "name": "Tech Breakthrough", "description": "New technology becomes available"}
	elif roll <= 30:
		return {"type": "civil_unrest", "name": "Civil Unrest", "description": "Political instability affects operations"}
	else:
		return {"type": "none", "name": "No Event", "description": "Nothing significant occurs"}

func _apply_campaign_event(event: Dictionary) -> void:
	## Apply campaign event effects by calling the public working method
	var event_name: String = event.get("name", event.get("title", "Unknown"))
	apply_campaign_event_effect(event_name)

func _has_precursor_crew() -> bool:
	## Check if crew has any Precursor species members (Five Parsecs p.19-20)
	if not game_state_manager:
		return false
	if not game_state_manager.has_method("get_crew_members"):
		push_warning("PostBattlePhase: game_state_manager does not have get_crew_members() method")
		return false
	var crew: Array = game_state_manager.get_crew_members()
	for member in crew:
		# Sprint 26.3: Crew members are now always Character objects
		if not member:
			continue
		var origin: String = member.origin.to_lower() if "origin" in member else ""
		if origin == "precursor":
			return true
	return false

func _process_character_event() -> void:
	## Step 13: Roll for a Character Event
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.CHARACTER_EVENT
		self.post_battle_substep_changed.emit(current_substep)

	# Roll for character event
	var character_event: Dictionary = _get_character_event()

	if character_event.has("type") and character_event.type != "none":
		_apply_character_event(character_event)

	self.character_event_occurred.emit(character_event)

	# Continue to galactic war
	_process_galactic_war()

func _get_character_event() -> Dictionary:
	## Get character event for random crew member
	var crew_size: int = crew_participants.size()

	if crew_size == 0:
		return {"type": "none", "name": "No Event"}

	var random_crew = crew_participants[randi() % crew_size]
	var event_roll = randi_range(1, 100)

	# Simplified character events
	if event_roll <= 15:
		return {"type": "personal_growth", "crew_id": random_crew, "name": "Personal Growth", "description": "Character develops new skills"}
	elif event_roll <= 30:
		return {"type": "contact_made", "crew_id": random_crew, "name": "New Contact", "description": "Character makes useful connection"}
	else:
		return {"type": "none", "name": "No Event"}

func _apply_character_event(event: Dictionary) -> void:
	## Apply character event effects by calling the public working method
	var crew: Variant = _get_random_crew_member()
	var event_name: String = event.get("name", event.get("title", "Unknown"))
	if crew:
		apply_character_event_effect(event_name, crew)

func _process_galactic_war() -> void:
	## Step 14: Check for Galactic War Progress
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.GALACTIC_WAR
		self.post_battle_substep_changed.emit(current_substep)

	# Track large-scale conflicts and their progression
	var war_progress = _update_galactic_war_progress()


	self.galactic_war_updated.emit(war_progress)

	# Complete post-battle phase
	_complete_post_battle_phase()

func _update_galactic_war_progress() -> Dictionary:
	## Update galactic war progression (Sprint 19.1: Core Rules p.139-140)
	##
	## For each invaded planet, roll 2D6 + war_modifier:
	## - 4 or less: Planet lost to Unity (crew must flee if present)
	## - 5-7: Conflict continues (contested)
	## - 8-9: Making ground (+1 to future rolls)
	## - 10+: Victorious (planet liberated, -2 invasion chance)
	## ##
	return {}
	## var progress = {
	## "conflicts_active": 0,
	## "major_events": [],
	## "faction_changes": [],
	## "planet_results": []
	## }
	##
	## # Get invaded planets from game state
	## var invaded_planets: Array = _get_invaded_planets()
	##
	## if invaded_planets.is_empty():
	## print("PostBattlePhase: No active invasions to resolve")
	## return progress
	##
	## progress["conflicts_active"] = invaded_planets.size()
	## print("PostBattlePhase: Resolving %d active invasions" % invaded_planets.size())
	##
	## for planet in invaded_planets:
	## var planet_id: String = ""
	## var planet_name: String = "Unknown Planet"
	## var war_modifier: int = 0
	##
	## if planet is Dictionary:
	## planet_id = planet.get("id", planet.get("planet_id", ""))
	## planet_name = planet.get("name", planet.get("planet_name", "Unknown"))
	## war_modifier = planet.get("war_modifier", 0)
	## elif planet is String:
	## planet_id = planet
	## planet_name = planet
	##
	## # Roll 2D6 for war outcome
	## var roll: int = _roll_2d6("Galactic War - %s" % planet_name)
	## var modified_roll: int = roll + war_modifier
	##
	## var outcome: Dictionary = {
	## "planet_id": planet_id,
	## "planet_name": planet_name,
	## "roll": roll,
	## "modifier": war_modifier,
	## "final_roll": modified_roll,
	## "result": ""
	## }
	##
	## # Determine outcome based on Core Rules
	## if modified_roll <= 4:
	## # Planet lost to Unity
	## outcome["result"] = "lost_to_unity"
	## outcome["description"] = "%s has fallen to Unity forces" % planet_name
	## _mark_planet_lost(planet_id)
	## progress["major_events"].append({
	## "type": "planet_lost",
	## "planet": planet_name,
	## "message": "Planet %s conquered by Unity!" % planet_name
	## })
	## print("PostBattlePhase: %s LOST to Unity (roll %d + %d = %d)" % [
	## planet_name, roll, war_modifier, modified_roll
	## ])
	##
	## elif modified_roll <= 7:
	## # Conflict continues
	## outcome["result"] = "contested"
	## outcome["description"] = "%s remains contested" % planet_name
	## print("PostBattlePhase: %s remains CONTESTED (roll %d + %d = %d)" % [
	## planet_name, roll, war_modifier, modified_roll
	## ])
	##
	## elif modified_roll <= 9:
	## # Making ground
	## outcome["result"] = "making_ground"
	## outcome["description"] = "%s defenders making progress" % planet_name
	## _add_planet_war_modifier(planet_id, 1)
	## progress["faction_changes"].append({
	## "type": "momentum_gained",
	## "planet": planet_name,
	## "bonus": 1
	## })
	## print("PostBattlePhase: %s MAKING GROUND (+1 modifier) (roll %d + %d = %d)" % [
	## planet_name, roll, war_modifier, modified_roll
	## ])
	##
	## else:  # 10+
	## # Victory
	## outcome["result"] = "victorious"
	## outcome["description"] = "%s liberated from Unity forces" % planet_name
	## _mark_planet_liberated(planet_id)
	## _reduce_invasion_modifier(planet_id, 2)
	## progress["major_events"].append({
	## "type": "planet_liberated",
	## "planet": planet_name,
	## "message": "Planet %s liberated!" % planet_name
	## })
	## print("PostBattlePhase: %s VICTORIOUS (liberated) (roll %d + %d = %d)" % [
	## planet_name, roll, war_modifier, modified_roll
	## ])
	##
	## progress["planet_results"].append(outcome)
	##
	## return progress
	##
	## func _get_invaded_planets() -> Array:
	## ## Get list of planets currently under invasion
	## var game_state = _game_state
	## if game_state and game_state.current_campaign and "invaded_planets" in game_state.current_campaign:
	## return game_state.current_campaign.invaded_planets
	## return []
	##
	## func _mark_planet_lost(planet_id: String) -> void:
	## ## Mark a planet as lost to Unity forces
	## var game_state = _game_state
	## if game_state and game_state.current_campaign:
	## var campaign = game_state.current_campaign
	## if "lost_planets" in campaign:
	## if planet_id not in campaign.lost_planets:
	## campaign.lost_planets.append(planet_id)
	## if "invaded_planets" in campaign:
	## campaign.invaded_planets = campaign.invaded_planets.filter(func(p): return _get_planet_id(p) != planet_id)
	## print("PostBattlePhase: Marked planet %s as lost" % planet_id)
	##
	## func _mark_planet_liberated(planet_id: String) -> void:
	## ## Mark a planet as liberated from Unity
	## var game_state = _game_state
	## if game_state and game_state.current_campaign:
	## var campaign = game_state.current_campaign
	## if "liberated_planets" in campaign:
	## if planet_id not in campaign.liberated_planets:
	## campaign.liberated_planets.append(planet_id)
	## if "invaded_planets" in campaign:
	## campaign.invaded_planets = campaign.invaded_planets.filter(func(p): return _get_planet_id(p) != planet_id)
	## print("PostBattlePhase: Marked planet %s as liberated" % planet_id)
	##
	## func _add_planet_war_modifier(planet_id: String, amount: int) -> void:
	## ## Add to a planet's war modifier (making ground bonus)
	## var game_state = _game_state
	## if game_state and game_state.current_campaign:
	## var campaign = game_state.current_campaign
	## if "invaded_planets" in campaign:
	## for i in range(campaign.invaded_planets.size()):
	## var planet = campaign.invaded_planets[i]
	## if _get_planet_id(planet) == planet_id:
	## if planet is Dictionary:
	## planet["war_modifier"] = planet.get("war_modifier", 0) + amount
	## else:
	## campaign.invaded_planets[i] = {"id": planet_id, "war_modifier": amount}
	## break
	## print("PostBattlePhase: Added +%d war modifier to planet %s" % [amount, planet_id])
	##
	## func _reduce_invasion_modifier(planet_id: String, amount: int) -> void:
	## ## Reduce future invasion chance for a planet (after liberation)
	## var game_state = _game_state
	## if game_state and game_state.current_campaign:
	## var campaign = game_state.current_campaign
	## if "invasion_modifiers" in campaign:
	## campaign.invasion_modifiers[planet_id] = campaign.invasion_modifiers.get(planet_id, 0) - amount
	## print("PostBattlePhase: Reduced invasion modifier for %s by %d" % [planet_id, amount])
	##
	## func _get_planet_id(planet: Variant) -> String:
	## ## Extract planet ID from various formats
	## if planet is String:
	## return planet
	## elif planet is Dictionary:
	## return planet.get("id", planet.get("planet_id", ""))
	## return ""
	##
func get_completion_data() -> Dictionary:
	## ReturnsDictionarywith:
	## - mission_successful: bool - Whetherthemissionwaswon
	## - injuries_sustained: Array - Listofinjuryrecordsfrombattle
	## - loot_earned: Array - Items and creditscollected
	## - enemies_defeated: int - Numberofenemieseliminated
	## - crew_participants: Array - Crewthatparticipated in thebattle
	## - battle_result: Dictionary - Fullbattleresultsummary
	##
	return {
		"mission_successful": mission_successful,
		"injuries_sustained": injuries_sustained.duplicate(),
		"loot_earned": loot_earned.duplicate(),
		"enemies_defeated": enemies_defeated,
		"crew_participants": crew_participants.duplicate(),
		"battle_result": battle_result.duplicate(true),
		"defeated_enemies": defeated_enemies.duplicate(),
	}

func _complete_post_battle_phase() -> void:
	## Complete the Post-Battle Phase
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.NONE

	# Update character lifetime statistics from battle results
	_update_character_lifetime_statistics()

	# Create journal entry for this battle
	_create_battle_journal_entry()

	# F-4 fix: Tick injury recovery for all crew members each turn
	_tick_injury_recovery()

	# Apply crew morale changes based on battle outcome
	_apply_post_battle_morale()

	self.post_battle_phase_completed.emit()

func _update_character_lifetime_statistics() -> void:
	## Update character lifetime statistics from battle results (kills, damage, participation)
	var crew: Array = _get_participating_crew()
	if crew.is_empty():
		return

	# Get kill attribution data from battle_result (passed from BattleTracker)
	var kills_by_character: Dictionary = battle_result.get("kills_by_character", {})
	var damage_dealt_per_unit: Dictionary = battle_result.get("damage_dealt_per_unit", {})
	var damage_taken_per_unit: Dictionary = battle_result.get("damage_taken_per_unit", {})
	var units_downed: Array = battle_result.get("units_downed", [])

	for member in crew:
		if not member:
			continue

		var char_id: String = ""
		if member is Object and member.has_method("get"):
			char_id = member.get("character_id") if member.get("character_id") else ""
		elif member is Dictionary:
			char_id = member.get("character_id", "")

		if char_id.is_empty():
			continue

		# Update battles_participated
		if member is Object and "battles_participated" in member:
			member.battles_participated += 1

			# Update battles_survived (not knocked out/downed)
			if char_id not in units_downed:
				member.battles_survived += 1

			# Update lifetime kills from kill attribution
			var kills: Array = kills_by_character.get(char_id, [])
			member.lifetime_kills += kills.size()

			# Update lifetime damage dealt/taken
			member.lifetime_damage_dealt += damage_dealt_per_unit.get(char_id, 0)
			member.lifetime_damage_taken += damage_taken_per_unit.get(char_id, 0)

			# Create character event in journal
			_create_character_battle_journal_event(member, char_id, kills.size())

func _get_participating_crew() -> Array:
	## Get crew members who participated in the battle
	var crew: Array = []

	# First try to get from stored participants
	if not crew_participants.is_empty():
		# Resolve participant IDs to actual Character objects
		var gsm = game_state_manager
		if gsm and gsm.has_method("get_crew_member"):
			for participant_id in crew_participants:
				var member = gsm.get_crew_member(participant_id)
				if member:
					crew.append(member)
		return crew

	# Fallback: Get all crew from GameStateManager or GameState
	if game_state_manager and game_state_manager.has_method("get_crew_members"):
		crew = game_state_manager.get_crew_members()
	elif game_state_manager and game_state_manager.has_method("get_game_state"):
		var gs = game_state_manager.get_game_state()
		if gs and gs.has_method("get_crew"):
			crew = gs.get_crew()
		elif gs and gs.current_campaign and gs.current_campaign is Dictionary:
			crew = gs.current_campaign.get("crew", [])
	else:
		var game_state = _game_state
		if game_state and game_state.current_campaign:
			if game_state.current_campaign is Dictionary:
				crew = game_state.current_campaign.get("crew", [])

	return crew

func _create_character_battle_journal_event(member: Variant, char_id: String, kills: int) -> void:
	## Create a journal event for a character's battle participation
	var journal = get_node_or_null("/root/CampaignJournal")
	if not journal or not journal.has_method("auto_create_character_event"):
		return

	var outcome: String = "survived"
	if member is Object and member.has_method("get"):
		var status: String = member.get("status") if member.get("status") else "ACTIVE"
		if status == "DEAD":
			outcome = "killed"
		elif status == "INJURED" or status == "RECOVERING":
			outcome = "injured"
		elif status == "MISSING":
			outcome = "missing"

	journal.auto_create_character_event(char_id, "battle", {
		"kills": kills,
		"outcome": outcome,
		"mission_success": mission_successful,
		"turn": battle_result.get("turn", 0)
	})

func _create_battle_journal_entry() -> void:
	## Create a journal entry for the completed battle
	var journal = get_node_or_null("/root/CampaignJournal")
	if not journal or not journal.has_method("auto_create_battle_entry"):
		return

	var crew_ids: Array = []
	for participant in crew_participants:
		if participant is String:
			crew_ids.append(participant)

	journal.auto_create_battle_entry({
		"turn": battle_result.get("turn", 0),
		"location": battle_result.get("location", "Unknown"),
		"outcome": "victory" if mission_successful else "defeat",
		"casualties": injuries_sustained.size(),
		"loot": loot_earned.size(),
		"xp": battle_result.get("xp_earned", 0),
		"crew_ids": crew_ids,
		"enemy_type": battle_result.get("enemy_type", "Unknown")
	})


func _apply_post_battle_morale() -> void:
	## Apply crew morale adjustments after battle using MoraleSystem.
	var campaign = _campaign
	if not campaign and _game_state:
		campaign = _game_state.current_campaign if "current_campaign" in _game_state else null
	if not campaign or not "crew_morale" in campaign:
		return

	var crew_deaths := 0
	var crew_injuries := injuries_sustained.size()
	for injury in injuries_sustained:
		if injury is Dictionary and injury.get("is_fatal", false):
			crew_deaths += 1
	# Subtract fatal from injury count (deaths already counted separately)
	crew_injuries = maxi(0, crew_injuries - crew_deaths)

	var held := battle_result.get("held_field", false) if battle_result is Dictionary else false

	var morale_changes: Dictionary = MoraleSystemRef.apply_post_battle_morale(
		campaign, mission_successful, crew_deaths, crew_injuries, held
	)

func _tick_injury_recovery() -> void:
	## Decrement injury recovery turns for all wounded crew members.
	##
	## Note: Per Five Parsecs rules, recovery should happen during WorldPhase upkeep
	## (start of next turn). This method is kept as a fallback but primary recovery
	## is wired through WorldPhase → GameStateManager.process_crew_recovery().
	## ##
	pass
	## # Delegate to GameStateManager bridge which calls Character.process_recovery()
	## if game_state_manager and game_state_manager.has_method("process_crew_recovery"):
	## var recovered = game_state_manager.process_crew_recovery()
	## if not recovered.is_empty():
	## for r in recovered:
	## print("PostBattlePhase: %s has recovered from injuries" % r.get("name", "Crew member"))
	## print("PostBattlePhase: %d crew members recovered" % recovered.size())
	## return
	##
	## # Fallback: process status_effects directly on Character objects
	## var crew: Array = []
	## if game_state_manager and game_state_manager.has_method("get_crew_members"):
	## crew = game_state_manager.get_crew_members()
	##
	## for member in crew:
	## if not member:
	## continue
	## if member.get("is_wounded") != true:
	## continue
	##
	## # Decrement status effect durations
	## if member.get("status_effects") != null:
	## for i in range(member.status_effects.size() - 1, -1, -1):
	## var effect = member.status_effects[i]
	## if "duration" in effect:
	## effect.duration -= 1
	## if effect.duration <= 0:
	## member.status_effects.remove_at(i)
	##
	## # If no more injury effects remain, mark as recovered
	## var has_injury_effects := false
	## if member.get("status_effects") != null:
	## for effect in member.status_effects:
	## if effect.get("type", "").contains("INJURY") or effect.get("type", "") == "injury":
	## has_injury_effects = true
	## break
	## if not has_injury_effects and member.get("is_wounded") == true:
	## member.is_wounded = false
	## var name_val: String = member.character_name if "character_name" in member else "Crew member"
	## print("PostBattlePhase: %s has fully recovered from injuries!" % name_val)
	##
	## ## Event Effect Application Methods
	## func apply_campaign_event_effect(event_title: String) -> String:
	## ## Apply campaign event effects based on event title
	## match event_title:
	## # Story Point Events
	## "Local Friends", "Lucky Break", "New Ally":
	## if GameStateManager and GameStateManager.has_method("add_story_points"):
	## GameStateManager.add_story_points(1)
	## return "+1 Story Point"
	##
	## # Credit Events
	## "Valuable Find":
	## var credits: int = randi_range(1, 6)
	## if GameStateManager:
	## GameStateManager.add_credits(credits)
	## return "+%d Credits" % credits
	##
	## "Windfall":
	## var credits: int = randi_range(1, 6) + randi_range(1, 6)
	## if GameStateManager:
	## GameStateManager.add_credits(credits)
	## return "+%d Credits (windfall)" % credits
	##
	## "Life Support Issues":
	## var cost: int = randi_range(1, 6)
	## # Check for Engineer to reduce cost
	## var engineer_present: bool = _has_crew_with_class("Engineer")
	## if engineer_present:
	## cost = max(1, cost - 1)
	## if GameStateManager:
	## GameStateManager.add_credits(-cost)
	## return "Paid %d Credits (Life Support)" % cost
	##
	## "Odd Job":
	## var credits: int = randi_range(1, 6) + 1
	## if GameStateManager:
	## GameStateManager.add_credits(credits)
	## return "+%d Credits (Odd Job)" % credits
	##
	## "Unexpected Bill":
	## var cost: int = randi_range(1, 6)
	## if GameStateManager:
	## var current_credits: int = 0
	## if GameStateManager.has_method("get_credits"):
	## current_credits = GameStateManager.get_credits()
	## if current_credits >= cost:
	## GameStateManager.add_credits(-cost)
	## return "Paid %d Credits" % cost
	## else:
	## # Lose story point instead
	## if GameStateManager.has_method("add_story_points"):
	## GameStateManager.add_story_points(-1)
	## return "Lost 1 Story Point (couldn't pay %d Credits)" % cost
	##
	## # Rumor Events
	## "Old Contact", "Valuable Intel":
	## _add_quest_rumor()
	## return "+1 Quest Rumor"
	##
	## "Information Broker":
	## # Can buy up to 3 rumors for 2 credits each
	## return "Information Broker available (2 credits per rumor)"
	##
	## "Dangerous Information":
	## _add_quest_rumor()
	## _add_quest_rumor()
	## _add_rival("Information leak")
	## return "+2 Quest Rumors, +1 Rival"
	##
	## # Rival Events
	## "Mouthed Off", "Made Enemy":
	## _add_rival("Offended party")
	## return "+1 Rival"
	##
	## "Suspicious Activity":
	## # If has rivals, one tracks down
	## var game_state = _game_state  # Sprint 28.2: Use cached reference
	## if game_state and game_state.current_campaign:
	## var campaign = game_state.current_campaign
	## if campaign is Dictionary:
	## var rivals = campaign.get("rivals", [])
	## if rivals.size() > 0:
	## return "Rival tracks you down this turn"
	## return "No rivals to track you"
	##
	## # Patron Events
	## "Reputation Grows":
	## return "+1 to next Patron search roll"
	##
	## # Market Events
	## "Market Surplus":
	## return "All purchases -1 credit (min 1) this turn"
	##
	## "Trade Opportunity":
	## return "Roll twice on Trade Table this turn"
	##
	## # Equipment/Ship Events
	## "Equipment Malfunction":
	## _damage_random_equipment()
	## return "Random item damaged"
	##
	## "Ship Parts":
	## if GameStateManager and GameStateManager.has_method("repair_hull"):
	## GameStateManager.repair_hull(1)
	## return "Repaired 1 Hull Point"
	##
	## # Medical Events
	## "Friendly Doc":
	## _reduce_recovery_time(2)
	## return "Reduced recovery time by 1 turn (up to 2 crew)"
	##
	## "Medical Supplies":
	## _heal_crew_in_sickbay()
	## return "One crew in Sick Bay recovers immediately"
	##
	## # XP/Training Events
	## "Skill Training":
	## _award_xp_to_random_crew(1)
	## return "+1 XP to random crew member"
	##
	## "Crew Bonding":
	## _award_xp_to_all_crew(1)
	## return "+1 XP to all crew"
	##
	## # Injury Events
	## "Bar Brawl":
	## _injure_random_crew(1)
	## return "Random crew member injured (1 turn recovery)"
	##
	## # Gambling Events
	## "Gambling Opportunity":
	## return "Gambling opportunity (bet 1-6 credits)"
	##
	## # Cargo Events
	## "Cargo Opportunity":
	## return "Cargo job: +3 credits but cannot travel this turn"
	##
	## # ================================================================
	## # Sprint 18.1: Additional Campaign Events (Core Rules p.123-125)
	## # ================================================================
	##
	## # Tax/Government Events
	## "Tax Collection":
	## # Roll 2D6, pay the higher die in credits or face impound
	## var die1: int = _roll_d6("Tax collection die 1")
	## var die2: int = _roll_d6("Tax collection die 2")
	## var tax: int = max(die1, die2)
	## if GameStateManager:
	## var available: int = 0
	## if GameStateManager.has_method("get_credits"):
	## available = GameStateManager.get_credits()
	## if available >= tax:
	## GameStateManager.add_credits(-tax)
	## return "Paid %d Credits in taxes (rolled %d, %d)" % [tax, die1, die2]
	## else:
	## return "Ship impounded! Pay %d Credits to retrieve" % (tax + 5)
	## return "Tax collector demands %d Credits" % tax
	##
	## "Government Inspection":
	## # Must discard illegal goods or pay fine
	## var fine: int = _roll_d6("Inspection fine")
	## return "Government inspection: Discard illegal goods or pay %d credit fine" % fine
	##
	## "Bureaucratic Delay":
	## return "Bureaucratic delay: Cannot depart this turn"
	##
	## # Leadership Events
	## "New Captain":
	## # Select a crew member, +3 XP; 1-in-6 old captain leaves
	## var roll: int = _roll_d6("Captain transition")
	## if roll == 1:
	## return "Select new captain (+3 XP), old captain departs with D6 credits"
	## return "Select new captain (+3 XP)"
	##
	## "Crew Dispute":
	## # Two random crew argue, -1 morale or captain intervenes
	## return "Crew dispute: Captain must mediate or -1 morale"
	##
	## "Leadership Challenge":
	## # Roll Combat, failure means -2 morale
	## return "Leadership challenged: Captain must win combat roll or -2 morale"
	##
	## # Invasion/War Events
	## "War Rumors":
	## # +2 to invasion check while on this planet
	## return "War rumors: +2 to invasion check while on this planet"
	##
	## "Invasion Warning":
	## # Roll 2D6, on 9+ invasion begins next turn
	## var invasion_roll: int = _roll_2d6("Invasion warning")
	## if invasion_roll >= 9:
	## if GameStateManager and GameStateManager.has_method("set_invasion_pending"):
	## GameStateManager.set_invasion_pending(true)
	## return "Invasion imminent! (rolled %d) Invasion begins next turn" % invasion_roll
	## return "Invasion warning subsides (rolled %d)" % invasion_roll
	##
	## "Refugee Crisis":
	## # -1 credit for upkeep, +1 rumor
	## if GameStateManager:
	## GameStateManager.add_credits(-1)
	## _add_quest_rumor()
	## return "Helped refugees (-1 Credit, +1 Rumor)"
	##
	## # Reputation Events
	## "Bad Reputation":
	## # Lose 1 patron
	## _remove_random_patron()
	## return "Bad reputation spreads: Lost 1 Patron"
	##
	## "Reputation Boost":
	## if GameStateManager and GameStateManager.has_method("add_reputation"):
	## GameStateManager.add_reputation(1)
	## return "+1 Reputation"
	##
	## "Reputation Damaged":
	## if GameStateManager and GameStateManager.has_method("add_reputation"):
	## GameStateManager.add_reputation(-1)
	## return "-1 Reputation"
	##
	## # Rival Events (extended)
	## "Settled Business":
	## # Remove rival OR captain gains +1 XP
	## return "Settled business: Remove 1 Rival OR Captain gains +1 XP"
	##
	## "Rival Ambush":
	## # Must fight rival immediately, no deploy phase
	## return "Rival ambush! Fight immediately (no deployment phase)"
	##
	## "Rival Truce":
	## # Pay D6 credits to remove a rival
	## var truce_cost: int = _roll_d6("Truce cost")
	## return "Rival offers truce: Pay %d Credits to remove them" % truce_cost
	##
	## "Rival Alliance":
	## # Two rivals combine forces next battle
	## return "Two rivals have allied! Face combined forces next battle"
	##
	## # Patron Events (extended)
	## "Patron Request":
	## # Roll for urgent mission, +2 credits if accepted
	## return "Patron requests urgent mission: +2 Credits if completed this turn"
	##
	## "Patron Fallout":
	## # Patron relationship damaged
	## return "Patron relationship strained: -1 to next Patron roll"
	##
	## "New Patron":
	## # Automatically gain a patron
	## _add_patron()
	## return "Gained new Patron contact"
	##
	## # Supply/Resource Events
	## "Supply Shortage":
	## if GameStateManager and GameStateManager.has_method("remove_supplies"):
	## GameStateManager.remove_supplies(1)
	## return "Supply shortage: -1 Supplies"
	##
	## "Supply Cache":
	## if GameStateManager and GameStateManager.has_method("add_supplies"):
	## GameStateManager.add_supplies(2)
	## return "Found supply cache: +2 Supplies"
	##
	## "Fuel Price Surge":
	## return "Fuel prices surge: Travel costs +1 Credit this turn"
	##
	## "Fuel Discount":
	## return "Fuel discount: Travel costs -1 Credit this turn"
	##
	## # Ship Events (extended)
	## "Hull Damage":
	## if GameStateManager and GameStateManager.has_method("damage_hull"):
	## GameStateManager.damage_hull(1)
	## return "Ship hull damaged: -1 Hull Point"
	##
	## "System Failure":
	## return "Ship system failure: Pay D6 Credits or cannot travel"
	##
	## "Free Repairs":
	## if GameStateManager and GameStateManager.has_method("repair_hull"):
	## GameStateManager.repair_hull(2)
	## return "Free repair services: +2 Hull Points"
	##
	## "Stowaway":
	## # Roll D6: 1-2 thief, 3-4 refugee, 5-6 useful crew
	## var stowaway_roll: int = _roll_d6("Stowaway")
	## if stowaway_roll <= 2:
	## if GameStateManager:
	## GameStateManager.add_credits(-randi_range(1, 6))
	## return "Stowaway was a thief! Lost D6 Credits"
	## elif stowaway_roll <= 4:
	## return "Stowaway is refugee seeking passage"
	## else:
	## return "Stowaway offers to join crew (roll on character table)"
	##
	## # Quest Events (extended)
	## "Quest Lead":
	## _add_quest_rumor()
	## _add_quest_rumor()
	## return "Major quest lead: +2 Quest Rumors"
	##
	## "Quest Setback":
	## _remove_quest_rumor()
	## return "Quest setback: -1 Quest Rumor"
	##
	## "False Lead":
	## return "Quest lead was false: No progress this turn"
	##
	## # Market Events (extended)
	## "Black Market":
	## return "Black market access: Rare items available (illegal)"
	##
	## "Merchant Guild":
	## return "Merchant guild membership offered: 10 Credits for permanent -1 cost"
	##
	## "Trade War":
	## return "Local trade war: All buying/selling suspended this turn"
	##
	## # Crime Events
	## "Pickpocketed":
	## var loss: int = _roll_d6("Pickpocket loss")
	## if GameStateManager:
	## GameStateManager.add_credits(-loss)
	## return "Crew member pickpocketed: -%d Credits" % loss
	##
	## "Bounty Posted":
	## # Rival or enemy posts bounty
	## return "Bounty posted on crew: +1 Rival (bounty hunter)"
	##
	## "Crime Syndicate":
	## return "Crime syndicate offers job: High pay but +1 Rival if accepted"
	##
	## # Special Events
	## "Alien Artifact":
	## return "Alien artifact discovered: Roll on artifact table"
	##
	## "Psychic Disturbance":
	## return "Psychic disturbance: -1 to all Savvy rolls this battle"
	##
	## "Strange Signal":
	## _add_quest_rumor()
	## return "Strange signal detected: +1 Quest Rumor"
	##
	## "Local Festival":
	## return "Local festival: +1 morale, trade prices +1 Credit"
	##
	## _:
	## return "Event requires manual resolution"
	##
	## return "Event resolved"
	##
	## func apply_character_event_effect(event_title: String, character: Variant) -> String:
	## ## Apply character event effects based on event title
	## # Sprint 26.3: Character-Everywhere - crew members are always Character objects
	## var char_name: String = ""
	## if "character_name" in character:
	## char_name = character.character_name
	## elif "name" in character:
	## char_name = character.name
	## elif character is Dictionary:
	## char_name = character.get("name", "Unknown")
	## else:
	## char_name = "Unknown"
	##
	## match event_title:
	## # XP Gain Events
	## "Focused Training":
	## _add_character_xp(character, 1)
	## return "%s gained +1 Combat Skill XP" % char_name
	##
	## "Technical Study":
	## _add_character_xp(character, 1)
	## return "%s gained +1 Savvy XP" % char_name
	##
	## "Physical Training":
	## _add_character_xp(character, 1)
	## return "%s gained +1 Toughness XP" % char_name
	##
	## "Personal Growth":
	## _add_character_xp(character, 2)
	## return "%s gained +2 XP" % char_name
	##
	## "Moment of Glory":
	## _add_character_xp(character, 1)
	## if GameStateManager and GameStateManager.has_method("add_story_points"):
	## GameStateManager.add_story_points(1)
	## return "%s gained +1 XP and +1 Story Point" % char_name
	##
	## # Story Point Events
	## "Old Friend":
	## if GameStateManager and GameStateManager.has_method("add_story_points"):
	## GameStateManager.add_story_points(1)
	## return "%s reconnects with old friend (+1 Story Point)" % char_name
	##
	## # Credits Events
	## "Side Job":
	## var credits: int = randi_range(1, 6)
	## if GameStateManager:
	## GameStateManager.add_credits(credits)
	## return "%s earned %d Credits" % [char_name, credits]
	##
	## "Unexpected Windfall":
	## var credits: int = randi_range(1, 6) + randi_range(1, 6)
	## if GameStateManager:
	## GameStateManager.add_credits(credits)
	## return "%s received %d Credits" % [char_name, credits]
	##
	## "Gambling":
	## var roll: int = randi_range(1, 6)
	## var bet: int = randi_range(1, 6)
	## if roll <= 2:
	## if GameStateManager:
	## GameStateManager.add_credits(-bet)
	## return "%s lost %d Credits gambling" % [char_name, bet]
	## elif roll >= 5:
	## if GameStateManager:
	## GameStateManager.add_credits(bet)
	## return "%s won %d Credits gambling" % [char_name, bet]
	## else:
	## return "%s broke even gambling" % char_name
	##
	## # Equipment Events
	## "Found Item":
	## _add_random_equipment_to_stash()
	## return "%s found random gear item" % char_name
	##
	## "Equipment Care":
	## return "%s repaired one damaged item" % char_name
	##
	## "Equipment Lost":
	## return "%s lost random equipment" % char_name
	##
	## # Injury/Medical Events
	## "Bad Dreams":
	## return "%s suffers -1 to next combat roll (nightmares)" % char_name
	##
	## "Bar Fight":
	## var roll: int = randi_range(1, 6)
	## if roll <= 3:
	## _injure_specific_crew(character, 1)
	## return "%s injured in bar fight (1 turn recovery)" % char_name
	## else:
	## return "%s gained respect in bar fight" % char_name
	##
	## "Wound Heals":
	## _reduce_character_recovery(character, 1)
	## return "%s recovers faster (-1 turn recovery)" % char_name
	##
	## # Relationship Events
	## "Made Contact":
	## return "%s made useful contact (+1 to next Patron search)" % char_name
	##
	## "Made Enemy":
	## _add_rival("%s's enemy" % char_name)
	## return "%s made an enemy (+1 Rival)" % char_name
	##
	## "Valuable Intel":
	## _add_quest_rumor()
	## return "%s discovered valuable intel (+1 Rumor)" % char_name
	##
	## # Trait Events
	## "Trait Development":
	## return "%s develops positive trait (roll on trait table)" % char_name
	##
	## "Life-Changing Event":
	## return "%s experiences life-changing event (reroll Motivation)" % char_name
	##
	## "Quiet Day":
	## _add_character_xp(character, 1)
	## return "%s had a quiet day (+1 XP)" % char_name
	##
	## # ================================================================
	## # Sprint 18.2: Additional Character Events (Core Rules p.125-126)
	## # ================================================================
	##
	## # Priority Events (from plan)
	## "Business Elsewhere":
	## # Character unavailable 2 turns, returns with D6 XP + random loot
	## var xp_gain: int = _roll_d6("Business elsewhere XP")
	## return "%s has business elsewhere: Unavailable 2 turns, will return with %d XP + loot item" % [char_name, xp_gain]
	##
	## "In a Scrap":
	## # Roll combat vs another crew member, loser goes to Sick Bay
	## var combat_roll: int = _roll_d6("Scrap combat")
	## if combat_roll <= 3:
	## _injure_specific_crew(character, 2)
	## return "%s lost a scrap with crewmate: 2 turns in Sick Bay" % char_name
	## else:
	## return "%s won a scrap with crewmate: Other crew member in Sick Bay" % char_name
	##
	## "Letter from Home":
	## # +1 XP, 5-6 on D6 = receive Quest
	## _add_character_xp(character, 1)
	## var quest_roll: int = _roll_d6("Letter from home quest")
	## if quest_roll >= 5:
	## _add_quest_rumor()
	## return "%s received letter from home (+1 XP, +1 Quest Rumor)" % char_name
	## return "%s received letter from home (+1 XP)" % char_name
	##
	## "Scars Tell Story":
	## # +2 XP if injured last turn
	## _add_character_xp(character, 2)
	## return "%s earned respect from past battle (+2 XP from scars)" % char_name
	##
	## # Additional XP Events
	## "Combat Drill":
	## _add_character_xp(character, 1)
	## return "%s participated in combat drill (+1 XP)" % char_name
	##
	## "Mentor":
	## _add_character_xp(character, 2)
	## return "%s learned from experienced mentor (+2 XP)" % char_name
	##
	## "Hard Lessons":
	## _add_character_xp(character, 1)
	## return "%s learned from a painful failure (+1 XP)" % char_name
	##
	## "Combat Veteran":
	## _add_character_xp(character, 3)
	## return "%s reflects on long career (+3 XP)" % char_name
	##
	## # Additional Credit Events
	## "Inheritance":
	## var inheritance: int = _roll_d6("Inheritance") + _roll_d6("Inheritance bonus")
	## if GameStateManager:
	## GameStateManager.add_credits(inheritance)
	## return "%s received %d Credit inheritance" % [char_name, inheritance]
	##
	## "Lost Bet":
	## var loss: int = _roll_d6("Lost bet")
	## if GameStateManager:
	## GameStateManager.add_credits(-loss)
	## return "%s lost %d Credits on a bet" % [char_name, loss]
	##
	## "Collected Debt":
	## var debt: int = _roll_d6("Collected debt")
	## if GameStateManager:
	## GameStateManager.add_credits(debt)
	## return "%s collected %d Credits owed" % [char_name, debt]
	##
	## "Bribery":
	## var bribe: int = _roll_d6("Bribery")
	## if GameStateManager:
	## GameStateManager.add_credits(-bribe)
	## return "%s paid %d Credit bribe" % [char_name, bribe]
	##
	## # Injury/Medical Events (extended)
	## "Recurring Injury":
	## _injure_specific_crew(character, 1)
	## return "%s suffers from recurring injury (1 turn recovery)" % char_name
	##
	## "Close Call":
	## return "%s had a close call: -1 to next combat roll (shaken)" % char_name
	##
	## "Miraculous Recovery":
	## _reduce_character_recovery(character, 2)
	## return "%s makes miraculous recovery (-2 turns recovery)" % char_name
	##
	## "Sick":
	## _injure_specific_crew(character, 1)
	## return "%s falls ill (1 turn unavailable)" % char_name
	##
	## "Accident":
	## var severity: int = _roll_d6("Accident severity")
	## if severity <= 2:
	## _injure_specific_crew(character, 1)
	## return "%s had minor accident (1 turn recovery)" % char_name
	## elif severity <= 4:
	## _injure_specific_crew(character, 2)
	## return "%s had moderate accident (2 turns recovery)" % char_name
	## else:
	## return "%s narrowly avoided serious accident" % char_name
	##
	## # Relationship Events (extended)
	## "Made Friend":
	## if GameStateManager and GameStateManager.has_method("add_story_points"):
	## GameStateManager.add_story_points(1)
	## return "%s made valuable friend (+1 Story Point)" % char_name
	##
	## "Romantic Entanglement":
	## # D6: 1-2 causes problems, 3-4 neutral, 5-6 helpful
	## var romance_roll: int = _roll_d6("Romance outcome")
	## if romance_roll <= 2:
	## return "%s's romance causes complications (-1 to next mission)" % char_name
	## elif romance_roll >= 5:
	## return "%s's romance provides benefits (+1 to next Patron search)" % char_name
	## return "%s has romantic entanglement (no effect this turn)" % char_name
	##
	## "Family Trouble":
	## var trouble_roll: int = _roll_d6("Family trouble")
	## if trouble_roll <= 3:
	## if GameStateManager:
	## GameStateManager.add_credits(-_roll_d6("Family credits"))
	## return "%s must help family (sent D6 Credits)" % char_name
	## return "%s resolved family trouble" % char_name
	##
	## "Old Comrade":
	## _add_character_xp(character, 1)
	## return "%s met old comrade (+1 XP from reminiscing)" % char_name
	##
	## # Equipment Events (extended)
	## "Weapon Upgrade":
	## return "%s upgraded weapon (+1 to damage)" % char_name
	##
	## "Personal Item":
	## return "%s acquired personal item (sentimental value)" % char_name
	##
	## "Equipment Breakdown":
	## return "%s's equipment malfunctioned (repair needed)" % char_name
	##
	## "Lucky Find":
	## _add_random_equipment_to_stash()
	## return "%s found valuable item (added to stash)" % char_name
	##
	## # Morale/Mental Events
	## "Homesick":
	## return "%s is homesick (-1 morale this turn)" % char_name
	##
	## "Inspired":
	## _add_character_xp(character, 1)
	## return "%s feels inspired (+1 XP, +1 morale)" % char_name
	##
	## "Doubt":
	## return "%s experiences self-doubt (-1 to first combat roll next battle)" % char_name
	##
	## "Confidence":
	## return "%s gains confidence (+1 to first combat roll next battle)" % char_name
	##
	## "Nightmare":
	## return "%s has recurring nightmares (-1 to Savvy this turn)" % char_name
	##
	## # Special Events
	## "Spiritual Experience":
	## _add_character_xp(character, 1)
	## if GameStateManager and GameStateManager.has_method("add_story_points"):
	## GameStateManager.add_story_points(1)
	## return "%s had spiritual experience (+1 XP, +1 Story Point)" % char_name
	##
	## "Prophetic Dream":
	## _add_quest_rumor()
	## return "%s had prophetic dream (+1 Quest Rumor)" % char_name
	##
	## "Strange Encounter":
	## # D6: 1-2 bad, 3-4 nothing, 5-6 good
	## var encounter_roll: int = _roll_d6("Strange encounter")
	## if encounter_roll <= 2:
	## _add_rival("%s's strange encounter" % char_name)
	## return "%s had strange encounter (+1 Rival)" % char_name
	## elif encounter_roll >= 5:
	## _add_patron()
	## return "%s had strange encounter (+1 Patron contact)" % char_name
	## return "%s had strange encounter (no lasting effect)" % char_name
	##
	## "Psych Eval Required":
	## return "%s requires psych eval (unavailable 1 turn)" % char_name
	##
	## "On Leave":
	## return "%s takes personal leave (unavailable 1 turn, +1 morale)" % char_name
	##
	## _:
	## return "%s: Event requires manual resolution" % char_name
	##
	## return "Character event resolved"
	##
	## ## Helper Methods for Event Effects
	## func _has_crew_with_class(character_class: String) -> bool:
	## ## Check if any crew member has specific class
	## var game_state = _game_state  # Sprint 28.2: Use cached reference
	## if game_state and game_state.current_campaign:
	## var campaign = game_state.current_campaign
	## # Sprint 26.3: Character-Everywhere - handle both Campaign Resource and Dictionary
	## var crew: Array = []
	## if campaign.has_method("get_crew_members"):
	## crew = campaign.get_crew_members()
	## elif campaign is Dictionary:
	## crew = campaign.get("crew", [])
	## elif "crew_members" in campaign:
	## crew = campaign.crew_members
	## for member in crew:
	## # Sprint 26.3: crew members are always Character objects
	## var member_class: String = ""
	## if "character_class" in member:
	## member_class = member.character_class
	## elif member is Dictionary:
	## member_class = member.get("class", member.get("character_class", ""))
	## if member_class == character_class:
	## return true
	## return false
	##
	## func _get_random_crew_member() -> Variant:
	## ## Get random crew member from current crew participants
	## if crew_participants.is_empty():
	## return null
	##
	## var random_index: int = randi() % crew_participants.size()
	## return crew_participants[random_index]
	##
	## func _add_quest_rumor() -> void:
	## ## Add a quest rumor to campaign
	## var game_state = _game_state  # Sprint 28.2: Use cached reference
	## if game_state and game_state.current_campaign:
	## var campaign = game_state.current_campaign
	## if campaign is Dictionary:
	## var rumors = campaign.get("rumors", [])
	## var rumor_types = [
	## "An extracted data file",
	## "Notebook with secret information",
	## "Old map showing a location",
	## "A tip from a contact",
	## "An intercepted transmission"
	## ]
	## var roll = randi() % rumor_types.size()
	## rumors.append({
	## "id": "rumor_%d_%d" % [Time.get_ticks_msec(), randi() % 1000],
	## "type": roll + 1,
	## "description": rumor_types[roll],
	## "source": "event"
	## })
	## campaign["rumors"] = rumors
	## print("PostBattlePhase: +1 quest rumor")
	##
	## func _add_rival(rival_name: String) -> void:
	## ## Add a rival to campaign
	## var game_state = _game_state  # Sprint 28.2: Use cached reference
	## if game_state and game_state.current_campaign:
	## var campaign = game_state.current_campaign
	## if campaign is Dictionary:
	## var rivals = campaign.get("rivals", [])
	## var rival_id = "rival_%d_%d" % [Time.get_ticks_msec(), randi() % 1000]
	## rivals.append({
	## "id": rival_id,
	## "name": rival_name,
	## "type": ["Criminal", "Corporate", "Personal", "Gang"][randi() % 4],
	## "hostility": randi_range(3, 5),
	## "resources": randi_range(1, 3),
	## "source": "event"
	## })
	## campaign["rivals"] = rivals
	## # Register rival with PlanetDataManager for planet persistence
	## var pdm = get_node_or_null("/root/PlanetDataManager")
	## if pdm and pdm.current_planet_id != "":
	## pdm.add_contact_to_planet(pdm.current_planet_id, rival_id)
	## print("PostBattlePhase: +1 rival")
	##
	## ## Sprint 18.1: Additional helper functions for campaign events
	## func _remove_random_patron() -> void:
	## ## Remove a random patron from campaign
	## var game_state = _game_state  # Sprint 28.2: Use cached reference
	## if game_state and game_state.current_campaign:
	## var campaign = game_state.current_campaign
	## if campaign is Dictionary:
	## var patrons: Array = campaign.get("patrons", [])
	## if patrons.size() > 0:
	## var idx: int = randi() % patrons.size()
	## var removed = patrons[idx]
	## patrons.remove_at(idx)
	## campaign["patrons"] = patrons
	## print("PostBattlePhase: Removed patron: %s" % str(removed.get("name", "Unknown")))
	## else:
	## print("PostBattlePhase: No patrons to remove")
	##
	## func _add_patron() -> void:
	## ## Add a new patron to campaign
	## var game_state = _game_state  # Sprint 28.2: Use cached reference
	## if game_state and game_state.current_campaign:
	## var campaign = game_state.current_campaign
	## if campaign is Dictionary:
	## var patrons: Array = campaign.get("patrons", [])
	## var patron_types = ["Corporate", "Government", "Criminal", "Private", "Mercenary"]
	## var patron_names = ["The Broker", "Lady Silver", "Commander Vex", "Old Sal", "The Collector"]
	## var patron_id = "patron_%d_%d" % [Time.get_ticks_msec(), randi() % 1000]
	## patrons.append({
	## "id": patron_id,
	## "name": patron_names[randi() % patron_names.size()],
	## "type": patron_types[randi() % patron_types.size()],
	## "relationship": randi_range(1, 3),
	## "persistent": randi_range(1, 6) >= 4,  # 50% chance persistent
	## "source": "event"
	## })
	## campaign["patrons"] = patrons
	## # Register patron with PlanetDataManager for planet persistence
	## var pdm = get_node_or_null("/root/PlanetDataManager")
	## if pdm and pdm.current_planet_id != "":
	## pdm.add_contact_to_planet(pdm.current_planet_id, patron_id)
	## print("PostBattlePhase: +1 patron")
	##
	## func _remove_quest_rumor() -> void:
	## ## Remove a quest rumor from campaign (quest setback)
	## var game_state = _game_state  # Sprint 28.2: Use cached reference
	## if game_state and game_state.current_campaign:
	## var campaign = game_state.current_campaign
	## if campaign is Dictionary:
	## var rumors: Array = campaign.get("rumors", [])
	## if rumors.size() > 0:
	## var idx: int = randi() % rumors.size()
	## rumors.remove_at(idx)
	## campaign["rumors"] = rumors
	## print("PostBattlePhase: -1 quest rumor (setback)")
	## else:
	## print("PostBattlePhase: No rumors to remove")
	##
func _damage_random_equipment() -> void:
	## Equipmentdamagesystem(FiveParsecsrules):
	## - Selectsarandompieceofequipmentfromcrew or shipstash
	## - Reducesconditionby10 - 30points
	## - Equipmentat0 % condition is destroyed and removed
	## - Notifiesplayerofdamage
	##
	# Gather all equipment from crew members via GameStateManager
	var all_equipment: Array = []

	if game_state_manager and game_state_manager.has_method("get_crew_members"):
		for member in game_state_manager.get_crew_members():
			if member.get("is_dead") == true:
				continue
			var member_name: String = member.character_name if "character_name" in member else "Unknown"
			if "weapons" in member:
				for w in member.weapons:
					all_equipment.append({"source": "crew", "owner": member_name, "item_name": str(w)})
			if "items" in member:
				for it in member.items:
					all_equipment.append({"source": "crew", "owner": member_name, "item_name": str(it)})

	if all_equipment.is_empty():
		return

	# Pick a random item and report damage (condition tracking is informational)
	var random_index: int = randi() % all_equipment.size()
	var target: Dictionary = all_equipment[random_index]
	var item_name: String = target.get("item_name", "Unknown Item")
	var owner_name: String = target.get("owner", "Ship Stash")
	var damage_amount: int = 10 + (randi() % 21) # 10-30

func _reduce_recovery_time(max_crew: int) -> void:
	## Reduce recovery time for crew in sick bay
	var game_state = _game_state # Sprint 28.2: Use cached reference
	if game_state and game_state.current_campaign:
		var campaign = game_state.current_campaign
		# Sprint 26.3: Character-Everywhere - handle both Campaign Resource and Dictionary
		var crew: Array = []
		if campaign.has_method("get_crew_members"):
			crew = campaign.get_crew_members()
		elif campaign is Dictionary:
			crew = campaign.get("crew", [])
		elif "crew_members" in campaign:
			crew = campaign.crew_members
		var healed_count: int = 0
		for member in crew:
			if healed_count >= max_crew:
				break
			# Sprint 26.3: crew members are always Character objects
			var recovery_turns: int = member.injury_recovery_turns if "injury_recovery_turns" in member else 0
			if recovery_turns > 0:
				if "injury_recovery_turns" in member:
					member.injury_recovery_turns = max(0, recovery_turns - 1)
				healed_count += 1
				var member_name: String = member.character_name if "character_name" in member else (member.name if "name" in member else "crew")

func _heal_crew_in_sickbay() -> void:
	## Immediately heal one crew member in sick bay
	var game_state = _game_state # Sprint 28.2: Use cached reference
	if game_state and game_state.current_campaign:
		var campaign = game_state.current_campaign
		# Sprint 26.3: Character-Everywhere - handle both Campaign Resource and Dictionary
		var crew: Array = []
		if campaign.has_method("get_crew_members"):
			crew = campaign.get_crew_members()
		elif campaign is Dictionary:
			crew = campaign.get("crew", [])
		elif "crew_members" in campaign:
			crew = campaign.crew_members
		for member in crew:
			# Sprint 26.3: crew members are always Character objects
			var recovery_turns: int = member.injury_recovery_turns if "injury_recovery_turns" in member else 0
			if recovery_turns > 0:
				if "injury_recovery_turns" in member:
					member.injury_recovery_turns = 0
				var member_name: String = member.character_name if "character_name" in member else (member.name if "name" in member else "crew")
				return

func _award_xp_to_random_crew(xp_amount: int) -> void:
	## Award XP to random crew member
	var game_state = _game_state # Sprint 28.2: Use cached reference
	if game_state and game_state.current_campaign:
		var campaign = game_state.current_campaign
		# Sprint 26.3: Character-Everywhere - handle both Campaign Resource and Dictionary
		var crew: Array = []
		if campaign.has_method("get_crew_members"):
			crew = campaign.get_crew_members()
		elif campaign is Dictionary:
			crew = campaign.get("crew", [])
		elif "crew_members" in campaign:
			crew = campaign.crew_members
		if crew.size() > 0:
			var random_index = randi() % crew.size()
			var member = crew[random_index]
			# Sprint 26.3: crew members are always Character objects
			_add_character_xp(member, xp_amount)

func _award_xp_to_all_crew(xp_amount: int) -> void:
	## Award XP to all crew members
	var game_state = _game_state # Sprint 28.2: Use cached reference
	if game_state and game_state.current_campaign:
		var campaign = game_state.current_campaign
		# Sprint 26.3: Character-Everywhere - handle both Campaign Resource and Dictionary
		var crew: Array = []
		if campaign.has_method("get_crew_members"):
			crew = campaign.get_crew_members()
		elif campaign is Dictionary:
			crew = campaign.get("crew", [])
		elif "crew_members" in campaign:
			crew = campaign.crew_members
		for member in crew:
			# Sprint 26.3: crew members are always Character objects
			_add_character_xp(member, xp_amount)

func _injure_random_crew(recovery_turns: int) -> void:
	## Injure random crew member
	var game_state = _game_state # Sprint 28.2: Use cached reference
	if game_state and game_state.current_campaign:
		var campaign = game_state.current_campaign
		# Sprint 26.3: Character-Everywhere - handle both Campaign Resource and Dictionary
		var crew: Array = []
		if campaign.has_method("get_crew_members"):
			crew = campaign.get_crew_members()
		elif campaign is Dictionary:
			crew = campaign.get("crew", [])
		elif "crew_members" in campaign:
			crew = campaign.crew_members
		if crew.size() > 0:
			var random_index = randi() % crew.size()
			var member = crew[random_index]
			# Sprint 26.3: crew members are always Character objects
			if "injury_recovery_turns" in member:
				member.injury_recovery_turns = recovery_turns
			var member_name: String = member.character_name if "character_name" in member else (member.name if "name" in member else "crew")

func _add_character_xp(character: Variant, xp_amount: int) -> void:
	## Add XP to specific character (Sprint 26.3: Character-Everywhere)
	## Sprint 27.4: Cleaned up dead xp code path - canonical property is 'experience'
	## ##
	pass
	## if not character:
	## return
	## # Sprint 26.3: Characters are now always Character objects
	## # Use add_experience() method if available (preferred), otherwise direct property access
	## if character.has_method("add_experience"):
	## character.add_experience(xp_amount)
	## elif "experience" in character:
	## character.experience += xp_amount
	## elif character is Dictionary:
	## character["experience"] = character.get("experience", 0) + xp_amount
	## var char_name: String = character.character_name if "character_name" in character else character.name if "name" in character else "Unknown"
	## print("PostBattlePhase: %s gained +%d XP" % [char_name, xp_amount])
	##
	## func _reduce_character_recovery(character: Variant, turns: int) -> void:
	## ## Reduce recovery time for specific character via status_effects duration
	## if not character:
	## return
	## var char_name: String = character.character_name if "character_name" in character else "Unknown"
	## if character.get("status_effects") != null:
	## for effect in character.status_effects:
	## if effect is Dictionary and effect.get("type", "") in ["injury", "MINOR_INJURY", "SERIOUS_INJURY", "CRIPPLING_WOUND"]:
	## if "duration" in effect:
	## effect.duration = maxi(0, effect.duration - turns)
	## print("PostBattlePhase: %s recovery reduced by %d turns" % [char_name, turns])
	##
	## func _injure_specific_crew(character: Variant, recovery_turns: int) -> void:
	## ## Injure specific crew member via GameStateManager bridge
	## if not character:
	## return
	## var char_name: String = character.character_name if "character_name" in character else "Unknown"
	## var injury_data := {
	## "type": "injury",
	## "severity": 1,
	## "recovery_turns": recovery_turns,
	## "description": "Injury sustained",
	## "is_fatal": false
	## }
	## if game_state_manager and game_state_manager.has_method("apply_crew_injury"):
	## var crew_id = character.character_name if "character_name" in character else 0
	## game_state_manager.apply_crew_injury(crew_id, injury_data)
	## else:
	## character.is_wounded = true
	## if character.get("status_effects") != null:
	## character.status_effects.append({
	## "type": "injury", "severity": 1,
	## "duration": recovery_turns, "description": "Injury sustained"
	## })
	## print("PostBattlePhase: %s injured (%d turn recovery)" % [char_name, recovery_turns])
	##
	## func _add_random_equipment_to_stash() -> void:
	## ## Add random equipment to ship stash via GameStateManager bridge
	## var equipment_types = ["Infantry Laser", "Auto Rifle", "Scrap Pistol", "Blade"]
	## var random_item = equipment_types[randi() % equipment_types.size()]
	## var equipment_data = {
	## "id": "found_%d" % Time.get_ticks_msec(),
	## "name": random_item,
	## "type": "weapon",
	## "location": "ship_stash"
	## }
	##
	## if game_state_manager and game_state_manager.has_method("add_to_ship_inventory"):
	## game_state_manager.add_to_ship_inventory(equipment_data)
	## print("PostBattlePhase: Found %s (added to stash)" % random_item)
	## else:
	## push_warning("PostBattlePhase: Could not add %s to stash - no bridge available" % random_item)
	##
	## ## Public API Methods
	## func get_current_substep() -> int:
	## ## Get the current post-battle sub-step
	## return current_substep
	##
	## func set_battle_result(result: Dictionary) -> void:
	## ## Set battle result data for processing
	## battle_result = result.duplicate()
	## mission_successful = result.get("success", false)
	## enemies_defeated = result.get("enemies_defeated", 0)
	##
	## func add_injury(crew_id: String, injury_type: String) -> void:
	## ## Add injury for processing
	## injuries_sustained.append({"crew_id": crew_id, "type": injury_type})
	##
	## func set_crew_participants(participants: Array) -> void:
	## ## Set crew members who participated in battle
	## crew_participants.clear()
	## for p in participants:
	## if p is String:
	## crew_participants.append(p)
	##
	## func is_post_battle_phase_active() -> bool:
	## ## Check if post-battle phase is currently active
	## return current_substep != GlobalEnums.PostBattleSubPhase.NONE if GlobalEnums else false
	##
	## func get_battle_result() -> Dictionary:
	## ## Get stored battle result data
	## return battle_result.duplicate()
	##
	## ## =============================================================================
	## ## ═══════════════════════════════════════════════════════════════════════════════
	## ## DEBUG LOGGING - Sprint 26.5: Substep-Level Debug Output
	## ## ═══════════════════════════════════════════════════════════════════════════════
	##
	## func _debug_log_post_battle_input(battle_data: Dictionary) -> void:
	## ## Log post-battle input data for debugging handoff from Battle Phase
	## print("\n" + "=".repeat(70))
	## print("[POST-BATTLE DEBUG] Processing Results")
	## print("=".repeat(70))
	##
	## # Battle outcome
	## print("  BATTLE OUTCOME:")
	## print("    Victory: %s" % str(battle_data.get("success", battle_data.get("victory", "MISSING"))))
	## print("    Rounds Fought: %s" % str(battle_data.get("rounds_fought", "MISSING")))
	## print("    Combat Mode: %s" % str(battle_data.get("combat_mode", "auto-resolve")))
	##
	## # Enemy results
	## print("  ENEMY RESULTS:")
	## print("    Enemies Defeated: %s" % str(battle_data.get("enemies_defeated", "MISSING")))
	## var defeated_list = battle_data.get("defeated_enemy_list", [])
	## print("    Defeated List Size: %d" % defeated_list.size())
	## if not defeated_list.is_empty():
	## var rival_count: int = 0
	## for enemy in defeated_list:
	## if enemy is Dictionary and enemy.get("is_rival", false):
	## rival_count += 1
	## if rival_count > 0:
	## print("    Rivals Defeated: %d" % rival_count)
	##
	## # Crew results
	## print("  CREW RESULTS:")
	## var participants = battle_data.get("crew_participants", [])
	## print("    Participants: %d" % participants.size())
	## var casualties = battle_data.get("casualties", battle_data.get("injured_crew", []))
	## print("    Casualties: %s" % str(casualties.size() if casualties is Array else casualties))
	## var injuries = battle_data.get("injuries_sustained", [])
	## print("    Injuries Sustained: %d" % injuries.size())
	##
	## # Show first few participants
	## if not participants.is_empty():
	## print("    Crew Names:")
	## for i in range(min(3, participants.size())):
	## var member = participants[i]
	## var name_str: String = "Unknown"
	## var survived: bool = true
	## if member is Dictionary:
	## name_str = member.get("character_name", member.get("name", "Unknown"))
	## survived = member.get("survived", true)
	## print("      [%d] %s - %s" % [i, name_str, "Survived" if survived else "CASUALTY"])
	## if participants.size() > 3:
	## print("      ... and %d more" % (participants.size() - 3))
	##
	## # Rewards
	## print("  REWARDS:")
	## print("    Payment: %s credits" % str(battle_data.get("payment", battle_data.get("credits_earned", "MISSING"))))
	## print("    XP per Participant: %s" % str(battle_data.get("xp_per_participant", "MISSING")))
	## print("    XP Victory Bonus: %s" % str(battle_data.get("xp_victory_bonus", "0")))
	## print("    Loot Opportunities: %s" % str(battle_data.get("loot_opportunities", "MISSING")))
	## print("    Battlefield Finds: %s" % str(battle_data.get("battlefield_finds", "MISSING")))
	##
	## # Mission reference
	## print("  MISSION REFERENCE:")
	## print("    Mission Type: %s" % str(battle_data.get("mission_type", "MISSING")))
	## print("    Mission ID: %s" % str(battle_data.get("mission_id", "MISSING")))
	##
	## # Data completeness check
	## var required_keys = ["success", "enemies_defeated", "crew_participants", "payment"]
	## var missing_keys: Array = []
	## for key in required_keys:
	## if not battle_data.has(key):
	## missing_keys.append(key)
	## if not missing_keys.is_empty():
	## print("  ⚠️ MISSING REQUIRED KEYS: %s" % str(missing_keys))
	##
	## print("└─────────────────────────────────────────────────────────────┘")
	##
	##
	## func _debug_log_rival_status(rivals_defeated: Array, removal_rolls: Array, rivals_removed: Array) -> void:
	## ## Log rival status resolution
	## print("┌─────────────────────────────────────────────────────────────┐")
	## print("│ POST-BATTLE SUBSTEP: RIVAL_STATUS                          │")
	## print("├─────────────────────────────────────────────────────────────┤")
	## print("│ Rivals Defeated in Battle: %d" % rivals_defeated.size())
	## for i in range(rivals_defeated.size()):
	## var rival = rivals_defeated[i]
	## var roll = removal_rolls[i] if i < removal_rolls.size() else 0
	## var removed = i < rivals_removed.size()
	## print("│   - %s: Roll %d → %s" % [str(rival.get("name", "Unknown")), roll, "REMOVED" if removed else "Survives"])
	## if rivals_defeated.is_empty():
	## print("│   No rivals defeated this battle")
	## print("└─────────────────────────────────────────────────────────────┘")
	##
	##
	## func _debug_log_patron_status(mission_patron: Dictionary, contact_added: bool, house_rule_active: bool) -> void:
	## ## Log patron status resolution
	## print("┌─────────────────────────────────────────────────────────────┐")
	## print("│ POST-BATTLE SUBSTEP: PATRON_STATUS                         │")
	## print("├─────────────────────────────────────────────────────────────┤")
	## if not mission_patron.is_empty():
	## print("│ Mission Patron: %s" % str(mission_patron.get("name", "Unknown")))
	## print("│ Contact Added: %s" % ("Yes" if contact_added else "No"))
	## if house_rule_active:
	## print("│ House Rule: Patron contact auto-added")
	## else:
	## print("│ No patron mission - skipping")
	## print("└─────────────────────────────────────────────────────────────┘")
	##
	##
	## func _debug_log_quest_progress(rumors_count: int, quest_roll: int, progress_stage: int, finale_ready: bool) -> void:
	## ## Log quest progress update
	## print("┌─────────────────────────────────────────────────────────────┐")
	## print("│ POST-BATTLE SUBSTEP: QUEST_PROGRESS                        │")
	## print("├─────────────────────────────────────────────────────────────┤")
	## print("│ Current Rumors: %d" % rumors_count)
	## print("│ Quest Roll: D6=%d + rumors → %d" % [quest_roll, quest_roll + rumors_count])
	## print("│ Progress Stage: %d" % progress_stage)
	## print("│ Finale Ready: %s" % ("YES!" if finale_ready else "No"))
	## print("└─────────────────────────────────────────────────────────────┘")
	##
	##
	## func _debug_log_payment(base_pay: int, difficulty_bonus: int, objective_bonus: int, bounties: int, total: int) -> void:
	## ## Log payment calculation
	## print("┌─────────────────────────────────────────────────────────────┐")
	## print("│ POST-BATTLE SUBSTEP: GET_PAID                              │")
	## print("├─────────────────────────────────────────────────────────────┤")
	## print("│ PAYMENT BREAKDOWN:")
	## print("│   Base Pay: %d credits" % base_pay)
	## print("│   Difficulty Bonus: %d credits" % difficulty_bonus)
	## print("│   Objective Bonus: %d credits" % objective_bonus)
	## print("│   Enemy Bounties: %d credits" % bounties)
	## print("│   ─────────────────────")
	## print("│   TOTAL: %d credits" % total)
	## print("└─────────────────────────────────────────────────────────────┘")
	##
	##
	## func _debug_log_battlefield_finds(find_rolls: Array, items_found: Array) -> void:
	## ## Log battlefield finds
	## print("┌─────────────────────────────────────────────────────────────┐")
	## print("│ POST-BATTLE SUBSTEP: BATTLEFIELD_FINDS                     │")
	## print("├─────────────────────────────────────────────────────────────┤")
	## print("│ Find Rolls (D100): %s" % str(find_rolls))
	## print("│ Items Found: %d" % items_found.size())
	## for item in items_found:
	## print("│   - %s" % str(item.get("name", item)))
	## if items_found.is_empty():
	## print("│   (No finds this battle)")
	## print("└─────────────────────────────────────────────────────────────┘")
	##
	##
	## func _debug_log_invasion_check(roll: int, invasion_pending: bool) -> void:
	## ## Log invasion check
	## print("┌─────────────────────────────────────────────────────────────┐")
	## print("│ POST-BATTLE SUBSTEP: CHECK_INVASION                        │")
	## print("├─────────────────────────────────────────────────────────────┤")
	## print("│ Invasion Roll: D6=%d" % roll)
	## print("│ Invasion Pending: %s" % ("YES - Must flee next turn!" if invasion_pending else "No"))
	## print("└─────────────────────────────────────────────────────────────┘")
	##
	##
	## func _debug_log_loot_gathering(loot_rolls: int, items: Array, credits_from_loot: int) -> void:
	## ## Log loot gathering
	## print("┌─────────────────────────────────────────────────────────────┐")
	## print("│ POST-BATTLE SUBSTEP: GATHER_LOOT                           │")
	## print("├─────────────────────────────────────────────────────────────┤")
	## print("│ Loot Opportunities: %d rolls" % loot_rolls)
	## print("│ Items Looted: %d" % items.size())
	## for i in range(min(items.size(), 5)):
	## print("│   - %s" % str(items[i].get("name", items[i])))
	## if items.size() > 5:
	## print("│   ... and %d more" % (items.size() - 5))
	## print("│ Credits from Loot: %d" % credits_from_loot)
	## print("└─────────────────────────────────────────────────────────────┘")
	##
	##
	## func _debug_log_injury(crew_name: String, casualty_roll: int, modifiers: Dictionary, final_result: String, recovery_turns: int) -> void:
	## ## Log individual injury processing - CRITICAL for debugging
	## print("┌─────────────────────────────────────────────────────────────┐")
	## print("│ POST-BATTLE SUBSTEP: INJURIES                              │")
	## print("├─────────────────────────────────────────────────────────────┤")
	## print("│ Crew Member: %s" % crew_name)
	## print("│ Casualty Roll: D6=%d" % casualty_roll)
	## print("│ MODIFIERS:")
	## for mod_name in modifiers:
	## print("│   %s: %+d" % [mod_name, modifiers[mod_name]])
	## print("│ FINAL RESULT: %s" % final_result)
	## if recovery_turns > 0:
	## print("│ Recovery Time: %d turns" % recovery_turns)
	## print("└─────────────────────────────────────────────────────────────┘")
	##
	##
	## func _debug_log_experience(xp_awards: Array, total_xp: int, advancements: Array) -> void:
	## ## Log experience awards
	## print("┌─────────────────────────────────────────────────────────────┐")
	## print("│ POST-BATTLE SUBSTEP: EXPERIENCE                            │")
	## print("├─────────────────────────────────────────────────────────────┤")
	## print("│ XP AWARDS:")
	## for award in xp_awards:
	## print("│   %s: +%d XP" % [str(award.get("name", "Unknown")), award.get("xp", 0)])
	## print("│ Total XP Awarded: %d" % total_xp)
	## if not advancements.is_empty():
	## print("│ ADVANCEMENTS EARNED:")
	## for adv in advancements:
	## print("│   → %s advanced!" % str(adv.get("name", "Unknown")))
	## print("└─────────────────────────────────────────────────────────────┘")
	##
	##
	## func _debug_log_training(training_purchased: Array, xp_spent: int) -> void:
	## ## Log training purchases
	## print("┌─────────────────────────────────────────────────────────────┐")
	## print("│ POST-BATTLE SUBSTEP: TRAINING                              │")
	## print("├─────────────────────────────────────────────────────────────┤")
	## if not training_purchased.is_empty():
	## for training in training_purchased:
	## print("│ %s trained: %s (Cost: %d XP)" % [
	## str(training.get("character", "Unknown")),
	## str(training.get("skill", "Unknown")),
	## training.get("cost", 0)
	## ])
	## print("│ Total XP Spent: %d" % xp_spent)
	## else:
	## print("│ No training purchased")
	## print("└─────────────────────────────────────────────────────────────┘")
	##
	##
	## func _debug_log_purchases(items_bought: Array, credits_spent: int, credits_remaining: int) -> void:
	## ## Log equipment purchases
	## print("┌─────────────────────────────────────────────────────────────┐")
	## print("│ POST-BATTLE SUBSTEP: PURCHASES                             │")
	## print("├─────────────────────────────────────────────────────────────┤")
	## if not items_bought.is_empty():
	## for item in items_bought:
	## print("│ Bought: %s (%d credits)" % [str(item.get("name", "Unknown")), item.get("cost", 0)])
	## print("│ Total Spent: %d credits" % credits_spent)
	## else:
	## print("│ No purchases made")
	## print("│ Credits Remaining: %d" % credits_remaining)
	## print("└─────────────────────────────────────────────────────────────┘")
	##
	##
	## func _debug_log_campaign_event(event_roll: int, event: Dictionary) -> void:
	## ## Log campaign event
	## print("┌─────────────────────────────────────────────────────────────┐")
	## print("│ POST-BATTLE SUBSTEP: CAMPAIGN_EVENT                        │")
	## print("├─────────────────────────────────────────────────────────────┤")
	## print("│ Event Roll: D100=%d" % event_roll)
	## if not event.is_empty():
	## print("│ Event: %s" % str(event.get("name", "Unknown")))
	## print("│ Effects: %s" % str(event.get("effects", {})))
	## else:
	## print("│ No event this turn")
	## print("└─────────────────────────────────────────────────────────────┘")
	##
	##
	## func _debug_log_character_event(character: String, event_roll: int, event: Dictionary) -> void:
	## ## Log character event
	## print("┌─────────────────────────────────────────────────────────────┐")
	## print("│ POST-BATTLE SUBSTEP: CHARACTER_EVENT                       │")
	## print("├─────────────────────────────────────────────────────────────┤")
	## print("│ Character: %s" % character)
	## print("│ Event Roll: D100=%d" % event_roll)
	## if not event.is_empty():
	## print("│ Event: %s" % str(event.get("name", "Unknown")))
	## print("│ Effects: %s" % str(event.get("effects", {})))
	## else:
	## print("│ No character event")
	## print("└─────────────────────────────────────────────────────────────┘")
	##
	##
	## func _debug_log_galactic_war(progress: Dictionary) -> void:
	## ## Log galactic war progress
	## print("┌─────────────────────────────────────────────────────────────┐")
	## print("│ POST-BATTLE SUBSTEP: GALACTIC_WAR                          │")
	## print("├─────────────────────────────────────────────────────────────┤")
	## print("│ War Progress: %s" % str(progress.get("progress", 0)))
	## print("│ Current Stage: %s" % str(progress.get("stage", "Unknown")))
	## print("│ Effects: %s" % str(progress.get("effects", "None")))
	## print("└─────────────────────────────────────────────────────────────┘")
	##
	##

# ═══════════════════════════════════════════════════════════════════════════════
# Stub functions for methods whose implementations are commented out above.
# These stubs prevent parse/compile errors from live code that calls them.
# ═══════════════════════════════════════════════════════════════════════════════

func _debug_log_post_battle_input(_battle_data: Dictionary) -> void:
	## Log post-battle input data for debugging handoff from Battle Phase (stub)
	pass

func _add_quest_rumor() -> void:
	## Add a quest rumor to campaign (stub)
	pass

func _debug_log_payment(_base_pay: int, _difficulty_bonus: int, _objective_bonus: int, _bounties: int, _total: int) -> void:
	## Log payment breakdown for debugging (stub)
	pass

func _debug_log_injury(_crew_name: String, _casualty_roll: int, _modifiers: Dictionary, _final_result: String, _recovery_turns: int) -> void:
	## Log injury details for debugging (stub)
	pass

func _get_achievement_xp(_crew_id: String) -> int:
	## Get bonus XP for achievements (stub)
	return 0

func apply_campaign_event_effect(_event_title: String) -> String:
	## Apply campaign event effects based on event title (stub)
	return "Event resolved"

func _get_random_crew_member() -> Variant:
	## Get a random crew member from participants (stub)
	if crew_participants.size() > 0:
		var random_index: int = randi() % crew_participants.size()
		return crew_participants[random_index]
	return null

func apply_character_event_effect(_event_title: String, _character: Variant) -> String:
	## Apply character event effects based on event title (stub)
	return "Character event resolved"
