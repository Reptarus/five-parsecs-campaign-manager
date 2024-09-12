extends Node2D

var game_manager

func initialize(manager):
	game_manager = manager
	# Rest of your initialization code...

const GRID_SIZE = Vector2i(24, 24)
enum TerrainType { INDUSTRIAL, WILDERNESS, ALIEN_RUIN, CRASH_SITE }

var current_terrain_type: TerrainType
var battlefield: Array
var center_feature: Dictionary
var quarters: Array
var deployment_condition: Dictionary
var notable_sight: Dictionary

@onready var grid_container = $GridContainer
@onready var terrain_type_option = $UI/TerrainTypeOption
@onready var generate_button = $UI/GenerateButton
@onready var save_button = $UI/SaveButton
@onready var load_button = $UI/LoadButton
@onready var terrain_suggestions = $UI/TerrainSuggestions

func _ready():
	initialize_ui()
	generate_battlefield()

func initialize_ui():
	terrain_type_option.add_item("Industrial", TerrainType.INDUSTRIAL)
	terrain_type_option.add_item("Wilderness", TerrainType.WILDERNESS)
	terrain_type_option.add_item("Alien Ruin", TerrainType.ALIEN_RUIN)
	terrain_type_option.add_item("Crash Site", TerrainType.CRASH_SITE)
	generate_button.connect("pressed", generate_battlefield)
	save_button.connect("pressed", save_battlefield)
	load_button.connect("pressed", load_battlefield)

func generate_battlefield():
	current_terrain_type = terrain_type_option.get_selected_id() as TerrainType
	battlefield = []
	_initialize_grid()
	_generate_center_feature()
	_generate_quarters()
	_generate_deployment_condition()
	_generate_notable_sight()
	update_battlefield_display()
	update_terrain_suggestions()

func _initialize_grid():
	for x in range(GRID_SIZE.x):
		battlefield.append([])
		for y in range(GRID_SIZE.y):
			battlefield[x].append(".")

func _generate_center_feature():
	center_feature = {
		"type": _roll_notable_feature(),
		"position": Vector2i(int(GRID_SIZE.x / 2), int(GRID_SIZE.y / 2))
	}
	_apply_feature_to_grid(center_feature)

func _generate_quarters():
	quarters = []
	for q in range(4):
		var quarter = {
			"features": [],
			"scatter_terrain": []
		}
		for i in range(4):
			quarter.features.append(_roll_regular_feature())
		var scatter_count = randi() % 6 + 1
		for i in range(scatter_count):
			quarter.scatter_terrain.append(_generate_scatter_terrain())
		quarters.append(quarter)
	_apply_quarters_to_grid()

func _generate_deployment_condition():
	var conditions = [
		{"name": "Standard Deployment", "effect": "No special effect"},
		{"name": "Scattered Forces", "effect": "Deploy anywhere on your table edge"},
		{"name": "Flanking Maneuver", "effect": "Deploy on two adjacent table edges"},
		{"name": "Infiltration", "effect": "Deploy anywhere, but at least 6\" from enemies"},
		{"name": "Delayed Reinforcements", "effect": "Half your crew (rounded up) deploys normally, the rest arrive on turn 2"},
		{"name": "Surrounded", "effect": "Enemy deploys first, then you deploy anywhere 6\" from table edge"}
	]
	deployment_condition = conditions[randi() % conditions.size()]

func _generate_notable_sight():
	var sights = [
		{"name": "Ominous Sky", "effect": "-1 to all Reaction rolls"},
		{"name": "Eerie Calm", "effect": "+1 to all Morale checks"},
		{"name": "Strange Readings", "effect": "Reroll 1 failed Reaction roll per turn"},
		{"name": "Hostile Environment", "effect": "-1 to all Combat Skill rolls"},
		{"name": "Inspiring Vista", "effect": "+1 to all Combat Skill rolls"},
		{"name": "Treacherous Ground", "effect": "-1\" to all movement"}
	]
	notable_sight = sights[randi() % sights.size()]

func _roll_notable_feature():
	var table = _get_notable_feature_table()
	return table[randi() % table.size()]

func _roll_regular_feature():
	var table = _get_regular_feature_table()
	return table[randi() % table.size()]

func _generate_scatter_terrain():
	var scatter_types = ["Fuel Barrel", "Crate", "Rock", "Rubble", "Tree"]
	return scatter_types[randi() % scatter_types.size()]

func _apply_feature_to_grid(feature):
	var symbol = _get_feature_symbol(feature.type)
	battlefield[feature.position.x][feature.position.y] = symbol

func _apply_quarters_to_grid():
	var quarter_size = Vector2i(int(GRID_SIZE.x / 2), int(GRID_SIZE.y / 2))
	for q in range(4):
		var start_x = int(q % 2) * quarter_size.x
		var start_y = int(q / 2) * quarter_size.y
		for feature in quarters[q].features:
			var feature_pos = Vector2i(
				randi() % quarter_size.x + start_x,
				randi() % quarter_size.y + start_y
			)
			_apply_feature_to_grid({"type": feature, "position": feature_pos})
		for scatter in quarters[q].scatter_terrain:
			var scatter_pos = Vector2i(
				randi() % quarter_size.x + start_x,
				randi() % quarter_size.y + start_y
			)
			battlefield[scatter_pos.x][scatter_pos.y] = "S"

func _get_feature_symbol(feature_type: String) -> String:
	return feature_type[0].to_upper()

func _get_notable_feature_table():
	match current_terrain_type:
		TerrainType.INDUSTRIAL:
			return ["Large structure", "Industrial cluster", "Fenced area", "Landing pad", "Cargo area", "Large structure"]
		TerrainType.WILDERNESS:
			return ["Forested hill", "Swamp", "Rock formations", "Forested area", "Large hill", "Single building"]
		TerrainType.ALIEN_RUIN:
			return ["Overgrown area", "Large debris", "Ruined building", "Overgrown plaza", "Ruined tower", "Large statue"]
		TerrainType.CRASH_SITE:
			return ["Damaged structure", "Natural features with wreckage", "Burning forest", "Wreckage pile", "Large wreckage in crater", "Large crater"]
	return []

func _get_regular_feature_table():
	match current_terrain_type:
		TerrainType.INDUSTRIAL:
			return ["Linear obstacle", "Building", "Open ground", "Scatter cluster", "Statue", "Industrial item"]
		TerrainType.WILDERNESS:
			return ["Difficult terrain", "Rock formation", "Plant cluster", "Rock formation", "Open space", "Natural linear feature"]
		TerrainType.ALIEN_RUIN:
			return ["Odd feature", "Ruined building", "Partial ruin", "Open space", "Strange statue", "Scattered plants"]
		TerrainType.CRASH_SITE:
			return ["Mixed scatter", "Scattered wreckage", "Large wreckage", "Crater", "Natural feature", "Open ground"]
	return []

func update_battlefield_display():
	for child in grid_container.get_children():
		child.queue_free()
	
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var label = Label.new()
			label.text = battlefield[x][y]
			grid_container.add_child(label)

func update_terrain_suggestions():
	var suggestions = {
		"small": [],
		"medium": [],
		"large": []
	}
	
	match current_terrain_type:
		TerrainType.INDUSTRIAL:
			suggestions.small.extend(["Crates", "Barrels", "Debris", "Consoles", "Pipes"])
			suggestions.medium.extend(["Containers", "Machinery", "Vehicles", "Fuel tanks", "Generators"])
			suggestions.large.extend(["Warehouse", "Factory", "Storage tanks", "Landing pad", "Cargo crane"])
		TerrainType.WILDERNESS:
			suggestions.small.extend(["Rocks", "Bushes", "Logs", "Small plants", "Animal remains"])
			suggestions.medium.extend(["Trees", "Boulders", "Ponds", "Fallen trees", "Rock formations"])
			suggestions.large.extend(["Hills", "Dense forest", "Cliffs", "River", "Cave entrance"])
		TerrainType.ALIEN_RUIN:
			suggestions.small.extend(["Alien artifacts", "Strange crystals", "Debris", "Alien flora", "Mysterious devices"])
			suggestions.medium.extend(["Broken pillars", "Alien machinery", "Overgrown structures", "Stasis pods", "Energy conduits"])
			suggestions.large.extend(["Ruined temple", "Crashed alien ship", "Mysterious monolith", "Ancient gateway", "Alien habitat dome"])
		TerrainType.CRASH_SITE:
			suggestions.small.extend(["Wreckage pieces", "Scattered cargo", "Debris", "Broken equipment", "Personal effects"])
			suggestions.medium.extend(["Engine parts", "Broken hull sections", "Damaged vehicles", "Escape pods", "Fuel spills"])
			suggestions.large.extend(["Main ship hull", "Crash crater", "Burning forest", "Impact trench", "Scattered large components"])
	
	terrain_suggestions.text = "Terrain Suggestions:\n"
	terrain_suggestions.text += "Small: " + ", ".join(suggestions.small) + "\n"
	terrain_suggestions.text += "Medium: " + ", ".join(suggestions.medium) + "\n"
	terrain_suggestions.text += "Large: " + ", ".join(suggestions.large) + "\n\n"
	terrain_suggestions.text += "Center Feature: " + center_feature.type + "\n"

func save_battlefield():
	# Implement save functionality
	pass

func load_battlefield():
	# Implement load functionality
	pass
