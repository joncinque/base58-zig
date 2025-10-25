const std = @import("std");
const base58 = @import("base58");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const program = b.addLibrary(.{
        .name = "test_build",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    base58.generateProgramKeypair(b, program);
    b.installArtifact(program);
}
