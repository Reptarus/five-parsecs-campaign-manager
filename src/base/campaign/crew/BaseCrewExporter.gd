class_name BaseCrewExporter
extends Node

const EXPORT_DIR = "user://exports/"

signal export_completed(success: bool, message: String)
signal export_failed(error: String)

var pdf_generator = null

func _init() -> void:
    _initialize_pdf_generator()

func _initialize_pdf_generator() -> void:
    # To be implemented by derived classes
    push_error("_initialize_pdf_generator must be implemented by derived classes")

func export_crew_to_pdf(crew, file_name: String = "") -> void:
    if file_name.is_empty():
        file_name = "crew_roster_%s.pdf" % Time.get_datetime_string_from_system()
    
    # Ensure export directory exists
    var dir = DirAccess.open("user://")
    if not dir.dir_exists(EXPORT_DIR):
        dir.make_dir(EXPORT_DIR)
    
    var file_path = EXPORT_DIR.path_join(file_name)
    
    # Generate PDF content
    if pdf_generator == null:
        export_failed.emit("PDF generator not initialized")
        return
        
    pdf_generator.generate_crew_roster(crew)
    
    # Save to file
    if pdf_generator.save_to_file(file_path) == OK:
        export_completed.emit(true, "PDF file created successfully at " + file_path)
    else:
        export_failed.emit("Failed to create PDF file")

func export_character_sheet(character, file_name: String = "") -> void:
    if file_name.is_empty():
        file_name = "character_%s_%s.pdf" % [character.character_name.to_lower().replace(" ", "_"), Time.get_datetime_string_from_system()]
    
    var file_path = EXPORT_DIR.path_join(file_name)
    
    # Generate PDF content
    if pdf_generator == null:
        export_failed.emit("PDF generator not initialized")
        return
        
    pdf_generator.generate_character_sheet(character)
    
    # Save to file
    if pdf_generator.save_to_file(file_path) == OK:
        export_completed.emit(true, "PDF file created successfully at " + file_path)
    else:
        export_failed.emit("Failed to create character sheet PDF")

func export_campaign_summary(campaign, file_name: String = "") -> void:
    if file_name.is_empty():
        file_name = "campaign_summary_%s.pdf" % Time.get_datetime_string_from_system()
    
    var file_path = EXPORT_DIR.path_join(file_name)
    
    # Create new document
    if pdf_generator == null:
        export_failed.emit("PDF generator not initialized")
        return
        
    pdf_generator.create_document()
    
    # Add campaign information
    pdf_generator.add_title("Campaign Summary")
    pdf_generator.add_separator()
    
    # Game-specific implementation should be handled by derived classes
    _generate_campaign_summary_content(campaign)
    
    # Save to file
    if pdf_generator.save_to_file(file_path) == OK:
        export_completed.emit(true, "PDF file created successfully at " + file_path)
    else:
        export_failed.emit("Failed to create campaign summary PDF")

func _generate_campaign_summary_content(campaign) -> void:
    # To be implemented by derived classes
    push_error("_generate_campaign_summary_content must be implemented by derived classes")

func export_crew_to_json(crew_data: Dictionary, file_path: String) -> void:
    var file = FileAccess.open(file_path, FileAccess.WRITE)
    if file:
        var json_string = JSON.stringify(crew_data, "\t")
        file.store_string(json_string)
        file.close()
        export_completed.emit(true, "Crew data exported successfully to " + file_path)
    else:
        export_completed.emit(false, "Failed to open file for writing: " + file_path)

func import_crew_from_json(file_path: String) -> Dictionary:
    var file = FileAccess.open(file_path, FileAccess.READ)
    if file:
        var json_string = file.get_as_text()
        file.close()
        
        var json = JSON.new()
        var error = json.parse(json_string)
        if error == OK:
            var crew_data = json.data
            export_completed.emit(true, "Crew data imported successfully from " + file_path)
            return crew_data
        else:
            export_completed.emit(false, "Failed to parse JSON data from " + file_path)
            return {}
    else:
        export_completed.emit(false, "Failed to open file for reading: " + file_path)
        return {}