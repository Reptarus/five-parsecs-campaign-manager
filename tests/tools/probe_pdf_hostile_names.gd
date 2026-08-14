extends SceneTree

## Export a sheet whose crew names contain every character that is SPECIAL inside
## a PDF literal string, and prove both backends survive it.
##
## `(`, `)` and `\` are the whole hazard: GodotPDF concatenated raw text into
## `(text) Tj`, so one unbalanced paren terminates the string early and the rest
## of the name is parsed as PDF operators — a corrupt file from a legal crew name.
## libharu escapes internally, which is why the router must NOT pre-escape.
##
##   Godot_console.exe --path <project> --script tests/tools/probe_pdf_hostile_names.gd

const SheetRendererScript = preload("res://src/ui/components/sheet/SheetRenderer.gd")
const SheetDataContextScript = preload("res://src/core/export/SheetDataContext.gd")
const CampaignCore = preload("res://src/game/campaign/FiveParsecsCampaignCore.gd")


func _member(n: String) -> Dictionary:
	return {
		"character_name": n, "name": n, "is_captain": false,
		"species_id": "human", "combat": 1, "reaction": 1, "toughness": 3,
		"speed": 4, "savvy": 0, "luck": 0, "experience": 0,
		"player_notes": "", "equipment": [],
	}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var c: Resource = CampaignCore.new()
	# Every hazardous form: unbalanced open, unbalanced close, balanced pair,
	# a trailing backslash (which would escape the closing paren), and a
	# backslash-paren combination.
	var members: Array = [
		_member("Vance (Doc) Ryu"),
		_member("Half ( Open"),
		_member("Half ) Close"),
		_member("Trail Backslash\\"),
		_member("Mix \\( Weird"),
		_member("Plain Name"),
	]
	members[0]["is_captain"] = true
	c.campaign_name = "Paren (Test) \\ Run"
	c.crew_data = {"members": members}
	c.captain_data = members[0]
	c.ship_data = {"name": "Slash\\Nine (II)", "hull_points": 20, "traits": []}
	c.equipment_data = {"equipment": []}
	c.progress_data = {"turns_played": 1}

	var renderer: Control = SheetRendererScript.new()
	root.add_child(renderer)
	renderer.size = Vector2(1660, 1107)
	await process_frame
	SheetDataContextScript.reset_cache()
	renderer.render_sheet("crew_log", SheetDataContextScript.build(c, {}, []))
	await process_frame
	await process_frame

	var sub: SubViewport = await renderer._render_offscreen()
	var layer: Array = renderer._collect_text_layer(sub)
	print("text_layer_entries=%d" % layer.size())
	for backend in ["godotharu", "godotpdf"]:
		var out: String = "user://hostile_%s.pdf" % backend
		var err: int = (
			PdfExportRouter._export_via_godotharu(sub.get_texture(), Vector2(11, 8.5), out, layer)
			if backend == "godotharu"
			else PdfExportRouter._export_via_godotpdf(sub.get_texture(), Vector2(11, 8.5), out, layer))
		print("%s err=%d -> %s" % [backend, err, ProjectSettings.globalize_path(out)])
	sub.queue_free()
	quit()
