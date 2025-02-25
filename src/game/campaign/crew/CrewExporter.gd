class_name CrewExporter
extends Node

const EXPORT_DIR = "user://exports/"
const PDFGenerator = preload("res://src/core/utils/PDFGenerator.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const Crew = preload("res://src/core/campaign/crew/Crew.gd")
const CampaignSystem = preload("res://src/core/campaign/CampaignSystem.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal export_completed(success: bool, message: String)
signal export_failed(error: String)

var pdf_generator: PDFGenerator

func _init() -> void:
    pdf_generator = PDFGenerator.new()

func export_crew_to_pdf(crew: Crew, file_name: String = "") -> void:
    if file_name.is_empty():
        file_name = "crew_roster_%s.pdf" % Time.get_datetime_string_from_system()
    
    # Ensure export directory exists
    var dir = DirAccess.open("user://")
    if not dir.dir_exists(EXPORT_DIR):
        dir.make_dir(EXPORT_DIR)
    
    var file_path = EXPORT_DIR.path_join(file_name)
    
    # Generate PDF content
    pdf_generator.generate_crew_roster(crew)
    
    # Save to file
    if pdf_generator.save_to_file(file_path) == OK:
        export_completed.emit(true, "PDF file created successfully at " + file_path)
    else:
        export_failed.emit("Failed to create PDF file")

func export_character_sheet(character: Character, file_name: String = "") -> void:
    if file_name.is_empty():
        file_name = "character_%s_%s.pdf" % [character.character_name.to_lower().replace(" ", "_"), Time.get_datetime_string_from_system()]
    
    var file_path = EXPORT_DIR.path_join(file_name)
    
    # Generate PDF content
    pdf_generator.generate_character_sheet(character)
    
    # Save to file
    if pdf_generator.save_to_file(file_path) == OK:
        export_completed.emit(true, "PDF file created successfully at " + file_path)
    else:
        export_failed.emit("Failed to create character sheet PDF")

func export_campaign_summary(campaign: CampaignSystem, file_name: String = "") -> void:
    if file_name.is_empty():
        file_name = "campaign_summary_%s.pdf" % Time.get_datetime_string_from_system()
    
    var file_path = EXPORT_DIR.path_join(file_name)
    
    # Create new document
    pdf_generator.create_document()
    
    # Add campaign information
    pdf_generator.add_title("Campaign Summary")
    pdf_generator.add_separator()
    
    # Add game state info
    var game_state = campaign.game_state
    pdf_generator.add_heading("Campaign Status")
    pdf_generator.add_text("Turn: %d" % game_state.campaign_turn)
    pdf_generator.add_text("Phase: %s" % GlobalEnums.CampaignPhase.keys()[campaign.current_phase])
    pdf_generator.add_separator()
    
    # Add crew information
    pdf_generator.add_heading("Current Crew")
    var crew = game_state.current_crew
    pdf_generator.add_text("Total Members: %d" % crew.get_member_count())
    pdf_generator.add_text("Credits: %d" % crew.credits)
    pdf_generator.add_text("Morale: %d/10" % crew.crew_morale)
    pdf_generator.add_separator()
    
    # Add mission history
    pdf_generator.add_heading("Mission History")
    pdf_generator.add_text("Total Battles: %d" % crew.total_battles)
    pdf_generator.add_text("Battles Won: %d" % crew.battles_won)
    pdf_generator.add_text("Victory Rate: %d%%" % (crew.battles_won * 100 / max(crew.total_battles, 1)))
    pdf_generator.add_separator()
    
    # Save to file
    if pdf_generator.save_to_file(file_path) == OK:
        export_completed.emit(true, "PDF file created successfully at " + file_path)
    else:
        export_failed.emit("Failed to create campaign summary PDF")

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