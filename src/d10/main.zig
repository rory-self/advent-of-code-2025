const std = @import("std");
const utils = @import("utils");

const TEST_FILEPATH = "test-inputs/d10.txt";

const Machine = struct {
    required_indicators: std.DynamicBitSet,
    button_wiring: []const std.DynamicBitSet,

    fn fromString(str: []const u8, allocator: Allocator) !Machine {
        var token_it = std.mem.splitScalar(u8, str, ' ');
       
        // Parse indicator requirements
        const indicators_token = token_it.next() orelse return error.NoIndicatorRequirements;
        const num_indicators = indicators_token.len - 2;
        var indicator_requirements: std.DynamicBitSet = try .initEmpty(num_indicators);
        for (0..num_indicators, indicators_token) |i, indicator_char| {
            if (indicator_char == '#') {
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

            var wirings: std.DynamicBitSet = try .initEmpty(num_indicators);
            var num_it = std.mem.splitScalar(u8, wiring_token, ',');
            var is_useful_wiring = false;
            while (num_it.next()) |num_char| {
                const button_num = try std.fmt.parseInt(usize, num_char, 10);
                wirings.setValue(button_num, true);

                if (indicator_requirements.isSet(button_num)) {
                    is_useful_wiring = true;
                }
            }

            // Skip wiring config if not relevant to the indicator requirements
            if (is_useful_wiring) {
                try button_wirings.append(allocator, wirings);
            }
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
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const setup_filepath = try utils.getFilepathArg(allocator);
    const fewest_presses = try fewestPressesForSetup(setup_filepath, allocator);

    try utils.printToStdout("Fewest presses: {}\n", .{ fewest_presses });
}

fn fewestPressesForSetup(setup_filepath: []const u8, allocator: Allocator) !u8 {
    const machines = try readMachinesFromFile(setup_filepath, allocator);

    var fewest_presses: u8 = 0;
    for (machines) |machine| {
        const num_indicators = machine.required_indicators.capacity();
        const initial_state: std.DynamicBitSet = try .initEmpty(allocator, num_indicators);
        fewest_presses += simulatePresses(machine, allocator, initial_state);
    }

    return fewest_presses;
}

fn simulatePresses(machine: Machine, allocator: Allocator, curr_state: std.DynamicBitSet) u8 { 
    const num_indicators = machine.required_indicators.capacity();
    var indicator_state: std.DynamicBitSet = .initEmpty(allocator, num_indicators);
    for (machine.button_wiring) |button_wiring| {
        var new_state = try curr_state.clone(allocator);
    }
}

fn readMachinesFromFile(filepath: []const u8, allocator: Allocator) ![]const Machine {
    const setup = utils.readAllFromFile(filepath, allocator);
   
    var machines: std.ArrayList(Machine) = .empty;
    var line_it = std.mem.tokenizeScalar(u8, setup, '\n');
    while (line_it.next()) |line| {
        const new_machine = Machine.fromString(line, allocator);
        try machines.append(allocator, new_machine); 
    }

    return try machines.toOwnedSlice(allocator);
}

test "Example" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const fewest_presses = try fewestPressesForSetup(TEST_FILEPATH, allocator);
    try std.testing.expect(fewest_presses == 7);
}

