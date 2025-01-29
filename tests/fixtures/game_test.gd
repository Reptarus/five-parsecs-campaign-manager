@tool
extends BaseTest
class_name GameTest

const Enemy := preload("res://src/core/enemy/base/Enemy.gd")
const Character := preload("res://src/core/character/Base/Character.gd")
const GameState := preload("res://src/core/state/GameState.gd")
const FiveParcsecsCampaign := preload("res://src/core/campaign/Campaign.gd")
const TestHelper := preload("res://tests/fixtures/test_helper.gd")

# Campaign test configuration
const DEFAULT_CAMPAIGN_CONFIG := {
	"difficulty_level": GameEnums.DifficultyLevel.NORMAL,
	"enable_permadeath": true,
	"use_story_track": true
}

# Game state references
var _game_state: GameState
var _campaign_system = null

func before_each() -> void:
	await super.before_each()
	
	# Initialize game state
	_game_state = GameState.new()
	add_child_autofree(_game_state)
	track_test_node(_game_state)
	
	# Wait for engine to stabilize
	await stabilize_engine()

func after_each() -> void:
	_game_state = null
	_campaign_system = null
	await super.after_each()

# Game state helpers
func create_test_game_state() -> Node:
	var game_state = GameState.new()
	add_child_autofree(game_state)
	track_test_node(game_state)
	return game_state

func create_test_enemy() -> Node:
	var enemy = Enemy.new()
	add_child_autofree(enemy)
	track_test_node(enemy)
	return enemy

func create_test_character() -> Node:
	var character = Character.new()
	add_child_autofree(character)
	track_test_node(character)
	return character

func setup_campaign_system() -> Node:
	var campaign_system = Node.new()
	campaign_system.name = "CampaignSystem"
	add_child_autofree(campaign_system)
	track_test_node(campaign_system)
	return campaign_system

func create_test_campaign() -> Resource:
	var campaign = FiveParcsecsCampaign.new()
	track_test_resource(campaign)
	return campaign

func load_test_campaign(game_state: Node = null) -> void:
	var target_state = game_state if game_state else _game_state
	if not target_state:
		push_error("No game state available to load campaign into")
		return
	
	var campaign = create_test_campaign()
	target_state.current_campaign = campaign
	target_state.campaign_loaded.emit(campaign)

# Campaign state assertions
func assert_campaign_state(campaign: Resource, expected_state: Dictionary) -> void:
	for key in expected_state:
		assert_eq(campaign[key], expected_state[key],
			"Campaign %s should match expected state" % key)

func assert_campaign_phase(campaign: Resource, expected_phase: int) -> void:
	assert_eq(campaign.current_phase, expected_phase,
		"Campaign should be in phase %d" % expected_phase)

func assert_campaign_resources(campaign: Resource, expected_resources: Dictionary) -> void:
	for resource in expected_resources:
		assert_eq(campaign.resources[resource], expected_resources[resource],
			"Campaign should have %d %s" % [expected_resources[resource], resource])

# State verification
func assert_valid_game_state(game_state: Node) -> void:
	assert_not_null(game_state, "Game state should exist")
	assert_not_null(game_state.current_campaign, "Campaign state should be initialized")
	assert_eq(game_state.difficulty_level, GameEnums.DifficultyLevel.NORMAL,
		"Difficulty should be set to normal")
	assert_true(game_state.enable_permadeath, "Permadeath should be enabled")
	assert_true(game_state.use_story_track, "Story track should be enabled")
	assert_true(game_state.auto_save_enabled, "Auto save should be enabled")

# Utility methods
func stabilize_engine(time: float = STABILIZATION_TIME) -> void:
	await get_tree().create_timer(time).timeout

func assert_async_signal(emitter: Object, signal_name: String, timeout: float = SIGNAL_TIMEOUT) -> bool:
	var timer = get_tree().create_timer(timeout)
	var signal_received = false
	
	# Connect to signal
	var callable = func(): signal_received = true
	emitter.connect(signal_name, callable, CONNECT_ONE_SHOT)
	
	# Wait for either signal or timeout
	timer.timeout.connect(func(): signal_received = false, CONNECT_ONE_SHOT)
	while not signal_received and not timer.is_stopped():
		await get_tree().process_frame
	
	return signal_received

func add_child_autofree(node: Node) -> Node:
	if node.get_parent():
		node.get_parent().remove_child(node)
	add_child(node)
	track_test_node(node)
	return node
