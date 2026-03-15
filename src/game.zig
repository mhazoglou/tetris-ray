const std = @import("std");
const Io = std.Io;
const posix = std.posix;
const fs = std.fs;
const File = std.fs.File;
const tih = @import("termios_input_handler.zig");
const Tetramino = @import("tetramino.zig").Tetramino;

pub fn main() !void {
    var prng: std.Random.DefaultPrng = .init(blk: {
        var seed: u64 = undefined;
        try posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    var rand = prng.random();
    var game = Game.init(&rand);

    try game.gameLoop();
}

const MAXROWS = 22;
const MAXCOLS = 10;
const BUFFERSIZE = 4096;
const LOCKTIME = 500_000_000; // 500 ms

pub const State = Matrix(MAXROWS, MAXCOLS);

pub const Game = struct{

    active_tetramino: Tetramino,
    state: State,
    tetramino_num: u64,
    tetramino_seq: [7]u8,
    rand: *std.Random,
    timeToDrop: u64, // time in ns to move one down inverse of gravity
    
    pub fn init(rand: *std.Random) Game {
        var buffer = [_]u8{'I', 'O', 'J', 'L', 'T', 'S', 'Z'};
        rand.shuffle(u8, &buffer);
        return .{
            .active_tetramino = Tetramino.init(buffer[0]),
            .state = State.init(),
            .tetramino_num = 0,
            .tetramino_seq = buffer,
            .rand = rand,
            .timeToDrop = 200_000_000,
        };
    }

    pub fn gameLoop(self: *Game) !void {
        var running: bool = true;

        const tty_file = try fs.openFileAbsolute("/dev/tty", .{});
        defer tty_file.close();
        const tty_fd = tty_file.handle;

        const old_settings = try posix.tcgetattr(tty_fd);

        // Set non-blocking (polling)
        var new_settings: posix.termios = old_settings;
        new_settings.lflag.ICANON = false;
        new_settings.lflag.ECHO = false;
        new_settings.cc[6] = 0; //VMIN
        new_settings.cc[5] = 0; //VTIME
        new_settings.lflag.ECHOE = false;

        _ = try posix.tcsetattr(tty_fd, posix.TCSA.NOW, new_settings);

        var stdin_buffer: [BUFFERSIZE]u8 = undefined;
        var stdout_buffer: [BUFFERSIZE]u8 = undefined;

        var stdin_reader = File.stdin().reader(&stdin_buffer);
        const reader = &stdin_reader.interface;
        var stdout_writer = File.stdout().writer(&stdout_buffer);
        const writer = &stdout_writer.interface;

        std.debug.print("{f}", .{self});
        var timer = std.time.Timer.start() catch unreachable;
        var time_lock = timer.read();
        var time_drop = timer.read();
        var in_lock_delay = false;
        while (running) {
            var input = try tih.InputHandler(reader, writer);

            switch (input) {
                .LeftButton => {
                    if (!self.leftBlocked()) {
                        self.active_tetramino.move_left();
                        std.debug.print("{f}", .{self});
                    }
                },
                .RightButton => {
                    if (!self.rightBlocked()) {
                        self.active_tetramino.move_right();
                        std.debug.print("{f}", .{self});
                    }
                },
                .DownButton => {
                    if (!self.downBlocked()) {
                        self.active_tetramino.move_down();
                        std.debug.print("{f}", .{self});
                    }
                },
                .RotCWButton => {
                    const opt_wall_kick = self.superRotationSystem(tih.UserInput.RotCWButton);
                    if (opt_wall_kick) |wall_kick| {
                        self.active_tetramino.rot_CW(wall_kick);
                        in_lock_delay = false;
                        std.debug.print("{f}", .{self});
                    }
                },
                .RotCCWButton => {
                    const opt_wall_kick = self.superRotationSystem(tih.UserInput.RotCCWButton);
                    if (opt_wall_kick) |wall_kick| {
                        self.active_tetramino.rot_CCW(wall_kick);
                        in_lock_delay = false;
                        std.debug.print("{f}", .{self});
                    }
                },
                .PauseButton => {
                    var paused = true;
                    while (paused) {
                        // blocking 
                        new_settings.cc[6] = 1; //VMIN
                        _ = try posix.tcsetattr(tty_fd, posix.TCSA.NOW, new_settings);
                        input = try tih.InputHandler(reader, writer);
                        switch (input) {
                            .PauseButton => {
                                new_settings.cc[6] = 0; //VMIN
                                _ = try posix.tcsetattr(tty_fd, posix.TCSA.NOW, new_settings);
                                paused = false;
                            },
                            else => {},
                        }
                    }
                },
                .ExitGameButton => running = false,
                else => {},
            }

            if ((timer.read() - time_drop) > self.timeToDrop) {
                if (!self.downBlocked()) {
                    self.active_tetramino.move_down();
                } else {
                    if (!in_lock_delay) {
                        in_lock_delay = true;
                        time_lock = timer.read();
                    } else {
                        if ((timer.read() - time_lock) > LOCKTIME) {
                            self.lockTetramino();
                            self.spawnTetramino();
                            in_lock_delay = false;
                            timer.reset();
                        }
                    }
                }
                std.debug.print("{f}", .{self});
                time_drop = timer.read();
            }
        } else {
            _ = try posix.tcsetattr(tty_fd, posix.TCSA.NOW, old_settings);
        }
    }

    fn shufflePieces(self: *Game) void {
        self.rand.shuffle(u8, &self.tetramino_seq);
    }

    fn spawnTetramino(self: *Game) void {
        self.tetramino_num += 1;
        const idx = self.tetramino_num % 7;
        if (idx == 0) {
            self.shufflePieces();
        }
        self.active_tetramino = Tetramino.init(self.tetramino_seq[idx]);
    }

    fn lockTetramino(self: *Game) void {
        const block_pos_arr = self.active_tetramino.get_blocks();
        // initialize with max usize by wrapping subtraction
        var row_full_arr: [4]usize = .{ @as(usize, 0) -% 1 } ** 4;
        var idx: usize = 0;
        for (block_pos_arr) |block_pos| {
            const row = @as(usize, @intCast(block_pos[0]));
            const col = @as(usize, @intCast(block_pos[1]));
            self.state.update(row, col, true);
            if (self.state.checkRowFull(row)) {
                row_full_arr[idx] = row;
                idx += 1;
            }
        }
        std.mem.sort(usize, &row_full_arr, {}, comptime std.sort.asc(usize));
        for (0..idx) |i| {
            self.state.shiftRowsDown(row_full_arr[i]);
        }
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

    fn checkOverlap(self: *const Game, block_pos: [4][2]isize) bool {
        const state = self.state;
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
            any_overlap = any_overlap or state.array[@as(usize, @intCast(row))][@as(usize, @intCast(col))];
        }
        return any_overlap;
    }

    fn superRotationSystem(self: *const Game, input: tih.UserInput) ?[2]isize {
        const tetra_i = self.active_tetramino;
        switch (input) {
            .RotCWButton => {
                const tetra_o = tetra_i.true_rot_CW();
                return tetra_i.superRotationSystemLogic(tetra_o, self.state);
            },
            .RotCCWButton => {
                const tetra_o = tetra_i.true_rot_CCW();
                return tetra_i.superRotationSystemLogic(tetra_o, self.state);
            },
            else => unreachable,
        }
    }

    pub fn format(self: *Game, writer: *Io.Writer) !void {

        try writer.print("\x1B[H\x1B[2J\u{250F}", .{});
        for (0..self.state.columns) |_| {
            try writer.print("\u{2501}" ** 2, .{});
        }
        try writer.print("\u{2513}\n", .{});

        for (2..self.state.rows) |row| {
            try writer.print("\u{2503}", .{});
            for (0..self.state.columns) |col| {
                if (self.state.array[row][col] or self.active_tetramino.isOccupied(row, col)
            ) {
                    try writer.print("\u{2588}" ** 2, .{});
                } else {
                    try writer.print("  ", .{});
                }
            }
            try writer.print("\u{2503}\n", .{});
        }

        try writer.print("\u{2517}", .{});
        for (0..self.state.columns) |_| {
            try writer.print("\u{2501}" ** 2, .{});
        }
        try writer.print("\u{251B}\n", .{});

    }

};

pub fn Matrix(rows: usize, columns: usize) type {
    return struct{
        rows: usize,
        columns: usize,
        array: [rows][columns]bool,

        const Self = @This();

        pub fn init() Self {
            const array: [rows][columns]bool = .{ .{false} ** columns} ** rows;
            return .{
                .rows = rows,
                .columns = columns,
                .array = array,
            };
        }

        pub fn update(self: *Self, row: usize, col: usize, val: bool) void {
            self.array[row][col] = val;
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
                r -= 1;
            }
            self.array[0] = .{false} ** MAXCOLS;
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

        pub fn format(self: *Self, writer: *Io.Writer) !void {

            try writer.print("\u{250F}", .{});
            for (0..self.columns) |_| {
                try writer.print("\u{2501}" ** 2, .{});
            }
            try writer.print("\u{2513}\n", .{});

            for (0..self.rows) |row| {
                try writer.print("\u{2503}", .{});
                for (0..self.columns) |col| {
                    if (self.array[row][col]) {
                        try writer.print("\u{2588}" ** 2, .{});
                    } else {
                        try writer.print("  ", .{});
                    }
                }
                try writer.print("\u{2503}\n", .{});
            }

            try writer.print("\u{2517}", .{});
            for (0..self.columns) |_| {
                try writer.print("\u{2501}" ** 2, .{});
            }
            try writer.print("\u{251B}\n", .{});

        }
    };
}
