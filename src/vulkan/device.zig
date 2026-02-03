const std = @import("std");
const vk = @import("vulkan");
const Instance = @import("instance.zig").Instance;

pub const DeviceError = error{
    NoSuitableDevice,
    NoComputeQueue,
    DeviceCreationFailed,
    OutOfHostMemory,
    OutOfDeviceMemory,
    InitializationFailed,
    TooManyObjects,
    DeviceLost,
};

pub const DeviceConfig = struct {
    prefer_discrete: bool = true,
    require_compute: bool = true,
    require_graphics: bool = false,
};

pub const QueueInfo = struct {
    family_index: u32,
    handle: vk.Queue,
};

pub const Device = struct {
    physical_device: vk.PhysicalDevice,
    handle: vk.Device,
    dispatch: vk.DeviceWrapper,
    compute_queue: QueueInfo,
    properties: vk.PhysicalDeviceProperties,
    memory_properties: vk.PhysicalDeviceMemoryProperties,

    pub fn init(instance: *const Instance, config: DeviceConfig) DeviceError!Device {
        const physical_device = try selectPhysicalDevice(instance, config);
        const queue_family_index = try findQueueFamily(instance, physical_device, config);

        const queue_priority: f32 = 1.0;
        const queue_create_info = vk.DeviceQueueCreateInfo{
            .queue_family_index = queue_family_index,
            .queue_count = 1,
            .p_queue_priorities = @ptrCast(&queue_priority),
        };

        const device_features = vk.PhysicalDeviceFeatures{};

        const device_create_info = vk.DeviceCreateInfo{
            .queue_create_info_count = 1,
            .p_queue_create_infos = @ptrCast(&queue_create_info),
            .enabled_layer_count = 0,
            .pp_enabled_layer_names = undefined,
            .enabled_extension_count = 0,
            .pp_enabled_extension_names = undefined,
            .p_enabled_features = &device_features,
        };

        const device = instance.dispatch.createDevice(physical_device, &device_create_info, null) catch |err| {
            return switch (err) {
                error.OutOfHostMemory => error.OutOfHostMemory,
                error.OutOfDeviceMemory => error.OutOfDeviceMemory,
                error.InitializationFailed => error.InitializationFailed,
                error.TooManyObjects => error.TooManyObjects,
                error.DeviceLost => error.DeviceLost,
                else => error.DeviceCreationFailed,
            };
        };

        const get_proc = instance.dispatch.dispatch.vkGetDeviceProcAddr orelse return error.InitializationFailed;
        const dispatch = vk.DeviceWrapper.load(device, get_proc);

        const compute_queue = dispatch.getDeviceQueue(device, queue_family_index, 0);

        const properties = instance.dispatch.getPhysicalDeviceProperties(physical_device);
        const memory_properties = instance.dispatch.getPhysicalDeviceMemoryProperties(physical_device);

        return .{
            .physical_device = physical_device,
            .handle = device,
            .dispatch = dispatch,
            .compute_queue = .{
                .family_index = queue_family_index,
                .handle = compute_queue,
            },
            .properties = properties,
            .memory_properties = memory_properties,
        };
    }

    pub fn deinit(self: *Device) void {
        self.dispatch.destroyDevice(self.handle, null);
        self.* = undefined;
    }

    pub fn waitIdle(self: *const Device) DeviceError!void {
        self.dispatch.deviceWaitIdle(self.handle) catch |err| {
            return switch (err) {
                error.OutOfHostMemory => error.OutOfHostMemory,
                error.OutOfDeviceMemory => error.OutOfDeviceMemory,
                error.DeviceLost => error.DeviceLost,
                else => error.DeviceCreationFailed,
            };
        };
    }

    fn selectPhysicalDevice(instance: *const Instance, config: DeviceConfig) DeviceError!vk.PhysicalDevice {
        var device_count: u32 = 0;
        _ = instance.dispatch.enumeratePhysicalDevices(instance.handle, &device_count, null) catch {
            return error.NoSuitableDevice;
        };

        if (device_count == 0) {
            return error.NoSuitableDevice;
        }

        var devices: [16]vk.PhysicalDevice = undefined;
        var actual_count: u32 = @min(device_count, 16);
        _ = instance.dispatch.enumeratePhysicalDevices(instance.handle, &actual_count, &devices) catch {
            return error.NoSuitableDevice;
        };

        var best_device: ?vk.PhysicalDevice = null;
        var best_score: i32 = -1;

        for (devices[0..actual_count]) |device| {
            const score = rateDevice(instance, device, config);
            if (score > best_score) {
                best_score = score;
                best_device = device;
            }
        }

        return best_device orelse error.NoSuitableDevice;
    }

    fn rateDevice(instance: *const Instance, device: vk.PhysicalDevice, config: DeviceConfig) i32 {
        const props = instance.dispatch.getPhysicalDeviceProperties(device);

        if (config.require_compute or config.require_graphics) {
            if (findQueueFamily(instance, device, config)) |_| {} else |_| {
                return -1;
            }
        }

        return switch (props.device_type) {
            .discrete_gpu => if (config.prefer_discrete) 1000 else 0,
            .integrated_gpu => 100,
            .virtual_gpu => 50,
            .cpu => 10,
            else => 0,
        };
    }

    fn findQueueFamily(instance: *const Instance, device: vk.PhysicalDevice, config: DeviceConfig) DeviceError!u32 {
        var queue_family_count: u32 = 0;
        instance.dispatch.getPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, null);

        if (queue_family_count == 0) {
            return error.NoComputeQueue;
        }

        var queue_families: [32]vk.QueueFamilyProperties = undefined;
        var actual_count: u32 = @min(queue_family_count, 32);
        instance.dispatch.getPhysicalDeviceQueueFamilyProperties(device, &actual_count, &queue_families);

        for (queue_families[0..actual_count], 0..) |props, i| {
            const has_compute = props.queue_flags.compute_bit;
            const has_graphics = props.queue_flags.graphics_bit;

            const compute_ok = !config.require_compute or has_compute;
            const graphics_ok = !config.require_graphics or has_graphics;

            if (compute_ok and graphics_ok) {
                return @intCast(i);
            }
        }

        return error.NoComputeQueue;
    }
};
