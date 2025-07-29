## UnifiedStorySystem
## Manages story progression, quests, and events in the Five Parsecs campaign system.
extends Node

## Dependencies
const Mission = preload("res://src/core/systems/Mission.gd")
# GlobalEnums available as autoload singleton
const Character = preload("res://src/core/character/Character.gd")
const SaveManager = preload("res://src/core/state/SaveManager.gd")
const StoryQuestData := preload("res://src/game/story/StoryQuestData.gd")

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
var game_state: GameState = null
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


# Safe access to SaveManager
func _get_safe_savemanager() -> Variant:
	if ClassDB.class_exists("SaveManager"):
		return get_node_or_null("/root/SaveManager")
	return null

func _init_story_system(state: GameState, campaign_mgr: Node, event_mgr: Node = null) -> void:
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
func trigger_story_event(_event: StoryQuestData) -> void:
	if not _event:
		push_error("UnifiedStorySystem: Cannot trigger null event")
		return

	story_event_triggered.emit(_event)

	# Apply event effects
	_event.apply_effects(game_state)

	# Generate related quests
	var related_quests := _generate_related_quests(_event)
	available_quests.append_array(related_quests)

	# Update campaign state
	if campaign_manager:
		campaign_manager.handle_story_event(_event)

## Handle campaign events
func _on_campaign_event(event_type: int) -> void:
	match event_type:
		0: # MARKET_CRASH
			_handle_market_crash()
		1: # ALIEN_INVASION
			_handle_alien_invasion()
		2: # TECH_BREAKTHROUGH
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
	if FileAccess.file_exists("res://src/data/resources/Story/story_events.json"):
		var file := FileAccess.open("res://src/data/resources/Story/story_events.json", FileAccess.READ)
		var json := JSON.new()
		var parse_result := json.parse(file.get_as_text())
		if file: file.close()

		if parse_result == OK:
			story_event_templates = json.get_data()
		else:
			push_error("Failed to parse story events file")
	else:
		push_error("Story events file not found")

## Load quest templates from JSON file

func _load_quest_templates() -> void:
	if FileAccess.file_exists("res://src/data/resources/Story/quest_templates.json"):
		var file := FileAccess.open("res://src/data/resources/Story/quest_templates.json", FileAccess.READ)
		var json := JSON.new()
		var parse_result := json.parse(file.get_as_text())
		if file: file.close()

		if parse_result == OK:
			quest_templates = json.get_data()
		else:
			push_error("Failed to parse quest templates file")
	else:
		push_error("Quest templates file not found")

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

	# Remove expired quests
	available_quests = available_quests.filter(func(q): return not q.is_expired(game_state.current_turn))

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
func _generate_related_quests(_event: StoryQuestData) -> Array[StoryQuestData]:
	if not _event:
		return []

	var quests: Array[StoryQuestData] = []

	# Generate 1-3 related quests based on the event
	var quest_count := randi() % 3 + 1
	for i: int in range(quest_count):
		var quest := _create_related_quest(_event)
		if quest:
			quests.append(quest)

	return quests

## Create a quest related to a specific event
func _create_related_quest(_event: StoryQuestData) -> StoryQuestData:
	if not _event:
		return null

	var quest := StoryQuestData.new()

	# Set quest properties based on event type
	match _event.event_type:
		0: # MARKET_CRASH
			_setup_market_crash_quest(quest)
		1: # ALIEN_INVASION
			_setup_alien_invasion_quest(quest)
		2: # TECH_BREAKTHROUGH
			_setup_tech_breakthrough_quest(quest)
	return quest

## Setup quest for market crash event
func _setup_market_crash_quest(quest: StoryQuestData) -> void:
	if not quest:
		return

	quest.objective = GlobalEnums.MissionObjective.EXPLORE
	quest.story_point_reward = 2
	quest.rewards = {
		"credits": 1000,
		"reputation": 5
	}

## Setup quest for alien invasion event
func _setup_alien_invasion_quest(quest: StoryQuestData) -> void:
	if not quest:
		return

	quest.objective = GlobalEnums.MissionObjective.ASSASSINATION
	quest.story_point_reward = 3
	quest.rewards = {
		"credits": 1500,
		"reputation": 8
	}

## Setup quest for tech breakthrough event
func _setup_tech_breakthrough_quest(quest: StoryQuestData) -> void:
	if not quest:
		return

	quest.objective = GlobalEnums.MissionObjective.EXPLORE
	quest.story_point_reward = 2
	quest.rewards = {
		"credits": 1200,
		"reputation": 6,
		"special": GlobalEnums.ItemType.MISC
	}

## Create a market crash event
func _create_market_crash_event() -> StoryQuestData:
	var event := StoryQuestData.new()
	event.event_type = 0 # MARKET_CRASH

	event.description = "A massive market crash has occurred! Resource values fluctuate wildly."
	return event

## Create an alien invasion event
func _create_alien_invasion_event() -> StoryQuestData:
	var event := StoryQuestData.new()
	event.event_type = 1 # ALIEN_INVASION
	event.description = "Alien forces have been spotted in multiple star systems!"
	return event

## Create a tech breakthrough event
func _create_tech_breakthrough_event() -> StoryQuestData:
	var event := StoryQuestData.new()
	event.event_type = 2 # TECH_BREAKTHROUGH

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
	# Market crash event logic
	story_event_triggered.emit(0, {"type": "market_crash", "severity": "high"}) # MARKET_CRASH

## Handle alien invasion event
func _handle_alien_invasion() -> void:
	# Alien invasion event logic
	story_event_triggered.emit(1, {"type": "alien_invasion", "severity": "critical"}) # ALIEN_INVASION

## Handle tech breakthrough event
func _handle_tech_breakthrough() -> void:
	# Tech breakthrough event logic
	story_event_triggered.emit(2, {"type": "tech_breakthrough", "severity": "medium"}) # TECH_BREAKTHROUGH

## Handle generic event
func _handle_generic_event(event_type: int) -> void:
	# Generic event handling
	story_event_triggered.emit(event_type, {"type": "generic", "severity": "low"})

func _generate_chapter_content() -> void:
	# Generate chapter-specific content
	var chapter_events = _get_chapter_events()
	for event_data in chapter_events:
		var event := StoryQuestData.new()
		if event and event.has_method("deserialize"): event.deserialize(event_data)

		story_events.append(event)

func _get_chapter_events() -> Array:
	# Get events for current chapter from templates
	if story_event_templates.has(str(current_chapter)):
		return story_event_templates[str(current_chapter)]
	return []

func _generate_quest() -> StoryQuestData:
	var quest := StoryQuestData.new()

	# Get appropriate quest template for current chapter
	var templates = _get_available_quest_templates()
	if templates.is_empty():
		return quest

	var template = templates[randi() % templates.size()]
	if quest and quest.has_method("deserialize"): quest.deserialize(template)

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
	quest.quest_type = 0 # STORY
	quest.story_point_reward = 5
	return quest

# Serialization
func serialize() -> Dictionary:
	return {
		"story_points": story_points,
		"current_milestone": current_milestone,
		"story_ticks": story_ticks,
		"current_chapter": current_chapter,
		"active_quests": active_quests.map(func(q): return q.serialize() if q and q.has_method("serialize") else {}),
		"completed_quests": completed_quests.map(func(q): return q.serialize() if q and q.has_method("serialize") else {}),
		"available_quests": available_quests.map(func(q): return q.serialize() if q and q.has_method("serialize") else {})
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
		var quest := StoryQuestData.new()
		if quest and quest.has_method("deserialize"): quest.deserialize(quest_data)

		active_quests.append(quest)

	for quest_data in data.get("completed_quests", []):
		var quest := StoryQuestData.new()
		if quest and quest.has_method("deserialize"): quest.deserialize(quest_data)

		completed_quests.append(quest)

	for quest_data in data.get("available_quests", []):
		var quest := StoryQuestData.new()
		if quest and quest.has_method("deserialize"): quest.deserialize(quest_data)

		available_quests.append(quest)

## Setup quest for event based on event type
func _setup_event_quest(_event: int) -> StoryQuestData:
	var quest := StoryQuestData.new()

	match _event:
		0: # MARKET_CRASH
			_setup_market_crash_quest(quest)
		1: # ALIEN_INVASION
			_setup_alien_invasion_quest(quest)
		2: # TECH_BREAKTHROUGH
			_setup_tech_breakthrough_quest(quest)
		_:
			pass

	return quest

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