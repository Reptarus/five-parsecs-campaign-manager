extends Control
class_name CampaignEventComponent

## Campaign Event Component - Random Campaign Events
## Implements Core Rules pp.126-129 - D100 Campaign Event Table
## Roll once per campaign turn for random events affecting the crew

# Event bus integration
const CampaignTurnEventBus = preload("res://src/core/events/CampaignTurnEventBus.gd")
var event_bus: CampaignTurnEventBus = null

# UI Components
@onready var roll_button: Button = %RollButton
@onready var event_title_label: Label = %EventTitleLabel
@onready var event_description_label: Label = %EventDescriptionLabel
@onready var event_effect_label: Label = %EventEffectLabel
@onready var resolve_button: Button = %ResolveButton
@onready var roll_result_label: Label = %RollResultLabel

# State
var current_event: Dictionary = {}
var event_resolved: bool = false
var last_roll: int = 0

# Campaign Event Table (Core Rules pp.126-129) - Simplified version
# Full table has 100 entries - this is a representative sample
var campaign_events: Array[Dictionary] = [
	{"range": [1, 3], "title": "Friendly Doc", "description": "You've met a friendly doc who doesn't ask too many questions.", "effect": "Reduce Recovery time by 1 turn for up to 2 crew in Sick Bay"},
	{"range": [4, 8], "title": "Life Support Issues", "description": "The life support system on the ship needs upgrading badly.", "effect": "Pay 1D6 credits. Ship cannot fly until paid. Engineer: -1 to cost"},
	{"range": [9, 12], "title": "New Ally", "description": "A chance meeting turns into a new ally.", "effect": "Roll up a new character OR gain +1 story point"},
	{"range": [13, 16], "title": "Local Friends", "description": "You've made friends among the locals.", "effect": "+1 story point"},
	{"range": [17, 20], "title": "Mouthed Off", "description": "You managed to mouth off to the wrong people.", "effect": "Add a Rival"},
	{"range": [21, 24], "title": "Gambling Opportunity", "description": "There's a high-stakes gambling game tonight.", "effect": "Bet 1-6 credits, roll D6: 1-2 lose all, 3-4 break even, 5-6 double it"},
	{"range": [25, 28], "title": "Trade Opportunity", "description": "Someone approaches with an interesting deal.", "effect": "Roll twice on Trade Table this turn"},
	{"range": [29, 32], "title": "Odd Job", "description": "A quick job comes up that pays well.", "effect": "One crew member unavailable, gain 1D6+1 credits"},
	{"range": [33, 36], "title": "Bar Brawl", "description": "Things got heated at the local watering hole.", "effect": "Random crew member injured (1 turn recovery)"},
	{"range": [37, 40], "title": "Old Contact", "description": "An old contact reaches out with information.", "effect": "Gain 1 Rumor"},
	{"range": [41, 44], "title": "Valuable Find", "description": "You stumble across something valuable.", "effect": "Gain 1D6 credits"},
	{"range": [45, 48], "title": "Equipment Malfunction", "description": "A piece of equipment stops working.", "effect": "Random item is damaged"},
	{"range": [49, 52], "title": "Reputation Grows", "description": "Word is spreading about your crew.", "effect": "+1 to next Patron search roll"},
	{"range": [53, 56], "title": "Suspicious Activity", "description": "You notice someone watching your ship.", "effect": "If you have Rivals, one tracks you down this turn"},
	{"range": [57, 60], "title": "Market Surplus", "description": "Local markets are well-stocked.", "effect": "All purchases cost 1 less credit (min 1) this turn"},
	{"range": [61, 64], "title": "Skill Training", "description": "A training opportunity presents itself.", "effect": "One crew member gains 1 XP"},
	{"range": [65, 68], "title": "Information Broker", "description": "A broker offers intel for sale.", "effect": "Buy up to 3 Rumors for 2 credits each"},
	{"range": [69, 72], "title": "Ship Parts", "description": "Spare parts are available cheap.", "effect": "Repair 1 Hull Point for free"},
	{"range": [73, 76], "title": "Medical Supplies", "description": "Medical supplies become available.", "effect": "One crew in Sick Bay recovers immediately"},
	{"range": [77, 80], "title": "Cargo Opportunity", "description": "Someone needs cargo moved.", "effect": "Accept: Gain 3 credits but cannot travel this turn"},
	{"range": [81, 84], "title": "Unexpected Bill", "description": "An unexpected expense comes up.", "effect": "Pay 1D6 credits or lose 1 story point"},
	{"range": [85, 88], "title": "Lucky Break", "description": "Things just seem to go your way.", "effect": "+1 story point"},
	{"range": [89, 92], "title": "Crew Bonding", "description": "The crew spends quality time together.", "effect": "All crew gain +1 XP"},
	{"range": [93, 96], "title": "Dangerous Information", "description": "You learn something you probably shouldn't know.", "effect": "Gain 2 Rumors but also gain 1 Rival"},
	{"range": [97, 100], "title": "Windfall", "description": "An unexpected opportunity pays off big.", "effect": "Gain 2D6 credits"}
]

func _ready() -> void:
	name = "CampaignEventComponent"
	print("CampaignEventComponent: Initialized - Five Parsecs campaign event system")

	_initialize_event_bus()
	_connect_ui_signals()
	_setup_initial_state()

func _initialize_event_bus() -> void:
	"""Connect to the centralized event bus"""
	event_bus = get_node_or_null("/root/CampaignTurnEventBus")
	if event_bus:
		event_bus.subscribe_to_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)
		print("CampaignEventComponent: Connected to event bus")

func _connect_ui_signals() -> void:
	"""Connect UI button signals"""
	if roll_button:
		roll_button.pressed.connect(_on_roll_pressed)
	if resolve_button:
		resolve_button.pressed.connect(_on_resolve_pressed)

func _setup_initial_state() -> void:
	"""Initialize component state"""
	event_resolved = false
	current_event.clear()
	_update_ui_display()

## Public API
func initialize_event_phase() -> void:
	"""Initialize campaign event phase"""
	event_resolved = false
	current_event.clear()
	last_roll = 0

	_update_ui_display()

	print("CampaignEventComponent: Event phase initialized")

	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, {
			"phase_name": "campaign_event"
		})

## Core Mechanic - Roll Campaign Event
func _on_roll_pressed() -> void:
	"""Roll D100 on Campaign Event Table"""
	last_roll = randi() % 100 + 1

	# Find matching event
	current_event = _get_event_for_roll(last_roll)

	print("CampaignEventComponent: Rolled %d - %s" % [last_roll, current_event.get("title", "Unknown")])

	_update_ui_display()

	if roll_result_label:
		roll_result_label.text = "Rolled: %d" % last_roll

func _get_event_for_roll(roll: int) -> Dictionary:
	"""Get event matching the roll result"""
	for event in campaign_events:
		var range_arr = event.get("range", [0, 0])
		if roll >= range_arr[0] and roll <= range_arr[1]:
			return event.duplicate()

	# Default fallback
	return {
		"title": "Nothing Special",
		"description": "The day passes uneventfully.",
		"effect": "No effect"
	}

func _on_resolve_pressed() -> void:
	"""Resolve the current event"""
	if current_event.is_empty():
		return

	event_resolved = true

	# Apply event effects using PostBattlePhase handler
	var effect_text: String = _apply_event_effects()
	
	# Show effect result in UI
	if event_effect_label:
		event_effect_label.text = "Result: " + effect_text
		event_effect_label.modulate = Color(0.5, 1.0, 0.5)

	_update_ui_display()

	print("CampaignEventComponent: Event resolved - %s (%s)" % [current_event.get("title", "Unknown"), effect_text])

	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_COMPLETED, {
			"phase_name": "campaign_event",
			"event": current_event,
			"roll": last_roll,
			"effect": effect_text
		})

func _apply_event_effects() -> String:
	"""Apply effects of current event to campaign using PostBattlePhase handler"""
	var title = current_event.get("title", "")
	
	# Get PostBattlePhase handler
	var post_battle_phase = get_node_or_null("/root/PostBattlePhase")
	if not post_battle_phase:
		# Fallback: Try to find in scene tree
		post_battle_phase = get_tree().root.find_child("PostBattlePhase", true, false)
	
	if post_battle_phase and post_battle_phase.has_method("apply_campaign_event_effect"):
		var result = post_battle_phase.apply_campaign_event_effect(title)
		print("CampaignEventComponent: %s" % result)
		return result
	else:
		push_warning("CampaignEventComponent: PostBattlePhase not found - using fallback")
		return _apply_event_effects_fallback(title)

func _apply_event_effects_fallback(title: String) -> String:
	"""Fallback event effect application if PostBattlePhase not available"""
	match title:
		"Local Friends", "Lucky Break":
			if GameStateManager and GameStateManager.has_method("add_story_points"):
				GameStateManager.add_story_points(1)
			return "+1 Story Point"
		
		"Valuable Find":
			var credits = randi_range(1, 6)
			if GameStateManager:
				GameStateManager.add_credits(credits)
			return "+%d Credits" % credits
		
		"Windfall":
			var credits = randi_range(1, 6) + randi_range(1, 6)
			if GameStateManager:
				GameStateManager.add_credits(credits)
			return "+%d Credits (windfall)" % credits
		
		_:
			return "Event requires manual resolution"

## UI Updates
func _update_ui_display() -> void:
	"""Update all UI elements"""
	var has_event = not current_event.is_empty()

	if roll_button:
		roll_button.disabled = has_event

	if resolve_button:
		resolve_button.disabled = not has_event or event_resolved
		resolve_button.visible = has_event

	if event_title_label:
		event_title_label.text = current_event.get("title", "Roll for Campaign Event")
		event_title_label.visible = true

	if event_description_label:
		event_description_label.text = current_event.get("description", "")
		event_description_label.visible = has_event

	if event_effect_label:
		event_effect_label.text = "Effect: " + current_event.get("effect", "") if has_event else ""
		event_effect_label.visible = has_event
		if event_resolved:
			event_effect_label.modulate = Color(0.5, 1.0, 0.5)
		else:
			event_effect_label.modulate = Color(1.0, 1.0, 1.0)

## Event Handlers
func _on_phase_started(data: Dictionary) -> void:
	"""Handle phase started events"""
	var phase_name = data.get("phase_name", "")
	if phase_name == "campaign_event":
		print("CampaignEventComponent: Campaign event phase started")

## Public API
func is_event_resolved() -> bool:
	"""Check if event phase is completed"""
	return event_resolved

func get_current_event() -> Dictionary:
	"""Get current event data"""
	return current_event.duplicate()

func reset_event_phase() -> void:
	"""Reset for new turn"""
	event_resolved = false
	current_event.clear()
	last_roll = 0
	if roll_result_label:
		roll_result_label.text = ""
	_update_ui_display()
	print("CampaignEventComponent: Reset for new turn")
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                