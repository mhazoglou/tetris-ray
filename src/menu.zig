const std = @import("std");
const fs = std.fs;
const File = fs.File;
const Io = std.Io;
const posix = std.posix;
const tih = @import("termios_input_handler.zig");

const BUFFERSIZE = 4096;

pub fn main() !void {
    const tty_file = try fs.openFileAbsolute("/dev/tty", .{});
    defer tty_file.close();
    const tty_fd = tty_file.handle;

    const old_settings = try posix.tcgetattr(tty_fd);

    // Set blocking 
    var new_settings: posix.termios = old_settings;
    new_settings.lflag.ICANON = false;
    new_settings.lflag.ECHO = false;
    new_settings.cc[6] = 1; //VMIN
    new_settings.cc[5] = 0; //VTIME
    new_settings.lflag.ECHOE = false;

    _ = try posix.tcsetattr(tty_fd, posix.TCSA.NOW, new_settings);

    var stdin_buffer: [BUFFERSIZE]u8 = undefined;
    var stdout_buffer: [BUFFERSIZE]u8 = undefined;

    var stdin_reader = File.stdin().reader(&stdin_buffer);
    const reader = &stdin_reader.interface;
    var stdout_writer = File.stdout().writer(&stdout_buffer);
    const writer = &stdout_writer.interface;

    var menu = Menu.init();
    try menu.menu_loop(reader, writer);
    _ = try posix.tcsetattr(tty_fd, posix.TCSA.NOW, old_settings);
}

// ╶┬╴╭─╴╶┬╴╭─╮╷╭─╮
//  │ ├╴  │ ├┬╯│╰─╮
//  ╵ ╰─╴ ╵ ╵╰╴╵╰─╯

// ╭─╮╭─╮╷ ╷╭─╮╭─╴╶┬╮
// ├─╯├─┤│ │╰─╮├╴  ││
// ╵  ╵ ╵╰─╯╰─╯╰─╴╶┴╯

//\\┏━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━┓
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                 ┏━━━━━━━━━━━━━━━━━━━━━━━━━━┓                 ┃
//\\┃                 ┃     ╶┬╴╭─╴╶┬╴╭─╮╷╭─╮     ┃                 ┃
//\\┃                 ┃      │ ├╴  │ ├┬╯│╰─╮     ┃                 ┃
//\\┃                 ┃      ╵ ╰─╴ ╵ ╵╰╴╵╰─╯     ┃                 ┃
//\\┃                 ┗━━━━━━━━┓        ┏━━━━━━━━┛                 ┃
//\\┃                    ┃     ┃        ┃     ┃                    ┃
//\\┃                    ┃     ┃        ┃     ┃                    ┃
//\\┃                    ┃     ┃        ┃     ┃                    ┃
//\\┃                    ┃     ┗━━━━━━━━┛     ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃    {} Marathon      ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃    {} Settings      ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃    {}   Quit        ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┗━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━┛

//\\┏━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━┓
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                 ┏━━━━━━━━━━━━━━━━━━━━━━━━━━┓                 ┃
//\\┃                 ┃     ╶┬╴╭─╴╶┬╴╭─╮╷╭─╮     ┃                 ┃
//\\┃                 ┃      │ ├╴  │ ├┬╯│╰─╮     ┃                 ┃
//\\┃                 ┃      ╵ ╰─╴ ╵ ╵╰╴╵╰─╯     ┃                 ┃
//\\┃                 ┗━━━━━━━━┓        ┏━━━━━━━━┛                 ┃
//\\┃                    ┃     ┃        ┃     ┃                    ┃
//\\┃                    ┃     ┃        ┃     ┃                    ┃
//\\┃                    ┃     ┃        ┃     ┃                    ┃
//\\┃                    ┃     ┗━━━━━━━━┛     ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃      Settings      ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃      Theme A       ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃      Default       ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┗━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━┛


// 
// pub const Config = struct {};
// 

const StartMenuPosition = enum{
    Marathon,
    Settings,
    Quit,

    pub fn cycleDown(self: *StartMenuPosition) void {
            switch (self) {
            .Marathon => self.* = .Settings,
            .Settings => self.* = .Quit,
            .Quit =>     self.* = .Marathon,
        }
    }

    pub fn cycleUp(self: *StartMenuPosition) void {
        switch (self) {
            .Marathon => self.* = .Quit,
            .Settings => self.* = .Marathon,
            .Quit =>     self.* = .Settings,
        }
    }
};

const SettingsMenuPosition = enum{
    Theme,
    Controls,
    Return,

    pub fn cycleDown(self: *SettingsMenuPosition) void {
            switch (self) {
            .Theme => self.* = .Controls,
            .Controls => self.* = .Return,
            .Return => self.* = .Theme,
        }
    }

    pub fn cycleUp(self: *SettingsMenuPosition) void {
        switch (self) {
            .Theme => self.* = .Return,
            .Controls => self.* = .Theme,
            .Return => self.* = .Controls,
        }
    }
};

const PauseMenuPosition = enum{
    Continue,
    Settings,
    Return,
    Quit,

    pub fn cycleDown(self: *PauseMenuPosition) void {
            switch (self) {
            .Continue => self.* = .Settings,
            .Settings => self.* = .Return,
            .Return => self.* = .Quit,
            .Quit =>     self.* = .Continue,
        }
    }

    pub fn cycleUp(self: *PauseMenuPosition) void {
        switch (self) {
            .Continue => self.* = .Quit, 
            .Settings => self.* = .Continue,
            .Return => self.* = .Settings,
            .Quit =>     self.* = .Return,
        }
    }
};

const MenuState = union(enum) {
    StartMenu: StartMenuPosition,
    SettingsMenu: SettingsMenuPosition,
    PauseMenu: PauseMenuPosition,
};

const Position = enum {
    zero,
    one,
    two,
    three,
};

pub fn MenuScreen(
    zero_str: []const u8, 
    first_str: []const u8, 
    second_str: []const u8, 
    third_str: []const u8
) type {
    return struct {
        const Self = @This();

        position: Position,
        max_position: Position,
        running: bool,

        pub fn init(max_position: Position) Self {
            return .{
                .position = .zero,
                .max_position = max_position,
                .running = true
            };
        }

        pub fn cycleDown(self: *Self) void {
            switch (*self.position) {
                .zero => self.position.* = .one,
                .one => self.position.* = .two,
                .two => self.position.* = .three,
                .three => self.position.* = .zero,
            }
        }

        pub fn cycleUp(self: *PauseMenuPosition) void {
            switch (*self.position) {
                .zero => self.position.* = .three,
                .one => self.position.* = .zero,
                .two => self.position.* = .one,
                .three => self.position.* = .two,
            }
        }

        pub fn format(self: Self, writer: *Io.Writer) !void {
            const p_struct = switch (self.position) {
                .zero => .{"▶", zero_str, " ", first_str, " ", second_str, " ", third_str},
                .one => .{" ", zero_str, "▶", first_str, " ", second_str, " ", third_str},
                .two => .{" ", zero_str, " ", first_str, "▶", second_str, " ", third_str},
                .three => .{" ", zero_str, " ", first_str, " ", second_str, "▶", third_str},
            };
            try writer.print("\x1B[?25l\x1B[H\x1B[2J" ++
    \\┏━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━┓
    \\┃                    ┃                    ┃                    ┃
    \\┃                    ┃                    ┃                    ┃
    \\┃                 ┏━━━━━━━━━━━━━━━━━━━━━━━━━━┓                 ┃
    \\┃                 ┃     ╶┬╴╭─╴╶┬╴╭─╮╷╭─╮     ┃                 ┃
    \\┃                 ┃      │ ├╴  │ ├┬╯│╰─╮     ┃                 ┃
    \\┃                 ┃      ╵ ╰─╴ ╵ ╵╰╴╵╰─╯     ┃                 ┃
    \\┃                 ┗━━━━━━━━┓        ┏━━━━━━━━┛                 ┃
    \\┃                    ┃     ┃        ┃     ┃                    ┃
    \\┃                    ┃     ┃        ┃     ┃                    ┃
    \\┃                    ┃     ┃        ┃     ┃                    ┃
    \\┃                    ┃     ┗━━━━━━━━┛     ┃                    ┃
    \\┃                    ┃                    ┃                    ┃
    \\┃                    ┃    {s} {s: <14}┃                    ┃
    \\┃                    ┃                    ┃                    ┃
    \\┃                    ┃    {s} {s: <14}┃                    ┃
    \\┃                    ┃                    ┃                    ┃
    \\┃                    ┃    {s} {s: <14}┃                    ┃
    \\┃                    ┃                    ┃                    ┃
    \\┃                    ┃    {s} {s: <14}┃                    ┃
    \\┃                    ┃                    ┃                    ┃
    \\┗━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━┛
            , p_struct);
        }

    };
}
pub const Menu = struct {
    state: MenuState,
    running: bool,

    pub fn init() Menu {
        return .{
            .state = .{ .StartMenu = .Marathon },
            .running = true,
        };
    }

    pub fn menu_loop(self: *Menu, reader: *Io.Reader, writer: *Io.Writer) !void {
        try writer.print("{f}", .{self});
        try writer.flush();
        while (self.running) {
            const input: tih.UserInput = try tih.InputHandler(reader);

            switch (input) {
                .DownButton => self.cycleDown(),
                .UpButton => self.cycleUp(),
                .PauseButton => self.selected(),
                .ExitGameButton => self.running = false,
                else => {},
            }
            try writer.print("{f}", .{self});
            try writer.flush();
        }
    }

    fn cycleUp(self: *Menu) void {
        switch (*self.state) {
            _ => |pos| {
                pos.cycleUp();
            },
        }
    }

    fn cycleDown(self: *Menu) void {
        switch (*self.state) {
            _ => |pos| {
                pos.cycleDown();
            },
        }
    }

    fn selected(self: *Menu) void {
        switch (self.position) {
            .Marathon => {},
            .Settings => self.state = .SettingsMenu,
            .Quit =>     self.running = false,
        }
    }

    pub fn format(self: Menu, writer: *Io.Writer) !void {
        const p_struct = switch (self.position) {
            .Marathon => .{"▶", " ", " "},
            .Settings => .{" ", "▶", " "},
            .Quit =>     .{" ", " ", "▶"},
        };
        try writer.print("\x1B[?25l\x1B[H\x1B[2J" ++
\\┏━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━┓
\\┃                    ┃                    ┃                    ┃
\\┃                    ┃                    ┃                    ┃
\\┃                    ┃                    ┃                    ┃
\\┃                 ┏━━━━━━━━━━━━━━━━━━━━━━━━━━┓                 ┃
\\┃                 ┃     ╶┬╴╭─╴╶┬╴╭─╮╷╭─╮     ┃                 ┃
\\┃                 ┃      │ ├╴  │ ├┬╯│╰─╮     ┃                 ┃
\\┃                 ┃      ╵ ╰─╴ ╵ ╵╰╴╵╰─╯     ┃                 ┃
\\┃                 ┗━━━━━━━━┓        ┏━━━━━━━━┛                 ┃
\\┃                    ┃     ┃        ┃     ┃                    ┃
\\┃                    ┃     ┃        ┃     ┃                    ┃
\\┃                    ┃     ┃        ┃     ┃                    ┃
\\┃                    ┃     ┗━━━━━━━━┛     ┃                    ┃
\\┃                    ┃                    ┃                    ┃
\\┃                    ┃    {s} Marathon      ┃                    ┃
\\┃                    ┃                    ┃                    ┃
\\┃                    ┃    {s} Settings      ┃                    ┃
\\┃                    ┃                    ┃                    ┃
\\┃                    ┃    {s}   Quit        ┃                    ┃
\\┃                    ┃                    ┃                    ┃
\\┃                    ┃                    ┃                    ┃
\\┗━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━┛
        , p_struct);
    }

};


