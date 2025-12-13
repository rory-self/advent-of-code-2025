const std = @import("std");
const utils = @import("utils");

const IO_BUF_SIZE: usize = 128;
const TEST_INPUT_FILEPATH = "test.txt";

const Allocator = std.mem.Allocator;
const TermType = u16;
const Operator = enum {
    multiply,
    add,

    fn fromChar(char: u8) !Operator {
        return switch (char) {
            '+' => .add,
            '*' => .multiply,
            else => error.InvalidOperator,
        };
    }
};

const Problem = struct {
    numbers: []const TermType,
    operator: Operator = .add,

    fn eval(self: *const Problem) u128 {
        if (self.numbers.len == 0) {
            return 0;
        }

        var answer = @as(u128, self.numbers[0]);
        for (self.numbers[1..]) |number| {
            const padded_num = @as(u128, number);
            switch (self.operator) {
                .add => answer += padded_num,
                .multiply => answer *= padded_num,
            }
        }
        return answer;
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const input_filepath = try utils.getFilepathArg(allocator);
    const answer_total, const ceph_answer = try calcAnswerTotal(input_filepath, allocator);

    try utils.printToStdout("Total sum: {d}. Cephalopod sum: {d}\n", .{ answer_total, ceph_answer });
}

fn calcAnswerTotal(input_filepath: []const u8, allocator: Allocator) !struct { u128, u128 } {
    const normal_problems, _ = try readProblemsFromFile(input_filepath, allocator);

    var answer_sum: u128 = 0;
    for (normal_problems) |problem| {
        answer_sum += problem.eval();
    }

    return .{ answer_sum, 0 };
}

fn readProblemsFromFile(filepath: []const u8, allocator: Allocator) ![2][]const Problem {
    const file_contents = try utils.readAllFromFile(filepath, allocator);
    const normal_problems = try readNormalProblems(file_contents, allocator);
    const cephalopod_problems: []const Problem = undefined;

    return .{ normal_problems, cephalopod_problems };
}

fn readNormalProblems(input: []const u8, allocator: Allocator) ![]const Problem {
    var line_it = std.mem.splitScalar(u8, input, '\n');
    const first_line = line_it.peek() orelse return error.EmptyInput;
    const num_problems = countProblems(first_line);

    var terms_by_problem = try allocator.alloc(std.ArrayList(TermType), num_problems);
    for (0..num_problems) |i| {
        terms_by_problem[i] = .empty;
    }

    var problems = try allocator.alloc(Problem, num_problems);
    while (line_it.next()) |line| {
        if (line.len == 0) {
            break;
        }

        var term_it = std.mem.tokenizeScalar(u8, line, ' ');
        for (0..num_problems) |i| {
            const term = term_it.next().?;
            if (Operator.fromChar(term[0])) |operator| {
                problems[i].operator = operator;
                continue;
            } else |_| {}

            const parsed_num = try std.fmt.parseInt(TermType, term, 10);
            try terms_by_problem[i].append(allocator, parsed_num);
        }
    }

    for (0..num_problems) |i| {
        problems[i].numbers = try terms_by_problem[i].toOwnedSlice(allocator);
    }

    return problems;
}

fn countProblems(line: []const u8) usize {
    var term_it = std.mem.tokenizeScalar(u8, line, ' ');
    
    var num_problems: usize = 0;
    while (term_it.next()) |_| {
        num_problems += 1;
    }
    return num_problems;
}

test "Example" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const answer_total, const ceph_answer = try calcAnswerTotal(TEST_INPUT_FILEPATH, allocator);
    try std.testing.expect(answer_total == 4277556);
    try std.testing.expect(ceph_answer == 3263827);
}
