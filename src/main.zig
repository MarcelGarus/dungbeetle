const std = @import("std");
const Vm = @import("vm.zig");
const c = @cImport({
    @cInclude("termios.h");
    @cInclude("unistd.h");
    @cInclude("stdlib.h");
});
const zbox = @import("zbox");

var orig_termios: c.termios = undefined;

pub fn enableRawMode() void {
    _ = c.tcgetattr(c.STDIN_FILENO, &orig_termios);
    _ = c.atexit(disableRawMode);

    var raw: c.termios = undefined;
    raw.c_lflag &= ~(@as(u8, c.ECHO) | @as(u8, c.ICANON));

    _ = c.tcsetattr(c.STDIN_FILENO, c.TCSAFLUSH, &raw);
}

pub fn disableRawMode() callconv(.C) void {
    _ = c.tcsetattr(c.STDIN_FILENO, c.TCSAFLUSH, &orig_termios);
}

// const Vm = struct {
//     memory: [256]u8,
// };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var memory: [256]u8 = undefined;

    // You can specify an argument, the file to run.
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    switch (args.len) {
        1 => {
            for (0..256) |i| {
                memory[i] = 0;
            }
        },
        2 => {
            var my_file = std.fs.cwd().openFile(args[1], .{}) catch |err| {
                std.debug.print("Couldn't open file: {}\n", .{err});
                return;
            };
            const file = args[1];
            std.debug.print("File: {s}\n", .{file});

            // Read from the file.
            defer my_file.close();
            const read = my_file.read(&memory) catch |err| {
                std.debug.print("Couldn't read from file: {}\n", .{err});
                return;
            };
            for (read..256) |i| {
                memory[i] = 0;
            }
        },
        else => {
            std.debug.print("You provided too many arguments.\n", .{});
            return;
        }
    }

    // Create a VM.
    var vm = Vm{
        .memory = memory,
    };

    // initialize the display with stdin/out
    try zbox.init(&allocator);
    defer zbox.deinit();

    // ignore ctrl+C
    try zbox.ignoreSignalInput();
    try zbox.cursorHide();
    defer zbox.cursorShow() catch {};

    enableRawMode();
    var char: u8 = undefined;
    const stdin = std.io.getStdIn().reader();

    var output = try zbox.Buffer.init(&allocator, 20, 80);
    defer output.deinit();

    while (true) {
        vm.dump_to_buffer(&output);

        const hex_chars = "0123456789abcdef";
        output.cellRef(19, 1).* = .{
            .char = hex_chars[char / 16],
        };
        output.cellRef(19, 2).* = .{
            .char = hex_chars[char % 16],
        };

        try zbox.push(output);

        char = try stdin.readByte();
        // std.debug.print("char: {x}\n", .{char});
        switch (char) {
            // Q to quit.
            'Q' => break,
            // Move using arrows.
            0x41 => vm.move_up(),
            0x42 => vm.move_down(),
            0x43 => vm.move_right(),
            0x44 => vm.move_left(),
            // Literal input for letters, space, and digits.
            '0'...'9' => vm.enter(char),
            'a'...'z' => vm.enter(char),
            // 'A'...'Z' => vm.enter(char),
            ' ' => vm.enter(char),
            0x7f => vm.backspace(),
            // Comma and dot for decreasing / increasing.
            ',' => vm.dec(),
            '.' => vm.inc(),
            // Tab to run one instruction.
            0x09 => try vm.run(),
            // Hash sign to run until next halt.
            0x23 => try vm.run(), // TODO
            else => {},
        }
    }

    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
