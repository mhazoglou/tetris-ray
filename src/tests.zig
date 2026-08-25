const std = @import("std");
const Tetramino = @import("tetramino.zig").Tetramino;
const menu = @import("menu.zig");
const game = @import("game.zig");
const c = @import("c");

test "test left input" {
    const settings = game.default_settings;
    const high_score = game.empty_high_score;
    var prng: std.Random.DefaultPrng = .init(42);
    var rand = prng.random();

    const game_obj = game.Game.init(&rand, settings, high_score);

    const initial_pos = game_obj.active_tetramino.get_blocks();

    const final_pos = game_obj.active_tetramino.get_blocks();

    for (initial_pos, final_pos) |i, f| {
        try std.testing.expect(i[1]  == f[1]);
    }
}
