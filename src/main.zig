const std = @import("std");
const Game = @import("game.zig").Game;
const tih = @import("termios_input_handler.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file_name = "button_config.json";
    const file = try std.fs.cwd().openFile(
        file_name, 
        .{ .mode = .read_write },
    );
    defer file.close();

    const file_size = (try file.stat()).size;
    var file_buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(file_buffer);
    var file_reader = file.reader(file_buffer[0..]);
    var reader = &file_reader.interface;
    const json_str = try reader.take(file_size);

    const parsed = try std.json.parseFromSlice(
        tih.InputMapping,
        allocator,
        json_str,
        .{},
    );
    defer parsed.deinit();
    var button_map: tih.InputMapping = parsed.value;

    var prng: std.Random.DefaultPrng = .init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    var rand = prng.random();
    var game = Game.init(&rand, &button_map);

    try game.gameLoop();
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
