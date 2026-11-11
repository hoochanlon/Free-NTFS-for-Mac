#!/bin/bash
set -euo pipefail

MACOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$MACOS_ROOT/.." && pwd)"
cd "$PROJECT_ROOT"

swift run Nigate "$@"
