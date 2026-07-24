const std = @import("std");
const c = @import("c");
const Tetramino = @import("tetramino.zig").Tetramino;
const menu = @import("menu.zig");

var font: c.Font = undefined;
var screenWidth: u16 = 800;
var screenHeight: u16 = 450;
var item_font_size: u16 = 16;
var banner_font_size: u16 = 60;
var spacing: u16 = 4;
var squareSize: u16 = 20;
var enter_name: [NAMELENGTH:0]u8 = ("_" ** NAMELENGTH).*;

const MINWIDTH = 400;
const MINHEIGHT = 225;
const FRAMERATE = 60;

const MAXROWS = 22;
const MAXCOLS = 10;
const LOCKDELAY = 0.5; // 0.5 s or 500 ms
const DAS = 10.0 / @as(comptime_float, @floatFromInt(FRAMERATE)); // 10 frames of delay auto shift
const DASART = 2.0 / @as(comptime_float, @floatFromInt(FRAMERATE)); // 2 frames auto repeat rate
const DART = 3.0 / @as(comptime_float, @floatFromInt(FRAMERATE)); // 3 frames drop auto repeat rate
pub const EXITTIME = 3.0;
const LINESFORLEVELUP = 10;
const NAMELENGTH = 3;

pub const State = Matrix(MAXROWS, MAXCOLS);

pub const Game = struct{

    state: State,
    active_tetramino: Tetramino,
    // ghost_tetramino: Tetramino,
    hold_tetramino: ?u8,
    tetramino_num: usize,
    tetramino_seq: [7]u8,
    rand: *std.Random,
    timer_das: c_longdouble,
    timer_ar: c_longdouble,
    time_to_drop: c_longdouble, // the time in second before the tetramino drops by one square of the grid
    timer_lock: c_longdouble,
    timer_drop: c_longdouble,
    timer_exit: c_longdouble,
    in_lock_delay: bool,
    is_t_spin: bool,
    is_t_spin_mini: bool,
    lines_cleared: u64,
    level_sub_one: u64, // level minus one
    score: u64,
    combo: ?u64,
    menu: menu.Menu,
    imap: InputMapping,
    high_score: HighScore,
    running: bool,
    just_held: bool,
    
    pub fn init(
        rand: *std.Random, 
        imap: InputMapping, 
        high_score: HighScore
    ) Game {
        var buffer = [_]u8{'I', 'O', 'J', 'L', 'T', 'S', 'Z'};
        rand.shuffle(u8, &buffer);
        return .{
            .state = State.init(),
            .active_tetramino = Tetramino.init(buffer[0]),
            .hold_tetramino = null,
            .tetramino_num = 0,
            .tetramino_seq = buffer,
            .rand = rand, 
            .timer_das = 0.0,
            .timer_ar = 0.0,
            .time_to_drop = 1.0, // 1 sec
            .timer_lock = 0.0,
            .timer_drop = 0.0,
            .timer_exit = 0.0,
            .in_lock_delay = false,
            .is_t_spin = false,
            .is_t_spin_mini = false,
            .lines_cleared = 0,
            .level_sub_one = 0,
            .score = 0,
            .combo = null,
            .menu = menu.Menu.init(),
            .imap = imap,
            .high_score = high_score,
            .running = true,
            .just_held = false,
        };
    }
    
    pub fn reset(self: *Game) void {
        self.state = State.init();
        self.tetramino_num = 0;
        self.shufflePieces();
        self.active_tetramino = Tetramino.init(self.tetramino_seq[0]);
        self.hold_tetramino = null;
        self.timer_das = 0.0;
        self.timer_ar = 0.0;
        self.time_to_drop = 1.0;
        self.timer_lock = 0.0;
        self.timer_drop = 0.0;
        self.timer_exit = 0.0;
        self.in_lock_delay = false;
        self.is_t_spin = false;
        self.is_t_spin_mini = false;
        self.lines_cleared = 0;
        self.level_sub_one = 0;
        self.score = 0;
        self.combo = null;
        self.running = true;
        self.just_held = false;
    }

    pub fn gameLoop(self: *Game) !void {

        c.SetConfigFlags(c.FLAG_WINDOW_RESIZABLE | c.FLAG_VSYNC_HINT);
        c.InitWindow(screenWidth, screenHeight, "Tetris");
        c.SetExitKey(c.KEY_NULL); // remove with single button press
        c.SetWindowMinSize(screenWidth / 2, screenHeight / 2);
        defer c.CloseWindow();      // Close window and OpenGL context

        // load a nice monospaced nerd font
        font = c.GetFontDefault();// c.LoadFont("resources/DepartureMonoNerdFontMono-Regular.otf"); // 
        defer c.UnloadFont(font);

        c.InitAudioDevice(); // Initialize audio device
        var music = c.LoadMusicStream("resources/theme_A.mp3");
        const rot_sound = c.LoadSound("resources/Rotate_Piece_Sound_Effect.mp3");
        const lock_sound = c.LoadSound("resources/se_game_landing.wav");
        const sdrop_sound = c.LoadSound("resources/se_game_softdrop.wav");
        const hold_sound = c.LoadSound("resources/se_game_hold.wav");
        const hdrop_sound = c.LoadSound("resources/se_game_harddrop.wav");
        defer c.UnloadMusicStream(music);
        c.PlayMusicStream(music);
        defer c.StopMusicStream(music);
        c.SetMusicPan(music, 0.0);
        c.SetMusicVolume(music, 0.8);

        c.SetTargetFPS(FRAMERATE);
        while (!c.WindowShouldClose()) { // Detect window close button or ESC key

            loop: switch (self.menu.state) {
                .ExitGame => {
                    break;
                },
                .InGame => {
                    c.UpdateMusicStream(music);
                    if (c.IsKeyPressed(self.imap.left) and !self.leftBlocked()) {
                        self.active_tetramino.move_left();
                        self.resetTimerDAS();
                        self.resetTSpin();
                    }
                    if (c.IsKeyPressed(self.imap.right) and !self.rightBlocked()) {
                        self.active_tetramino.move_right();
                        self.resetTimerDAS();
                        self.resetTSpin();
                    }
                    if (c.IsKeyDown(self.imap.left) and !self.leftBlocked()) {
                        const das_condition = self.lapseDASandAR();
                        if (das_condition) {
                            self.active_tetramino.move_left();
                            self.timer_ar = 0;
                        }
                        self.resetTSpin();
                    }
                    if (c.IsKeyDown(self.imap.right) and !self.rightBlocked()) {
                        const das_condition = self.lapseDASandAR();
                        if (das_condition) {
                            self.active_tetramino.move_right();
                            self.timer_ar = 0;
                        }
                        self.resetTSpin();
                    }
                    if (c.IsKeyDown(self.imap.@"soft drop")) {
                        self.timer_drop += c.GetFrameTime();
                        if (!self.downBlocked() and (self.timer_drop >= DART)) {
                            self.active_tetramino.move_down();
                            self.score += 1;
                            self.timer_drop = 0;
                            c.PlaySound(sdrop_sound);
                        } else {
                            self.lockDelay(lock_sound);
                        }
                        self.resetTSpin();
                    }
                    if (c.IsKeyPressed(self.imap.@"hard drop")) {
                        var cells: u64 = 0; 
                        while(!self.downBlocked()) {
                            self.active_tetramino.move_down();
                            cells += 1;
                        } else {
                            self.lockTetramino();
                            c.PlaySound(lock_sound);
                            self.running = !self.spawnTetramino();
                        }
                        self.score += 2 * cells;
                        c.PlaySound(hdrop_sound);
                        self.resetTSpin();
                    }
                    if (c.IsKeyPressed(self.imap.hold)) {
                        self.holdPiece();
                        c.PlaySound(hold_sound);
                        self.resetTSpin();
                    }
                    if (c.IsKeyPressed(self.imap.@"rotate CW")) {
                        const opt_wall_kick = self.superRotationSystem(.CW);
                        if (opt_wall_kick) |wall_kick| {
                            self.active_tetramino.rot_CW(wall_kick);
                            c.PlaySound(rot_sound);
                            self.in_lock_delay = false;
                            self.is_t_spin = self.isTSpin(wall_kick);
                            self.is_t_spin_mini = self.isTSpinMini(wall_kick);
                        }
                    }
                    if (c.IsKeyPressed(self.imap.@"rotate CCW")) {
                        const opt_wall_kick = self.superRotationSystem(.CCW);
                        if (opt_wall_kick) |wall_kick| {
                            self.active_tetramino.rot_CCW(wall_kick);
                            c.PlaySound(rot_sound);
                            self.in_lock_delay = false;
                            self.is_t_spin = self.isTSpin(wall_kick);
                            self.is_t_spin_mini = self.isTSpinMini(wall_kick);
                        }
                    }
                    if (c.IsKeyPressed(self.imap.pause)) {
                        self.menu.state = .{ .PauseMenu = menu.pauseScreen };
                    }

                    const exit_elapsed = self.timer_exit >= EXITTIME;
                    if (c.IsKeyUp(self.imap.exit)) {
                        self.timer_exit = 0.0;
                    } else {
                        self.timer_exit += c.GetFrameTime();
                        if (exit_elapsed) {
                            self.menu.state = .ExitGame;
                        }
                    }

                    self.timer_drop += c.GetFrameTime();
                    const drop_elapsed = self.timer_drop >= self.time_to_drop;
                    if (drop_elapsed) {
                        if (!self.downBlocked()) {
                            self.active_tetramino.move_down();
                        } else {
                            self.lockDelay(lock_sound);
                        }
                        self.timer_drop = 0;
                    }

                    if (self.in_lock_delay and self.downBlocked()) {
                        self.lockDelay(lock_sound);
                    } else {
                        self.in_lock_delay = false;
                    }

                    if (!self.running) {
                        const opt_i = self.high_score.checkHighScore(self.score);
                        if (opt_i) |idx| {
                            self.menu.state = .{ .EnterName = idx };
                        } else {
                            self.menu.state = .{ .GameOverMenu = menu.gameOverScreen };
                            self.reset();
                        }
                    }

                    self.drawGame();
                    continue :loop self.menu.state;
                },
                .RemappingInput => |str| {
                    c.UpdateMusicStream(music);
                    const end = str.len;
                    if (end > 0) {
                        const field = str[0..end - 2];
                        const new_key = self.imap.rebind(field);
                        if (new_key != 0) {
                            self.menu.state = .{ .ControlsMenu = menu.controlsScreen };
                        }
                        self.drawGame();
                    } else {
                        self.imap = default_map;
                        self.menu.state = .{ .ControlsMenu = menu.controlsScreen };
                    }
                    continue :loop self.menu.state;
                },
                .ChangeMusic => |str| {
                    music = c.LoadMusicStream(str);
                    c.PlayMusicStream(music);
                    c.UpdateMusicStream(music);
                    self.menu.state = .{ .MusicMenu = menu.musicScreen };
                    continue :loop self.menu.state;
                },
                .EnterName => |idx| {
                    c.UpdateMusicStream(music);
                    self.drawGame();
                    var letterCount: usize = 0;
                    var key = c.GetCharPressed();

                    entry: while (letterCount <= NAMELENGTH) {
                        if ((key >= 32) and (key <= 125)) {
                            if (letterCount != NAMELENGTH) {
                                enter_name[letterCount] = @as(u8, @intCast(key));
                                letterCount += 1;
                            }
                        }

                        key = c.GetCharPressed();  // Check next character in the queue

                        if (c.IsKeyPressed(c.KEY_BACKSPACE) and (letterCount > 0)) {
                            letterCount -= 1;
                            enter_name[letterCount] = '_'; 
                        }

                        if (c.IsKeyReleased(c.KEY_ENTER) and (letterCount == NAMELENGTH)) {
                            break: entry;
                        }
                        c.UpdateMusicStream(music);
                        self.drawGame();
                    }
                    self.high_score.addNewScore(idx, self.score, enter_name);
                    enter_name = ("_" ** NAMELENGTH).*;
                    self.menu.state = .{ .GameOverMenu = menu.gameOverScreen };
                    self.reset();
                    continue :loop self.menu.state;
                },
                else => {
                    c.UpdateMusicStream(music);
                    self.menu.menu_loop(self.*);
                    self.drawGame();
                    switch (self.menu.state) {
                        .StartMenu => self.reset(),
                        else => {},
                    } 
                    continue :loop self.menu.state;
                },
            }
        }
    }

    fn lockDelay(self: *Game, lock_sound: c.Sound) void {
        if (!self.in_lock_delay) {
            self.in_lock_delay = true;
            self.timer_lock = 0;
        } else {
            self.timer_lock += c.GetFrameTime();
            const lock_elapsed = self.timer_lock >= LOCKDELAY;
            if (lock_elapsed) {
                self.lockTetramino();
                c.PlaySound(lock_sound);
                self.running = !self.spawnTetramino();
                self.in_lock_delay = false;
            }
        }
    }

    fn shufflePieces(self: *Game) void {
        self.rand.shuffle(u8, &self.tetramino_seq);
    }

    fn spawnTetramino(self: *Game) bool {
        self.tetramino_num += 1;
        const idx = self.tetramino_num % self.tetramino_seq.len;
        self.active_tetramino = Tetramino.init(self.tetramino_seq[idx]);
        //shuffle when you get to the last piece in current queue
        if (idx == 6) { 
            self.shufflePieces();
        }
        return self.state.checkOverlap(
            self.active_tetramino.get_blocks()
        );
    }

    fn lockTetramino(self: *Game) void {
        self.just_held = false;
        const block_pos_arr = self.active_tetramino.get_blocks();
        // initialize with max usize by wrapping subtraction
        var row_full_arr: [4]usize = .{ @as(usize, 0) -% 1 } ** 4;
        var idx: usize = 0;
        for (block_pos_arr) |block_pos| {
            const row = @as(usize, @intCast(block_pos[0]));
            const col = @as(usize, @intCast(block_pos[1]));
            self.state.update(row, col, true, self.active_tetramino.get_color());
            if (self.state.checkRowFull(row)) {
                row_full_arr[idx] = row;
                idx += 1;
            }
        }

        std.mem.sort(usize, &row_full_arr, {}, comptime std.sort.asc(usize));
        for (0..idx) |i| {
            self.state.shiftRowsDown(row_full_arr[i]);
        }

        self.lines_cleared += idx;
        // if it's a perfect line clear you earn extra points
        var score_factor: [4]u64 = undefined;
        if (self.is_t_spin) {
            score_factor = [_]u64{800, 1200, 1600, 0};
        } else if (self.is_t_spin_mini) {
            score_factor = [_]u64{200, 400, 0, 0};
        } else {
            score_factor = [_]u64{100, 300, 500, 800};
        }
        if (self.state.isEmpty()) {
            const perfect_clear_bonus = [_]u64{800, 1200, 1800, 2000};
            for (perfect_clear_bonus, 0..) |bonus, i| {
                score_factor[i] += bonus;
            }
        }
        const score_level = self.level_sub_one + 1;
        if (idx > 0) {
            self.score += score_factor[idx - 1] * score_level;
            if (self.combo) |*val| {
                self.score += 50 * score_level * val.*;
                val.* += 1;
            } else {
                self.combo = 0;
            }
            if (@divFloor(self.lines_cleared, LINESFORLEVELUP) > self.level_sub_one) {
                self.increaseLevel();
            }
        } else {
            self.combo = null;
            if (self.is_t_spin_mini) {
                self.score += 100 * score_level;
            }
            if (self.is_t_spin) {
                self.score += 400 * score_level;
            }
        }
        self.is_t_spin = false;
        self.is_t_spin_mini = false;
    }

    fn increaseLevel(self: *Game) void {
        self.level_sub_one += 1;
        const level_sub_one = @as(f64, @floatFromInt(self.level_sub_one));
        self.time_to_drop = std.math.pow(
            f64, (0.8 - level_sub_one * 0.007), level_sub_one
        );
    }

    fn resetTimerDAS(self: *Game) void {
        self.timer_das = 0;
        self.timer_ar = 0;
    }

    fn lapseDASandAR(self: *Game) bool {
        self.timer_das += c.GetFrameTime();
        self.timer_ar += c.GetFrameTime();
        const das_condition = (
            (self.timer_das >= DAS) and 
            (self.timer_ar >= DASART)
        );
        return das_condition;
    }

    fn resetTSpin(self: *Game) void {
        self.is_t_spin = false;
        self.is_t_spin_mini = false;
    }

    fn leftBlocked(self: *Game) bool {
        const block_pos_arr = self.active_tetramino.get_blocks();
        var any_block = false; 
        for (block_pos_arr) |block_pos| {
            const row = @as(usize, @intCast(block_pos[0]));
            const col = @as(usize, @intCast(block_pos[1]));
            any_block = (col == 0) or any_block;
            if (~any_block) {
                any_block = any_block or self.state.array[@as(usize, @intCast(row))][@as(usize, @intCast(col)) - 1];
            } else {
                return true;
            }
        }
        return any_block;
    }

    fn rightBlocked(self: *Game) bool {
        const block_pos_arr = self.active_tetramino.get_blocks();
        var any_block = false; 
        for (block_pos_arr) |block_pos| {
            const row = block_pos[0];
            const col = block_pos[1];
            any_block = (col == (MAXCOLS - 1)) or any_block;
            if (~any_block) {
                any_block = any_block or self.state.array[
                    @as(usize, @intCast(row))][
                    @as(usize, @intCast(col)) + 1];
            } else {
                return true;
            }
        }
        return any_block;
    }

    fn downBlocked(self: *Game) bool {
        const block_pos_arr = self.active_tetramino.get_blocks();
        var any_block = false; 
        for (block_pos_arr) |block_pos| {
            const row = block_pos[0];
            const col = block_pos[1];
            any_block = (row == (MAXROWS - 1)) or any_block;
            if (~any_block) {
                any_block = any_block or self.state.array[@as(usize, @intCast(row)) + 1][@as(usize, @intCast(col))];
            } else {
                return true;
            }
        }
        return any_block;
    }

    fn superRotationSystem(self: Game, rot: Rotation) ?[2]isize {
        const tetra_i = self.active_tetramino;
        switch (rot) {
            .CW => {
                const tetra_o = tetra_i.true_rot_CW();
                return tetra_i.superRotationSystemLogic(tetra_o, self.state);
            },
            .CCW => {
                const tetra_o = tetra_i.true_rot_CCW();
                return tetra_i.superRotationSystemLogic(tetra_o, self.state);
            },
        }
    }

    fn holdPiece(self: *Game) void {
        if (self.just_held) {
            return;
        }
        const prev_act = self.active_tetramino;
        if (self.hold_tetramino) |char| {
            self.active_tetramino = Tetramino.init(char);
        } else {
            self.running = !self.spawnTetramino();
        }
        self.hold_tetramino = switch (prev_act) {
            .I => 'I',
            .O => 'O',
            .J => 'J',
            .L => 'L',
            .T => 'T',
            .S => 'S',
            .Z => 'Z',
        };
        self.just_held = true;
    }

    fn isTSpin(self: Game, wall_kick: [2]isize) bool {
        // need logic for 5th SRS kick
        switch (self.active_tetramino) {
            .T => |piece| {
                // if the wall kick if has the offset from the fifth set
                if ((@abs(wall_kick[0]) == 2) and (@abs(wall_kick[1]) == 1)) {
                    return true;
                }
                const row = piece.row;
                const col = piece.col;
                const orientation = piece.orientation;

                const ll_diag = if ((row + 1 > MAXROWS) or (col - 1) < 0) true else self.state.array[
                    @as(usize, @intCast(row + 1))
                ][
                    @as(usize, @intCast(col - 1))
                ];

                const lr_diag = if ((row + 1 > MAXROWS) or (col + 1) > MAXCOLS) true else self.state.array[
                    @as(usize, @intCast(row + 1))
                ][
                    @as(usize, @intCast(col + 1))
                ];
                const bottom_diags = ll_diag and lr_diag; 
                if (!bottom_diags) return false;
                

                const ul_diag = if ((col - 1) < 0) true else self.state.array[
                    @as(usize, @intCast(row - 1))
                ][
                    @as(usize, @intCast(col - 1))
                ];

                const ur_diag = if ((col + 1) > MAXCOLS) true else self.state.array[
                    @as(usize, @intCast(row - 1))
                ][
                    @as(usize, @intCast(col + 1))
                ];

                const three_diags = bottom_diags and (ul_diag or ur_diag);
                return switch (orientation) {
                    .Spawn => ul_diag and ur_diag and (ll_diag or lr_diag),
                    .Clockwise => bottom_diags and ur_diag,
                    .CounterClockwise => bottom_diags and ul_diag,
                    .DoubleRotated => three_diags,
                };
            },
            else => return false,
        }
    }

    fn isTSpinMini(self: Game, wall_kick: [2]isize) bool {
        switch (self.active_tetramino) {
            .T => |piece| {
                // if the wall kick if has the offset from the fifth set
                if ((@abs(wall_kick[0]) == 2) and (@abs(wall_kick[1]) == 1)) {
                    return false;
                }
                const row = piece.row;
                const col = piece.col;
                const orientation = piece.orientation;

                const ll_diag = if ((row + 1 > MAXROWS) or (col - 1) < 0) true else self.state.array[
                    @as(usize, @intCast(row + 1))
                ][
                    @as(usize, @intCast(col - 1))
                ];

                const lr_diag = if ((row + 1 > MAXROWS) or (col + 1) > MAXCOLS) true else self.state.array[
                    @as(usize, @intCast(row + 1))
                ][
                    @as(usize, @intCast(col + 1))
                ];
                const bottom_diags = ll_diag and lr_diag; 
                if (!bottom_diags) return false;
                

                const ul_diag = if ((col - 1) < 0) true else self.state.array[
                    @as(usize, @intCast(row - 1))
                ][
                    @as(usize, @intCast(col - 1))
                ];

                const ur_diag = if ((col + 1) > MAXCOLS) true else self.state.array[
                    @as(usize, @intCast(row - 1))
                ][
                    @as(usize, @intCast(col + 1))
                ];

                const three_diags = bottom_diags and (ul_diag or ur_diag);
                return switch (orientation) {
                    .Spawn => three_diags,
                    .Clockwise => bottom_diags and ul_diag,
                    .CounterClockwise => bottom_diags and ur_diag,
                    .DoubleRotated => ul_diag and ur_diag and (ll_diag or lr_diag),
                };
            },
            else => return false,
        }
    }

    pub fn drawGame(self: Game) void {
        if (c.IsWindowResized()) {
            const scale: f32 = @min(
                @as(f32, @floatFromInt(c.GetScreenWidth())) / @as(f32, @floatFromInt(screenWidth)), 
                @as(f32, @floatFromInt(c.GetScreenHeight())) / @as(f32, @floatFromInt(screenHeight)),
            );

            const tempWidth: f32 = @as(f32, @floatFromInt(screenWidth)) * scale;
            screenWidth = @intFromFloat(@round(tempWidth)); 
            const tempHeight: f32 = @as(f32, @floatFromInt(screenHeight)) * scale;
            screenHeight = @intFromFloat(@round(tempHeight));
            const tempSquareSize: f32 = @as(f32, @floatFromInt(squareSize)) * scale;
            squareSize = @intFromFloat(@round(tempSquareSize));
            const tempSpacing: f32 = @as(f32, @floatFromInt(spacing)) * scale;
            spacing = @intFromFloat(@round(tempSpacing));
            const tempIFS: f32 = @as(f32, @floatFromInt(item_font_size)) * scale;
            item_font_size = @intFromFloat(@round(tempIFS));
            const tempBFS: f32 = @as(f32, @floatFromInt(banner_font_size)) * scale;
            banner_font_size = @intFromFloat(@round(tempBFS));
        }


        const state = self.state;
        const active_tetramino = self.active_tetramino;
        c.BeginDrawing();

        c.ClearBackground(c.BLACK);
        if (c.IsKeyDown(self.imap.exit)) {
            c.DrawTextEx(font, "Keep holding to exit game...", 
                .{ .x = 0, .y = 0 }, 2 * item_font_size, spacing, c.LIGHTGRAY
            );
        }
        switch (self.menu.state) {
            .InGame => {
                var x: c_int = screenWidth / 2 - MAXCOLS * squareSize / 2;
                var y: c_int = screenHeight / 2 - (MAXROWS - 2) * squareSize / 2;

                const controller: c_int = x;

                var blocks_pos = active_tetramino.get_blocks();
                while (!state.checkOverlap(blocks_pos)) {
                    for (&blocks_pos) |*block| {
                        block.*[0] += 1;
                    }
                }
                for (&blocks_pos) |*block| {
                    block.*[0] -= 1;
                }
                const tetra_color = active_tetramino.get_color();
                for (2..MAXROWS) |row| {
                    for (0..state.columns) |col| {
                        if (state.array[row][col]) {
                            c.DrawRectangle(x, y, squareSize, squareSize, state.color_array[row][col]);
                        } else if (active_tetramino.isOccupied(row, col)) {
                            c.DrawRectangle(x, y, squareSize, squareSize, tetra_color);
                        }
                        for (blocks_pos) |block| {
                            if ((block[0] == row) and (block[1] == col)) {
                                c.DrawRectangle(
                                    x, y, squareSize, squareSize, c.Fade(tetra_color, 0.3)
                                );
                            }
                        }
                        c.DrawLine(x, y, x + squareSize, y, c.LIGHTGRAY );
                        c.DrawLine(x, y, x, y + squareSize, c.LIGHTGRAY );
                        c.DrawLine(x + squareSize, y, x + squareSize, y + squareSize, c.LIGHTGRAY );
                        c.DrawLine(x, y + squareSize, x + squareSize, y + squareSize, c.LIGHTGRAY );
                        x += squareSize;
                    }
                    x = controller;
                    y += squareSize;
                }
                x = screenWidth / 2 + MAXCOLS * squareSize;
                y = screenHeight / 4;

                const controler: c_int = x;
                const next = self.tetramino_seq[(self.tetramino_num + 1) % self.tetramino_seq.len];
                drawPiece(next, &x, &y);

                x = screenWidth / 2 - MAXCOLS * squareSize - 6 * squareSize;
                y = screenHeight / 4;
                var x_float: f32 = @floatFromInt(x);
                var y_float: f32 = @floatFromInt(y);
                c.DrawTextEx(font, "HOLD:", .{ .x = x_float, .y = y_float - squareSize}, item_font_size, spacing, c.LIGHTGRAY);
                c.DrawTextEx(font, c.TextFormat("COMBO:      % 6i", self.combo orelse 0), .{ .x = x_float, .y = y_float + 7 * squareSize}, item_font_size, spacing, c.LIGHTGRAY);
                if (self.hold_tetramino) |hold| {
                    drawPiece(hold, &x, &y);
                }
                y_float = screenHeight / 4;

                x_float = @floatFromInt(controler);
                y_float += 3 * squareSize;
                c.DrawTextEx(font, "NEXT:", .{ .x = x_float, .y = y_float - 4 * squareSize }, item_font_size, spacing, c.LIGHTGRAY);
                c.DrawTextEx(font, c.TextFormat("LINES:      % 6i", self.lines_cleared), .{ .x = x_float, .y = y_float + 4 * squareSize}, item_font_size, spacing, c.LIGHTGRAY);
                c.DrawTextEx(font, c.TextFormat("SCORE:      % 6i", self.score), .{ .x = x_float, .y = y_float}, item_font_size, spacing, c.LIGHTGRAY);
                c.DrawTextEx(font, c.TextFormat("LEVEL:      % 6i", self.level_sub_one + 1), .{ .x = x_float, .y = y_float + 8 * squareSize}, item_font_size, spacing, c.LIGHTGRAY);
            },
            .StartMenu, 
            .SettingsMenu, 
            .PauseMenu,
            .GameOverMenu, 
            .MusicMenu => |screen| {
                const draw_top_y = screenHeight / 4;
                const draw_left_x = screenWidth / 4;
                const draw_right_x = 3 * screenWidth / 4;
                const block_size = screenWidth / 6;
                c.DrawLine(draw_left_x, draw_top_y, draw_right_x, draw_top_y, c.LIGHTGRAY );
                c.DrawLine(draw_left_x, draw_top_y, draw_left_x, draw_top_y + block_size, c.LIGHTGRAY );
                c.DrawLine(draw_right_x, draw_top_y, draw_right_x, draw_top_y + block_size, c.LIGHTGRAY );
                c.DrawLine(draw_left_x, draw_top_y + block_size, draw_left_x + block_size, draw_top_y + block_size, c.LIGHTGRAY);
                c.DrawLine(draw_right_x, draw_top_y + block_size, draw_right_x - block_size, draw_top_y + block_size, c.LIGHTGRAY);
                c.DrawLine(draw_left_x + block_size, draw_top_y + block_size, draw_left_x + block_size, draw_top_y + 2 * block_size, c.LIGHTGRAY);
                c.DrawLine(draw_right_x - block_size, draw_top_y + block_size, draw_right_x - block_size, draw_top_y + 2 * block_size, c.LIGHTGRAY);
                c.DrawLine(draw_left_x + block_size, draw_top_y + 2 * block_size, draw_right_x - block_size, draw_top_y + 2 * block_size, c.LIGHTGRAY);

                const banner_dim = c.MeasureTextEx(font, screen.banner, banner_font_size, spacing);
                c.DrawTextEx(font, screen.banner, .{ .x = @as(f32, @floatFromInt(screenWidth)) / 2 - @as(f32, banner_dim.x) / 2, .y = @as(f32, draw_top_y + block_size / 2 - banner_dim.y / 2 )}, banner_font_size, spacing, c.LIGHTGRAY);

                const shift: f32 = 0.5 * @as(f32, @floatFromInt(@intFromEnum(screen.max_position_y) + 1));
                const len_y: usize = (@intFromEnum(screen.max_position_y) + 1);
                for (0..len_y) |row| {
                    const item_dim = c.MeasureTextEx(font, screen.arr_str[row][0], item_font_size, spacing);
                    const pos_x = @as(f32, @floatFromInt(screenWidth)) / 2 - item_dim.x / 2;
                    const pos_y = @as(f32, draw_top_y + 3 * block_size / 2 ) + squareSize * (@as(f32, @floatFromInt(row)) - shift);
                    c.DrawTextEx(font, screen.arr_str[row][0], .{ .x = pos_x, .y = pos_y }, item_font_size, spacing, c.LIGHTGRAY);
                    if ((@intFromEnum(screen.position_y) == row)) {
                        const arrow_dim = c.MeasureTextEx(font, ">", item_font_size, spacing);
                        const arrow_shift_x = 2 * arrow_dim.x;
                        c.DrawTextEx(font, ">", .{ .x = pos_x - arrow_shift_x, .y = pos_y}, item_font_size, spacing, c.LIGHTGRAY);
                    }
                }
            },
            .ControlsMenu => |screen| {
                const banner_dim = c.MeasureTextEx(font, screen.banner, banner_font_size, spacing);
                c.DrawTextEx(font, screen.banner, .{ .x = @as(f32, @floatFromInt(screenWidth)) / 2 - banner_dim.x / 2, .y = @as(f32, @floatFromInt(screenHeight)) / 2 - banner_dim.y }, banner_font_size, spacing, c.LIGHTGRAY);
                const len_y = (@intFromEnum(screen.max_position_y) + 1);
                const len_x = (@intFromEnum(screen.max_position_x) + 1);
                for (0..len_y) |row| {
                    for (0..len_x) |col| {
                        const field = screen.arr_str[row][col];
                        const end = field.len;
                        const pos_x: f32 = (2 * @as(f32, @floatFromInt(col)) + 1) * @divFloor(screenWidth, 4);
                        const pos_y: f32 = @as(f32, @floatFromInt(screenHeight)) / 2 - banner_dim.y / 2 + squareSize * @as(f32, @floatFromInt(row + len_y / 2));
                        const field_dim = c.MeasureTextEx(font, field, item_font_size, spacing);
                        const fields = @typeInfo(InputMapping).@"struct".fields;
                        var any: bool = false;
                        inline for (fields) |fld| {
                            if (std.mem.eql(u8, fld.name, field[0..end - 2])) {
                                any ^= true;
                                c.DrawTextEx(font, GetKeyText(@field(self.imap, fld.name)), .{ .x = pos_x, .y = pos_y}, item_font_size, spacing, c.LIGHTGRAY);
                                c.DrawTextEx(font, field, .{ .x = pos_x - field_dim.x, .y = pos_y}, item_font_size, spacing, c.LIGHTGRAY);
                            }
                        } 
                        if (!any) {
                            c.DrawTextEx(font, field, .{ .x = pos_x - field_dim.x / 2, .y = pos_y}, item_font_size, spacing, c.LIGHTGRAY);
                        }
                        if ((@intFromEnum(screen.position_x) == col) and (@intFromEnum(screen.position_y) == row)) {
                            const arrow_dim = c.MeasureTextEx(font, ">", item_font_size, spacing);
                            const arrow_shift_x = (if (any) field_dim.x else (field_dim.x / 2)) + 2 * arrow_dim.x;
                            c.DrawTextEx(font, ">", .{ .x = pos_x - arrow_shift_x, .y = pos_y}, item_font_size, spacing, c.LIGHTGRAY);
                        }
                    }
                }
            },
            .HighScoreMenu => |screen| {
                const banner_dim = c.MeasureTextEx(font, screen.banner, banner_font_size, spacing);
                const banner_pos: c.Vector2 = .{ 
                    .x = @as(f32, @floatFromInt(screenWidth)) / 2 - banner_dim.x / 2, 
                    .y = @as(f32, @floatFromInt(screenHeight)) / 2 - banner_dim.y };
                c.DrawTextEx(font, screen.banner, banner_pos, banner_font_size, spacing, c.LIGHTGRAY);
                const len_y = (@intFromEnum(screen.max_position_y) + 1);
                const len_x = (@intFromEnum(screen.max_position_x) + 1);
                for (0..len_y) |row| {
                    for (0..len_x) |col| {
                        const rank = screen.arr_str[row][col];
                        const pos_x: f32 = (2 * @as(f32, @floatFromInt(col)) + 1) * @divFloor(screenWidth, 4);
                        const pos_y: f32 = @as(f32, @floatFromInt(screenHeight)) / 2 - banner_dim.y / 2 + squareSize * @as(f32, @floatFromInt(row + len_y / 2));
                        const rank_dim = c.MeasureTextEx(font, rank, item_font_size, spacing);
                        const name = self.high_score.top_ten_names[row + col * len_y];
                        const name_dim = c.MeasureTextEx(font, name[0..NAMELENGTH], item_font_size, spacing);
                        const score = self.high_score.top_ten_scores[row + col * len_y];
                        c.DrawTextEx(font, &name, .{ .x = pos_x, .y = pos_y}, item_font_size, spacing, c.LIGHTGRAY);
                        c.DrawTextEx(font, c.TextFormat("      % 6i", score), .{ .x = pos_x + name_dim.x, .y = pos_y}, item_font_size, spacing, c.LIGHTGRAY);
                        c.DrawTextEx(font, rank, .{ .x = pos_x - rank_dim.x, .y = pos_y}, item_font_size, spacing, c.LIGHTGRAY);
                    }
                }
                const return_txt = "Press Enter to Return.";
                const return_dim = c.MeasureTextEx(font, return_txt, item_font_size, spacing);
                const return_pos: c.Vector2 = .{ 
                    .x = @as(f32, @floatFromInt(screenWidth)) / 2 - return_dim.x / 2, 
                    .y = @as(f32, @floatFromInt(screenHeight)) / 2 + 8 * return_dim.y,
                };
                c.DrawTextEx(font, return_txt, return_pos, item_font_size, spacing, c.LIGHTGRAY);
            },
            .RemappingInput => |str| {
                const remap_text = "Press a key now to remap your selection";
                const remap_text_dim = c.MeasureTextEx(font, remap_text, item_font_size, spacing);
                if (str.len > 0) {
                    c.DrawTextEx(font, remap_text, .{ .x = screenWidth / 2 - remap_text_dim.x / 2, .y = screenHeight / 2 - remap_text_dim.y / 2}, item_font_size, spacing, c.LIGHTGRAY);
                    c.DrawTextEx(font, str, .{ .x = screenWidth / 2, .y = screenHeight / 2 + squareSize}, item_font_size, spacing, c.LIGHTGRAY);
                }
            },
            .EnterName => |idx| {
                _ = idx;
                var input_char: c_int = 0;
                for (enter_name) |char| {
                    if (char != '_') {
                        input_char += 1;
                    }
                }
                const txt = "Congratulations\nNew High Score\nEnter your name:";
                const txt_dim = c.MeasureTextEx(font, txt, item_font_size, spacing);
                c.DrawTextEx(font, txt, .{ .x = screenWidth / 2 - txt_dim.x / 2, .y = screenHeight / 2 - txt_dim.y / 2}, item_font_size, spacing, c.LIGHTGRAY);
                c.DrawTextEx(font, c.TextFormat("Score:      % 6i", self.score), .{ .x = screenWidth / 2 - txt_dim.x / 2, .y = screenHeight / 2 + txt_dim.y / 2}, item_font_size, spacing, c.LIGHTGRAY);
                c.DrawTextEx(font, &enter_name, .{ .x = screenWidth / 2 - txt_dim.x / 2, .y = screenHeight / 2 + txt_dim.y }, item_font_size, spacing, c.LIGHTGRAY);
                c.DrawTextEx(font, c.TextFormat("INPUT CHARS: %i/%i", input_char, @as(c_int, NAMELENGTH)), .{ .x = 315, .y = 250 }, item_font_size, spacing, c.LIGHTGRAY);
            },
            else => c.DrawFPS(0, 0),
        }
        c.EndDrawing();
    }

    fn drawPiece(piece: u8, x: *c_int, y: *c_int) void {
        switch (piece) {
            'I' => {
                for (0..4) |_| {
                    c.DrawRectangle(x.*, y.*, squareSize, squareSize, c.SKYBLUE);
                    x.* += squareSize;
                }
            },
            'O' => {
                c.DrawRectangle(x.*, y.*, squareSize, squareSize, c.YELLOW);
                x.* += squareSize;
                c.DrawRectangle(x.*, y.*, squareSize, squareSize, c.YELLOW);
                y.* += squareSize;
                c.DrawRectangle(x.*, y.*, squareSize, squareSize, c.YELLOW);
                x.* -= squareSize;
                c.DrawRectangle(x.*, y.*, squareSize, squareSize, c.YELLOW);
            },
            'J' => {
                c.DrawRectangle(x.*, y.*, squareSize, squareSize, c.BLUE);
                y.* += squareSize;
                for (0..3) |_| {
                    c.DrawRectangle(x.*, y.*, squareSize, squareSize, c.BLUE);
                    x.* += squareSize;
                }
            },
            'L' => {
                x.* += 2 * squareSize;
                c.DrawRectangle(x.*, y.*, squareSize, squareSize, c.ORANGE);
                y.* += squareSize;
                for (0..3) |_| {
                    c.DrawRectangle(x.*, y.*, squareSize, squareSize, c.ORANGE);
                    x.* -= squareSize;
                }
            },
            'T' => {
                x.* += squareSize;
                c.DrawRectangle(x.*, y.*, squareSize, squareSize, c.PURPLE);
                y.* += squareSize;
                x.* += squareSize;
                for (0..3) |_| {
                    c.DrawRectangle(x.*, y.*, squareSize, squareSize, c.PURPLE);
                    x.* -= squareSize;
                }
            },
            'S' => {
                x.* += squareSize;
                for (0..2) |_| {
                    c.DrawRectangle(x.*, y.*, squareSize, squareSize, c.GREEN);
                    x.* += squareSize;
                }
                y.* += squareSize;
                x.* -= 2 * squareSize;
                for (0..2) |_| {
                    c.DrawRectangle(x.*, y.*, squareSize, squareSize, c.GREEN);
                    x.* -= squareSize;
                }
            },
            'Z' => {
                for (0..2) |_| {
                    c.DrawRectangle(x.*, y.*, squareSize, squareSize, c.RED);
                    x.* += squareSize;
                }
                y.* += squareSize;
                for (0..2) |_| {
                    c.DrawRectangle(x.*, y.*, squareSize, squareSize, c.RED);
                    x.* -= squareSize;
                }
            },
            else => unreachable,
        }
    }


};

pub fn Matrix(rows: usize, columns: usize) type {
    return struct{
        rows: usize,
        columns: usize,
        array: [rows][columns]bool,
        color_array: [rows][columns]c.Color,

        const Self = @This();

        pub fn init() Self {
            const array: [rows][columns]bool = .{ .{false} ** columns} ** rows;
            const clr_array: [rows][columns]c.Color = .{ .{c.WHITE} ** columns} ** rows;
            return .{
                .rows = rows,
                .columns = columns,
                .array = array,
                .color_array = clr_array,
            };
        }

        pub fn update(self: *Self, row: usize, col: usize, val: bool, clr: c.Color) void {
            self.array[row][col] = val;
            self.color_array[row][col] = clr;
        }

        pub fn checkRowFull(self: *Self, row: usize) bool {
            var full = true;
            var col: usize = 0;
            while (full and (col < self.columns)) {
                full = full and self.array[row][col];
                col += 1;
            }

            return full;
        }

        pub fn shiftRowsDown(self: *Self, row: usize) void {
            var r = row;
            while (r > 0) {
                self.array[r] = self.array[r - 1];
                self.color_array[r] = self.color_array[r - 1];
                r -= 1;
            }
            self.array[0] = .{false} ** MAXCOLS;
            self.color_array[0] = .{c.WHITE} ** MAXCOLS;
        }

        pub fn checkOverlap(self: *const Self, block_pos: [4][2]isize) bool {
            var any_overlap = false; 
            for (block_pos) |pos| {
                const col = pos[1];
                if ((col >= MAXCOLS) or (col < 0)) {
                    return true;
                }
                const row = pos[0];
                if ((row >= MAXROWS) or (row < 0)) {
                    return true;
                }
                any_overlap = any_overlap or self.array[@as(usize, @intCast(row))][@as(usize, @intCast(col))];
            }
            return any_overlap;
        }

        pub fn isEmpty(self: Self) bool {
            var empty = true;
            var row: usize = self.rows - 1;
            var col: usize = 0;
            while (empty and (row >= 0)) : (row -= 1) {
                while (empty and (col < self.columns)) : (col += 1) {
                    empty = !self.array[row][col];
                }
            }
            return empty;
        }

    };

}

pub const InputMapping = struct {
    left: c_int,
    right: c_int,
    @"soft drop": c_int,
    @"hard drop": c_int,
    hold: c_int,
    @"rotate CW": c_int,
    @"rotate CCW": c_int,
    pause: c_int,
    exit: c_int,

    fn rebind(self: *InputMapping, field: []const u8) c_int {
        const new_key = c.GetKeyPressed();
        var old_key: c_int = undefined;
        std.debug.print("{s}", .{GetKeyText(new_key)});
        const fields = @typeInfo(InputMapping).@"struct".fields;
        const is_clash, const clash_field = self.checkButtonClash(new_key);
        if (new_key > 0) {
            inline for (fields) |fld| {
                if (std.mem.eql(u8, fld.name, field)) {
                    old_key = @field(self.*, fld.name);
                    @field(self.*, fld.name) = new_key;
                }
            }
            if (is_clash) {
                inline for (fields) |fld| {
                    if (std.mem.eql(u8, fld.name, clash_field)) {
                        @field(self.*, fld.name) = old_key;
                    }
                }
            }
        }
        return new_key;
    }

    fn resetDefault(self: *InputMapping) void {
        self.* = default_map;
    }

    fn checkButtonClash(self: InputMapping, key: c_int) struct{bool, []const u8} {
        const fields = @typeInfo(InputMapping).@"struct".fields;
        inline for (fields) |fld| {
            if (@field(self, fld.name) == key) {
                return .{true, fld.name};
            }
        }
        return .{false, ""};
    }
};

pub const default_map: InputMapping = .{
    .left = c.KEY_LEFT,
    .right = c.KEY_RIGHT,
    .@"soft drop" = c.KEY_DOWN,
    .@"hard drop" = c.KEY_SPACE,
    .hold = c.KEY_LEFT_SHIFT,
    .@"rotate CW" = c.KEY_UP,
    .@"rotate CCW" = c.KEY_LEFT_CONTROL,
    .pause = c.KEY_ENTER,
    .exit = c.KEY_ESCAPE,
};

const Rotation = enum {
    CW,
    CCW,
};

pub const HighScore = extern struct {
    top_ten_scores: [10]u64,
    top_ten_names: [10][NAMELENGTH:0]u8,

    fn addNewScore(self: *HighScore, index: usize, 
                   high_score: u64, name: [NAMELENGTH:0]u8) void {
        const score_len = self.top_ten_scores.len;
        for (0..(score_len - index)) |idx| {
            // 0..10 10 - 9 -2
            if (score_len == idx + 1) {
                break;
            }
            self.top_ten_scores[score_len - idx - 1] = self.top_ten_scores[score_len - idx - 2];
            self.top_ten_names[score_len - idx - 1] = self.top_ten_names[score_len - idx - 2];
        }
        self.top_ten_scores[index] = high_score;
        self.top_ten_names[index] = name;
    }

    fn checkHighScore(self: HighScore, new_score: u64) ?usize {
        for (self.top_ten_scores, 0..) |score, i| {
            if (new_score > score) {
                return i;
            }
        } else {
            return null;
        }
    }
    
};

pub const empty_high_score: HighScore = .{
    .top_ten_scores = .{0} ** 10,
    .top_ten_names = .{("a" ** NAMELENGTH).*} ** 10,
};

pub fn GetKeyText(key: c_int) [:0]const u8 {
    return switch (key) {
        c.KEY_APOSTROPHE      => "'",          // Key: '
        c.KEY_COMMA           => ",",          // Key: ,
        c.KEY_MINUS           => "-",          // Key: -
        c.KEY_PERIOD          => ".",          // Key: .
        c.KEY_SLASH           => "/",          // Key: /
        c.KEY_ZERO            => "0",          // Key: 0
        c.KEY_ONE             => "1",          // Key: 1
        c.KEY_TWO             => "2",          // Key: 2
        c.KEY_THREE           => "3",          // Key: 3
        c.KEY_FOUR            => "4",          // Key: 4
        c.KEY_FIVE            => "5",          // Key: 5
        c.KEY_SIX             => "6",          // Key: 6
        c.KEY_SEVEN           => "7",          // Key: 7
        c.KEY_EIGHT           => "8",          // Key: 8
        c.KEY_NINE            => "9",          // Key: 9
        c.KEY_SEMICOLON       => ";",          // Key: ;
        c.KEY_EQUAL           => "=",          // Key: =
        c.KEY_A               => "A",          // Key: A | a
        c.KEY_B               => "B",          // Key: B | b
        c.KEY_C               => "C",          // Key: C | c
        c.KEY_D               => "D",          // Key: D | d
        c.KEY_E               => "E",          // Key: E | e
        c.KEY_F               => "F",          // Key: F | f
        c.KEY_G               => "G",          // Key: G | g
        c.KEY_H               => "H",          // Key: H | h
        c.KEY_I               => "I",          // Key: I | i
        c.KEY_J               => "J",          // Key: J | j
        c.KEY_K               => "K",          // Key: K | k
        c.KEY_L               => "L",          // Key: L | l
        c.KEY_M               => "M",          // Key: M | m
        c.KEY_N               => "N",          // Key: N | n
        c.KEY_O               => "O",          // Key: O | o
        c.KEY_P               => "P",          // Key: P | p
        c.KEY_Q               => "Q",          // Key: Q | q
        c.KEY_R               => "R",          // Key: R | r
        c.KEY_S               => "S",          // Key: S | s
        c.KEY_T               => "T",          // Key: T | t
        c.KEY_U               => "U",          // Key: U | u
        c.KEY_V               => "V",          // Key: V | v
        c.KEY_W               => "W",          // Key: W | w
        c.KEY_X               => "X",          // Key: X | x
        c.KEY_Y               => "Y",          // Key: Y | y
        c.KEY_Z               => "Z",          // Key: Z | z
        c.KEY_LEFT_BRACKET    => "[",          // Key: [
        c.KEY_BACKSLASH       => "\\",         // Key: '\'
        c.KEY_RIGHT_BRACKET   => "]",          // Key: ]
        c.KEY_GRAVE           => "`",          // Key: `
        c.KEY_SPACE           => "SPACE",      // Key: Space
        c.KEY_ESCAPE          => "ESC",        // Key: Esc
        c.KEY_ENTER           => "ENTER",      // Key: Enter
        c.KEY_TAB             => "TAB",        // Key: Tab
        c.KEY_BACKSPACE       => "BACK",       // Key: Backspace
        c.KEY_INSERT          => "INS",        // Key: Ins
        c.KEY_DELETE          => "DEL",        // Key: Del
        c.KEY_RIGHT           => "RIGHT",      // Key: Cursor right
        c.KEY_LEFT            => "LEFT",       // Key: Cursor left
        c.KEY_DOWN            => "DOWN",       // Key: Cursor down
        c.KEY_UP              => "UP",         // Key: Cursor up
        c.KEY_PAGE_UP         => "PGUP",       // Key: Page up
        c.KEY_PAGE_DOWN       => "PGDOWN",     // Key: Page down
        c.KEY_HOME            => "HOME",       // Key: Home
        c.KEY_END             => "END",        // Key: End
        c.KEY_CAPS_LOCK       => "CAPS",       // Key: Caps lock
        c.KEY_SCROLL_LOCK     => "LOCK",       // Key: Scroll down
        c.KEY_NUM_LOCK        => "NUMLOCK",    // Key: Num lock
        c.KEY_PRINT_SCREEN    => "PRINTSCR",   // Key: Print screen
        c.KEY_PAUSE           => "PAUSE",      // Key: Pause
        c.KEY_F1              => "F1",         // Key: F1
        c.KEY_F2              => "F2",         // Key: F2
        c.KEY_F3              => "F3",         // Key: F3
        c.KEY_F4              => "F4",         // Key: F4
        c.KEY_F5              => "F5",         // Key: F5
        c.KEY_F6              => "F6",         // Key: F6
        c.KEY_F7              => "F7",         // Key: F7
        c.KEY_F8              => "F8",         // Key: F8
        c.KEY_F9              => "F9",         // Key: F9
        c.KEY_F10             => "F10",        // Key: F10
        c.KEY_F11             => "F11",        // Key: F11
        c.KEY_F12             => "F12",        // Key: F12
        c.KEY_LEFT_SHIFT      => "LSHIFT",     // Key: Shift left
        c.KEY_LEFT_CONTROL    => "LCTRL",      // Key: Control left
        c.KEY_LEFT_ALT        => "LALT",       // Key: Alt left
        c.KEY_LEFT_SUPER      => "WIN",        // Key: Super left
        c.KEY_RIGHT_SHIFT     => "RSHIFT",     // Key: Shift right
        c.KEY_RIGHT_CONTROL   => "RCTRL",      // Key: Control right
        c.KEY_RIGHT_ALT       => "ALTGR",      // Key: Alt right
        c.KEY_RIGHT_SUPER     => "RSUPER",     // Key: Super right
        c.KEY_KB_MENU         => "KBMENU",     // Key: KB menu
        c.KEY_KP_0            => "KP0",        // Key: Keypad 0
        c.KEY_KP_1            => "KP1",        // Key: Keypad 1
        c.KEY_KP_2            => "KP2",        // Key: Keypad 2
        c.KEY_KP_3            => "KP3",        // Key: Keypad 3
        c.KEY_KP_4            => "KP4",        // Key: Keypad 4
        c.KEY_KP_5            => "KP5",        // Key: Keypad 5
        c.KEY_KP_6            => "KP6",        // Key: Keypad 6
        c.KEY_KP_7            => "KP7",        // Key: Keypad 7
        c.KEY_KP_8            => "KP8",        // Key: Keypad 8
        c.KEY_KP_9            => "KP9",        // Key: Keypad 9
        c.KEY_KP_DECIMAL      => "KPDEC",      // Key: Keypad .
        c.KEY_KP_DIVIDE       => "KPDIV",      // Key: Keypad /
        c.KEY_KP_MULTIPLY     => "KPMUL",      // Key: Keypad *
        c.KEY_KP_SUBTRACT     => "KPSUB",      // Key: Keypad -
        c.KEY_KP_ADD          => "KPADD",      // Key: Keypad +
        c.KEY_KP_ENTER        => "KPENTER",    // Key: Keypad Enter
        c.KEY_KP_EQUAL        => "KPEQU",      // Key: Keypad =
        else => "",
    };
}
