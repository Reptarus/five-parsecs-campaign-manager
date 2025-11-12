extends Control

## Post-Battle Results UI - Five Parsecs Campaign Manager
## Displays battle outcome, casualties, loot, and experience gained
## Handles post-battle processing according to Five Parsecs Core Rules

# UI Node References
@onready var battle_outcome_label: Label = $MainContainer/ResultsPanel/BattleOutcome
@onready var casualties_list: ItemList = $MainContainer/ResultsPanel/CasualtiesSection/CasualtiesList
@onready var injuries_list: ItemList = $MainContainer/ResultsPanel/InjuriesSection/InjuriesList
@onready var loot_list: ItemList = $MainContainer/ResultsPanel/LootSection/LootList
@onready var credits_earned_label: Label = $MainContainer/ResultsPanel/RewardsSection/CreditsEarned
@onready var experience_list: ItemList = $MainContainer/ResultsPanel/ExperienceSection/ExperienceList
@onready var continue_button: Button = $MainContainer/ButtonPanel/ContinueButton
@onready var save_results_button: Button = $MainContainer/ButtonPanel/SaveResultsButton

# Core Dependencies
const Character = preload("res://src/core/character/Character.gd")
const Mission = preload("res://src/core/systems/Mission.gd")

# Battle Results Data
var battle_results: Dictionary = {}
var crew_casualties: Array[Character] = []
var crew_injuries: Array[Character] = []
var loot_gained: Array[Resource] = []
var credits_earned: int = 0
var experience_gained: Array[Dictionary] = []

# Signals
signal results_processed()
signal continue_to_campaign()
signal results_saved()

func _ready() -> void:
	"""Initialize the post-battle results UI"""
	_setup_ui_components()
	_connect_signals()
	print("PostBattleResultsUI: Initialized")

func _setup_ui_components() -> void:
	"""Configure UI components"""
	# Initially hide all sections until results are loaded
	_hide_empty_sections()
	
	# Disable continue button until results are processed
	continue_button.disabled = true

func _connect_signals() -> void:
	"""Connect UI signals"""
	continue_button.pressed.connect(_on_continue_pressed)
	save_results_button.pressed.connect(_on_save_results_pressed)

## Public Interface

func display_battle_results(results: Dictionary) -> void:
	"""Display the battle results data"""
	battle_results = results
	
	# Extract battle outcome data
	_extract_battle_data(results)
	
	# Update UI displays
	_update_battle_outcome()
	_update_casualties_display()
	_update_injuries_display()
	_update_loot_display()
	_update_rewards_display()
	_update_experience_display()
	
	# Show relevant sections
	_show_relevant_sections()
	
	# Enable continue button
	continue_button.disabled = false
	
	print("PostBattleResultsUI: Battle results displayed")

func process_post_battle_sequence() -> void:
	"""Process the complete post-battle sequence according to Five Parsecs rules"""
	print("PostBattleResultsUI: Processing post-battle sequence...")
	
	# Step 1: Determine casualties and injuries (Core Rules p.89-91)
	_process_casualties_and_injuries()
	
	# Step 2: Calculate loot and rewards (Core Rules p.91-93)
	_process_loot_and_rewards()
	
	# Step 3: Award experience and advancement (Core Rules p.93-95)
	_process_experience_and_advancement()
	
	# Step 4: Update character states
	_apply_results_to_characters()
	
	# Step 5: Save campaign state
	_save_campaign_state()
	
	results_processed.emit()

## Private Methods

func _extract_battle_data(results: Dictionary) -> void:
	"""Extract battle data from results dictionary"""
	# Battle outcome
	var victory = results.get("victory", false)
	
	# Casualties and injuries
	crew_casualties = results.get("casualties", [])
	crew_injuries = results.get("injuries", [])
	
	# Loot and rewards
	loot_gained = results.get("loot", [])
	credits_earned = results.get("credits", 0)
	
	# Experience
	experience_gained = results.get("experience", [])

func _update_battle_outcome() -> void:
	"""Update battle outcome display"""
	var victory = battle_results.get("victory", false)
	var rounds_fought = battle_results.get("rounds_fought", 0)
	
	if victory:
		battle_outcome_label.text = "VICTORY! (%d rounds)" % rounds_fought
		battle_outcome_label.modulate = Color.GREEN
	else:
		battle_outcome_label.text = "DEFEAT (%d rounds)" % rounds_fought
		battle_outcome_label.modulate = Color.RED

func _update_casualties_display() -> void:
	"""Update casualties list"""
	casualties_list.clear()
	
	for casualty in crew_casualties:
		if casualty and casualty.has_method("get_display_name"):
			casualties_list.add_item("† " + casualty.get_display_name())
		else:
			casualties_list.add_item("† Unknown Crew Member")

func _update_injuries_display() -> void:
	"""Update injuries list"""
	injuries_list.clear()
	
	for injured in crew_injuries:
		if injured and injured.has_method("get_display_name"):
			var injury_type = _determine_injury_type(injured)
			injuries_list.add_item("⚡ " + injured.get_display_name() + " - " + injury_type)
		else:
			injuries_list.add_item("⚡ Unknown Crew Member - Injury")

func _update_loot_display() -> void:
	"""Update loot list"""
	loot_list.clear()
	
	for item in loot_gained:
		if item and item.has_method("get_display_name"):
			loot_list.add_item("📦 " + item.get_display_name())
		else:
			loot_list.add_item("📦 Unknown Item")

func _update_rewards_display() -> void:
	"""Update rewards display"""
	credits_earned_label.text = "Credits Earned: %d" % credits_earned

func _update_experience_display() -> void:
	"""Update experience list"""
	experience_list.clear()
	
	for exp_entry in experience_gained:
		var character_name = exp_entry.get("character", "Unknown")
		var exp_amount = exp_entry.get("experience", 0)
		var advancement = exp_entry.get("advancement", false)
		
		var display_text = "⭐ %s: +%d XP" % [character_name, exp_amount]
		if advancement:
			display_text += " (ADVANCEMENT!)"
		
		experience_list.add_item(display_text)

func _hide_empty_sections() -> void:
	"""Hide sections that have no content"""
	# Implementation depends on actual scene structure
	pass

func _show_relevant_sections() -> void:
	"""Show sections based on available data"""
	# Show casualties section if there are casualties
	var casualties_section = get_node_or_null("MainContainer/ResultsPanel/CasualtiesSection")
	if casualties_section:
		casualties_section.visible = crew_casualties.size() > 0
	
	# Show injuries section if there are injuries
	var injuries_section = get_node_or_null("MainContainer/ResultsPanel/InjuriesSection")
	if injuries_section:
		injuries_section.visible = crew_injuries.size() > 0
	
	# Show loot section if there is loot
	var loot_section = get_node_or_null("MainContainer/ResultsPanel/LootSection")
	if loot_section:
		loot_section.visible = loot_gained.size() > 0
	
	# Always show rewards and experience sections
	var rewards_section = get_node_or_null("MainContainer/ResultsPanel/RewardsSection")
	if rewards_section:
		rewards_section.visible = true
	
	var experience_section = get_node_or_null("MainContainer/ResultsPanel/ExperienceSection")
	if experience_section:
		experience_section.visible = experience_gained.size() > 0

func _process_casualties_and_injuries() -> void:
	"""Process casualties and injuries according to Five Parsecs rules"""
	# Five Parsecs Post-Battle Casualty Rules (Core Rules p.89-91)
	for character in crew_casualties:
		print("PostBattleResultsUI: Processing casualty for %s" % character.get_display_name() if character.has_method("get_display_name") else "Unknown")
		# Character is permanently removed from crew
		# Handle will and equipment inheritance
	
	for character in crew_injuries:
		print("PostBattleResultsUI: Processing injury for %s" % character.get_display_name() if character.has_method("get_display_name") else "Unknown")
		# Apply injury effects and recovery time

func _process_loot_and_rewards() -> void:
	"""Process loot and rewards according to Five Parsecs rules"""
	# Five Parsecs Post-Battle Loot Rules (Core Rules p.91-93)
	print("PostBattleResultsUI: Processing %d credits and %d loot items" % [credits_earned, loot_gained.size()])
	
	# Add credits to campaign funds
	if GameState:
		GameState.add_credits(credits_earned)
	
	# Add loot to ship inventory
	for item in loot_gained:
		# GameStateManagerAutoload not available - use GameState fallback
		if GameState and GameState.has_method("add_item_to_inventory"):
			GameState.add_item_to_inventory(item)

func _process_experience_and_advancement() -> void:
	"""Process experience and advancement according to Five Parsecs rules"""
	# Five Parsecs Experience Rules (Core Rules p.93-95)
	for exp_entry in experience_gained:
		var character = exp_entry.get("character_ref")
		var exp_amount = exp_entry.get("experience", 0)
		
		if character and character.has_method("add_experience"):
			character.add_experience(exp_amount)
			print("PostBattleResultsUI: Awarded %d XP to %s" % [exp_amount, character.get_display_name() if character.has_method("get_display_name") else "Unknown"])

func _apply_results_to_characters() -> void:
	"""Apply all battle results to character states"""
	# Remove casualties from active crew
	for casualty in crew_casualties:
		# GameStateManagerAutoload not available - use GameState fallback
		if GameState and GameState.has_method("remove_character"):
			GameState.remove_character(casualty)
	
	# Apply injury states to injured characters
	for injured in crew_injuries:
		if injured.has_method("apply_injury"):
			var injury_type = _determine_injury_type(injured)
			injured.apply_injury(injury_type)

func _determine_injury_type(character: Character) -> String:
	"""Determine injury type according to Five Parsecs rules"""
	# Five Parsecs Injury Table (Core Rules p.90)
	var injury_roll = randi() % 6 + 1
	
	match injury_roll:
		1, 2:
			return "Light Wound"
		3, 4:
			return "Serious Wound"
		5:
			return "Severe Injury"
		6:
			return "Critical Injury"
		_:
			return "Unknown Injury"

func _save_campaign_state() -> void:
	"""Save campaign state with post-battle results"""
	if GameState:
		GameState.save_game_state()
		print("PostBattleResultsUI: Campaign state saved")

## Signal Handlers

func _on_continue_pressed() -> void:
	"""Handle continue button press"""
	print("PostBattleResultsUI: Continue to campaign")
	continue_to_campaign.emit()

func _on_save_results_pressed() -> void:
	"""Handle save results button press"""
	print("PostBattleResultsUI: Saving battle results")
	_save_campaign_state()
	results_saved.emit()

## Utility Methods

func get_battle_summary() -> Dictionary:
	"""Get a summary of battle results for logging"""
	return {
		"victory": battle_results.get("victory", false),
		"rounds_fought": battle_results.get("rounds_fought", 0),
		"casualties": crew_casualties.size(),
		"injuries": crew_injuries.size(),
		"loot_items": loot_gained.size(),
		"credits_earned": credits_earned,
		"experience_awards": experience_gained.size()
	}