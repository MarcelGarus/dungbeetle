const std = @import("std");
const Vm = @import("vm.zig");

// const Vm = struct {
//     memory: [256]u8,
// };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // There has to be an argument, the file to run.
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len != 2) {
        std.debug.print("You need to provide a file path.\n", .{});
        return;
    }
    const file = args[1];
    std.debug.print("File: {s}\n", .{file});

    // Read from the file.
    var my_file = std.fs.cwd().openFile(file, .{}) catch |err| {
        std.debug.print("Couldn't open file: {}\n", .{err});
        return;
    };
    defer my_file.close();
    var memory: [256]u8 = undefined;
    const read = my_file.read(&memory) catch |err| {
        std.debug.print("Couldn't read from file: {}\n", .{err});
        return;
    };
    for (read..256) |i| {
        memory[i] = 0;
    }
    std.debug.print("Read {d} bytes.\n", .{read});

    // Create a VM.
    const vm = Vm{
        .memory = memory,
    };
    vm.dump();

    // Run the VM.

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
