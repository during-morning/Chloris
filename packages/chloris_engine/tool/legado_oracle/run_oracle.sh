#!/usr/bin/env bash
# Convenience wrapper around the Legado-E judging launcher.
# Ensures the launcher is built once, then execs it with stdin passthrough.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

# Use the project's pinned JDK if JAVA_HOME is not already set.
if [ -z "${JAVA_HOME:-}" ]; then
  export JAVA_HOME="/Users/bedrock/Library/Java/JavaVirtualMachines/ms-21.0.7/Contents/Home"
fi

LAUNCHER="$DIR/build/install/legado-oracle/bin/legado-oracle"
if [ ! -x "$LAUNCHER" ]; then
  echo "[run_oracle] launcher not found, building via gradle installDist ..." >&2
  gradle installDist -q
fi

exec "$LAUNCHER" "$@"
