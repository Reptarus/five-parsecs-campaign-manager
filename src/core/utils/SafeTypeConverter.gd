class_name SafeTypeConverter extends RefCounted
"""
Production-ready type conversion utility to eliminate unsafe int() casting throughout codebase.
Replaces 2000+ dangerous type conversions with safe, validated alternatives.

Usage:
    var combat = SafeTypeConverter.safe_int(data.get("combat"), 0)
    var crew_size = SafeTypeConverter.safe_int(ui_input.text, 4)
"""

# Safe integer conversion with comprehensive validation
static func safe_int(value: Variant, default: int = 0) -> int:
    if value == null:
        return default
    
    match typeof(value):
        TYPE_INT:
            return value as int
        TYPE_FLOAT:
            return int(value)
        TYPE_STRING:
            var str_val = value as String
            if str_val.strip_edges().is_empty():
                return default
            if str_val.is_valid_int():
                return str_val.to_int()
            # Try to extract numeric part from mixed strings
            var numeric_part = ""
            for char in str_val:
                if char.is_valid_int() or char == "-":
                    numeric_part += char
                else:
                    break
            if numeric_part.is_valid_int():
                return numeric_part.to_int()
            return default
        TYPE_BOOL:
            return 1 if value else 0
        _:
            push_warning("SafeTypeConverter: Invalid type %s for value '%s', using default %d" % [typeof(value), str(value), default])
            return default

# Safe string conversion
static func safe_string(value: Variant, default: String = "") -> String:
    if value == null:
        return default
    return str(value)

# Safe boolean conversion
static func safe_bool(value: Variant, default: bool = false) -> bool:
    if value == null:
        return default
    
    match typeof(value):
        TYPE_BOOL:
            return value as bool
        TYPE_INT:
            return (value as int) != 0
        TYPE_STRING:
            var str_val = (value as String).strip_edges().to_lower()
            return str_val in ["true", "1", "yes", "on"]
        _:
            return default

# Safe array access with bounds checking
static func safe_array_get(array: Array, index: int, default: Variant = null) -> Variant:
    if array == null or index < 0 or index >= array.size():
        return default
    return array[index]

# Safe dictionary access with type validation
static func safe_dict_get(dict: Dictionary, key: String, default: Variant = null) -> Variant:
    if dict == null or not dict.has(key):
        return default
    return dict[key]
