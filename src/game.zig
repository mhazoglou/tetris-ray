const std = @import("std");
const Tetramino = @import("tetramino.zig").Tetramino;
const menu = @import("menu.zig");
const c = @import("c.zig").c;

const screenWidth: c_int = 800;
const screenHeight: c_int = 450;
const SQUARE_SIZE = 20;
const FRAMERATE = 60;

const MAXROWS = 22;
const MAXCOLS = 10;
const LOCKDELAY = 0.5; // 0.5 s or 500 ms
const DAS = 10.0 / @as(comptime_float, @floatFromInt(FRAMERATE)); // 10 frames of delay auto shift
const DASART = 2.0 / @as(comptime_float, @floatFromInt(FRAMERATE)); // 2 frames auto repeat rate
const DART = 3.0 / @as(comptime_float, @floatFromInt(FRAMERATE)); // 3 frames drop auto repeat rate
const LINESFORLEVELUP = 10;

pub const State = Matrix(MAXROWS, MAXCOLS);

pub const Game = struct{

    state: State,
    active_tetramino: Tetramino,
    hold_tetramino: ?u8,
    tetramino_num: u64,
    tetramino_seq: [7]u8,
    rand: *std.Random,
    time_das: c_longdouble,
    time_ar: c_longdouble,
    time_to_drop: c_longdouble, // the time in second before the tetramino drops by one square of the grid
    time_lock: c_longdouble,
    time_drop: c_longdouble,
    in_lock_delay: bool,
    lines_cleared: u64,
    level_sub_one: u64, // level minus one
    score: u64,
    menu: menu.Menu,
    imap: InputMapping,
    running: bool,
    just_held: bool,
    
    pub fn init(rand: *std.Random) Game {
        var buffer = [_]u8{'I', 'O', 'J', 'L', 'T', 'S', 'Z'};
        rand.shuffle(u8, &buffer);
        return .{
            .state = State.init(),
            .active_tetramino = Tetramino.init(buffer[0]),
            .hold_tetramino = null,
            .tetramino_num = 0,
            .tetramino_seq = buffer,
            .rand = rand, 
            .time_das = 0.0,
            .time_ar = 0.0,
            .time_to_drop = 1.0, // 1 sec
            .time_lock = 0.0,
            .time_drop = 0.0,
            .in_lock_delay = false,
            .lines_cleared = 0,
            .level_sub_one = 0,
            .score = 0,
            .menu = menu.Menu.init(),
            .imap = .{
                .left = c.KEY_LEFT,
                .right = c.KEY_RIGHT,
                .@"soft drop" = c.KEY_DOWN,
                .@"hard drop" = c.KEY_SPACE,
                .hold = c.KEY_LEFT_SHIFT,
                .@"rotate CW" = c.KEY_UP,
                .@"rotate CCW" = c.KEY_LEFT_CONTROL,
                .pause = c.KEY_ENTER,
                .exit = c.KEY_ESCAPE,
            },
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
        self.time_das = 0.0;
        self.time_ar = 0.0;
        self.time_to_drop = 1.0;
        self.time_lock = 0.0;
        self.time_drop = 0.0;
        self.in_lock_delay = false;
        self.lines_cleared = 0;
        self.level_sub_one = 0;
        self.score = 0;
        self.running = true;
        self.just_held = false;
    }

    pub fn gameLoop(self: *Game) !void {

        c.InitWindow(screenWidth, screenHeight, "classic game: tetris");
        c.SetTargetFPS(FRAMERATE);
        while (!c.WindowShouldClose()) {   // Detect window close button or ESC key

            loop: switch (self.menu.state) {
                .ExitGame => {
                    break;// c.CloseWindow();
                },
                .InGame => {
                    if (c.IsKeyPressed(self.imap.left) and !self.leftBlocked()) {
                        self.active_tetramino.move_left();
                        self.time_das = c.GetTime();
                        self.time_ar = self.time_das;
                    }
                    if (c.IsKeyPressed(self.imap.right) and !self.rightBlocked()) {
                        self.active_tetramino.move_right();
                        self.time_das = c.GetTime();
                        self.time_ar = self.time_das;
                    }
                    if (c.IsKeyDown(self.imap.left) and !self.leftBlocked()) {
                        const now = c.GetTime();
                        const das_condition = (
                            (now - self.time_das) >= DAS) and 
                            ((now - self.time_ar) >= DASART);
                        if (das_condition) {
                            self.active_tetramino.move_left();
                            self.time_ar = c.GetTime();
                        }
                    }
                    if (c.IsKeyDown(self.imap.right) and !self.rightBlocked()) {
                        const now = c.GetTime();
                        const das_condition = (
                            (now - self.time_das) >= DAS) and 
                            ((now - self.time_ar) >= DASART);
                        if (das_condition) {
                            self.active_tetramino.move_right();
                            self.time_ar = c.GetTime();
                        }
                    }
                    // if (c.IsKeyReleased(self.imap.left)) {
                    //     self.time_das_count = 0;
                    // }
                    // if (c.IsKeyReleased(self.imap.right)) {
                    //     self.das_count = 0;
                    // }
                    if (c.IsKeyDown(self.imap.@"soft drop")) {
                        if (!self.downBlocked() and ((c.GetTime() - self.time_drop) >= DART)) {
                            self.active_tetramino.move_down();
                            self.score += 1;
                            self.time_drop = c.GetTime();
                        } else {
                            self.lockDelay();
                        }
                    }
                    // if (c.IsKeyReleased(self.imap.@"soft drop")) {
                    //     self.drop_speed_counter = 0;
                    // }
                    if (c.IsKeyPressed(self.imap.@"hard drop")) {
                        var cells: u64 = 0; 
                        while(!self.downBlocked()) {
                            self.active_tetramino.move_down();
                            cells += 1;
                        } else {
                            self.lockTetramino();
                            self.running = !self.spawnTetramino();
                        }
                        self.score += 2 * cells;
                    }
                    if (c.IsKeyPressed(self.imap.hold)) {
                        self.holdPiece();
                    }
                    if (c.IsKeyPressed(self.imap.@"rotate CW")) {
                        const opt_wall_kick = self.superRotationSystem(.CW);
                        if (opt_wall_kick) |wall_kick| {
                            self.active_tetramino.rot_CW(wall_kick);
                            self.in_lock_delay = false;
                        }
                    }
                    if (c.IsKeyPressed(self.imap.@"rotate CCW")) {
                        const opt_wall_kick = self.superRotationSystem(.CCW);
                        if (opt_wall_kick) |wall_kick| {
                            self.active_tetramino.rot_CCW(wall_kick);
                            self.in_lock_delay = false;
                        }
                    }
                    if (c.IsKeyPressed(self.imap.pause)) {
                            self.menu.state = .{ .PauseMenu = menu.pauseScreen };
                    }
                    if (c.IsKeyPressed(self.imap.exit)) {
                        self.menu.state = .ExitGame;
                    }

                    const drop_elapsed = (c.GetTime() - self.time_drop) >= self.time_to_drop;
                    if (drop_elapsed) {
                        if (!self.downBlocked()) {
                            self.active_tetramino.move_down();
                        } else {
                            self.lockDelay();
                        }
                        self.time_drop = c.GetTime();
                    }

                    if (self.in_lock_delay and self.downBlocked()) {
                        self.lockDelay();
                    } else {
                        self.in_lock_delay = false;
                    }

                    if (!self.running) {
                        self.menu.state = .{ .GameOverMenu = menu.gameOverScreen };
                        self.reset();
                    }
                    self.drawGame();

                    continue :loop self.menu.state;
                },
                .RemappingInput => |str| {
                    const end = str.len;
                    const field = str[0..end - 2];
                    const new_key = self.imap.rebind(field);
                    if (new_key != 0) {
                        self.menu.state = .{ .ControlsMenu = menu.controlsScreen };
                    }
                    self.drawGame();
                    continue :loop self.menu.state;
                },
                else => {
                    self.menu.menu_loop();
                    self.drawGame();
                    continue :loop self.menu.state;
                },
            }
        }
        c.CloseWindow();        // Close window and OpenGL context
    }

    fn lockDelay(self: *Game) void {
        if (!self.in_lock_delay) {
            self.in_lock_delay = true;
            self.time_lock = c.GetTime();
        } else {
            const lock_elapsed = (c.GetTime() - self.time_lock) >= LOCKDELAY;
            if (lock_elapsed) {
                self.lockTetramino();
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
        self.lines_cleared += idx;
        if (idx == 1) {
            self.score += 100 * (self.level_sub_one + 1);
        } else if (idx == 2) {
            self.score += 300 * (self.level_sub_one + 1);
        } else if (idx == 3) {
            self.score += 500 * (self.level_sub_one + 1);
        } else if (idx == 4) {
            self.score += 800 * (self.level_sub_one + 1);
        }
        if ((idx > 0) and (@divFloor(self.lines_cleared, LINESFORLEVELUP) > self.level_sub_one)) {
            self.increaseLevel();
        }
        std.mem.sort(usize, &row_full_arr, {}, comptime std.sort.asc(usize));
        for (0..idx) |i| {
            self.state.shiftRowsDown(row_full_arr[i]);
        }
    }

    fn increaseLevel(self: *Game) void {
        self.level_sub_one += 1;
        const level_sub_one = @as(f64, @floatFromInt(self.level_sub_one));
        self.time_to_drop = std.math.pow(
            f64, (0.8 - level_sub_one * 0.007), level_sub_one
        );
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

    pub fn drawGame(self: Game) void {

        const state = self.state;
        const active_tetramino = self.active_tetramino;
        c.BeginDrawing();

        c.ClearBackground(c.BLACK);
        switch (self.menu.state) {
            .InGame => {
                var x: c_int = screenWidth/2 - (MAXCOLS * SQUARE_SIZE/2);
                var y: c_int = screenHeight/2 - ((MAXROWS - 2) * SQUARE_SIZE/2);

                const controller: c_int = x;

                for (2..MAXROWS) |row| {
                    for (0..state.columns) |col| {
                        if (state.array[row][col]) {
                            c.DrawRectangle(x, y, SQUARE_SIZE, SQUARE_SIZE, state.color_array[row][col]);
                            x += SQUARE_SIZE;
                            // state.color_array[row][col] stl.mino_block;
                        } else if (active_tetramino.isOccupied(row, col)) {
                            c.DrawRectangle(x, y, SQUARE_SIZE, SQUARE_SIZE, active_tetramino.get_color());
                            x += SQUARE_SIZE;
                        } else {
                            c.DrawLine(x, y, x + SQUARE_SIZE, y, c.LIGHTGRAY );
                            c.DrawLine(x, y, x, y + SQUARE_SIZE, c.LIGHTGRAY );
                            c.DrawLine(x + SQUARE_SIZE, y, x + SQUARE_SIZE, y + SQUARE_SIZE, c.LIGHTGRAY );
                            c.DrawLine(x, y + SQUARE_SIZE, x + SQUARE_SIZE, y + SQUARE_SIZE, c.LIGHTGRAY );
                            x += SQUARE_SIZE;
                        }
                    }
                    x = controller;
                    y += SQUARE_SIZE;
                }
                x = 550;
                y = 45;

                const controler: c_int = x;
                const next = self.tetramino_seq[(self.tetramino_num + 1) % self.tetramino_seq.len];
                drawPiece(next, &x, &y);

                x = 200;
                y = 45;
                c.DrawText("HOLD:", x, y - 20 , 14, c.LIGHTGRAY);
                if (self.hold_tetramino) |hold| {
                    drawPiece(hold, &x, &y);
                }
                y = 45;

                x = controler;
                y += 2 * SQUARE_SIZE;
                c.DrawText("NEXT:", x, y - 60, 14, c.LIGHTGRAY);
                c.DrawText(c.TextFormat("LINES:      %06i", self.lines_cleared), x + 100, y - 40, 14, c.LIGHTGRAY);
                c.DrawText(c.TextFormat("SCORE:      %06i", self.score), x + 100, y - 60, 14, c.LIGHTGRAY);
                c.DrawText(c.TextFormat("LEVEL:      %06i", self.level_sub_one + 1), x + 100, y - 20, 14, c.LIGHTGRAY);
                c.DrawFPS(0, 0);
            },
            .StartMenu, .SettingsMenu, .PauseMenu, .GameOverMenu => |screen| {
                const banner_font_size = 60;
                const item_font_size = 12;
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

                c.DrawText(screen.banner, screenWidth/2 - @divFloor(c.MeasureText(screen.banner, banner_font_size), 2), draw_top_y + screenWidth / 24, banner_font_size, c.LIGHTGRAY);
                inline for (0..4) |i| {
                    c.DrawText(screen.arr_str[i][0], screenWidth/2 - @divFloor(c.MeasureText(screen.arr_str[i][0], item_font_size), 2), draw_top_y + 2 * screenWidth / 9 + 20 * @as(c_int, @intCast(i)), item_font_size, c.LIGHTGRAY);
                }
                c.DrawText(">", screenWidth/2 - 60, draw_top_y + 2 * screenWidth / 9 + 20 * @intFromEnum(screen.position_y), item_font_size, c.LIGHTGRAY);
                c.DrawFPS(0, 0);
            },
            .ControlsMenu => |screen| {
                const banner_font_size = 60;
                const item_font_size = 12;
                c.DrawText(screen.banner, screenWidth / 2 - @divFloor(c.MeasureText(screen.banner, banner_font_size), 2), 100, banner_font_size, c.LIGHTGRAY);
                // const ti_imap = @typeInfo(self.imap);
                for (0..4) |row| {
                    for (0..2) |col| {
                        const field = screen.arr_str[row][col];
                        const end = field.len;
                        c.DrawText(field, (2 * @as(c_int, @intCast(col)) + 1) * @divFloor(screenWidth, 4), 200 + 20 * @as(c_int, @intCast(row)), item_font_size, c.LIGHTGRAY);
                        const fields = @typeInfo(InputMapping).@"struct".fields;
                        inline for (fields) |fld| {
                            if (std.mem.eql(u8, fld.name, field[0..end - 2])) {
                                c.DrawText(GetKeyText(@field(self.imap, fld.name)), (2 * @as(c_int, @intCast(col)) + 1) * @divFloor(screenWidth, 4) + 80, 200 + 20 * @as(c_int, @intCast(row)), item_font_size, c.LIGHTGRAY);
                            }
                        }
                    }
                }
                c.DrawText(">", (2 * @as(c_int, @intFromEnum(screen.position_x)) + 1) * @divFloor(screenWidth, 4) - 20, 200 + 20 * @as(c_int, @intFromEnum(screen.position_y)), item_font_size, c.LIGHTGRAY);
            },
            .RemappingInput => |str| {
                c.DrawText("Press a key now to remap your selection", screenWidth / 2, screenHeight / 2, 12, c.LIGHTGRAY);
                c.DrawText(str, screenWidth / 2, screenHeight / 2 + 20, 12, c.LIGHTGRAY);
            },
            else => {},
        }
        c.EndDrawing();
    }

    fn drawPiece(piece: u8, x: *c_int, y: *c_int) void {
        switch (piece) {
            'I' => {
                for (0..4) |_| {
                    c.DrawRectangle(x.*, y.*, SQUARE_SIZE, SQUARE_SIZE, c.SKYBLUE);
                    x.* += SQUARE_SIZE;
                }
            },
            'O' => {
                c.DrawRectangle(x.*, y.*, SQUARE_SIZE, SQUARE_SIZE, c.YELLOW);
                x.* += SQUARE_SIZE;
                c.DrawRectangle(x.*, y.*, SQUARE_SIZE, SQUARE_SIZE, c.YELLOW);
                y.* += SQUARE_SIZE;
                c.DrawRectangle(x.*, y.*, SQUARE_SIZE, SQUARE_SIZE, c.YELLOW);
                x.* -= SQUARE_SIZE;
                c.DrawRectangle(x.*, y.*, SQUARE_SIZE, SQUARE_SIZE, c.YELLOW);
            },
            'J' => {
                c.DrawRectangle(x.*, y.*, SQUARE_SIZE, SQUARE_SIZE, c.BLUE);
                y.* += SQUARE_SIZE;
                for (0..3) |_| {
                    c.DrawRectangle(x.*, y.*, SQUARE_SIZE, SQUARE_SIZE, c.BLUE);
                    x.* += SQUARE_SIZE;
                }
            },
            'L' => {
                x.* += 2 * SQUARE_SIZE;
                c.DrawRectangle(x.*, y.*, SQUARE_SIZE, SQUARE_SIZE, c.ORANGE);
                y.* += SQUARE_SIZE;
                for (0..3) |_| {
                    c.DrawRectangle(x.*, y.*, SQUARE_SIZE, SQUARE_SIZE, c.ORANGE);
                    x.* -= SQUARE_SIZE;
                }
            },
            'T' => {
                x.* += SQUARE_SIZE;
                c.DrawRectangle(x.*, y.*, SQUARE_SIZE, SQUARE_SIZE, c.PURPLE);
                y.* += SQUARE_SIZE;
                x.* += SQUARE_SIZE;
                for (0..3) |_| {
                    c.DrawRectangle(x.*, y.*, SQUARE_SIZE, SQUARE_SIZE, c.PURPLE);
                    x.* -= SQUARE_SIZE;
                }
            },
            'S' => {
                x.* += SQUARE_SIZE;
                for (0..2) |_| {
                    c.DrawRectangle(x.*, y.*, SQUARE_SIZE, SQUARE_SIZE, c.GREEN);
                    x.* += SQUARE_SIZE;
                }
                y.* += SQUARE_SIZE;
                x.* -= 2 * SQUARE_SIZE;
                for (0..2) |_| {
                    c.DrawRectangle(x.*, y.*, SQUARE_SIZE, SQUARE_SIZE, c.GREEN);
                    x.* -= SQUARE_SIZE;
                }
            },
            'Z' => {
                for (0..2) |_| {
                    c.DrawRectangle(x.*, y.*, SQUARE_SIZE, SQUARE_SIZE, c.RED);
                    x.* += SQUARE_SIZE;
                }
                y.* += SQUARE_SIZE;
                for (0..2) |_| {
                    c.DrawRectangle(x.*, y.*, SQUARE_SIZE, SQUARE_SIZE, c.RED);
                    x.* -= SQUARE_SIZE;
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
        std.debug.print("{s}", .{GetKeyText(new_key)});
        const fields = @typeInfo(InputMapping).@"struct".fields;
        if (new_key > 0) {
            inline for (fields) |fld| {
                if (std.mem.eql(u8, fld.name, field)) {
                    @field(self.*, fld.name) = new_key;
                }
            }
        }
        return new_key;
    }

    fn reset_default(self: *InputMapping) void {
        self.* = default_map;
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

