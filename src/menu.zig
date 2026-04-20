const std = @import("std");
const c = @import("c.zig").c;

const MenuState = union(enum) {
    StartMenu: StartScreen,
    SettingsMenu: SettingsScreen,
    MusicMenu: MusicScreen,
    ControlsMenu: ControlsScreen,
    InGame,
    PauseMenu: PauseScreen,
    GameOverMenu: GameOverScreen,
    RemappingInput: [:0]const u8,
    ChangeMusic: [:0]const u8,
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

        position_y: Position,
        position_x: Position,
        max_position_y: Position,
        max_position_x: Position,
        arr_str: [4][4][:0]const u8, 
        banner: [:0]const u8,

        pub fn init(
            max_position_y: Position,
            max_position_x: Position,
            arr_str: [4][4][:0]const u8, 
            banner: [:0]const u8,
        ) Self {
            return .{
                .position_y = .zero,
                .position_x = .zero,
                .max_position_y = max_position_y,
                .max_position_x = max_position_x,
                .arr_str = arr_str,
                .banner = banner,
            };
        }

        pub fn cycleDown(self: *Self) void {
            var pos = @intFromEnum(self.position_y);
            const max = @intFromEnum(self.max_position_y);
            pos = if (pos == max) 0 else (pos + 1) % (max + 1);
            self.position_y = @enumFromInt(pos);
        }

        pub fn cycleUp(self: *Self) void {
            var pos = @intFromEnum(self.position_y);
            const max = @intFromEnum(self.max_position_y);
            pos = if (pos == 0) max else (pos - 1) % (max + 1);
            self.position_y = @enumFromInt(pos);
        }

        pub fn cycleRight(self: *Self) void {
            var pos = @intFromEnum(self.position_x);
            const max = @intFromEnum(self.max_position_x);
            pos = if (pos == max) 0 else (pos + 1) % (max + 1);
            self.position_x = @enumFromInt(pos);
        }

        pub fn cycleLeft(self: *Self) void {
            var pos = @intFromEnum(self.position_x);
            const max = @intFromEnum(self.max_position_x);
            pos = if (pos == 0) max else (pos - 1) % (max + 1);
            self.position_x = @enumFromInt(pos);
        }

        // "▶"

    };
}

const StartScreen = MenuScreen();
const SettingsScreen = MenuScreen();
const PauseScreen = MenuScreen();
const GameOverScreen = MenuScreen();
const ControlsScreen = MenuScreen();
const MusicScreen = MenuScreen();

pub const startScreen = StartScreen.init(.two, .zero, 
    .{ 
        .{"Marathon"} ++ .{""} ** 3, 
        .{"Settings"} ++ .{""} ** 3, 
        .{"Quit"} ++ .{""} ** 3,
        .{""} ** 4
    }, 
    "TETRIS"
);
pub const settingsScreen = SettingsScreen.init(.two, .zero, 
    .{ 
        .{"Theme"} ++ .{""} ** 3, 
        .{"Controls"} ++ .{""} ** 3, 
        .{"Return"} ++ .{""} ** 3,
        .{""} ** 4
    }, 
    "SETTINGS"
);
pub const pauseScreen = PauseScreen.init(.three, .zero, 
    .{ 
        .{"Continue"} ++ .{""} ** 3,
        .{"Settings"} ++ .{""} ** 3,
        .{"Return"} ++ .{""} ** 3, 
        .{"Quit"} ++ .{""} ** 3
    }, 
    "PAUSED"
);
pub const gameOverScreen = GameOverScreen.init(.two, .zero, 
    .{ 
        .{"Retry"} ++ .{""} ** 3, 
        .{"Return"} ++ .{""} ** 3, 
        .{"Quit"} ++ .{""} ** 3,
        .{""} ** 4
    }, 
    "GAME OVER"
);
pub const controlsScreen = ControlsScreen.init(.two, .two, 
    .{
        .{"left: ", "right: ", "soft drop: "} ++ .{""}, 
        .{"hard drop: ", "rotate CW: ", "rotate CCW: "} ++ .{""}, 
        .{"pause: ", "Reset Default", "Return"} ++ .{""}, 
        .{""} ** 4, 
    }, 
    "Controls"
);
pub const musicScreen = MusicScreen.init(.three, .one, 
    .{
        .{"Theme A"} ++ .{""} ** 3, 
        .{"Theme B"} ++ .{""} ** 3, 
        .{"Theme C"} ++ .{""} ** 3, 
        .{"Return"} ++ .{""} ** 3, 
    }, 
    "Theme Select"
);

pub const Menu = struct {
    state: MenuState,
    settings_return: MenuState,

    pub fn init() Menu {
        return .{
            .state = .{ .StartMenu = startScreen },
            .settings_return = .{ .StartMenu = startScreen },
        };
    }

    pub fn menu_loop(self: *Menu) void {
        if (c.IsKeyPressed(c.KEY_DOWN)) {
            self.cycleDown();
        }
        if (c.IsKeyPressed(c.KEY_UP)) {
            self.cycleUp();
        }
        if (c.IsKeyPressed(c.KEY_RIGHT)) {
            self.cycleRight();
        }
        if (c.IsKeyPressed(c.KEY_LEFT)) {
            self.cycleLeft();
        }
        if (c.IsKeyPressed(c.KEY_ENTER)) {
            self.selected();
        }
        if (c.IsKeyPressed(c.KEY_ESCAPE)) {
            self.state = .ExitGame;
        }
    }

    pub fn cycleUp(self: *Menu) void {
        switch (self.state) {
            .StartMenu, .SettingsMenu, .PauseMenu, .GameOverMenu, .ControlsMenu, .MusicMenu => |*pos| {
                pos.cycleUp();
            },
            else => {},
        }
    }

    pub fn cycleDown(self: *Menu) void {
        switch (self.state) {
            .StartMenu, .SettingsMenu, .PauseMenu, .GameOverMenu, .ControlsMenu, .MusicMenu => |*pos| {
                pos.cycleDown();
            },
            else => {}
        }
    }

    pub fn cycleLeft(self: *Menu) void {
        switch (self.state) {
            .StartMenu, .SettingsMenu, .PauseMenu, .GameOverMenu, .ControlsMenu, .MusicMenu => |*pos| {
                pos.cycleLeft();
            },
            else => {},
        }
    }

    pub fn cycleRight(self: *Menu) void {
        switch (self.state) {
            .StartMenu, .SettingsMenu, .PauseMenu, .GameOverMenu, .ControlsMenu, .MusicMenu => |*pos| {
                pos.cycleRight();
            },
            else => {}
        }
    }

    pub fn selected(self: *Menu) void {
        const state = self.state;
        switch (state) {
            .StartMenu => |screen| {
                switch (screen.position_y) {
                    .zero => self.state = .InGame,
                    .one => {
                        self.state = .{ .SettingsMenu = settingsScreen};
                        self.settings_return = .{ .StartMenu = startScreen};
                    },
                    .two => self.state = .ExitGame,
                    .three => unreachable,
                }
            },
            .SettingsMenu => |screen| {
                switch (screen.position_y) {
                    .zero => self.state = .{ .MusicMenu = musicScreen },
                    .one => self.state = .{ .ControlsMenu = controlsScreen },
                    .two => self.state = self.settings_return,
                    .three => unreachable,
                }
            },
            .PauseMenu => |screen| {
                switch (screen.position_y) {
                    .zero => self.state = .InGame,
                    .one => {
                        self.state = .{ .SettingsMenu = settingsScreen};
                        self.settings_return = .{ .PauseMenu = pauseScreen};
                    },
                    .two => self.state = .{ .StartMenu = startScreen},
                    .three => self.state = .ExitGame,
                }
            },
            .GameOverMenu => |screen| {
                switch (screen.position_y) {
                    .zero => self.state = .InGame,
                    .one => self.state = .{ .StartMenu = startScreen},
                    .two => self.state =  .ExitGame,
                    .three => unreachable,
                }
            },
            .ControlsMenu => |screen| {
                const y = @intFromEnum(screen.position_y);
                const x = @intFromEnum(screen.position_x);
                if ((y == 2) and (x == 2)) {
                    self.state = .{ .SettingsMenu = settingsScreen};
                } else if ((y == 2) and (x == 1)) {
                    self.state = .{ .RemappingInput = "" };
                } else {
                    self.state = .{ .RemappingInput = screen.arr_str[y][x]};
                }
            },
            .MusicMenu => |screen| {
                switch (screen.position_y) {
                    .zero => self.state = .{ .ChangeMusic = "resources/theme_A.mp3" },
                    .one => self.state = .{ .ChangeMusic = "resources/theme_B.mp3" },
                    .two => self.state = .{ .ChangeMusic = "resources/theme_C.mp3" },
                    .three => self.state = .{ .SettingsMenu = settingsScreen },
                }
            },
            else => {},
        }
    }

};


