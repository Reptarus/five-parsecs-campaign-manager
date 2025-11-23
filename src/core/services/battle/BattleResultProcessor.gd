extends Node

## Battle Result Processor - Post-Battle Campaign State Updates
## Processes battle results and applies them to campaign state, crew, and story progression
## Updated for modern codebase architecture

# Runtime dependencies
var game_state_manager: Node = null

# Processing Configuration
var auto_process_enabled: bool = true
var experience_multiplier: float = 1.0
var credit_multiplier: float = 1.0
var injury_recovery_enabled: bool = true

# Signals
signal results_processed(session_id: String, changes_applied: Dictionary)
signal experience_gained(crew_member: String, experience: int)
signal injury_sustained(crew_member: String, injury_data: Dictionary)
signal loot_acquired(items: Array, credits: int)
signal story_progression(developments: Array)
signal processing_error(error_message: String)

func _ready() -> void:
	"""Initialize battle result processor"""
	# Initialize game state manager reference
	if GameStateManager:
		game_state_manager = GameStateManager
	print("BattleResultProcessor: Initialized successfully")

## Public Interface

func process_results(battle_results: Dictionary) -> Dictionary:
	"""Process complete battle results and update campaign state"""
	if not battle_results:
		processing_error.emit("No battle results provided")
		return {"success": false, "error": "No results"}
	
	print("BattleResultProcessor: Processing battle results for session %s" % battle_results.get("session_id", "unknown"))
	
	var changes_applied = {}
	
	# Process each type of result (with error handling)
	var casualty_result = _process_casualties(battle_results.get("crew_casualties", []))
	if casualty_result.has("error"):
		return {"success": false, "error": "Casualty processing failed: " + casualty_result.error}
	changes_applied["casualties"] = casualty_result
	
	var experience_result = _process_experience(battle_results.get("crew_experience", {}))
	if experience_result.has("error"):
		return {"success": false, "error": "Experience processing failed: " + experience_result.error}
	changes_applied["experience"] = experience_result
	
	var loot_result = _process_loot(battle_results.get("loot_acquired", []), battle_results.get("credits_earned", 0))
	if loot_result.has("error"):
		return {"success": false, "error": "Loot processing failed: " + loot_result.error}
	changes_applied["loot"] = loot_result
	
	# Process remaining result types
	changes_applied["story"] = _process_story_developments(battle_results.get("story_developments", []))
	changes_applied["relationships"] = _process_relationships(battle_results.get("patron_relationships", {}), battle_results.get("rival_encounters", {}))
	changes_applied["equipment"] = _process_equipment_changes(battle_results.get("equipment_lost", []))
	
	# Update campaign state
	_update_campaign_state(battle_results, changes_applied)
	
	# Save changes using SaveManager autoload
	if auto_process_enabled:
		var save_manager = get_node_or_null("/root/SaveManager")
		if save_manager and save_manager.has_method("quick_save"):
			save_manager.quick_save()
	
	results_processed.emit(battle_results.get("session_id", "unknown"), changes_applied)
	print("BattleResultProcessor: Successfully processed battle results")
	
	return {"success": true, "changes": changes_applied}

## Individual Result Processing

func _process_casualties(casualties: Array) -> Dictionary:
	"""Process crew casualties and injuries"""
	var casualty_changes = {
		"injured_crew": [],
		"recovery_times": {},
		"medical_costs": 0
	}
	
	for casualty in casualties:
		var crew_name = casualty.get("name", "Unknown")
		var injury_type = casualty.get("injury_type", "Light Wound")
		var recovery_time = casualty.get("recovery_time", 1)
		
		# Apply injury to crew member using GameState
		if game_state_manager and game_state_manager.has_method("get_game_state"):
			var game_state = game_state_manager.get_game_state()
			if game_state and game_state.has_method("apply_crew_injury"):
				game_state.apply_crew_injury(crew_name, injury_type, recovery_time)
		
		casualty_changes.injured_crew.append(crew_name)
		casualty_changes.recovery_times[crew_name] = recovery_time
		
		# Calculate medical costs
		var medical_cost = _calculate_medical_cost(injury_type)
		casualty_changes.medical_costs += medical_cost
		
		print("BattleResultProcessor: Applied injury to %s - %s (%d turns recovery)" % [crew_name, injury_type, recovery_time])
		injury_sustained.emit(crew_name, casualty)
	
	# Deduct medical costs from campaign funds using GameState
	if casualty_changes.medical_costs > 0:
		if game_state_manager and game_state_manager.has_method("get_game_state"):
			var game_state = game_state_manager.get_game_state()
			if game_state and game_state.has_method("update_campaign_credits"):
				var current_credits = game_state.get_campaign_credits() or 0
				var new_credits = max(0, current_credits - casualty_changes.medical_costs)
				game_state.update_campaign_credits(new_credits)
				print("BattleResultProcessor: Medical costs: %d credits" % casualty_changes.medical_costs)
	
	return casualty_changes

func _process_experience(experience_data: Dictionary) -> Dictionary:
	"""Process crew experience gains"""
	var experience_changes = {
		"crew_xp_gained": {},
		"level_ups": [],
		"total_xp": 0
	}
	
	for crew_name in experience_data:
		var xp_gained = int(experience_data[crew_name] * experience_multiplier)
		
		# Apply experience to crew member using GameState
		if game_state_manager and game_state_manager.has_method("get_game_state"):
			var game_state = game_state_manager.get_game_state()
			if game_state and game_state.has_method("gain_crew_experience"):
				var level_up = game_state.gain_crew_experience(crew_name, xp_gained)
				if level_up:
					experience_changes.level_ups.append(crew_name)
		
		experience_changes.crew_xp_gained[crew_name] = xp_gained
		experience_changes.total_xp += xp_gained
		
		print("BattleResultProcessor: %s gained %d experience" % [crew_name, xp_gained])
		experience_gained.emit(crew_name, xp_gained)
	
	return experience_changes

func _process_loot(loot_items: Array, credits_earned: int) -> Dictionary:
	"""Process loot and credit rewards"""
	var loot_changes = {
		"items_acquired": loot_items.duplicate(),
		"credits_gained": int(credits_earned * credit_multiplier),
		"total_value": 0
	}
	
	# Add credits to campaign funds using GameState
	if loot_changes.credits_gained > 0:
		if game_state_manager and game_state_manager.has_method("get_game_state"):
			var game_state = game_state_manager.get_game_state()
			if game_state and game_state.has_method("update_campaign_credits"):
				var current_credits = game_state.get_campaign_credits() or 0
				var new_credits = current_credits + loot_changes.credits_gained
				game_state.update_campaign_credits(new_credits)
				print("BattleResultProcessor: Gained %d credits" % loot_changes.credits_gained)
	
	# Process items
	for item in loot_items:
		_add_item_to_inventory(item)
		loot_changes.total_value += _estimate_item_value(item)
	
	if loot_items.size() > 0 or loot_changes.credits_gained > 0:
		loot_acquired.emit(loot_items, loot_changes.credits_gained)
	
	return loot_changes

func _process_story_developments(developments: Array) -> Dictionary:
	"""Process story developments and campaign progression"""
	var story_changes = {
		"developments_added": developments.duplicate(),
		"story_flags_updated": [],
		"reputation_changes": {}
	}
	
	# Add story developments to campaign log using GameState
	if game_state_manager and game_state_manager.has_method("get_game_state"):
		var game_state = game_state_manager.get_game_state()
		if game_state and game_state.has_method("add_story_development"):
			for development in developments:
				game_state.add_story_development(development)
	
	# Process specific story triggers
	for development in developments:
		_process_story_trigger(development, story_changes)
	
	if developments.size() > 0:
		story_progression.emit(developments)
	
	return story_changes

func _process_relationships(patron_relationships: Dictionary, rival_encounters: Dictionary) -> Dictionary:
	"""Process patron and rival relationship changes"""
	var relationship_changes = {
		"patron_changes": patron_relationships.duplicate(),
		"rival_changes": rival_encounters.duplicate(),
		"new_contacts": [],
		"reputation_shifts": {}
	}
	
	# Process patron relationships using GameState
	if game_state_manager and game_state_manager.has_method("get_game_state"):
		var game_state = game_state_manager.get_game_state()
		if game_state:
			for patron_id in patron_relationships:
				var relationship_change = patron_relationships[patron_id]
				if game_state.has_method("update_patron_relationship"):
					game_state.update_patron_relationship(patron_id, relationship_change)
				print("BattleResultProcessor: Patron relationship updated - %s: %s" % [patron_id, relationship_change])
			
			# Process rival encounters
			for rival_id in rival_encounters:
				var encounter_data = rival_encounters[rival_id]
				if game_state.has_method("update_rival_status"):
					game_state.update_rival_status(rival_id, encounter_data)
				print("BattleResultProcessor: Rival encounter processed - %s" % rival_id)
	
	return relationship_changes

func _process_equipment_changes(equipment_lost: Array) -> Dictionary:
	"""Process equipment losses and damage"""
	var equipment_changes = {
		"items_lost": equipment_lost.duplicate(),
		"replacement_cost": 0,
		"insurance_claims": []
	}
	
	for item in equipment_lost:
		_remove_item_from_inventory(item)
		equipment_changes.replacement_cost += _estimate_item_value(item)
		print("BattleResultProcessor: Lost equipment - %s" % item)
	
	return equipment_changes

## Helper Methods

func _calculate_medical_cost(injury_type: String) -> int:
	"""Calculate medical treatment cost based on injury severity"""
	match injury_type:
		"Light Wound":
			return 50
		"Serious Wound":
			return 150
		"Critical Wound":
			return 300
		_:
			return 100

func _add_item_to_inventory(item: String) -> void:
	"""Add item to campaign inventory using GameState"""
	if game_state_manager and game_state_manager.has_method("get_game_state"):
		var game_state = game_state_manager.get_game_state()
		if game_state and game_state.has_method("add_inventory_item"):
			game_state.add_inventory_item({
				"name": item,
				"acquired_date": Time.get_datetime_string_from_system(),
				"source": "battle_loot"
			})

func _remove_item_from_inventory(item: String) -> void:
	"""Remove item from campaign inventory using GameState"""
	if game_state_manager and game_state_manager.has_method("get_game_state"):
		var game_state = game_state_manager.get_game_state()
		if game_state and game_state.has_method("remove_inventory_item"):
			game_state.remove_inventory_item(item)

func _estimate_item_value(item: String) -> int:
	"""Estimate item value for economic calculations"""
	# Simple estimation based on item type
	if "Weapon" in item:
		return 200
	elif "Armor" in item:
		return 150
	elif "Equipment" in item:
		return 100
	elif "Medical" in item:
		return 75
	else:
		return 50

func _process_story_trigger(development: String, story_changes: Dictionary) -> void:
	"""Process individual story development triggers"""
	# Check for reputation changes
	if "reputation" in development.to_lower():
		story_changes.reputation_changes["general"] = 1
	
	# Check for new contacts
	if "contact" in development.to_lower():
		story_changes.story_flags_updated.append("new_contact_available")
	
	# Future: Add more sophisticated story trigger processing

func _update_campaign_state(battle_results: Dictionary, changes: Dictionary) -> void:
	"""Update overall campaign state based on battle results"""
	if not game_state_manager or not game_state_manager.has_method("get_game_state"):
		return
	
	var game_state = game_state_manager.get_game_state()
	if not game_state:
		return
	
	# Update battle statistics
	var battle_stats = game_state.get_battle_statistics() or {
		"battles_fought": 0,
		"victories": 0,
		"defeats": 0,
		"total_credits_earned": 0,
		"total_experience_gained": 0
	}
	
	battle_stats.battles_fought += 1
	if battle_results.get("victory", false):
		battle_stats.victories += 1
	else:
		battle_stats.defeats += 1
	
	battle_stats.total_credits_earned += battle_results.get("credits_earned", 0)
	battle_stats.total_experience_gained += changes.get("experience", {}).get("total_xp", 0)
	
	if game_state.has_method("update_battle_statistics"):
		game_state.update_battle_statistics(battle_stats)
	
	# Update last battle timestamp
	if game_state.has_method("set_last_battle_date"):
		game_state.set_last_battle_date(Time.get_datetime_string_from_system())
	
	print("BattleResultProcessor: Campaign state updated with battle results")

## Debug and Testing

func create_test_results() -> Dictionary:
	"""Create test battle results for debugging"""
	var test_results = {
		"session_id": "test_battle_" + str(Time.get_unix_time_from_system()),
		"victory": true,
		"mission_completed": true,
		"crew_experience": {"Captain": 75, "Marine": 50, "Medic": 60},
		"loot_acquired": ["Equipment: Scanner", "Weapon: Pistol"],
		"credits_earned": 350,
		"story_developments": ["Mission completed successfully", "Gained reputation with locals"],
		"crew_casualties": [],
		"patron_relationships": {},
		"rival_encounters": {},
		"equipment_lost": []
	}
	
	return test_results

func test_processing() -> void:
	"""Test battle result processing"""
	var test_results = create_test_results()
	var result = process_results(test_results)
	print("BattleResultProcessor: Test processing result - %s" % str(result))
