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
    down: []u8,
    hard_drop: []u8,
    up: []u8,
    rotCW: []u8,
    rotCCW: []u8,
    pause: []u8,
    exit: []u8,
};

const default_imap: InputMapping = .{
    .left = "\x1B[D",
    .right = "\x1B[C",
    .down = "\x1B[B",
    .hard_drop = " ",
    .up = "\x1B[A",
    .rotCW = "x",
    .rotCCW = "z",
    .pause = "\n",
    .exit = "\x1B",
};

pub fn InputHandler(reader: *Io.Reader, imap: InputMapping) !UserInput {

    const str: []u8 = reader.peekGreedy(1) catch |err| switch (err) {
        error.EndOfStream => return .Idle,
        else => return err,
    };
    reader.toss(str.len);

    if (std.mem.eql(u8, str, imap.exit)) {
        return .ExitGameButton;
    }
    if (std.mem.eql(u8, str, imap.up)) {
        return .UpButton;
    } 
    if (std.mem.eql(u8, str, imap.down)) {
        return .DownButton;
    }
    if (std.mem.eql(u8, str, imap.right)) {
        return .RightButton;
    }
    if (std.mem.eql(u8, str, imap.left)) {
        return .LeftButton;
    } 
    if (std.mem.eql(u8, str, imap.rotCW)) {
        return .RotCWButton;
    }
    if (std.mem.eql(u8, str, imap.rotCCW)) {
        return .RotCCWButton;
    }
    if (std.mem.eql(u8, str, imap.pause)) {
        return .PauseButton;
    }
    if (std.mem.eql(u8, str, imap.hard_drop)) {
        return .HardDropButton;
    }
    return .Idle;
}
