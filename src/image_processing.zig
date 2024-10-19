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

fn squareDistance(a: [3]u8, b: [3]u8) i32 {
    const dr = @as(i32, a[0]) - @as(i32, b[0]);
    const dg = @as(i32, a[1]) - @as(i32, b[1]);
    const db = @as(i32, a[2]) - @as(i32, b[2]);
    return dr * dr + dg * dg + db * db;
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

export fn box_blur(ptr: [*]u8, width: u32, height: u32, kernel_size: u8, temp_pixels: [*]u8) void {
    // First, apply the horizontal blur
    horizontal_blur(ptr, width, height, temp_pixels, kernel_size);

    // Then, apply the vertical blur using the temp_pixels as the source and ptr as the destination
    vertical_blur(temp_pixels, width, height, ptr, kernel_size);
}

fn horizontal_blur(src: [*]u8, width: u32, height: u32, dst: [*]u8, kernel_size: u32) void {
    const half_k: u32 = kernel_size / 2;
    const normalization_factor: f32 = @floatFromInt(kernel_size);

    // Apply horizontal blur
    var y: u32 = 0;
    while (y < height) : (y += 1) {
        var x: u32 = 0;
        while (x < width) : (x += 1) {
            const i = (y * width + x) * 4;

            var sum_r: f32 = 0.0;
            var sum_g: f32 = 0.0;
            var sum_b: f32 = 0.0;

            // Blur over the horizontal range
            var kx: u32 = 0;
            while (kx < kernel_size) : (kx += 1) {
                const xi: i32 = @intCast(x);
                const kxi: i32 = @intCast(kx);
                const half_ki: i32 = @intCast(half_k);

                const max_value: i32 = @intCast(width - 1);

                const neighbor_x: u32 = @intCast(clamp_i32(xi + kxi - half_ki, 0, max_value));
                const offset_i = (y * width + neighbor_x) * 4;

                sum_r += @floatFromInt(src[offset_i]);
                sum_g += @floatFromInt(src[offset_i + 1]);
                sum_b += @floatFromInt(src[offset_i + 2]);
            }

            dst[i] = @as(u8, @intFromFloat(sum_r / normalization_factor));
            dst[i + 1] = @as(u8, @intFromFloat(sum_g / normalization_factor));
            dst[i + 2] = @as(u8, @intFromFloat(sum_b / normalization_factor));
            dst[i + 3] = 255; // Assuming alpha remains 255
        }
    }
}

fn vertical_blur(src: [*]u8, width: u32, height: u32, dst: [*]u8, kernel_size: u32) void {
    const half_k: u32 = kernel_size / 2;
    const normalization_factor: f32 = @floatFromInt(kernel_size);

    // Apply vertical blur
    var y: u32 = 0;
    while (y < height) : (y += 1) {
        var x: u32 = 0;
        while (x < width) : (x += 1) {
            const i = (y * width + x) * 4;

            var sum_r: f32 = 0.0;
            var sum_g: f32 = 0.0;
            var sum_b: f32 = 0.0;

            // Blur over the vertical range
            var ky: u32 = 0;
            while (ky < kernel_size) : (ky += 1) {
                const yi: i32 = @intCast(y);
                const kyi: i32 = @intCast(ky);
                const half_ki: i32 = @intCast(half_k);

                const max_value: i32 = @intCast(height - 1);

                const neighbor_y: u32 = @intCast(clamp_i32(yi + kyi - half_ki, 0, max_value));
                const offset_i = (neighbor_y * width + x) * 4;

                sum_r += @floatFromInt(src[offset_i]);
                sum_g += @floatFromInt(src[offset_i + 1]);
                sum_b += @floatFromInt(src[offset_i + 2]);
            }

            dst[i] = @as(u8, @intFromFloat(sum_r / normalization_factor));
            dst[i + 1] = @as(u8, @intFromFloat(sum_g / normalization_factor));
            dst[i + 2] = @as(u8, @intFromFloat(sum_b / normalization_factor));
            dst[i + 3] = 255; // Assuming alpha remains 255
        }
    }
}

fn clamp_i32(value: i32, min_value: i32, max_value: i32) i32 {
    if (value < min_value) return min_value;
    if (value > max_value) return max_value;
    return value;
}

fn conv(ptr: [*]u8, width: u32, height: u32, kernel: []const f32, kernel_size: u8, temp_pixels: [*]u8) void {
    const total_pixels: usize = @as(usize, width * height * 4);
    const half_k: u32 = kernel_size / 2;

    var y: u32 = half_k;
    while (y < height - half_k) : (y += 1) {
        var x: u32 = half_k;
        while (x < width - half_k) : (x += 1) {
            const i = (y * width + x) * 4;

            if (i >= total_pixels - 3) {
                continue;
            }

            var sum_r: f32 = 0.0;
            var sum_g: f32 = 0.0;
            var sum_b: f32 = 0.0;

            var ki: usize = 0;
            var ky: u32 = 0;
            while (ky < kernel_size) : (ky += 1) {
                var kx: u32 = 0;
                while (kx < kernel_size) : (kx += 1) {
                    const neighbor_x: u32 = x + kx - half_k;
                    const neighbor_y: u32 = y + ky - half_k;

                    // Boundary checks to prevent out-of-bounds access
                    if (neighbor_x < 0 or neighbor_x >= width or neighbor_y < 0 or neighbor_y >= height) {
                        continue;
                    }

                    const offset_i = ((y + ky - 1) * width + (x + kx - 1)) * 4;

                    // Bounds checking for offset_i
                    if (offset_i >= total_pixels - 3) {
                        continue;
                    }

                    sum_r += @as(f32, @floatFromInt(ptr[offset_i])) * kernel[ki];
                    sum_g += @as(f32, @floatFromInt(ptr[offset_i + 1])) * kernel[ki];
                    sum_b += @as(f32, @floatFromInt(ptr[offset_i + 2])) * kernel[ki];
                    ki += 1;
                }
            }
            if (i < total_pixels - 3) {
                const normalization_factor = @as(f32, @floatFromInt(kernel_size * kernel_size));

                temp_pixels[i] = @as(u8, @intFromFloat(sum_r / normalization_factor));
                temp_pixels[i + 1] = @as(u8, @intFromFloat(sum_g / normalization_factor));
                temp_pixels[i + 2] = @as(u8, @intFromFloat(sum_b / normalization_factor));
                temp_pixels[i + 3] = 255;
            }
        }
    }

    var idx: usize = 0;
    while (idx < total_pixels) : (idx += 1) {
        ptr[idx] = temp_pixels[idx];
    }
}

export fn channel_shift(ptr: [*]u8, width: u32, height: u32, offset: u32, channel_index: u32) void {
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

export fn ryo(ptr: [*]u8, len: usize) void {
    var i: usize = 0;
    while (i < len) : (i += 4) {
        ptr[i] = 255 - ptr[i];
        ptr[i + 2] = 255 - ptr[i + 2];
    }
}

export fn lix(ptr: [*]u8, len: usize) void {
    var i: usize = 0;
    while (i < len) : (i += 4) {
        ptr[i] = 255 - ptr[i];
        ptr[i + 1] = 255 - ptr[i + 1];
    }
}

export fn neue(ptr: [*]u8, len: usize) void {
    var i: usize = 0;
    while (i < len) : (i += 4) {
        const b_val = ptr[i + 2];
        if (@as(i32, 255) - @as(i32, b_val) > 0) {
            ptr[i + 2] = 255 - b_val;
        }
    }
}

export fn colorize(ptr: [*]u8, width: u32, height: u32) void {
    const threshold: i32 = 220;
    const threshold_squared = threshold * threshold;
    const baseline_color = [3]u8{ 0, 255, 255 };

    var y: u32 = 0;
    while (y < height) : (y += 1) {
        var x: u32 = 0;
        while (x < width) : (x += 1) {
            const i = (y * width + x) * 4;
            const pixel = [3]u8{ ptr[i], ptr[i + 1], ptr[i + 2] };

            const distance = squareDistance(baseline_color, pixel);

            if (distance < threshold_squared) {
                const r = @as(f32, @floatFromInt(pixel[0])) * 0.5;
                const g = @as(f32, @floatFromInt(pixel[1])) * 1.25;
                const b = @as(f32, @floatFromInt(pixel[2])) * 0.5;

                ptr[i] = @intFromFloat(std.math.clamp(r, 0, 255));
                ptr[i + 1] = @intFromFloat(std.math.clamp(g, 0, 255));
                ptr[i + 2] = @intFromFloat(std.math.clamp(b, 0, 255));
            }
        }
    }
}

export fn solarize(ptr: [*]u8, len: usize) void {
    var i: usize = 0;
    while (i < len) : (i += 4) {
        const r_val = ptr[i];
        if (@as(i32, 200) - @as(i32, r_val) > 0) {
            ptr[i] = @intCast(200 - r_val);
        }
    }
}
