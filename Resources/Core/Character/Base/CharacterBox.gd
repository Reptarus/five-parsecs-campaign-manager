class_name CharacterBox
extends PanelContainer

@onready var portrait = $MarginContainer/HBoxContainer/PortraitContainer/Portrait
@onready var name_label = $MarginContainer/HBoxContainer/InfoContainer/NameLabel
@onready var class_label = $MarginContainer/HBoxContainer/InfoContainer/ClassLabel
@onready var reactions_value = $MarginContainer/HBoxContainer/InfoContainer/StatsContainer/ReactionsValue
@onready var speed_value = $MarginContainer/HBoxContainer/InfoContainer/StatsContainer/SpeedValue
@onready var combat_skill_value = $MarginContainer/HBoxContainer/InfoContainer/StatsContainer/CombatSkillValue
@onready var toughness_value = $MarginContainer/HBoxContainer/InfoContainer/StatsContainer/ToughnessValue
@onready var savvy_value = $MarginContainer/HBoxContainer/InfoContainer/StatsContainer/SavvyValue
@onready var luck_value = $MarginContainer/HBoxContainer/InfoContainer/StatsContainer/LuckValue
@onready var status_value = $MarginContainer/HBoxContainer/InfoContainer/StatusContainer/StatusValue

var character_data: Resource # Using Resource as base class since CharacterData is not found

func update_display(data: Resource) -> void: # Using Resource as base class
    if not data:
        push_error("CharacterBox: Received null CharacterData")
        return
        
    character_data = data
    
    name_label.text = data.character_name
    var origin_text: String = GlobalEnums.Origin.keys()[data.origin]
    var class_text: String = GlobalEnums.CharacterClass.keys()[data.character_class]
    class_label.text = "%s %s" % [origin_text, class_text]
    
    # Update Core Rules stats
    reactions_value.text = str(data.stats.reactions)
    speed_value.text = str(data.stats.speed)
    combat_skill_value.text = "%+d" % data.stats.combat_skill
    toughness_value.text = str(data.stats.toughness)
    savvy_value.text = "%+d" % data.stats.savvy
    luck_value.text = str(data.stats.luck)
    
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

func get_character_data() -> Resource: # Using Resource as base class since CharacterData is not found
    return character_data