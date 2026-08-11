extends SceneTree

## Introspect the PDF backends' TEXT APIs and prove a native-text overlay is
## reachable, rather than trusting a design note's three-month-old introspection.
##
##   Godot_console.exe --path <project> --script tests/tools/probe_pdf_text_api.gd


func _initialize() -> void:
	print("=== PDF_DOC present: %s ===" % ClassDB.class_exists(&"PDF_DOC"))
	for cls in [&"PDF_DOC", &"PDF_PAGE", &"PDF_FONT"]:
		if not ClassDB.class_exists(cls):
			print("\n-- %s : ABSENT --" % cls)
			continue
		var names: Array[String] = []
		for m in ClassDB.class_get_method_list(cls, true):
			names.append(str(m.name))
		names.sort()
		print("\n-- %s : %d own methods --" % [cls, names.size()])
		print("   " + ", ".join(names))

	# Does a text write actually land? Minimal document, then read the bytes back.
	if ClassDB.class_exists(&"PDF_DOC"):
		var doc: RefCounted = ClassDB.instantiate(&"PDF_DOC")
		doc.new_doc()
		var page: RefCounted = doc.add_page()
		page.set_width(792.0)
		page.set_height(612.0)
		var font_ok := false
		var font = null
		if doc.has_method("get_font"):
			font = doc.get_font("Helvetica")
			font_ok = font != null
		print("\nget_font('Helvetica') -> %s" % font)
		if font_ok and page.has_method("begin_text"):
			page.begin_text()
			page.set_font_and_size(font, 18.0)
			page.text_out(72.0, 500.0, "PROBE_TOKEN_Bryn Ito")
			page.end_text()
			if page.has_method("text_width"):
				print("text_width('Bryn Ito') = %s" % page.text_width("Bryn Ito"))
		var out := "user://pdf_text_probe.pdf"
		print("save_to_file -> %d" % doc.save_to_file(out))
		print("path=%s" % ProjectSettings.globalize_path(out))
	quit()
