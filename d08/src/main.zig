const std = @import("std");
const utils = @import("utils");

// Constants //
const TEST_FILEPATH = "test.txt";
const CONNECTIONS_TO_MAKE = 1000;

// Types //
const Connection = struct {
    distance: u32,
    box_ids: [2]usize,
};

const Coordinates = [3]u16;
const DistanceQueue = std.PriorityQueue(Connection, void, compareByDistance);
const Circuit = std.ArrayList(usize);
const CircuitsById = std.AutoHashMap(usize, Circuit);
const Allocator = std.mem.Allocator;

// Implementation //
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    arena.deinit();
    const allocator = arena.allocator();

    const input_filepath = try utils.getFilepathArg(allocator);
    const p1_result = try simulateConnections(input_filepath, CONNECTIONS_TO_MAKE, allocator);

    try utils.printToStdout("Part 1 result: {}\n", .{ p1_result });
}

fn simulateConnections(
    input_filepath: []const u8,
    num_connections: u16,
    allocator: Allocator,
) !u16 {
    const box_coords = try boxCoordsFromFile(input_filepath, allocator);
    const connections_to_make = try collectConnectionsToMake(box_coords, num_connections,  allocator);
    var circuits_by_id = try formCircuits(connections_to_make, box_coords.len, allocator);

    var circuits = try allocator.alloc(Circuit, circuits_by_id.count());
    var circuit_it = circuits_by_id.valueIterator();
    for (0..circuits.len) |i| {
        const curr_circuit = circuit_it.next() orelse break;
        circuits[i] = curr_circuit.*;
    }

    std.mem.sort(Circuit, circuits, void, compareCircuitSize);
    var size_result = 1;
    for (0..3) |i| {
        size_result *= circuits[i].items.len;
    }

    return size_result;
}

fn compareCircuitSize(_: void, lhs: Circuit, rhs: Circuit) bool {
    return lhs.items.len > rhs.items.len;
}

fn boxCoordsFromFile(filepath: []const u8, allocator: Allocator) ![]const Coordinates {
    const file_contents = try utils.readAllFromFile(filepath, allocator);
    
    var line_it = std.mem.splitScalar(u8, file_contents, '\n');
    var box_coords: std.ArrayList(Coordinates) = .empty;
    while (line_it.next()) |line| {
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
        coordinates[i] = try std.fmt.parseInt(u16, token, 10);
    }

    return coordinates;
}

fn collectConnectionsToMake(
    box_coords: []const Coordinates,
    num_connections: u16,
    allocator: Allocator,
) ![]const Connection {
    var distance_queue: DistanceQueue = .init(allocator, {});
    try distance_queue.ensureTotalCapacityPrecise(num_connections);
    for (0..box_coords.len) |i| {
        for (i + 1..box_coords.len) |j| {
            const distance = calculateDistance(box_coords[i], box_coords[j]);
            const box_pair: Connection = .{ .distance = distance, .box_ids = .{ i, j } };
           
            if (distance_queue.count() < num_connections) {
                try distance_queue.add(box_pair);
                continue;
            }

            const largest_distance = distance_queue.peek().?.distance;
            if (largest_distance > distance) {
                try distance_queue.add(box_pair);
                _ = distance_queue.remove();
            }
        }
    }

    return distance_queue.items;
}

fn compareByDistance(_: void, a: Connection, b: Connection) std.math.Order {
    return std.math.order(a.distance, b.distance).invert();
}

fn calculateDistance(p1: Coordinates, p2: Coordinates) u32 {
    const x1, const y1, const z1 = p1;
    const x2, const y2, const z2 = p2;
    return squaredDiff(x1, x2) + squaredDiff(y1, y2) + squaredDiff(z1, z2);
}

fn squaredDiff(a: u16, b: u16) u32 {
    const signed_a: i16 = @intCast(a);
    const signed_b: i16 = @intCast(b);

    const diff: u32 = @intCast(@abs(signed_a - signed_b));
    return std.math.pow(u32, diff, 2);
}

fn formCircuits(
    connections: []const Connection,
    num_boxes: usize,
    allocator: Allocator,
) !CircuitsById {
    var circuit_id_by_box = try allocator.alloc(?usize, num_boxes);
    var circuit_by_id: CircuitsById = .init(allocator);
    var total_circuits_created: usize = 0;
    for (connections) |connection| {
        const box_1_id, const box_2_id = connection.box_ids;
        const circuit1_id_opt = circuit_id_by_box[box_1_id];
        const circuit2_id_opt = circuit_id_by_box[box_2_id];

        if (circuit1_id_opt == circuit2_id_opt and circuit1_id_opt != null and circuit2_id_opt != null) {
            continue;
        }

        if (circuit1_id_opt == null and circuit2_id_opt == null) {
            var new_circuit = try Circuit.initCapacity(allocator, 2);
            new_circuit.appendSliceAssumeCapacity(&connection.box_ids);

            try circuit_by_id.put(total_circuits_created, new_circuit);
            circuit_id_by_box[box_1_id] = total_circuits_created;
            circuit_id_by_box[box_2_id] = total_circuits_created;
            total_circuits_created += 1;
            continue;
        }

        if (circuit1_id_opt == null) {
            try addBoxToCircuit(&circuit_by_id, circuit_id_by_box, circuit2_id_opt.?, box_1_id, allocator);
            continue;
        }

        if (circuit2_id_opt == null) {
            try addBoxToCircuit(&circuit_by_id, circuit_id_by_box, circuit1_id_opt.?, box_2_id, allocator);
            continue;
        }

        // Merge two circuits
        const circuit1_id = circuit1_id_opt.?;
        const circuit2_id = circuit2_id_opt.?;
        const circuit1_size = circuit_by_id.get(circuit1_id).?.items.len;
        const circuit2_size = circuit_by_id.get(circuit2_id).?.items.len;
        const big_circuit_id = if (circuit1_size >= circuit2_size) circuit1_id else circuit2_id;
        const small_circuit_id = if (circuit1_size >= circuit2_size) circuit2_id else circuit1_id;

        const small_circuit_boxes = circuit_by_id.get(small_circuit_id).?.items;
        try circuit_by_id.getPtr(big_circuit_id).?.appendSlice(allocator, small_circuit_boxes);
        for (small_circuit_boxes) |box_id| {
            circuit_id_by_box[box_id] = big_circuit_id;
        }

        _ = circuit_by_id.remove(small_circuit_id);
    }

    return circuit_by_id;
}

inline fn addBoxToCircuit(
    circuits: *CircuitsById,
    circuit_id_by_box: []?usize,
    circuit_id: usize,
    box_id: usize,
    allocator: Allocator,
) !void {
    try circuits.getPtr(circuit_id).?.append(allocator, box_id);
    circuit_id_by_box[box_id] = circuit_id;
}

test "Example" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    arena.deinit();
    const allocator = arena.allocator();

    const p1_result = try simulateConnections(TEST_FILEPATH, 10, allocator);
    try std.testing.expect(p1_result == 40);
}

