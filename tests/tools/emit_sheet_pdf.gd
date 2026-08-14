extends SceneTree

## Export the Crew Log through the REAL PDF path (SheetRenderer.export_to_pdf ->
## PdfExportRouter -> addons/godotpdf) so the artifact can be read back with a
## foreign library instead of judged from the code that wrote it.
##
## Run WITHOUT --headless — export_to_pdf renders through a SubViewport and needs a
## real framebuffer (docs/sop/visual-runtime-verification.md).
##
##   Godot_console.exe --path <project> --script tests/tools/emit_sheet_pdf.gd
##
## Sister script to emit_sheet_png.gd, which shares _campaign() by construction:
## both must describe the SAME campaign or a geometry finding on one will not
## reproduce on the other.

const SheetRendererScript = preload("res://src/ui/components/sheet/SheetRenderer.gd")
const SheetDataContextScript = preload("res://src/core/export/SheetDataContext.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")

const OUT_PATH := "user://sheet_export_probe.pdf"


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
	c.progress_data = {"turns_played": 8}
	return c


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var renderer: Control = SheetRendererScript.new()
	root.add_child(renderer)
	renderer.size = Vector2(1660, 1107)
	await process_frame

	SheetDataContextScript.reset_cache()
	var ctx: Dictionary = SheetDataContextScript.build(_campaign(), {}, [])
	renderer.render_sheet("crew_log", ctx)
	await process_frame
	await process_frame

	# Emit BOTH backends. The router picks godotharu on desktop and godotpdf on
	# Android (godotharu ships no Android binary — see its .gdextension), so a
	# desktop probe of the default path measures the backend the TABLET never uses.
	var sub: SubViewport = await renderer._render_offscreen()
	var tex: Texture2D = sub.get_texture()
	var page := Vector2(11.0, 8.5)
	var layer: Array = renderer._collect_text_layer(sub)
	print("text_layer_entries=%d" % layer.size())

	for backend in ["godotharu", "godotpdf"]:
		var out: String = "user://sheet_probe_%s.pdf" % backend
		var start_ms: int = Time.get_ticks_msec()
		var err: int = (
			PdfExportRouter._export_via_godotharu(tex, page, out, layer) if backend == "godotharu"
			else PdfExportRouter._export_via_godotpdf(tex, page, out, layer))
		print("%s err=%d ms=%d -> %s" % [
			backend, err, Time.get_ticks_msec() - start_ms,
			ProjectSettings.globalize_path(out)])
	sub.queue_free()
	print("router_default=%s" % PdfExportRouter.best_available_backend())
	quit()
