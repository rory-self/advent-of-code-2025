const std = @import("std");

const TEST_INPUT_PATH = "test.txt";
const START_CHARACTER = 'S';
const SPLITTER_CHARACTER = '^';
const IO_BUF_SIZE = 128;

const Allocator = std.mem.Allocator;
const BeamMap = std.AutoArrayHashMap(usize, u64);

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    _ = args.skip();
    const input_filepath = args.next() orelse return error.MissingArgument;

    const beam_splits, const timelines = try simulateBeamSplits(input_filepath, allocator);

    const stdout_file = std.fs.File.stdout();
    var writer_buf: [IO_BUF_SIZE]u8 = undefined;
    var stdout_writer = stdout_file.writer(&writer_buf);
    const stdout_interface = &stdout_writer.interface;
    try stdout_interface.print("{d} beam splits.\n", .{beam_splits});
    try stdout_interface.print("{d} timelines.\n", .{timelines});
    try stdout_interface.flush();
}

fn simulateBeamSplits(input_filepath: []const u8, allocator: Allocator) !struct { u16, u64 } {
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

    var beam_map: BeamMap = .init(allocator);
    try beam_map.put(start_pos, 1);

    var beam_splits: u16 = 0;
    while (line_it.next()) |line| {
        const curr_beam_positions = try allocator.dupe(usize, beam_map.keys());
        const incident_timelines = try allocator.dupe(u64, beam_map.values());

        for (curr_beam_positions, incident_timelines) |beam_pos, prev_timelines| {
            if (line[beam_pos] != SPLITTER_CHARACTER) {
                continue;
            }

            try beamMapInsert(&beam_map, beam_pos - 1, prev_timelines);
            try beamMapInsert(&beam_map, beam_pos + 1, prev_timelines);
            if (!beam_map.swapRemove(beam_pos)) {
                return error.ArrayHashMapFail;
            }
            beam_splits += 1;
        }
    }

    var timelines: u64 = 0;
    for (beam_map.values()) |beam_timelines| {
        timelines += beam_timelines;
    }

    return .{ beam_splits, timelines };
}

fn beamMapInsert(beam_map: *BeamMap, beam_pos: usize, new_timelines: u64) !void {
    if (beam_map.get(beam_pos)) |curr_timelines| {
        try beam_map.put(beam_pos, new_timelines + curr_timelines);
        return;
    }

    try beam_map.putNoClobber(beam_pos, new_timelines);
}

test "Example" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const beam_splits, const timelines = try simulateBeamSplits(TEST_INPUT_PATH, allocator);
    try std.testing.expect(beam_splits == 21);
    try std.testing.expect(timelines == 40);
}
