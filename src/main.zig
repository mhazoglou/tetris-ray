const std = @import("std");
const Game = @import("game.zig").Game;
const InputMapping = @import("game.zig").InputMapping;
const HighScore = @import("game.zig").HighScore;
const default_map = @import("game.zig").default_map;
const empty_high_score = @import("game.zig").empty_high_score;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var single_threaded = std.Io.Threaded.init_single_threaded;
    const io = single_threaded.io();

    const button_file_name = "button_config.json";
    const button_file = try std.Io.Dir.cwd().openFile(
        io,
        button_file_name, 
        .{ .mode = .read_write },
    );
    defer button_file.close(io);

    const score_file_name = "high_score.bin";
    const score_file = try std.Io.Dir.cwd().openFile(
        io,
        score_file_name, 
        .{ .mode = .read_write },
    );
    defer score_file.close(io);

    const button_file_size: usize = 4096; //(try file.stat(io)).size;
    var button_file_buffer = try allocator.alloc(u8, button_file_size);
    defer allocator.free(button_file_buffer);
    var button_file_reader = button_file.reader(io, button_file_buffer[0..]);
    var button_reader = &button_file_reader.interface;
    const button_json_str = try button_reader.takeDelimiterExclusive(0);

    const score_file_size: usize = 4096; //(try file.stat(io)).size;
    var score_file_buffer = try allocator.alloc(u8, score_file_size);
    defer allocator.free(score_file_buffer);
    var score_file_reader = score_file.reader(io, score_file_buffer[0..]);
    var score_reader = &score_file_reader.interface;
    const score_str = try score_reader.takeDelimiterExclusive(0);

    const button_parsed = try std.json.parseFromSlice(
        InputMapping,
        allocator,
        button_json_str,
        .{},
    );
    defer button_parsed.deinit();
    const button_map: InputMapping = button_parsed.value;

    // _ = score_str;
    // const score: HighScore = empty_high_score; 
    const score = std.mem.bytesToValue(HighScore, score_str.ptr);

    var prng: std.Random.DefaultPrng = .init(blk: {
        var seed: u64 = undefined;
        const clock: std.Io.Clock = .awake;
        const now = clock.now(io);
        const now_micros = now.toMicroseconds();
        seed = @bitCast(now_micros);
        break :blk seed;
    });
    var rand = prng.random();
    var game = Game.init(&rand, button_map, score);

    try game.gameLoop();

    try button_file.setLength(io, 0);
    var button_file_writer = button_file.writer(io, button_file_buffer[0..]);
    const button_writer = &button_file_writer.interface;
    try button_writer.print(
        "{f}", 
        .{std.json.fmt(game.imap, .{.whitespace = .indent_2})}
    );
    try button_writer.flush();

    try score_file.setLength(io, 0);
    var score_file_writer = score_file.writer(io, score_file_buffer[0..]);
    const score_writer = &score_file_writer.interface;
    try score_writer.writeAll(
        std.mem.asBytes(&game.high_score)
    );
    try score_writer.flush();

}
