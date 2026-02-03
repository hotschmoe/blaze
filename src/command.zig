const vk = @import("vulkan");
const Context = @import("context.zig").Context;
const ComputePipeline = @import("pipeline.zig").ComputePipeline;

pub const CommandError = error{
    CommandBufferAllocationFailed,
    CommandBufferBeginFailed,
    CommandBufferEndFailed,
    SubmitFailed,
    OutOfHostMemory,
    OutOfDeviceMemory,
    DeviceLost,
};

pub const CommandBuffer = struct {
    handle: vk.CommandBuffer,

    pub fn allocate(ctx: *Context) CommandError!CommandBuffer {
        const alloc_info = vk.CommandBufferAllocateInfo{
            .command_pool = ctx.command_pool,
            .level = .primary,
            .command_buffer_count = 1,
        };

        var cmd_buffer: [1]vk.CommandBuffer = undefined;
        ctx.device.dispatch.allocateCommandBuffers(ctx.device.handle, &alloc_info, &cmd_buffer) catch |err| {
            return switch (err) {
                error.OutOfHostMemory => error.OutOfHostMemory,
                error.OutOfDeviceMemory => error.OutOfDeviceMemory,
                else => error.CommandBufferAllocationFailed,
            };
        };

        return .{ .handle = cmd_buffer[0] };
    }

    pub fn free(self: *CommandBuffer, ctx: *Context) void {
        const buffers = [_]vk.CommandBuffer{self.handle};
        ctx.device.dispatch.freeCommandBuffers(ctx.device.handle, ctx.command_pool, 1, &buffers);
        self.* = undefined;
    }

    pub fn begin(self: *const CommandBuffer, ctx: *Context) CommandError!void {
        const begin_info = vk.CommandBufferBeginInfo{
            .flags = .{ .one_time_submit_bit = true },
            .p_inheritance_info = null,
        };

        ctx.device.dispatch.beginCommandBuffer(self.handle, &begin_info) catch |err| {
            return switch (err) {
                error.OutOfHostMemory => error.OutOfHostMemory,
                error.OutOfDeviceMemory => error.OutOfDeviceMemory,
                else => error.CommandBufferBeginFailed,
            };
        };
    }

    pub fn end(self: *const CommandBuffer, ctx: *Context) CommandError!void {
        ctx.device.dispatch.endCommandBuffer(self.handle) catch |err| {
            return switch (err) {
                error.OutOfHostMemory => error.OutOfHostMemory,
                error.OutOfDeviceMemory => error.OutOfDeviceMemory,
                else => error.CommandBufferEndFailed,
            };
        };
    }

    pub fn bindComputePipeline(self: *const CommandBuffer, ctx: *Context, pipeline: *const ComputePipeline) void {
        ctx.device.dispatch.cmdBindPipeline(self.handle, .compute, pipeline.pipeline);
    }

    pub fn bindDescriptorSet(
        self: *const CommandBuffer,
        ctx: *Context,
        pipeline: *const ComputePipeline,
        descriptor_set: vk.DescriptorSet,
    ) void {
        const sets = [_]vk.DescriptorSet{descriptor_set};
        ctx.device.dispatch.cmdBindDescriptorSets(
            self.handle,
            .compute,
            pipeline.pipeline_layout,
            0,
            1,
            &sets,
            0,
            undefined,
        );
    }

    pub fn dispatch(self: *const CommandBuffer, ctx: *Context, x: u32, y: u32, z: u32) void {
        ctx.device.dispatch.cmdDispatch(self.handle, x, y, z);
    }

    pub fn submit(self: *const CommandBuffer, ctx: *Context) CommandError!void {
        const cmd_buffers = [_]vk.CommandBuffer{self.handle};
        const submit_info = vk.SubmitInfo{
            .wait_semaphore_count = 0,
            .p_wait_semaphores = undefined,
            .p_wait_dst_stage_mask = undefined,
            .command_buffer_count = 1,
            .p_command_buffers = &cmd_buffers,
            .signal_semaphore_count = 0,
            .p_signal_semaphores = undefined,
        };

        ctx.device.dispatch.queueSubmit(ctx.device.compute_queue.handle, 1, @ptrCast(&submit_info), .null_handle) catch |err| {
            return switch (err) {
                error.OutOfHostMemory => error.OutOfHostMemory,
                error.OutOfDeviceMemory => error.OutOfDeviceMemory,
                error.DeviceLost => error.DeviceLost,
                else => error.SubmitFailed,
            };
        };
    }
};
