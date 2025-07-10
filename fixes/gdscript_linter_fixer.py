#!/usr/bin/env python3
"""
GDScript Linter Error Fixing Automation Tool
Systematic approach to resolve 200+ linter errors following senior development practices
"""

import re
import os
import json
from pathlib import Path
from typing import Dict, List, Tuple, Set
from dataclasses import dataclass
from enum import Enum

class ErrorSeverity(Enum):
    CRITICAL = 8  # Compilation blockers
    WARNING = 4   # Type safety issues

@dataclass
class LinterError:
    """Structured representation of GDScript linter errors"""
    file_path: str
    line: int
    column: int
    code: str
    severity: int
    message: str
    
    @property
    def is_critical(self) -> bool:
        return self.severity == ErrorSeverity.CRITICAL.value

class GDScriptLinterFixer:
    """
    Production-grade automated GDScript linter error resolution
    
    Implements patterns for:
    - Type safety enforcement
    - Import dependency resolution  
    - Code quality improvements
    - Architecture compliance
    """
    
    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.src_path = self.project_root / "src"
        self.backup_path = self.project_root / "backups"
        
        # Create backup directory
        self.backup_path.mkdir(exist_ok=True)
        
        # Error patterns for automated fixing
        self.error_patterns = {
            'missing_type_prefix': re.compile(r'FPCM_(\w+)'),
            'untyped_var': re.compile(r'var\s+(\w+)\s*=\s*(.+?)(?:\s*#.*)?$'),
            'unsafe_method_call': re.compile(r'(\w+)\.has_method\s*\(\s*["\'](\w+)["\']\s*\)'),
            'shadowed_const': re.compile(r'const\s+(Character|Mission|Campaign)\s*='),
            'discarded_return': re.compile(r'^\s*(\w+\.\w+\([^)]*\))(?!\s*#.*ignore)'),
            'unused_parameter': re.compile(r'func\s+\w+\([^)]*(\w+)[^)]*\):.*?(?=func|\Z)', re.DOTALL)
        }
        
        # Type inference mappings
        self.type_mappings = {
            'create_tween()': 'Tween',
            'load(': 'Resource',
            'preload(': 'Resource', 
            'get_node(': 'Node',
            'get_children()': 'Array[Node]',
            'Time.get_datetime_string_from_system()': 'String',
            'randi()': 'int',
            'randf()': 'float',
            'Vector2()': 'Vector2',
            'Dictionary()': 'Dictionary',
            'Array()': 'Array'
        }

    def parse_linter_errors(self, errors_json_path: str) -> List[LinterError]:
        """Parse linter errors from JSON output"""
        with open(errors_json_path, 'r') as f:
            errors_data = json.load(f)
        
        parsed_errors = []
        for error in errors_data:
            parsed_errors.append(LinterError(
                file_path=error['resource'],
                line=error['startLineNumber'], 
                column=error['startColumn'],
                code=error['code'],
                severity=error['severity'],
                message=error['message']
            ))
        
        return parsed_errors

    def fix_missing_type_definitions(self, content: str) -> str:
        """
        Fix FPCM_ prefixed types that don't exist
        Strategy: Remove prefix and use actual class names
        """
        # Map FPCM_ prefixes to actual classes
        type_replacements = {
            'FPCM_UnifiedTerrainSystem': 'UnifiedTerrainSystem',
            'FPCM_PreBattleUI': 'Node',  # Generic fallback until proper typing
            'FPCM_CampaignManager': 'CampaignManager',
            'FPCM_Character': 'Character'
        }
        
        for old_type, new_type in type_replacements.items():
            content = content.replace(old_type, new_type)
        
        return content

    def fix_shadowed_identifiers(self, content: str) -> str:
        """
        Resolve global identifier shadowing
        Strategy: Rename constants with descriptive suffixes
        """
        shadowing_fixes = {
            r'const Character =': 'const CharacterDataManager =',
            r'const Mission =': 'const MissionSystem =', 
            r'const Campaign =': 'const CampaignManager =',
            r'const GameSettings =': 'const SettingsManager =',
            r'const UniversalNodeValidator =': 'const NodeValidator ='
        }
        
        for pattern, replacement in shadowing_fixes.items():
            content = re.sub(pattern, replacement, content)
        
        return content

    def add_type_annotations(self, content: str) -> str:
        """
        Add explicit type annotations to variable declarations
        Uses inference mappings and pattern matching
        """
        lines = content.split('\n')
        fixed_lines = []
        
        for line in lines:
            # Skip if already typed or is a comment
            if ':' in line and 'var' in line or line.strip().startswith('#'):
                fixed_lines.append(line)
                continue
                
            # Match untyped variable declarations
            match = self.error_patterns['untyped_var'].match(line.strip())
            if match:
                var_name, assignment = match.groups()
                inferred_type = self._infer_type(assignment.strip())
                
                if inferred_type:
                    # Reconstruct line with type annotation
                    indent = len(line) - len(line.lstrip())
                    fixed_line = f"{' ' * indent}var {var_name}: {inferred_type} = {assignment}"
                    fixed_lines.append(fixed_line)
                else:
                    fixed_lines.append(line)
            else:
                fixed_lines.append(line)
        
        return '\n'.join(fixed_lines)

    def _infer_type(self, assignment: str) -> str:
        """Infer GDScript types from assignment expressions"""
        assignment = assignment.strip()
        
        # Direct mappings from assignment patterns
        for pattern, gdscript_type in self.type_mappings.items():
            if pattern.rstrip('(') in assignment:
                return gdscript_type
        
        # Literal type inference
        if assignment.startswith('"') or assignment.startswith("'"):
            return 'String'
        elif assignment.replace('.', '').replace('-', '').isdigit():
            return 'float' if '.' in assignment else 'int'
        elif assignment.lower() in ['true', 'false']:
            return 'bool'
        elif assignment.startswith('['):
            return 'Array'  # Could be more specific with element type analysis
        elif assignment.startswith('{'):
            return 'Dictionary'
        elif assignment == 'null':
            return ''  # Skip typing null assignments
        
        return ''  # No type inference possible

    def fix_unsafe_method_access(self, content: str) -> str:
        """
        Convert unsafe dynamic method calls to type-safe patterns
        """
        # Pattern: obj.has_method("method_name") followed by obj.method_name()
        def replace_unsafe_call(match):
            obj_name = match.group(1)
            method_name = match.group(2)
            
            return f"""# Type-safe method call pattern
if {obj_name} is Node and {obj_name}.has_method("{method_name}"):
    {obj_name}.{method_name}()"""
        
        content = re.sub(
            self.error_patterns['unsafe_method_call'],
            replace_unsafe_call,
            content
        )
        
        return content

    def fix_discarded_return_values(self, content: str) -> str:
        """
        Handle discarded return values with explicit intent
        """
        lines = content.split('\n')
        fixed_lines = []
        
        for line in lines:
            if self.error_patterns['discarded_return'].match(line):
                # Add explicit discard for known safe methods
                safe_to_discard = [
                    'connect(', 'add_child(', 'remove_child(',
                    'queue_free()', 'emit_signal('
                ]
                
                if any(method in line for method in safe_to_discard):
                    # Add warning ignore comment
                    fixed_line = line.rstrip() + ' # @warning_ignore:return_value_discarded'
                    fixed_lines.append(fixed_line)
                else:
                    # Store in throwaway variable
                    indent = len(line) - len(line.lstrip())
                    method_call = line.strip()
                    fixed_line = f"{' ' * indent}var _result := {method_call}"
                    fixed_lines.append(fixed_line)
            else:
                fixed_lines.append(line)
        
        return '\n'.join(fixed_lines)

    def remove_unused_code(self, content: str) -> str:
        """
        Remove unused variables, parameters, and imports
        Conservative approach - only remove obvious cases
        """
        lines = content.split('\n')
        fixed_lines = []
        
        for line in lines:
            # Skip unused variable declarations (conservative)
            if re.match(r'^\s*var\s+_\w+.*=', line):
                continue
            
            # Convert unused parameters to underscore prefix
            if 'func ' in line and '(' in line:
                # This would need more sophisticated AST parsing for production
                fixed_lines.append(line)
            else:
                fixed_lines.append(line)
        
        return '\n'.join(fixed_lines)

    def apply_fixes_to_file(self, file_path: str, errors: List[LinterError]) -> bool:
        """
        Apply appropriate fixes to a single file based on its errors
        """
        if not os.path.exists(file_path):
            return False
            
        # Create backup
        backup_file = self.backup_path / f"{Path(file_path).name}.backup"
        with open(file_path, 'r') as f:
            original_content = f.read()
        
        with open(backup_file, 'w') as f:
            f.write(original_content)
        
        # Apply fixes in order of severity and dependency
        content = original_content
        
        # Phase 1: Critical fixes (compilation blockers)
        critical_errors = [e for e in errors if e.is_critical]
        if critical_errors:
            content = self.fix_missing_type_definitions(content)
            content = self.fix_shadowed_identifiers(content)
        
        # Phase 2: Type safety improvements
        content = self.add_type_annotations(content)
        content = self.fix_unsafe_method_access(content)
        
        # Phase 3: Code quality
        content = self.fix_discarded_return_values(content)
        content = self.remove_unused_code(content)
        
        # Write fixed content
        with open(file_path, 'w') as f:
            f.write(content)
        
        return True

    def generate_type_registry(self) -> str:
        """
        Generate a central type registry for project-wide consistency
        """
        type_registry_content = '''# Five Parsecs Campaign Manager - Type Registry
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
'''
        return type_registry_content

def main():
    """Production automation script for fixing GDScript linter errors"""
    
    # Configuration
    PROJECT_ROOT = "C:/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager"
    ERRORS_JSON = "linter_errors.json"  # Would be generated by CI/CD
    
    fixer = GDScriptLinterFixer(PROJECT_ROOT)
    
    # Generate type registry first
    type_registry_path = Path(PROJECT_ROOT) / "src/core/types/TypeRegistry.gd"
    type_registry_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(type_registry_path, 'w') as f:
        f.write(fixer.generate_type_registry())
    
    print("✅ Generated central type registry")
    
    # Parse and categorize errors
    if os.path.exists(ERRORS_JSON):
        errors = fixer.parse_linter_errors(ERRORS_JSON)
        
        # Group errors by file
        errors_by_file = {}
        for error in errors:
            file_path = error.file_path.replace('/', os.sep)
            if file_path not in errors_by_file:
                errors_by_file[file_path] = []
            errors_by_file[file_path].append(error)
        
        # Apply fixes file by file
        for file_path, file_errors in errors_by_file.items():
            print(f"📝 Fixing {len(file_errors)} errors in {Path(file_path).name}")
            success = fixer.apply_fixes_to_file(file_path, file_errors)
            if success:
                print(f"✅ Fixed {file_path}")
            else:
                print(f"❌ Failed to fix {file_path}")
    
    print("🎯 Automated fixes complete. Run linter validation to verify.")

if __name__ == "__main__":
    main()
