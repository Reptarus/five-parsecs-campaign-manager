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


# ============================================================================
# _collect_text_layer — the PDF's invisible, searchable text layer
#
# The exported PDF embeds the sheet as a raster and lays an INVISIBLE text layer
# over it (PDF render mode 3), so the document is searchable and selectable
# without the printed pixels changing at all.
#
# The load-bearing property is WHERE the layer comes from: the nodes the
# SubViewport actually rasterized, never a second pass over the manifest. Two
# producers for one fact is the shape that has bitten this project repeatedly —
# the layer would keep asserting a value the picture no longer shows, and nothing
# would error. These build a SubViewport by hand (no rendering needed) so the
# derivation is pinned without depending on a framebuffer.
# ============================================================================

func _fake_export_viewport(entries: Array) -> SubViewport:
	# Mirrors what _render_offscreen() hands back: a SubViewport whose first
	# child is the renderer clone, whose Control children carry the field meta.
	var sub := SubViewport.new()
	var clone := Control.new()
	sub.add_child(clone)
	for e in entries:
		var lbl := Label.new()
		lbl.text = str(e.get("text", ""))
		lbl.horizontal_alignment = e.get("align", HORIZONTAL_ALIGNMENT_LEFT)
		lbl.set_meta("sheet_src_rect", e.get("rect", Rect2(10, 20, 100, 30)))
		lbl.set_meta("sheet_font_size", e.get("font_size", 22))
		clone.add_child(lbl)
	auto_free(sub)
	return sub


func test_collect_text_layer_reads_the_rasterized_nodes() -> void:
	var r: SheetRenderer = _make_renderer()
	var sub: SubViewport = _fake_export_viewport([
		{"text": "Bryn Ito", "rect": Rect2(171, 712, 300, 62), "font_size": 26},
	])
	var layer: Array = r._collect_text_layer(sub)
	assert_int(layer.size()).is_equal(1)
	assert_str(layer[0]["text"]).is_equal("Bryn Ito")
	assert_int(layer[0]["font_size"]).is_equal(26)
	# SOURCE-pixel rect, so the router can map it onto any page size.
	assert_vector(layer[0]["rect"].position).is_equal(Vector2(171, 712))


func test_collect_text_layer_skips_empty_values() -> void:
	# A blank weapon slot is correct output for an empty slot, but an empty
	# search token is noise that makes the layer disagree with the picture.
	var r: SheetRenderer = _make_renderer()
	var layer: Array = r._collect_text_layer(_fake_export_viewport([
		{"text": "Shotgun"}, {"text": ""}, {"text": "   "},
	]))
	assert_int(layer.size()).is_equal(1)
	assert_str(layer[0]["text"]).is_equal("Shotgun")


func test_collect_text_layer_carries_alignment_from_the_node() -> void:
	# Read off the node rather than re-read the manifest — same single-source rule.
	var r: SheetRenderer = _make_renderer()
	var layer: Array = r._collect_text_layer(_fake_export_viewport([
		{"text": "3", "align": HORIZONTAL_ALIGNMENT_CENTER},
		{"text": "12", "align": HORIZONTAL_ALIGNMENT_RIGHT},
		{"text": "Blade", "align": HORIZONTAL_ALIGNMENT_LEFT},
	]))
	assert_str(layer[0]["align"]).is_equal("center")
	assert_str(layer[1]["align"]).is_equal("right")
	assert_str(layer[2]["align"]).is_equal("left")


func test_collect_text_layer_is_empty_in_blank_mode() -> void:
	# "Print blank to fill in by hand" must not ship a HIDDEN copy of the data
	# the player explicitly asked to leave off the page. Invisible text is still
	# text: it survives copy-paste, search and text extraction.
	var r: SheetRenderer = _make_renderer()
	r.set_blank_mode(true)
	var layer: Array = r._collect_text_layer(_fake_export_viewport([
		{"text": "Bryn Ito"}, {"text": "Shotgun"},
	]))
	assert_int(layer.size()).is_equal(0) \
		.override_failure_message(
			"Blank mode leaked %d values into the PDF's hidden text layer" % layer.size())


func test_collect_text_layer_tolerates_a_missing_clone() -> void:
	var r: SheetRenderer = _make_renderer()
	assert_int(r._collect_text_layer(null).size()).is_equal(0)
	var empty := SubViewport.new()
	auto_free(empty)
	assert_int(r._collect_text_layer(empty).size()).is_equal(0)
