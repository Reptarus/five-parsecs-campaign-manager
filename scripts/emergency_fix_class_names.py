#!/usr/bin/env python3
"""
Emergency class name conflict resolver for Five Parsecs
Finds and fixes duplicate class_name declarations
"""

import os
import re
from pathlib import Path

def find_class_conflicts(src_dir):
    """Find all duplicate class_name declarations"""
    class_names = {}
    
    for root, dirs, files in os.walk(src_dir):
        for file in files:
            if file.endswith('.gd'):
                filepath = os.path.join(root, file)
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()
                    matches = re.findall(r'^class_name\s+(\w+)', content, re.MULTILINE)
                    for class_name in matches:
                        if class_name not in class_names:
                            class_names[class_name] = []
                        class_names[class_name].append(filepath)
    
    # Find conflicts
    conflicts = {k: v for k, v in class_names.items() if len(v) > 1}
    return conflicts

def fix_conflicts(conflicts):
    """Rename conflicting class names to unique names"""
    fixes = []
    
    for class_name, files in conflicts.items():
        print(f"\n[CONFLICT] {class_name} defined in {len(files)} files:")
        
        # Keep the first one, rename others
        for i, filepath in enumerate(files):
            rel_path = filepath.replace('\\', '/').split('/')[-3:]
            print(f"  {i+1}. .../{'/'.join(rel_path)}")
            
            if i > 0:  # Rename all but the first
                # Generate unique name based on path
                path_parts = Path(filepath).parts
                unique_suffix = path_parts[-2].title()
                new_name = f"{class_name}{unique_suffix}"
                
                fixes.append({
                    'file': filepath,
                    'old': f"class_name {class_name}",
                    'new': f"class_name {new_name}"
                })
                print(f"     -> Will rename to: {new_name}")
    
    return fixes

def apply_fixes(fixes):
    """Apply the renaming fixes"""
    print(f"\n[FIXING] Applying {len(fixes)} fixes...")
    
    for fix in fixes:
        with open(fix['file'], 'r', encoding='utf-8') as f:
            content = f.read()
        
        content = content.replace(fix['old'], fix['new'])
        
        with open(fix['file'], 'w', encoding='utf-8') as f:
            f.write(content)
        
        print(f"  [FIXED] {fix['file'].split('\\')[-1]}")

if __name__ == "__main__":
    src_dir = r"C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager\src"
    
    print("[SCAN] Scanning for class name conflicts...")
    conflicts = find_class_conflicts(src_dir)
    
    if conflicts:
        print(f"\n[WARNING] Found {len(conflicts)} class name conflicts!")
        fixes = fix_conflicts(conflicts)
        
        if input("\nApply fixes? (y/n): ").lower() == 'y':
            apply_fixes(fixes)
            print("\n[SUCCESS] All conflicts resolved!")
    else:
        print("[SUCCESS] No class name conflicts found!")
