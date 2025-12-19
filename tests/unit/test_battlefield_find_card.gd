extends GdUnitTestSuite

## Unit Tests for BattlefieldFindCard Component
## Tests display logic, signal emission, and design system compliance

const BattlefieldFindCardScene = preload("res://src/ui/components/postbattle/BattlefieldFindCard.tscn")
const LootSystemConstants = preload("res://src/core/systems/LootSystemConstants.gd")

var _card: BattlefieldFindCard

func before_test() -> void:
	_card = auto_free(BattlefieldFindCardScene.instantiate())
	add_child(_card)
	# _ready() runs synchronously on add_child(), no await needed

func test_weapon_find_display() -> void:
	# Arrange
	var find_data := {
		"type": LootSystemConstants.LootCategory.WEAPON,
		"description": "A battered but functional infantry laser",
		"item": "Infantry Laser"
	}

	# Act
	_card.setup(find_data)

	# Assert
	assert_that(_card._find_title.text).is_equal("Weapon Found!")
	assert_that(_card._add_to_stash_button.visible).is_true()
	assert_that(_card._find_icon.color).is_equal(_card.COLOR_SUCCESS)

func test_nothing_found_display() -> void:
	# Arrange
	var find_data := {
		"type": LootSystemConstants.LootCategory.NOTHING,
		"description": "You find nothing of value in the debris.",
		"credits": 0
	}

	# Act
	_card.setup(find_data)

	# Assert
	assert_that(_card._find_title.text).is_equal("Nothing Found")
	assert_that(_card._add_to_stash_button.visible).is_false()
	assert_that(_card._find_icon.color).is_equal(_card.COLOR_TEXT_SECONDARY)

func test_credits_find_display() -> void:
	# Arrange
	var find_data := {
		"type": LootSystemConstants.LootCategory.DEBRIS,
		"description": "Salvageable debris worth a few credits",
		"credits": 3
	}

	# Act
	_card.setup(find_data)

	# Assert
	assert_that(_card._find_title.text).is_equal("Debris")
	assert_that(_card._value_row.get_child_count()).is_greater(0)
	assert_that(_card._add_to_stash_button.visible).is_false()

func test_quest_rumor_display() -> void:
	# Arrange
	var find_data := {
		"type": LootSystemConstants.LootCategory.QUEST_RUMOR,
		"description": "A data stick with encrypted coordinates",
		"item": "Quest Rumor"
	}

	# Act
	_card.setup(find_data)

	# Assert
	assert_that(_card._find_title.text).is_equal("Curious Data Stick")
	assert_that(_card._find_icon.color).is_equal(_card.COLOR_ACCENT)
	assert_that(_card._add_to_stash_button.visible).is_false()

func test_add_to_stash_signal_emission() -> void:
	# Arrange
	var find_data := {
		"type": LootSystemConstants.LootCategory.WEAPON,
		"description": "Test weapon",
		"item": "Test Item"
	}
	_card.setup(find_data)

	var signal_emitted := false
	var emitted_data: Dictionary = {}

	_card.add_to_stash_requested.connect(func(data: Dictionary):
		signal_emitted = true
		emitted_data = data
	)

	# Act
	_card._add_to_stash_button.pressed.emit()

	# Assert
	assert_that(signal_emitted).is_true()
	assert_that(emitted_data.get("item")).is_equal("Test Item")

func test_stashable_type_detection() -> void:
	# Arrange & Assert
	assert_that(_card._is_stashable(LootSystemConstants.LootCategory.WEAPON)).is_true()
	assert_that(_card._is_stashable(LootSystemConstants.LootCategory.CONSUMABLE)).is_true()
	assert_that(_card._is_stashable(LootSystemConstants.LootCategory.SHIP_PART)).is_true()
	assert_that(_card._is_stashable(LootSystemConstants.LootCategory.TRINKET)).is_true()

	assert_that(_card._is_stashable(LootSystemConstants.LootCategory.NOTHING)).is_false()
	assert_that(_card._is_stashable(LootSystemConstants.LootCategory.QUEST_RUMOR)).is_false()
	assert_that(_card._is_stashable(LootSystemConstants.LootCategory.DEBRIS)).is_false()
	assert_that(_card._is_stashable(LootSystemConstants.LootCategory.VITAL_INFO)).is_false()

func test_touch_target_compliance() -> void:
	# Arrange
	var find_data := {
		"type": LootSystemConstants.LootCategory.WEAPON,
		"description": "Test weapon",
		"item": "Test Item"
	}
	_card.setup(find_data)

	# Assert - Button should meet 48dp minimum touch target
	assert_that(_card._add_to_stash_button.custom_minimum_size.y).is_equal(48)

func test_bbcode_coloring() -> void:
	# Arrange & Act
	var weapon_desc := _card._colorize_description("Test weapon", LootSystemConstants.LootCategory.WEAPON)
	var nothing_desc := _card._colorize_description("Test nothing", LootSystemConstants.LootCategory.NOTHING)
	var quest_desc := _card._colorize_description("Test quest", LootSystemConstants.LootCategory.QUEST_RUMOR)

	# Assert
	assert_that(weapon_desc).contains("#10b981")  # Green
	assert_that(nothing_desc).contains("#6b7280")  # Muted gray
	assert_that(quest_desc).contains("#3b82f6")   # Blue
