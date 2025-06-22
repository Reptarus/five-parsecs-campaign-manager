#!/usr/bin/env python3
"""
Apply Stage 1 class-level @warning_ignore annotations to test files
Following the proven 7-stage methodology from WARNING_FIX_SUMMARY.md
"""

import os
import re
import sys

def apply_stage1_warnings(file_path):
    """Apply class-level warning ignore annotations to a test file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Skip if already has comprehensive warning ignores
        if "@warning_ignore(\"return_value_discarded\")" in content:
            return False
        
        # Pattern to find extends line after class_name or first line
        extends_patterns = [
            # Pattern for class_name followed by extends
            (r'^(class_name\s+\w+\s*)(\nextends\s+)', r'\1\n@warning_ignore("return_value_discarded")\n@warning_ignore("unsafe_method_access")\n@warning_ignore("unsafe_call_argument")\n@warning_ignore("untyped_declaration")\n@warning_ignore("unused_variable")\2'),
            # Pattern for @tool followed by extends
            (r'^(@tool\s*)(\nextends\s+)', r'\1\n@warning_ignore("return_value_discarded")\n@warning_ignore("unsafe_method_access")\n@warning_ignore("unsafe_call_argument")\n@warning_ignore("untyped_declaration")\n@warning_ignore("unused_variable")\2'),
            # Pattern for direct extends line
            (r'^(extends\s+)', r'@warning_ignore("return_value_discarded")\n@warning_ignore("unsafe_method_access")\n@warning_ignore("unsafe_call_argument")\n@warning_ignore("untyped_declaration")\n@warning_ignore("unused_variable")\n\1'),
        ]
        
        modified = False
        for pattern, replacement in extends_patterns:
            new_content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
            if new_content != content:
                content = new_content
                modified = True
                break
        
        if modified:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✅ Applied Stage 1 warnings to: {file_path}")
            return True
        else:
            print(f"⏭️  Skipped (no pattern match): {file_path}")
            return False
            
    except Exception as e:
        print(f"❌ Error processing {file_path}: {e}")
        return False

def main():
    """Main function to apply Stage 1 warnings to all test files"""
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
    print("🚀 Applying Stage 1 class-level @warning_ignore annotations...")
    
    processed = 0
    modified = 0
    
    for file_path in sorted(test_files):
        processed += 1
        if apply_stage1_warnings(file_path):
            modified += 1
    
    print(f"\n📊 Stage 1 Results:")
    print(f"   Processed: {processed} files")
    print(f"   Modified:  {modified} files")
    print(f"   Skipped:   {processed - modified} files")
    print("✅ Stage 1 class-level foundation complete!")

if __name__ == "__main__":
    main()