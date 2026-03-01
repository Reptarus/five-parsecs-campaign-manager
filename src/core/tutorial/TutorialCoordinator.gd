class_name FPCM_TutorialCoordinator
extends Node

## Tutorial Coordinator - Orchestrates all tutorial components for Story Track
## Part of the Story Track vertical slice implementation
##
## Responsibilities:
## - First-run detection for new users
## - Guided mode prompt display
## - Connection between StoryTrackSystem and TutorialOverlay
## - Tutorial hint orchestration
## - Companion tool highlighting

# Preload tutorial overlay
const TutorialOverlayScript = preload("res://src/ui/components/tutorial/TutorialOverlay.gd")

## Signals for external coordination
signal guided_mode_selected(enabled: bool)
signal tutorial_hint_shown(event_id: String)
signal tutorial_dismissed
signal first_run_detected

## Constants
const PLAYER_SETTINGS_PATH := "user://player_settings.json"
const TUTORIAL_CONFIG_PATH := "res://data/tutorial/story_companion_tutorials.json"
const HINT_DISPLAY_DURATION := 15.0  # seconds

## State
var is_first_run: bool = false
var guided_mode_enabled: bool = false
var tutorial_overlay: Node = null  # FPCM_TutorialOverlay
var story_track_system: Resource = null  # FPCM_StoryTrackSystem
var tutorial_config: Dictionary = {}
var _pending_hints: Array[Dictionary] = []
var _current_hint_event_id: String = ""

## References to highlighted companion tools
var _highlighted_tools: Array[Control] = []

func _ready() -> void:
	_check_first_run()
	_load_tutorial_config()
	_initialize_overlay()
	print("TutorialCoordinator: Initialized (first_run=%s)" % is_first_run)

## Check if this is the user's first time running the app
func _check_first_run() -> void:
	is_first_run = not FileAccess.file_exists(PLAYER_SETTINGS_PATH)
	if is_first_run:
		print("TutorialCoordinator: First run detected - no player settings found")
		first_run_detected.emit()

## Load tutorial configuration from JSON
func _load_tutorial_config() -> void:
	if not FileAccess.file_exists(TUTORIAL_CONFIG_PATH):
		push_warning("TutorialCoordinator: Tutorial config not found at %s" % TUTORIAL_CONFIG_PATH)
		return

	var file := FileAccess.open(TUTORIAL_CONFIG_PATH, FileAccess.READ)
	if not file:
		push_error("TutorialCoordinator: Failed to open tutorial config")
		return

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()

	if parse_result != OK:
		push_error("TutorialCoordinator: Failed to parse tutorial config - %s" % json.get_error_message())
		return

	tutorial_config = json.get_data()
	print("TutorialCoordinator: Loaded tutorial config with %d event mappings" % tutorial_config.get("event_tool_mapping", {}).size())

## Initialize the tutorial overlay component
func _initialize_overlay() -> void:
	# Check if overlay already exists in scene tree
	tutorial_overlay = get_node_or_null("/root/TutorialOverlay")
	if tutorial_overlay:
		print("TutorialCoordinator: Found existing TutorialOverlay in scene tree")
		return

	# Create a new overlay instance if needed
	tutorial_overlay = TutorialOverlayScript.new()
	tutorial_overlay.name = "TutorialOverlay"
	# Will be added to scene tree when needed

## Connect to a StoryTrackSystem instance
func connect_to_story_track(story_system: Resource) -> void:
	if not story_system:
		push_error("TutorialCoordinator: Cannot connect to null StoryTrackSystem")
		return

	story_track_system = story_system

	# Connect the tutorial_requested signal
	if story_system.has_signal("tutorial_requested"):
		if not story_system.is_connected("tutorial_requested", _on_tutorial_requested):
			story_system.tutorial_requested.connect(_on_tutorial_requested)
			print("TutorialCoordinator: Connected to StoryTrackSystem.tutorial_requested")

	# Sync guided mode state
	if "guided_mode_enabled" in story_system:
		story_system.guided_mode_enabled = guided_mode_enabled

## Show the guided mode prompt for first-run users
func show_guided_mode_prompt() -> void:
	# Create confirmation dialog for guided mode
	var dialog := ConfirmationDialog.new()
	dialog.title = "Welcome to Five Parsecs"
	dialog.dialog_text = """Welcome, Captain!

Would you like to play in Guided Mode?

Guided Mode walks you through the Story Track - a curated 6-mission campaign that teaches game mechanics progressively while telling an engaging story.

Perfect for new players or those wanting a structured experience.

You can switch to Sandbox Mode anytime after completing the Story Track."""

	dialog.ok_button_text = "Start Guided Mode"
	dialog.cancel_button_text = "Skip to Sandbox"
	dialog.min_size = Vector2(450, 250)

	# Connect dialog signals
	dialog.confirmed.connect(_on_guided_mode_confirmed.bind(dialog))
	dialog.canceled.connect(_on_guided_mode_declined.bind(dialog))

	# Add to scene tree and show
	var root := get_tree().root
	if root:
		root.add_child(dialog)
		dialog.popup_centered()
	else:
		push_error("TutorialCoordinator: Cannot show guided mode prompt - no scene tree root")
		dialog.queue_free()

func _on_guided_mode_confirmed(dialog: ConfirmationDialog) -> void:
	guided_mode_enabled = true
	_save_guided_mode_preference(true)

	if story_track_system and "guided_mode_enabled" in story_track_system:
		story_track_system.guided_mode_enabled = true

	print("TutorialCoordinator: Guided mode enabled by user")
	guided_mode_selected.emit(true)
	dialog.queue_free()

func _on_guided_mode_declined(dialog: ConfirmationDialog) -> void:
	guided_mode_enabled = false
	_save_guided_mode_preference(false)

	print("TutorialCoordinator: User declined guided mode")
	guided_mode_selected.emit(false)
	dialog.queue_free()

## Save guided mode preference to player settings
func _save_guided_mode_preference(enabled: bool) -> void:
	var settings := {}

	# Load existing settings if present
	if FileAccess.file_exists(PLAYER_SETTINGS_PATH):
		var file := FileAccess.open(PLAYER_SETTINGS_PATH, FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK:
				settings = json.get_data()
			file.close()

	# Update guided mode setting
	settings["guided_mode_enabled"] = enabled
	settings["first_run_completed"] = true
	settings["settings_version"] = 1

	# Save settings
	var file := FileAccess.open(PLAYER_SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()
		print("TutorialCoordinator: Saved player settings")
	else:
		push_error("TutorialCoordinator: Failed to save player settings")

## Load guided mode preference from player settings
func load_guided_mode_preference() -> bool:
	if not FileAccess.file_exists(PLAYER_SETTINGS_PATH):
		return false

	var file := FileAccess.open(PLAYER_SETTINGS_PATH, FileAccess.READ)
	if not file:
		return false

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return false

	file.close()
	var settings: Dictionary = json.get_data()
	guided_mode_enabled = settings.get("guided_mode_enabled", false)
	return guided_mode_enabled

## Handle tutorial requests from StoryTrackSystem
func _on_tutorial_requested(event_id: String, companion_tools: Array, story_context: String) -> void:
	if not guided_mode_enabled:
		return

	print("TutorialCoordinator: Tutorial requested for event '%s'" % event_id)
	_current_hint_event_id = event_id

	# Get additional hint text from tutorial config
	var hint_text := _get_hint_text_for_event(event_id)

	# Show hint via overlay
	if tutorial_overlay and tutorial_overlay.has_method("show_story_hint"):
		# Ensure overlay is in scene tree
		if not tutorial_overlay.is_inside_tree():
			var root := get_tree().root
			if root:
				root.add_child(tutorial_overlay)

		tutorial_overlay.show_story_hint(companion_tools, story_context, hint_text)
		tutorial_hint_shown.emit(event_id)

	# Highlight companion tools
	_highlight_companion_tools(companion_tools)

## Get hint text for a specific event from config
func _get_hint_text_for_event(event_id: String) -> String:
	var event_mapping: Dictionary = tutorial_config.get("event_tool_mapping", {})
	var event_data: Dictionary = event_mapping.get(event_id, {})
	return event_data.get("hint_text", "")

## Highlight companion tools in the UI
func _highlight_companion_tools(tool_names: Array) -> void:
	# Clear previous highlights
	_clear_tool_highlights()

	# Find and highlight each tool by name
	for tool_name in tool_names:
		var tool_node := _find_companion_tool_node(tool_name)
		if tool_node and tool_node is Control:
			_apply_highlight_to_control(tool_node)
			_highlighted_tools.append(tool_node)

## Find a companion tool node by name
func _find_companion_tool_node(tool_name: String) -> Node:
	# Map tool names to scene paths (can be expanded)
	var tool_path_map := {
		"BattleJournal": "/root/MainGameScene/BattleJournal",
		"ObjectiveDisplay": "/root/MainGameScene/ObjectiveDisplay",
		"DiceDashboard": "/root/MainGameScene/DiceDashboard",
		"CrewRoster": "/root/MainGameScene/CrewRoster",
		"EquipmentPanel": "/root/MainGameScene/EquipmentPanel",
		"MissionBriefing": "/root/MainGameScene/MissionBriefing"
	}

	var path: String = tool_path_map.get(tool_name, "")
	if path.is_empty():
		return null

	return get_node_or_null(path)

## Apply highlight effect to a control
func _apply_highlight_to_control(control: Control) -> void:
	# Store original modulate for restoration
	if not control.has_meta("original_modulate"):
		control.set_meta("original_modulate", control.modulate)

	# Apply pulsing highlight effect
	var tween := create_tween()
	tween.set_loops(3)  # Pulse 3 times
	tween.tween_property(control, "modulate", Color(1.2, 1.2, 1.5, 1.0), 0.3)
	tween.tween_property(control, "modulate", Color.WHITE, 0.3)

	# Store tween reference for cleanup
	control.set_meta("highlight_tween", tween)

## Clear all tool highlights
func _clear_tool_highlights() -> void:
	for tool_node in _highlighted_tools:
		if is_instance_valid(tool_node):
			# Stop any active tween
			if tool_node.has_meta("highlight_tween"):
				var tween: Tween = tool_node.get_meta("highlight_tween")
				if tween and tween.is_valid():
					tween.kill()

			# Restore original modulate
			if tool_node.has_meta("original_modulate"):
				tool_node.modulate = tool_node.get_meta("original_modulate")

	_highlighted_tools.clear()

## Dismiss current tutorial hint
func dismiss_current_hint() -> void:
	if tutorial_overlay and tutorial_overlay.has_method("hide_overlay"):
		tutorial_overlay.hide_overlay()

	_clear_tool_highlights()
	_current_hint_event_id = ""
	tutorial_dismissed.emit()

## Queue a hint for later display
func queue_hint(event_id: String, tools: Array, context: String) -> void:
	_pending_hints.append({
		"event_id": event_id,
		"tools": tools,
		"context": context
	})

## Show next queued hint
func show_next_queued_hint() -> void:
	if _pending_hints.is_empty():
		return

	var hint: Dictionary = _pending_hints.pop_front()
	_on_tutorial_requested(hint.event_id, hint.tools, hint.context)

## Check if guided mode should be offered (first run or preference)
func should_offer_guided_mode() -> bool:
	return is_first_run

## Check if guided mode is currently active
func is_guided_mode_active() -> bool:
	return guided_mode_enabled

## Force enable guided mode (for testing)
func force_enable_guided_mode() -> void:
	guided_mode_enabled = true
	if story_track_system and "guided_mode_enabled" in story_track_system:
		story_track_system.guided_mode_enabled = true
	print("TutorialCoordinator: Forced guided mode enabled")

## Force disable guided mode
func force_disable_guided_mode() -> void:
	guided_mode_enabled = false
	if story_track_system and "guided_mode_enabled" in story_track_system:
		story_track_system.guided_mode_enabled = false
	dismiss_current_hint()
	print("TutorialCoordinator: Forced guided mode disabled")

## Get current tutorial state for save/load
func get_tutorial_state() -> Dictionary:
	return {
		"guided_mode_enabled": guided_mode_enabled,
		"current_hint_event_id": _current_hint_event_id,
		"pending_hints_count": _pending_hints.size()
	}

## Restore tutorial state from save data
func restore_tutorial_state(state: Dictionary) -> void:
	guided_mode_enabled = state.get("guided_mode_enabled", false)
	if story_track_system and "guided_mode_enabled" in story_track_system:
		story_track_system.guided_mode_enabled = guided_mode_enabled
