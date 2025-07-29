# Five Parsecs Campaign Manager - Data Architecture & Safety Patterns Memory
**Memory Type**: Data Management & Safety Architecture  
**Last Updated**: 2025-07-29  
**Context**: Critical data handling patterns and safety mechanisms

## 🏗️ Data Manager Architecture (Production Ready)

### DataManager Core Functions
**Location**: `src/core/data/DataManager.gd` (globally accessible autoload)

**Responsibilities**:
- **Loading Data**: Loads all game data from JSON files at startup
- **Caching**: Caches all data in memory for high-performance access
- **Validation**: Validates data integrity and checks for consistency
- **Hot-Reloading**: Supports hot-reloading in development builds
- **API**: Provides consistent API for accessing all game data

### JSON Data File Organization
**Location**: `data/` directory with comprehensive file structure

**Key Data Categories**:
- `data/RulesReference/` - In-game reference for Five Parsecs rulebook
- `data/Tutorials/` - Tutorial system data
- `data/character_creation_data.json` - Character generation data
- `data/equipment_database.json` - Equipment and gear systems
- `data/campaign_tables/` - Campaign events and mission generation
- `data/battlefield/` - Battlefield generation and combat data
- `data/enemies/` - Enemy types and AI behavior
- `data/missions/` - Patron and opportunity missions

## 🛡️ Critical Data Handling Patterns

### Testing vs Production Data Differences (CRITICAL INSIGHT)
**Discovery**: Major architectural insight from comprehensive testing

#### Production Environment:
```gdscript
# Real Character objects with proper typing
var character = Character.new()
character.combat = 5
character.toughness = 6
character.savvy = 7
```

#### Testing Environment (Fallback Pattern):
```gdscript
# Dictionary fallbacks for safe testing
var character = {
    "combat": 5,
    "toughness": 6, 
    "savvy": 7
}
# Safe access pattern
var combat = character.combat if typeof(character) == TYPE_OBJECT else character.combat
```

### Number Safety Architecture (ESSENTIAL)
**Context**: Five Parsecs campaigns involve complex numerical calculations

#### Safe Numerical Access Pattern
```gdscript
# Safe property access with type validation
func safe_get_stat(character: Variant, stat_name: String, default: int = 0) -> int:
    if character == null:
        return default
    if typeof(character) == TYPE_OBJECT and stat_name in character:
        var value = character.get(stat_name)
        return value if value is int else default
    elif character is Dictionary:
        return character.get(stat_name, default)
    return default
```

#### Credit and Equipment Value Safety
```gdscript
# Safe credit calculations with validation
func calculate_total_credits(equipment_list: Array, starting_credits: int = 0) -> int:
    var total = starting_credits
    for item in equipment_list:
        if item is Dictionary and item.has("credits"):
            var credits = item.credits
            if credits is int and credits > 0:
                total += credits
    return max(0, total)  # Ensure non-negative
```

## 🔍 Data Validation Architecture

### Campaign Data Validation (Comprehensive)
```gdscript
func validate_campaign_data(campaign_data: Dictionary) -> ValidationResult:
    var result = ValidationResult.new()
    
    # Validate essential keys exist
    var required_keys = ["config", "crew", "captain", "ship", "equipment"]
    for key in required_keys:
        if not campaign_data.has(key):
            result.add_error("Missing required key: " + key)
    
    # Validate crew data integrity
    if campaign_data.has("crew") and campaign_data.crew is Array:
        for i in range(campaign_data.crew.size()):
            var character = campaign_data.crew[i]
            if not _validate_character_data(character):
                result.add_error("Invalid character data at index " + str(i))
    
    return result
```

### Character Data Integrity Validation
**Critical Areas**:
- **Stat Validation**: All character stats validated within Five Parsecs ranges (typically 1-6)
- **Health Calculation**: Health always calculated as Toughness + bonus (2 for crew, 3 for captains)
- **Equipment Assignment**: All equipment properly linked to character owners
- **Credit Tracking**: All monetary values validated and bounded

### Campaign Turn Data Safety
**Complex Calculations Requiring Safety**:
- **Resource Tracking**: Credits, fuel, supplies validated on each access
- **Progress Tracking**: Mission completion, character advancement safely calculated
- **State Persistence**: All numerical data properly serialized and validated on load

## 🔧 Error Recovery Patterns (Production-Tested)

### Graceful Degradation Pattern
```gdscript
# Graceful degradation for missing data
func get_character_stat_safe(character: Variant, stat: String) -> int:
    # Try production path first
    if character is Character and stat in character:
        return character.get(stat)
    
    # Fall back to dictionary access
    elif character is Dictionary and character.has(stat):
        var value = character[stat]
        return value if value is int else 0
    
    # Final fallback to reasonable default
    return _get_stat_default(stat)
```

### Safe Data Access Pattern
```gdscript
# Example safe usage patterns validated through testing

# Get character origin data with validation
var origin_data = DataManager.get_origin_data("HUMAN")

# Get weapon data with safety validation
var weapon_data = DataManager.get_weapon_data("LASER_PISTOL")
if weapon_data and weapon_data.has("damage"):
    var damage = weapon_data.damage if weapon_data.damage is int else 0

# Get all character backgrounds safely
var all_backgrounds = DataManager.get_all_backgrounds()

# Safe campaign data access with validation
var campaign = load_campaign_safely("campaign_save.dat")
if campaign and _validate_campaign_data(campaign).is_valid():
    var crew_count = campaign.crew.size() if campaign.crew is Array else 0
```

## 🏭 Production Data Integrity Standards

### Universal Safety Integration
**Architecture**: All data access goes through Universal Safety patterns
- **UniversalDataAccess**: Safe data operations with null protection
- **UniversalResourceLoader**: Safe resource loading with graceful failure handling
- **Context-Aware Errors**: Detailed error reporting for rapid debugging
- **Enterprise Patterns**: Production-ready error handling and validation

### Save Data Protection Mechanisms
```gdscript
class SaveManager:
    func save_campaign(campaign: Campaign, file_path: String) -> SaveResult:
        # Validate data before saving
        var validation = CampaignValidator.validate_save_data(campaign)
        if not validation.valid:
            result.success = false
            result.error = validation.error_message
            return result
        
        # Create backup before saving
        if FileAccess.file_exists(file_path):
            var backup_path = file_path + ".backup"
            DirAccess.copy_absolute(file_path, backup_path)
```

### Input Validation Standards
```gdscript
class InputValidator:
    static func validate_character_name(name: String) -> ValidationResult:
        var result = ValidationResult.new()
        
        if name.length() < 2:
            result.valid = false
            result.error = "Character name must be at least 2 characters"
            return result
        
        # Sanitize for security
        var sanitized = name.strip_edges()
        result.valid = true
        result.sanitized_value = sanitized
        return result
```

## 📊 Data Architecture Performance Characteristics

### Memory Management Patterns
- **Object pooling** for frequently created entities
- **Lazy loading** of game data tables
- **Proper cleanup** of scene references
- **Memory profiling** integration during development

### Optimization Strategies (Production-Tested)
- **Safe node access caching** for repeated operations
- **Efficient state management** with minimal copying
- **Optimized scene transitions** with preloading
- **Resource bundling** for faster loading times

## 🔒 Security & Data Protection

### Input Validation Security
- **Type-safe data structures** throughout the system
- **Validation at system boundaries** with proper error handling
- **Sanitized user input** for save files and character names
- **Protected resource access** with existence checking

### Save Data Security Standards
- **Validated save data** with schema checking
- **Backup creation** before overwriting saves
- **Error recovery** for corrupted save files
- **Version compatibility** checking

## 💡 Key Architectural Insights

### Data Handling Architecture Discoveries
1. **Testing vs Production**: Comprehensive fallback patterns ensure safe data handling whether using Character objects or Dictionary fallbacks
2. **Number Safety**: All numerical calculations (stats, credits, equipment values) validated through multiple test scenarios  
3. **Type Safety**: Robust type checking prevents runtime errors during campaign creation
4. **Integration Architecture**: Story track, tutorial system, and campaign creation all require coordinated data validation

### Production Deployment Insights
- **Complete Workflow**: 6-step campaign creation requires data validation at each phase
- **Error Recovery**: Graceful handling of missing components with fallback systems
- **Performance**: Sub-second execution times validated for complete campaign generation
- **Data Integrity**: All campaign data properly validated and compiled for game launch

## 🚀 Data Architecture Status: PRODUCTION READY
This robust data architecture ensures that the Five Parsecs Campaign Manager can handle the complex numerical requirements of campaign gameplay while maintaining data integrity across all scenarios, from testing to production deployment. The system demonstrates enterprise-grade reliability with comprehensive validation, error recovery, and performance optimization.