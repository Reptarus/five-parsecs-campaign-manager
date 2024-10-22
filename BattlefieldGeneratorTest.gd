extends Node

var mock_game_state: MockGameState

func _ready():
	mock_game_state = preload("res://Resources/MockGameState.tres")
	
	var battlefield_generator = get_parent()
	if battlefield_generator.has_method("initialize"):
		battlefield_generator.initialize(mock_game_state)

	print("Mission generated: ", mock_game_state.game_state.current_mission != null)

	if battlefield_generator.has_method("_generate_battlefield"):
		battlefield_generator._generate_battlefield()
		print("Battlefield generated")

	if battlefield_generator.has_method("_generate_battlefield_grid"):
		battlefield_generator._generate_battlefield_grid()
		print("Battlefield grid generated")

	_display_mission_data()
	_generate_suggested_layout()

func _display_mission_data():
	var mission = mock_game_state.game_state.current_mission
	print("\nMission Data:")
	print("Title: ", mission.title)
	print("Objective: ", GlobalEnums.MissionObjective.keys()[mission.objective])
	print("Environmental Factors: ", mission.environmental_factors)
	print("Enemies: ", mission.get_enemies())

func _generate_suggested_layout():
	print("\nSuggested Industrial Battlefield Layout:")
	var layout = [
		["W", "C", "M", "F"],
		["S", "L", "R", "B"],
		["P", "T", "E", "D"]
	]
	var legend = {
		"W": "Warehouse",
		"C": "Cargo Area",
		"M": "Manufacturing Plant",
		"F": "Fuel Storage",
		"S": "Storage Silos",
		"L": "Loading Dock",
		"R": "Repair Bay",
		"B": "Barracks",
		"P": "Power Plant",
		"T": "Transit Hub",
		"E": "Equipment Yard",
		"D": "Disposal Area"
	}
	
	for row in layout:
		var row_str = ""
		for cell in row:
			row_str += cell + " | "
		print(row_str)
	
	print("\nLegend:")
	for key in legend:
		print(key, ": ", legend[key])

	print("\nRemember to add scatter terrain like crates, barrels, and industrial equipment throughout the battlefield.")
