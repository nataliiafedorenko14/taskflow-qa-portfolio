#!/usr/bin/env bash
#
# Regenerate the Xcode project from project.yml using XcodeGen.
#   brew install xcodegen   # one-time, if not installed
#   ./regen-ios.sh
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is not installed. Install it with:" >&2
  echo "  brew install xcodegen" >&2
  exit 1
fi

echo ">> Generating TaskFlow.xcodeproj"
xcodegen generate
echo ">> Done. Open ios/TaskFlow.xcodeproj in Xcode."
