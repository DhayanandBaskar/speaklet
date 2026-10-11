#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
export CLANG_MODULE_CACHE_PATH="$PWD/build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/build/module-cache"
swift run --disable-sandbox --scratch-path build/spm --cache-path build/cache \
  --config-path build/config --security-path build/security WhisperCoreChecks
swift run --disable-sandbox --scratch-path build/spm --cache-path build/cache \
  --config-path build/config --security-path build/security WhisperAccessibilityChecks
swift run --disable-sandbox --scratch-path build/spm --cache-path build/cache \
  --config-path build/config --security-path build/security WhisperNativeChecks
