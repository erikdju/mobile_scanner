#!/bin/bash
# Run capture rotation tests on macOS without building a Flutter application.
set -euo pipefail

test_dir="$(cd "$(dirname "$0")" && pwd)"
test_build_dir="$(mktemp -d "${TMPDIR:-/tmp}/mobile-scanner-rotation.XXXXXX")"
trap 'rm -rf "$test_build_dir"' EXIT
developer_dir="$(xcode-select -p)"
framework_dir="$developer_dir/Platforms/MacOSX.platform/Developer/Library/Frameworks"
test_library_dir="$developer_dir/Platforms/MacOSX.platform/Developer/usr/lib"

xcrun swiftc -emit-library -emit-module -enable-testing -module-name mobile_scanner \
    "$test_dir/../mobile_scanner/Sources/mobile_scanner/CapturedImageRotation.swift" \
    -o "$test_build_dir/libmobile_scanner.dylib" \
    -emit-module-path "$test_build_dir/mobile_scanner.swiftmodule" \
    -module-cache-path "$test_build_dir/cache"

cat > "$test_build_dir/main.swift" <<'SWIFT'
import XCTest
let suite = CapturedImageRotationTests.defaultTestSuite
suite.run()
if suite.testRun?.hasSucceeded != true { exit(1) }
SWIFT

xcrun swiftc -F "$framework_dir" -I "$test_library_dir" -L "$test_library_dir" \
    -I "$test_build_dir" -L "$test_build_dir" -lmobile_scanner \
    -Xlinker -rpath -Xlinker "$test_build_dir" \
    -Xlinker -rpath -Xlinker "$framework_dir" \
    -Xlinker -rpath -Xlinker "$test_library_dir" \
    "$test_dir/CapturedImageRotationTests.swift" "$test_build_dir/main.swift" \
    -o "$test_build_dir/tests" -module-cache-path "$test_build_dir/cache"
"$test_build_dir/tests"
