#!/bin/bash

PROGRAM_NAME="./zig-out/bin/tetris"
# Find the absolute path of the folder where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change the working directory to that folder
cd "$SCRIPT_DIR" || exit 1
"$PROGRAM_NAME"
