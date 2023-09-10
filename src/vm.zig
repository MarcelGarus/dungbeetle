const std = @import("std");

memory: [256]u8,
ip: u8 = 0, // Instruction pointer.

pub fn dump(self: @This()) void {
    const bytes_per_row = 16;
    
    for (0..(256 / bytes_per_row)) |i| {
        // Hex part
        for (0..bytes_per_row) |j| {
            const pos = i * bytes_per_row + j;
            if (pos == self.ip) {
                std.debug.print("[", .{});
            } else if (pos == self.ip + 1) {
                std.debug.print("]", .{});
            } else {
                std.debug.print(" ", .{});
            }
            std.debug.print("{x:2}", .{self.memory[pos]});
        }
        if ((i + 1) * bytes_per_row == self.ip + 1) {
            std.debug.print("]", .{});
        } else {
            std.debug.print(" ", .{});
        }
        std.debug.print(" ", .{});

        // ASCII part
        for (0..bytes_per_row) |j| {
            const pos = i * bytes_per_row + j;
            const char = switch (self.memory[pos]) {
                32...126 => self.memory[pos],
                else => '.',
            };
            std.debug.print("{c}", .{char});
        }

        std.debug.print("\n", .{});
    }
    // std.debug.print("{any}", .{self.memory});
}
