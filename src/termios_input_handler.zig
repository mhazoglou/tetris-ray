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

const imap: InputMapping = .{
    .left = "\x1B[D",
    .right = "\x1B[C",
    .soft_drop = "\x1B[B",
    .hard_drop = " ",
    .hold = "\x1B[A",
    .rotCW = "x",
    .rotCCW = "z",
    .pause = "\n",
    .exit = "\x1B",
};

pub fn InputHandler(reader: *Io.Reader) !UserInput {

    const str: []u8 = reader.peekGreedy(1) catch |err| switch (err) {
        error.EndOfStream => return .Idle,
        else => return err,
    };
    reader.toss(str.len);

    if (std.mem.eql(u8, str, "\x1B")) {
        return UserInput.ExitGameButton;
    }
    if (std.mem.eql(u8, str, "\x1B[A")) {
        return UserInput.UpButton;
    } 
    if (std.mem.eql(u8, str, "\x1B[B")) {
        return UserInput.DownButton;
    }
    if (std.mem.eql(u8, str, "\x1B[C")) {
        return UserInput.RightButton;
    }
    if (std.mem.eql(u8, str, "\x1B[D")) {
        return UserInput.LeftButton;
    } 
    if (std.mem.eql(u8, str, "x")) {
        return UserInput.RotCWButton;
    }
    if (std.mem.eql(u8, str, "z")) {
        return UserInput.RotCCWButton;
    }
    if (std.mem.eql(u8, str, "\n")) {
        return UserInput.PauseButton;
    }
    if (std.mem.eql(u8, str, "\t")) {
        return UserInput.PauseButton;
    }
    if (std.mem.eql(u8, str, " ")) {
        return UserInput.HardDropButton;
    }
    unreachable;
}

const Button = enum {
    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k,
    l,
    m,
    n,
    o,
    p,
    q,
    r,
    s,
    t,
    u,
    v,
    w,
    x,
    y,
    z,
    @"1",
    @"2",
    @"3",
    @"4",
    @"5",
    @"6",
    @"7",
    @"8",
    @"9",
    @"0",
    @",",
    @".",
    @"/",
    @"<",
    @">",
    @"?",
    @";",
    @"'",
    @":",
    @"\"",
    @"[",
    @"]",
    @"\\",
    @"{",
    @"}",
    @"|",
    @"\x1B[D",
    @"\x1B[C",
    @"\x1B[B",
    @" ",
    @"\x1B[A",
    @"\n",
    @"\x1B",

};
