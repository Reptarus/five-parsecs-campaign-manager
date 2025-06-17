extends Control
class_name FPCM_StoryTrackPanel

## Story Track Panel for displaying story events and choices
## Integrates with FPCM_StoryTrackSystem

# References to UI components
@onready var story_title: Label = $VBoxContainer/TitleContainer/StoryTitle
@onready var story_clock_label: Label = $VBoxContainer/TitleContainer/ClockLabel
@onready var evidence_label: Label = $VBoxContainer/TitleContainer/EvidenceLabel
@onready var event_description: RichTextLabel = $VBoxContainer/EventContainer/EventDescription
@onready var choices_container: VBoxContainer = $VBoxContainer/ChoicesContainer
@onready var status_label: Label = $VBoxContainer/StatusLabel

# Story system reference
var story_track_system: FPCM_StoryTrackSystem
var campaign_manager: Resource # CampaignManager
var current_event: FPCM_StoryTrackSystem.StoryEvent
var is_initialized: bool = false

# Signals
signal choice_selected(choice: FPCM_StoryTrackSystem.StoryChoice)
signal story_panel_updated()

func _ready():
	# Initialize UI state
	_initialize_ui()
	is_initialized = true

## Initialize the UI components
func _initialize_ui() -> void:
	# Set default text
	story_title.text = "Story Track"
	story_clock_label.text = "Clock: --"
	evidence_label.text = "Evidence: 0"
	event_description.text = "[i]No active story events[/i]"
	status_label.text = "Story track inactive"
	
	# Clear choices
	_clear_choices()

## Setup the panel with story track system
func setup(p_story_system: FPCM_StoryTrackSystem, p_campaign_manager: Resource) -> void:
	story_track_system = p_story_system
	campaign_manager = p_campaign_manager
	
	if story_track_system:
		# Connect signals
		story_track_system.story_event_triggered.connect(_on_story_event_triggered)
		story_track_system.story_clock_advanced.connect(_on_story_clock_advanced)
		story_track_system.evidence_discovered.connect(_on_evidence_discovered)
		story_track_system.story_track_completed.connect(_on_story_track_completed)
		
		# Update display
		update_display()

## Update the display with current story state
func update_display() -> void:
	if not story_track_system or not is_initialized:
		return
	
	var status = story_track_system.get_story_track_status()
	
	# Update clock and evidence
	story_clock_label.text = "Clock: %d" % status.get("clock_ticks", 0)
	evidence_label.text = "Evidence: %d" % status.get("evidence_pieces", 0)
	
	# Update status
	if status.get("is_active", false):
		status_label.text = "Phase: %s" % status.get("phase", "unknown")
		status_label.modulate = Color.GREEN
	else:
		status_label.text = "Story track inactive"
		status_label.modulate = Color.GRAY
	
	# Update current event
	current_event = story_track_system.get_current_event()
	if current_event:
		_display_event(current_event)
	else:
		_display_no_event()
	
	story_panel_updated.emit()

## Display a story event
func _display_event(event: FPCM_StoryTrackSystem.StoryEvent) -> void:
	story_title.text = event.title
	
	# Format event description with BBCode
	var description_text = "[b]%s[/b]\n\n%s" % [event.title, event.description]
	
	# Add evidence requirement info
	if event.required_evidence > 0:
		description_text += "\n\n[color=yellow]Required Evidence: %d[/color]" % event.required_evidence
	
	event_description.text = description_text
	
	# Display choices
	_display_choices(event.choices)

## Display no active event
func _display_no_event() -> void:
	story_title.text = "Story Track"
	event_description.text = "[i]No active story events[/i]"
	_clear_choices()

## Display story choices
func _display_choices(choices: Array) -> void:
	_clear_choices()
	
	for choice in choices:
		var choice_button = Button.new()
		choice_button.text = choice.choice_text
		choice_button.custom_minimum_size = Vector2(0, 40)
		
		# Add risk indicator to button text
		var risk_color = _get_risk_color(choice.risk_level)
		var button_text = "%s [color=%s](%s risk)[/color]" % [choice.choice_text, risk_color, choice.risk_level]
		choice_button.text = choice.choice_text + " (" + choice.risk_level + " risk)"
		
		# Add tooltip with reward information
		if choice.potential_reward != "":
			choice_button.tooltip_text = "Risk: %s\nPotential Reward: %s\nEvidence Gain: %d" % [
				choice.risk_level.capitalize(),
				choice.potential_reward.capitalize(),
				choice.evidence_gain
			]
		
		# Connect choice selection
		choice_button.pressed.connect(_on_choice_selected.bind(choice))
		
		choices_container.add_child(choice_button)

## Clear all choice buttons
func _clear_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()

## Get color for risk level
func _get_risk_color(risk_level: String) -> String:
	match risk_level:
		"none": return "green"
		"low": return "lightgreen"
		"medium": return "yellow"
		"high": return "orange"
		"very_high": return "red"
		"extreme": return "darkred"
		_: return "white"

## Handle choice selection
func _on_choice_selected(choice: FPCM_StoryTrackSystem.StoryChoice) -> void:
	if not current_event or not choice:
		return
	
	# Disable all choice buttons to prevent double-selection
	for button in choices_container.get_children():
		button.disabled = true
	
	# Emit signal for external handling
	choice_selected.emit(choice)
	
	# Apply choice through campaign manager if available
	if campaign_manager and campaign_manager.has_method("make_story_choice"):
		var outcome = campaign_manager.make_story_choice(current_event, choice)
		_display_choice_outcome(choice, outcome)
	else:
		# Fallback: apply choice directly
		var outcome = story_track_system.make_story_choice(current_event, choice)
		_display_choice_outcome(choice, outcome)
	
	# Update display after short delay
	await get_tree().create_timer(2.0).timeout
	update_display()

## Display choice outcome
func _display_choice_outcome(choice: FPCM_StoryTrackSystem.StoryChoice, outcome: Dictionary) -> void:
	var outcome_text = ""
	
	if outcome.get("success", false):
		outcome_text = "[color=green]✓ Success![/color] " + outcome.get("description", "Choice was successful.")
	else:
		outcome_text = "[color=red]✗ Failed![/color] " + outcome.get("description", "Choice did not go as planned.")
	
	# Temporarily show outcome
	event_description.text += "\n\n" + outcome_text

## Signal handlers for story system events
func _on_story_event_triggered(event: FPCM_StoryTrackSystem.StoryEvent) -> void:
	current_event = event
	update_display()

func _on_story_clock_advanced(ticks_remaining: int) -> void:
	story_clock_label.text = "Clock: %d" % ticks_remaining
	
	# Flash the clock to indicate change
	var tween = create_tween()
	tween.tween_property(story_clock_label, "modulate", Color.YELLOW, 0.3)
	tween.tween_property(story_clock_label, "modulate", Color.WHITE, 0.3)

func _on_evidence_discovered(evidence_count: int) -> void:
	evidence_label.text = "Evidence: %d" % evidence_count
	
	# Flash the evidence to indicate discovery
	var tween = create_tween()
	tween.tween_property(evidence_label, "modulate", Color.GREEN, 0.3)
	tween.tween_property(evidence_label, "modulate", Color.WHITE, 0.3)

func _on_story_track_completed() -> void:
	status_label.text = "Story track completed!"
	status_label.modulate = Color.GOLD
	
	# Show completion message
	event_description.text = "[center][b][color=gold]Story Track Completed![/color][/b]\n\nYou have successfully navigated the story and uncovered the truth. Your reputation and resources have been enhanced as a reward for your efforts.[/center]"
	_clear_choices()

## Enable/disable the panel
func set_panel_enabled(enabled: bool) -> void:
	visible = enabled
	if enabled:
		update_display()

## Check if story track is active
func is_story_track_active() -> bool:
	if story_track_system:
		return story_track_system.is_story_track_active
	return false

## Get story progress for external systems
func get_story_progress() -> Dictionary:
	if story_track_system:
		return story_track_system.get_story_track_status()
	return {"is_active": false}

## Manually refresh the display
func refresh_display() -> void:
	update_display()

## Set theme for the panel (if needed)
func apply_story_theme() -> void:
	# Add any story-specific theming here
	modulate = Color(1.0, 1.0, 1.0, 0.95) # Slightly transparent for atmospheric effect