class_name DiceTestScene
extends Control

## Test scene for demonstrating the dice system
## Shows both automatic and manual dice rolling options

const FPCM_DiceSystem = preload("res://src/core/systems/DiceSystem.gd")
const FPCM_DiceManager = preload("res://src/core/managers/DiceManager.gd")
const DiceDisplay = preload("res://src/ui/components/dice/DiceDisplay.gd")
const DiceFeed = preload("res://src/ui/components/dice/DiceFeed.gd")

@onready var dice_display: DiceDisplay = $VBoxContainer/DiceDisplay
@onready var dice_feed: DiceFeed = $DiceFeed
@onready var button_container: VBoxContainer = $VBoxContainer/ButtonContainer
@onready var settings_panel: Control = $VBoxContainer/SettingsPanel
@onready var auto_roll_checkbox: CheckBox = $VBoxContainer/SettingsPanel/HBoxContainer/AutoRollCheckBox
@onready var show_animations_checkbox: CheckBox = $VBoxContainer/SettingsPanel/HBoxContainer/ShowAnimationsCheckBox
@onready var results_label: Label = $VBoxContainer/ResultsPanel/ResultsLabel

var dice_manager: FPCM_DiceManager

func _ready():
	_setup_dice_system()
	_create_test_buttons()
	_setup_settings()

func _setup_dice_system():
	# Create dice manager
	dice_manager = FPCM_DiceManager.new()
	
	# Connect dice display
	if dice_display:
		dice_display.set_dice_system(dice_manager.get_dice_system())
		dice_display.manual_roll_completed.connect(_on_manual_roll_completed)
	
	# Connect dice feed
	if dice_feed:
		dice_manager.set_dice_feed(dice_feed)
	
	# Connect signals
	dice_manager.dice_result_ready.connect(_on_dice_result_ready)

func _create_test_buttons():
	if not button_container:
		return
	
	# D6 Tests
	_create_test_button("Roll D6", func(): _test_d6())
	_create_test_button("Roll 2D6", func(): _test_2d6())
	_create_test_button("Roll Attribute (2D6/3)", func(): _test_attribute())
	
	# D10 Tests
	_create_test_button("Roll D10", func(): _test_d10())
	
	# D100 Tests
	_create_test_button("Roll D100", func(): _test_d100())
	_create_test_button("Roll Injury Table", func(): _test_injury())
	
	# D66 Tests
	_create_test_button("Roll D66", func(): _test_d66())
	_create_test_button("Roll Character Background", func(): _test_background())
	
	# Combat Tests
	_create_test_button("Roll Combat Check", func(): _test_combat())
	_create_test_button("Roll Initiative", func(): _test_initiative())
	_create_test_button("Roll Damage (2D6)", func(): _test_damage())
	
	# Mission Tests
	_create_test_button("Roll Mission Type", func(): _test_mission_type())
	_create_test_button("Roll Mission Difficulty", func(): _test_mission_difficulty())
	
	# Multiple Rolls Test
	_create_test_button("Roll 5 D6s", func(): _test_multiple_d6())
	
	# Manual Override Test
	_create_test_button("Force Manual Roll", func(): _test_manual_override())

func _create_test_button(text: String, callback: Callable):
	var button = Button.new()
	button.text = text
	button.pressed.connect(callback)
	button_container.add_child(button)

func _setup_settings():
	if auto_roll_checkbox:
		auto_roll_checkbox.button_pressed = dice_manager.auto_mode
		auto_roll_checkbox.toggled.connect(_on_auto_roll_toggled)
	
	if show_animations_checkbox:
		show_animations_checkbox.button_pressed = dice_manager.get_dice_system().show_animations
		show_animations_checkbox.toggled.connect(_on_show_animations_toggled)

## Test Methods

func _test_d6():
	var result = dice_manager.roll_d6("Test D6 Roll")
	_update_results("D6 Roll: %d" % result)

func _test_2d6():
	var result = dice_manager.roll_2d6("Test 2D6 Roll")
	_update_results("2D6 Roll: %d" % result)

func _test_attribute():
	var result = dice_manager.roll_attribute("Test Attribute Generation")
	_update_results("Attribute (2D6/3): %d" % result)

func _test_d10():
	var result = dice_manager.roll_d10("Test D10 Roll")
	_update_results("D10 Roll: %d" % result)

func _test_d100():
	var result = dice_manager.roll_d100("Test D100 Roll")
	_update_results("D100 Roll: %d" % result)

func _test_injury():
	var result = dice_manager.roll_injury_table("Test Injury Table")
	_update_results("Injury Table: %d" % result)

func _test_d66():
	var result = dice_manager.roll_d66("Test D66 Roll")
	_update_results("D66 Roll: %d" % result)

func _test_background():
	var result = dice_manager.roll_character_background("Test Character Background")
	_update_results("Character Background: %d" % result)

func _test_combat():
	var result = dice_manager.roll_combat_check(1, "Test Combat Check (+1)")
	_update_results("Combat Check (+1): %d" % result)

func _test_initiative():
	var result = dice_manager.roll_initiative("Test Initiative")
	_update_results("Initiative: %d" % result)

func _test_damage():
	var result = dice_manager.roll_damage(2, "Test Damage (2D6)")
	_update_results("Damage (2D6): %d" % result)

func _test_mission_type():
	var result = dice_manager.roll_mission_type("Test Mission Type")
	_update_results("Mission Type: %d" % result)

func _test_mission_difficulty():
	var result = dice_manager.roll_mission_difficulty("Test Mission Difficulty")
	_update_results("Mission Difficulty: %d" % result)

func _test_multiple_d6():
	var results = dice_manager.roll_multiple_d6(5, "Test Multiple D6")
	var results_text = "Multiple D6: " + str(results)
	_update_results(results_text)

func _test_manual_override():
	var result = dice_manager.request_manual_roll(1, 6, "Manual Override Test")
	_update_results("Manual Override Requested")

## Event Handlers

func _on_dice_result_ready(result: int, context: String):
	print("Dice result ready: %d for %s" % [result, context])

func _on_manual_roll_completed(dice_roll: FPCM_DiceSystem.DiceRoll):
	_update_results("Manual Roll Completed: %s" % dice_roll.get_simple_text())

func _on_auto_roll_toggled(button_pressed: bool):
	dice_manager.set_auto_mode(button_pressed)
	_update_results("Auto Roll: %s" % ("Enabled" if button_pressed else "Disabled"))

func _on_show_animations_toggled(button_pressed: bool):
	dice_manager.get_dice_system().show_animations = button_pressed
	_update_results("Animations: %s" % ("Enabled" if button_pressed else "Disabled"))

func _update_results(text: String):
	if results_label:
		results_label.text = text
	print("Dice Test: " + text)

## Demonstration of integration with existing systems
func demonstrate_integration():
	print("\n=== Dice System Integration Demo ===")
	
	# Show how existing random calls can be replaced
	print("Traditional: randi() % 6 + 1")
	print("New: dice_manager.roll_d6('Context')")
	
	# Demonstrate Five Parsecs specific patterns
	var character_background = dice_manager.roll_character_background("Character Creation")
	print("Character Background Roll: %d" % character_background)
	
	var mission_difficulty = dice_manager.roll_mission_difficulty("Mission Generation")
	print("Mission Difficulty: %d" % mission_difficulty)
	
	var injury_result = dice_manager.roll_injury_table("Post-Battle Injury")
	print("Injury Table Result: %d" % injury_result)
	
	# Show statistics
	var stats = dice_manager.get_roll_statistics(FPCM_DiceSystem.DicePattern.D6)
	print("D6 Statistics: %s" % str(stats))
	
	print("=== Demo Complete ===\n")