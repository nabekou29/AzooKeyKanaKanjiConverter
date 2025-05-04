#!/bin/bash
set -e

USE_ZENZAI=0

# 引数の解析
for arg in "$@"; do
  if [ "$arg" = "--zenzai" ]; then
    USE_ZENZAI=1
  fi
done

if [ "$USE_ZENZAI" -eq 1 ]; then
  echo "📦 Building with Zenzai support..."
  swift build -c release -Xcxx -xobjective-c++ --traits Zenzai
else
  echo "📦 Building..."
  # Build
  swift build -c release -Xcxx -xobjective-c++
fi

# Copy Required Resources
sudo cp -R .build/release/llama.framework /usr/local/lib/
# add rpath
install_name_tool -add_rpath /usr/local/lib/ .build/release/CliTool
# Install
sudo cp -f .build/release/CliTool /usr/local/bin/anco
