const std = @import("std");
const builtin = std.builtin;
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

pub const is_posix: bool = switch (builtin.os.tag) {
    .windows, .uefi, .wasi => false,
    else => true,
};

pub fn InputHandler(reader: *Io.Reader, writer: *Io.Writer) !UserInput {

    blk: while (true) {
        const c: u8 = reader.takeByte() catch |err| switch (err) {
            error.EndOfStream => {
                return UserInput.Idle;
            },
            error.ReadFailed => {
                return err;
            },
        };
        if (c == '\n') {
            return UserInput.PauseButton;
        } else if (c == '\t') {
            return UserInput.PauseButton;
        } else if (c == ' ') {
            return UserInput.HardDropButton;
        } else if (c == '\x7F') {
            continue: blk;
        } else if (c == '\x1B') {

            var char: u8 = reader.takeByte() catch |err| switch (err) {
                error.EndOfStream => {
                    return UserInput.ExitGameButton;
                },
                error.ReadFailed => {
                    return err;
                },
            };

            esc: switch (char) {
                '[' => {

                    char = reader.takeByte() catch |err| switch (err) {
                        error.EndOfStream => break: esc,
                        error.ReadFailed => return err,
                    };

                    switch (char) {

                        '3' => {
                            char = reader.takeByte() catch |err| switch (err) {
                                error.EndOfStream => break: esc,
                                error.ReadFailed => return err,
                            };
                            if (char == '~') {
                                continue: blk;
                            } else {
                                break: esc;
                            }
                        },

                        'A' => {
                            // Handle up arrow input
                            return UserInput.RotCWButton;//UpButton;
                        },

                        'B' => {
                            // Handle down arrow input
                            return UserInput.DownButton;
                        },

                        'C' => {
                            // Handle right arrow input
                            return UserInput.RightButton;
                        },

                        'D' => {
                            // Handle left arrow input
                            return UserInput.LeftButton;
                        },

                        'H' => {
                            // Handle Home key
                            continue: blk; 
                        },

                        'F' => {
                            // Handle End key
                            continue: blk;
                        },
                        '5' => continue: esc '~',
                        '6' => continue: esc '~',
                        '~' => break: esc,
                        else => try writer.print(
                            "failed to handle escape [: {c}", .{char}
                        ),
                    }

                    break: esc;

                },

                else => {
                    break: esc;
                },
            }

        }
    }
}
