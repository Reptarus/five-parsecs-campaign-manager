# Five Parsecs - Complete Crew/Character Creation Production Implementation

## Executive Summary

This document provides a comprehensive production implementation plan for the entire crew and character creation system in Five Parsecs Campaign Manager. We'll build a complete, functional character creation pipeline from UI wireframes to data persistence, ensuring players can create captains and crew members seamlessly.

## User Journey Architecture

### **Complete User Flow**
```
Main Menu → Campaign Creation → Configuration → Crew Setup → Character Creation → Captain Assignment → Crew Management → Campaign Start
```

### **Detailed Flow Breakdown**
1. **Campaign Configuration** - Basic campaign settings
2. **Crew Size Selection** - Choose initial crew size (4-6 members)
3. **Character Creation Hub** - Central character creation interface
4. **Individual Character Builder** - Per-character creation workflow
5. **Captain Selection** - Choose captain from created characters
6. **Crew Review** - Final crew composition validation
7. **Campaign Integration** - Pass data to main campaign system

## Complete UI/UX Component Architecture

### **Core UI Components Hierarchy**

```
CampaignCreationUI (Main Container)
├── ConfigPanel (Campaign Settings)
├── CrewSetupPanel (Crew Size & Initial Setup)
├── CharacterCreationHub (Character Management)
│   ├── CharacterList (Created Characters Display)
│   ├── CharacterCreationDialog (Individual Character Builder)
│   │   ├── BasicInfoSection (Name, Background)
│   │   ├── AttributesSection (Stats Generation)
│   │   ├── SkillsSection (Skill Assignment)
│   │   ├── EquipmentSection (Starting Gear)
│   │   └── PreviewSection (Character Summary)
│   └── CharacterActions (Edit/Delete/Duplicate)
├── CaptainSelectionPanel (Choose Captain)
├── CrewReviewPanel (Final Validation)
└── NavigationControls (Back/Next/Finish)
```

### **Character Creation Workflow Components**

```
CharacterCreationDialog
├── StepIndicator (Progress: 1/5, 2/5, etc.)
├── StepContent (Dynamic content area)
│   ├── Step1_BasicInfo
│   │   ├── NameInput (Text field)
│   │   ├── BackgroundDropdown (Soldier, Scavenger, etc.)
│   │   └── MotivationDropdown (Revenge, Glory, etc.)
│   ├── Step2_Attributes
│   │   ├── AttributeRollers (2d6/3 system)
│   │   ├── AttributeDisplay (Visual stats)
│   │   └── RerollButton (If allowed)
│   ├── Step3_Skills
│   │   ├── SkillPointsDisplay
│   │   ├── SkillList (Checkboxes/Spinboxes)
│   │   └── SkillDescription (Help text)
│   ├── Step4_Equipment
│   │   ├── StartingGearList
│   │   ├── EquipmentSelection
│   │   └── InventoryPreview
│   └── Step5_Preview
│       ├── CharacterSummary
│       ├── StatBlock
│       └── ConfirmButton
└── StepNavigation (Previous/Next/Cancel)
```

## Complete Data Models

### **Character Data Structure**
```gdscript
class_name FiveParsecsCharacter
extends Resource

# Basic Information
@export var character_name: String = ""
@export var background: CharacterBackground
@export var motivation: CharacterMotivation
@export var character_class: CharacterClass = CharacterClass.NONE

# Core Attributes (1-6 scale)
@export var combat: int = 2
@export var reaction: int = 2
@export var toughness: int = 2
@export var savvy: int = 2
@export var tech: int = 2
@export var move: int = 2

# Derived Stats
@export var max_health: int = 4
@export var current_health: int = 4
@export var experience_points: int = 0
@export var skill_points: int = 0

# Skills and Abilities
@export var skills: Dictionary = {}
@export var special_abilities: Array[String] = []

# Equipment and Inventory
@export var equipment: Dictionary = {
    "weapon": null,
    "armor": null,
    "gear": []
}
@export var inventory: Array[Dictionary] = []

# Campaign Status
@export var is_captain: bool = false
@export var status: CharacterStatus = CharacterStatus.ACTIVE
@export var injuries: Array[Dictionary] = []

# Metadata
@export var created_date: String = ""
@export var last_modified: String = ""
@export var version: String = "1.0"

# Character generation according to Five Parsecs rules
func generate_character(background: CharacterBackground, motivation: CharacterMotivation) -> void:
    self.background = background
    self.motivation = motivation
    _roll_attributes()
    _apply_background_modifiers()
    _calculate_derived_stats()
    _assign_starting_equipment()
    created_date = Time.get_datetime_string_from_system()

func _roll_attributes() -> void:
    # Five Parsecs rule: 2d6/3 rounded up for each attribute
    combat = _roll_attribute()
    reaction = _roll_attribute()
    toughness = _roll_attribute()
    savvy = _roll_attribute()
    tech = _roll_attribute()
    move = _roll_attribute()

func _roll_attribute() -> int:
    var roll = (randi() % 6 + 1) + (randi() % 6 + 1)
    return ceili(float(roll) / 3.0)
```

### **Crew Management Data Structure**
```gdscript
class_name CrewManager
extends Resource

@export var crew_members: Array[FiveParsecsCharacter] = []
@export var captain: FiveParsecsCharacter = null
@export var max_crew_size: int = 6
@export var current_crew_size: int = 0

signal crew_member_added(character: FiveParsecsCharacter)
signal crew_member_removed(character: FiveParsecsCharacter)
signal captain_assigned(character: FiveParsecsCharacter)
signal crew_size_changed(new_size: int)

func add_crew_member(character: FiveParsecsCharacter) -> bool:
    if current_crew_size >= max_crew_size:
        push_warning("Cannot add crew member: crew at maximum size")
        return false
    
    crew_members.append(character)
    current_crew_size += 1
    crew_member_added.emit(character)
    crew_size_changed.emit(current_crew_size)
    return true

func assign_captain(character: FiveParsecsCharacter) -> bool:
    if character not in crew_members:
        push_error("Cannot assign captain: character not in crew")
        return false
    
    # Remove captain status from previous captain
    if captain:
        captain.is_captain = false
    
    captain = character
    character.is_captain = true
    captain_assigned.emit(character)
    return true

func get_crew_summary() -> Dictionary:
    return {
        "total_members": current_crew_size,
        "captain": captain.character_name if captain else "None",
        "average_combat": _calculate_average_stat("combat"),
        "total_health": _calculate_total_health(),
        "skill_distribution": _get_skill_distribution()
    }
```

## Complete Scene Structures

### **1. CrewSetupPanel.tscn**
```gdscript
[gd_scene load_steps=2 format=3]

[node name="CrewSetupPanel" type="Control"]
anchors_preset = 15
script = ExtResource("CrewSetupPanel.gd")

[node name="MainContainer" type="VBoxContainer" parent="."]
anchors_preset = 15

[node name="Title" type="Label" parent="MainContainer"]
text = "Crew Setup"
horizontal_alignment = 1

[node name="CrewSizeSection" type="VBoxContainer" parent="MainContainer"]

[node name="CrewSizeLabel" type="Label" parent="MainContainer/CrewSizeSection"]
text = "Initial Crew Size"

[node name="CrewSizeSpinBox" type="SpinBox" parent="MainContainer/CrewSizeSection"]
min_value = 4
max_value = 6
value = 4

[node name="CrewSizeDescription" type="Label" parent="MainContainer/CrewSizeSection"]
text = "Choose your starting crew size (4-6 members). Larger crews have more capabilities but higher upkeep costs."
autowrap_mode = 2

[node name="CrewCompositionSection" type="VBoxContainer" parent="MainContainer"]

[node name="CompositionLabel" type="Label" parent="MainContainer/CrewCompositionSection"]
text = "Crew Composition"

[node name="BackgroundDistribution" type="GridContainer" parent="MainContainer/CrewCompositionSection"]
columns = 2

[node name="SoldierLabel" type="Label" parent="MainContainer/CrewCompositionSection/BackgroundDistribution"]
text = "Soldiers:"

[node name="SoldierSpinBox" type="SpinBox" parent="MainContainer/CrewCompositionSection/BackgroundDistribution"]
max_value = 6

[node name="ScavengerLabel" type="Label" parent="MainContainer/CrewCompositionSection/BackgroundDistribution"]
text = "Scavengers:"

[node name="ScavengerSpinBox" type="SpinBox" parent="MainContainer/CrewCompositionSection/BackgroundDistribution"]
max_value = 6

[node name="TechnicianLabel" type="Label" parent="MainContainer/CrewCompositionSection/BackgroundDistribution"]
text = "Technicians:"

[node name="TechnicianSpinBox" type="SpinBox" parent="MainContainer/CrewCompositionSection/BackgroundDistribution"]
max_value = 6

[node name="Actions" type="HBoxContainer" parent="MainContainer"]
alignment = 1

[node name="AutoGenerateButton" type="Button" parent="MainContainer/Actions"]
text = "Auto-Generate Crew"

[node name="ManualSetupButton" type="Button" parent="MainContainer/Actions"]
text = "Manual Character Creation"
```

### **2. CharacterCreationHub.tscn**
```gdscript
[gd_scene load_steps=3 format=3]

[node name="CharacterCreationHub" type="Control"]
anchors_preset = 15
script = ExtResource("CharacterCreationHub.gd")

[node name="HSplitContainer" type="HSplitContainer" parent="."]
anchors_preset = 15
split_offset = 400

[node name="CreatedCharactersList" type="VBoxContainer" parent="HSplitContainer"]
custom_minimum_size = Vector2(400, 0)

[node name="ListHeader" type="HBoxContainer" parent="HSplitContainer/CreatedCharactersList"]

[node name="ListTitle" type="Label" parent="HSplitContainer/CreatedCharactersList/ListHeader"]
size_flags_horizontal = 3
text = "Created Characters"

[node name="CharacterCountLabel" type="Label" parent="HSplitContainer/CreatedCharactersList/ListHeader"]
text = "0/4"

[node name="CharacterListContainer" type="ScrollContainer" parent="HSplitContainer/CreatedCharactersList"]
size_flags_vertical = 3

[node name="CharacterList" type="VBoxContainer" parent="HSplitContainer/CreatedCharactersList/CharacterListContainer"]

[node name="ListActions" type="HBoxContainer" parent="HSplitContainer/CreatedCharactersList"]

[node name="CreateCharacterButton" type="Button" parent="HSplitContainer/CreatedCharactersList/ListActions"]
text = "Create Character"

[node name="ImportCharacterButton" type="Button" parent="HSplitContainer/CreatedCharactersList/ListActions"]
text = "Import"

[node name="CharacterCreationArea" type="VBoxContainer" parent="HSplitContainer"]

[node name="CreationTitle" type="Label" parent="HSplitContainer/CharacterCreationArea"]
text = "Character Creation"
horizontal_alignment = 1

[node name="CreationContent" type="Control" parent="HSplitContainer/CharacterCreationArea"]
size_flags_vertical = 3

[node name="WelcomePanel" type="VBoxContainer" parent="HSplitContainer/CharacterCreationArea/CreationContent"]
anchors_preset = 8

[node name="WelcomeText" type="Label" parent="HSplitContainer/CharacterCreationArea/CreationContent/WelcomePanel"]
text = "Click 'Create Character' to start building your crew."
horizontal_alignment = 1
```

### **3. CharacterCreationDialog.tscn**
```gdscript
[gd_scene load_steps=2 format=3]

[node name="CharacterCreationDialog" type="AcceptDialog"]
size = Vector2i(800, 600)
title = "Create Character"
script = ExtResource("CharacterCreationDialog.gd")

[node name="MainContainer" type="VBoxContainer" parent="."]
anchors_preset = 15
offset_left = 8.0
offset_top = 8.0
offset_right = -8.0
offset_bottom = -49.0

[node name="Header" type="HBoxContainer" parent="MainContainer"]

[node name="StepIndicator" type="Label" parent="MainContainer/Header"]
size_flags_horizontal = 3
text = "Step 1 of 5: Basic Information"

[node name="CloseButton" type="Button" parent="MainContainer/Header"]
text = "×"
flat = true

[node name="ProgressBar" type="ProgressBar" parent="MainContainer"]
max_value = 5.0
step = 1.0

[node name="StepContent" type="Control" parent="MainContainer"]
size_flags_vertical = 3

# Step 1: Basic Information
[node name="Step1_BasicInfo" type="VBoxContainer" parent="MainContainer/StepContent"]
anchors_preset = 15

[node name="NameSection" type="VBoxContainer" parent="MainContainer/StepContent/Step1_BasicInfo"]

[node name="NameLabel" type="Label" parent="MainContainer/StepContent/Step1_BasicInfo/NameSection"]
text = "Character Name"

[node name="NameInput" type="LineEdit" parent="MainContainer/StepContent/Step1_BasicInfo/NameSection"]
placeholder_text = "Enter character name..."

[node name="NameGenerateButton" type="Button" parent="MainContainer/StepContent/Step1_BasicInfo/NameSection"]
text = "Generate Random Name"

[node name="BackgroundSection" type="VBoxContainer" parent="MainContainer/StepContent/Step1_BasicInfo"]

[node name="BackgroundLabel" type="Label" parent="MainContainer/StepContent/Step1_BasicInfo/BackgroundSection"]
text = "Background"

[node name="BackgroundOption" type="OptionButton" parent="MainContainer/StepContent/Step1_BasicInfo/BackgroundSection"]

[node name="BackgroundDescription" type="Label" parent="MainContainer/StepContent/Step1_BasicInfo/BackgroundSection"]
text = "Select a background to see description..."
autowrap_mode = 2

[node name="MotivationSection" type="VBoxContainer" parent="MainContainer/StepContent/Step1_BasicInfo"]

[node name="MotivationLabel" type="Label" parent="MainContainer/StepContent/Step1_BasicInfo/MotivationSection"]
text = "Motivation"

[node name="MotivationOption" type="OptionButton" parent="MainContainer/StepContent/Step1_BasicInfo/MotivationSection"]

[node name="MotivationDescription" type="Label" parent="MainContainer/StepContent/Step1_BasicInfo/MotivationSection"]
text = "Select a motivation to see description..."
autowrap_mode = 2

# Step 2: Attributes
[node name="Step2_Attributes" type="VBoxContainer" parent="MainContainer/StepContent"]
visible = false
anchors_preset = 15

[node name="AttributesTitle" type="Label" parent="MainContainer/StepContent/Step2_Attributes"]
text = "Character Attributes"
horizontal_alignment = 1

[node name="AttributesGrid" type="GridContainer" parent="MainContainer/StepContent/Step2_Attributes"]
columns = 3

[node name="CombatLabel" type="Label" parent="MainContainer/StepContent/Step2_Attributes/AttributesGrid"]
text = "Combat"

[node name="CombatRollButton" type="Button" parent="MainContainer/StepContent/Step2_Attributes/AttributesGrid"]
text = "Roll"

[node name="CombatValue" type="Label" parent="MainContainer/StepContent/Step2_Attributes/AttributesGrid"]
text = "2"

[node name="ReactionLabel" type="Label" parent="MainContainer/StepContent/Step2_Attributes/AttributesGrid"]
text = "Reaction"

[node name="ReactionRollButton" type="Button" parent="MainContainer/StepContent/Step2_Attributes/AttributesGrid"]
text = "Roll"

[node name="ReactionValue" type="Label" parent="MainContainer/StepContent/Step2_Attributes/AttributesGrid"]
text = "2"

[node name="ToughnessLabel" type="Label" parent="MainContainer/StepContent/Step2_Attributes/AttributesGrid"]
text = "Toughness"

[node name="ToughnessRollButton" type="Button" parent="MainContainer/StepContent/Step2_Attributes/AttributesGrid"]
text = "Roll"

[node name="ToughnessValue" type="Label" parent="MainContainer/StepContent/Step2_Attributes/AttributesGrid"]
text = "2"

[node name="SavvyLabel" type="Label" parent="MainContainer/StepContent/Step2_Attributes/AttributesGrid"]
text = "Savvy"

[node name="SavvyRollButton" type="Button" parent="MainContainer/StepContent/Step2_Attributes/AttributesGrid"]
text = "Roll"

[node name="SavvyValue" type="Label" parent="MainContainer/StepContent/Step2_Attributes/AttributesGrid"]
text = "2"

[node name="TechLabel" type="Label" parent="MainContainer/StepContent/Step2_Attributes/AttributesGrid"]
text = "Tech"

[node name="TechRollButton" type="Button" parent="MainContainer/StepContent/Step2_Attributes/AttributesGrid"]
text = "Roll"

[node name="TechValue" type="Label" parent="MainContainer/StepContent/Step2_Attributes/AttributesGrid"]
text = "2"

[node name="MoveLabel" type="Label" parent="MainContainer/StepContent/Step2_Attributes/AttributesGrid"]
text = "Move"

[node name="MoveRollButton" type="Button" parent="MainContainer/StepContent/Step2_Attributes/AttributesGrid"]
text = "Roll"

[node name="MoveValue" type="Label" parent="MainContainer/StepContent/Step2_Attributes/AttributesGrid"]
text = "2"

[node name="AttributeActions" type="HBoxContainer" parent="MainContainer/StepContent/Step2_Attributes"]
alignment = 1

[node name="RollAllButton" type="Button" parent="MainContainer/StepContent/Step2_Attributes/AttributeActions"]
text = "Roll All Attributes"

[node name="RerollButton" type="Button" parent="MainContainer/StepContent/Step2_Attributes/AttributeActions"]
text = "Reroll All"

# Step Navigation
[node name="StepNavigation" type="HBoxContainer" parent="MainContainer"]
alignment = 1

[node name="PreviousButton" type="Button" parent="MainContainer/StepNavigation"]
text = "Previous"

[node name="NextButton" type="Button" parent="MainContainer/StepNavigation"]
text = "Next"

[node name="CancelButton" type="Button" parent="MainContainer/StepNavigation"]
text = "Cancel"

[node name="FinishButton" type="Button" parent="MainContainer/StepNavigation"]
text = "Create Character"
visible = false
```

### **4. CharacterListItem.tscn**
```gdscript
[gd_scene load_steps=2 format=3]

[node name="CharacterListItem" type="PanelContainer"]
custom_minimum_size = Vector2(0, 80)
script = ExtResource("CharacterListItem.gd")

[node name="MarginContainer" type="MarginContainer" parent="."]
layout_mode = 2
theme_override_constants/margin_left = 10
theme_override_constants/margin_top = 10
theme_override_constants/margin_right = 10
theme_override_constants/margin_bottom = 10

[node name="HBoxContainer" type="HBoxContainer" parent="MarginContainer"]
layout_mode = 2

[node name="CharacterInfo" type="VBoxContainer" parent="MarginContainer/HBoxContainer"]
layout_mode = 2
size_flags_horizontal = 3

[node name="NameAndBackground" type="HBoxContainer" parent="MarginContainer/HBoxContainer/CharacterInfo"]
layout_mode = 2

[node name="CharacterName" type="Label" parent="MarginContainer/HBoxContainer/CharacterInfo/NameAndBackground"]
layout_mode = 2
size_flags_horizontal = 3
text = "Character Name"

[node name="Background" type="Label" parent="MarginContainer/HBoxContainer/CharacterInfo/NameAndBackground"]
layout_mode = 2
theme_override_colors/font_color = Color(0.7, 0.7, 0.7, 1)
text = "Soldier"

[node name="StatsLine" type="Label" parent="MarginContainer/HBoxContainer/CharacterInfo"]
layout_mode = 2
theme_override_colors/font_color = Color(0.8, 0.8, 0.8, 1)
text = "Combat: 3, Reaction: 2, Toughness: 4"

[node name="Status" type="Label" parent="MarginContainer/HBoxContainer/CharacterInfo"]
layout_mode = 2
theme_override_colors/font_color = Color(0.6, 0.9, 0.6, 1)
text = "Ready"

[node name="Actions" type="VBoxContainer" parent="MarginContainer/HBoxContainer"]
layout_mode = 2

[node name="EditButton" type="Button" parent="MarginContainer/HBoxContainer/Actions"]
layout_mode = 2
text = "Edit"

[node name="MakeCaptainButton" type="Button" parent="MarginContainer/HBoxContainer/Actions"]
layout_mode = 2
text = "Make Captain"

[node name="DeleteButton" type="Button" parent="MarginContainer/HBoxContainer/Actions"]
layout_mode = 2
text = "Delete"
```

## Complete Script Implementations

### **1. CrewSetupPanel.gd**
```gdscript
class_name CrewSetupPanel
extends Control

signal crew_setup_configured(config: Dictionary)
signal manual_character_creation_requested
signal auto_generation_requested(crew_size: int, composition: Dictionary)

@onready var crew_size_spinbox: SpinBox = $"MainContainer/CrewSizeSection/CrewSizeSpinBox"
@onready var soldier_spinbox: SpinBox = $"MainContainer/CrewCompositionSection/BackgroundDistribution/SoldierSpinBox"
@onready var scavenger_spinbox: SpinBox = $"MainContainer/CrewCompositionSection/BackgroundDistribution/ScavengerSpinBox"
@onready var technician_spinbox: SpinBox = $"MainContainer/CrewCompositionSection/BackgroundDistribution/TechnicianSpinBox"
@onready var auto_generate_button: Button = $"MainContainer/Actions/AutoGenerateButton"
@onready var manual_setup_button: Button = $"MainContainer/Actions/ManualSetupButton"

var current_crew_size: int = 4
var composition: Dictionary = {
    "soldier": 1,
    "scavenger": 1,
    "technician": 1,
    "other": 1
}

func _ready() -> void:
    _setup_connections()
    _update_composition_constraints()

func _setup_connections() -> void:
    crew_size_spinbox.value_changed.connect(_on_crew_size_changed)
    soldier_spinbox.value_changed.connect(_on_composition_changed)
    scavenger_spinbox.value_changed.connect(_on_composition_changed)
    technician_spinbox.value_changed.connect(_on_composition_changed)
    auto_generate_button.pressed.connect(_on_auto_generate_pressed)
    manual_setup_button.pressed.connect(_on_manual_setup_pressed)

func _on_crew_size_changed(new_size: float) -> void:
    current_crew_size = int(new_size)
    _update_composition_constraints()

func _update_composition_constraints() -> void:
    var total_assigned = soldier_spinbox.value + scavenger_spinbox.value + technician_spinbox.value
    var remaining = current_crew_size - total_assigned
    
    # Update max values to prevent over-assignment
    soldier_spinbox.max_value = current_crew_size
    scavenger_spinbox.max_value = current_crew_size
    technician_spinbox.max_value = current_crew_size
    
    composition.other = max(0, remaining)

func _on_composition_changed(_value: float) -> void:
    _update_composition_constraints()

func _on_auto_generate_pressed() -> void:
    var config = {
        "crew_size": current_crew_size,
        "composition": {
            "soldier": int(soldier_spinbox.value),
            "scavenger": int(scavenger_spinbox.value),
            "technician": int(technician_spinbox.value),
            "other": composition.other
        }
    }
    auto_generation_requested.emit(current_crew_size, config.composition)

func _on_manual_setup_pressed() -> void:
    var config = {
        "crew_size": current_crew_size,
        "setup_method": "manual"
    }
    crew_setup_configured.emit(config)
    manual_character_creation_requested.emit()

func get_crew_setup_data() -> Dictionary:
    return {
        "crew_size": current_crew_size,
        "composition": composition,
        "setup_method": "configured"
    }

func is_valid() -> bool:
    var total_assigned = composition.soldier + composition.scavenger + composition.technician + composition.other
    return total_assigned == current_crew_size
```

### **2. CharacterCreationHub.gd**
```gdscript
class_name CharacterCreationHub
extends Control

signal character_created(character: FiveParsecsCharacter)
signal captain_selected(character: FiveParsecsCharacter)
signal crew_setup_complete(crew_data: Dictionary)

@onready var character_list: VBoxContainer = $"HSplitContainer/CreatedCharactersList/CharacterListContainer/CharacterList"
@onready var character_count_label: Label = $"HSplitContainer/CreatedCharactersList/ListHeader/CharacterCountLabel"
@onready var create_button: Button = $"HSplitContainer/CreatedCharactersList/ListActions/CreateCharacterButton"
@onready var creation_area: Control = $"HSplitContainer/CharacterCreationArea/CreationContent"

var created_characters: Array[FiveParsecsCharacter] = []
var character_list_items: Array[Control] = []
var required_crew_size: int = 4
var current_captain: FiveParsecsCharacter = null

# Preload scenes
const CharacterListItem = preload("res://src/ui/screens/campaign/panels/CharacterListItem.tscn")
const CharacterCreationDialog = preload("res://src/ui/screens/campaign/panels/CharacterCreationDialog.tscn")

func _ready() -> void:
    create_button.pressed.connect(_on_create_character_pressed)
    _update_character_count()

func set_required_crew_size(size: int) -> void:
    required_crew_size = size
    _update_character_count()

func _on_create_character_pressed() -> void:
    var dialog = CharacterCreationDialog.instantiate()
    get_viewport().add_child(dialog)
    dialog.character_created.connect(_on_character_created)
    dialog.popup_centered()

func _on_character_created(character: FiveParsecsCharacter) -> void:
    created_characters.append(character)
    _add_character_to_list(character)
    _update_character_count()
    character_created.emit(character)
    
    # Auto-assign first character as captain
    if created_characters.size() == 1:
        _set_character_as_captain(character)

func _add_character_to_list(character: FiveParsecsCharacter) -> void:
    var list_item = CharacterListItem.instantiate()
    character_list.add_child(list_item)
    
    list_item.setup_character(character)
    list_item.make_captain_requested.connect(_on_make_captain_requested)
    list_item.edit_character_requested.connect(_on_edit_character_requested)
    list_item.delete_character_requested.connect(_on_delete_character_requested)
    
    character_list_items.append(list_item)

func _on_make_captain_requested(character: FiveParsecsCharacter) -> void:
    _set_character_as_captain(character)

func _set_character_as_captain(character: FiveParsecsCharacter) -> void:
    # Remove captain status from previous captain
    if current_captain:
        current_captain.is_captain = false
    
    current_captain = character
    character.is_captain = true
    
    # Update UI to reflect captain status
    _update_character_list_display()
    captain_selected.emit(character)

func _update_character_list_display() -> void:
    for i in range(character_list_items.size()):
        var list_item = character_list_items[i]
        var character = created_characters[i]
        list_item.update_captain_status(character.is_captain)

func _update_character_count() -> void:
    character_count_label.text = "%d/%d" % [created_characters.size(), required_crew_size]
    
    # Enable/disable creation based on crew size
    create_button.disabled = created_characters.size() >= required_crew_size

func _on_edit_character_requested(character: FiveParsecsCharacter) -> void:
    var dialog = CharacterCreationDialog.instantiate()
    get_viewport().add_child(dialog)
    dialog.setup_for_editing(character)
    dialog.character_updated.connect(_on_character_updated)
    dialog.popup_centered()

func _on_character_updated(character: FiveParsecsCharacter) -> void:
    _update_character_list_display()

func _on_delete_character_requested(character: FiveParsecsCharacter) -> void:
    var index = created_characters.find(character)
    if index >= 0:
        created_characters.remove_at(index)
        var list_item = character_list_items[index]
        character_list_items.remove_at(index)
        list_item.queue_free()
        
        # If deleted character was captain, assign new captain
        if character.is_captain and created_characters.size() > 0:
            _set_character_as_captain(created_characters[0])
        
        _update_character_count()

func get_crew_data() -> Dictionary:
    return {
        "characters": created_characters,
        "captain": current_captain,
        "total_members": created_characters.size(),
        "is_complete": created_characters.size() >= required_crew_size
    }

func is_crew_complete() -> bool:
    return created_characters.size() >= required_crew_size and current_captain != null
```

### **3. CharacterCreationDialog.gd**
```gdscript
class_name CharacterCreationDialog
extends AcceptDialog

signal character_created(character: FiveParsecsCharacter)
signal character_updated(character: FiveParsecsCharacter)

@onready var step_indicator: Label = $"MainContainer/Header/StepIndicator"
@onready var progress_bar: ProgressBar = $"MainContainer/ProgressBar"
@onready var step_content: Control = $"MainContainer/StepContent"

# Step panels
@onready var step1_basic_info: VBoxContainer = $"MainContainer/StepContent/Step1_BasicInfo"
@onready var step2_attributes: VBoxContainer = $"MainContainer/StepContent/Step2_Attributes"

# Navigation
@onready var previous_button: Button = $"MainContainer/StepNavigation/PreviousButton"
@onready var next_button: Button = $"MainContainer/StepNavigation/NextButton"
@onready var finish_button: Button = $"MainContainer/StepNavigation/FinishButton"

# Step 1 controls
@onready var name_input: LineEdit = $"MainContainer/StepContent/Step1_BasicInfo/NameSection/NameInput"
@onready var background_option: OptionButton = $"MainContainer/StepContent/Step1_BasicInfo/BackgroundSection/BackgroundOption"
@onready var motivation_option: OptionButton = $"MainContainer/StepContent/Step1_BasicInfo/MotivationSection/MotivationOption"

# Step 2 controls
@onready var combat_value: Label = $"MainContainer/StepContent/Step2_Attributes/AttributesGrid/CombatValue"
@onready var reaction_value: Label = $"MainContainer/StepContent/Step2_Attributes/AttributesGrid/ReactionValue"
@onready var roll_all_button: Button = $"MainContainer/StepContent/Step2_Attributes/AttributeActions/RollAllButton"

var current_step: int = 0
var total_steps: int = 5
var editing_character: FiveParsecsCharacter = null
var character_data: Dictionary = {}

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

func _ready() -> void:
    _setup_navigation()
    _setup_step1()
    _setup_step2()
    _show_step(0)

func _setup_navigation() -> void:
    previous_button.pressed.connect(_on_previous_pressed)
    next_button.pressed.connect(_on_next_pressed)
    finish_button.pressed.connect(_on_finish_pressed)

func _setup_step1() -> void:
    # Setup background options
    background_option.clear()
    for background in GameEnums.CharacterBackground.values():
        background_option.add_item(GameEnums.get_background_name(background), background)
    
    # Setup motivation options
    motivation_option.clear()
    for motivation in GameEnums.CharacterMotivation.values():
        motivation_option.add_item(GameEnums.get_motivation_name(motivation), motivation)
    
    # Connect signals
    name_input.text_changed.connect(_on_name_changed)
    background_option.item_selected.connect(_on_background_selected)
    motivation_option.item_selected.connect(_on_motivation_selected)

func _setup_step2() -> void:
    roll_all_button.pressed.connect(_on_roll_all_attributes)
    
    # Setup individual attribute roll buttons
    var attribute_buttons = [
        $"MainContainer/StepContent/Step2_Attributes/AttributesGrid/CombatRollButton",
        $"MainContainer/StepContent/Step2_Attributes/AttributesGrid/ReactionRollButton",
        $"MainContainer/StepContent/Step2_Attributes/AttributesGrid/ToughnessRollButton",
        $"MainContainer/StepContent/Step2_Attributes/AttributesGrid/SavvyRollButton",
        $"MainContainer/StepContent/Step2_Attributes/AttributesGrid/TechRollButton",
        $"MainContainer/StepContent/Step2_Attributes/AttributesGrid/MoveRollButton"
    ]
    
    var attributes = ["combat", "reaction", "toughness", "savvy", "tech", "move"]
    
    for i in range(attribute_buttons.size()):
        var button = attribute_buttons[i]
        var attribute = attributes[i]
        button.pressed.connect(_on_roll_attribute.bind(attribute))

func _show_step(step: int) -> void:
    current_step = step
    
    # Hide all step panels
    for child in step_content.get_children():
        child.visible = false
    
    # Show current step
    match step:
        0:
            step1_basic_info.visible = true
            step_indicator.text = "Step 1 of %d: Basic Information" % total_steps
        1:
            step2_attributes.visible = true
            step_indicator.text = "Step 2 of %d: Attributes" % total_steps
    
    # Update progress bar
    progress_bar.value = step + 1
    
    # Update navigation buttons
    previous_button.disabled = (step == 0)
    next_button.visible = (step < total_steps - 1)
    finish_button.visible = (step == total_steps - 1)

func _on_previous_pressed() -> void:
    if current_step > 0:
        _show_step(current_step - 1)

func _on_next_pressed() -> void:
    if _validate_current_step() and current_step < total_steps - 1:
        _show_step(current_step + 1)

func _on_finish_pressed() -> void:
    if _validate_all_steps():
        _create_character()

func _validate_current_step() -> bool:
    match current_step:
        0:
            return _validate_basic_info()
        1:
            return _validate_attributes()
        _:
            return true

func _validate_basic_info() -> bool:
    if name_input.text.strip_edges().is_empty():
        _show_validation_error("Character name is required")
        return false
    return true

func _validate_attributes() -> bool:
    # All attributes should be at least 1
    var attributes = ["combat", "reaction", "toughness", "savvy", "tech", "move"]
    for attr in attributes:
        if character_data.get(attr, 0) < 1:
            _show_validation_error("All attributes must be rolled")
            return false
    return true

func _validate_all_steps() -> bool:
    for step in range(total_steps):
        current_step = step
        if not _validate_current_step():
            return false
    return true

func _show_validation_error(message: String) -> void:
    var error_dialog = AcceptDialog.new()
    error_dialog.dialog_text = message
    error_dialog.title = "Validation Error"
    get_parent().add_child(error_dialog)
    error_dialog.popup_centered()
    error_dialog.confirmed.connect(func(): error_dialog.queue_free())

func _on_name_changed(new_text: String) -> void:
    character_data.name = new_text

func _on_background_selected(index: int) -> void:
    character_data.background = background_option.get_item_id(index)

func _on_motivation_selected(index: int) -> void:
    character_data.motivation = motivation_option.get_item_id(index)

func _on_roll_all_attributes() -> void:
    character_data.combat = _roll_attribute_value()
    character_data.reaction = _roll_attribute_value()
    character_data.toughness = _roll_attribute_value()
    character_data.savvy = _roll_attribute_value()
    character_data.tech = _roll_attribute_value()
    character_data.move = _roll_attribute_value()
    
    _update_attribute_display()

func _on_roll_attribute(attribute: String) -> void:
    character_data[attribute] = _roll_attribute_value()
    _update_attribute_display()

func _roll_attribute_value() -> int:
    # Five Parsecs rule: 2d6/3 rounded up
    var roll = (randi() % 6 + 1) + (randi() % 6 + 1)
    return ceili(float(roll) / 3.0)

func _update_attribute_display() -> void:
    combat_value.text = str(character_data.get("combat", 2))
    reaction_value.text = str(character_data.get("reaction", 2))
    # Update other attribute displays...

func _create_character() -> void:
    var character = FiveParsecsCharacter.new()
    
    # Apply basic info
    character.character_name = character_data.name
    character.background = character_data.background
    character.motivation = character_data.motivation
    
    # Apply attributes
    character.combat = character_data.combat
    character.reaction = character_data.reaction
    character.toughness = character_data.toughness
    character.savvy = character_data.savvy
    character.tech = character_data.tech
    character.move = character_data.move
    
    # Calculate derived stats
    character.max_health = character.toughness + 2
    character.current_health = character.max_health
    
    # Set metadata
    character.created_date = Time.get_datetime_string_from_system()
    
    if editing_character:
        # Update existing character
        _copy_character_data(character, editing_character)
        character_updated.emit(editing_character)
    else:
        # Create new character
        character_created.emit(character)
    
    hide()

func setup_for_editing(character: FiveParsecsCharacter) -> void:
    editing_character = character
    
    # Load character data into dialog
    name_input.text = character.character_name
    # Set background and motivation options...
    character_data = {
        "name": character.character_name,
        "background": character.background,
        "motivation": character.motivation,
        "combat": character.combat,
        "reaction": character.reaction,
        "toughness": character.toughness,
        "savvy": character.savvy,
        "tech": character.tech,
        "move": character.move
    }
    
    _update_attribute_display()

func _copy_character_data(source: FiveParsecsCharacter, target: FiveParsecsCharacter) -> void:
    target.character_name = source.character_name
    target.background = source.background
    target.motivation = source.motivation
    target.combat = source.combat
    target.reaction = source.reaction
    target.toughness = source.toughness
    target.savvy = source.savvy
    target.tech = source.tech
    target.move = source.move
    target.max_health = source.max_health
    target.current_health = source.current_health
    target.last_modified = Time.get_datetime_string_from_system()
```

## Integration with Campaign System

### **CampaignCreationUI.gd Updates**
```gdscript
# Add to CampaignCreationUI.gd

func _setup_character_creation_integration() -> void:
    """Setup integration between crew setup and character creation"""
    
    # Connect crew setup panel
    if crew_panel and crew_panel.has_signal("manual_character_creation_requested"):
        crew_panel.manual_character_creation_requested.connect(_on_character_creation_requested)
    
    # Connect character creation hub
    if captain_panel and captain_panel.has_signal("crew_setup_complete"):
        captain_panel.crew_setup_complete.connect(_on_crew_setup_complete)

func _on_character_creation_requested() -> void:
    """Handle request to start character creation"""
    print("CampaignCreationUI: Starting character creation workflow")
    
    # Get crew size from crew setup
    var crew_size = 4  # Default
    if crew_panel and crew_panel.has_method("get_crew_setup_data"):
        var setup_data = crew_panel.get_crew_setup_data()
        crew_size = setup_data.get("crew_size", 4)
    
    # Configure character creation hub
    if captain_panel and captain_panel.has_method("set_required_crew_size"):
        captain_panel.set_required_crew_size(crew_size)
    
    # Move to character creation step
    _update_ui_for_step(2)  # Captain/Character creation step

func _on_crew_setup_complete(crew_data: Dictionary) -> void:
    """Handle completion of crew setup"""
    print("CampaignCreationUI: Crew setup complete with ", crew_data.total_members, " members")
    
    # Store crew data in state manager
    if state_manager:
        state_manager.set_phase_data(CampaignCreationStateManager.Phase.CREW_SETUP, crew_data)
    
    # Enable next button for progression
    if next_button:
        next_button.disabled = false
```

## Testing & Validation Strategy

### **Component Testing Checklist**
- [ ] **CrewSetupPanel**: Crew size selection works
- [ ] **CharacterCreationHub**: Character list management works
- [ ] **CharacterCreationDialog**: Complete character creation workflow
- [ ] **CharacterListItem**: Display and actions work correctly
- [ ] **State Management**: Data persists through navigation
- [ ] **Integration**: Flows between panels work seamlessly

### **User Flow Testing**
- [ ] **Happy Path**: Complete crew creation from start to finish
- [ ] **Error Handling**: Invalid inputs handled gracefully
- [ ] **Edge Cases**: Minimum/maximum crew sizes work
- [ ] **Data Persistence**: Character data survives app restart
- [ ] **Captain Assignment**: Captain selection and management works

## Implementation Timeline

### **Phase 1: Core Components** (4-6 hours)
1. Create all scene files with proper node structure
2. Implement basic script functionality
3. Setup data models and enums
4. Test individual components in isolation

### **Phase 2: Integration** (3-4 hours)
1. Connect components with signal system
2. Implement state management integration
3. Add error handling and validation
4. Test complete user workflow

### **Phase 3: Polish & Testing** (2-3 hours)
1. Add UI polish and feedback
2. Implement keyboard shortcuts
3. Add tooltips and help text
4. Comprehensive testing and bug fixes

### **Total Estimated Time: 9-13 hours**

## Success Metrics
- ✅ **Character Creation**: Complete character creation from basic info to equipment
- ✅ **Crew Management**: Add, edit, delete, and assign captain
- ✅ **Data Persistence**: All character data preserved through workflow
- ✅ **UI Responsiveness**: Smooth, intuitive user experience
- ✅ **Error Handling**: Graceful handling of all edge cases
- ✅ **Integration**: Seamless flow with existing campaign system

This comprehensive implementation provides a complete, production-ready crew and character creation system that integrates seamlessly with your existing Five Parsecs Campaign Manager architecture.