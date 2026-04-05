const c = @import("c.zig").c;
const tih = @import("termios_input_handler.zig");


pub fn input_handler() tih.UserInput {
    if (c.IsKeyDown(c.KEY_UP)) {
        return .UpButton;
    }
    if (c.IsKeyDown(c.KEY_DOWN)) {
        return .DownButton;
    }
    if (c.IsKeyDown(c.KEY_LEFT)) {
        return .LeftButton;
    }
    if (c.IsKeyDown(c.KEY_RIGHT)) {
        return .RightButton;
    }
    if (c.IsKeyPressed(c.KEY_SPACE)) {
        return .HardDropButton;
    }
    if (c.IsKeyPressed(c.KEY_X)) {
        return .RotCWButton;
    }
    if (c.IsKeyPressed(c.KEY_Z)) {
        return .RotCCWButton;
    }
    if (c.IsKeyPressed(c.KEY_ENTER)) {
        return .PauseButton;
    }
    return .Idle;
}
