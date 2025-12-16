// Modules //
const std = @import("std");
const utils = @import("utils");

// Constants //
const IO_BUF_SIZE: usize = 128;
const TEST_FILEPATH = "test-inputs/d06.txt";
const DELIMITER = ' ';

// Types //
const Allocator = std.mem.Allocator;
const InputIterator = std.mem.TokenIterator(u8, .scalar);
const TermType = u16;
const SumType = u128;
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

    fn eval(self: *const Problem) SumType {
        if (self.numbers.len == 0) {
            return 0;
        }

        var answer = @as(SumType, self.numbers[0]);
        for (self.numbers[1..]) |number| {
            const padded_num = @as(SumType, number);
            switch (self.operator) {
                .add => answer += padded_num,
                .multiply => answer *= padded_num,
            }
        }
        return answer;
    }
};

// Implementation //
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const input_filepath = try utils.getFilepathArg(allocator);
    const answer_total, const ceph_answer = try calcAnswerTotals(input_filepath, allocator);

    try utils.printToStdout("Total sum: {d}. Cephalopod sum: {d}\n", .{ answer_total, ceph_answer });
}

fn calcAnswerTotals(input_filepath: []const u8, allocator: Allocator) ![2]SumType {
    const normal_problems, const ceph_problems = try readProblemsFromFile(input_filepath, allocator);

    var answer_sum: SumType = 0;
    var ceph_answer_sum: SumType = 0;
    for (normal_problems, ceph_problems) |normal_problem, ceph_problem| {
        answer_sum += normal_problem.eval();
        ceph_answer_sum += ceph_problem.eval();
    }

    return .{ answer_sum, ceph_answer_sum };
}

fn readProblemsFromFile(filepath: []const u8, allocator: Allocator) ![2][]const Problem {
    const file_contents = try utils.readAllFromFile(filepath, allocator);
    const normal_problems = try readNormalProblems(file_contents, allocator);
    const cephalopod_problems = try readCephalopodProblems(file_contents, allocator);

    return .{ normal_problems, cephalopod_problems };
}

fn readNormalProblems(input: []const u8, allocator: Allocator) ![]const Problem {
    var line_it = tokenizeLines(input);
    var problems = try allocProblems(&line_it, allocator);
    var terms_by_problem = try allocator.alloc(std.ArrayList(TermType), problems.len);
    for (0..problems.len) |i| {
        terms_by_problem[i] = .empty;
    }

    while (line_it.next()) |line| {
        var term_it = tokenizeTerms(line);
        for (0..problems.len) |i| {
            const term = term_it.next().?;
            if (Operator.fromChar(term[0])) |operator| {
                problems[i].operator = operator;
                continue;
            } else |_| {}

            const parsed_num = try std.fmt.parseInt(TermType, term, 10);
            try terms_by_problem[i].append(allocator, parsed_num);
        }
    }

    for (0..problems.len) |i| {
        problems[i].numbers = try terms_by_problem[i].toOwnedSlice(allocator);
    }

    return problems;
}

inline fn tokenizeTerms(line: []const u8) InputIterator {
    return std.mem.tokenizeScalar(u8, line, DELIMITER);
}

fn allocProblems(line_it: *InputIterator, allocator: Allocator) ![]Problem {
    const first_line = line_it.peek() orelse return error.NoProblems;
    var term_it = tokenizeTerms(first_line);

    var num_problems: usize = 0;
    while (term_it.next()) |_| {
        num_problems += 1;
    }

    return allocator.alloc(Problem, num_problems);
}

fn readCephalopodProblems(input: []const u8, allocator: Allocator) ![]const Problem {
    var line_it = tokenizeLines(input);
    const line_len = line_it.peek().?.len;

    var problems = try allocProblems(&line_it, allocator);
    var terms_by_problem = try allocator.alloc(std.ArrayList(TermType), problems.len);
    for (0..problems.len) |i| {
        terms_by_problem[i] = .empty;
    }

    const magnitudes = try allocMagnitudes(&line_it, allocator);

    // Read input bottom-to-top
    const reversed_input = try allocator.dupe(u8, input);
    std.mem.reverse(u8, reversed_input);

    var rev_line_it = tokenizeLines(reversed_input);
    const last_line = rev_line_it.next().?;
    var operator_it = tokenizeTerms(last_line);
    for (0..problems.len) |i| {
        const token = operator_it.next().?;
        problems[i].operator = try Operator.fromChar(token[0]);
    }

    var curr_line_pos: usize = 0;
    var curr_problem_num: usize = 0;
    while (curr_line_pos != line_len) : (curr_line_pos += 1) {
        const term = try readCephalopodTerm(&rev_line_it, curr_line_pos, magnitudes) orelse {
            // No term / empty col
            curr_problem_num += 1;
            continue;
        };

        try terms_by_problem[curr_problem_num].append(allocator, term);
    }

    for (0..problems.len) |i| {
        problems[i].numbers = try terms_by_problem[i].toOwnedSlice(allocator);
    }

    return problems;
}

inline fn tokenizeLines(input: []const u8) InputIterator {
    return std.mem.tokenizeScalar(u8, input, '\n');
}

fn allocMagnitudes(line_it: *InputIterator, allocator: Allocator) ![]const TermType {
    var num_lines: usize = 0;
    while (line_it.next()) |_| {
        num_lines += 1;
    }
    line_it.reset();

    var magnitudes = try allocator.alloc(TermType, num_lines - 1);
    for (0..magnitudes.len) |i| {
        const term_size_i: TermType = @intCast(i);
        magnitudes[i] = std.math.pow(TermType, 10, term_size_i);
    }
    return magnitudes;
}

fn readCephalopodTerm(line_it: *InputIterator, line_pos: usize, magnitudes: []const TermType) !?TermType {
    var digits_read: usize = 0;
    var curr_term: TermType = 0;
    while (line_it.next()) |line| {
        const char_at_pos = line[line_pos];
        const is_delimiter = char_at_pos == DELIMITER;
        if (is_delimiter and digits_read == 0) {
            continue;
        } else if (is_delimiter) {
            break;
        }

        const digit = char_at_pos - '0';
        curr_term += magnitudes[digits_read] * digit;
        digits_read += 1;
    }
    line_it.reset();
    _ = line_it.next();

    return if (digits_read == 0) null else curr_term;
}

test "Example" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const answer_total, const ceph_answer = try calcAnswerTotals(TEST_FILEPATH, allocator);
    try std.testing.expect(answer_total == 4277556);
    try std.testing.expect(ceph_answer == 3263827);
}
