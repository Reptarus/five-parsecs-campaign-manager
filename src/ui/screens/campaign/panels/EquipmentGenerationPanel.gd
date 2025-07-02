extends Control

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal equipment_generated(equipment: Array[Dictionary])

@onready var equipment_list: VBoxContainer = $"Content/EquipmentList/Container"
@onready var generate_button: Button = $"Content/Controls/GenerateButton"
@onready var reroll_button: Button = $"Content/Controls/RerollButton"
@onready var summary_label: Label = $"Content/Summary/Label"

var generated_equipment: Array[Dictionary] = []
var crew_size: int = 6

func _ready() -> void:
	_connect_signals()
	_generate_starting_equipment()

func _connect_signals() -> void:
	if generate_button:
		generate_button.pressed.connect(_on_generate_pressed)
	if reroll_button:
		reroll_button.pressed.connect(_on_reroll_pressed)

func set_crew_size(size: int) -> void:
	crew_size = size
	_generate_starting_equipment()

func _on_generate_pressed() -> void:
	_generate_starting_equipment()

func _on_reroll_pressed() -> void:
	_generate_starting_equipment()

func _generate_starting_equipment() -> void:
	"""Generate starting equipment following Five Parsecs rules (Core Rules pp. 1747-1829)"""
	generated_equipment.clear()
	
	# Core starting equipment per rules:
	# - 3 rolls on Military Weapon Table
	# - 3 rolls on Low-tech Weapon Table  
	# - 1 roll on Gear Table
	# - 1 roll on Gadget Table
	# - 1 credit per crew member
	
	print("Generating starting equipment for crew of ", crew_size)
	
	# Generate Military Weapons (3 rolls)
	for i in range(3):
		var weapon = _roll_military_weapon()
		generated_equipment.append(weapon)
	
	# Generate Low-tech Weapons (3 rolls)
	for i in range(3):
		var weapon = _roll_low_tech_weapon()
		generated_equipment.append(weapon)
	
	# Generate Gear (1 roll)
	var gear = _roll_gear()
	generated_equipment.append(gear)
	
	# Generate Gadget (1 roll)
	var gadget = _roll_gadget()
	generated_equipment.append(gadget)
	
	_update_equipment_display()
	equipment_generated.emit(generated_equipment)

func _roll_military_weapon() -> Dictionary:
	"""Roll on Military Weapon Table (Core Rules pp. 1778-1787)"""
	var roll = randi_range(1, 100)
	var weapon = {"category": "military_weapon", "type": "weapon"}
	
	if roll <= 25:
		weapon.name = "Military Rifle"
		weapon.range = 24
		weapon.shots = 1
		weapon.damage = 1
		weapon.traits = ["Military"]
	elif roll <= 45:
		weapon.name = "Infantry Laser"
		weapon.range = 24
		weapon.shots = 1
		weapon.damage = 1
		weapon.traits = ["Military", "Energy"]
	elif roll <= 50:
		weapon.name = "Marksman's Rifle"
		weapon.range = 30
		weapon.shots = 1
		weapon.damage = 1
		weapon.traits = ["Military", "Precise"]
	elif roll <= 60:
		weapon.name = "Needle Rifle"
		weapon.range = 18
		weapon.shots = 1
		weapon.damage = 1
		weapon.traits = ["Military", "Piercing"]
	elif roll <= 75:
		weapon.name = "Auto Rifle"
		weapon.range = 24
		weapon.shots = 2
		weapon.damage = 1
		weapon.traits = ["Military", "Auto"]
	elif roll <= 80:
		weapon.name = "Rattle Gun"
		weapon.range = 12
		weapon.shots = 3
		weapon.damage = 1
		weapon.traits = ["Military", "Suppressive"]
	elif roll <= 95:
		weapon.name = "Boarding Saber"
		weapon.range = 0
		weapon.shots = 1
		weapon.damage = 1
		weapon.traits = ["Military", "Melee", "Blade"]
	else: # 96-100
		weapon.name = "Shatter Axe"
		weapon.range = 0
		weapon.shots = 1
		weapon.damage = 2
		weapon.traits = ["Military", "Melee", "Brutal"]
	
	return weapon

func _roll_low_tech_weapon() -> Dictionary:
	"""Roll on Low-tech Weapon Table (Core Rules pp. 1765-1776)"""
	var roll = randi_range(1, 100)
	var weapon = {"category": "low_tech_weapon", "type": "weapon"}
	
	if roll <= 15:
		weapon.name = "Handgun"
		weapon.range = 12
		weapon.shots = 1
		weapon.damage = 1
		weapon.traits = ["Pistol"]
	elif roll <= 35:
		weapon.name = "Scrap Pistol"
		weapon.range = 8
		weapon.shots = 1
		weapon.damage = 1
		weapon.traits = ["Pistol", "Unreliable"]
	elif roll <= 40:
		weapon.name = "Machine Pistol"
		weapon.range = 8
		weapon.shots = 2
		weapon.damage = 1
		weapon.traits = ["Pistol", "Auto"]
	elif roll <= 65:
		weapon.name = "Colony Rifle"
		weapon.range = 20
		weapon.shots = 1
		weapon.damage = 1
		weapon.traits = ["Rifle"]
	elif roll <= 75:
		weapon.name = "Shotgun"
		weapon.range = 12
		weapon.shots = 1
		weapon.damage = 2
		weapon.traits = ["Shotgun", "Close Range"]
	elif roll <= 80:
		weapon.name = "Hunting Rifle"
		weapon.range = 30
		weapon.shots = 1
		weapon.damage = 1
		weapon.traits = ["Rifle", "Precise"]
	elif roll <= 95:
		weapon.name = "Blade"
		weapon.range = 0
		weapon.shots = 1
		weapon.damage = 1
		weapon.traits = ["Melee", "Blade"]
	else: # 96-100
		weapon.name = "Brutal Melee Weapon"
		weapon.range = 0
		weapon.shots = 1
		weapon.damage = 2
		weapon.traits = ["Melee", "Brutal"]
	
	return weapon

func _roll_gear() -> Dictionary:
	"""Roll on Gear Table (Core Rules pp. 1808-1829)"""
	var roll = randi_range(1, 100)
	var gear = {"category": "gear", "type": "gear"}
	
	if roll <= 4:
		gear.name = "Assault Blade"
		gear.effect = "Melee weapon upgrade"
		gear.traits = ["Weapon Mod"]
	elif roll <= 10:
		gear.name = "Beam Light"
		gear.effect = "Illumination device"
		gear.traits = ["Utility"]
	elif roll <= 15:
		gear.name = "Bipod"
		gear.effect = "+1 to hit when stationary"
		gear.traits = ["Weapon Mod"]
	elif roll <= 20:
		gear.name = "Booster Pills"
		gear.effect = "Temporary stat bonus"
		gear.traits = ["Consumable"]
	elif roll <= 24:
		gear.name = "Camo Cloak"
		gear.effect = "Stealth bonus"
		gear.traits = ["Armor"]
	elif roll <= 28:
		gear.name = "Combat Armor"
		gear.effect = "5+ Armor Save"
		gear.traits = ["Armor", "Heavy"]
	elif roll <= 33:
		gear.name = "Communicator"
		gear.effect = "Long-range communication"
		gear.traits = ["Utility"]
	elif roll <= 37:
		gear.name = "Concealed Blade"
		gear.effect = "Hidden melee weapon"
		gear.traits = ["Weapon", "Concealed"]
	elif roll <= 42:
		gear.name = "Fake ID"
		gear.effect = "Identity concealment"
		gear.traits = ["Utility"]
	elif roll <= 46:
		gear.name = "Fixer"
		gear.effect = "Repair equipment"
		gear.traits = ["Utility"]
	elif roll <= 52:
		gear.name = "Frag Vest"
		gear.effect = "6+ Armor Save"
		gear.traits = ["Armor"]
	elif roll <= 57:
		gear.name = "Grapple Launcher"
		gear.effect = "Climbing and mobility"
		gear.traits = ["Utility"]
	elif roll <= 61:
		gear.name = "Hazard Suit"
		gear.effect = "Environmental protection"
		gear.traits = ["Armor", "Environmental"]
	elif roll <= 65:
		gear.name = "Laser Sight"
		gear.effect = "+1 to hit with ranged weapons"
		gear.traits = ["Weapon Mod"]
	elif roll <= 69:
		gear.name = "Loaded Dice"
		gear.effect = "Gambling advantage"
		gear.traits = ["Utility"]
	else:
		gear.name = "Med-patch"
		gear.effect = "Healing item"
		gear.traits = ["Medical", "Consumable"]
	
	return gear

func _roll_gadget() -> Dictionary:
	"""Roll on Gadget Table"""
	var roll = randi_range(1, 100)
	var gadget = {"category": "gadget", "type": "gadget"}
	
	if roll <= 20:
		gadget.name = "Scanner"
		gadget.effect = "Detect enemies and objects"
		gadget.traits = ["Tech"]
	elif roll <= 40:
		gadget.name = "Jump Belt"
		gadget.effect = "Enhanced mobility"
		gadget.traits = ["Tech", "Mobility"]
	elif roll <= 60:
		gadget.name = "Shield Generator"
		gadget.effect = "Temporary protection"
		gadget.traits = ["Tech", "Defense"]
	elif roll <= 80:
		gadget.name = "Analyzer"
		gadget.effect = "Information gathering"
		gadget.traits = ["Tech"]
	else:
		gadget.name = "Stim-pack"
		gadget.effect = "Quick healing"
		gadget.traits = ["Medical", "Consumable"]
	
	return gadget

func _update_equipment_display() -> void:
	"""Update the equipment list display"""
	# Clear existing equipment items
	if equipment_list:
		for child in equipment_list.get_children():
			child.queue_free()
		
		# Add new equipment items
		for item in generated_equipment:
			var item_container = HBoxContainer.new()
			
			var name_label = Label.new()
			name_label.text = item.name
			name_label.custom_minimum_size.x = 150
			item_container.add_child(name_label)
			
			var category_label = Label.new()
			category_label.text = "(" + item.category.replace("_", " ").capitalize() + ")"
			category_label.custom_minimum_size.x = 120
			item_container.add_child(category_label)
			
			var traits_label = Label.new()
			if item.has("traits"):
				traits_label.text = ", ".join(item.traits)
			traits_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_container.add_child(traits_label)
			
			equipment_list.add_child(item_container)
	
	# Update summary
	if summary_label:
		var weapon_count = 0
		var gear_count = 0
		var gadget_count = 0
		
		for item in generated_equipment:
			match item.category:
				"military_weapon", "low_tech_weapon":
					weapon_count += 1
				"gear":
					gear_count += 1
				"gadget":
					gadget_count += 1
		
		summary_label.text = "Generated: %d Weapons, %d Gear, %d Gadgets" % [weapon_count, gear_count, gadget_count]

func get_equipment() -> Array[Dictionary]:
	return generated_equipment.duplicate()

func is_valid() -> bool:
	return generated_equipment.size() >= 8  # Should have at least 8 items (3+3+1+1)