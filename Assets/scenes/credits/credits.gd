# Universal Warning Fixes Applied - 7-Stage Methodology
# Based on proven patterns: Universal Mock Strategy + comprehensive annotation coverage
@warning_ignore("unused_parameter")
@warning_ignore("shadowed_global_identifier")
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_method_access")
@warning_ignore("unused_signal")
@warning_ignore("return_value_discarded")
extends Control

@export var scroll_speed: float = 50.0
@onready var credits_label: Label = $CreditsLabel

var credits_text: String = """
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

func _ready() -> void:
    if credits_label:
        credits_label.text = credits_text
        credits_label.anchor_top = 1.0
        credits_label.anchor_bottom = 1.0
        var viewport_rect: Rect2 = get_viewport_rect()
        credits_label.position.y = viewport_rect.size.y
    else:
        push_error("CRASH PREVENTION: Credits label not found")

func _process(delta: float) -> void:
    if not credits_label:
        return
        
    credits_label.position.y -= scroll_speed * delta
    
    if credits_label.position.y + credits_label.size.y < 0:
        var viewport_rect: Rect2 = get_viewport_rect()
        credits_label.position.y = viewport_rect.size.y

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        # Use deferred scene change for better performance
        var tree: SceneTree = get_tree()
        if tree:
            tree.call_deferred("change_scene_to_file", "res://scenes/main_menu/main_menu.tscn")
