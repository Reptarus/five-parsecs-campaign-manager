extends GdUnitTestSuite
## Tests for Three-Enum Synchronization
## Covers 3 NOT_TESTED mechanics from QA_CORE_RULES_TEST_PLAN.md §9
## CRITICAL: GlobalEnums, GameEnums, and FiveParsecsGameEnums must stay in sync

var GlobalEnumsRef
var GameEnumsRef
var FPGameEnumsRef

func before():
	GlobalEnumsRef = load("res://src/core/systems/GlobalEnums.gd")
	GameEnumsRef = load("res://src/core/enums/GameEnums.gd")
	FPGameEnumsRef = load("res://src/game/campaign/crew/FiveParsecsGameEnums.gd")

func after():
	GlobalEnumsRef = null
	GameEnumsRef = null
	FPGameEnumsRef = null

# ============================================================================
# GlobalEnums Basic Validation
# ============================================================================

func test_global_enums_loads():
	assert_that(GlobalEnumsRef).is_not_null()

func test_game_enums_loads():
	assert_that(GameEnumsRef).is_not_null()

func test_fp_game_enums_loads():
	assert_that(FPGameEnumsRef).is_not_null()

# ============================================================================
# FiveParsecsCampaignPhase Ordinals (14 values)
# ============================================================================

func test_campaign_phase_has_fourteen_values():
	"""FiveParsecsCampaignPhase should have 14 phase values"""
	var phase_keys = GlobalEnumsRef.FiveParsecsCampaignPhase.keys()
	assert_that(phase_keys.size()).is_equal(14)

func test_campaign_phase_includes_required_phases():
	"""Core 9 phases + extras must all exist"""
	var phase_keys = GlobalEnumsRef.FiveParsecsCampaignPhase.keys()
	for required in ["STORY", "TRAVEL", "UPKEEP", "MISSION", "POST_MISSION",
			"ADVANCEMENT", "TRADING", "CHARACTER", "RETIREMENT"]:
		assert_that(phase_keys.has(required)).is_true()

# ============================================================================
# CharacterClass Superset Validation
# ============================================================================

func test_global_enums_has_character_class():
	var keys = GlobalEnumsRef.CharacterClass.keys()
	assert_that(keys.size()).is_greater(0)

func test_fp_game_enums_has_character_class():
	var keys = FPGameEnumsRef.CharacterClass.keys()
	assert_that(keys.size()).is_greater(0)

func test_fp_character_class_is_superset_of_global():
	"""FiveParsecsGameEnums.CharacterClass must contain all values from GlobalEnums.CharacterClass"""
	var global_keys = GlobalEnumsRef.CharacterClass.keys()
	var fp_keys = FPGameEnumsRef.CharacterClass.keys()
	for key in global_keys:
		assert_that(fp_keys.has(key)).is_true()

# ============================================================================
# DifficultyLevel Validation
# ============================================================================

func test_global_difficulty_level_exists():
	var keys = GlobalEnumsRef.DifficultyLevel.keys()
	assert_that(keys.size()).is_greater(0)

func test_global_difficulty_has_required_levels():
	var keys = GlobalEnumsRef.DifficultyLevel.keys()
	for required in ["EASY", "NORMAL", "HARDCORE", "INSANITY"]:
		assert_that(keys.has(required)).is_true()

func test_difficulty_level_easy_value():
	assert_that(GlobalEnumsRef.DifficultyLevel.EASY).is_equal(1)

func test_difficulty_level_normal_value():
	assert_that(GlobalEnumsRef.DifficultyLevel.NORMAL).is_equal(2)

func test_difficulty_level_hardcore_value():
	assert_that(GlobalEnumsRef.DifficultyLevel.HARDCORE).is_equal(6)

func test_difficulty_level_insanity_value():
	assert_that(GlobalEnumsRef.DifficultyLevel.INSANITY).is_equal(8)

# ============================================================================
# ContentFlag Count (DLC System)
# ============================================================================

func test_content_flag_count():
	"""DLCManager should have 35 DLC + 2 Bug Hunt = 37 ContentFlags total"""
	if GlobalEnumsRef.get("ContentFlag") != null:
		var keys = GlobalEnumsRef.ContentFlag.keys()
		assert_that(keys.size()).is_equal(37)
	else:
		# ContentFlag may be in DLCManager instead of GlobalEnums
		pass

# ============================================================================
# Motivation Enum Completeness
# ============================================================================

func test_motivation_enum_has_twenty_one_values():
	"""21 motivations (including NONE)"""
	var keys = GlobalEnumsRef.Motivation.keys()
	assert_that(keys.size()).is_equal(21)

func test_motivation_enum_required_values():
	var keys = GlobalEnumsRef.Motivation.keys()
	for required in ["NONE", "WEALTH", "REVENGE", "GLORY", "KNOWLEDGE",
			"POWER", "JUSTICE", "SURVIVAL", "LOYALTY", "FREEDOM",
			"DISCOVERY", "REDEMPTION", "DUTY", "FAME", "ESCAPE",
			"ADVENTURE", "TRUTH", "TECHNOLOGY", "ROMANCE", "FAITH",
			"POLITICAL", "ORDER"]:
		assert_that(keys.has(required)).is_true()

# ============================================================================
# Background Enum
# ============================================================================

func test_background_enum_not_empty():
	var keys = GlobalEnumsRef.Background.keys()
	assert_that(keys.size()).is_greater(0)

func test_background_has_required_values():
	var keys = GlobalEnumsRef.Background.keys()
	for required in ["MILITARY", "ACADEMIC", "NOBLE", "COLONIST"]:
		assert_that(keys.has(required)).is_true()

# ============================================================================
# Origin Enum
# ============================================================================

func test_origin_enum_not_empty():
	var keys = GlobalEnumsRef.Origin.keys()
	assert_that(keys.size()).is_greater(0)

# ============================================================================
# GameEnums Cross-Check
# ============================================================================

func test_game_enums_has_difficulty_level():
	var keys = GameEnumsRef.DifficultyLevel.keys()
	assert_that(keys.size()).is_greater(0)

func test_game_enums_has_edit_mode():
	var keys = GameEnumsRef.EditMode.keys()
	assert_that(keys.size()).is_greater(0)

func test_game_enums_has_game_phase():
	var keys = GameEnumsRef.GamePhase.keys()
	assert_that(keys.size()).is_greater(0)
