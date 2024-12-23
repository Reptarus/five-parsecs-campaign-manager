class_name BaseContainer
extends Container

enum Orientation {
    HORIZONTAL,
    VERTICAL
}

@export var orientation: Orientation = Orientation.HORIZONTAL
@export var spacing: float = 10.0

func _ready() -> void:
    sort_children.connect(_on_sort_children)

func _on_sort_children() -> void:
    var offset := Vector2.ZERO
    var available_size := size
    
    for child in get_children():
        if not child is Control or not child.visible:
            continue
            
        var child_min_size := child.get_combined_minimum_size()
        var child_size := Vector2.ZERO
        
        match orientation:
            Orientation.HORIZONTAL:
                child_size.x = child_min_size.x
                child_size.y = available_size.y
                if offset.x + child_size.x > available_size.x:
                    offset.x = 0
                    offset.y += child_min_size.y + spacing
            Orientation.VERTICAL:
                child_size.x = available_size.x
                child_size.y = child_min_size.y
                if offset.y + child_size.y > available_size.y:
                    offset.y = 0
                    offset.x += child_min_size.x + spacing
        
        fit_child_in_rect(child, Rect2(offset, child_size))
        
        match orientation:
            Orientation.HORIZONTAL:
                offset.x += child_size.x + spacing
            Orientation.VERTICAL:
                offset.y += child_size.y + spacing 