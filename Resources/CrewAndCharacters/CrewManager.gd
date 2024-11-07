class_name CrewManager
extends Resource

var crew: Array[Character] = []

func get_crew() -> Array[Character]:
    return crew

func get_character(index: int) -> Character:
    if index >= 0 and index < crew.size():
        return crew[index]
    return null

func validate_crew() -> bool:
    return crew.size() >= 3  # Minimum crew size
