#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p work/swift-cache work/clang-cache
export CLANG_MODULE_CACHE_PATH="$PWD/work/clang-cache"
swiftc -parse-as-library -swift-version 6 -module-cache-path work/swift-cache Sources/OutputTray/ArtifactStore.swift Sources/OutputTray/CodexDiscovery.swift scripts/store-tests.swift -o work/store-tests
./work/store-tests
PYTHONPYCACHEPREFIX="$PWD/work/python-cache" python3 -m py_compile outputs/register-output.py

PYTHONPYCACHEPREFIX="$PWD/work/python-cache" python3 scripts/test-cli.py
