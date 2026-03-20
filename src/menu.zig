const std = @import("std");
const Io = std.Io;
const posix = std.posix;
const tih = @import("termios_input_handler.zig");

comptime{
    if (!tih.is_posix) {
        @compileError("Only Posix compliant operating systems are supported. :(");
    }
}

// ╶┬╴╭─╴╶┬╴╭─╮╷╭─╮
//  │ ├╴  │ ├┬╯│╰─╮
//  ╵ ╰─╴ ╵ ╵╰╴╵╰─╯


//\\┏━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━┓
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                 ┏━━━━━━━━━━━━━━━━━━━━━━━━━━┓                 ┃
//\\┃                 ┃     ╶┬╴╭─╴╶┬╴╭─╮╷╭─╮     ┃                 ┃
//\\┃                 ┃      │ ├╴  │ ├┬╯│╰─╮     ┃                 ┃
//\\┃                 ┃      ╵ ╰─╴ ╵ ╵╰╴╵╰─╯     ┃                 ┃
//\\┃                 ┗━━━━━━━━┓        ┏━━━━━━━━┛                 ┃
//\\┃                    ┃     ┃        ┃     ┃                    ┃
//\\┃                    ┃     ┃        ┃     ┃                    ┃
//\\┃                    ┃     ┃        ┃     ┃                    ┃
//\\┃                    ┃     ┗━━━━━━━━┛     ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃      Marathon      ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃      Settings      ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┗━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━┛

//\\┏━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━┓
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                 ┏━━━━━━━━━━━━━━━━━━━━━━━━━━┓                 ┃
//\\┃                 ┃     ╶┬╴╭─╴╶┬╴╭─╮╷╭─╮     ┃                 ┃
//\\┃                 ┃      │ ├╴  │ ├┬╯│╰─╮     ┃                 ┃
//\\┃                 ┃      ╵ ╰─╴ ╵ ╵╰╴╵╰─╯     ┃                 ┃
//\\┃                 ┗━━━━━━━━┓        ┏━━━━━━━━┛                 ┃
//\\┃                    ┃     ┃        ┃     ┃                    ┃
//\\┃                    ┃     ┃        ┃     ┃                    ┃
//\\┃                    ┃     ┃        ┃     ┃                    ┃
//\\┃                    ┃     ┗━━━━━━━━┛     ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃      Settings      ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃      Theme A       ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃      Default       ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┃                    ┃                    ┃                    ┃
//\\┗━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━┛


// const ProgramState = enum {
//     StartMenu,
//     Game,
//     PauseMenu,
//     Gameover,
// };
// 
// pub const Config = struct {};
// 
// pub const Menu = struct {
//     config: Config,
// 
//     pub fn menu_loop(self: *Menu, reader: *Io.Reader, writer: *Io.Writer) void {
//         var running = true;
//         while (running) {
//             const input = tih.InputHandler(reader, writer);
// 
//             switch (input) {
//                 
//             }
//             
//             running = false;
//         }
//     }
// 
//     pub fn format(self: Menu, writer: *Io.writer) !void {
//         for (0..MAXCOLS) |_| {
//             
//         }
//     }
// 
// };
// 
// 
