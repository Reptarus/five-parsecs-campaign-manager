extends GdUnitTestSuite

## The three tracking tiers must be described ONE way.
##
## PreBattleUI carried its own list of tier names and descriptions while
## TierSelectionPanel rendered BattleTierController.TIER_INFO, so the same three
## choices read differently depending on which screen the player was on — and
## neither list matched the code. PreBattleUI promised "Full Oracle — AI runs enemy
## turns"; the picker inside the battle promised it would "manage everything". It
## does neither: it adds an oracle panel to the enemy tracker and the player still
## moves every figure.
##
## This suite instantiates the REAL screen rather than scanning the source, because
## a text scan proves the right words exist somewhere, not that the control the
## player reads is built from them.

const PreBattleScene = preload("res://src/ui/screens/battle/PreBattle.tscn")
const TierController = preload("res://src/core/battle/BattleTierController.gd")


func _screen() -> Control:
	var ui: Control = PreBattleScene.instantiate()
	add_child(ui)
	auto_free(ui)
	return ui


func test_every_tier_radio_is_built_from_tier_info() -> void:
	var ui := _screen()
	ui._build_tier_selector()
	var radios: Array = ui._tier_radios
	assert_int(radios.size()).is_equal(3)
	for tier in [0, 1, 2]:
		var info: Dictionary = TierController.TIER_INFO.get(tier, {})
		var text: String = str(radios[tier].text)
		assert_str(text).contains(str(info.get("name", "")))
		assert_str(text).contains(str(info.get("description", "")))


func test_tier_copy_does_not_promise_what_the_code_does_not_do() -> void:
	## Regression guard on the specific claims that were wrong. FULL_ORACLE does not
	## run the enemy turn — the book's AI instructions are shown at EVERY tier
	## (TacticalBattleUI._show_enemy_actions_ui: "the tier gates AUTOMATION, not
	## INSTRUCTIONS"), and the player moves the figures at all three.
	var oracle: String = str(TierController.TIER_INFO[2].get("description", ""))
	assert_str(oracle.to_lower()).not_contains("runs enemy turns")
	assert_str(oracle.to_lower()).not_contains("manage everything")
	# LOG_ONLY gets the whole companion; describing it as note-taking undersold it
	# badly enough that a player would pick a higher tier than they wanted.
	var log_only: String = str(TierController.TIER_INFO[0].get("description", ""))
	assert_str(log_only.to_lower()).not_contains("minimal tracking")


func test_the_battle_choices_are_remembered_between_battles() -> void:
	## They reset to LOG_ONLY / play_on_table every single battle, so a player who
	## prefers Assisted re-picked it before every fight — while TierSelectionPanel's
	## docblock claimed it "remembers last selection" and nothing persisted it.
	var sm := get_node_or_null("/root/SettingsManager")
	if sm == null:
		return
	var prior_tier: int = int(sm.get_last_tracking_tier())
	var prior_mode: String = str(sm.get_last_combat_mode())

	# Set FIRST, then instantiate: the screen must pick these up in _ready(),
	# which is the only thing that makes it work in the app. Calling
	# _restore_remembered_choices() by hand here would pass just as happily
	# with the _ready() call removed — it did, on the first version of this
	# test, and detected nothing.
	sm.set_last_tracking_tier(2)
	sm.set_last_combat_mode("no_minis")
	var ui := _screen()
	assert_int(ui.selected_tier).is_equal(2)
	assert_str(ui.selected_representation_mode).is_equal("no_minis")

	# And the radio that comes up pressed is the remembered one, not index 0.
	ui._build_tier_selector()
	assert_bool(ui._tier_radios[2].button_pressed).is_true()
	assert_bool(ui._tier_radios[0].button_pressed).is_false()

	sm.set_last_tracking_tier(prior_tier)
	sm.set_last_combat_mode(prior_mode)


func test_an_unknown_stored_mode_is_ignored() -> void:
	## options.cfg is a text file a player can edit, and a junk value must not put
	## the screen into a combat mode that has no radio.
	var sm := get_node_or_null("/root/SettingsManager")
	if sm == null:
		return
	var prior_mode: String = str(sm.get_last_combat_mode())
	sm.set_last_combat_mode("not_a_mode")
	var ui := _screen()
	assert_str(ui.selected_representation_mode).is_equal("play_on_table")
	sm.set_last_combat_mode(prior_mode)
