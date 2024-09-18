# StoryClock.gd
class_name StoryClock
extends Resource

var ticks: int = 0

func set_ticks(value: int):
    ticks = value

func count_down(won_mission: bool):
    ticks -= 2 if won_mission else 1

func is_event_triggered() -> bool:
    return ticks <= 0