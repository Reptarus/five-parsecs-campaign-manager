extends CanvasLayer
class_name NotificationManagerClass

## NotificationManager - Toast/Snackbar notification system
## Sprint B2: Provides user feedback for save/load, phase changes, errors, etc.
##
## Usage:
##   NotificationManager.show_success("Campaign saved!")
##   NotificationManager.show_error("Failed to load save file")
##   NotificationManager.show_warning("Low credits!")
##   NotificationManager.show_info("Phase: World Step 3")

signal notification_shown(message: String, type: String)
signal notification_dismissed(message: String)
signal queue_cleared

## Notification Types
enum NotificationType {
	INFO,
	SUCCESS,
	WARNING,
	ERROR
}

## Configuration
const DEFAULT_DURATION := 3.0   # Seconds before auto-dismiss
const SHORT_DURATION := 2.0     # Quick notifications
const LONG_DURATION := 5.0      # Important notifications
const MAX_VISIBLE := 3          # Maximum notifications visible at once
const ANIMATION_DURATION := 0.2 # Slide in/out animation

## Position settings
enum NotificationPosition {
	TOP_CENTER,
	TOP_RIGHT,
	BOTTOM_CENTER,
	BOTTOM_RIGHT
}
var position := NotificationPosition.TOP_CENTER

## Colors from UIColors design system
const COLORS := {
	"info": UIColors.COLOR_BLUE,
	"success": UIColors.COLOR_EMERALD,
	"warning": UIColors.COLOR_AMBER,
	"error": UIColors.COLOR_RED,
	"background": UIColors.COLOR_SECONDARY,
	"text": UIColors.COLOR_TEXT_PRIMARY,
	"border": UIColors.COLOR_BORDER
}

## State
var _notification_queue: Array[Dictionary] = []
var _active_notifications: Array[Control] = []
var _container: VBoxContainer
var _is_processing: bool = false

func _ready() -> void:
	# Set layer above most UI but below TransitionManager
	layer = 90

	# Create container for notifications
	_setup_container()

	print("NotificationManager: Initialized with %d max visible notifications" % MAX_VISIBLE)

func _exit_tree() -> void:
	clear_all()
	_container = null

func _setup_container() -> void:
	## Create the container that holds notifications
	_container = VBoxContainer.new()
	_container.name = "NotificationContainer"

	# Configure container based on position
	_update_container_position()

	# Add spacing between notifications
	_container.add_theme_constant_override("separation", 8)

	add_child(_container)

func _update_container_position() -> void:
	## Update container anchors based on position setting
	match position:
		NotificationPosition.TOP_CENTER:
			_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
			_container.position = Vector2(-200, 20)  # Offset from top
			_container.custom_minimum_size = Vector2(400, 0)
		NotificationPosition.TOP_RIGHT:
			_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			_container.position = Vector2(-420, 20)
			_container.custom_minimum_size = Vector2(400, 0)
		NotificationPosition.BOTTOM_CENTER:
			_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
			_container.position = Vector2(-200, -100)
			_container.custom_minimum_size = Vector2(400, 0)
		NotificationPosition.BOTTOM_RIGHT:
			_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			_container.position = Vector2(-420, -100)
			_container.custom_minimum_size = Vector2(400, 0)

## Public API - Show notifications

func show_info(message: String, duration: float = DEFAULT_DURATION) -> void:
	## Show an info notification (blue)
	_queue_notification(message, NotificationType.INFO, duration)

func show_success(message: String, duration: float = DEFAULT_DURATION) -> void:
	## Show a success notification (green)
	_queue_notification(message, NotificationType.SUCCESS, duration)

func show_warning(message: String, duration: float = DEFAULT_DURATION) -> void:
	## Show a warning notification (orange)
	_queue_notification(message, NotificationType.WARNING, duration)

func show_error(message: String, duration: float = LONG_DURATION) -> void:
	## Show an error notification (red, longer duration)
	_queue_notification(message, NotificationType.ERROR, duration)

func show_toast(message: String, type: String = "info", duration: float = DEFAULT_DURATION) -> void:
	## Generic toast method - type can be "info", "success", "warning", "error" 
	var notification_type := NotificationType.INFO
	match type.to_lower():
		"success":
			notification_type = NotificationType.SUCCESS
		"warning":
			notification_type = NotificationType.WARNING
		"error":
			notification_type = NotificationType.ERROR
	_queue_notification(message, notification_type, duration)

## Queue Management

func _queue_notification(message: String, type: NotificationType, duration: float) -> void:
	## Add notification to queue and process
	_notification_queue.append({
		"message": message,
		"type": type,
		"duration": duration
	})

	if not _is_processing:
		_process_queue()

func _process_queue() -> void:
	## Process queued notifications
	_is_processing = true

	while not _notification_queue.is_empty():
		# Wait if max visible reached
		while _active_notifications.size() >= MAX_VISIBLE:
			await get_tree().create_timer(0.5).timeout
			# Clean up dismissed notifications
			_cleanup_dismissed()

		# Get next notification
		var notification_data = _notification_queue.pop_front()
		await _show_notification(notification_data)

		# Small delay between notifications
		await get_tree().create_timer(0.1).timeout

	_is_processing = false

func _cleanup_dismissed() -> void:
	## Remove dismissed notifications from active list
	_active_notifications = _active_notifications.filter(func(n): return is_instance_valid(n))

## Notification Creation and Display

func _show_notification(data: Dictionary) -> void:
	## Create and display a notification
	var notification = _create_notification_panel(data)
	_container.add_child(notification)
	_active_notifications.append(notification)

	# Animate in
	await _animate_in(notification)

	notification_shown.emit(data.message, _type_to_string(data.type))

	# Start auto-dismiss timer
	_start_dismiss_timer(notification, data.message, data.duration)

func _create_notification_panel(data: Dictionary) -> PanelContainer:
	## Create the visual notification panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 56)

	# Create stylebox
	var style = StyleBoxFlat.new()
	style.bg_color = COLORS.background
	style.border_color = _get_type_color(data.type)
	style.set_border_width_all(2)
	style.border_width_left = 4  # Accent stripe on left
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	# Create content layout
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# Icon based on type
	var icon = Label.new()
	icon.text = _get_type_icon(data.type)
	icon.add_theme_font_size_override("font_size", 20)
	icon.add_theme_color_override("font_color", _get_type_color(data.type))
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon)

	# Message
	var message = Label.new()
	message.text = data.message
	message.add_theme_font_size_override("font_size", 14)
	message.add_theme_color_override("font_color", COLORS.text)
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(message)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
	close_btn.pressed.connect(func(): _dismiss_notification(panel, data.message))
	hbox.add_child(close_btn)

	# Start transparent for animation
	panel.modulate.a = 0.0

	return panel

func _get_type_color(type: NotificationType) -> Color:
	## Get color for notification type
	match type:
		NotificationType.INFO:
			return COLORS.info
		NotificationType.SUCCESS:
			return COLORS.success
		NotificationType.WARNING:
			return COLORS.warning
		NotificationType.ERROR:
			return COLORS.error
	return COLORS.info

func _get_type_icon(type: NotificationType) -> String:
	## Get icon for notification type
	match type:
		NotificationType.INFO:
			return "i"
		NotificationType.SUCCESS:
			return "v"  # checkmark
		NotificationType.WARNING:
			return "!"
		NotificationType.ERROR:
			return "X"
	return "i"

func _type_to_string(type: NotificationType) -> String:
	## Convert type enum to string
	match type:
		NotificationType.INFO:
			return "info"
		NotificationType.SUCCESS:
			return "success"
		NotificationType.WARNING:
			return "warning"
		NotificationType.ERROR:
			return "error"
	return "info"

## Animation

func _animate_in(notification: Control) -> void:
	## Animate notification sliding in
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(notification, "modulate:a", 1.0, ANIMATION_DURATION)

	await tween.finished

func _animate_out(notification: Control) -> void:
	## Animate notification sliding out
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(notification, "modulate:a", 0.0, ANIMATION_DURATION)

	await tween.finished

## Dismiss

func _start_dismiss_timer(notification: Control, message: String, duration: float) -> void:
	## Start auto-dismiss timer for notification
	await get_tree().create_timer(duration).timeout

	if is_instance_valid(notification):
		_dismiss_notification(notification, message)

func _dismiss_notification(notification: Control, message: String) -> void:
	## Dismiss a notification with animation
	if not is_instance_valid(notification):
		return

	await _animate_out(notification)

	if is_instance_valid(notification):
		_active_notifications.erase(notification)
		notification.queue_free()

	notification_dismissed.emit(message)

## Utility

func clear_all() -> void:
	## Clear all notifications immediately
	_notification_queue.clear()

	for notification in _active_notifications:
		if is_instance_valid(notification):
			notification.queue_free()

	_active_notifications.clear()
	queue_cleared.emit()

func set_position(new_position: NotificationPosition) -> void:
	## Change notification display position
	position = new_position
	_update_container_position()

func get_queue_size() -> int:
	## Get number of queued notifications
	return _notification_queue.size()

func get_active_count() -> int:
	## Get number of currently visible notifications
	return _active_notifications.size()

## Convenience methods for common notifications

func notify_save_success(campaign_name: String = "") -> void:
	## Show save success notification
	var msg = "Campaign saved!" if campaign_name.is_empty() else "Campaign '%s' saved!" % campaign_name
	show_success(msg)

func notify_save_failed(error: String = "") -> void:
	## Show save failed notification
	var msg = "Failed to save campaign" if error.is_empty() else "Save failed: %s" % error
	show_error(msg)

func notify_load_success(campaign_name: String = "") -> void:
	## Show load success notification
	var msg = "Campaign loaded!" if campaign_name.is_empty() else "Campaign '%s' loaded!" % campaign_name
	show_success(msg)

func notify_load_failed(error: String = "") -> void:
	## Show load failed notification
	var msg = "Failed to load campaign" if error.is_empty() else "Load failed: %s" % error
	show_error(msg)

func notify_phase_change(phase_name: String) -> void:
	## Show phase change notification
	show_info("Phase: %s" % phase_name, SHORT_DURATION)

func notify_auto_save() -> void:
	## Show auto-save notification
	show_info("Auto-saving...", SHORT_DURATION)

func notify_low_credits(amount: int) -> void:
	## Show low credits warning
	show_warning("Low credits: %d remaining" % amount)

func notify_crew_injured(crew_name: String) -> void:
	## Show crew injured notification
	show_warning("%s was injured!" % crew_name)

func notify_victory_progress(condition: String, progress: int, target: int) -> void:
	## Show victory progress notification
	show_info("%s: %d/%d" % [condition, progress, target], SHORT_DURATION)

## Debug

func _test_notifications() -> void:
	## Test all notification types
	show_info("This is an info notification")
	await get_tree().create_timer(0.5).timeout
	show_success("This is a success notification")
	await get_tree().create_timer(0.5).timeout
	show_warning("This is a warning notification")
	await get_tree().create_timer(0.5).timeout
	show_error("This is an error notification")
