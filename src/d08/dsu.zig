//! Implementation of a disjoint set union data structure
const std = @import("std");

pub const DisjointSetUnion = struct {
    num_elements: usize,
    parent: []usize,
    size: []usize,
    num_sets: usize,

    pub fn init(num_elements: usize, allocator: std.mem.Allocator) !DisjointSetUnion {
        const parent_array = try allocator.alloc(usize, num_elements);
        const size_array = try allocator.alloc(usize, num_elements);
        for (0..num_elements) |i| {
            parent_array[i] = i;
            size_array[i] = 1;
        }

        return .{
            .parent = parent_array,
            .size = size_array,
            .num_elements = num_elements,
            .num_sets = num_elements,
        };
    }

    /// Find root element / identifier of the element's set
    pub fn find(self: *DisjointSetUnion, element: usize) !usize {
        if (element >= self.num_elements) {
            return error.InvalidElement;
        }

        const parent = self.parent[element];
        if (element == parent) {
            return element;
        }

        const set_root = self.find(parent) catch unreachable;
        self.parent[element] = set_root;
        return set_root;
    }

    /// Join the sets of two given elements
    pub fn unionSets(self: *DisjointSetUnion, a: usize, b: usize) !void {
        if (a >= self.num_elements or b >= self.num_elements) {
            return error.InvalidElement;
        }

        if (a == b) {
            return;
        }

        var a_set = self.find(a) catch unreachable;
        var b_set = self.find(b) catch unreachable;
        if (a_set == b_set) {
            return;
        }

        if (self.size[a_set] < self.size[b_set]) {
            std.mem.swap(usize, &a_set, &b_set);
        }

        self.parent[b_set] = a_set;
        self.size[a_set] += self.size[b_set];
        self.num_sets -= 1;
    }

    pub fn getSetSizes(self: *DisjointSetUnion) []const usize {
        return self.size;
    }

    pub fn count(self: *DisjointSetUnion) usize {
        return self.num_sets;
    }
};
