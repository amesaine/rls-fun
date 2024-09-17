// This is just an overview of the algorithm logic.
// It does not reproduce the undefined assignment.
pub fn main() !void {
    var list = std.ArrayList(u8).init(std.heap.page_allocator);

    const idx = try reserve(&list);
    list.items[idx] = try parse(&list);

    std.debug.print("{any}", .{list.items});
    // Output: {1, 2}
    // In my original program, it would be: {2863311530, 2}
}

fn reserve(list: *std.ArrayList(u8)) !usize {
    try list.resize(list.items.len + 1);
    return list.items.len - 1;
}

fn parse(list: *std.ArrayList(u8)) !u8 {
    try list.append(2);
    return 1;
}

const std = @import("std");
