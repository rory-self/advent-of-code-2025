const std = @import("std");
const utils = @import("utils");

const TEST_FILEPATH = "test-inputs/d09.txt";

const Coordinate = u32;
const SignedCoord = utils.UnsignedToSigned(Coordinate);
const Coordinates = struct {
    x: Coordinate,
    y: Coordinate,
};
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const input_filepath = try utils.getFilepathArg(allocator);
    const largest_area = try calcLargestRectangle(input_filepath, allocator);

    try utils.printToStdout("Largest area: {d}\n", .{ largest_area });
}

fn calcLargestRectangle(input_filepath: []const u8, allocator: Allocator) !usize {
    const tile_coords = try collectTileCoordinates(input_filepath, allocator);

    var largest_area: usize = 0;
    for (0..tile_coords.len) |i| {
        for (i + 1..tile_coords.len) |j| {
            const tile1 = tile_coords[i];
            const tile2 = tile_coords[j];
            const area = calcEnclosedArea(tile1, tile2);

            if (area > largest_area) {
                largest_area = area;
            }
        }
    }

    return largest_area;
}

fn collectTileCoordinates(input_filepath: []const u8, allocator: Allocator) ![]const Coordinates {
    const file_contents = try utils.readAllFromFile(input_filepath, allocator); 
    var line_it = std.mem.tokenizeScalar(u8, file_contents, '\n');

    var coordinates_list: std.ArrayList(Coordinates) = .empty;
    while (line_it.next()) |line| {
        const delimiter_pos = std.mem.indexOfScalar(u8, line, ',') orelse return error.MissingDelimiter;
        const x_coord = try std.fmt.parseInt(Coordinate, line[0..delimiter_pos], 10);
        const y_coord = try std.fmt.parseInt(Coordinate, line[delimiter_pos + 1..], 10);

        const coords = Coordinates{ .x = x_coord, .y = y_coord };
        try coordinates_list.append(allocator, coords);
    }

    return try coordinates_list.toOwnedSlice(allocator);
}

fn calcEnclosedArea(coords1: Coordinates, coords2: Coordinates) usize { 
    const signed_x1, const signed_y1 = getSignedCoords(coords1);
    const signed_x2, const signed_y2 = getSignedCoords(coords2);

    const y_diff: usize = @intCast(@abs(signed_y2 - signed_y1));
    const x_diff: usize = @intCast(@abs(signed_x2 - signed_x1));

    return (y_diff + 1) * (x_diff + 1);
}

fn getSignedCoords(coords: Coordinates) [2]SignedCoord {
   const signed_x: SignedCoord = @intCast(coords.x);
   const signed_y: SignedCoord = @intCast(coords.y);

   return .{ signed_x, signed_y };
}

test "Example" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const largest_area = try calcLargestRectangle(TEST_FILEPATH, allocator);
    try std.testing.expect(largest_area == 50);
}

