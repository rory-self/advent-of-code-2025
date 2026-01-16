// Modules //
const std = @import("std");
const utils = @import("utils");

// Constants //
const TEST_FILEPATH = "./test-inputs/d01.txt";
const NUM_DIALS: TurningType = 100;
const STARTING_POSITION: DialPosition = 50;

// Types //
const Direction = enum {
    left,
    right,

    fn fromChar(direction_char: u8) !Direction {
        switch (direction_char) {
            'L' => return .left,
            'R' => return .right,
            else => {
                std.debug.print("Invalid direction character: {}\n", .{direction_char});
                return error.InvalidChar;
            },
        }
    }
};

const DialPosition = u7;
const TurningType = utils.UpgradeBitWidth(DialPosition, 1);
const Password = u16;
const Instruction = struct {
    direction: Direction,
    num_turns: Password,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const input_filepath = try utils.getFilepathArg(allocator);
    defer allocator.free(input_filepath);
    const password1, const password2 = try findPasswords(input_filepath, allocator);

    try utils.printToStdout("Part 1 password: {d} Part 2 password: {d}\n", .{ password1, password2 });
}

fn findPasswords(input_filepath: []const u8, allocator: std.mem.Allocator) ![2]Password {
    const instructions = try instructionsFromFile(input_filepath, allocator);
    defer allocator.free(instructions);

    var curr_dial_pos: DialPosition = STARTING_POSITION;
    var num_zeroes: Password = 0;
    var zero_crossings: Password = 0;
    for (instructions) |instruction| {
        zero_crossings += turn_dial(&curr_dial_pos, instruction);

        if (curr_dial_pos == 0) {
            num_zeroes += 1;
        }
    }

    return .{ num_zeroes, zero_crossings };
}

fn instructionsFromFile(filepath: []const u8, allocator: std.mem.Allocator) ![]const Instruction {
    const file_contents = try utils.readAllFromFile(filepath, allocator);
    defer allocator.free(file_contents);

    var instructions_it = std.mem.tokenizeScalar(u8, file_contents, '\n');
    var instructions: std.ArrayList(Instruction) = .empty;
    errdefer instructions.deinit(allocator);

    while (instructions_it.next()) |instruction_string| {
        const direction: Direction = try .fromChar(instruction_string[0]);
        const num_turns: Password = try std.fmt.parseInt(Password, instruction_string[1..], 10);
        const instruction: Instruction = .{ .direction = direction, .num_turns = num_turns };

        try instructions.append(allocator, instruction);
    }

    return try instructions.toOwnedSlice(allocator);
}

/// Turn the dial according to the given instruction, return the number of times the 0 position
/// was crossed.
fn turnDial(curr_dial_pos: *DialPosition, instruction: Instruction) Password {
    const num_turns: Password = instruction.num_turns;
    if (num_turns == 0) {
        return 0;
    }

    // Calculate full rotations and remaining turns
    const effective_turns: TurningType = @intCast(num_turns % NUM_DIALS);
    var zero_clicks: Password = @intCast(@divFloor(num_turns, NUM_DIALS));
    if (effective_turns == 0) {
        return zero_clicks;
    }

    const dial_pos: TurningType = curr_dial_pos.*;
    curr_dial_pos.* = if (instruction.direction == .left) left_turn: {
        if (dial_pos <= effective_turns and dial_pos != 0) {
            zero_clicks += 1;
        }

        break :left_turn @intCast((dial_pos + NUM_DIALS - effective_turns) % NUM_DIALS);
    } else right_turn: {
        const raw_turn_total: TurningType = dial_pos + effective_turns;
        if (raw_turn_total >= NUM_DIALS and dial_pos != 0) {
            zero_clicks += 1;
        }

        break :right_turn @intCast(raw_turn_total % NUM_DIALS);
    };

    return zero_clicks;
}

test "Example" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const password1, const password2 = try findPasswords(TEST_FILEPATH, allocator);
    try std.testing.expect(password1 == 3);
    try std.testing.expect(password2 == 6);
}
