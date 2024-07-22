const std = @import("std");

extern fn print(ptr: u32, len: u32) void;

/// ASCII value for `' '`
const ASCII_SPACE: u8 = 32;
const ASCII_NEWLINE: u8 = 10;
const PI: f32 = 3.14;

const SCREEN_WIDTH: i32 = 80;
const SCREEN_HEIGHT: i32 = 24;

/// Radius of cross section circle
/// OR how thick donut is
var R1: f32 = 0.85;

/// Distance from center of donut to
/// center of cross section circle
/// OR size of hole in donut
var R2: f32 = 2;

/// Distance of object from viewer
var K2: f32 = 5;

/// Increment of first axis to rotate on
/// per frame, controls speed of rotations
var A_INCREMENT: f32 = 0.00004;

/// Increment of second axis to rotate on
/// per frame, controls speed of rotations
var B_INCREMENT: f32 = 0.00002;

/// Increment of each angle for all values between 0 till 2pi
/// Smaller theta increments = more points in R1 circle
var THETA_INCREMENT: f32 = 0.07;

/// Increment of each angle for all values between 0 till 2pi
/// Smaller phi increments = more points in R2 circle
var PHI_INCREMENT: f32 = 0.03;

// Z index of each point (stored as 1 / sqrt(z))
var z_buffer: [SCREEN_WIDTH * SCREEN_HEIGHT]f32 = undefined;
// ASCII char value at each  point
var char_buffer: [SCREEN_WIDTH * SCREEN_HEIGHT]u8 = undefined;

var A: f32 = 0;
var B: f32 = 0;

/// The returned pointer will be used as an offset integer to the wasm memory
export fn getCharBufferPtr() [*]u8 {
    return @ptrCast(&char_buffer);
}

export fn getScreenHeight() i32 {
    return SCREEN_HEIGHT;
}

export fn getScreenWidth() i32 {
    return SCREEN_WIDTH;
}

export fn getR1() f32 {
    return R1;
}

export fn setR1(r1: f32) void {
    R1 = r1;
}

export fn getR2() f32 {
    return R2;
}

export fn setR2(r2: f32) void {
    R2 = r2;
}

export fn getK2() f32 {
    return K2;
}

export fn setK2(k2: f32) void {
    K2 = k2;
}

export fn getA() f32 {
    return A;
}

export fn setA(a: f32) void {
    A = a;
}

export fn getB() f32 {
    return B;
}

export fn setB(b: f32) void {
    B = b;
}

export fn getAIncrement() f32 {
    return A_INCREMENT;
}

export fn setAIncrement(increment: f32) void {
    A_INCREMENT = increment;
}

export fn getBIncrement() f32 {
    return B_INCREMENT;
}

export fn setBIncrement(increment: f32) void {
    B_INCREMENT = increment;
}

export fn getThetaIncrement() f32 {
    return THETA_INCREMENT;
}

export fn setThetaIncrement(increment: f32) void {
    THETA_INCREMENT = increment;
}

export fn getPhiIncrement() f32 {
    return PHI_INCREMENT;
}

export fn setPhiIncrement(increment: f32) void {
    PHI_INCREMENT = increment;
}

var log_buf: [100]u8 = undefined;

/// We take `char_buffer` and `z_buffer` as array pointers instead of slices since
/// `@memset` uses 'C' style syntax and expects a pointer to an array when this fn is
/// exported with `export`. Slice references are also passed as const pointers, which
/// cannot work with `@memset`
export fn render_frame() void {
    // Set up text, z buffer arrays
    @memset(&z_buffer, 0);
    @memset(&char_buffer, ASCII_SPACE);

    const res = std.fmt.bufPrint(&log_buf, "a: {}, b: {}, a_increment: {}, b_increment: {}, theta_increment: {}, phi_increment: {}", .{ A, B, A_INCREMENT, B_INCREMENT, THETA_INCREMENT, PHI_INCREMENT });

    if (res) |s| {
        const log_ptr_int = @intFromPtr(s.ptr);
        print(log_ptr_int, s.len);
    } else |_| {
        const log_ptr: [*]u8 = @ptrCast(&log_buf);
        const log_ptr_int = @intFromPtr(log_ptr);
        print(log_ptr_int, 100);
    }

    const sin_A = std.math.sin(A);
    const cos_A = std.math.cos(A);
    const sin_B = std.math.sin(B);
    const cos_B = std.math.cos(B);

    var i: u32 = 0;
    while (i < SCREEN_WIDTH * SCREEN_HEIGHT) : (i += (SCREEN_WIDTH - 1)) {
        char_buffer[i] = ASCII_NEWLINE;
    }

    var theta: f32 = 0.0;
    // Theta goes around the cross-sectional circle of a torus (0 to 2pi)
    while (theta < 2 * PI) : (theta += THETA_INCREMENT) {

        // Precompute sines, cosines of theta
        const sin_theta = std.math.sin(theta);
        const cos_theta = std.math.cos(theta);

        var phi: f32 = 0.0;
        // Phi goes around the center of revolution of a torus (0 to 2pi)
        while (phi < 2 * PI) : (phi += PHI_INCREMENT) {

            // Precompute sines, cosines of phi
            const sin_phi = std.math.sin(phi);
            const cos_phi = std.math.cos(phi);

            // the x coordinate of the circle (R2 + R1*cos(theta))
            const h: f32 = R2 + R1 * cos_theta;

            const z = (sin_phi * h * sin_A + sin_theta * cos_A + K2);
            const D: f32 = 1 / z;

            // this is a clever factoring of some of the terms in x' and y'
            const t: f32 = (sin_phi * h * cos_A) - (sin_theta * sin_A);

            const center_x: f32 = (SCREEN_WIDTH / 2) - 10;
            // const center_x: f32 = 40;
            const x: i32 = @intFromFloat(center_x + 30 * D * (cos_phi * h * cos_B - t * sin_B));

            const center_y: f32 = SCREEN_HEIGHT / 2;
            // const center_y: f32 = 12;
            const y: i32 = @intFromFloat(center_y + 15 * D * (cos_phi * h * sin_B + t * cos_B));

            // index in char buffer for x,y coordinate
            const o: i32 = x + SCREEN_WIDTH * y;
            const o_u: u32 = @as(u32, @intCast(o));

            // determine ascii char for x,y coordinate based on brightness
            const L: i32 = @intFromFloat(8 * ((sin_theta * sin_A - sin_phi * cos_theta * cos_A) * cos_B - sin_phi * cos_theta * sin_A - sin_theta * cos_A - cos_phi * cos_theta * sin_B));

            if (y < SCREEN_HEIGHT and y >= 0 and x < (SCREEN_WIDTH - 1) and x >= 0 and D > z_buffer[o_u]) {
                z_buffer[o_u] = D;
                if (L > 0) {
                    char_buffer[o_u] = ".,-~:;=!*#$@"[@as(u32, @intCast(L))];
                } else {
                    char_buffer[o_u] = ".,-~:;=!*#$@"[0];
                }
            }
        }
    }

    A += A_INCREMENT * (SCREEN_HEIGHT * SCREEN_WIDTH);
    B += B_INCREMENT * (SCREEN_HEIGHT * SCREEN_WIDTH);
}

// pub fn main() !void {
//     // const stdout_file = std.io.getStdOut().writer();
//     // var bw = std.io.bufferedWriter(stdout_file);
//     // var stdout = bw.writer().any();
//
//     // 2 axes of rotation
//     // var A: f32 = 0;
//     // var B: f32 = 0;
//
//     // Z index of each point (stored as 1 / sqrt(z))
//     // var z_buffer: [SCREEN_WIDTH * SCREEN_HEIGHT]f32 = undefined;
//     // // ASCII char value at each  point
//     // var char_buffer: [SCREEN_WIDTH * SCREEN_HEIGHT]u8 = undefined;
//
//     // Clear output and move cursor to home and hide cursor
//     // try stdout.print("\x1b[?25l", .{});
//     // try bw.flush();
//
//     while (true) {
//         render_frame(A, B, &char_buffer, &z_buffer);
//
//         // try stdout.print("\x1B[2J\x1B[H", .{});
//         var k: u32 = 0;
//         while (k < SCREEN_HEIGHT * SCREEN_WIDTH + 1) : (k += 1) {
//             if (@rem(k, SCREEN_WIDTH) != 0) {
//                 try stdout.print("{c}", .{char_buffer[@as(u32, @intCast(k))]});
//             } else {
//                 try stdout.print("{c}", .{10});
//             }
//         }
//         try bw.flush();
//         std.time.sleep(FPNS);
//     }
//     _ = &z_buffer;
//     _ = &char_buffer;
// }
