const std = @import("std");
const vk = @import("vulkan");
const Loader = @import("vulkan/loader.zig").Loader;
const Instance = @import("vulkan/instance.zig").Instance;
const InstanceConfig = @import("vulkan/instance.zig").InstanceConfig;
const Device = @import("vulkan/device.zig").Device;
const DeviceConfig = @import("vulkan/device.zig").DeviceConfig;

pub const ContextError = error{
    LibraryNotFound,
    SymbolNotFound,
    InitializationFailed,
    InstanceCreationFailed,
    ExtensionNotPresent,
    LayerNotPresent,
    OutOfHostMemory,
    OutOfDeviceMemory,
    IncompatibleDriver,
    NoSuitableDevice,
    NoComputeQueue,
    DeviceCreationFailed,
    TooManyObjects,
    DeviceLost,
};

pub const Mode = enum {
    full,
    compute_only,
};

pub const Config = struct {
    app_name: [*:0]const u8 = "BLAZE App",
    validation: bool = @import("builtin").mode == .Debug,
    mode: Mode = .full,
};

pub const Context = struct {
    allocator: std.mem.Allocator,
    loader: Loader,
    vkb: vk.BaseWrapper,
    instance: Instance,
    device: Device,
    command_pool: vk.CommandPool,

    pub fn init(allocator: std.mem.Allocator, config: Config) ContextError!Context {
        var loader = Loader.init() catch |err| {
            return switch (err) {
                error.LibraryNotFound => error.LibraryNotFound,
                error.SymbolNotFound => error.SymbolNotFound,
                error.InitializationFailed => error.InitializationFailed,
            };
        };
        errdefer loader.deinit();

        const vkb = loader.getBaseFunctions();

        const instance_config = InstanceConfig{
            .app_name = config.app_name,
            .validation = config.validation,
        };

        var instance = Instance.init(vkb, instance_config) catch |err| {
            return switch (err) {
                error.InstanceCreationFailed => error.InstanceCreationFailed,
                error.ExtensionNotPresent => error.ExtensionNotPresent,
                error.LayerNotPresent => error.LayerNotPresent,
                error.OutOfHostMemory => error.OutOfHostMemory,
                error.OutOfDeviceMemory => error.OutOfDeviceMemory,
                error.InitializationFailed => error.InitializationFailed,
                error.IncompatibleDriver => error.IncompatibleDriver,
            };
        };
        errdefer instance.deinit();

        const device_config = DeviceConfig{
            .prefer_discrete = true,
            .require_compute = true,
            .require_graphics = config.mode == .full,
        };

        var device = Device.init(&instance, device_config) catch |err| {
            return switch (err) {
                error.NoSuitableDevice => error.NoSuitableDevice,
                error.NoComputeQueue => error.NoComputeQueue,
                error.DeviceCreationFailed => error.DeviceCreationFailed,
                error.OutOfHostMemory => error.OutOfHostMemory,
                error.OutOfDeviceMemory => error.OutOfDeviceMemory,
                error.InitializationFailed => error.InitializationFailed,
                error.TooManyObjects => error.TooManyObjects,
                error.DeviceLost => error.DeviceLost,
            };
        };
        errdefer device.deinit();

        const pool_info = vk.CommandPoolCreateInfo{
            .flags = .{ .reset_command_buffer_bit = true },
            .queue_family_index = device.compute_queue.family_index,
        };

        const command_pool = device.dispatch.createCommandPool(device.handle, &pool_info, null) catch |err| {
            return switch (err) {
                error.OutOfHostMemory => error.OutOfHostMemory,
                error.OutOfDeviceMemory => error.OutOfDeviceMemory,
                else => error.InitializationFailed,
            };
        };

        return .{
            .allocator = allocator,
            .loader = loader,
            .vkb = vkb,
            .instance = instance,
            .device = device,
            .command_pool = command_pool,
        };
    }

    pub fn deinit(self: *Context) void {
        self.device.dispatch.destroyCommandPool(self.device.handle, self.command_pool, null);
        self.device.deinit();
        self.instance.deinit();
        self.loader.deinit();
        self.* = undefined;
    }

    pub fn waitIdle(self: *Context) void {
        self.device.waitIdle() catch {};
    }

    pub fn getDeviceName(self: *const Context) []const u8 {
        const name_bytes = &self.device.properties.device_name;
        const len = std.mem.indexOfScalar(u8, name_bytes, 0) orelse name_bytes.len;
        return name_bytes[0..len];
    }
};
