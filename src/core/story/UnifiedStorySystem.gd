## UnifiedStorySystem
## Manages story progression, quests, and events in the Five Parsecs campaign system.
extends Node

## Dependencies
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const Character = preload("res://src/core/character/Management/CharacterDataManager.gd")
const Mission = preload("res://src/core/systems/Mission.gd")
const StoryQuestData := preload("res://src/game/story/StoryQuestData.gd")
const GameLocation = preload("res://src/game/world/GameLocation.gd")
const SaveManager = preload("res://src/core/state/SaveManager.gd")

## Emitted when a story event is triggered
signal story_event_triggered(event: StoryQuestData)
## Emitted when a quest is started
signal quest_started(quest: StoryQuestData)
## Emitted when a quest is completed
signal quest_completed(quest: StoryQuestData)
## Emitted when a quest is failed
signal quest_failed(quest: StoryQuestData)
## Emitted when a story milestone is reached
signal story_milestone_reached(milestone: int)
## Emitted when story points change
signal story_points_changed(points: int)
## Emitted when a global event is triggered
signal global_event_triggered(event_type: int)

## Story progression tracking
var story_points: int = 0
var current_milestone: int = 0
var story_ticks: int = 0
var current_chapter: int = 0

## Quest tracking arrays
var active_quests: Array[StoryQuestData] = []
var completed_quests: Array[StoryQuestData] = []
var available_quests: Array[StoryQuestData] = []
var story_events: Array[StoryQuestData] = []

## Campaign state references
var game_state: FiveParsecsGameState = null
var campaign_manager: Node = null # Will be cast to CampaignManager
var event_manager: Node = null # Will be cast to EventManager

## Story configuration constants
const TICKS_PER_CHAPTER := 10
const POINTS_PER_MILESTONE := 5
const MAX_ACTIVE_QUESTS := 5
const STORY_TICK_REDUCTION_ON_SUCCESS := 2

## Story content templates
var story_event_templates: Dictionary = {}
var quest_templates: Dictionary = {}

## Initialize the story system
func _init() -> void:
	_initialize_story_content()

## Setup the story system with required references
func setup(state: FiveParsecsGameState, campaign_mgr: Node, event_mgr: Node = null) -> void:
	if not state:
		push_error("UnifiedStorySystem: Invalid game state provided")
		return
		
	game_state = state
	campaign_manager = campaign_mgr
	event_manager = event_mgr
	
	if event_manager and event_manager.has_signal("event_triggered"):
		event_manager.event_triggered.connect(_on_campaign_event)
	else:
		push_warning("UnifiedStorySystem: No event manager provided or invalid event manager")

## Advance the story progression
func advance_story(success: bool = true) -> void:
	# Reduce story ticks based on success
	story_ticks = max(0, story_ticks - (STORY_TICK_REDUCTION_ON_SUCCESS if success else 1))
	
	# Check for chapter completion
	if story_ticks <= 0:
		_complete_current_chapter()
	
	# Update available content
	_update_available_content()

## Add story points and check for milestones
func add_story_points(points: int) -> void:
	if points <= 0:
		return
		
	story_points += points
	var new_milestone := story_points / POINTS_PER_MILESTONE
	
	if new_milestone > current_milestone:
		current_milestone = new_milestone
		story_milestone_reached.emit(current_milestone)
	
	story_points_changed.emit(story_points)

## Start a new quest
func start_quest(quest: StoryQuestData) -> bool:
	if not quest:
		push_error("UnifiedStorySystem: Cannot start null quest")
		return false
		
	if active_quests.size() >= MAX_ACTIVE_QUESTS:
		return false
		
	if available_quests.has(quest):
		available_quests.erase(quest)
		active_quests.append(quest)
		quest.start(game_state.current_turn)
		quest_started.emit(quest)
		return true
	return false

## Complete a quest and award rewards
func complete_quest(quest: StoryQuestData) -> void:
	if not quest:
		push_error("UnifiedStorySystem: Cannot complete null quest")
		return
		
	if active_quests.has(quest):
		active_quests.erase(quest)
		completed_quests.append(quest)
		quest.complete(game_state.current_turn)
		
		# Award story points
		add_story_points(quest.story_point_reward)
		
		# Apply rewards
		_apply_quest_rewards(quest)
		
		quest_completed.emit(quest)
		advance_story(true)

## Fail a quest and apply penalties
func fail_quest(quest: StoryQuestData) -> void:
	if not quest:
		push_error("UnifiedStorySystem: Cannot fail null quest")
		return
		
	if active_quests.has(quest):
		active_quests.erase(quest)
		quest.fail(game_state.current_turn)
		
		# Apply penalties
		_apply_quest_penalties(quest)
		
		quest_failed.emit(quest)
		advance_story(false)

## Trigger a story event
func trigger_story_event(event: StoryQuestData) -> void:
	if not event:
		push_error("UnifiedStorySystem: Cannot trigger null event")
		return
		
	story_event_triggered.emit(event)
	
	# Apply event effects
	event.apply_effects(game_state)
	
	# Generate related quests
	var related_quests := _generate_related_quests(event)
	# Properly append each quest to the typed array instead of using append_array
	for quest in related_quests:
		available_quests.append(quest)
	
	# Update campaign state
	if campaign_manager:
		campaign_manager.handle_story_event(event)

## Handle campaign events
func _on_campaign_event(event_type: int) -> void:
	match event_type:
		GameEnums.GlobalEvent.MARKET_CRASH:
			_handle_market_crash()
		GameEnums.GlobalEvent.ALIEN_INVASION:
			_handle_alien_invasion()
		GameEnums.GlobalEvent.TECH_BREAKTHROUGH:
			_handle_tech_breakthrough()
		_:
			_handle_generic_event(event_type)

## Initialize story content from data files
func _initialize_story_content() -> void:
	_load_story_events()
	_load_quest_templates()
	_setup_initial_chapter()

## Load story events from JSON file
func _load_story_events() -> void:
	var story_events_filepath = "res://src/data/resources/Story/story_events.json"
	if FileAccess.file_exists(story_events_filepath):
		var file := FileAccess.open(story_events_filepath, FileAccess.READ)
		var json := JSON.new()
		var parse_result := json.parse(file.get_as_text())
		file.close()
		
		if parse_result == OK:
			story_event_templates = json.get_data()
		else:
			push_error("Failed to parse story events file: %s at line %s" % [json.get_error_message(), json.get_error_line()])
			story_event_templates = _get_default_story_events()
	else:
		push_warning("Story events file not found, using built-in defaults")
		story_event_templates = _get_default_story_events()

## Load quest templates from JSON file
func _load_quest_templates() -> void:
	var quest_templates_filepath = "res://src/data/resources/Story/quest_templates.json"
	if FileAccess.file_exists(quest_templates_filepath):
		var file := FileAccess.open(quest_templates_filepath, FileAccess.READ)
		var json := JSON.new()
		var parse_result := json.parse(file.get_as_text())
		file.close()
		
		if parse_result == OK:
			quest_templates = json.get_data()
		else:
			push_error("Failed to parse quest templates file: %s at line %s" % [json.get_error_message(), json.get_error_line()])
			quest_templates = _get_default_quest_templates()
	else:
		push_warning("Quest templates file not found, using built-in defaults")
		quest_templates = _get_default_quest_templates()

## Get default story events when the file is missing
func _get_default_story_events() -> Dictionary:
	var defaults = {
		"0": [
			{
				"event_id": "intro_event",
				"event_type": GameEnums.GlobalEvent.TECH_BREAKTHROUGH,
				"title": "A New Beginning",
				"description": "As you begin your journey among the stars, rumors of new technologies spread across the sector."
			}
		],
		"1": [
			{
				"event_id": "market_event",
				"event_type": GameEnums.GlobalEvent.MARKET_CRASH,
				"title": "Market Upheaval",
				"description": "Economic turmoil spreads throughout the sector as trade routes are disrupted."
			},
			{
				"event_id": "pirate_event",
				"event_type": 3,
				"title": "Rising Threats",
				"description": "Pirate activity has increased in outlying systems, making travel more dangerous."
			}
		],
		"2": [
			{
				"event_id": "alien_event",
				"event_type": GameEnums.GlobalEvent.ALIEN_INVASION,
				"title": "Unknown Contact",
				"description": "Strange signals have been detected on the fringes of known space."
			}
		]
	}
	return defaults

## Get default quest templates when the file is missing
func _get_default_quest_templates() -> Dictionary:
	var defaults = {
		"0": [
			{
				"quest_id": "tutorial_quest",
				"title": "First Steps",
				"description": "Complete a basic mission to prove your crew's worth.",
				"objective": GameEnums.MissionObjective.RECON,
				"story_point_reward": 1,
				"rewards": {
					"credits": 500,
					"reputation": 3
				}
			}
		],
		"1": [
			{
				"quest_id": "patrol_quest",
				"title": "Border Patrol",
				"description": "Help secure the borders against increasing threats.",
				"objective": GameEnums.MissionObjective.PATROL,
				"story_point_reward": 2,
				"rewards": {
					"credits": 800,
					"reputation": 5
				}
			},
			{
				"quest_id": "rescue_quest",
				"title": "Rescue Operation",
				"description": "Save a stranded crew from a derelict station.",
				"objective": GameEnums.MissionObjective.RESCUE,
				"story_point_reward": 3,
				"rewards": {
					"credits": 1000,
					"reputation": 7,
					"special": 2
				}
			}
		],
		"2": [
			{
				"quest_id": "artifact_quest",
				"title": "Ancient Discovery",
				"description": "Recover a mysterious alien artifact from a forgotten world.",
				"objective": 3,
				"story_point_reward": 4,
				"rewards": {
					"credits": 1500,
					"reputation": 8,
					"special": 5
				}
			}
		]
	}
	return defaults

## Setup the initial chapter
func _setup_initial_chapter() -> void:
	current_chapter = 0
	story_ticks = TICKS_PER_CHAPTER
	_generate_chapter_content()

## Complete the current chapter and setup the next
func _complete_current_chapter() -> void:
	current_chapter += 1
	story_ticks = TICKS_PER_CHAPTER
	
	# Generate new content for next chapter
	_generate_chapter_content()

## Update available content and generate new quests
func _update_available_content() -> void:
	if not game_state:
		return
		
	# Remove expired quests - use a safer approach for typed arrays
	var valid_quests: Array[StoryQuestData] = []
	for quest in available_quests:
		if not quest.is_expired(game_state.current_turn):
			valid_quests.append(quest)
	available_quests = valid_quests
	
	# Generate new quests if needed
	while available_quests.size() < 3:
		var new_quest := _generate_quest()
		if new_quest:
			available_quests.append(new_quest)

## Apply rewards for a completed quest
func _apply_quest_rewards(quest: StoryQuestData) -> void:
	if not game_state or not quest:
		return
		
	# Apply resource rewards
	if quest.rewards.has("credits"):
		game_state.add_credits(quest.rewards.credits)
	
	if quest.rewards.has("reputation"):
		game_state.add_reputation(quest.rewards.reputation)
	
	# Apply special rewards
	if quest.rewards.has("special_effect"):
		_apply_special_reward(quest.rewards.special_effect)

## Apply penalties for a failed quest
func _apply_quest_penalties(quest: StoryQuestData) -> void:
	if not game_state or not quest:
		return
		
	# Apply reputation penalty
	game_state.add_reputation(-2)
	
	# Apply relationship penalties
	if quest.patron:
		quest.patron.change_relationship(-5)

## Generate quests related to a story event
func _generate_related_quests(event: StoryQuestData) -> Array[StoryQuestData]:
	if not event:
		return []
		
	var quests: Array[StoryQuestData] = []
	
	# Generate 1-3 related quests based on the event
	var quest_count := randi() % 3 + 1
	for i in range(quest_count):
		var quest := _create_related_quest(event)
		if quest:
			quests.append(quest)
	
	return quests

## Create a quest related to a specific event
func _create_related_quest(event: StoryQuestData) -> StoryQuestData:
	if not event:
		return null
		
	var quest := StoryQuestData.new()
	
	# Set quest properties based on event type
	match event.event_type:
		GameEnums.GlobalEvent.MARKET_CRASH:
			_setup_market_crash_quest(quest)
		GameEnums.GlobalEvent.ALIEN_INVASION:
			_setup_alien_invasion_quest(quest)
		GameEnums.GlobalEvent.TECH_BREAKTHROUGH:
			_setup_tech_breakthrough_quest(quest)
		_:
			return null
	
	return quest

## Setup quest for market crash event
func _setup_market_crash_quest(quest: StoryQuestData) -> void:
	if not quest:
		return
		
	quest.objective = GameEnums.MissionObjective.RECON
	quest.story_point_reward = 2
	quest.rewards = {
		"credits": 1000,
		"reputation": 5
	}

## Setup quest for alien invasion event
func _setup_alien_invasion_quest(quest: StoryQuestData) -> void:
	if not quest:
		return
		
	quest.objective = GameEnums.MissionObjective.WIN_BATTLE
	quest.story_point_reward = 3
	quest.rewards = {
		"credits": 1500,
		"reputation": 8
	}

## Setup quest for tech breakthrough event
func _setup_tech_breakthrough_quest(quest: StoryQuestData) -> void:
	if not quest:
		return
		
	quest.objective = GameEnums.MissionObjective.RECON
	quest.story_point_reward = 2
	quest.rewards = {
		"credits": 1200,
		"reputation": 6,
		"special": GameEnums.ItemType.MISC
	}

## Create a market crash event
func _create_market_crash_event() -> StoryQuestData:
	var event := StoryQuestData.new()
	event.event_type = GameEnums.GlobalEvent.MARKET_CRASH
	event.description = "A massive market crash has occurred! Resource values fluctuate wildly."
	return event

## Create an alien invasion event
func _create_alien_invasion_event() -> StoryQuestData:
	var event := StoryQuestData.new()
	event.event_type = GameEnums.GlobalEvent.ALIEN_INVASION
	event.description = "Alien forces have been spotted in multiple star systems!"
	return event

## Create a tech breakthrough event
func _create_tech_breakthrough_event() -> StoryQuestData:
	var event := StoryQuestData.new()
	event.event_type = GameEnums.GlobalEvent.TECH_BREAKTHROUGH
	event.description = "A technological breakthrough has been announced!"
	return event

## Create a generic event based on type
func _create_generic_event(event_type: int) -> StoryQuestData:
	var event := StoryQuestData.new()
	event.event_type = event_type
	event.description = "A new event has occurred in the galaxy..."
	return event

## Handle market crash event
func _handle_market_crash() -> void:
	if not game_state:
		return
		
	game_state.modify_market_prices(0.75) # 25% price reduction
	trigger_story_event(_create_market_crash_event())

## Handle alien invasion event
func _handle_alien_invasion() -> void:
	if not game_state:
		return
		
	game_state.increase_threat_level()
	trigger_story_event(_create_alien_invasion_event())

## Handle tech breakthrough event
func _handle_tech_breakthrough() -> void:
	if not game_state:
		return
		
	game_state.unlock_tech_upgrade()
	trigger_story_event(_create_tech_breakthrough_event())

## Handle generic event
func _handle_generic_event(event_type: int) -> void:
	if not game_state:
		return
		
	var event := _create_generic_event(event_type)
	if event:
			trigger_story_event(event)

func _generate_chapter_content() -> void:
	# Generate chapter-specific content
	var chapter_events = _get_chapter_events()
	for event_data in chapter_events:
		var event = StoryQuestData.new()
		event.deserialize(event_data)
		story_events.append(event)

func _get_chapter_events() -> Array:
	# Get events for current chapter from templates
	if story_event_templates.has(str(current_chapter)):
		return story_event_templates[str(current_chapter)]
	return []

func _generate_quest() -> StoryQuestData:
	var quest = StoryQuestData.new()
	
	# Get appropriate quest template for current chapter
	var templates = _get_available_quest_templates()
	if templates.is_empty():
		return null
	
	var template = templates[randi() % templates.size()]
	quest.deserialize(template)
	
	return quest

func _get_available_quest_templates() -> Array:
	# Get quest templates appropriate for current chapter
	if quest_templates.has(str(current_chapter)):
		return quest_templates[str(current_chapter)]
	return []

func _apply_special_reward(effect: String) -> void:
	match effect:
		"unlock_special_mission":
			var quest = _generate_special_quest()
			if quest:
				available_quests.append(quest)
		"improve_reputation":
			game_state.add_reputation(5)
		"resource_bonus":
			game_state.add_credits(200)

## Generate a special quest
func _generate_special_quest() -> StoryQuestData:
	var quest := StoryQuestData.new()
	quest.quest_type = GameEnums.QuestType.STORY
	quest.story_point_reward = 5
	return quest

# Serialization
func serialize() -> Dictionary:
	return {
		"story_points": story_points,
		"current_milestone": current_milestone,
		"story_ticks": story_ticks,
		"current_chapter": current_chapter,
		"active_quests": active_quests.map(func(q): return q.serialize()),
		"completed_quests": completed_quests.map(func(q): return q.serialize()),
		"available_quests": available_quests.map(func(q): return q.serialize())
	}

func deserialize(data: Dictionary) -> void:
	story_points = data.get("story_points", 0)
	current_milestone = data.get("current_milestone", 0)
	story_ticks = data.get("story_ticks", TICKS_PER_CHAPTER)
	current_chapter = data.get("current_chapter", 0)
	
	# Clear existing quests
	active_quests.clear()
	completed_quests.clear()
	available_quests.clear()
	
	# Load quest data
	for quest_data in data.get("active_quests", []):
		var quest = StoryQuestData.new()
		quest.deserialize(quest_data)
		active_quests.append(quest)
	
	for quest_data in data.get("completed_quests", []):
		var quest = StoryQuestData.new()
		quest.deserialize(quest_data)
		completed_quests.append(quest)
	
	for quest_data in data.get("available_quests", []):
		var quest = StoryQuestData.new()
		quest.deserialize(quest_data)
		available_quests.append(quest)

## Setup quest for event based on event type
func _setup_event_quest(event: int) -> StoryQuestData:
	var quest = StoryQuestData.new()
	
	match event:
		GameEnums.GlobalEvent.MARKET_CRASH:
			_setup_market_crash_quest(quest)
		GameEnums.GlobalEvent.ALIEN_INVASION:
			_setup_alien_invasion_quest(quest)
		GameEnums.GlobalEvent.TECH_BREAKTHROUGH:
			_setup_tech_breakthrough_quest(quest)
		_:
			return null
	
	return quest
