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
SDK_ROOT="$SCRIPT_DIR/.."
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

# Build e2e-cli (separate package that depends on parent SDK)
cd "$SCRIPT_DIR"
swift build

CLI_PATH="$SCRIPT_DIR/.build/debug/E2ECLI"
echo "Built: $CLI_PATH"

echo ""

# Run tests
cd "$E2E_DIR"
./scripts/run-tests.sh \
    --sdk-dir "$SCRIPT_DIR" \
    --cli "$CLI_PATH" \
    --sdk-path "$SDK_ROOT" \
    "$@"
