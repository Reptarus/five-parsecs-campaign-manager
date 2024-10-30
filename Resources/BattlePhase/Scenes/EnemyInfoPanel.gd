extends PanelContainer

@onready var encounter_label = %EncounterLabel
@onready var weapons_label = %WeaponsLabel
@onready var notable_sights_label = %NotableSightsLabel
@onready var mission_objective_label = %MissionObjectiveLabel

func setup(mission_data: Dictionary) -> void:
	# Set encounter information
	var encounter_text = "Encounter:"
	for enemy in mission_data.enemies:
		encounter_text += "\n%dx %s" % [enemy.count, enemy.name]
	encounter_label.text = encounter_text
	
	# Set weapons information
	var weapons_text = "Weapons:"
	for weapon in mission_data.enemy_weapons:
		weapons_text += "\n%dx %s" % [weapon.count, weapon.name]
	weapons_label.text = weapons_text
	
	# Set notable sights
	if mission_data.notable_sight:
		notable_sights_label.text = "Notable Sight: %s" % mission_data.notable_sight
	else:
		notable_sights_label.text = "Notable Sight: None"
	
	# Set mission objective
	var objective_text = "Mission Objective: %s\n%s" % [
		mission_data.objective_name,
		mission_data.objective_description
	]
	mission_objective_label.text = objective_text
