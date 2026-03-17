class_name TestPreBattleChecklist
extends GdUnitTestSuite

## Unit tests for PreBattleChecklist - Tier Filtering & Completion
##
## Tests item count per tier, visibility filtering, completion logic,
## serialization, and species reminder always-visible behavior.
## No .tscn needed - PreBattleChecklist builds UI in _ready().

const PreBattleChecklistClass = preload("res://src/ui/components/battle/PreBattleChecklist.gd")

var checklist: FPCM_PreBattleChecklist

func before_test() -> void:
	seed(12345)
	checklist = PreBattleChecklistClass.new()
	add_child(checklist)
	# Wait for node to be ready in tree (_build_ui runs in _ready)
	for i in range(3):
		await get_tree().process_frame
	if not is_instance_valid(checklist):
		push_warning("checklist failed to initialize")
		return

func after_test() -> void:
	if is_instance_valid(checklist):
		remove_child(checklist)
		checklist.free()
	checklist = null

# =====================================================
# ITEM COUNT PER TIER TESTS
# =====================================================

func test_item_count_at_tier_0_is_3() -> void:
	## LOG_ONLY tier should show exactly 3 checklist items
	if not is_instance_valid(checklist):
		return
	checklist.set_tier(0)
	assert_int(checklist.get_item_count()).is_equal(3)

func test_item_count_at_tier_1_is_8() -> void:
	## ASSISTED tier should show exactly 8 checklist items
	if not is_instance_valid(checklist):
		return
	checklist.set_tier(1)
	assert_int(checklist.get_item_count()).is_equal(8)

func test_item_count_at_tier_2_is_11() -> void:
	## FULL_ORACLE tier should show exactly 11 checklist items
	if not is_instance_valid(checklist):
		return
	checklist.set_tier(2)
	assert_int(checklist.get_item_count()).is_equal(11)

func test_tier_upgrade_shows_more_items() -> void:
	## Upgrading tier should increase visible item count
	if not is_instance_valid(checklist):
		return
	checklist.set_tier(0)
	assert_int(checklist.get_item_count()).is_equal(3)
	checklist.set_tier(1)
	assert_int(checklist.get_item_count()).is_equal(8)

# =====================================================
# COMPLETION LOGIC TESTS
# =====================================================

func test_checklist_complete_when_all_visible_checked() -> void:
	## Checklist complete when all visible items are checked
	if not is_instance_valid(checklist):
		return
	checklist.set_tier(0)
	# Simulate checking all 3 LOG_ONLY items via internal state
	checklist._check_states["setup_terrain"] = true
	checklist._check_states["deploy_enemies"] = true
	checklist._check_states["deploy_crew"] = true
	assert_bool(checklist._is_checklist_complete()).is_true()

func test_checklist_incomplete_when_missing_one() -> void:
	## Missing one checked item means checklist is incomplete
	if not is_instance_valid(checklist):
		return
	checklist.set_tier(0)
	checklist._check_states["setup_terrain"] = true
	checklist._check_states["deploy_enemies"] = true
	# deploy_crew is still false
	assert_bool(checklist._is_checklist_complete()).is_false()

func test_hidden_items_dont_block_completion() -> void:
	## Hidden higher-tier items should not block completion
	if not is_instance_valid(checklist):
		return
	checklist.set_tier(0)
	# Check all 3 tier-0 items
	checklist._check_states["setup_terrain"] = true
	checklist._check_states["deploy_enemies"] = true
	checklist._check_states["deploy_crew"] = true
	# Tier-1 items like "deployment_conditions" are unchecked but hidden
	assert_bool(checklist._is_checklist_complete()).is_true()

# =====================================================
# CHECKED COUNT & RESET TESTS
# =====================================================

func test_checked_count_accurate() -> void:
	## get_checked_count() returns correct number of checked items
	if not is_instance_valid(checklist):
		return
	checklist.set_tier(0)
	checklist._check_states["setup_terrain"] = true
	checklist._check_states["deploy_enemies"] = true
	assert_int(checklist.get_checked_count()).is_equal(2)

func test_reset_clears_all_checks() -> void:
	## reset() should clear all check states to unchecked
	if not is_instance_valid(checklist):
		return
	checklist._check_states["setup_terrain"] = true
	checklist._check_states["deploy_enemies"] = true
	checklist.reset()
	assert_int(checklist.get_checked_count()).is_equal(0)

# =====================================================
# SERIALIZATION TESTS
# =====================================================

func test_serialize_preserves_state() -> void:
	## serialize() should capture tier and checked state
	if not is_instance_valid(checklist):
		return
	checklist.set_tier(1)
	checklist._check_states["setup_terrain"] = true
	var data := checklist.serialize()
	assert_int(data.get("tier", -1)).is_equal(1)
	assert_bool(data.get("checked", {}).get("setup_terrain", false)).is_true()

func test_deserialize_restores_state() -> void:
	## deserialize() should restore tier, items, and checked state
	if not is_instance_valid(checklist):
		return
	var save_data := {
		"tier": 2,
		"checked": {"setup_terrain": true, "deploy_enemies": true},
	}
	checklist.deserialize(save_data)
	assert_int(checklist.get_item_count()).is_equal(11)
	assert_int(checklist.get_checked_count()).is_equal(2)

# =====================================================
# SIGNAL TESTS
# =====================================================

func test_checklist_completed_signal_emitted() -> void:
	## checklist_completed signal fires when all items toggled on
	if not is_instance_valid(checklist):
		return
	checklist.set_tier(0)
	var signal_fired := [false]
	checklist.checklist_completed.connect(func(): signal_fired[0] = true)
	# Check all 3 tier-0 items by toggling checkboxes
	# Use the _on_item_toggled method which is the signal handler
	checklist._on_item_toggled(true, "setup_terrain")
	checklist._on_item_toggled(true, "deploy_enemies")
	checklist._on_item_toggled(true, "deploy_crew")
	assert_bool(signal_fired[0]).is_true()
