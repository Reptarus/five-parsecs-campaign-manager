extends Control

const TerrainTypes = preload("res://Battle/TerrainTypes.gd")
const BattlefieldGenerator = preload("res://Resources/BattlePhase/BattlefieldGenerator.gd")

@onready var mission_info_panel = %MissionInfoPanel
@onready var enemy_info_panel = %EnemyInfoPanel
@onready var battlefield_preview = %BattlefieldPreview
@onready var generation_progress = %GenerationProgress
@onready var progress_label = %ProgressLabel
@onready var regenerate_button = %RegenerateButton
@onready var start_mission_button = %StartMissionButton
@onready var grid_size_option = %GridSizeOption
@onready var terrain_type_option = %TerrainTypeOption
@onready var density_sliders = %DensitySliders

var generator: BattlefieldGenerator
var current_mission: Dictionary
var terrain_densities: Dictionary = {}

signal mission_started(battlefield_data: Dictionary)

func _ready() -> void:
	generator = BattlefieldGenerator.new()
	generator.generation_progress.connect(_on_generation_progress)
	generator.battlefield_generated.connect(_on_battlefield_generated)
	
	setup_ui()
	setup_terrain_densities()
	
	# Default mission data for testing
	current_mission = {
		"mission_type": "urban",
		"deployment_type": "standard",
		"objective_type": "capture",
		"enemy_count": 5,
		"terrain_requirements": ["cover", "elevation"],
		"special_conditions": []
	}
	
	update_mission_info()

func setup_ui() -> void:
	# Setup grid size options
	for size in [16, 20, 24, 32]:
		grid_size_option.add_item("%dx%d" % [size, size])
	grid_size_option.select(2) # Default to 24x24
	
	# Setup terrain type options
	terrain_type_option.add_item("Urban")
	terrain_type_option.add_item("Wilderness")
	terrain_type_option.add_item("Industrial")
	
	# Connect signals
	regenerate_button.pressed.connect(_on_regenerate_pressed)
	start_mission_button.pressed.connect(_on_start_mission_pressed)
	grid_size_option.item_selected.connect(_on_grid_size_changed)
	terrain_type_option.item_selected.connect(_on_terrain_type_changed)

func setup_terrain_densities() -> void:
	# Clear existing sliders
	for child in density_sliders.get_children():
		child.queue_free()
	
	# Create sliders for each terrain type
	for terrain_type in TerrainTypes.Type.values():
		if terrain_type == TerrainTypes.Type.EMPTY:
			continue
			
		var container = HBoxContainer.new()
		var label = Label.new()
		label.text = TerrainTypes.Type.keys()[terrain_type].capitalize().replace("_", " ")
		
		var slider = HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 5
		slider.value = _get_default_density(terrain_type) * 100
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		container.add_child(label)
		container.add_child(slider)
		density_sliders.add_child(container)
		
		# Store initial density
		terrain_densities[terrain_type] = slider.value / 100.0
		
		# Connect signal
		slider.value_changed.connect(_on_density_changed.bind(terrain_type))

func _get_default_density(terrain_type: int) -> float:
	match terrain_type:
		TerrainTypes.Type.WALL: return 0.05
		TerrainTypes.Type.COVER_LOW: return 0.15
		TerrainTypes.Type.COVER_HIGH: return 0.10
		TerrainTypes.Type.DIFFICULT: return 0.08
		TerrainTypes.Type.HAZARDOUS: return 0.05
		TerrainTypes.Type.ELEVATED: return 0.07
		TerrainTypes.Type.WATER: return 0.03
		_: return 0.0

func update_mission_info() -> void:
	mission_info_panel.setup(current_mission)
	
	var enemy_info = {
		"enemies": [
			{"name": "Grunt", "count": current_mission.enemy_count}
		],
		"enemy_weapons": [
			{"name": "Rifle", "count": current_mission.enemy_count}
		],
		"notable_sight": "None",
		"objective_name": current_mission.objective_type.capitalize(),
		"objective_description": "Complete the mission objective"
	}
	enemy_info_panel.setup(enemy_info)

func generate_battlefield() -> void:
	regenerate_button.disabled = true
	start_mission_button.disabled = true
	
	# Update generator settings
	var selected_size = int(grid_size_option.get_item_text(grid_size_option.selected).split("x")[0])
	generator.grid_size = Vector2i(selected_size, selected_size)
	
	# Generate battlefield
	var battlefield_data = generator.generate_battlefield(current_mission)
	battlefield_preview.update_preview(battlefield_data)

func _on_generation_progress(step: String, progress: float) -> void:
	generation_progress.value = progress * 100
	progress_label.text = step

func _on_battlefield_generated(battlefield_data: Dictionary) -> void:
	regenerate_button.disabled = false
	start_mission_button.disabled = false
	progress_label.text = "Generation Complete"

func _on_regenerate_pressed() -> void:
	generate_battlefield()

func _on_start_mission_pressed() -> void:
	var battlefield_data = generator.get_current_battlefield()
	mission_started.emit(battlefield_data)

func _on_grid_size_changed(index: int) -> void:
	var size = int(grid_size_option.get_item_text(index).split("x")[0])
	generator.grid_size = Vector2i(size, size)

func _on_terrain_type_changed(index: int) -> void:
	var type = terrain_type_option.get_item_text(index).to_lower()
	current_mission.mission_type = type
	update_mission_info()

func _on_density_changed(value: float, terrain_type: int) -> void:
	terrain_densities[terrain_type] = value / 100.0
	generator.update_terrain_density(terrain_type, terrain_densities[terrain_type]) 