const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{ .default_target = .{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
        .cpu_features_add = std.Target.wasm.featureSet(&.{ .atomics, .bulk_memory }),
    } });
    const optimization = b.standardOptimizeOption(.{});

    const lib = b.addExecutable(.{
        .name = "imageprocessing",
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/image_processing.zig" } },
        .target = target,
        .optimize = optimization,
        .strip = false,
        .single_threaded = false,
    });

    lib.entry = .disabled;
    lib.rdynamic = true;
    lib.use_lld = false;
    lib.shared_memory = true;
    lib.import_memory = true;
    lib.export_memory = true;
    // lib.max_memory = 67108864;

    b.installArtifact(lib);

    // Create a custom step to copy the WASM file to the public directory
    const copy_step = b.addInstallBinFile(.{ .src_path = .{ .owner = b, .sub_path = "zig-out/bin/imageprocessing.wasm" } }, "../../public/wasm/imageprocessing.wasm");
    b.getInstallStep().dependOn(&copy_step.step);
}
