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
    return [_]u32{ @intCast(ptr[i]), @intCast(ptr[i + 1]), @intCast(ptr[i + 2]) };
}

fn squareDistance(a: [3]u8, b: [3]u8) i32 {
    const dr = @as(i32, a[0]) - @as(i32, b[0]);
    const dg = @as(i32, a[1]) - @as(i32, b[1]);
    const db = @as(i32, a[2]) - @as(i32, b[2]);
    return dr * dr + dg * dg + db * db;
}

export fn grayscale(ptr: [*]u8, len: usize) void {
    var i: usize = 0;
    while (i + 3 < len) : (i += 4) {
        const r = @as(u32, ptr[i]);
        const g = @as(u32, ptr[i + 1]);
        const b = @as(u32, ptr[i + 2]);

        // Fast approximation: (r + g + b) * 85 >> 8 ≈ (r + g + b) / 3
        // 85/256 ≈ 1/3, so we use bit shifting for performance
        const gray: u8 = @as(u8, @intCast(((r + g + b) * 85) >> 8));
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

/// Optimized sepia filter using direct memory access and reduced conversions.
/// Processes 4 pixels at a time with minimal SIMD overhead.
pub export fn sepia(ptr: [*]u8, len: usize) void {
    // Simple scalar sepia implementation with safe integer arithmetic
    var i: usize = 0;
    while (i + 3 < len) : (i += 4) {
        const r = @as(u32, ptr[i]);
        const g = @as(u32, ptr[i + 1]);
        const b = @as(u32, ptr[i + 2]);

        // Sepia transformation using integer math (coefficients scaled by 1024 for precision)
        // Original: r*0.393 + g*0.769 + b*0.189
        const new_r_scaled = r * 402 + g * 787 + b * 194; // Sum: 1383, max: 255*1383 = 352,665
        const new_g_scaled = r * 357 + g * 702 + b * 172; // Sum: 1231, max: 255*1231 = 313,905
        const new_b_scaled = r * 278 + g * 547 + b * 134; // Sum: 959,  max: 255*959  = 244,545

        // Divide by 1024 (>> 10) and clamp to 0-255
        const new_r = @min(new_r_scaled >> 10, 255);
        const new_g = @min(new_g_scaled >> 10, 255);
        const new_b = @min(new_b_scaled >> 10, 255);

        ptr[i] = @as(u8, @intCast(new_r));
        ptr[i + 1] = @as(u8, @intCast(new_g));
        ptr[i + 2] = @as(u8, @intCast(new_b));
        // Alpha channel (ptr[i + 3]) remains unchanged
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
    // Optimized neue filter: inverts blue channel if not at maximum value
    var i: usize = 0;
    while (i + 3 < len) : (i += 4) {
        const b_val = ptr[i + 2];
        if (b_val != 255) {
            ptr[i + 2] = 255 - b_val;
        }
        // Red, green, and alpha channels remain unchanged
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

pub export fn solarize(ptr: [*]u8, len: usize) void {
    // Optimized solarize filter: flips red channel values below threshold
    const threshold: u8 = 200;
    var i: usize = 0;
    while (i + 3 < len) : (i += 4) {
        const r = ptr[i];
        if (r < threshold) {
            ptr[i] = threshold - r;
        }
        // Green, blue, and alpha channels remain unchanged
    }
}

// === BATCH 1: CLASSIC PHOTO FILTERS ===

/// Vignette effect - darkens edges, keeps center bright
pub export fn vignette(ptr: [*]u8, len: usize, width: u32, height: u32, intensity: f32) void {
    // Safety checks
    if (width == 0 or height == 0 or len == 0) return;

    const center_x: f32 = @as(f32, @floatFromInt(width)) * 0.5;
    const center_y: f32 = @as(f32, @floatFromInt(height)) * 0.5;
    const max_distance: f32 = @sqrt(center_x * center_x + center_y * center_y);

    // Prevent division by zero
    if (max_distance == 0.0) return;

    var i: usize = 0;
    var y: u32 = 0;
    while (y < height) : (y += 1) {
        var x: u32 = 0;
        while (x < width) : (x += 1) {
            // Bounds checking
            if (i + 3 >= len) return;

            // Calculate distance from center
            const dx: f32 = @as(f32, @floatFromInt(x)) - center_x;
            const dy: f32 = @as(f32, @floatFromInt(y)) - center_y;
            const distance: f32 = @sqrt(dx * dx + dy * dy);

            // Calculate vignette factor (0.0 = black edges, 1.0 = no effect)
            const normalized_distance: f32 = distance / max_distance;
            const vignette_factor: f32 = 1.0 - (normalized_distance * @max(0.0, @min(1.0, intensity)));
            const factor: f32 = @max(0.0, @min(1.0, vignette_factor));

            // Apply vignette to RGB channels with safe casting
            const r: f32 = @as(f32, @floatFromInt(ptr[i])) * factor;
            const g: f32 = @as(f32, @floatFromInt(ptr[i + 1])) * factor;
            const b: f32 = @as(f32, @floatFromInt(ptr[i + 2])) * factor;

            ptr[i] = @as(u8, @intFromFloat(@max(0.0, @min(255.0, r))));
            ptr[i + 1] = @as(u8, @intFromFloat(@max(0.0, @min(255.0, g))));
            ptr[i + 2] = @as(u8, @intFromFloat(@max(0.0, @min(255.0, b))));

            i += 4;
        }
    }
}

/// Film grain effect - adds random noise for vintage look
pub export fn film_grain(ptr: [*]u8, len: usize, intensity: u32) void {
    var seed: u32 = 12345;
    var i: usize = 0;
    while (i + 3 < len) : (i += 4) {
        // Simple linear congruential generator for noise
        seed = seed *% 1103515245 +% 12345;
        const noise: i32 = @as(i32, @intCast((seed >> 16) & 0xFF)) - 128;
        const grain: i32 = (noise * @as(i32, @intCast(intensity))) >> 8;

        // Apply grain to RGB channels
        const r: i32 = @as(i32, ptr[i]) + grain;
        const g: i32 = @as(i32, ptr[i + 1]) + grain;
        const b: i32 = @as(i32, ptr[i + 2]) + grain;

        ptr[i] = @as(u8, @intCast(@max(0, @min(255, r))));
        ptr[i + 1] = @as(u8, @intCast(@max(0, @min(255, g))));
        ptr[i + 2] = @as(u8, @intCast(@max(0, @min(255, b))));
    }
}

/// Cross process effect - dramatic color curve manipulation
pub export fn cross_process(ptr: [*]u8, len: usize) void {
    var i: usize = 0;
    while (i + 3 < len) : (i += 4) {
        const r = @as(f32, @floatFromInt(ptr[i])) / 255.0;
        const g = @as(f32, @floatFromInt(ptr[i + 1])) / 255.0;
        const b = @as(f32, @floatFromInt(ptr[i + 2])) / 255.0;

        // S-curve for dramatic contrast
        const new_r: f32 = r * r * (3.0 - 2.0 * r);
        const new_g: f32 = g * 0.9 + 0.1;  // Slight green tint
        const new_b: f32 = b * b * b;      // Crush blues

        ptr[i] = @as(u8, @intFromFloat(@max(0.0, @min(1.0, new_r)) * 255.0));
        ptr[i + 1] = @as(u8, @intFromFloat(@max(0.0, @min(1.0, new_g)) * 255.0));
        ptr[i + 2] = @as(u8, @intFromFloat(@max(0.0, @min(1.0, new_b)) * 255.0));
    }
}

/// Lomography effect - high contrast with color cast
pub export fn lomography(ptr: [*]u8, len: usize) void {
    var i: usize = 0;
    while (i + 3 < len) : (i += 4) {
        const r = @as(f32, @floatFromInt(ptr[i])) / 255.0;
        const g = @as(f32, @floatFromInt(ptr[i + 1])) / 255.0;
        const b = @as(f32, @floatFromInt(ptr[i + 2])) / 255.0;

        // High contrast curve
        const contrast: f32 = 1.5;
        const new_r: f32 = ((r - 0.5) * contrast + 0.5) * 1.1;  // Boost reds
        const new_g: f32 = ((g - 0.5) * contrast + 0.5) * 0.95; // Reduce greens
        const new_b: f32 = ((b - 0.5) * contrast + 0.5) * 0.8;  // Cyan cast

        ptr[i] = @as(u8, @intFromFloat(@max(0.0, @min(1.0, new_r)) * 255.0));
        ptr[i + 1] = @as(u8, @intFromFloat(@max(0.0, @min(1.0, new_g)) * 255.0));
        ptr[i + 2] = @as(u8, @intFromFloat(@max(0.0, @min(1.0, new_b)) * 255.0));
    }
}

/// Brightness and contrast adjustment
pub export fn brightness_contrast(ptr: [*]u8, len: usize, brightness: i32, contrast: f32) void {
    var i: usize = 0;
    while (i + 3 < len) : (i += 4) {
        // Apply brightness and contrast to RGB channels
        const r: i32 = @as(i32, ptr[i]) + brightness;
        const g: i32 = @as(i32, ptr[i + 1]) + brightness;
        const b: i32 = @as(i32, ptr[i + 2]) + brightness;

        // Apply contrast
        const contrast_r: f32 = (@as(f32, @floatFromInt(r)) - 128.0) * contrast + 128.0;
        const contrast_g: f32 = (@as(f32, @floatFromInt(g)) - 128.0) * contrast + 128.0;
        const contrast_b: f32 = (@as(f32, @floatFromInt(b)) - 128.0) * contrast + 128.0;

        ptr[i] = @as(u8, @intCast(@max(0, @min(255, @as(i32, @intFromFloat(contrast_r))))));
        ptr[i + 1] = @as(u8, @intCast(@max(0, @min(255, @as(i32, @intFromFloat(contrast_g))))));
        ptr[i + 2] = @as(u8, @intCast(@max(0, @min(255, @as(i32, @intFromFloat(contrast_b))))));
    }
}

/// Saturation adjustment - control color intensity
pub export fn saturation(ptr: [*]u8, len: usize, factor: f32) void {
    var i: usize = 0;
    while (i + 3 < len) : (i += 4) {
        const r: f32 = @floatFromInt(ptr[i]);
        const g: f32 = @floatFromInt(ptr[i + 1]);
        const b: f32 = @floatFromInt(ptr[i + 2]);

        // Calculate grayscale value (luminance)
        const gray: f32 = r * 0.299 + g * 0.587 + b * 0.114;

        // Interpolate between grayscale and original color
        const new_r: f32 = gray + (r - gray) * factor;
        const new_g: f32 = gray + (g - gray) * factor;
        const new_b: f32 = gray + (b - gray) * factor;

        ptr[i] = @as(u8, @intCast(@max(0, @min(255, @as(i32, @intFromFloat(new_r))))));
        ptr[i + 1] = @as(u8, @intCast(@max(0, @min(255, @as(i32, @intFromFloat(new_g))))));
        ptr[i + 2] = @as(u8, @intCast(@max(0, @min(255, @as(i32, @intFromFloat(new_b))))));
    }
}

/// Hue shift - rotate colors around the color wheel
pub export fn hue_shift(ptr: [*]u8, len: usize, shift_degrees: f32) void {
    const shift_radians: f32 = shift_degrees * std.math.pi / 180.0;
    const cos_shift: f32 = @cos(shift_radians);
    const sin_shift: f32 = @sin(shift_radians);

    var i: usize = 0;
    while (i + 3 < len) : (i += 4) {
        const r: f32 = @floatFromInt(ptr[i]);
        const g: f32 = @floatFromInt(ptr[i + 1]);
        const b: f32 = @floatFromInt(ptr[i + 2]);

        // Convert to YIQ color space for hue rotation
        const y: f32 = 0.299 * r + 0.587 * g + 0.114 * b;
        const i_val: f32 = 0.596 * r - 0.275 * g - 0.321 * b;
        const q_val: f32 = 0.212 * r - 0.523 * g + 0.311 * b;

        // Rotate I and Q components
        const new_i: f32 = i_val * cos_shift - q_val * sin_shift;
        const new_q: f32 = i_val * sin_shift + q_val * cos_shift;

        // Convert back to RGB
        const new_r: f32 = y + 0.956 * new_i + 0.621 * new_q;
        const new_g: f32 = y - 0.272 * new_i - 0.647 * new_q;
        const new_b: f32 = y - 1.106 * new_i + 1.703 * new_q;

        ptr[i] = @as(u8, @intCast(@max(0, @min(255, @as(i32, @intFromFloat(new_r))))));
        ptr[i + 1] = @as(u8, @intCast(@max(0, @min(255, @as(i32, @intFromFloat(new_g))))));
        ptr[i + 2] = @as(u8, @intCast(@max(0, @min(255, @as(i32, @intFromFloat(new_b))))));
    }
}

/// Color temperature adjustment - warm/cool balance
pub export fn temperature(ptr: [*]u8, len: usize, temp_factor: f32) void {
    var i: usize = 0;
    while (i + 3 < len) : (i += 4) {
        const r: f32 = @floatFromInt(ptr[i]);
        const g: f32 = @floatFromInt(ptr[i + 1]);
        const b: f32 = @floatFromInt(ptr[i + 2]);

        // Adjust color temperature
        // Positive values = warmer (more red/yellow)
        // Negative values = cooler (more blue)
        const new_r: f32 = r * (1.0 + temp_factor * 0.3);
        const new_g: f32 = g * (1.0 + temp_factor * 0.1);
        const new_b: f32 = b * (1.0 - temp_factor * 0.4);

        ptr[i] = @as(u8, @intCast(@max(0, @min(255, @as(i32, @intFromFloat(new_r))))));
        ptr[i + 1] = @as(u8, @intCast(@max(0, @min(255, @as(i32, @intFromFloat(new_g))))));
        ptr[i + 2] = @as(u8, @intCast(@max(0, @min(255, @as(i32, @intFromFloat(new_b))))));
    }
}
