class_name PDFGenerator
extends Node

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

const FONT_REGULAR = "res://assets/fonts/regular.ttf"
const FONT_BOLD = "res://assets/fonts/bold.ttf"
const FONT_ITALIC = "res://assets/fonts/italic.ttf"

const MARGIN = 50
const PAGE_WIDTH = 595  # A4 width in points
const PAGE_HEIGHT = 842  # A4 height in points

var current_y: float = MARGIN
var current_page: int = 1
var content: String = ""

func create_document() -> void:
    content = ""
    current_y = MARGIN
    current_page = 1

func add_title(text: String) -> void:
    _check_page_break(50)
    content += "[font_size=24][center][b]%s[/b][/center][/font_size]\n\n" % text
    current_y += 50

func add_heading(text: String) -> void:
    _check_page_break(30)
    content += "[font_size=18][b]%s[/b][/font_size]\n\n" % text
    current_y += 30

func add_subheading(text: String) -> void:
    _check_page_break(25)
    content += "[font_size=16][b]%s[/b][/font_size]\n\n" % text
    current_y += 25

func add_text(text: String) -> void:
    _check_page_break(20)
    content += text + "\n"
    current_y += 20

func add_list_item(text: String) -> void:
    _check_page_break(20)
    content += "• %s\n" % text
    current_y += 20

func _pad_string(text: String, length: int) -> String:
    var result = text
    while result.length() < length:
        result += " "
    return result

func add_table(headers: Array[String], rows: Array[Array]) -> void:
    _check_page_break(30 + rows.size() * 20)
    
    # Calculate column widths
    var col_count = headers.size()
    var col_width = (PAGE_WIDTH - 2 * MARGIN) / col_count
    
    # Add headers
    var header_row = "|"
    var separator = "|"
    for header in headers:
        header_row += " %s |" % _pad_string(header, col_width - 3)
        separator += "-".repeat(col_width) + "|"
    
    content += header_row + "\n" + separator + "\n"
    current_y += 30
    
    # Add rows
    for row in rows:
        var row_text = "|"
        for cell in row:
            row_text += " %s |" % _pad_string(str(cell), col_width - 3)
        content += row_text + "\n"
        current_y += 20

func add_image(image_path: String, width: float = 200, height: float = 200) -> void:
    _check_page_break(height + 20)
    content += "[img=%dx%d]%s[/img]\n" % [width, height, image_path]
    current_y += height + 20

func add_separator() -> void:
    _check_page_break(20)
    content += "-".repeat(int((PAGE_WIDTH - 2 * MARGIN) / 5)) + "\n"
    current_y += 20

func add_page_break() -> void:
    content += "[page_break]\n"
    current_y = MARGIN
    current_page += 1

func _check_page_break(height: float) -> void:
    if current_y + height > PAGE_HEIGHT - MARGIN:
        add_page_break()

func get_content() -> String:
    return content

func save_to_file(file_path: String) -> Error:
    var file = FileAccess.open(file_path, FileAccess.WRITE)
    if file:
        file.store_string(content)
        file.close()
        return OK
    return FAILED

# Helper functions for character sheet generation
func generate_character_sheet(character: Character) -> void:
    create_document()
    
    # Header
    add_title("Character Sheet")
    add_separator()
    
    # Basic Info
    add_heading("Basic Information")
    add_text("Name: %s" % character.character_name)
    add_text("Class: %s" % GlobalEnums.Class.keys()[character.character_class])
    add_text("Background: %s" % GlobalEnums.Background.keys()[character.background])
    add_text("Status: %s" % GlobalEnums.CharacterStatus.keys()[character.status])
    add_text("Role: %s" % GlobalEnums.CrewRole.keys()[character.crew_role])
    add_separator()
    
    # Stats
    add_heading("Statistics")
    var stats = [
        ["Combat Skill", character.get_stat(GlobalEnums.CharacterStats.COMBAT_SKILL)],
        ["Savvy", character.get_stat(GlobalEnums.CharacterStats.SAVVY)],
        ["Intelligence", character.get_stat(GlobalEnums.CharacterStats.INTELLIGENCE)],
        ["Survival", character.get_stat(GlobalEnums.CharacterStats.SURVIVAL)],
        ["Stealth", character.get_stat(GlobalEnums.CharacterStats.STEALTH)],
        ["Leadership", character.get_stat(GlobalEnums.CharacterStats.LEADERSHIP)]
    ]
    add_table(["Stat", "Value"], stats)
    add_separator()
    
    # Equipment
    add_heading("Equipment")
    var equipped_items = character.get_equipped_items()
    if equipped_items.is_empty():
        add_text("No equipment")
    else:
        for item in equipped_items:
            var type_name = GlobalEnums.ItemType.keys()[item.type]
            add_text("%s: %s" % [type_name, item.name])
            if item.has("description"):
                add_text("  Description: %s" % item.description)
            if item.has("bonuses"):
                for stat in item.bonuses:
                    add_text("  %s Bonus: +%d" % [stat, item.bonuses[stat]])
    add_separator()
    
    # Skills and Experience
    add_heading("Skills and Experience")
    if character.has_method("get_experience"):
        add_text("Experience Points: %d" % character.get_experience())
    if character.has_method("get_level"):
        add_text("Level: %d" % character.get_level())
    
    if not character.skills.is_empty():
        add_subheading("Skills")
        for skill_name in character.skills:
            var skill_level = character.get_skill_level(skill_name)
            add_list_item("%s (Level %d)" % [skill_name, skill_level])
    add_separator()
    
    # Traits and Special Abilities
    if not character.traits.is_empty():
        add_heading("Traits and Abilities")
        for trait_name in character.traits:
            add_list_item(trait_name)
        add_separator()

# Helper functions for crew roster generation
func generate_crew_roster(crew: Crew) -> void:
    create_document()
    
    # Header
    add_title("Crew Roster: %s" % crew.crew_name)
    add_separator()
    
    # Crew Overview
    add_heading("Crew Information")
    add_text("Total Members: %d" % crew.get_member_count())
    add_text("Credits: %d" % crew.credits)
    if crew.has_method("get_reputation"):
        add_text("Reputation: %s" % _get_reputation_text(crew.get_reputation()))
    add_separator()
    
    # Campaign Information
    if crew.has_method("get_campaign_info"):
        var campaign_info = crew.get_campaign_info()
        add_heading("Campaign Status")
        add_text("Campaign Turn: %d" % campaign_info.get("turn", 0))
        add_text("Missions Completed: %d" % campaign_info.get("completed_missions", 0))
        add_text("Victory Progress: %d%%" % (campaign_info.get("victory_progress", 0.0) * 100))
        add_separator()
    
    # Captain
    if crew.captain:
        add_heading("Captain")
        _add_crew_member_summary(crew.captain)
        add_separator()
    
    # Crew Members
    add_heading("Crew Members")
    for member in crew.members:
        if member != crew.captain:
            _add_crew_member_summary(member)
            add_separator()

func _add_crew_member_summary(character: Character) -> void:
    add_subheading(character.character_name)
    add_text("Class: %s" % GlobalEnums.Class.keys()[character.character_class])
    add_text("Role: %s" % GlobalEnums.CrewRole.keys()[character.crew_role])
    add_text("Status: %s" % GlobalEnums.CharacterStatus.keys()[character.status])
    
    # Add stats in a compact table
    var stats = [
        ["Combat Skill", character.get_stat(GlobalEnums.CharacterStats.COMBAT_SKILL)],
        ["Savvy", character.get_stat(GlobalEnums.CharacterStats.SAVVY)],
        ["Intelligence", character.get_stat(GlobalEnums.CharacterStats.INTELLIGENCE)],
        ["Survival", character.get_stat(GlobalEnums.CharacterStats.SURVIVAL)],
        ["Stealth", character.get_stat(GlobalEnums.CharacterStats.STEALTH)],
        ["Leadership", character.get_stat(GlobalEnums.CharacterStats.LEADERSHIP)]
    ]
    add_table(["Stat", "Value"], stats)
    
    # Equipment Summary
    var equipped_items = character.get_equipped_items()
    if not equipped_items.is_empty():
        add_text("\nEquipment:")
        for item in equipped_items:
            add_list_item("%s: %s" % [GlobalEnums.ItemType.keys()[item.type], item.name])

func _get_reputation_text(reputation: int) -> String:
    match reputation:
        GlobalEnums.ReputationType.ADMIRED:
            return "Admired (+2)"
        GlobalEnums.ReputationType.TRUSTED:
            return "Trusted (+1)"
        GlobalEnums.ReputationType.NEUTRAL:
            return "Neutral (0)"
        GlobalEnums.ReputationType.DISLIKED:
            return "Disliked (-1)"
        GlobalEnums.ReputationType.HATED:
            return "Hated (-2)"
        _:
            return "Unknown"
    