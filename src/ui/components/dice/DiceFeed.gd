class_name DiceFeed
extends Control

## Top-level dice feed that displays recent rolls
## Can be overlaid on any screen to show dice activity

const FPCM_DiceSystem = preload("res://src/core/systems/DiceSystem.gd")

@onready var feed_container: VBoxContainer = $Panel/VBoxContainer
@onready var toggle_button: Button = $ToggleButton
@onready var clear_button: Button = $Panel/VBoxContainer/HeaderPanel/ClearButton
@onready var settings_button: Button = $Panel/VBoxContainer/HeaderPanel/SettingsButton
@onready var panel: Panel = $Panel

var dice_system: FPCM_DiceSystem
var roll_entries: Array[Control] = []
var max_visible_rolls: int = 5
var is_expanded: bool = true
var auto_hide_timer: Timer

## Individual roll entry in the feed
class RollEntry extends Control:
	var roll_data: FPCM_DiceSystem.DiceRoll
	
	@onready var context_label: Label = $HBoxContainer/ContextLabel
	@onready var dice_label: Label = $HBoxContainer/DiceLabel
	@onready var result_label: Label = $HBoxContainer/ResultLabel
	@onready var timestamp_label: Label = $HBoxContainer/TimestampLabel
	
	func _ready():
		custom_minimum_size.y = 30
		_setup_layout()
	
	func _setup_layout():
		var hbox = HBoxContainer.new()
		add_child(hbox)
		
		context_label = Label.new()
		context_label.custom_minimum_size.x = 120
		context_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		hbox.add_child(context_label)
		
		dice_label = Label.new()
		dice_label.custom_minimum_size.x = 60
		dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(dice_label)
		
		result_label = Label.new()
		result_label.custom_minimum_size.x = 80
		result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(result_label)
		
		timestamp_label = Label.new()
		timestamp_label.custom_minimum_size.x = 60
		timestamp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		timestamp_label.add_theme_font_size_override("font_size", 10)
		hbox.add_child(timestamp_label)
	
	func set_roll_data(p_roll_data: FPCM_DiceSystem.DiceRoll):
		roll_data = p_roll_data
		_update_display()
	
	func _update_display():
		if not roll_data:
			return
		
		# Context (what the roll was for)
		context_label.text = roll_data.context if roll_data.context != "" else "Roll"
		
		# Dice notation
		dice_label.text = "%dd%s" % [roll_data.dice_count, roll_data.dice_type.substr(1)]
		
		# Result with color coding
		result_label.text = str(roll_data.total)
		_apply_result_color()
		
		# Timestamp (relative)
		var time_diff = Time.get_ticks_msec() / 1000.0 - roll_data.timestamp
		if time_diff < 60:
			timestamp_label.text = "%ds" % time_diff
		elif time_diff < 3600:
			timestamp_label.text = "%dm" % (time_diff / 60)
		else:
			timestamp_label.text = "%dh" % (time_diff / 3600)
		
		# Manual roll indicator
		if roll_data.is_manual:
			modulate = Color(1.0, 1.0, 0.8) # Slight yellow tint
	
	func _apply_result_color():
		var max_possible = _get_max_possible_roll()
		var min_possible = roll_data.dice_count
		
		if roll_data.total >= max_possible:
			result_label.modulate = Color.GREEN # Maximum roll
		elif roll_data.total <= min_possible:
			result_label.modulate = Color.RED # Minimum roll
		elif roll_data.total >= max_possible * 0.8:
			result_label.modulate = Color.LIGHT_GREEN # High roll
		elif roll_data.total <= max_possible * 0.3:
			result_label.modulate = Color.ORANGE # Low roll
		else:
			result_label.modulate = Color.WHITE # Normal roll
	
	func _get_max_possible_roll() -> int:
		match roll_data.dice_type:
			"d6": return 6 * roll_data.dice_count
			"d10": return 10 * roll_data.dice_count
			"d20": return 20 * roll_data.dice_count
			"d100": return 100 * roll_data.dice_count
			"d66": return 66 * roll_data.dice_count
			_: return 6 * roll_data.dice_count

func _ready():
	_setup_ui()
	_setup_connections()
	_setup_auto_hide_timer()
	
	# Position in top-right corner by default
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	position.x -= 20
	position.y += 20

func _setup_ui():
	# Make the feed semi-transparent and non-intrusive
	modulate.a = 0.9
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Setup toggle button
	toggle_button.text = "◀"
	toggle_button.custom_minimum_size = Vector2(30, 30)
	
	# Setup panel
	panel.custom_minimum_size = Vector2(350, 200)

func _setup_connections():
	if toggle_button:
		toggle_button.pressed.connect(_on_toggle_pressed)
	if clear_button:
		clear_button.pressed.connect(_on_clear_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)

func _setup_auto_hide_timer():
	auto_hide_timer = Timer.new()
	auto_hide_timer.wait_time = 10.0 # Auto-hide after 10 seconds
	auto_hide_timer.one_shot = true
	auto_hide_timer.timeout.connect(_on_auto_hide_timeout)
	add_child(auto_hide_timer)

## Connect to the dice system
func set_dice_system(p_dice_system: FPCM_DiceSystem):
	dice_system = p_dice_system
	
	if dice_system:
		dice_system.dice_rolled.connect(_on_dice_rolled)

## Add a new roll to the feed
func add_roll(dice_roll: FPCM_DiceSystem.DiceRoll):
	# Create new roll entry
	var roll_entry = RollEntry.new()
	roll_entry.set_roll_data(dice_roll)
	
	# Add to beginning of list
	roll_entries.insert(0, roll_entry)
	feed_container.add_child(roll_entry)
	feed_container.move_child(roll_entry, 1) # After header
	
	# Remove excess entries
	while roll_entries.size() > max_visible_rolls:
		var old_entry = roll_entries.pop_back()
		if is_instance_valid(old_entry):
			old_entry.queue_free()
	
	# Show feed and reset auto-hide timer
	_show_feed()
	auto_hide_timer.start()
	
	# Animate new entry
	_animate_new_entry(roll_entry)

## Animate a new entry appearing
func _animate_new_entry(entry: Control):
	entry.modulate.a = 0.0
	entry.scale = Vector2(0.8, 0.8)
	
	var tween = create_tween()
	tween.parallel().tween_property(entry, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(entry, "scale", Vector2(1.0, 1.0), 0.3)

## Show the feed
func _show_feed():
	if not is_expanded:
		_toggle_feed()

## Toggle feed visibility
func _toggle_feed():
	is_expanded = !is_expanded
	
	var tween = create_tween()
	if is_expanded:
		toggle_button.text = "◀"
		tween.tween_property(panel, "modulate:a", 1.0, 0.3)
		panel.visible = true
	else:
		toggle_button.text = "▶"
		tween.tween_property(panel, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func(): panel.visible = false)

## Clear all roll entries
func clear_feed():
	for entry in roll_entries:
		if is_instance_valid(entry):
			entry.queue_free()
	roll_entries.clear()

## Update timestamps periodically
func _on_timer_timeout():
	for entry in roll_entries:
		if entry is RollEntry and is_instance_valid(entry):
			entry._update_display()

## Handle dice system events
func _on_dice_rolled(dice_roll: FPCM_DiceSystem.DiceRoll):
	add_roll(dice_roll)

## Handle UI events
func _on_toggle_pressed():
	_toggle_feed()

func _on_clear_pressed():
	clear_feed()

func _on_settings_pressed():
	# TODO: Show dice settings
	print("Dice Feed Settings - TODO: Implement")

func _on_auto_hide_timeout():
	if is_expanded:
		_toggle_feed()

## Public interface for configuration
func set_max_visible_rolls(count: int):
	max_visible_rolls = count

func set_auto_hide_time(seconds: float):
	auto_hide_timer.wait_time = seconds

func set_position_preset(preset: Control.LayoutPreset):
	set_anchors_and_offsets_preset(preset)

## Save/load feed settings
func get_feed_settings() -> Dictionary:
	return {
		"max_visible_rolls": max_visible_rolls,
		"auto_hide_time": auto_hide_timer.wait_time,
		"is_expanded": is_expanded,
		"position": position,
		"modulate_alpha": modulate.a
	}

func apply_feed_settings(settings: Dictionary):
	max_visible_rolls = settings.get("max_visible_rolls", 5)
	auto_hide_timer.wait_time = settings.get("auto_hide_time", 10.0)
	is_expanded = settings.get("is_expanded", true)
	position = settings.get("position", position)
	modulate.a = settings.get("modulate_alpha", 0.9)
	
	if not is_expanded:
		panel.visible = false
		toggle_button.text = "▶"