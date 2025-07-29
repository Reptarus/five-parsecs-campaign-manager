@tool
@warning_ignore("return_value_discarded")
@warning_ignore("unsafe_method_access")
@warning_ignore("untyped_declaration")
@warning_ignore("unused_signal")
extends Node
class_name GameCampaignManager

## Game Campaign Manager for Five Parsecs from Home
## Manages campaign-level operations, integrating with various game systems

# GlobalEnums available as autoload singleton
# Note: GameState injected via initialize() to avoid circular dependencies
const CampaignPhaseManager = preload("res://src/core/campaign/CampaignPhaseManager.gd")

signal campaign_updated()
signal phase_changed(old_phase: int, new_phase: int)
signal event_occurred(event_data: Dictionary)
signal resource_updated(resource_type: GlobalEnums.ResourceType, new_value: int)

var gamestate: Node # GameState - avoiding circular dependency
var phase_manager: CampaignPhaseManager
var current_campaign: Dictionary = {}

func _init() -> void:
	name = "GameCampaignManager"

func initialize(game_state: Node) -> void:
	gamestate = game_state
	phase_manager = CampaignPhaseManager.new()
	add_child(phase_manager)

	# Connect phase manager signals
	phase_manager.phase_changed.connect(_on_phase_changed)

func get_current_campaign() -> Dictionary:
	return current_campaign

func create_new_campaign(campaign_data: Dictionary) -> void:
	current_campaign = campaign_data.duplicate(true)
	campaign_updated.emit()

func save_current_campaign() -> void:
	if gamestate:
		gamestate.save_campaign()

func load_campaign(campaign_data: Dictionary) -> void:
	current_campaign = campaign_data.duplicate(true)
	campaign_updated.emit()

func start_battle() -> void:
	# Start battle implementation
	pass

func resolve_combat() -> void:
	# Resolve combat implementation
	pass

func collect_rewards() -> void:
	# Collect rewards implementation
	pass

func process_upkeep() -> void:
	# Process upkeep implementation
	pass

func check_events() -> void:
	# Check events implementation
	pass

func resolve_events() -> void:
	# Resolve events implementation
	pass

func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	phase_changed.emit(old_phase, new_phase)

func update_resource(resource_type: int, amount: int) -> void:
	gamestate.update_resource(resource_type, amount)

func trigger_event(event_data: Dictionary) -> void:
	event_occurred.emit(event_data) # warning: return value discarded (intentional)

func get_game_state() -> Node:
	return gamestate

func _exit_tree() -> void:
	if gamestate:
		gamestate.queue_free()
	current_campaign.clear()

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null