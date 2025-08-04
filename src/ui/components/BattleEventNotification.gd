class_name FPCM_BattleEventNotification
extends Control

## Battle Event Notification Component
##
## Displays battle events that occur during Five Parsecs battles.
## Provides clear notification with action buttons and automatic dismissal.
## Designed for non-intrusive notification during active gameplay.
##
## Architecture: Slide-in notification with timed auto-dismiss
## Performance: Lightweight animation with memory-efficient lifecycle

# Dependencies
# GlobalEnums available as autoload singleton
const Character = preload("res://src/core/character/Character.gd")

# Battle Event Types
enum BattleEventType {
	COMBAT,
	MOVEMENT,
	OBJECTIVE,
	ENVIRONMENTAL,
	SPECIAL
}

# Event notification signals
signal event_acknowledged(event_id: String)
signal event_dismissed(event_id: String)
signal dice_roll_requested(pattern: String, context: String)
signal event_details_requested(event_id: String)

# UI node references
@onready var notification_container: Control = %NotificationContainer
@onready var event_icon: TextureRect = %EventIcon
@onready var event_title: Label = %EventTitle
@onready var event_description: Label = %EventDescription
@onready var round_indicator: Label = %RoundIndicator
@onready var action_buttons: HBoxContainer = %ActionButtons
@onready var auto_dismiss_timer: Timer = %AutoDismissTimer
@onready var animation_player: AnimationPlayer = %AnimationPlayer

# Event data
var event_data: Resource = null
var notification_id: String = ""
var auto_dismiss_enabled: bool = true
var display_duration: float = 10.0 # seconds

# Animation and visual states
var is_visible: bool = false
var is_animating: bool = false

# Event type styling
var event_type_colors := {
	0: Color.ORANGE, # ENVIRONMENTAL_HAZARD
	1: Color.RED, # REINFORCEMENTS
	2: Color.CYAN, # WEATHER_CHANGE
	3: Color.YELLOW, # EQUIPMENT_MALFUNCTION
	4: Color.PURPLE, # MORALE_CHECK
	5: Color.GOLD # SPECIAL_MISSION
}

var event_type_icons := {
	0: "⚠️", # ENVIRONMENTAL_HAZARD
	1: "🚁", # REINFORCEMENTS
	2: "🌧️", # WEATHER_CHANGE
	3: "⚙️", # EQUIPMENT_MALFUNCTION
	4: "💭", # MORALE_CHECK
	5: "⭐" # SPECIAL_MISSION
}

# Internal variables
var _battle_tracker: Resource = null
var _notification_queue: Array = []
var _current_notification: Resource = null

func _ready() -> void:
	"""Initialize notification component"""
	_setup_notification_styling()
	_setup_auto_dismiss_timer()
	_setup_animations()

	# Start hidden
	hide_notification(false)

## Initialize the notification system
func initialize(battle_tracker: Resource) -> void:
	if not battle_tracker:
		push_error("BattleEventNotification: Cannot initialize with null battle tracker")
		return

	_battle_tracker = battle_tracker
	_connect_to_battle_events()

## Connect to battle events
func _connect_to_battle_events() -> void:
	if not _battle_tracker:
		return

	# Connect to battle event signals
	if _battle_tracker.has_signal("combat_event"):
		_battle_tracker.combat_event.connect(_on_combat_event)
	if _battle_tracker.has_signal("movement_event"):
		_battle_tracker.movement_event.connect(_on_movement_event)
	if _battle_tracker.has_signal("objective_event"):
		_battle_tracker.objective_event.connect(_on_objective_event)
	if _battle_tracker.has_signal("environmental_event"):
		_battle_tracker.environmental_event.connect(_on_environmental_event)
	if _battle_tracker.has_signal("special_event"):
		_battle_tracker.special_event.connect(_on_special_event)

## Disconnect from battle events
func _disconnect_from_battle_events() -> void:
	if not _battle_tracker:
		return

	# Disconnect from battle event signals
	if _battle_tracker.has_signal("combat_event"):
		_battle_tracker.combat_event.disconnect(_on_combat_event)
	if _battle_tracker.has_signal("movement_event"):
		_battle_tracker.movement_event.disconnect(_on_movement_event)
	if _battle_tracker.has_signal("objective_event"):
		_battle_tracker.objective_event.disconnect(_on_objective_event)
	if _battle_tracker.has_signal("environmental_event"):
		_battle_tracker.environmental_event.disconnect(_on_environmental_event)
	if _battle_tracker.has_signal("special_event"):
		_battle_tracker.special_event.disconnect(_on_special_event)

func _setup_notification_styling() -> void:
	"""Setup visual styling for notification"""
	if notification_container:
		var style := _create_notification_style()
		notification_container.add_theme_stylebox_override("panel", style)

func _create_notification_style() -> StyleBox:
	"""Create notification card style"""
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 4
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color.CYAN
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 8
	style.shadow_offset = Vector2(2, 2)
	return style

func _setup_auto_dismiss_timer() -> void:
	"""Setup auto-dismiss timer"""
	if auto_dismiss_timer:
		auto_dismiss_timer.wait_time = display_duration
		auto_dismiss_timer.one_shot = true
		auto_dismiss_timer.timeout.connect(_on_auto_dismiss_timeout)

func _setup_animations() -> void:
	"""Setup animation player with slide animations"""
	if not is_node_ready():
		push_warning("BattleEventNotification: Node not ready, deferring animation setup")
		call_deferred("_setup_animations")
		return
	
	# Skip animation setup if we're in the editor or during scene loading
	if Engine.is_editor_hint():
		return
		
	# CRITICAL FIX: Skip animation setup entirely during campaign creation to prevent crashes
	# Check if we're in a campaign creation context
	var current_scene = get_tree().current_scene if get_tree() else null
	if current_scene:
		var scene_name = current_scene.name
		if scene_name.contains("Campaign") or scene_name.contains("Creation"):
			print("BattleEventNotification: Skipping animation setup in campaign creation context")
			return
	
	if not animation_player:
		animation_player = AnimationPlayer.new()
		add_child(animation_player)

	# Safely create animations with error handling - defer to avoid scene loading issues
	call_deferred("_create_animations_deferred")

func _create_animations_deferred() -> void:
	"""Create animations in a deferred call to avoid scene loading conflicts"""
	# Additional safety check - don't create animations if we're not properly in the scene tree
	if not is_inside_tree() or not get_viewport():
		push_warning("BattleEventNotification: Not properly in scene tree, skipping animation creation")
		return
		
	# Don't create animations during campaign creation UI loading
	var scene_root = get_tree().current_scene
	if scene_root and scene_root.name == "CampaignCreationUI":
		push_warning("BattleEventNotification: Skipping animation creation during campaign UI loading")
		return
	
	if not _create_slide_in_animation():
		push_warning("BattleEventNotification: Failed to create slide-in animation")
	
	if not _create_slide_out_animation():
		push_warning("BattleEventNotification: Failed to create slide-out animation")

func _create_slide_in_animation() -> bool:
	"""Create slide-in animation with safe error handling"""
	if not animation_player or not is_inside_tree():
		return false
	
	# CRITICAL FIX: Add comprehensive null checks for animation creation
	if not is_instance_valid(animation_player):
		push_error("BattleEventNotification: AnimationPlayer is not valid")
		return false
	
	# Create animation library first with validation
	var anim_library = AnimationLibrary.new()
	if not anim_library or not is_instance_valid(anim_library):
		push_error("BattleEventNotification: Failed to create AnimationLibrary")
		return false
	
	# Add library to animation player first - with error handling
	if animation_player.has_animation_library("default"):
		animation_player.remove_animation_library("default")
	
	# CRITICAL FIX: Validate library before adding to prevent null reference
	if not anim_library:
		push_error("BattleEventNotification: AnimationLibrary is null before adding")
		return false
	
	var result = animation_player.add_animation_library("default", anim_library)
	if result != OK:
		push_error("BattleEventNotification: Failed to add animation library: " + str(result))
		return false
	
	var animation := Animation.new()
	animation.length = 0.5

	# Position track - with safe viewport access
	var position_track := animation.add_track(Animation.TYPE_VALUE)
	if position_track >= 0:
		animation.track_set_path(position_track, NodePath(".:position"))
		var viewport = get_viewport()
		var start_x = viewport.get_visible_rect().size.x if viewport else 800
		animation.track_insert_key(position_track, 0.0, Vector2(start_x, position.y))
		animation.track_insert_key(position_track, 0.5, position)
	else:
		push_error("BattleEventNotification: Failed to create position track")
		return false

	# Modulate track for fade-in
	var modulate_track := animation.add_track(Animation.TYPE_VALUE)
	if modulate_track >= 0:
		animation.track_set_path(modulate_track, NodePath(".:modulate"))
		animation.track_insert_key(modulate_track, 0.0, Color(1, 1, 1, 0))
		animation.track_insert_key(modulate_track, 0.5, Color(1, 1, 1, 1))
	else:
		push_error("BattleEventNotification: Failed to create modulate track")
		return false

	# Add animation to library
	anim_library.add_animation("slide_in", animation)
	return true

func _create_slide_out_animation() -> bool:
	"""Create slide-out animation with safe error handling"""
	if not animation_player or not is_inside_tree():
		return false
	
	# Get existing library (should be created by slide_in animation)
	var library = animation_player.get_animation_library("default")
	if not library:
		push_error("BattleEventNotification: Animation library not found for slide_out")
		return false
		
	var animation := Animation.new()
	animation.length = 0.3

	# Position track - with safe viewport access
	var position_track := animation.add_track(Animation.TYPE_VALUE)
	if position_track >= 0:
		animation.track_set_path(position_track, NodePath(".:position"))
		var viewport = get_viewport()
		var end_x = viewport.get_visible_rect().size.x if viewport else 800
		animation.track_insert_key(position_track, 0.0, position)
		animation.track_insert_key(position_track, 0.3, Vector2(end_x, position.y))
	else:
		push_error("BattleEventNotification: Failed to create position track for slide-out")
		return false

	# Modulate track for fade-out
	var modulate_track := animation.add_track(Animation.TYPE_VALUE)
	if modulate_track >= 0:
		animation.track_set_path(modulate_track, NodePath(".:modulate"))
		animation.track_insert_key(modulate_track, 0.0, Color(1, 1, 1, 1))
		animation.track_insert_key(modulate_track, 0.3, Color(1, 1, 1, 0))
	else:
		push_error("BattleEventNotification: Failed to create modulate track for slide-out")
		return false

	# Add animation to existing library
	library.add_animation("slide_out", animation)
	return true

# =====================================================
# EVENT DISPLAY MANAGEMENT
# =====================================================

func show_event(event: Resource, round_number: int = 0) -> void:
	"""
	Display battle event notification

	@param event: Battle event to display
	@param round_number: Current battle round
	"""
	if is_animating or not event:
		return

	event_data = event
	notification_id = event.event_id

	_update_event_display(round_number)
	_setup_action_buttons()
	_show_notification()

func _update_event_display(round_number: int) -> void:
	"""Update display elements with event data"""
	if not event_data:
		return

	# Update title
	if event_title:
		event_title.text = event_data.title

	# Update description
	if event_description:
		event_description.text = event_data.description
		event_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Update round indicator
	if round_indicator and round_number > 0:
		round_indicator.text = "Round %d" % round_number

	# Update icon
	if event_icon:
		_update_event_icon()

	# Update styling based on event type
	_update_event_styling()

func _update_event_icon() -> void:
	"""Update event icon based on type"""
	if not event_icon or not event_data:
		return

	var icon_text: String = event_type_icons.get(event_data.event_type, "📢")

	# Since event_icon is TextureRect, we need to handle icon differently
	# For now, we'll just set the modulate color

	# Color the icon
	var type_color: Color = event_type_colors.get(event_data.event_type, Color.WHITE)
	event_icon.modulate = type_color

func _update_event_styling() -> void:
	"""Update notification styling based on event type"""
	if not notification_container or not event_data:
		return

	var style := notification_container.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var type_color: Color = event_type_colors.get(event_data.event_type, Color.CYAN)
		style.border_color = type_color

func _setup_action_buttons() -> void:
	"""Setup action buttons based on event requirements"""
	if not action_buttons:
		return

	# Clear existing buttons
	_clear_action_buttons()

	# Acknowledge button (always present)
	var acknowledge_btn := _create_action_button("Got It", _on_acknowledge_pressed)
	action_buttons.add_child(acknowledge_btn)

	# Dice roll button (if event requires dice)
	if event_data and event_data.requires_dice_roll:
		var dice_btn := _create_action_button("Roll %s" % event_data.dice_pattern, _on_dice_roll_pressed)
		dice_btn.modulate = Color.YELLOW
		action_buttons.add_child(dice_btn)

	# Details button (if more info available)
	var details_btn := _create_action_button("Details", _on_details_pressed)
	details_btn.modulate = Color.CYAN
	action_buttons.add_child(details_btn)

	# Dismiss button
	var dismiss_btn := _create_action_button("✕", _on_dismiss_pressed)
	dismiss_btn.custom_minimum_size = Vector2(32, 32)
	dismiss_btn.modulate = Color.LIGHT_GRAY
	action_buttons.add_child(dismiss_btn)

func _create_action_button(text: String, callback: Callable) -> Button:
	"""Create action button with styling"""
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(60, 32)
	button.pressed.connect(callback)

	# Style button
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.8)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("normal", style)

	return button

func _clear_action_buttons() -> void:
	"""Clear all action buttons"""
	if action_buttons:
		for child in action_buttons.get_children():
			child.queue_free()

# =====================================================
# NOTIFICATION VISIBILITY
# =====================================================

func _show_notification() -> void:
	"""Show notification with animation"""
	if is_visible or is_animating:
		return

	is_animating = true
	visible = true

	# Position for slide-in (start off-screen right)
	position.x = get_viewport().get_visible_rect().size.x

	# Play slide-in animation
	if animation_player and animation_player.has_animation("slide_in"):
		animation_player.play("slide_in")
		await animation_player.animation_finished

	is_animating = false
	is_visible = true

	# Start auto-dismiss timer if enabled
	if auto_dismiss_enabled and auto_dismiss_timer:
		auto_dismiss_timer.start()

func hide_notification(animate: bool = true) -> void:
	"""Hide notification with optional animation"""
	if not is_visible and not animate:
		visible = false
		return

	if is_animating:
		return

	# Stop auto-dismiss timer
	if auto_dismiss_timer:
		auto_dismiss_timer.stop()

	if animate:
		is_animating = true

		# Play slide-out animation
		if animation_player and animation_player.has_animation("slide_out"):
			animation_player.play("slide_out")
			await animation_player.animation_finished

		is_animating = false

	is_visible = false
	visible = false

# =====================================================
# ACTION HANDLERS
# =====================================================

func _on_acknowledge_pressed() -> void:
	"""Handle acknowledge button press"""
	if event_data:
		event_acknowledged.emit(event_data.event_id)

	hide_notification()

func _on_dice_roll_pressed() -> void:
	"""Handle dice roll button press"""
	if event_data:
		var pattern: String = event_data.dice_pattern if event_data.requires_dice_roll else "d6"
		var context: String = "Event: %s" % event_data.title
		dice_roll_requested.emit(pattern, context)

func _on_details_pressed() -> void:
	"""Handle details button press"""
	if event_data:
		event_details_requested.emit(event_data.event_id)

	_show_event_details()

func _on_dismiss_pressed() -> void:
	"""Handle dismiss button press"""
	if event_data:
		event_dismissed.emit(event_data.event_id)

	hide_notification()

func _on_auto_dismiss_timeout() -> void:
	"""Handle auto-dismiss timeout"""
	if auto_dismiss_enabled:
		hide_notification()

# =====================================================
# EVENT DETAILS DISPLAY
# =====================================================

func _show_event_details() -> void:
	"""Show detailed event information popup"""
	var details_popup := _create_details_popup()
	get_tree().current_scene.add_child(details_popup)
	details_popup.popup_centered()

func _create_details_popup() -> AcceptDialog:
	"""Create event details popup"""
	var popup := AcceptDialog.new()
	popup.title = "Battle Event Details"
	popup.size = Vector2(400, 300)

	var content := VBoxContainer.new()

	# Event title
	var title_label := Label.new()
	title_label.text = event_data.title if event_data else "Unknown Event"
	title_label.add_theme_font_size_override("font_size", 18)
	content.add_child(title_label)

	# Event description
	var desc_label := RichTextLabel.new()
	desc_label.custom_minimum_size = Vector2(0, 100)
	desc_label.bbcode_enabled = true
	desc_label.text = _get_detailed_event_description()
	content.add_child(desc_label)

	# Event effects
	if event_data and (event_data.affects_crew or event_data.affects_enemies or event_data.affects_battlefield):
		var effects_label := Label.new()
		effects_label.text = "Effects:"
		effects_label.add_theme_font_size_override("font_size", 14)
		content.add_child(effects_label)

		var effects_text := _get_event_effects_text()
		var effects_detail := Label.new()
		effects_detail.text = effects_text
		effects_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(effects_detail)

	# Special instructions
	if event_data and event_data.special_instructions != "":
		var instructions_label := Label.new()
		instructions_label.text = "Instructions:"
		instructions_label.add_theme_font_size_override("font_size", 14)
		content.add_child(instructions_label)

		var instructions_text := Label.new()
		instructions_text.text = event_data.special_instructions
		instructions_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		instructions_text.modulate = Color.YELLOW
		content.add_child(instructions_text)

	popup.add_child(content)
	popup.confirmed.connect(popup.queue_free)

	return popup

func _get_detailed_event_description() -> String:
	"""Get detailed event description with formatting"""
	if not event_data:
		return "No event data available"

	var description: String = event_data.description

	# Add event type context
	var type_context: String = _get_event_type_context(event_data.event_type)
	if type_context != "":
		description += "\n\n[i]" + type_context + "[/i]"

	return description

func _get_event_type_context(event_type: int) -> String:
	"""Get contextual information for event type"""
	match event_type:
		0: # ENVIRONMENTAL_HAZARD
			return "Environmental hazards can affect movement, visibility, or cause damage to units in specific areas."
		1: # REINFORCEMENTS
			return "Reinforcement events may bring additional enemy units or provide support for existing forces."
		2: # WEATHER_CHANGE
			return "Weather changes can affect visibility, movement, and weapon effectiveness across the battlefield."
		3: # EQUIPMENT_MALFUNCTION
			return "Equipment malfunctions may require repair rolls or cause temporary disadvantages."
		4: # MORALE_CHECK
			return "Morale checks test unit resolve and may cause retreats or performance penalties."
		5: # SPECIAL_MISSION
			return "Mission-specific events are unique to the current scenario and may affect victory conditions."
		_:
			return "Unknown event type."

func _get_event_effects_text() -> String:
	"""Get formatted text describing event effects"""
	if not event_data:
		return ""

	var effects: Array[String] = []

	if event_data.affects_crew:
		effects.append("• Affects crew units")
	if event_data.affects_enemies:
		effects.append("• Affects enemy units")
	if event_data.affects_battlefield:
		effects.append("• Affects battlefield conditions")

	if event_data.duration_rounds > 0:
		effects.append("• Duration: %d rounds" % event_data.duration_rounds)
	else:
		effects.append("• Effect: Immediate")

	return "\n".join(effects)

# =====================================================
# CONFIGURATION AND UTILITY
# =====================================================

func set_auto_dismiss(enabled: bool, duration: float = 10.0) -> void:
	"""Configure auto-dismiss behavior"""
	auto_dismiss_enabled = enabled
	display_duration = duration

	if auto_dismiss_timer:
		auto_dismiss_timer.wait_time = duration

func set_notification_position(screen_position: Vector2) -> void:
	"""Set notification position on screen"""
	position = screen_position

func is_notification_visible() -> bool:
	"""Check if notification is currently visible"""
	return is_visible

func get_current_event_id() -> String:
	"""Get the current event ID"""
	return notification_id

func force_dismiss() -> void:
	"""Force immediate dismissal without animation"""
	if auto_dismiss_timer:
		auto_dismiss_timer.stop()

	hide_notification(false)

# =====================================================
# INPUT HANDLING
# =====================================================

func _input(event: InputEvent) -> void:
	"""Handle keyboard shortcuts for notification"""
	if not is_visible or is_animating:
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed:
			match key_event.keycode:
				KEY_ENTER, KEY_SPACE:
					_on_acknowledge_pressed()
				KEY_ESCAPE:
					_on_dismiss_pressed()
				KEY_D:
					_on_details_pressed()
				KEY_R:
					if event_data and event_data.requires_dice_roll:
						_on_dice_roll_pressed()

# =====================================================
# CLEANUP
# =====================================================

func cleanup() -> void:
	"""Clean up notification resources"""
	if auto_dismiss_timer:
		auto_dismiss_timer.stop()

	event_data = null
	notification_id = ""
	is_visible = false
	is_animating = false

	hide_notification(false)

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null

## Event handlers
func _on_combat_event(event_data: Dictionary) -> void:
	show_event(Resource.new(), event_data.get("round", 0))

func _on_movement_event(event_data: Dictionary) -> void:
	show_event(Resource.new(), event_data.get("round", 0))

func _on_objective_event(event_data: Dictionary) -> void:
	show_event(Resource.new(), event_data.get("round", 0))

func _on_environmental_event(event_data: Dictionary) -> void:
	show_event(Resource.new(), event_data.get("round", 0))

func _on_special_event(event_data: Dictionary) -> void:
	show_event(Resource.new(), event_data.get("round", 0))