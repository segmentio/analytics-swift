#!/bin/bash
#
# Run E2E tests for analytics-swift
#
# Prerequisites: Xcode / Swift toolchain, Node.js 18+
#
# Usage:
#   ./run-e2e.sh [extra args passed to run-tests.sh]
#
# Override sdk-e2e-tests location:
#   E2E_TESTS_DIR=../my-e2e-tests ./run-e2e.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK_ROOT="$SCRIPT_DIR"
E2E_DIR="${E2E_TESTS_DIR:-$SDK_ROOT/../sdk-e2e-tests}"

echo "=== Building analytics-swift e2e-cli ==="

# Apply HTTP patch
cd "$SDK_ROOT"
if git apply --check "$E2E_DIR/patches/analytics-swift-http.patch" 2>/dev/null; then
    git apply "$E2E_DIR/patches/analytics-swift-http.patch"
    echo "HTTP patch applied"
else
    echo "HTTP patch already applied or not applicable (skipping)"
fi

# Build SDK and e2e-cli
swift build

CLI_PATH="$SDK_ROOT/.build/debug/e2e-cli"
echo "Built: $CLI_PATH"

echo ""

# Run tests — swift's e2e-config.json is at repo root (not in a subdir)
cd "$E2E_DIR"
./scripts/run-tests.sh \
    --sdk-dir "$SDK_ROOT" \
    --cli "$CLI_PATH" \
    --sdk-path "$SDK_ROOT" \
    "$@"
