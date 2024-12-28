extends GutTest

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")

var game_state_manager: GameStateManager

func before_each():
	game_state_manager = GameStateManager.new()
	add_child_autoqfree(game_state_manager)

func after_each():
	game_state_manager = null

func test_initial_state():
	assert_eq(game_state_manager.current_state, GameEnums.GameState.SETUP,
		"Initial state should be SETUP")
	assert_eq(game_state_manager.current_difficulty, GameEnums.DifficultyMode.NORMAL,
		"Initial difficulty should be NORMAL")
	assert_not_null(game_state_manager.game_data,
		"Game data should be initialized")

func test_difficulty_change():
	var signal_emitted = false
	game_state_manager.difficulty_changed.connect(
		func(new_difficulty): signal_emitted = true
	)
	
	game_state_manager.set_difficulty(GameEnums.DifficultyMode.CHALLENGING)
	assert_eq(game_state_manager.current_difficulty, GameEnums.DifficultyMode.CHALLENGING,
		"Difficulty should be updated")
	assert_true(signal_emitted,
		"Difficulty changed signal should be emitted")

func test_state_change():
	var signal_emitted = false
	game_state_manager.game_state_changed.connect(
		func(new_state): signal_emitted = true
	)
	
	game_state_manager.change_state(GameEnums.GameState.PLAYING)
	assert_eq(game_state_manager.current_state, GameEnums.GameState.PLAYING,
		"Game state should be updated")
	assert_true(signal_emitted,
		"State changed signal should be emitted")

func test_game_state_queries():
	game_state_manager.change_state(GameEnums.GameState.PLAYING)
	assert_true(game_state_manager.is_game_active(),
		"Game should be active when in PLAYING state")
	assert_false(game_state_manager.is_game_paused(),
		"Game should not be paused when in PLAYING state")
	assert_false(game_state_manager.is_game_over(),
		"Game should not be over when in PLAYING state")
	
	game_state_manager.change_state(GameEnums.GameState.PAUSED)
	assert_true(game_state_manager.is_game_paused(),
		"Game should be paused when in PAUSED state")
	
	game_state_manager.change_state(GameEnums.GameState.ENDED)
	assert_true(game_state_manager.is_game_over(),
		"Game should be over when in ENDED state")

func test_save_load():
	game_state_manager.change_state(GameEnums.GameState.PLAYING)
	game_state_manager.set_difficulty(GameEnums.DifficultyMode.HARDCORE)
	
	var save_data = game_state_manager.save_game()
	assert_not_null(save_data,
		"Save data should not be null")
	assert_eq(save_data.current_state, GameEnums.GameState.PLAYING,
		"Save data should contain correct state")
	assert_eq(save_data.current_difficulty, GameEnums.DifficultyMode.HARDCORE,
		"Save data should contain correct difficulty")
	
	# Reset state
	game_state_manager.change_state(GameEnums.GameState.SETUP)
	game_state_manager.set_difficulty(GameEnums.DifficultyMode.NORMAL)
	
	# Load saved state
	game_state_manager.load_game(save_data)
	assert_eq(game_state_manager.current_state, GameEnums.GameState.PLAYING,
		"Loaded state should match saved state")
	assert_eq(game_state_manager.current_difficulty, GameEnums.DifficultyMode.HARDCORE,
		"Loaded difficulty should match saved difficulty")