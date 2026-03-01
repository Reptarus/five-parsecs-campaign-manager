#!/bin/bash

# Five Parsecs Campaign Manager - Git Hooks Installation Script
# Sets up pre-commit hooks for test-driven development workflow

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

echo "🔧 Installing Five Parsecs Git hooks..."
echo "Project root: $PROJECT_ROOT"

# Ensure hooks directory exists
mkdir -p "$HOOKS_DIR"

# Create pre-commit hook
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
# Five Parsecs Campaign Manager - Pre-commit Hook
# Runs quick validation before allowing commits

set -e

echo "🧪 Five Parsecs pre-commit validation..."

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
cd "$PROJECT_ROOT"

# Configuration
GODOT_BINARY_PATHS=(
    "/mnt/c/Users/elija/Desktop/GoDot/Godot 4.4/Godot_v4.4.1-stable_win64_console.exe"
    "/usr/bin/godot4"
    "/usr/local/bin/godot"
    "$HOME/godot/Godot_v4.4.1-stable_linux.x86_64"
)

# Find available Godot binary
GODOT_BINARY=""
for path in "${GODOT_BINARY_PATHS[@]}"; do
    if [ -f "$path" ]; then
        GODOT_BINARY="$path"
        break
    fi
done

if [ -z "$GODOT_BINARY" ]; then
    echo "⚠️  Warning: No Godot binary found. Skipping pre-commit tests."
    echo "   Expected paths:"
    for path in "${GODOT_BINARY_PATHS[@]}"; do
        echo "   - $path"
    done
    echo "   Commit allowed, but run manual tests before push."
    exit 0
fi

echo "✅ Using Godot binary: $GODOT_BINARY"

# Check if this is a test-related change
CHANGED_FILES=$(git diff --cached --name-only)
TEST_CHANGES=$(echo "$CHANGED_FILES" | grep -E "(test|spec)" || true)
SRC_CHANGES=$(echo "$CHANGED_FILES" | grep -E "src/" || true)

echo "📄 Changed files: $(echo "$CHANGED_FILES" | wc -l)"

# Quick syntax validation (always run)
echo "🔍 Running syntax validation..."
if ! timeout 30 "$GODOT_BINARY" --headless --check-only --quit >/dev/null 2>&1; then
    echo "❌ COMMIT BLOCKED: Syntax validation failed"
    echo "   Run this command to check errors:"
    echo "   \"$GODOT_BINARY\" --headless --check-only"
    exit 1
fi
echo "✅ Syntax validation passed"

# Run critical tests if source code changed
if [ -n "$SRC_CHANGES" ] || [ -n "$TEST_CHANGES" ]; then
    echo "🧪 Running critical unit tests..."
    
    # Run wrapper unit test (fastest validation)
    if ! timeout 60 "$GODOT_BINARY" --headless --path . \
         -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
         -a res://tests/unit/test_global_enums_unit.gd \
         --ignoreHeadlessMode -c >/dev/null 2>&1; then
        echo "❌ COMMIT BLOCKED: Critical unit tests failed"
        echo "   Run this command to see test output:"
        echo "   \"$GODOT_BINARY\" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/test_global_enums_unit.gd --ignoreHeadlessMode -c"
        exit 1
    fi
    echo "✅ Critical unit tests passed"
    
    # Run quick integration test if major source changes
    SRC_FILE_COUNT=$(echo "$SRC_CHANGES" | wc -l)
    if [ "$SRC_FILE_COUNT" -gt 3 ]; then
        echo "🔄 Running quick integration test..."
        
        if ! timeout 90 "$GODOT_BINARY" --headless --path . \
             -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
             -a res://tests/integration/test_campaign_initialization.gd \
             --ignoreHeadlessMode -c >/dev/null 2>&1; then
            echo "⚠️  Warning: Integration test failed"
            echo "   Consider running full test suite before push:"
            echo "   ./scripts/run_comprehensive_test_suite.sh"
            echo "   Commit allowed, but investigate test failure."
        else
            echo "✅ Quick integration test passed"
        fi
    fi
fi

echo "🎉 Pre-commit validation completed successfully"
echo "💡 Tip: Run './scripts/run_comprehensive_test_suite.sh' for full validation"

exit 0
EOF

# Make pre-commit hook executable
chmod +x "$HOOKS_DIR/pre-commit"

# Create pre-push hook for comprehensive testing
cat > "$HOOKS_DIR/pre-push" << 'EOF'
#!/bin/bash
# Five Parsecs Campaign Manager - Pre-push Hook
# Runs comprehensive test suite before pushing to remote

set -e

echo "🚀 Five Parsecs pre-push validation..."

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
cd "$PROJECT_ROOT"

# Check if comprehensive test runner exists
if [ ! -f "scripts/run_comprehensive_test_suite.sh" ]; then
    echo "⚠️  Warning: Comprehensive test runner not found. Push allowed."
    exit 0
fi

# Get branch being pushed
protected_branches="main develop emergency-character-fix-comprehensive"
current_branch=$(git rev-parse --abbrev-ref HEAD)

# Run comprehensive tests for protected branches
for branch in $protected_branches; do
    if [ "$current_branch" = "$branch" ]; then
        echo "🧪 Running comprehensive test suite for protected branch: $branch"
        
        if ! timeout 300 ./scripts/run_comprehensive_test_suite.sh; then
            echo "❌ PUSH BLOCKED: Comprehensive test suite failed"
            echo "   Fix failing tests before pushing to $branch"
            exit 1
        fi
        
        echo "✅ Comprehensive test suite passed"
        break
    fi
done

echo "🎉 Pre-push validation completed successfully"
exit 0
EOF

# Make pre-push hook executable
chmod +x "$HOOKS_DIR/pre-push"

echo "✅ Git hooks installed successfully!"
echo ""
echo "📋 Installed hooks:"
echo "  • pre-commit: Quick syntax and critical test validation"
echo "  • pre-push: Comprehensive test suite for protected branches"
echo ""
echo "🎯 Hook behavior:"
echo "  • Syntax validation: Always runs"
echo "  • Critical tests: Run when src/ or test files change"  
echo "  • Integration tests: Run when 3+ source files change"
echo "  • Comprehensive tests: Run before push to main/develop"
echo ""
echo "💡 Manual execution:"
echo "  • Quick tests: ./.git/hooks/pre-commit"
echo "  • Full tests: ./scripts/run_comprehensive_test_suite.sh"
echo ""
echo "🔧 To disable hooks temporarily:"
echo "  • git commit --no-verify"
echo "  • git push --no-verify"