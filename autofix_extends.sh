#!/bin/bash
# Script to automatically fix extends statements in test files

# Define the base path for test files
TEST_DIR="tests"

# Fix direct GameTest extends
echo "Fixing extends GameTest references..."
find $TEST_DIR -type f -name "*.gd" -exec grep -l "extends GameTest" {} \; | while read file; do
  # Skip files that might already use proper extends
  if grep -q "extends \"res://" "$file"; then
    echo "  Skipping $file - already uses explicit path"
    continue
  fi
  
  echo "  Fixing $file"
  # Use sed to replace the extends statement
  sed -i 's/extends GameTest/extends "res:\/\/tests\/fixtures\/base\/game_test.gd"\n# Use explicit preloads instead of global class names/g' "$file"
done

# Fix direct BattleTest extends
echo "Fixing extends BattleTest references..."
find $TEST_DIR -type f -name "*.gd" -exec grep -l "extends BattleTest" {} \; | while read file; do
  # Skip files that might already use proper extends
  if grep -q "extends \"res://" "$file"; then
    echo "  Skipping $file - already uses explicit path"
    continue
  fi
  
  echo "  Fixing $file"
  # Use sed to replace the extends statement
  sed -i 's/extends BattleTest/extends "res:\/\/tests\/fixtures\/specialized\/battle_test.gd"\n# Use explicit preloads instead of global class names/g' "$file"
done

# Fix direct UITest extends
echo "Fixing extends UITest references..."
find $TEST_DIR -type f -name "*.gd" -exec grep -l "extends UITest" {} \; | while read file; do
  # Skip files that might already use proper extends
  if grep -q "extends \"res://" "$file"; then
    echo "  Skipping $file - already uses explicit path"
    continue
  fi
  
  echo "  Fixing $file"
  # Use sed to replace the extends statement
  sed -i 's/extends UITest/extends "res:\/\/tests\/fixtures\/specialized\/ui_test.gd"\n# Use explicit preloads instead of global class names/g' "$file"
done

echo "Done! Please check the modified files." 