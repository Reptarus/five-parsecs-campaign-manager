extends SceneTree

## Render the Crew Log at SOURCE resolution (2764x1843) with a realistic campaign and
## write it to a known path, so field alignment can be measured on the artifact rather
## than judged on the ~0.6x on-screen preview.
##
## Run WITHOUT --headless — this needs a real framebuffer
## (docs/sop/visual-runtime-verification.md).
##
##   Godot_console.exe --path <project> --script tests/tools/emit_sheet_png.gd

const SheetRendererScript = preload("res://src/ui/components/sheet/SheetRenderer.gd")
const SheetDataContextScript = preload("res://src/core/export/SheetDataContext.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

const OUT_PATH := "user://sheet_alignment_probe.png"

## Which sheet to render; override with SHEET=<id> in the environment.
static var SHEET_ID := "crew_log"


func _member(n: String, captain: bool, species: String, eq: Array) -> Dictionary:
	return {
		"character_name": n, "name": n, "is_captain": captain,
		"species_id": species, "combat": 3, "reaction": 2, "toughness": 4,
		"speed": 5, "savvy": 2, "luck": 1, "experience": 6,
		"player_notes": "", "equipment": eq,
	}


func _campaign() -> Resource:
	var c: Resource = CampaignCore.new()
	c.campaign_name = "Tablet QA Run"
	c.credits = 23
	c.story_points = 9
	c.ship_debt = 49
	c.quest_rumors = 3
	c.patrons = []
	c.rivals = [{"name": "Feral Jackals"}]
	# Long-ish names on purpose: alignment problems show up at the extremes.
	var members: Array = [_member("Bryn Ito", true, "genetic_uplift", ["Shatter Axe"])]
	members.append(_member("Dex Kovac", false, "traveler", ["Blade"]))
	members.append(_member("Yuri Drake", false, "mutant", ["Shotgun"]))
	members.append(_member("Mars Stark", false, "kerin", ["Sonic Emitter"]))
	members.append(_member("Finn Mendez", false, "feral", []))
	members.append(_member("Nyx Ward", false, "human", ["Shotgun", "Colony Rifle"]))
	c.crew_data = {"members": members}
	c.captain_data = members[0]
	c.ship_data = {"name": "Far Runner", "hull_points": 35, "traits": ["Fuel Hog"]}
	c.equipment_data = {"equipment": ["Handgun"]}
	c.progress_data = {
		"turns_played": 8,
		# InterdictionRule's record (p.75) — the World Record Sheet's Licensing
		# octagons are derived from it, so a probe without it renders them blank.
		"interdiction": {"active": true, "until_turn": 10, "licensed": true},
	}
	# p.126 step 14 — puts a value in the Invasion Status block.
	c.invaded_planets = [{"id": "gamma_prime", "name": "Gamma Prime", "war_modifier": 1}]
	return c


## The battle entry, built by the REAL producer.
##
## This probe used to hand-write {"type": "battle", "mission_type": ..., "enemy_faction":
## ...}. CampaignJournal.create_entry() assembles entries from a fixed key set and drops
## everything else, so that shape cannot occur in the app — and a probe rendering values
## the app can never produce is worse than no probe.
func _entries() -> Array:
	var journal: Node = load("res://src/core/campaign/CampaignJournal.gd").new()
	root.add_child(journal)
	journal.auto_create_battle_entry({
		"outcome": "Victory",
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


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var renderer: Control = SheetRendererScript.new()
	root.add_child(renderer)
	# A realistic on-screen size, so the export path exercises the same rescale the
	# app does rather than a convenient 1:1.
	renderer.size = Vector2(1660, 1107)
	await process_frame

	SheetDataContextScript.reset_cache()
	var ctx: Dictionary = SheetDataContextScript.build(
		_campaign(),
		# `id` matters: the Invasion Status block joins on the planet id.
		{"id": "gamma_prime", "name": "Gamma Prime", "type_name": "High Cost",
			"danger_level": 3, "traits": ["High Cost", "Booming Trade", "Fringe"]},
		_entries())
	var sid: String = OS.get_environment("SHEET")
	if sid.is_empty(): sid = "crew_log"
	renderer.render_sheet(sid, ctx)
	await process_frame
	await process_frame

	var err: int = await renderer.export_to_png(OUT_PATH)
	print("export_err=%d" % err)
	print("path=%s" % ProjectSettings.globalize_path(OUT_PATH))
	quit()
