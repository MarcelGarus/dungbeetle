const std = @import("std");
const Vm = @import("vm.zig");
const c = @cImport({
    @cInclude("termios.h");
    @cInclude("unistd.h");
    @cInclude("stdlib.h");
});
const zbox = @import("zbox");
const Ui = @import("ui.zig");

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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var memory: [256]u8 = undefined;

    // You can specify an argument, the file to run.
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const file = switch (args.len) {
        1 => null,
        2 => args[1],
        else => {
            std.debug.print("You provided too many arguments.\n", .{});
            return;
        },
    };

    if (file) |f| {
        var my_file = std.fs.cwd().openFile(f, .{}) catch |err| {
            std.debug.print("Couldn't open file: {}\n", .{err});
            return;
        };
        defer my_file.close();

        const read = my_file.read(&memory) catch |err| {
            std.debug.print("Couldn't read from file: {}\n", .{err});
            return;
        };
        for (read..256) |i| {
            memory[i] = 0;
        }
    } else {
        for (0..256) |i| {
            memory[i] = 0;
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

    var ui = Ui{};
    var output = try zbox.Buffer.init(&allocator, Ui.height, Ui.width);
    defer output.deinit();

    while (true) {
        vm.render_to_ui(&ui);
        ui.write_hex(Ui.width - 4, 18, char, .{});

        for (0..Ui.width) |x| {
            for (0..Ui.height) |y| {
                const cell = ui.get_cell(x, y);
                output.cellRef(y, x).* = .{
                    .char = cell.char,
                    .attribs = .{
                        .reverse = cell.style.reversed,
                        .underline = cell.style.underlined,
                        .bg_yellow = cell.style.chrome,
                        .fg_red = cell.style.color == .red,
                        .fg_yellow = cell.style.color == .yellow,
                        .fg_green = cell.style.color == .green,
                        .fg_blue = cell.style.color == .blue,
                        .fg_magenta = cell.style.color == .magenta,
                        .fg_cyan = cell.style.color == .cyan,
                    },
                };
            }
        }

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
            // Literal input for lowercase letters, space, and digits.
            '0'...'9' => vm.input(char),
            'a'...'z' => vm.input(char),
            '-' => vm.input(char),
            ':' => vm.input(char),
            0x7f => vm.backspace(),
            // Comma and dot for decreasing / increasing.
            ',' => vm.dec(),
            '.' => vm.inc(),
            // Space to run one instruction.
            ' ' => {
                vm.run() catch {
                    std.debug.print("Invalid instruction.", .{});
                };
            },
            // Tab to run until next halt.
            0x09 => try vm.run(), // TODO
            // S to save.
            'S' => {
                if (file) |f| {
                    var my_file = std.fs.cwd().openFile(f, .{ .mode = .write_only }) catch |err| {
                        std.debug.print("Couldn't open file: {}\n", .{err});
                        continue;
                    };
                    defer my_file.close();

                    _ = my_file.write(&vm.memory) catch |err| {
                        std.debug.print("Couldn't write to file: {}\n", .{err});
                        continue;
                    };

                    std.debug.print("Written.", .{});
                }
            },
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
