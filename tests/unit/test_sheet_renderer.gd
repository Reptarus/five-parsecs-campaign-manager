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


## A crew_log context with EVERY addressed box populated.
##
## `_make_data_context()` fills three crew members with a name and a species, which
## leaves most of the sheet blank — and a blank field cannot overlap anything, so the
## overlap case measured a 1-pair margin against a real campaign's ~49. A detection
## proof is only as discriminating as its fixture, so this one fills all 8 slots (the
## manifest addresses `crew[0..6]` plus the captain) with stats, two weapons and text.
func _dense_data_context() -> Dictionary:
	var crew: Array = []
	for i in range(8):
		crew.append({
			"character_id": "char_%d" % i,
			# Long enough to exercise the widest boxes, as a real roster does.
			"character_name": "Character Number %d" % i,
			"species": "Genetic Uplift",
			"character_class": "Soldier",
			"reaction": 2, "speed": 5, "combat": 3,
			"toughness": 4, "savvy": 2, "luck": 1,
			"experience": 7,
			"gear_text": "Stim-pack, Camo Cloak",
			"notes": "Wounded in the last engagement",
			"weapons": [
				{"name": "Infantry Laser", "range": 30, "shots": 1,
					"damage": 0, "traits": "Snap Shot"},
				{"name": "Blast Pistol", "range": 8, "shots": 1,
					"damage": 1, "traits": "Pistol"},
			],
		})
	var ctx: Dictionary = _make_data_context()
	var campaign: Dictionary = ctx["campaign"]
	campaign["crew"] = crew
	campaign["captain"] = crew[0]
	campaign["stash_items_text"] = "Handgun, Blade, Colony Rifle"
	campaign["patrons_count"] = 2
	campaign["rivals_count"] = 1
	campaign["quest_rumors"] = 3
	campaign["notes"] = "Held the field at Gamma Prime"
	campaign["story_track_label"] = "The Signal"
	campaign["story_event"] = "Event 3"
	campaign["story_clock"] = 4
	campaign["ship"] = {
		"name": "Far Runner", "hull_current": 35, "debt": 49,
		"traits_text": "Fuel Hog", "upgrades_text": "Improved Shielding",
	}
	return ctx


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
	# Count the FIELD nodes, by their marker, anywhere in the subtree.
	#
	# This used to walk r.get_children() and skip TextureRects, i.e. it asserted a tree
	# SHAPE ("field nodes are direct children of the renderer") while claiming to test a
	# behaviour. The T11-06 fix moved the fields under a transformed FieldLayer and the
	# case went red with blank mode working perfectly. What matters is that no VALUE is
	# painted, so assert exactly that.
	assert_int(_visible_field_count(r)).is_equal(0) 		.override_failure_message(
			"blank_mode=true should hide all field overlays; %d still visible" 				% _visible_field_count(r))
	# Toggle back.
	r.set_blank_mode(false)
	assert_int(_visible_field_count(r)).is_greater(0) 		.override_failure_message(
			"blank_mode=false should restore field visibility")


## Visible Controls carrying the field marker, anywhere under `n`. A hidden ancestor
## hides its children, so `visible` alone would under-report — is_visible_in_tree() is
## what "the player can see this value" actually means.
func _visible_field_count(n: Node) -> int:
	var count: int = 0
	for child in n.get_children():
		if child is Control and (child as Control).has_meta("sheet_src_rect"):
			if (child as Control).is_visible_in_tree():
				count += 1
		count += _visible_field_count(child)
	return count


# ── T11-06: the field overlay is built at SOURCE scale ─────────────────────
#
# THE DEFECT, measured (tests/tools/probe_label_min_cache.gd):
# `add_theme_font_size_override()` INVALIDATES a Control's minimum-size cache but does
# not recompute it - the recomputation is deferred to the next frame. So `size = rect`
# on the following line is clamped up to the PREVIOUS font's line height. Reordering
# does not help: a brand-new, never-laid-out Label does the same thing, because its
# first minimum is computed with the theme's DEFAULT font. Every field Label therefore
# came out a flat 21 px tall at EVERY display scale, so on a phone the manifest boxes
# shrank with the sheet while the text boxes did not, and fields painted over each
# other - ~130 layout-sweep findings at the two smallest configs, none at desktop.
#
# The fix removes the dependency rather than fighting it: nodes are positioned and sized
# in SOURCE pixels with their manifest font, and the display scale is one transform on
# the FieldLayer. These two cases pin that, and are detection-proven by restoring the
# per-node scaling.

func test_field_nodes_keep_their_manifest_rect_at_every_display_size() -> void:
	var r: SheetRenderer = _make_renderer()
	r.render_sheet("crew_log", _make_data_context())
	# Sizes spanning the sweep, smallest first — the defect only bound once the sheet
	# was small enough for a box to fall under the default 21 px line height.
	for box in [Vector2(360, 640), Vector2(421, 362), Vector2(1280, 800),
			Vector2(1920, 1080)]:
		r.size = box
		var worst: float = 0.0
		var worst_name: String = ""
		for node in r._field_nodes:
			var src: Rect2 = node.get_meta("sheet_src_rect")
			var got := Rect2(node.position, node.size)
			var err: float = maxf(absf(got.size.x - src.size.x),
				absf(got.size.y - src.size.y))
			if err > worst:
				worst = err
				worst_name = "%s src=%s got=%s" % [node.name, src, got]
		assert_float(worst).is_less(0.01) 			.override_failure_message(
				("field rects must stay in SOURCE pixels at renderer size %s; " 				+ "worst error %.2f px on %s") % [box, worst, worst_name])


func test_no_two_populated_fields_overlap_at_a_phone_size() -> void:
	var r: SheetRenderer = _make_renderer()
	# The renderer's real box inside PrintSheetScreen at 851x393 (phone landscape),
	# measured with tests/tools/probe_sheet_field_geometry.gd. This is the config the
	# layout sweep failed on.
	r.size = Vector2(421, 362)
	r.render_sheet("crew_log", _dense_data_context())

	var rects: Array = []
	var names: Array = []
	for node in r._field_nodes:
		# A print form is MEANT to have empty boxes - a blank field paints nothing and
		# cannot cover a neighbour, so counting it would report the sheet as broken for
		# being blank. (CLAUDE.md: blank is a legitimate value, null is a bug.)
		var txt: String = ""
		if node is Label:
			txt = (node as Label).text
		elif node is RichTextLabel:
			txt = (node as RichTextLabel).text
		if txt.strip_edges().is_empty():
			continue
		var rect := Rect2(node.position, node.size)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		rects.append(rect)
		names.append(str(node.name))

	# A floor on the fixture itself. The first version of this case populated only 3
	# crew members and found a ONE-pair margin against the defect, which is the shape
	# that lets a detection proof quietly stop detecting.
	assert_int(rects.size()).is_greater(100) 		.override_failure_message(
			("fixture rendered only %d populated fields; this case needs a DENSE "
			+ "sheet or it stops discriminating") % rects.size())

	var collisions: Array = []
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			# grow(-0.5): a shared border is adjacency, not an overlap.
			if (rects[i] as Rect2).grow(-0.5).intersects((rects[j] as Rect2).grow(-0.5)):
				collisions.append("%s over %s" % [names[i], names[j]])
	assert_int(collisions.size()).is_equal(0) 		.override_failure_message(
			"populated fields must not overlap; %d pairs, first: %s" 				% [collisions.size(), collisions[0] if collisions.size() > 0 else ""])


func test_the_field_layer_carries_the_display_scale() -> void:
	var r: SheetRenderer = _make_renderer()
	r.render_sheet("crew_log", _make_data_context())
	r.size = Vector2(421, 362)
	var layer: Control = r.get_node_or_null("FieldLayer") as Control
	assert_object(layer).is_not_null() 		.override_failure_message("the renderer must own a FieldLayer")
	# The layer's transform IS the display scale — if these diverge the fields no longer
	# line up with the background PNG, which is the failure the shared _content_fit()
	# exists to prevent.
	assert_float(layer.scale.x).is_equal_approx(r._get_display_scale(), 0.0001)
	assert_float(layer.scale.y).is_equal_approx(r._get_display_scale(), 0.0001)
	assert_vector(layer.size).is_equal(Vector2(r.get_source_size()))


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
