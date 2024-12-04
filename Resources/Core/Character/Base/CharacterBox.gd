class_name CharacterBox
extends PanelContainer

@onready var portrait = $MarginContainer/HBoxContainer/PortraitContainer/Portrait
@onready var name_label = $MarginContainer/HBoxContainer/InfoContainer/NameLabel
@onready var class_label = $MarginContainer/HBoxContainer/InfoContainer/ClassLabel
@onready var combat_value = $MarginContainer/HBoxContainer/InfoContainer/StatsContainer/CombatValue
@onready var technical_value = $MarginContainer/HBoxContainer/InfoContainer/StatsContainer/TechnicalValue
@onready var social_value = $MarginContainer/HBoxContainer/InfoContainer/StatsContainer/SocialValue
@onready var survival_value = $MarginContainer/HBoxContainer/InfoContainer/StatsContainer/SurvivalValue
@onready var status_value = $MarginContainer/HBoxContainer/InfoContainer/StatusContainer/StatusValue

var character_data: CharacterData

func update_display(data: CharacterData) -> void:
    character_data = data
    
    name_label.text = data.character_name
    class_label.text = GlobalEnums.Class.keys()[data.character_class]
    
    # Update stats
    combat_value.text = str(data.stats.get_stat("combat"))
    technical_value.text = str(data.stats.get_stat("technical"))
    social_value.text = str(data.stats.get_stat("social"))
    survival_value.text = str(data.stats.get_stat("survival"))
    
    # Update status
    status_value.text = GlobalEnums.CharacterStatus.keys()[data.status]
    _update_status_color(data.status)
    
    # Update portrait if available
    if data.portrait:
        portrait.texture = data.portrait

func _update_status_color(status: GlobalEnums.CharacterStatus) -> void:
    var color = Color.WHITE
    match status:
        GlobalEnums.CharacterStatus.HEALTHY:
            color = Color(0, 1, 0, 1)  # Green
        GlobalEnums.CharacterStatus.INJURED:
            color = Color(1, 0.5, 0, 1)  # Orange
        GlobalEnums.CharacterStatus.CRITICAL:
            color = Color(1, 0, 0, 1)  # Red
        GlobalEnums.CharacterStatus.DEAD:
            color = Color(0.5, 0.5, 0.5, 1)  # Gray
    status_value.add_theme_color_override("font_color", color)

func get_character_data() -> CharacterData:
    return character_data 