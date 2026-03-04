class_name FPCM_StoryNotificationIndicator
extends Control

## Story Track Notification Indicator
## Shows when story events are available and provides quick access

signal story_notification_clicked()

@onready var notification_button: Button = $NotificationButton
@onready var status_label: Label = $StatusLabel

# Manager references
var alpha_manager: Node = null
var story_track_system: Variant = null

# Current state
var story_available: bool = false
var _check_timer: Timer

func _ready() -> void:
	_initialize_managers()
	_setup_ui()
	_connect_signals()
	_setup_check_timer()

func _exit_tree() -> void:
	## Cleanup when indicator is removed from scene tree
	if _check_timer:
		_check_timer.stop()
		_check_timer.queue_free()
		_check_timer = null

func _initialize_managers() -> void:
	## Initialize manager references from autoloads
	alpha_manager = get_node("/root/FPCM_AlphaGameManager") if has_node("/root/FPCM_AlphaGameManager") else null

	if alpha_manager and alpha_manager.has_method("get_story_track_system"):
		story_track_system = alpha_manager.get_story_track_system()

func _setup_ui() -> void:
	## Setup the notification UI
	notification_button.text = "📖"
	notification_button.custom_minimum_size = Vector2(40, 40)
	notification_button.visible = false

	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Position indicator in top-right corner
	anchors_preset = Control.PRESET_TOP_RIGHT
	offset_left = -120
	offset_top = 10
	custom_minimum_size = Vector2(100, 60)

func _connect_signals() -> void:
	## Connect UI signals
	notification_button.pressed.connect(_on_notification_clicked)

func _setup_check_timer() -> void:
	## Setup periodic status check timer
	_check_timer = Timer.new()
	add_child(_check_timer)
	_check_timer.wait_time = 2.0  # Check every 2 seconds
	_check_timer.timeout.connect(_check_story_status)
	_check_timer.start()

func _check_story_status() -> void:
	## Check if story events are available
	if not story_track_system:
		_hide_notification()
		return

	var status = story_track_system.get_story_track_status()

	var is_active = status.get("is_active", false)
	var current_event = story_track_system.get_current_event()

	var can_progress = status.get("can_progress", false)

	# Show notification if story is active and has events or can progress
	var should_show = is_active and (current_event != null or can_progress)

	if should_show != story_available:
		story_available = should_show
		if story_available:
			_show_notification(status)
		else:
			_hide_notification()

func _show_notification(status: Dictionary) -> void:
	## Show story notification
	notification_button.visible = true

	var evidence_count = status.get("evidence_pieces", 0)

	var clock_ticks = status.get("clock_ticks", 0)

	# Update tooltip with story status
	notification_button.tooltip_text = "Story Events Available!\nEvidence: %d\nClock: %d\nClick to access story phase" % [evidence_count, clock_ticks]

	status_label.text = "Story!"
	status_label.modulate = Color.GOLD

	# Pulse animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(notification_button, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.5)
	tween.tween_property(notification_button, "modulate", Color.WHITE, 0.5)

func _hide_notification() -> void:
	## Hide story notification
	notification_button.visible = false
	status_label.text = ""

	# Stop any running tweens
	var tweens = get_tree().get_nodes_in_group("tween")
	for tween in tweens:
		if tween.is_valid():
			tween.kill()

func _on_notification_clicked() -> void:
	## Handle notification button click
	story_notification_clicked.emit()

	# Also try to directly trigger story phase if MainGameScene is available
	var main_scene = get_tree().get_nodes_in_group("main_game_scene")
	if main_scene.size() > 0:
		var main_game = main_scene[0]
		if main_game and main_game.has_method("show_story_phase_manually"):
			main_game.show_story_phase_manually()

## Manual refresh for external calls
func refresh_status() -> void:
	## Manually refresh story status
	_check_story_status()

## Check if story is currently available

func is_story_available() -> bool:
	## Check if story events are currently available
	return story_available

