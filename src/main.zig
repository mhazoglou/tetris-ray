const std = @import("std");
const Game = @import("game.zig").Game;
const default_map = @import("game.zig").default_map;
const c = @import("c.zig").c;

pub fn main() !void {
    // var gpa = std.heap.DebugAllocator(.{}).init;
    // defer _ = gpa.deinit();
    // const allocator = gpa.allocator();

    // var single_threaded = std.Io.Threaded.init_single_threaded;
    // const io = single_threaded.io();
    // const file_name = "button_config.json";
    // const file = try std.Io.Dir.cwd().openFile(
    //     io,
    //     file_name, 
    //     .{ .mode = .read_write },
    // );
    // defer file.close(io);

    // const file_size = (try file.stat(io)).size;
    // var file_buffer = try allocator.alloc(u8, file_size);
    // defer allocator.free(file_buffer);
    // var file_reader = file.reader(io, file_buffer[0..]);
    // var reader = &file_reader.interface;
    // const json_str = try reader.take(file_size);

    // const parsed = try std.json.parseFromSlice(
    //     tih.InputMapping,
    //     allocator,
    //     json_str,
    //     .{},
    // );
    // defer parsed.deinit();
    // var button_map: tih.InputMapping = parsed.value;

    var button_map = default_map;

    var prng: std.Random.DefaultPrng = .init(blk: {
        var seed: u64 = undefined;
        const buf: []u8 = @ptrCast(@alignCast(&seed));
        _ = std.os.linux.getrandom(buf.ptr, buf.len, 0);
        break :blk seed;
    });
    var rand = prng.random();
    var game = Game.init(&rand, &button_map);

    try game.gameLoop();
}
