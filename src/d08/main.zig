// Modules //
const std = @import("std");
const utils = @import("utils");

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
const Circuit = []const usize;
const CircuitByIdMap = std.AutoHashMap(usize, std.ArrayList(usize));
const Allocator = std.mem.Allocator;
const NetworkParameters = struct {
    circuit_by_id: *CircuitByIdMap,
    circuit_id_by_box: []?usize,
    allocator: Allocator,
};

// Implementation //
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const input_filepath = try utils.getFilepathArg(allocator);
    const p1_result = try simulateConnections(input_filepath, NUM_CONNECTIONS, allocator);

    try utils.printToStdout("Part 1 result: {}\n", .{p1_result});
}

fn simulateConnections(
    input_filepath: []const u8,
    num_connections: usize,
    allocator: Allocator,
) !usize {
    const box_coords = try boxCoordsFromFile(input_filepath, allocator);
    const connections = try collectShortestConnections(box_coords, num_connections, allocator);

    const circuits = try formCircuits(connections, box_coords.len, allocator);
    std.mem.sort(Circuit, circuits, {}, compareCircuitSize);

    var size_result: usize = 1;
    for (0..NUM_CIRCUITS_TO_MULTIPLY) |i| {
        size_result *= circuits[i].len;
    }

    return size_result;
}

fn compareCircuitSize(_: void, lhs: Circuit, rhs: Circuit) bool {
    return lhs.len > rhs.len;
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

/// Given a slice of box coordinates, returns the shortest 1000 connections.
fn collectShortestConnections(
    box_coords: []const Coordinates,
    num_connections: usize,
    allocator: Allocator,
) ![]const Connection {
    var connection_queue: ConnectionQueue = .init(allocator, {});
    try connection_queue.ensureTotalCapacityPrecise(num_connections);
    for (0..box_coords.len) |i| {
        for (i + 1..box_coords.len) |j| {
            const distance = calculateDistance(box_coords[i], box_coords[j]);
            const connection: Connection = .{ .distance = distance, .box_ids = .{ i, j } };

            if (connection_queue.count() < num_connections) {
                try connection_queue.add(connection);
                continue;
            }

            // popped item from the priority queue is always the longest connection
            const largest_distance = connection_queue.peek().?.distance;
            if (largest_distance <= distance) {
                continue;
            }

            _ = connection_queue.remove();
            try connection_queue.add(connection);
        }
    }

    return connection_queue.items;
}

fn compareByDistance(_: void, a: Connection, b: Connection) std.math.Order {
    return std.math.order(a.distance, b.distance).invert();
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

/// Given a slice of connections and the total number of junction boxes, return a slice of circuits
/// formed.
fn formCircuits(
    connections: []const Connection,
    num_boxes: usize,
    allocator: Allocator,
) ![]Circuit {
    const circuit_id_by_box = try allocator.alloc(?usize, num_boxes);
    for (0..num_boxes) |i| {
        circuit_id_by_box[i] = null;
    }

    var circuit_by_id: CircuitByIdMap = .init(allocator);
    const network_params = NetworkParameters{
        .circuit_by_id = &circuit_by_id,
        .circuit_id_by_box = circuit_id_by_box,
        .allocator = allocator,
    };

    var total_circuits_created: usize = 0;
    for (connections) |connection| {
        const box1_id, const box2_id = connection.box_ids;
        const circuit1_id_opt = circuit_id_by_box[box1_id];
        const circuit2_id_opt = circuit_id_by_box[box2_id];

        if (circuit1_id_opt == circuit2_id_opt and circuit1_id_opt != null and circuit2_id_opt != null) {
            continue;
        }

        if (circuit1_id_opt == null and circuit2_id_opt == null) {
            try createNewCircuit(network_params, total_circuits_created, box1_id, box2_id);
            total_circuits_created += 1;
            continue;
        }

        if (circuit1_id_opt == null) {
            try addBoxToCircuit(network_params, circuit2_id_opt.?, box1_id);
            continue;
        }

        const circuit1_id = circuit1_id_opt.?;
        if (circuit2_id_opt == null) {
            try addBoxToCircuit(network_params, circuit1_id, box2_id);
            continue;
        }

        try mergeCircuits(network_params, circuit1_id, circuit2_id_opt.?);
    }

    // Compile circuits to slice
    var circuits = try allocator.alloc(Circuit, circuit_by_id.count());
    var circuit_it = circuit_by_id.valueIterator();
    for (0..circuits.len) |i| {
        const curr_circuit = circuit_it.next() orelse return error.MissingCircuit;
        circuits[i] = try curr_circuit.toOwnedSlice(allocator);
    }

    return circuits;
}

fn createNewCircuit(
    network_params: NetworkParameters,
    new_circuit_id: usize,
    box1_id: usize,
    box2_id: usize,
) !void {
    var new_circuit = try std.ArrayList(usize).initCapacity(network_params.allocator, 2);
    new_circuit.appendSliceAssumeCapacity(&.{ box1_id, box2_id });

    try network_params.circuit_by_id.put(new_circuit_id, new_circuit);
    
    const circuit_id_by_box = network_params.circuit_id_by_box;
    circuit_id_by_box[box1_id] = new_circuit_id;
    circuit_id_by_box[box2_id] = new_circuit_id;
}

inline fn addBoxToCircuit(
    network_params: NetworkParameters,
    circuit_id: usize,
    box_id: usize,
) !void {
    try network_params.circuit_by_id.getPtr(circuit_id).?.append(network_params.allocator, box_id);
    network_params.circuit_id_by_box[box_id] = circuit_id;
}

fn mergeCircuits(
    network_params: NetworkParameters,
    id1: usize,
    id2: usize,
) !void {
    const circuit_by_id = network_params.circuit_by_id;
    const circuit1_size = circuit_by_id.get(id1).?.items.len;
    const circuit2_size = circuit_by_id.get(id2).?.items.len;
    const big_circuit_id = if (circuit1_size >= circuit2_size) id1 else id2;
    const small_circuit_id = if (circuit1_size >= circuit2_size) id2 else id1;

    const small_circuit_boxes = circuit_by_id.get(small_circuit_id).?.items;
    try circuit_by_id.getPtr(big_circuit_id).?.appendSlice(network_params.allocator, small_circuit_boxes);
    for (small_circuit_boxes) |box_id| {
        network_params.circuit_id_by_box[box_id] = big_circuit_id;
    }

    if (!circuit_by_id.remove(small_circuit_id)) {
        return error.RemoveFailure;
    }
}

test "Example" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    arena.deinit();
    const allocator = arena.allocator();

    const p1_result = try simulateConnections(TEST_FILEPATH, 10, allocator);
    try std.testing.expect(p1_result == 40);
}
