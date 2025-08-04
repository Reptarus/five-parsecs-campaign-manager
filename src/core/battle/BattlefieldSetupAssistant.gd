class_name FPCM_BattlefieldSetupAssistant
extends Node

## Battlefield Setup Assistant - Refactored
## Orchestrates the data-driven generation and rendering of a battlefield.

# --- Dependencies ---
const BattlefieldGenerator = preload("res://src/core/battle/BattlefieldGenerator.gd")
const BattlefieldRenderer = preload("res://src/core/battle/BattlefieldRenderer.gd")

# --- Signals ---
signal battlefield_generated(grid_data: Dictionary)
signal setup_error(message: String)

# --- Core Components ---
var generator: FPCM_BattlefieldGenerator
var renderer: FPCM_BattlefieldRenderer

# --- State ---
var last_generated_grid: Dictionary
var last_generation_context: Dictionary

# --- Initialization ---

func _init() -> void:
	generator = FPCM_BattlefieldGenerator.new()
	_setup_system_connections()

func _setup_system_connections() -> void:
	# Connect generator signals for proper workflow integration
	if generator:
		var result1 = generator.generation_started.connect(_on_generation_started)
		if result1 != OK:
			push_error("BattlefieldSetupAssistant: Failed to connect generation_started signal")
		var result2 = generator.generation_progress.connect(_on_generation_progress)
		if result2 != OK:
			push_error("BattlefieldSetupAssistant: Failed to connect generation_progress signal")
		var result3 = generator.generation_completed.connect(_on_generation_completed)
		if result3 != OK:
			push_error("BattlefieldSetupAssistant: Failed to connect generation_completed signal")
		var result4 = generator.generation_error.connect(_on_generation_error)
		if result4 != OK:
			push_error("BattlefieldSetupAssistant: Failed to connect generation_error signal")

func set_renderer(p_renderer: FPCM_BattlefieldRenderer) -> void:
	# Connect the renderer node to this assistant
	# This should be called after this node and the renderer are in the scene tree.
	renderer = p_renderer

func inject_battlefield_data(battlefield_data: Resource) -> void:
	"""Inject battlefield data resource for integration"""
	# Store reference to battlefield data for use in generation
	if battlefield_data:
		last_generation_context["battlefield_data"] = battlefield_data
		print("BattlefieldSetupAssistant: Battlefield data injected successfully")
	else:
		push_warning("BattlefieldSetupAssistant: Null battlefield data provided")

# --- Public API ---

## The main function to generate and display a battlefield.
## @param context: A dictionary containing `mission_resource` and `generation_seed`.
func generate_and_render_battlefield(context: Dictionary) -> void:
	if not generator:
		var error_msg = "BattlefieldGenerator not initialized."
		push_error(error_msg)
		setup_error.emit(error_msg)
		return

	# Store the context used for this generation for later use (e.g., export)
	self.last_generation_context = context

	# Step 1: Generate the data grid using JSON generator
	# The generation signals will be handled by our connected signal handlers
	last_generated_grid = generator.generate_battlefield(context)

	if last_generated_grid.is_empty():
		# Error already emitted by generator, just handle cleanup
		return

	# Step 2: Convert JSON data to FPCM types for integration
	var converted_data = _convert_json_to_fpcm_types(last_generated_grid)

	# Step 3: Render the grid data if renderer is available
	if renderer:
		renderer.render_battlefield(converted_data)

	# Step 4: Emit completion signal with converted data
	battlefield_generated.emit(converted_data)

## Regenerates the last battlefield with a new seed.
func regenerate_with_new_seed() -> void:
	if last_generation_context.is_empty():
		push_error("Cannot regenerate: no previous generation context found.")
		return
	var new_context = last_generation_context.duplicate(true)
	new_context["generation_seed"] = RandomNumberGenerator.new().randi()
	generate_and_render_battlefield(new_context)

## Returns the most recently generated grid data.
func get_last_generated_grid() -> Dictionary:
	return last_generated_grid

## Returns the context dictionary used for the last generation.
func get_last_generation_context() -> Dictionary:
	return last_generation_context

## Clears the rendered battlefield.
func clear_battlefield() -> void:
	if renderer:
		renderer.clear_battlefield()
	last_generated_grid = {}
	last_generation_context = {}

# --- Signal Handlers ---

func _on_generation_started(theme_name: String) -> void:
	# Forward progress updates to interested parties
	print("Battlefield generation started with theme: %s" % theme_name)

func _on_generation_progress(step: String, progress: float) -> void:
	# Forward progress updates - could be connected to UI progress bars
	print("Generation progress: %s (%.1f%%)" % [step, progress * 100])

func _on_generation_completed(battlefield_data: Dictionary) -> void:
	# Generation completed successfully
	print("Battlefield generation completed successfully")

func _on_generation_error(error_message: String) -> void:
	# Handle generation errors by forwarding to our error signal
	push_error("Battlefield generation failed: %s" % error_message)
	setup_error.emit(error_message)

# --- Type Conversion Methods ---

func _convert_json_to_fpcm_types(json_data: Dictionary) -> Dictionary:
	"""Convert JSON battlefield data to FPCM type system"""
	var converted = json_data.duplicate(true)
	
	# Convert terrain features from JSON to FPCM_BattlefieldTypes.TerrainFeature
	if json_data.has("terrain_features"):
		var terrain_features: Array[FPCM_BattlefieldTypes.TerrainFeature] = []
		for feature_data in json_data["terrain_features"]:
			if feature_data is FPCM_BattlefieldTypes.TerrainFeature:
				terrain_features.append(feature_data)
			else:
				var terrain_feature = _convert_json_to_terrain_feature(feature_data)
				if terrain_feature:
					terrain_features.append(terrain_feature)
		converted["terrain_features"] = terrain_features
	
	# Convert objectives from JSON to FPCM_BattlefieldTypes.FPCM_ObjectiveMarker
	if json_data.has("objectives"):
		var objectives: Array[FPCM_BattlefieldTypes.FPCM_ObjectiveMarker] = []
		for objective_data in json_data["objectives"]:
			if objective_data is FPCM_BattlefieldTypes.FPCM_ObjectiveMarker:
				objectives.append(objective_data)
			else:
				var objective = _convert_json_to_objective(objective_data)
				if objective:
					objectives.append(objective)
		converted["objectives"] = objectives
	
	return converted

func _convert_json_to_terrain_feature(feature_data: Dictionary) -> FPCM_BattlefieldTypes.TerrainFeature:
	"""Convert JSON feature data to TerrainFeature type with proper field mapping"""
	if not feature_data:
		return null
	
	var terrain_feature = FPCM_BattlefieldTypes.TerrainFeature.new()
	
	# Extract basic properties from JSON root
	terrain_feature.feature_id = feature_data.get("id", "")
	terrain_feature.title = feature_data.get("name", "")
	terrain_feature.description = feature_data.get("description", "")
	
	# Extract gameplay properties from nested gameplay object
	var gameplay = feature_data.get("gameplay", {})
	terrain_feature.cover_value = gameplay.get("cover_value", 0)
	terrain_feature.movement_modifier = gameplay.get("movement_cost", 1.0)
	
	# Extract size and convert to positions if available
	var size_array = feature_data.get("size", [1, 1])
	if size_array.size() >= 2:
		# Generate positions for multi-cell features
		for y in range(size_array[1]):
			for x in range(size_array[0]):
				terrain_feature.positions.append(Vector2i(x, y))
	else:
		terrain_feature.positions = [Vector2i(0, 0)]
	
	# Map gameplay type to FPCM setup methods
	var gameplay_type = gameplay.get("type", "")
	match gameplay_type:
		"cover":
			terrain_feature.setup_cover_feature()
		"elevation":
			terrain_feature.setup_elevation_feature()
		"difficult":
			terrain_feature.setup_difficult_terrain()
		"background":
			terrain_feature.setup_special_feature()
			terrain_feature.feature_type = &"background"
		_:
			terrain_feature.setup_special_feature()
	
	# Extract tags and convert to special rules
	var tags = feature_data.get("tags", [])
	for tag in tags:
		if tag not in ["background", "cover", "elevation", "difficult"]:
			terrain_feature.special_rules.append(tag.capitalize())
	
	# Add gameplay-specific properties
	if gameplay.has("blocks_los"):
		terrain_feature.properties["blocks_los"] = gameplay["blocks_los"]
	if gameplay.has("height"):
		terrain_feature.properties["height"] = gameplay["height"]
	
	return terrain_feature

func _convert_json_to_objective(objective_data: Dictionary) -> FPCM_BattlefieldTypes.FPCM_ObjectiveMarker:
	"""Convert JSON objective data to ObjectiveMarker type with proper field mapping"""
	if not objective_data:
		return null
	
	var objective = FPCM_BattlefieldTypes.FPCM_ObjectiveMarker.new()
	
	# Extract basic properties
	objective.objective_id = objective_data.get("id", "")
	objective.title = objective_data.get("name", "")
	objective.description = objective_data.get("description", "")
	
	# Extract gameplay properties if present
	var gameplay = objective_data.get("gameplay", {})
	if gameplay.has("interaction_type"):
		objective.objective_type = StringName(gameplay["interaction_type"])
		
		# Map interaction types to completion requirements
		match gameplay["interaction_type"]:
			"tech_check":
				objective.completion_requirements = {"requires_tech": true, "difficulty": 5}
				objective.victory_points = 2
			"search":
				objective.completion_requirements = {"requires_action": true, "search_roll": 4}
				objective.victory_points = 1
			"secure":
				objective.completion_requirements = {"control_distance": 1, "turns_required": 1}
				objective.victory_points = 1
			_:
				objective.completion_requirements = {"requires_action": true}
				objective.victory_points = 1
	else:
		# Fallback for legacy objectives
		objective.objective_type = &"secure"
		objective.victory_points = 1
		objective.completion_requirements = {"control_distance": 1}
	
	# Extract tags and convert to special rules
	var tags = objective_data.get("tags", [])
	for tag in tags:
		if tag != "objective":
			objective.special_rules.append(tag.capitalize())
	
	return objective

## Generate terrain features using the JSON generator for legacy compatibility
func _generate_terrain_features(mission_data: Resource, options: Dictionary) -> Array[FPCM_BattlefieldTypes.TerrainFeature]:
	"""Legacy method to generate terrain features using JSON system"""
	var context = {
		"mission_resource": mission_data,
		"generation_seed": options.get("generation_seed", RandomNumberGenerator.new().randi())
	}
	
	var generated_data = generator.generate_battlefield(context)
	return generated_data.get("terrain_features", [])
