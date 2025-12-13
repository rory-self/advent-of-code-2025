const std = @import("std");
const utils = @import("utils");

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

    const input_filepath = try utils.getFilepathArg(allocator);
    const beam_splits, const timelines = try simulateBeamSplits(input_filepath, allocator);

    try utils.printToStdout("{d} beam splits. {d} timelines\n", .{ beam_splits, timelines });
}

fn simulateBeamSplits(input_filepath: []const u8, allocator: Allocator) !struct { u16, u64 } {
    const file_contents = try utils.readAllFromFile(input_filepath, allocator);

    var line_it = std.mem.tokenizeScalar(u8, file_contents, '\n');
    const start_pos = findStartPos(&line_it) orelse return error.NoStart;

    var beam_map: BeamMap = .init(allocator);
    try beam_map.putNoClobber(start_pos, 1);

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

fn findStartPos(line_it: *std.mem.TokenIterator(u8, std.mem.DelimiterType.scalar)) ?usize {
   while (line_it.next()) |line| {
        if (std.mem.indexOfScalar(u8, line, START_CHARACTER)) |pos| {
            return pos;
        }
   }

   return null;
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
