const std = @import("std");

const Allocator = std.mem.Allocator;

pub const FreshIdRange = struct {
    min_id: u64,
    max_id: u64,

    pub fn fromString(string: []const u8) !FreshIdRange {
        const separator_index = std.mem.indexOf(u8, string, "-") orelse return error.MissingDelimiter;
        const min_id = string[0..separator_index];
        const max_id = string[separator_index + 1 ..];

        const min_val = try std.fmt.parseInt(u64, min_id, 10);
        const max_val = try std.fmt.parseInt(u64, max_id, 10);
        return .{ .min_id = min_val, .max_id = max_val };
    }

    inline fn idInRange(self: *const FreshIdRange, id: u64) bool {
        return id >= self.min_id and id <= self.max_id;
    }
};

const RangeTreeNode = struct {
    range: FreshIdRange,
    left: ?*RangeTreeNode,
    right: ?*RangeTreeNode,

    fn fromRange(range: FreshIdRange, allocator: Allocator) !*RangeTreeNode {
        var new_node = try allocator.create(RangeTreeNode);
        new_node.range = range;
        new_node.left = null;
        new_node.right = null;

        return new_node;
    }

    fn doInsertRange(
        self: *RangeTreeNode,
        new_range: FreshIdRange,
        allocator: Allocator,
    ) !void {
        const new_min_id = new_range.min_id;
        const new_max_id = new_range.max_id;
        var range = self.range;

        const min_overlaps = range.idInRange(new_min_id);
        const max_overlaps = range.idInRange(new_max_id);
        if (min_overlaps and max_overlaps) {
            return;
        }

        // If there is a partial overlap, expand this range and remove overlapping range nodes
        // lower in the tree.
        if (new_min_id < range.min_id and new_max_id > range.max_id) {
            self.range = mergeRanges(&self.left, new_range);
            self.range = mergeRanges(&self.right, new_range);
            return;
        } else if (min_overlaps) {
            range.max_id = new_range.max_id;
            self.range = mergeRanges(&self.right, range);
            return;
        } else if (max_overlaps) {
            range.min_id = new_range.min_id;
            self.range = mergeRanges(&self.left, range);
            return;
        }

        if (new_max_id < range.min_id) {
            if (self.left) |left_node| {
                try left_node.doInsertRange(new_range, allocator);
                return;
            }

            self.left = try RangeTreeNode.fromRange(new_range, allocator);
            return;
        }

        if (self.right) |right_node| {
            try right_node.doInsertRange(new_range, allocator);
            return;
        }

        self.right = try RangeTreeNode.fromRange(new_range, allocator);
    }

    /// Given a pointer to a node field, evaluates whether the node - and any child nodes -
    /// overlaps with the given parent range, removing the node if true. Will return the
    /// total merged range of all deleted nodes.
    fn mergeRanges(node: *?*RangeTreeNode, range: FreshIdRange) FreshIdRange {
        if (node.* == null) {
            return range;
        }

        const curr_node = node.*.?;
        const curr_range = curr_node.range;
        const curr_max = curr_range.max_id;
        const curr_min = curr_range.min_id;
        if (range.min_id > curr_max) {
            return mergeRanges(&curr_node.right, range);
        } else if (range.max_id < curr_min) {
            return mergeRanges(&curr_node.left, range);
        }

        var new_range = range;
        if (curr_range.idInRange(range.max_id)) {
            new_range.max_id = curr_max;
            node.* = curr_node.right;
        } else {
            new_range.min_id = curr_min;
            node.* = curr_node.left;
        }

        return new_range;
    }

    fn idInRange(self: *const RangeTreeNode, id: u64) bool {
        const range = self.range;
        if (range.idInRange(id)) {
            return true;
        }

        if (range.min_id > id) {
            if (self.left) |left_node| {
                return left_node.idInRange(id);
            }
            return false;
        }

        if (self.right) |right_node| {
            return right_node.idInRange(id);
        }
        return false;
    }

    fn countIDs(self: *const RangeTreeNode) u64 {
        var num_ids: u64 = self.range.max_id - self.range.min_id + 1;
        if (self.left) |left_node| {
            num_ids += left_node.countIDs();
        }

        if (self.right) |right_node| {
            num_ids += right_node.countIDs();
        }

        return num_ids;
    }
};

pub const RangeTree = struct {
    head: ?*RangeTreeNode,

    pub const empty = RangeTree{
        .head = null,
    };

    pub fn insertRange(
        self: *RangeTree,
        new_range: FreshIdRange,
        allocator: Allocator,
    ) !void {
        if (self.head) |head_range| {
            try head_range.doInsertRange(new_range, allocator);
        } else {
            self.head = try RangeTreeNode.fromRange(new_range, allocator);
        }
    }

    pub fn idInRange(self: *const RangeTree, id: u64) bool {
        if (self.head) |head_range| {
            return head_range.idInRange(id);
        }
        return false;
    }

    pub fn countIDs(self: *const RangeTree) u64 {
        if (self.head) |head_range| {
            return head_range.countIDs();
        }

        return 0;
    }
};
