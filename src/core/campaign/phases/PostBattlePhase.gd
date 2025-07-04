@tool
extends Node
class_name PostBattlePhase

## Post-Battle Phase Implementation - Official Five Parsecs Rules
## Handles the complete Post-Battle sequence (Phase 4 of campaign turn)

# Safe imports
const UniversalNodeAccess = preload("res://src/utils/UniversalNodeAccess.gd")
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd")
const UniversalSignalManager = preload("res://src/utils/UniversalSignalManager.gd")
const UniversalDataAccess = preload("res://src/utils/UniversalDataAccess.gd")
const UniversalSceneManager = preload("res://src/utils/UniversalSceneManager.gd")

# Safe dependency loading - loaded at runtime in _ready()
var GameEnums = null
var dice_manager = null
var game_state_manager = null

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

## Current post-battle state
var current_substep: int = 0 # Will be set to PostBattleSubPhase.NONE in _ready()
var battle_result: Dictionary = {}
var defeated_enemies: Array[Dictionary] = []
var crew_participants: Array[String] = []

## Battle outcome data
var mission_successful: bool = false
var enemies_defeated: int = 0
var loot_earned: Array[Dictionary] = []
var injuries_sustained: Array[Dictionary] = []

func _ready() -> void:
	# Load dependencies safely at runtime
	GameEnums = UniversalResourceLoader.load_script_safe("res://src/core/systems/GlobalEnums.gd", "PostBattlePhase GameEnums")
	dice_manager = DiceManager
	game_state_manager = get_node_or_null("/root/GameStateManagerAutoload")
	
	# Initialize enum values after loading GameEnums
	if GameEnums:
		current_substep = GameEnums.PostBattleSubPhase.NONE
	
	print("PostBattlePhase: Initialized successfully")

## Main Post-Battle Phase Processing
func start_post_battle_phase(battle_data: Dictionary = {}) -> void:
	"""Begin the Post-Battle Phase sequence"""
	print("PostBattlePhase: Starting Post-Battle Phase")
	
	# Store battle result data
	battle_result = battle_data.duplicate()
	mission_successful = UniversalDataAccess.get_dict_value_safe(battle_data, "success", false, "PostBattlePhase mission_successful")
	enemies_defeated = UniversalDataAccess.get_dict_value_safe(battle_data, "enemies_defeated", 0, "PostBattlePhase enemies_defeated")
	defeated_enemies = UniversalDataAccess.get_dict_value_safe(battle_data, "defeated_enemy_list", [], "PostBattlePhase defeated_enemies")
	crew_participants = UniversalDataAccess.get_dict_value_safe(battle_data, "crew_participants", [], "PostBattlePhase crew_participants")
	
	UniversalSignalManager.emit_signal_safe(self, "post_battle_phase_started", [], "PostBattlePhase start_post_battle_phase")
	
	# Step 1: Resolve rival status
	_process_rival_status()

func _process_rival_status() -> void:
	"""Step 1: Resolve Rival Status"""
	if GameEnums:
		current_substep = GameEnums.PostBattleSubPhase.RIVAL_STATUS
		UniversalSignalManager.emit_signal_safe(self, "post_battle_substep_changed", [current_substep], "PostBattlePhase rival_status")
	
	var rivals_removed: Array[String] = []
	
	# Check if any rivals were defeated in battle
	for enemy in defeated_enemies:
		if UniversalDataAccess.get_dict_value_safe(enemy, "is_rival", false, "PostBattlePhase is_rival"):
			var rival_id = UniversalDataAccess.get_dict_value_safe(enemy, "rival_id", "", "PostBattlePhase rival_id")
			if rival_id != "":
				# Roll D6+modifiers to remove rival permanently
				var removal_roll = _roll_rival_removal(rival_id)
				if removal_roll >= 6: # Standard threshold for rival removal
					rivals_removed.append(rival_id)
					_remove_rival(rival_id)
					print("PostBattlePhase: Rival %s permanently eliminated" % rival_id)
	
	UniversalSignalManager.emit_signal_safe(self, "rival_status_resolved", [rivals_removed], "PostBattlePhase rival_status_resolved")
	
	# Continue to patron status
	_process_patron_status()

func _roll_rival_removal(rival_id: String) -> int:
	"""Roll to determine if rival is permanently removed"""
	var base_roll = randi_range(1, 6)
	var modifiers = 0
	
	# Add modifiers based on how the rival was defeated
	if mission_successful:
		modifiers += 1
	
	# Add other modifiers based on circumstances
	modifiers += _get_rival_removal_modifiers(rival_id)
	
	return base_roll + modifiers

func _get_rival_removal_modifiers(rival_id: String) -> int:
	"""Get modifiers for rival removal based on circumstances"""
	var modifiers = 0
	
	# Check rival type, crew actions, etc.
	# This would be expanded based on full rival system implementation
	
	return modifiers

func _remove_rival(rival_id: String) -> void:
	"""Remove rival from active rivals list"""
	if game_state_manager and game_state_manager.has_method("remove_rival"):
		game_state_manager.remove_rival(rival_id)

func _process_patron_status() -> void:
	"""Step 2: Resolve Patron Status"""
	if GameEnums:
		current_substep = GameEnums.PostBattleSubPhase.PATRON_STATUS
		UniversalSignalManager.emit_signal_safe(self, "post_battle_substep_changed", [current_substep], "PostBattlePhase patron_status")
	
	var patrons_added: Array[String] = []
	
	# If mission was successful and involved a patron
	if mission_successful and battle_result.has("patron_id"):
		var patron_id = battle_result.patron_id
		
		# Add successful patrons to contacts
		if GameState and GameState.has_method("add_patron_contact"):
			GameState.add_patron_contact(patron_id)
			patrons_added.append(patron_id)
			print("PostBattlePhase: Patron %s added to contacts" % patron_id)
	
	# Handle persistent patrons
	_handle_persistent_patrons()
	
	UniversalSignalManager.emit_signal_safe(self, "patron_status_resolved", [patrons_added], "PostBattlePhase patron_status_resolved")
	
	# Continue to quest progress
	_process_quest_progress()

func _handle_persistent_patrons() -> void:
	"""Handle patrons with persistence trait"""
	# This would check for patrons with persistence and maintain their availability
	pass

func _process_quest_progress() -> void:
	"""Step 3: Determine Quest Progress"""
	if GameEnums:
		current_substep = GameEnums.PostBattleSubPhase.QUEST_PROGRESS
		UniversalSignalManager.emit_signal_safe(self, "post_battle_substep_changed", [current_substep], "PostBattlePhase quest_progress")
	
	var quest_progress = 0
	
	# Check if currently on a quest
	if GameState and GameState.has_method("has_active_quest") and GameState.has_active_quest():
		# Roll D6 + Quest Rumors to advance quest
		var base_roll = randi_range(1, 6)
		var quest_rumors = 0
		if GameState.has_method("get_quest_rumors"):
			quest_rumors = GameState.get_quest_rumors()
		
		quest_progress = base_roll + quest_rumors
		
		# Update quest progress
		if GameState.has_method("advance_quest"):
			GameState.advance_quest(quest_progress)
		
		print("PostBattlePhase: Quest advanced by %d points" % quest_progress)
	
	UniversalSignalManager.emit_signal_safe(self, "quest_progress_updated", [quest_progress], "PostBattlePhase quest_progress_updated")
	
	# Continue to payment
	_process_payment()

func _process_payment() -> void:
	"""Step 4: Get Paid"""
	if GameEnums:
		current_substep = GameEnums.PostBattleSubPhase.GET_PAID
		UniversalSignalManager.emit_signal_safe(self, "post_battle_substep_changed", [current_substep], "PostBattlePhase get_paid")
	
	var total_payment = 0
	
	# Base mission payment
	if mission_successful:
		var base_payment = UniversalDataAccess.get_dict_value_safe(battle_result, "base_payment", 0, "PostBattlePhase base_payment")
		total_payment += base_payment
		
		# Danger pay bonuses
		var danger_pay = UniversalDataAccess.get_dict_value_safe(battle_result, "danger_pay", 0, "PostBattlePhase danger_pay")
		total_payment += danger_pay
		
		print("PostBattlePhase: Mission payment: %d credits (base: %d, danger: %d)" % [total_payment, base_payment, danger_pay])
	else:
		print("PostBattlePhase: Mission failed - no payment received")
	
	# Award payment
	if total_payment > 0 and GameState and GameState.has_method("add_credits"):
		GameState.add_credits(total_payment)
	
	UniversalSignalManager.emit_signal_safe(self, "payment_received", [total_payment], "PostBattlePhase payment_received")
	
	# Continue to battlefield finds
	_process_battlefield_finds()

func _process_battlefield_finds() -> void:
	"""Step 5: Battlefield Finds"""
	if GameEnums:
		current_substep = GameEnums.PostBattleSubPhase.BATTLEFIELD_FINDS
		UniversalSignalManager.emit_signal_safe(self, "post_battle_substep_changed", [current_substep], "PostBattlePhase battlefield_finds")
	
	var battlefield_finds: Array[Dictionary] = []
	
	# Search battlefield for items and clues
	var search_attempts = crew_participants.size() # Each crew member can search
	
	for i in range(search_attempts):
		var find = _roll_battlefield_find()
		if find:
			battlefield_finds.append(find)
	
	print("PostBattlePhase: Found %d items on battlefield" % battlefield_finds.size())
	
	UniversalSignalManager.emit_signal_safe(self, "battlefield_finds_completed", [battlefield_finds], "PostBattlePhase battlefield_finds_completed")
	
	# Continue to invasion check
	_process_invasion_check()

func _roll_battlefield_find() -> Dictionary:
	"""Roll for battlefield finds"""
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
	"""Step 6: Check for Invasion"""
	if GameEnums:
		current_substep = GameEnums.PostBattleSubPhase.CHECK_INVASION
		UniversalSignalManager.emit_signal_safe(self, "post_battle_substep_changed", [current_substep], "PostBattlePhase check_invasion")
	
	# Roll for world invasion status
	var invasion_roll = randi_range(1, 100)
	var invasion_pending = invasion_roll <= 5 # 5% chance of invasion
	
	if invasion_pending:
		print("PostBattlePhase: World invasion detected!")
		if GameState and GameState.has_method("set_invasion_pending"):
			GameState.set_invasion_pending(true)
	
	UniversalSignalManager.emit_signal_safe(self, "invasion_checked", [invasion_pending], "PostBattlePhase invasion_checked")
	
	# Continue to loot gathering
	_process_loot_gathering()

func _process_loot_gathering() -> void:
	"""Step 7: Gather the Loot"""
	if GameEnums:
		current_substep = GameEnums.PostBattleSubPhase.GATHER_LOOT
		UniversalSignalManager.emit_signal_safe(self, "post_battle_substep_changed", [current_substep], "PostBattlePhase gather_loot")
	
	var gathered_loot: Array[Dictionary] = []
	
	# Roll on loot tables based on enemies defeated
	for enemy in defeated_enemies:
		var enemy_loot = _roll_enemy_loot(enemy)
		if enemy_loot.size() > 0:
			gathered_loot.append_array(enemy_loot)
	
	print("PostBattlePhase: Gathered %d loot items" % gathered_loot.size())
	
	# Add loot to inventory
	for loot_item in gathered_loot:
		_add_loot_to_inventory(loot_item)
	
	UniversalSignalManager.emit_signal_safe(self, "loot_gathered", [gathered_loot], "PostBattlePhase loot_gathered")
	
	# Continue to injuries
	_process_injuries()

func _roll_enemy_loot(enemy: Dictionary) -> Array[Dictionary]:
	"""Roll for loot from defeated enemy"""
	var loot: Array[Dictionary] = []
	var enemy_type = UniversalDataAccess.get_dict_value_safe(enemy, "type", "basic", "PostBattlePhase enemy_type")
	
	# Different loot tables based on enemy type
	match enemy_type:
		"elite":
			if randi_range(1, 6) >= 4: # 50% chance
				loot.append({"type": "weapon", "quality": "advanced", "description": "Elite weapon"})
		"boss":
			if randi_range(1, 6) >= 3: # 67% chance
				loot.append({"type": "special", "quality": "rare", "description": "Boss loot"})
		_:
			if randi_range(1, 6) >= 5: # 33% chance
				loot.append({"type": "equipment", "quality": "basic", "description": "Standard gear"})
	
	return loot

func _add_loot_to_inventory(loot_item: Dictionary) -> void:
	"""Add loot item to crew inventory"""
	if GameState and GameState.has_method("add_inventory_item"):
		GameState.add_inventory_item(loot_item)

func _process_injuries() -> void:
	"""Step 8: Determine Injuries and Recovery"""
	if GameEnums:
		current_substep = GameEnums.PostBattleSubPhase.INJURIES
		UniversalSignalManager.emit_signal_safe(self, "post_battle_substep_changed", [current_substep], "PostBattlePhase injuries")
	
	var processed_injuries: Array[Dictionary] = []
	
	# Process each injury from battle
	for injury_data in injuries_sustained:
		var processed_injury = _process_single_injury(injury_data)
		processed_injuries.append(processed_injury)
	
	print("PostBattlePhase: Processed %d injuries" % processed_injuries.size())
	
	UniversalSignalManager.emit_signal_safe(self, "injuries_resolved", [processed_injuries], "PostBattlePhase injuries_resolved")
	
	# Continue to experience
	_process_experience()

func _process_single_injury(injury_data: Dictionary) -> Dictionary:
	"""Process a single crew injury"""
	var crew_id = UniversalDataAccess.get_dict_value_safe(injury_data, "crew_id", "", "PostBattlePhase injury_crew_id")
	var injury_type = UniversalDataAccess.get_dict_value_safe(injury_data, "type", "minor", "PostBattlePhase injury_type")
	
	# Roll on injury table to determine severity and recovery time
	var injury_roll = randi_range(1, 6)
	var recovery_time = 0
	var permanent_effect = false
	
	match injury_type:
		"minor":
			recovery_time = injury_roll # 1-6 turns
		"serious":
			recovery_time = injury_roll + 3 # 4-9 turns
			permanent_effect = injury_roll == 1 # 16% chance
		"critical":
			recovery_time = injury_roll + 6 # 7-12 turns
			permanent_effect = injury_roll <= 2 # 33% chance
	
	var processed_injury = {
		"crew_id": crew_id,
		"type": injury_type,
		"recovery_time": recovery_time,
		"permanent_effect": permanent_effect
	}
	
	# Apply injury to crew member
	if GameState and GameState.has_method("apply_crew_injury"):
		GameState.apply_crew_injury(crew_id, processed_injury)
	
	return processed_injury

func _process_experience() -> void:
	"""Step 9: Experience and Character Upgrades"""
	if GameEnums:
		current_substep = GameEnums.PostBattleSubPhase.EXPERIENCE
		UniversalSignalManager.emit_signal_safe(self, "post_battle_substep_changed", [current_substep], "PostBattlePhase experience")
	
	var xp_awards: Array[Dictionary] = []
	
	# Award XP for participation and achievements
	for crew_id in crew_participants:
		var xp_earned = _calculate_crew_xp(crew_id)
		if xp_earned > 0:
			xp_awards.append({"crew_id": crew_id, "xp": xp_earned})
			
			# Apply XP to crew member
			if GameState and GameState.has_method("add_crew_experience"):
				GameState.add_crew_experience(crew_id, xp_earned)
	
	print("PostBattlePhase: Awarded XP to %d crew members" % xp_awards.size())
	
	UniversalSignalManager.emit_signal_safe(self, "experience_awarded", [xp_awards], "PostBattlePhase experience_awarded")
	
	# Continue to training
	_process_training()

func _calculate_crew_xp(crew_id: String) -> int:
	"""Calculate XP earned by crew member"""
	var xp = 1 # Base XP for participation
	
	# Additional XP for achievements
	if mission_successful:
		xp += 1
	
	# Check for special achievements (kills, objectives, etc.)
	xp += _get_achievement_xp(crew_id)
	
	return xp

func _get_achievement_xp(crew_id: String) -> int:
	"""Get bonus XP for achievements"""
	var bonus_xp = 0
	
	# This would check battle statistics for special achievements
	# First kill, objectives completed, heroic actions, etc.
	
	return bonus_xp

func _process_training() -> void:
	"""Step 10: Invest in Advanced Training"""
	if GameEnums:
		current_substep = GameEnums.PostBattleSubPhase.TRAINING
		UniversalSignalManager.emit_signal_safe(self, "post_battle_substep_changed", [current_substep], "PostBattlePhase training")
	
	# In a full implementation, this would present training options
	# For now, we'll handle automatic training opportunities
	var training_completed: Array[Dictionary] = []
	
	print("PostBattlePhase: Advanced training opportunities available")
	
	UniversalSignalManager.emit_signal_safe(self, "training_completed", [training_completed], "PostBattlePhase training_completed")
	
	# Continue to purchases
	_process_purchases()

func _process_purchases() -> void:
	"""Step 11: Purchase Items"""
	if GameEnums:
		current_substep = GameEnums.PostBattleSubPhase.PURCHASES
		UniversalSignalManager.emit_signal_safe(self, "post_battle_substep_changed", [current_substep], "PostBattlePhase purchases")
	
	# In a full implementation, this would present shop interface
	var purchases_made: Array[Dictionary] = []
	
	print("PostBattlePhase: Equipment and supplies available for purchase")
	
	UniversalSignalManager.emit_signal_safe(self, "purchases_made", [purchases_made], "PostBattlePhase purchases_made")
	
	# Continue to campaign event
	_process_campaign_event()

func _process_campaign_event() -> void:
	"""Step 12: Roll for a Campaign Event"""
	if GameEnums:
		current_substep = GameEnums.PostBattleSubPhase.CAMPAIGN_EVENT
		UniversalSignalManager.emit_signal_safe(self, "post_battle_substep_changed", [current_substep], "PostBattlePhase campaign_event")
	
	# Roll for campaign event
	var event_roll = randi_range(1, 100)
	var campaign_event = _get_campaign_event(event_roll)
	
	if campaign_event.has("type") and campaign_event.type != "none":
		print("PostBattlePhase: Campaign event: %s" % campaign_event.name)
		_apply_campaign_event(campaign_event)
	
	UniversalSignalManager.emit_signal_safe(self, "campaign_event_occurred", [campaign_event], "PostBattlePhase campaign_event_occurred")
	
	# Continue to character event
	_process_character_event()

func _get_campaign_event(roll: int) -> Dictionary:
	"""Get campaign event based on D100 roll"""
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
	"""Apply campaign event effects"""
	match event.type:
		"market_crash":
			# Affect market prices
			pass
		"tech_breakthrough":
			# Make new tech available
			pass
		"civil_unrest":
			# Increase danger levels
			pass

func _process_character_event() -> void:
	"""Step 13: Roll for a Character Event"""
	if GameEnums:
		current_substep = GameEnums.PostBattleSubPhase.CHARACTER_EVENT
		UniversalSignalManager.emit_signal_safe(self, "post_battle_substep_changed", [current_substep], "PostBattlePhase character_event")
	
	# Roll for character event
	var character_event = _get_character_event()
	
	if character_event.has("type") and character_event.type != "none":
		print("PostBattlePhase: Character event: %s" % character_event.name)
		_apply_character_event(character_event)
	
	UniversalSignalManager.emit_signal_safe(self, "character_event_occurred", [character_event], "PostBattlePhase character_event_occurred")
	
	# Continue to galactic war
	_process_galactic_war()

func _get_character_event() -> Dictionary:
	"""Get character event for random crew member"""
	if crew_participants.size() == 0:
		return {"type": "none", "name": "No Event"}
	
	var random_crew = crew_participants[randi() % crew_participants.size()]
	var event_roll = randi_range(1, 100)
	
	# Simplified character events
	if event_roll <= 15:
		return {"type": "personal_growth", "crew_id": random_crew, "name": "Personal Growth", "description": "Character develops new skills"}
	elif event_roll <= 30:
		return {"type": "contact_made", "crew_id": random_crew, "name": "New Contact", "description": "Character makes useful connection"}
	else:
		return {"type": "none", "name": "No Event"}

func _apply_character_event(event: Dictionary) -> void:
	"""Apply character event effects"""
	var crew_id = UniversalDataAccess.get_dict_value_safe(event, "crew_id", "", "PostBattlePhase character_event_crew")
	
	match event.type:
		"personal_growth":
			# Award bonus XP or skill
			if GameState and GameState.has_method("add_crew_experience"):
				GameState.add_crew_experience(crew_id, 1)
		"contact_made":
			# Add new contact for crew member
			if GameState and GameState.has_method("add_crew_contact"):
				GameState.add_crew_contact(crew_id, "random_contact")

func _process_galactic_war() -> void:
	"""Step 14: Check for Galactic War Progress"""
	if GameEnums:
		current_substep = GameEnums.PostBattleSubPhase.GALACTIC_WAR
		UniversalSignalManager.emit_signal_safe(self, "post_battle_substep_changed", [current_substep], "PostBattlePhase galactic_war")
	
	# Track large-scale conflicts and their progression
	var war_progress = _update_galactic_war_progress()
	
	print("PostBattlePhase: Galactic war status updated")
	
	UniversalSignalManager.emit_signal_safe(self, "galactic_war_updated", [war_progress], "PostBattlePhase galactic_war_updated")
	
	# Complete post-battle phase
	_complete_post_battle_phase()

func _update_galactic_war_progress() -> Dictionary:
	"""Update galactic war progression"""
	var progress = {
		"conflicts_active": 0,
		"major_events": [],
		"faction_changes": []
	}
	
	# This would track ongoing galactic conflicts and their effects on the campaign
	
	return progress

func _complete_post_battle_phase() -> void:
	"""Complete the Post-Battle Phase"""
	if GameEnums:
		current_substep = GameEnums.PostBattleSubPhase.NONE
	
	print("PostBattlePhase: Post-Battle Phase completed")
	UniversalSignalManager.emit_signal_safe(self, "post_battle_phase_completed", [], "PostBattlePhase completed")

## Public API Methods
func get_current_substep() -> int:
	"""Get the current post-battle sub-step"""
	return current_substep

func set_battle_result(result: Dictionary) -> void:
	"""Set battle result data for processing"""
	battle_result = result.duplicate()
	mission_successful = UniversalDataAccess.get_dict_value_safe(result, "success", false, "PostBattlePhase set_mission_successful")
	enemies_defeated = UniversalDataAccess.get_dict_value_safe(result, "enemies_defeated", 0, "PostBattlePhase set_enemies_defeated")

func add_injury(crew_id: String, injury_type: String) -> void:
	"""Add injury for processing"""
	injuries_sustained.append({"crew_id": crew_id, "type": injury_type})

func set_crew_participants(participants: Array[String]) -> void:
	"""Set crew members who participated in battle"""
	crew_participants = participants.duplicate()

func is_post_battle_phase_active() -> bool:
	"""Check if post-battle phase is currently active"""
	return current_substep != GameEnums.PostBattleSubPhase.NONE if GameEnums else false

func get_battle_result() -> Dictionary:
	"""Get stored battle result data"""
	return battle_result.duplicate()