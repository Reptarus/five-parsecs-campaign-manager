extends Control
class_name WorldPhaseComponent

## Base class for World Phase UI components.
## Provides event bus integration with auto-cleanup, lifecycle hooks,
## and shared utilities. All 9 world phase components extend this.
##
## Phase 33 Sprint 9: Redesigned from unused 111-line stub to actively
## inherited base with event bus auto-subscription pattern.

# Signals for parent integration
signal component_ready(component_name: String)
signal component_error(component_name: String, error_message: String)

# Design system constants shared by all world phase components
const TOUCH_TARGET_MIN := 48  # Minimum interactive element height (8px grid, Sprint 26.4)

# Event bus integration
const CampaignTurnEventBus = preload("res://src/core/events/CampaignTurnEventBus.gd")
var event_bus: CampaignTurnEventBus = null
var _event_subscriptions: Array[Dictionary] = []

# Component identity
var component_name: String = ""

# Feature flag
var feature_enabled: bool = true

func _ready() -> void:
	if component_name.is_empty():
		component_name = name
	if not feature_enabled:
		hide()
		return
	_initialize_event_bus()
	_connect_ui_signals()
	_setup_initial_state()

func _initialize_event_bus() -> void:
	## Resolve event bus autoload and call virtual _subscribe_to_events().
	event_bus = get_node_or_null("/root/CampaignTurnEventBus")
	_subscribe_to_events()

func _subscribe_to_events() -> void:
	## Override: subscribe to specific event bus events using _subscribe().
	pass

func _subscribe(event_type: CampaignTurnEventBus.TurnEvent, handler: Callable) -> void:
	## Subscribe to an event with automatic cleanup in _exit_tree().
	if event_bus:
		event_bus.subscribe_to_event(event_type, handler)
		_event_subscriptions.append({"event": event_type, "handler": handler})

func _exit_tree() -> void:
	## Auto-cleanup all event bus subscriptions.
	if event_bus:
		for sub in _event_subscriptions:
			event_bus.unsubscribe_from_event(sub.event, sub.handler)
	_event_subscriptions.clear()

func _connect_ui_signals() -> void:
	## Override: connect component-specific UI signals.
	pass

func _setup_initial_state() -> void:
	## Override: initialize component state for first use.
	pass

# --- Public API (override in subclasses) ---

func is_phase_completed() -> bool:
	## Override: return whether this component's phase work is done.
	return false

func get_step_results() -> Dictionary:
	## Override: return standardized results dict.
	return {"component_name": component_name}

func reset_phase() -> void:
	## Override: reset state for new campaign turn.
	pass

# --- Event handler stubs ---

func _on_phase_started(_data: Dictionary) -> void:
	## Override: react to phase started events.
	pass

func _on_automation_toggled(_data: Dictionary) -> void:
	## Override: react to automation toggle.
	pass

# --- Shared utilities ---

func _handle_error(error_message: String) -> void:
	push_error("%s Error: %s" % [component_name, error_message])
	component_error.emit(component_name, error_message)

func _publish_phase_completed(phase_name: String, extra_data: Dictionary = {}) -> void:
	if event_bus:
		var data: Dictionary = {"phase_name": phase_name}
		data.merge(extra_data)
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_COMPLETED, data)

var _help_dialog: AcceptDialog = null

func _show_help_dialog(title: String, content: String) -> void:
	if not _help_dialog:
		_help_dialog = AcceptDialog.new()
		_help_dialog.dialog_hide_on_ok = true
		add_child(_help_dialog)
	_help_dialog.title = title
	var existing := _help_dialog.get_node_or_null("HelpContent")
	if existing:
		existing.queue_free()
	var rtl := RichTextLabel.new()
	rtl.name = "HelpContent"
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.custom_minimum_size = Vector2(400, 200)
	rtl.text = content
	_help_dialog.add_child(rtl)
	_help_dialog.popup_centered()
