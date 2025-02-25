@tool
extends "res://src/core/mission/base/mission.gd"

## @deprecated
## Compatibility layer for the old Mission class.
## This file exists to maintain backward compatibility while transitioning
## to the new mission system. It will be removed in a future update.
##
## Use FiveParsecsMission instead.
## @see res://src/core/mission/base/mission.gd

func _init() -> void:
    super._init()
    push_warning("Mission class is deprecated. Use FiveParsecsMission instead. This class will be removed in version 1.0.0")
    push_warning("Migration guide: https://github.com/your-repo/five-parsecs-campaign-manager/wiki/Mission-System-Migration")