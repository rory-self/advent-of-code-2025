// Modules //
const std = @import("std");
const utils = @import("utils");
const dsu = @import("dsu.zig");

// Constants //
const TEST_FILEPATH = "test-inputs/d08.txt";
const NUM_CONNECTIONS = 1000;
const NUM_CIRCUITS_TO_MULTIPLY = 3;

// Types //
const Coordinate = u32;
const DistanceType = utils.UpgradeBitWidth(Coordinate, 1);
const Coordinates = [3]Coordinate;
const Connection = struct {
    distance: DistanceType,
    box_ids: [2]usize,
};
const ConnectionQueue = std.PriorityQueue(Connection, void, compareByDistance);
const DisjointSetUnion = dsu.DisjointSetUnion;
const Allocator = std.mem.Allocator;

// Implementation //
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const input_filepath = try utils.getFilepathArg(allocator);
    const p1_result, const p2_result = try simulateConnections(input_filepath, NUM_CONNECTIONS, allocator);

    try utils.printToStdout("Part 1 result: {d} Part 2 result: {d}\n", .{ p1_result, p2_result });
}

fn simulateConnections(
    input_filepath: []const u8,
    num_connections: usize,
    allocator: Allocator,
) !struct {usize, u64 } {
    const box_coords = try boxCoordsFromFile(input_filepath, allocator);
    var connections = try collectConnections(box_coords, allocator);
    if (connections.count() < num_connections) {
        return error.NotEnoughConnections;
    }

    var network = try DisjointSetUnion.init(box_coords.len, allocator);

    // Part 1
    try formCircuits(&connections, &network, num_connections);
    const circuit_sizes = network.getSetSizes();
    const size_result = try multiplyCircuitSizes(circuit_sizes, allocator);

    // Part 2
    var last_connection: Connection = undefined;
    while (network.count() > 1) {
        last_connection = connections.peek().?;
        try formCircuits(&connections, &network, 1);
    }

    const box1, const box2 = last_connection.box_ids;
    const x1: u64 = @intCast(box_coords[box1][0]);
    const x2: u64 = @intCast(box_coords[box2][0]);

    const x_coordinate_total = x1 * x2;
    
    return .{ size_result, x_coordinate_total };
}

fn multiplyCircuitSizes(circuit_sizes: []const usize, allocator: Allocator) !usize {
    const sizes = try allocator.dupe(usize, circuit_sizes);
    std.mem.sort(usize, sizes, {}, comptime std.sort.desc(usize));

    var size_result: usize = 1;
    for (0..NUM_CIRCUITS_TO_MULTIPLY) |i| {
        size_result *= sizes[i];
    }

    return size_result;
}

fn boxCoordsFromFile(filepath: []const u8, allocator: Allocator) ![]const Coordinates {
    const file_contents = try utils.readAllFromFile(filepath, allocator);

    var line_it = std.mem.splitScalar(u8, file_contents, '\n');
    var box_coords: std.ArrayList(Coordinates) = .empty;
    while (line_it.next()) |line| {
        if (line.len == 0) {
            break;
        }

        const new_coords = try coordsFromString(line);
        try box_coords.append(allocator, new_coords);
    }

    return try box_coords.toOwnedSlice(allocator);
}

fn coordsFromString(str: []const u8) !Coordinates {
    var token_it = std.mem.splitScalar(u8, str, ',');
    var coordinates: Coordinates = undefined;
    for (0..coordinates.len) |i| {
        const token = token_it.next() orelse return error.MissingCoordinate;
        coordinates[i] = try std.fmt.parseInt(Coordinate, token, 10);
    }

    return coordinates;
}

fn collectConnections(box_coords: []const Coordinates, allocator: Allocator) !ConnectionQueue {
    var connection_queue: ConnectionQueue = .init(allocator, {});
    const num_possible_connections = (box_coords.len * (box_coords.len - 1)) / 2;
    try connection_queue.ensureTotalCapacityPrecise(num_possible_connections);

    for (0..box_coords.len) |i| {
        for (i + 1..box_coords.len) |j| {
            const distance = calculateDistance(box_coords[i], box_coords[j]);
            const connection: Connection = .{ .distance = distance, .box_ids = .{ i, j } };

            try connection_queue.add(connection);
        }
    }

    return connection_queue;
}

fn compareByDistance(_: void, a: Connection, b: Connection) std.math.Order {
    return std.math.order(a.distance, b.distance);
}

fn calculateDistance(p1: Coordinates, p2: Coordinates) DistanceType {
    const x1, const y1, const z1 = p1;
    const x2, const y2, const z2 = p2;

    const T = comptime utils.UpgradeBitWidth(Coordinate, 3);
    const square_diff_sum: T = squaredDiff(x1, x2, T) + squaredDiff(y1, y2, T) + squaredDiff(z1, z2, T);

    return @intCast(std.math.sqrt(square_diff_sum));
}

fn squaredDiff(a: Coordinate, b: Coordinate, comptime T: type) T {
    const SignedType: type = comptime utils.UnsignedToSigned(Coordinate);
    const signed_a: SignedType = @intCast(a);
    const signed_b: SignedType = @intCast(b);

    const diff: T = @intCast(@abs(signed_a - signed_b));
    return std.math.pow(T, diff, 2);
}

fn formCircuits(
    connections: *ConnectionQueue,
    network: *DisjointSetUnion,
    num_connections: usize
) !void {
    for (0..num_connections) |_| {
        const connection = connections.removeOrNull() orelse return error.NoRemainingConnections;
        const box1_id, const box2_id = connection.box_ids;
        
        try network.unionSets(box1_id, box2_id);
    }   
}

test "Example" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    arena.deinit();
    const allocator = arena.allocator();

    const p1_result, const p2_result = try simulateConnections(TEST_FILEPATH, 10, allocator);
    try std.testing.expect(p1_result == 40);
    try std.testing.expect(p2_result == 25272);
}

