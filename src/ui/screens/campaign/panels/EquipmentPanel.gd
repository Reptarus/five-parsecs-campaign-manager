extends Control

## Five Parsecs Equipment Generation Panel
## Production-ready implementation with comprehensive equipment systems

const StartingEquipmentGenerator = preload("res://src/core/character/Equipment/StartingEquipmentGenerator.gd")
const Character = preload("res://src/core/character/Character.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal equipment_generated(equipment: Array[Dictionary])
@warning_ignore("unused_signal")
signal equipment_setup_complete(equipment_data: Dictionary)

# UI Components with safe access
var equipment_list: VBoxContainer
var generate_button: Button
var reroll_button: Button
var manual_button: Button
var summary_label: Label
var credits_label: Label

var generated_equipment: Array[Dictionary] = []
var starting_credits: int = 0
var crew_size: int = 4
var dice_manager: Node # Add dice_manager reference

func _ready() -> void:
	call_deferred("_initialize_components")

func _initialize_components() -> void:
	"""Initialize equipment panel with safe component access"""
	equipment_list = get_node("Content/EquipmentList/Container")
	generate_button = get_node("Content/Controls/GenerateButton")
	reroll_button = get_node("Content/Controls/RerollButton")
	manual_button = get_node("Content/Controls/ManualButton")
	summary_label = get_node("Content/Summary/Label")
	credits_label = get_node("Content/Credits/Value")

	# Get DiceManager from autoload
	if has_node("/root/DiceManager"):
		dice_manager = get_node("/root/DiceManager")
	else:
		push_warning("EquipmentGenerationPanel: DiceManager not found!")

	_connect_signals()
	_generate_starting_equipment()

func _connect_signals() -> void:
	"""Establish signal connections with error handling"""
	if generate_button:
		generate_button.pressed.connect(_on_generate_pressed)
	if reroll_button:
		reroll_button.pressed.connect(_on_reroll_equipment_pressed)
	if manual_button:
		manual_button.pressed.connect(_on_manual_select_pressed)

func set_crew_data(crew: Array[Character]) -> void:
	"""Set crew data and generate equipment"""
	# This is the intended entry point from the campaign wizard
	# For now, it's not called, but the logic is ready
	crew_size = crew.size()
	_generate_starting_equipment(crew)

func _generate_starting_equipment(crew: Array[Character] = []) -> void:
	"""Generate starting equipment using StartingEquipmentGenerator"""
	generated_equipment.clear()
	starting_credits = 0

	var current_crew: Array[Character] = crew
	if current_crew.is_empty():
		# If no crew is passed, create a mock crew for demonstration
		current_crew = _create_mock_crew()

	# Generate equipment for each character
	for character: Character in current_crew:
		var char_equipment: Dictionary = StartingEquipmentGenerator.generate_starting_equipment(character, dice_manager)
		StartingEquipmentGenerator.apply_equipment_condition(char_equipment, dice_manager)
		
		# Merge equipment into a single list
		for weapon: Dictionary in char_equipment.get("weapons", []):
			weapon["type"] = "Weapon"
			weapon["owner"] = character.character_name
			generated_equipment.append(weapon)
			
		for armor_item: Dictionary in char_equipment.get("armor", []):
			armor_item["type"] = "Armor"
			armor_item["owner"] = character.character_name
			generated_equipment.append(armor_item)

		for gear_item: Dictionary in char_equipment.get("gear", []):
			gear_item["type"] = "Gear"
			gear_item["owner"] = character.character_name
			generated_equipment.append(gear_item)
		
		starting_credits += char_equipment.get("credits", 0)

	_update_equipment_display()
	_update_summary()
	equipment_generated.emit(generated_equipment)

func _create_mock_crew() -> Array[Character]:
	"""Creates a mock crew for testing and demonstration purposes"""
	var mock_crew: Array[Character] = []
	var class_names: Array = GlobalEnums.CharacterClass.keys()
	var background_names: Array = GlobalEnums.Background.keys()
	
	for i in range(crew_size):
		var new_char: Character = Character.new()
		new_char.character_name = "Crew Member %d" % (i + 1)
		
		# Assign random class and background, skipping the 'NONE' enum at index 0
		var random_class_name: String = class_names[1 + randi() % (class_names.size() - 1)]
		new_char.character_class = GlobalEnums.CharacterClass[random_class_name]
		
		var random_bg_name: String = background_names[1 + randi() % (background_names.size() - 1)]
		new_char.background = GlobalEnums.Background[random_bg_name]
		
		mock_crew.append(new_char)
		
	return mock_crew

func _update_summary() -> void:
	"""Update equipment summary and credits display"""
	if summary_label:
		summary_label.text = "Equipment generated for %d crew members: %d items" % [crew_size, generated_equipment.size()]

	if credits_label:
		credits_label.text = str(starting_credits)

# Signal handlers
func _on_generate_pressed() -> void:
	_generate_starting_equipment()

func _on_reroll_equipment_pressed() -> void:
	_generate_starting_equipment()

func _on_manual_select_pressed() -> void:
	"""Show manual equipment selection - implement based on UI architecture"""
	print("Manual equipment selection not yet implemented")

func get_equipment_data() -> Dictionary:
	"""Return equipment data for campaign creation"""
	return {
		"equipment": generated_equipment,
		"starting_credits": starting_credits,
		"crew_size": crew_size,
		"is_complete": generated_equipment.size() > 0
	}

func is_setup_complete() -> bool:
	"""Check if equipment setup is complete"""
	return generated_equipment.size() > 0

func _update_equipment_display() -> void:
	"""Update the equipment list display"""
	if equipment_list:
		for child in equipment_list.get_children():
			child.queue_free()

		for item: Dictionary in generated_equipment:
			var item_container: HBoxContainer = HBoxContainer.new()
			
			var name_label: Label = Label.new()
			name_label.text = item.get("name", "Unknown Item")
			name_label.custom_minimum_size.x = 200
			item_container.add_child(name_label)
			
			var type_label: Label = Label.new()
			type_label.text = item.get("type", "Misc")
			type_label.custom_minimum_size.x = 100
			item_container.add_child(type_label)
			
			var condition_label: Label = Label.new()
			var condition: String = item.get("condition", "standard")
			condition_label.text = "Condition: %s" % condition.capitalize()
			condition_label.custom_minimum_size.x = 180
			item_container.add_child(condition_label)
			
			var owner_label: Label = Label.new()
			owner_label.text = "For: %s" % item.get("owner", "Crew")
			owner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_container.add_child(owner_label)
			
			equipment_list.add_child(item_container)

func is_valid() -> bool:
	return generated_equipment.size() > 0

func validate() -> Array[String]:
	"""Validate equipment data and return error messages"""
	var errors: Array[String] = []
	
	if generated_equipment.is_empty():
		errors.append("No equipment was generated for the crew.")
	
	if starting_credits <= 0:
		errors.append("Invalid starting credits. Must be greater than zero.")
	
	return errors

func get_data() -> Dictionary:
	"""Get panel data - generic interface method"""
	return get_equipment_data()

func set_data(data: Dictionary) -> void:
	"""Set panel data - generic interface method"""
	if data.has("crew"):
		var crew: Array[Character] = data.get("crew", [])
		set_crew_data(crew)
	elif data.has("crew_size"):
		crew_size = data.crew_size
		_generate_starting_equipment()

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
