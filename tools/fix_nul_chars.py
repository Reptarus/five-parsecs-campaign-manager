#!/usr/bin/env python3
"""
Fix NUL Character Script

This script scans files for NUL bytes (0x00) and other problematic control characters
and removes them. It's especially useful for fixing corrupted GDScript files.

Usage:
  python fix_nul_chars.py

The script will automatically scan the specified directories for problematic files.
"""

import os
import sys
import re

# Directories to scan
DIRECTORIES = [
    "addons/gut",
    "tests", 
    "src",
    "."  # Root directory (scan everything)
]

def fix_file(file_path):
    """Fix NUL characters in a file"""
    print(f"Checking: {file_path}")
    
    # Read the file in binary mode to detect NUL bytes
    try:
        with open(file_path, 'rb') as f:
            content = f.read()
    except Exception as e:
        print(f"  Error reading file: {e}")
        return False
    
    # Check for NUL bytes
    nul_count = content.count(b'\x00')
    if nul_count == 0:
        return False  # No NUL bytes found
    
    print(f"  Found {nul_count} NUL bytes")
    
    # Create a new content by filtering out NUL bytes and control characters
    # except for tab (0x09), LF (0x0A), and CR (0x0D)
    new_content = bytearray()
    for byte in content:
        if byte == 0x00:  # NUL byte
            continue
        elif byte < 32 and byte not in (9, 10, 13):  # Other control characters except tab, LF, CR
            continue
        else:
            new_content.append(byte)
    
    # If we filtered anything, write the file back
    if len(new_content) != len(content):
        try:
            with open(file_path, 'wb') as f:
                f.write(new_content)
            print(f"  Successfully cleaned file, removed {len(content) - len(new_content)} bytes")
            return True
        except Exception as e:
            print(f"  Error writing file: {e}")
            return False
    
    return False

def process_directory(directory):
    """Process all files in a directory recursively"""
    fixed_count = 0
    
    # Skip .git directory
    if ".git" in directory:
        return 0
        
    for root, dirs, files in os.walk(directory):
        # Skip .git directories
        if ".git" in dirs:
            dirs.remove(".git")
            
        for file in files:
            # Only process text file types that might have GDScript or scenes
            if file.endswith(('.gd', '.tscn', '.tres', '.md', '.txt', '.json', '.cfg', '.yaml', '.ini')):
                file_path = os.path.join(root, file)
                if fix_file(file_path):
                    fixed_count += 1
    
    return fixed_count

def main():
    """Main function"""
    print("Starting NUL character cleanup...")
    
    total_fixed = 0
    
    # First, fix critical files directly
    critical_files = [
        "tests/fixtures/base/base_test.gd",
        "tests/fixtures/specialized/enemy_test.gd",
        "addons/gut/test.gd",
        "addons/gut/strutils.gd",
        "addons/gut/gut.gd",
        "addons/gut/utils.gd"
    ]
    
    print("Fixing critical files first...")
    for file_path in critical_files:
        if os.path.exists(file_path):
            if fix_file(file_path):
                total_fixed += 1
        else:
            print(f"  Critical file not found: {file_path}")
    
    # Process directories
    for directory in DIRECTORIES:
        if os.path.exists(directory):
            print(f"Processing directory: {directory}")
            total_fixed += process_directory(directory)
        else:
            print(f"Directory not found: {directory}")
    
    print(f"Cleanup complete. Fixed {total_fixed} files.")
    print("Please restart Godot to ensure changes take effect.")

if __name__ == "__main__":
    main() 