class_name FPCM_BattlefieldMain
extends Control

## Enhanced BattlefieldMain UI for Five Parsecs Campaign Manager
## Handles tactical battle display and controls with modern architecture
## Optimized for 60 FPS performance and battle manager integration

# Dependencies
const FPCM_BattleManager = preload("res://src/core/battle/FPCM_BattleManager.gd")
const FPCM_BattleState = preload("res://src/core/battle/FPCM_BattleState.gd")
const FPCM_DiceSystem = preload("res://src/core/systems/DiceSystem.gd")

# Enhanced signals for battle manager integration
signal battle_completed()
signal turn_ended()
signal phase_completed()
signal viewport_error(error: String, context: Dictionary)

# UI References
@onready var battlefield_view: SubViewportContainer = %BattlefieldView
@onready var battlefield_viewport: SubViewport = $MarginContainer/VBoxContainer/BattlefieldView/SubViewport
@onready var camera_3d: Camera3D = %Camera3D
@onready var battlefield_node: Node3D = %Battlefield
@onready var end_turn_button: Button = %EndTurnButton

# Enhanced system references
var battle_manager: FPCM_BattleManager = null
var battle_state: FPCM_BattleState = null
var dice_system: FPCM_DiceSystem = null

# State tracking - modernized with strict typing
var campaign_data: Resource = null
var battle_data: Dictionary = {}
var current_turn: int = 1
var battle_active: bool = false
var performance_mode: bool = false

# Legacy manager references (for backward compatibility)
var alpha_manager: Node = null
var dice_manager: Node = null

func _ready() -> void:
	_initialize_managers()
	_setup_battlefield()
	_connect_signals()

func _initialize_managers() -> void:
	## Initialize manager references from autoloads
	alpha_manager = get_node("/root/FPCM_AlphaGameManager") if has_node("/root/FPCM_AlphaGameManager") else null
	dice_manager = get_node("/root/DiceManager") if has_node("/root/DiceManager") else null

	if alpha_manager and alpha_manager.has_method("get_battle_manager"):
		battle_manager = alpha_manager.get_battle_manager()

func _setup_battlefield() -> void:
	## Setup the 3D battlefield view
	# Configure camera for isometric view
	camera_3d.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera_3d.position = Vector3(0, 10, 10)
	camera_3d.look_at(Vector3.ZERO, Vector3.UP)

	# Create a simple grid for the battlefield
	_create_battlefield_grid()

func _create_battlefield_grid() -> void:
	## Create a visual grid for the battlefield
	# Create a simple plane for the battlefield
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var plane_mesh: PlaneMesh = PlaneMesh.new()
	plane_mesh.size = Vector2(20, 20)
	plane_mesh.subdivide_width = 20
	plane_mesh.subdivide_depth = 20
	mesh_instance.mesh = plane_mesh

	# Create a simple material
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.3, 0.3)
	material.metallic = 0.0
	material.roughness = 0.8
	mesh_instance.material_override = material

	battlefield_node.add_child(mesh_instance)

func _connect_signals() -> void:
	## Connect UI signals
	end_turn_button.pressed.connect(_on_end_turn_pressed)

	if battle_manager and battle_manager.has_signal("turn_completed"):
		battle_manager.turn_completed.connect(_on_turn_completed)
	if battle_manager and battle_manager.has_signal("battle_ended"):
		battle_manager.battle_ended.connect(_on_battle_ended)

func setup_phase(data: Resource) -> void:
	## Setup the battle phase with campaign data
	campaign_data = data
	# Safe property access with Universal Safety System pattern
	if data and data and data.has_method("get_meta"):
		battle_data = data.get_meta("current_battle", {})
	elif typeof(data) == TYPE_DICTIONARY and data.has("current_battle"):
		battle_data = data["current_battle"]
	elif data and "current_battle" in data:
		battle_data = data.current_battle
	else:
		battle_data = {}
	_start_battle()

func _start_battle() -> void:
	## Start the tactical battle
	battle_active = true
	current_turn = 1
	_update_ui()

	# Add log entry
	print("Tactical battle started")

func _update_ui() -> void:
	## Update the UI elements
	if battle_active:
		end_turn_button.text = "End Turn %d" % current_turn
		end_turn_button.disabled = false
	else:
		end_turn_button.text = "Battle Complete"
		end_turn_button.disabled = true

func _on_end_turn_pressed() -> void:
	## Handle end turn button press
	if not battle_active:
		return

	current_turn += 1
	turn_ended.emit()

	# Check if battle should end (simple condition for now)
	if current_turn > 6: # Simple turn limit
		_end_battle()
	else:
		_update_ui()
		print("Turn %d started" % current_turn)

func _end_battle() -> void:
	## End the tactical battle
	battle_active = false
	_update_ui()
	battle_completed.emit()
	print("Battle completed")

func _on_turn_completed() -> void:
	## Handle turn completion from battle manager
	print("Turn %d completed" % current_turn)

func _on_battle_ended(result: Dictionary) -> void:
	## Handle battle end from battle manager
	battle_active = false
	battle_data = result
	_update_ui()
	print("Battle ended with result: %s" % result)

func get_battle_status() -> Dictionary:
	## Get the current battle status
	return {
		"current_turn": current_turn,
		"battle_active": battle_active,
		"battle_data": battle_data
	}

func load_campaign_data(data: Resource) -> void:
	## Load campaign data for this phase
	campaign_data = data
	battle_data = data.get_meta("current_battle", {}) if data else {}
