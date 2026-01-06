@tool
extends RefCounted
class_name PDFGenerator

## PDF Generator for Five Parsecs campaign manager
## Generates PDF documents for crew rosters and character sheets

signal document_created()
signal section_added(section_name: String)
signal document_saved(file_path: String)

var current_document: Dictionary = {}
var template_path: String = ""

func _init() -> void:
	current_document = {
		"title": "",
		"subtitle": "",
		"sections": [],
		"metadata": {}
	}

func set_template(path: String) -> void:
	template_path = path

func create_document() -> void:
	current_document = {
		"title": "",
		"subtitle": "",
		"sections": [],
		"metadata": {
			"created": Time.get_datetime_string_from_system(),
			"generator": "Five Parsecs Campaign Manager"
		}
	}
	document_created.emit()

func add_title(title: String) -> void:
	current_document.title = title

func add_subtitle(subtitle: String) -> void:
	current_document.subtitle = subtitle

func add_section(section_name: String) -> void:
	var section = {
		"_name": section_name,
		"type": "section",
		"content": []
	}
	current_document.sections.append(section)
	section_added.emit(section_name)

func add_subsection(subsection_name: String) -> void:
	var subsection = {
		"_name": subsection_name,
		"type": "subsection",
		"content": []
	}
	current_document.sections.append(subsection)

func add_field(field_name: String, field_value: String) -> void:
	var field = {
		"name": field_name,
		"_value": field_value,
		"type": "field"
	}
	if current_document.sections.size() > 0:
		current_document.sections[-1].content.append(field)

func add_text(text: String) -> void:
	var text_block = {
		"content": text,
		"type": "text"
	}
	if current_document.sections.size() > 0:
		current_document.sections[-1].content.append(text_block)

func add_bullet_point(text: String) -> void:
	var bullet = {
		"content": text,
		"type": "bullet"
	}
	if current_document.sections.size() > 0:
		current_document.sections[-1].content.append(bullet)

func add_separator() -> void:
	var separator = {
		"type": "separator"
	}
	current_document.sections.append(separator)

func save_to_file(file_path: String) -> Error:
	# For now, save as JSON - in a real implementation this would generate PDF
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()

	var json_string = JSON.stringify(current_document, "    ")
	file.store_string(json_string)
	if file: file.close()

	document_saved.emit(file_path)
	return OK

func get_document_data() -> Dictionary:
	return current_document.duplicate(true)