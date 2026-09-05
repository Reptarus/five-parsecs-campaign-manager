extends GdUnitTestSuite
## ShipPanel must rebuild the traits LIST, never the section that contains it.
##
## THE BUG THIS PINS (2026-09-04). `_initialize_components()` resolved
## `content_node.get_node_or_null("Traits/Container")`. No such node exists —
## ShipPanel.tscn names the child `TraitsContainer` — so the lookup returned null
## and the code fell through to `get_node_or_null("Traits")`, which SUCCEEDS and
## binds the PARENT section.
##
## `_update_traits_display()` then does `for child in traits_container.get_children():
## child.queue_free()`, so every refresh freed the "Ship Traits:" header Label AND
## `%TraitsContainer` — the panel destroyed its own scene nodes, and any later
## `%TraitsContainer` lookup resolved a freed node.
##
## WHY A SCENE TEST AND NOT A SCRIPT TEST: the defect is entirely in the binding
## between ShipPanel.gd and ShipPanel.tscn. Instantiating the script alone has no
## `Traits` node at all, takes the `_create_traits_section()` fallback, and passes
## whether or not the bug is present. Testing the screen is the only way to see it
## (CLAUDE.md: "Test the SCREEN, not just the builder it calls").

const SHIP_PANEL_SCENE := "res://src/ui/screens/campaign/panels/ShipPanel.tscn"

## Located by NAME, never by path. ShipPanel._initialize_components()
## REPARENTS authored scene nodes into card containers (see the _reparent()
## calls around ShipPanel.gd:203), so the path the .tscn declares is only
## valid BEFORE the deferred init runs. A hardcoded path here passed
## pre-settle and failed post-settle, which reads like "the scene changed"
## when nothing had.
const TRAITS_SECTION_NAME := "Traits"


## NOTE: kept deliberately synchronous. Making this a coroutine (so it could
## await the settle itself) returns NULL to the caller even when awaited, which
## surfaces as "Cannot call method get_node_or_null on a null value". Each test
## awaits _settle() instead.
func _make_panel() -> Control:
	var packed: PackedScene = load(SHIP_PANEL_SCENE)
	assert_object(packed).override_failure_message(
		"ShipPanel.tscn failed to load — a parse error in ShipPanel.gd also lands here"
	).is_not_null()
	var panel: Control = packed.instantiate()
	add_child(panel)
	auto_free(panel)
	return panel


## ShipPanel._ready() ends with two call_deferred() callbacks, so the panel is
## still building on the frame after add_child(). A test that renders before that
## settles has its work silently overwritten by the deferred pass — observed
## live: freshly rendered trait rows were replaced by the empty-state Label,
## which reads exactly like "the render did nothing".
func _settle() -> void:
	await get_tree().process_frame


func _section(panel: Control) -> Node:
	return panel.find_child(TRAITS_SECTION_NAME, true, false)


func test_the_scene_still_has_the_shape_this_fix_assumes() -> void:
	# If someone renames these nodes, the rest of this suite would silently
	# stop testing anything, so assert the shape first.
	var panel := _make_panel()
	await _settle()
	var section := _section(panel)
	assert_object(section).override_failure_message(
		"ShipPanel.tscn no longer has a Traits section anywhere in the tree"
	).is_not_null()
	assert_object(section.get_node_or_null("Label")).override_failure_message(
		"the 'Ship Traits:' header Label is gone from the scene"
	).is_not_null()
	assert_object(section.get_node_or_null("TraitsContainer")).override_failure_message(
		"the child is named TraitsContainer — if it were named Container the"
		+ " original 'Traits/Container' lookup would have been correct"
	).is_not_null()
	# The node the buggy code was actually looking for must NOT exist; if it ever
	# does, this whole failure mode changes.
	assert_object(section.get_node_or_null("Container")).is_null()


func test_traits_container_binds_the_list_not_the_section() -> void:
	var panel := _make_panel()
	await _settle()
	var section := _section(panel)
	var bound: Node = panel.traits_container

	assert_object(bound).is_not_null()
	assert_str(str(bound.name)).override_failure_message(
		"traits_container must bind TraitsContainer. Binding the parent 'Traits'"
		+ " makes _update_traits_display() free the header and the container."
	).is_equal("TraitsContainer")
	assert_bool(bound == section).override_failure_message(
		"traits_container is the SECTION, not the list — this is the bug"
	).is_false()


func test_two_refreshes_do_not_destroy_the_scene_nodes() -> void:
	# The damage assertion. queue_free() is deferred, so a frame must pass
	# before is_instance_valid() can see it (CLAUDE.md: assert where the damage
	# lands, not where the call is made).
	var panel := _make_panel()
	await _settle()
	var section := _section(panel)
	var header: Node = section.get_node_or_null("Label")
	var list: Node = section.get_node_or_null("TraitsContainer")

	panel.ship_data["traits"] = ["armored", "dodgy_drive"]

	panel._update_traits_display()
	await get_tree().process_frame
	panel._update_traits_display()
	await get_tree().process_frame

	assert_bool(is_instance_valid(header)).override_failure_message(
		"the 'Ship Traits:' header Label was freed by a refresh"
	).is_true()
	assert_bool(is_instance_valid(list)).override_failure_message(
		"%TraitsContainer was freed by a refresh — every later unique-name"
		+ " lookup would resolve a dead node"
	).is_true()
	assert_object(section.get_node_or_null("Label")).is_not_null()
	assert_object(section.get_node_or_null("TraitsContainer")).is_not_null()


func test_a_refresh_still_renders_the_traits_into_the_list() -> void:
	# Guard against "fixing" the freeing by simply not rendering anything.
	var panel := _make_panel()
	await _settle()
	var section := _section(panel)
	var list: Node = section.get_node_or_null("TraitsContainer")

	panel.ship_data["traits"] = ["armored", "dodgy_drive"]
	panel._update_traits_display()
	await get_tree().process_frame

	assert_int(list.get_child_count()).override_failure_message(
		"the two ship traits must be rendered as children of TraitsContainer"
	).is_greater_equal(2)
	# ...and they must land in the LIST, not beside the header in the section.
	assert_int(section.get_child_count()).override_failure_message(
		"the section must still hold exactly its two scene children"
		+ " (Label + TraitsContainer) — trait rows belong inside the list"
	).is_equal(2)
