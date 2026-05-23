extends GdUnitTestSuite
## EntityCardActionsRow contract (Sprint 2 Item 6)
##
## Standardized verb-row component for entity cards. Pins down:
##   1. Canonical action IDs match the documented constants
##   2. default_actions() produces View / Edit / Remove (delete=true)
##   3. actions_with_print() adds the Print verb between Edit and Delete
##   4. setup() emits action_pressed with the action_id when a button is pressed
##   5. setup() is idempotent — calling twice clears prior buttons
##
## gdUnit4 v6.0.3 compatible.

const EntityCardActionsRowScript := preload("res://src/ui/components/common/EntityCardActionsRow.gd")


func test_action_ids_match_documented_constants() -> void:
	# Adopters reference these by name — guard against renames.
	assert_str(EntityCardActionsRowScript.ACTION_EDIT).is_equal("edit")
	assert_str(EntityCardActionsRowScript.ACTION_INSPECT).is_equal("inspect")
	assert_str(EntityCardActionsRowScript.ACTION_PRINT).is_equal("print")
	assert_str(EntityCardActionsRowScript.ACTION_DELETE).is_equal("delete")


func test_default_actions_produces_view_edit_remove() -> void:
	var actions: Array = EntityCardActionsRowScript.default_actions()
	assert_int(actions.size()).is_equal(3)
	assert_str(actions[0].id).is_equal("inspect")
	assert_str(actions[0].label).is_equal("View")
	assert_bool(actions[0].danger).is_false()
	assert_str(actions[1].id).is_equal("edit")
	assert_str(actions[1].label).is_equal("Edit")
	assert_str(actions[2].id).is_equal("delete")
	assert_str(actions[2].label).is_equal("Remove")
	assert_bool(actions[2].danger).is_true()


func test_actions_with_print_inserts_print_before_delete() -> void:
	var actions: Array = EntityCardActionsRowScript.actions_with_print()
	assert_int(actions.size()).is_equal(4)
	var ids: Array = []
	for a in actions:
		ids.append(a.id)
	assert_str(", ".join(ids)).is_equal("inspect, edit, print, delete")
	# Only the delete action carries the danger styling.
	assert_bool(actions[2].danger).is_false()
	assert_bool(actions[3].danger).is_true()


func test_setup_builds_buttons_and_emits_action_pressed() -> void:
	var row: HBoxContainer = EntityCardActionsRowScript.new()
	auto_free(row)
	add_child(row)
	row.setup(EntityCardActionsRowScript.default_actions())

	# Three buttons created with the right labels.
	assert_int(row.get_child_count()).is_equal(3)
	var labels: Array = []
	for child in row.get_children():
		labels.append((child as Button).text)
	assert_str(", ".join(labels)).is_equal("View, Edit, Remove")

	# Pressing the Edit button (idx 1) emits action_pressed("edit").
	var emitted: Array[String] = []
	row.action_pressed.connect(func(id): emitted.append(id))
	(row.get_child(1) as Button).pressed.emit()
	assert_int(emitted.size()).is_equal(1)
	assert_str(emitted[0]).is_equal("edit")


func test_setup_is_idempotent_clearing_prior_buttons() -> void:
	var row: HBoxContainer = EntityCardActionsRowScript.new()
	auto_free(row)
	add_child(row)
	row.setup(EntityCardActionsRowScript.actions_with_print())
	assert_int(row.get_child_count()).is_equal(4)
	# Re-setup with the smaller set should shrink, not append.
	row.setup(EntityCardActionsRowScript.default_actions())
	# queue_free is deferred — flush to confirm count after frame
	await get_tree().process_frame
	assert_int(row.get_child_count()).is_equal(3)
