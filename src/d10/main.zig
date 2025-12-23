const std = @import("std");
const utils = @import("utils");

const TEST_FILEPATH = "test-inputs/d10.txt";
const INDICATOR_CHAR = '#';

const Machine = struct {
    required_indicators: std.DynamicBitSet,
    button_wiring: []const std.DynamicBitSet,

    fn fromString(str: []const u8, allocator: Allocator) !Machine {
        var token_it = std.mem.tokenizeAny(u8, str, "()[] ");
       
        // Parse indicator requirements
        const indicators_token = token_it.next() orelse return error.NoIndicatorRequirements;
        const num_indicators = indicators_token.len;
        var indicator_requirements: std.DynamicBitSet = try .initEmpty(allocator, num_indicators);
        for (0..num_indicators, indicators_token) |i, indicator_char| {
            if (indicator_char == INDICATOR_CHAR) {
                indicator_requirements.setValue(i, true);
            } 
        }

        // Parse button wirings
        var button_wirings: std.ArrayList(std.DynamicBitSet) = .empty;
        while (token_it.next()) |wiring_token| {
            // Skip joltages for now 
            if (wiring_token[0] == '{') {
                break; 
            }

            var wirings: std.DynamicBitSet = try .initEmpty(allocator, num_indicators);
            var num_it = std.mem.splitScalar(u8, wiring_token, ',');
            while (num_it.next()) |num_char| {
                const button_num = try std.fmt.parseInt(usize, num_char, 10);
                wirings.setValue(button_num, true);
            }

            try button_wirings.append(allocator, wirings);
        }
        
        if (button_wirings.items.len == 0) {
            return error.NoButtonWirings;
        }

        return .{
            .required_indicators = indicator_requirements,
            .button_wiring = try button_wirings.toOwnedSlice(allocator),
        }; 
    }
};
const BitSetMapContext = struct {
    pub fn hash(_: *const BitSetMapContext, k: std.DynamicBitSet) u64 {
        var set_it = k.iterator(.{});
        var hash_val: usize = 0;
        const bit_mask: usize = 1;
        while (set_it.next()) |bit_index| {
            const bit_index_u6: u6 = @intCast(bit_index);
            hash_val |= bit_mask << bit_index_u6;
        }

        return hash_val;
    }
 
    pub fn eql(_: *const BitSetMapContext, a: std.DynamicBitSet, b: std.DynamicBitSet) bool {
        return a.eql(b); 
    }
};
const ButtonMask = u16;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const setup_filepath = try utils.getFilepathArg(allocator);
    const fewest_presses = try fewestPressesForSetup(setup_filepath, allocator);

    try utils.printToStdout("Fewest presses: {}\n", .{ fewest_presses });
}

/// Reads machine configuration data from the given filepath and returns the fewest presses
/// required to activate all of them.
fn fewestPressesForSetup(setup_filepath: []const u8, allocator: Allocator) !u16 {
    const machines = try readMachinesFromFile(setup_filepath, allocator);

    var fewest_presses: u16 = 0; 
    for (machines) |machine| {
        fewest_presses += try calcFewestPresses(machine, allocator);
    }

    return fewest_presses;
}

fn readMachinesFromFile(filepath: []const u8, allocator: Allocator) ![]const Machine {
    const setup = try utils.readAllFromFile(filepath, allocator);
   
    var machines: std.ArrayList(Machine) = .empty;
    var line_it = std.mem.tokenizeScalar(u8, setup, '\n');
    while (line_it.next()) |line| {
        const new_machine = try Machine.fromString(line, allocator);
        try machines.append(allocator, new_machine); 
    }

    return try machines.toOwnedSlice(allocator);
}

/// For a given machine, calculate the fewest presses required for initialisation.
fn calcFewestPresses(machine: Machine, allocator: Allocator) !u8 {
    const button_configs = machine.button_wiring;
    const num_combinations = std.math.pow(usize, 2, button_configs.len);

    // Pressing a button twice is pointless, cache all permutations and sort by minimum presses
    var button_combinations = try allocator.alloc(ButtonMask, num_combinations);
    for (0..num_combinations) |i| {
        button_combinations[i] = @intCast(i);
    }
    std.mem.sort(ButtonMask, button_combinations, {}, compareByHammingWeight);
  
    const NumButtons = comptime std.math.Log2Int(ButtonMask);
    const required_indicators = machine.required_indicators;
    const initial_indicator_state: std.DynamicBitSet = try .initEmpty(allocator, required_indicators.capacity());
    for (button_combinations) |button_mask| {
        var local_state = try initial_indicator_state.clone(allocator);

        var local_presses: NumButtons = 0;
        for (button_configs, 0..) |config, i| {
            const button_index: NumButtons = @intCast(i);

            const button_bit = (button_mask >> button_index) & 0b1;
            if (button_bit != 0b1) {
                continue;
            }

            local_state.toggleSet(config);
            local_presses += 1;
        }

        if (!required_indicators.eql(local_state)) {
            continue;
        }

        return local_presses;
    }

    return error.NoSolution;
}

fn compareByHammingWeight(_: void, a: ButtonMask, b: ButtonMask) bool {
    return @popCount(a) < @popCount(b);
}

test "Example" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const fewest_presses = try fewestPressesForSetup(TEST_FILEPATH, allocator);
    try std.testing.expect(fewest_presses == 7);
}

