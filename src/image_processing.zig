const std = @import("std");
const allocator = std.heap.wasm_allocator;

extern fn print(u8) void;
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

export fn blur(ptr: [*]u8, len: usize, width: u32, kernel: u8) void {
    var i: u32 = 0;
    while (i < len) : (i += 4) {
        const halfKernel: i8 = @intCast((kernel / 2) * 4);
        const rowStart: u32 = ptr[i] / width;
        const colStart: u32 = ptr[i] % width;

        var j: i8 = -halfKernel;
        var k: i8 = -halfKernel;
        var sum_r: u32 = 0;
        var sum_g: u32 = 0;
        var sum_b: u32 = 0;

        while (j <= halfKernel) : (j += 4) {
            while (k <= halfKernel) : (k += 4) {
                var row: u32 = 0;
                var col: u32 = 0;

                if (j < 0) {
                    const temp: u32 = @intCast(j);
                    row = rowStart - temp;
                } else {
                    const temp: u32 = @intCast(j);
                    row = rowStart + temp;
                }
                if (k < 0) {
                    const temp: u32 = @intCast(k);
                    col = colStart - temp;
                } else {
                    const temp: u32 = @intCast(k);
                    col = colStart + temp;
                }

                const r: f64 = @floatFromInt(len);
                const c: f64 = @floatFromInt(width);
                const x: f64 = @floatFromInt(row);
                if (row < 0 or x >= @ceil(r / c)) continue;
                if (col < 0 or row >= width) continue;

                const index: u32 = row * width + col;

                if (index >= 0 and index <= len) {
                    sum_r += ptr[index];
                    sum_g += ptr[index + 1];
                    sum_b += ptr[index + 2];
                }
            }
        }
        const avg_r: u32 = sum_r / kernel * kernel;
        const avg_g: u32 = sum_g / kernel * kernel;
        const avg_b: u32 = sum_b / kernel * kernel;

        ptr[i] = @intCast(avg_r);
        ptr[i + 1] = @intCast(avg_g);
        ptr[i + 2] = @intCast(avg_b);
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
