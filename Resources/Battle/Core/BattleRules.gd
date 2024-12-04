class_name BattleRules
extends Node

# Core Rules battle constants
const REACTION_BASE_TARGET := 3
const COMBAT_SKILL_BONUS := 1
const COVER_BONUS := 2
const RANGE_PENALTY := -1
const MOVEMENT_BASE := 6

# Core Rules status effects
enum BattleStatus {
    NORMAL,
    STUNNED,
    WOUNDED,
    DOWN,
    OUT
}

# Core Rules actions
enum BattleAction {
    MOVE,
    SHOOT,
    CHARGE,
    TAKE_COVER,
    USE_ITEM,
    ASSIST,
    SPECIAL
}

# Core Rules weapon ranges
enum WeaponRange {
    POINT_BLANK = 6,
    SHORT = 12,
    MEDIUM = 24,
    LONG = 36
} 