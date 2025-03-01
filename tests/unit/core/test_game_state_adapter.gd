extends GameTest
class_name TestGameStateAdapter

func before_each() -> void:
	super()

func after_each() -> void:
	super()

func test_can_create_game_state_instance() -> void:
	# Given we need a GameState instance for testing
	# When we use the adapter to create one
	var state = GameStateTestAdapter.create_test_instance()
	
	# Then it should be a valid GameState object
	assert_not_null(state, "GameState instance should be created")
	assert_true(state is GameState, "Should be a GameState instance")

func test_can_create_default_test_state() -> void:
	# Given we need a GameState with default values
	# When we use the adapter to create one
	var state = GameStateTestAdapter.create_default_test_state()
	
	# Then it should have the expected default values
	assert_eq(state.turn_number, 1, "Turn number should be 1")
	assert_eq(state.story_points, 3, "Story points should be 3")
	assert_eq(state.reputation, 50, "Reputation should be 50")
	assert_eq(state.resources[GameEnums.ResourceType.CREDITS], 1000, "Credits should be 1000")
	assert_eq(state.resources[GameEnums.ResourceType.FUEL], 10, "Fuel should be 10")
	assert_eq(state.resources[GameEnums.ResourceType.TECH_PARTS], 5, "Tech parts should be 5")

func test_can_deserialize_from_dict() -> void:
	# Given a serialized game state dictionary
	var serialized_data = GameStateTestAdapter.create_test_serialized_state()
	
	# When we deserialize it
	var state = GameStateTestAdapter.deserialize_from_dict(serialized_data)
	
	# Then it should be a valid GameState with the expected values
	assert_not_null(state, "GameState should be deserialized")
	assert_true(state is GameState, "Should be a GameState instance")
	assert_eq(state.turn_number, 1, "Turn number should be 1")
	assert_eq(state.story_points, 3, "Story points should be 3")
	assert_eq(state.reputation, 50, "Reputation should be 50")
	assert_eq(state.resources[GameEnums.ResourceType.CREDITS], 1000, "Credits should be 1000")