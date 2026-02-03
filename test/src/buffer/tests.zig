//! BLAZE Conformance Test Suite - Buffer Tests
//!
//! Tests for buffer creation, mapping, and data transfer operations.
//! Reference: CONFORMANCE.md Category 2: Buffer Operations

const std = @import("std");
const framework = @import("../framework.zig");
const blaze = @import("blaze");

pub const suite = framework.TestSuite{
    .name = "blaze.buffer",
    .tests = &.{
        // P0 - Critical
        .{ .name = "BUF-001_create_vertex_buffer", .run = createVertexBuffer, .priority = .p0 },
        .{ .name = "BUF-002_create_index_buffer", .run = createIndexBuffer, .priority = .p0 },
        .{ .name = "BUF-003_create_uniform_buffer", .run = createUniformBuffer, .priority = .p0 },
        .{ .name = "BUF-004_create_storage_buffer", .run = createStorageBuffer, .priority = .p0 },
        .{ .name = "BUF-009_map_host_visible", .run = mapHostVisible, .priority = .p0 },
        .{ .name = "BUF-010_map_write_read_back", .run = mapWriteReadBack, .priority = .p0 },
        .{ .name = "BUF-011_upload_device_local", .run = uploadDeviceLocal, .priority = .p0 },
        .{ .name = "BUF-012_download_device_local", .run = downloadDeviceLocal, .priority = .p0 },

        // P1 - Important
        .{ .name = "BUF-005_create_indirect_buffer", .run = createIndirectBuffer, .priority = .p1 },
        .{ .name = "BUF-006_create_combined_usage", .run = createCombinedUsage, .priority = .p1 },
        .{ .name = "BUF-007_create_zero_size", .run = createZeroSize, .priority = .p1 },
        .{ .name = "BUF-013_buffer_slice", .run = bufferSlice, .priority = .p1 },
        .{ .name = "BUF-014_destroy_while_mapped", .run = destroyWhileMapped, .priority = .p1 },

        // P2 - Nice to have
        .{ .name = "BUF-008_create_huge_buffer", .run = createHugeBuffer, .priority = .p2 },
        .{ .name = "BUF-015_destroy_while_in_use", .run = destroyWhileInUse, .priority = .p2 },
    },
};

fn createVertexBuffer() framework.TestError!void {
    return error.NotImplemented;
}

fn createIndexBuffer() framework.TestError!void {
    return error.NotImplemented;
}

fn createUniformBuffer() framework.TestError!void {
    return error.NotImplemented;
}

/// BUF-004: Create buffer with storage usage.
fn createStorageBuffer() framework.TestError!void {
    var ctx = blaze.Context.init(framework.getAllocator(), .{
        .app_name = "CTS-BUF-004",
        .validation = false,
        .mode = .compute_only,
    }) catch |err| {
        framework.log("Context creation failed: {s}", .{@errorName(err)});
        return error.DeviceError;
    };
    defer ctx.deinit();

    var buffer = blaze.Buffer.init(&ctx, .{
        .size = 1024,
        .usage = .{ .storage = true },
        .memory = .host_visible,
    }) catch |err| {
        framework.log("Buffer creation failed: {s}", .{@errorName(err)});
        return error.BufferError;
    };
    defer buffer.deinit(&ctx);

    try framework.expectEqual(u64, 1024, buffer.size);
    framework.log("Created storage buffer of size {d}", .{buffer.size});
}

fn createIndirectBuffer() framework.TestError!void {
    return error.NotImplemented;
}

fn createCombinedUsage() framework.TestError!void {
    return error.NotImplemented;
}

fn createZeroSize() framework.TestError!void {
    return error.NotImplemented;
}

fn createHugeBuffer() framework.TestError!void {
    return error.NotImplemented;
}

/// BUF-009: Map host-visible buffer and write directly.
fn mapHostVisible() framework.TestError!void {
    var ctx = blaze.Context.init(framework.getAllocator(), .{
        .app_name = "CTS-BUF-009",
        .validation = false,
        .mode = .compute_only,
    }) catch |err| {
        framework.log("Context creation failed: {s}", .{@errorName(err)});
        return error.DeviceError;
    };
    defer ctx.deinit();

    var buffer = blaze.Buffer.init(&ctx, .{
        .size = 256,
        .usage = .{ .storage = true },
        .memory = .host_visible,
    }) catch |err| {
        framework.log("Buffer creation failed: {s}", .{@errorName(err)});
        return error.BufferError;
    };
    defer buffer.deinit(&ctx);

    const mapped = buffer.getMappedSlice() orelse {
        framework.log("Buffer not mapped", .{});
        return error.BufferError;
    };

    const test_data = "Hello, BLAZE!";
    @memcpy(mapped[0..test_data.len], test_data);

    framework.log("Successfully wrote {d} bytes to mapped buffer", .{test_data.len});
}

/// BUF-010: Write via map, then verify contents.
fn mapWriteReadBack() framework.TestError!void {
    var ctx = blaze.Context.init(framework.getAllocator(), .{
        .app_name = "CTS-BUF-010",
        .validation = false,
        .mode = .compute_only,
    }) catch |err| {
        framework.log("Context creation failed: {s}", .{@errorName(err)});
        return error.DeviceError;
    };
    defer ctx.deinit();

    var buffer = blaze.Buffer.init(&ctx, .{
        .size = 256,
        .usage = .{ .storage = true },
        .memory = .host_visible,
    }) catch |err| {
        framework.log("Buffer creation failed: {s}", .{@errorName(err)});
        return error.BufferError;
    };
    defer buffer.deinit(&ctx);

    const test_pattern: [16]u8 = .{ 0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0 };

    buffer.write(&test_pattern) catch {
        return error.BufferError;
    };

    var read_back: [16]u8 = undefined;
    buffer.read(&read_back) catch {
        return error.BufferError;
    };

    try framework.expectEqualSlices(u8, &test_pattern, &read_back);

    framework.log("Buffer write/read round-trip verified", .{});
}

fn uploadDeviceLocal() framework.TestError!void {
    return error.NotImplemented;
}

fn downloadDeviceLocal() framework.TestError!void {
    return error.NotImplemented;
}

fn bufferSlice() framework.TestError!void {
    return error.NotImplemented;
}

fn destroyWhileMapped() framework.TestError!void {
    return error.NotImplemented;
}

fn destroyWhileInUse() framework.TestError!void {
    return error.NotImplemented;
}
