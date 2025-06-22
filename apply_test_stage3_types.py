#!/usr/bin/env python3
"""
Apply Stage 3 type declaration enhancement to test files
Following the proven 7-stage methodology from WARNING_FIX_SUMMARY.md
"""

import os
import re
import sys

def apply_stage3_types(file_path):
    """Apply type declaration enhancements to test files"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Type enhancement patterns for test files
        patterns = [
            # Array type declarations
            (r'var\s+(\w*test_\w+|mock_\w+|\w*_tests|\w*_data|\w*_files|crew|enemies|items|units)\s*:\s*Array\s*=\s*\[', r'var \1: Array = ['),
            (r'var\s+(\w*test_\w+|mock_\w+|\w*_tests|\w*_data|\w*_files|crew|enemies|items|units)\s*=\s*\[\]', r'var \1: Array = []'),
            
            # Dictionary type declarations
            (r'var\s+(\w*test_\w+|mock_\w+|\w*_config|\w*_data|\w*_state|campaign|mission|character)\s*:\s*Dictionary\s*=\s*\{', r'var \1: Dictionary = {'),
            (r'var\s+(\w*test_\w+|mock_\w+|\w*_config|\w*_data|\w*_state|campaign|mission|character)\s*=\s*\{\}', r'var \1: Dictionary = {}'),
            
            # String type declarations
            (r'var\s+(name|id|type|path|file|message|description)\s*=\s*""', r'var \1: String = ""'),
            (r'var\s+(name|id|type|path|file|message|description)\s*:\s*String\s*=\s*""', r'var \1: String = ""'),
            
            # Integer type declarations
            (r'var\s+(count|size|index|level|damage|health|credits|supplies)\s*=\s*([0-9]+)', r'var \1: int = \2'),
            (r'var\s+(count|size|index|level|damage|health|credits|supplies)\s*:\s*int\s*=\s*([0-9]+)', r'var \1: int = \2'),
            
            # Boolean type declarations
            (r'var\s+(is_\w+|has_\w+|can_\w+|should_\w+|valid|active|enabled)\s*=\s*(true|false)', r'var \1: bool = \2'),
            (r'var\s+(is_\w+|has_\w+|can_\w+|should_\w+|valid|active|enabled)\s*:\s*bool\s*=\s*(true|false)', r'var \1: bool = \2'),
            
            # Float type declarations
            (r'var\s+(timer|timeout|duration|progress|percentage)\s*=\s*([0-9]*\.[0-9]+)', r'var \1: float = \2'),
            (r'var\s+(timer|timeout|duration|progress|percentage)\s*:\s*float\s*=\s*([0-9]*\.[0-9]+)', r'var \1: float = \2'),
            
            # Loop variable typing
            (r'for\s+(\w+)\s+in\s+range\(', r'for \1: int in range('),
            (r'for\s+(\w+)\s+in\s+(\w*tests?|\w*items?|\w*files?|\w*data|\w*results?):', r'for \1: String in \2:'),
            (r'for\s+(\w+)\s+in\s+(\w*enemies?|\w*units?|\w*characters?):', r'for \1: Node in \2:'),
            
            # Method parameter typing for common test patterns
            (r'func\s+(test_\w+|create_\w+|setup_\w+|teardown_\w+)\s*\(\s*([^)]*)\)\s*->\s*void:', r'func \1(\2) -> void:'),
            (r'func\s+(assert_\w+|verify_\w+|check_\w+)\s*\(\s*([^)]*)\)\s*->\s*bool:', r'func \1(\2) -> bool:'),
            
            # Return type annotations for test utility functions
            (r'func\s+(get_\w+|create_\w+|build_\w+)\s*\([^)]*\)\s*:', r'\g<0> -> Variant:'),
            (r'func\s+(is_\w+|has_\w+|can_\w+|should_\w+)\s*\([^)]*\)\s*:', r'\g<0> -> bool:'),
            
            # Node variable typing
            (r'var\s+(\w*manager|\w*controller|\w*system|\w*component)\s*=\s*Node\.new\(\)', r'var \1: Node = Node.new()'),
            (r'var\s+(\w*button|\w*label|\w*panel|\w*dialog)\s*=\s*\w+\.new\(\)', r'var \1: Control = \g<0>'),
            
            # Resource variable typing
            (r'var\s+(\w*resource|\w*scene|\w*texture|\w*material)\s*=\s*\w+\.new\(\)', r'var \1: Resource = \g<0>'),
            
            # Test data structure typing
            (r'var\s+(test_\w+_data|mock_\w+_data|\w+_test_data)\s*=\s*\{', r'var \1: Dictionary = {'),
            (r'var\s+(test_\w+_list|mock_\w+_list|\w+_test_list)\s*=\s*\[', r'var \1: Array = ['),
            
            # Signal connection typing (common in tests)
            (r'var\s+(signal_\w+|connection_\w+)\s*=\s*.*\.connect\(', r'var \1: Callable = \g<0>'),
        ]
        
        # Apply all patterns
        for pattern, replacement in patterns:
            content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
        
        # Write back if changes were made
        if content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✅ Applied Stage 3 type enhancements to: {file_path}")
            return True
        else:
            print(f"⏭️  No type enhancement opportunities: {file_path}")
            return False
            
    except Exception as e:
        print(f"❌ Error processing {file_path}: {e}")
        return False

def main():
    """Main function to apply Stage 3 type enhancements to all test files"""
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
    print("📝 Applying Stage 3 type declaration enhancements...")
    
    processed = 0
    modified = 0
    
    for file_path in sorted(test_files):
        processed += 1
        if apply_stage3_types(file_path):
            modified += 1
    
    print(f"\n📊 Stage 3 Results:")
    print(f"   Processed: {processed} files")
    print(f"   Modified:  {modified} files")
    print(f"   Skipped:   {processed - modified} files")
    print("✅ Stage 3 type declaration enhancement complete!")

if __name__ == "__main__":
    main()