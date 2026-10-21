#!/usr/bin/env bash
# Builds the Rust FFI bridge and drops it next to the Flutter desktop binary.
# Usage: apps/xenterm/tool/build_native.sh
set -euo pipefail

repo="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$repo"

cargo build --release -p xenterm-bridge

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) lib="xenterm_bridge.dll" ;;
  Darwin) lib="libxenterm_bridge.dylib" ;;
  *) lib="libxenterm_bridge.so" ;;
esac

src="$repo/target/release/$lib"
[ -f "$src" ] || { echo "missing $src" >&2; exit 1; }

for cfg in Debug Release; do
  dst="$repo/apps/xenterm/build/windows/x64/runner/$cfg"
  # Windows runner layout.
  if [ -d "$dst" ]; then
    cp -f "$src" "$dst/"
    echo "copied -> $cfg"
  fi
done

if [ "$(uname -s)" = Linux ]; then
  for cfg in debug profile release; do
    dst="$repo/apps/xenterm/build/linux/x64/$cfg/bundle"
    if [ -d "$dst" ]; then
      cp -f "$src" "$dst/"
      echo "copied -> linux/$cfg/bundle"
    fi
  done
fi
