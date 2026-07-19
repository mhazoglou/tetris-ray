Made with Zig 0.16, should compile with 0.16 or future compatible version.

When the project is downloaded it can be run with the command:

zig build run

from the root of the directory. If a release version is desired
the following command can be run:

zig build -Doptimize=ReleaseFast

the output file will be ./zig-out/bin/tetris

currently missing features that may come in the future as I find the time
- Limit to lock delay reset upon rotation (15 rotations currently infinite)
- Scoring system: difficult line clears
- Volume controls for master and sound effects
- Nice monospaced font that isn't the default from Raylib 
  (This is a maybe the default font is kind of nice)
