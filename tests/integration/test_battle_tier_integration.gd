class_name TestBattleTierIntegration
extends GdUnitTestSuite

## Integration tests for Battle Tier System - End-to-End
##
## Tests tier controller â†’ checklist propagation, tab visibility logic,
## tier badge rendering, mid-battle upgrade flow, and cross-component
## state consistency.
##
## Uses lightweight mock TabContainers instead of full TacticalBattleUI.tscn
## to avoid fragile scene dependencies in headless test mode.

const BattleTierControllerClass = preload("res://src/core/battle/BattleTierController.gd")
const PreBattleChecklistClass = preload("res://src/ui/components/battle/PreBattleChecklist.gd")

var controller: FPCM_BattleTierController
var checklist: FPCM_PreBattleChecklist

# Mock tab containers to test visibility logic
var left_tabs: TabContainer
var center_tabs: TabContainer
var tier_badge: Label

func before_test() -> void:
	seed(12345)
	controller = BattleTierControllerClass.new()

	checklist = PreBattleChecklistClass.new()
	add_child(checklist)

	# Create mock tab containers matching TacticalBattleUI structure
	left_tabs = TabContainer.new()
	left_tabs.name = "LeftTabs"
	add_child(left_tabs)
	# Add 3 tabs: Crew (0), Units (1), Enemies (2)
	for tab_name in ["Crew", "Units", "Enemies"]:
		var panel := PanelContainer.new()
		panel.name = tab_name
		left_tabs.add_child(panel)

	center_tabs = TabContainer.new()
	center_tabs.name = "CenterTabs"
	add_child(center_tabs)
	# Add 3 tabs: BattleLog (0), Tracking (1), Events (2)
	for tab_name in ["BattleLog", "Tracking", "Events"]:
		var panel := PanelContainer.new()
		panel.name = tab_name
		center_tabs.add_child(panel)

	tier_badge = Label.new()
	tier_badge.name = "TierBadge"
	add_child(tier_badge)

	# Wait for nodes to initialize
	for i in range(3):
		await get_tree().process_frame

func after_test() -> void:
	controller = null
	if is_instance_valid(checklist):
		remove_child(checklist)
		checklist.queue_free()
	checklist = null
	if is_instance_valid(left_tabs):
		remove_child(left_tabs)
		left_tabs.queue_free()
	left_tabs = null
	if is_instance_valid(center_tabs):
		remove_child(center_tabs)
		center_tabs.queue_free()
	center_tabs = null
	if is_instance_valid(tier_badge):
		remove_child(tier_badge)
		tier_badge.queue_free()
	tier_badge = null

## Helper: apply tier visibility (mirrors TacticalBattleUI._apply_tier_visibility)
func _apply_tier_visibility(tier: int) -> void:
	var show_assisted := tier >= 1
	var show_oracle := tier >= 2
	if left_tabs:
		left_tabs.set_tab_hidden(1, not show_assisted)
		left_tabs.set_tab_hidden(2, not show_oracle)
	if center_tabs:
		center_tabs.set_tab_hidden(1, not show_assisted)
		center_tabs.set_tab_hidden(2, not show_assisted)
	if tier_badge:
		match tier:
			0: tier_badge.text = "[LOG ONLY]"
			1: tier_badge.text = "[ASSISTED]"
			2: tier_badge.text = "[FULL ORACLE]"

# =====================================================
# CONTROLLER â†’ CHECKLIST PROPAGATION TESTS
# =====================================================

func test_tier_controller_propagates_to_checklist() -> void:
	## Controller tier change propagates correct item count to checklist
	if not is_instance_valid(checklist):
		return
	controller.set_tier(FPCM_BattleTierController.TrackingTier.ASSISTED, true)
	checklist.set_tier(controller.get_current_tier())
	assert_int(checklist.get_item_count()).is_equal(8)

func test_tier_controller_upgrade_propagates() -> void:
	## Upgrading controller tier updates checklist item count
	if not is_instance_valid(checklist):
		return
	controller.set_tier(FPCM_BattleTierController.TrackingTier.LOG_ONLY, true)
	checklist.set_tier(controller.get_current_tier())
	assert_int(checklist.get_item_count()).is_equal(3)

	controller.set_tier(FPCM_BattleTierController.TrackingTier.FULL_ORACLE)
	checklist.set_tier(controller.get_current_tier())
	assert_int(checklist.get_item_count()).is_equal(11)

# =====================================================
# TAB VISIBILITY TESTS
# =====================================================

func test_tier_0_hides_units_and_enemies_tabs() -> void:
	## LOG_ONLY hides Units and Enemies tabs in left panel
	if not is_instance_valid(left_tabs):
		return
	_apply_tier_visibility(0)
	assert_bool(left_tabs.is_tab_hidden(1)).is_true()
	assert_bool(left_tabs.is_tab_hidden(2)).is_true()

func test_tier_0_hides_center_tracking_and_events() -> void:
	## LOG_ONLY hides Tracking and Events in center panel
	if not is_instance_valid(center_tabs):
		return
	_apply_tier_visibility(0)
	assert_bool(center_tabs.is_tab_hidden(1)).is_true()
	assert_bool(center_tabs.is_tab_hidden(2)).is_true()

func test_tier_1_shows_units_hides_enemies() -> void:
	## ASSISTED shows Units tab but keeps Enemies hidden
	if not is_instance_valid(left_tabs):
		return
	_apply_tier_visibility(1)
	assert_bool(left_tabs.is_tab_hidden(1)).is_false()  # Units visible
	assert_bool(left_tabs.is_tab_hidden(2)).is_true()    # Enemies hidden

func test_tier_1_shows_center_tracking_and_events() -> void:
	## ASSISTED shows Tracking and Events in center panel
	if not is_instance_valid(center_tabs):
		return
	_apply_tier_visibility(1)
	assert_bool(center_tabs.is_tab_hidden(1)).is_false()
	assert_bool(center_tabs.is_tab_hidden(2)).is_false()

func test_tier_2_shows_all_left_tabs() -> void:
	## FULL_ORACLE shows all left panel tabs
	if not is_instance_valid(left_tabs):
		return
	_apply_tier_visibility(2)
	assert_bool(left_tabs.is_tab_hidden(0)).is_false()  # Crew
	assert_bool(left_tabs.is_tab_hidden(1)).is_false()  # Units
	assert_bool(left_tabs.is_tab_hidden(2)).is_false()  # Enemies

# =====================================================
# TIER BADGE TESTS
# =====================================================

func test_tier_badge_text_log_only() -> void:
	## Tier badge displays "[LOG ONLY]" at tier 0
	if not is_instance_valid(tier_badge):
		return
	_apply_tier_visibility(0)
	assert_str(tier_badge.text).is_equal("[LOG ONLY]")

func test_tier_badge_text_assisted() -> void:
	## Tier badge displays "[ASSISTED]" at tier 1
	if not is_instance_valid(tier_badge):
		return
	_apply_tier_visibility(1)
	assert_str(tier_badge.text).is_equal("[ASSISTED]")

func test_tier_badge_text_full_oracle() -> void:
	## Tier badge displays "[FULL ORACLE]" at tier 2
	if not is_instance_valid(tier_badge):
		return
	_apply_tier_visibility(2)
	assert_str(tier_badge.text).is_equal("[FULL ORACLE]")

# =====================================================
# MID-BATTLE UPGRADE FLOW TESTS
# =====================================================

func test_mid_battle_upgrade_updates_visibility() -> void:
	## Mid-battle tier upgrade reveals previously hidden tabs
	if not is_instance_valid(left_tabs):
		return
	# Start at LOG_ONLY
	_apply_tier_visibility(0)
	assert_bool(left_tabs.is_tab_hidden(1)).is_true()  # Units hidden

	# Upgrade to ASSISTED mid-battle
	controller.set_tier(FPCM_BattleTierController.TrackingTier.ASSISTED)
	_apply_tier_visibility(controller.get_current_tier())
	assert_bool(left_tabs.is_tab_hidden(1)).is_false()  # Units now visible

func test_failed_downgrade_preserves_visibility() -> void:
	## Failed downgrade attempt preserves current tab visibility
	if not is_instance_valid(left_tabs):
		return
	# Start at FULL_ORACLE
	controller.set_tier(FPCM_BattleTierController.TrackingTier.FULL_ORACLE, true)
	_apply_tier_visibility(controller.get_current_tier())
	assert_bool(left_tabs.is_tab_hidden(2)).is_false()  # Enemies visible

	# Attempt downgrade (should fail)
	controller.set_tier(FPCM_BattleTierController.TrackingTier.LOG_ONLY)
	# Re-apply visibility with current (unchanged) tier
	_apply_tier_visibility(controller.get_current_tier())
	assert_bool(left_tabs.is_tab_hidden(2)).is_false()  # Enemies still visible
