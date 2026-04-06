const std = @import("std");
const Tetramino = @import("tetramino.zig").Tetramino;
const menu = @import("menu.zig");
const c = @import("c.zig").c;

const SQUARE_SIZE = 20;
const screenWidth: c_int = 800;
const screenHeight: c_int = 450;
const FRAMERATE = 60;

const MAXROWS = 22;
const MAXCOLS = 10;
const LEFTSIDEPANEL = 20; // character width
const RIGHTSIDEPANEL = 20; // character width
const BUFFERSIZE = 4096;
const LOCKRATE = 30; // every 30 frames for 500 ms
const DAS = 10; // 10 delayed auto shift
const ARR = 2; // 2 frames auto repeat rate
const LINESFORLEVELUP = 10;

pub const State = Matrix(MAXROWS, MAXCOLS);

pub const Game = struct{

    state: State,
    active_tetramino: Tetramino,
    hold_tetramino: ?u8,
    tetramino_num: u64,
    tetramino_seq: [7]u8,
    rand: *std.Random,
    das_count: u8,
    frames_for_drop: u8, // the number of frames before the tetramino drops by one
    frame_until_lock: u8,
    frame_until_drop: u8,
    drop_speed_counter: u8,
    in_lock_delay: bool,
    lines_cleared: u64,
    level_sub_one: u64, // level minus one
    score: u64,
    menu: menu.Menu,
    imap: InputMapping,
    running: bool,
    just_held: bool,
    
    pub fn init(rand: *std.Random, imap: *InputMapping) Game {
        var buffer = [_]u8{'I', 'O', 'J', 'L', 'T', 'S', 'Z'};
        rand.shuffle(u8, &buffer);
        return .{
            .state = State.init(),
            .active_tetramino = Tetramino.init(buffer[0]),
            .hold_tetramino = null,
            .tetramino_num = 0,
            .tetramino_seq = buffer,
            .rand = rand, 
            .das_count = 0, // frames until delayed auto shift 
            .frames_for_drop = FRAMERATE, // 1 sec
            .frame_until_lock = 0,
            .frame_until_drop = 0,
            .drop_speed_counter = 0,
            .in_lock_delay = false,
            .lines_cleared = 0,
            .level_sub_one = 0,
            .score = 0,
            .menu = menu.Menu.init(),
            .imap = imap.*,
            .running = true,
            .just_held = false,
        };
    }
    
    pub fn reset(self: *Game) void {
        self.state = State.init();
        self.tetramino_num = 0;
        self.das_count = 0;
        self.shufflePieces();
        self.active_tetramino = Tetramino.init(self.tetramino_seq[0]);
        self.hold_tetramino = null;
        self.frames_for_drop = FRAMERATE;
        self.frame_until_lock = 0;
        self.frame_until_drop = 0;
        self.drop_speed_counter = 0;
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
                    }
                    if (c.IsKeyPressed(self.imap.right) and !self.rightBlocked()) {
                        self.active_tetramino.move_right();
                    }
                    if (c.IsKeyDown(self.imap.left) and !self.leftBlocked()) {
                        self.das_count += 1;
                        if (self.das_count > DAS and (((self.das_count - DAS) % ARR) == 0)) {
                            self.active_tetramino.move_left();
                        }
                    }
                    if (c.IsKeyDown(self.imap.right) and !self.rightBlocked()) {
                        self.das_count += 1;
                        if (self.das_count > DAS and (((self.das_count - DAS) % ARR) == 0)) {
                            self.active_tetramino.move_right();
                        }
                    }
                    if (c.IsKeyReleased(self.imap.left)) {
                        self.das_count = 0;
                    }
                    if (c.IsKeyReleased(self.imap.right)) {
                        self.das_count = 0;
                    }
                    if (c.IsKeyDown(self.imap.soft_drop)) {
                        if (!self.downBlocked() and ((self.drop_speed_counter % 3) == 0)) {
                            self.active_tetramino.move_down();
                            self.score += 1;
                        } else {
                            self.lockDelay();
                        }
                    }
                    if (c.IsKeyReleased(self.imap.soft_drop)) {
                        self.drop_speed_counter = 0;
                    }
                    if (c.IsKeyPressed(self.imap.hard_drop)) {
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
                    if (c.IsKeyPressed(self.imap.rotCW)) {
                        const opt_wall_kick = self.superRotationSystem(.CW);
                        if (opt_wall_kick) |wall_kick| {
                            self.active_tetramino.rot_CW(wall_kick);
                            self.in_lock_delay = false;
                        }
                    }
                    if (c.IsKeyPressed(self.imap.rotCCW)) {
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

                    self.frame_until_drop += 1;
                    const drop_elapsed = self.frame_until_drop > self.frames_for_drop;
                    // (self.clock.now(io).nanoseconds - self.time_drop
                    // ) > self.timeToDrop;
                    if (drop_elapsed) {
                        if (!self.downBlocked()) {
                            self.active_tetramino.move_down();
                        } else {
                            self.lockDelay();
                        }
                        //self.time_drop = self.clock.now(io).nanoseconds;
                        self.frame_until_drop = 0;
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
            self.frame_until_lock = 0;
        } else {
            self.frame_until_lock += 1;
            const lock_elapsed = self.frame_until_lock > LOCKRATE; 
            //(self.clock.now(io).nanoseconds - self.time_lock) > LOCKTIME;
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
        self.frames_for_drop = @as(
            u8, 
            @intFromFloat(
                FRAMERATE * std.math.pow(f64, (0.8 - level_sub_one * 0.007), level_sub_one)
            )
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

                // y -= 50;     // NOTE: Harcoded position!

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
                if (self.hold_tetramino) |hold| {
                    drawPiece(hold, &x, &y);
                }

                x = controler;
                y += SQUARE_SIZE;
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
                c.DrawText(screen.zero_str, screenWidth/2 - @divFloor(c.MeasureText(screen.zero_str, item_font_size), 2), draw_top_y + 2 * screenWidth / 9 + 0, item_font_size, c.LIGHTGRAY);
                c.DrawText(screen.first_str, screenWidth/2 - @divFloor(c.MeasureText(screen.first_str, item_font_size), 2), draw_top_y + 2 * screenWidth / 9 + 20, item_font_size, c.LIGHTGRAY);
                c.DrawText(screen.second_str, screenWidth/2 - @divFloor(c.MeasureText(screen.second_str, item_font_size), 2), draw_top_y + 2 * screenWidth / 9 + 40, item_font_size, c.LIGHTGRAY);
                c.DrawText(screen.third_str, screenWidth/2 - @divFloor(c.MeasureText(screen.third_str, item_font_size), 2), draw_top_y + 2 * screenWidth / 9 + 60, item_font_size, c.LIGHTGRAY);
                c.DrawText(">", screenWidth/2 - 60, draw_top_y + 2 * screenWidth / 9 + 20 * @intFromEnum(screen.position), item_font_size, c.LIGHTGRAY);
                c.DrawFPS(0, 0);
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
    soft_drop: c_int,
    hard_drop: c_int,
    hold: c_int,
    rotCW: c_int,
    rotCCW: c_int,
    pause: c_int,
    exit: c_int,
};

pub const default_map: InputMapping = .{
    .left = c.KEY_LEFT,
    .right = c.KEY_RIGHT,
    .soft_drop = c.KEY_DOWN,
    .hard_drop = c.KEY_SPACE,
    .hold = c.KEY_LEFT_SHIFT,
    .rotCW = c.KEY_UP,
    .rotCCW = c.KEY_LEFT_CONTROL,
    .pause = c.KEY_ENTER,
    .exit = c.KEY_ESCAPE,
};

const Rotation = enum {
    CW,
    CCW,
};
