const std = @import("std");
const utils = @import("utils");

const TEST_INPUT_PATH = "test.txt";
const START_CHARACTER = 'S';
const SPLITTER_CHARACTER = '^';
const IO_BUF_SIZE = 128;

const Allocator = std.mem.Allocator;
const NumTimelinesType = u64;
const NumSplitsType = u16;
const BeamSimulationResult = struct {
    num_splits: NumSplitsType,
    num_timelines: NumTimelinesType,
};
const BeamMap = std.AutoArrayHashMap(usize, NumTimelinesType);

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const input_filepath = try utils.getFilepathArg(allocator);

    const sim_result = try simulateBeamSplits(input_filepath, allocator);
    const num_splits = sim_result.num_splits;
    const num_timelines = sim_result.num_timelines; 

    try utils.printToStdout("{d} beam splits. {d} timelines\n", .{ num_splits, num_timelines });
}

fn simulateBeamSplits(input_filepath: []const u8, allocator: Allocator) !BeamSimulationResult {
    const file_contents = try utils.readAllFromFile(input_filepath, allocator);

    var line_it = std.mem.tokenizeScalar(u8, file_contents, '\n');
    const start_pos = findStartPos(&line_it) orelse return error.NoStart;

    var beam_map: BeamMap = .init(allocator);
    try beam_map.putNoClobber(start_pos, 1);

    var num_splits: NumSplitsType = 0;
    while (line_it.next()) |line| {
        const curr_beam_positions = try allocator.dupe(usize, beam_map.keys());
        const incident_timelines = try allocator.dupe(NumTimelinesType, beam_map.values());

        for (curr_beam_positions, incident_timelines) |beam_pos, prev_timelines| {
            if (line[beam_pos] != SPLITTER_CHARACTER) {
                continue;
            }

            try beamMapInsert(&beam_map, beam_pos - 1, prev_timelines);
            try beamMapInsert(&beam_map, beam_pos + 1, prev_timelines);
            if (!beam_map.swapRemove(beam_pos)) {
                return error.ArrayHashMapFail;
            }
            num_splits += 1;
        }
    }

    var num_timelines: NumTimelinesType = 0;
    for (beam_map.values()) |beam_timelines| {
        num_timelines += beam_timelines;
    }

    return .{ .num_splits = num_splits, .num_timelines = num_timelines };
}

fn findStartPos(line_it: *std.mem.TokenIterator(u8, std.mem.DelimiterType.scalar)) ?usize {
   while (line_it.next()) |line| {
        if (std.mem.indexOfScalar(u8, line, START_CHARACTER)) |pos| {
            return pos;
        }
   }

   return null;
}

fn beamMapInsert(beam_map: *BeamMap, beam_pos: usize, new_timelines: NumTimelinesType) !void {
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

    const sim_result = try simulateBeamSplits(TEST_INPUT_PATH, allocator);
    try std.testing.expect(sim_result.num_splits == 21);
    try std.testing.expect(sim_result.num_timelines == 40);
}
