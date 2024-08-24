const std = @import("std");
const base58 = @import("base58");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const program = b.addSharedLibrary(.{
        .name = "test-build",
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
    });
    base58.generateProgramKeypair(b, program);
    b.installArtifact(program);
}
