extends Node

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsCharacter = preload("res://src/core/character/Base/Character.gd")

@export var character_data: FiveParsecsCharacter

func _ready() -> void:
    if not character_data:
        character_data = FiveParsecsCharacter.new()

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

## Safe Property Access Methods
func _get_character_property(data: Resource, property: String, default_value = null) -> Variant:
    if not data:
        push_error("Trying to access property '%s' on null character data" % property)
        return default_value
    if not property in data:
        push_error("Character data missing required property: %s" % property)
        return default_value
    return data.get(property)

func _get_stats_property(stats: Resource, property: String, default_value = 0) -> int:
    if not stats:
        push_error("Trying to access property '%s' on null stats" % property)
        return default_value
    if not property in stats:
        push_error("Stats missing required property: %s" % property)
        return default_value
    return stats.get(property)

func update_display(data: Resource) -> void:
    if not data:
        push_error("CharacterBox: Received null CharacterData")
        return
        
    character_data = data
    
    name_label.text = _get_character_property(data, "character_name", "Unknown")
    var origin = _get_character_property(data, "origin", 0)
    var char_class = _get_character_property(data, "character_class", 0)
    
    var origin_text: String = "Unknown"
    if GlobalEnums and GlobalEnums.get("Origin") and GlobalEnums.Origin.size() > origin:
        origin_text = GlobalEnums.Origin.keys()[origin]
        
    var class_text: String = "Unknown"
    if GlobalEnums and GlobalEnums.get("CharacterClass") and GlobalEnums.CharacterClass.size() > char_class:
        class_text = GlobalEnums.CharacterClass.keys()[char_class]
        
    class_label.text = "%s %s" % [origin_text, class_text]
    
    # Update Core Rules stats
    var stats = _get_character_property(data, "stats", null)
    if stats:
        if is_instance_valid(reactions_value):
            reactions_value.text = str(_get_stats_property(stats, "reactions"))
        if is_instance_valid(speed_value):
            speed_value.text = str(_get_stats_property(stats, "speed"))
        if is_instance_valid(combat_skill_value):
            combat_skill_value.text = "%+d" % _get_stats_property(stats, "combat_skill")
        if is_instance_valid(toughness_value):
            toughness_value.text = str(_get_stats_property(stats, "toughness"))
        if is_instance_valid(savvy_value):
            savvy_value.text = "%+d" % _get_stats_property(stats, "savvy")
        if is_instance_valid(luck_value):
            luck_value.text = str(_get_stats_property(stats, "luck"))
    
    # Update status
    var status = _get_character_property(data, "status", GlobalEnums.CharacterStatus.HEALTHY)
    if is_instance_valid(status_value):
        if GlobalEnums and GlobalEnums.get("CharacterStatus") and GlobalEnums.CharacterStatus.size() > status:
            status_value.text = GlobalEnums.CharacterStatus.keys()[status]
        _update_status_color(status)
    
    # Update portrait if available
    var portrait_texture = _get_character_property(data, "portrait", null)
    if portrait_texture and is_instance_valid(portrait):
        portrait.texture = portrait_texture

func _update_status_color(status: int) -> void:
    if not is_instance_valid(status_value):
        return
        
    var color = Color.WHITE
    if GlobalEnums and GlobalEnums.get("CharacterStatus"):
        match status:
            GlobalEnums.CharacterStatus.HEALTHY:
                color = Color(0, 1, 0, 1) # Green
            GlobalEnums.CharacterStatus.INJURED:
                color = Color(1, 0.5, 0, 1) # Orange
            GlobalEnums.CharacterStatus.CRITICAL:
                color = Color(1, 0, 0, 1) # Red
            GlobalEnums.CharacterStatus.DEAD:
                color = Color(0.5, 0.5, 0.5, 1) # Gray
    status_value.add_theme_color_override("font_color", color)

func get_character_data() -> Resource:
    return character_data