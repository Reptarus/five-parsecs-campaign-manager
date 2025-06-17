class_name MainGameScene
extends Control

## Main game scene that orchestrates the complete Five Parsecs campaign turn flow
## Following the core rules: Travel -> World -> Battle -> Post-Battle

signal phase_changed(new_phase: GamePhase)
signal campaign_turn_completed()

enum GamePhase {
	CAMPAIGN_DASHBOARD,
	TRAVEL_PHASE,
	WORLD_PHASE,
	PRE_BATTLE_PHASE,
	BATTLE_PHASE,
	POST_BATTLE_PHASE
}

# Phase nodes
@onready var phase_container: Control = $PhaseContainer
@onready var campaign_dashboard: Control = $PhaseContainer/CampaignDashboard
@onready var travel_phase: Control = $PhaseContainer/TravelPhase
@onready var world_phase: Control = $PhaseContainer/WorldPhase
@onready var pre_battle_phase: Control = $PhaseContainer/PreBattlePhase
@onready var battle_phase: Control = $PhaseContainer/BattlePhase
@onready var post_battle_phase: Control = $PhaseContainer/PostBattlePhase

# UI elements
@onready var phase_title: Label = $PhaseUI/PhaseTitle
@onready var previous_button: Button = $PhaseUI/PhaseControls/PreviousPhase
@onready var next_button: Button = $PhaseUI/PhaseControls/NextPhase
@onready var menu_button: Button = $PhaseUI/PhaseControls/PhaseMenu

var current_phase: GamePhase = GamePhase.CAMPAIGN_DASHBOARD
var campaign_data: Resource = null
var phase_nodes: Array[Control] = []

func _ready() -> void:
	_setup_phase_nodes()
	_connect_signals()
	_start_campaign_turn()

func _setup_phase_nodes() -> void:
	"""Initialize all phase nodes"""
	phase_nodes = [
		campaign_dashboard,
		travel_phase,
		world_phase,
		pre_battle_phase,
		battle_phase,
		post_battle_phase
	]
	
	# Hide all phases initially
	for phase_node in phase_nodes:
		if phase_node:
			phase_node.visible = false

func _connect_signals() -> void:
	"""Connect all UI signals"""
	previous_button.pressed.connect(_on_previous_phase)
	next_button.pressed.connect(_on_next_phase)
	menu_button.pressed.connect(_on_menu_pressed)
	
	# Connect phase completion signals
	if travel_phase and travel_phase.has_signal("phase_completed"):
		travel_phase.phase_completed.connect(_on_phase_completed)
	if world_phase and world_phase.has_signal("phase_completed"):
		world_phase.phase_completed.connect(_on_phase_completed)
	if pre_battle_phase and pre_battle_phase.has_signal("phase_completed"):
		pre_battle_phase.phase_completed.connect(_on_phase_completed)
	if battle_phase and battle_phase.has_signal("battle_completed"):
		battle_phase.battle_completed.connect(_on_battle_completed)
	if post_battle_phase and post_battle_phase.has_signal("phase_completed"):
		post_battle_phase.phase_completed.connect(_on_phase_completed)

func _start_campaign_turn() -> void:
	"""Start a new campaign turn from the dashboard"""
	_switch_to_phase(GamePhase.CAMPAIGN_DASHBOARD)

func _switch_to_phase(new_phase: GamePhase) -> void:
	"""Switch to a specific campaign phase"""
	# Hide current phase
	var current_node = _get_phase_node(current_phase)
	if current_node:
		current_node.visible = false
	
	# Show new phase
	var new_node = _get_phase_node(new_phase)
	if new_node:
		new_node.visible = true
		
		# Initialize phase if it has setup method
		if new_node.has_method("setup_phase"):
			new_node.setup_phase(campaign_data)
	
	# Update current phase
	current_phase = new_phase
	_update_phase_ui()
	phase_changed.emit(new_phase)

func _get_phase_node(phase: GamePhase) -> Control:
	"""Get the node for a specific phase"""
	match phase:
		GamePhase.CAMPAIGN_DASHBOARD:
			return campaign_dashboard
		GamePhase.TRAVEL_PHASE:
			return travel_phase
		GamePhase.WORLD_PHASE:
			return world_phase
		GamePhase.PRE_BATTLE_PHASE:
			return pre_battle_phase
		GamePhase.BATTLE_PHASE:
			return battle_phase
		GamePhase.POST_BATTLE_PHASE:
			return post_battle_phase
		_:
			return null

func _update_phase_ui() -> void:
	"""Update the phase UI controls"""
	var phase_names = [
		"Campaign Dashboard",
		"Travel Phase",
		"World Phase",
		"Pre-Battle Phase",
		"Battle Phase",
		"Post-Battle Phase"
	]
	
	phase_title.text = phase_names[current_phase]
	
	# Update button states
	previous_button.disabled = (current_phase == GamePhase.CAMPAIGN_DASHBOARD)
	next_button.disabled = (current_phase == GamePhase.POST_BATTLE_PHASE)

func _on_previous_phase() -> void:
	"""Go to previous phase"""
	if current_phase > GamePhase.CAMPAIGN_DASHBOARD:
		_switch_to_phase(current_phase - 1)

func _on_next_phase() -> void:
	"""Go to next phase"""
	if current_phase < GamePhase.POST_BATTLE_PHASE:
		_switch_to_phase(current_phase + 1)

func _on_menu_pressed() -> void:
	"""Handle menu button press"""
	# TODO: Show phase menu with options
	print("Phase menu pressed")

func _on_phase_completed() -> void:
	"""Handle phase completion - advance to next phase"""
	_on_next_phase()

func _on_battle_completed() -> void:
	"""Handle battle completion - go to post-battle"""
	_switch_to_phase(GamePhase.POST_BATTLE_PHASE)

func start_new_campaign_turn() -> void:
	"""Start a brand new campaign turn"""
	_switch_to_phase(GamePhase.TRAVEL_PHASE)

func load_campaign_data(data: Resource) -> void:
	"""Load campaign data for all phases"""
	campaign_data = data
	
	# Pass data to all phase nodes that need it
	for phase_node in phase_nodes:
		if phase_node and phase_node.has_method("load_campaign_data"):
			phase_node.load_campaign_data(data)

func get_current_phase() -> GamePhase:
	"""Get the current campaign phase"""
	return current_phase

func is_campaign_turn_complete() -> bool:
	"""Check if the campaign turn is complete"""
	return current_phase == GamePhase.POST_BATTLE_PHASE