extends Panel

@onready var portrait: TextureRect = $Portrait
@onready var name_label: Label = $NameLabel
@onready var species_label: Label = $SpeciesLabel
@onready var background_label: Label = $BackgroundLabel
@onready var motivation_label: Label = $MotivationLabel
@onready var class_label: Label = $ClassLabel
@onready var stats_container: VBoxContainer = $StatsContainer

func update_preview(character):
    portrait.texture = load(character.portrait)
    name_label.text = character.name
    species_label.text = "Species: " + GlobalEnums.Species.keys()[character.race]
    background_label.text = "Background: " + GlobalEnums.Background.keys()[character.background]
    motivation_label.text = "Motivation: " + GlobalEnums.Motivation.keys()[character.motivation]
    class_label.text = "Class: " + GlobalEnums.Class.keys()[character.character_class]
    
    for stat in character.stats:
        var stat_label = stats_container.get_node(stat.capitalize() + "Label")
        if stat_label:
            stat_label.text = stat.capitalize() + ": " + str(character.stats[stat])
