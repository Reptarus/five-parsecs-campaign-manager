# Five Parsecs Campaign Manager - Type Registry
# Central type definitions for consistent typing across the project

class_name FPCM_TypeRegistry

# === Core System Types ===
typedef CampaignStateData = Dictionary
typedef CharacterData = Dictionary  
typedef MissionData = Dictionary
typedef TerrainData = Dictionary
typedef BattleData = Dictionary

# === Manager Type Aliases ===
typedef CharacterManager = CharacterDataManager
typedef SettingsManager = GameSettings  
typedef StateManager = CoreGameState

# === UI Component Interfaces ===
class_name PreviewableComponent extends Control
func setup_preview() -> void:
    pass
    
func can_preview() -> bool:
    return true

# === Error Handling Types ===
enum ErrorCategory { SYSTEM, VALIDATION, NETWORK, USER_INPUT }
enum ErrorSeverity { INFO, WARNING, ERROR, CRITICAL }

class_name GameError extends RefCounted:
    var id: String
    var timestamp: float  
    var category: ErrorCategory
    var severity: ErrorSeverity
    var message: String
    var context: Dictionary = {}
    var resolved: bool = false

# === Validation Interfaces ===  
class_name ValidatableComponent:
    func validate() -> ValidationResult:
        return ValidationResult.success()
    
    func is_valid() -> bool:
        return validate().is_valid

class_name ValidationResult:
    var is_valid: bool
    var errors: Array[String] = []
    
    static func success() -> ValidationResult:
        var result := ValidationResult.new()
        result.is_valid = true
        return result
        
    static func failure(error_messages: Array[String]) -> ValidationResult:
        var result := ValidationResult.new()
        result.is_valid = false
        result.errors = error_messages
        return result
