const vk = @import("vulkan");

pub const InstanceError = error{
    InstanceCreationFailed,
    ExtensionNotPresent,
    LayerNotPresent,
    OutOfHostMemory,
    OutOfDeviceMemory,
    InitializationFailed,
    IncompatibleDriver,
};

pub const InstanceConfig = struct {
    app_name: [*:0]const u8 = "BLAZE App",
    app_version: u32 = 0x00000100,
    engine_name: [*:0]const u8 = "BLAZE",
    engine_version: u32 = 0x00000100,
    api_version: u32 = @bitCast(vk.API_VERSION_1_3),
    validation: bool = false,
};

pub const Instance = struct {
    handle: vk.Instance,
    dispatch: vk.InstanceWrapper,
    validation_enabled: bool,

    pub fn init(vkb: vk.BaseWrapper, config: InstanceConfig) InstanceError!Instance {
        const validation_layer: [*:0]const u8 = "VK_LAYER_KHRONOS_validation";

        const layers: []const [*:0]const u8 = if (config.validation)
            &.{validation_layer}
        else
            &.{};

        const app_info = vk.ApplicationInfo{
            .p_application_name = config.app_name,
            .application_version = config.app_version,
            .p_engine_name = config.engine_name,
            .engine_version = config.engine_version,
            .api_version = config.api_version,
        };

        const create_info = vk.InstanceCreateInfo{
            .p_application_info = &app_info,
            .enabled_layer_count = @intCast(layers.len),
            .pp_enabled_layer_names = layers.ptr,
            .enabled_extension_count = 0,
            .pp_enabled_extension_names = undefined,
        };

        const instance = vkb.createInstance(&create_info, null) catch |err| {
            return switch (err) {
                error.OutOfHostMemory => error.OutOfHostMemory,
                error.OutOfDeviceMemory => error.OutOfDeviceMemory,
                error.InitializationFailed => error.InitializationFailed,
                error.LayerNotPresent => error.LayerNotPresent,
                error.ExtensionNotPresent => error.ExtensionNotPresent,
                error.IncompatibleDriver => error.IncompatibleDriver,
                else => error.InstanceCreationFailed,
            };
        };

        const get_proc = vkb.dispatch.vkGetInstanceProcAddr orelse return error.InitializationFailed;
        const dispatch = vk.InstanceWrapper.load(instance, get_proc);

        return .{
            .handle = instance,
            .dispatch = dispatch,
            .validation_enabled = config.validation,
        };
    }

    pub fn deinit(self: *Instance) void {
        self.dispatch.destroyInstance(self.handle, null);
        self.* = undefined;
    }
};
