extends GdUnitTestSuite
## T9-09 (Aug 9 2026): every `source` in a sheet manifest must RESOLVE, not merely exist.
##
## Found on hardware: the Print Sheet screen rendered every one of the crew log's 144
## fields BLANK against a fully-populated campaign (6 crew, 23 credits, ship "Far
## Runner"). The debug overlay drew all 144 rects perfectly calibrated, so the manifest
## loaded and the geometry was right — the VALUES resolved to null. Measured before the
## fix: **154 of 163 sources resolved to NULL**.
##
## Cause: the manifests address a view-model (`campaign.crew[2].weapons[0].damage`) that
## nothing built; the raw campaign has `crew_data["members"]`. `SheetDataContext` is that
## view-model.
##
## WHY THE EXISTING SUITE COULD NOT SEE IT. `tests/unit/test_sheet_field_mapping.gd` is
## green and its docblock claims to catch "a misspelled source path", but
## `test_non_checkbox_fields_have_non_empty_source` only asserts the string is NON-EMPTY.
## "campaign.captain.name" passes that and renders nothing. Textbook
## [[reference_a_green_test_can_detect_nothing]] — assert where the damage lands, which
## here means running the REAL resolver against a REAL campaign.
##
## Note the two halves below are both needed. Resolution-only would pass trivially if the
## builder returned "" for everything; value assertions alone would not catch a typo in a
## field nobody spot-checks.
##
## gdUnit4 v6.0.3. NOTE: run with -c, never --headless (project rule).

const SheetRendererScript = preload("res://src/ui/components/sheet/SheetRenderer.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")
const SheetDataContextScript = preload("res://src/core/export/SheetDataContext.gd")
const PdfExportRouterScript = preload("res://src/core/export/PdfExportRouter.gd")
const CampaignJournalScript = preload("res://src/core/campaign/CampaignJournal.gd")
const PlanetDataManagerScript = preload("res://src/core/world/PlanetDataManager.gd")

const MANIFEST_PATHS: Array[String] = [
	"res://data/sheets/core/crew_log_fields.json",
	"res://data/sheets/core/encounter_log_fields.json",
	"res://data/sheets/core/world_record_sheet_fields.json",
]


func _member(n: String, captain: bool, combat: int, equipment: Array) -> Dictionary:
	return {
		"character_name": n, "name": n, "is_captain": captain,
		"species_id": "human", "combat": combat, "reaction": 2, "toughness": 4,
		"speed": 5, "savvy": 2, "luck": 1, "experience": 6,
		"player_notes": "note-%s" % n, "equipment": equipment,
	}


func _make_campaign() -> Resource:
	var c: Resource = CampaignCore.new()
	c.campaign_name = "Test Crew"
	c.credits = 23
	c.story_points = 9
	c.ship_debt = 49
	c.patrons = []
	c.rivals = [{"name": "Feral Jackals"}]
	# Captain + 7 crew so every crew[0..6] slot the manifest addresses is populated.
	# A real campaign caps at 6; using 8 here tests the MAPPING, not the fixture size.
	# The captain carries a weapon AND a gear item: the Crew Log prints them in two
	# different boxes, so a captain holding only a weapon leaves gear_text blank and
	# the sheet's gear column goes untested.
	var members: Array = [_member("Bryn Ito", true, 3, ["Shatter Axe", "Sonic Emitter"])]
	for i in range(7):
		members.append(_member("Crew %d" % i, false, i, ["Blade", "Sonic Emitter"]))
	c.crew_data = {"members": members}
	c.captain_data = members[0]
	c.ship_data = {"name": "Far Runner", "hull_points": 35, "traits": ["Fuel Hog"]}
	c.equipment_data = {"equipment": ["Handgun"]}
	c.quest_rumors = 3
	c.story_track_enabled = true
	# The story-track keys are StoryTrackSystem.serialize()'s OWN names. Writing the
	# real names here is the point of the fixture: the builder used to read `clock`
	# and `current_event_name`, which nothing has ever written.
	c.progress_data = {
		"turns_played": 8,
		"story_track": {
			"is_story_track_active": true,
			"current_event_index": 2,   # 0-based -> event 3 on the printed sheet
			"story_clock_ticks": 4,
		},
		# InterdictionRule's own record (Core Rules p.75), written on EVERY arrival.
		# The World Record Sheet's "Licensing Required" octagons are derived from it:
		# active -> Yes, active+licensed -> Obtained, not active -> No.
		"interdiction": {"active": true, "until_turn": 10, "licensed": true},
	}
	# This world is being fought over (Core Rules p.126 step 14). war_modifier is the
	# accumulated "Making Ground" +1, which is the only trace that result leaves.
	c.invaded_planets = [
		{"id": "gamma_prime", "name": "Gamma Prime", "war_modifier": 1}]
	return c


## The world the sheets are printed against — a REAL `PlanetData`, which is what
## `PlanetDataManager.get_current_planet()` hands PrintSheetScreen.
##
## It used to be a hand-built Dictionary. That is not the producer's type: PlanetData
## is an OBJECT with property access, and the builder's `world is Dictionary` check
## silently threw it away, so World Name and World Traits printed blank on device for
## every campaign while this suite was green. Same fabricated-fixture failure as the
## journal entry above.
##
## `id` matters: the Invasion Status block joins on the planet id.
func _world() -> Object:
	var p: Object = PlanetDataManagerScript.PlanetData.new("gamma_prime")
	p.name = "Gamma Prime"
	p.type_name = "High Cost"
	p.danger_level = 3
	# traits is Array[String]; a plain `=` from an untyped literal aborts in Godot 4.6.
	p.traits.assign(["High Cost", "Booming Trade", "Fringe"])
	return p


## Build the battle journal entry THE WAY THE APP BUILDS IT, through the real producer.
##
## This fixture used to be hand-written as
##   {"type": "battle", "mission_type": "Patrol", "enemy_faction": "Raiders", ...}
## — a shape `CampaignJournal.create_entry()` can never produce. It assembles every
## entry from a FIXED key set (id/turn_number/timestamp/type/title/description/mood/
## tags/characters_involved/location/photos/stats/player_notes) and DROPS everything
## else, so those keys existed only in this file. The Encounter Log read them off the
## entry's top level, got "" (a legal blank on a print form, not null), and five of its
## six boxes printed empty on every real campaign while this suite stayed green.
##
## Going through auto_create_battle_entry() is the only version that cannot drift: if
## the entry's key set changes, this fixture changes with it.
func _battle_entries() -> Array:
	var journal: Node = CampaignJournalScript.new()
	add_child(journal)
	auto_free(journal)
	journal.auto_create_battle_entry({
		"outcome": "Victory",
		# p.94-103 encounter tables: the CATEGORY is the sheet's "Encounter Type";
		# the individual name belongs in the Enemy Types table.
		"enemy_category": "Criminal Elements",
		"enemy_type": "Gangers",
		"mission_type": "Patron",
		"objective_id": "patrol",
		"enemy_count": 7,
		"deployment_condition": {
			"condition_id": "poor_visibility", "title": "Poor Visibility"},
		"notable_sight": {"type": "SHINY_BITS", "effect": "Gain 1 credit.", "roll": 55},
		"location": "Gamma Prime",
		"xp": 3,
	})
	return journal.get_all_entries()


func _ctx() -> Dictionary:
	SheetDataContextScript.reset_cache()
	return SheetDataContextScript.build(_make_campaign(), _world(), _battle_entries())


## Same fixture as _ctx(), but for a caller that needs to vary the campaign.
func _ctx_for(c: Resource) -> Dictionary:
	SheetDataContextScript.reset_cache()
	return SheetDataContextScript.build(c, _world(), _battle_entries())


func _renderer() -> Node:
	var r: Node = SheetRendererScript.new()
	add_child(r)
	auto_free(r)
	return r


func _load_manifest(path: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed as Dictionary if parsed is Dictionary else {}


## The story-track row on the Crew Log: Story Track | Event | Clock | Quest Rumors.
##
## Every one of these was wrong on device (Aug 9 2026) in a different way, and all
## four failures LOOKED like "the campaign has no story track":
##   - the clock read `clock` and the label read `current_event_name`; the persisted
##     keys are `story_clock_ticks` and `current_event_index`, so both were always ""
##   - the "Event" box was mapped to `campaign.ship.fuel`, a field that is deliberately
##     blank, which is why nobody noticed the box belonged to something else
##   - the "Quest Rumors" box had no manifest field at all
##
## Asserting VALUES here, not just resolvability — a blank string resolves perfectly.
func test_the_story_track_row_reads_the_keys_the_story_track_actually_writes() -> void:
	var ctx: Dictionary = _ctx()
	var campaign: Dictionary = ctx.get("campaign", {})

	assert_int(int(campaign.get("story_clock", -1))).override_failure_message(
		"story_clock must read progress_data.story_track.story_clock_ticks " +
		"(StoryTrackSystem.serialize()), not a key nothing writes."
	).is_equal(4)
	assert_int(int(campaign.get("story_event", -1))).override_failure_message(
		"story_event must be the 1-BASED event number; current_event_index 2 is event 3."
	).is_equal(3)
	assert_str(str(campaign.get("story_track_label", ""))).override_failure_message(
		"story_track_label should name event 3 from its own JSON."
	).is_equal("Disrupting the Plan")
	assert_int(int(campaign.get("quest_rumors", -1))).override_failure_message(
		"quest_rumors must come from the campaign; the artwork prints a box for it."
	).is_equal(3)


## The manifest must address the artwork's boxes, not a field someone assumed was
## there. `ship_fuel` sat on the box printed "Event" for as long as it resolved blank.
func test_the_story_row_manifest_ids_match_the_printed_artwork() -> void:
	var manifest: Dictionary = _load_manifest("res://data/sheets/core/crew_log_fields.json")
	var by_x: Dictionary = {}
	for raw in manifest.get("fields", []):
		var f: Dictionary = raw
		var rect: Array = f.get("rect", [])
		if rect.size() >= 4 and int(rect[1]) > 500 and int(rect[1]) < 560:
			by_x[int(rect[0])] = str(f.get("id", ""))
	# x positions and captions read off assets/sheets/core/crew_log.png (2764px wide).
	for expected: Array in [
		[1875, "story_track", "Story Track"], [2244, "story_event", "Event"],
		[2379, "story_clock", "Clock"], [2520, "quest_rumors", "Quest Rumors"],
	]:
		assert_str(str(by_x.get(int(expected[0]), "<no field>"))).override_failure_message(
			"The box at x=%d is printed '%s' on the sheet artwork, so its field must be '%s'." % [
				int(expected[0]), str(expected[2]), str(expected[1])]
		).is_equal(str(expected[1]))


## The printed weapon table is ONE box with five columns and TWO writing rows, i.e. two
## weapon slots per character (measured off the artwork, Aug 9 2026).
##
## Found on the real device save: Nyx Ward carries a Shotgun AND a Colony Rifle, and the
## Colony Rifle appeared nowhere on the sheet — the manifest only addressed slot 1, and
## the extra could not reach Gear either because that branch only saw NON-weapons.
##
## ⚠ The first correction routed it into Gear. That was wrong: a weapon belongs in a
## weapon slot with its Range/Shots/Damage under the right captions. This asserts the
## slot, and that Gear is only the overflow for weapon THREE onward.
func test_a_second_weapon_fills_the_second_printed_weapon_slot() -> void:
	var campaign: Resource = _make_campaign()
	# All three are real weapons in equipment_database.json.
	campaign.crew_data["members"][1]["equipment"] = ["Shotgun", "Colony Rifle", "Blade"]
	SheetDataContextScript.reset_cache()
	var ctx: Dictionary = SheetDataContextScript.build(campaign, {}, [])
	var member: Dictionary = (ctx["campaign"]["crew"] as Array)[0]
	var weapons: Array = member["weapons"]

	assert_int(weapons.size()).override_failure_message(
		"The manifest addresses weapons[0] AND weapons[1] unconditionally, so both must " +
		"exist or the second row resolves to null."
	).is_equal(SheetDataContextScript.WEAPON_SLOTS)
	assert_str(str(weapons[0].get("name", ""))).is_equal("Shotgun")
	assert_str(str(weapons[1].get("name", ""))).override_failure_message(
		"Colony Rifle must fill the printed second weapon slot, not spill into Gear."
	).is_equal("Colony Rifle")
	# Its stats must come across too — a name with no Range/Shots/Damage is the same
	# defect one column over.
	assert_str(str(weapons[1].get("range", ""))).is_equal("18")
	assert_str(str(member.get("gear_text", ""))).override_failure_message(
		"Weapon three has nowhere printed to go, so Gear is the right overflow."
	).contains("Blade")


## An unarmed character must still resolve both slots — blank rows are the correct
## printed output, and a null would be indistinguishable from a broken source path.
func test_both_weapon_slots_resolve_for_an_unarmed_character() -> void:
	var campaign: Resource = _make_campaign()
	campaign.crew_data["members"][1]["equipment"] = []
	SheetDataContextScript.reset_cache()
	var ctx: Dictionary = SheetDataContextScript.build(campaign, {}, [])
	var weapons: Array = ((ctx["campaign"]["crew"] as Array)[0])["weapons"]
	assert_int(weapons.size()).is_equal(SheetDataContextScript.WEAPON_SLOTS)
	for w: Dictionary in weapons:
		assert_str(str(w.get("name", "<null>"))).is_equal("")


## Half one: nothing resolves to null. Guards typos and renamed properties.
func test_every_manifest_source_resolves_against_a_real_campaign() -> void:
	var r: Node = _renderer()
	var ctx: Dictionary = _ctx()
	var dead: Array[String] = []
	var live: int = 0
	for path in MANIFEST_PATHS:
		for raw in _load_manifest(path).get("fields", []):
			if not raw is Dictionary:
				continue
			var field: Dictionary = raw
			var src: String = str(field.get("source", ""))
			if src.is_empty():
				continue
			if r._resolve_source(src, ctx) == null:
				dead.append("%s :: %s (id=%s)" % [
					path.get_file(), src, str(field.get("id", "?"))])
			else:
				live += 1
	assert_array(dead).override_failure_message(
		"%d of %d manifest sources resolve to NULL — those fields render BLANK " % [
			dead.size(), dead.size() + live] +
		"on the printed sheet:\n  " + "\n  ".join(dead)).is_empty()


## Half two: the values are the RIGHT ones. Resolution alone would pass if the builder
## returned "" for everything, which would print an empty sheet just as happily.
func test_the_resolved_values_are_the_campaigns_actual_values() -> void:
	var r: Node = _renderer()
	var ctx: Dictionary = _ctx()
	var expected := {
		"campaign.campaign_name": "Test Crew",
		"campaign.credits": 23,
		"campaign.story_points": 9,
		"campaign.rivals_count": 1,
		"campaign.progress_data.turns_played": 8,
		"campaign.captain.character_name": "Bryn Ito",
		"campaign.captain.combat": 3,
		"campaign.captain.notes": "note-Bryn Ito",
		"campaign.crew[0].character_name": "Crew 0",
		"campaign.crew[6].character_name": "Crew 6",
		"campaign.crew[3].combat": 3,
		"campaign.ship.name": "Far Runner",
		"campaign.ship.hull_current": 35,
		# Canonical owner is campaign.ship_debt, NOT ship_data["debt"] (absent here on
		# purpose — if the builder ever reads the mirror instead, this goes red).
		"campaign.ship.debt": 49,
		"campaign.ship.traits_text": "Fuel Hog",
		"campaign.stash_items_text": "Handgun",
		"world.name": "Gamma Prime",
		"world.danger": 3,
		"world.traits[1]": "Booming Trade",
		"journal.last_battle.result": "Victory",
		"journal.last_battle.enemy_count": 7,
		# Encounter Log, Core Rules Appendix X p.180. Every one of these comes out of
		# the journal entry's `stats`, which is the only place a battle's scenario
		# survives create_entry()'s fixed key set.
		"journal.last_battle.encounter_type": "Criminal Elements",
		"journal.last_battle.mission_label": "Patron — Patrol",
		"journal.last_battle.deployment_condition": "Poor Visibility",
		# "Shiny Bits" is the p.89 Notable Sight box, NOT credits earned.
		"journal.last_battle.notable_sight": "Shiny bits — Gain 1 credit.",
	}
	var wrong: Array[String] = []
	for src: String in expected:
		var got: Variant = r._resolve_source(src, ctx)
		if str(got) != str(expected[src]):
			wrong.append("%s -> %s (expected %s)" % [src, str(got), str(expected[src])])
	assert_array(wrong).override_failure_message(
		"resolved values disagree with the campaign:\n  " + "\n  ".join(wrong)).is_empty()


## Weapon stats must come from equipment_database.json — the canonical owner per
## CLAUDE.md — never be derived or invented in the view-model.
func test_weapon_stats_come_from_the_equipment_database() -> void:
	var r: Node = _renderer()
	var ctx: Dictionary = _ctx()
	# Shatter Axe, equipment_database.json: damage 2, range 0, shots 0, traits ["Melee"].
	assert_str(str(r._resolve_source("campaign.captain.weapons[0].name", ctx))) \
		.is_equal("Shatter Axe")
	assert_str(str(r._resolve_source("campaign.captain.weapons[0].damage", ctx))).is_equal("2")
	assert_str(str(r._resolve_source("campaign.captain.weapons[0].range", ctx))).is_equal("0")
	assert_str(str(r._resolve_source("campaign.captain.weapons[0].traits", ctx))).is_equal("Melee")


## A non-weapon must NOT be printed in the weapon row — it belongs in gear.
func test_non_weapons_route_to_gear_not_the_weapon_row() -> void:
	var r: Node = _renderer()
	var ctx: Dictionary = _ctx()
	# Crew carry ["Blade", "Sonic Emitter"]. Blade is a weapon; Sonic Emitter is gear.
	assert_str(str(r._resolve_source("campaign.crew[0].weapons[0].name", ctx))).is_equal("Blade")
	assert_str(str(r._resolve_source("campaign.crew[0].gear_text", ctx))) \
		.contains("Sonic Emitter")
	assert_str(str(r._resolve_source("campaign.crew[0].gear_text", ctx))) \
		.override_failure_message("a weapon leaked into gear_text").not_contains("Blade")


## An empty campaign must still resolve every path — a blank printable form, not nulls.
## This is the [[reference_empty_container_is_not_absence]] guard: the emptiest legal
## object is exactly what a brand-new campaign looks like.
func test_an_empty_campaign_still_produces_a_fully_resolvable_blank_form() -> void:
	var r: Node = _renderer()
	SheetDataContextScript.reset_cache()
	var ctx: Dictionary = SheetDataContextScript.build(CampaignCore.new(), null, [])
	var dead: Array[String] = []
	for path in MANIFEST_PATHS:
		for raw in _load_manifest(path).get("fields", []):
			if not raw is Dictionary:
				continue
			var src: String = str((raw as Dictionary).get("source", ""))
			if src.is_empty():
				continue
			# Crew slots are legitimately absent on an empty roster — a blank row is the
			# correct printed output. Everything else must still resolve.
			if src.begins_with("campaign.crew["):
				continue
			if r._resolve_source(src, ctx) == null:
				dead.append("%s :: %s" % [path.get_file(), src])
	assert_array(dead).override_failure_message(
		"an EMPTY campaign leaves these unresolvable (should be blank, not null):\n  " +
		"\n  ".join(dead)).is_empty()


## T9-11: the field overlays must survive being rendered BEFORE layout.
##
## Every field node's position/size is computed once, at render_sheet() time, from
## `_scale_rect_to_display()` — which divides by the renderer's OWN `size`. A screen that
## calls render_sheet() during setup (before the Control has been laid out) therefore
## builds every Label at (0,0) with size 0, and `clip_text = true` makes them invisible
## forever after. The background is PRESET_FULL_RECT so it resizes itself and looks
## perfect, and `_draw()` recomputes the debug rects every frame so the overlay looks
## perfect too — which is exactly why this hid behind the blank-data bug (T9-09).
func test_field_nodes_are_not_stranded_at_zero_size_when_rendered_before_layout() -> void:
	var r: Node = _renderer()
	r.size = Vector2.ZERO                  # pre-layout, as during screen setup
	r.render_sheet("crew_log", _ctx())
	r.size = Vector2(1670.0, 1113.0)       # layout arrives afterwards
	await get_tree().process_frame

	var sized: int = 0
	var collapsed: int = 0
	for n in r._field_nodes:
		if not is_instance_valid(n):
			continue
		if n.size.x > 1.0 and n.size.y > 1.0:
			sized += 1
		else:
			collapsed += 1
	assert_int(collapsed).override_failure_message(
		"%d of %d field overlays have zero size after layout — they were positioned " % [
			collapsed, collapsed + sized] +
		"against a zero-size renderer and never re-scaled, so the sheet prints blank " +
		"no matter how good the data is.").is_equal(0)


## T9-11, export half. The PDF/PNG path duplicates the renderer into a SubViewport at
## SOURCE resolution. `duplicate()` copies the child Labels and their meta but NOT the
## plain `var _field_nodes`, so the clone must re-adopt them before rescaling — otherwise
## the export writes the overlay at the on-screen scale inside a 2764x1843 page.
func test_the_export_clone_rescales_overlays_to_source_resolution() -> void:
	var r: Node = _renderer()
	r.size = Vector2(1670.0, 1113.0)
	r.render_sheet("crew_log", _ctx())
	await get_tree().process_frame

	# Stand in for _render_offscreen()'s clone: same duplicate + resize + handoff.
	# DUPLICATE_SCRIPTS is load-bearing — `duplicate(flags)` REPLACES the default
	# bitmask (15) rather than adding to it, so USE_INSTANTIATION alone returns a
	# SCRIPTLESS Control and the production has_method() guard skips the handoff in
	# silence. Dropping it here reproduces the original bug exactly.
	var clone: Control = r.duplicate(
		Node.DUPLICATE_USE_INSTANTIATION | Node.DUPLICATE_SCRIPTS) as Control
	add_child(clone)
	auto_free(clone)
	clone.size = Vector2(2764.0, 1843.0)   # the SubViewport's source size
	clone._set_manifest_for_export(r._manifest)
	await get_tree().process_frame

	# At source resolution the scale is 1:1, so a field must sit on its VALUE rect —
	# the manifest rect with the printed caption band (label_inset) off the top and
	# FIELD_PAD_X off each side. crew_log "credits" is rect [1650, 159, 110, 110].
	var expected_x: float = 1650.0 + SheetRendererScript.FIELD_PAD_X
	var credits: Control = null
	for n in clone._field_nodes:
		if is_instance_valid(n) and n.has_meta("sheet_src_rect") \
				and is_equal_approx((n.get_meta("sheet_src_rect") as Rect2).position.x, expected_x):
			credits = n
			break
	assert_that(credits).override_failure_message(
		"the export clone re-adopted %d overlays but none matched the credits rect" \
			% clone._field_nodes.size()).is_not_null()
	assert_float(credits.position.x).override_failure_message(
		"credits label at x=%.1f, expected ~%.0f (overlay left at on-screen scale " \
			% [credits.position.x, expected_x] + "inside a source-resolution page)"
	).is_equal_approx(expected_x, 2.0)
	assert_float(credits.size.x).is_equal_approx(
		110.0 - SheetRendererScript.FIELD_PAD_X * 2.0, 2.0)
	# The value sits BELOW the printed "Credits" caption, not centred over it.
	assert_float(credits.position.y).override_failure_message(
		"credits label top at y=%.1f; the manifest box starts at 159 and the artwork " \
			% credits.position.y + "prints a 26px caption there, so the value must start below it."
	).is_greater(159.0)


## T9-12: the exported PDF must be a STRUCTURALLY COMPLETE PDF, not just a file.
##
## Measured on device before the fix: Save PDF produced a 100 KB file with a valid
## `%PDF-1.6` header, no xref, no trailer, no startxref and no `%%EOF` — it ended
## mid-image-stream and PyPDF2 refused it ("EOF marker not found"). The write had not
## failed; it was still RUNNING, 4+ minutes in at 50-110% CPU, because
## `_addImageDictionary()` emitted 15.3 MB one `store_8()` call per colour channel
## (~40.7M GDScript calls for a 2764x1843 sheet).
##
## "The file exists" is NOT the assertion that matters — a truncated PDF exists too.
## Assert the trailer, because that is the part a slow or interrupted write loses first.
func test_the_exported_pdf_is_structurally_complete() -> void:
	if not PdfExportRouterScript.is_pdf_available():
		return   # no backend in this checkout; the router has its own coverage
	var r: Node = _renderer()
	r.size = Vector2(1670.0, 1113.0)
	r.render_sheet("crew_log", _ctx())
	await get_tree().process_frame

	var out_path := "user://test_export_%d.pdf" % Time.get_ticks_msec()
	var err: Error = await r.export_to_pdf(out_path)
	assert_int(err).override_failure_message(
		"export_to_pdf returned %d" % err).is_equal(OK)

	var f: FileAccess = FileAccess.open(out_path, FileAccess.READ)
	assert_that(f).override_failure_message("no file at %s" % out_path).is_not_null()
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(out_path))

	assert_str(bytes.slice(0, 5).get_string_from_ascii()).override_failure_message(
		"missing %PDF header").is_equal("%PDF-")

	# Search RAW BYTES. Do NOT decode: get_string_from_ascii() stops at the first null
	# byte, and a PDF image stream is full of them, so ANY decode-then-search silently
	# truncates before the trailer and reports a perfectly good PDF as broken. (Cost me
	# two wrong readings of this very test.)
	for marker: String in ["xref", "trailer", "startxref", "%%EOF"]:
		assert_bool(_bytes_contain(bytes, marker)).override_failure_message(
			"exported PDF has no '%s' — the write did not finish (%d bytes). " % [
				marker, bytes.size()] +
			"A partial PDF still exists and still has a valid header; only the " +
			"trailer proves completion.").is_true()


## The export must rasterise at SOURCE resolution — that is the entire purpose of
## _render_offscreen()'s SubViewport + set_size_2d_override. If it comes back smaller,
## every export is a low-resolution print of a sheet meant for paper.
func test_export_rasterises_at_source_resolution() -> void:
	var r: Node = _renderer()
	r.size = Vector2(1670.0, 1113.0)
	r.render_sheet("crew_log", _ctx())
	await get_tree().process_frame

	var out_path := "user://test_export_%d.png" % Time.get_ticks_msec()
	var err: Error = await r.export_to_png(out_path)
	assert_int(err).is_equal(OK)
	var img: Image = Image.new()
	assert_int(img.load(out_path)).is_equal(OK)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(out_path))
	assert_vector(img.get_size()).override_failure_message(
		"exported at %s, expected the manifest source_size 2764x1843" % str(img.get_size())
	).is_equal(Vector2i(2764, 1843))


## Byte-subsequence search. Needed because PDF payloads contain nulls and every
## String-decoding helper in Godot stops there.
func _bytes_contain(haystack: PackedByteArray, needle: String) -> bool:
	var n: PackedByteArray = needle.to_ascii_buffer()
	if n.size() == 0 or haystack.size() < n.size():
		return false
	for i in range(haystack.size() - n.size() + 1):
		var hit: bool = true
		for j in range(n.size()):
			if haystack[i + j] != n[j]:
				hit = false
				break
		if hit:
			return true
	return false


## T9-13: exercise the backend ANDROID actually uses.
##
## `PdfExportRouter.best_available_backend()` prefers GodotHaru, and desktop HAS the
## PDF_DOC GDExtension — so every test above silently validated libharu. The Android
## export preset EXCLUDES `addons/godotharu/*`, so the device runs the pure-GDScript
## GodotPDF path instead. A desktop suite can therefore be fully green while the
## shipping backend is broken, which is exactly what happened: on a TB361FU the export
## ran >4 minutes at 50-110% CPU and produced a file with no xref, trailer or %%EOF.
##
## Call the GodotPDF writer DIRECTLY so the platform that ships it is the platform the
## test covers. The tell that this was needed: the desktop artifact came out 792x612pt
## (11x8.5in, GodotHaru's custom page) while GodotPDF hardcodes 612x792.
func test_the_godotpdf_backend_android_ships_writes_a_complete_pdf() -> void:
	if not ResourceLoader.exists("res://addons/godotpdf/PDF.gd"):
		return
	# A sheet-sized RGBA8 source, the same shape SheetRenderer hands the router.
	var img: Image = Image.create(2764, 1843, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.92, 0.92, 0.92, 1.0))

	var out_path := "user://test_godotpdf_%d.pdf" % Time.get_ticks_msec()
	var t0: int = Time.get_ticks_msec()
	var err: Error = PdfExportRouterScript._export_via_godotpdf(
		ImageTexture.create_from_image(img), Vector2(11.0, 8.5), out_path)
	var elapsed: int = Time.get_ticks_msec() - t0
	assert_int(err).override_failure_message(
		"_export_via_godotpdf returned %d" % err).is_equal(OK)

	var f: FileAccess = FileAccess.open(out_path, FileAccess.READ)
	assert_that(f).is_not_null()
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(out_path))

	for marker: String in ["%PDF-", "xref", "trailer", "startxref", "%%EOF"]:
		assert_bool(_bytes_contain(bytes, marker)).override_failure_message(
			"GodotPDF output has no '%s' (%d bytes) — this is the ANDROID backend." % [
				marker, bytes.size()]).is_true()

	# Guards the bulk-write patch in addons/godotpdf/PDF.gd. The per-byte store_8()
	# loop it replaced took MINUTES for this image; anything in that class blows past
	# a couple of seconds by orders of magnitude.
	assert_int(elapsed).override_failure_message(
		"GodotPDF export took %d ms — the per-byte store_8() writer is probably back " % elapsed +
		"(see the bulk-write patch in addons/godotpdf/PDF.gd::_addImageDictionary)"
	).is_less(5000)

	# /MediaBox is a REQUIRED page attribute (PDF 1.7 Table 30). Upstream GodotPDF
	# emitted none anywhere, so every file it wrote was malformed and viewers were
	# guessing the page size. Found by reading a real device export back with PyPDF2,
	# which returned mediabox = None.
	assert_bool(_bytes_contain(bytes, "/MediaBox")).override_failure_message(
		"No /MediaBox in the PDF — required by the spec; see PDF.gd::_addPageTree()"
	).is_true()

	# LANDSCAPE, because the sheets are 3:2 landscape pages. Upstream GodotPDF was
	# locked to US Letter portrait, so the sheet occupied a 612x408 band of a 612x792
	# page — 47% of the paper blank, and every reader opening zoomed to fit the PAPER.
	# The caller passes (11, 8.5); this asserts the backend stopped discarding it.
	assert_bool(_bytes_contain(bytes, "/MediaBox [0 0 792 612]")).override_failure_message(
		"Page is not 792x612pt (US Letter LANDSCAPE). The 3:2 sheet letterboxes into " +
		"a portrait page with huge margins — see setPageSize() in addons/godotpdf/PDF.gd."
	).is_true()

	# THE PRINT-QUALITY INVARIANT. newImage() resamples to whatever size it is given,
	# and upstream's 4-arg form passes the POINT rect — which pinned every export to
	# exactly 612x408 px, i.e. 72 DPI, in a feature literally called Print Sheet.
	# Assert the source resolution survives into the embedded image.
	assert_bool(_bytes_contain(bytes, "/Width 2764")).override_failure_message(
		"Embedded image is not 2764px wide — the sheet is being downsampled again. " +
		"PdfExportRouter must pass img.get_size() as imageSize and the point rect as drawSize."
	).is_true()
	assert_bool(_bytes_contain(bytes, "/Height 1843")).override_failure_message(
		"Embedded image is not 1843px tall — see the /Width note above."
	).is_true()

	# Native resolution means a 15.3 MB raw stream (2764*1843*3), so the stream has to
	# be compressed. /FlateDecode is zlib (RFC1950) — COMPRESSION_GZIP would produce a
	# structurally valid file that no PDF reader can decode, so pin the filter itself.
	assert_bool(_bytes_contain(bytes, "/FlateDecode")).override_failure_message(
		"Image stream is not Flate-compressed — an uncompressed native-resolution " +
		"sheet is ~15.3 MB. See the /FlateDecode patch in PDF.gd::_addImageDictionary."
	).is_true()
	assert_int(bytes.size()).override_failure_message(
		"PDF is %d bytes; an uncompressed 2764x1843 RGB stream would be ~15.3 MB, " % bytes.size() +
		"so compression is not being applied."
	).is_less(4_000_000)


## THE GEOMETRY INVARIANT: no field's rect may span a printed column divider.
##
## This is the check that would have caught the whole class. On Aug 9 2026, 48 of 144
## crew-log fields had rects shifted ~50-68px right of their printed cell, so centred
## values printed under the NEXT column's caption — the test render put Blade's
## Range/Shots/Damage under the headings "Shots", "Damage" and "Traits". Nothing was
## null, nothing was blank, every source resolved, and the sheet was wrong in a way
## that would make a reader misread the weapon.
##
## A divider is a cyan rule running the full height of the box. If one is INSIDE a
## field's rect, that rect covers two cells and at most one of them can be right.
func test_no_field_rect_spans_a_printed_column_divider() -> void:
	for manifest_path: String in MANIFEST_PATHS:
		var manifest: Dictionary = _load_manifest(manifest_path)
		var art_path: String = str(manifest.get("source_png", ""))
		if art_path.is_empty() or not ResourceLoader.exists(art_path):
			continue
		var tex: Texture2D = load(art_path)
		var img: Image = tex.get_image()
		assert_that(img).is_not_null()

		var offenders: Array[String] = []
		for raw in manifest.get("fields", []):
			var f: Dictionary = raw
			var rect: Array = f.get("rect", [])
			if rect.size() < 4 or int(rect[2]) < 40 or int(rect[3]) < 20:
				continue
			var x: int = int(rect[0])
			var y: int = int(rect[1])
			var w: int = int(rect[2])
			var h: int = int(rect[3])
			# Skip the outer 6px each side — that is the box's own border stroke.
			for col in range(6, w - 6):
				var inked: int = 0
				var sampled: int = 0
				# Sample rows rather than every pixel; a rule is continuous, so a
				# quarter of the rows is plenty and keeps this test fast.
				for row in range(4, h - 4, 4):
					var px: int = x + col
					var py: int = y + row
					if px >= img.get_width() or py >= img.get_height():
						continue
					sampled += 1
					var c: Color = img.get_pixel(px, py)
					if c.b > 0.58 and c.b - c.r > 0.15 and c.g > 0.47:
						inked += 1
				if sampled > 0 and float(inked) / float(sampled) > 0.85:
					offenders.append("%s (divider at +%d of %d)" % [str(f.get("id", "?")), col, w])
					break

		# The Crew Log is the calibrated, shipped sheet: zero tolerance.
		#
		# ⚠ The ratchet that used to live here (2 for encounter_log, 3 for
		# world_record) is GONE, and deliberately: both manifests were re-authored
		# against the artwork on 2026-08-09 and now span nothing. All three sheets
		# are held to zero. Do not re-introduce an allowance — if a sheet spans a
		# divider, its values print under the wrong caption.
		var allowed: int = 0

		assert_int(offenders.size()).override_failure_message(
			"%d field(s) in %s have a rect spanning a printed column divider (allowed %d), " % [
				offenders.size(), manifest_path, allowed]
			+ "so their values print under the wrong caption: %s\n" % str(offenders)
			+ "For the crew log, re-run scripts/recalibrate_crew_log_rows.py. The other two "
			+ "sheets still carry starter geometry and need a calibration pass of their own."
		).is_less_equal(allowed)


## The sheet must print the species' BOOK NAME, not its storage id.
##
## The crew log used to read "kerin" / "genetic_uplift" / "de_converted" — the raw
## keys — on a form the player prints and keeps. `data/character_species.json`
## carries a `name` for all 28 ids and is their canonical owner.
##
## The three ids below are chosen because a naive `capitalize()` gets every one of
## them WRONG, so this test cannot pass by accident if the JSON lookup is ever
## "simplified" into string formatting.
func test_the_species_column_prints_the_book_name_not_the_storage_id() -> void:
	var cases := {
		"kerin": "K'Erin",                     # apostrophe: unreachable by formatting
		"de_converted": "De-converted",        # hyphen, and lowercase second word
		"primitive_character": "Primitive",    # display name is SHORTER than the id
		"genetic_uplift": "Genetic Uplift",
		"human": "Human",
	}
	var wrong: Array[String] = []
	for species_id: String in cases:
		var c: Resource = _make_campaign()
		var members: Array = c.crew_data["members"]
		members[0]["species_id"] = species_id
		c.crew_data = {"members": members}
		c.captain_data = members[0]
		var ctx: Dictionary = _ctx_for(c)
		var got: Variant = _renderer()._resolve_source("campaign.captain.species", ctx)
		if str(got) != cases[species_id]:
			wrong.append("%s -> %s (expected %s)" % [species_id, str(got), cases[species_id]])
	assert_array(wrong).override_failure_message(
		"species printed with the wrong name:\n  " + "\n  ".join(wrong)
		+ "\nResolve via SpeciesDataService against data/character_species.json; "
		+ "do NOT reformat the id.").is_empty()


## An id with no JSON entry — a legacy save storing `origin` as a numeric enum, or
## a species added to code before data — must still print SOMETHING. A print form
## with a silently empty Species box is worse than one showing a raw token.
func test_an_unknown_species_id_still_prints_a_value() -> void:
	var c: Resource = _make_campaign()
	var members: Array = c.crew_data["members"]
	members[0]["species_id"] = "not_a_real_species"
	c.crew_data = {"members": members}
	c.captain_data = members[0]
	var ctx: Dictionary = _ctx_for(c)
	var got: String = str(_renderer()._resolve_source("campaign.captain.species", ctx))
	assert_str(got).is_not_empty()
	# Godot's capitalize() is a snake_case humaniser, so the raw id must be handed
	# to it directly — pre-replacing the underscores yields "Not aA rReal sSpecies".
	assert_str(got).is_equal("Not A Real Species")


## The book spells some weapons TWO ways, and save data uses the other one.
##
## "Handgun" is how the Low Tech Weapon Table prints it (Core Rules p.28) and how
## the worked example prints it (p.34) — and it is what a real save's stash
## actually contains. The STAT table on p.50 prints "Hand gun", which is the form
## `equipment_database.json` carries.
##
## Found on the device's own legacy save: the exact-name lookup missed, so a
## Handgun printed as GEAR with no Range/Shots/Damage instead of as the weapon it
## is. The database is complete and book-exact (36 weapons, matching pp.50-52) —
## the fix is a normalised key, NOT a second database row for one weapon.
func test_a_weapon_resolves_under_either_of_the_books_spellings() -> void:
	SheetDataContextScript.reset_cache()
	var canonical: Dictionary = SheetDataContextScript._lookup_weapon("Hand Gun")
	var as_saved: Dictionary = SheetDataContextScript._lookup_weapon("Handgun")
	assert_bool(canonical.is_empty()).is_false() \
		.override_failure_message("'Hand Gun' (the p.50 spelling) is not in the database")
	assert_bool(as_saved.is_empty()).is_false() \
		.override_failure_message(
			"'Handgun' (the p.28 spelling, and what saves contain) did not resolve — "
			+ "it will print as Gear with no weapon stats")
	# Same weapon, so same stats. Core Rules p.50: 12in, 1 shot, 0 damage, Pistol.
	assert_int(int(as_saved["range"])).is_equal(12)
	assert_int(int(as_saved["shots"])).is_equal(1)
	assert_int(int(as_saved["damage"])).is_equal(0)
	assert_str(str(as_saved["traits"])).contains("Pistol")
	assert_str(str(as_saved["name"])).is_equal(str(canonical["name"]))


func test_the_normalised_lookup_does_not_collide_distinct_weapons() -> void:
	# Stripping spaces/punctuation must not make two real weapons the same key.
	SheetDataContextScript.reset_cache()
	var seen: Dictionary = {}
	var f: FileAccess = FileAccess.open("res://data/equipment_database.json", FileAccess.READ)
	var db: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	var collisions: Array[String] = []
	for w in db.get("weapons", []):
		var key: String = SheetDataContextScript._weapon_key(str((w as Dictionary).get("name", "")))
		if seen.has(key):
			collisions.append("%s == %s (key %s)" % [seen[key], w["name"], key])
		seen[key] = w["name"]
	assert_array(collisions).override_failure_message(
		"normalisation collapsed distinct weapons:\n  " + "\n  ".join(collisions)).is_empty()


func test_a_stash_handgun_prints_with_its_weapon_stats() -> void:
	# End to end through the view-model, the way the sheet consumes it.
	var c: Resource = _make_campaign()
	var members: Array = c.crew_data["members"]
	members[0]["equipment"] = ["Handgun"]
	c.crew_data = {"members": members}
	c.captain_data = members[0]
	var ctx: Dictionary = _ctx_for(c)
	var r: Node = _renderer()
	assert_str(str(r._resolve_source("campaign.captain.weapons[0].name", ctx))) \
		.is_equal("Hand Gun")
	assert_str(str(r._resolve_source("campaign.captain.weapons[0].range", ctx))) \
		.is_equal("12")
	assert_str(str(r._resolve_source("campaign.captain.gear_text", ctx))) \
		.not_contains("Handgun") \
		.override_failure_message("a Handgun is a WEAPON (p.28/p.50), not gear")


## Every manifest field must render a NON-BLANK value against a fully-populated
## campaign, unless it is on the documented blank list below.
##
## THIS IS THE GUARD THE SUITE WAS MISSING. `test_every_manifest_source_resolves...`
## only asserts non-null, and `SheetDataContext` deliberately returns "" rather than
## null for anything it cannot fill — so a source pointing at a key no producer writes
## resolves to "" and passes. That is exactly how five of the Encounter Log's six boxes
## printed empty on every campaign while this file was green
## ([[reference_non_empty_is_not_resolvable]]: resolves + is right + OBSERVED non-blank).
##
## A new field whose data does not exist yet must be added to BLANK_BY_DESIGN with a
## reason, which makes "this box is deliberately empty" a decision someone wrote down
## instead of an accident nobody can see.
func test_every_addressed_box_prints_something_on_a_populated_campaign() -> void:
	# source path -> why it is legitimately blank. Mirrors SheetDataContext's
	# _EMPTY_UNTIL_MODELLED list; both must be updated together.
	var blank_by_design: Dictionary = {
		"world.notes": "no per-world player note field exists",
		"world.invading_force":
			"the box appears only on the printed sheet, never in the rules text, and "
			+ "record_invaded_planet() persists no invader identity",
		"campaign.notes": "no free-text campaign note field exists",
		"campaign.ship.upgrades_text": "ship upgrades are not modelled on ship_data",
	}
	# NOTE: world.turns_visited, campaign.ship.fuel and journal.last_battle.credits_earned
	# are also unmodelled, but NO manifest addresses them, so listing them here would be a
	# dead exemption. SheetDataContext's _EMPTY_UNTIL_MODELLED docblock is their home.
	var r: Node = _renderer()
	var ctx: Dictionary = _ctx()
	var blank: Array[String] = []
	var unused: Dictionary = blank_by_design.duplicate()
	for path: String in MANIFEST_PATHS:
		var manifest: Dictionary = _load_manifest(path)
		for field: Variant in manifest.get("fields", []):
			var source: String = str((field as Dictionary).get("source", ""))
			if source.is_empty():
				continue
			# Padded rows (crew slot 5 on a 4-crew campaign, patron 3 of 3) are
			# blank on purpose — a print form is meant to have empty rows.
			if "[" in source:
				continue
			unused.erase(source)
			if blank_by_design.has(source):
				continue
			var got: Variant = r._resolve_source(source, ctx)
			if got == null or str(got).strip_edges().is_empty():
				blank.append("%s (%s -> %s)" % [
					path.get_file(), (field as Dictionary).get("id", "?"), source])
	assert_array(blank).override_failure_message(
		"these boxes print blank against a fully-populated campaign — either wire a "
		+ "producer or add the source to blank_by_design with a reason:\n  "
		+ "\n  ".join(blank)).is_empty()
	# A stale exemption is how a fixed field silently loses its coverage.
	assert_dict(unused).override_failure_message(
		"blank_by_design lists sources no manifest addresses any more: %s"
		% str(unused.keys())).is_empty()


## The current world arrives as a PlanetData OBJECT, not a Dictionary.
##
## `PlanetDataManager.get_current_planet() -> PlanetData` — an inner class consumed by
## property access (`planet.visit_count` in CampaignDashboard). SheetDataContext used
## `world if world is Dictionary else {}`, so on device the World Record Sheet printed
## World Name and World Traits BLANK for every campaign while the dashboard, one screen
## away, showed the world fine. Found on hardware Aug 9 2026, deploy #5.
##
## Both shapes must work: the object is what the app passes, the Dictionary is what
## older callers and probes pass.
func test_the_current_world_resolves_whether_object_or_dictionary() -> void:
	var r: Node = _renderer()

	SheetDataContextScript.reset_cache()
	var from_object: Dictionary = SheetDataContextScript.build(
		_make_campaign(), _world(), _battle_entries())
	assert_str(str(r._resolve_source("world.name", from_object))) \
		.override_failure_message(
			"a PlanetData OBJECT must resolve — this is the type the app actually passes") \
		.is_equal("Gamma Prime")
	assert_str(str(r._resolve_source("world.traits_text", from_object))) \
		.contains("Booming Trade")

	SheetDataContextScript.reset_cache()
	var from_dict: Dictionary = SheetDataContextScript.build(
		_make_campaign(),
		{"id": "gamma_prime", "name": "Gamma Prime", "type_name": "High Cost",
			"danger_level": 3, "traits": ["High Cost", "Booming Trade", "Fringe"]},
		_battle_entries())
	assert_str(str(r._resolve_source("world.name", from_dict))).is_equal("Gamma Prime")


## The journal accessor PrintSheetScreen guards on must actually EXIST.
##
## It guarded on `has_method("get_entries")`. `func get_entries` has ZERO definitions
## repo-wide — the real accessor is `get_all_entries()` — so the branch was permanently
## false and `entries` was ALWAYS []. The Encounter Log's entire journal block printed
## blank in every campaign on every platform, and the whole `journal.*` namespace of the
## view-model had never received a single entry. Found on device, deploy #5.
##
## This suite could not see it: every other test calls SheetDataContext.build() directly
## and PASSES entries in, so the screen's own resolution step is never exercised. Reading
## the name out of the source is what makes a rename break this test instead of the sheet.
func test_the_journal_accessor_the_print_screen_calls_actually_exists() -> void:
	var f: FileAccess = FileAccess.open(
		"res://src/ui/screens/print/PrintSheetScreen.gd", FileAccess.READ)
	assert_object(f).is_not_null()
	var src: String = f.get_as_text()
	f.close()

	var re := RegEx.new()
	# Bracket classes instead of backslash escapes — GDScript rejects `\.` as an
	# invalid string escape, and a parse error makes gdUnit4 report "No test cases
	# found" while still EXITING 0 ([[reference_gdunit4_parse_error_exits_zero]]).
	re.compile('journal[.]has_method[(]"([A-Za-z_]+)"[)]')
	var m: RegExMatch = re.search(src)
	assert_object(m).override_failure_message(
		"PrintSheetScreen no longer guards the journal accessor by name — if the lookup " +
		"was restructured, retarget this test at the new call.").is_not_null()

	var accessor: String = m.get_string(1)
	var journal: Node = CampaignJournalScript.new()
	add_child(journal)
	auto_free(journal)
	assert_bool(journal.has_method(accessor)).override_failure_message(
		"PrintSheetScreen guards on journal.has_method(\"%s\"), which CampaignJournal " % accessor
		+ "does NOT define — a permanently-false branch, so the sheet gets zero entries."
		).is_true()

	# And it must actually hand back the entries that were created.
	journal.auto_create_battle_entry({"outcome": "Victory", "location": "Gamma Prime"})
	var got: Variant = journal.call(accessor)
	assert_int((got as Array).size()).override_failure_message(
		"%s() returned no entries after one was created" % accessor).is_greater(0)
