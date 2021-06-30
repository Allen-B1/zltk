const std = @import("std");

const Builder = std.build.Builder;
const Mode = builtin.Mode;

fn configure_build(exe: *std.build.LibExeObjStep) void {
    const interface = std.build.Pkg{
        .name="interface",
        .path="interface/interface.zig"
    };
    const zltk = std.build.Pkg{
        .name="zltk",
        .path="zltk/zltk.zig",
        .dependencies= &[_]std.build.Pkg{interface}
    };
    exe.addPackage(zltk);
    exe.addIncludeDir("/usr/include/xcb");
    exe.addIncludeDir("./zltk/layer/xcb");

    exe.linkLibC();
    exe.linkSystemLibrary("xcb");
}

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    inline for(.{"layer", "test"}) |name| {
        const exe = b.addExecutable(name, "examples/" ++ name ++ ".zig");

        configure_build(exe);
        exe.setBuildMode(mode);
        exe.setTarget(target);
        exe.install();

        const step = b.step("example-" ++ name, "Build example '" ++ name ++ "'");
        step.dependOn(&exe.step);

        const run = exe.run();
        run.step.dependOn(&exe.install_step.?.step);

        const runStep = b.step("run-example-" ++ name, "Run example '" ++ name ++ "'");
        runStep.dependOn(&run.step);
    }
}