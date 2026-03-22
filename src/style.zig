
pub const Style = struct {
    upper_left_corner: []const u8,
    upper_right_corner: []const u8,
    lower_left_corner: []const u8,
    lower_right_corner: []const u8,
    upper_tee: []const u8,
    lower_tee: []const u8,
    top_border: []const u8,
    bottom_border: []const u8,
    left_border: []const u8,
    right_border: []const u8,
    empty_block: []const u8,
    mino_block: []const u8,
};

pub const base_style: Style = .{
    .upper_left_corner =  "\u{250F}",
    .upper_right_corner = "\u{2513}",
    .lower_left_corner = "\u{2517}",
    .lower_right_corner = "\u{251B}",
    .upper_tee = "\u{2533}",
    .lower_tee = "\u{253B}",
    .top_border = "\u{2501}",
    .bottom_border =  "\u{2501}",
    .left_border = "\u{2503}",
    .right_border =  "\u{2503}",
    .empty_block = "  ",
    .mino_block = "\u{2588}" ** 2,
};

pub const blocky_style: Style = .{
    .upper_left_corner =  "\u{250F}",
    .upper_right_corner = "\u{2513}",
    .lower_left_corner = "\u{2517}",
    .lower_right_corner = "\u{251B}",
    .upper_tee = "\u{2533}",
    .lower_tee = "\u{253B}",
    .top_border = "\u{2501}",
    .bottom_border =  "\u{2501}",
    .left_border = "\u{2503}",
    .right_border =  "\u{2503}",
    .empty_block = "◾",
    .mino_block = "◽",
};

pub const ascii_style: Style = .{
    .upper_left_corner =  "+",
    .upper_right_corner = "+",
    .lower_left_corner = "+",
    .lower_right_corner = "+",
    .upper_tee = "+",
    .lower_tee = "+",
    .top_border = "-",
    .bottom_border =  "-",
    .left_border = "|",
    .right_border =  "|",
    .empty_block = " .",
    .mino_block = "[]",
};
