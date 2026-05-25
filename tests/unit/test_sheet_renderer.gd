extends GdUnitTestSuite
## Tests for SheetRenderer — the Control that overlays player data onto an
## official Modiphius sheet PNG.
##
## Coverage:
##   - render_sheet() loads manifest, builds field nodes, populates background
##   - _resolve_source() handles dot-notation paths and [N] array access
##   - set_blank_mode() and set_debug_overlay() toggle without crash
##   - export_to_png() returns ERR_UNCONFIGURED when no manifest loaded
##   - get_source_size() reflects the manifest's source_size after load
##
## Notes:
##   - PNG export itself isn't unit-tested (it depends on the SubViewport
##     await frame_post_draw cycle, which needs a real render loop). It's
##     covered by the MCP runtime verification instead.
##   - Renderer must be add_child()'d before render_sheet() so _ready runs
##     and the background TextureRect can be created.

const SheetRenderer := preload("res://src/ui/components/sheet/SheetRenderer.gd")
const FiveParsecsCampaignCore := preload(
	"res://src/game/campaign/FiveParsecsCampaignCore.gd")


# ============================================================================
# Helpers
# ============================================================================

func _make_renderer() -> SheetRenderer:
	var r: SheetRenderer = SheetRenderer.new()
	add_child(r)
	# Give it a non-zero size so _scale_rect_to_display doesn't divide-by-zero.
	r.size = Vector2(800, 600)
	return r


func _make_data_context() -> Dictionary:
	# Mirrors what PrintSheetScreen._build_data_context() produces, but with
	# a stub campaign + world dict so we don't depend on a live game state.
	var captain: Dictionary = {
		"character_id": "char_captain",
		"character_name": "Yuri",
		"species": "Human",
		"character_class": "Soldier",
	}
	var crew: Array = [
		captain,
		{"character_name": "Beta", "species": "K'Erin"},
		{"character_name": "Gamma", "species": "Engineer"},
	]
	return {
		"campaign": {
			"captain": captain,
			"crew": crew,
			"campaign_name": "Test Campaign",
			"credits": 42,
			"story_points": 3,
			"ship": {"name": "The Beagle"},
		},
		"world": {
			"name": "Kepler-9c",
			"traits": ["Barren", "Cold"],
		},
		"journal": {
			"last_battle": {
				"location": "Abandoned Outpost",
				"outcome": "Victory",
			},
		},
	}


# ============================================================================
# render_sheet — basic happy path
# ============================================================================

func test_render_sheet_with_known_id_loads_manifest() -> void:
	var r: SheetRenderer = _make_renderer()
	r.render_sheet("crew_log", _make_data_context())
	# After load, source size matches the Core Rulebook PNG dimensions.
	var size: Vector2i = r.get_source_size()
	assert_int(size.x).is_equal(2764) \
		.override_failure_message(
			"crew_log source_size.x should be 2764, got %d" % size.x)
	assert_int(size.y).is_equal(1843) \
		.override_failure_message(
			"crew_log source_size.y should be 1843, got %d" % size.y)


func test_render_sheet_with_unknown_id_no_crash() -> void:
	# Defensive: typo'd or future sheet_id must not crash the renderer.
	var r: SheetRenderer = _make_renderer()
	r.render_sheet("nonexistent_sheet", _make_data_context())
	# Source size stays at the default since manifest didn't load.
	var size: Vector2i = r.get_source_size()
	assert_int(size.x).is_equal(2764)


func test_render_sheet_populates_field_nodes_for_known_sheet() -> void:
	# After render, the renderer should have child nodes for fields PLUS the
	# background TextureRect. Verifying child_count > 1 is enough to know the
	# field-node loop ran.
	var r: SheetRenderer = _make_renderer()
	r.render_sheet("crew_log", _make_data_context())
	# Background + at least one field overlay node.
	assert_int(r.get_child_count()).is_greater(1) \
		.override_failure_message(
			"Expected background + field nodes; got %d children" \
				% r.get_child_count())


# ============================================================================
# _resolve_source — dot notation + array index
# ============================================================================

func test_resolve_source_simple_property() -> void:
	var r: SheetRenderer = _make_renderer()
	var ctx: Dictionary = _make_data_context()
	var value: Variant = r._resolve_source("campaign.campaign_name", ctx)
	assert_str(str(value)).is_equal("Test Campaign")


func test_resolve_source_nested_property() -> void:
	var r: SheetRenderer = _make_renderer()
	var ctx: Dictionary = _make_data_context()
	var value: Variant = r._resolve_source(
		"campaign.captain.character_name", ctx)
	assert_str(str(value)).is_equal("Yuri")


func test_resolve_source_array_index() -> void:
	var r: SheetRenderer = _make_renderer()
	var ctx: Dictionary = _make_data_context()
	var value: Variant = r._resolve_source(
		"campaign.crew[1].character_name", ctx)
	assert_str(str(value)).is_equal("Beta")


func test_resolve_source_world_traits_array() -> void:
	var r: SheetRenderer = _make_renderer()
	var ctx: Dictionary = _make_data_context()
	var value: Variant = r._resolve_source("world.traits[0]", ctx)
	assert_str(str(value)).is_equal("Barren")


func test_resolve_source_missing_property_returns_null() -> void:
	var r: SheetRenderer = _make_renderer()
	var ctx: Dictionary = _make_data_context()
	var value: Variant = r._resolve_source("campaign.does_not_exist", ctx)
	assert_object(value).is_null()


func test_resolve_source_out_of_range_index_returns_null() -> void:
	var r: SheetRenderer = _make_renderer()
	var ctx: Dictionary = _make_data_context()
	var value: Variant = r._resolve_source("campaign.crew[99]", ctx)
	assert_object(value).is_null()


func test_resolve_source_empty_path_returns_null() -> void:
	var r: SheetRenderer = _make_renderer()
	var ctx: Dictionary = _make_data_context()
	var value: Variant = r._resolve_source("", ctx)
	assert_object(value).is_null()


# ============================================================================
# Toggle controls — no crash, observable effect
# ============================================================================

func test_set_blank_mode_toggles_field_visibility() -> void:
	var r: SheetRenderer = _make_renderer()
	r.render_sheet("crew_log", _make_data_context())
	r.set_blank_mode(true)
	# All field nodes hidden after blank mode toggled on.
	var visible_count: int = 0
	for child in r.get_children():
		# Skip the background — it remains visible in blank mode.
		if child is TextureRect:
			continue
		if (child as Control).visible:
			visible_count += 1
	assert_int(visible_count).is_equal(0) \
		.override_failure_message(
			"blank_mode=true should hide all field overlays; %d still visible" \
				% visible_count)
	# Toggle back.
	r.set_blank_mode(false)
	visible_count = 0
	for child in r.get_children():
		if child is TextureRect:
			continue
		if (child as Control).visible:
			visible_count += 1
	assert_int(visible_count).is_greater(0) \
		.override_failure_message(
			"blank_mode=false should restore field visibility")


func test_set_debug_overlay_does_not_crash() -> void:
	var r: SheetRenderer = _make_renderer()
	r.render_sheet("crew_log", _make_data_context())
	r.set_debug_overlay(true)
	r.set_debug_overlay(false)
	# Reaching here without crash is the assertion. _draw is verified
	# visually via the MCP runtime test (debug-overlay toggle button).
	assert_bool(true).is_true()


# ============================================================================
# export_to_png — pre-render guard
# ============================================================================

func test_export_to_png_without_manifest_returns_unconfigured() -> void:
	var r: SheetRenderer = _make_renderer()
	# No render_sheet() call — manifest is empty.
	var err: Error = await r.export_to_png("user://_unit_test_should_not_exist.png")
	assert_int(err).is_equal(ERR_UNCONFIGURED) \
		.override_failure_message(
			"Export without manifest should return ERR_UNCONFIGURED, got %d" % err)


func test_export_to_pdf_without_manifest_returns_unconfigured() -> void:
	var r: SheetRenderer = _make_renderer()
	var err: Error = await r.export_to_pdf("user://_unit_test_should_not_exist.pdf")
	assert_int(err).is_equal(ERR_UNCONFIGURED) \
		.override_failure_message(
			"Export without manifest should return ERR_UNCONFIGURED, got %d" % err)
