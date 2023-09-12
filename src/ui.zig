pub const width = 68;
pub const height = 18;

cells: [width][height]Cell = undefined,

pub const Cell = struct {
    char: u8,
    style: Style,
};

pub const Style = struct {
    chrome: bool = false,
    reversed: bool = false,
    underlined: bool = false,
    color: ?Color = null,
};

pub const Color = enum {
    red,
    yellow,
    green,
    blue,
    magenta,
    cyan,
};

const Self = @This();

pub fn get_cell(self: Self, x: usize, y: usize) Cell {
    return self.cells[x][y];
}

pub fn clear(self: *Self) void {
    for (0..width) |x| {
        for (0..height) |y| {
            self.write_char(x, y, ' ', .{});
        }
    }
}

pub fn write_char(self: *Self, x: usize, y: usize, char: u8, style: Style) void {
    self.cells[x][y] = .{
        .char = char,
        .style = style,
    };
}

pub fn write_text(self: *Self, x: usize, y: usize, text: []const u8, style: Style) void {
    for (0.., text) |i, char| {
        self.write_char(x + i, y, char, style);
    }
}

pub fn write_hex(self: *Self, x: usize, y: usize, byte: u8, style: Style) void {
    const hex_chars = "0123456789abcdef";
    self.write_char(x, y, hex_chars[byte / 16], style);
    self.write_char(x + 1, y, hex_chars[byte % 16], style);
}
