const vk = @import("vulkan");
const Context = @import("context.zig").Context;
const memory_utils = @import("memory.zig");
const MemoryLocation = memory_utils.MemoryLocation;

pub const BufferUsage = packed struct(u8) {
    transfer_src: bool = false,
    transfer_dst: bool = false,
    uniform: bool = false,
    storage: bool = false,
    index: bool = false,
    vertex: bool = false,
    indirect: bool = false,
    _padding: u1 = 0,
};

pub const BufferDesc = struct {
    size: u64,
    usage: BufferUsage,
    memory: MemoryLocation = .auto,
};

pub const BufferError = error{
    InvalidSize,
    OutOfHostMemory,
    OutOfDeviceMemory,
    NoSuitableMemoryType,
    MappingFailed,
    BufferCreationFailed,
};

pub const Buffer = struct {
    handle: vk.Buffer,
    memory: vk.DeviceMemory,
    size: u64,
    mapped: ?[*]u8,
    memory_location: MemoryLocation,

    pub fn init(ctx: *Context, desc: BufferDesc) BufferError!Buffer {
        if (desc.size == 0) {
            return error.InvalidSize;
        }

        const vk_usage = toVkBufferUsage(desc.usage);

        const buffer_info = vk.BufferCreateInfo{
            .size = desc.size,
            .usage = vk_usage,
            .sharing_mode = .exclusive,
            .queue_family_index_count = 0,
            .p_queue_family_indices = undefined,
        };

        const buffer = ctx.device.dispatch.createBuffer(ctx.device.handle, &buffer_info, null) catch |err| {
            return switch (err) {
                error.OutOfHostMemory => error.OutOfHostMemory,
                error.OutOfDeviceMemory => error.OutOfDeviceMemory,
                else => error.BufferCreationFailed,
            };
        };
        errdefer ctx.device.dispatch.destroyBuffer(ctx.device.handle, buffer, null);

        const mem_requirements = ctx.device.dispatch.getBufferMemoryRequirements(ctx.device.handle, buffer);

        const effective_location: MemoryLocation = if (desc.memory == .auto)
            (if (desc.usage.storage or desc.usage.vertex or desc.usage.index)
                .device_local
            else
                .host_visible)
        else
            desc.memory;

        const memory_type_index = memory_utils.findMemoryType(
            ctx.device.memory_properties,
            mem_requirements.memory_type_bits,
            effective_location,
        ) catch {
            return error.NoSuitableMemoryType;
        };

        const alloc_info = vk.MemoryAllocateInfo{
            .allocation_size = mem_requirements.size,
            .memory_type_index = memory_type_index,
        };

        const device_memory = ctx.device.dispatch.allocateMemory(ctx.device.handle, &alloc_info, null) catch |err| {
            return switch (err) {
                error.OutOfHostMemory => error.OutOfHostMemory,
                error.OutOfDeviceMemory => error.OutOfDeviceMemory,
                else => error.BufferCreationFailed,
            };
        };
        errdefer ctx.device.dispatch.freeMemory(ctx.device.handle, device_memory, null);

        ctx.device.dispatch.bindBufferMemory(ctx.device.handle, buffer, device_memory, 0) catch |err| {
            return switch (err) {
                error.OutOfHostMemory => error.OutOfHostMemory,
                error.OutOfDeviceMemory => error.OutOfDeviceMemory,
                else => error.BufferCreationFailed,
            };
        };

        var mapped: ?[*]u8 = null;
        if (effective_location == .host_visible or effective_location == .host_cached) {
            const ptr = ctx.device.dispatch.mapMemory(ctx.device.handle, device_memory, 0, desc.size, .{}) catch {
                return error.MappingFailed;
            };
            mapped = @ptrCast(ptr);
        }

        return .{
            .handle = buffer,
            .memory = device_memory,
            .size = desc.size,
            .mapped = mapped,
            .memory_location = effective_location,
        };
    }

    pub fn deinit(self: *Buffer, ctx: *Context) void {
        if (self.mapped != null) {
            ctx.device.dispatch.unmapMemory(ctx.device.handle, self.memory);
        }
        ctx.device.dispatch.destroyBuffer(ctx.device.handle, self.handle, null);
        ctx.device.dispatch.freeMemory(ctx.device.handle, self.memory, null);
        self.* = undefined;
    }

    pub fn getMappedSlice(self: *const Buffer) ?[]u8 {
        if (self.mapped) |ptr| {
            return ptr[0..self.size];
        }
        return null;
    }

    pub fn write(self: *const Buffer, data: []const u8) BufferError!void {
        const mapped_ptr = self.mapped orelse return error.MappingFailed;
        const copy_size = @min(data.len, self.size);
        @memcpy(mapped_ptr[0..copy_size], data[0..copy_size]);
    }

    pub fn read(self: *const Buffer, dest: []u8) BufferError!void {
        const mapped_ptr = self.mapped orelse return error.MappingFailed;
        const copy_size = @min(dest.len, self.size);
        @memcpy(dest[0..copy_size], mapped_ptr[0..copy_size]);
    }
};

fn toVkBufferUsage(usage: BufferUsage) vk.BufferUsageFlags {
    return .{
        .transfer_src_bit = usage.transfer_src,
        .transfer_dst_bit = usage.transfer_dst,
        .uniform_buffer_bit = usage.uniform,
        .storage_buffer_bit = usage.storage,
        .index_buffer_bit = usage.index,
        .vertex_buffer_bit = usage.vertex,
        .indirect_buffer_bit = usage.indirect,
    };
}
