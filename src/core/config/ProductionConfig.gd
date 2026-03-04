class_name ProductionConfig
extends RefCounted

## Production Configuration Manager
## Centralizes production vs development configuration settings

enum BuildEnvironment {
	DEVELOPMENT,
	STAGING,
	PRODUCTION
}

# Build configuration - set during compilation
const BUILD_ENVIRONMENT: BuildEnvironment = BuildEnvironment.PRODUCTION

# Production feature flags
const ENABLE_DEBUG_LOGGING: bool = BUILD_ENVIRONMENT != BuildEnvironment.PRODUCTION
const ENABLE_PERFORMANCE_MONITORING: bool = true
const ENABLE_ERROR_REPORTING: bool = true
const ENABLE_VALIDATION: bool = true
const STRICT_TYPE_CHECKING: bool = BUILD_ENVIRONMENT == BuildEnvironment.PRODUCTION

# Performance settings
const MAX_ERROR_LOGS_PER_MINUTE: int = 60 if BUILD_ENVIRONMENT == BuildEnvironment.PRODUCTION else 1000
const COMPONENT_CREATION_TIMEOUT_MS: int = 5000
const VALIDATION_TIMEOUT_MS: int = 10000

# Debug settings (disabled in production)
const SKIP_VALIDATION: bool = false # Never skip validation in any environment
const ALLOW_UNSAFE_OPERATIONS: bool = BUILD_ENVIRONMENT == BuildEnvironment.DEVELOPMENT

# UI settings
const SHOW_DEBUG_PANELS: bool = BUILD_ENVIRONMENT != BuildEnvironment.PRODUCTION
const ENABLE_DEVELOPER_SHORTCUTS: bool = BUILD_ENVIRONMENT == BuildEnvironment.DEVELOPMENT

## Get current environment as string
static func get_environment_name() -> String:
	match BUILD_ENVIRONMENT:
		BuildEnvironment.DEVELOPMENT:
			return "Development"
		BuildEnvironment.STAGING:
			return "Staging"
		BuildEnvironment.PRODUCTION:
			return "Production"
		_:
			return "Unknown"

## Check if running in production mode
static func is_production() -> bool:
	return BUILD_ENVIRONMENT == BuildEnvironment.PRODUCTION

## Check if running in development mode
static func is_development() -> bool:
	return BUILD_ENVIRONMENT == BuildEnvironment.DEVELOPMENT

## Get debug log level based on environment
static func get_log_level() -> int:
	match BUILD_ENVIRONMENT:
		BuildEnvironment.DEVELOPMENT:
			return 0 # All logs
		BuildEnvironment.STAGING:
			return 1 # Warning and above
		BuildEnvironment.PRODUCTION:
			return 2 # Error only
		_:
			return 1

## Production-safe logging
static func log_debug(message: String, category: String = "General") -> void:
	if ENABLE_DEBUG_LOGGING:
		pass

static func log_info(message: String, category: String = "General") -> void:
	if get_log_level() <= 1:
		pass

static func log_warning(message: String, category: String = "General") -> void:
	if get_log_level() <= 2:
		push_warning("[WARNING][%s] %s" % [category, message])

static func log_error(message: String, category: String = "General") -> void:
	push_error("[ERROR][%s] %s" % [category, message])

## Validate production readiness
static func validate_production_readiness() -> Dictionary:
	var validation_result := {
		"ready": true,
		"environment": get_environment_name(),
		"issues": [],
		"warnings": []
	}
	
	# Check for development artifacts
	if BUILD_ENVIRONMENT == BuildEnvironment.PRODUCTION:
		if ENABLE_DEBUG_LOGGING:
			validation_result.warnings.append("Debug logging enabled in production")
		
		if ALLOW_UNSAFE_OPERATIONS:
			validation_result.issues.append("Unsafe operations allowed in production")
			validation_result.ready = false
		
		if SKIP_VALIDATION:
			validation_result.issues.append("Validation skipping enabled in production")
			validation_result.ready = false
	
	return validation_result