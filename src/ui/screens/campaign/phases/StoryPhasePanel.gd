extends FPCM_BasePhasePanel
class_name FPCM_StoryPhasePanel

const FPCM_StoryTrackSystem = preload("res://src/core/story/StoryTrackSystem.gd")
const FPCM_StoryTrackPanel = preload("res://src/ui/components/story/StoryTrackPanel.gd")

signal story_event_selected(event: FPCM_StoryTrackSystem.StoryEvent)
signal story_choice_made(choice: FPCM_StoryTrackSystem.StoryChoice)
signal story_phase_completed()

@onready var event_list: ItemList = $VBoxContainer/EventList
@onready var event_details: RichTextLabel = $VBoxContainer/EventDetails
@onready var choice_container: VBoxContainer = $VBoxContainer/ChoiceContainer
@onready var resolve_button: Button = $VBoxContainer/ResolveButton

# Manager references
var story_track_system: FPCM_StoryTrackSystem = null
var campaign_manager: Resource = null
var alpha_manager: Node = null
var dice_manager: Node = null

# Story track UI component
var story_track_panel: FPCM_StoryTrackPanel = null

# Current state
var current_event: FPCM_StoryTrackSystem.StoryEvent = null
var available_choices: Array[FPCM_StoryTrackSystem.StoryChoice] = []
var story_phase_active: bool = false

func _ready() -> void:
	super._ready()
	_initialize_managers()
	_setup_story_track_panel()
	_connect_signals()
	
	event_list.item_selected.connect(_on_event_selected)
	resolve_button.pressed.connect(_on_resolve_pressed)
	resolve_button.disabled = true

func setup_phase() -> void:
	super.setup_phase()
	_initialize_story_phase()
	_update_story_display()

## Initialize manager references from autoloads

func _initialize_managers() -> void:
	"""Initialize manager references from autoloads"""
	alpha_manager = get_node("/root/AlphaGameManager") if has_node("/root/AlphaGameManager") else null
	dice_manager = get_node("/root/DiceManager") if has_node("/root/DiceManager") else null
	
	# Get story track system from alpha manager
	if alpha_manager and alpha_manager.has_method("get_story_track_system"):
		story_track_system = alpha_manager.get_story_track_system()
	
	# Get campaign manager
	if alpha_manager and alpha_manager.has_method("get_campaign_manager"):
		campaign_manager = alpha_manager.get_campaign_manager()

## Setup the story track panel component

func _setup_story_track_panel() -> void:
	"""Create and setup the story track panel component"""
	story_track_panel = FPCM_StoryTrackPanel.new()
	story_track_panel.name = "StoryTrackPanel"
	
	# Add to the scene (replace the existing UI)
	add_child(story_track_panel)
	
	# Move it to be visible and replace the old UI temporarily
	story_track_panel.position = Vector2(0, 0)
	story_track_panel.size = size

## Connect story track system signals

func _connect_signals() -> void:
	"""Connect signals from story track system"""
	if story_track_system:
		story_track_system.story_event_triggered.connect(_on_story_event_triggered)
		story_track_system.story_choice_made.connect(_on_story_choice_made)
		story_track_system.story_track_completed.connect(_on_story_track_completed)
		story_track_system.evidence_discovered.connect(_on_evidence_discovered)

## Initialize the story phase

func _initialize_story_phase() -> void:
	"""Initialize the story phase with story track system"""
	current_event = null
	available_choices.clear()
	story_phase_active = false
	
	if story_track_system:
		# Connect story track panel to system
		if story_track_panel:
			story_track_panel.connect_to_story_system()
		
		# Check if story track is active
		story_phase_active = story_track_system.is_story_track_active
		
		if not story_phase_active:
			# Start story track if not active
			story_track_system.start_story_track()
			story_phase_active = true
		
		# Get current event
		current_event = story_track_system.get_current_event()

## Update story display

func _update_story_display() -> void:
	"""Update the story phase display"""
	if story_track_panel:
		story_track_panel.refresh_display()
	
	_update_event_list()
	_update_event_details()

## Update event list with current story events

func _update_event_list() -> void:
	"""Update the event list display"""
	event_list.clear()
	
	if story_track_system:
		var available_events = story_track_system.get_available_events()
		for event in available_events:
			event_list.add_item(event.title)
			event_list.set_item_metadata(event_list.get_item_count() - 1, event)

## Update event details display

func _update_event_details() -> void:
	"""Update event details display"""
	if current_event:
		var details: String = "[b]%s[/b]\n\n%s" % [current_event.title, current_event.description]
		if current_event.required_evidence > 0:
			details += "\n\n[color=yellow]Required Evidence: %d[/color]" % current_event.required_evidence
		event_details.text = details
		_update_choice_buttons()
	else:
		event_details.text = "[i]No active story events[/i]"
		_clear_choice_buttons()

## Update choice buttons

func _update_choice_buttons() -> void:
	"""Update choice buttons for current event"""
	_clear_choice_buttons()
	
	if current_event and current_event.choices:
		available_choices = current_event.choices
		for choice in available_choices:
			var choice_button := Button.new()
			choice_button.text = "%s (%s risk)" % [choice.choice_text, choice.risk_level]
			choice_button.custom_minimum_size = Vector2(0, 40)
			choice_button.pressed.connect(_on_choice_selected.bind(choice))
			choice_container.add_child(choice_button)

## Clear choice buttons

func _clear_choice_buttons() -> void:
	"""Clear all choice buttons"""
	for child in choice_container.get_children():
		child.queue_free()
	available_choices.clear()

## Signal handlers for story track system events

func _on_story_event_triggered(event: FPCM_StoryTrackSystem.StoryEvent) -> void:
	"""Handle story event triggered"""
	current_event = event
	_update_story_display()
	story_event_selected.emit(event) # warning: return value discarded (intentional)

func _on_story_choice_made(choice: FPCM_StoryTrackSystem.StoryChoice) -> void:
	"""Handle story choice made"""
	story_choice_made.emit(choice) # warning: return value discarded (intentional)

func _on_story_track_completed() -> void:
	"""Handle story track completion"""
	story_phase_active = false
	story_phase_completed.emit() # warning: return value discarded (intentional)
	
	# Show completion message
	event_details.text = "[center][b][color=gold]Story Track Completed![/color][/b]\\n\\nYou have successfully navigated the story and uncovered the truth.[/center]"
	_clear_choice_buttons()

func _on_evidence_discovered(evidence_count: int) -> void:
	"""Handle evidence discovery"""
	_update_story_display()

## Handle choice selection from buttons

func _on_choice_selected(choice: FPCM_StoryTrackSystem.StoryChoice) -> void:
	"""Handle choice selection from UI"""
	if not choice or not current_event:
		return
	
	# Make the choice through the story track system
	if story_track_system:
		var outcome = story_track_system.make_story_choice(current_event, choice)
		_display_choice_outcome(choice, outcome)
	
	# Update display after choice
	await get_tree().create_timer(2.0).timeout
	_update_story_display()

## Display choice outcome
func _display_choice_outcome(choice: FPCM_StoryTrackSystem.StoryChoice, outcome: Dictionary) -> void:
	"""Display the outcome of a story choice"""
	var outcome_text: String = ""

	if outcome.get("success", false):
		outcome_text = "[color=green]✓ Success![/color] " + outcome.get("description", "Choice was successful.")
	else:
		outcome_text = "[color=red]✗ Failed![/color] " + outcome.get("description", "Choice did not go as planned.")
	
	# Temporarily show outcome
	event_details.text += "\n\n" + outcome_text

## Handle event selection from list

func _on_event_selected(index: int) -> void:
	"""Handle event selection from event list"""
	if not story_track_system:
		return
	
	var events = story_track_system.get_available_events()
	if index >= 0 and index < events.size():
		current_event = events[index]
		_update_event_details()
		story_event_selected.emit(current_event) # warning: return value discarded (intentional)

## Handle resolve button press
func _on_resolve_pressed() -> void:
	"""Handle resolve button press - complete the story phase"""
	if story_track_system and story_track_system.is_story_track_active:
		# Check if story track is complete
		var status = story_track_system.get_story_track_status()

		if not status.get("can_progress", false):
			# Need more evidence or choices to complete
			event_details.text += "\n\n[color=yellow]Cannot progress - need more evidence or choices[/color]"
			return
	
	# Complete the story phase
	story_phase_completed.emit() # warning: return value discarded (intentional)
	complete_phase()

## Validate phase requirements
func validate_phase_requirements() -> bool:
	"""Validate if story phase can be completed"""
	if not story_track_system:
		return true # Allow completion if no story system
	
	var status = story_track_system.get_story_track_status()

	return status.get("is_active", false) or status.get("can_progress", true)

## Get phase data for save/load
func get_phase_data() -> Dictionary:
	"""Get story phase data for persistence"""
	var data = {
		"story_phase_active": story_phase_active,
		"current_event_id": "",
		"story_track_status": {}
	}
	
	if current_event:
		data["current_event_id"] = current_event.event_id
	
	if story_track_system:
		data["story_track_status"] = story_track_system.get_story_track_status()
	
	return data

## Check if story track system is available
func is_story_system_available() -> bool:
	"""Check if story track system is available"""
	return story_track_system != null

## Get story progress for external systems
func get_story_progress() -> Dictionary:
	"""Get story progress for external systems"""
	if story_track_system:
		return story_track_system.get_story_track_status()
	return {"is_active": false, "progress": 0}
