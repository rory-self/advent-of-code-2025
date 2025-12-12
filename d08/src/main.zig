const std = @import("std");
const utils = @import("utils");

// Constants //
const TEST_FILEPATH = "test.txt";
const PAIRS_TO_CONNECT = 1000;

// Types //
const Allocator = std.mem.Allocator;

const JunctionBox = struct {
    pos: [3]u16,

    fn fromString(str: []const u8) !JunctionBox {
        var token_it = std.mem.splitScalar(u8, str, ',');
        var positions: [3]u16 = undefined;
        for (0..positions.len) |i| {
            const token = token_it.next() orelse return error.MissingCoordinate;
            positions[i] = try std.fmt.parseInt(u16, token, 10);
        }

        return .{ positions };
    }
};

const Circuit = struct {
    size: usize,
};

// Implementation //
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    arena.deinit();
    const allocator = arena.allocator();

    const input_filepath = try utils.getFilepathArg(allocator);
    const p1_result = try connectCircuitsAndMultiply(input_filepath, PAIRS_TO_CONNECT, allocator);

    try utils.printToStdout("Part 1 result: {}\n", .{ p1_result });
}

fn connectCircuitsAndMultiply(
    input_filepath: []const u8,
    num_connections: u16,
    allocator: Allocator,
) u16 {
    const file_contents = try utils.readAllFromFile(input_filepath, allocator);
    
    var line_it = std.mem.splitScalar(u8, file_contents, '\n');
    var boxes: std.ArrayList(JunctionBox) = .init();
    while (line_it.next()) |line| {
        const new_box = try JunctionBox.fromString(line);
        try boxes.append(new_box);
    }


}

fn calculateDistance(box1: JunctionBox, box2: JunctionBox) u32 {
    const x1, const y1, const z1 = box1;
    const x2, const y2, const z2 = box2;
    return (x2 - x1) ** 2 + (y2 - y1) ** 2 + (z2 - z1) ** 2;
}

test "Example" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    arena.deinit();
    const allocator = arena.allocator();

    const p1_result = try connectCircuitsAndMultiply(TEST_FILEPATH, 10, allocator);
    try std.testing.expect(p1_result == 40);
}

