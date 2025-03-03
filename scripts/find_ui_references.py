#!/usr/bin/env python3
"""
Find UI References Script for Five Parsecs Campaign Manager
This script scans the codebase for references to UI files that need to be updated
after the UI reorganization. It generates a replacement script to update references.
"""

import os
import re
import sys
from pathlib import Path

# Define search patterns and their replacements
SEARCH_PATTERNS = {
    # Character-related files
    r'["\'](?:res://)?src/ui/CharacterBox\.tscn["\']': 'res://src/ui/screens/character/CharacterBox.tscn',
    r'["\'](?:res://)?src/ui/CharacterCreator\.tscn["\']': 'res://src/ui/screens/character/CharacterCreator.tscn',
    r'["\'](?:res://)?src/ui/CharacterSheet\.tscn["\']': 'res://src/ui/screens/character/CharacterSheet.tscn',
    r'["\'](?:res://)?src/ui/CharacterProgression\.tscn["\']': 'res://src/ui/screens/character/CharacterProgression.tscn',
    
    # Campaign-related files
    r'["\'](?:res://)?src/ui/CampaignDashboard\.tscn["\']': 'res://src/ui/screens/campaign/CampaignDashboard.tscn',
    r'["\'](?:res://)?src/ui/VictoryConditionSelection\.tscn["\']': 'res://src/ui/screens/campaign/setup/VictoryConditionSelection.tscn',
    
    # Tutorial-related files
    r'["\'](?:res://)?src/ui/TutorialSelection\.tscn["\']': 'res://src/ui/screens/tutorial/TutorialSelection.tscn',
    r'["\'](?:res://)?src/ui/NewCampaignTutorial\.tscn["\']': 'res://src/ui/screens/tutorial/NewCampaignTutorial.tscn',
    
    # Other files
    r'["\'](?:res://)?src/ui/ConnectionsCreation\.tscn["\']': 'res://src/ui/screens/connections/ConnectionsCreation.tscn',
    
    # Catch preload/load statements
    r'preload\(["\'](?:res://)?src/ui/CharacterBox\.tscn["\']\)': 'preload("res://src/ui/screens/character/CharacterBox.tscn")',
    r'preload\(["\'](?:res://)?src/ui/CharacterCreator\.tscn["\']\)': 'preload("res://src/ui/screens/character/CharacterCreator.tscn")', 
    r'preload\(["\'](?:res://)?src/ui/CharacterSheet\.tscn["\']\)': 'preload("res://src/ui/screens/character/CharacterSheet.tscn")',
    r'preload\(["\'](?:res://)?src/ui/CharacterProgression\.tscn["\']\)': 'preload("res://src/ui/screens/character/CharacterProgression.tscn")',
    r'preload\(["\'](?:res://)?src/ui/CampaignDashboard\.tscn["\']\)': 'preload("res://src/ui/screens/campaign/CampaignDashboard.tscn")',
    r'preload\(["\'](?:res://)?src/ui/VictoryConditionSelection\.tscn["\']\)': 'preload("res://src/ui/screens/campaign/setup/VictoryConditionSelection.tscn")',
    r'preload\(["\'](?:res://)?src/ui/TutorialSelection\.tscn["\']\)': 'preload("res://src/ui/screens/tutorial/TutorialSelection.tscn")',
    r'preload\(["\'](?:res://)?src/ui/NewCampaignTutorial\.tscn["\']\)': 'preload("res://src/ui/screens/tutorial/NewCampaignTutorial.tscn")',
    r'preload\(["\'](?:res://)?src/ui/ConnectionsCreation\.tscn["\']\)': 'preload("res://src/ui/screens/connections/ConnectionsCreation.tscn")',
    
    r'load\(["\'](?:res://)?src/ui/CharacterBox\.tscn["\']\)': 'load("res://src/ui/screens/character/CharacterBox.tscn")',
    r'load\(["\'](?:res://)?src/ui/CharacterCreator\.tscn["\']\)': 'load("res://src/ui/screens/character/CharacterCreator.tscn")',
    r'load\(["\'](?:res://)?src/ui/CharacterSheet\.tscn["\']\)': 'load("res://src/ui/screens/character/CharacterSheet.tscn")',
    r'load\(["\'](?:res://)?src/ui/CharacterProgression\.tscn["\']\)': 'load("res://src/ui/screens/character/CharacterProgression.tscn")',
    r'load\(["\'](?:res://)?src/ui/CampaignDashboard\.tscn["\']\)': 'load("res://src/ui/screens/campaign/CampaignDashboard.tscn")',
    r'load\(["\'](?:res://)?src/ui/VictoryConditionSelection\.tscn["\']\)': 'load("res://src/ui/screens/campaign/setup/VictoryConditionSelection.tscn")',
    r'load\(["\'](?:res://)?src/ui/TutorialSelection\.tscn["\']\)': 'load("res://src/ui/screens/tutorial/TutorialSelection.tscn")',
    r'load\(["\'](?:res://)?src/ui/NewCampaignTutorial\.tscn["\']\)': 'load("res://src/ui/screens/tutorial/NewCampaignTutorial.tscn")',
    r'load\(["\'](?:res://)?src/ui/ConnectionsCreation\.tscn["\']\)': 'load("res://src/ui/screens/connections/ConnectionsCreation.tscn")',
}

def find_references(search_dir, patterns):
    """
    Find all files that contain references to UI files that need to be updated.
    
    Args:
        search_dir (str): Directory to search for references
        patterns (dict): Dictionary of regex patterns to search for
        
    Returns:
        dict: Dictionary of files with references found and their replacements
    """
    if not os.path.isdir(search_dir):
        print(f"Error: {search_dir} is not a valid directory")
        sys.exit(1)
        
    print(f"Searching for UI references in {search_dir}...")
    references = {}
    
    # File extensions to search
    extensions = ['.gd', '.tscn', '.tres', '.import', '.cfg']
    
    for root, _, files in os.walk(search_dir):
        for file in files:
            # Skip directories like .git
            if root.startswith('.'):
                continue
                
            # Check if file has a relevant extension
            if not any(file.endswith(ext) for ext in extensions):
                continue
                
            file_path = os.path.join(root, file)
            
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    
                file_references = {}
                
                for pattern, replacement in patterns.items():
                    matches = re.findall(pattern, content)
                    if matches:
                        file_references[pattern] = {
                            'replacement': replacement,
                            'count': len(matches)
                        }
                        
                if file_references:
                    references[file_path] = file_references
                    
            except UnicodeDecodeError:
                print(f"Warning: Could not read {file_path} as text")
            except Exception as e:
                print(f"Error reading {file_path}: {e}")
                
    return references

def create_replacement_script(references, output_file="scripts/apply_ui_replacements.py"):
    """
    Create a Python script that will apply the replacements found.
    
    Args:
        references (dict): Dictionary of files with references found
        output_file (str): Path to write the replacement script to
    """
    if not references:
        print("No references found.")
        return
        
    print(f"Creating replacement script: {output_file}")
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("""#!/usr/bin/env python3
\"\"\"
UI Reference Updater for Five Parsecs Campaign Manager
This script updates references to UI files after reorganization.
Generated by find_ui_references.py
\"\"\"

import os
import re
import sys
import argparse
from pathlib import Path

def update_references(dry_run=False):
    \"\"\"
    Update references to UI files.
    
    Args:
        dry_run (bool): If True, print changes but don't apply them
    \"\"\"
    changes_made = 0
    
    # Dictionary of files to process with their replacements
    files_to_process = {
""")
        
        # Generate the files_to_process dictionary
        for file_path, patterns in references.items():
            f.write(f"        \"{file_path}\": {{\n")
            for pattern, info in patterns.items():
                f.write(f"            r\"{pattern}\": \"{info['replacement']}\",\n")
            f.write("        },\n")
            
        f.write("""    }
    
    for file_path, patterns in files_to_process.items():
        if not os.path.exists(file_path):
            print(f"Warning: {file_path} no longer exists, skipping")
            continue
            
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            original_content = content
            
            for pattern, replacement in patterns.items():
                content = re.sub(pattern, replacement, content)
                
            if content != original_content:
                if dry_run:
                    print(f"Would update: {file_path}")
                    # Show diff
                    for line_num, (old_line, new_line) in enumerate(zip(
                            original_content.splitlines(), 
                            content.splitlines())):
                        if old_line != new_line:
                            print(f"  Line {line_num + 1}:")
                            print(f"    - {old_line}")
                            print(f"    + {new_line}")
                else:
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(content)
                    print(f"Updated: {file_path}")
                changes_made += 1
                
        except Exception as e:
            print(f"Error processing {file_path}: {e}")
            
    print(f"{'Would make' if dry_run else 'Made'} changes to {changes_made} files")
    return changes_made

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Update UI file references")
    parser.add_argument("--dry-run", action="store_true", 
                        help="Show changes without applying them")
    args = parser.parse_args()
    
    update_references(dry_run=args.dry_run)
""")
    
    print(f"Created replacement script: {output_file}")
    print(f"Run with: python {output_file} --dry-run")
    print(f"After verifying changes: python {output_file}")

def main():
    if len(sys.argv) < 2:
        print("Usage: python find_ui_references.py <directory_to_search>")
        sys.exit(1)
        
    search_dir = sys.argv[1]
    references = find_references(search_dir, SEARCH_PATTERNS)
    
    print(f"Found references in {len(references)} files:")
    for file_path, patterns in references.items():
        print(f"- {file_path}")
        for pattern, info in patterns.items():
            print(f"  - {info['count']} matches for {pattern}")
            
    create_replacement_script(references)
    
if __name__ == "__main__":
    main() 