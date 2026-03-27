const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;
const posix = std.posix;
const fs = std.fs;
const File = fs.File;

pub const UserInput = enum{
    Idle,
    LeftButton,
    RightButton,
    DownButton,
    UpButton,
    RotCWButton,
    RotCCWButton,
    HardDropButton,
    PauseButton,
    ExitGameButton,
};

pub const is_posix: bool = switch (builtin.os.tag)  {
    .windows, .uefi, .wasi => false,
    else => true,
};

comptime{
    if (!is_posix) {
        @compileError(
            "Only Posix compliant operating systems are supported. :("
        );
    }
}
pub const InputMapping = struct {
    left: []u8,
    right: []u8,
    soft_drop: []u8,
    hard_drop: []u8,
    hold: []u8,
    rotCW: []u8,
    rotCCW: []u8,
    pause: []u8,
    exit: []u8,
};

pub fn InputHandler(reader: *Io.Reader) !UserInput {

    // while (true) {
        // var buffer: [1024]u8 = .{0} ** 1024;
        // const length = try reader.readSliceShort(&buffer);
        // // if (length == 0) return UserInput.Idle;
        // const str: []u8 = buffer[0..length];
        
        const char: u8 = reader.takeByte() catch |err| switch (err) {
            error.EndOfStream => return .Idle,
            else => return err,
        };
        switch (char) {
            '\n' => return .PauseButton,
            '\t' => return .PauseButton,
            ' ' => return .HardDropButton,
            'x' => return .RotCWButton,
            'z' => return .RotCCWButton,
            '\x1B' => {
                const next_char = reader.takeByte() catch |err| switch (err) {
                    error.EndOfStream => return .ExitGameButton,

                    else => return err,
                };

                switch (next_char) {
                    '[' => {
                        const nn_char = try reader.takeByte();
                        switch (nn_char) {
                            'A' => return .UpButton,
                            'B' => return .DownButton,
                            'C' => return .RightButton,
                            'D' => return .LeftButton,
                            else => return .Idle,
                        }
                    },
                    'O' => return .Idle,
                    else => return .Idle,
                }

            },
            else => return .Idle,
        }
    // }
}
