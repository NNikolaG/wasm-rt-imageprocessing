const std = @import("std");
const allocator = std.heap.wasm_allocator;

extern "env" const memory: [*]u8;

extern fn print(u8) void;
extern fn printi8(i8) void;
extern fn printf16(f16) void;
extern fn printu32(u32) void;
extern fn printusize(usize) void;

/// Allocate `len` bytes in WASM memory. Returns
/// many item pointer on success, null on error.
pub export fn alloc(len: usize) ?[*]u8 {
    return if (allocator.alloc(u8, len)) |slice|
        slice.ptr
    else |_|
        null;
}

/// Free `len` bytes in WASM memory pointed to by `ptr`.
pub export fn free(ptr: [*]u8, len: usize) void {
    allocator.free(ptr[0..len]);
}

fn extractRGB(ptr: [*]u8, i: usize) [3]u32 {
    // Extract and cast the three consecutive u8 values to u32
    return [_]u32{ @intCast(ptr[i]), @intCast(ptr[i + 1]), @intCast(ptr[i + 1]) };
}

export fn grayscale(ptr: [*]u8, len: usize) void {
    var i: u32 = 0;
    while (i < len) : (i += 4) {
        const rgb = extractRGB(ptr, i);

        const gray: u8 = @intCast((rgb[0] + rgb[1] + rgb[2]) / 3);
        ptr[i] = gray;
        ptr[i + 1] = gray;
        ptr[i + 2] = gray;
    }
}

export fn monochrome(ptr: [*]u8, len: usize, r: u32, g: u32, b: u32) void {
    var i: u32 = 0;
    while (i < len) : (i += 4) {
        const rgb = extractRGB(ptr, i);

        ptr[i] = @intCast((rgb[0] * r) / 255);
        ptr[i + 1] = @intCast((rgb[1] * g) / 255);
        ptr[i + 2] = @intCast((rgb[2] * b) / 255);
    }
}

export fn ascii(image_ptr: [*]u8, len: usize, string_ptr: [*]u8, width: u32, inverted: bool) void {
    var i: u32 = 0;
    var j: u32 = 0;
    const ascii_map: []const u8 = " .:-=+*#%@";
    const ascii_map_len: f16 = @floatFromInt(ascii_map.len);

    while (i < len) : (i += 4) {
        const pixel: f32 = @floatFromInt(image_ptr[i]);
        var value: f32 = pixel / 255;
        if (inverted) {
            value = 1 - value;
        }
        const ascii_index: u8 = @intFromFloat(value * (ascii_map_len - 1));
        string_ptr[j] = ascii_map[ascii_index];

        if (j > 0 and j % width == 0) {
            string_ptr[j] = 10;
        }
        j += 1;
    }
}

// TODO
// export fn blur(ptr: [*]u8, len: usize, width: u32, kernel: u8) void {
//     const height = @as(u32, @intCast(len / (4 * width)));
//     const half_kernel = @as(i32, @intCast(kernel / 2));

//     // Create a slice for the entire image
//     const image = ptr[0..len];

//     // Temporary buffer in the imported memory
//     const temp_start = len;
//     const temp = memory[temp_start .. temp_start + len];

//     // Copy original image to temp buffer
//     @memcpy(temp, image);

//     var y: u32 = 0;
//     while (y < height) : (y += 1) {
//         var x: u32 = 0;
//         while (x < width) : (x += 1) {
//             var r: u32 = 0;
//             var g: u32 = 0;
//             var b: u32 = 0;
//             var a: u32 = 0;
//             var count: u32 = 0;

//             var ky: i32 = -half_kernel;
//             while (ky <= half_kernel) : (ky += 1) {
//                 var kx: i32 = -half_kernel;
//                 while (kx <= half_kernel) : (kx += 1) {
//                     const ny = @as(i32, @intCast(y)) + ky;
//                     const nx = @as(i32, @intCast(x)) + kx;

//                     if (ny >= 0 and ny < @as(i32, @intCast(height)) and nx >= 0 and nx < @as(i32, @intCast(width))) {
//                         const idx = @as(usize, @intCast((@as(u32, @intCast(ny)) * width + @as(u32, @intCast(nx))) * 4));
//                         r += temp[idx];
//                         g += temp[idx + 1];
//                         b += temp[idx + 2];
//                         a += temp[idx + 3];
//                         count += 1;
//                     }
//                 }
//             }

//             const idx = (y * width + x) * 4;
//             image[idx] = @as(u8, @intCast(r / count));
//             image[idx + 1] = @as(u8, @intCast(g / count));
//             image[idx + 2] = @as(u8, @intCast(b / count));
//             image[idx + 3] = @as(u8, @intCast(a / count));
//         }
//     }
// }

export fn rgbChannelShift(ptr: [*]u8, width: u32, height: u32, offset: u32, channel_index: u32) void {
    var y: u32 = 0;
    while (y < height) : (y += 1) {
        var x: u32 = 0;
        while (x < width) : (x += 1) {
            const i = (y * width + x) * 4;
            const offset_i = ((y + offset) * width + (x + offset)) * 4;

            const offset_channel_value = ptr[offset_i + channel_index];

            var new_pixel: [4]u8 = undefined;
            new_pixel[0] = if (channel_index == 0) offset_channel_value else ptr[i];
            new_pixel[1] = if (channel_index == 1) offset_channel_value else ptr[i + 1];
            new_pixel[2] = if (channel_index == 2) offset_channel_value else ptr[i + 2];
            new_pixel[3] = 255;

            ptr[i] = new_pixel[0];
            ptr[i + 1] = new_pixel[1];
            ptr[i + 2] = new_pixel[2];
            ptr[i + 3] = new_pixel[3];
        }
    }
}

export fn sepia(ptr: [*]u8, len: usize) void {
    var i: u32 = 0;

    while (i < len) : (i += 4) {
        const r: f32 = @floatFromInt(ptr[i]);
        const g: f32 = @floatFromInt(ptr[i + 1]);
        const b: f32 = @floatFromInt(ptr[i + 2]);

        ptr[i] = @intFromFloat((r * 0.393) + (g * 0.769) + (b * 0.189));
        ptr[i + 1] = @intFromFloat((r * 0.349) + (g * 0.686) + (b * 0.168));
        ptr[i + 2] = @intFromFloat((r * 0.272) + (g * 0.534) + (b * 0.131));
    }
}
