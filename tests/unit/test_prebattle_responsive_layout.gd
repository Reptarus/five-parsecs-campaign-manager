extends GdUnitTestSuite
## Pre-battle responsive / clarity layout contract (battle-flow UX pass, Jun 2026)
##
## Instantiates the real PreBattle.tscn and locks in the structural changes that
## de-clip the screen on the 360dp portrait floor and keep the CampaignTurnController
## handoff contract intact:
##   1. AdaptivePanelGroup holds 4 panes in order Mission / Forces / Battlefield / Crew
##   2. The 8-col enemy stat GridContainer is wrapped in a horizontal-scroll
##      ScrollContainer (h=AUTO, v=DISABLED) so it swipes in portrait, fills on desktop
##   3. Crew selection buttons meet the touch-target floor and wrap long names
##   4. selected_representation_mode / selected_tier remain script PROPERTIES
##      (read by CampaignTurnController._on_deployment_confirmed) and auto-resolve
##      greys out the tracking-tier radios
##
## gdUnit4 v6.0.3 compatible. NOTE: run with -c, never --headless (project rule).

const PreBattleScene := preload("res://src/ui/screens/battle/PreBattle.tscn")

const ENEMY_FIXTURE := {
	"title": "Test Raid",
	"description": "A test mission.",
	"battle_type": 0,
	"enemy_force": {
		"type": "Enforcers",
		"numbers": "+0",
		"panic": "1-2",
		"speed": 4,
		"combat_skill": 1,
		"toughness": 4,
		"ai": "T",
		"weapons": "2 A",
		"count": 4,
		"special_rules": [],
	},
}


func _make_ui() -> Control:
	var ui: Control = auto_free(PreBattleScene.instantiate())
	add_child(ui)
	return ui


## Depth-first find the first node of a given Godot class under `root`.
func _find_by_class(root: Node, klass: String) -> Node:
	for child in root.get_children():
		if child.is_class(klass):
			return child
		var found := _find_by_class(child, klass)
		if found:
			return found
	return null


func test_adaptive_panes_order_mission_forces_battlefield_crew() -> void:
	var ui := _make_ui()
	var group = ui._panel_group
	assert_object(group).is_not_null()
	assert_int(group.get_pane_count()).is_equal(4)
	# _titles is the tab/focus order = add_pane order.
	var titles: Array = []
	for t in group._titles:
		titles.append(str(t))
	assert_array(titles).is_equal(["Mission", "Forces", "Battlefield", "Crew"])


func test_enemy_table_wrapped_in_horizontal_scroll() -> void:
	var ui := _make_ui()
	ui._setup_enemy_info(ENEMY_FIXTURE)
	var grid := _find_by_class(ui.enemy_info_panel, "GridContainer")
	assert_object(grid).override_failure_message(
		"enemy stat GridContainer not found under enemy_info_panel").is_not_null()
	var parent := grid.get_parent()
	assert_bool(parent is ScrollContainer).override_failure_message(
		"enemy GridContainer must be wrapped in a ScrollContainer for portrait swipe"
	).is_true()
	var scroll := parent as ScrollContainer
	assert_int(scroll.horizontal_scroll_mode).is_equal(ScrollContainer.SCROLL_MODE_AUTO)
	assert_int(scroll.vertical_scroll_mode).is_equal(ScrollContainer.SCROLL_MODE_DISABLED)


func test_crew_buttons_meet_touch_target_and_wrap() -> void:
	var ui := _make_ui()
	ui.setup_crew_selection([
		{"name": "Alice Longnameson the Considerably Verbose"},
		{"name": "Bob"},
		{"name": "Carol"},
	], 6)
	var buttons: Array = []
	_collect_toggle_buttons(ui.crew_selection_panel, buttons)
	assert_int(buttons.size()).is_greater_equal(3)
	for b in buttons:
		assert_int(int(b.custom_minimum_size.y)).override_failure_message(
			"crew button below 48px touch floor").is_greater_equal(48)
		assert_bool(b.autowrap_mode != TextServer.AUTOWRAP_OFF).override_failure_message(
			"crew button must wrap long names").is_true()


func _collect_toggle_buttons(root: Node, out: Array) -> void:
	for child in root.get_children():
		if child is Button and (child as Button).toggle_mode:
			out.append(child)
		_collect_toggle_buttons(child, out)


func test_selection_properties_preserved_and_auto_resolve_couples_tier() -> void:
	var ui := _make_ui()
	# The CampaignTurnController handoff reads these as script properties.
	assert_bool("selected_representation_mode" in ui).is_true()
	assert_bool("selected_tier" in ui).is_true()
	# Build the two decision cards (radios), then pick auto-resolve.
	ui._setup_mission_info(ENEMY_FIXTURE)
	assert_int(ui._tier_radios.size()).is_equal(3)
	ui._on_representation_radio_pressed("auto_resolve")
	for r in ui._tier_radios:
		assert_bool(r.disabled).override_failure_message(
			"tracking-tier radios must grey out under auto-resolve").is_true()
	assert_str(str(ui.selected_representation_mode)).is_equal("auto_resolve")
