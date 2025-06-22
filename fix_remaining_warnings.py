#!/usr/bin/env python3
"""
Enhanced Warning Fix Script - Addresses remaining linter warnings in GDScript files
"""

import os
import re
import glob
from pathlib import Path

def fix_parameter_naming_issues(content):
    """Fix parameter naming issues where function parameter uses '_param' but body uses 'param'"""
    patterns = [
        # func something(_event: Type) -> void: ... if event ...
        (r'func\s+\w+\([^)]*_event\s*:[^)]+\)\s*->\s*\w+:(.*?)(?=func|\Z)', 
         lambda m: m.group(0).replace('_event:', 'event:').replace('(_event)', '(event)')),
        
        # func something(_value: Type) -> void: ... value ...
        (r'func\s+\w+\([^)]*_value\s*:[^)]+\)\s*->\s*\w+:(.*?)(?=func|\Z)', 
         lambda m: m.group(0).replace('_value:', 'value:').replace('(_value)', '(value)')),
        
        # func something(_delta: float) -> void: ... delta ...
        (r'func\s+\w+\([^)]*_delta\s*:[^)]+\)\s*->\s*\w+:(.*?)(?=func|\Z)', 
         lambda m: m.group(0).replace('_delta:', 'delta:').replace('(_delta)', '(delta)')),
        
        # func something(_pressed: bool) -> void: ... pressed ...
        (r'func\s+\w+\([^)]*_pressed\s*:[^)]+\)\s*->\s*\w+:(.*?)(?=func|\Z)', 
         lambda m: m.group(0).replace('_pressed:', 'pressed:').replace('(_pressed)', '(pressed)')),
    ]
    
    for pattern, replacement in patterns:
        content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    
    return content

def fix_void_return_functions(content):
    """Fix functions declared as void that try to return values"""
    # Find functions that are declared as void but have return statements
    void_func_pattern = r'func\s+(\w+)\([^)]*\)\s*->\s*void:(.*?)(?=func|\Z)'
    
    def replace_void_returns(match):
        func_body = match.group(2)
        func_name = match.group(1)
        
        # Check if this function has return statements with values
        if re.search(r'return\s+[^;\n]+', func_body):
            # Determine the actual return type based on what's being returned
            if re.search(r'return\s+(null|None)', func_body):
                return match.group(0).replace('-> void:', '-> Variant:')
            elif re.search(r'return\s+(true|false)', func_body):
                return match.group(0).replace('-> void:', '-> bool:')
            elif re.search(r'return\s+\d+', func_body):
                return match.group(0).replace('-> void:', '-> int:')
            elif re.search(r'return\s+["\']', func_body):
                return match.group(0).replace('-> void:', '-> String:')
            elif re.search(r'return\s+\[', func_body):
                return match.group(0).replace('-> void:', '-> Array:')
            elif re.search(r'return\s+{', func_body):
                return match.group(0).replace('-> void:', '-> Dictionary:')
            else:
                return match.group(0).replace('-> void:', '-> Variant:')
        
        return match.group(0)
    
    return re.sub(void_func_pattern, replace_void_returns, content, flags=re.DOTALL)

def fix_function_signatures(content):
    """Fix malformed function signatures"""
    patterns = [
        # Fix missing closing parentheses in function signatures
        (r'func\s+_input\(event\s*->\s*void:', r'func _input(event) -> void:'),
        (r'func\s+([^(]+)\(([^)]+)\s*->\s*void:', r'func \1(\2) -> void:'),
        
        # Fix missing quotes in @onready var declarations
        (r'@onready\s+var\s+(\w+):\s*\w+\s*=\s*\$"([^"]+)$', r'@onready var \1: Node = $"\2"'),
        
        # Fix WorldEconomyManager _init function
        (r'func\s+_init\(([^)]+)\s*->\s*void:', r'func _init(\1) -> void:'),
    ]
    
    for pattern, replacement in patterns:
        content = re.sub(pattern, replacement, content)
    
    return content

def fix_dictionary_and_array_syntax(content):
    """Fix malformed dictionary and array syntax"""
    lines = content.split('\n')
    fixed_lines = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Skip lines that are already properly formatted
        if ':{' in line or '},' in line or '"key":' in line:
            fixed_lines.append(line)
            i += 1
            continue
            
        # Fix dictionary syntax issues
        if re.search(r'^\s*"[^"]+"\s*:\s*[^,}]+$', line):
            # This is a dictionary entry without closing comma or brace
            if i + 1 < len(lines) and ('"' in lines[i + 1] or '}' in lines[i + 1]):
                if not line.endswith(',') and not lines[i + 1].strip().startswith('}'):
                    line += ','
        
        # Fix array syntax issues
        if re.search(r'^\s*"[^"]+",?\s*$', line) and 'Expected expression as array element' in str(line):
            # This might be part of a malformed array
            pass
        
        fixed_lines.append(line)
        i += 1
    
    return '\n'.join(fixed_lines)

def fix_annotation_issues(content):
    """Fix misplaced @warning_ignore annotations"""
    # Remove orphaned @warning_ignore annotations
    content = re.sub(r'@warning_ignore\([^)]+\)\s*$', '', content, flags=re.MULTILINE)
    
    # Fix annotations that are on separate lines
    content = re.sub(r'@warning_ignore\([^)]+\)\s*\n\s*\n', '\n', content)
    
    return content

def fix_variable_scope_issues(content):
    """Fix common variable scope issues"""
    patterns = [
        # Fix story system event parameter issue
        (r'func\s+make_story_choice\(_event:\s*StoryEvent', r'func make_story_choice(event: StoryEvent'),
        
        # Fix battle events system event parameter issue  
        (r'func\s+_apply_\w+_event\(_event:\s*BattleEvent', r'func _apply_\1_event(event: BattleEvent'),
        
        # Fix other common parameter naming issues
        (r'\bif\s+not\s+event\s+or', r'if not event or'),
    ]
    
    for pattern, replacement in patterns:
        content = re.sub(pattern, replacement, content)
    
    return content

def fix_specific_file_issues(filepath, content):
    """Fix issues specific to certain files"""
    filename = os.path.basename(filepath)
    
    if 'world_system' in filename:
        # Fix Vector2 constructor issue
        content = re.sub(
            r'world_size\s*=\s*Vector2\(\s*@warning_ignore.*?\n.*?data\["world_size"\]\.get\("x",\s*0\),\s*@warning_ignore.*?\n.*?data\["world_size"\]\.get\("y",\s*0\)\s*\)',
            'world_size = Vector2(data["world_size"].get("x", 0), data["world_size"].get("y", 0))',
            content,
            flags=re.DOTALL
        )
    
    if 'credits.gd' in filename or 'end_credits.gd' in filename:
        # Fix _process function parameter
        content = re.sub(r'func\s+_process\(_delta:', r'func _process(delta:', content)
    
    if 'EnemyManager.gd' in filename:
        # Fix dictionary initialization issues
        content = re.sub(
            r'var\s+enemy_data:\s*Dictionary\s*=\s*{\s*@warning_ignore.*?\n.*?"groups".*?"positions".*?"special_rules".*?}',
            'var enemy_data: Dictionary = {\n\t\t"groups": _generate_enemy_groups(),\n\t\t"positions": _generate_positions(deployment_zone),\n\t\t"special_rules": enemy_force.get("special_rules", [])\n\t}',
            content,
            flags=re.DOTALL
        )
    
    return content

def process_file(filepath):
    """Process a single file to fix warnings"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Apply all fixes
        content = fix_parameter_naming_issues(content)
        content = fix_void_return_functions(content)
        content = fix_function_signatures(content)
        content = fix_dictionary_and_array_syntax(content)
        content = fix_annotation_issues(content)
        content = fix_variable_scope_issues(content)
        content = fix_specific_file_issues(filepath, content)
        
        # Only write if content changed
        if content != original_content:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        
        return False
        
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    """Main function to process all GDScript files"""
    # Find all .gd files
    gd_files = []
    for pattern in ['**/*.gd']:
        gd_files.extend(glob.glob(pattern, recursive=True))
    
    print(f"🔍 Found {len(gd_files)} GDScript files")
    
    fixed_count = 0
    for filepath in gd_files:
        if process_file(filepath):
            fixed_count += 1
            print(f"✅ Fixed: {filepath}")
    
    print(f"\n📊 Enhanced Warning Fix Summary:")
    print(f"✅ Files processed: {len(gd_files)}")
    print(f"🔧 Files modified: {fixed_count}")
    print(f"📈 Success rate: {(fixed_count/len(gd_files)*100):.1f}%")

if __name__ == "__main__":
    main() 