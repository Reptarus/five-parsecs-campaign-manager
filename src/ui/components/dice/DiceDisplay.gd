class_name DiceDisplay
extends Control

## Visual dice display component with animations and manual input
## Provides real-time visual feedback for dice rolls

const FPCM_DiceSystem = preload("res://src/core/systems/DiceSystem.gd")

signal manual_roll_completed(dice_roll: FPCM_DiceSystem.DiceRoll)
signal dice_animation_finished()

@onready var dice_container: HBoxContainer = $VBoxContainer/DiceContainer
@onready var roll_result_label: Label = $VBoxContainer/ResultPanel/RollResultLabel
@onready var context_label: Label = $VBoxContainer/ContextLabel
@onready var manual_input_panel: Control = $VBoxContainer/ManualInputPanel
@onready var manual_input_container: HBoxContainer = $VBoxContainer/ManualInputPanel/HBoxContainer
@onready var manual_confirm_button: Button = $VBoxContainer/ManualInputPanel/HBoxContainer/ConfirmButton
@onready var auto_roll_button: Button = $VBoxContainer/ManualInputPanel/HBoxContainer/AutoRollButton
@onready var history_button: Button = $VBoxContainer/ButtonsPanel/HistoryButton
@onready var settings_button: Button = $VBoxContainer/ButtonsPanel/SettingsButton
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var dice_system: FPCM_DiceSystem
var current_dice_roll: FPCM_DiceSystem.DiceRoll
var dice_scenes: Array[Control] = []
var manual_input_spinboxes: Array[SpinBox] = []

## Individual dice visual component
class DiceVisual extends Control:
	var dice_value: int = 1
	var dice_type: String = "d6"
	var is_rolling: bool = false
	
	@onready var dice_face: Label = $DiceFace
	@onready var animation_player: AnimationPlayer = $AnimationPlayer
	
	func _ready():
		custom_minimum_size = Vector2(60, 60)
		_update_display()
	
	func set_value(value: int):
		dice_value = value
		_update_display()
	
	func set_type(type: String):
		dice_type = type
		_update_display()
	
	func start_roll_animation():
		is_rolling = true
		if animation_player:
			animation_player.play("roll_animation")
	
	func stop_roll_animation():
		is_rolling = false
		if animation_player:
			animation_player.stop()
		_update_display()
	
	func _update_display():
		if not dice_face:
			return
			
		dice_face.text = str(dice_value)
		
		# Style based on dice type
		match dice_type:
			"d6":
				modulate = Color.WHITE
			"d10":
				modulate = Color.LIGHT_BLUE
			"d20":
				modulate = Color.LIGHT_GREEN
			"d100":
				modulate = Color.ORANGE
			"d66":
				modulate = Color.PINK
			_:
				modulate = Color.WHITE

func _ready():
	_setup_connections()
	manual_input_panel.visible = false
	
	# Connect to dice system if available
	if not dice_system:
		dice_system = FPCM_DiceSystem.new()

func _setup_connections():
	if manual_confirm_button:
		manual_confirm_button.pressed.connect(_on_manual_confirm_pressed)
	if auto_roll_button:
		auto_roll_button.pressed.connect(_on_auto_roll_pressed)
	if history_button:
		history_button.pressed.connect(_on_history_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)

## Display a dice roll with visual feedback
func display_dice_roll(dice_roll: FPCM_DiceSystem.DiceRoll, show_manual_option: bool = true):
	current_dice_roll = dice_roll
	
	# Update context
	if context_label:
		context_label.text = dice_roll.context if dice_roll.context != "" else "Dice Roll"
	
	# Clear previous dice
	_clear_dice_display()
	
	# Check if this is a manual input request
	if dice_roll.individual_rolls.is_empty() and show_manual_option:
		_show_manual_input_panel()
	else:
		_show_automatic_result()

## Show the result of an automatic dice roll
func _show_automatic_result():
	manual_input_panel.visible = false
	
	# Create visual dice for each roll
	for i in range(current_dice_roll.individual_rolls.size()):
		var dice_visual = _create_dice_visual(current_dice_roll.dice_type)
		dice_visual.set_value(current_dice_roll.individual_rolls[i])
		dice_scenes.append(dice_visual)
		dice_container.add_child(dice_visual)
	
	# Show result
	_update_result_display()
	
	# Play animation if enabled
	if dice_system.show_animations:
		_play_roll_animation()

## Show manual input panel for player to enter their own rolls
func _show_manual_input_panel():
	manual_input_panel.visible = true
	manual_input_spinboxes.clear()
	
	# Clear any existing manual input controls
	for child in manual_input_container.get_children():
		if child is SpinBox:
			child.queue_free()
	
	# Create input controls for each die
	for i in range(current_dice_roll.dice_count):
		var spinbox = SpinBox.new()
		spinbox.min_value = 1
		
		# Set max value based on dice type
		match current_dice_roll.dice_type:
			"d6":
				spinbox.max_value = 6
			"d10":
				spinbox.max_value = 10
			"d20":
				spinbox.max_value = 20
			"d100":
				spinbox.max_value = 100
			"d66":
				spinbox.min_value = 11
				spinbox.max_value = 66
			_:
				spinbox.max_value = 6
		
		spinbox.value = spinbox.min_value
		spinbox.custom_minimum_size = Vector2(80, 30)
		
		manual_input_spinboxes.append(spinbox)
		manual_input_container.add_child(spinbox)
		
		# Move buttons to end
		manual_input_container.move_child(manual_confirm_button, -1)
		manual_input_container.move_child(auto_roll_button, -1)

## Create a visual dice component
func _create_dice_visual(dice_type: String) -> DiceVisual:
	var dice_visual = DiceVisual.new()
	dice_visual.set_type(dice_type)
	return dice_visual

## Play rolling animation
func _play_roll_animation():
	for dice_visual in dice_scenes:
		if dice_visual is DiceVisual:
			dice_visual.start_roll_animation()
	
	# Simulate rolling animation
	var tween = create_tween()
	var animation_duration = 1.0 / dice_system.animation_speed
	
	# Random number animation
	for step in range(10):
		tween.tween_callback(_animate_random_numbers).set_delay(animation_duration / 10.0)
	
	# Final result
	tween.tween_callback(_show_final_result).set_delay(animation_duration / 10.0)

## Animate random numbers during rolling
func _animate_random_numbers():
	for i in range(dice_scenes.size()):
		if i < dice_scenes.size() and dice_scenes[i] is DiceVisual:
			var random_value = randi() % _get_max_value_for_type(current_dice_roll.dice_type) + 1
			dice_scenes[i].set_value(random_value)

## Show final dice result
func _show_final_result():
	for i in range(dice_scenes.size()):
		if i < dice_scenes.size() and dice_scenes[i] is DiceVisual:
			dice_scenes[i].stop_roll_animation()
			if i < current_dice_roll.individual_rolls.size():
				dice_scenes[i].set_value(current_dice_roll.individual_rolls[i])
	
	dice_animation_finished.emit()

## Get maximum value for dice type
func _get_max_value_for_type(dice_type: String) -> int:
	match dice_type:
		"d6": return 6
		"d10": return 10
		"d20": return 20
		"d100": return 100
		"d66": return 66
		_: return 6

## Update the result display
func _update_result_display():
	if not roll_result_label or not current_dice_roll:
		return
	
	roll_result_label.text = current_dice_roll.get_display_text()
	
	# Color coding based on result
	if current_dice_roll.total >= _get_max_value_for_type(current_dice_roll.dice_type) * current_dice_roll.dice_count:
		roll_result_label.modulate = Color.GREEN # Maximum roll
	elif current_dice_roll.total <= current_dice_roll.dice_count:
		roll_result_label.modulate = Color.RED # Minimum roll
	else:
		roll_result_label.modulate = Color.WHITE # Normal roll

## Clear the dice display
func _clear_dice_display():
	for dice_visual in dice_scenes:
		if is_instance_valid(dice_visual):
			dice_visual.queue_free()
	dice_scenes.clear()

## Handle manual input confirmation
func _on_manual_confirm_pressed():
	if manual_input_spinboxes.is_empty():
		return
	
	var manual_rolls: Array[int] = []
	for spinbox in manual_input_spinboxes:
		manual_rolls.append(int(spinbox.value))
	
	# Validate d66 rolls
	if current_dice_roll.dice_type == "d66":
		for i in range(manual_rolls.size()):
			var roll = manual_rolls[i]
			var tens = roll / 10
			var ones = roll % 10
			if tens < 1 or tens > 6 or ones < 1 or ones > 6:
				# Invalid d66 roll, fix it
				manual_rolls[i] = 11 # Default to minimum valid d66
	
	# Apply manual input to dice roll
	dice_system.input_manual_result(current_dice_roll, manual_rolls)
	
	# Update display
	manual_input_panel.visible = false
	_show_automatic_result()
	
	manual_roll_completed.emit(current_dice_roll)

## Handle auto roll button
func _on_auto_roll_pressed():
	if not current_dice_roll:
		return
	
	# Execute automatic roll
	dice_system._execute_dice_roll(current_dice_roll)
	
	# Update display
	manual_input_panel.visible = false
	_show_automatic_result()

## Show roll history
func _on_history_pressed():
	var history_text = dice_system.get_roll_history_text(20)
	# TODO: Show in a popup dialog
	print("Dice Roll History:\n" + history_text)

## Show dice settings
func _on_settings_pressed():
	# TODO: Show settings dialog
	print("Dice Settings - TODO: Implement settings dialog")

## Set the dice system reference
func set_dice_system(p_dice_system: FPCM_DiceSystem):
	dice_system = p_dice_system
	
	# Connect signals
	if dice_system:
		dice_system.dice_rolled.connect(_on_dice_rolled)
		dice_system.manual_input_requested.connect(_on_manual_input_requested)
		dice_system.dice_animation_started.connect(_on_dice_animation_started)

## Handle dice system signals
func _on_dice_rolled(dice_roll: FPCM_DiceSystem.DiceRoll):
	display_dice_roll(dice_roll, false)

func _on_manual_input_requested(dice_roll: FPCM_DiceSystem.DiceRoll):
	display_dice_roll(dice_roll, true)

func _on_dice_animation_started(dice_count: int, dice_type: String):
	# Prepare for animation
	pass