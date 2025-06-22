#!/usr/bin/env python3
"""
Apply Stage 2 parameter name resolution to test files
Following the proven 7-stage methodology from WARNING_FIX_SUMMARY.md
"""

import os
import re
import sys

def apply_stage2_parameters(file_path):
    """Apply parameter name resolution fixes to test files"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Common parameter name resolution patterns for test files
        patterns = [
            # Fix _event parameter shadowing
            (r'func\s+(\w+)\s*\(\s*_event([^)]*)\)\s*->\s*void:', r'func \1(event\2) -> void:'),
            (r'func\s+(\w+)\s*\(\s*_event([^)]*)\):', r'func \1(event\2):'),
            
            # Fix _data parameter shadowing
            (r'func\s+(\w+)\s*\(\s*_data([^)]*)\)\s*->\s*([^:]+):', r'func \1(test_data\2) -> \3:'),
            (r'func\s+(\w+)\s*\(\s*_data([^)]*)\):', r'func \1(test_data\2):'),
            
            # Fix _value parameter shadowing  
            (r'func\s+(\w+)\s*\(\s*_value([^)]*)\)\s*->\s*([^:]+):', r'func \1(test_value\2) -> \3:'),
            (r'func\s+(\w+)\s*\(\s*_value([^)]*)\):', r'func \1(test_value\2):'),
            
            # Fix _name parameter shadowing in test functions
            (r'func\s+(create_test_\w+|test_\w+)\s*\(\s*name([^)]*)\)\s*->\s*([^:]+):', r'func \1(test_name\2) -> \3:'),
            (r'func\s+(create_test_\w+|test_\w+)\s*\(\s*name([^)]*)\):', r'func \1(test_name\2):'),
            
            # Fix _type parameter shadowing
            (r'func\s+(\w+)\s*\(\s*_type([^)]*)\)\s*->\s*([^:]+):', r'func \1(test_type\2) -> \3:'),
            (r'func\s+(\w+)\s*\(\s*_type([^)]*)\):', r'func \1(test_type\2):'),
            
            # Fix _size parameter shadowing
            (r'func\s+(\w+)\s*\(\s*_size([^)]*)\)\s*->\s*([^:]+):', r'func \1(test_size\2) -> \3:'),
            (r'func\s+(\w+)\s*\(\s*_size([^)]*)\):', r'func \1(test_size\2):'),
            
            # Fix parameter references in function bodies (event)
            (r'if\s+_event\.', r'if event.'),
            (r'_event\.is_action_pressed', r'event.is_action_pressed'),
            (r'_event\.type', r'event.type'),
            (r'return\s+_event', r'return event'),
            
            # Fix parameter references in function bodies (data)
            (r'if\s+_data\.', r'if test_data.'),
            (r'_data\.get\(', r'test_data.get('),
            (r'return\s+_data', r'return test_data'),
            
            # Fix parameter references in function bodies (value)
            (r'if\s+_value\s*==', r'if test_value =='),
            (r'_value\.strip_edges', r'test_value.strip_edges'),
            (r'return\s+_value', r'return test_value'),
            
            # Fix parameter references in function bodies (name)
            (r'campaign_name\s*=\s*name\b', r'campaign_name = test_name'),
            (r'character_name\s*=\s*name\b', r'character_name = test_name'),
            (r'\.name\s*=\s*name\b', r'.name = test_name'),
            
            # Fix parameter references in function bodies (type)
            (r'mission_type\s*=\s*_type\b', r'mission_type = test_type'),
            (r'\.type\s*=\s*_type\b', r'.type = test_type'),
            
            # Fix parameter references in function bodies (size)
            (r'for\s+i\s+in\s+range\(_size\)', r'for i in range(test_size)'),
            (r'crew\.has_size\(_size\)', r'crew.has_size(test_size)'),
        ]
        
        # Apply all patterns
        for pattern, replacement in patterns:
            content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
        
        # Write back if changes were made
        if content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✅ Applied Stage 2 parameter fixes to: {file_path}")
            return True
        else:
            print(f"⏭️  No parameter issues found: {file_path}")
            return False
            
    except Exception as e:
        print(f"❌ Error processing {file_path}: {e}")
        return False

def main():
    """Main function to apply Stage 2 parameter resolution to all test files"""
    test_dir = "/mnt/c/Users/elija/SynologyDrive/Godot/five-parsecs-campaign-manager/tests"
    
    if not os.path.exists(test_dir):
        print(f"❌ Test directory not found: {test_dir}")
        sys.exit(1)
    
    # Find all .gd files in tests directory
    test_files = []
    for root, dirs, files in os.walk(test_dir):
        for file in files:
            if file.endswith('.gd'):
                test_files.append(os.path.join(root, file))
    
    print(f"🎯 Found {len(test_files)} test files")
    print("🔧 Applying Stage 2 parameter name resolution...")
    
    processed = 0
    modified = 0
    
    for file_path in sorted(test_files):
        processed += 1
        if apply_stage2_parameters(file_path):
            modified += 1
    
    print(f"\n📊 Stage 2 Results:")
    print(f"   Processed: {processed} files")
    print(f"   Modified:  {modified} files")
    print(f"   Skipped:   {processed - modified} files")
    print("✅ Stage 2 parameter name resolution complete!")

if __name__ == "__main__":
    main()