const std = @import("std");
const fs = std.fs;
const File = fs.File;
const Io = std.Io;
const posix = std.posix;
const tih = @import("termios_input_handler.zig");
const Game = @import("game.zig").Game;

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

// \\┃                 ┃     ╶┬╴╭─╴╶┬╴╭─╮╷╭─╮     ┃                 ┃
// \\┃                 ┃      │ ├╴  │ ├┬╯│╰─╮     ┃                 ┃
// \\┃                 ┃      ╵ ╰─╴ ╵ ╵╰╴╵╰─╯     ┃                 ┃

// \\┃                 ┃    ╭─╮╭─╮╷ ╷╭─╮╭─╴╶┬╮    ┃                 ┃
// \\┃                 ┃    ├─╯├─┤│ │╰─╮├╴  ││    ┃                 ┃
// \\┃                 ┃    ╵  ╵ ╵╰─╯╰─╯╰─╴╶┴╯    ┃                 ┃

// \\┃                 ┃╭─╴╭─╮╭┬╮╭─╴  ╭─╮╷ ╷╭─╴╭─╮┃                 ┃
// \\┃                 ┃│╶╮├─┤│││├╴   │ ││╭╯├╴ ├┬╯┃                 ┃
// \\┃                 ┃╰─╯╵ ╵╵ ╵╰─╴  ╰─╯╰╯ ╰─╴╵╰╴┃                 ┃

// \\┃                 ┃  ╭─╮╭─╴╶┬╴╶┬╴╷╭╮╷╭─╴╭─╮  ┃                 ┃
// \\┃                 ┃  ╰─╮├╴  │  │ ││╰┤│╶╮╰─╮  ┃                 ┃
// \\┃                 ┃  ╰─╯╰─╴ ╵  ╵ ╵╵ ╵╰─╯╰─╯  ┃                 ┃

// ╶┬╴╭─╴╶┬╴╭─╮╷╭─╮
//  │ ├╴  │ ├┬╯│╰─╮
//  ╵ ╰─╴ ╵ ╵╰╴╵╰─╯

// ╭─╮╭─╮╷ ╷╭─╮╭─╴╶┬╮
// ├─╯├─┤│ │╰─╮├╴  ││
// ╵  ╵ ╵╰─╯╰─╯╰─╴╶┴╯

// ╭─╴╭─╮╭┬╮╭─╴   ╭─╮╷ ╷╭─╴╭─╮
// │╶╮├─┤│││├╴    │ ││╭╯├╴ ├┬╯
// ╰─╯╵ ╵╵ ╵╰─╴   ╰─╯╰╯ ╰─╴╵╰╴

// ╭─╮╭─╴╶┬╴╶┬╴╷╭╮╷╭─╴╭─╮
// ╰─╮├╴  │  │ ││╰┤│╶╮╰─╮
// ╰─╯╰─╴ ╵  ╵ ╵╵ ╵╰─╯╰─╯

// ╭─╴╭─╮╭╮╷╶┬╴╭─╮╭─╮╷  ╭─╮
// │  │ ││╰┤ │ ├┬╯│ ││  ╰─╮
// ╰─╴╰─╯╵ ╵ ╵ ╵╰╴╰─╯╰─╴╰─╯

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
//\\┃                    ┃      Marathon      ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃      Settings      ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃        Quit        ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┗━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━┛


const MenuState = union(enum) {
    StartMenu: StartScreen,
    SettingsMenu: SettingsScreen,
    InGame,
    PauseMenu: PauseScreen,
    GameOverMenu: GameOverScreen,
    ExitGame,
};

const Position = enum(u8) {
    zero,
    one,
    two,
    three,
};

pub fn MenuScreen() type {
    return struct {
        const Self = @This();

        position: Position,
        max_position: Position,
        zero_str: []const u8, 
        first_str: []const u8, 
        second_str: []const u8, 
        third_str: []const u8,
        banner: []const u8,

        pub fn init(
            max_position: Position,
            zero_str: []const u8, 
            first_str: []const u8, 
            second_str: []const u8, 
            third_str: []const u8,
            banner: []const u8,
        ) Self {
            return .{
                .position = .zero,
                .max_position = max_position,
                .zero_str = zero_str,
                .first_str  = first_str, 
                .second_str = second_str, 
                .third_str = third_str,
                .banner = banner,
            };
        }

        pub fn cycleDown(self: *Self) void {
            var pos = @intFromEnum(self.position);
            const max = @intFromEnum(self.max_position);
            pos = if (pos == max) 0 else (pos + 1) % (max + 1);
            self.position = @enumFromInt(pos);
        }

        pub fn cycleUp(self: *Self) void {
            var pos = @intFromEnum(self.position);
            const max = @intFromEnum(self.max_position);
            pos = if (pos == 0) max else (pos - 1) % (max + 1);
            self.position = @enumFromInt(pos);
        }

        pub fn format(self: Self, writer: *Io.Writer) !void {
            const p_struct = switch (self.position) {
                .zero =>  .{self.banner, "▶", self.zero_str, " ", 
                    self.first_str, " ", self.second_str, " ", self.third_str},
                .one =>   .{self.banner, " ", self.zero_str, "▶", 
                    self.first_str, " ", self.second_str, " ", self.third_str},
                .two =>   .{self.banner, " ", self.zero_str, " ", 
                    self.first_str, "▶", self.second_str, " ", self.third_str},
                .three => .{self.banner, " ", self.zero_str, " ", 
                    self.first_str, " ", self.second_str, "▶", self.third_str},
            };
            try writer.print("\x1B[?25l\x1B[H\x1B[2J" ++
    \\┏━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━┓
    \\┃                    ┃                    ┃                    ┃
    \\┃                    ┃                    ┃                    ┃
    \\┃                 ┏━━━━━━━━━━━━━━━━━━━━━━━━━━┓                 ┃
++ "\n{s}\n" ++
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

const StartScreen = MenuScreen();
const SettingsScreen = MenuScreen();
const PauseScreen = MenuScreen();
const GameOverScreen = MenuScreen();

pub const startScreen = StartScreen.init(Position.two, "Marathon", "Settings", "Quit", "",
\\┃                 ┃     ╶┬╴╭─╴╶┬╴╭─╮╷╭─╮     ┃                 ┃
\\┃                 ┃      │ ├╴  │ ├┬╯│╰─╮     ┃                 ┃
\\┃                 ┃      ╵ ╰─╴ ╵ ╵╰╴╵╰─╯     ┃                 ┃
);
pub const settingsScreen = SettingsScreen.init(Position.two, "Theme", "Controls", "Return", "",
\\┃                 ┃  ╭─╮╭─╴╶┬╴╶┬╴╷╭╮╷╭─╴╭─╮  ┃                 ┃
\\┃                 ┃  ╰─╮├╴  │  │ ││╰┤│╶╮╰─╮  ┃                 ┃
\\┃                 ┃  ╰─╯╰─╴ ╵  ╵ ╵╵ ╵╰─╯╰─╯  ┃                 ┃
);
pub const pauseScreen = PauseScreen.init(Position.three, "Continue", "Settings", "Return", "Quit",
\\┃                 ┃    ╭─╮╭─╮╷ ╷╭─╮╭─╴╶┬╮    ┃                 ┃
\\┃                 ┃    ├─╯├─┤│ │╰─╮├╴  ││    ┃                 ┃
\\┃                 ┃    ╵  ╵ ╵╰─╯╰─╯╰─╴╶┴╯    ┃                 ┃
);
pub const gameOverScreen = GameOverScreen.init(Position.two, "Retry", "Return", "Quit", "", 
\\┃                 ┃╭─╴╭─╮╭┬╮╭─╴  ╭─╮╷ ╷╭─╴╭─╮┃                 ┃
\\┃                 ┃│╶╮├─┤│││├╴   │ ││╭╯├╴ ├┬╯┃                 ┃
\\┃                 ┃╰─╯╵ ╵╵ ╵╰─╴  ╰─╯╰╯ ╰─╴╵╰╴┃                 ┃
);

pub const Menu = struct {
    state: MenuState,

    pub fn init() Menu {
        return .{
            .state = .{ .StartMenu = startScreen },
        };
    }

    pub fn menu_loop(self: *Menu, reader: *Io.Reader, 
        writer: *Io.Writer, imap: tih.InputMapping
    ) !void {
        try writer.print("{f}", .{self});
        try writer.flush();
        const input: tih.UserInput = try tih.InputHandler(reader, imap);

        switch (input) {
            .DownButton => self.cycleDown(),
            .UpButton => self.cycleUp(),
            .PauseButton => {
                self.selected();
            },
            .ExitGameButton => self.state = .ExitGame,
            else => {},
        }
        try writer.print("{f}", .{self});
        try writer.flush();
    }

    fn cycleUp(self: *Menu) void {
        switch (self.state) {
            .StartMenu, .SettingsMenu, .PauseMenu, .GameOverMenu => |*pos| {
                pos.cycleUp();
            },
            else => {},
        }
    }

    fn cycleDown(self: *Menu) void {
        switch (self.state) {
            .StartMenu, .SettingsMenu, .PauseMenu, .GameOverMenu => |*pos| {
                pos.cycleDown();
            },
            else => {}
        }
    }

    fn selected(self: *Menu) void {
        switch (self.state) {
            .StartMenu => |screen| {
                switch (screen.position) {
                    .zero => self.state = .InGame,
                    .one => self.state = .{ .SettingsMenu = settingsScreen},
                    .two => self.state = .ExitGame,
                    .three => unreachable,
                }
            },
            .SettingsMenu => |screen| {
                switch (screen.position) {
                    .zero => {}, //need to implement theme select
                    .one => {}, // need to implement control customization
                    .two => self.state = .{ .StartMenu = startScreen},
                    .three => unreachable,
                }
            },
            .PauseMenu => |screen| {
                switch (screen.position) {
                    .zero => self.state = .InGame,
                    .one => self.state = .{ .SettingsMenu = settingsScreen},
                    .two => self.state = .{ .StartMenu = startScreen},
                    .three => self.state = .ExitGame,
                }
            },
            .GameOverMenu => |screen| {
                switch (screen.position) {
                    .zero => self.state = .InGame,
                    .one => self.state = .{ .StartMenu = startScreen},
                    .two => self.state =  .ExitGame,
                    .three => unreachable,
                }
            },
            else => {},
        }
    }

    pub fn format(self: Menu, writer: *Io.Writer) !void {
        switch (self.state) {
            .StartMenu, .SettingsMenu, .PauseMenu, .GameOverMenu => |screen| try writer.print("{f}", .{screen}),
            else => {},
        }
    }

};


