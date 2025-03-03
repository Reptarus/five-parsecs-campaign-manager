extends Control

const Character = preload("res://src/core/character/Base/Character.gd")
const CrewRelationshipManager = preload("res://src/core/campaign/crew/CrewRelationshipManager.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

@onready var crew_characteristic_label := $VBoxContainer/CrewCharacteristicLabel
@onready var meeting_story_label := $VBoxContainer/MeetingStoryLabel
@onready var relationships_container := $VBoxContainer/RelationshipsContainer
@onready var add_relationship_button := $VBoxContainer/AddRelationshipButton
@onready var character1_dropdown := $VBoxContainer/AddRelationshipPanel/Character1Dropdown
@onready var character2_dropdown := $VBoxContainer/AddRelationshipPanel/Character2Dropdown
@onready var relationship_type_dropdown := $VBoxContainer/AddRelationshipPanel/RelationshipTypeDropdown

# Use Node type as a fallback if CrewRelationshipManager doesn't have a class_name defined
var relationship_manager: Node
var crew_members: Array[Character] = []

func _ready() -> void:
	relationship_manager = CrewRelationshipManager.new()
	add_child(relationship_manager)
	
	# Connect signals
	relationship_manager.relationship_added.connect(_on_relationship_added)
	relationship_manager.relationship_removed.connect(_on_relationship_removed)
	add_relationship_button.pressed.connect(_on_add_relationship_pressed)
	
	# Hide add relationship panel initially
	$VBoxContainer/AddRelationshipPanel.hide()

func initialize(members: Array[Character]) -> void:
	crew_members = members
	relationship_manager.generate_initial_relationships(members)
	_update_display()
	_populate_dropdowns()

func _update_display() -> void:
	# Update crew characteristic and meeting story
	crew_characteristic_label.text = "Crew Characteristic: " + relationship_manager.crew_characteristic
	meeting_story_label.text = "Meeting Story: " + relationship_manager.crew_meeting_story
	
	# Clear existing relationship displays
	for child in relationships_container.get_children():
		child.queue_free()
	
	# Add relationship displays
	for char1 in crew_members:
		var relationships = relationship_manager.get_all_relationships(char1)
		for rel in relationships:
			var char2 = rel["character"]
			var relationship = rel["relationship"]
			
			var rel_display = HBoxContainer.new()
			
			# Character names
			var names_label = Label.new()
			names_label.text = "%s ←→ %s" % [char1.character_name, char2.character_name]
			rel_display.add_child(names_label)
			
			# Relationship type
			var type_label = Label.new()
			type_label.text = ": %s" % relationship
			rel_display.add_child(type_label)
			
			# Remove button
			var remove_button = Button.new()
			remove_button.text = "Remove"
			remove_button.pressed.connect(func():
				relationship_manager.remove_relationship(char1, char2)
			)
			rel_display.add_child(remove_button)
			
			relationships_container.add_child(rel_display)

func _populate_dropdowns() -> void:
	# Clear existing items
	character1_dropdown.clear()
	character2_dropdown.clear()
	relationship_type_dropdown.clear()
	
	# Add characters to dropdowns
	for character in crew_members:
		character1_dropdown.add_item(character.character_name)
		character2_dropdown.add_item(character.character_name)
	
	# Add relationship types
	for rel_type in relationship_manager.RELATIONSHIP_TYPES.values():
		relationship_type_dropdown.add_item(rel_type)

func _on_add_relationship_pressed() -> void:
	$VBoxContainer/AddRelationshipPanel.visible = !$VBoxContainer/AddRelationshipPanel.visible

func _on_relationship_added(_char1: Character, _char2: Character, _relationship_type: String) -> void:
	_update_display()

func _on_relationship_removed(_char1: Character, _char2: Character) -> void:
	_update_display()

func _on_confirm_relationship_pressed() -> void:
	var char1 = crew_members[character1_dropdown.selected]
	var char2 = crew_members[character2_dropdown.selected]
	var rel_type = relationship_manager.RELATIONSHIP_TYPES.values()[relationship_type_dropdown.selected]
	
	if char1 != char2:
		relationship_manager.add_relationship(char1, char2, rel_type)
		$VBoxContainer/AddRelationshipPanel.hide()

func serialize() -> Dictionary:
	return relationship_manager.serialize()

func deserialize(data: Dictionary) -> void:
	relationship_manager.deserialize(data)
	_update_display()