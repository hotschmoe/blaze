const vk = @import("vulkan");

pub const MemoryLocation = enum {
    device_local,
    host_visible,
    host_cached,
    auto,
};

pub const MemoryError = error{
    NoSuitableMemoryType,
    OutOfHostMemory,
    OutOfDeviceMemory,
};

pub fn findMemoryType(
    memory_properties: vk.PhysicalDeviceMemoryProperties,
    type_filter: u32,
    location: MemoryLocation,
) MemoryError!u32 {
    const required_flags: vk.MemoryPropertyFlags = switch (location) {
        .device_local => .{ .device_local_bit = true },
        .host_visible => .{ .host_visible_bit = true, .host_coherent_bit = true },
        .host_cached => .{ .host_visible_bit = true, .host_coherent_bit = true, .host_cached_bit = true },
        .auto => .{},
    };

    const preferred_flags: vk.MemoryPropertyFlags = switch (location) {
        .device_local => .{ .device_local_bit = true },
        .host_visible => .{ .host_visible_bit = true, .host_coherent_bit = true },
        .host_cached => .{ .host_visible_bit = true, .host_coherent_bit = true, .host_cached_bit = true },
        .auto => .{ .device_local_bit = true },
    };

    var best_type: ?u32 = null;
    var best_score: i32 = -1;

    for (0..memory_properties.memory_type_count) |i| {
        const type_bit = @as(u32, 1) << @intCast(i);
        if (type_filter & type_bit == 0) {
            continue;
        }

        const mem_type = memory_properties.memory_types[i];

        if (!hasRequiredFlags(mem_type.property_flags, required_flags)) {
            continue;
        }

        var score: i32 = 0;

        if (hasRequiredFlags(mem_type.property_flags, preferred_flags)) {
            score += 100;
        }

        if (mem_type.property_flags.device_local_bit) {
            score += 10;
        }

        if (score > best_score) {
            best_score = score;
            best_type = @intCast(i);
        }
    }

    return best_type orelse error.NoSuitableMemoryType;
}

fn hasRequiredFlags(flags: vk.MemoryPropertyFlags, required: vk.MemoryPropertyFlags) bool {
    if (required.device_local_bit and !flags.device_local_bit) return false;
    if (required.host_visible_bit and !flags.host_visible_bit) return false;
    if (required.host_coherent_bit and !flags.host_coherent_bit) return false;
    if (required.host_cached_bit and !flags.host_cached_bit) return false;
    return true;
}
