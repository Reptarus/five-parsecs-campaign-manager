extends Control

@export var scroll_speed: float = 50.0
@onready var credits_label: Label = $CreditsLabel

var credits_text = """
Five Parsecs from Home
A Solo Adventure Game

Developed by:
[Your Name/Team Name]

Based on the tabletop game by:
Ivan Sorensen

Programming:
[Programmer Names]

Art:
[Artist Names]

Music:
[Composer Names]

Sound Effects:
[Sound Designer Names]

Special Thanks:
[List of people or organizations to thank]

Thank you for playing!
"""

func _ready():
    credits_label.text = credits_text
    credits_label.anchor_top = 1.0
    credits_label.anchor_bottom = 1.0
    credits_label.position.y = get_viewport_rect().size.y

func _process(delta):
    credits_label.position.y -= scroll_speed * delta
    
    if credits_label.position.y + credits_label.size.y < 0:
        credits_label.position.y = get_viewport_rect().size.y

func _input(event):
    if event.is_action_pressed("ui_cancel"):
        get_tree().change_scene_to_file("res://ui/mainmenu/MainMenu.tscn")
