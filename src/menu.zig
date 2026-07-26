const std = @import("std");
const Game = @import("game.zig").Game;
const EXITTIME = @import("game.zig").EXITTIME;
const c = @import("c");

const DEPTH = 7;

const MenuState = union(enum) {
    StartMenu: StartScreen,
    SettingsMenu: SettingsScreen,
    MusicMenu: MusicScreen,
    ThemeSelectMenu: ThemeSelectScreen,
    ControlsMenu: ControlsScreen,
    InGame,
    PauseMenu: PauseScreen, 
    GameOverMenu: GameOverScreen,
    HighScoreMenu: HighScoreScreen,
    ToggleGhost,
    ChangeMasterVolume: f32,
    ChangeMusicVolume: f32,
    ChangeSFXVolume: f32,
    RemappingInput: [:0]const u8,
    ChangeMusic: [:0]const u8,
    EnterName: usize,
    ExitGame,
};

const Position = enum(u8) {
    zero,
    one,
    two,
    three,
    four,
};

pub fn MenuScreen() type {
    return struct {
        const Self = @This();

        position_y: Position,
        position_x: Position,
        max_position_y: Position,
        max_position_x: Position,
        arr_str: [5][5][:0]const u8, 
        banner: [:0]const u8,

        pub fn init(
            max_position_y: Position,
            max_position_x: Position,
            arr_str: [5][5][:0]const u8, 
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

    };
}

const StartScreen = MenuScreen();
const SettingsScreen = MenuScreen();
const PauseScreen = MenuScreen();
const GameOverScreen = MenuScreen();
const ControlsScreen = MenuScreen();
const MusicScreen = MenuScreen();
const ThemeSelectScreen = MenuScreen();
const HighScoreScreen = MenuScreen();

pub const startScreen = StartScreen.init(.three, .zero, 
    .{ 
        .{"Marathon"} ++ .{""} ** 4, 
        .{"Settings"} ++ .{""} ** 4, 
        .{"High Score"} ++ .{""} ** 4,
        .{"Quit"} ++ .{""} ** 4,
        .{""} ** 5,
    }, 
    "TETRIS"
);
pub const settingsScreen = SettingsScreen.init(.three, .zero, 
    .{ 
        .{"Music"} ++ .{""} ** 4, 
        .{"Controls"} ++ .{""} ** 4, 
        .{"Toggle Ghost"} ++ .{""} ** 4,
        .{"Return"} ++ .{""} ** 4,
        .{""} ** 5,
    }, 
    "SETTINGS"
);
pub const pauseScreen = PauseScreen.init(.three, .zero, 
    .{ 
        .{"Continue"} ++ .{""} ** 4,
        .{"Settings"} ++ .{""} ** 4,
        .{"Return"} ++ .{""} ** 4, 
        .{"Quit"} ++ .{""} ** 4,
        .{""} ** 5,
    }, 
    "PAUSED"
);
pub const gameOverScreen = GameOverScreen.init(.two, .zero, 
    .{ 
        .{"Retry"} ++ .{""} ** 4, 
        .{"Return"} ++ .{""} ** 4, 
        .{"Quit"} ++ .{""} ** 4,
        .{""} ** 5,
        .{""} ** 5,
    }, 
    "GAME OVER"
);
pub const controlsScreen = ControlsScreen.init(.four, .one, 
    .{
        .{"left: ", "right: "} ++ .{""} ** 3, 
        .{"soft drop: ", "hard drop: "} ++ .{""} ** 3,
        .{"rotate CW: ", "rotate CCW: "} ++ .{""} ** 3, 
        .{"pause: ", "exit: "} ++ .{""} ** 3, 
        .{"Reset Default", "Return"} ++ .{""} ** 3, 
    }, 
    "Controls"
);
pub const musicScreen = MusicScreen.init(.four, .zero,
    .{
        .{"Theme Select"} ++ .{""} ** 4,
        .{"Master Volume: "} ++ .{""} ** 4,
        .{"Music Volume: "} ++ .{""} ** 4,
        .{"Sound Effects Volume: "} ++ .{""} ** 4,
        .{"Return"} ++ .{""} ** 4, 
    },
    "Music"
);
pub const themeSelectScreen = ThemeSelectScreen.init(.three, .zero, 
    .{
        .{"Theme A"} ++ .{""} ** 4, 
        .{"Theme B"} ++ .{""} ** 4, 
        .{"Theme C"} ++ .{""} ** 4, 
        .{"Return"} ++ .{""} ** 4, 
        .{""} ** 5,
    }, 
    "Theme Select"
);
pub const highScoreScreen = HighScoreScreen.init(.four, .one,
    .{
        .{"1st: ", "6th: "} ++ .{""} ** 3,
        .{"2nd: ", "7th: "} ++ .{""} ** 3,
        .{"3rd: ", "8th: "} ++ .{""} ** 3,
        .{"4th: ", "9th: "} ++ .{""} ** 3,
        .{"5th: ", "10th: "} ++ .{""} ** 3,
    },
    "High Score"
);

pub const Menu = struct {
    state_idx: usize,
    state_hist: [DEPTH]MenuState,
    timer_exit: f64,

    pub fn init() Menu {
        const start_menu: MenuState = .{ .StartMenu = startScreen };
        return .{
            .state_idx = 0,
            .state_hist = .{start_menu} ** DEPTH,
            .timer_exit = 0.0,
        };
    }

    pub fn menu_loop(self: *Menu, game: Game) void {
        if (c.IsKeyPressed(c.KEY_DOWN)) {
            self.cycleDown();
        }
        if (c.IsKeyPressed(c.KEY_UP)) {
            self.cycleUp();
        }
        if (c.IsKeyPressed(game.settings.imap.right)) {
            self.cycleRight();
        }
        if (c.IsKeyPressed(game.settings.imap.left)) {
            self.cycleLeft();
        }
        if (c.IsKeyPressed(c.KEY_ENTER)) {
            self.selected();
        }
        const exit_elapsed = self.timer_exit >= EXITTIME;
        if (c.IsKeyUp(game.settings.imap.exit)) {
            self.timer_exit = 0.0;
        } else {
            self.timer_exit += c.GetFrameTime();
            if (exit_elapsed) {
                self.changeState(.ExitGame);
            }
        }
    }

    pub fn cycleUp(self: *Menu) void {
        const idx = self.state_idx;
        switch (self.state_hist[idx]) {
            .StartMenu, .SettingsMenu, .PauseMenu, .GameOverMenu, 
            .ControlsMenu, .MusicMenu, .ThemeSelectMenu => |*pos| {
                pos.cycleUp();
            },
            else => {},
        }
    }

    pub fn cycleDown(self: *Menu) void {
        const idx = self.state_idx;
        switch (self.state_hist[idx]) {
            .StartMenu, .SettingsMenu, .PauseMenu, .GameOverMenu, 
            .ControlsMenu, .MusicMenu, .ThemeSelectMenu => |*pos| {
                pos.cycleDown();
            },
            else => {}
        }
    }

    pub fn cycleLeft(self: *Menu) void {
        const idx = self.state_idx;
        switch (self.state_hist[idx]) {
            .StartMenu, .SettingsMenu, .PauseMenu, .GameOverMenu, 
            .ControlsMenu, .ThemeSelectMenu => |*pos| {
                pos.cycleLeft();
            },
            .MusicMenu => |screen| {
                switch (screen.position_y) {
                    .one => self.push(.{ .ChangeMasterVolume = -0.05 }),
                    .two => self.push(.{ .ChangeMusicVolume = -0.05 }),
                    .three => self.push(.{ .ChangeSFXVolume = -0.05 }),
                    else => {},
                }
            },
            else => {},
        }
    }

    pub fn cycleRight(self: *Menu) void {
        const idx = self.state_idx;
        switch (self.state_hist[idx]) {
            .StartMenu, .SettingsMenu, .PauseMenu, .GameOverMenu, 
            .ControlsMenu, .ThemeSelectMenu => |*pos| {
                pos.cycleRight();
            },
            .MusicMenu => |screen| {
                switch (screen.position_y) {
                    .one => self.push(.{ .ChangeMasterVolume = 0.05 }),
                    .two => self.push(.{ .ChangeMusicVolume = 0.05 }),
                    .three => self.push(.{ .ChangeSFXVolume = 0.05 }),
                    else => {},
                }
            },
            else => {}
        }
    }

    pub fn selected(self: *Menu) void {
        const idx = self.state_idx;
        switch (self.state_hist[idx]) {
            .StartMenu => |screen| {
                switch (screen.position_y) {
                    .zero => self.push(.InGame),
                    .one => self.push(
                        .{ .SettingsMenu = settingsScreen }
                    ),
                    .two => self.push(
                        .{ .HighScoreMenu = highScoreScreen }
                    ),
                    .three => self.changeState(.ExitGame),
                    else => unreachable,
                }
            },
            .SettingsMenu => |screen| {
                switch (screen.position_y) {
                    .zero => self.push(.{ .MusicMenu = musicScreen }),
                    .one => self.push(.{ .ControlsMenu = controlsScreen }),
                    .two => self.push(.ToggleGhost),
                    .three => self.back(),
                    else => unreachable,
                }
            },
            .HighScoreMenu => |screen| {
                _ = screen;
                self.back();
            },
            .PauseMenu => |screen| {
                switch (screen.position_y) {
                    .zero => self.back(),
                    .one => self.push(.{ .SettingsMenu = settingsScreen}),
                    .two => self.backToStart(),
                    .three => self.changeState(.ExitGame),
                    .four => unreachable,
                }
            },
            .GameOverMenu => |screen| {
                switch (screen.position_y) {
                    .zero => self.back(),
                    .one => self.backToStart(),
                    .two => self.changeState(.ExitGame),
                    else => unreachable,
                }
            },
            .ControlsMenu => |screen| {
                // brittle to changes because of hardcoded positions
                // need to refactor in the future
                const y = @intFromEnum(screen.position_y);
                const x = @intFromEnum(screen.position_x);
                if ((y == 4) and (x == 1)) {
                    self.back();
                } else if ((y == 4) and (x == 0)) {
                    self.push(.{ .RemappingInput = "" });
                } else {
                    self.push(.{ .RemappingInput = screen.arr_str[y][x]});
                }
            },
            .MusicMenu => |screen| {
                switch (screen.position_y) {
                    .zero => self.push(
                        .{ .ThemeSelectMenu = themeSelectScreen }
                    ),
                    .four => self.back(),
                    else => {},
                }
            },
            .ThemeSelectMenu => |screen| {
                switch (screen.position_y) {
                    .zero => self.push(
                        .{ .ChangeMusic = "resources/theme_A.mp3" }
                    ),
                    .one => self.push(
                        .{ .ChangeMusic = "resources/theme_B.mp3" }
                    ),
                    .two => self.push(
                        .{ .ChangeMusic = "resources/theme_C.mp3" }
                    ),
                    .three => self.back(),
                    .four => unreachable,
                }
            },
            else => {},
        }
    }

    pub fn push(self: *Menu, state: MenuState) void {
        const idx = self.state_idx;
        self.state_idx += 1;
        self.state_hist[idx + 1] = state;
    }

    pub fn back(self: *Menu) void {
        self.state_idx -|= 1;
    }

    pub fn backToStart(self: *Menu) void {
        self.state_idx = 0;
    }

    pub fn changeState(self: *Menu, state: MenuState) void {
        const idx = self.state_idx;
        self.state_hist[idx] = state;
    }

    pub fn getState(self: Menu) MenuState {
        const idx = self.state_idx;
        return self.state_hist[idx];
    }

};


