const std = @import("std");
const blaze = @import("blaze");

pub fn main() !void {
    std.debug.print("BLAZE GPU Abstraction Layer\n", .{});
    std.debug.print("Attempting to initialize context...\n", .{});

    var ctx = blaze.Context.init(std.heap.page_allocator, .{
        .app_name = "BLAZE Test",
        .validation = false,
        .mode = .compute_only,
    }) catch |err| {
        std.debug.print("Failed to initialize context: {s}\n", .{@errorName(err)});
        std.debug.print("This is expected if no Vulkan driver is available.\n", .{});
        return;
    };
    defer ctx.deinit();

    std.debug.print("Context initialized successfully!\n", .{});
    std.debug.print("Device: {s}\n", .{ctx.getDeviceName()});
}
