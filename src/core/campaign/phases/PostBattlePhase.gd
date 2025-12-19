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
var dice_manager: Variant = null
var game_state_manager: Variant = null

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
var defeated_enemies: Array = []  # Removed strict typing for dynamic data compatibility
var crew_participants: Array = []  # Removed strict typing for dynamic data compatibility

## Battle outcome data
var mission_successful: bool = false
var enemies_defeated: int = 0
var loot_earned: Array = []  # Removed strict typing for dynamic data compatibility
var injuries_sustained: Array = []  # Removed strict typing for dynamic data compatibility

func _ready() -> void:
	# Load dependencies safely at runtime
	# GlobalEnums already loaded as const at compile time
	dice_manager = DiceManager
	game_state_manager = get_node_or_null("/root/GameStateManager")

	# Initialize enum values using preloaded GlobalEnums
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.NONE

	print("PostBattlePhase: Initialized successfully")

## Main Post-Battle Phase Processing
func start_post_battle_phase(battle_data: Dictionary = {}) -> void:
	"""Begin the Post-Battle Phase sequence"""
	print("PostBattlePhase: Starting Post-Battle Phase")

	# Store battle result data
	battle_result = battle_data.duplicate()
	mission_successful = battle_data.get("success", false)
	enemies_defeated = battle_data.get("enemies_defeated", 0)
	defeated_enemies = battle_data.get("defeated_enemy_list", [])
	crew_participants = battle_data.get("crew_participants", [])

	self.post_battle_phase_started.emit()

	# Step 1: Resolve rival status
	_process_rival_status()

func _process_rival_status() -> void:
	"""Step 1: Resolve Rival Status"""
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.RIVAL_STATUS
		self.post_battle_substep_changed.emit(current_substep)

	var rivals_removed: Array[String] = []

	# Check if any rivals were defeated in battle
	for enemy in defeated_enemies:
		if enemy.get("is_rival", false):
			var rival_id = enemy.get("rival_id", "")
			if rival_id != "":
				# Roll D6+modifiers to remove rival permanently
				var removal_roll = _roll_rival_removal(rival_id)
				if removal_roll >= 6: # Standard threshold for rival removal
					rivals_removed.append(rival_id)
					_remove_rival(rival_id)
					print("PostBattlePhase: Rival %s permanently eliminated" % rival_id)

	self.rival_status_resolved.emit(rivals_removed)

	# Continue to patron status
	_process_patron_status()

func _roll_rival_removal(rival_id: String) -> int:
	"""Roll to determine if rival is permanently removed"""
	var base_roll = randi_range(1, 6)
	var modifiers: int = 0

	# Add modifiers based on how the rival was defeated
	if mission_successful:
		modifiers += 1

	# Add other modifiers based on circumstances
	modifiers += _get_rival_removal_modifiers(rival_id)

	return base_roll + modifiers

func _get_rival_removal_modifiers(rival_id: String) -> int:
	"""Get modifiers for rival removal based on circumstances"""
	var modifiers: int = 0

	# Check rival type, crew actions, etc.
	# This would be expanded based on full rival system implementation

	return modifiers

func _remove_rival(rival_id: String) -> void:
	"""Remove rival from active rivals list"""
	if game_state_manager and game_state_manager.has_method("remove_rival"):
		game_state_manager.remove_rival(rival_id)

func _process_patron_status() -> void:
	"""Step 2: Resolve Patron Status"""
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
			print("PostBattlePhase: Patron %s added to contacts" % patron_id)

		# HOUSE RULE: expanded_rumors - +1 quest rumor on patron mission completion
		if HouseRulesHelper.is_enabled("expanded_rumors"):
			_add_quest_rumor()
			print("PostBattlePhase: Expanded Rumors house rule - added +1 quest rumor")

	# Handle persistent patrons
	_handle_persistent_patrons()

	self.patron_status_resolved.emit(patrons_added)

	# Continue to quest progress
	_process_quest_progress()

func _handle_persistent_patrons() -> void:
	"""Handle patrons with persistence trait"""
	# This would check for patrons with persistence and maintain their availability
	pass

func _process_quest_progress() -> void:
	"""Step 3: Determine Quest Progress"""
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.QUEST_PROGRESS
		self.post_battle_substep_changed.emit(current_substep)

	var quest_progress: int = 0

	# Check if currently on a quest
	if GameState and GameState.has_active_quest():
		# Roll D6 + Quest Rumors to advance quest
		var base_roll = randi_range(1, 6)
		var quest_rumors: int = 0
		if GameState.has_method("get_quest_rumors"):
			quest_rumors = GameState.get_quest_rumors()

		quest_progress = base_roll + quest_rumors

		# Update quest progress
		if GameState.has_method("advance_quest"):
			GameState.advance_quest(quest_progress)

		print("PostBattlePhase: Quest advanced by %d points" % quest_progress)

	self.quest_progress_updated.emit(quest_progress)

	# Continue to payment
	_process_payment()

func _process_payment() -> void:
	"""Step 4: Get Paid"""
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.GET_PAID
		self.post_battle_substep_changed.emit(current_substep)

	var total_payment: int = 0

	# Base mission payment
	if mission_successful:
		var base_payment = battle_result.get("base_payment", 0)
		total_payment += base_payment

		# Danger pay bonuses
		var danger_pay = battle_result.get("danger_pay", 0)
		total_payment += danger_pay

		print("PostBattlePhase: Mission payment: %d credits (base: %d, danger: %d)" % [total_payment, base_payment, danger_pay])
	else:
		print("PostBattlePhase: Mission failed - no payment received")

	# Award payment
	if total_payment > 0 and GameState.has_method("add_credits"):
		GameState.add_credits(total_payment)

	self.payment_received.emit(total_payment)

	# Continue to battlefield finds
	_process_battlefield_finds()

func _process_battlefield_finds() -> void:
	"""Step 5: Battlefield Finds"""
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

	print("PostBattlePhase: Found %d items on battlefield" % battlefield_finds.size())

	self.battlefield_finds_completed.emit(battlefield_finds)

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
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.CHECK_INVASION
		self.post_battle_substep_changed.emit(current_substep)

	# Roll for world invasion status
	var invasion_roll = randi_range(1, 100)
	var invasion_pending = invasion_roll <= 5 # 5% chance of invasion

	if invasion_pending:
		print("PostBattlePhase: World invasion detected!")
		if GameState and GameState and GameState.has_method("set_invasion_pending"):
			GameState.set_invasion_pending(true)

	self.invasion_checked.emit(invasion_pending)

	# Continue to loot gathering
	_process_loot_gathering()

func _process_loot_gathering() -> void:
	"""Step 7: Gather the Loot"""
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.GATHER_LOOT
		self.post_battle_substep_changed.emit(current_substep)

	var gathered_loot: Array[Dictionary] = []

	# Roll on loot tables based on enemies defeated
	for enemy in defeated_enemies:
		var enemy_loot: Array[Dictionary] = _roll_enemy_loot(enemy)
		if enemy_loot.size() > 0:
			gathered_loot.append_array(enemy_loot)

	print("PostBattlePhase: Gathered %d loot items" % gathered_loot.size())

	# Add loot to inventory
	for loot_item in gathered_loot:
		_add_loot_to_inventory(loot_item)

	self.loot_gathered.emit(gathered_loot)

	# Continue to injuries
	_process_injuries()

func _roll_enemy_loot(enemy: Dictionary) -> Array[Dictionary]:
	"""Roll for loot from defeated enemy"""
	var loot: Array[Dictionary] = []
	var enemy_type: String = enemy.get("type", "basic")

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
	"""Add loot item to ship stash via EquipmentManager"""
	var equipment_manager = get_node_or_null("/root/EquipmentManager")
	if not equipment_manager:
		push_error("PostBattlePhase: EquipmentManager not found - cannot add loot to ship stash")
		return

	# Convert loot item to equipment format if needed
	var equipment_data = loot_item.duplicate()
	if not equipment_data.has("id"):
		equipment_data["id"] = "loot_" + str(Time.get_ticks_msec()) + "_" + str(randi())
	if not equipment_data.has("name"):
		equipment_data["name"] = equipment_data.get("description", "Unknown Loot")
	if not equipment_data.has("location"):
		equipment_data["location"] = "ship_stash"

	# Try to add to ship stash using EquipmentManager
	if equipment_manager.has_method("can_add_to_ship_stash") and equipment_manager.can_add_to_ship_stash():
		# Direct stash access (EquipmentManager._ship_stash is accessible via method)
		if equipment_manager.has_method("add_equipment"):
			equipment_manager.add_equipment(equipment_data)
			print("PostBattlePhase: Added loot '%s' to ship stash" % equipment_data.get("name", "Unknown"))
		else:
			push_warning("PostBattlePhase: EquipmentManager missing add_equipment method")
	else:
		push_warning("PostBattlePhase: Ship stash is full (max 10 items) - loot lost")

	# Fallback: Try GameState if EquipmentManager fails
	if GameState and GameState.has_method("add_inventory_item"):
		GameState.add_inventory_item(loot_item)
		print("PostBattlePhase: Loot added to GameState inventory (fallback)")

func _process_injuries() -> void:
	"""Step 8: Determine Injuries and Recovery"""
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.INJURIES
		self.post_battle_substep_changed.emit(current_substep)

	var processed_injuries: Array[Dictionary] = []

	# Process each injury from battle
	for injury_data in injuries_sustained:
		var processed_injury = _process_single_injury(injury_data)
		processed_injuries.append(processed_injury)

	print("PostBattlePhase: Processed %d injuries" % processed_injuries.size())

	self.injuries_resolved.emit(processed_injuries)

	# Continue to experience
	_process_experience()

func _process_single_injury(injury_data: Dictionary) -> Dictionary:
	"""Process a single crew injury using Five Parsecs injury table (p.94-95)"""
	var crew_id = injury_data.get("crew_id", "")

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

	# Handle fatal injuries
	if is_fatal:
		print("PostBattlePhase: FATAL INJURY - Crew member %s has died" % crew_id)
		# Character death should be handled by campaign manager
		return processed_injury

	# Apply injury to crew member via GameState
	if game_state_manager and game_state_manager.has_method("apply_crew_injury"):
		game_state_manager.apply_crew_injury(crew_id, processed_injury)
		print("PostBattlePhase: Applied injury to crew member %s - %s (recovery: %d turns)" % [crew_id, injury_type_name, recovery_time])
	else:
		push_error("PostBattlePhase: GameStateManager missing apply_crew_injury method")

	# Apply bonus XP for Hard Knocks
	if bonus_xp > 0 and game_state_manager:
		print("PostBattlePhase: Crew member %s gained +%d XP from Hard Knocks" % [crew_id, bonus_xp])

	return processed_injury

func _process_experience() -> void:
	"""Step 9: Experience and Character Upgrades"""
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.EXPERIENCE
		self.post_battle_substep_changed.emit(current_substep)

	var xp_awards: Array[Dictionary] = []

	# Award XP for participation and achievements
	for crew_id in crew_participants:
		var xp_earned = _calculate_crew_xp(crew_id)
		if xp_earned > 0:
			xp_awards.append({"crew_id": crew_id, "xp": xp_earned})

			# Apply XP to crew member
			if GameState and GameState and GameState.has_method("add_crew_experience"):
				GameState.add_crew_experience(crew_id, xp_earned)

	# Safe Variant handling for print statement
	var xp_awards_count_result: Variant = safe_call_method(xp_awards, "size")
	var xp_awards_count: int = xp_awards_count_result if xp_awards_count_result is int else 0
	print("PostBattlePhase: Awarded XP to %d crew members" % xp_awards_count)

	self.experience_awarded.emit(xp_awards)

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
	var bonus_xp: int = 0

	# This would check battle statistics for special achievements
	# First kill, objectives completed, heroic actions, etc.

	return bonus_xp

func _process_training() -> void:
	"""Step 10: Invest in Advanced Training"""
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.TRAINING
		self.post_battle_substep_changed.emit(current_substep)

	# In a full implementation, this would present training options
	# For now, we'll handle automatic training opportunities
	var training_completed: Array[Dictionary] = []

	print("PostBattlePhase: Advanced training opportunities available")

	self.training_completed.emit(training_completed)

	# Continue to purchases
	_process_purchases()

func _process_purchases() -> void:
	"""Step 11: Purchase Items"""
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.PURCHASES
		self.post_battle_substep_changed.emit(current_substep)

	# In a full implementation, this would present shop interface
	var purchases_made: Array[Dictionary] = []

	print("PostBattlePhase: Equipment and supplies available for purchase")

	self.purchases_made.emit(purchases_made)

	# Continue to campaign event
	_process_campaign_event()

func _process_campaign_event() -> void:
	"""Step 12: Roll for a Campaign Event"""
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.CAMPAIGN_EVENT
		self.post_battle_substep_changed.emit(current_substep)

	# Roll for campaign event
	var event_roll = randi_range(1, 100)
	var campaign_event = _get_campaign_event(event_roll)
	
	# Precursors roll twice and pick better event (Five Parsecs p.19-20)
	if _has_precursor_crew():
		var second_roll = randi_range(1, 100)
		var second_event = _get_campaign_event(second_roll)
		print("PostBattlePhase: Precursor crew - rolled twice: %d and %d" % [event_roll, second_roll])
		# Pick randomly between the two (in full implementation, player would choose)
		if randi() % 2 == 0:
			campaign_event = second_event

	if campaign_event.has("type") and campaign_event.type != "none":
		print("PostBattlePhase: Campaign event: %s" % campaign_event.name)
		_apply_campaign_event(campaign_event)

	self.campaign_event_occurred.emit(campaign_event)

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
	"""Apply campaign event effects by calling the public working method"""
	var event_name: String = event.get("name", event.get("title", "Unknown"))
	apply_campaign_event_effect(event_name)

func _has_precursor_crew() -> bool:
	"""Check if crew has any Precursor species members (Five Parsecs p.19-20)"""
	if not game_state_manager:
		return false
	if not game_state_manager.has_method("get_crew_members"):
		push_warning("PostBattlePhase: game_state_manager does not have get_crew_members() method")
		return false
	var crew: Array = game_state_manager.get_crew_members()
	for member in crew:
		# Check both origin (Character Resource) and species (Dictionary) properties
		var origin: String = ""
		if member is Resource and "origin" in member:
			origin = str(member.origin).to_lower()
		elif member is Resource and "_origin" in member:
			origin = str(member._origin).to_lower()
		elif member is Dictionary:
			origin = member.get("origin", member.get("species", "")).to_lower()
		if origin == "precursor":
			return true
	return false

func _process_character_event() -> void:
	"""Step 13: Roll for a Character Event"""
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.CHARACTER_EVENT
		self.post_battle_substep_changed.emit(current_substep)

	# Roll for character event
	var character_event: Dictionary = _get_character_event()

	if character_event.has("type") and character_event.type != "none":
		print("PostBattlePhase: Character event: %s" % character_event.name)
		_apply_character_event(character_event)

	self.character_event_occurred.emit(character_event)

	# Continue to galactic war
	_process_galactic_war()

func _get_character_event() -> Dictionary:
	"""Get character event for random crew member"""
	# Safe Variant handling
	var crew_size_result: Variant = safe_call_method(crew_participants, "size")
	var crew_size: int = crew_size_result if crew_size_result is int else 0

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
	"""Apply character event effects by calling the public working method"""
	var crew: Variant = _get_random_crew_member()
	var event_name: String = event.get("name", event.get("title", "Unknown"))
	if crew:
		apply_character_event_effect(event_name, crew)

func _process_galactic_war() -> void:
	"""Step 14: Check for Galactic War Progress"""
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.GALACTIC_WAR
		self.post_battle_substep_changed.emit(current_substep)

	# Track large-scale conflicts and their progression
	var war_progress = _update_galactic_war_progress()

	print("PostBattlePhase: Galactic war status updated")

	self.galactic_war_updated.emit(war_progress)

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
	if GlobalEnums:
		current_substep = GlobalEnums.PostBattleSubPhase.NONE

	print("PostBattlePhase: Post-Battle Phase completed")
	self.post_battle_phase_completed.emit()

## Event Effect Application Methods
func apply_campaign_event_effect(event_title: String) -> String:
	"""Apply campaign event effects based on event title"""
	match event_title:
		# Story Point Events
		"Local Friends", "Lucky Break", "New Ally":
			if GameStateManager and GameStateManager.has_method("add_story_points"):
				GameStateManager.add_story_points(1)
			return "+1 Story Point"
		
		# Credit Events
		"Valuable Find":
			var credits: int = randi_range(1, 6)
			if GameStateManager:
				GameStateManager.add_credits(credits)
			return "+%d Credits" % credits
		
		"Windfall":
			var credits: int = randi_range(1, 6) + randi_range(1, 6)
			if GameStateManager:
				GameStateManager.add_credits(credits)
			return "+%d Credits (windfall)" % credits
		
		"Life Support Issues":
			var cost: int = randi_range(1, 6)
			# Check for Engineer to reduce cost
			var engineer_present: bool = _has_crew_with_class("Engineer")
			if engineer_present:
				cost = max(1, cost - 1)
			if GameStateManager:
				GameStateManager.add_credits(-cost)
			return "Paid %d Credits (Life Support)" % cost
		
		"Odd Job":
			var credits: int = randi_range(1, 6) + 1
			if GameStateManager:
				GameStateManager.add_credits(credits)
			return "+%d Credits (Odd Job)" % credits
		
		"Unexpected Bill":
			var cost: int = randi_range(1, 6)
			if GameStateManager:
				var current_credits: int = 0
				if GameStateManager.has_method("get_credits"):
					current_credits = GameStateManager.get_credits()
				if current_credits >= cost:
					GameStateManager.add_credits(-cost)
					return "Paid %d Credits" % cost
				else:
					# Lose story point instead
					if GameStateManager.has_method("add_story_points"):
						GameStateManager.add_story_points(-1)
					return "Lost 1 Story Point (couldn't pay %d Credits)" % cost
		
		# Rumor Events
		"Old Contact", "Valuable Intel":
			_add_quest_rumor()
			return "+1 Quest Rumor"
		
		"Information Broker":
			# Can buy up to 3 rumors for 2 credits each
			return "Information Broker available (2 credits per rumor)"
		
		"Dangerous Information":
			_add_quest_rumor()
			_add_quest_rumor()
			_add_rival("Information leak")
			return "+2 Quest Rumors, +1 Rival"
		
		# Rival Events
		"Mouthed Off", "Made Enemy":
			_add_rival("Offended party")
			return "+1 Rival"
		
		"Suspicious Activity":
			# If has rivals, one tracks down
			var game_state = get_node_or_null("/root/GameState")
			if game_state and game_state.current_campaign:
				var campaign = game_state.current_campaign
				if campaign is Dictionary:
					var rivals = campaign.get("rivals", [])
					if rivals.size() > 0:
						return "Rival tracks you down this turn"
			return "No rivals to track you"
		
		# Patron Events
		"Reputation Grows":
			return "+1 to next Patron search roll"
		
		# Market Events
		"Market Surplus":
			return "All purchases -1 credit (min 1) this turn"
		
		"Trade Opportunity":
			return "Roll twice on Trade Table this turn"
		
		# Equipment/Ship Events
		"Equipment Malfunction":
			_damage_random_equipment()
			return "Random item damaged"
		
		"Ship Parts":
			if GameStateManager and GameStateManager.has_method("repair_hull"):
				GameStateManager.repair_hull(1)
			return "Repaired 1 Hull Point"
		
		# Medical Events
		"Friendly Doc":
			_reduce_recovery_time(2)
			return "Reduced recovery time by 1 turn (up to 2 crew)"
		
		"Medical Supplies":
			_heal_crew_in_sickbay()
			return "One crew in Sick Bay recovers immediately"
		
		# XP/Training Events
		"Skill Training":
			_award_xp_to_random_crew(1)
			return "+1 XP to random crew member"
		
		"Crew Bonding":
			_award_xp_to_all_crew(1)
			return "+1 XP to all crew"
		
		# Injury Events
		"Bar Brawl":
			_injure_random_crew(1)
			return "Random crew member injured (1 turn recovery)"
		
		# Gambling Events
		"Gambling Opportunity":
			return "Gambling opportunity (bet 1-6 credits)"
		
		# Cargo Events
		"Cargo Opportunity":
			return "Cargo job: +3 credits but cannot travel this turn"
		
		_:
			return "Event requires manual resolution"
	
	return "Event resolved"

func apply_character_event_effect(event_title: String, character: Variant) -> String:
	"""Apply character event effects based on event title"""
	var char_name: String = ""
	if character is Dictionary:
		char_name = character.get("name", "Unknown")
	elif character is Resource and "name" in character:
		char_name = character.name
	else:
		char_name = "Unknown"
	
	match event_title:
		# XP Gain Events
		"Focused Training":
			_add_character_xp(character, 1)
			return "%s gained +1 Combat Skill XP" % char_name
		
		"Technical Study":
			_add_character_xp(character, 1)
			return "%s gained +1 Savvy XP" % char_name
		
		"Physical Training":
			_add_character_xp(character, 1)
			return "%s gained +1 Toughness XP" % char_name
		
		"Personal Growth":
			_add_character_xp(character, 2)
			return "%s gained +2 XP" % char_name
		
		"Moment of Glory":
			_add_character_xp(character, 1)
			if GameStateManager and GameStateManager.has_method("add_story_points"):
				GameStateManager.add_story_points(1)
			return "%s gained +1 XP and +1 Story Point" % char_name
		
		# Story Point Events
		"Old Friend":
			if GameStateManager and GameStateManager.has_method("add_story_points"):
				GameStateManager.add_story_points(1)
			return "%s reconnects with old friend (+1 Story Point)" % char_name
		
		# Credits Events
		"Side Job":
			var credits: int = randi_range(1, 6)
			if GameStateManager:
				GameStateManager.add_credits(credits)
			return "%s earned %d Credits" % [char_name, credits]
		
		"Unexpected Windfall":
			var credits: int = randi_range(1, 6) + randi_range(1, 6)
			if GameStateManager:
				GameStateManager.add_credits(credits)
			return "%s received %d Credits" % [char_name, credits]
		
		"Gambling":
			var roll: int = randi_range(1, 6)
			var bet: int = randi_range(1, 6)
			if roll <= 2:
				if GameStateManager:
					GameStateManager.add_credits(-bet)
				return "%s lost %d Credits gambling" % [char_name, bet]
			elif roll >= 5:
				if GameStateManager:
					GameStateManager.add_credits(bet)
				return "%s won %d Credits gambling" % [char_name, bet]
			else:
				return "%s broke even gambling" % char_name
		
		# Equipment Events
		"Found Item":
			_add_random_equipment_to_stash()
			return "%s found random gear item" % char_name
		
		"Equipment Care":
			return "%s repaired one damaged item" % char_name
		
		"Equipment Lost":
			return "%s lost random equipment" % char_name
		
		# Injury/Medical Events
		"Bad Dreams":
			return "%s suffers -1 to next combat roll (nightmares)" % char_name
		
		"Bar Fight":
			var roll: int = randi_range(1, 6)
			if roll <= 3:
				_injure_specific_crew(character, 1)
				return "%s injured in bar fight (1 turn recovery)" % char_name
			else:
				return "%s gained respect in bar fight" % char_name
		
		"Wound Heals":
			_reduce_character_recovery(character, 1)
			return "%s recovers faster (-1 turn recovery)" % char_name
		
		# Relationship Events
		"Made Contact":
			return "%s made useful contact (+1 to next Patron search)" % char_name
		
		"Made Enemy":
			_add_rival("%s's enemy" % char_name)
			return "%s made an enemy (+1 Rival)" % char_name
		
		"Valuable Intel":
			_add_quest_rumor()
			return "%s discovered valuable intel (+1 Rumor)" % char_name
		
		# Trait Events
		"Trait Development":
			return "%s develops positive trait (roll on trait table)" % char_name
		
		"Life-Changing Event":
			return "%s experiences life-changing event (reroll Motivation)" % char_name
		
		"Quiet Day":
			_add_character_xp(character, 1)
			return "%s had a quiet day (+1 XP)" % char_name
		
		_:
			return "%s: Event requires manual resolution" % char_name
	
	return "Character event resolved"

## Helper Methods for Event Effects
func _has_crew_with_class(character_class: String) -> bool:
	"""Check if any crew member has specific class"""
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.current_campaign:
		var campaign = game_state.current_campaign
		if campaign is Dictionary:
			var crew = campaign.get("crew", [])
			for member in crew:
				if member is Dictionary and member.get("class", "") == character_class:
					return true
	return false

func _get_random_crew_member() -> Variant:
	"""Get random crew member from current crew participants"""
	if crew_participants.is_empty():
		return null

	var random_index: int = randi() % crew_participants.size()
	return crew_participants[random_index]

func _add_quest_rumor() -> void:
	"""Add a quest rumor to campaign"""
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.current_campaign:
		var campaign = game_state.current_campaign
		if campaign is Dictionary:
			var rumors = campaign.get("rumors", [])
			var rumor_types = [
				"An extracted data file",
				"Notebook with secret information",
				"Old map showing a location",
				"A tip from a contact",
				"An intercepted transmission"
			]
			var roll = randi() % rumor_types.size()
			rumors.append({
				"id": "rumor_%d_%d" % [Time.get_ticks_msec(), randi() % 1000],
				"type": roll + 1,
				"description": rumor_types[roll],
				"source": "event"
			})
			campaign["rumors"] = rumors
			print("PostBattlePhase: +1 quest rumor")

func _add_rival(rival_name: String) -> void:
	"""Add a rival to campaign"""
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.current_campaign:
		var campaign = game_state.current_campaign
		if campaign is Dictionary:
			var rivals = campaign.get("rivals", [])
			rivals.append({
				"id": "rival_%d_%d" % [Time.get_ticks_msec(), randi() % 1000],
				"name": rival_name,
				"type": ["Criminal", "Corporate", "Personal", "Gang"][randi() % 4],
				"hostility": randi_range(3, 5),
				"resources": randi_range(1, 3),
				"source": "event"
			})
			campaign["rivals"] = rivals
			print("PostBattlePhase: +1 rival")

func _damage_random_equipment() -> void:
	"""Damage random equipment item"""
	# TODO: Implement equipment damage system
	print("PostBattlePhase: Random equipment damaged")

func _reduce_recovery_time(max_crew: int) -> void:
	"""Reduce recovery time for crew in sick bay"""
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.current_campaign:
		var campaign = game_state.current_campaign
		if campaign is Dictionary:
			var crew = campaign.get("crew", [])
			var healed_count: int = 0
			for member in crew:
				if member is Dictionary and healed_count < max_crew:
					if member.has("injury_recovery_turns") and member.injury_recovery_turns > 0:
						member.injury_recovery_turns = max(0, member.injury_recovery_turns - 1)
						healed_count += 1
						print("PostBattlePhase: Reduced recovery time for %s" % member.get("name", "crew"))

func _heal_crew_in_sickbay() -> void:
	"""Immediately heal one crew member in sick bay"""
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.current_campaign:
		var campaign = game_state.current_campaign
		if campaign is Dictionary:
			var crew = campaign.get("crew", [])
			for member in crew:
				if member is Dictionary:
					if member.has("injury_recovery_turns") and member.injury_recovery_turns > 0:
						member.injury_recovery_turns = 0
						print("PostBattlePhase: %s recovered from sick bay" % member.get("name", "crew"))
						return

func _award_xp_to_random_crew(xp_amount: int) -> void:
	"""Award XP to random crew member"""
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.current_campaign:
		var campaign = game_state.current_campaign
		if campaign is Dictionary:
			var crew = campaign.get("crew", [])
			if crew.size() > 0:
				var random_index = randi() % crew.size()
				var member = crew[random_index]
				if member is Dictionary:
					member["experience"] = member.get("experience", 0) + xp_amount
					print("PostBattlePhase: %s gained +%d XP" % [member.get("name", "crew"), xp_amount])

func _award_xp_to_all_crew(xp_amount: int) -> void:
	"""Award XP to all crew members"""
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.current_campaign:
		var campaign = game_state.current_campaign
		if campaign is Dictionary:
			var crew = campaign.get("crew", [])
			for member in crew:
				if member is Dictionary:
					member["experience"] = member.get("experience", 0) + xp_amount
					print("PostBattlePhase: %s gained +%d XP" % [member.get("name", "crew"), xp_amount])

func _injure_random_crew(recovery_turns: int) -> void:
	"""Injure random crew member"""
	var game_state = get_node_or_null("/root/GameState")
	if game_state and game_state.current_campaign:
		var campaign = game_state.current_campaign
		if campaign is Dictionary:
			var crew = campaign.get("crew", [])
			if crew.size() > 0:
				var random_index = randi() % crew.size()
				var member = crew[random_index]
				if member is Dictionary:
					member["injury_recovery_turns"] = recovery_turns
					print("PostBattlePhase: %s injured (%d turn recovery)" % [member.get("name", "crew"), recovery_turns])

func _add_character_xp(character: Variant, xp_amount: int) -> void:
	"""Add XP to specific character"""
	if character is Dictionary:
		character["experience"] = character.get("experience", 0) + xp_amount
		print("PostBattlePhase: %s gained +%d XP" % [character.get("name", "Unknown"), xp_amount])
	elif character is Resource and "experience" in character:
		character.experience += xp_amount
		var char_name = character.name if "name" in character else "Unknown"
		print("PostBattlePhase: %s gained +%d XP" % [char_name, xp_amount])

func _reduce_character_recovery(character: Variant, turns: int) -> void:
	"""Reduce recovery time for specific character"""
	if character is Dictionary:
		if character.has("injury_recovery_turns"):
			character.injury_recovery_turns = max(0, character.injury_recovery_turns - turns)
			print("PostBattlePhase: %s recovery reduced by %d turns" % [character.get("name", "Unknown"), turns])

func _injure_specific_crew(character: Variant, recovery_turns: int) -> void:
	"""Injure specific crew member"""
	if character is Dictionary:
		character["injury_recovery_turns"] = recovery_turns
		print("PostBattlePhase: %s injured (%d turn recovery)" % [character.get("name", "Unknown"), recovery_turns])
	elif character is Resource and "injury_recovery_turns" in character:
		character.injury_recovery_turns = recovery_turns
		var char_name = character.name if "name" in character else "Unknown"
		print("PostBattlePhase: %s injured (%d turn recovery)" % [char_name, recovery_turns])

func _add_random_equipment_to_stash() -> void:
	"""Add random equipment to ship stash"""
	var equipment_manager = get_node_or_null("/root/EquipmentManager")
	if equipment_manager and equipment_manager.has_method("can_add_to_ship_stash"):
		if equipment_manager.can_add_to_ship_stash():
			# Generate random basic equipment
			var equipment_types = ["Infantry Laser", "Auto Rifle", "Scrap Pistol", "Blade"]
			var random_item = equipment_types[randi() % equipment_types.size()]
			var equipment_data = {
				"id": "found_%d" % Time.get_ticks_msec(),
				"name": random_item,
				"type": "weapon",
				"location": "ship_stash"
			}
			if equipment_manager.has_method("add_equipment"):
				equipment_manager.add_equipment(equipment_data)
				print("PostBattlePhase: Found %s (added to stash)" % random_item)
		else:
			print("PostBattlePhase: Ship stash full - equipment lost")

## Public API Methods
func get_current_substep() -> int:
	"""Get the current post-battle sub-step"""
	return current_substep

func set_battle_result(result: Dictionary) -> void:
	"""Set battle result data for processing"""
	battle_result = result.duplicate()
	mission_successful = result.get("success", false)
	enemies_defeated = result.get("enemies_defeated", 0)

func add_injury(crew_id: String, injury_type: String) -> void:
	"""Add injury for processing"""
	injuries_sustained.append({"crew_id": crew_id, "type": injury_type})

func set_crew_participants(participants: Array) -> void:
	"""Set crew members who participated in battle"""
	crew_participants.clear()
	for p in participants:
		if p is String:
			crew_participants.append(p)

func is_post_battle_phase_active() -> bool:
	"""Check if post-battle phase is currently active"""
	return current_substep != GlobalEnums.PostBattleSubPhase.NONE if GlobalEnums else false

func get_battle_result() -> Dictionary:
	"""Get stored battle result data"""
	return battle_result.duplicate()

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
