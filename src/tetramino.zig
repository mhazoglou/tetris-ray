const State = @import("game.zig").State;
const c = @import("c.zig").c;

pub const Tetramino = union(enum) {
    I: I_piece,
    O: O_piece,
    J: J_piece,
    L: L_piece,
    T: T_piece,
    S: S_piece,
    Z: Z_piece,

    pub fn init(char: u8) Tetramino {
        return switch (char) {
            'I' => .{ .I = I_piece.init(1, 4, .{ .{ 0, -1}, .{ 0,  1}, .{ 0,  2} }, c.SKYBLUE)},
            'O' => .{ .O = O_piece.init(0, 4, .{ .{ 0,  1}, .{ 1,  0}, .{ 1,  1} }, c.YELLOW)},
            'J' => .{ .J = J_piece.init(1, 4, .{ .{-1, -1}, .{ 0, -1}, .{ 0,  1} }, c.BLUE)},
            'L' => .{ .L = L_piece.init(1, 4, .{ .{ 0, -1}, .{ 0,  1}, .{-1,  1} }, c.ORANGE)},
            'T' => .{ .T = T_piece.init(1, 4, .{ .{ 0, -1}, .{-1,  0}, .{ 0,  1} }, c.PURPLE)},
            'S' => .{ .S = S_piece.init(1, 4, .{ .{ 0, -1}, .{-1,  0}, .{-1,  1} }, c.GREEN)},
            'Z' => .{ .Z = Z_piece.init(1, 4, .{ .{-1, -1}, .{-1,  0}, .{ 0,  1} }, c.RED)},
            else => unreachable, 
        };
    }

    pub fn true_rot_CW(self: *const Tetramino) Tetramino {
        return switch (self.*) {
            .I => |piece| .{ .I = piece.true_rot_CW() },
            .O => |piece| .{ .O = piece.true_rot_CW() },
            .J => |piece| .{ .J = piece.true_rot_CW() },
            .L => |piece| .{ .L = piece.true_rot_CW() },
            .T => |piece| .{ .T = piece.true_rot_CW() },
            .S => |piece| .{ .S = piece.true_rot_CW() },
            .Z => |piece| .{ .Z = piece.true_rot_CW() },
        };
    }

    pub fn true_rot_CCW(self: *const Tetramino) Tetramino {
        return switch (self.*) {
            .I => |piece| .{ .I = piece.true_rot_CCW() },
            .O => |piece| .{ .O = piece.true_rot_CCW() },
            .J => |piece| .{ .J = piece.true_rot_CCW() },
            .L => |piece| .{ .L = piece.true_rot_CCW() },
            .T => |piece| .{ .T = piece.true_rot_CCW() },
            .S => |piece| .{ .S = piece.true_rot_CCW() },
            .Z => |piece| .{ .Z = piece.true_rot_CCW() },
        };
    }

    pub fn rot_CW(self: *Tetramino, wall_kick: [2]isize) void {
        switch (self.*) {
            .O => {},
            .I, .J, .L, .T, .S, .Z => |*piece| piece.rot_CW(wall_kick),
        }
    }

    pub fn rot_CCW(self: *Tetramino, wall_kick: [2]isize) void {
        switch (self.*) {
            .O => {},
            .I, .J, .L, .T, .S, .Z => |*piece| piece.rot_CCW(wall_kick),
        }
    }

    pub fn move_down(self: *Tetramino) void {
        switch (self.*) {
            .I, .O, .J, .L, .T, .S, .Z => |*piece| piece.move_down(),
        }
    }

    pub fn move_left(self: *Tetramino) void {
        switch (self.*) {
            .I, .O, .J, .L, .T, .S, .Z => |*piece| piece.move_left(),
        }
    }

    pub fn move_right(self: *Tetramino) void {
        switch (self.*) {
            .I, .O, .J, .L, .T, .S, .Z => |*piece| piece.move_right(),
        }
    }

    pub fn get_blocks(self: *const Tetramino) [4][2]isize {
        return switch (self.*) {
            .I, .O, .J, .L, .T, .S, .Z => |piece| piece.get_blocks(),
        };
    }

    pub fn get_color(self: Tetramino) c.Color {
        return switch (self) {
            .I, .O, .J, .L, .T, .S, .Z => |piece| piece.color,
        };
    }

    pub fn isOccupied(self: *const Tetramino, col: usize, row: usize) bool {
        return switch (self.*) {
            .I, .O, .J, .L, .T, .S, .Z => |piece| piece.isOccupied(row, col),
        };
    }

// J, L, S, T, Z Tetromino Offset Data
//      Offset 1  Offset 2  Offset 3  Offset 4  Offset 5
// 0 .{ .{ 0, 0}, .{ 0, 0}, .{ 0, 0}, .{ 0, 0}, .{ 0, 0} }
// R .{ .{ 0, 0}, .{ 0, 1}, .{ 1, 1}, .{-2, 0}, .{-2, 1} }
// 2 .{ .{ 0, 0}, .{ 0, 0}, .{ 0, 0}, .{ 0, 0}, .{ 0, 0} }
// L .{ .{ 0, 0}, .{ 0,-1}, .{ 1,-1}, .{-2, 0}, .{-2,-1} }

// I Tetromino Offset Data
//      Offset 1  Offset 2  Offset 3  Offset 4  Offset 5
// 0 .{ .{ 0, 0}, .{ 0,-1}, .{ 0, 2}, .{ 0,-1}, .{ 0, 2} }
// R .{ .{ 0,-1}, .{ 0, 0}, .{ 0, 0}, .{-1, 0}, .{ 2, 0} }
// 2 .{ .{-1,-1}, .{-1, 1}, .{-1,-2}, .{ 0, 1}, .{ 0,-2} }
// L .{ .{-1, 0}, .{-1, 0}, .{-1, 0}, .{ 1, 0}, .{-2, 0} }

//     O Tetromino Offset Data
//   Offset 1 Offset 2 Offset 3 Offset 4 Offset 5
// 0 .{ 0, 0}, No further offset data required
// R .{ 1, 0},
// 2 .{ 1,-1},
// L .{ 0,-1},

    pub fn offset(self: *const Tetramino) [5][2]isize {
        return switch (self.*) {
            .I => |piece| {
                return switch (piece.orientation) {
                    .Spawn =>            .{ .{ 0, 0}, .{ 0,-1}, .{ 0, 2}, .{ 0,-1}, .{ 0, 2} },
                    .Clockwise =>        .{ .{ 0,-1}, .{ 0, 0}, .{ 0, 0}, .{-1, 0}, .{ 2, 0} },
                    .DoubleRotated => .{ .{-1,-1}, .{-1, 1}, .{-1,-2}, .{ 0, 1}, .{ 0,-2} },
                    .CounterClockwise =>    .{ .{-1, 0}, .{-1, 0}, .{-1, 0}, .{ 1, 0}, .{-2, 0} },
                };
            },
            .O => |piece| {
                return switch (piece.orientation) {
                    .Spawn =>            .{ .{ 0, 0} } ** 5,
                    .Clockwise =>        .{ .{ 1, 0} } ** 5,
                    .DoubleRotated => .{ .{ 1,-1} } ** 5,
                    .CounterClockwise =>    .{ .{ 0,-1} } ** 5,
                };
            },
            .J, .L, .T, .S, .Z => |piece| {
                return switch (piece.orientation) {
                    .Spawn =>            .{ .{ 0, 0}, .{ 0, 0}, .{ 0, 0}, .{ 0, 0}, .{ 0, 0} },
                    .Clockwise =>        .{ .{ 0, 0}, .{ 0, 1}, .{ 1, 1}, .{-2, 0}, .{-2, 1} },
                    .DoubleRotated => .{ .{ 0, 0}, .{ 0, 0}, .{ 0, 0}, .{ 0, 0}, .{ 0, 0} },
                    .CounterClockwise =>    .{ .{ 0, 0}, .{ 0,-1}, .{ 1,-1}, .{-2, 0}, .{-2,-1} },
                };
            },
        };
    }

    pub fn superRotationSystemLogic(self: Tetramino, propose_rot_tetra: Tetramino, state: State) ?[2]isize {
        const offset_arr_i = self.offset();
        const tmp_blk_pos = propose_rot_tetra.get_blocks();
        const offset_arr_o = propose_rot_tetra.offset();
        var offset_blk_pos: [4][2]isize = undefined;
        var wall_kick_arr: [5][2]isize = undefined;
        for (0..wall_kick_arr.len) |i| {
            wall_kick_arr[i][0] = offset_arr_i[i][0] - offset_arr_o[i][0];
            wall_kick_arr[i][1] = offset_arr_i[i][1] - offset_arr_o[i][1];
            for (0..offset_blk_pos.len) |j| {
                offset_blk_pos[j][0] = tmp_blk_pos[j][0] + wall_kick_arr[i][0];
                offset_blk_pos[j][1] = tmp_blk_pos[j][1] + wall_kick_arr[i][1];
            }
            if (~state.checkOverlap(offset_blk_pos)) {
                return wall_kick_arr[i];
            }
        } else {
            return null;
        }
    } 

};

pub const Orientation = enum{
    Spawn,
    Clockwise,
    CounterClockwise,
    DoubleRotated,
};

pub fn GenericPiece() type {
    return struct{
        const Self = @This();

        row: isize,
        col: isize,
        orientation: Orientation,
        block_pos: [3][2]isize,
        color: c.Color,

        // block_pos is based on a grid with the pivot of the piece at
        // row index 0 and column index 0 which is always assumed to be 
        // included, the "I" tetramino will be given by:
        // .{ .{0, -1}, .{0, 1}, .{0, 2} }
        pub fn init(row: isize, col: isize, block_pos: [3][2]isize, color: c.Color) Self {
            var tmp_blk_pos: [3][2]isize = undefined;
            for (0..tmp_blk_pos.len) |i| {
                tmp_blk_pos[i][1] = col + block_pos[i][1];
                tmp_blk_pos[i][0] = row + block_pos[i][0];
            }
            return .{
                .row = row,
                .col = col,
                .orientation = .Spawn,
                .block_pos = tmp_blk_pos,
                .color = color,
            };
        }

        pub fn true_rot_CW(self: *const Self) Self {
            var tmp_blk_pos: [3][2]isize = undefined;
            const end = tmp_blk_pos.len;
            for (0..end) |i| {
                tmp_blk_pos[i][1] = self.col + self.row - self.block_pos[i][0];
                tmp_blk_pos[i][0] = self.block_pos[i][1] + self.row - self.col;
            }
            const orient: Orientation = switch (self.orientation) {
                .Spawn => .Clockwise,
                .Clockwise => .DoubleRotated,
                .DoubleRotated => .CounterClockwise,
                .CounterClockwise => .Spawn,
            };
            return .{
                .row = self.row,
                .col = self.col,
                .orientation = orient,
                .block_pos = tmp_blk_pos,
                .color = self.color,
            };
        }

        pub fn true_rot_CCW(self: *const Self) Self {
            var tmp_blk_pos: [3][2]isize = undefined;
            const end = tmp_blk_pos.len;
            for (0..end) |i| {
                tmp_blk_pos[i][1] = self.block_pos[i][0] + self.col - self.row;
                tmp_blk_pos[i][0] = self.row + self.col - self.block_pos[i][1];
            }
            const orient: Orientation = switch (self.orientation) {
                .Spawn => .CounterClockwise,
                .Clockwise => .Spawn,
                .DoubleRotated => .Clockwise,
                .CounterClockwise => .DoubleRotated,
            };
            return .{
                .row = self.row,
                .col = self.col,
                .orientation = orient,
                .block_pos = tmp_blk_pos,
                .color = self.color,
            };
        }

        pub fn rot_CW(self: *Self, wall_kick: [2]isize) void {
            self.row = self.row + wall_kick[0];
            self.col = self.col + wall_kick[1];
            for (&self.block_pos) |*pos| {
                pos[0] = pos[0] + wall_kick[0];
                pos[1] = pos[1] + wall_kick[1];
            }
            var tmp_blk_pos: [3][2]isize = undefined;
            for (0..tmp_blk_pos.len) |i| {
                tmp_blk_pos[i][1] = self.col + self.row - self.block_pos[i][0];
                tmp_blk_pos[i][0] = self.block_pos[i][1] + self.row - self.col;
            }
            self.block_pos = tmp_blk_pos;
            switch (self.orientation) {
                .Spawn => {
                    self.orientation = .Clockwise;
                },
                .Clockwise => self.orientation = .DoubleRotated,
                .DoubleRotated => self.orientation = .CounterClockwise,
                .CounterClockwise => self.orientation = .Spawn,
            }
        }

        pub fn rot_CCW(self: *Self, wall_kick: [2]isize) void {
            self.row = self.row + wall_kick[0];
            self.col = self.col + wall_kick[1];
            for (&self.block_pos) |*pos| {
                pos[0] = pos[0] + wall_kick[0];
                pos[1] = pos[1] + wall_kick[1];
            }
            var tmp_blk_pos: [3][2]isize = undefined;
            for (0..tmp_blk_pos.len) |i| {
                tmp_blk_pos[i][1] = self.block_pos[i][0] + self.col - self.row;
                tmp_blk_pos[i][0] = self.row + self.col - self.block_pos[i][1];
            }
            self.block_pos = tmp_blk_pos;
            switch (self.orientation) {
                .Spawn => self.orientation = .CounterClockwise,
                .Clockwise => self.orientation = .Spawn,
                .DoubleRotated => self.orientation = .Clockwise,
                .CounterClockwise => self.orientation = .DoubleRotated,
            }
        }

        pub fn move_down(self: *Self) void {
            self.row += 1;
            for (0..self.block_pos.len) |i| {
                self.block_pos[i][0] += 1;
            }
        }

        pub fn move_left(self: *Self) void {
            self.col -= 1;
            for (0..self.block_pos.len) |i| {
                self.block_pos[i][1] -= 1;
            }
        }

        pub fn move_right(self: *Self) void {
            self.col += 1;
            for (0..self.block_pos.len) |i| {
                self.block_pos[i][1] += 1;
            }
        }

        pub fn get_blocks(self: *const Self) [4][2]isize {
            return .{ 
                self.block_pos[0],
                .{self.row, self.col}, 
                self.block_pos[1],
                self.block_pos[2],
            };
        }

        pub fn isOccupied(self: *const Self, col: usize, row: usize) bool {
            const blockpos = self.get_blocks();

            inline for (0..blockpos.len) |i| {
                if ((blockpos[i][1] == col) and (blockpos[i][0] == row)) {
                    return true;
                }
            } else {
                return false;
            }
        }
    };
}

const I_piece = GenericPiece();
const O_piece = GenericPiece();
const J_piece = GenericPiece();
const L_piece = GenericPiece();
const T_piece = GenericPiece();
const S_piece = GenericPiece();
const Z_piece = GenericPiece();

pub fn u_plus_i(u: usize, i: isize) usize {
    var nu: usize = u;
    if (i < 0) {
        nu -%= @intCast(-i);
    } else {
        nu +%= @intCast(i);
    }
    return nu;
}
