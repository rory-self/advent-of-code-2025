const std = @import("std");

const TEST_INPUT_PATH = "test.txt";
const START_CHARACTER = 'S';
const SPLITTER_CHARACTER = '^';
const IO_BUF_SIZE = 128;

const Allocator = std.mem.Allocator;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    _ = args.skip();
    const input_filepath = args.next() orelse return error.MissingArgument;

    const beam_splits = try calculateBeamSplits(input_filepath, allocator);

    const stdout_file = std.fs.File.stdout();
    var writer_buf: [IO_BUF_SIZE]u8 = undefined;
    var stdout_writer = stdout_file.writer(&writer_buf);
    const stdout_interface = &stdout_writer.interface;
    try stdout_interface.print("{d} beam splits.\n", .{beam_splits});
    try stdout_interface.flush();
}

fn calculateBeamSplits(input_filepath: []const u8, allocator: Allocator) !u16 {
    const file = try std.fs.cwd().openFile(input_filepath, .{ .mode = .read_only });
    defer file.close();

    const file_length = try file.getEndPos();
    const file_contents = try allocator.alloc(u8, file_length);
    _ = try file.readAll(file_contents);

    var line_it = std.mem.tokenizeScalar(u8, file_contents, '\n');
    const start_pos = find_start: while (line_it.next()) |line| {
        if (std.mem.indexOfScalar(u8, line, START_CHARACTER)) |pos| {
            break :find_start pos;
        } 
    } else {
        return error.NoStart;
    };

    var beam_positions: std.AutoArrayHashMap(usize, void) = .init(allocator);
    try beam_positions.put(start_pos, {});

    var beam_splits: u16 = 0;
    while (line_it.next()) |line| {
        const curr_beam_positions = try allocator.dupe(usize, beam_positions.keys()); 

        for (curr_beam_positions) |beam_pos| {
            if (line[beam_pos] != SPLITTER_CHARACTER) {
                continue;
            }

            try beam_positions.put(beam_pos - 1, {});
            try beam_positions.put(beam_pos + 1, {});
            if (!beam_positions.swapRemove(beam_pos)) {
                return error.ArrayHashMapFail;
            }
            beam_splits += 1;
        }
    }

    return beam_splits;
}

test "Example" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const beam_splits = try calculateBeamSplits(TEST_INPUT_PATH, allocator);
    try std.testing.expect(beam_splits == 21);
}

