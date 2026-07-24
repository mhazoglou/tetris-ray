const std = @import("std");
const Game = @import("game.zig").Game;
const Settings = @import("game.zig").Settings;
const HighScore = @import("game.zig").HighScore;
const default_settings = @import("game.zig").default_settings;
const empty_high_score = @import("game.zig").empty_high_score;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var single_threaded = std.Io.Threaded.init_single_threaded;
    const io = single_threaded.io();

    const settings_file_name = "settings_config.json";
    const settings_file = try std.Io.Dir.cwd().openFile(
        io,
        settings_file_name, 
        .{ .mode = .read_write },
    );
    defer settings_file.close(io);

    const score_file_name = "high_score.bin";
    const score_file = try std.Io.Dir.cwd().openFile(
        io,
        score_file_name, 
        .{ .mode = .read_write },
    );
    defer score_file.close(io);

    const settings_file_size: usize = 4096; //(try file.stat(io)).size;
    var settings_file_buffer = try allocator.alloc(u8, settings_file_size);
    defer allocator.free(settings_file_buffer);
    var settings_file_reader = settings_file.reader(io, settings_file_buffer[0..]);
    var settings_reader = &settings_file_reader.interface;
    const settings_json_str = try settings_reader.takeDelimiterExclusive(0);

    const score_file_size: usize = 4096; //(try file.stat(io)).size;
    var score_file_buffer = try allocator.alloc(u8, score_file_size);
    defer allocator.free(score_file_buffer);
    var score_file_reader = score_file.reader(io, score_file_buffer[0..]);
    var score_reader = &score_file_reader.interface;
    const score_str = try score_reader.takeDelimiterExclusive(0);

    const settings_parsed = try std.json.parseFromSlice(
        Settings,
        allocator,
        settings_json_str,
        .{},
    );
    defer settings_parsed.deinit();
    const settings: Settings = settings_parsed.value;
    // const settings: Settings = default_settings;

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
    var game = Game.init(&rand, settings, //settings_map, 
        score);

    try game.gameLoop();

    try settings_file.setLength(io, 0);
    var settings_file_writer = settings_file.writer(io, settings_file_buffer[0..]);
    const settings_writer = &settings_file_writer.interface;
    try settings_writer.print(
        "{f}", 
        .{std.json.fmt(game.settings, .{.whitespace = .indent_2})}
    );
    try settings_writer.flush();

    try score_file.setLength(io, 0);
    var score_file_writer = score_file.writer(io, score_file_buffer[0..]);
    const score_writer = &score_file_writer.interface;
    try score_writer.writeAll(
        std.mem.asBytes(&game.high_score)
    );
    try score_writer.flush();

}
