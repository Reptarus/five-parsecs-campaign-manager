extends Node

## Battle Result Processor - Post-Battle Campaign State Updates
## Processes battle results and applies them to campaign state, crew, and story progression

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
	print("BattleResultProcessor: Initialized successfully")

## Public Interface

func process_results(battle_results: IBattleService.BattleResults) -> Dictionary:
	"""Process complete battle results and update campaign state"""
	if not battle_results:
		processing_error.emit("No battle results provided")
		return {"success": false, "error": "No results"}
	
	print("BattleResultProcessor: Processing battle results for session %s" % battle_results.session_id)
	
	var changes_applied = {}
	
	# Process each type of result (with error handling)
	var casualty_result = _process_casualties(battle_results.crew_casualties)
	if casualty_result.has("error"):
		return {"success": false, "error": "Casualty processing failed: " + casualty_result.error}
	changes_applied["casualties"] = casualty_result
	
	var experience_result = _process_experience(battle_results.crew_experience)
	if experience_result.has("error"):
		return {"success": false, "error": "Experience processing failed: " + experience_result.error}
	changes_applied["experience"] = experience_result
	
	var loot_result = _process_loot(battle_results.loot_acquired, battle_results.credits_earned)
	if loot_result.has("error"):
		return {"success": false, "error": "Loot processing failed: " + loot_result.error}
	changes_applied["loot"] = loot_result
	
	# Process remaining result types
	changes_applied["story"] = _process_story_developments(battle_results.story_developments)
	changes_applied["relationships"] = _process_relationships(battle_results.patron_relationships, battle_results.rival_encounters)
	changes_applied["equipment"] = _process_equipment_changes(battle_results.equipment_lost)
	
	# Update campaign state
	_update_campaign_state(battle_results, changes_applied)
	
	# Save changes
	if PersistenceService and auto_process_enabled:
		PersistenceService.quick_save()
	
	results_processed.emit(battle_results.session_id, changes_applied)
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
		
		# Apply injury to crew member
		if CharacterManagerAutoload:
			CharacterManagerAutoload.apply_injury(crew_name, injury_type, recovery_time)
		
		casualty_changes.injured_crew.append(crew_name)
		casualty_changes.recovery_times[crew_name] = recovery_time
		
		# Calculate medical costs
		var medical_cost = _calculate_medical_cost(injury_type)
		casualty_changes.medical_costs += medical_cost
		
		print("BattleResultProcessor: Applied injury to %s - %s (%d turns recovery)" % [crew_name, injury_type, recovery_time])
		injury_sustained.emit(crew_name, casualty)
	
	# Deduct medical costs from campaign funds
	if casualty_changes.medical_costs > 0 and CampaignStateService:
		var current_credits = CampaignStateService.get_campaign_data("credits") or 0
		var new_credits = max(0, current_credits - casualty_changes.medical_costs)
		CampaignStateService.update_campaign_data("credits", new_credits)
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
		
		# Apply experience to crew member
		if CharacterManagerAutoload:
			var level_up = CharacterManagerAutoload.gain_experience(crew_name, xp_gained)
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
	
	# Add credits to campaign funds
	if loot_changes.credits_gained > 0 and CampaignStateService:
		var current_credits = CampaignStateService.get_campaign_data("credits") or 0
		var new_credits = current_credits + loot_changes.credits_gained
		CampaignStateService.update_campaign_data("credits", new_credits)
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
	
	# Add story developments to campaign log
	if CampaignStateService:
		var current_story = CampaignStateService.get_campaign_data("story_log") or []
		current_story.append_array(developments)
		CampaignStateService.update_campaign_data("story_log", current_story)
	
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
	
	# Process patron relationships
	for patron_id in patron_relationships:
		var relationship_change = patron_relationships[patron_id]
		_update_patron_relationship(patron_id, relationship_change)
		print("BattleResultProcessor: Patron relationship updated - %s: %s" % [patron_id, relationship_change])
	
	# Process rival encounters
	for rival_id in rival_encounters:
		var encounter_data = rival_encounters[rival_id]
		_update_rival_status(rival_id, encounter_data)
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
	"""Add item to campaign inventory"""
	if CampaignStateService:
		var inventory = CampaignStateService.get_campaign_data("inventory") or []
		inventory.append({
			"name": item,
			"acquired_date": Time.get_datetime_string_from_system(),
			"source": "battle_loot"
		})
		CampaignStateService.update_campaign_data("inventory", inventory)

func _remove_item_from_inventory(item: String) -> void:
	"""Remove item from campaign inventory"""
	if CampaignStateService:
		var inventory = CampaignStateService.get_campaign_data("inventory") or []
		# Find and remove first matching item
		for i in range(inventory.size()):
			if inventory[i].get("name", "") == item:
				inventory.remove_at(i)
				break
		CampaignStateService.update_campaign_data("inventory", inventory)

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

func _update_patron_relationship(patron_id: String, change_data: Dictionary) -> void:
	"""Update patron relationship status"""
	if CampaignStateService:
		var patrons = CampaignStateService.get_campaign_data("patrons") or {}
		if not patrons.has(patron_id):
			patrons[patron_id] = {"relationship": 0, "jobs_completed": 0}
		
		patrons[patron_id].relationship += change_data.get("relationship_change", 0)
		patrons[patron_id].jobs_completed += change_data.get("jobs_completed", 0)
		
		CampaignStateService.update_campaign_data("patrons", patrons)

func _update_rival_status(rival_id: String, encounter_data: Dictionary) -> void:
	"""Update rival status after encounter"""
	if CampaignStateService:
		var rivals = CampaignStateService.get_campaign_data("rivals") or {}
		if not rivals.has(rival_id):
			rivals[rival_id] = {"encounters": 0, "victories": 0, "defeats": 0}
		
		rivals[rival_id].encounters += 1
		if encounter_data.get("player_victory", false):
			rivals[rival_id].victories += 1
		else:
			rivals[rival_id].defeats += 1
		
		CampaignStateService.update_campaign_data("rivals", rivals)

func _update_campaign_state(battle_results: IBattleService.BattleResults, changes: Dictionary) -> void:
	"""Update overall campaign state based on battle results"""
	if not CampaignStateService:
		return
	
	# Update battle statistics
	var battle_stats = CampaignStateService.get_campaign_data("battle_statistics") or {
		"battles_fought": 0,
		"victories": 0,
		"defeats": 0,
		"total_credits_earned": 0,
		"total_experience_gained": 0
	}
	
	battle_stats.battles_fought += 1
	if battle_results.victory:
		battle_stats.victories += 1
	else:
		battle_stats.defeats += 1
	
	battle_stats.total_credits_earned += battle_results.credits_earned
	battle_stats.total_experience_gained += changes.get("experience", {}).get("total_xp", 0)
	
	CampaignStateService.update_campaign_data("battle_statistics", battle_stats)
	
	# Update last battle timestamp
	CampaignStateService.update_campaign_data("last_battle_date", Time.get_datetime_string_from_system())
	
	print("BattleResultProcessor: Campaign state updated with battle results")

## Debug and Testing

func create_test_results() -> IBattleService.BattleResults:
	"""Create test battle results for debugging"""
	var test_results = IBattleService.BattleResults.new()
	test_results.session_id = "test_battle_" + str(Time.get_unix_time_from_system())
	test_results.victory = true
	test_results.mission_completed = true
	test_results.crew_experience = {"Captain": 75, "Marine": 50, "Medic": 60}
	test_results.loot_acquired = ["Equipment: Scanner", "Weapon: Pistol"]
	test_results.credits_earned = 350
	test_results.story_developments = ["Mission completed successfully", "Gained reputation with locals"]
	
	return test_results

func test_processing() -> void:
	"""Test battle result processing"""
	var test_results = create_test_results()
	var result = process_results(test_results)
	print("BattleResultProcessor: Test processing result - %s" % str(result))